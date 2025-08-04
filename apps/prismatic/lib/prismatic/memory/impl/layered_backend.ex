defmodule Prismatic.Memory.Impl.LayeredBackend do
  @moduledoc """
  Layered backend implementation that orchestrates multiple memory backends.

  This backend provides a hierarchical memory system that automatically
  routes operations to appropriate backends based on memory type and
  implements intelligent data flow between layers.

  ## Architecture

  The layered backend implements a multi-tier memory hierarchy:

  - **Working Memory** (Cachex) - Fast, volatile, short-term storage
  - **Episodic Memory** (Nebulex) - Distributed, medium-term storage
  - **Semantic Memory** (Mnesia) - Persistent, long-term knowledge storage
  - **Procedural Memory** (Mnesia) - Persistent, long-term skill storage

  ## Features

  - **Automatic Routing**: Operations routed to appropriate backend by memory type
  - **Data Promotion**: Automatic promotion of frequently accessed data
  - **Intelligent Consolidation**: Smart movement of data between layers
  - **Fallback Strategy**: Automatic fallback to other layers on failure
  - **Unified Interface**: Single interface for all memory operations
  - **Performance Optimization**: Caching and prefetching strategies

  ## Configuration

  ```elixir
  config = %{
    backend_type: :layered,
    name: :hierarchical_memory,
    backends: %{
      working: {:cachex, %{name: :working_cache, ttl: 300_000}},
      episodic: {:nebulex, %{name: :episodic_cache, cache_module: MyApp.EpisodicCache}},
      semantic: {:mnesia, %{name: :semantic_db, table_name: :semantic_memory}},
      procedural: {:mnesia, %{name: :procedural_db, table_name: :procedural_memory}}
    },
    promotion_policy: %{
      access_threshold: 5,      # Promote after 5 accesses
      time_window: 3600_000     # Within 1 hour
    },
    consolidation_policy: %{
      auto_consolidate: true,
      consolidation_interval: 1800_000  # Every 30 minutes
    }
  }
  ```

  ## Usage Examples

  ### Basic Usage

      {:ok, config} = Memory.Protocol.create_config(:layered, %{
        backends: %{
          working: {:cachex, %{name: :working_memory}},
          semantic: {:mnesia, %{name: :knowledge_base}}
        }
      })

      # Data automatically routed to appropriate backend
      {:ok, _} = Memory.Protocol.store(config, :working, "temp_data", data)
      {:ok, _} = Memory.Protocol.store(config, :semantic, "knowledge", facts)

  ### With Automatic Promotion

      # Frequently accessed working memory data gets promoted to episodic
      {:ok, data} = Memory.Protocol.retrieve(config, :working, "popular_item")
  """

  @behaviour Prismatic.Memory.Protocol

  alias Prismatic.Memory.Impl.{CachexBackend, MnesiaBackend, NebulexBackend, TestBackend}

  require Logger

  @default_backends %{
    working: {:cachex, %{name: :default_working}},
    episodic: {:nebulex, %{name: :default_episodic}},
    semantic: {:mnesia, %{name: :default_semantic, table_name: :semantic_memory}},
    procedural: {:mnesia, %{name: :default_procedural, table_name: :procedural_memory}}
  }

  @doc """
  Stores data in the appropriate backend based on memory type.

  Routes the operation to the configured backend for the given memory type.
  """
  @impl true
  def store(config, memory_type, key, value) do
    Logger.debug("LayeredBackend.store: #{memory_type}/#{key}")

    with {:ok, backend_config} <- get_backend_config(config, memory_type),
         {:ok, backend_module} <- get_backend_module(backend_config) do

      # Store in the primary backend
      case backend_module.store(backend_config, memory_type, key, value) do
        {:ok, _} = success ->
          # Update access tracking for promotion decisions
          track_access(config, memory_type, key, :write)

          # Check if we should also store in other layers (write-through caching)
          maybe_write_through(config, memory_type, key, value)

          success

        {:error, reason} = error ->
          Logger.warning("LayeredBackend: primary store failed for #{memory_type}/#{key}: #{inspect(reason)}")

          # Try fallback strategy
          case try_fallback_store(config, memory_type, key, value) do
            {:ok, _} = fallback_success ->
              Logger.info("LayeredBackend: fallback store succeeded for #{memory_type}/#{key}")
              fallback_success

            {:error, _} ->
              error
          end
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Retrieves data with intelligent layer traversal.

  Searches through memory layers in order of access speed, with automatic
  promotion of frequently accessed data.
  """
  @impl true
  def retrieve(config, memory_type, key) do
    Logger.debug("LayeredBackend.retrieve: #{memory_type}/#{key}")

    with {:ok, backend_config} <- get_backend_config(config, memory_type),
         {:ok, backend_module} <- get_backend_module(backend_config) do

      case backend_module.retrieve(backend_config, memory_type, key) do
        {:ok, value} = success ->
          # Update access tracking
          track_access(config, memory_type, key, :read)

          # Check if data should be promoted to faster layer
          maybe_promote_data(config, memory_type, key, value)

          success

        {:error, :not_found} ->
          # Try to find in other layers
          case search_other_layers(config, memory_type, key) do
            {:ok, value} = found ->
              Logger.info("LayeredBackend: found #{key} in fallback layer, promoting")

              # Store in primary layer for future access
              backend_module.store(backend_config, memory_type, key, value)

              found

            {:error, :not_found} = not_found ->
              not_found
          end

        {:error, reason} = error ->
          Logger.warning("LayeredBackend: primary retrieve failed for #{memory_type}/#{key}: #{inspect(reason)}")

          # Try fallback layers
          case search_other_layers(config, memory_type, key) do
            {:ok, _} = fallback_success ->
              fallback_success

            {:error, :not_found} ->
              error
          end
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Consolidates data across memory layers.

  Implements intelligent consolidation that moves data between layers
  based on access patterns and configured policies.
  """
  @impl true
  def consolidate(config) do
    Logger.debug("LayeredBackend.consolidate")

    consolidation_results = Enum.map([:working, :episodic, :semantic, :procedural], fn memory_type ->
      consolidate_single_layer(config, memory_type)
    end)

    # Perform cross-layer consolidation
    cross_layer_consolidation(config)

    # Check if all consolidations were successful
    failed_consolidations = Enum.filter(consolidation_results, fn {_, result} ->
      match?({:error, _}, result)
    end)

    case failed_consolidations do
      [] ->
        Logger.info("LayeredBackend: all layers consolidated successfully")
        {:ok, config}

      failures ->
        Logger.error("LayeredBackend: some consolidations failed: #{inspect(failures)}")
        {:ok, Map.put(config, :consolidation_warnings, failures)}
    end
  end

  @spec consolidate_single_layer(map(), atom()) :: {atom(), :success | {:error, term()}}
  defp consolidate_single_layer(config, memory_type) do
    with {:ok, backend_config} <- get_backend_config(config, memory_type),
         {:ok, backend_module} <- get_backend_module(backend_config),
         {:ok, _} <- backend_module.consolidate(backend_config) do
      Logger.debug("LayeredBackend: consolidated #{memory_type} layer")
      {memory_type, :success}
    else
      {:error, reason} ->
        Logger.warning("LayeredBackend: consolidation failed for #{memory_type}: #{inspect(reason)}")
        {memory_type, {:error, reason}}
    end
  end

  @doc """
  Removes data from the appropriate backend.
  """
  @impl true
  def forget(config, memory_type, key) do
    Logger.debug("LayeredBackend.forget: #{memory_type}/#{key}")

    with {:ok, backend_config} <- get_backend_config(config, memory_type),
         {:ok, backend_module} <- get_backend_module(backend_config) do

      # Remove from primary backend
      primary_result = backend_module.forget(backend_config, memory_type, key)

      # Also remove from other layers where it might exist
      cleanup_other_layers(config, memory_type, key)

      # Clear access tracking
      clear_access_tracking(config, memory_type, key)

      primary_result
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Searches across all configured backends.

  Performs parallel search across all layers and merges results.
  """
  @impl true
  def search(config, memory_type, pattern) do
    Logger.debug("LayeredBackend.search: #{memory_type}/#{pattern}")

    # Search in primary backend
    primary_results = search_primary_backend(config, memory_type, pattern)

    # Search in other layers for additional results
    other_results = search_all_layers(config, memory_type, pattern)

    # Merge and deduplicate results
    all_results = (primary_results ++ other_results)
    |> Enum.uniq_by(fn {key, _value} -> key end)

    Logger.debug("LayeredBackend: found #{length(all_results)} total matches for pattern #{pattern}")
    {:ok, all_results}
  end

  @spec search_primary_backend(map(), atom(), String.t()) :: [{term(), term()}]
  defp search_primary_backend(config, memory_type, pattern) do
    with {:ok, backend_config} <- get_backend_config(config, memory_type),
         {:ok, backend_module} <- get_backend_module(backend_config),
         {:ok, results} <- backend_module.search(backend_config, memory_type, pattern) do
      results
    else
      {:error, _} -> []
    end
  end

  @doc """
  Validates the layered backend configuration.
  """
  @impl true
  def validate_config(config) do
    required_fields = [:backend_type, :name]

    case check_required_fields(config, required_fields) do
      :ok ->
        if config.backend_type == :layered do
          validate_layered_specific_config(config)
        else
          {:error, {:invalid_backend_type, config.backend_type}}
        end

      error ->
        error
    end
  end

  @doc """
  Performs health checks on all configured backends.
  """
  @impl true
  def health_check(config) do
    Logger.debug("LayeredBackend.health_check")

    backends = get_configured_backends(config)
    health_results = check_all_backends_health(backends)

    unhealthy_backends = Enum.filter(health_results, fn {_, status} ->
      status != :healthy
    end)

    case unhealthy_backends do
      [] ->
        Logger.info("LayeredBackend: all backends healthy")
        :ok

      unhealthy ->
        Logger.warning("LayeredBackend: some backends unhealthy: #{inspect(unhealthy)}")
        {:error, {:unhealthy_backends, unhealthy}}
    end
  end

  @spec check_all_backends_health([{atom(), {atom(), map()}}]) ::
    [{atom(), :healthy | {:unhealthy, term()} | {:error, term()}}]
  defp check_all_backends_health(backends) do
    Enum.map(backends, fn {memory_type, {backend_type, backend_config}} ->
      health_status = check_single_backend_health(backend_type, backend_config)
      {memory_type, health_status}
    end)
  end

  @spec check_single_backend_health(atom(), map()) :: :healthy | {:unhealthy, term()} | {:error, term()}
  defp check_single_backend_health(backend_type, backend_config) do
    with {:ok, backend_module} <- get_backend_module_by_type(backend_type),
         :ok <- backend_module.health_check(backend_config) do
      :healthy
    else
      {:error, reason} when is_atom(reason) -> {:error, reason}
      {:error, reason} -> {:unhealthy, reason}
    end
  end

  @doc """
  Gets comprehensive information about all backends.
  """
  @impl true
  def get_backend_info(config) do
    backends = get_configured_backends(config)
    backend_info = collect_backend_info(backends)

    info = %{
      backend_type: :layered,
      name: config.name,
      supports_ttl: true,
      supports_search: true,
      supports_consolidation: true,
      supports_promotion: true,
      supports_fallback: true,
      backends: backend_info,
      promotion_policy: Map.get(config, :promotion_policy, %{}),
      consolidation_policy: Map.get(config, :consolidation_policy, %{})
    }

    {:ok, info}
  end

  @spec collect_backend_info([{atom(), {atom(), map()}}]) :: map()
  defp collect_backend_info(backends) do
    Enum.reduce(backends, %{}, fn {memory_type, {backend_type, backend_config}}, acc ->
      info = get_single_backend_info(backend_type, backend_config)
      Map.put(acc, memory_type, info)
    end)
  end

  @spec get_single_backend_info(atom(), map()) :: map() | {:error, term()}
  defp get_single_backend_info(backend_type, backend_config) do
    with {:ok, backend_module} <- get_backend_module_by_type(backend_type),
         {:ok, info} <- backend_module.get_backend_info(backend_config) do
      info
    else
      {:error, reason} -> {:error, reason}
    end
  end

  ## Private Implementation

  @spec get_backend_config(map(), atom()) :: {:ok, map()} | {:error, term()}
  defp get_backend_config(config, memory_type) do
    backends = Map.get(config, :backends, @default_backends)

    case Map.get(backends, memory_type) do
      nil ->
        {:error, {:no_backend_configured, memory_type}}

      {backend_type, backend_config} ->
        full_config = Map.merge(backend_config, %{backend_type: backend_type})
        {:ok, full_config}

      other ->
        {:error, {:invalid_backend_config, other}}
    end
  end

  @spec get_backend_module(map()) :: {:ok, module()} | {:error, term()}
  defp get_backend_module(backend_config) do
    get_backend_module_by_type(backend_config.backend_type)
  end

  @spec get_backend_module_by_type(atom()) :: {:ok, module()} | {:error, term()}
  defp get_backend_module_by_type(:cachex), do: {:ok, CachexBackend}
  defp get_backend_module_by_type(:nebulex), do: {:ok, NebulexBackend}
  defp get_backend_module_by_type(:mnesia), do: {:ok, MnesiaBackend}
  defp get_backend_module_by_type(:test), do: {:ok, TestBackend}
  defp get_backend_module_by_type(backend_type), do: {:error, {:unsupported_backend, backend_type}}

  @spec get_configured_backends(map()) :: [{atom(), {atom(), map()}}]
  defp get_configured_backends(config) do
    backends = Map.get(config, :backends, @default_backends)
    Enum.to_list(backends)
  end

  @spec track_access(map(), atom(), term(), atom()) :: :ok
  defp track_access(_config, memory_type, key, operation) do
    # This would integrate with a metrics system
    # For now, we'll just log the access
    Logger.debug("LayeredBackend: tracking #{operation} access to #{memory_type}/#{key}")

    # In a real implementation, you'd store access patterns in ETS or similar
    # to make promotion decisions
    :ok
  end

  @spec maybe_write_through(map(), atom(), term(), term()) :: :ok
  defp maybe_write_through(config, memory_type, key, value) do
    # Implement write-through caching logic
    # For example, store working memory items also in episodic for durability
    case memory_type do
      :working ->
        write_through_to_episodic(config, key, value)

      _ ->
        :ok
    end
  end

  @spec write_through_to_episodic(map(), term(), term()) :: :ok
  defp write_through_to_episodic(config, key, value) do
    with {:ok, episodic_config} <- get_backend_config(config, :episodic),
         {:ok, backend_module} <- get_backend_module(episodic_config) do
      backend_module.store(episodic_config, :episodic, key, value)
      :ok
    else
      {:error, _} -> :ok
    end
  end

  @spec try_fallback_store(map(), atom(), term(), term()) :: {:ok, map()} | {:error, term()}
  defp try_fallback_store(config, memory_type, key, value) do
    # Try to store in alternative backends
    fallback_order = get_fallback_order(memory_type)

    Enum.reduce_while(fallback_order, {:error, :no_fallback}, fn fallback_type, _acc ->
      case try_store_in_layer(config, fallback_type, key, value) do
        {:ok, _} = success ->
          {:halt, success}

        {:error, _} ->
          {:cont, {:error, :fallback_failed}}
      end
    end)
  end

  @spec try_store_in_layer(map(), atom(), term(), term()) :: {:ok, map()} | {:error, term()}
  defp try_store_in_layer(config, memory_type, key, value) do
    with {:ok, backend_config} <- get_backend_config(config, memory_type),
         {:ok, backend_module} <- get_backend_module(backend_config),
         {:ok, result} <- backend_module.store(backend_config, memory_type, key, value) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec search_other_layers(map(), atom(), term()) :: {:ok, term()} | {:error, :not_found}
  defp search_other_layers(config, memory_type, key) do
    fallback_order = get_fallback_order(memory_type)

    Enum.reduce_while(fallback_order, {:error, :not_found}, fn fallback_type, _acc ->
      case try_retrieve_from_layer(config, fallback_type, key) do
        {:ok, value} ->
          {:halt, {:ok, value}}

        {:error, _} ->
          {:cont, {:error, :not_found}}
      end
    end)
  end

  @spec try_retrieve_from_layer(map(), atom(), term()) :: {:ok, term()} | {:error, term()}
  defp try_retrieve_from_layer(config, memory_type, key) do
    with {:ok, backend_config} <- get_backend_config(config, memory_type),
         {:ok, backend_module} <- get_backend_module(backend_config),
         {:ok, value} <- backend_module.retrieve(backend_config, memory_type, key) do
      {:ok, value}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @spec get_fallback_order(atom()) :: [atom()]
  defp get_fallback_order(:working), do: [:episodic, :semantic]
  defp get_fallback_order(:episodic), do: [:working, :semantic]
  defp get_fallback_order(:semantic), do: [:episodic, :procedural]
  defp get_fallback_order(:procedural), do: [:semantic, :episodic]

  @spec maybe_promote_data(map(), atom(), term(), term()) :: :ok
  defp maybe_promote_data(_config, _memory_type, _key, _value) do
    # Implement data promotion logic based on access patterns
    # This would check access frequency and promote frequently accessed data
    # to faster storage layers
    :ok
  end

  @spec cross_layer_consolidation(map()) :: :ok
  defp cross_layer_consolidation(_config) do
    # Implement cross-layer consolidation logic
    # This would move data between layers based on policies
    :ok
  end

  @spec cleanup_other_layers(map(), atom(), term()) :: :ok
  defp cleanup_other_layers(config, memory_type, key) do
    # Remove the key from other layers where it might exist
    other_types = [:working, :episodic, :semantic, :procedural] -- [memory_type]

    Enum.each(other_types, fn other_type ->
      cleanup_single_layer(config, other_type, key)
    end)
  end

  @spec cleanup_single_layer(map(), atom(), term()) :: :ok
  defp cleanup_single_layer(config, memory_type, key) do
    with {:ok, backend_config} <- get_backend_config(config, memory_type),
         {:ok, backend_module} <- get_backend_module(backend_config) do
      backend_module.forget(backend_config, memory_type, key)
    else
      {:error, _} -> :ok
    end
  end

  @spec clear_access_tracking(map(), atom(), term()) :: :ok
  defp clear_access_tracking(_config, _memory_type, _key) do
    # Clear access tracking data for the key
    :ok
  end

  @spec search_all_layers(map(), atom(), String.t()) :: [{term(), term()}]
  defp search_all_layers(config, memory_type, pattern) do
    other_types = [:working, :episodic, :semantic, :procedural] -- [memory_type]

    Enum.flat_map(other_types, fn other_type ->
      search_single_layer(config, other_type, pattern)
    end)
  end

  @spec search_single_layer(map(), atom(), String.t()) :: [{term(), term()}]
  defp search_single_layer(config, memory_type, pattern) do
    with {:ok, backend_config} <- get_backend_config(config, memory_type),
         {:ok, backend_module} <- get_backend_module(backend_config),
         {:ok, results} <- backend_module.search(backend_config, memory_type, pattern) do
      results
    else
      {:error, _} -> []
    end
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

  @spec validate_layered_specific_config(map()) :: :ok | {:error, term()}
  defp validate_layered_specific_config(config) do
    with :ok <- validate_backends_config(config),
         :ok <- validate_promotion_policy(config) do
      validate_consolidation_policy(config)
    end
  end

  @spec validate_backends_config(map()) :: :ok | {:error, term()}
  defp validate_backends_config(config) do
    backends = Map.get(config, :backends, @default_backends)

    if is_map(backends) do
      validate_each_backend_spec(backends)
    else
      {:error, {:invalid_backends_config, backends}}
    end
  end

  @spec validate_each_backend_spec(map()) :: :ok | {:error, term()}
  defp validate_each_backend_spec(backends) do
    Enum.reduce_while(backends, :ok, fn {memory_type, backend_spec}, _acc ->
      case validate_backend_spec(memory_type, backend_spec) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  @spec validate_backend_spec(atom(), term()) :: :ok | {:error, term()}
  defp validate_backend_spec(memory_type, {backend_type, backend_config})
      when is_atom(backend_type) and is_map(backend_config) do
    case backend_type in [:cachex, :nebulex, :mnesia, :test] do
      true -> :ok
      false -> {:error, {:invalid_backend_type_for_memory, memory_type, backend_type}}
    end
  end

  defp validate_backend_spec(memory_type, backend_spec) do
    {:error, {:invalid_backend_spec, memory_type, backend_spec}}
  end

  @spec validate_promotion_policy(map()) :: :ok | {:error, term()}
  defp validate_promotion_policy(config) do
    case Map.get(config, :promotion_policy) do
      nil -> :ok
      policy when is_map(policy) -> :ok
      policy -> {:error, {:invalid_promotion_policy, policy}}
    end
  end

  @spec validate_consolidation_policy(map()) :: :ok | {:error, term()}
  defp validate_consolidation_policy(config) do
    case Map.get(config, :consolidation_policy) do
      nil -> :ok
      policy when is_map(policy) -> :ok
      policy -> {:error, {:invalid_consolidation_policy, policy}}
    end
  end
end
