# Prismatic Event System

The Prismatic Event System is a comprehensive, production-ready event-driven communication infrastructure for the Prismatic AI Agent Framework. It provides distributed pub/sub capabilities, event sourcing, pattern-based routing, and comprehensive monitoring.

## Architecture Overview

The Event System follows a layered, protocol-driven architecture designed for reliability, performance, and extensibility:

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                        │
├─────────────────────────────────────────────────────────────┤
│                    Protocol Layer                           │
│  • Unified API interface                                    │
│  • Backend abstraction                                      │
│  • Error handling & validation                              │
├─────────────────────────────────────────────────────────────┤
│                    Bus Layer                                │
│  • Event routing & coordination                             │
│  • Subscription management                                  │
│  • Telemetry integration                                    │
├─────────────────────────────────────────────────────────────┤
│   Registry Layer        │        Sourcing Layer            │
│  • Pattern matching     │  • Event persistence             │
│  • Subscription storage │  • Replay capabilities           │
│  • Performance caching  │  • Snapshot management           │
├─────────────────────────────────────────────────────────────┤
│                    Backend Layer                            │
│  • InMemory    • Test    • PhoenixPubSub    • Redis        │
├─────────────────────────────────────────────────────────────┤
│                Infrastructure Layer                         │
│  • Circuit Breakers    • Retry Logic    • Telemetry        │
└─────────────────────────────────────────────────────────────┘
```

## Key Features

### 🚀 **High Performance**
- Optimized pattern matching with O(1) exact matches
- ETS-based storage for sub-millisecond operations
- Concurrent-safe design for high-throughput scenarios
- Smart caching for frequently matched patterns

### 🔄 **Event Sourcing**
- Complete event history with replay capabilities
- Snapshot support for performance optimization
- Flexible querying by time, sequence, or patterns
- Automatic compaction for storage management

### 🎯 **Advanced Pattern Matching**
- Wildcard patterns: `agent.*.message`, `system.**`
- Alternative patterns: `{agent,system}.*.error`
- Hierarchical matching for complex event routing
- Compiled patterns for optimal performance

### 🛡️ **Fault Tolerance**
- Circuit breaker protection for backend failures
- Configurable retry logic with exponential backoff
- Comprehensive error classification and handling
- Health monitoring and automatic recovery

### 📊 **Observability**
- Rich telemetry events for monitoring
- Performance metrics and statistics
- Integration with standard Elixir telemetry tools
- Built-in logging and debugging support

### 🔧 **Extensible Architecture**
- Pluggable backend implementations
- Protocol-driven design for easy extension
- Support for custom storage backends
- Flexible configuration options

## Quick Start

### Basic Usage

```elixir
# Create event system configuration
{:ok, config} = Prismatic.Event.Protocol.create_config(:in_memory, %{
  name: :my_event_system,
  enable_sourcing: true,
  max_events: 1_000_000
})

# Subscribe to events
{:ok, subscription_id} = Prismatic.Event.Protocol.subscribe(
  config,
  "user.*.action",
  fn event ->
    IO.puts("Received: #{event.type} - #{inspect(event.payload)}")
    :ok
  end
)

# Publish an event
event = %{
  type: "user.alice.action",
  payload: %{action: "login", timestamp: DateTime.utc_now()},
  metadata: %{correlation_id: "request_123"}
}

{:ok, event_id} = Prismatic.Event.Protocol.publish(config, event)

# Event will be automatically delivered to matching subscribers
```

### Advanced Pattern Matching

```elixir
# Subscribe to various patterns
patterns = [
  {"agent.*.message", &handle_agent_message/1},
  {"system.{memory,llm}.error", &handle_system_error/1},
  {"**.critical", &handle_critical_events/1},
  {"user.{login,logout}", &handle_auth_events/1}
]

subscription_ids = Enum.map(patterns, fn {pattern, handler} ->
  {:ok, sub_id} = Prismatic.Event.Protocol.subscribe(config, pattern, handler)
  sub_id
end)
```

### Event Sourcing and Replay

```elixir
# Replay recent events
{:ok, recent_events} = Prismatic.Event.Protocol.replay(config, %{
  from: DateTime.add(DateTime.utc_now(), -3600, :second),  # Last hour
  patterns: ["user.*", "system.error.*"],
  limit: 100,
  order: :desc
})

# Replay by sequence range
{:ok, range_events} = Prismatic.Event.Protocol.replay(config, %{
  from_sequence: 1000,
  to_sequence: 2000,
  patterns: ["critical.*"]
})
```

## Backend Implementations

### In-Memory Backend (Production Ready)

High-performance backend using ETS tables, ideal for single-node deployments:

```elixir
{:ok, config} = Prismatic.Event.Protocol.create_config(:in_memory, %{
  name: :production_events,
  max_events: 5_000_000,
  enable_sourcing: true,
  cleanup_interval: 300_000  # 5 minutes
})
```

**Features:**
- Sub-millisecond event processing
- Efficient pattern matching with caching
- Configurable memory limits and cleanup
- Full event sourcing support

### Phoenix PubSub Backend (Distributed)

Distributed backend leveraging Phoenix.PubSub for multi-node deployments:

```elixir
{:ok, config} = Prismatic.Event.Protocol.create_config(:phoenix_pubsub, %{
  name: :distributed_events,
  pubsub_name: MyApp.PubSub,
  topic_prefix: "events"
})
```

**Features:**
- Automatic distribution across nodes
- Web application integration
- Multiple PubSub adapter support
- Client-side pattern filtering

### Test Backend (Development)

Configurable backend for testing and development:

```elixir
{:ok, config} = Prismatic.Event.Protocol.create_config(:test, %{
  name: :test_events,
  responses: %{
    "error.test" => {:error, :simulated_failure}
  },
  track_events: true
})

# Get published events for verification
{:ok, events} = Prismatic.Event.Impl.TestBackend.get_published_events(config)
```

## Event Structure

All events follow a consistent structure:

```elixir
%{
  type: "domain.entity.action",           # Required: Event type for routing
  payload: %{                             # Required: Event data
    user_id: "alice_123",
    action: "profile_update",
    changes: %{email: "new@example.com"}
  },
  metadata: %{                            # Optional: Additional context
    event_id: "evt_abc123",               # Auto-generated if not provided
    timestamp: ~U[2024-01-01 10:00:00Z],  # Auto-generated if not provided
    source: "user_service",
    correlation_id: "req_xyz789",
    causation_id: "evt_def456",
    version: 1
  }
}
```

## Pattern Matching Guide

### Basic Patterns

- **Exact Match**: `user.alice.login` - Matches exactly this event type
- **Single Wildcard**: `user.*.login` - Matches any user's login event
- **Multi Wildcard**: `user.**` - Matches all events under user hierarchy

### Advanced Patterns

- **Alternatives**: `{user,admin}.login` - Matches login for user or admin
- **Complex**: `system.{memory,llm}.*.{error,warning}` - System component errors/warnings
- **Suffix**: `**.critical` - Any critical event at any level

### Pattern Performance

- **Exact matches**: O(1) lookup via hash table
- **Wildcard patterns**: O(n) but optimized with caching
- **Complex patterns**: Compiled for best performance

## Configuration Options

### Protocol Configuration

```elixir
%{
  backend_type: :in_memory | :phoenix_pubsub | :test,
  name: atom(),                    # Unique system name
  timeout: 30_000,                 # Request timeout (ms)
  max_retries: 3,                  # Retry attempts
  enable_sourcing: true,           # Event persistence
  max_events: 1_000_000,           # Storage limit
  circuit_breaker: %{              # Fault tolerance
    failure_threshold: 5,
    recovery_timeout: 60_000,
    success_threshold: 2
  }
}
```

### Backend-Specific Options

#### In-Memory Backend
```elixir
%{
  max_subscriptions: 10_000,       # Subscription limit
  pattern_cache_size: 1_000,       # Pattern cache entries
  cleanup_interval: 300_000        # Cleanup frequency (ms)
}
```

#### Phoenix PubSub Backend
```elixir
%{
  pubsub_name: MyApp.PubSub,       # PubSub process name
  topic_prefix: "events",          # Topic namespace
  enable_pattern_topics: true      # Pattern-based topics
}
```

## Telemetry and Monitoring

The Event System provides comprehensive telemetry for monitoring and observability:

### Telemetry Events

```elixir
# Attach telemetry handlers
Prismatic.Event.Telemetry.attach_default_handlers(
  log_level: :info,
  enable_metrics: true,
  enable_health_checks: true
)

# Custom telemetry handler
:telemetry.attach(
  "my-event-handler",
  [:prismatic, :event, :protocol, :publish],
  fn event_name, measurements, metadata, _config ->
    Logger.info("Event published", %{
      event_type: metadata.event_type,
      duration: measurements.duration,
      backend: metadata.backend_type
    })
  end,
  %{}
)
```

### Available Metrics

- **Protocol Level**: `[:prismatic, :event, :protocol, :publish]`
- **Bus Level**: `[:prismatic, :event, :bus, :delivery]`
- **Registry Level**: `[:prismatic, :event, :registry, :pattern_match]`
- **Sourcing Level**: `[:prismatic, :event, :sourcing, :store]`
- **Backend Level**: `[:prismatic, :event, :backend, :circuit_breaker]`

## Error Handling

The Event System provides comprehensive error classification and handling:

### Error Types

```elixir
# Network errors (retryable)
{:error, :timeout}
{:error, :econnrefused}

# Validation errors (non-retryable)
{:error, :invalid_event}
{:error, :invalid_pattern}

# Backend errors (context-dependent)
{:error, :circuit_breaker_open}
{:error, :max_subscriptions_exceeded}

# Storage errors (retryable)
{:error, :storage_full}
{:error, :write_failed}
```

### Error Handling Patterns

```elixir
case Prismatic.Event.Protocol.publish(config, event) do
  {:ok, event_id} ->
    handle_success(event_id)
    
  {:error, :circuit_breaker_open} ->
    # Backend is temporarily unavailable
    schedule_retry(event)
    
  {:error, :invalid_event} ->
    # Permanent error - log and discard
    Logger.error("Invalid event", %{event: event})
    
  {:error, reason} ->
    # Handle other errors
    handle_error(reason, event)
end
```

## Performance Characteristics

### Benchmarks

Based on internal testing with the in-memory backend:

- **Event Publication**: ~10,000 events/second
- **Pattern Matching**: <1ms for most patterns
- **Subscription Creation**: <10ms average
- **Event Replay**: ~50,000 events/second

### Optimization Tips

1. **Use Exact Patterns When Possible**: O(1) vs O(n) lookup
2. **Batch Operations**: Group related events together
3. **Configure Limits**: Set appropriate max_events and max_subscriptions
4. **Monitor Telemetry**: Watch for performance bottlenecks
5. **Use Appropriate Backend**: In-memory for single-node, PubSub for distributed

## Integration Examples

### With Phoenix Applications

```elixir
# In your application supervisor
children = [
  # ... other children
  {Prismatic.Event.Bus, [
    name: :app_events,
    config: %{
      backend_type: :phoenix_pubsub,
      pubsub_name: MyApp.PubSub,
      enable_sourcing: true
    }
  ]}
]

# In a LiveView
defmodule MyAppWeb.DashboardLive do
  use MyAppWeb, :live_view
  
  def mount(_params, _session, socket) do
    # Subscribe to real-time events
    {:ok, _sub_id} = Prismatic.Event.Protocol.subscribe(
      :app_events,
      "user.*.activity",
      &handle_user_activity/1
    )
    
    {:ok, socket}
  end
  
  defp handle_user_activity(event) do
    send(self(), {:user_activity, event})
  end
end
```

### With GenServer Applications

```elixir
defmodule MyService do
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    # Subscribe to relevant events
    {:ok, _sub_id} = Prismatic.Event.Protocol.subscribe(
      :app_events,
      "system.{memory,llm}.**",
      fn event -> GenServer.cast(__MODULE__, {:system_event, event}) end
    )
    
    {:ok, %{}}
  end
  
  def handle_cast({:system_event, event}, state) do
    # Process system events
    Logger.info("System event received", %{type: event.type})
    {:noreply, state}
  end
end
```

## Best Practices

### Event Design

1. **Use Hierarchical Event Types**: `domain.entity.action` format
2. **Include Rich Metadata**: correlation_id, causation_id for tracing
3. **Keep Payloads Focused**: Single responsibility per event
4. **Version Your Events**: Support schema evolution

### Pattern Design

1. **Start Specific, Generalize**: Begin with exact matches, add wildcards as needed
2. **Use Semantic Patterns**: Patterns should reflect business concepts
3. **Avoid Over-broad Patterns**: `**` patterns can impact performance
4. **Test Pattern Performance**: Monitor pattern matching metrics

### Subscription Management

1. **Clean Up Subscriptions**: Always unsubscribe when done
2. **Handle Errors Gracefully**: Event handlers should not throw
3. **Use Async Processing**: Avoid blocking the event bus
4. **Monitor Subscription Health**: Watch for failed handlers

### Production Deployment

1. **Configure Appropriate Limits**: max_events, max_subscriptions
2. **Enable Telemetry**: Monitor system health and performance
3. **Set Up Alerting**: Circuit breaker trips, high error rates
4. **Plan for Growth**: Consider distributed backends early
5. **Test Failure Scenarios**: Circuit breakers, backend failures

## Troubleshooting

### Common Issues

**Events Not Being Delivered**
- Check pattern matching: Use exact event type to test
- Verify subscription exists: `list_subscriptions/1`
- Check handler errors: Monitor telemetry events

**Performance Issues**
- Profile pattern matching: Use `get_stats/1` for metrics
- Review subscription patterns: Avoid overly broad patterns
- Check backend configuration: Adjust limits and caching

**Memory Usage**
- Configure event limits: Set max_events appropriately
- Enable compaction: Configure cleanup intervals
- Monitor growth: Use telemetry for storage metrics

### Debug Tools

```elixir
# Check system health
:ok = Prismatic.Event.Protocol.health_check(config)

# Get backend information
{:ok, info} = Prismatic.Event.Protocol.get_backend_info(config)

# List active subscriptions
{:ok, subscriptions} = Prismatic.Event.Protocol.list_subscriptions(config)

# Get system statistics
{:ok, stats} = Prismatic.Event.Bus.get_stats(:my_event_bus)
```

## Contributing

The Event System is designed for extensibility. To add new backends:

1. Implement the `Prismatic.Event.Protocol` behavior
2. Add backend-specific configuration validation
3. Provide comprehensive tests
4. Update documentation

For storage backends, implement `Prismatic.Event.Storage.Behaviour`.

## License

Part of the Prismatic AI Agent Framework. See main project license for details.