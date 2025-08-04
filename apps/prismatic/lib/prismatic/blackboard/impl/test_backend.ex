defmodule Prismatic.Blackboard.Impl.TestBackend do
  @moduledoc """
  Test backend implementation for the Prismatic Blackboard System.

  This backend provides a simple in-memory implementation suitable for
  testing and development. It supports all protocol operations with
  configurable responses for testing error conditions and edge cases.

  ## Features

  - **Configurable Responses**: Pre-configure responses for specific operations
  - **Knowledge History**: Track all posted knowledge for verification
  - **Subscription Tracking**: Monitor subscription lifecycle
  - **Rule Tracking**: Monitor rule registration and execution
  - **Error Simulation**: Simulate various failure conditions
  - **No Persistence**: All data is lost when the process stops

  ## Configuration

  The test backend accepts these configuration options:

      %{
        backend_type: :test,
        name: :test_blackboard,
        responses: %{
          "error_knowledge" => {:error, :test_error},
          "timeout_knowledge" => {:error, :timeout}
        },
        default_response: {:ok, "test_response"},
        track_knowledge: true,
        track_subscriptions: true,
        track_rules: true
      }

  ## Usage

  Primarily used in tests and development:

      {:ok, config} = Protocol.create_config(:test, %{
        responses: %{"test_error" => {:error, :simulated_failure}}
      })

      {:ok, knowledge_id} = Protocol.post(config, %{
        category: :facts,
        content: %{fact: "test data"}
      })
  """

  @behaviour Prismatic.Blackboard.Protocol

  use GenServer
  require Logger

  alias Prismatic.Blackboard.{Protocol, KnowledgeObject, AccessControl, RuleEngine}

  @type test_state :: %{
    config: Protocol.config(),
    knowledge_objects: %{Protocol.knowledge_id() => KnowledgeObject.t()},
    subscriptions: %{String.t() => map()},
    rules: %{String.t() => map()},
    knowledge_history: [KnowledgeObject.t()],
    subscription_counter: non_neg_integer(),
    rule_counter: non_neg_integer(),
    stats: map()
  }

  ## Protocol Implementation

  @impl Protocol
  def post(config, knowledge, context \\ %{}) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        GenServer.call(pid, {:post, knowledge, context})
      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Protocol
  def read(config, knowledge_id, context \\ %{}) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        GenServer.call(pid, {:read, knowledge_id, context})
      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Protocol
  def update(config, knowledge_id, updates, context \\ %{}) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        GenServer.call(pid, {:update, knowledge_id, updates, context})
      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Protocol
  def remove(config, knowledge_id, context \\ %{}) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        GenServer.call(pid, {:remove, knowledge_id, context})
      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Protocol
  def query(config, pattern, context \\ %{}) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        GenServer.call(pid, {:query, pattern, context})
      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Protocol
  def subscribe(config, pattern, handler, context \\ %{}) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        GenServer.call(pid, {:subscribe, pattern, handler, context})
      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Protocol
  def unsubscribe(config, subscription_id) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        GenServer.call(pid, {:unsubscribe, subscription_id})
      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Protocol
  def add_rule(config, rule, context \\ %{}) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        GenServer.call(pid, {:add_rule, rule, context})
      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Protocol
  def remove_rule(config, rule_id, context \\ %{}) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        GenServer.call(pid, {:remove_rule, rule_id, context})
      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Protocol
  def validate_config(config) do
    required_fields = [:backend_type, :name]

    case Enum.find(required_fields, &(not Map.has_key?(config, &1))) do
      nil -> :ok
      missing_field -> {:error, {:missing_required_field, missing_field}}
    end
  end

  @impl Protocol
  def health_check(_config) do
    :ok
  end

  @impl Protocol
  def get_backend_info(_config) do
    {:ok, %{
      backend_type: :test,
      name: :test_blackboard_backend,
      supports_persistence: false,
      supports_events: true,
      supports_rules: true,
      supports_access_control: true,
      max_knowledge_objects: :unlimited,
      features: [:configurable_responses, :knowledge_tracking, :subscription_tracking, :rule_tracking]
    }}
  end

  ## GenServer Implementation

  @doc false
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: config.name)
  end

  @impl GenServer
  def init(config) do
    state = %{
      config: config,
      knowledge_objects: %{},
      subscriptions: %{},
      rules: %{},
      knowledge_history: [],
      subscription_counter: 0,
      rule_counter: 0,
      stats: %{
        posts: 0,
        reads: 0,
        updates: 0,
        removes: 0,
        queries: 0,
        subscriptions: 0,
        rules: 0,
        errors: 0
      }
    }

    Logger.debug("Test blackboard backend started", %{name: config.name})
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:post, knowledge, context}, _from, state) do
    # Check for configured response
    response = case get_configured_response(:post, knowledge, state.config) do
      nil ->
        # Default success response
        case normalize_knowledge(knowledge) do
          {:ok, knowledge_obj} ->
            knowledge_id = knowledge_obj.id || generate_knowledge_id()
            final_knowledge = %{knowledge_obj | id: knowledge_id}

            # Track the knowledge if enabled
            new_state = if Map.get(state.config, :track_knowledge, true) do
              %{state |
                knowledge_objects: Map.put(state.knowledge_objects, knowledge_id, final_knowledge),
                knowledge_history: [final_knowledge | state.knowledge_history],
                stats: update_stats(state.stats, :posts)
              }
            else
              %{state | stats: update_stats(state.stats, :posts)}
            end

            # Simulate rule triggering
            trigger_mock_rules(final_knowledge, state)

            {{:ok, knowledge_id}, new_state}

          {:error, reason} ->
            {{:error, reason}, %{state | stats: update_stats(state.stats, :errors)}}
        end

      configured_response ->
        {configured_response, %{state | stats: update_stats(state.stats, :errors)}}
    end

    case response do
      {{:ok, knowledge_id}, new_state} ->
        {:reply, {:ok, knowledge_id}, new_state}
      {{:error, reason}, new_state} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:read, knowledge_id, context}, _from, state) do
    case get_configured_response(:read, knowledge_id, state.config) do
      nil ->
        case Map.get(state.knowledge_objects, knowledge_id) do
          nil ->
            new_stats = update_stats(state.stats, :errors)
            {:reply, {:error, :not_found}, %{state | stats: new_stats}}

          knowledge_obj ->
            # Simulate access control check
            case simulate_access_control(context, :read, knowledge_obj, state.config) do
              :ok ->
                new_stats = update_stats(state.stats, :reads)
                {:reply, {:ok, knowledge_obj}, %{state | stats: new_stats}}

              {:error, reason} ->
                new_stats = update_stats(state.stats, :errors)
                {:reply, {:error, reason}, %{state | stats: new_stats}}
            end
        end

      configured_response ->
        new_stats = if match?({:ok, _}, configured_response) do
          update_stats(state.stats, :reads)
        else
          update_stats(state.stats, :errors)
        end
        {:reply, configured_response, %{state | stats: new_stats}}
    end
  end

  @impl GenServer
  def handle_call({:update, knowledge_id, updates, context}, _from, state) do
    case get_configured_response(:update, knowledge_id, state.config) do
      nil ->
        case Map.get(state.knowledge_objects, knowledge_id) do
          nil ->
            new_stats = update_stats(state.stats, :errors)
            {:reply, {:error, :not_found}, %{state | stats: new_stats}}

          current_obj ->
            case simulate_access_control(context, :write, current_obj, state.config) do
              :ok ->
                case KnowledgeObject.update(current_obj, updates) do
                  {:ok, updated_obj} ->
                    new_knowledge_objects = Map.put(state.knowledge_objects, knowledge_id, updated_obj)
                    new_stats = update_stats(state.stats, :updates)

                    # Trigger mock rules
                    trigger_mock_rules(updated_obj, state)

                    {:reply, {:ok, updated_obj}, %{state |
                      knowledge_objects: new_knowledge_objects,
                      stats: new_stats
                    }}

                  {:error, reason} ->
                    new_stats = update_stats(state.stats, :errors)
                    {:reply, {:error, reason}, %{state | stats: new_stats}}
                end

              {:error, reason} ->
                new_stats = update_stats(state.stats, :errors)
                {:reply, {:error, reason}, %{state | stats: new_stats}}
            end
        end

      configured_response ->
        new_stats = if match?({:ok, _}, configured_response) do
          update_stats(state.stats, :updates)
        else
          update_stats(state.stats, :errors)
        end
        {:reply, configured_response, %{state | stats: new_stats}}
    end
  end

  @impl GenServer
  def handle_call({:remove, knowledge_id, context}, _from, state) do
    case get_configured_response(:remove, knowledge_id, state.config) do
      nil ->
        case Map.get(state.knowledge_objects, knowledge_id) do
          nil ->
            new_stats = update_stats(state.stats, :errors)
            {:reply, {:error, :not_found}, %{state | stats: new_stats}}

          knowledge_obj ->
            case simulate_access_control(context, :write, knowledge_obj, state.config) do
              :ok ->
                new_knowledge_objects = Map.delete(state.knowledge_objects, knowledge_id)
                new_stats = update_stats(state.stats, :removes)
                {:reply, :ok, %{state |
                  knowledge_objects: new_knowledge_objects,
                  stats: new_stats
                }}

              {:error, reason} ->
                new_stats = update_stats(state.stats, :errors)
                {:reply, {:error, reason}, %{state | stats: new_stats}}
            end
        end

      configured_response ->
        new_stats = if configured_response == :ok do
          update_stats(state.stats, :removes)
        else
          update_stats(state.stats, :errors)
        end
        {:reply, configured_response, %{state | stats: new_stats}}
    end
  end

  @impl GenServer
  def handle_call({:query, pattern, context}, _from, state) do
    case get_configured_response(:query, pattern, state.config) do
      nil ->
        # Simple pattern matching implementation
        matching_objects = state.knowledge_objects
        |> Map.values()
        |> Enum.filter(&match_pattern?(&1, pattern))
        |> Enum.filter(&(simulate_access_control(context, :read, &1, state.config) == :ok))

        new_stats = update_stats(state.stats, :queries)
        {:reply, {:ok, matching_objects}, %{state | stats: new_stats}}

      configured_response ->
        new_stats = if match?({:ok, _}, configured_response) do
          update_stats(state.stats, :queries)
        else
          update_stats(state.stats, :errors)
        end
        {:reply, configured_response, %{state | stats: new_stats}}
    end
  end

  @impl GenServer
  def handle_call({:subscribe, pattern, handler, context}, _from, state) do
    subscription_id = generate_subscription_id(state.subscription_counter)

    subscription = %{
      id: subscription_id,
      pattern: pattern,
      handler: handler,
      context: context,
      created_at: DateTime.utc_now()
    }

    new_subscriptions = Map.put(state.subscriptions, subscription_id, subscription)
    new_state = %{state |
      subscriptions: new_subscriptions,
      subscription_counter: state.subscription_counter + 1,
      stats: update_stats(state.stats, :subscriptions)
    }

    Logger.debug("Test subscription created", %{
      subscription_id: subscription_id,
      pattern: inspect(pattern)
    })

    {:reply, {:ok, subscription_id}, new_state}
  end

  @impl GenServer
  def handle_call({:unsubscribe, subscription_id}, _from, state) do
    case Map.get(state.subscriptions, subscription_id) do
      nil ->
        {:reply, {:error, :subscription_not_found}, state}

      _subscription ->
        new_subscriptions = Map.delete(state.subscriptions, subscription_id)
        new_state = %{state | subscriptions: new_subscriptions}

        Logger.debug("Test subscription removed", %{subscription_id: subscription_id})
        {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call({:add_rule, rule, context}, _from, state) do
    rule_id = generate_rule_id(state.rule_counter)

    rule_obj = Map.merge(rule, %{
      id: rule_id,
      context: context,
      created_at: DateTime.utc_now()
    })

    new_rules = Map.put(state.rules, rule_id, rule_obj)
    new_state = %{state |
      rules: new_rules,
      rule_counter: state.rule_counter + 1,
      stats: update_stats(state.stats, :rules)
    }

    Logger.debug("Test rule added", %{rule_id: rule_id})
    {:reply, {:ok, rule_id}, new_state}
  end

  @impl GenServer
  def handle_call({:remove_rule, rule_id, _context}, _from, state) do
    case Map.get(state.rules, rule_id) do
      nil ->
        {:reply, {:error, :rule_not_found}, state}

      _rule ->
        new_rules = Map.delete(state.rules, rule_id)
        new_state = %{state | rules: new_rules}

        Logger.debug("Test rule removed", %{rule_id: rule_id})
        {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call(:get_knowledge_objects, _from, state) do
    {:reply, state.knowledge_objects, state}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl GenServer
  def handle_call(:clear_all_data, _from, state) do
    new_state = %{state |
      knowledge_objects: %{},
      subscriptions: %{},
      rules: %{},
      knowledge_history: [],
      stats: %{
        posts: 0,
        reads: 0,
        updates: 0,
        removes: 0,
        queries: 0,
        subscriptions: 0,
        rules: 0,
        errors: 0
      }
    }
    {:reply, :ok, new_state}
  end

  ## Test Helper Functions

  @doc """
  Get all knowledge objects from the test backend.

  Useful for verifying knowledge storage in tests.
  """
  @spec get_knowledge_objects(Protocol.config()) :: {:ok, map()} | {:error, term()}
  def get_knowledge_objects(config) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        {:ok, GenServer.call(pid, :get_knowledge_objects)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get statistics from the test backend.
  """
  @spec get_stats(Protocol.config()) :: {:ok, map()} | {:error, term()}
  def get_stats(config) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        {:ok, GenServer.call(pid, :get_stats)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Clear all data from the test backend.

  Useful for resetting state between tests.
  """
  @spec clear_all_data(Protocol.config()) :: :ok | {:error, term()}
  def clear_all_data(config) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        GenServer.call(pid, :clear_all_data)
      {:error, reason} ->
        {:error, reason}
    end
  end

  ## Private Implementation

  @spec get_or_start_backend(Protocol.config()) :: {:ok, pid()} | {:error, term()}
  defp get_or_start_backend(config) do
    case Process.whereis(config.name) do
      nil ->
        case start_link(config) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          {:error, reason} -> {:error, reason}
        end
      pid ->
        {:ok, pid}
    end
  end

  @spec get_configured_response(atom(), term(), Protocol.config()) :: term() | nil
  defp get_configured_response(operation, subject, config) do
    responses = Map.get(config, :responses, %{})

    # Try operation-specific response first
    operation_key = "#{operation}_#{inspect(subject)}"
    case Map.get(responses, operation_key) do
      nil ->
        # Try general subject response
        subject_key = to_string(subject)
        Map.get(responses, subject_key)

      response ->
        response
    end
  end

  @spec normalize_knowledge(KnowledgeObject.t() | map()) :: {:ok, KnowledgeObject.t()} | {:error, term()}
  defp normalize_knowledge(%KnowledgeObject{} = knowledge_obj), do: {:ok, knowledge_obj}
  defp normalize_knowledge(knowledge) when is_map(knowledge) do
    KnowledgeObject.new(knowledge)
  end
  defp normalize_knowledge(knowledge), do: {:error, {:invalid_knowledge, knowledge}}

  @spec match_pattern?(KnowledgeObject.t(), map()) :: boolean()
  defp match_pattern?(knowledge_obj, pattern) do
    Enum.all?(pattern, fn
      {:category, category} -> knowledge_obj.category == category
      {:pattern, content_pattern} when is_map(content_pattern) ->
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

  @spec simulate_access_control(AccessControl.access_context(), AccessControl.permission(), KnowledgeObject.t(), Protocol.config()) ::
    :ok | {:error, term()}
  defp simulate_access_control(context, _operation, _knowledge_obj, config) do
    # Simple simulation - check if access control is disabled or if context has agent_id
    if Map.get(config, :enable_access_control, true) do
      case Map.get(context, :agent_id) do
        nil -> {:error, :access_denied}
        _agent_id -> :ok
      end
    else
      :ok
    end
  end

  @spec trigger_mock_rules(KnowledgeObject.t(), test_state()) :: :ok
  defp trigger_mock_rules(knowledge_obj, state) do
    # Simulate rule triggering for testing
    matching_rules = state.rules
    |> Map.values()
    |> Enum.filter(fn rule ->
      pattern = Map.get(rule, :pattern, %{})
      match_pattern?(knowledge_obj, pattern)
    end)

    Enum.each(matching_rules, fn rule ->
      Logger.debug("Mock rule triggered", %{
        rule_id: rule.id,
        knowledge_id: knowledge_obj.id
      })
    end)

    :ok
  end

  @spec update_stats(map(), atom()) :: map()
  defp update_stats(stats, key) do
    Map.update(stats, key, 1, &(&1 + 1))
  end

  @spec generate_knowledge_id() :: String.t()
  defp generate_knowledge_id do
    "test_knowledge_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  @spec generate_subscription_id(non_neg_integer()) :: String.t()
  defp generate_subscription_id(counter) do
    "test_sub_" <> Integer.to_string(counter) <> "_" <>
      (:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower))
  end

  @spec generate_rule_id(non_neg_integer()) :: String.t()
  defp generate_rule_id(counter) do
    "test_rule_" <> Integer.to_string(counter) <> "_" <>
      (:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower))
  end
end
