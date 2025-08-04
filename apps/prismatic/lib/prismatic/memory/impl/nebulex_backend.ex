defmodule Prismatic.Memory.Impl.NebulexBackend do
  @moduledoc """
  Nebulex backend implementation for distributed caching.

  This backend uses Nebulex for medium-term episodic memory with features like
  distributed caching, partitioning, and replication across nodes.
  Ideal for data that needs to be shared across multiple nodes but doesn't
  require permanent persistence.

  ## Features

  - **Distributed Caching**: Automatic data distribution across cluster nodes
  - **Partitioning**: Data partitioned for scalability
  - **Replication**: Configurable replication for fault tolerance
  - **TTL Support**: Automatic expiration of entries
  - **Near Cache**: Local caching for frequently accessed data
  - **Telemetry Integration**: Built-in metrics and monitoring

  ## Configuration

  ```elixir
  config = %{
    backend_type: :nebulex,
    name: :episodic_memory,
    cache_module: MyApp.EpisodicCache,
    ttl: 3600_000,          # 1 hour TTL
    partitions: 4,          # Number of partitions
    replicas: 2             # Number of replicas
  }
  ```

  ## Cache Module Definition

  You need to define a cache module using Nebulex:

  ```elixir
  defmodule MyApp.EpisodicCache do
    use Nebulex.Cache,
      otp_app: :my_app,
      adapter: Nebulex.Adapters.Partitioned

    defmodule Primary do
      use Nebulex.Cache,
        otp_app: :my_app,
        adapter: Nebulex.Adapters.Local
    end
  end
  ```

  ## Usage Examples

  ### Basic Usage

      {:ok, config} = Memory.Protocol.create_config(:nebulex, %{
        name: :episodic_memory,
        cache_module: MyApp.EpisodicCache,
        ttl: 3600_000
      })

      {:ok, _} = Memory.Protocol.store(config, :episodic, "user_session_123", session_data)
      {:ok, data} = Memory.Protocol.retrieve(config, :episodic, "user_session_123")
  """

  @behaviour Prismatic.Memory.Protocol

  require Logger

  @doc """
  Stores data in the Nebulex backend.

  Uses the configured cache module to store data with TTL.
  """
  @impl true
  def store(config, memory_type, key, value) do
    Logger.debug("NebulexBackend.store: #{memory_type}/#{key}")

    with {:ok, cache_module} <- get_cache_module(config),
         :ok <- ensure_cache_started(cache_module),
         storage_key <- build_storage_key(memory_type, key),
         ttl <- get_ttl(config) do

      try do
        case ttl do
          nil ->
            cache_module.put(storage_key, value)

          ttl_ms when is_integer(ttl_ms) ->
            cache_module.put(storage_key, value, ttl: ttl_ms)
        end

        Logger.debug("NebulexBackend: stored #{storage_key} in #{cache_module}")
        {:ok, config}
      rescue
        error ->
          Logger.error("NebulexBackend: store error for #{storage_key}: #{inspect(error)}")
          {:error, {:store_failed, error}}
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Retrieves data from the Nebulex backend.
  """
  @impl true
  def retrieve(config, memory_type, key) do
    Logger.debug("NebulexBackend.retrieve: #{memory_type}/#{key}")

    with {:ok, cache_module} <- get_cache_module(config),
         :ok <- ensure_cache_started(cache_module),
         storage_key <- build_storage_key(memory_type, key) do

      try do
        case cache_module.get(storage_key) do
          nil ->
            Logger.debug("NebulexBackend: key #{storage_key} not found")
            {:error, :not_found}

          value ->
            Logger.debug("NebulexBackend: retrieved #{storage_key}")
            {:ok, value}
        end
      rescue
        error ->
          Logger.error("NebulexBackend: retrieve error for #{storage_key}: #{inspect(error)}")
          {:error, {:retrieve_failed, error}}
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Consolidates working memory to long-term storage.

  In Nebulex backend, this moves entries from working memory type
  to episodic memory type within the same cache.
  """
  @impl true
  def consolidate(config) do
    Logger.debug("NebulexBackend.consolidate")

    with {:ok, cache_module} <- get_cache_module(config),
         :ok <- ensure_cache_started(cache_module) do

      try do
        # Get all working memory keys
        working_pattern = build_storage_key(:working, "*")
        working_keys = get_keys_by_pattern(cache_module, working_pattern)

        consolidated_count = Enum.reduce(working_keys, 0, fn working_key, acc ->
          case cache_module.get(working_key) do
            nil ->
              acc

            value ->
              # Extract original key from storage key
              original_key = extract_original_key(working_key, :working)
              episodic_key = build_storage_key(:episodic, original_key)

              # Move to episodic memory
              cache_module.put(episodic_key, value, ttl: get_ttl(config))
              cache_module.delete(working_key)

              acc + 1
          end
        end)

        Logger.info("NebulexBackend: consolidated #{consolidated_count} entries")
        {:ok, config}
      rescue
        error ->
          Logger.error("NebulexBackend: consolidation failed: #{inspect(error)}")
          {:error, {:consolidation_failed, error}}
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Removes data from the Nebulex backend.
  """
  @impl true
  def forget(config, memory_type, key) do
    Logger.debug("NebulexBackend.forget: #{memory_type}/#{key}")

    with {:ok, cache_module} <- get_cache_module(config),
         :ok <- ensure_cache_started(cache_module),
         storage_key <- build_storage_key(memory_type, key) do

      try do
        case cache_module.get(storage_key) do
          nil ->
            Logger.debug("NebulexBackend: key #{storage_key} not found for deletion")
            {:error, :not_found}

          _value ->
            cache_module.delete(storage_key)
            Logger.debug("NebulexBackend: deleted #{storage_key}")
            {:ok, config}
        end
      rescue
        error ->
          Logger.error("NebulexBackend: delete error for #{storage_key}: #{inspect(error)}")
          {:error, {:delete_failed, error}}
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Searches for entries matching a pattern.

  Uses pattern matching to find keys and retrieves their values.
  """
  @impl true
  def search(config, memory_type, pattern) do
    Logger.debug("NebulexBackend.search: #{memory_type}/#{pattern}")

    with {:ok, cache_module} <- get_cache_module(config),
         :ok <- ensure_cache_started(cache_module) do

      try do
        # Build search pattern for storage keys
        storage_pattern = build_storage_key(memory_type, pattern)
        matching_keys = get_keys_by_pattern(cache_module, storage_pattern)

        results = Enum.reduce(matching_keys, [], fn storage_key, acc ->
          case cache_module.get(storage_key) do
            nil ->
              acc

            value ->
              original_key = extract_original_key(storage_key, memory_type)
              [{original_key, value} | acc]
          end
        end)
        |> Enum.reverse()

        Logger.debug("NebulexBackend: found #{length(results)} matches for pattern #{pattern}")
        {:ok, results}
      rescue
        error ->
          Logger.error("NebulexBackend: search error: #{inspect(error)}")
          {:error, {:search_failed, error}}
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates the Nebulex backend configuration.
  """
  @impl true
  def validate_config(config) do
    required_fields = [:backend_type, :name, :cache_module]

    case check_required_fields(config, required_fields) do
      :ok ->
        if config.backend_type == :nebulex do
          validate_nebulex_specific_config(config)
        else
          {:error, {:invalid_backend_type, config.backend_type}}
        end

      error ->
        error
    end
  end

  @doc """
  Performs a health check on the Nebulex backend.
  """
  @impl true
  def health_check(config) do
    Logger.debug("NebulexBackend.health_check")

    with {:ok, cache_module} <- get_cache_module(config),
         :ok <- ensure_cache_started(cache_module) do

      try do
        # Test basic operations
        test_key = "health_check_#{System.unique_integer()}"
        test_value = "health_check_value"

        # Test put
        cache_module.put(test_key, test_value)

        # Test get
        case cache_module.get(test_key) do
          ^test_value ->
            # Test delete
            cache_module.delete(test_key)
            :ok

          other ->
            Logger.error("NebulexBackend: health check failed - got #{inspect(other)}, expected #{test_value}")
            {:error, :health_check_failed}
        end
      rescue
        error ->
          Logger.error("NebulexBackend: health check exception: #{inspect(error)}")
          {:error, {:health_check_exception, error}}
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets information about the Nebulex backend.
  """
  @impl true
  def get_backend_info(config) do
    case get_cache_module(config) do
      {:ok, cache_module} ->
        try do
          # Get cache statistics if available
          stats = case function_exported?(cache_module, :stats, 0) do
            true -> cache_module.stats()
            false -> %{}
          end

          info = %{
            backend_type: :nebulex,
            name: config.name,
            cache_module: cache_module,
            ttl_ms: get_ttl(config),
            supports_ttl: true,
            supports_search: true,
            supports_consolidation: true,
            supports_distribution: true,
            partitions: Map.get(config, :partitions, :unknown),
            replicas: Map.get(config, :replicas, :unknown),
            stats: stats
          }

          {:ok, info}
        rescue
          error ->
            Logger.error("NebulexBackend: failed to get backend info: #{inspect(error)}")
            {:error, {:backend_info_failed, error}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  ## Private Implementation

  @spec get_cache_module(map()) :: {:error, :missing_cache_module | {:invalid_cache_module, term()}} | {:ok, atom()}
  defp get_cache_module(config) do
    case Map.get(config, :cache_module) do
      nil ->
        {:error, :missing_cache_module}

      module when is_atom(module) ->
        {:ok, module}

      other ->
        {:error, {:invalid_cache_module, other}}
    end
  end

  @spec ensure_cache_started(atom()) :: :ok | {:error, {:cache_not_available, %{:__exception__ => true, :__struct__ => atom(), atom() => term()}}}
  defp ensure_cache_started(cache_module) do
    # Try a simple operation to check if cache is available
    cache_module.get("__health_check__")
    :ok
  rescue
    error ->
      Logger.error("NebulexBackend: cache #{cache_module} not available: #{inspect(error)}")
      {:error, {:cache_not_available, error}}
  end

  @spec build_storage_key(atom(), term()) :: String.t()
  defp build_storage_key(memory_type, key) do
    "#{memory_type}:#{key}"
  end

  @spec extract_original_key(String.t(), atom()) :: String.t()
  defp extract_original_key(storage_key, memory_type) do
    prefix = "#{memory_type}:"
    String.replace_prefix(storage_key, prefix, "")
  end

  @spec get_keys_by_pattern(module(), String.t()) :: [String.t()]
  defp get_keys_by_pattern(cache_module, pattern) do
    # Convert wildcard pattern to regex
    regex_pattern = pattern
    |> String.replace("*", ".*")
    |> then(&("^" <> &1 <> "$"))

    {:ok, regex} = Regex.compile(regex_pattern)

    # This is a simplified implementation
    # In a real implementation, you'd use Nebulex's streaming capabilities
    # or implement a more efficient key scanning mechanism
    try do
      # Get all keys (this is not efficient for large datasets)
      # In production, you'd want to implement proper key streaming
      all_keys = case function_exported?(cache_module, :all, 0) do
        true ->
          cache_module.all()
          |> Enum.map(fn {key, _value} -> key end)

        false ->
          # Fallback - this is not ideal for production
          []
      end

      Enum.filter(all_keys, fn key ->
        key_str = to_string(key)
        Regex.match?(regex, key_str)
      end)
    rescue
      _error ->
        # If we can't get all keys, return empty list
        []
    end
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

  @spec validate_nebulex_specific_config(map()) :: :ok | {:error, {:cache_module_not_loaded, atom()} | {:invalid_cache_module, term()} | {:invalid_partitions, term()} | {:invalid_replicas, term()} | {:invalid_ttl, term()}}
  defp validate_nebulex_specific_config(config) do
    with :ok <- validate_cache_module(config),
         :ok <- validate_ttl(config),
         :ok <- validate_partitions(config) do
      validate_replicas(config)
    end
  end

  @spec validate_cache_module(map()) :: :ok | {:error, {:cache_module_not_loaded, atom()} | {:invalid_cache_module, term()}}
  defp validate_cache_module(config) do
    case Map.get(config, :cache_module) do
      module when is_atom(module) ->
        if Code.ensure_loaded?(module) do
          :ok
        else
          {:error, {:cache_module_not_loaded, module}}
        end

      other ->
        {:error, {:invalid_cache_module, other}}
    end
  end

  @spec validate_ttl(map()) :: :ok | {:error, {:invalid_ttl, term()}}
  defp validate_ttl(config) do
    case Map.get(config, :ttl) do
      nil -> :ok
      ttl when is_integer(ttl) and ttl > 0 -> :ok
      ttl -> {:error, {:invalid_ttl, ttl}}
    end
  end

  @spec validate_partitions(map()) :: :ok | {:error, {:invalid_partitions, term()}}
  defp validate_partitions(config) do
    case Map.get(config, :partitions) do
      nil -> :ok
      partitions when is_integer(partitions) and partitions > 0 -> :ok
      partitions -> {:error, {:invalid_partitions, partitions}}
    end
  end

  @spec validate_replicas(map()) :: :ok | {:error, {:invalid_replicas, term()}}
  defp validate_replicas(config) do
    case Map.get(config, :replicas) do
      nil -> :ok
      replicas when is_integer(replicas) and replicas >= 0 -> :ok
      replicas -> {:error, {:invalid_replicas, replicas}}
    end
  end
end
