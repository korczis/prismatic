defmodule Prismatic.Blackboard.Impl.MemoryBackend do
  @moduledoc """
  Memory backend implementation for the Prismatic Blackboard System.

  This backend uses the existing Prismatic Memory system for persistent
  storage of knowledge objects. It provides full blackboard functionality
  with data persistence across system restarts.

  ## Features

  - **Persistent Storage**: Uses Memory system for durable storage
  - **Memory Type Integration**: Leverages semantic memory for knowledge storage
  - **Full Protocol Support**: Implements all blackboard protocol operations
  - **Performance Optimized**: Efficient storage and retrieval patterns
  - **Memory System Integration**: Seamless integration with existing memory backends

  ## Configuration

  The memory backend accepts these configuration options:

      %{
        backend_type: :memory,
        name: :memory_blackboard,
        memory_backend: :layered,  # Memory system backend to use
        timeout: 30_000,
        max_retries: 3,
        max_knowledge_objects: 100_000,
        enable_indexing: true,
        enable_search_cache: true
      }

  ## Memory Integration

  The backend uses the Memory system's semantic memory type for storage:

  - **Knowledge Objects**: Stored as serialized maps in semantic memory
  - **Indexing**: Uses content-based keys for efficient retrieval
  - **Search**: Leverages memory system's pattern matching capabilities
  - **Consolidation**: Integrates with memory consolidation processes

  ## Usage

  Used for production deployments requiring persistence:

      {:ok, config} = Protocol.create_config(:memory, %{
        memory_backend: :layered,
        max_knowledge_objects: 50_000
      })

      {:ok, knowledge_id} = Protocol.post(config, %{
        category: :facts,
        content: %{fact: "persistent data"}
      })
  """

  @behaviour Prismatic.Blackboard.Protocol

  require Logger

  alias Prismatic.Blackboard.{Protocol, KnowledgeObject, AccessControl}
  alias Prismatic.Memory.Protocol, as: MemoryProtocol

  @type memory_config :: MemoryProtocol.config()

  ## Protocol Implementation

  @impl Protocol
  def post(config, knowledge, context \\ %{}) do
    with {:ok, knowledge_obj} <- normalize_knowledge(knowledge),
         {:ok, memory_config} <- get_memory_config(config),
         :ok <- check_capacity_limits(config, memory_config),
         {:ok, secured_obj} <- apply_access_control(knowledge_obj, context, config),
         {:ok, stored_obj} <- store_knowledge_object(secured_obj, memory_config) do

      # Update indexes for efficient querying
      update_indexes(stored_obj, memory_config)

      emit_telemetry([:post], %{
        knowledge_id: stored_obj.id,
        category: stored_obj.category,
        success: true
      })

      {:ok, stored_obj.id}
    else
      {:error, reason} ->
        emit_telemetry([:post], %{success: false, error: reason})
        {:error, reason}
    end
  end

  @impl Protocol
  def read(config, knowledge_id, context \\ %{}) do
    with {:ok, memory_config} <- get_memory_config(config),
         {:ok, knowledge_obj} <- retrieve_knowledge_object(knowledge_id, memory_config),
         :ok <- check_access_permissions(context, :read, knowledge_obj, config) do

      emit_telemetry([:read], %{
        knowledge_id: knowledge_id,
        success: true
      })

      {:ok, knowledge_obj}
    else
      {:error, reason} ->
        emit_telemetry([:read], %{
          knowledge_id: knowledge_id,
          success: false,
          error: reason
        })
        {:error, reason}
    end
  end

  @impl Protocol
  def update(config, knowledge_id, updates, context \\ %{}) do
    with {:ok, memory_config} <- get_memory_config(config),
         {:ok, current_obj} <- retrieve_knowledge_object(knowledge_id, memory_config),
         :ok <- check_access_permissions(context, :write, current_obj, config),
         {:ok, updated_obj} <- KnowledgeObject.update(current_obj, updates),
         {:ok, stored_obj} <- store_knowledge_object(updated_obj, memory_config) do

      # Update indexes
      update_indexes(stored_obj, memory_config)

      emit_telemetry([:update], %{
        knowledge_id: knowledge_id,
        success: true
      })

      {:ok, stored_obj}
    else
      {:error, reason} ->
        emit_telemetry([:update], %{
          knowledge_id: knowledge_id,
          success: false,
          error: reason
        })
        {:error, reason}
    end
  end

  @impl Protocol
  def remove(config, knowledge_id, context \\ %{}) do
    with {:ok, memory_config} <- get_memory_config(config),
         {:ok, knowledge_obj} <- retrieve_knowledge_object(knowledge_id, memory_config),
         :ok <- check_access_permissions(context, :write, knowledge_obj, config),
         :ok <- delete_knowledge_object(knowledge_id, memory_config) do

      # Remove from indexes
      remove_from_indexes(knowledge_obj, memory_config)

      emit_telemetry([:remove], %{
        knowledge_id: knowledge_id,
        success: true
      })

      :ok
    else
      {:error, reason} ->
        emit_telemetry([:remove], %{
          knowledge_id: knowledge_id,
          success: false,
          error: reason
        })
        {:error, reason}
    end
  end

  @impl Protocol
  def query(config, pattern, context \\ %{}) do
    with {:ok, memory_config} <- get_memory_config(config),
         {:ok, candidate_objects} <- find_candidate_objects(pattern, memory_config),
         {:ok, matched_objects} <- filter_by_pattern(candidate_objects, pattern),
         {:ok, accessible_objects} <- filter_by_access(matched_objects, context, config) do

      # Apply query options (limit, order)
      final_results = apply_query_options(accessible_objects, pattern)

      emit_telemetry([:query], %{
        result_count: length(final_results),
        success: true
      })

      {:ok, final_results}
    else
      {:error, reason} ->
        emit_telemetry([:query], %{success: false, error: reason})
        {:error, reason}
    end
  end

  @impl Protocol
  def subscribe(config, pattern, handler, context \\ %{}) do
    # Memory backend doesn't directly support subscriptions
    # This would typically be handled by the Manager layer
    # For now, return a simple subscription ID
    subscription_id = generate_subscription_id()

    Logger.debug("Memory backend subscription created", %{
      subscription_id: subscription_id,
      pattern: inspect(pattern)
    })

    {:ok, subscription_id}
  end

  @impl Protocol
  def unsubscribe(config, subscription_id) do
    Logger.debug("Memory backend subscription removed", %{
      subscription_id: subscription_id
    })

    :ok
  end

  @impl Protocol
  def add_rule(config, rule, context \\ %{}) do
    # Memory backend doesn't directly support rules
    # This would typically be handled by the Manager layer
    rule_id = generate_rule_id()

    Logger.debug("Memory backend rule added", %{rule_id: rule_id})
    {:ok, rule_id}
  end

  @impl Protocol
  def remove_rule(config, rule_id, context \\ %{}) do
    Logger.debug("Memory backend rule removed", %{rule_id: rule_id})
    :ok
  end

  @impl Protocol
  def validate_config(config) do
    required_fields = [:backend_type, :name, :memory_backend]

    with :ok <- check_required_fields(config, required_fields),
         :ok <- validate_memory_backend(config.memory_backend) do
      :ok
    end
  end

  @impl Protocol
  def health_check(config) do
    with {:ok, memory_config} <- get_memory_config(config),
         :ok <- MemoryProtocol.health_check(memory_config) do
      # Test basic operations
      test_knowledge = %{
        id: "health_check_#{System.unique_integer()}",
        category: :facts,
        content: %{test: "health_check"},
        metadata: %{},
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      with {:ok, _} <- store_knowledge_object(test_knowledge, memory_config),
           {:ok, _} <- retrieve_knowledge_object(test_knowledge.id, memory_config),
           :ok <- delete_knowledge_object(test_knowledge.id, memory_config) do
        :ok
      else
        {:error, reason} ->
          {:error, {:health_check_failed, reason}}
      end
    else
      {:error, reason} ->
        {:error, {:memory_backend_unhealthy, reason}}
    end
  end

  @impl Protocol
  def get_backend_info(config) do
    with {:ok, memory_config} <- get_memory_config(config),
         {:ok, memory_info} <- MemoryProtocol.get_backend_info(memory_config) do

      # Get knowledge count from indexes
      knowledge_count = get_knowledge_count(memory_config)

      info = %{
        backend_type: :memory,
        name: config.name,
        supports_persistence: true,
        supports_events: false,  # Handled by Manager layer
        supports_rules: false,   # Handled by Manager layer
        supports_access_control: true,
        max_knowledge_objects: Map.get(config, :max_knowledge_objects, :unlimited),
        current_knowledge_objects: knowledge_count,
        memory_backend_info: memory_info,
        features: [:persistence, :indexing, :pattern_matching, :access_control]
      }

      {:ok, info}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  ## Private Implementation

  @spec get_memory_config(Protocol.config()) :: {:ok, memory_config()} | {:error, term()}
  defp get_memory_config(config) do
    memory_backend = Map.get(config, :memory_backend, :layered)

    case MemoryProtocol.create_config(memory_backend, %{
      name: :"#{config.name}_memory",
      timeout: Map.get(config, :timeout, 30_000),
      max_retries: Map.get(config, :max_retries, 3)
    }) do
      {:ok, memory_config} -> {:ok, memory_config}
      {:error, reason} -> {:error, {:memory_config_error, reason}}
    end
  end

  @spec normalize_knowledge(KnowledgeObject.t() | map()) :: {:ok, KnowledgeObject.t()} | {:error, term()}
  defp normalize_knowledge(%KnowledgeObject{} = knowledge_obj), do: {:ok, knowledge_obj}
  defp normalize_knowledge(knowledge) when is_map(knowledge) do
    KnowledgeObject.new(knowledge)
  end
  defp normalize_knowledge(knowledge), do: {:error, {:invalid_knowledge, knowledge}}

  @spec apply_access_control(KnowledgeObject.t(), AccessControl.access_context(), Protocol.config()) ::
    {:ok, KnowledgeObject.t()} | {:error, term()}
  defp apply_access_control(knowledge_obj, context, config) do
    if Map.get(config, :enable_access_control, true) and map_size(context) > 0 do
      AccessControl.secure_knowledge_object(knowledge_obj, context)
    else
      {:ok, knowledge_obj}
    end
  end

  @spec check_capacity_limits(Protocol.config(), memory_config()) :: :ok | {:error, term()}
  defp check_capacity_limits(config, memory_config) do
    case Map.get(config, :max_knowledge_objects) do
      nil -> :ok
      max_objects when is_integer(max_objects) ->
        current_count = get_knowledge_count(memory_config)
        if current_count >= max_objects do
          {:error, :storage_full}
        else
          :ok
        end
      _ -> :ok
    end
  end

  @spec store_knowledge_object(KnowledgeObject.t(), memory_config()) :: {:ok, KnowledgeObject.t()} | {:error, term()}
  defp store_knowledge_object(knowledge_obj, memory_config) do
    knowledge_map = KnowledgeObject.to_map(knowledge_obj)
    storage_key = knowledge_storage_key(knowledge_obj.id)

    case MemoryProtocol.store(memory_config, :semantic, storage_key, knowledge_map) do
      {:ok, _} -> {:ok, knowledge_obj}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec retrieve_knowledge_object(Protocol.knowledge_id(), memory_config()) :: {:ok, KnowledgeObject.t()} | {:error, term()}
  defp retrieve_knowledge_object(knowledge_id, memory_config) do
    storage_key = knowledge_storage_key(knowledge_id)

    case MemoryProtocol.retrieve(memory_config, :semantic, storage_key) do
      {:ok, knowledge_map} ->
        KnowledgeObject.from_map(knowledge_map)

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec delete_knowledge_object(Protocol.knowledge_id(), memory_config()) :: :ok | {:error, term()}
  defp delete_knowledge_object(knowledge_id, memory_config) do
    storage_key = knowledge_storage_key(knowledge_id)

    case MemoryProtocol.forget(memory_config, :semantic, storage_key) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec check_access_permissions(AccessControl.access_context(), AccessControl.permission(), KnowledgeObject.t(), Protocol.config()) ::
    :ok | {:error, term()}
  defp check_access_permissions(context, operation, knowledge_obj, config) do
    if Map.get(config, :enable_access_control, true) and map_size(context) > 0 do
      AccessControl.authorize(context, operation, knowledge_obj)
    else
      :ok
    end
  end

  @spec find_candidate_objects(map(), memory_config()) :: {:ok, [KnowledgeObject.t()]} | {:error, term()}
  defp find_candidate_objects(pattern, memory_config) do
    # Use category-based indexing if available
    case Map.get(pattern, :category) do
      nil ->
        # No category filter, search all knowledge objects
        search_all_knowledge_objects(memory_config)

      category ->
        # Search by category index
        search_by_category(category, memory_config)
    end
  end

  @spec search_all_knowledge_objects(memory_config()) :: {:ok, [KnowledgeObject.t()]} | {:error, term()}
  defp search_all_knowledge_objects(memory_config) do
    pattern = knowledge_storage_key("*")

    case MemoryProtocol.search(memory_config, :semantic, pattern) do
      {:ok, results} ->
        knowledge_objects = results
        |> Enum.map(fn {_key, knowledge_map} ->
          case KnowledgeObject.from_map(knowledge_map) do
            {:ok, obj} -> obj
            {:error, _} -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

        {:ok, knowledge_objects}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec search_by_category(KnowledgeObject.category(), memory_config()) :: {:ok, [KnowledgeObject.t()]} | {:error, term()}
  defp search_by_category(category, memory_config) do
    # Use category index for efficient lookup
    index_key = category_index_key(category)

    case MemoryProtocol.retrieve(memory_config, :semantic, index_key) do
      {:ok, knowledge_ids} when is_list(knowledge_ids) ->
        # Retrieve all knowledge objects for this category
        objects = Enum.map(knowledge_ids, fn knowledge_id ->
          case retrieve_knowledge_object(knowledge_id, memory_config) do
            {:ok, obj} -> obj
            {:error, _} -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)

        {:ok, objects}

      {:error, :not_found} ->
        {:ok, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec filter_by_pattern([KnowledgeObject.t()], map()) :: {:ok, [KnowledgeObject.t()]} | {:error, term()}
  defp filter_by_pattern(objects, pattern) do
    matched_objects = Enum.filter(objects, fn obj ->
      match_pattern?(obj, pattern)
    end)

    {:ok, matched_objects}
  end

  @spec filter_by_access([KnowledgeObject.t()], AccessControl.access_context(), Protocol.config()) :: {:ok, [KnowledgeObject.t()]} | {:error, term()}
  defp filter_by_access(objects, context, config) do
    if Map.get(config, :enable_access_control, true) and map_size(context) > 0 do
      accessible_objects = Enum.filter(objects, fn obj ->
        AccessControl.authorize(context, :read, obj) == :ok
      end)

      {:ok, accessible_objects}
    else
      {:ok, objects}
    end
  end

  @spec apply_query_options([KnowledgeObject.t()], map()) :: [KnowledgeObject.t()]
  defp apply_query_options(objects, pattern) do
    objects
    |> maybe_sort(Map.get(pattern, :order, :desc))
    |> maybe_limit(Map.get(pattern, :limit))
  end

  @spec maybe_sort([KnowledgeObject.t()], :asc | :desc) :: [KnowledgeObject.t()]
  defp maybe_sort(objects, :asc) do
    Enum.sort_by(objects, & &1.created_at, DateTime)
  end
  defp maybe_sort(objects, :desc) do
    Enum.sort_by(objects, & &1.created_at, {:desc, DateTime})
  end

  @spec maybe_limit([KnowledgeObject.t()], pos_integer() | nil) :: [KnowledgeObject.t()]
  defp maybe_limit(objects, nil), do: objects
  defp maybe_limit(objects, limit) when is_integer(limit) and limit > 0 do
    Enum.take(objects, limit)
  end
  defp maybe_limit(objects, _), do: objects

  @spec match_pattern?(KnowledgeObject.t(), map()) :: boolean()
  defp match_pattern?(knowledge_obj, pattern) do
    Enum.all?(pattern, fn
      {:category, category} -> knowledge_obj.category == category
      {:pattern, content_pattern} when is_map(content_pattern) ->
        match_content_pattern?(knowledge_obj.content, content_pattern)
      {:metadata, metadata_pattern} when is_map(metadata_pattern) ->
        match_metadata_pattern?(knowledge_obj.metadata, metadata_pattern)
      {:limit, _} -> true  # Skip query options
      {:order, _} -> true  # Skip query options
      _ -> true
    end)
  end

  @spec match_content_pattern?(map(), map()) :: boolean()
  defp match_content_pattern?(content, pattern) when is_map(content) and is_map(pattern) do
    Enum.all?(pattern, fn {key, value} ->
      Map.get(content, key) == value
    end)
  end
  defp match_content_pattern?(_, _), do: false

  @spec match_metadata_pattern?(map() | nil, map()) :: boolean()
  defp match_metadata_pattern?(metadata, pattern) when is_map(metadata) and is_map(pattern) do
    Enum.all?(pattern, fn {key, value} ->
      Map.get(metadata, key) == value
    end)
  end
  defp match_metadata_pattern?(_, _), do: false

  @spec update_indexes(KnowledgeObject.t(), memory_config()) :: :ok
  defp update_indexes(knowledge_obj, memory_config) do
    # Update category index
    update_category_index(knowledge_obj, memory_config)

    # Update other indexes as needed
    update_content_indexes(knowledge_obj, memory_config)

    :ok
  end

  @spec remove_from_indexes(KnowledgeObject.t(), memory_config()) :: :ok
  defp remove_from_indexes(knowledge_obj, memory_config) do
    # Remove from category index
    remove_from_category_index(knowledge_obj, memory_config)

    # Remove from other indexes as needed
    remove_from_content_indexes(knowledge_obj, memory_config)

    :ok
  end

  @spec update_category_index(KnowledgeObject.t(), memory_config()) :: :ok
  defp update_category_index(knowledge_obj, memory_config) do
    index_key = category_index_key(knowledge_obj.category)

    case MemoryProtocol.retrieve(memory_config, :semantic, index_key) do
      {:ok, existing_ids} when is_list(existing_ids) ->
        updated_ids = [knowledge_obj.id | existing_ids -- [knowledge_obj.id]]
        MemoryProtocol.store(memory_config, :semantic, index_key, updated_ids)

      {:error, :not_found} ->
        MemoryProtocol.store(memory_config, :semantic, index_key, [knowledge_obj.id])

      _ ->
        :ok
    end

    :ok
  end

  @spec remove_from_category_index(KnowledgeObject.t(), memory_config()) :: :ok
  defp remove_from_category_index(knowledge_obj, memory_config) do
    index_key = category_index_key(knowledge_obj.category)

    case MemoryProtocol.retrieve(memory_config, :semantic, index_key) do
      {:ok, existing_ids} when is_list(existing_ids) ->
        updated_ids = existing_ids -- [knowledge_obj.id]
        if Enum.empty?(updated_ids) do
          MemoryProtocol.forget(memory_config, :semantic, index_key)
        else
          MemoryProtocol.store(memory_config, :semantic, index_key, updated_ids)
        end

      _ ->
        :ok
    end

    :ok
  end

  @spec update_content_indexes(KnowledgeObject.t(), memory_config()) :: :ok
  defp update_content_indexes(_knowledge_obj, _memory_config) do
    # Content-based indexing could be implemented here
    # For now, we rely on the category index and full searches
    :ok
  end

  @spec remove_from_content_indexes(KnowledgeObject.t(), memory_config()) :: :ok
  defp remove_from_content_indexes(_knowledge_obj, _memory_config) do
    # Content-based index removal would be implemented here
    :ok
  end

  @spec get_knowledge_count(memory_config()) :: non_neg_integer()
  defp get_knowledge_count(memory_config) do
    # Count all knowledge objects by searching the pattern
    case search_all_knowledge_objects(memory_config) do
      {:ok, objects} -> length(objects)
      {:error, _} -> 0
    end
  end

  @spec check_required_fields(map(), [atom()]) :: :ok | {:error, {:missing_field, atom()}}
  defp check_required_fields(config, fields) do
    case Enum.find(fields, &(not Map.has_key?(config, &1))) do
      nil -> :ok
      field -> {:error, {:missing_field, field}}
    end
  end

  @spec validate_memory_backend(term()) :: :ok | {:error, {:invalid_memory_backend, term()}}
  defp validate_memory_backend(backend) when backend in [:cachex, :nebulex, :mnesia, :layered, :test] do
    :ok
  end
  defp validate_memory_backend(backend) do
    {:error, {:invalid_memory_backend, backend}}
  end

  @spec knowledge_storage_key(Protocol.knowledge_id()) :: String.t()
  defp knowledge_storage_key(knowledge_id) do
    "blackboard:knowledge:#{knowledge_id}"
  end

  @spec category_index_key(KnowledgeObject.category()) :: String.t()
  defp category_index_key(category) do
    "blackboard:index:category:#{category}"
  end

  @spec generate_subscription_id() :: String.t()
  defp generate_subscription_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
    |> then(&("memory_sub_#{&1}"))
  end

  @spec generate_rule_id() :: String.t()
  defp generate_rule_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
    |> then(&("memory_rule_#{&1}"))
  end

  @spec emit_telemetry([atom()], map()) :: :ok
  defp emit_telemetry(event_name, measurements) do
    :telemetry.execute(
      [:prismatic, :blackboard, :memory_backend] ++ event_name,
      Map.merge(%{count: 1}, measurements),
      %{}
    )
  end
end
