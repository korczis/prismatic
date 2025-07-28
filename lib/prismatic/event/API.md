# Prismatic Event System API Reference

This document provides detailed API documentation for all public functions in the Prismatic Event System.

## Prismatic.Event.Protocol

The main protocol interface for the Event System.

### create_config/2

Creates a new event system configuration.

**Signature:**
```elixir
@spec create_config(backend_type :: atom(), options :: map()) :: 
  {:ok, config :: map()} | {:error, reason :: term()}
```

**Parameters:**
- `backend_type` - Backend type (`:in_memory`, `:phoenix_pubsub`, `:test`)
- `options` - Configuration options map

**Returns:**
- `{:ok, config}` - Successfully created configuration
- `{:error, reason}` - Configuration creation failed

**Example:**
```elixir
{:ok, config} = Prismatic.Event.Protocol.create_config(:in_memory, %{
  name: :my_events,
  enable_sourcing: true,
  max_events: 100_000
})
```

### publish/2

Publishes an event to the system.

**Signature:**
```elixir
@spec publish(config :: map(), event :: map()) :: 
  {:ok, event_id :: binary()} | {:error, reason :: term()}
```

**Parameters:**
- `config` - Event system configuration
- `event` - Event map with required `:type` and `:payload` keys

**Returns:**
- `{:ok, event_id}` - Event published successfully
- `{:error, reason}` - Publication failed

**Event Structure:**
```elixir
%{
  type: "domain.entity.action",     # Required
  payload: %{...},                  # Required
  metadata: %{                      # Optional
    event_id: "auto-generated",
    timestamp: DateTime.utc_now(),
    source: "service_name",
    correlation_id: "request_id",
    causation_id: "parent_event_id",
    version: 1
  }
}
```

**Example:**
```elixir
event = %{
  type: "user.profile.updated",
  payload: %{user_id: "123", changes: %{email: "new@example.com"}},
  metadata: %{correlation_id: "req_456"}
}

{:ok, event_id} = Prismatic.Event.Protocol.publish(config, event)
```

### subscribe/3

Subscribes to events matching a pattern.

**Signature:**
```elixir
@spec subscribe(config :: map(), pattern :: binary(), handler :: function()) :: 
  {:ok, subscription_id :: binary()} | {:error, reason :: term()}
```

**Parameters:**
- `config` - Event system configuration
- `pattern` - Event pattern to match (supports wildcards)
- `handler` - Function to handle matching events `(event -> :ok | {:error, reason})`

**Returns:**
- `{:ok, subscription_id}` - Subscription created successfully
- `{:error, reason}` - Subscription failed

**Pattern Syntax:**
- `*` - Single level wildcard (`user.*.login`)
- `**` - Multi-level wildcard (`user.**`)
- `{a,b}` - Alternatives (`{user,admin}.login`)

**Example:**
```elixir
{:ok, sub_id} = Prismatic.Event.Protocol.subscribe(
  config,
  "user.*.profile_updated",
  fn event ->
    Logger.info("Profile updated", %{user_id: event.payload.user_id})
    :ok
  end
)
```

### unsubscribe/2

Removes a subscription from the system.

**Signature:**
```elixir
@spec unsubscribe(config :: map(), subscription_id :: binary()) :: 
  :ok | {:error, reason :: term()}
```

**Parameters:**
- `config` - Event system configuration
- `subscription_id` - ID returned from `subscribe/3`

**Returns:**
- `:ok` - Subscription removed successfully
- `{:error, reason}` - Unsubscribe failed

**Example:**
```elixir
:ok = Prismatic.Event.Protocol.unsubscribe(config, subscription_id)
```

### replay/2

Replays events from the event store.

**Signature:**
```elixir
@spec replay(config :: map(), options :: map()) :: 
  {:ok, events :: [map()]} | {:error, reason :: term()}
```

**Parameters:**
- `config` - Event system configuration (with `enable_sourcing: true`)
- `options` - Replay options map

**Replay Options:**
```elixir
%{
  # Time-based replay
  from: DateTime.t(),               # Start time
  to: DateTime.t(),                 # End time (optional)
  
  # Sequence-based replay
  from_sequence: integer(),         # Start sequence number
  to_sequence: integer(),           # End sequence number (optional)
  
  # Pattern filtering
  patterns: [binary()],             # Event patterns to match
  
  # Result limiting
  limit: integer(),                 # Maximum events to return
  order: :asc | :desc               # Sort order (default: :asc)
}
```

**Returns:**
- `{:ok, events}` - List of matching events
- `{:error, reason}` - Replay failed

**Example:**
```elixir
# Replay last hour of user events
{:ok, events} = Prismatic.Event.Protocol.replay(config, %{
  from: DateTime.add(DateTime.utc_now(), -3600, :second),
  patterns: ["user.**"],
  limit: 1000,
  order: :desc
})

# Replay specific sequence range
{:ok, events} = Prismatic.Event.Protocol.replay(config, %{
  from_sequence: 1000,
  to_sequence: 2000,
  patterns: ["critical.**"]
})
```

### list_subscriptions/1

Lists all active subscriptions.

**Signature:**
```elixir
@spec list_subscriptions(config :: map()) :: 
  {:ok, subscriptions :: [map()]} | {:error, reason :: term()}
```

**Parameters:**
- `config` - Event system configuration

**Returns:**
- `{:ok, subscriptions}` - List of subscription info maps
- `{:error, reason}` - Operation failed

**Subscription Info Structure:**
```elixir
%{
  id: "subscription_id",
  pattern: "user.*.login",
  created_at: DateTime.t(),
  handler_pid: pid(),
  stats: %{
    events_received: 42,
    last_event_at: DateTime.t(),
    errors: 0
  }
}
```

**Example:**
```elixir
{:ok, subscriptions} = Prismatic.Event.Protocol.list_subscriptions(config)

Enum.each(subscriptions, fn sub ->
  IO.puts("Subscription #{sub.id}: #{sub.pattern} (#{sub.stats.events_received} events)")
end)
```

### health_check/1

Performs a health check on the event system.

**Signature:**
```elixir
@spec health_check(config :: map()) :: 
  :ok | {:error, reason :: term()}
```

**Parameters:**
- `config` - Event system configuration

**Returns:**
- `:ok` - System is healthy
- `{:error, reason}` - Health check failed

**Example:**
```elixir
case Prismatic.Event.Protocol.health_check(config) do
  :ok -> 
    Logger.info("Event system healthy")
  {:error, reason} -> 
    Logger.error("Event system unhealthy", %{reason: reason})
end
```

### get_backend_info/1

Retrieves information about the backend implementation.

**Signature:**
```elixir
@spec get_backend_info(config :: map()) :: 
  {:ok, info :: map()} | {:error, reason :: term()}
```

**Parameters:**
- `config` - Event system configuration

**Returns:**
- `{:ok, info}` - Backend information map
- `{:error, reason}` - Operation failed

**Backend Info Structure:**
```elixir
%{
  type: :in_memory,
  name: :my_events,
  pid: #PID<0.123.0>,
  stats: %{
    events_published: 1234,
    active_subscriptions: 5,
    memory_usage: 1024000,
    uptime_seconds: 3600
  },
  config: %{...}
}
```

**Example:**
```elixir
{:ok, info} = Prismatic.Event.Protocol.get_backend_info(config)
IO.puts("Backend: #{info.type}, Events: #{info.stats.events_published}")
```

## Prismatic.Event.Bus

The central event bus coordination service.

### start_link/1

Starts the event bus GenServer.

**Signature:**
```elixir
@spec start_link(options :: keyword()) :: GenServer.on_start()
```

**Parameters:**
- `options` - Keyword list with `:name` and `:config` keys

**Example:**
```elixir
{:ok, pid} = Prismatic.Event.Bus.start_link(
  name: :my_event_bus,
  config: %{backend_type: :in_memory, enable_sourcing: true}
)
```

### get_stats/1

Retrieves statistics for the event bus.

**Signature:**
```elixir
@spec get_stats(bus_name :: atom()) :: 
  {:ok, stats :: map()} | {:error, reason :: term()}
```

**Parameters:**
- `bus_name` - Name of the event bus process

**Returns:**
- `{:ok, stats}` - Statistics map
- `{:error, reason}` - Operation failed

**Stats Structure:**
```elixir
%{
  events_published: 1234,
  events_delivered: 5678,
  active_subscriptions: 12,
  pattern_cache_hits: 890,
  pattern_cache_misses: 34,
  average_delivery_time_ms: 2.5,
  error_count: 1,
  uptime_seconds: 3600
}
```

## Prismatic.Event.Registry

Subscription registry with pattern matching.

### create/1

Creates a new registry.

**Signature:**
```elixir
@spec create(options :: map()) :: {:ok, registry :: term()} | {:error, reason :: term()}
```

### add_subscription/3

Adds a subscription to the registry.

**Signature:**
```elixir
@spec add_subscription(registry :: term(), pattern :: binary(), handler :: function()) :: 
  {:ok, subscription_id :: binary()} | {:error, reason :: term()}
```

### find_matching_subscriptions/2

Finds subscriptions matching an event type.

**Signature:**
```elixir
@spec find_matching_subscriptions(registry :: term(), event_type :: binary()) :: 
  {:ok, subscriptions :: [map()]} | {:error, reason :: term()}
```

## Prismatic.Event.Pattern

Advanced pattern matching utilities.

### compile/1

Compiles a pattern for efficient matching.

**Signature:**
```elixir
@spec compile(pattern :: binary()) :: 
  {:ok, compiled_pattern :: term()} | {:error, reason :: term()}
```

**Example:**
```elixir
{:ok, compiled} = Prismatic.Event.Pattern.compile("user.*.{login,logout}")
```

### match?/2

Tests if a pattern matches an event type.

**Signature:**
```elixir
@spec match?(pattern :: binary() | term(), event_type :: binary()) :: boolean()
```

**Example:**
```elixir
true = Prismatic.Event.Pattern.match?("user.*", "user.alice.login")
false = Prismatic.Event.Pattern.match?("admin.*", "user.alice.login")
```

### validate/1

Validates pattern syntax.

**Signature:**
```elixir
@spec validate(pattern :: binary()) :: :ok | {:error, reason :: term()}
```

**Example:**
```elixir
:ok = Prismatic.Event.Pattern.validate("user.*.action")
{:error, :invalid_syntax} = Prismatic.Event.Pattern.validate("user.[invalid")
```

## Prismatic.Event.Sourcing

Event sourcing and replay functionality.

### create_store/1

Creates a new event store.

**Signature:**
```elixir
@spec create_store(options :: map()) :: 
  {:ok, store :: term()} | {:error, reason :: term()}
```

### store_event/2

Stores an event in the event store.

**Signature:**
```elixir
@spec store_event(store :: term(), event :: map()) :: 
  {:ok, sequence :: integer()} | {:error, reason :: term()}
```

### query_events/2

Queries events from the store.

**Signature:**
```elixir
@spec query_events(store :: term(), query :: map()) :: 
  {:ok, events :: [map()]} | {:error, reason :: term()}
```

**Query Structure:**
```elixir
%{
  from_sequence: 1,               # Optional: Start sequence
  to_sequence: 100,               # Optional: End sequence
  from_time: DateTime.t(),        # Optional: Start time
  to_time: DateTime.t(),          # Optional: End time
  event_types: ["user.login"],    # Optional: Filter by types
  limit: 50,                      # Optional: Max results
  order: :asc                     # Optional: Sort order
}
```

## Prismatic.Event.Telemetry

Telemetry integration and monitoring.

### attach_default_handlers/1

Attaches default telemetry handlers for logging and metrics.

**Signature:**
```elixir
@spec attach_default_handlers(options :: keyword()) :: :ok
```

**Options:**
- `:log_level` - Log level for events (default: `:info`)
- `:enable_metrics` - Enable metrics collection (default: `true`)
- `:enable_health_checks` - Enable health monitoring (default: `true`)

**Example:**
```elixir
Prismatic.Event.Telemetry.attach_default_handlers(
  log_level: :debug,
  enable_metrics: true,
  enable_health_checks: true
)
```

### detach_default_handlers/0

Removes default telemetry handlers.

**Signature:**
```elixir
@spec detach_default_handlers() :: :ok
```

## Error Types

### Protocol Errors

- `:invalid_config` - Configuration validation failed
- `:invalid_event` - Event validation failed
- `:invalid_pattern` - Pattern syntax error
- `:timeout` - Operation timed out
- `:backend_unavailable` - Backend service unavailable

### Backend Errors

- `:circuit_breaker_open` - Circuit breaker protecting backend
- `:max_subscriptions_exceeded` - Subscription limit reached
- `:storage_full` - Event storage capacity exceeded
- `:write_failed` - Storage write operation failed

### Network Errors

- `:econnrefused` - Connection refused
- `:timeout` - Network timeout
- `:nxdomain` - DNS resolution failed

## Configuration Reference

### Common Configuration

```elixir
%{
  backend_type: :in_memory | :phoenix_pubsub | :test,
  name: atom(),                    # Unique system identifier
  timeout: 30_000,                 # Request timeout (milliseconds)
  max_retries: 3,                  # Retry attempts for retryable errors
  enable_sourcing: false,          # Enable event persistence
  max_events: 1_000_000,           # Maximum stored events
  circuit_breaker: %{              # Circuit breaker configuration
    failure_threshold: 5,          # Failures before opening
    recovery_timeout: 60_000,      # Time before retry (ms)
    success_threshold: 2           # Successes to close circuit
  }
}
```

### In-Memory Backend Configuration

```elixir
%{
  max_subscriptions: 10_000,       # Maximum active subscriptions
  pattern_cache_size: 1_000,       # Pattern matching cache size
  cleanup_interval: 300_000,       # Storage cleanup interval (ms)
  table_options: [                 # ETS table options
    :set,
    :public,
    {:read_concurrency, true},
    {:write_concurrency, true}
  ]
}
```

### Phoenix PubSub Backend Configuration

```elixir
%{
  pubsub_name: MyApp.PubSub,       # PubSub process name
  topic_prefix: "events",          # Topic namespace prefix
  enable_pattern_topics: true,     # Use pattern-based topics
  broadcast_options: []            # Phoenix.PubSub broadcast options
}
```

### Test Backend Configuration

```elixir
%{
  responses: %{                    # Predefined responses
    "error.test" => {:error, :simulated_failure},
    "slow.test" => {:ok, "event_id", 1000}  # Delay in ms
  },
  track_events: true,              # Track published events
  max_tracked_events: 1000         # Maximum tracked events
}
```

## Performance Guidelines

### Optimization Tips

1. **Use Exact Patterns**: Exact matches are O(1) vs O(n) for wildcards
2. **Cache Compiled Patterns**: Pre-compile frequently used patterns
3. **Batch Operations**: Group related events when possible
4. **Monitor Memory**: Set appropriate `max_events` limits
5. **Use Appropriate Backend**: In-memory for single-node, PubSub for distributed

### Performance Characteristics

| Operation | In-Memory Backend | Phoenix PubSub Backend |
|-----------|-------------------|------------------------|
| Publish Event | ~100μs | ~500μs |
| Pattern Match | <1ms | <1ms |
| Subscribe | ~10ms | ~20ms |
| Event Replay | ~50k events/sec | N/A |

### Memory Usage

- **Base overhead**: ~10MB for event bus and registry
- **Per event**: ~1KB average (depends on payload size)
- **Per subscription**: ~500 bytes
- **Pattern cache**: ~100 bytes per cached pattern

## Migration Guide

### From Manual Event Handling

**Before:**
```elixir
# Manual GenServer-based events
GenServer.cast(UserManager, {:user_updated, user_id, changes})
```

**After:**
```elixir
# Event System
event = %{
  type: "user.profile.updated",
  payload: %{user_id: user_id, changes: changes}
}
Prismatic.Event.Protocol.publish(config, event)
```

### From Phoenix PubSub

**Before:**
```elixir
Phoenix.PubSub.broadcast(MyApp.PubSub, "users", {:user_updated, user})
Phoenix.PubSub.subscribe(MyApp.PubSub, "users")
```

**After:**
```elixir
# More structured with pattern matching
event = %{
  type: "user.profile.updated",
  payload: %{user: user}
}
Prismatic.Event.Protocol.publish(config, event)

Prismatic.Event.Protocol.subscribe(config, "user.**", &handle_user_event/1)