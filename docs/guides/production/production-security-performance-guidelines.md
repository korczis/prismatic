# Production Security & Performance Guidelines

**🏭 Enterprise Production Deployment** - Comprehensive guidelines for deploying Phoenix/Elixir applications with LLM integrations to production environments, covering security hardening, performance optimization, monitoring, and operational excellence.

## ⏱️ Time Estimates

📖 Reading time: 45 minutes | 🔧 Implementation time: 8-16 hours | 📊 Skill level: Expert

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../../README.md) > [Guides](../README.md) > [Production](README.md) > Production Security & Performance Guidelines

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to production guides
- **🏠 [Documentation Home](../../README.md)** - Main documentation index
- **🔍 [Search Documentation](../../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Comprehensive Security Framework](../security/comprehensive-security-framework.md) - Enterprise security architecture
- [Comprehensive Performance Optimization](../performance/comprehensive-performance-optimization.md) - Performance engineering
- [BEAM VM Optimization](../performance/beam-vm-optimization.md) - VM-specific tuning  
- [LLM Integration Security](../security/llm-integration-security.md) - AI/LLM security
<!-- NAV_END -->

---

## Overview

This guide provides comprehensive production deployment guidelines that integrate both security and performance considerations for Phoenix/Elixir applications with LLM capabilities. It covers infrastructure hardening, performance optimization, monitoring strategies, and operational procedures for enterprise-grade deployments.

## Production Architecture

### Secure High-Performance Production Architecture

```mermaid
graph TD
    A["🌐 Internet"] --> B["🛡️ CDN + WAF"]
    B --> C["⚖️ Load Balancer"]
    C --> D["🔒 API Gateway"]
    D --> E["🚀 Phoenix App Cluster"]
    
    E --> F["🤖 LLM Processing"]
    E --> G["💾 Database Cluster"]
    E --> H["⚡ Cache Cluster"]
    
    F --> F1["🔐 OpenAI Secure"]
    F --> F2["🔐 Anthropic Secure"]
    
    G --> G1["📊 Primary DB"]
    G --> G2["📖 Read Replicas"]
    
    H --> H1["🏃 Redis Cluster"]
    H --> H2["📦 ETS Cache"]
    
    I["📈 Monitoring Stack"] --> I1["📊 Metrics"]
    I --> I2["📋 Logs"]
    I --> I3["🚨 Alerts"]
    
    J["🔐 Security Stack"] --> J1["🛡️ SIEM"]
    J --> J2["🔍 Vulnerability Scanning"]
    J --> J3["📝 Audit Logging"]
```

## Infrastructure Security Hardening

### Container Security Configuration

```dockerfile
# Dockerfile.production - Security-hardened production image
FROM elixir:1.17-alpine AS builder

# Security: Install only essential packages and clean up
RUN apk add --no-cache --virtual .build-deps \
    build-base \
    git \
    nodejs \
    npm \
    openssl-dev \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/*

# Security: Create non-root user for build
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -G appgroup -u 1001

WORKDIR /app
RUN chown -R appuser:appgroup /app
USER appuser

# Copy and build with security checks
COPY --chown=appuser:appgroup . .

# Security: Verify dependencies
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only prod && \
    mix deps.audit && \
    mix deps.compile

# Build with security flags
ENV MIX_ENV=prod
RUN mix compile --warnings-as-errors && \
    mix assets.deploy && \
    mix release --overwrite

# Production runtime image
FROM alpine:3.18 AS runtime

# Security: Install minimal runtime dependencies
RUN apk add --no-cache \
    openssl \
    libstdc++ \
    ncurses-libs \
    ca-certificates \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* \
    && update-ca-certificates

# Security: Create application user with minimal privileges
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -G appgroup -u 1001 -h /app -s /bin/sh

# Security: Set up secure directories
WORKDIR /app
RUN mkdir -p /app/tmp /app/logs && \
    chown -R appuser:appgroup /app && \
    chmod 750 /app && \
    chmod 700 /app/tmp /app/logs

USER appuser

# Copy release with proper permissions
COPY --from=builder --chown=appuser:appgroup /app/_build/prod/rel/prismatic ./

# Performance: Production VM flags
ENV ERL_FLAGS="+K true +A 64 +P 2000000 +Q 1000000 +stbt db +sbwt none +swt low"

EXPOSE 4000
CMD ["./bin/prismatic", "start"]
```

### Database Security and Performance

```elixir
# Production Database Security Configuration
defmodule Prismatic.Production.DatabaseSecurity do
  @moduledoc """
  Production database security implementation with connection pooling,
  SSL/TLS encryption, and audit logging.
  """
  
  def configure_production_repo do
    config = [
      # Connection Security
      ssl: true,
      ssl_opts: [
        verify: :verify_peer,
        cacerts: load_ca_certificates(),
        server_name_indication: get_database_hostname()
      ],
      
      # Connection Pool Configuration
      pool_size: get_optimal_pool_size(),
      queue_target: 50,
      queue_interval: 1000,
      checkout_timeout: 5_000,
      ownership_timeout: 10_000,
      timeout: 15_000,
      
      # Performance Settings
      parameters: [
        {"application_name", "prismatic_production"},
        {"statement_timeout", "30000"},
        {"idle_in_transaction_session_timeout", "60000"}
      ]
    ]
    
    Application.put_env(:prismatic, Prismatic.Repo, config)
  end
  
  defp get_optimal_pool_size do
    cpu_cores = System.schedulers_online()
    expected_load = Application.get_env(:prismatic, :expected_concurrent_users, 1000)
    
    # Base formula: 2-3 connections per core + load factor
    base_size = cpu_cores * 3
    load_factor = min(div(expected_load, 100), 10)
    
    max(base_size + load_factor, 10)
  end
end
```

## Load Balancing and High Availability

### NGINX Production Configuration

```nginx
# nginx.conf - Production load balancer configuration
user nginx;
worker_processes auto;
worker_cpu_affinity auto;
worker_rlimit_nofile 100000;

events {
    worker_connections 8192;
    use epoll;
    multi_accept on;
    accept_mutex off;
}

http {
    # Security Headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Performance Optimizations
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    
    # Rate Limiting
    limit_req_zone $binary_remote_addr zone=api:100m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;
    
    # Upstream Configuration
    upstream prismatic_backend {
        least_conn;
        keepalive 64;
        keepalive_requests 1000;
        
        server app1.internal:4000 max_fails=3 fail_timeout=30s weight=1;
        server app2.internal:4000 max_fails=3 fail_timeout=30s weight=1;
        server app3.internal:4000 max_fails=3 fail_timeout=30s weight=1;
    }
    
    server {
        listen 443 ssl http2;
        server_name prismatic.example.com;
        
        # SSL Configuration
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
        ssl_prefer_server_ciphers off;
        
        # API Endpoints
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            
            proxy_pass http://prismatic_backend;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Timeouts
            proxy_connect_timeout 10s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }
    }
}
```

## Monitoring and Observability

### Production Monitoring Stack

```elixir
# Production Monitoring Configuration
defmodule Prismatic.Production.Monitoring do
  use Supervisor
  import Telemetry.Metrics
  
  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @impl true
  def init(_opts) do
    children = [
      {:telemetry_poller, measurements: measurements(), period: 5_000},
      {TelemetryMetricsPrometheus.Core, metrics: prometheus_metrics()}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  def prometheus_metrics do
    [
      # Application Performance
      counter("phoenix_endpoint_requests_total",
        tags: [:method, :route, :status_class],
        description: "Total number of HTTP requests"
      ),
      
      histogram("phoenix_endpoint_request_duration_seconds",
        unit: {:native, :second},
        tags: [:method, :route],
        buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 5.0, 10.0],
        description: "HTTP request duration"
      ),
      
      # Database Performance
      counter("database_queries_total",
        tags: [:source, :command, :result],
        description: "Total database queries"
      ),
      
      # LLM Performance
      counter("llm_requests_total",
        tags: [:backend, :model, :result],
        description: "Total LLM requests"
      ),
      
      gauge("llm_circuit_breaker_state",
        tags: [:backend],
        description: "Circuit breaker state (0=closed, 1=open, 2=half_open)"
      ),
      
      # Security Metrics
      counter("security_events_total",
        tags: [:event_type, :severity],
        description: "Total security events"
      ),
      
      # System Resources
      gauge("beam_memory_bytes",
        unit: :byte,
        tags: [:kind],
        description: "BEAM VM memory usage"
      )
    ]
  end
end
```

### Alerting Configuration

```yaml
# alerting-rules.yml - Prometheus alerting rules
groups:
- name: prismatic.application
  rules:
  - alert: HighErrorRate
    expr: rate(phoenix_endpoint_requests_total{status_class="5xx"}[5m]) > 0.1
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "High error rate detected"
      description: "Error rate is {{ $value }} errors per second"
  
  - alert: HighResponseTime
    expr: histogram_quantile(0.95, rate(phoenix_endpoint_request_duration_seconds_bucket[5m])) > 1.0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High response time detected"
      description: "95th percentile response time is {{ $value }}s"

- name: prismatic.security
  rules:
  - alert: SecurityEventSpike
    expr: rate(security_events_total{severity="high"}[5m]) > 10
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "High number of security events"
      description: "{{ $value }} high-severity security events per second"

- name: prismatic.llm
  rules:
  - alert: LLMCircuitBreakerOpen
    expr: llm_circuit_breaker_state == 1
    for: 0m
    labels:
      severity: critical
    annotations:
      summary: "LLM circuit breaker is open"
      description: "Circuit breaker for {{ $labels.backend }} is open"
```

## Backup and Disaster Recovery

### Automated Backup Strategy

```bash
#!/bin/bash
# backup-production.sh - Production backup script

set -euo pipefail

# Configuration
BACKUP_RETENTION_DAYS=30
BACKUP_BASE_DIR="/backups/prismatic"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="${BACKUP_BASE_DIR}/${DATE}"
LOG_FILE="/var/log/prismatic-backup.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Create backup directory
mkdir -p "$BACKUP_DIR"

log "Starting production backup to $BACKUP_DIR"

# Database backup with encryption
log "Creating database backup..."
DATABASE_URL="${DATABASE_URL:-}"
if [ -z "$DATABASE_URL" ]; then
    log "ERROR: DATABASE_URL not set"
    exit 1
fi

pg_dump "$DATABASE_URL" | \
    gzip | \
    gpg --cipher-algo AES256 --compress-algo 1 --s2k-mode 3 \
        --s2k-digest-algo SHA512 --s2k-count 65011712 \
        --symmetric --output "${BACKUP_DIR}/database.sql.gz.gpg"

# Upload to remote storage
log "Uploading backup to remote storage..."
aws s3 cp "$BACKUP_DIR" "s3://prismatic-backups/production/${DATE}/" --recursive

# Clean up old backups
log "Cleaning up old backups..."
find "$BACKUP_BASE_DIR" -type d -mtime +$BACKUP_RETENTION_DAYS -exec rm -rf {} +

log "Backup completed successfully"
```

## Performance Optimization Checklist

### Production Deployment Checklist

#### Security Hardening
- [ ] **Container Security** - Non-root user, minimal base image, security scanning
- [ ] **Network Security** - Firewalls, VPC isolation, TLS everywhere
- [ ] **Database Security** - SSL connections, connection pooling, audit logging
- [ ] **API Security** - Rate limiting, authentication, input validation
- [ ] **Secret Management** - External secret store, key rotation, access logging

#### Performance Optimization
- [ ] **BEAM VM Tuning** - Scheduler configuration, memory settings, GC tuning
- [ ] **Database Optimization** - Connection pooling, query optimization, indexing
- [ ] **Caching Implementation** - Multi-level caching, cache warming, invalidation
- [ ] **Load Balancing** - Health checks, connection pooling, failover
- [ ] **Asset Optimization** - CDN, compression, caching headers

#### Monitoring and Observability
- [ ] **Metrics Collection** - Application, system, and business metrics
- [ ] **Logging** - Structured logging, log aggregation, retention policies
- [ ] **Alerting** - Critical alerts, escalation procedures, on-call rotation
- [ ] **Health Checks** - Liveness, readiness, and custom health endpoints
- [ ] **Tracing** - Distributed tracing for complex request flows

#### Operational Excellence
- [ ] **Backup Strategy** - Automated backups, encryption, offsite storage
- [ ] **Disaster Recovery** - Recovery procedures, RTO/RPO targets, testing
- [ ] **Deployment Pipeline** - Blue/green deployments, rollback procedures
- [ ] **Capacity Planning** - Resource monitoring, scaling triggers, growth planning
- [ ] **Documentation** - Runbooks, incident procedures, architecture diagrams

## Production Configuration Templates

### Environment Configuration

```bash
# production.env - Production environment variables

# Application Configuration
MIX_ENV=prod
PHX_SERVER=true
PORT=4000

# Database Configuration
DATABASE_URL=postgresql://user:pass@db-cluster.internal:5432/prismatic_prod
POOL_SIZE=20

# Security Configuration
SECRET_KEY_BASE=your-secret-key-base-64-chars-minimum
GUARDIAN_SECRET_KEY=your-guardian-secret-key
ENCRYPTION_KEY=your-encryption-key

# LLM Configuration
OPENAI_API_KEY=your-openai-api-key
ANTHROPIC_API_KEY=your-anthropic-api-key

# Cache Configuration
REDIS_URL=redis://redis-cluster.internal:6379/0

# Monitoring Configuration
PROMETHEUS_METRICS_ENABLED=true
TELEMETRY_ENABLED=true

# Performance Configuration
ERL_MAX_PORTS=65536
ERL_MAX_ETS_TABLES=32768
ERL_FLAGS="+K true +A 64 +P 2000000 +Q 1000000"
```

### Kubernetes Production Deployment

```yaml
# k8s-production.yaml - Kubernetes production deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prismatic-app
  namespace: prismatic-prod
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: prismatic
  template:
    metadata:
      labels:
        app: prismatic
    spec:
      containers:
      - name: prismatic
        image: prismatic:latest
        ports:
        - containerPort: 4000
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: prismatic-secrets
              key: database-url
        - name: SECRET_KEY_BASE
          valueFrom:
            secretKeyRef:
              name: prismatic-secrets
              key: secret-key-base
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 4000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 4000
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: prismatic-service
  namespace: prismatic-prod
spec:
  selector:
    app: prismatic
  ports:
  - port: 80
    targetPort: 4000
  type: ClusterIP
```

## Related Documentation

- [Comprehensive Security Framework](../security/comprehensive-security-framework.md) - Enterprise security architecture
- [Comprehensive Performance Optimization](../performance/comprehensive-performance-optimization.md) - Performance engineering
- [BEAM VM Optimization](../performance/beam-vm-optimization.md) - VM-specific tuning
- [LLM Integration Security](../security/llm-integration-security.md) - AI/LLM security measures
- [Monitoring Setup](../../operations/monitoring-setup.md) - Operational monitoring

---

**🏭 Production Tip**: Production deployments require careful balance between security and performance. Regular security audits, performance testing, and disaster recovery drills are essential for maintaining a robust production environment.