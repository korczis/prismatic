defmodule Prismatic.Event.Impl.PhoenixPubSubBackend do
  @moduledoc """
  Phoenix PubSub backend implementation for the Prismatic Event System.

  This backend provides distributed pub/sub capabilities using Phoenix.PubSub,
  making it suitable for multi-node deployments and web applications. It leverages
  Phoenix's battle-tested distributed messaging infrastructure.

  ## Features

  - **Distributed Events**: Automatic distribution across connected nodes
  - **Web Integration**: Seamless integration with Phoenix web applications
  - **Pattern Matching**: Client-side pattern matching for efficiency
  - **Scalable**: Handles thousands of concurrent subscribers
  - **Fault Tolerant**: Built-in supervision and recovery
  - **Adapter Support**: Multiple PubSub adapters (Redis, PG2, etc.)

  ## Architecture

  The Phoenix PubSub backend uses Phoenix.PubSub for message distribution:

  - **Topic Mapping**: Event types are mapped to PubSub topics
  - **Pattern Translation**: Patterns are converted to topic subscriptions
  - **Local Filtering**: Additional filtering happens at subscribers
  - **Metadata Preservation**: Full event metadata is maintained

  ## Configuration

      %{
        backend_type: :phoenix_pubsub,
        name: :phoenix_event_system,
        pubsub_name: MyApp.PubSub,
        topic_prefix: "events",
        enable_pattern_topics: true,
        max_subscriptions_per_pattern: 1000
      }

  ## Usage

  Ideal for Phoenix applications and distributed systems:

      {:ok, config} = Protocol.create_config(:phoenix_pubsub, %{
        pubsub_name: MyApp.PubSub,
        topic_prefix: "app_events"
      })

      {:ok, event_id} = Protocol.publish(config, event)

  ## Topic Strategy

  Events are published to topics using different strategies:

  - **Exact Topics**: `events:agent.alice.message`
  - **Wildcard Topics**: `events:agent.*` (for pattern subscriptions)
  - **Hierarchy Topics**: `events:agent`, `events:agent.alice` (for `**` patterns)
  """

  @behaviour Prismatic.Event.Protocol

  use GenServer
  require Logger

  alias Prismatic.Event.{Protocol, Pattern}

  @type backend_state :: %{
    config: Protocol.config(),
    pubsub_name: atom(),
    topic_prefix: String.t(),
    local_subscriptions: %{Protocol.subscription_id() => subscription_info()},
    subscription_counter: non_neg_integer()
  }

  @type subscription_info :: %{
    id: Protocol.subscription_id(),
    pattern: String.t(),
    handler: Protocol.event_handler(),
    topics: [String.t()],
    metadata: map()
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
  def replay(_config, _options) do
    # Phoenix PubSub doesn't provide message history
    {:error, :replay_not_supported}
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
      nil ->
        # Check for PubSub name
        pubsub_name = Map.get(config, :pubsub_name)
        if pubsub_name && is_atom(pubsub_name) do
          # Verify PubSub is running
          case Process.whereis(pubsub_name) do
            nil -> {:error, {:pubsub_not_running, pubsub_name}}
            _pid -> :ok
          end
        else
          {:error, :missing_pubsub_name}
        end
      missing_field ->
        {:error, {:missing_required_field, missing_field}}
    end
  end

  @impl Protocol
  def health_check(config) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        if Process.alive?(pid) do
          # Also check PubSub health
          pubsub_name = Map.get(config, :pubsub_name)
          case Process.whereis(pubsub_name) do
            nil -> {:error, {:pubsub_not_running, pubsub_name}}
            _pid -> :ok
          end
        else
          {:error, :backend_process_dead}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Protocol
  def get_backend_info(config) do
    case get_or_start_backend(config) do
      {:ok, pid} ->
        {:ok, GenServer.call(pid, :get_backend_info)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  ## GenServer Implementation

  @doc false
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: config.name)
  end

  @impl GenServer
  def init(config) do
    pubsub_name = Map.get(config, :pubsub_name)
    topic_prefix = Map.get(config, :topic_prefix, "events")

    state = %{
      config: config,
      pubsub_name: pubsub_name,
      topic_prefix: topic_prefix,
      local_subscriptions: %{},
      subscription_counter: 1
    }

    Logger.info("Phoenix PubSub backend started", %{
      name: config.name,
      pubsub_name: pubsub_name,
      topic_prefix: topic_prefix
    })

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:publish, event}, _from, state) do
    try do
      # Generate event ID
      event_id = generate_event_id()

      # Enrich event with metadata
      enriched_event = enrich_event(event, event_id)

      # Determine topics to publish to
      topics = generate_topics_for_event(enriched_event.type, state)

      # Publish to all relevant topics
      Enum.each(topics, fn topic ->
        Phoenix.PubSub.broadcast(state.pubsub_name, topic, {:event, enriched_event})
      end)

      Logger.debug("Event published to Phoenix PubSub", %{
        event_id: event_id,
        event_type: enriched_event.type,
        topics: topics
      })

      {:reply, {:ok, event_id}, state}

    rescue
      error ->
        Logger.error("Event publication failed", %{
          error: inspect(error),
          event_type: event.type
        })
        {:reply, {:error, {:publication_failed, error}}, state}
    end
  end

  @impl GenServer
  def handle_call({:subscribe, pattern, handler, options}, _from, state) do
    try do
      # Generate subscription ID
      subscription_id = generate_subscription_id(state.subscription_counter)

      # Determine topics to subscribe to
      topics = generate_topics_for_pattern(pattern, state)

      # Subscribe to topics
      Enum.each(topics, fn topic ->
        Phoenix.PubSub.subscribe(state.pubsub_name, topic)
      end)

      # Store subscription info
      subscription_info = %{
        id: subscription_id,
        pattern: pattern,
        handler: handler,
        topics: topics,
        metadata: Map.merge(%{
          created_at: DateTime.utc_now(),
          backend: :phoenix_pubsub
        }, options)
      }

      new_subscriptions = Map.put(state.local_subscriptions, subscription_id, subscription_info)
      new_state = %{state |
        local_subscriptions: new_subscriptions,
        subscription_counter: state.subscription_counter + 1
      }

      Logger.debug("Phoenix PubSub subscription created", %{
        subscription_id: subscription_id,
        pattern: pattern,
        topics: topics
      })

      {:reply, {:ok, subscription_id}, new_state}

    rescue
      error ->
        Logger.error("Subscription failed", %{
          error: inspect(error),
          pattern: pattern
        })
        {:reply, {:error, {:subscription_failed, error}}, state}
    end
  end

  @impl GenServer
  def handle_call({:unsubscribe, subscription_id}, _from, state) do
    case Map.get(state.local_subscriptions, subscription_id) do
      nil ->
        {:reply, {:error, :subscription_not_found}, state}

      subscription_info ->
        # Unsubscribe from topics
        Enum.each(subscription_info.topics, fn topic ->
          Phoenix.PubSub.unsubscribe(state.pubsub_name, topic)
        end)

        # Remove from local subscriptions
        new_subscriptions = Map.delete(state.local_subscriptions, subscription_id)
        new_state = %{state | local_subscriptions: new_subscriptions}

        Logger.debug("Phoenix PubSub subscription removed", %{
          subscription_id: subscription_id,
          topics: subscription_info.topics
        })

        {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call(:list_subscriptions, _from, state) do
    subscriptions = state.local_subscriptions
    |> Map.values()
    |> Enum.map(fn subscription_info ->
      %{
        id: subscription_info.id,
        pattern: subscription_info.pattern,
        handler: subscription_info.handler,
        metadata: subscription_info.metadata
      }
    end)

    {:reply, {:ok, subscriptions}, state}
  end

  @impl GenServer
  def handle_call(:get_backend_info, _from, state) do
    info = %{
      backend_type: :phoenix_pubsub,
      name: state.config.name,
      supports_sourcing: false,
      supports_patterns: true,
      max_subscribers: :unlimited,
      max_events: :unlimited,
      features: [:distributed, :scalable, :phoenix_integration],
      pubsub_name: state.pubsub_name,
      topic_prefix: state.topic_prefix,
      active_subscriptions: map_size(state.local_subscriptions)
    }

    {:reply, info, state}
  end

  @impl GenServer
  def handle_info({:event, event}, state) do
    # Handle incoming events from PubSub
    matching_subscriptions = find_matching_local_subscriptions(event.type, state.local_subscriptions)

    # Deliver to matching handlers
    Enum.each(matching_subscriptions, fn subscription_info ->
      Task.start(fn ->
        try do
          case subscription_info.handler.(event) do
            :ok -> :ok
            {:error, reason} ->
              Logger.warning("Event handler error", %{
                subscription_id: subscription_info.id,
                event_type: event.type,
                reason: reason
              })
          end
        rescue
          error ->
            Logger.error("Event handler exception", %{
              subscription_id: subscription_info.id,
              event_type: event.type,
              error: inspect(error)
            })
        end
      end)
    end)

    {:noreply, state}
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

  @spec enrich_event(Protocol.event(), Protocol.event_id()) :: Protocol.event()
  defp enrich_event(event, event_id) do
    base_metadata = %{
      event_id: event_id,
      timestamp: DateTime.utc_now(),
      source: "phoenix_pubsub_backend",
      correlation_id: nil,
      causation_id: nil,
      version: 1
    }

    enriched_metadata = Map.merge(base_metadata, Map.get(event, :metadata, %{}))
    Map.put(event, :metadata, enriched_metadata)
  end

  @spec generate_event_id() :: String.t()
  defp generate_event_id do
    "pps_evt_" <> (:crypto.strong_rand_bytes(12) |> Base.encode16(case: :lower))
  end

  @spec generate_subscription_id(non_neg_integer()) :: String.t()
  defp generate_subscription_id(counter) do
    "pps_sub_" <> Integer.to_string(counter) <> "_" <>
      (:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower))
  end

  @spec generate_topics_for_event(String.t(), backend_state()) :: [String.t()]
  defp generate_topics_for_event(event_type, state) do
    base_topic = "#{state.topic_prefix}:#{event_type}"

    # Generate hierarchical topics for wildcard subscriptions
    segments = String.split(event_type, ".")
    hierarchical_topics = generate_hierarchical_topics(segments, state.topic_prefix)

    [base_topic | hierarchical_topics]
    |> Enum.uniq()
  end

  @spec generate_topics_for_pattern(String.t(), backend_state()) :: [String.t()]
  defp generate_topics_for_pattern(pattern, state) do
    cond do
      Pattern.is_exact_match?(pattern) ->
        # Exact match - subscribe to specific topic
        ["#{state.topic_prefix}:#{pattern}"]

      String.contains?(pattern, "**") ->
        # Multi-segment wildcard - subscribe to hierarchical topics
        base_segments = pattern
        |> String.replace("**", "")
        |> String.split(".")
        |> Enum.reject(&(&1 == ""))

        if Enum.empty?(base_segments) do
          # Subscribe to all events
          ["#{state.topic_prefix}:*"]
        else
          base_path = Enum.join(base_segments, ".")
          generate_hierarchical_topics(String.split(base_path, "."), state.topic_prefix)
        end

      String.contains?(pattern, "*") ->
        # Single wildcard - generate specific topic patterns
        generate_wildcard_topics(pattern, state.topic_prefix)

      true ->
        # No wildcards - exact match
        ["#{state.topic_prefix}:#{pattern}"]
    end
  end

  @spec generate_hierarchical_topics([String.t()], String.t()) :: [String.t()]
  defp generate_hierarchical_topics(segments, prefix) do
    segments
    |> Enum.with_index()
    |> Enum.map(fn {_segment, index} ->
      partial_path = segments
      |> Enum.take(index + 1)
      |> Enum.join(".")
      "#{prefix}:#{partial_path}"
    end)
  end

  @spec generate_wildcard_topics(String.t(), String.t()) :: [String.t()]
  defp generate_wildcard_topics(pattern, prefix) do
    # For simple patterns, we might need to subscribe to multiple topics
    # This is a simplified implementation
    ["#{prefix}:#{pattern}"]
  end

  @spec find_matching_local_subscriptions(String.t(), map()) :: [subscription_info()]
  defp find_matching_local_subscriptions(event_type, subscriptions) do
    subscriptions
    |> Map.values()
    |> Enum.filter(fn subscription_info ->
      Pattern.match?(subscription_info.pattern, event_type)
    end)
  end
end
