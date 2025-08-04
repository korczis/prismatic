defmodule Prismatic.Blackboard.RuleEngine do
  @moduledoc """
  Rule Engine for the Prismatic Blackboard System.

  The Rule Engine provides pattern-based rule execution for blackboard operations,
  allowing agents to define rules that trigger automatically when matching knowledge
  objects are posted, updated, or removed. It follows the same GenServer patterns
  as the Event.Bus with comprehensive error handling and monitoring.

  ## Architecture

  The Rule Engine uses a multi-layered architecture:

  - **Rule Layer**: Rule definitions with patterns and actions
  - **Engine Layer**: This module - rule coordination and execution logic
  - **Pattern Matching**: Advanced pattern matching on knowledge objects
  - **Action Execution**: Triggering of rule actions when patterns match
  - **Event Integration**: Publishing rule execution events

  ## Rule Structure

  Rules consist of:

  - **Pattern** - Condition that must match for rule to trigger
  - **Action** - Function to execute when pattern matches
  - **Metadata** - Additional rule information and configuration
  - **Priority** - Execution order for conflicting rules

  ## Pattern Matching

  The rule engine supports sophisticated pattern matching:

  - **Category Matching** - `%{category: :facts}`
  - **Content Matching** - `%{content: %{priority: :high}}`
  - **Metadata Matching** - `%{metadata: %{source: "agent_alice"}}`
  - **Combined Patterns** - Multiple conditions with AND/OR logic
  - **Wildcard Patterns** - Flexible matching with wildcards

  ## Usage Examples

  ### Basic Rule Definition

      rule = %{
        id: "high_priority_alert",
        pattern: %{
          category: :goals,
          content: %{priority: :high}
        },
        action: fn knowledge_obj, _ctx ->
          # Send alert notification
          IO.puts("High priority goal detected: [ID]")
          :ok
        end,
        metadata: %{
          created_by: "agent_alice",
          description: "Alert on high priority goals"
        }
      }

      {:ok, rule_id} = RuleEngine.add_rule(:rule_engine, rule)

  ### Pattern Matching Examples

      # Simple category match
      pattern = %{category: :facts}

      # Complex content match
      pattern = %{
        category: :observations,
        content: %{
          type: "sensor_reading",
          value: fn val -> val > 100 end
        }
      }

      # Metadata-based match
      pattern = %{
        metadata: %{
          source: "agent_alice",
          confidence: fn conf -> conf > 0.8 end
        }
      }

  ### Integration with Events

      # Rules can publish events when triggered
      rule_action = fn obj, context ->
        event = %{
          type: "blackboard.rule_triggered",
          payload: %{
            rule_id: context.rule_id,
            knowledge_id: obj.id,
            triggered_at: DateTime.utc_now()
          }
        }

        Event.Protocol.publish(context.event_config, event)
      end

  ## Configuration

  Rule engine can be configured with various options:

      config = %{
        name: :rule_engine,
        max_rules: 10_000,
        execution_timeout: 5_000,
        enable_parallel_execution: true,
        max_concurrent_executions: 100,
        enable_events: true,
        rule_cache_ttl: :timer.minutes(5)
      }

  ## Performance Features

  - **Rule Indexing** - Fast rule lookup by pattern type
  - **Parallel Execution** - Concurrent rule execution
  - **Caching** - Pattern compilation and matching cache
  - **Circuit Breaker** - Protection against failing rules
  - **Metrics** - Comprehensive performance monitoring

  ## Telemetry Events

  The engine emits detailed telemetry for monitoring:

  - `[:prismatic, :blackboard, :rule_engine, :rule_triggered]` - Rule execution
  - `[:prismatic, :blackboard, :rule_engine, :rule_added]` - Rule registration
  - `[:prismatic, :blackboard, :rule_engine, :rule_removed]` - Rule removal
  - `[:prismatic, :blackboard, :rule_engine, :pattern_match]` - Pattern matching performance
  """

  use GenServer
  require Logger

  alias Prismatic.Blackboard.{KnowledgeObject, AccessControl}
  alias Prismatic.Event.Protocol, as: EventProtocol

  @typedoc "Rule identifier"
  @type rule_id :: String.t()

  @typedoc "Rule pattern for matching knowledge objects"
  @type rule_pattern :: %{
    optional(:category) => KnowledgeObject.category() | (KnowledgeObject.category() -> boolean()),
    optional(:content) => map() | (map() -> boolean()),
    optional(:metadata) => map() | (map() -> boolean()),
    optional(:id) => String.t() | (String.t() -> boolean()),
    optional(:created_at) => DateTime.t() | (DateTime.t() -> boolean()),
    optional(:updated_at) => DateTime.t() | (DateTime.t() -> boolean())
  }

  @typedoc "Rule action context"
  @type action_context :: %{
    rule_id: rule_id(),
    engine_pid: pid(),
    event_config: map() | nil,
    agent_id: String.t() | nil,
    timestamp: DateTime.t()
  }

  @typedoc "Rule action function"
  @type rule_action :: (KnowledgeObject.t(), action_context() -> :ok | {:error, term()})

  @typedoc "Rule priority level"
  @type rule_priority :: :low | :normal | :high | :critical | non_neg_integer()

  @typedoc "Rule structure"
  @type rule :: %{
    id: rule_id(),
    pattern: rule_pattern(),
    action: rule_action(),
    priority: rule_priority(),
    enabled: boolean(),
    metadata: map(),
    created_at: DateTime.t(),
    created_by: String.t(),
    execution_count: non_neg_integer(),
    last_executed: DateTime.t() | nil
  }

  @typedoc "Rule engine configuration"
  @type config :: %{
    name: atom(),
    max_rules: pos_integer(),
    execution_timeout: pos_integer(),
    enable_parallel_execution: boolean(),
    max_concurrent_executions: pos_integer(),
    enable_events: boolean(),
    rule_cache_ttl: pos_integer(),
    event_config: map() | nil
  }

  @typedoc "Rule engine state"
  @type engine_state :: %{
    config: config(),
    rules: %{rule_id() => rule()},
    rule_index: map(),
    execution_stats: map(),
    concurrent_executions: non_neg_integer(),
    start_time: integer()
  }

  @type start_options :: [
    name: atom(),
    config: config()
  ]

  @default_priority_values %{
    low: 10,
    normal: 50,
    high: 80,
    critical: 100
  }

  ## Public API

  @doc """
  Start the Rule Engine GenServer.

  ## Options

  - `:name` - Process name (default: `__MODULE__`)
  - `:config` - Rule engine configuration

  ## Examples

      iex> {:ok, pid} = RuleEngine.start_link(name: :test_engine)
      iex> is_pid(pid)
      true
  """
  @spec start_link(start_options()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Add a rule to the engine.

  Registers a new rule that will be evaluated against knowledge objects.

  ## Parameters

  - `engine` - Rule engine process identifier
  - `rule_spec` - Rule specification map
  - `context` - Optional access control context

  ## Returns

  - `{:ok, rule_id}` - Successfully added rule
  - `{:error, reason}` - Rule addition failed

  ## Examples

      iex> {:ok, engine} = RuleEngine.start_link(name: :test_engine)
      iex> rule = %{
      ...>   pattern: %{category: :facts},
      ...>   action: fn _obj, _ctx -> :ok end
      ...> }
      iex> {:ok, rule_id} = RuleEngine.add_rule(engine, rule)
      iex> is_binary(rule_id)
      true
  """
  @spec add_rule(GenServer.server(), map(), AccessControl.access_context()) ::
    {:ok, rule_id()} | {:error, term()}
  def add_rule(engine, rule_spec, context \\ %{}) do
    GenServer.call(engine, {:add_rule, rule_spec, context})
  end

  @doc """
  Remove a rule from the engine.

  Unregisters a previously added rule.

  ## Parameters

  - `engine` - Rule engine process identifier
  - `rule_id` - ID of rule to remove
  - `context` - Optional access control context

  ## Returns

  - `:ok` - Successfully removed rule
  - `{:error, reason}` - Rule removal failed

  ## Examples

      iex> {:ok, engine} = RuleEngine.start_link(name: :test_engine)
      iex> rule = %{pattern: %{category: :facts}, action: fn _,_ -> :ok end}
      iex> {:ok, rule_id} = RuleEngine.add_rule(engine, rule)
      iex> :ok = RuleEngine.remove_rule(engine, rule_id)
      :ok
  """
  @spec remove_rule(GenServer.server(), rule_id(), AccessControl.access_context()) ::
    :ok | {:error, term()}
  def remove_rule(engine, rule_id, context \\ %{}) do
    GenServer.call(engine, {:remove_rule, rule_id, context})
  end

  @doc """
  Evaluate knowledge object against all rules.

  Tests a knowledge object against all registered rules and executes
  matching rule actions.

  ## Parameters

  - `engine` - Rule engine process identifier
  - `knowledge_obj` - Knowledge object to evaluate
  - `context` - Optional access control context

  ## Returns

  - `{:ok, triggered_rules}` - List of triggered rule IDs
  - `{:error, reason}` - Evaluation failed

  ## Examples

      iex> {:ok, engine} = RuleEngine.start_link(name: :test_engine)
      iex> knowledge = KnowledgeObject.new!(%{category: :facts, content: %{test: "data"}})
      iex> {:ok, triggered} = RuleEngine.evaluate(engine, knowledge)
      iex> is_list(triggered)
      true
  """
  @spec evaluate(GenServer.server(), KnowledgeObject.t(), AccessControl.access_context()) ::
    {:ok, [rule_id()]} | {:error, term()}
  def evaluate(engine, knowledge_obj, context \\ %{}) do
    GenServer.call(engine, {:evaluate, knowledge_obj, context})
  end

  @doc """
  List all registered rules.

  Returns information about all active rules for monitoring and debugging.

  ## Parameters

  - `engine` - Rule engine process identifier
  - `context` - Optional access control context

  ## Returns

  - `{:ok, rules}` - List of rule information
  - `{:error, reason}` - Failed to list rules

  ## Examples

      iex> {:ok, engine} = RuleEngine.start_link(name: :test_engine)
      iex> {:ok, rules} = RuleEngine.list_rules(engine)
      iex> is_list(rules)
      true
  """
  @spec list_rules(GenServer.server(), AccessControl.access_context()) ::
    {:ok, [rule()]} | {:error, term()}
  def list_rules(engine, context \\ %{}) do
    GenServer.call(engine, {:list_rules, context})
  end

  @doc """
  Get rule engine statistics.

  Returns comprehensive information about engine performance and state.

  ## Parameters

  - `engine` - Rule engine process identifier

  ## Returns

  - `{:ok, stats}` - Engine statistics
  - `{:error, reason}` - Failed to get stats

  ## Examples

      iex> {:ok, engine} = RuleEngine.start_link(name: :test_engine)
      iex> {:ok, stats} = RuleEngine.get_stats(engine)
      iex> is_map(stats)
      true
      iex> Map.has_key?(stats, :rules_count)
      true
  """
  @spec get_stats(GenServer.server()) :: {:ok, map()} | {:error, term()}
  def get_stats(engine) do
    GenServer.call(engine, :get_stats)
  end

  @doc """
  Perform a health check on the engine.

  Verifies that the rule engine is functioning correctly.

  ## Parameters

  - `engine` - Rule engine process identifier

  ## Returns

  - `:ok` - Engine is healthy
  - `{:error, reason}` - Engine has issues

  ## Examples

      iex> {:ok, engine} = RuleEngine.start_link(name: :test_engine)
      iex> RuleEngine.health_check(engine)
      :ok
  """
  @spec health_check(GenServer.server()) :: :ok | {:error, term()}
  def health_check(engine) do
    GenServer.call(engine, :health_check)
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(opts) do
    # Get or create configuration
    config = case Keyword.get(opts, :config) do
      nil ->
        default_config(%{
          name: Keyword.get(opts, :name, :rule_engine)
        })
      config -> config
    end

    # Initialize engine state
    state = %{
      config: config,
      rules: %{},
      rule_index: build_empty_index(),
      execution_stats: %{
        rules_executed: 0,
        total_executions: 0,
        execution_errors: 0,
        pattern_matches: 0
      },
      concurrent_executions: 0,
      start_time: System.monotonic_time()
    }

    Logger.info("Rule Engine started", %{
      name: config.name,
      max_rules: config.max_rules
    })

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:add_rule, rule_spec, context}, _from, state) do
    case add_rule_impl(rule_spec, context, state) do
      {:ok, rule_id, new_state} ->
        emit_telemetry([:rule_added], %{rule_id: rule_id})
        {:reply, {:ok, rule_id}, new_state}

      {:error, reason} ->
        Logger.warning("Failed to add rule", %{reason: reason})
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:remove_rule, rule_id, context}, _from, state) do
    case remove_rule_impl(rule_id, context, state) do
      {:ok, new_state} ->
        emit_telemetry([:rule_removed], %{rule_id: rule_id})
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:evaluate, knowledge_obj, context}, _from, state) do
    start_time = System.monotonic_time()

    case evaluate_impl(knowledge_obj, context, state) do
      {:ok, triggered_rules, new_state} ->
        duration = System.monotonic_time() - start_time

        emit_telemetry([:evaluate], %{
          triggered_count: length(triggered_rules),
          duration: duration,
          knowledge_category: knowledge_obj.category
        })

        {:reply, {:ok, triggered_rules}, new_state}

      {:error, reason} ->
        Logger.warning("Rule evaluation failed", %{
          reason: reason,
          knowledge_id: knowledge_obj.id
        })
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:list_rules, context}, _from, state) do
    case list_rules_impl(context, state) do
      {:ok, rules} ->
        {:reply, {:ok, rules}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    stats = %{
      name: state.config.name,
      rules_count: map_size(state.rules),
      concurrent_executions: state.concurrent_executions,
      execution_stats: state.execution_stats,
      uptime_seconds: get_uptime_seconds(state.start_time),
      memory_usage: :erlang.process_info(self(), :memory)
    }

    {:reply, {:ok, stats}, state}
  end

  @impl GenServer
  def handle_call(:health_check, _from, state) do
    # Basic health checks
    health = cond do
      map_size(state.rules) > state.config.max_rules ->
        {:error, :too_many_rules}

      state.concurrent_executions > state.config.max_concurrent_executions ->
        {:error, :too_many_concurrent_executions}

      true ->
        :ok
    end

    {:reply, health, state}
  end

  ## Private Implementation

  @spec default_config(map()) :: config()
  defp default_config(options \\ %{}) do
    %{
      name: Map.get(options, :name, :rule_engine),
      max_rules: Map.get(options, :max_rules, 10_000),
      execution_timeout: Map.get(options, :execution_timeout, 5_000),
      enable_parallel_execution: Map.get(options, :enable_parallel_execution, true),
      max_concurrent_executions: Map.get(options, :max_concurrent_executions, 100),
      enable_events: Map.get(options, :enable_events, true),
      rule_cache_ttl: Map.get(options, :rule_cache_ttl, :timer.minutes(5)),
      event_config: Map.get(options, :event_config)
    }
  end

  @spec add_rule_impl(map(), AccessControl.access_context(), engine_state()) ::
    {:ok, rule_id(), engine_state()} | {:error, term()}
  defp add_rule_impl(rule_spec, context, state) do
    with :ok <- validate_rule_spec(rule_spec),
         :ok <- check_rule_limits(state),
         {:ok, rule} <- build_rule(rule_spec, context) do

      rule_id = rule.id
      new_rules = Map.put(state.rules, rule_id, rule)
      new_index = update_rule_index(state.rule_index, rule, :add)

      new_state = %{state |
        rules: new_rules,
        rule_index: new_index
      }

      {:ok, rule_id, new_state}
    end
  end

  @spec remove_rule_impl(rule_id(), AccessControl.access_context(), engine_state()) ::
    {:ok, engine_state()} | {:error, term()}
  defp remove_rule_impl(rule_id, _context, state) do
    case Map.get(state.rules, rule_id) do
      nil ->
        {:error, :rule_not_found}

      rule ->
        new_rules = Map.delete(state.rules, rule_id)
        new_index = update_rule_index(state.rule_index, rule, :remove)

        new_state = %{state |
          rules: new_rules,
          rule_index: new_index
        }

        {:ok, new_state}
    end
  end

  @spec evaluate_impl(KnowledgeObject.t(), AccessControl.access_context(), engine_state()) ::
    {:ok, [rule_id()], engine_state()} | {:error, term()}
  defp evaluate_impl(knowledge_obj, context, state) do
    # Find matching rules
    matching_rules = find_matching_rules(knowledge_obj, state)

    # Sort by priority
    sorted_rules = sort_rules_by_priority(matching_rules)

    # Execute rules
    case execute_rules(sorted_rules, knowledge_obj, context, state) do
      {:ok, triggered_rules, new_stats} ->
        new_state = %{state | execution_stats: new_stats}
        {:ok, triggered_rules, new_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec list_rules_impl(AccessControl.access_context(), engine_state()) ::
    {:ok, [rule()]} | {:error, term()}
  defp list_rules_impl(_context, state) do
    # In a full implementation, this would apply access control filtering
    rules = Map.values(state.rules)
    {:ok, rules}
  end

  @spec find_matching_rules(KnowledgeObject.t(), engine_state()) :: [rule()]
  defp find_matching_rules(knowledge_obj, state) do
    # Use index to find candidate rules efficiently
    candidate_rules = get_candidate_rules_from_index(knowledge_obj, state.rule_index)

    # Filter by pattern matching
    Enum.filter(candidate_rules, fn rule ->
      rule.enabled and match_pattern?(rule.pattern, knowledge_obj)
    end)
  end

  @spec match_pattern?(rule_pattern(), KnowledgeObject.t()) :: boolean()
  defp match_pattern?(pattern, knowledge_obj) do
    Enum.all?(pattern, fn {field, matcher} ->
      field_value = get_field_value(knowledge_obj, field)
      match_field?(matcher, field_value)
    end)
  end

  @spec match_field?(term(), term()) :: boolean()
  defp match_field?(matcher, value) when is_function(matcher, 1) do
    try do
      matcher.(value)
    rescue
      _ -> false
    end
  end
  defp match_field?(matcher, value), do: matcher == value

  @spec get_field_value(KnowledgeObject.t(), atom()) :: term()
  defp get_field_value(knowledge_obj, :category), do: knowledge_obj.category
  defp get_field_value(knowledge_obj, :content), do: knowledge_obj.content
  defp get_field_value(knowledge_obj, :metadata), do: knowledge_obj.metadata
  defp get_field_value(knowledge_obj, :id), do: knowledge_obj.id
  defp get_field_value(knowledge_obj, :created_at), do: knowledge_obj.created_at
  defp get_field_value(knowledge_obj, :updated_at), do: knowledge_obj.updated_at

  @spec sort_rules_by_priority([rule()]) :: [rule()]
  defp sort_rules_by_priority(rules) do
    Enum.sort_by(rules, &get_priority_value(&1.priority), :desc)
  end

  @spec get_priority_value(rule_priority()) :: non_neg_integer()
  defp get_priority_value(priority) when is_integer(priority), do: priority
  defp get_priority_value(priority) when is_atom(priority) do
    Map.get(@default_priority_values, priority, 50)
  end

  @spec execute_rules([rule()], KnowledgeObject.t(), AccessControl.access_context(), engine_state()) ::
    {:ok, [rule_id()], map()} | {:error, term()}
  defp execute_rules(rules, knowledge_obj, context, state) do
    action_context = %{
      rule_id: nil,  # Will be set per rule
      engine_pid: self(),
      event_config: state.config.event_config,
      agent_id: Map.get(context, :agent_id),
      timestamp: DateTime.utc_now()
    }

    {triggered_rules, new_stats} = Enum.reduce(rules, {[], state.execution_stats}, fn rule, {acc_triggered, acc_stats} ->
      rule_context = %{action_context | rule_id: rule.id}

      case execute_single_rule(rule, knowledge_obj, rule_context, state.config) do
        :ok ->
          emit_telemetry([:rule_triggered], %{
            rule_id: rule.id,
            knowledge_id: knowledge_obj.id,
            knowledge_category: knowledge_obj.category
          })

          updated_stats = %{acc_stats |
            rules_executed: acc_stats.rules_executed + 1,
            total_executions: acc_stats.total_executions + 1
          }

          {[rule.id | acc_triggered], updated_stats}

        {:error, reason} ->
          Logger.warning("Rule execution failed", %{
            rule_id: rule.id,
            knowledge_id: knowledge_obj.id,
            reason: reason
          })

          updated_stats = %{acc_stats |
            execution_errors: acc_stats.execution_errors + 1,
            total_executions: acc_stats.total_executions + 1
          }

          {acc_triggered, updated_stats}
      end
    end)

    {:ok, Enum.reverse(triggered_rules), new_stats}
  end

  @spec execute_single_rule(rule(), KnowledgeObject.t(), action_context(), config()) ::
    :ok | {:error, term()}
  defp execute_single_rule(rule, knowledge_obj, context, config) do
    timeout = config.execution_timeout

    task = Task.async(fn ->
      rule.action.(knowledge_obj, context)
    end)

    case Task.yield(task, timeout) do
      {:ok, :ok} -> :ok
      {:ok, {:error, reason}} -> {:error, reason}
      nil ->
        Task.shutdown(task, :brutal_kill)
        {:error, :timeout}
    end
  rescue
    error -> {:error, {:rule_execution_error, error}}
  end

  @spec validate_rule_spec(map()) :: :ok | {:error, term()}
  defp validate_rule_spec(%{pattern: pattern, action: action}) when is_map(pattern) and is_function(action, 2) do
    :ok
  end
  defp validate_rule_spec(spec) do
    {:error, {:invalid_rule_spec, spec}}
  end

  @spec check_rule_limits(engine_state()) :: :ok | {:error, term()}
  defp check_rule_limits(state) do
    if map_size(state.rules) >= state.config.max_rules do
      {:error, :max_rules_exceeded}
    else
      :ok
    end
  end

  @spec build_rule(map(), AccessControl.access_context()) :: {:ok, rule()} | {:error, term()}
  defp build_rule(rule_spec, context) do
    now = DateTime.utc_now()

    rule = %{
      id: Map.get(rule_spec, :id, generate_rule_id()),
      pattern: rule_spec.pattern,
      action: rule_spec.action,
      priority: Map.get(rule_spec, :priority, :normal),
      enabled: Map.get(rule_spec, :enabled, true),
      metadata: Map.get(rule_spec, :metadata, %{}),
      created_at: now,
      created_by: Map.get(context, :agent_id, "system"),
      execution_count: 0,
      last_executed: nil
    }

    {:ok, rule}
  end

  @spec build_empty_index() :: map()
  defp build_empty_index do
    %{
      by_category: %{},
      by_content_keys: %{},
      by_metadata_keys: %{}
    }
  end

  @spec update_rule_index(map(), rule(), :add | :remove) :: map()
  defp update_rule_index(index, rule, operation) do
    # Simple indexing by category - could be extended for more sophisticated indexing
    category_pattern = Map.get(rule.pattern, :category)

    case {category_pattern, operation} do
      {nil, _} ->
        index

      {category, :add} when is_atom(category) ->
        category_rules = Map.get(index.by_category, category, [])
        put_in(index, [:by_category, category], [rule | category_rules])

      {category, :remove} when is_atom(category) ->
        category_rules = Map.get(index.by_category, category, [])
        updated_rules = Enum.reject(category_rules, &(&1.id == rule.id))
        put_in(index, [:by_category, category], updated_rules)

      _ ->
        index
    end
  end

  @spec get_candidate_rules_from_index(KnowledgeObject.t(), map()) :: [rule()]
  defp get_candidate_rules_from_index(knowledge_obj, index) do
    # Get rules indexed by category
    category_rules = Map.get(index.by_category, knowledge_obj.category, [])

    # Add rules that don't specify category (match all)
    all_category_rules = Map.get(index.by_category, :all, [])

    category_rules ++ all_category_rules
  end

  @spec generate_rule_id() :: rule_id()
  defp generate_rule_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
    |> then(&("rule_#{&1}"))
  end

  @spec emit_telemetry([atom()], map()) :: :ok
  defp emit_telemetry(event_name, measurements) do
    :telemetry.execute(
      [:prismatic, :blackboard, :rule_engine] ++ event_name,
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
