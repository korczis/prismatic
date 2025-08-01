# Performance Optimization

Comprehensive performance optimization guidelines and best practices for the Prismatic application, covering application code, database queries, infrastructure, and monitoring.

## ⏱️ Time Estimates

📖 Reading time: 25 minutes | 🔧 Implementation time: 2-4 hours | 📊 Skill level: Intermediate

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > [Guides](README.md) > Performance Optimization

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to guides index
- **🏠 [Documentation Home](../README.md)** - Main documentation index
- **🔍 [Search Documentation](../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Security Guidelines](security-guidelines.md) - Security considerations for performance optimizations
- [Architecture Overview](../core/architecture-overview.md) - System architecture and design patterns
- [Database Schema](../reference/database-schema.md) - Database structure and optimization opportunities
- [Monitoring Setup](../operations/monitoring-setup.md) - Performance monitoring and alerting
- [System Diagrams](../architecture/system-diagrams.md) - Visual representation of system performance bottlenecks
<!-- NAV_END -->

## Overview

Performance optimization is crucial for maintaining a responsive, scalable, and cost-effective Prismatic application. This guide covers performance considerations across all layers of the system, from application code to infrastructure, providing both preventive best practices and reactive optimization strategies.

## Performance Principles

### Optimization Philosophy
- **Measure First** - Always profile and measure before optimizing
- **Identify Bottlenecks** - Focus optimization efforts on actual performance bottlenecks
- **Trade-off Awareness** - Understand the trade-offs between performance, complexity, and maintainability
- **User-Centric Metrics** - Optimize for metrics that directly impact user experience

### Performance Budgets
- **Response Time Targets** - API responses < 200ms, page loads < 2s
- **Resource Utilization** - CPU < 70%, Memory < 80%, Database connections < 80%
- **Throughput Goals** - Handle 1000+ concurrent users, 10,000+ requests/minute
- **Availability Standards** - 99.9% uptime, < 1s recovery time

## Application Performance

### Elixir/Phoenix Optimization

#### Process Management
```elixir
# Efficient GenServer implementation
defmodule Prismatic.Cache do
  use GenServer

  # Use ETS for fast in-memory lookups
  def init(_) do
    table = :ets.new(__MODULE__, [:set, :protected, :named_table])
    {:ok, %{table: table}}
  end

  # Batch operations to reduce message passing
  def handle_call({:get_batch, keys}, _from, state) do
    results = Enum.map(keys, &:ets.lookup(state.table, &1))
    {:reply, results, state}
  end
end
```

#### Memory Management
- **Process Lifecycle** - Properly manage GenServer and Agent lifecycles
- **Message Queue Monitoring** - Monitor and prevent message queue buildup
- **Garbage Collection** - Tune garbage collection settings for workload
- **Memory Leaks** - Regular monitoring for memory leaks in long-running processes

#### Concurrency Optimization
```elixir
# Use Task.async_stream for concurrent operations
def process_data_concurrently(data_list) do
  data_list
  |> Task.async_stream(&process_item/1, max_concurrency: 10, timeout: 5000)
  |> Enum.to_list()
end

# Implement backpressure for high-volume operations
def handle_high_volume_requests(requests) do
  requests
  |> Flow.from_enumerable()
  |> Flow.partition()
  |> Flow.map(&process_request/1)
  |> Enum.to_list()
end
```

### Phoenix Web Layer Optimization

#### Controller Performance
```elixir
# Efficient data loading with preloading
def show(conn, %{"id" => id}) do
  user = 
    User
    |> preload([:profile, :settings, posts: :comments])
    |> Repo.get!(id)
  
  render(conn, "show.html", user: user)
end

# Use Phoenix.View for expensive computations
defmodule PrismaticWeb.UserView do
  def expensive_calculation(data) do
    # Cache expensive calculations
    ConCache.get_or_store(:view_cache, cache_key(data), fn ->
      perform_calculation(data)
    end)
  end
end
```

#### Template Optimization
- **Minimize Database Calls** - Preload associations to avoid N+1 queries
- **Cache Fragments** - Use Phoenix's template fragment caching
- **Lazy Loading** - Implement lazy loading for non-critical content
- **Asset Optimization** - Optimize CSS/JS assets and implement CDN

#### LiveView Performance
```elixir
# Optimize LiveView updates
def handle_event("search", %{"query" => query}, socket) do
  # Debounce search requests
  Process.send_after(self(), {:perform_search, query}, 300)
  {:noreply, assign(socket, searching: true)}
end

# Use temporary assigns for large data
def handle_info({:search_results, results}, socket) do
  {:noreply, 
   socket
   |> assign(results: results)
   |> assign(searching: false)
   |> assign(temp_data: nil)}  # Clear temporary data
end
```

## Database Performance

### Query Optimization

#### Efficient Ecto Queries
```elixir
# Avoid N+1 queries with preloading
users = 
  User
  |> preload([u], posts: [comments: :author])
  |> Repo.all()

# Use joins instead of separate queries
popular_posts = 
  from(p in Post,
    join: c in assoc(p, :comments),
    group_by: p.id,
    having: count(c.id) > 10,
    select: p
  )
  |> Repo.all()

# Optimize with database functions
monthly_stats = 
  from(o in Order,
    where: o.inserted_at >= ^start_date,
    group_by: fragment("date_trunc('month', ?)", o.inserted_at),
    select: %{
      month: fragment("date_trunc('month', ?)", o.inserted_at),
      total: sum(o.amount),
      count: count(o.id)
    }
  )
  |> Repo.all()
```

#### Index Strategy
```sql
-- Composite indexes for common query patterns
CREATE INDEX idx_users_status_created ON users(status, inserted_at);
CREATE INDEX idx_posts_author_published ON posts(author_id, published_at) 
  WHERE status = 'published';

-- Partial indexes for filtered queries  
CREATE INDEX idx_active_users ON users(email) WHERE active = true;

-- Covering indexes to avoid table lookups
CREATE INDEX idx_user_summary ON users(id) INCLUDE (name, email, status);
```

#### Connection Pool Optimization
```elixir
# Optimize Repo configuration
config :prismatic, Prismatic.Repo,
  pool_size: 15,
  checkout_timeout: 5_000,
  ownership_timeout: 10_000,
  timeout: 15_000,
  pool_overflow: 5
```

### Caching Strategies

#### Application-Level Caching
```elixir
# Multi-level caching strategy
defmodule Prismatic.UserService do
  @cache_ttl :timer.minutes(15)

  def get_user_with_stats(user_id) do
    # L1: Process cache
    case Process.get({:user_cache, user_id}) do
      nil ->
        # L2: Application cache (ConCache/ETS)
        case ConCache.get(:user_cache, user_id) do
          nil ->
            # L3: Database
            user = fetch_user_from_db(user_id)
            ConCache.put(:user_cache, user_id, user, ttl: @cache_ttl)
            Process.put({:user_cache, user_id}, user)
            user
          cached_user ->
            Process.put({:user_cache, user_id}, cached_user)
            cached_user
        end
      cached_user -> cached_user
    end
  end
end
```

#### Query Result Caching
```elixir
# Cache expensive aggregations
defmodule Prismatic.Analytics do
  def dashboard_metrics(date_range) do
    cache_key = "dashboard:#{Date.to_string(date_range.start)}:#{Date.to_string(date_range.end)}"
    
    ConCache.get_or_store(:metrics_cache, cache_key, fn ->
      calculate_dashboard_metrics(date_range)
    end, ttl: :timer.hours(1))
  end

  # Background cache warming
  def warm_cache do
    popular_date_ranges()
    |> Task.async_stream(&dashboard_metrics/1, max_concurrency: 5)
    |> Stream.run()
  end
end
```

#### HTTP Caching
```elixir
# ETags for cache validation
def show(conn, %{"id" => id}) do
  user = Repo.get!(User, id)
  etag = generate_etag(user)
  
  conn
  |> put_resp_header("etag", etag)
  |> put_resp_header("cache-control", "max-age=300, must-revalidate")
  |> render("show.json", user: user)
end
```

## Infrastructure Performance

### Load Balancing and Scaling

#### Horizontal Scaling
```yaml
# Docker Compose scaling configuration
version: '3.8'
services:
  app:
    image: prismatic:latest
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
```

#### Load Balancer Configuration
```nginx
# Nginx load balancing with health checks
upstream prismatic_backend {
    least_conn;
    server app1:4000 max_fails=3 fail_timeout=30s;
    server app2:4000 max_fails=3 fail_timeout=30s;
    server app3:4000 max_fails=3 fail_timeout=30s;
}

# Connection pooling and keep-alive
proxy_http_version 1.1;
proxy_set_header Connection "";
proxy_connect_timeout 5s;
proxy_send_timeout 10s;
proxy_read_timeout 10s;
```

### CDN and Asset Optimization

#### Static Asset Optimization
```elixir
# Phoenix asset configuration
config :prismatic_web, PrismaticWeb.Endpoint,
  static_url: [host: "cdn.example.com", port: 443, scheme: "https"],
  cache_static_manifest: "priv/static/cache_manifest.json"

# Efficient asset serving
defmodule PrismaticWeb.Endpoint do
  plug Plug.Static,
    at: "/",
    from: :prismatic_web,
    gzip: true,
    cache_control_for_etags: "public, max-age=31536000",
    headers: %{"access-control-allow-origin" => "*"}
end
```

#### Image Optimization
```elixir
# Dynamic image resizing and optimization
defmodule Prismatic.ImageProcessor do
  def resize_and_optimize(image_path, dimensions) do
    image_path
    |> Mogrify.open()
    |> Mogrify.resize_to_limit(dimensions)
    |> Mogrify.format("webp")
    |> Mogrify.quality(85)
    |> Mogrify.save(path: optimized_path(image_path))
  end
end
```

### Database Infrastructure

#### Read Replicas
```elixir
# Read replica configuration
config :prismatic, Prismatic.ReadRepo,
  adapter: Ecto.Adapters.Postgres,
  url: System.get_env("READ_DATABASE_URL"),
  pool_size: 20

# Repository routing
defmodule Prismatic.DataService do
  def read_user(id), do: ReadRepo.get(User, id)
  def create_user(attrs), do: WriteRepo.insert(User.changeset(%User{}, attrs))
end
```

#### Connection Pooling
```elixir
# PgBouncer configuration for connection pooling
# pgbouncer.ini
[databases]
prismatic = host=localhost port=5432 dbname=prismatic_prod

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
min_pool_size = 5
reserve_pool_size = 5
```

## Monitoring and Profiling

### Application Monitoring

#### Performance Metrics
```elixir
# Custom metrics with Telemetry
defmodule Prismatic.Telemetry do
  def handle_event([:prismatic, :user, :login], measurements, metadata, _config) do
    :telemetry_metrics_prometheus_core.execute(
      [:prismatic, :user, :login, :duration],
      measurements.duration,
      metadata
    )
  end
end

# Phoenix LiveDashboard metrics
config :prismatic_web, PrismaticWeb.Telemetry,
  metrics: [
    # Application metrics
    summary("phoenix.endpoint.stop.duration", unit: {:native, :millisecond}),
    summary("phoenix.router.dispatch.stop.duration", unit: {:native, :millisecond}),
    
    # Database metrics
    summary("prismatic.repo.query.total_time", unit: {:native, :millisecond}),
    counter("prismatic.repo.query.count"),
    
    # Custom business metrics
    counter("prismatic.user.registration.count"),
    summary("prismatic.order.processing.duration", unit: {:native, :millisecond})
  ]
```

#### APM Integration
```elixir
# New Relic integration
config :new_relic_agent,
  app_name: "Prismatic",
  license_key: System.get_env("NEW_RELIC_LICENSE_KEY")

# AppSignal integration  
config :appsignal, :config,
  otp_app: :prismatic,
  name: "Prismatic",
  push_api_key: System.get_env("APPSIGNAL_PUSH_API_KEY")
```

### Database Monitoring

#### Query Performance
```sql
-- Monitor slow queries
SELECT query, mean_time, calls, total_time
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;

-- Index usage analysis
SELECT schemaname, tablename, attname, n_distinct, correlation 
FROM pg_stats 
WHERE tablename = 'users';
```

#### Connection Monitoring
```elixir
# Database connection monitoring
defmodule Prismatic.DbMonitor do
  def check_connection_health do
    %{
      active_connections: get_active_connections(),
      pool_size: Prismatic.Repo.config()[:pool_size],
      checkout_timeout: get_checkout_timeouts(),
      slow_queries: get_slow_queries()
    }
  end
end
```

## Performance Testing

### Load Testing

#### Artillery.js Configuration
```yaml
# artillery-config.yml
config:
  target: 'http://localhost:4000'
  phases:
    - duration: 60
      arrivalRate: 10
    - duration: 120
      arrivalRate: 50
    - duration: 60
      arrivalRate: 100
scenarios:
  - name: "User journey"
    flow:
      - get:
          url: "/api/users/{{ $randomInt(1, 1000) }}"
      - post:
          url: "/api/posts"
          json:
            title: "Performance test post"
            content: "Testing application performance"
```

#### k6 Performance Tests
```javascript
// performance-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '5m', target: 200 },
    { duration: '2m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.1'],
  },
};

export default function() {
  let response = http.get('http://localhost:4000/api/health');
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 200ms': (r) => r.timings.duration < 200,
  });
  sleep(1);
}
```

### Benchmarking

#### Mix Benchee Tests
```elixir
# benchmarks/user_queries.exs
data = setup_test_data()

Benchee.run(%{
  "preload all" => fn -> 
    Repo.all(from u in User, preload: [:posts, :profile])
  end,
  "lazy load" => fn ->
    users = Repo.all(User)
    Enum.map(users, &Repo.preload(&1, [:posts, :profile]))
  end,
  "join query" => fn ->
    Repo.all(from u in User, 
      join: p in assoc(u, :posts),
      join: pr in assoc(u, :profile),
      select: {u, p, pr})
  end
})
```

#### Memory Profiling
```elixir
# Memory usage profiling
defmodule Prismatic.ProfilerTest do
  def profile_memory_usage do
    :fprof.apply(&expensive_operation/0, [])
    :fprof.profile()
    :fprof.analyse([dest: "profile_results.txt"])
  end

  def profile_with_eprof do
    :eprof.start()
    :eprof.start_profiling([self()])
    expensive_operation()
    :eprof.stop_profiling()
    :eprof.analyze()
  end
end
```

## Performance Optimization Checklist

### Development Phase
- [ ] **Code Review** - Review code for performance anti-patterns
- [ ] **Database Queries** - Optimize N+1 queries and add appropriate indexes  
- [ ] **Caching Strategy** - Implement multi-level caching where appropriate
- [ ] **Asset Optimization** - Minify and compress static assets
- [ ] **Memory Management** - Monitor for memory leaks and optimize garbage collection

### Testing Phase
- [ ] **Load Testing** - Run load tests to identify bottlenecks
- [ ] **Performance Benchmarks** - Establish performance baselines
- [ ] **Database Performance** - Analyze query execution plans
- [ ] **Memory Profiling** - Profile memory usage under load
- [ ] **Monitoring Setup** - Configure performance monitoring and alerting

### Production Phase
- [ ] **Infrastructure Scaling** - Scale resources based on load patterns
- [ ] **CDN Configuration** - Optimize content delivery network setup
- [ ] **Database Optimization** - Tune database configuration for production workload
- [ ] **Cache Warming** - Implement cache warming strategies
- [ ] **Performance Monitoring** - Continuous monitoring and alerting

## Performance Troubleshooting

### Common Performance Issues

#### High Response Times
1. **Identify Bottleneck** - Use APM tools to identify slow endpoints
2. **Database Analysis** - Check for slow queries and missing indexes
3. **Memory Usage** - Monitor memory consumption and garbage collection
4. **Network Latency** - Analyze network latency and connection pooling

#### Memory Issues
1. **Memory Leaks** - Profile long-running processes for memory leaks
2. **Process Monitoring** - Monitor GenServer message queues
3. **Garbage Collection** - Tune garbage collection settings
4. **Cache Management** - Implement proper cache eviction policies

#### Database Performance
1. **Query Optimization** - Analyze and optimize slow queries
2. **Index Management** - Add missing indexes and remove unused ones
3. **Connection Pooling** - Optimize connection pool configuration
4. **Read Replicas** - Distribute read load across replicas

### Performance Recovery Procedures
1. **Immediate Response** - Scale resources horizontally if possible
2. **Cache Clearing** - Clear potentially corrupted caches
3. **Database Optimization** - Apply immediate query optimizations
4. **Monitoring** - Increase monitoring granularity during incidents
5. **Rollback Plan** - Maintain ability to rollback performance-impacting changes

## Related Documentation

- [Security Guidelines](security-guidelines.md) - Security considerations when implementing performance optimizations
- [Architecture Overview](../core/architecture-overview.md) - Understanding system architecture for optimization opportunities
- [Database Schema](../reference/database-schema.md) - Database structure and indexing strategies
- [Monitoring Setup](../operations/monitoring-setup.md) - Comprehensive performance monitoring configuration
- [System Diagrams](../architecture/system-diagrams.md) - Visual system architecture for identifying bottlenecks
- [Developer Experience](developer-experience.md) - Development tools and practices that support performance

---

**Performance optimization is an ongoing process. Regular monitoring, testing, and incremental improvements are key to maintaining optimal system performance.**