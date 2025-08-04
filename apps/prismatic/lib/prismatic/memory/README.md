# Prismatic Memory Protocol System

A comprehensive, multi-layered memory system for the Prismatic AI Agent Framework, implementing proven memory solutions with strict quality standards.

## Overview

The Memory Protocol system provides a unified interface for memory operations across different memory types and backend implementations. It follows an alpine-style, bottom-up development approach with zero compilation warnings and comprehensive type safety.

## Architecture

### Core Components

1. **Memory Protocol** (`lib/prismatic/memory/protocol.ex`)
   - Defines the behavior contract for all memory backends
   - Provides unified API for store, retrieve, search, forget, and consolidate operations
   - Includes circuit breaker protection and retry logic
   - Comprehensive error handling and validation

2. **Memory Manager** (`lib/prismatic/memory/manager.ex`)
   - Coordinates multi-layered memory system
   - Provides high-level API for memory operations
   - Manages backend configurations and lifecycle
   - Supports different memory types: working, episodic, semantic, procedural

3. **Backend Implementations**
   - **CachexBackend** (`lib/prismatic/memory/impl/cachex_backend.ex`) - High-performance in-memory cache
   - **NebulexBackend** (`lib/prismatic/memory/impl/nebulex_backend.ex`) - Distributed cache system
   - **MnesiaBackend** (`lib/prismatic/memory/impl/mnesia_backend.ex`) - Persistent distributed database
   - **LayeredBackend** (`lib/prismatic/memory/impl/layered_backend.ex`) - Orchestrates multiple backends
   - **TestBackend** (`lib/prismatic/memory/impl/test_backend.ex`) - ETS-based testing implementation

4. **Supporting Infrastructure**
   - **CircuitBreaker** (`lib/prismatic/memory/backend/circuit_breaker.ex`) - Fault tolerance
   - **RetryLogic** (`lib/prismatic/memory/backend/retry_logic.ex`) - Exponential backoff retry
   - **ExpirationPolicy** (`lib/prismatic/memory/expiration_policy.ex`) - TTL and eviction management
   - **SearchEngine** (`lib/prismatic/memory/search_engine.ex`) - Advanced search capabilities
   - **Metrics** (`lib/prismatic/memory/metrics.ex`) - Comprehensive observability

## Memory Types

### Working Memory (`:working`)
- **Backend**: Cachex
- **Purpose**: Short-term, high-speed cache for active processing
- **TTL**: 30 minutes
- **Max Size**: 10,000 entries
- **Use Case**: Current task state, temporary calculations

### Episodic Memory (`:episodic`)
- **Backend**: Nebulex
- **Purpose**: Medium-term distributed cache for experiences
- **TTL**: 24 hours
- **Max Size**: 100,000 entries
- **Use Case**: Recent interactions, session data

### Semantic Memory (`:semantic`)
- **Backend**: Mnesia
- **Purpose**: Long-term persistent storage for facts and knowledge
- **TTL**: None (persistent)
- **Max Size**: Unlimited
- **Use Case**: Learned facts, general knowledge, patterns

### Procedural Memory (`:procedural`)
- **Backend**: Mnesia
- **Purpose**: Long-term storage for skills and procedures
- **TTL**: None (persistent)
- **Max Size**: Unlimited
- **Use Case**: Learned procedures, workflows, skills

## Features

### Fault Tolerance
- **Circuit Breaker**: Prevents cascading failures with configurable thresholds
- **Retry Logic**: Exponential backoff with jitter for transient failures
- **Health Monitoring**: Continuous backend health checks

### Search Capabilities
- **Pattern Matching**: Wildcard and regex pattern support
- **Fuzzy Search**: Approximate string matching with configurable distance
- **Semantic Search**: Vector-based similarity search (simplified implementation)
- **Full-Text Search**: TF-IDF ranking with field weights
- **Composite Search**: Combination of multiple search strategies

### Expiration Policies
- **TTL-based**: Time-based expiration
- **LRU**: Least Recently Used eviction
- **LFU**: Least Frequently Used eviction
- **Size-based**: Capacity-based eviction
- **Custom**: User-defined expiration logic

### Observability
- **Performance Metrics**: Operation latency, throughput, error rates
- **Usage Metrics**: Memory utilization, entry counts, cache hit rates
- **Health Metrics**: Circuit breaker states, backend availability
- **Telemetry Integration**: Real-time monitoring with Telemetry
- **Prometheus Export**: Standard metrics format

## Usage Examples

### Basic Operations

```elixir
# Start the memory manager
{:ok, _} = Prismatic.Memory.Manager.start_link()

# Store data in working memory
:ok = Prismatic.Memory.Manager.store(:memory_manager, "current_task", 
  %{task: "analyze_document", status: :in_progress}, :working)

# Retrieve data
{:ok, task} = Prismatic.Memory.Manager.retrieve(:memory_manager, "current_task", :working)

# Search across memory types
{:ok, results} = Prismatic.Memory.Manager.search(:memory_manager, 
  %{task: "analyze"}, [:working, :episodic])

# Consolidate memories
:ok = Prismatic.Memory.Manager.consolidate(:memory_manager)
```

### Advanced Search

```elixir
# Pattern search
query = Prismatic.Memory.SearchEngine.pattern_query("user_*", [:key])
{:ok, results} = Prismatic.Memory.SearchEngine.search(entries, query)

# Fuzzy search
query = Prismatic.Memory.SearchEngine.fuzzy_query("alice", 2, [:value])
{:ok, results} = Prismatic.Memory.SearchEngine.search(entries, query)

# Semantic search
query = Prismatic.Memory.SearchEngine.semantic_query("machine learning", 0.7)
{:ok, results} = Prismatic.Memory.SearchEngine.search(entries, query)
```

### Metrics Collection

```elixir
# Start metrics collection
{:ok, _} = Prismatic.Memory.Metrics.start_link()

# Record operation metrics
Prismatic.Memory.Metrics.record_operation(:store, :working, 15.2, :success, :cachex)

# Get current metrics
metrics = Prismatic.Memory.Metrics.get_metrics()

# Export Prometheus format
prometheus_data = Prismatic.Memory.Metrics.export_prometheus()
```

## Configuration

### Dependencies (mix.exs)

```elixir
defp deps do
  [
    {:cachex, "~> 3.6"},
    {:nebulex, "~> 2.6"},
    {:shards, "~> 1.1"},
    {:decorator, "~> 1.4"},
    {:telemetry_registry, "~> 0.3"}
  ]
end

defp extra_applications do
  [:logger, :mnesia]
end
```

### Application Configuration

```elixir
config :prismatic,
  circuit_breaker_failure_threshold: 5,
  circuit_breaker_reset_timeout: 60_000,
  memory_retry_max_attempts: 3,
  memory_retry_base_delay: 1_000
```

## Quality Standards

### Compilation
- **Zero Warnings**: All code compiles with `--warnings-as-errors`
- **Strict Mode**: Uses `--strict` flag for enhanced checking
- **Type Safety**: Comprehensive `@spec` annotations for all public functions

### Testing
- **Comprehensive Coverage**: Doctests and unit tests for all modules
- **Property-Based Testing**: Uses StreamData for robust testing
- **Integration Tests**: End-to-end testing of memory operations

### Documentation
- **Alpine Style**: Comprehensive module documentation with examples
- **Doctests**: Executable examples in documentation
- **Type Specifications**: Detailed type annotations for all functions

### Monitoring
- **Telemetry Events**: Comprehensive event emission for monitoring
- **Health Checks**: Continuous backend health monitoring
- **Performance Metrics**: Detailed performance and usage tracking

## Backend Details

### Cachex Backend
- **Storage**: In-memory ETS tables
- **Features**: TTL support, size limits, LRU eviction
- **Performance**: Sub-millisecond operations
- **Use Case**: High-frequency, short-term data

### Nebulex Backend
- **Storage**: Distributed cache with multiple adapters
- **Features**: Clustering, partitioning, replication
- **Performance**: Low-latency distributed operations
- **Use Case**: Shared state across nodes

### Mnesia Backend
- **Storage**: Distributed database with ACID properties
- **Features**: Transactions, replication, persistence
- **Performance**: Consistent, durable operations
- **Use Case**: Critical, long-term data

## Error Handling

The system provides comprehensive error classification:

- **Storage Errors**: `:storage_full`, `:write_failed`, `:read_failed`
- **Network Errors**: `:timeout`, `:econnrefused`, `:enetunreach`
- **Validation**: `:invalid_key`, `:invalid_value`, `:invalid_memory_type`
- **Circuit Breaker**: `:circuit_breaker_open`
- **Not Found**: `:not_found`, `:key_not_found`

## Performance Characteristics

### Working Memory (Cachex)
- **Latency**: < 1ms for most operations
- **Throughput**: > 100K ops/sec
- **Memory**: Configurable limits with LRU eviction

### Episodic Memory (Nebulex)
- **Latency**: < 5ms for local operations
- **Throughput**: > 50K ops/sec
- **Distribution**: Automatic partitioning and replication

### Semantic/Procedural Memory (Mnesia)
- **Latency**: < 10ms for simple operations
- **Throughput**: > 10K ops/sec
- **Durability**: ACID transactions with disk persistence

## Future Enhancements

1. **Vector Embeddings**: True semantic search with embeddings
2. **Compression**: Automatic data compression for large values
3. **Encryption**: At-rest and in-transit encryption
4. **Backup/Restore**: Automated backup and recovery
5. **Multi-tenancy**: Isolated memory spaces per tenant
6. **Query Language**: SQL-like query interface
7. **Stream Processing**: Real-time memory stream processing

## Contributing

When contributing to the memory system:

1. Maintain zero compilation warnings
2. Add comprehensive tests and documentation
3. Follow the alpine-style documentation approach
4. Include type specifications for all public functions
5. Emit appropriate telemetry events
6. Handle all error cases explicitly

## License

Part of the Prismatic AI Agent Framework.