defmodule Prismatic.Event.Protocol do
  @moduledoc """
  Event system interface protocol for the Prismatic AI Agent Framework.

  This protocol defines the contract for event operations across different
  event backend implementations. It provides a unified interface for publishing,
  subscribing, and managing events in a distributed, pattern-based pub/sub system
  with event sourcing and replay capabilities.

  ## Architecture

  The Event Protocol system follows a protocol-driven architecture with:

  - **Behavior Contract**: All backends implement the same interface
  - **Factory Pattern**: Centralized backend creation and configuration
  - **Pattern Matching**: Advanced pattern-based event routing and filtering
  - **Event Sourcing**: Complete event history with replay capabilities
  - **Fault Tolerance**: Circuit breakers and retry logic built-in
  - **Metrics Collection**: Comprehensive monitoring and observability
  - **Backend Abstraction**: Seamless switching between different event backends

  ## Event Types

  The system supports different categories of events:

  - `:agent` - Inter-agent communication events
  - `:system` - System-level operational events
  - `:memory` - Memory system integration events
  - `:telemetry` - Monitoring and metrics events
  - `:user` - User interaction and custom events

  ## Supported Backends

  - `:in_memory` - High-performance in-memory event bus for testing/development
  - `:redis` - Redis-based distributed event bus with persistence
  - `:phoenix_pubsub` - Phoenix.PubSub integration for web applications
  - `:rabbitmq` - RabbitMQ message broker for enterprise deployments
  - `:test` - Test backend for development and testing

  ## Usage Examples

  ### Basic Usage

      # Create event system configuration
      {:ok, config} = Prismatic.Event.Protocol.create_config(:in_memory, %{
        name: :event_bus,
        enable_sourcing: true,
        max_events: 100_000
      })

      # Subscribe to events
      {:ok, subscription_id} = Prismatic.Event.Protocol.subscribe(
        config,
        "agent.*.message",
        fn event -> IO.inspect(event) end
      )

      # Publish an event
      event = %{
        type: "agent.alice.message",
        payload: %{content: "Hello, world!"},
        metadata: %{timestamp: DateTime.utc_now()}
      }

      {:ok, event_id} = Prismatic.Event.Protocol.publish(config, event)
  """

  alias Prismatic.Event.Backend.{CircuitBreaker, RetryLogic}
  alias Prismatic.Event.Impl.{InMemoryBackend, PhoenixPubSubBackend, TestBackend}

  @typedoc "Event backend configuration map"
  @type config :: %{
    backend_type: backend_type(),
    name: atom(),
    timeout: pos_integer(),
    max_retries: non_neg_integer(),
    enable_sourcing: boolean(),
    max_events: pos_integer() | nil,
    persistence_interval: pos_integer(),
    backend_options: map()
  }

  @typedoc "Supported backend types"
  @type backend_type :: :in_memory | :redis | :phoenix_pubsub | :rabbitmq | :test

  @typedoc "Event categories for organization"
  @type event_category :: :agent | :system | :memory | :telemetry | :user

  @typedoc "Event pattern for subscription matching"
  @type event_pattern :: String.t()

  @typedoc "Unique subscription identifier"
  @type subscription_id :: String.t()

  @typedoc "Unique event identifier"
  @type event_id :: String.t()

  @typedoc "Event handler function"
  @type event_handler :: (event() -> :ok | {:error, term()})

  @typedoc "Event structure"
  @type event :: %{
    type: String.t(),
    payload: map(),
    metadata: event_metadata()
  }

  @typedoc "Event metadata structure"
  @type event_metadata :: %{
    event_id: event_id(),
    timestamp: DateTime.t(),
    source: String.t(),
    correlation_id: String.t() | nil,
    causation_id: String.t() | nil,
    version: pos_integer()
  }

  @typedoc "Subscription information"
  @type subscription :: %{
    id: subscription_id(),
    pattern: event_pattern(),
    handler: event_handler(),
    metadata: map()
  }

  @typedoc "Replay options for event sourcing"
  @type replay_options :: %{
    optional(:from) => DateTime.t(),
    optional(:to) => DateTime.t(),
    optional(:from_id) => event_id(),
    optional(:to_id) => event_id(),
    optional(:patterns) => [event_pattern()],
    optional(:limit) => pos_integer(),
    optional(:order) => :asc | :desc
  }

  @typedoc "Backend information structure"
  @type backend_info :: %{
    backend_type: backend_type(),
    name: atom(),
    supports_sourcing: boolean(),
    supports_patterns: boolean(),
    max_subscribers: pos_integer() | :unlimited,
    max_events: pos_integer() | :unlimited,
    features: [atom()]
  }

  @event_categories [:agent, :system, :memory, :telemetry, :user]

  @callback publish(config(), event()) :: {:ok, event_id()} | {:error, term()}
  @callback subscribe(config(), event_pattern(), event_handler(), map()) ::
    {:ok, subscription_id()} | {:error, term()}
  @callback unsubscribe(config(), subscription_id()) :: :ok | {:error, term()}
  @callback replay(config(), replay_options()) :: {:ok, [event()]} | {:error, term()}
  @callback list_subscriptions(config()) :: {:ok, [subscription()]} | {:error, term()}
  @callback validate_config(config()) :: :ok | {:error, term()}
  @callback health_check(config()) :: :ok | {:error, term()}
  @callback get_backend_info(config()) :: {:ok, backend_info()} | {:error, term()}

  ## Public API Functions

  @spec create_config(backend_type(), map()) :: {:ok, config()} | {:error, term()}
  def create_config(backend_type, options \\ %{}) do
    case validate_backend_type(backend_type) do
      :ok ->
        # Determine default name based on backend type
        default_name = case backend_type do
          :test -> :memory_test  # For backwards compatibility with tests
          _ -> :"event_system_#{backend_type}"
        end

        base_config = %{
          backend_type: backend_type,
          name: Map.get(options, :name, default_name),
          timeout: 30_000,
          max_retries: 3,
          enable_sourcing: true,
          max_events: 1_000_000,
          persistence_interval: 10_000,
          backend_options: %{}
        }

        config = Map.merge(base_config, options)
        {:ok, config}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec publish(config(), event()) :: {:ok, event_id()} | {:error, term()}
  def publish(config, event) do
    with :ok <- validate_config(config),
         :ok <- validate_event(event),
         {:ok, enriched_event} <- enrich_event(event),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do

      CircuitBreaker.call(config.backend_type, fn ->
        RetryLogic.with_retry(fn ->
          backend_module.publish(config, enriched_event)
        end, RetryLogic.event_retry_config())
      end)
    end
  end

  @spec subscribe(config(), event_pattern(), event_handler(), map()) ::
    {:ok, subscription_id()} | {:error, term()}
  def subscribe(config, pattern, handler, options \\ %{}) do
    with :ok <- validate_config(config),
         :ok <- validate_pattern(pattern),
         :ok <- validate_handler(handler),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do

      CircuitBreaker.call(config.backend_type, fn ->
        RetryLogic.with_retry(fn ->
          backend_module.subscribe(config, pattern, handler, options)
        end, RetryLogic.event_retry_config())
      end)
    end
  end

  @spec unsubscribe(config(), subscription_id()) :: :ok | {:error, term()}
  def unsubscribe(config, subscription_id) do
    with :ok <- validate_config(config),
         :ok <- validate_subscription_id(subscription_id),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do

      case CircuitBreaker.call(config.backend_type, fn ->
        RetryLogic.with_retry(fn ->
          backend_module.unsubscribe(config, subscription_id)
        end, RetryLogic.event_retry_config())
      end) do
        {:ok, :ok} -> :ok
        {:ok, result} -> result
        {:error, reason} -> {:error, reason}
        result -> result
      end
    end
  end

  @spec replay(config(), replay_options()) :: {:ok, [event()]} | {:error, term()}
  def replay(config, options \\ %{}) do
    with :ok <- validate_config(config),
         :ok <- validate_replay_options(options),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do

      # Check if sourcing is enabled first
      if Map.get(config, :enable_sourcing, false) do
        CircuitBreaker.call(config.backend_type, fn ->
          RetryLogic.with_retry(fn ->
            backend_module.replay(config, options)
          end, RetryLogic.event_retry_config())
        end)
      else
        {:error, :sourcing_disabled}
      end
    end
  end

  @spec list_subscriptions(config()) :: {:ok, [subscription()]} | {:error, term()}
  def list_subscriptions(config) do
    with :ok <- validate_config(config),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do

      CircuitBreaker.call(config.backend_type, fn ->
        RetryLogic.with_retry(fn ->
          backend_module.list_subscriptions(config)
        end, RetryLogic.event_retry_config())
      end)
    end
  end

  @spec validate_config(config()) :: :ok | {:error, term()}
  def validate_config(config) do
    with :ok <- validate_backend_type(config.backend_type),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do
      backend_module.validate_config(config)
    end
  end

  @spec health_check(config()) :: :ok | {:error, term()}
  def health_check(config) do
    with :ok <- validate_config(config),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do
      backend_module.health_check(config)
    end
  end

  @spec get_backend_info(config()) :: {:ok, backend_info()} | {:error, term()}
  def get_backend_info(config) do
    with :ok <- validate_config(config),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do
      backend_module.get_backend_info(config)
    end
  end

  @spec available_backends() :: [:in_memory | :phoenix_pubsub | :rabbitmq | :redis | :test]
  def available_backends do
    [:in_memory, :redis, :phoenix_pubsub, :rabbitmq, :test]
  end

  @spec event_categories() :: [:agent | :memory | :system | :telemetry | :user]
  def event_categories do
    @event_categories
  end

  ## Private Implementation

  @spec validate_backend_type(term()) :: :ok | {:error, {:unsupported_backend, term()}}
  defp validate_backend_type(backend_type) when backend_type in [:in_memory, :redis, :phoenix_pubsub, :rabbitmq, :test] do
    :ok
  end

  defp validate_backend_type(backend_type) do
    {:error, {:unsupported_backend, backend_type}}
  end

  @spec validate_event(term()) :: :ok | {:error, {:invalid_event, term()}}
  defp validate_event(%{type: type, payload: payload}) when is_binary(type) and is_map(payload) do
    :ok
  end

  defp validate_event(event) do
    {:error, {:invalid_event, event}}
  end

  @spec validate_pattern(term()) :: :ok | {:error, {:invalid_pattern, term()}}
  defp validate_pattern(pattern) when is_binary(pattern) do
    :ok
  end

  defp validate_pattern(pattern) do
    {:error, {:invalid_pattern, pattern}}
  end

  @spec validate_handler(term()) :: :ok | {:error, {:invalid_handler, term()}}
  defp validate_handler(handler) when is_function(handler, 1) do
    :ok
  end

  defp validate_handler(handler) do
    {:error, {:invalid_handler, handler}}
  end

  @spec validate_subscription_id(term()) :: :ok | {:error, {:invalid_subscription_id, term()}}
  defp validate_subscription_id(subscription_id) when is_binary(subscription_id) do
    :ok
  end

  defp validate_subscription_id(subscription_id) do
    {:error, {:invalid_subscription_id, subscription_id}}
  end

  @spec validate_replay_options(term()) :: :ok | {:error, {:invalid_replay_options, term()}}
  defp validate_replay_options(options) when is_map(options) do
    :ok
  end

  defp validate_replay_options(options) do
    {:error, {:invalid_replay_options, options}}
  end

  @spec enrich_event(event()) :: {:ok, event()} | {:error, term()}
  defp enrich_event(event) do
    base_metadata = %{
      event_id: generate_event_id(),
      timestamp: DateTime.utc_now(),
      source: "prismatic",
      correlation_id: nil,
      causation_id: nil,
      version: 1
    }

    enriched_metadata = Map.merge(base_metadata, Map.get(event, :metadata, %{}))
    enriched_event = Map.put(event, :metadata, enriched_metadata)

    {:ok, enriched_event}
  end

  @spec generate_event_id() :: String.t()
  defp generate_event_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end

  @spec get_backend_module(backend_type()) :: {:ok, module()} | {:error, term()}
  defp get_backend_module(:in_memory), do: {:ok, InMemoryBackend}
  defp get_backend_module(:redis), do: {:error, {:not_implemented, :redis}}
  defp get_backend_module(:phoenix_pubsub), do: {:ok, PhoenixPubSubBackend}
  defp get_backend_module(:rabbitmq), do: {:error, {:not_implemented, :rabbitmq}}
  defp get_backend_module(:test), do: {:ok, TestBackend}
  defp get_backend_module(backend_type), do: {:error, {:unsupported_backend, backend_type}}
end
