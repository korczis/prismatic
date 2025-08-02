defmodule Prismatic.Event.Impl.TestBackend do
  @moduledoc """
  Test backend implementation for the Prismatic Event System.

  This backend provides a simple in-memory implementation suitable for
  testing and development. It supports all protocol operations with
  configurable responses for testing error conditions and edge cases.

  ## Features

  - **Configurable Responses**: Pre-configure responses for specific events
  - **Event History**: Track all published events for verification
  - **Subscription Tracking**: Monitor subscription lifecycle
  - **Error Simulation**: Simulate various failure conditions
  - **No Persistence**: All data is lost when the process stops

  ## Configuration

  The test backend accepts these configuration options:

      %{
        backend_type: :test,
        name: :test_event_system,
        responses: %{
          "error_event" => {:error, :test_error},
          "timeout_event" => {:error, :timeout}
        },
        default_response: {:ok, "test_response"},
        track_events: true,
        track_subscriptions: true
      }

  ## Usage

  Primarily used in tests and development:

      {:ok, config} = Protocol.create_config(:test, %{
        responses: %{"test.error" => {:error, :simulated_failure}}
      })

      {:ok, event_id} = Protocol.publish(config, %{
        type: "test.message",
        payload: %{data: "hello"}
      })
  """

  @behaviour Prismatic.Event.Protocol

  use GenServer
  require Logger

  alias Prismatic.Event.Protocol

  @type test_state :: %{
    config: Protocol.config(),
    published_events: [Protocol.event()],
    subscriptions: %{Protocol.subscription_id() => Protocol.subscription()},
    event_history: [Protocol.event()],
    subscription_counter: non_neg_integer()
  }

  ## Protocol Implementation

  @impl Protocol
  def publish(config, event) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        GenServer.call(pid, {:publish, event})
      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Protocol
  def subscribe(config, pattern, handler, options \\ %{}) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        GenServer.call(pid, {:subscribe, pattern, handler, options})
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
  def replay(config, options \\ %{}) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        GenServer.call(pid, {:replay, options})
      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Protocol
  def list_subscriptions(config) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        GenServer.call(pid, :list_subscriptions)
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
      name: :test_backend,
      supports_sourcing: true,
      supports_patterns: true,
      max_subscribers: :unlimited,
      max_events: :unlimited,
      features: [:configurable_responses, :event_tracking, :subscription_tracking]
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
      published_events: [],
      subscriptions: %{},
      event_history: [],
      subscription_counter: 0
    }

    Logger.debug("Test backend started", %{name: config.name})
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:publish, event}, _from, state) do
    # Check for configured response
    response = case get_configured_response(event, state.config) do
      nil ->
        # Default success response
        event_id = generate_event_id()
        new_event = enrich_event(event, event_id)

        # Track the event if enabled
        new_state = if Map.get(state.config, :track_events, true) do
          %{state |
            published_events: [new_event | state.published_events],
            event_history: [new_event | state.event_history]
          }
        else
          state
        end

        # Simulate event delivery to subscribers
        deliver_to_subscribers(new_event, state.subscriptions)

        {{:ok, event_id}, new_state}

      configured_response ->
        {configured_response, state}
    end

    case response do
      {{:ok, event_id}, new_state} ->
        {:reply, {:ok, event_id}, new_state}
      {{:error, reason}, new_state} ->
        {:reply, {:error, reason}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:subscribe, pattern, handler, options}, _from, state) do
    subscription_id = generate_subscription_id(state.subscription_counter)

    subscription = %{
      id: subscription_id,
      pattern: pattern,
      handler: handler,
      metadata: Map.merge(%{
        created_at: DateTime.utc_now(),
        backend: :test
      }, options)
    }

    new_subscriptions = Map.put(state.subscriptions, subscription_id, subscription)
    new_state = %{state |
      subscriptions: new_subscriptions,
      subscription_counter: state.subscription_counter + 1
    }

    Logger.debug("Test subscription created", %{
      subscription_id: subscription_id,
      pattern: pattern
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
  def handle_call({:replay, options}, _from, state) do
    # Apply filtering based on options
    filtered_events = filter_events_for_replay(state.event_history, options)

    # Apply limit if specified
    limited_events = case Map.get(options, :limit) do
      nil -> filtered_events
      limit -> Enum.take(filtered_events, limit)
    end

    {:reply, {:ok, limited_events}, state}
  end

  @impl GenServer
  def handle_call(:list_subscriptions, _from, state) do
    subscriptions = Map.values(state.subscriptions)
    {:reply, {:ok, subscriptions}, state}
  end

  @impl GenServer
  def handle_call(:get_published_events, _from, state) do
    {:reply, state.published_events, state}
  end

  @impl GenServer
  def handle_call(:clear_published_events, _from, state) do
    new_state = %{state | published_events: [], event_history: []}
    {:reply, :ok, new_state}
  end

  ## Test Helper Functions

  @doc """
  Get all published events from the test backend.

  Useful for verifying event publication in tests.

  ## Parameters

  - `config` - Test backend configuration

  ## Returns

  - `{:ok, events}` - List of published events
  - `{:error, reason}` - Failed to get events

  ## Examples

      iex> {:ok, events} = Prismatic.Event.Impl.TestBackend.get_published_events(config)
      iex> length(events)
      0
  """
  @spec get_published_events(Protocol.config()) :: {:ok, [Protocol.event()]} | {:error, term()}
  def get_published_events(config) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        {:ok, GenServer.call(pid, :get_published_events)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Clear all published events from the test backend.

  Useful for resetting state between tests.

  ## Parameters

  - `config` - Test backend configuration

  ## Returns

  - `:ok` - Events cleared successfully
  - `{:error, reason}` - Failed to clear events
  """
  @spec clear_published_events(Protocol.config()) :: :ok | {:error, term()}
  def clear_published_events(config) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        GenServer.call(pid, :clear_published_events)
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

  @spec get_configured_response(Protocol.event(), Protocol.config()) ::
    {:ok, Protocol.event_id()} | {:error, term()} | nil
  defp get_configured_response(event, config) do
    responses = Map.get(config, :responses, %{})
    Map.get(responses, event.type)
  end

  @spec enrich_event(Protocol.event(), Protocol.event_id()) :: Protocol.event()
  defp enrich_event(event, event_id) do
    base_metadata = %{
      event_id: event_id,
      timestamp: DateTime.utc_now(),
      source: "test_backend",
      correlation_id: nil,
      causation_id: nil,
      version: 1
    }

    enriched_metadata = Map.merge(base_metadata, Map.get(event, :metadata, %{}))
    Map.put(event, :metadata, enriched_metadata)
  end

  @spec generate_event_id() :: String.t()
  defp generate_event_id do
    "test_event_" <> (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  @spec generate_subscription_id(non_neg_integer()) :: String.t()
  defp generate_subscription_id(counter) do
    "test_sub_" <> Integer.to_string(counter) <> "_" <>
      (:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower))
  end

  @spec deliver_to_subscribers(Protocol.event(), map()) :: :ok
  defp deliver_to_subscribers(event, subscriptions) do
    # Simple pattern matching for test backend
    Enum.each(subscriptions, fn {_id, subscription} ->
      if pattern_matches?(subscription.pattern, event.type) do
        try do
          subscription.handler.(event)
        rescue
          error ->
            Logger.warning("Test handler error", %{
              error: inspect(error),
              event_type: event.type,
              subscription_id: subscription.id
            })
        end
      end
    end)
  end

  @spec pattern_matches?(String.t(), String.t()) :: boolean()
  defp pattern_matches?(pattern, event_type) do
    # Simple wildcard matching for test backend
    cond do
      pattern == event_type -> true
      String.ends_with?(pattern, ".*") ->
        prefix = String.trim_trailing(pattern, ".*")
        String.starts_with?(event_type, prefix <> ".")
      String.starts_with?(pattern, "*.") ->
        suffix = String.trim_leading(pattern, "*.")
        String.ends_with?(event_type, "." <> suffix)
      pattern == "*" -> true
      true -> false
    end
  end

  @spec filter_events_for_replay([Protocol.event()], map()) :: [Protocol.event()]
  defp filter_events_for_replay(events, options) do
    events
    |> filter_by_patterns(Map.get(options, :patterns))
    |> filter_by_time_range(Map.get(options, :from), Map.get(options, :to))
    |> maybe_reverse(Map.get(options, :order, :desc))
  end

  @spec filter_by_patterns([Protocol.event()], [String.t()] | nil) :: [Protocol.event()]
  defp filter_by_patterns(events, nil), do: events
  defp filter_by_patterns(events, patterns) do
    Enum.filter(events, fn event ->
      Enum.any?(patterns, &pattern_matches?(&1, event.type))
    end)
  end

  @spec filter_by_time_range([Protocol.event()], DateTime.t() | nil, DateTime.t() | nil) :: [Protocol.event()]
  defp filter_by_time_range(events, nil, nil), do: events
  defp filter_by_time_range(events, from_time, to_time) do
    Enum.filter(events, fn event ->
      timestamp = event.metadata.timestamp

      from_check = if from_time, do: DateTime.compare(timestamp, from_time) != :lt, else: true
      to_check = if to_time, do: DateTime.compare(timestamp, to_time) != :gt, else: true

      from_check and to_check
    end)
  end

  @spec maybe_reverse([Protocol.event()], :asc | :desc) :: [Protocol.event()]
  defp maybe_reverse(events, :asc), do: Enum.reverse(events)
  defp maybe_reverse(events, :desc), do: events
end
