defmodule Prismatic.Memory.Impl.CachexBackend do
  @moduledoc """
  Cachex backend implementation for high-performance in-memory caching.

  This backend uses Cachex for short-term working memory with features like
  TTL expiration, LRU eviction, and high-performance concurrent access.
  Ideal for frequently accessed data that doesn't need persistence.

  ## Features

  - **High Performance**: Optimized for concurrent read/write operations
  - **TTL Support**: Automatic expiration of entries
  - **LRU Eviction**: Least Recently Used eviction when capacity is reached
  - **Memory Type Isolation**: Separate cache instances per memory type
  - **Pattern Matching**: Efficient key pattern search
  - **Comprehensive Metrics**: Built-in statistics and monitoring

  ## Configuration

  ```elixir
  config = %{
    backend_type: :cachex,
    name: :working_memory,
    ttl: 300_000,           # 5 minutes TTL
    max_size: 10_000,       # Maximum entries
    eviction_policy: :lru,  # LRU eviction
    stats: true             # Enable statistics
  }
  ```

  ## Usage Examples

  ### Basic Usage

      {:ok, config} = Memory.Protocol.create_config(:cachex, %{
        name: :working_memory,
        ttl: 300_000,
        max_size: 1000
      })

      {:ok, _} = Memory.Protocol.store(config, :working, "session_123", session_data)
      {:ok, data} = Memory.Protocol.retrieve(config, :working, "session_123")

  ### With Custom TTL

      {:ok, config} = Memory.Protocol.create_config(:cachex, %{
        name: :temp_cache,
        ttl: 60_000  # 1 minute
      })
  """

  @behaviour Prismatic.Memory.Protocol

  require Logger

  @doc """
  Stores data in the Cachex backend.

  Creates cache instances per memory type and stores data with configured TTL.
  """
  @impl true
  def store(config, memory_type, key, value) do
    Logger.debug("CachexBackend.store: #{memory_type}/#{key}")

    with {:ok, cache_name} <- get_cache_name(config, memory_type),
         :ok <- ensure_cache_started(cache_name, config),
         {:ok, true} <- Cachex.put(cache_name, key, value, ttl: get_ttl(config)) do

      Logger.debug("CachexBackend: stored #{key} in #{cache_name}")
      {:ok, config}
    else
      {:ok, false} ->
        Logger.warning("CachexBackend: failed to store #{key}")
        {:error, :write_failed}

      {:error, reason} ->
        Logger.error("CachexBackend: store error for #{key}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Retrieves data from the Cachex backend.
  """
  @impl true
  def retrieve(config, memory_type, key) do
    Logger.debug("CachexBackend.retrieve: #{memory_type}/#{key}")

    with {:ok, cache_name} <- get_cache_name(config, memory_type),
         :ok <- ensure_cache_started(cache_name, config),
         {:ok, value} <- Cachex.get(cache_name, key) do

      case value do
        nil ->
          Logger.debug("CachexBackend: key #{key} not found in #{cache_name}")
          {:error, :not_found}

        data ->
          Logger.debug("CachexBackend: retrieved #{key} from #{cache_name}")
          {:ok, data}
      end
    else
      {:error, reason} ->
        Logger.error("CachexBackend: retrieve error for #{key}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Consolidates working memory to long-term storage.

  In Cachex backend, this exports working memory entries and clears them,
  expecting another backend to handle long-term storage.
  """
  @impl true
  def consolidate(config) do
    Logger.debug("CachexBackend.consolidate")

    with {:ok, working_cache} <- get_cache_name(config, :working),
         :ok <- ensure_cache_started(working_cache, config) do

      # Export all working memory entries
      {:ok, entries} = Cachex.export(working_cache)

      # Clear working memory
      {:ok, cleared_count} = Cachex.clear(working_cache)

      Logger.info("CachexBackend: consolidated #{length(entries)} entries, cleared #{cleared_count}")

      # Return the exported entries for potential use by layered backend
      {:ok, %{config | consolidated_entries: entries}}
    else
      {:error, reason} ->
        Logger.error("CachexBackend: consolidation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Removes data from the Cachex backend.
  """
  @impl true
  def forget(config, memory_type, key) do
    Logger.debug("CachexBackend.forget: #{memory_type}/#{key}")

    with {:ok, cache_name} <- get_cache_name(config, memory_type),
         :ok <- ensure_cache_started(cache_name, config) do

      case Cachex.del(cache_name, key) do
        {:ok, true} ->
          Logger.debug("CachexBackend: deleted #{key} from #{cache_name}")
          {:ok, config}

        {:ok, false} ->
          Logger.debug("CachexBackend: key #{key} not found for deletion")
          {:error, :not_found}

        {:error, reason} ->
          Logger.error("CachexBackend: delete error for #{key}: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Searches for entries matching a pattern.

  Uses Cachex's key streaming for efficient pattern matching.
  """
  @impl true
  def search(config, memory_type, pattern) do
    Logger.debug("CachexBackend.search: #{memory_type}/#{pattern}")

    with {:ok, cache_name} <- get_cache_name(config, memory_type),
         :ok <- ensure_cache_started(cache_name, config) do

      # Convert wildcard pattern to regex
      regex_pattern = pattern
      |> String.replace("*", ".*")
      |> then(&("^" <> &1 <> "$"))

      {:ok, regex} = Regex.compile(regex_pattern)

      # Stream keys and filter by pattern
      results = cache_name
      |> Cachex.stream!(keys: true)
      |> Stream.filter(fn key ->
        key_str = to_string(key)
        Regex.match?(regex, key_str)
      end)
      |> Stream.map(fn key ->
        {:ok, value} = Cachex.get(cache_name, key)
        {key, value}
      end)
      |> Enum.to_list()

      Logger.debug("CachexBackend: found #{length(results)} matches for pattern #{pattern}")
      {:ok, results}
    else
      {:error, reason} ->
        Logger.error("CachexBackend: search error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Validates the Cachex backend configuration.
  """
  @impl true
  def validate_config(config) do
    required_fields = [:backend_type, :name]

    case check_required_fields(config, required_fields) do
      :ok ->
        if config.backend_type == :cachex do
          validate_cachex_specific_config(config)
        else
          {:error, {:invalid_backend_type, config.backend_type}}
        end

      error ->
        error
    end
  end

  @doc """
  Performs a health check on the Cachex backend.
  """
  @impl true
  def health_check(config) do
    Logger.debug("CachexBackend.health_check")

    test_cache = :"health_check_#{config.name}"

    try do
      # Start a temporary cache for health check
      {:ok, _pid} = Cachex.start_link(test_cache, [])

      # Test basic operations
      test_key = "health_check_#{System.unique_integer()}"
      test_value = "health_check_value"

      with {:ok, true} <- Cachex.put(test_cache, test_key, test_value),
           {:ok, ^test_value} <- Cachex.get(test_cache, test_key),
           {:ok, true} <- Cachex.del(test_cache, test_key) do

        # Clean up
        GenServer.stop(test_cache)
        :ok
      else
        error ->
          GenServer.stop(test_cache)
          Logger.error("CachexBackend health check failed: #{inspect(error)}")
          {:error, :health_check_failed}
      end
    rescue
      error ->
        Logger.error("CachexBackend health check exception: #{inspect(error)}")
        {:error, {:health_check_exception, error}}
    end
  end

  @doc """
  Gets information about the Cachex backend.
  """
  @impl true
  def get_backend_info(config) do
    # Get stats from all memory type caches
    memory_types = [:working, :episodic, :semantic, :procedural]

    cache_stats = Enum.reduce(memory_types, %{}, fn memory_type, acc ->
      case get_cache_stats(config, memory_type) do
        {:ok, stats} -> Map.put(acc, memory_type, stats)
        {:error, _} -> acc
      end
    end)

    info = %{
      backend_type: :cachex,
      name: config.name,
      max_entries: Map.get(config, :max_size, :unlimited),
      ttl_ms: get_ttl(config),
      supports_ttl: true,
      supports_search: true,
      supports_consolidation: true,
      cache_stats: cache_stats,
      eviction_policy: Map.get(config, :eviction_policy, :lru)
    }

    {:ok, info}
  end

  @spec get_cache_stats(map(), atom()) :: {:ok, map()} | {:error, term()}
  defp get_cache_stats(config, memory_type) do
    with {:ok, cache_name} <- get_cache_name(config, memory_type),
         pid when not is_nil(pid) <- Process.whereis(cache_name),
         {:ok, stats} <- Cachex.stats(cache_name) do
      {:ok, stats}
    else
      _ -> {:error, :cache_not_available}
    end
  end

  ## Private Implementation

  @spec get_cache_name(map(), atom()) :: {:ok, atom()}
  defp get_cache_name(config, memory_type) do
    cache_name = :"#{config.name}_#{memory_type}"
    {:ok, cache_name}
  end

  @spec ensure_cache_started(atom(), map()) :: :ok | {:error, term()}
  defp ensure_cache_started(cache_name, config) do
    case Process.whereis(cache_name) do
      nil ->
        start_cache(cache_name, config)

      _pid ->
        :ok
    end
  end

  @spec start_cache(atom(), map()) :: :ok | {:error, term()}
  defp start_cache(cache_name, config) do
    cache_options = build_cache_options(config)

    case Cachex.start_link(cache_name, cache_options) do
      {:ok, _pid} ->
        Logger.info("CachexBackend: started cache #{cache_name}")
        :ok

      {:error, pid} when is_pid(pid) ->
        :ok

      {:error, reason} ->
        Logger.error("CachexBackend: failed to start cache #{cache_name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec build_cache_options(map()) :: keyword()
  defp build_cache_options(config) do
    options = []

    # Add size limit if configured
    options = case Map.get(config, :max_size) do
      nil -> options
      max_size when is_integer(max_size) ->
        [{:limit, max_size} | options]
      _ -> options
    end

    # Add eviction policy
    options = case Map.get(config, :eviction_policy, :lru) do
      :lru -> [{:policy, Cachex.Policy.LRU} | options]
      _ -> options
    end

    # Enable stats if requested
    options = case Map.get(config, :stats, true) do
      true -> [{:stats, true} | options]
      false -> options
    end

    options
  end

  @spec get_ttl(map()) :: pos_integer() | nil
  defp get_ttl(config) do
    Map.get(config, :ttl)
  end

  @spec check_required_fields(map(), [atom()]) :: :ok | {:error, {:missing_field, atom()}}
  defp check_required_fields(config, required_fields) do
    missing_field = Enum.find(required_fields, fn field ->
      not Map.has_key?(config, field)
    end)

    case missing_field do
      nil -> :ok
      field -> {:error, {:missing_field, field}}
    end
  end

  @spec validate_cachex_specific_config(map()) :: :ok | {:error, term()}
  defp validate_cachex_specific_config(config) do
    with :ok <- validate_max_size(config),
         :ok <- validate_ttl(config) do
      validate_eviction_policy(config)
    end
  end

  @spec validate_max_size(map()) :: :ok | {:error, term()}
  defp validate_max_size(config) do
    case Map.get(config, :max_size) do
      nil -> :ok
      size when is_integer(size) and size > 0 -> :ok
      size -> {:error, {:invalid_max_size, size}}
    end
  end

  @spec validate_ttl(map()) :: :ok | {:error, term()}
  defp validate_ttl(config) do
    case Map.get(config, :ttl) do
      nil -> :ok
      ttl when is_integer(ttl) and ttl > 0 -> :ok
      ttl -> {:error, {:invalid_ttl, ttl}}
    end
  end

  @spec validate_eviction_policy(map()) :: :ok | {:error, term()}
  defp validate_eviction_policy(config) do
    case Map.get(config, :eviction_policy, :lru) do
      :lru -> :ok
      policy -> {:error, {:invalid_eviction_policy, policy}}
    end
  end
end
