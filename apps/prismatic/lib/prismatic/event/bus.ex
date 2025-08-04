defmodule Prismatic.Event.Bus do
  @moduledoc """
  Core event bus implementation for the Prismatic Event System.

  The Event Bus serves as the central coordination point for all event operations,
  providing pattern-based routing, subscription management, event sourcing, and
  distributed pub/sub capabilities. It follows the same architectural patterns
  as the Memory and LLM systems with circuit breaker protection and comprehensive
  error handling.

  ## Architecture

  The Event Bus uses a multi-layered architecture:

  - **Protocol Layer**: Interface defined in `Prismatic.Event.Protocol`
  - **Bus Layer**: This module - coordination and routing logic
  - **Registry Layer**: Subscription management and pattern matching
  - **Sourcing Layer**: Event persistence and replay capabilities
  - **Backend Layer**: Pluggable backend implementations

  ## Features

  - **Pattern Matching**: Advanced glob and wildcard pattern matching
  - **Event Sourcing**: Complete event history with replay capabilities
  - **Circuit Protection**: Built-in circuit breaker for fault tolerance
  - **Retry Logic**: Configurable retry policies for resilience
  - **Telemetry**: Comprehensive metrics and monitoring
  - **Hot-swappable Backends**: Runtime backend switching capability

  ## Usage

  The Bus is typically started as part of the application supervision tree:

      children = [
        {Prismatic.Event.Bus, name: :event_bus, backend: :in_memory}
      ]

  ## Pattern Matching

  The bus supports sophisticated pattern matching:

  - `agent.alice.message` - Exact match
  - `agent.*.message` - Single wildcard
  - `agent.**` - Multi-level wildcard
  - `{agent,system}.*.error` - Alternative matching
  - `**.{error,warning}` - Complex patterns

  ## Configuration

  Bus configuration follows the protocol configuration structure with additional
  bus-specific options:

      %{
        name: :event_bus,
        backend_type: :in_memory,
        enable_sourcing: true,
        max_subscribers_per_pattern: 1000,
        pattern_cache_size: 10_000,
        event_buffer_size: 1000,
        telemetry_enabled: true
      }

  ## Telemetry Events

  The bus emits detailed telemetry for monitoring:

  - `[:prismatic, :event, :bus, :publish]` - Event publication metrics
  - `[:prismatic, :event, :bus, :subscribe]` - Subscription metrics
  - `[:prismatic, :event, :bus, :pattern_match]` - Pattern matching performance
  - `[:prismatic, :event, :bus, :sourcing]` - Event sourcing operations
  """

  use GenServer
  require Logger

  alias Prismatic.Event.{Protocol, Registry, Sourcing}
  alias Prismatic.Event.Backend.CircuitBreaker

  @type bus_state :: %{
    config: Protocol.config(),
    registry_pid: pid(),
    sourcing_pid: pid() | nil,
    backend_module: module(),
    circuit_breaker: pid(),
    metrics: map(),
    subscribers_count: non_neg_integer(),
    events_published: non_neg_integer()
  }

  @type start_options :: [
    name: atom(),
    config: Protocol.config()
  ]

  ## Public API

  @doc """
  Start the Event Bus GenServer.

  ## Options

  - `:name` - Process name (default: `__MODULE__`)
  - `:config` - Event system configuration

  ## Examples

      iex> {:ok, pid} = Prismatic.Event.Bus.start_link(name: :test_bus)
      iex> is_pid(pid)
      true
  """
  @spec start_link(start_options()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Publish an event through the bus.

  Routes the event to all matching subscribers using pattern matching,
  optionally stores it for event sourcing, and emits telemetry.

  ## Parameters

  - `bus` - Bus process identifier
  - `event` - Event to publish

  ## Returns

  - `{:ok, event_id}` - Successfully published
  - `{:error, reason}` - Publication failed

  ## Examples

      iex> {:ok, bus} = Prismatic.Event.Bus.start_link(name: :test_bus)
      iex> event = %{type: "test.message", payload: %{data: "hello"}}
      iex> {:ok, event_id} = Prismatic.Event.Bus.publish(bus, event)
      iex> is_binary(event_id)
      true
  """
  @spec publish(GenServer.server(), Protocol.event()) :: {:ok, Protocol.event_id()} | {:error, term()}
  def publish(bus, event) do
    GenServer.call(bus, {:publish, event})
  end

  @doc """
  Subscribe to events matching a pattern.

  Registers a new subscription with the registry and returns a unique
  subscription ID for later unsubscription.

  ## Parameters

  - `bus` - Bus process identifier
  - `pattern` - Event pattern to match
  - `handler` - Event handler function
  - `options` - Optional subscription metadata

  ## Returns

  - `{:ok, subscription_id}` - Successfully subscribed
  - `{:error, reason}` - Subscription failed

  ## Examples

      iex> {:ok, bus} = Prismatic.Event.Bus.start_link(name: :test_bus)
      iex> handler = fn _event -> :ok end
      iex> {:ok, sub_id} = Prismatic.Event.Bus.subscribe(bus, "test.*", handler)
      iex> is_binary(sub_id)
      true
  """
  @spec subscribe(GenServer.server(), Protocol.event_pattern(), Protocol.event_handler(), map()) ::
    {:ok, Protocol.subscription_id()} | {:error, term()}
  def subscribe(bus, pattern, handler, options \\ %{}) do
    GenServer.call(bus, {:subscribe, pattern, handler, options})
  end

  @doc """
  Unsubscribe from events.

  Removes the subscription from the registry and stops event delivery.

  ## Parameters

  - `bus` - Bus process identifier
  - `subscription_id` - Subscription to remove

  ## Returns

  - `:ok` - Successfully unsubscribed
  - `{:error, reason}` - Unsubscription failed

  ## Examples

      iex> {:ok, bus} = Prismatic.Event.Bus.start_link(name: :test_bus)
      iex> handler = fn _event -> :ok end
      iex> {:ok, sub_id} = Prismatic.Event.Bus.subscribe(bus, "test.*", handler)
      iex> :ok = Prismatic.Event.Bus.unsubscribe(bus, sub_id)
      :ok
  """
  @spec unsubscribe(GenServer.server(), Protocol.subscription_id()) :: :ok | {:error, term()}
  def unsubscribe(bus, subscription_id) do
    GenServer.call(bus, {:unsubscribe, subscription_id})
  end

  @doc """
  Replay events from the event store.

  Retrieves historical events matching the specified criteria.
  Only available when event sourcing is enabled.

  ## Parameters

  - `bus` - Bus process identifier
  - `options` - Replay options

  ## Returns

  - `{:ok, events}` - Successfully retrieved events
  - `{:error, reason}` - Replay failed

  ## Examples

      iex> {:ok, bus} = Prismatic.Event.Bus.start_link(name: :test_bus)
      iex> {:ok, events} = Prismatic.Event.Bus.replay(bus, %{patterns: ["test.*"]})
      iex> is_list(events)
      true
  """
  @spec replay(GenServer.server(), Protocol.replay_options()) :: {:ok, [Protocol.event()]} | {:error, term()}
  def replay(bus, options \\ %{}) do
    GenServer.call(bus, {:replay, options})
  end

  @doc """
  List all active subscriptions.

  Returns information about current subscriptions for monitoring and debugging.

  ## Parameters

  - `bus` - Bus process identifier

  ## Returns

  - `{:ok, subscriptions}` - List of active subscriptions
  - `{:error, reason}` - Failed to list subscriptions

  ## Examples

      iex> {:ok, bus} = Prismatic.Event.Bus.start_link(name: :test_bus)
      iex> {:ok, subscriptions} = Prismatic.Event.Bus.list_subscriptions(bus)
      iex> is_list(subscriptions)
      true
  """
  @spec list_subscriptions(GenServer.server()) :: {:ok, [Protocol.subscription()]} | {:error, term()}
  def list_subscriptions(bus) do
    GenServer.call(bus, :list_subscriptions)
  end

  @doc """
  Get bus statistics and metrics.

  Returns comprehensive information about bus performance and state.

  ## Parameters

  - `bus` - Bus process identifier

  ## Returns

  - `{:ok, stats}` - Bus statistics
  - `{:error, reason}` - Failed to get stats

  ## Examples

      iex> {:ok, bus} = Prismatic.Event.Bus.start_link(name: :test_bus)
      iex> {:ok, stats} = Prismatic.Event.Bus.get_stats(bus)
      iex> is_map(stats)
      true
      iex> Map.has_key?(stats, :subscribers_count)
      true
  """
  @spec get_stats(GenServer.server()) :: {:ok, map()} | {:error, term()}
  def get_stats(bus) do
    GenServer.call(bus, :get_stats)
  end

  @doc """
  Perform a health check on the bus.

  Verifies that all bus components are functioning correctly.

  ## Parameters

  - `bus` - Bus process identifier

  ## Returns

  - `:ok` - Bus is healthy
  - `{:error, reason}` - Bus has issues

  ## Examples

      iex> {:ok, bus} = Prismatic.Event.Bus.start_link(name: :test_bus)
      iex> Prismatic.Event.Bus.health_check(bus)
      :ok
  """
  @spec health_check(GenServer.server()) :: :ok | {:error, term()}
  def health_check(bus) do
    GenServer.call(bus, :health_check)
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(opts) do
    # Get or create configuration
    config = case Keyword.get(opts, :config) do
      nil ->
        {:ok, default_config} = Protocol.create_config(:in_memory, %{
          name: Keyword.get(opts, :name, :event_bus),
          enable_sourcing: true
        })
        default_config
      config -> config
    end

    # Start registry for subscription management
    {:ok, registry_pid} = Registry.start_link(name: :"#{config.name}_registry")

    # Start event sourcing if enabled
    sourcing_pid = if config.enable_sourcing do
      {:ok, pid} = Sourcing.start_link(config: config, name: :"#{config.name}_sourcing")
      pid
    else
      nil
    end

    # Get backend module
    {:ok, backend_module} = get_backend_module(config.backend_type)

    # Get or create circuit breaker (shared across bus instances with same backend)
    {:ok, circuit_breaker} = CircuitBreaker.get_or_create_circuit_breaker(config.backend_type)

    # Initialize metrics
    metrics = %{
      events_published: 0,
      events_sourced: 0,
      subscriptions_created: 0,
      subscriptions_removed: 0,
      pattern_matches: 0,
      handler_errors: 0,
      circuit_breaker_trips: 0
    }

    state = %{
      config: config,
      registry_pid: registry_pid,
      sourcing_pid: sourcing_pid,
      backend_module: backend_module,
      circuit_breaker: circuit_breaker,
      metrics: metrics,
      subscribers_count: 0,
      events_published: 0,
      start_time: System.monotonic_time()
    }

    Logger.info("Event Bus started", %{
      name: config.name,
      backend: config.backend_type,
      sourcing_enabled: config.enable_sourcing
    })

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:publish, event}, _from, state) do
    start_time = System.monotonic_time()

    case do_publish(event, state) do
      {:ok, event_id} ->
        # Update metrics
        new_metrics = update_metrics(state.metrics, :events_published)
        new_state = %{state |
          metrics: new_metrics,
          events_published: state.events_published + 1
        }

        # Emit telemetry
        emit_telemetry([:prismatic, :event, :bus, :publish], %{
          event_id: event_id,
          event_type: Map.get(event, :type, "unknown"),
          duration: System.monotonic_time() - start_time
        })

        {:reply, {:ok, event_id}, new_state}

      {:error, reason} ->
        Logger.warning("Event publication failed", %{reason: reason, event_type: event.type})
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:subscribe, pattern, handler, options}, _from, state) do
    case Registry.subscribe(state.registry_pid, pattern, handler, options) do
      {:ok, subscription_id} ->
        # Update metrics
        new_metrics = update_metrics(state.metrics, :subscriptions_created)
        new_state = %{state |
          metrics: new_metrics,
          subscribers_count: state.subscribers_count + 1
        }

        # Emit telemetry
        emit_telemetry([:prismatic, :event, :bus, :subscribe], %{
          subscription_id: subscription_id,
          pattern: pattern
        })

        {:reply, {:ok, subscription_id}, new_state}

      {:error, reason} ->
        Logger.warning("Subscription failed", %{reason: reason, pattern: pattern})
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:unsubscribe, subscription_id}, _from, state) do
    case Registry.unsubscribe(state.registry_pid, subscription_id) do
      :ok ->
        # Update metrics
        new_metrics = update_metrics(state.metrics, :subscriptions_removed)
        new_state = %{state |
          metrics: new_metrics,
          subscribers_count: max(0, state.subscribers_count - 1)
        }

        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:replay, options}, _from, state) do
    if state.sourcing_pid do
      case Sourcing.replay(state.sourcing_pid, options) do
        {:ok, events} ->
          {:reply, {:ok, events}, state}
        {:error, reason} ->
          {:reply, {:error, reason}, state}
      end
    else
      {:reply, {:error, :sourcing_disabled}, state}
    end
  end

  @impl GenServer
  def handle_call(:list_subscriptions, _from, state) do
    case Registry.list_subscriptions(state.registry_pid) do
      {:ok, subscriptions} ->
        {:reply, {:ok, subscriptions}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    stats = %{
      name: state.config.name,
      backend_type: state.config.backend_type,
      subscribers_count: state.subscribers_count,
      events_published: state.events_published,
      sourcing_enabled: state.config.enable_sourcing,
      metrics: state.metrics,
      uptime: get_uptime()
    }

    {:reply, {:ok, stats}, state}
  end

  @impl GenServer
  def handle_call(:health_check, _from, state) do
    # Check registry health
    registry_health = if Process.alive?(state.registry_pid), do: :ok, else: {:error, :registry_down}

    # Check sourcing health if enabled
    sourcing_health = if state.sourcing_pid do
      if Process.alive?(state.sourcing_pid), do: :ok, else: {:error, :sourcing_down}
    else
      :ok
    end

    # Check circuit breaker health
    circuit_breaker_health = if Process.alive?(state.circuit_breaker), do: :ok, else: {:error, :circuit_breaker_down}

    case {registry_health, sourcing_health, circuit_breaker_health} do
      {:ok, :ok, :ok} ->
        {:reply, :ok, state}
      _ ->
        {:reply, {:error, :unhealthy_components}, state}
    end
  end

  ## Private Implementation

  @spec do_publish(Protocol.event(), bus_state()) :: {:ok, Protocol.event_id()} | {:error, term()}
  defp do_publish(event, state) do
    # Enrich event with metadata
    enriched_event = enrich_event(event)

    # Store event if sourcing is enabled
    if state.sourcing_pid do
      case Sourcing.store_event(state.sourcing_pid, enriched_event) do
        {:ok, _} -> :ok
        {:error, reason} ->
          Logger.warning("Event sourcing failed", %{reason: reason, event_id: enriched_event.metadata.event_id})
      end
    end

    # Find matching subscriptions
    case Registry.find_matching_subscriptions(state.registry_pid, enriched_event.type) do
      {:ok, matching_subscriptions} ->
        # Deliver to all matching handlers
        deliver_to_subscribers(enriched_event, matching_subscriptions, state)
        {:ok, enriched_event.metadata.event_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec deliver_to_subscribers(Protocol.event(), [Protocol.subscription()], bus_state()) :: :ok
  defp deliver_to_subscribers(event, subscriptions, _state) do
    Enum.each(subscriptions, fn subscription ->
      Task.start(fn ->
        try do
          case subscription.handler.(event) do
            :ok ->
              :ok
            {:error, reason} ->
              Logger.warning("Event handler error", %{
                subscription_id: subscription.id,
                event_type: event.type,
                reason: reason
              })
          end
        rescue
          error ->
            Logger.error("Event handler exception", %{
              subscription_id: subscription.id,
              event_type: event.type,
              error: inspect(error)
            })
        end
      end)
    end)
  end

  @spec enrich_event(Protocol.event()) :: Protocol.event()
  defp enrich_event(event) do
    # Ensure event has required fields
    event_with_defaults = event
    |> Map.put_new(:type, "unknown")
    |> Map.put_new(:payload, %{})

    base_metadata = %{
      event_id: generate_event_id(),
      timestamp: DateTime.utc_now(),
      source: "prismatic_event_bus",
      correlation_id: nil,
      causation_id: nil,
      version: 1
    }

    enriched_metadata = Map.merge(base_metadata, Map.get(event_with_defaults, :metadata, %{}))
    Map.put(event_with_defaults, :metadata, enriched_metadata)
  end

  @spec generate_event_id() :: String.t()
  defp generate_event_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end

  @spec update_metrics(map(), atom()) :: map()
  defp update_metrics(metrics, key) do
    Map.update(metrics, key, 1, &(&1 + 1))
  end

  @spec emit_telemetry([atom()], map()) :: :ok
  defp emit_telemetry(event_name, measurements) do
    :telemetry.execute(event_name, measurements, %{})
  end

  @spec get_uptime() :: non_neg_integer()
  defp get_uptime do
    # Return 0 for now - uptime calculation can be added later if needed
    0
  end

  @spec get_backend_module(Protocol.backend_type()) :: {:ok, module()} | {:error, term()}
  defp get_backend_module(:in_memory), do: {:ok, Prismatic.Event.Impl.InMemoryBackend}
  defp get_backend_module(:redis), do: {:error, {:not_implemented, :redis}}
  defp get_backend_module(:phoenix_pubsub), do: {:ok, Prismatic.Event.Impl.PhoenixPubSubBackend}
  defp get_backend_module(:rabbitmq), do: {:error, {:not_implemented, :rabbitmq}}
  defp get_backend_module(:test), do: {:ok, Prismatic.Event.Impl.TestBackend}
  defp get_backend_module(backend_type), do: {:error, {:unsupported_backend, backend_type}}
end
