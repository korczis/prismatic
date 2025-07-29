# Monitoring Setup

Comprehensive guide for setting up monitoring, observability, and alerting for the Prismatic application across all environments.

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > [Operations](README.md) > Monitoring Setup

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to operations index
- **🏠 [Documentation Home](../README.md)** - Main documentation index
- **🔍 [Search Documentation](../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Performance Optimization](../guides/performance-optimization.md) - Performance monitoring and tuning
- [Security Guidelines](../guides/security-guidelines.md) - Security monitoring and alerting
- [System Diagrams](../architecture/system-diagrams.md) - Monitoring architecture visualization
- [Database Setup](database-setup.md) - Database monitoring configuration
- [CI/CD Configuration](cicd-configuration.md) - Pipeline monitoring integration
<!-- NAV_END -->

## Overview

This guide provides comprehensive instructions for setting up monitoring, observability, and alerting for the Prismatic application. It covers application metrics, infrastructure monitoring, log aggregation, distributed tracing, and alerting systems to ensure optimal system health and performance.

## Monitoring Architecture

### Three Pillars of Observability
1. **Metrics** - Quantitative data about system performance
2. **Logs** - Detailed event records for debugging and analysis
3. **Traces** - Request flow through distributed system components

### Monitoring Stack Components
- **Metrics Collection**: Prometheus, StatsD
- **Log Aggregation**: ELK Stack (Elasticsearch, Logstash, Kibana)
- **Distributed Tracing**: Jaeger, Zipkin
- **Visualization**: Grafana, Kibana
- **Alerting**: AlertManager, PagerDuty
- **APM**: New Relic, DataDog, AppSignal

## Application Metrics

### Telemetry Configuration

#### Basic Telemetry Setup
```elixir
# lib/prismatic_web/telemetry.ex
defmodule PrismaticWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000},
      # Add reporters as children of your supervision tree
      {TelemetryMetricsPrometheus, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond},
        tags: [:method, :route]
      ),
      summary("phoenix.router.dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      
      # Database Metrics
      summary("prismatic.repo.query.total_time",
        unit: {:native, :millisecond},
        tags: [:source, :command]
      ),
      counter("prismatic.repo.query.count",
        tags: [:source, :command, :result]
      ),
      
      # LiveView Metrics
      summary("phoenix.live_view.mount.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view, :connected?]
      ),
      counter("phoenix.live_view.handle_event.stop.count",
        tags: [:view, :event]
      ),
      
      # Custom Business Metrics
      counter("prismatic.users.registration.count",
        tags: [:source, :plan]
      ),
      counter("prismatic.posts.published.count",
        tags: [:category, :author_type]
      ),
      summary("prismatic.posts.processing.duration",
        unit: {:native, :millisecond},
        tags: [:processing_type]
      ),
      counter("prismatic.auth.login.count",
        tags: [:method, :result]
      ),
      counter("prismatic.payments.processed.count",
        tags: [:status, :amount_range]
      ),
      
      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io"),
      
      # System Metrics
      last_value("vm.memory.processes", unit: {:byte, :kilobyte}),
      last_value("vm.memory.atoms", unit: {:byte, :kilobyte}),
      last_value("vm.memory.binary", unit: {:byte, :kilobyte}),
      last_value("vm.memory.code", unit: {:byte, :kilobyte}),
      last_value("vm.memory.ets", unit: {:byte, :kilobyte}),
      
      # HTTP Metrics
      counter("phoenix.endpoint.stop.count",
        tags: [:method, :status_class]
      ),
      distribution("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond},
        tags: [:method, :status_class],
        reporter_options: [
          buckets: [0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0]
        ]
      )
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically
      {__MODULE__, :dispatch_system_metrics, []},
      {:process_info, :info, [self(), [:message_queue_len, :memory]]}
    ]
  end

  def dispatch_system_metrics do
    :telemetry.execute([:vm, :memory], :erlang.memory())
    :telemetry.execute([:vm, :total_run_queue_lengths], 
      %{total: :erlang.statistics(:total_run_queue_lengths)})
  end
end
```

#### Custom Metrics Implementation
```elixir
# lib/prismatic/telemetry.ex
defmodule Prismatic.Telemetry do
  @doc """
  Emit custom business metrics
  """
  def emit_user_registration(user, source) do
    :telemetry.execute(
      [:prismatic, :users, :registration],
      %{count: 1},
      %{source: source, plan: user.plan, user_id: user.id}
    )
  end

  def emit_post_published(post) do
    :telemetry.execute(
      [:prismatic, :posts, :published],
      %{count: 1},
      %{
        category: post.category,
        author_type: get_author_type(post.author),
        post_id: post.id
      }
    )
  end

  def emit_payment_processed(payment) do
    :telemetry.execute(
      [:prismatic, :payments, :processed],
      %{count: 1, amount: payment.amount},
      %{
        status: payment.status,
        amount_range: get_amount_range(payment.amount),
        payment_id: payment.id
      }
    )
  end

  defp get_amount_range(amount) when amount < 1000, do: "under_10"
  defp get_amount_range(amount) when amount < 5000, do: "10_to_50"
  defp get_amount_range(amount) when amount < 10000, do: "50_to_100"
  defp get_amount_range(_), do: "over_100"
end
```

### Prometheus Integration

#### Prometheus Configuration
```elixir
# mix.exs dependencies
defp deps do
  [
    {:telemetry_metrics_prometheus, "~> 1.1"},
    {:telemetry_poller, "~> 1.0"}
  ]
end

# config/config.exs
config :telemetry_metrics_prometheus,
  port: 9568,
  metrics: PrismaticWeb.Telemetry.metrics()
```

#### Prometheus Scrape Configuration
```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prismatic-app'
    static_configs:
      - targets: ['app:9568']
    metrics_path: '/metrics'
    scrape_interval: 10s
    scrape_timeout: 5s

  - job_name: 'prismatic-postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'prismatic-redis'
    static_configs:
      - targets: ['redis-exporter:9121']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

rule_files:
  - "alerts/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
```

### StatsD Integration

#### StatsD Configuration
```elixir
# Alternative metrics collection via StatsD
# config/config.exs
config :statsd,
  host: {:system, "STATSD_HOST", "localhost"},
  port: {:system, "STATSD_PORT", 8125}

# Custom StatsD reporter
defmodule Prismatic.StatsD do
  @statsd_client Application.compile_env(:prismatic, :statsd_client, :statsd)

  def increment(metric, tags \\ []) do
    @statsd_client.increment("prismatic.#{metric}", 1, tags: tags)
  end

  def timing(metric, value, tags \\ []) do
    @statsd_client.timing("prismatic.#{metric}", value, tags: tags)
  end

  def gauge(metric, value, tags \\ []) do
    @statsd_client.gauge("prismatic.#{metric}", value, tags: tags)
  end
end
```

## Log Aggregation

### Structured Logging Setup

#### JSON Logger Configuration
```elixir
# mix.exs
defp deps do
  [
    {:logger_json, "~> 5.1"}
  ]
end

# config/prod.exs
config :logger, :console,
  format: {LoggerJSON.Formatters.BasicLogger, :format},
  metadata: [
    :request_id,
    :user_id,
    :organization_id,
    :session_id,
    :trace_id,
    :span_id
  ]

# Custom log formatter
defmodule Prismatic.LogFormatter do
  def format(level, message, timestamp, metadata) do
    %{
      "@timestamp" => format_timestamp(timestamp),
      level: level,
      message: to_string(message),
      application: "prismatic",
      environment: Application.get_env(:prismatic, :environment),
      node: Node.self(),
      pid: inspect(self())
    }
    |> Map.merge(format_metadata(metadata))
    |> Jason.encode!()
    |> Kernel.<>("\n")
  end

  defp format_timestamp({{year, month, day}, {hour, minute, second, millisecond}}) do
    "#{year}-#{pad(month)}-#{pad(day)}T#{pad(hour)}:#{pad(minute)}:#{pad(second)}.#{pad(millisecond, 3)}Z"
  end

  defp format_metadata(metadata) do
    metadata
    |> Enum.into(%{})
    |> Map.take([:request_id, :user_id, :organization_id, :session_id, :trace_id, :span_id])
  end

  defp pad(number, digits \\ 2) do
    number |> Integer.to_string() |> String.pad_leading(digits, "0")
  end
end
```

#### Application Logging Patterns
```elixir
# lib/prismatic/logging.ex
defmodule Prismatic.Logging do
  require Logger

  def log_user_action(user, action, resource, metadata \\ %{}) do
    Logger.info("User action performed",
      user_id: user.id,
      organization_id: user.organization_id,
      action: action,
      resource: resource,
      metadata: metadata
    )
  end

  def log_business_event(event, data) do
    Logger.info("Business event",
      event_type: event,
      data: data,
      timestamp: DateTime.utc_now()
    )
  end

  def log_performance_metric(operation, duration, metadata \\ %{}) do
    Logger.info("Performance metric",
      operation: operation,
      duration_ms: duration,
      metadata: metadata
    )
  end

  def log_security_event(event_type, severity, details) do
    Logger.warn("Security event",
      event_type: event_type,
      severity: severity,
      details: details,
      timestamp: DateTime.utc_now()
    )
  end
end
```

### ELK Stack Setup

#### Elasticsearch Configuration
```yaml
# docker-compose.yml
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.11.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
      - xpack.security.enabled=false
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
    networks:
      - monitoring

  logstash:
    image: docker.elastic.co/logstash/logstash:8.11.0
    container_name: logstash
    volumes:
      - ./logstash/config/logstash.yml:/usr/share/logstash/config/logstash.yml:ro
      - ./logstash/pipeline:/usr/share/logstash/pipeline:ro
    ports:
      - "5044:5044"
      - "5000:5000/tcp"
      - "5000:5000/udp"
      - "9600:9600"
    environment:
      LS_JAVA_OPTS: "-Xmx512m -Xms512m"
    networks:
      - monitoring
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:8.11.0
    container_name: kibana
    ports:
      - "5601:5601"
    environment:
      ELASTICSEARCH_URL: http://elasticsearch:9200
      ELASTICSEARCH_HOSTS: '["http://elasticsearch:9200"]'
    networks:
      - monitoring
    depends_on:
      - elasticsearch

volumes:
  elasticsearch_data:

networks:
  monitoring:
    driver: bridge
```

#### Logstash Pipeline Configuration
```ruby
# logstash/pipeline/prismatic.conf
input {
  beats {
    port => 5044
  }
  
  tcp {
    port => 5000
    codec => json_lines
  }
}

filter {
  if [application] == "prismatic" {
    # Parse timestamp
    date {
      match => [ "@timestamp", "ISO8601" ]
    }
    
    # Add environment tag
    mutate {
      add_tag => [ "%{environment}" ]
    }
    
    # Parse log level
    if [level] == "error" {
      mutate {
        add_tag => [ "error" ]
      }
    }
    
    # Extract user context
    if [user_id] {
      mutate {
        add_field => { "user_context" => "%{user_id}" }
      }
    }
    
    # Parse request ID
    if [request_id] {
      mutate {
        add_field => { "request_context" => "%{request_id}" }
      }
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "prismatic-logs-%{+YYYY.MM.dd}"
  }
  
  # Output errors to separate index
  if "error" in [tags] {
    elasticsearch {
      hosts => ["elasticsearch:9200"]
      index => "prismatic-errors-%{+YYYY.MM.dd}"
    }
  }
}
```

#### Filebeat Configuration
```yaml
# filebeat.yml
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/prismatic/*.log
  fields:
    application: prismatic
    environment: production
  fields_under_root: true
  multiline.pattern: '^\d{4}-\d{2}-\d{2}'
  multiline.negate: true
  multiline.match: after

output.logstash:
  hosts: ["logstash:5044"]

processors:
  - add_host_metadata:
      when.not.contains.tags: forwarded
```

## Distributed Tracing

### Jaeger Setup

#### Jaeger Configuration
```elixir
# mix.exs
defp deps do
  [
    {:opentelemetry, "~> 1.3"},
    {:opentelemetry_api, "~> 1.2"},
    {:opentelemetry_exporter, "~> 1.6"},
    {:opentelemetry_phoenix, "~> 1.1"},
    {:opentelemetry_ecto, "~> 1.1"}
  ]
end

# config/config.exs
config :opentelemetry,
  resource: [
    service: [
      name: "prismatic",
      version: Application.spec(:prismatic, :vsn)
    ]
  ]

# config/runtime.exs
if config_env() == :prod do
  config :opentelemetry, :processors,
    otel_batch_processor: %{
      exporter: {:otel_exporter_jaeger, %{
        endpoint: System.get_env("JAEGER_ENDPOINT", "http://jaeger:14268/api/traces")
      }}
    }
end
```

#### Custom Tracing
```elixir
# lib/prismatic/tracing.ex
defmodule Prismatic.Tracing do
  require OpenTelemetry.Tracer

  def trace_business_operation(operation_name, metadata \\ %{}, fun) do
    OpenTelemetry.Tracer.with_span operation_name, %{attributes: metadata} do
      fun.()
    end
  end

  def add_span_attributes(attributes) when is_map(attributes) do
    Enum.each(attributes, fn {key, value} ->
      OpenTelemetry.Span.set_attribute(key, value)
    end)
  end

  def trace_database_query(query_name, fun) do
    trace_business_operation("db.query", %{
      "db.operation" => query_name,
      "db.system" => "postgresql"
    }, fun)
  end

  def trace_external_api_call(service_name, endpoint, fun) do
    trace_business_operation("http.client", %{
      "http.service" => service_name,
      "http.endpoint" => endpoint
    }, fun)
  end
end
```

#### Jaeger Docker Setup
```yaml
# jaeger service in docker-compose.yml
  jaeger:
    image: jaegertracing/all-in-one:1.50
    container_name: jaeger
    ports:
      - "16686:16686"  # Jaeger UI
      - "14268:14268"  # HTTP collector
      - "6831:6831/udp"  # UDP collector
    environment:
      - COLLECTOR_OTLP_ENABLED=true
    networks:
      - monitoring
```

## Infrastructure Monitoring

### Node Exporter Setup

#### System Metrics Collection
```yaml
# docker-compose.yml - Node Exporter
  node-exporter:
    image: prom/node-exporter:v1.6.1
    container_name: node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"
    networks:
      - monitoring
```

### Database Monitoring

#### PostgreSQL Exporter
```yaml
# docker-compose.yml - PostgreSQL Exporter  
  postgres-exporter:
    image: prometheuscommunity/postgres-exporter:v0.13.2
    container_name: postgres-exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:postgres@db:5432/prismatic_prod?sslmode=disable"
    ports:
      - "9187:9187"
    networks:
      - monitoring
    depends_on:
      - db
```

#### Redis Exporter
```yaml
# docker-compose.yml - Redis Exporter
  redis-exporter:
    image: oliver006/redis_exporter:v1.55.0
    container_name: redis-exporter
    environment:
      REDIS_ADDR: "redis://redis:6379"
    ports:
      - "9121:9121"
    networks:
      - monitoring
    depends_on:
      - redis
```

## Visualization with Grafana

### Grafana Setup

#### Grafana Configuration
```yaml
# docker-compose.yml - Grafana
  grafana:
    image: grafana/grafana:10.2.0
    container_name: grafana
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
      - ./grafana/dashboards:/var/lib/grafana/dashboards
    networks:
      - monitoring
    depends_on:
      - prometheus

volumes:
  grafana_data:
```

#### Data Source Provisioning
```yaml
# grafana/provisioning/datasources/prometheus.yml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    
  - name: Elasticsearch
    type: elasticsearch
    access: proxy
    url: http://elasticsearch:9200
    database: "prismatic-logs-*"
    timeField: "@timestamp"
```

### Dashboard Configuration

#### Application Dashboard JSON
```json
{
  "dashboard": {
    "id": null,
    "title": "Prismatic Application Metrics",
    "tags": ["prismatic", "application"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(phoenix_endpoint_stop_count[5m])",
            "legendFormat": "Requests/sec"
          }
        ],
        "yAxes": [
          {
            "label": "requests/sec",
            "min": 0
          }
        ]
      },
      {
        "id": 2,
        "title": "Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(phoenix_endpoint_stop_duration_bucket[5m]))",
            "legendFormat": "95th percentile"
          },
          {
            "expr": "histogram_quantile(0.50, rate(phoenix_endpoint_stop_duration_bucket[5m]))",
            "legendFormat": "50th percentile"
          }
        ]
      },
      {
        "id": 3,
        "title": "Database Connections",
        "type": "graph",
        "targets": [
          {
            "expr": "prismatic_repo_pool_size",
            "legendFormat": "Pool Size"
          },
          {
            "expr": "prismatic_repo_pool_checked_out",
            "legendFormat": "Checked Out"
          }
        ]
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
```

## Alerting Configuration

### AlertManager Setup

#### AlertManager Configuration
```yaml
# alertmanager.yml
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@prismatic.example.com'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'
  routes:
  - match:
      severity: critical
    receiver: 'pagerduty'
  - match:
      severity: warning
    receiver: 'slack'

receivers:
- name: 'web.hook'
  webhook_configs:
  - url: 'http://127.0.0.1:5001/'

- name: 'pagerduty'
  pagerduty_configs:
  - service_key: 'your-pagerduty-service-key'
    description: 'Critical alert from Prismatic'

- name: 'slack'
  slack_configs:
  - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
    channel: '#alerts'
    username: 'AlertManager'
    text: 'Alert: {{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
```

### Alert Rules

#### Prometheus Alert Rules
```yaml
# alerts/application.yml
groups:
- name: prismatic.rules
  rules:
  # High error rate
  - alert: HighErrorRate
    expr: rate(phoenix_endpoint_stop_count{status_class="5xx"}[5m]) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High error rate detected"
      description: "Error rate is {{ $value }} errors per second"

  # High response time
  - alert: HighResponseTime
    expr: histogram_quantile(0.95, rate(phoenix_endpoint_stop_duration_bucket[5m])) > 1000
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High response time detected"
      description: "95th percentile response time is {{ $value }}ms"

  # Database connection pool exhaustion
  - alert: DatabaseConnectionPoolHigh
    expr: prismatic_repo_pool_checked_out / prismatic_repo_pool_size > 0.8
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "Database connection pool nearly exhausted"
      description: "{{ $value }}% of database connections are in use"

  # Memory usage high
  - alert: HighMemoryUsage
    expr: (vm_memory_total / (1024*1024*1024)) > 2
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage"
      description: "Memory usage is {{ $value }}GB"

  # Service down
  - alert: ServiceDown
    expr: up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Service is down"
      description: "{{ $labels.instance }} is down"
```

## APM Integration

### New Relic Setup

#### New Relic Configuration
```elixir
# mix.exs
defp deps do
  [
    {:new_relic_agent, "~> 1.27"}
  ]
end

# config/config.exs
config :new_relic_agent,
  app_name: "Prismatic",
  license_key: {:system, "NEW_RELIC_LICENSE_KEY"},
  harvest_enabled: true

# Custom instrumentation
defmodule Prismatic.NewRelicInstrumentation do
  use NewRelic.Tracer

  @trace :business_operation
  def process_payment(payment_params) do
    NewRelic.add_attributes(%{
      payment_amount: payment_params.amount,
      payment_method: payment_params.method
    })
    
    # Process payment logic
  end

  @trace :database_query
  def complex_report_query(params) do
    NewRelic.add_attributes(%{
      query_type: "report",
      date_range: params.date_range
    })
    
    # Query logic
  end
end
```

### AppSignal Integration

#### AppSignal Configuration
```elixir
# mix.exs
defp deps do
  [
    {:appsignal, "~> 2.8"}
  ]
end

# config/config.exs
config :appsignal, :config,
  otp_app: :prismatic,
  name: "Prismatic",
  push_api_key: {:system, "APPSIGNAL_PUSH_API_KEY"},
  env: Mix.env(),
  active: true

# Custom instrumentation
defmodule Prismatic.AppSignalInstrumentation do
  def track_business_event(event_name, metadata \\ %{}) do
    Appsignal.increment_counter("business_events", 1, %{event: event_name})
    Appsignal.add_distribution_value("business_event_processing", 
      System.monotonic_time(:millisecond), metadata)
  end
end
```

## Health Checks

### Application Health Endpoint

#### Health Check Implementation
```elixir
# lib/prismatic_web/controllers/health_controller.ex
defmodule PrismaticWeb.HealthController do
  use PrismaticWeb, :controller

  def check(conn, _params) do
    checks = %{
      database: check_database(),
      cache: check_cache(),
      external_apis: check_external_apis(),
      disk_space: check_disk_space(),
      memory: check_memory()
    }

    overall_status = if Enum.all?(checks, fn {_k, v} -> v.status == :ok end) do
      :ok
    else
      :error
    end

    status_code = case overall_status do
      :ok -> 200
      :error -> 503
    end

    conn
    |> put_status(status_code)
    |> json(%{
      status: overall_status,
      version: Application.spec(:prismatic, :vsn),
      environment: Application.get_env(:prismatic, :environment),
      timestamp: DateTime.utc_now(),
      checks: checks
    })
  end

  defp check_database do
    try do
      start_time = System.monotonic_time(:millisecond)
      Prismatic.Repo.query!("SELECT 1")
      response_time = System.monotonic_time(:millisecond) - start_time

      %{
        status: :ok,
        response_time_ms: response_time,
        connection_pool: get_pool_status()
      }
    rescue
      exception ->
        %{
          status: :error,
          error: Exception.message(exception)
        }
    end
  end

  defp check_cache do
    try do
      key = "health_check_#{:rand.uniform(1000)}"
      value = "test_value"
      
      # Test write/read
      :ok = Prismatic.Cache.put(key, value, ttl: 10)
      ^value = Prismatic.Cache.get(key)
      
      %{status: :ok}
    rescue
      exception ->
        %{
          status: :error,
          error: Exception.message(exception)
        }
    end
  end

  defp check_external_apis do
    %{
      stripe: check_stripe_api(),
      sendgrid: check_sendgrid_api()
    }
  end

  defp get_pool_status do
    pool_config = Prismatic.Repo.config()
    %{
      pool_size: pool_config[:pool_size],
      checked_out: get_checked_out_connections()
    }
  end
end
```

### Load Balancer Health Checks

#### Nginx Health Check Configuration
```nginx
# nginx.conf
upstream prismatic_backend {
    server app1:4000 max_fails=3 fail_timeout=30s;
    server app2:4000 max_fails=3 fail_timeout=30s;
    server app3:4000 max_fails=3 fail_timeout=30s;
}

server {
    location /health {
        proxy_pass http://prismatic_backend/api/health;
        proxy_set_header Host $host;
        proxy_connect_timeout 5s;
        proxy_send_timeout 5s;
        proxy_read_timeout 5s;
    }
}
```

## Monitoring Automation

### Deployment Integration

#### Deploy-time Health Checks
```bash
#!/bin/bash
# scripts/deploy_health_check.sh

HEALTH_ENDPOINT="https://your-app.com/api/health"
MAX_ATTEMPTS=30
WAIT_TIME=10

echo "Waiting for application to be healthy..."

for i in $(seq 1 $MAX_ATTEMPTS); do
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" $HEALTH_ENDPOINT)
    
    if [ $HTTP_STATUS -eq 200 ]; then
        echo "Application is healthy!"
        exit 0
    fi
    
    echo "Attempt $i/$MAX_ATTEMPTS: Health check returned $HTTP_STATUS, waiting ${WAIT_TIME}s..."
    sleep $WAIT_TIME
done

echo "Application failed to become healthy within $((MAX_ATTEMPTS * WAIT_TIME)) seconds"
exit 1
```

### Automated Remediation

#### Auto-scaling Configuration
```yaml
# kubernetes/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: prismatic-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: prismatic-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## Troubleshooting

### Common Monitoring Issues

#### High Cardinality Metrics
```elixir
# Avoid high cardinality tags
# ❌ Bad - user_id creates many unique metric series
counter("user_actions", tags: [:user_id, :action])

# ✅ Good - use bounded tags
counter("user_actions", tags: [:user_type, :action])
```

#### Missing Metrics
```bash
# Debug Prometheus metrics endpoint
curl http://localhost:9568/metrics | grep prismatic

# Check Telemetry events
iex> :telemetry.list_handlers([])
```

#### Log Volume Management
```ruby
# logstash/pipeline/filters.conf
filter {
  # Drop debug logs in production
  if [level] == "debug" and [environment] == "production" {
    drop { }
  }
  
  # Sample high-volume logs
  if [message] =~ /high_frequency_event/ {
    if [sample_rate] != "keep" {
      ruby {
        code => "
          if rand(100) > 10  # Keep only 10%
            event.cancel
          end
        "
      }
    }
  }
}
```

## Related Documentation

- [Performance Optimization](../guides/performance-optimization.md) - Performance monitoring and optimization strategies
- [Security Guidelines](../guides/security-guidelines.md) - Security monitoring and alerting best practices
- [System Diagrams](../architecture/system-diagrams.md) - Visual representation of monitoring architecture
- [Database Setup](database-setup.md) - Database monitoring and performance configuration
- [CI/CD Configuration](cicd-configuration.md) - Pipeline monitoring and deployment health checks
- [Deployment Procedures](deployment-procedures.md) - Production deployment monitoring

---

**Effective monitoring is essential for maintaining system reliability and performance. Regular review and updating of monitoring configurations ensures continued effectiveness as the system evolves.**