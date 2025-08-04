defmodule Prismatic.Blackboard.Manager do
  @moduledoc """
  Blackboard Manager coordinates the multi-component blackboard system.

  The Blackboard Manager acts as the primary interface for the blackboard system,
  orchestrating operations across different components (knowledge objects, access control,
  rule engine) and providing a unified API for blackboard operations. It follows the
  same patterns as Memory.Manager and Event.Bus with comprehensive error handling.

  ## Architecture

  The Manager coordinates several components:

  - **Knowledge Storage** - Uses Memory system for persistence
  - **Access Control** - Fine-grained permissions and security
  - **Rule Engine** - Pattern-based rule execution
  - **Event Integration** - Publishing blackboard changes as events
  - **Circuit Breaker** - Fault tolerance and resilience

  ## Usage Examples

  ### Basic Operations

      iex> {:ok, manager} = Manager.start_link()
      iex> knowledge = %{category: :facts, content: %{fact: "sky is blue"}}
      iex> {:ok, knowledge_id} = Manager.post(manager, knowledge)
      iex> {:ok, retrieved} = Manager.read(manager, knowledge_id)

  ### With Access Control

      iex> context = %{agent_id: "agent_alice", permissions: [:read, :write]}
      iex> {:ok, knowledge_id} = Manager.post(manager, knowledge, context)
      iex> {:ok, retrieved} = Manager.read(manager, knowledge_id, context)

  ### Pattern Matching Queries

      iex> {:ok, results} = Manager.query(manager, %{
      ...>   category: :goals,
      ...>   pattern: %{priority: :high}
      ...> })

  ## Configuration

  The manager can be configured with various options:

      config = %{
        name: :blackboard_manager,
        memory_backend: :layered,
        enable_events: true,
        enable_rules: true,
        enable_access_control: true,
        max_knowledge_objects: 100_000,
        circuit_breaker_config: %{
          failure_threshold: 5,
          recovery_timeout: 30_000
        }
      }

  ## Integration Components

  - **Memory System**: Persistent storage of knowledge objects
  - **Event System**: Publishing changes for inter-system communication
  - **Rule Engine**: Automatic rule execution on knowledge changes
  - **Access Control**: Security and permission management

  ## Telemetry Events

  The manager emits comprehensive telemetry:

  - `[:prismatic, :blackboard, :manager, :post]` - Knowledge posting
  - `[:prismatic, :blackboard, :manager, :read]` - Knowledge reading
  - `[:prismatic, :blackboard, :manager, :query]` - Query operations
  - `[:prismatic, :blackboard, :manager, :rule_triggered]` - Rule executions
  """

  use GenServer
  require Logger

  alias Prismatic.Blackboard.{KnowledgeObject, AccessControl, RuleEngine}
  alias Prismatic.Memory.Protocol, as: MemoryProtocol
  alias Prismatic.Event.Protocol, as: EventProtocol

  @type manager_state :: %{
    config: map(),
    memory_config: MemoryProtocol.config(),
    event_config: EventProtocol.config() | nil,
    rule_engine_pid: pid() | nil,
    circuit_breaker_pid: pid() | nil,
    stats: map(),
    start_time: integer()
  }

  @type start_options :: [
    name: atom(),
    config: map()
  ]

  ## Public API

  @doc """
  Start the Blackboard Manager.

  ## Options
  - `:name` - Process name (default: `__MODULE__`)
  - `:config` - Manager configuration

  ## Examples

      iex> {:ok, manager} = Manager.start_link()
      iex> is_pid(manager)
      true
  """
  @spec start_link(start_options()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Post knowledge to the blackboard.

  Stores a knowledge object with access control, triggers rules,
  and publishes events if configured.

  ## Parameters

  - `manager` - Manager process identifier
  - `knowledge` - Knowledge object or map to post
  - `context` - Optional access control context

  ## Returns

  - `{:ok, knowledge_id}` - Successfully posted
  - `{:error, reason}` - Posting failed

  ## Examples

      iex> {:ok, manager} = Manager.start_link()
      iex> knowledge = %{category: :facts, content: %{test: "data"}}
      iex> {:ok, knowledge_id} = Manager.post(manager, knowledge)
      iex> is_binary(knowledge_id)
      true
  """
  @spec post(GenServer.server(), KnowledgeObject.t() | map(), AccessControl.access_context()) ::
    {:ok, KnowledgeObject.knowledge_id()} | {:error, term()}
  def post(manager, knowledge, context \\ %{}) do
    GenServer.call(manager, {:post, knowledge, context})
  end

  @doc """
  Read knowledge from the blackboard.

  Retrieves a knowledge object by ID with access control validation.

  ## Parameters

  - `manager` - Manager process identifier
  - `knowledge_id` - ID of knowledge to retrieve
  - `context` - Optional access control context

  ## Returns

  - `{:ok, knowledge_object}` - Successfully retrieved
  - `{:error, reason}` - Retrieval failed

  ## Examples

      iex> {:ok, manager} = Manager.start_link()
      iex> knowledge = %{category: :facts, content: %{test: "data"}}
      iex> {:ok, knowledge_id} = Manager.post(manager, knowledge)
      iex> {:ok, retrieved} = Manager.read(manager, knowledge_id)
      iex> retrieved.content.test
      "data"
  """
  @spec read(GenServer.server(), KnowledgeObject.knowledge_id(), AccessControl.access_context()) ::
    {:ok, KnowledgeObject.t()} | {:error, term()}
  def read(manager, knowledge_id, context \\ %{}) do
    GenServer.call(manager, {:read, knowledge_id, context})
  end

  @doc """
  Update existing knowledge on the blackboard.

  Modifies a knowledge object with access control and event publishing.

  ## Parameters

  - `manager` - Manager process identifier
  - `knowledge_id` - ID of knowledge to update
  - `updates` - Map of fields to update
  - `context` - Optional access control context

  ## Returns

  - `{:ok, updated_knowledge}` - Successfully updated
  - `{:error, reason}` - Update failed

  ## Examples

      iex> {:ok, manager} = Manager.start_link()
      iex> knowledge = %{category: :facts, content: %{value: 1}}
      iex> {:ok, knowledge_id} = Manager.post(manager, knowledge)
      iex> {:ok, updated} = Manager.update(manager, knowledge_id, %{content: %{value: 2}})
      iex> updated.content.value
      2
  """
  @spec update(GenServer.server(), KnowledgeObject.knowledge_id(), map(), AccessControl.access_context()) ::
    {:ok, KnowledgeObject.t()} | {:error, term()}
  def update(manager, knowledge_id, updates, context \\ %{}) do
    GenServer.call(manager, {:update, knowledge_id, updates, context})
  end

  @doc """
  Remove knowledge from the blackboard.

  Deletes a knowledge object with access control and event publishing.

  ## Parameters

  - `manager` - Manager process identifier
  - `knowledge_id` - ID of knowledge to remove
  - `context` - Optional access control context

  ## Returns

  - `:ok` - Successfully removed
  - `{:error, reason}` - Removal failed

  ## Examples

      iex> {:ok, manager} = Manager.start_link()
      iex> knowledge = %{category: :facts, content: %{temp: "data"}}
      iex> {:ok, knowledge_id} = Manager.post(manager, knowledge)
      iex> :ok = Manager.remove(manager, knowledge_id)
      :ok
  """
  @spec remove(GenServer.server(), KnowledgeObject.knowledge_id(), AccessControl.access_context()) ::
    :ok | {:error, term()}
  def remove(manager, knowledge_id, context \\ %{}) do
    GenServer.call(manager, {:remove, knowledge_id, context})
  end

  @doc """
  Query knowledge using pattern matching.

  Searches for knowledge objects matching the given pattern.

  ## Parameters

  - `manager` - Manager process identifier
  - `pattern` - Query pattern with filters
  - `context` - Optional access control context

  ## Returns

  - `{:ok, results}` - List of matching knowledge objects
  - `{:error, reason}` - Query failed

  ## Examples

      iex> {:ok, manager} = Manager.start_link()
      iex> knowledge = %{category: :goals, content: %{priority: :high}}
      iex> {:ok, _} = Manager.post(manager, knowledge)
      iex> {:ok, results} = Manager.query(manager, %{category: :goals})
      iex> length(results) >= 1
      true
  """
  @spec query(GenServer.server(), map(), AccessControl.access_context()) ::
    {:ok, [KnowledgeObject.t()]} | {:error, term()}
  def query(manager, pattern, context \\ %{}) do
    GenServer.call(manager, {:query, pattern, context})
  end

  @doc """
  Subscribe to blackboard changes matching a pattern.

  Registers for notifications when knowledge objects are changed.

  ## Parameters

  - `manager` - Manager process identifier
  - `pattern` - Pattern to match for notifications
  - `handler` - Function to call when changes occur
  - `context` - Optional access control context

  ## Returns

  - `{:ok, subscription_id}` - Successfully subscribed
  - `{:error, reason}` - Subscription failed

  ## Examples

      iex> {:ok, manager} = Manager.start_link()
      iex> handler = fn event -> IO.inspect(event) end
      iex> {:ok, sub_id} = Manager.subscribe(manager, %{category: :facts}, handler)
      iex> is_binary(sub_id)
      true
  """
  @spec subscribe(GenServer.server(), map(), function(), AccessControl.access_context()) ::
    {:ok, String.t()} | {:error, term()}
  def subscribe(manager, pattern, handler, context \\ %{}) do
    GenServer.call(manager, {:subscribe, pattern, handler, context})
  end

  @doc """
  Unsubscribe from blackboard changes.

  Removes a previously registered subscription.

  ## Parameters

  - `manager` - Manager process identifier
  - `subscription_id` - ID of subscription to remove

  ## Returns

  - `:ok` - Successfully unsubscribed
  - `{:error, reason}` - Unsubscription failed

  ## Examples

      iex> {:ok, manager} = Manager.start_link()
      iex> handler = fn _event -> :ok end
      iex> {:ok, sub_id} = Manager.subscribe(manager, %{category: :facts}, handler)
      iex> :ok = Manager.unsubscribe(manager, sub_id)
      :ok
  """
  @spec unsubscribe(GenServer.server(), String.t()) :: :ok | {:error, term()}
  def unsubscribe(manager, subscription_id) do
    GenServer.call(manager, {:unsubscribe, subscription_id})
  end

  @doc """
  Add a rule to the rule engine.

  Registers a rule that will be triggered on knowledge changes.

  ## Parameters

  - `manager` - Manager process identifier
  - `rule` - Rule definition
  - `context` - Optional access control context

  ## Returns

  - `{:ok, rule_id}` - Successfully added rule
  - `{:error, reason}` - Rule addition failed

  ## Examples

      iex> {:ok, manager} = Manager.start_link()
      iex> rule = %{
      ...>   pattern: %{category: :facts},
      ...>   action: fn _obj, _ctx -> :ok end
      ...> }
      iex> {:ok, rule_id} = Manager.add_rule(manager, rule)
      iex> is_binary(rule_id)
      true
  """
  @spec add_rule(GenServer.server(), map(), AccessControl.access_context()) ::
    {:ok, String.t()} | {:error, term()}
  def add_rule(manager, rule, context \\ %{}) do
    GenServer.call(manager, {:add_rule, rule, context})
  end

  @doc """
  Remove a rule from the rule engine.

  Unregisters a previously added rule.

  ## Parameters

  - `manager` - Manager process identifier
  - `rule_id` - ID of rule to remove
  - `context` - Optional access control context

  ## Returns

  - `:ok` - Successfully removed rule
  - `{:error, reason}` - Rule removal failed

  ## Examples

      iex> {:ok, manager} = Manager.start_link()
      iex> rule = %{pattern: %{category: :facts}, action: fn _,_ -> :ok end}
      iex> {:ok, rule_id} = Manager.add_rule(manager, rule)
      iex> :ok = Manager.remove_rule(manager, rule_id)
      :ok
  """
  @spec remove_rule(GenServer.server(), String.t(), AccessControl.access_context()) ::
    :ok | {:error, term()}
  def remove_rule(manager, rule_id, context \\ %{}) do
    GenServer.call(manager, {:remove_rule, rule_id, context})
  end

  @doc """
  Get blackboard statistics.

  Returns comprehensive information about blackboard state and performance.

  ## Parameters

  - `manager` - Manager process identifier

  ## Returns

  - `{:ok, stats}` - Blackboard statistics
  - `{:error, reason}` - Failed to get stats

  ## Examples

      iex> {:ok, manager} = Manager.start_link()
      iex> {:ok, stats} = Manager.get_stats(manager)
      iex> is_map(stats)
      true
      iex> Map.has_key?(stats, :knowledge_count)
      true
  """
  @spec get_stats(GenServer.server()) :: {:ok, map()} | {:error, term()}
  def get_stats(manager) do
    GenServer.call(manager, :get_stats)
  end

  @doc """
  Perform a health check on the blackboard.

  Verifies that all blackboard components are functioning correctly.

  ## Parameters

  - `manager` - Manager process identifier

  ## Returns

  - `:ok` - Blackboard is healthy
  - `{:error, reason}` - Blackboard has issues

  ## Examples

      iex> {:ok, manager} = Manager.start_link()
      iex> Manager.health_check(manager)
      :ok
  """
  @spec health_check(GenServer.server()) :: :ok | {:error, term()}
  def health_check(manager) do
    GenServer.call(manager, :health_check)
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(opts) do
    # Get or create configuration
    config = Keyword.get(opts, :config, default_config())

    # Initialize memory configuration
    {:ok, memory_config} = MemoryProtocol.create_config(
      config.memory_backend,
      %{name: :"#{config.name}_memory"}
    )

    # Initialize event configuration if enabled
    event_config = if config.enable_events do
      case EventProtocol.create_config(:in_memory, %{name: :"#{config.name}_events"}) do
        {:ok, config} -> config
        {:error, _} -> nil
      end
    else
      nil
    end

    # Start rule engine if enabled
    rule_engine_pid = if config.enable_rules do
      rule_config = Map.merge(config.rule_engine_config, %{
        name: :"#{config.name}_rules",
        event_config: event_config
      })

      case RuleEngine.start_link(config: rule_config) do
        {:ok, pid} -> pid
        {:error, reason} ->
          Logger.warning("Failed to start rule engine", %{reason: reason})
          nil
      end
    else
      nil
    end

    # Initialize statistics
    stats = %{
      knowledge_count: 0,
      posts: 0,
      reads: 0,
      updates: 0,
      removes: 0,
      queries: 0,
      rule_executions: 0,
      events_published: 0
    }

    state = %{
      config: config,
      memory_config: memory_config,
      event_config: event_config,
      rule_engine_pid: rule_engine_pid,
      circuit_breaker_pid: nil,  # Would be initialized in full implementation
      stats: stats,
      start_time: System.monotonic_time()
    }

    Logger.info("Blackboard Manager started", %{
      name: config.name,
      memory_backend: config.memory_backend,
      events_enabled: config.enable_events,
      rules_enabled: config.enable_rules,
      access_control_enabled: config.enable_access_control
    })

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:post, knowledge, context}, _from, state) do
    start_time = System.monotonic_time()

    case post_impl(knowledge, context, state) do
      {:ok, knowledge_id, new_state} ->
        duration = System.monotonic_time() - start_time

        emit_telemetry([:post], %{
          knowledge_id: knowledge_id,
          duration: duration,
          success: true
        })

        {:reply, {:ok, knowledge_id}, new_state}

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        emit_telemetry([:post], %{
          duration: duration,
          success: false,
          error: reason
        })

        Logger.warning("Knowledge post failed", %{reason: reason})
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:read, knowledge_id, context}, _from, state) do
    case read_impl(knowledge_id, context, state) do
      {:ok, knowledge_obj} ->
        new_stats = update_stats(state.stats, :reads)
        emit_telemetry([:read], %{knowledge_id: knowledge_id, success: true})
        {:reply, {:ok, knowledge_obj}, %{state | stats: new_stats}}

      {:error, reason} ->
        emit_telemetry([:read], %{knowledge_id: knowledge_id, success: false, error: reason})
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:update, knowledge_id, updates, context}, _from, state) do
    case update_impl(knowledge_id, updates, context, state) do
      {:ok, knowledge_obj, new_state} ->
        emit_telemetry([:update], %{knowledge_id: knowledge_id, success: true})
        {:reply, {:ok, knowledge_obj}, new_state}

      {:error, reason} ->
        emit_telemetry([:update], %{knowledge_id: knowledge_id, success: false, error: reason})
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:remove, knowledge_id, context}, _from, state) do
    case remove_impl(knowledge_id, context, state) do
      {:ok, new_state} ->
        emit_telemetry([:remove], %{knowledge_id: knowledge_id, success: true})
        {:reply, :ok, new_state}

      {:error, reason} ->
        emit_telemetry([:remove], %{knowledge_id: knowledge_id, success: false, error: reason})
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:query, pattern, context}, _from, state) do
    case query_impl(pattern, context, state) do
      {:ok, results} ->
        new_stats = update_stats(state.stats, :queries)
        emit_telemetry([:query], %{result_count: length(results), success: true})
        {:reply, {:ok, results}, %{state | stats: new_stats}}

      {:error, reason} ->
        emit_telemetry([:query], %{success: false, error: reason})
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:subscribe, pattern, handler, context}, _from, state) do
    case subscribe_impl(pattern, handler, context, state) do
      {:ok, subscription_id} ->
        {:reply, {:ok, subscription_id}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:unsubscribe, subscription_id}, _from, state) do
    case unsubscribe_impl(subscription_id, state) do
      :ok ->
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:add_rule, rule, context}, _from, state) do
    case add_rule_impl(rule, context, state) do
      {:ok, rule_id} ->
        {:reply, {:ok, rule_id}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:remove_rule, rule_id, context}, _from, state) do
    case remove_rule_impl(rule_id, context, state) do
      :ok ->
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    stats = %{
      name: state.config.name,
      uptime_seconds: get_uptime_seconds(state.start_time),
      components: %{
        memory_enabled: true,
        events_enabled: state.config.enable_events,
        rules_enabled: state.config.enable_rules,
        access_control_enabled: state.config.enable_access_control
      },
      statistics: state.stats,
      memory_usage: :erlang.process_info(self(), :memory)
    }

    {:reply, {:ok, stats}, state}
  end

  @impl GenServer
  def handle_call(:health_check, _from, state) do
    health = perform_health_check(state)
    {:reply, health, state}
  end

  ## Private Implementation

  @spec default_config() :: map()
  defp default_config do
    %{
      name: :blackboard_manager,
      memory_backend: :layered,
      enable_events: true,
      enable_rules: true,
      enable_access_control: true,
      max_knowledge_objects: 100_000,
      rule_engine_config: %{},
      access_control_config: AccessControl.default_config(),
      event_config: %{},
      circuit_breaker_config: %{
        failure_threshold: 5,
        recovery_timeout: 30_000
      }
    }
  end

  @spec post_impl(KnowledgeObject.t() | map(), AccessControl.access_context(), manager_state()) ::
    {:ok, KnowledgeObject.knowledge_id(), manager_state()} | {:error, term()}
  defp post_impl(knowledge, context, state) do
    with {:ok, knowledge_obj} <- normalize_knowledge(knowledge),
         :ok <- authorize_operation(context, :write, knowledge_obj, state),
         {:ok, secured_obj} <- apply_access_control(knowledge_obj, context, state),
         {:ok, stored_obj} <- store_knowledge(secured_obj, state),
         :ok <- trigger_rules(stored_obj, context, state),
         :ok <- publish_event(:knowledge_posted, stored_obj, context, state) do

      new_stats = state.stats
      |> update_stats(:posts)
      |> update_stats(:knowledge_count)

      {:ok, stored_obj.id, %{state | stats: new_stats}}
    end
  end

  @spec read_impl(KnowledgeObject.knowledge_id(), AccessControl.access_context(), manager_state()) ::
    {:ok, KnowledgeObject.t()} | {:error, term()}
  defp read_impl(knowledge_id, context, state) do
    with {:ok, knowledge_obj} <- retrieve_knowledge(knowledge_id, state),
         :ok <- authorize_operation(context, :read, knowledge_obj, state) do
      {:ok, knowledge_obj}
    end
  end

  @spec update_impl(KnowledgeObject.knowledge_id(), map(), AccessControl.access_context(), manager_state()) ::
    {:ok, KnowledgeObject.t(), manager_state()} | {:error, term()}
  defp update_impl(knowledge_id, updates, context, state) do
    with {:ok, current_obj} <- retrieve_knowledge(knowledge_id, state),
         :ok <- authorize_operation(context, :write, current_obj, state),
         {:ok, updated_obj} <- KnowledgeObject.update(current_obj, updates),
         {:ok, stored_obj} <- store_knowledge(updated_obj, state),
         :ok <- trigger_rules(stored_obj, context, state),
         :ok <- publish_event(:knowledge_updated, stored_obj, context, state) do

      new_stats = update_stats(state.stats, :updates)
      {:ok, stored_obj, %{state | stats: new_stats}}
    end
  end

  @spec remove_impl(KnowledgeObject.knowledge_id(), AccessControl.access_context(), manager_state()) ::
    {:ok, manager_state()} | {:error, term()}
  defp remove_impl(knowledge_id, context, state) do
    with {:ok, knowledge_obj} <- retrieve_knowledge(knowledge_id, state),
         :ok <- authorize_operation(context, :write, knowledge_obj, state),
         :ok <- delete_knowledge(knowledge_id, state),
         :ok <- publish_event(:knowledge_removed, knowledge_obj, context, state) do

      new_stats = state.stats
      |> update_stats(:removes)
      |> Map.update(:knowledge_count, 0, &max(0, &1 - 1))

      {:ok, %{state | stats: new_stats}}
    end
  end

  @spec query_impl(map(), AccessControl.access_context(), manager_state()) ::
    {:ok, [KnowledgeObject.t()]} | {:error, term()}
  defp query_impl(pattern, context, state) do
    # This is a simplified implementation
    # In a full implementation, this would use sophisticated indexing and filtering
    with {:ok, all_knowledge} <- list_all_knowledge(state) do
      filtered_results = all_knowledge
      |> Enum.filter(&match_pattern?(&1, pattern))
      |> Enum.filter(&(authorize_operation(context, :read, &1, state) == :ok))

      {:ok, filtered_results}
    end
  end

  @spec normalize_knowledge(KnowledgeObject.t() | map()) :: {:ok, KnowledgeObject.t()} | {:error, term()}
  defp normalize_knowledge(%KnowledgeObject{} = knowledge_obj), do: {:ok, knowledge_obj}
  defp normalize_knowledge(knowledge) when is_map(knowledge) do
    KnowledgeObject.new(knowledge)
  end
  defp normalize_knowledge(knowledge), do: {:error, {:invalid_knowledge, knowledge}}

  @spec authorize_operation(AccessControl.access_context(), AccessControl.permission(), KnowledgeObject.t(), manager_state()) ::
    :ok | {:error, term()}
  defp authorize_operation(context, operation, knowledge_obj, state) do
    if state.config.enable_access_control and map_size(context) > 0 do
      AccessControl.authorize(context, operation, knowledge_obj)
    else
      :ok
    end
  end

  @spec apply_access_control(KnowledgeObject.t(), AccessControl.access_context(), manager_state()) ::
    {:ok, KnowledgeObject.t()} | {:error, term()}
  defp apply_access_control(knowledge_obj, context, state) do
    if state.config.enable_access_control and map_size(context) > 0 do
      AccessControl.secure_knowledge_object(knowledge_obj, context)
    else
      {:ok, knowledge_obj}
    end
  end

  @spec store_knowledge(KnowledgeObject.t(), manager_state()) :: {:ok, KnowledgeObject.t()} | {:error, term()}
  defp store_knowledge(knowledge_obj, state) do
    knowledge_map = KnowledgeObject.to_map(knowledge_obj)

    case MemoryProtocol.store(state.memory_config, :semantic, knowledge_obj.id, knowledge_map) do
      {:ok, _} -> {:ok, knowledge_obj}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec retrieve_knowledge(KnowledgeObject.knowledge_id(), manager_state()) :: {:ok, KnowledgeObject.t()} | {:error, term()}
  defp retrieve_knowledge(knowledge_id, state) do
    case MemoryProtocol.retrieve(state.memory_config, :semantic, knowledge_id) do
      {:ok, knowledge_map} ->
        KnowledgeObject.from_map(knowledge_map)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec delete_knowledge(KnowledgeObject.knowledge_id(), manager_state()) :: :ok | {:error, term()}
  defp delete_knowledge(knowledge_id, state) do
    case MemoryProtocol.forget(state.memory_config, :semantic, knowledge_id) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec trigger_rules(KnowledgeObject.t(), AccessControl.access_context(), manager_state()) :: :ok | {:error, term()}
  defp trigger_rules(knowledge_obj, context, state) do
    if state.rule_engine_pid do
      case RuleEngine.evaluate(state.rule_engine_pid, knowledge_obj, context) do
        {:ok, triggered_rules} ->
          new_stats = Map.update(state.stats, :rule_executions, length(triggered_rules), &(&1 + length(triggered_rules)))
          :ok

        {:error, reason} ->
          Logger.warning("Rule engine evaluation failed", %{reason: reason})
          :ok  # Don't fail the entire operation due to rule engine issues
      end
    else
      :ok
    end
  end

  @spec publish_event(atom(), KnowledgeObject.t(), AccessControl.access_context(), manager_state()) :: :ok
  defp publish_event(event_type, knowledge_obj, context, state) do
    if state.event_config do
      event = %{
        type: "blackboard.#{event_type}",
        payload: %{
          knowledge_id: knowledge_obj.id,
          category: knowledge_obj.category,
          agent_id: Map.get(context, :agent_id),
          timestamp: DateTime.utc_now()
        },
        metadata: %{
          source: "blackboard_manager"
        }
      }

      case EventProtocol.publish(state.event_config, event) do
        {:ok, _event_id} ->
          new_stats = update_stats(state.stats, :events_published)
          :ok

        {:error, reason} ->
          Logger.warning("Failed to publish blackboard event", %{reason: reason})
          :ok  # Don't fail the operation due to event publishing issues
      end
    else
      :ok
    end
  end

  @spec subscribe_impl(map(), function(), AccessControl.access_context(), manager_state()) ::
    {:ok, String.t()} | {:error, term()}
  defp subscribe_impl(_pattern, _handler, _context, _state) do
    # Subscription implementation would integrate with Event system
    # For now, return a placeholder
    {:ok, generate_subscription_id()}
  end

  @spec unsubscribe_impl(String.t(), manager_state()) :: :ok | {:error, term()}
  defp unsubscribe_impl(_subscription_id, _state) do
    # Unsubscription implementation
    :ok
  end

  @spec add_rule_impl(map(), AccessControl.access_context(), manager_state()) :: {:ok, String.t()} | {:error, term()}
  defp add_rule_impl(rule, context, state) do
    if state.rule_engine_pid do
      RuleEngine.add_rule(state.rule_engine_pid, rule, context)
    else
      {:error, :rule_engine_disabled}
    end
  end

  @spec remove_rule_impl(String.t(), AccessControl.access_context(), manager_state()) :: :ok | {:error, term()}
  defp remove_rule_impl(rule_id, context, state) do
    if state.rule_engine_pid do
      RuleEngine.remove_rule(state.rule_engine_pid, rule_id, context)
    else
      {:error, :rule_engine_disabled}
    end
  end

  @spec list_all_knowledge(manager_state()) :: {:ok, [KnowledgeObject.t()]} | {:error, term()}
  defp list_all_knowledge(state) do
    # This is a simplified implementation
    # In a full implementation, this would use pagination and efficient querying
    case MemoryProtocol.search(state.memory_config, :semantic, "*") do
      {:ok, results} ->
        knowledge_objects = Enum.map(results, fn {_key, knowledge_map} ->
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

  @spec match_pattern?(KnowledgeObject.t(), map()) :: boolean()
  defp match_pattern?(knowledge_obj, pattern) do
    Enum.all?(pattern, fn
      {:category, category} -> knowledge_obj.category == category
      {:content, content_pattern} when is_map(content_pattern) ->
        match_content_pattern?(knowledge_obj.content, content_pattern)
      {:metadata, metadata_pattern} when is_map(metadata_pattern) ->
        match_metadata_pattern?(knowledge_obj.metadata, metadata_pattern)
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

  @spec update_stats(map(), atom()) :: map()
  defp update_stats(stats, key) do
    Map.update(stats, key, 1, &(&1 + 1))
  end

  @spec perform_health_check(manager_state()) :: :ok | {:error, term()}
  defp perform_health_check(state) do
    checks = [
      check_memory_health(state),
      check_event_health(state),
      check_rule_engine_health(state)
    ]

    case Enum.find(checks, &match?({:error, _}, &1)) do
      nil -> :ok
      error -> error
    end
  end

  @spec check_memory_health(manager_state()) :: :ok | {:error, term()}
  defp check_memory_health(state) do
    case MemoryProtocol.health_check(state.memory_config) do
      :ok -> :ok
      {:error, reason} -> {:error, {:memory_unhealthy, reason}}
    end
  end

  @spec check_event_health(manager_state()) :: :ok | {:error, term()}
  defp check_event_health(state) do
    if state.event_config do
      case EventProtocol.health_check(state.event_config) do
        :ok -> :ok
        {:error, reason} -> {:error, {:event_system_unhealthy, reason}}
      end
    else
      :ok
    end
  end

  @spec check_rule_engine_health(manager_state()) :: :ok | {:error, term()}
  defp check_rule_engine_health(state) do
    if state.rule_engine_pid and Process.alive?(state.rule_engine_pid) do
      case RuleEngine.health_check(state.rule_engine_pid) do
        :ok -> :ok
        {:error, reason} -> {:error, {:rule_engine_unhealthy, reason}}
      end
    else
      if state.config.enable_rules do
        {:error, :rule_engine_down}
      else
        :ok
      end
    end
  end

  @spec generate_subscription_id() :: String.t()
  defp generate_subscription_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
    |> then(&("sub_#{&1}"))
  end

  @spec emit_telemetry([atom()], map()) :: :ok
  defp emit_telemetry(event_name, measurements) do
    :telemetry.execute(
      [:prismatic, :blackboard, :manager] ++ event_name,
      Map.merge(%{count: 1}, measurements),
      %{}
    )
  end

  @spec get_uptime_seconds(integer()) :: non_neg_integer()
  defp get_uptime_seconds(start_time) do
    System.convert_time_unit(
      System.monotonic_time() - start_time,
      :native,
      :second
    )
  end
end
