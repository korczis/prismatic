defmodule Prismatic.Memory.Protocol do
  @moduledoc """
  Memory system interface protocol for the Prismatic AI Agent Framework.

  This protocol defines the contract for memory operations across different
  memory types and backend implementations. It provides a unified interface
  for storing, retrieving, and managing data in a multi-layered memory system
  using proven solutions (Mnesia, Cachex, Nebulex).

  ## Architecture

  The Memory Protocol system follows a protocol-driven architecture with:

  - **Behavior Contract**: All backends implement the same interface
  - **Factory Pattern**: Centralized backend creation and configuration
  - **Layered Memory**: Hierarchical memory with different persistence levels
  - **Fault Tolerance**: Circuit breakers and retry logic built-in
  - **Metrics Collection**: Comprehensive monitoring and observability
  - **Backend Abstraction**: Seamless switching between different memory backends

  ## Memory Types

  - `:working` - Short-term working memory for active processing (Cachex)
  - `:episodic` - Long-term memory for specific experiences and events (Nebulex)
  - `:semantic` - Long-term memory for facts and general knowledge (Mnesia)
  - `:procedural` - Long-term memory for skills and procedures (Mnesia)

  ## Supported Backends

  - `:cachex` - High-performance in-memory cache for short-term memory
  - `:nebulex` - Distributed cache for medium-term memory
  - `:mnesia` - Persistent distributed database for long-term memory
  - `:layered` - Orchestrates multiple backends in a hierarchy
  - `:test` - Test backend for development and testing

  ## Usage Examples

  ### Basic Usage

      # Create memory configuration
      {:ok, config} = Prismatic.Memory.Protocol.create_config(:layered, %{
        backends: %{
          working: {:cachex, %{name: :working_memory}},
          episodic: {:nebulex, %{name: :episodic_cache}},
          semantic: {:mnesia, %{table: :semantic_memory}}
        }
      })

      # Store data
      {:ok, updated_memory} = Prismatic.Memory.Protocol.store(
        config,
        :working,
        "current_task",
        %{task: "analyze_document", status: :in_progress}
      )

      # Retrieve data
      {:ok, value} = Prismatic.Memory.Protocol.retrieve(config, :working, "current_task")

  ### With Error Handling

      case Prismatic.Memory.Protocol.store(config, :semantic, key, value) do
        {:ok, updated_memory} ->
          handle_success(updated_memory)
        {:error, :circuit_breaker_open} ->
          handle_circuit_breaker()
        {:error, :storage_full} ->
          handle_storage_full()
        {:error, reason} ->
          handle_error(reason)
      end

  ### Memory Consolidation

      # Move working memory to long-term storage
      {:ok, consolidated_memory} = Prismatic.Memory.Protocol.consolidate(config)

  ### Search Operations

      # Search for patterns
      {:ok, results} = Prismatic.Memory.Protocol.search(config, :semantic, "user_*")

  ## Configuration Structure

      %{
        backend_type: :cachex | :nebulex | :mnesia | :layered | :test,
        name: atom(),                  # Memory instance name
        timeout: integer(),            # Request timeout (ms)
        max_retries: integer(),        # Maximum retry attempts
        ttl: integer() | nil,          # Time-to-live (ms)
        max_size: integer() | nil,     # Maximum entries
        backends: %{                   # For layered backend
          working: {backend_type(), config()},
          episodic: {backend_type(), config()},
          semantic: {backend_type(), config()},
          procedural: {backend_type(), config()}
        },
        circuit_breaker: %{            # Circuit breaker settings
          failure_threshold: integer(),
          recovery_timeout: integer(),
          success_threshold: integer()
        }
      }

  ## Error Handling

  The memory system provides comprehensive error classification:

  - **Storage Errors**: `:storage_full`, `:write_failed`, `:read_failed`
  - **Network Errors**: `:timeout`, `:econnrefused`, `:enetunreach`
  - **Validation**: `:invalid_key`, `:invalid_value`, `:invalid_memory_type`
  - **Circuit Breaker**: `:circuit_breaker_open`
  - **Not Found**: `:not_found`, `:key_not_found`

  ## Telemetry Events

  The system emits telemetry events for monitoring:

  - `[:prismatic, :memory, :protocol, :store]` - Store operation completion
  - `[:prismatic, :memory, :protocol, :retrieve]` - Retrieve operation completion
  - `[:prismatic, :memory, :protocol, :consolidate]` - Consolidation completion
  - `[:prismatic, :memory, :protocol, :circuit_breaker]` - Circuit breaker state changes
  """

  alias Prismatic.Memory.Impl.{CachexBackend, LayeredBackend, MnesiaBackend, NebulexBackend, TestBackend}

  @typedoc "Memory backend configuration map"
  @type config :: %{
    backend_type: backend_type(),
    name: atom(),
    timeout: pos_integer(),
    max_retries: non_neg_integer(),
    retry_delay: pos_integer(),
    ttl: pos_integer() | nil,
    max_size: pos_integer() | nil
  }

  @typedoc "Supported backend types"
  @type backend_type :: :cachex | :nebulex | :mnesia | :layered | :test

  @typedoc "Memory types for different data categories"
  @type memory_type :: :working | :episodic | :semantic | :procedural

  @typedoc "Storage key (must be string or atom)"
  @type key :: String.t() | atom()

  @typedoc "Stored value (any term)"
  @type value :: term()

  @typedoc "Search pattern with wildcards"
  @type pattern :: String.t()

  @typedoc "Search results as key-value pairs"
  @type search_results :: [{key(), value()}]

  @typedoc "Memory instance state"
  @type memory_state :: term()

  @typedoc "Memory entry with key, value, and metadata"
  @type memory_entry :: %{
    key: key(),
    value: value(),
    metadata: map()
  }

  @memory_types [:working, :episodic, :semantic, :procedural]

  @doc """
  Store data in the specified memory type.

  This is the primary function for storing data in memory backends. It handles
  routing to the appropriate backend implementation, applies circuit breaker
  protection, retry logic, and metrics collection.

  ## Parameters

  - `memory` - The memory instance or configuration
  - `type` - Memory type (#{inspect(@memory_types)})
  - `key` - Storage key (string or atom)
  - `value` - Data to store (any term)

  ## Returns

  - `{:ok, updated_memory}` - Successfully stored data
  - `{:error, reason}` - Storage failed with reason

  ## Examples

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{})
      iex> {:ok, _memory} = Prismatic.Memory.Protocol.store(config, :working, "test_key", "test_value")
      {:ok, %{}}

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{
      ...>   responses: %{"error_key" => {:error, :storage_full}}
      ...> })
      iex> Prismatic.Memory.Protocol.store(config, :working, "error_key", "value")
      {:error, :storage_full}
  """
  @callback store(memory_state(), memory_type(), key(), value()) ::
    {:ok, memory_state()} | {:error, term()}

  @doc """
  Retrieve data from Prismatic.Memory.

  Fetches data from the specified memory type using the provided key.
  Handles backend routing, error handling, and metrics collection.

  ## Parameters

  - `memory` - The memory instance or configuration
  - `type` - Memory type (#{inspect(@memory_types)})
  - `key` - Storage key (string or atom)

  ## Returns

  - `{:ok, value}` - Successfully retrieved data
  - `{:error, :not_found}` - Key not found
  - `{:error, reason}` - Retrieval failed

  ## Examples

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{})
      iex> {:ok, _} = Prismatic.Memory.Protocol.store(config, :working, "test", "value")
      iex> {:ok, value} = Prismatic.Memory.Protocol.retrieve(config, :working, "test")
      iex> value
      "value"

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{})
      iex> Prismatic.Memory.Protocol.retrieve(config, :working, "nonexistent")
      {:error, :not_found}
  """
  @callback retrieve(memory_state(), memory_type(), key()) ::
    {:ok, value()} | {:error, term()}

  @doc """
  Consolidate working memory to long-term storage.

  This operation moves appropriate data from working memory to
  long-term memory types based on consolidation rules and policies.

  ## Parameters

  - `memory` - The memory instance

  ## Returns

  - `{:ok, consolidated_memory}` - Successfully consolidated
  - `{:error, reason}` - Consolidation failed

  ## Examples

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{})
      iex> {:ok, _} = Prismatic.Memory.Protocol.store(config, :working, "temp", "data")
      iex> {:ok, consolidated} = Prismatic.Memory.Protocol.consolidate(config)
      iex> is_map(consolidated)
      true
  """
  @callback consolidate(memory_state()) :: {:ok, memory_state()} | {:error, term()}

  @doc """
  Remove data from Prismatic.Memory.

  Deletes the specified key from the given memory type.

  ## Parameters

  - `memory` - The memory instance
  - `type` - Memory type (#{inspect(@memory_types)})
  - `key` - Storage key (string or atom)

  ## Returns

  - `{:ok, updated_memory}` - Successfully removed data
  - `{:error, :not_found}` - Key not found
  - `{:error, reason}` - Removal failed

  ## Examples

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{})
      iex> {:ok, _} = Prismatic.Memory.Protocol.store(config, :working, "temp", "data")
      iex> {:ok, _memory} = Prismatic.Memory.Protocol.forget(config, :working, "temp")
      {:ok, %{}}

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{})
      iex> Prismatic.Memory.Protocol.forget(config, :working, "nonexistent")
      {:error, :not_found}
  """
  @callback forget(memory_state(), memory_type(), key()) ::
    {:ok, memory_state()} | {:error, term()}

  @doc """
  Search memory with pattern matching.

  Searches for keys matching the given pattern in the specified memory type.
  Supports wildcards and regular expressions depending on backend.

  ## Parameters

  - `memory` - The memory instance
  - `type` - Memory type (#{inspect(@memory_types)})
  - `pattern` - Search pattern (string with wildcards)

  ## Returns

  - `{:ok, results}` - List of matching key-value pairs
  - `{:error, reason}` - Search failed

  ## Examples

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{})
      iex> {:ok, _} = Prismatic.Memory.Protocol.store(config, :working, "user_1", "data1")
      iex> {:ok, _} = Prismatic.Memory.Protocol.store(config, :working, "user_2", "data2")
      iex> {:ok, results} = Prismatic.Memory.Protocol.search(config, :working, "user_*")
      iex> length(results)
      2
  """
  @callback search(memory_state(), memory_type(), pattern()) ::
    {:ok, search_results()} | {:error, term()}

  @doc """
  Validates the memory configuration.

  Checks that all required fields are present and have valid values.
  Each backend implementation may have specific validation requirements.

  ## Parameters

  - `config` - Configuration to validate

  ## Returns

  - `:ok` - Configuration is valid
  - `{:error, reason}` - Configuration is invalid

  ## Examples

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{})
      iex> Prismatic.Memory.Protocol.validate_config(config)
      :ok

      iex> Prismatic.Memory.Protocol.validate_config(%{backend_type: :invalid})
      {:error, {:unsupported_backend, :invalid}}
  """
  @callback validate_config(config()) :: :ok | {:error, term()}

  @doc """
  Checks if the memory backend is healthy and available.

  Performs a lightweight health check to verify backend connectivity
  and basic functionality. Used for monitoring and load balancing.

  ## Parameters

  - `config` - Memory configuration

  ## Returns

  - `:ok` - Backend is healthy
  - `{:error, reason}` - Backend is unavailable

  ## Examples

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{})
      iex> Prismatic.Memory.Protocol.health_check(config)
      :ok
  """
  @callback health_check(config()) :: :ok | {:error, term()}

  @doc """
  Retrieves information about the memory backend capabilities.

  Returns detailed information about the configured backend including
  capacity limits, supported features, and performance characteristics.

  ## Parameters

  - `config` - Memory configuration

  ## Returns

  - `{:ok, backend_info}` - Backend information
  - `{:error, reason}` - Failed to get backend info

  ## Examples

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{})
      iex> {:ok, info} = Prismatic.Memory.Protocol.get_backend_info(config)
      iex> info.backend_type
      :test
      iex> is_integer(info.max_entries)
      true
  """
  @callback get_backend_info(config()) :: {:ok, map()} | {:error, term()}

  ## Public API Functions

  @doc """
  Creates a new memory backend configuration.

  This function validates the backend type and creates a properly structured
  configuration map with defaults applied.

  ## Parameters

  - `backend_type` - Type of backend (`:cachex`, `:nebulex`, `:mnesia`, `:layered`, `:test`)
  - `options` - Backend-specific options

  ## Returns

  - `{:ok, config}` - Valid configuration
  - `{:error, reason}` - Invalid configuration

  ## Examples

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{})
      iex> config.backend_type
      :test
      iex> is_integer(config.timeout)
      true

      iex> Prismatic.Memory.Protocol.create_config(:invalid, %{})
      {:error, {:unsupported_backend, :invalid}}
  """
  @spec create_config(backend_type(), map()) :: {:ok, config()} | {:error, term()}
  def create_config(backend_type, options \\ %{}) do
    case validate_backend_type(backend_type) do
      :ok ->
        base_config = %{
          backend_type: backend_type,
          name: Map.get(options, :name, :"memory_#{backend_type}"),
          timeout: 30_000,
          max_retries: 3,
          retry_delay: 1_000,
          ttl: nil,
          max_size: nil
        }

        config = Map.merge(base_config, options)
        {:ok, config}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Stores data using the specified memory configuration.

  This is the main entry point for memory storage operations. It routes the request
  to the appropriate backend implementation with full error handling and monitoring.

  ## Examples

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{})
      iex> {:ok, _memory} = Prismatic.Memory.Protocol.store(config, :working, "test", "value")
      {:ok, %{}}
  """
  @spec store(config(), memory_type(), key(), value()) :: {:ok, memory_state()} | {:error, term()}
  def store(config, memory_type, key, value) do
    with :ok <- validate_config(config),
         :ok <- validate_memory_type(memory_type),
         :ok <- validate_key(key),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do

      # Circuit breaker and retry logic are now handled by the shared backend macro
      backend_module.store(config, memory_type, key, value)
    end
  end

  @doc """
  Retrieves data using the specified memory configuration.

  ## Examples

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{})
      iex> {:ok, _} = Prismatic.Memory.Protocol.store(config, :working, "test", "value")
      iex> {:ok, value} = Prismatic.Memory.Protocol.retrieve(config, :working, "test")
      iex> value
      "value"
  """
  @spec retrieve(config(), memory_type(), key()) :: {:ok, value()} | {:error, term()}
  def retrieve(config, memory_type, key) do
    with :ok <- validate_config(config),
         :ok <- validate_memory_type(memory_type),
         :ok <- validate_key(key),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do

      # Circuit breaker and retry logic are now handled by the shared backend macro
      backend_module.retrieve(config, memory_type, key)
    end
  end

  @doc """
  Consolidates working memory to long-term storage.

  ## Examples

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{})
      iex> {:ok, consolidated} = Prismatic.Memory.Protocol.consolidate(config)
      iex> is_map(consolidated)
      true
  """
  @spec consolidate(config()) :: {:ok, memory_state()} | {:error, term()}
  def consolidate(config) do
    with :ok <- validate_config(config),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do

      # Circuit breaker and retry logic are now handled by the shared backend macro
      backend_module.consolidate(config)
    end
  end

  @doc """
  Removes data from Prismatic.Memory.

  ## Examples

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{})
      iex> {:ok, _} = Prismatic.Memory.Protocol.store(config, :working, "temp", "data")
      iex> {:ok, _memory} = Prismatic.Memory.Protocol.forget(config, :working, "temp")
      {:ok, %{}}
  """
  @spec forget(config(), memory_type(), key()) :: {:ok, memory_state()} | {:error, term()}
  def forget(config, memory_type, key) do
    with :ok <- validate_config(config),
         :ok <- validate_memory_type(memory_type),
         :ok <- validate_key(key),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do

      # Circuit breaker and retry logic are now handled by the shared backend macro
      backend_module.forget(config, memory_type, key)
    end
  end

  @doc """
  Searches memory with pattern matching.

  ## Examples

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{})
      iex> {:ok, _} = Prismatic.Memory.Protocol.store(config, :working, "user_1", "data1")
      iex> {:ok, results} = Prismatic.Memory.Protocol.search(config, :working, "user_*")
      iex> length(results) >= 1
      true
  """
  @spec search(config(), memory_type(), pattern()) :: {:ok, search_results()} | {:error, term()}
  def search(config, memory_type, pattern) do
    with :ok <- validate_config(config),
         :ok <- validate_memory_type(memory_type),
         :ok <- validate_pattern(pattern),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do

      # Circuit breaker and retry logic are now handled by the shared backend macro
      backend_module.search(config, memory_type, pattern)
    end
  end

  @doc """
  Validates a memory configuration.

  ## Examples

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{})
      iex> Prismatic.Memory.Protocol.validate_config(config)
      :ok
  """
  @spec validate_config(config()) :: :ok | {:error, term()}
  def validate_config(config) do
    with :ok <- validate_backend_type(config.backend_type),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do
      backend_module.validate_config(config)
    end
  end

  @doc """
  Performs a health check on the memory backend.

  ## Examples

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{})
      iex> Prismatic.Memory.Protocol.health_check(config)
      :ok
  """
  @spec health_check(config()) :: :ok | {:error, term()}
  def health_check(config) do
    with :ok <- validate_config(config),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do
      backend_module.health_check(config)
    end
  end

  @doc """
  Gets backend information for the configured memory system.

  ## Examples

      iex> {:ok, config} = Prismatic.Memory.Protocol.create_config(:test, %{})
      iex> {:ok, info} = Prismatic.Memory.Protocol.get_backend_info(config)
      iex> info.backend_type
      :test
  """
  @spec get_backend_info(config()) :: {:ok, map()} | {:error, term()}
  def get_backend_info(config) do
    with :ok <- validate_config(config),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do
      backend_module.get_backend_info(config)
    end
  end

  @doc """
  Lists all available backend types.

  ## Returns

  List of supported backend atoms.

  ## Examples

      iex> backends = Prismatic.Memory.Protocol.available_backends()
      iex> :test in backends
      true
      iex> :cachex in backends
      true
  """
  @spec available_backends() :: [:cachex | :layered | :mnesia | :nebulex | :test]
  def available_backends do
    [:cachex, :nebulex, :mnesia, :layered, :test]
  end

  @doc """
  Lists all supported memory types.

  ## Returns

  List of supported memory type atoms.

  ## Examples

      iex> types = Prismatic.Memory.Protocol.memory_types()
      iex> :working in types
      true
      iex> :semantic in types
      true
  """
  @spec memory_types() :: [:episodic | :procedural | :semantic | :working]
  def memory_types do
    @memory_types
  end

  ## Private Implementation

  @spec validate_backend_type(term()) :: :ok | {:error, {:unsupported_backend, term()}}
  defp validate_backend_type(backend_type) when backend_type in [:cachex, :nebulex, :mnesia, :layered, :test] do
    :ok
  end

  defp validate_backend_type(backend_type) do
    {:error, {:unsupported_backend, backend_type}}
  end

  @spec validate_memory_type(term()) :: :ok | {:error, {:invalid_memory_type, term()}}
  defp validate_memory_type(memory_type) when memory_type in @memory_types do
    :ok
  end

  defp validate_memory_type(memory_type) do
    {:error, {:invalid_memory_type, memory_type}}
  end

  @spec validate_key(term()) :: :ok | {:error, {:invalid_key, term()}}
  defp validate_key(key) when is_binary(key) or is_atom(key) do
    :ok
  end

  defp validate_key(key) do
    {:error, {:invalid_key, key}}
  end

  @spec validate_pattern(term()) :: :ok | {:error, {:invalid_pattern, term()}}
  defp validate_pattern(pattern) when is_binary(pattern) do
    :ok
  end

  defp validate_pattern(pattern) do
    {:error, {:invalid_pattern, pattern}}
  end

  @spec get_backend_module(backend_type()) :: {:ok, module()} | {:error, term()}
  defp get_backend_module(:cachex), do: {:ok, CachexBackend}
  defp get_backend_module(:nebulex), do: {:ok, NebulexBackend}
  defp get_backend_module(:mnesia), do: {:ok, MnesiaBackend}
  defp get_backend_module(:layered), do: {:ok, LayeredBackend}
  defp get_backend_module(:test), do: {:ok, TestBackend}
  defp get_backend_module(backend_type), do: {:error, {:unsupported_backend, backend_type}}
end
