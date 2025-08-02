# Deployment Procedures Guide

Comprehensive deployment strategies, procedures, and best practices for deploying Prismatic applications to production environments.

## ⏱️ Time Estimates

📖 Reading time: 35 minutes | 🔧 Implementation time: 4-6 hours | 📊 Skill level: Advanced

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../../README.md) > [Guides](../README.md) > [Deployment](README.md) > Deployment Procedures

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to deployment guides
- **🏠 [Documentation Home](../../README.md)** - Main documentation index
- **🔍 [Search Documentation](../../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [CI/CD Implementation](../workflow/ci-cd-implementation.md) - Automated deployment pipelines
- [Error Handling & Logging](../development/error-handling-logging.md) - Production error monitoring
- [Performance Optimization](../performance/performance-optimization.md) - Production performance monitoring
- [Security Guidelines](../security/security-guidelines.md) - Production security considerations
- [Testing Strategy](../development/testing-strategy.md) - Pre-deployment testing procedures
- [Deployment Operations](deployment-operations.md) - Operational deployment procedures
<!-- NAV_END -->

---

## Table of Contents

1. [Overview](#overview)
2. [Production Deployment Checklist](#production-deployment-checklist)
3. [Environment Configuration Management](#environment-configuration-management)
4. [Database Migration Procedures](#database-migration-procedures)
5. [Zero-Downtime Deployment Strategies](#zero-downtime-deployment-strategies)
6. [Rollback Procedures](#rollback-procedures)
7. [Health Checks and Monitoring](#health-checks-and-monitoring)
8. [Load Balancer Configuration](#load-balancer-configuration)
9. [SSL/TLS Certificate Management](#ssltls-certificate-management)
10. [Container Deployment with Docker](#container-deployment-with-docker)
11. [CI/CD Integration](#cicd-integration)
12. [Emergency Procedures](#emergency-procedures)
13. [Post-Deployment Verification](#post-deployment-verification)
14. [Common Issues and Troubleshooting](#common-issues-and-troubleshooting)

---

## Overview

Successful production deployments require careful planning, systematic procedures, and robust monitoring. This guide establishes comprehensive deployment strategies that minimize risk, ensure system reliability, and enable rapid recovery when issues occur.

### Why This Matters

- **System Reliability**: Consistent deployment procedures reduce the risk of production outages
- **Zero Downtime**: Proper deployment strategies maintain service availability
- **Rapid Recovery**: Well-defined rollback procedures minimize incident duration
- **Quality Assurance**: Systematic verification ensures deployments meet requirements
- **Team Coordination**: Standardized procedures enable effective team collaboration

### Scope

This guide covers:
- Production deployment checklists and procedures
- Environment configuration and secret management
- Database migration strategies and safety measures
- Zero-downtime deployment techniques
- Rollback and emergency response procedures
- Health monitoring and verification processes
- Container orchestration and load balancing

---

## Production Deployment Checklist

### Pre-Deployment Checklist

Complete these steps before any production deployment:

```markdown
## Pre-Deployment Verification

### Code Quality
- [ ] All tests pass (unit, integration, end-to-end)
- [ ] Code review completed and approved
- [ ] Security scan completed without critical issues
- [ ] Performance benchmarks meet requirements
- [ ] Documentation updated for new features

### Environment Preparation
- [ ] Production environment health verified
- [ ] Database backup completed and verified
- [ ] Disk space availability confirmed (>20% free)
- [ ] SSL certificates validated (>30 days until expiration)
- [ ] DNS configuration verified
- [ ] Load balancer health checks configured

### Dependencies and Configuration
- [ ] Environment variables updated in secure storage
- [ ] Database migrations tested in staging
- [ ] External service integrations verified
- [ ] Feature flags configured appropriately
- [ ] Monitoring and alerting rules updated

### Team Coordination
- [ ] Deployment window scheduled and communicated
- [ ] On-call engineer identified and available
- [ ] Rollback plan documented and ready
- [ ] Stakeholders notified of deployment
- [ ] Incident response team on standby
```

### Deployment Execution Checklist

Follow these steps during deployment:

```markdown
## Deployment Execution

### Pre-Flight
- [ ] Verify all pre-deployment items completed
- [ ] Enable maintenance mode (if applicable)
- [ ] Take final database snapshot
- [ ] Notify monitoring systems of deployment start

### Deployment Steps
- [ ] Deploy application code to staging instances
- [ ] Run database migrations (if required)
- [ ] Update configuration and secrets
- [ ] Deploy to production instances (rolling/blue-green)
- [ ] Verify health checks pass on new instances

### Verification
- [ ] Application starts successfully on all instances
- [ ] Database connections established
- [ ] External service integrations functional
- [ ] Critical user journeys verified
- [ ] Performance metrics within acceptable range

### Post-Deployment
- [ ] Disable maintenance mode
- [ ] Monitor error rates and performance
- [ ] Verify alerting and monitoring active
- [ ] Update deployment documentation
- [ ] Notify stakeholders of successful deployment
```

---

## Environment Configuration Management

### Configuration Strategy

Manage environment-specific configuration securely and consistently:

```elixir
# config/runtime.exs - Production configuration
import Config

# Database configuration with connection pooling
config :prismatic, Prismatic.Repo,
  url: System.get_env("DATABASE_URL") || raise("DATABASE_URL not set"),
  pool_size: String.to_integer(System.get_env("DATABASE_POOL_SIZE", "15")),
  socket_options: [:inet6],
  timeout: 15_000,
  queue_target: 50,
  queue_interval: 1_000

# Phoenix endpoint configuration
config :prismatic_web, PrismaticWeb.Endpoint,
  url: [
    scheme: "https",
    host: System.get_env("PHX_HOST") || raise("PHX_HOST not set"),
    port: 443
  ],
  http: [
    port: String.to_integer(System.get_env("PORT", "4000")),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: System.get_env("SECRET_KEY_BASE") || raise("SECRET_KEY_BASE not set"),
  live_view: [signing_salt: System.get_env("LIVE_VIEW_SALT")],
  check_origin: [
    "https://#{System.get_env("PHX_HOST")}",
    "https://www.#{System.get_env("PHX_HOST")}"
  ]

# External service configuration
config :prismatic, :external_services,
  api_key: System.get_env("EXTERNAL_API_KEY") || raise("EXTERNAL_API_KEY not set"),
  base_url: System.get_env("EXTERNAL_API_URL", "https://api.external.com"),
  timeout: String.to_integer(System.get_env("EXTERNAL_API_TIMEOUT", "30000"))

# Logging configuration
config :logger,
  level: String.to_atom(System.get_env("LOG_LEVEL", "info")),
  backends: [:console],
  metadata: [:request_id, :user_id]

# Error reporting
if System.get_env("SENTRY_DSN") do
  config :sentry,
    dsn: System.get_env("SENTRY_DSN"),
    environment_name: System.get_env("DEPLOYMENT_ENV", "production"),
    included_environments: [:prod],
    tags: %{
      version: System.get_env("APP_VERSION", "unknown"),
      deployment_id: System.get_env("DEPLOYMENT_ID", "unknown")
    }
end

# Email configuration
config :prismatic, Prismatic.Mailer,
  adapter: Swoosh.Adapters.Mailgun,
  api_key: System.get_env("MAILGUN_API_KEY"),
  domain: System.get_env("MAILGUN_DOMAIN"),
  base_url: System.get_env("MAILGUN_BASE_URL", "https://api.mailgun.net/v3")
```

### Secret Management

Use secure secret management for production credentials:

```bash
#!/bin/bash
# scripts/deploy/setup-secrets.sh

set -euo pipefail

ENVIRONMENT=${1:-production}
VAULT_PATH="secret/prismatic/${ENVIRONMENT}"

# Retrieve secrets from HashiCorp Vault
echo "Fetching secrets for environment: ${ENVIRONMENT}"

# Database credentials
export DATABASE_URL=$(vault kv get -field=url ${VAULT_PATH}/database)
export DATABASE_POOL_SIZE=$(vault kv get -field=pool_size ${VAULT_PATH}/database)

# Application secrets
export SECRET_KEY_BASE=$(vault kv get -field=secret_key_base ${VAULT_PATH}/app)
export LIVE_VIEW_SALT=$(vault kv get -field=live_view_salt ${VAULT_PATH}/app)

# External service keys
export EXTERNAL_API_KEY=$(vault kv get -field=api_key ${VAULT_PATH}/external_services)
export MAILGUN_API_KEY=$(vault kv get -field=api_key ${VAULT_PATH}/mailgun)

# Monitoring and alerting
export SENTRY_DSN=$(vault kv get -field=dsn ${VAULT_PATH}/sentry)

echo "Secrets loaded successfully"
```

### Environment Validation

Validate configuration before deployment:

```elixir
defmodule Prismatic.ConfigValidator do
  @moduledoc """
  Validates production configuration before deployment.
  """
  
  require Logger
  
  @required_env_vars [
    "DATABASE_URL",
    "SECRET_KEY_BASE",
    "PHX_HOST",
    "EXTERNAL_API_KEY",
    "MAILGUN_API_KEY"
  ]
  
  @optional_env_vars %{
    "PORT" => "4000",
    "DATABASE_POOL_SIZE" => "15",
    "LOG_LEVEL" => "info",
    "EXTERNAL_API_TIMEOUT" => "30000"
  }
  
  def validate_production_config! do
    Logger.info("Validating production configuration...")
    
    validate_required_env_vars!()
    validate_optional_env_vars()
    validate_database_connection!()
    validate_external_services!()
    validate_ssl_certificates!()
    
    Logger.info("Production configuration validation completed successfully")
  end
  
  defp validate_required_env_vars! do
    missing_vars = 
      @required_env_vars
      |> Enum.filter(&(System.get_env(&1) in [nil, ""]))
    
    unless Enum.empty?(missing_vars) do
      raise "Missing required environment variables: #{Enum.join(missing_vars, ", ")}"
    end
    
    Logger.info("Required environment variables present: #{length(@required_env_vars)}")
  end
  
  defp validate_optional_env_vars do
    @optional_env_vars
    |> Enum.each(fn {var_name, default_value} ->
      value = System.get_env(var_name, default_value)
      Logger.info("#{var_name}=#{value}")
    end)
  end
  
  defp validate_database_connection! do
    case Ecto.Adapters.SQL.query(Prismatic.Repo, "SELECT 1", []) do
      {:ok, _} ->
        Logger.info("Database connection validated")
        
      {:error, error} ->
        raise "Database connection failed: #{inspect(error)}"
    end
  end
  
  defp validate_external_services! do
    api_key = System.get_env("EXTERNAL_API_KEY")
    base_url = System.get_env("EXTERNAL_API_URL", "https://api.external.com")
    
    case HTTPoison.get("#{base_url}/health", [{"Authorization", "Bearer #{api_key}"}]) do
      {:ok, %{status_code: 200}} ->
        Logger.info("External service connection validated")
        
      {:ok, %{status_code: status}} ->
        Logger.warning("External service returned status #{status}")
        
      {:error, error} ->
        Logger.warning("External service validation failed: #{inspect(error)}")
    end
  end
  
  defp validate_ssl_certificates! do
    host = System.get_env("PHX_HOST")
    
    case :ssl.connect(to_charlist(host), 443, [], 5000) do
      {:ok, socket} ->
        :ssl.close(socket)
        Logger.info("SSL certificate validation passed")
        
      {:error, reason} ->
        Logger.warning("SSL certificate validation failed: #{inspect(reason)}")
    end
  end
end

# Usage in deployment script
try do
  Prismatic.ConfigValidator.validate_production_config!()
rescue
  error ->
    IO.puts("Configuration validation failed: #{Exception.message(error)}")
    System.halt(1)
end
```

---

## Database Migration Procedures

### Safe Migration Patterns

Implement database migrations with zero downtime:

```elixir
defmodule Prismatic.Repo.Migrations.SafelyAddColumnWithIndex do
  use Ecto.Migration
  
  @disable_ddl_transaction true
  @disable_migration_lock true
  
  def up do
    # Step 1: Add column without constraints (safe for live traffic)
    alter table(:articles) do
      add :status, :string
    end
    
    # Step 2: Add default value for existing records
    execute("UPDATE articles SET status = 'published' WHERE status IS NULL")
    
    # Step 3: Add index concurrently (doesn't block reads/writes)
    create index(:articles, [:status], concurrently: true)
    
    # Step 4: Add NOT NULL constraint (safe after data is populated)
    execute("ALTER TABLE articles ALTER COLUMN status SET NOT NULL")
  end
  
  def down do
    drop index(:articles, [:status])
    
    alter table(:articles) do
      remove :status
    end
  end
end

# Migration for renaming columns safely
defmodule Prismatic.Repo.Migrations.SafelyRenameColumn do
  use Ecto.Migration
  
  def up do
    # Step 1: Add new column
    alter table(:users) do
      add :full_name, :string
    end
    
    # Step 2: Copy data from old column to new column
    execute("UPDATE users SET full_name = name WHERE full_name IS NULL")
    
    # Step 3: Update application code to use new column (deploy separately)
    # Step 4: Remove old column (in next migration after confirming new column works)
  end
  
  def down do
    alter table(:users) do
      remove :full_name
    end
  end
end
```

### Migration Safety Checks

Validate migrations before running in production:

```elixir
defmodule Prismatic.MigrationValidator do
  @moduledoc """
  Validates database migrations for production safety.
  """
  
  require Logger
  
  @unsafe_patterns [
    # Operations that lock tables
    ~r/ALTER TABLE .+ DROP COLUMN/i,
    ~r/ALTER TABLE .+ RENAME COLUMN/i,
    ~r/CREATE UNIQUE INDEX(?! CONCURRENTLY)/i,
    
    # Operations that require full table scans
    ~r/ALTER TABLE .+ ALTER COLUMN .+ TYPE/i,
    ~r/UPDATE .+ SET .+ WHERE/i,
    
    # Operations without proper safeguards
    ~r/ALTER TABLE .+ ADD COLUMN .+ NOT NULL(?! DEFAULT)/i,
    ~r/ALTER TABLE .+ ADD .+ FOREIGN KEY/i
  ]
  
  def validate_migration_safety(migration_content) do
    Logger.info("Validating migration safety...")
    
    unsafe_operations = find_unsafe_operations(migration_content)
    
    if Enum.empty?(unsafe_operations) do
      Logger.info("Migration safety validation passed")
      :ok
    else
      Logger.error("Unsafe migration operations detected:")
      Enum.each(unsafe_operations, &Logger.error("  - #{&1}"))
      {:error, :unsafe_migration}
    end
  end
  
  defp find_unsafe_operations(content) do
    @unsafe_patterns
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, content, capture: :all)
      |> Enum.map(&List.first/1)
    end)
    |> Enum.uniq()
  end
  
  def estimate_migration_duration(migration_module) do
    # Analyze migration operations and estimate duration
    operations = extract_operations(migration_module)
    
    estimated_seconds = 
      operations
      |> Enum.map(&estimate_operation_duration/1)
      |> Enum.sum()
    
    Logger.info("Estimated migration duration: #{estimated_seconds} seconds")
    estimated_seconds
  end
  
  defp extract_operations(_migration_module) do
    # Implementation to extract operations from migration
    []
  end
  
  defp estimate_operation_duration({:add_column, _table, _column}), do: 1
  defp estimate_operation_duration({:create_index, _table, _columns, opts}) do
    if Keyword.get(opts, :concurrently, false), do: 30, else: 10
  end
  defp estimate_operation_duration({:alter_column, _table, _column}), do: 60
  defp estimate_operation_duration(_), do: 5
end
```

### Migration Execution Strategy

Execute migrations safely in production:

```bash
#!/bin/bash
# scripts/deploy/run-migrations.sh

set -euo pipefail

ENVIRONMENT=${1:-production}
DRY_RUN=${2:-false}

echo "Running database migrations for environment: ${ENVIRONMENT}"

# Load environment configuration
source scripts/deploy/setup-secrets.sh ${ENVIRONMENT}

# Validate migration safety
echo "Validating migration safety..."
mix do deps.get, compile
mix run -e "
  migrations = Ecto.Migrator.migrations(Prismatic.Repo)
  pending = Enum.filter(migrations, fn {status, _, _} -> status == :down end)
  
  if length(pending) > 0 do
    IO.puts \"Pending migrations: #{length(pending)}\"
    Enum.each(pending, fn {_, version, name} ->
      IO.puts \"  - #{version}: #{name}\"
    end)
  else
    IO.puts \"No pending migrations\"
    System.halt(0)
  end
"

if [ "$DRY_RUN" = "true" ]; then
  echo "DRY RUN: Would execute migrations but --dry-run flag is set"
  exit 0
fi

# Create database backup before migrations
echo "Creating database backup..."
BACKUP_FILE="backup_pre_migration_$(date +%Y%m%d_%H%M%S).sql"
pg_dump $DATABASE_URL > "/tmp/${BACKUP_FILE}"
echo "Backup created: ${BACKUP_FILE}"

# Execute migrations with timeout
echo "Executing database migrations..."
timeout 300 mix ecto.migrate || {
  echo "Migration timeout or failure detected"
  echo "Manual intervention required"
  exit 1
}

# Verify database state after migration
echo "Verifying database state..."
mix run -e "
  case Ecto.Adapters.SQL.query(Prismatic.Repo, \"SELECT 1\", []) do
    {:ok, _} -> IO.puts \"Database connection verified\"
    {:error, error} -> 
      IO.puts \"Database verification failed: #{inspect(error)}\"
      System.halt(1)
  end
"

echo "Database migrations completed successfully"
```

---

## Zero-Downtime Deployment Strategies

### Blue-Green Deployment

Implement blue-green deployment for zero-downtime releases:

```bash
#!/bin/bash
# scripts/deploy/blue-green-deploy.sh

set -euo pipefail

CURRENT_COLOR=$(curl -s http://load-balancer/health | jq -r '.current_deployment')
NEW_COLOR=$([ "$CURRENT_COLOR" = "blue" ] && echo "green" || echo "blue")

echo "Current deployment: $CURRENT_COLOR"
echo "New deployment: $NEW_COLOR"

# Deploy to inactive environment
echo "Deploying to $NEW_COLOR environment..."
docker-compose -f docker-compose.${NEW_COLOR}.yml up -d

# Wait for new environment to be healthy
echo "Waiting for $NEW_COLOR environment to be healthy..."
for i in {1..30}; do
  if curl -f http://${NEW_COLOR}-app:4000/health; then
    echo "$NEW_COLOR environment is healthy"
    break
  fi
  
  if [ $i -eq 30 ]; then
    echo "$NEW_COLOR environment failed to become healthy"
    exit 1
  fi
  
  sleep 10
done

# Run smoke tests on new environment
echo "Running smoke tests on $NEW_COLOR environment..."
./scripts/deploy/smoke-tests.sh ${NEW_COLOR}-app:4000

# Switch load balancer to new environment
echo "Switching load balancer to $NEW_COLOR environment..."
curl -X POST http://load-balancer/switch -d "target=${NEW_COLOR}"

# Verify traffic is flowing to new environment
echo "Verifying traffic switch..."
sleep 30
NEW_HEALTH=$(curl -s http://load-balancer/health | jq -r '.current_deployment')

if [ "$NEW_HEALTH" = "$NEW_COLOR" ]; then
  echo "Traffic successfully switched to $NEW_COLOR"
  
  # Keep old environment running for quick rollback
  echo "Deployment completed successfully"
  echo "Old $CURRENT_COLOR environment kept running for potential rollback"
else
  echo "Traffic switch failed, rolling back..."
  curl -X POST http://load-balancer/switch -d "target=${CURRENT_COLOR}"
  exit 1
fi
```

### Rolling Deployment

Implement rolling deployment for gradual instance updates:

```bash
#!/bin/bash
# scripts/deploy/rolling-deploy.sh

set -euo pipefail

INSTANCES=(app-1 app-2 app-3 app-4)
NEW_IMAGE=${1:-prismatic:latest}
HEALTH_CHECK_URL="http://localhost:4000/health"

echo "Starting rolling deployment with image: $NEW_IMAGE"

for instance in "${INSTANCES[@]}"; do
  echo "Deploying to instance: $instance"
  
  # Remove instance from load balancer
  echo "Removing $instance from load balancer..."
  curl -X POST http://load-balancer/remove -d "instance=${instance}"
  
  # Wait for connections to drain
  echo "Waiting for connection draining..."
  sleep 30
  
  # Update instance
  echo "Updating $instance..."
  docker stop $instance || true
  docker run -d --name $instance \
    --network app-network \
    -e DATABASE_URL=$DATABASE_URL \
    -e SECRET_KEY_BASE=$SECRET_KEY_BASE \
    $NEW_IMAGE
  
  # Wait for instance to be healthy
  echo "Waiting for $instance to be healthy..."
  for i in {1..30}; do
    if docker exec $instance curl -f $HEALTH_CHECK_URL; then
      echo "$instance is healthy"
      break
    fi
    
    if [ $i -eq 30 ]; then
      echo "$instance failed to become healthy, rolling back..."
      # Rollback logic here
      exit 1
    fi
    
    sleep 10
  done
  
  # Add instance back to load balancer
  echo "Adding $instance back to load balancer..."
  curl -X POST http://load-balancer/add -d "instance=${instance}"
  
  # Wait before processing next instance
  sleep 15
done

echo "Rolling deployment completed successfully"
```

### Canary Deployment

Implement canary deployment for gradual traffic migration:

```elixir
defmodule Prismatic.CanaryDeployment do
  @moduledoc """
  Manages canary deployments with gradual traffic shifting.
  """
  
  use GenServer
  require Logger
  
  defstruct [
    :current_version,
    :canary_version,
    :traffic_percentage,
    :metrics,
    :rollback_threshold
  ]
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def start_canary(canary_version, initial_percentage \\ 5) do
    GenServer.call(__MODULE__, {:start_canary, canary_version, initial_percentage})
  end
  
  def increase_traffic(percentage) do
    GenServer.call(__MODULE__, {:increase_traffic, percentage})
  end
  
  def complete_canary do
    GenServer.call(__MODULE__, :complete_canary)
  end
  
  def rollback_canary do
    GenServer.call(__MODULE__, :rollback_canary)
  end
  
  def init(opts) do
    state = %__MODULE__{
      current_version: Keyword.get(opts, :current_version),
      canary_version: nil,
      traffic_percentage: 0,
      metrics: %{},
      rollback_threshold: Keyword.get(opts, :rollback_threshold, %{
        error_rate: 0.05,  # 5% error rate
        response_time_p95: 2000  # 2 second 95th percentile
      })
    }
    
    # Check metrics every minute
    :timer.send_interval(60_000, :check_metrics)
    
    {:ok, state}
  end
  
  def handle_call({:start_canary, canary_version, percentage}, _from, state) do
    Logger.info("Starting canary deployment", 
      canary_version: canary_version, 
      initial_percentage: percentage
    )
    
    case deploy_canary_instances(canary_version) do
      :ok ->
        update_traffic_routing(percentage, canary_version)
        
        new_state = %{state | 
          canary_version: canary_version,
          traffic_percentage: percentage
        }
        
        {:reply, :ok, new_state}
        
      {:error, reason} ->
        Logger.error("Canary deployment failed", reason: reason)
        {:reply, {:error, reason}, state}
    end
  end
  
  def handle_call({:increase_traffic, percentage}, _from, state) do
    if state.canary_version do
      Logger.info("Increasing canary traffic", 
        from: state.traffic_percentage,
        to: percentage
      )
      
      update_traffic_routing(percentage, state.canary_version)
      
      new_state = %{state | traffic_percentage: percentage}
      {:reply, :ok, new_state}
    else
      {:reply, {:error, :no_active_canary}, state}
    end
  end
  
  def handle_call(:complete_canary, _from, state) do
    if state.canary_version do
      Logger.info("Completing canary deployment", version: state.canary_version)
      
      # Route 100% traffic to canary
      update_traffic_routing(100, state.canary_version)
      
      # Terminate old version instances
      terminate_old_instances(state.current_version)
      
      new_state = %{state |
        current_version: state.canary_version,
        canary_version: nil,
        traffic_percentage: 0
      }
      
      {:reply, :ok, new_state}
    else
      {:reply, {:error, :no_active_canary}, state}
    end
  end
  
  def handle_info(:check_metrics, state) do
    if state.canary_version do
      metrics = collect_canary_metrics(state.canary_version)
      
      if should_rollback?(metrics, state.rollback_threshold) do
        Logger.error("Canary metrics exceed rollback threshold, initiating rollback",
          metrics: metrics,
          threshold: state.rollback_threshold
        )
        
        rollback_canary_deployment(state)
        new_state = %{state | canary_version: nil, traffic_percentage: 0}
        {:noreply, new_state}
      else
        {:noreply, %{state | metrics: metrics}}
      end
    else
      {:noreply, state}
    end
  end
  
  defp deploy_canary_instances(version) do
    # Deploy canary instances with new version
    :ok
  end
  
  defp update_traffic_routing(percentage, canary_version) do
    # Update load balancer to route percentage of traffic to canary
    HTTPoison.post("http://load-balancer/canary", %{
      canary_version: canary_version,
      traffic_percentage: percentage
    })
  end
  
  defp collect_canary_metrics(canary_version) do
    # Collect metrics from monitoring system
    %{
      error_rate: 0.02,
      response_time_p95: 1500,
      throughput: 1000
    }
  end
  
  defp should_rollback?(metrics, threshold) do
    metrics.error_rate > threshold.error_rate or 
    metrics.response_time_p95 > threshold.response_time_p95
  end
  
  defp rollback_canary_deployment(state) do
    update_traffic_routing(0, state.canary_version)
    terminate_canary_instances(state.canary_version)
  end
end
```

---

## Rollback Procedures

### Automated Rollback Triggers

Implement automated rollback based on health metrics:

```elixir
defmodule Prismatic.RollbackManager do
  use GenServer
  require Logger
  
  @rollback_conditions %{
    error_rate_threshold: 0.05,      # 5% error rate
    response_time_threshold: 5000,   # 5 second response time
    health_check_failures: 3,        # 3 consecutive health check failures
    deployment_timeout: 600          # 10 minutes deployment timeout
  }
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def monitor_deployment(deployment_id, version) do
    GenServer.cast(__MODULE__, {:monitor_deployment, deployment_id, version})
  end
  
  def init(_opts) do
    :timer.send_interval(30_000, :check_health_metrics)  # Check every 30 seconds
    {:ok, %{active_deployments: %{}, rollback_history: []}}
  end
  
  def handle_cast({:monitor_deployment, deployment_id, version}, state) do
    deployment_info = %{
      id: deployment_id,
      version: version,
      started_at: DateTime.utc_now(),
      health_check_failures: 0,
      metrics_history: []
    }
    
    Logger.info("Starting deployment monitoring", 
      deployment_id: deployment_id,
      version: version
    )
    
    active_deployments = Map.put(state.active_deployments, deployment_id, deployment_info)
    {:noreply, %{state | active_deployments: active_deployments}}
  end
  
  def handle_info(:check_health_metrics, state) do
    new_state = 
      state.active_deployments
      |> Enum.reduce(state, fn {deployment_id, deployment}, acc_state ->
        case check_deployment_health(deployment) do
          {:healthy, updated_deployment} ->
            active_deployments = Map.put(acc_state.active_deployments, deployment_id, updated_deployment)
            %{acc_state | active_deployments: active_deployments}
            
          {:unhealthy, reason, updated_deployment} ->
            Logger.error("Deployment health check failed", 
              deployment_id: deployment_id,
              reason: reason,
              version: deployment.version
            )
            
            initiate_rollback(deployment_id, deployment.version, reason)
            
            # Remove from active monitoring
            active_deployments = Map.delete(acc_state.active_deployments, deployment_id)
            rollback_entry = %{
              deployment_id: deployment_id,
              version: deployment.version,
              rollback_reason: reason,
              rolled_back_at: DateTime.utc_now()
            }
            
            %{acc_state | 
              active_deployments: active_deployments,
              rollback_history: [rollback_entry | acc_state.rollback_history]
            }
        end
      end)
    
    {:noreply, new_state}
  end
  
  defp check_deployment_health(deployment) do
    current_metrics = collect_deployment_metrics(deployment.version)
    updated_deployment = %{deployment | metrics_history: [current_metrics | deployment.metrics_history]}
    
    cond do
      deployment_timeout_exceeded?(deployment) ->
        {:unhealthy, :deployment_timeout, updated_deployment}
        
      error_rate_too_high?(current_metrics) ->
        {:unhealthy, :high_error_rate, updated_deployment}
        
      response_time_too_high?(current_metrics) ->
        {:unhealthy, :high_response_time, updated_deployment}
        
      health_check_failing?(deployment.version) ->
        failures = deployment.health_check_failures + 1
        updated_deployment = %{updated_deployment | health_check_failures: failures}
        
        if failures >= @rollback_conditions.health_check_failures do
          {:unhealthy, :health_check_failures, updated_deployment}
        else
          {:healthy, updated_deployment}
        end
        
      true ->
        # Reset failure count on successful health check
        updated_deployment = %{updated_deployment | health_check_failures: 0}
        {:healthy, updated_deployment}
    end
  end
  
  defp deployment_timeout_exceeded?(deployment) do
    elapsed_seconds = DateTime.diff(DateTime.utc_now(), deployment.started_at)
    elapsed_seconds > @rollback_conditions.deployment_timeout
  end
  
  defp error_rate_too_high?(metrics) do
    metrics.error_rate > @rollback_conditions.error_rate_threshold
  end
  
  defp response_time_too_high?(metrics) do
    metrics.avg_response_time > @rollback_conditions.response_time_threshold
  end
  
  defp health_check_failing?(version) do
    case HTTPoison.get("http://app-#{version}/health", [], timeout: 5000) do
      {:ok, %{status_code: 200}} -> false
      _ -> true
    end
  end
  
  defp collect_deployment_metrics(version) do
    # Collect metrics from monitoring system
    %{
      error_rate: 0.01,
      avg_response_time: 800,
      throughput: 1200,
      timestamp: DateTime.utc_now()
    }
  end
  
  defp initiate_rollback(deployment_id, version, reason) do
    Logger.error("Initiating automatic rollback", 
      deployment_id: deployment_id,
      version: version,
      reason: reason
    )
    
    # Execute rollback procedure
    Task.start(fn ->
      case execute_rollback(deployment_id, version) do
        :ok ->
          Logger.info("Automatic rollback completed successfully", 
            deployment_id: deployment_id
          )
          
        {:error, rollback_error} ->
          Logger.error("Automatic rollback failed", 
            deployment_id: deployment_id,
            rollback_error: rollback_error
          )
          
          # Trigger emergency procedures
          trigger_emergency_alert(deployment_id, version, rollback_error)
      end
    end)
  end
  
  defp execute_rollback(deployment_id, version) do
    # Implementation of rollback procedure
    :ok
  end
  
  defp trigger_emergency_alert(deployment_id, version, error) do
    # Send emergency alerts to on-call team
    Logger.error("EMERGENCY: Automatic rollback failed", 
      deployment_id: deployment_id,
      version: version,
      error: error
    )
  end
end
```

### Manual Rollback Procedures

Provide manual rollback capabilities for emergency situations:

```bash
#!/bin/bash
# scripts/deploy/rollback.sh

set -euo pipefail

TARGET_VERSION=${1:-}
DEPLOYMENT_ID=${2:-}
SKIP_CONFIRMATIONS=${3:-false}

if [ -z "$TARGET_VERSION" ]; then
  echo "Usage: $0 <target_version> [deployment_id] [skip_confirmations]"
  echo ""
  echo "Available versions:"
  docker images prismatic --format "table {{.Tag}}\t{{.CreatedAt}}"
  exit 1
fi

echo "======================================="
echo "EMERGENCY ROLLBACK PROCEDURE"
echo "======================================="
echo "Target version: $TARGET_VERSION"
echo "Deployment ID: $DEPLOYMENT_ID"
echo "Current time: $(date)"
echo ""

if [ "$SKIP_CONFIRMATIONS" != "true" ]; then
  read -p "Are you sure you want to rollback to $TARGET_VERSION? (yes/no): " confirmation
  if [ "$confirmation" != "yes" ]; then
    echo "Rollback cancelled"
    exit 0
  fi
fi

# Log rollback initiation
echo "$(date): Rollback initiated by $(whoami) to version $TARGET_VERSION" >> /var/log/prismatic/rollbacks.log

# Step 1: Verify target version exists
echo "Verifying target version exists..."
if ! docker images prismatic:$TARGET_VERSION | grep -q $TARGET_VERSION; then
  echo "ERROR: Target version $TARGET_VERSION not found"
  exit 1
fi

# Step 2: Create database backup before rollback
echo "Creating pre-rollback database backup..."
BACKUP_FILE="backup_pre_rollback_$(date +%Y%m%d_%H%M%S).sql"
pg_dump $DATABASE_URL > "/tmp/${BACKUP_FILE}"
echo "Backup created: ${BACKUP_FILE}"

# Step 3: Switch load balancer to maintenance mode
echo "Enabling maintenance mode..."
curl -X POST http://load-balancer/maintenance -d "enabled=true"

# Step 4: Stop current version instances
echo "Stopping current version instances..."
docker-compose down

# Step 5: Start target version instances
echo "Starting target version instances..."
export APP_VERSION=$TARGET_VERSION
docker-compose up -d

# Step 6: Wait for instances to be healthy
echo "Waiting for instances to be healthy..."
for i in {1..30}; do
  if curl -f http://localhost:4000/health; then
    echo "Instance health check passed"
    break
  fi
  
  if [ $i -eq 30 ]; then
    echo "ERROR: Instances failed to become healthy"
    echo "Manual intervention required"
    exit 1
  fi
  
  sleep 10
done

# Step 7: Run post-rollback verification
echo "Running post-rollback verification..."
./scripts/deploy/smoke-tests.sh localhost:4000

# Step 8: Disable maintenance mode
echo "Disabling maintenance mode..."
curl -X POST http://load-balancer/maintenance -d "enabled=false"

# Log rollback completion
echo "$(date): Rollback completed successfully to version $TARGET_VERSION" >> /var/log/prismatic/rollbacks.log

echo ""
echo "======================================="
echo "ROLLBACK COMPLETED SUCCESSFULLY"
echo "======================================="
echo "Rolled back to version: $TARGET_VERSION"
echo "Backup file: ${BACKUP_FILE}"
echo "Completion time: $(date)"
```

---

## Health Checks and Monitoring

### Application Health Checks

Implement comprehensive health checks:

```elixir
defmodule PrismaticWeb.HealthController do
  use PrismaticWeb, :controller
  
  def show(conn, _params) do
    health_checks = [
      {:database, check_database()},
      {:redis, check_redis()},
      {:external_services, check_external_services()},
      {:disk_space, check_disk_space()},
      {:memory, check_memory()},
      {:load_average, check_load_average()}
    ]
    
    {healthy_checks, unhealthy_checks} = 
      Enum.split_with(health_checks, fn {_name, status} -> 
        status == :ok 
      end)
    
    overall_status = if Enum.empty?(unhealthy_checks), do: :healthy, else: :unhealthy
    status_code = if overall_status == :healthy, do: 200, else: 503
    
    response = %{
      status: overall_status,
      timestamp: DateTime.utc_now(),
      version: Application.get_env(:prismatic, :version, "unknown"),
      deployment_id: System.get_env("DEPLOYMENT_ID", "unknown"),
      hostname: System.get_env("HOSTNAME", "unknown"),
      checks: %{
        healthy: format_checks(healthy_checks),
        unhealthy: format_checks(unhealthy_checks)
      },
      metrics: %{
        uptime_seconds: get_uptime_seconds(),
        memory_usage: get_memory_usage(),
        active_connections: get_active_connections()
      }
    }
    
    conn
    |> put_status(status_code)
    |> json(response)
  end
  
  defp check_database do
    try do
      case Ecto.Adapters.SQL.query(Prismatic.Repo, "SELECT 1", [], timeout: 5000) do
        {:ok, _} -> :ok
        {:error, _} -> :error
      end
    rescue
      _ -> :error
    end
  end
  
  defp check_redis do
    try do
      case Redix.command(Prismatic.Redis, ["PING"], timeout: 5000) do
        {:ok, "PONG"} -> :ok
        _ -> :error
      end
    rescue
      _ -> :error
    end
  end
  
  defp check_external_services do
    external_api_url = System.get_env("EXTERNAL_API_URL", "https://api.external.com")
    
    case HTTPoison.get("#{external_api_url}/health", [], timeout: 5000) do
      {:ok, %{status_code: 200}} -> :ok
      _ -> :error
    end
  end
  
  defp check_disk_space do
    case File.stat("/") do
      {:ok, stat} ->
        # Check if disk usage is under 90%
        case System.cmd("df", ["-h", "/"]) do
          {output, 0} ->
            usage_line = output |> String.split("\n") |> Enum.at(1)
            usage_percent = 
              usage_line
              |> String.split()
              |> Enum.at(4)
              |> String.trim("%")
              |> String.to_integer()
            
            if usage_percent < 90, do: :ok, else: :error
            
          _ -> :error
        end
        
      _ -> :error
    end
  end
  
  defp check_memory do
    memory_info = :erlang.memory()
    total_memory = memory_info[:total]
    
    # Check if memory usage is under 90% of available
    system_memory = get_system_memory()
    
    if total_memory < system_memory * 0.9, do: :ok, else: :error
  end
  
  defp check_load_average do
    case File.read("/proc/loadavg") do
      {:ok, content} ->
        load_1min = 
          content
          |> String.split()
          |> List.first()
          |> String.to_float()
        
        cpu_count = System.schedulers_online()
        
        # Alert if load average is more than 2x CPU count
        if load_1min < cpu_count * 2, do: :ok, else: :error
        
      _ -> :error
    end
  end
  
  defp format_checks(checks) do
    Enum.into(checks, %{}, fn {name, status} -> {name, status} end)
  end
  
  defp get_uptime_seconds do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    div(uptime_ms, 1000)
  end
  
  defp get_memory_usage do
    memory_info = :erlang.memory()
    %{
      total: memory_info[:total],
      processes: memory_info[:processes],
      system: memory_info[:system],
      atom: memory_info[:atom],
      binary: memory_info[:binary],
      ets: memory_info[:ets]
    }
  end
  
  defp get_active_connections do
    # Return number of active Phoenix connections
    DynamicSupervisor.count_children(Phoenix.PubSub.PG2Server)[:active] || 0
  end
  
  defp get_system_memory do
    case File.read("/proc/meminfo") do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.find(&String.starts_with?(&1, "MemTotal:"))
        |> String.split()
        |> Enum.at(1)
        |> String.to_integer()
        |> Kernel.*(1024)  # Convert KB to bytes
        
      _ -> 8_000_000_000  # Default 8GB
    end
  end
end
```

### Monitoring Integration

Integrate with monitoring systems for comprehensive observability:

```elixir
defmodule Prismatic.MonitoringReporter do
  use GenServer
  require Logger
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    # Report metrics every 60 seconds
    :timer.send_interval(60_000, :report_metrics)
    
    # Report deployment events
    :telemetry.attach_many(
      "prismatic-monitoring",
      [
        [:prismatic, :deployment, :started],
        [:prismatic, :deployment, :completed],
        [:prismatic, :deployment, :failed]
      ],
      &handle_telemetry_event/4,
      nil
    )
    
    {:ok, %{}}
  end
  
  def handle_info(:report_metrics, state) do
    metrics = collect_system_metrics()
    
    # Report to monitoring system (e.g., Prometheus, DataDog)
    report_to_monitoring_system(metrics)
    
    {:noreply, state}
  end
  
  defp collect_system_metrics do
    %{
      timestamp: DateTime.utc_now(),
      deployment_id: System.get_env("DEPLOYMENT_ID", "unknown"),
      version: Application.get_env(:prismatic, :version, "unknown"),
      hostname: System.get_env("HOSTNAME", "unknown"),
      
      # System metrics
      memory_usage: :erlang.memory()[:total],
      process_count: length(Process.list()),
      message_queue_lengths: get_message_queue_lengths(),
      
      # Application metrics
      active_users: count_active_users(),
      request_rate: get_request_rate(),
      error_rate: get_error_rate(),
      
      # Business metrics
      orders_per_minute: count_recent_orders(),
      user_registrations_per_hour: count_recent_registrations()
    }
  end
  
  defp report_to_monitoring_system(metrics) do
    # Example: Report to Prometheus
    for {metric_name, value} <- metrics do
      :prometheus_gauge.set(metric_name, value)
    end
    
    # Example: Report to DataDog
    case HTTPoison.post(
      "https://api.datadoghq.com/api/v1/series",
      Jason.encode!(%{
        series: [
          %{
            metric: "prismatic.system.memory_usage",
            points: [[DateTime.to_unix(metrics.timestamp), metrics.memory_usage]],
            tags: ["deployment_id:#{metrics.deployment_id}", "version:#{metrics.version}"]
          }
        ]
      }),
      [
        {"Content-Type", "application/json"},
        {"DD-API-KEY", System.get_env("DATADOG_API_KEY")}
      ]
    ) do
      {:ok, _} -> :ok
      {:error, error} -> Logger.warning("Failed to report metrics", error: error)
    end
  end
  
  defp handle_telemetry_event([:prismatic, :deployment, :started], measurements, metadata, _config) do
    Logger.info("Deployment started", 
      deployment_id: metadata.deployment_id,
      version: metadata.version
    )
    
    # Report deployment start to monitoring system
    report_deployment_event("deployment.started", metadata)
  end
  
  defp handle_telemetry_event([:prismatic, :deployment, :completed], measurements, metadata, _config) do
    Logger.info("Deployment completed", 
      deployment_id: metadata.deployment_id,
      version: metadata.version,
      duration_ms: measurements.duration
    )
    
    report_deployment_event("deployment.completed", metadata)
  end
  
  defp handle_telemetry_event([:prismatic, :deployment, :failed], measurements, metadata, _config) do
    Logger.error("Deployment failed", 
      deployment_id: metadata.deployment_id,
      version: metadata.version,
      error: metadata.error
    )
    
    report_deployment_event("deployment.failed", metadata)
    
    # Trigger alerts for deployment failures
    trigger_deployment_failure_alert(metadata)
  end
  
  defp report_deployment_event(event_type, metadata) do
    # Report deployment events to monitoring system
  end
  
  defp trigger_deployment_failure_alert(metadata) do
    # Send immediate alerts for deployment failures
    Logger.error("ALERT: Deployment failure", metadata: metadata)
  end
end
```

---

## Load Balancer Configuration

### HAProxy Configuration

Configure HAProxy for high availability and health checking:

```
# /etc/haproxy/haproxy.cfg
global
    daemon
    maxconn 4096
    user haproxy
    group haproxy
    
    # SSL configuration
    ssl-default-bind-ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets
    
    # Logging
    log 127.0.0.1:514 local0 info

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    
    # Health check settings
    option httpchk GET /health
    http-check expect status 200
    
    # Connection limits
    default-server inter 10s downinter 5s rise 2 fall 3 slowstart 60s maxconn 250

# Statistics interface
stats enable
stats uri /haproxy-stats
stats refresh 30s
stats admin if TRUE

# Frontend configuration
frontend prismatic_frontend
    bind *:80
    bind *:443 ssl crt /etc/ssl/certs/prismatic.pem
    
    # Redirect HTTP to HTTPS
    redirect scheme https if !{ ssl_fc }
    
    # Security headers
    http-response set-header Strict-Transport-Security "max-age=31536000; includeSubDomains"
    http-response set-header X-Frame-Options "DENY"
    http-response set-header X-Content-Type-Options "nosniff"
    
    # Maintenance mode
    acl maintenance_mode nbsrv(prismatic_backend) eq 0
    http request deny if maintenance_mode
    
    default_backend prismatic_backend

# Backend configuration
backend prismatic_backend
    balance roundrobin
    
    # Health check configuration
    option httpchk GET /health HTTP/1.1\r\nHost:\ prismatic.com
    http-check expect status 200
    
    # Application servers
    server app1 10.0.1.10:4000 check port 4000 weight 100
    server app2 10.0.1.11:4000 check port 4000 weight 100
    server app3 10.0.1.12:4000 check port 4000 weight 100
    server app4 10.0.1.13:4000 check port 4000 weight 100
    
    # Backup server for maintenance
    server maintenance 10.0.1.100:8080 check port 8080 backup

# Canary deployment backend
backend prismatic_canary
    balance roundrobin
    
    # Canary servers
    server canary1 10.0.2.10:4000 check port 4000 weight 100
    server canary2 10.0.2.11:4000 check port 4000 weight 100

# Blue-green deployment configuration
backend prismatic_blue
    balance roundrobin
    server blue1 10.0.3.10:4000 check port 4000 weight 100
    server blue2 10.0.3.11:4000 check port 4000 weight 100

backend prismatic_green
    balance roundrobin
    server green1 10.0.4.10:4000 check port 4000 weight 100
    server green2 10.0.4.11:4000 check port 4000 weight 100
```

### NGINX Configuration

Alternative NGINX configuration for load balancing:

```nginx
# /etc/nginx/sites-available/prismatic
upstream prismatic_app {
    least_conn;
    
    server 10.0.1.10:4000 max_fails=3 fail_timeout=30s weight=100;
    server 10.0.1.11:4000 max_fails=3 fail_timeout=30s weight=100;
    server 10.0.1.12:4000 max_fails=3 fail_timeout=30s weight=100;
    server 10.0.1.13:4000 max_fails=3 fail_timeout=30s weight=100;
    
    # Health check
    keepalive 32;
}

# Canary upstream for gradual deployments
upstream prismatic_canary {
    server 10.0.2.10:4000 max_fails=3 fail_timeout=30s;
    server 10.0.2.11:4000 max_fails=3 fail_timeout=30s;
    
    keepalive 16;
}

# Rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;

server {
    listen 80;
    server_name prismatic.com www.prismatic.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name prismatic.com www.prismatic.com;
    
    # SSL configuration
    ssl_certificate /etc/ssl/certs/prismatic.pem;
    ssl_certificate_key /etc/ssl/private/prismatic.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
    
    # Health check endpoint (bypass rate limiting)
    location /health {
        access_log off;
        proxy_pass http://prismatic_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # API endpoints with rate limiting
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        
        # Canary deployment logic
        set $backend prismatic_app;
        
        # Route 10% of traffic to canary if enabled
        if ($arg_canary = "true") {
            set $backend prismatic_canary;
        }
        
        # Random canary routing (10% of traffic)
        if ($request_id ~ "^.{0,1}[0]") {
            set $backend prismatic_canary;
        }
        
        proxy_pass http://$backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 5s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Login endpoints with stricter rate limiting
    location /login {
        limit_req zone=login burst=3 nodelay;
        
        proxy_pass http://prismatic_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Static assets with caching
    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        
        proxy_pass http://prismatic_app;
        proxy_set_header Host $host;
    }
    
    # All other requests
    location / {
        proxy_pass http://prismatic_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Custom error pages
    error_page 502 503 504 /maintenance.html;
    location = /maintenance.html {
        root /var/www/error_pages;
        internal;
    }
}
```

---

## SSL/TLS Certificate Management

### Automated Certificate Management

Implement automated SSL certificate management with Let's Encrypt:

```bash
#!/bin/bash
# scripts/deploy/manage-ssl-certificates.sh

set -euo pipefail

DOMAIN=${1:-prismatic.com}
EMAIL=${2:-admin@prismatic.com}
STAGING=${3:-false}

echo "Managing SSL certificates for domain: $DOMAIN"

# Install certbot if not present
if ! command -v certbot &> /dev/null; then
    echo "Installing certbot..."
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
fi

# Use staging environment for testing
CERTBOT_ARGS=""
if [ "$STAGING" = "true" ]; then
    CERTBOT_ARGS="--staging"
    echo "Using Let's Encrypt staging environment"
fi

# Obtain or renew certificate
echo "Obtaining certificate for $DOMAIN..."
certbot certonly \
    --nginx \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    --domains $DOMAIN,www.$DOMAIN \
    $CERTBOT_ARGS

# Verify certificate
echo "Verifying certificate..."
openssl x509 -in /etc/letsencrypt/live/$DOMAIN/cert.pem -text -noout | grep -E "(Subject|DNS)"

# Set up automatic renewal
echo "Setting up automatic renewal..."
cat > /etc/cron.d/certbot-renewal << EOF
# Renew certificates twice daily
0 0,12 * * * root certbot renew --quiet --nginx && systemctl reload nginx
EOF

# Test certificate configuration
echo "Testing SSL configuration..."
if curl -f https://$DOMAIN/health; then
    echo "SSL configuration test passed"
else
    echo "SSL configuration test failed"
    exit 1
fi

echo "SSL certificate management completed"
```

### Certificate Monitoring

Monitor certificate expiration and health:

```elixir
defmodule Prismatic.CertificateMonitor do
  use GenServer
  require Logger
  
  @check_interval 24 * 60 * 60 * 1000  # Check daily
  @warning_threshold 30  # Warn when certificate expires in 30 days
  @critical_threshold 7  # Critical alert when certificate expires in 7 days
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    domains = Keyword.get(opts, :domains, ["prismatic.com"])
    
    # Check certificates immediately and then daily
    send(self(), :check_certificates)
    :timer.send_interval(@check_interval, :check_certificates)
    
    {:ok, %{domains: domains}}
  end
  
  def handle_info(:check_certificates, state) do
    for domain <- state.domains do
      check_certificate_expiration(domain)
    end
    
    {:noreply, state}
  end
  
  defp check_certificate_expiration(domain) do
    case get_certificate_info(domain) do
      {:ok, cert_info} ->
        days_until_expiry = calculate_days_until_expiry(cert_info.expires_at)
        
        Logger.info("Certificate status for #{domain}", 
          expires_at: cert_info.expires_at,
          days_until_expiry: days_until_expiry,
          issuer: cert_info.issuer
        )
        
        cond do
          days_until_expiry <= @critical_threshold ->
            Logger.error("CRITICAL: SSL certificate expires soon", 
              domain: domain,
              days_until_expiry: days_until_expiry,
              expires_at: cert_info.expires_at
            )
            send_certificate_alert(domain, :critical, days_until_expiry)
            
          days_until_expiry <= @warning_threshold ->
            Logger.warning("WARNING: SSL certificate expires soon", 
              domain: domain,
              days_until_expiry: days_until_expiry,
              expires_at: cert_info.expires_at
            )
            send_certificate_alert(domain, :warning, days_until_expiry)
            
          true ->
            :ok
        end
        
      {:error, reason} ->
        Logger.error("Failed to check certificate for #{domain}", reason: reason)
        send_certificate_alert(domain, :error, "Certificate check failed: #{reason}")
    end
  end
  
  defp get_certificate_info(domain) do
    case :ssl.connect(to_charlist(domain), 443, [], 10_000) do
      {:ok, socket} ->
        case :ssl.peercert(socket) do
          {:ok, cert} ->
            :ssl.close(socket)
            parse_certificate(cert)
            
          {:error, reason} ->
            :ssl.close(socket)
            {:error, reason}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp parse_certificate(cert) do
    case :public_key.pkix_decode_cert(cert, :otp) do
      {:OTPCertificate, _, _, cert_info} ->
        validity = cert_info.validity
        {:ok, %{
          expires_at: parse_asn1_time(validity.notAfter),
          issuer: "Parsed Issuer"
        }}
        
      _ ->
        {:error, "Failed to parse certificate"}
    end
  end
  
  defp parse_asn1_time({:utcTime, time_string}) do
    # Parse ASN.1 time format
    time_string
    |> to_string()
    |> String.to_charlist()
    |> :calendar.datetime_to_gregorian_seconds()
    |> DateTime.from_gregorian_seconds()
  end
  
  defp calculate_days_until_expiry(expires_at) do
    now = DateTime.utc_now()
    DateTime.diff(expires_at, now, :day)
  end
  
  defp send_certificate_alert(domain, severity, details) do
    # Send alerts via configured notification channels
    Logger.log(severity, "Certificate alert for #{domain}", details: details)
  end
end
```

---

## Container Deployment with Docker

### Docker Configuration

Optimize Docker containers for production deployment:

```dockerfile
# Dockerfile
FROM elixir:1.15-alpine AS builder

# Install build dependencies
RUN apk add --no-cache build-base npm git python3

# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV=prod

# Install mix dependencies
COPY mix.exs mix.lock ./
COPY apps/prismatic/mix.exs ./apps/prismatic/
COPY apps/prismatic_web/mix.exs ./apps/prismatic_web/
RUN mix do deps.get, deps.compile

# Build assets
COPY apps/prismatic_web/assets/package.json apps/prismatic_web/assets/package-lock.json ./apps/prismatic_web/assets/
RUN npm --prefix ./apps/prismatic_web/assets ci --progress=false --no-audit --loglevel=error

COPY apps/prismatic_web/priv ./apps/prismatic_web/priv
COPY apps/prismatic_web/assets ./apps/prismatic_web/assets
RUN npm run --prefix ./apps/prismatic_web/assets build
RUN mix phx.digest

# Compile and build release
COPY . .
RUN mix do compile, release

# Production image
FROM alpine:3.18 AS app

RUN apk add --no-cache openssl ncurses-libs libstdc++

# Create app user
RUN addgroup -g 1000 -S app && \
    adduser -S app -G app -u 1000

# Create app directory
WORKDIR /app
RUN chown app:app /app

# Copy release from builder stage
COPY --from=builder --chown=app:app /app/_build/prod/rel/prismatic ./

# Switch to app user
USER app

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD /app/bin/prismatic rpc "Elixir.PrismaticWeb.HealthController.check(nil, nil)"

EXPOSE 4000

CMD ["/app/bin/prismatic", "start"]
```

### Docker Compose for Production

Production Docker Compose configuration:

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  app:
    image: prismatic:${APP_VERSION:-latest}
    restart: unless-stopped
    ports:
      - "4000:4000"
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - PHX_HOST=${PHX_HOST}
      - EXTERNAL_API_KEY=${EXTERNAL_API_KEY}
      - SENTRY_DSN=${SENTRY_DSN}
      - DEPLOYMENT_ID=${DEPLOYMENT_ID:-unknown}
    depends_on:
      - postgres
      - redis
    healthcheck:
      test: ["CMD", "/app/bin/prismatic", "rpc", "System.get_env(\"HEALTH_CHECK_PORT\", \"4000\") |> String.to_integer() |> (&HTTPoison.get(\"http://localhost:#{&1}/health\")).() |> elem(1) |> Map.get(:status_code) |> Kernel.==(200)"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - app-network
    volumes:
      - app-logs:/app/logs
    deploy:
      resources:
        limits:
          memory: 1G
          cpus: '0.5'
        reservations:
          memory: 512M
          cpus: '0.25'

  postgres:
    image: postgres:15-alpine
    restart: unless-stopped
    environment:
      - POSTGRES_DB=${DB_NAME:-prismatic}
      - POSTGRES_USER=${DB_USER:-prismatic}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./scripts/postgres/init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-prismatic}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - app-network
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3
    networks:
      - app-network
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.25'

  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/ssl:/etc/ssl/certs:ro
      - nginx-logs:/var/log/nginx
    depends_on:
      - app
    networks:
      - app-network
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: '0.25'

volumes:
  postgres-data:
    driver: local
  redis-data:
    driver: local
  app-logs:
    driver: local
  nginx-logs:
    driver: local

networks:
  app-network:
    driver: bridge
```

---

## CI/CD Integration

### GitHub Actions Deployment Pipeline

Integrate deployment with CI/CD pipeline:

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        default: 'staging'
        type: choice
        options:
          - staging
          - production

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.15'
          otp-version: '26'
          
      - name: Cache dependencies
        uses: actions/cache@v3
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
          restore-keys: ${{ runner.os }}-mix-
          
      - name: Install dependencies
        run: mix deps.get
        
      - name: Run tests
        run: mix test
        
      - name: Check formatting
        run: mix format --check-formatted
        
      - name: Run security scan
        run: mix sobelow --config

  build:
    needs: test
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
      image-digest: ${{ steps.build.outputs.digest }}
      
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
        
      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=tag
            type=sha,prefix={{branch}}-
            
      - name: Build and push Docker image
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy-staging:
    if: github.event.inputs.environment == 'staging' || startsWith(github.ref, 'refs/tags/v')
    needs: build
    runs-on: ubuntu-latest
    environment: staging
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
          
      - name: Deploy to staging
        run: |
          echo "Deploying to staging environment..."
          ./scripts/deploy/deploy.sh staging ${{ needs.build.outputs.image-tag }}
          
      - name: Run smoke tests
        run: |
          ./scripts/deploy/smoke-tests.sh https://staging.prismatic.com
          
      - name: Notify team
        if: failure()
        uses: 8398a7/action-slack@v3
        with:
          status: failure
          text: 'Staging deployment failed!'
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

  deploy-production:
    if: github.event.inputs.environment == 'production' && startsWith(github.ref, 'refs/tags/v')
    needs: [build, deploy-staging]
    runs-on: ubuntu-latest
    environment: production
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
          
      - name: Pre-deployment checks
        run: |
          ./scripts/deploy/pre-deployment-checks.sh production
          
      - name: Create deployment backup
        run: |
          ./scripts/deploy/backup.sh production
          
      - name: Deploy to production
        run: |
          echo "Deploying to production environment..."
          ./scripts/deploy/deploy.sh production ${{ needs.build.outputs.image-tag }}
          
      - name: Post-deployment verification
        run: |
          ./scripts/deploy/post-deployment-verification.sh https://prismatic.com
          
      - name: Notify team of success
        uses: 8398a7/action-slack@v3
        with:
          status: success
          text: 'Production deployment completed successfully!'
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
          
      - name: Notify team of failure
        if: failure()
        uses: 8398a7/action-slack@v3
        with:
          status: failure
          text: 'Production deployment failed! Immediate attention required.'
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

## Emergency Procedures

### Incident Response Playbook

Handle production incidents systematically:

```bash
#!/bin/bash
# scripts/deploy/emergency-response.sh

set -euo pipefail

INCIDENT_TYPE=${1:-}
SEVERITY=${2:-medium}

if [ -z "$INCIDENT_TYPE" ]; then
  echo "Usage: $0 <incident_type> [severity]"
  echo ""
  echo "Incident types:"
  echo "  outage          - Complete service outage"
  echo "  performance     - Performance degradation"
  echo "  security        - Security incident"
  echo "  data_loss       - Data loss or corruption"
  echo "  deployment      - Deployment failure"
  echo ""
  echo "Severity levels: low, medium, high, critical"
  exit 1
fi

echo "======================================="
echo "EMERGENCY INCIDENT RESPONSE"
echo "======================================="
echo "Incident type: $INCIDENT_TYPE"
echo "Severity: $SEVERITY"
echo "Response time: $(date)"
echo "Responder: $(whoami)"
echo ""

# Log incident start
echo "$(date): Emergency response initiated - Type: $INCIDENT_TYPE, Severity: $SEVERITY, Responder: $(whoami)" >> /var/log/prismatic/incidents.log

case $INCIDENT_TYPE in
  "outage")
    echo "Executing outage response procedure..."
    
    # Check system status
    echo "1. Checking system status..."
    ./scripts/deploy/health-check.sh || echo "Health check failed"
    
    # Enable maintenance mode
    echo "2. Enabling maintenance mode..."
    curl -X POST http://load-balancer/maintenance -d "enabled=true"
    
    # Check recent deployments
    echo "3. Checking recent deployments..."
    docker images prismatic --format "table {{.Tag}}\t{{.CreatedAt}}" | head -5
    
    # Prompt for rollback
    read -p "Do you want to rollback to previous version? (yes/no): " rollback_confirm
    if [ "$rollback_confirm" = "yes" ]; then
      echo "Initiating emergency rollback..."
      ./scripts/deploy/rollback.sh $(docker images prismatic --format "{{.Tag}}" | sed -n '2p') emergency true
    fi
    ;;
    
  "performance")
    echo "Executing performance incident response..."
    
    # Check resource usage
    echo "1. Checking resource usage..."
    echo "Memory usage:"
    free -h
    echo "CPU usage:"
    top -bn1 | grep "Cpu(s)"
    echo "Disk usage:"
    df -h
    
    # Check application metrics
    echo "2. Checking application metrics..."
    curl -s http://localhost:4000/metrics || echo "Metrics endpoint unavailable"
    
    # Scale up if necessary
    read -p "Do you want to scale up instances? (yes/no): " scale_confirm
    if [ "$scale_confirm" = "yes" ]; then
      echo "Scaling up application instances..."
      docker-compose up -d --scale app=4
    fi
    ;;
    
  "security")
    echo "Executing security incident response..."
    
    # Immediate security measures
    echo "1. Implementing immediate security measures..."
    
    # Block suspicious IPs if provided
    read -p "Enter suspicious IP addresses to block (space-separated, or press Enter to skip): " suspicious_ips
    if [ -n "$suspicious_ips" ]; then
      for ip in $suspicious_ips; do
        echo "Blocking IP: $ip"
        iptables -A INPUT -s $ip -j DROP
      done
    fi
    
    # Enable additional logging
    echo "2. Enabling enhanced security logging..."
    # Implementation depends on your logging setup
    
    # Notify security team
    echo "3. Security incident logged and notifications sent"
    ;;
    
  "deployment")
    echo "Executing deployment failure response..."
    
    # Automatic rollback for deployment failures
    echo "1. Checking deployment status..."
    ./scripts/deploy/deployment-status.sh
    
    echo "2. Initiating automatic rollback..."
    ./scripts/deploy/rollback.sh $(docker images prismatic --format "{{.Tag}}" | sed -n '2p') deployment_failure true
    ;;
    
  *)
    echo "Generic incident response procedure..."
    echo "1. Document the incident"
    echo "2. Assess the impact"
    echo "3. Implement immediate mitigation"
    echo "4. Monitor the situation"
    ;;
esac

# Send notifications based on severity
case $SEVERITY in
  "critical"|"high")
    echo "Sending high-priority notifications..."
    # Send immediate alerts to on-call team
    curl -X POST "$SLACK_WEBHOOK_URL" -H 'Content-type: application/json' --data "{\"text\":\"🚨 CRITICAL INCIDENT: $INCIDENT_TYPE - Immediate attention required\"}"
    ;;
  "medium")
    echo "Sending standard notifications..."
    curl -X POST "$SLACK_WEBHOOK_URL" -H 'Content-type: application/json' --data "{\"text\":\"⚠️ Incident: $INCIDENT_TYPE - Investigation in progress\"}"
    ;;
esac

echo ""
echo "======================================="
echo "IMMEDIATE RESPONSE COMPLETED"
echo "======================================="
echo "Next steps:"
echo "1. Continue monitoring the situation"
echo "2. Document findings and actions taken"
echo "3. Communicate status updates to stakeholders"
echo "4. Plan long-term resolution if needed"
echo ""

# Log incident response completion
echo "$(date): Emergency response completed - Type: $INCIDENT_TYPE" >> /var/log/prismatic/incidents.log
```

---

## Post-Deployment Verification

### Comprehensive Verification Suite

Verify deployment success with comprehensive checks:

```bash
#!/bin/bash
# scripts/deploy/post-deployment-verification.sh

set -euo pipefail

BASE_URL=${1:-https://prismatic.com}
TIMEOUT=${2:-300}

echo "======================================="
echo "POST-DEPLOYMENT VERIFICATION"
echo "======================================="
echo "Target URL: $BASE_URL"
echo "Timeout: ${TIMEOUT}s"
echo "Start time: $(date)"
echo ""

FAILED_CHECKS=0

# Function to run check and track failures
run_check() {
  local check_name="$1"
  local check_command="$2"
  
  echo "Checking: $check_name"
  if eval "$check_command"; then
    echo "✅ $check_name: PASSED"
  else
    echo "❌ $check_name: FAILED"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  fi
  echo ""
}

# Health check
run_check "Application Health" "curl -f -s --max-time 10 $BASE_URL/health > /dev/null"

# Database connectivity
run_check "Database Connectivity" "curl -f -s --max-time 10 $BASE_URL/health | jq -e '.checks.database == \"ok\"' > /dev/null"

# External service connectivity
run_check "External Services" "curl -f -s --max-time 10 $BASE_URL/health | jq -e '.checks.external_services == \"ok\"' > /dev/null"

# SSL certificate validity
run_check "SSL Certificate" "echo | openssl s_client -servername $(echo $BASE_URL | sed 's|https://||') -connect $(echo $BASE_URL | sed 's|https://||'):443 2>/dev/null | openssl x509 -noout -dates | grep -q 'notAfter'"

# Response time check
run_check "Response Time (<2s)" "[ \$(curl -o /dev/null -s -w '%{time_total}' $BASE_URL/health | cut -d. -f1) -lt 2 ]"

# Critical user journeys
echo "Testing critical user journeys..."

# Test home page
run_check "Home Page Load" "curl -f -s --max-time 10 $BASE_URL/ | grep -q '<title>'"

# Test API endpoints
run_check "API Health Endpoint" "curl -f -s --max-time 10 $BASE_URL/api/health | jq -e '.status == \"healthy\"' > /dev/null"

# Test authentication flow (if applicable)
if [ -n "${API_TOKEN:-}" ]; then
  run_check "API Authentication" "curl -f -s --max-time 10 -H \"Authorization: Bearer $API_TOKEN\" $BASE_URL/api/user/profile > /dev/null"
fi

# Test static assets
run_check "Static Assets" "curl -f -s --max-time 10 $BASE_URL/assets/app.css > /dev/null"

# Performance benchmarks
echo "Running performance benchmarks..."

# Load test (light)
run_check "Light Load Test (10 concurrent)" "ab -n 100 -c 10 -t 30 $BASE_URL/ | grep -q 'Complete requests:.*100'"

# Memory usage check
run_check "Memory Usage Reasonable" "[ \$(docker stats --no-stream --format \"{{.MemUsage}}\" | grep -o '[0-9]*' | head -1) -lt 1000 ]"

# Log analysis for errors
echo "Analyzing recent logs for errors..."
ERROR_COUNT=$(docker logs prismatic_app_1 --since="5m" 2>&1 | grep -i error | wc -l)
run_check "Error Log Analysis (<5 errors in 5min)" "[ $ERROR_COUNT -lt 5 ]"

# Database migration status
run_check "Database Migrations Current" "docker exec prismatic_app_1 /app/bin/prismatic rpc 'length(Ecto.Migrator.migrations(Prismatic.Repo, :down))' | grep -q '^0$'"

# Feature flags validation (if applicable)
if command -v prismatic-cli &> /dev/null; then
  run_check "Feature Flags Validation" "prismatic-cli feature-flags validate"
fi

# Final summary
echo "======================================="
echo "VERIFICATION SUMMARY"
echo "======================================="
echo "Total checks run: $(($(grep -c 'Checking:' <<< "$(set +x; eval 'echo checking placeholder')" 2>/dev/null || echo 15)))"
echo "Failed checks: $FAILED_CHECKS"
echo "Completion time: $(date)"

if [ $FAILED_CHECKS -eq 0 ]; then
  echo ""
  echo "🎉 ALL VERIFICATION CHECKS PASSED!"
  echo "Deployment verified successfully."
  exit 0
else
  echo ""
  echo "⚠️  $FAILED_CHECKS VERIFICATION CHECKS FAILED!"
  echo "Please investigate the failed checks before considering the deployment complete."
  exit 1
fi
```

---

## Common Issues and Troubleshooting

### Issue Resolution Guide

Common deployment issues and their solutions:

```markdown
## Common Deployment Issues

### 1. Database Migration Failures

**Symptoms:**
- Deployment hangs during migration step
- Application fails to start with database errors
- Migration timeout errors

**Diagnosis:**
```bash
# Check migration status
docker exec app_container /app/bin/prismatic rpc "Ecto.Migrator.status(Prismatic.Repo)"

# Check database connectivity
docker exec app_container /app/bin/prismatic rpc "Ecto.Adapters.SQL.query!(Prismatic.Repo, \"SELECT 1\", [])"
```

**Solutions:**
- Verify database backup exists before migration
- Check migration syntax for unsafe operations
- Increase migration timeout in deployment script
- Run migrations separately from application deployment
- Use migration rollback if needed

### 2. Health Check Failures

**Symptoms:**
- Load balancer marks instances as unhealthy
- Deployment rollback triggered automatically
- HTTP 503 errors from load balancer

**Diagnosis:**
```bash
# Test health endpoint directly
curl -v http://instance:4000/health

# Check application logs
docker logs app_container --tail 100

# Check resource usage
docker stats app_container
```

**Solutions:**
- Verify health check endpoint responds correctly
- Increase health check timeout in load balancer
- Check application startup time and adjust grace period
- Verify database connectivity from application
- Check resource constraints (memory, CPU)

### 3. SSL Certificate Issues

**Symptoms:**
- Browser security warnings
- SSL handshake failures
- Certificate expiration alerts

**Diagnosis:**
```bash
# Check certificate expiration
echo | openssl s_client -servername yourdomain.com -connect yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates

# Verify certificate chain
curl -I https://yourdomain.com
```

**Solutions:**
- Renew certificates before expiration
- Verify certificate chain completeness
- Update load balancer with new certificates
- Check certificate permissions and ownership
- Validate DNS configuration

### 4. Container Resource Issues

**Symptoms:**
- Application OOM (Out of Memory) kills
- CPU throttling affecting performance
- Container startup failures

**Diagnosis:**
```bash
# Check resource usage
docker stats

# Check container limits
docker inspect container_name | jq '.[0].HostConfig.Memory'

# Check system resources
free -h && df -h
```

**Solutions:**
- Increase memory limits in Docker Compose
- Optimize application memory usage
- Add swap space if appropriate
- Scale horizontally instead of vertically
- Profile application for memory leaks

### 5. Load Balancer Configuration Issues

**Symptoms:**
- Uneven traffic distribution
- Session affinity problems
- Intermittent 502/503 errors

**Diagnosis:**
```bash
# Check load balancer status
curl http://load-balancer/stats

# Test individual instances
for instance in app1 app2 app3; do
  curl -f http://$instance:4000/health || echo "$instance failed"
done
```

**Solutions:**
- Verify health check configuration
- Adjust load balancing algorithm
- Check instance capacity and scaling
- Review session handling configuration
- Update timeout settings
```

### Debugging Commands

Essential commands for deployment troubleshooting:

```bash
#!/bin/bash
# scripts/deploy/debug-deployment.sh

echo "=== Deployment Debug Information ==="
echo "Timestamp: $(date)"
echo "User: $(whoami)"
echo "Host: $(hostname)"
echo ""

echo "=== Application Status ==="
docker-compose ps
echo ""

echo "=== Recent Logs ==="
echo "Application logs (last 50 lines):"
docker logs prismatic_app_1 --tail 50
echo ""

echo "Database logs (last 20 lines):"
docker logs prismatic_postgres_1 --tail 20
echo ""

echo "=== Resource Usage ==="
echo "Docker stats:"
docker stats --no-stream
echo ""

echo "System resources:"
echo "Memory:"
free -h
echo "Disk:"
df -h
echo "Load average:"
uptime
echo ""

echo "=== Network Connectivity ==="
echo "Testing internal connectivity:"
docker exec prismatic_app_1 nc -zv postgres 5432 || echo "Database connection failed"
docker exec prismatic_app_1 nc -zv redis 6379 || echo "Redis connection failed"
echo ""

echo "Testing external connectivity:"
docker exec prismatic_app_1 curl -f -s --max-time 5 https://httpbin.org/get > /dev/null && echo "External connectivity: OK" || echo "External connectivity: FAILED"
echo ""

echo "=== Configuration ==="
echo "Environment variables (sanitized):"
docker exec prismatic_app_1 env | grep -E "^(DATABASE_URL|PHX_HOST|MIX_ENV)" | sed 's/\(.*=\)[^@]*@\(.*\)/\1***@\2/' | sed 's/\(.*=\)[^:]*:\([^@]*\)@/\1***:\2@/'
echo ""

echo "=== Health Checks ==="
echo "Application health:"
curl -s http://localhost:4000/health | jq '.' 2>/dev/null || echo "Health check failed or invalid JSON"
echo ""

echo "Load balancer status:"
curl -s http://load-balancer/stats 2>/dev/null || echo "Load balancer stats unavailable"
echo ""
```

---

## Related Documentation

- **[CI/CD Implementation](../workflow/ci-cd-implementation.md)** - Automated deployment pipeline setup and configuration
- **[Error Handling & Logging](../development/error-handling-logging.md)** - Production error monitoring and alerting strategies
- **[Testing Strategy](../development/testing-strategy.md)** - Pre-deployment testing procedures and verification
- **[Performance Optimization](../performance/performance-optimization.md)** - Production performance monitoring and optimization
- **[Security Guidelines](../security/security-guidelines.md)** - Production security considerations and hardening
- **[Deployment Operations](deployment-operations.md)** - Day-to-day operational deployment procedures

---

**💡 Pro Tip**: Successful deployments require preparation, automation, and monitoring. Invest time in creating robust deployment procedures, comprehensive health checks, and effective rollback mechanisms. Remember that the goal is not just to deploy code, but to maintain a reliable, performant system that serves users effectively. Always have a rollback plan and don't hesitate to use it when issues arise.