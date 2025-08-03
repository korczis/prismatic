# Phase 2: Core Infrastructure Migration Implementation Guide

## Overview

This document provides detailed implementation guidance for Phase 2 of the Enterprise Phoenix Umbrella Consolidation Strategy, focusing on core infrastructure migration, authentication unification, and monitoring setup.

## Timeline: Week 3-5

## Prerequisites

- Phase 1 completed with legacy analysis reports
- Migration tooling validated and ready
- Development environment prepared

## Objectives

- Migrate core business logic to domain-driven contexts
- Implement unified authentication and authorization
- Set up comprehensive monitoring infrastructure
- Consolidate data access layer

## Task 1: Umbrella App Structure Creation

### 1.1 Create prismatic_core App

**Generate the app:**
```bash
cd apps
mix new prismatic_core --app prismatic_core
```

**App structure (DDD contexts):**
```
apps/prismatic_core/
├── lib/
│   ├── prismatic_core.ex
│   ├── prismatic_core/
│   │   ├── application.ex
│   │   ├── contexts/
│   │   │   ├── agents/           # Agent management
│   │   │   │   ├── agent.ex
│   │   │   │   ├── agent_instance.ex
│   │   │   │   ├── agent_behavior.ex
│   │   │   │   └── agent_orchestrator.ex
│   │   │   ├── cognitive/        # Cognitive modeling
│   │   │   │   ├── cognitive_profile.ex
│   │   │   │   ├── personality_trait.ex
│   │   │   │   ├── fallacy_detector.ex
│   │   │   │   └── cognitive_analyzer.ex
│   │   │   ├── knowledge/        # Knowledge management
│   │   │   │   ├── knowledge_base.ex
│   │   │   │   ├── blackboard_entry.ex
│   │   │   │   ├── prolog_rule.ex
│   │   │   │   └── inference_engine.ex
│   │   │   ├── memory/           # Memory systems
│   │   │   │   ├── memory_store.ex
│   │   │   │   ├── episodic_memory.ex
│   │   │   │   └── semantic_memory.ex
│   │   │   ├── speech/           # Speech processing
│   │   │   │   ├── speech_session.ex
│   │   │   │   ├── audio_segment.ex
│   │   │   │   ├── transcript.ex
│   │   │   │   └── whisper_processor.ex
│   │   │   └── llm/              # LLM orchestration
│   │   │       ├── llm_backend.ex
│   │   │       ├── llm_orchestrator.ex
│   │   │       └── conversation.ex
│   │   └── shared/
│   │       ├── protocols/        # Core behavior contracts
│   │       ├── supervisors/      # OTP supervision trees
│   │       └── telemetry/        # Instrumentation
│   └── test/
```

**Sample context module:**
```elixir
# apps/prismatic_core/lib/prismatic_core/contexts/agents.ex
defmodule PrismaticCore.Agents do
  @moduledoc """
  Agent management context with business logic for agent lifecycle,
  behavior protocols, and orchestration.
  """
  
  alias PrismaticCore.Agents.{Agent, AgentInstance, AgentOrchestrator}
  alias PrismaticData.Repo
  
  def create_agent(attrs) do
    %Agent{}
    |> Agent.changeset(attrs)
    |> Repo.insert()
  end
  
  def get_agent!(id), do: Repo.get!(Agent, id)
  
  def list_agents(filters \\ []) do
    Agent
    |> apply_filters(filters)
    |> Repo.all()
  end
  
  def start_agent_instance(agent_id, config) do
    AgentOrchestrator.start_instance(agent_id, config)
  end
  
  defp apply_filters(query, []), do: query
  defp apply_filters(query, [{:tenant_id, tenant_id} | rest]) do
    query
    |> where([a], a.tenant_id == ^tenant_id)
    |> apply_filters(rest)
  end
end
```

### 1.2 Create prismatic_auth App

**Generate the app:**
```bash
cd apps
mix new prismatic_auth --app prismatic_auth
```

**Authentication structure:**
```
apps/prismatic_auth/
├── lib/
│   ├── prismatic_auth.ex
│   ├── prismatic_auth/
│   │   ├── application.ex
│   │   ├── accounts/              # User management
│   │   │   ├── user.ex
│   │   │   ├── user_token.ex
│   │   │   └── accounts.ex
│   │   ├── sessions/              # Session management
│   │   │   ├── session.ex
│   │   │   └── session_manager.ex
│   │   ├── permissions/           # RBAC
│   │   │   ├── role.ex
│   │   │   ├── permission.ex
│   │   │   └── authorization.ex
│   │   ├── multi_tenant/          # Tenant management
│   │   │   ├── tenant.ex
│   │   │   └── tenant_context.ex
│   │   ├── providers/             # External auth
│   │   │   ├── oauth2.ex
│   │   │   └── saml.ex
│   │   └── guardian.ex            # JWT handling
```

**Guardian setup:**
```elixir
# apps/prismatic_auth/lib/prismatic_auth/guardian.ex
defmodule PrismaticAuth.Guardian do
  use Guardian, otp_app: :prismatic_auth
  
  alias PrismaticAuth.Accounts
  
  def subject_for_token(user, _claims) do
    {:ok, to_string(user.id)}
  end
  
  def resource_from_claims(%{"sub" => id}) do
    case Accounts.get_user(id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  end
  
  def authenticate_with_mfa(user, token, opts \\ []) do
    with {:ok, _claims} <- verify_mfa_token(token),
         {:ok, jwt, claims} <- encode_and_sign(user, %{mfa_verified: true}, opts) do
      {:ok, jwt, claims}
    end
  end
end
```

### 1.3 Create prismatic_data App

**Generate the app:**
```bash
cd apps
mix new prismatic_data --app prismatic_data
```

**Data access structure:**
```
apps/prismatic_data/
├── lib/
│   ├── prismatic_data.ex
│   ├── prismatic_data/
│   │   ├── application.ex
│   │   ├── repo.ex                # Main repository
│   │   ├── schemas/               # Database schemas
│   │   │   ├── agent.ex
│   │   │   ├── user.ex
│   │   │   ├── tenant.ex
│   │   │   └── knowledge_base.ex
│   │   ├── migrations/            # Database migrations
│   │   └── seeds/                 # Data seeding
│   └── priv/
│       └── repo/
│           ├── migrations/
│           └── seeds.exs
```

**Multi-tenant repository:**
```elixir
# apps/prismatic_data/lib/prismatic_data/repo.ex
defmodule PrismaticData.Repo do
  use Ecto.Repo,
    otp_app: :prismatic_data,
    adapter: Ecto.Adapters.Postgres
  
  def with_tenant(tenant_id, fun) when is_function(fun, 0) do
    Ecto.Multi.new()
    |> Ecto.Multi.run(:set_tenant, fn _repo, _changes ->
      set_tenant_context(tenant_id)
    end)
    |> Ecto.Multi.run(:execute, fn _repo, _changes ->
      fun.()
    end)
    |> transaction()
  end
  
  def distributed_transaction(operations) do
    prepare_phase(operations)
    |> case do
      :ok -> commit_phase(operations)
      {:error, reason} -> abort_phase(operations, reason)
    end
  end
  
  defp set_tenant_context(tenant_id) do
    # Set row-level security or schema switching
    query("SET app.current_tenant = $1", [tenant_id])
  end
end
```

### 1.4 Create prismatic_monitoring App

**Generate the app:**
```bash
cd apps
mix new prismatic_monitoring --app prismatic_monitoring
```

**Monitoring structure:**
```
apps/prismatic_monitoring/
├── lib/
│   ├── prismatic_monitoring.ex
│   ├── prismatic_monitoring/
│   │   ├── application.ex
│   │   ├── metrics/               # Prometheus metrics
│   │   │   ├── business_metrics.ex
│   │   │   └── system_metrics.ex
│   │   ├── tracing/               # Distributed tracing
│   │   │   └── tracer.ex
│   │   ├── logging/               # Structured logging
│   │   │   └── logger.ex
│   │   ├── health/                # Health checks
│   │   │   └── health_check.ex
│   │   └── telemetry.ex           # Telemetry setup
```

## Task 2: Business Logic Migration

### 2.1 Agent Management Migration

**From legacy applications to [`prismatic_core/contexts/agents`](apps/prismatic_core/lib/prismatic_core/contexts/agents.ex):**

1. **Identify agent-related modules** in legacy apps
2. **Extract business logic** (remove infrastructure concerns)
3. **Create domain entities** following DDD patterns
4. **Implement context API** for external access
5. **Migrate tests** with proper isolation

**Migration checklist:**
- [ ] Agent lifecycle management
- [ ] Behavior protocol definitions
- [ ] Agent configuration handling
- [ ] Performance monitoring integration
- [ ] Multi-tenant agent isolation

### 2.2 Cognitive Analysis Migration

**Target:** [`prismatic_core/contexts/cognitive`](apps/prismatic_core/lib/prismatic_core/contexts/cognitive.ex)

**Key components to migrate:**
- Personality trait analysis
- Fallacy detection algorithms
- Manipulation vector analysis
- Cognitive bias detection
- Psychological profiling

### 2.3 Knowledge Base Migration

**Target:** [`prismatic_core/contexts/knowledge`](apps/prismatic_core/lib/prismatic_core/contexts/knowledge.ex)

**Components:**
- Knowledge source management
- Blackboard coordination
- Prolog rule engine integration
- Inference engine
- Knowledge graph operations

### 2.4 Speech Processing Migration

**Target:** [`prismatic_core/contexts/speech`](apps/prismatic_core/lib/prismatic_core/contexts/speech.ex)

**Components:**
- Whisper integration
- Audio segmentation
- Speaker diarization
- Transcript management
- Audio metadata handling

### 2.5 LLM Integration Migration

**Target:** [`prismatic_core/contexts/llm`](apps/prismatic_core/lib/prismatic_core/contexts/llm.ex)

**Components:**
- Backend abstraction layer
- Model orchestration
- Conversation management
- Token optimization
- Response caching

## Task 3: Authentication System Implementation

### 3.1 Guardian JWT Setup

**Configuration in [`config/config.exs`](config/config.exs):**
```elixir
config :prismatic_auth, PrismaticAuth.Guardian,
  issuer: "prismatic",
  secret_key: System.get_env("GUARDIAN_SECRET_KEY"),
  token_ttl: %{
    "access" => {30, :minutes},
    "refresh" => {7, :days}
  },
  token_verify_module: PrismaticAuth.Guardian.Token,
  allowed_algos: ["HS256"]
```

### 3.2 RBAC Implementation

**Role-based access control:**
```elixir
# apps/prismatic_auth/lib/prismatic_auth/authorization.ex
defmodule PrismaticAuth.Authorization do
  def authorize(user, action, resource, context \\ %{}) do
    user
    |> get_effective_permissions(context)
    |> has_permission?(action, resource)
  end
  
  defp get_effective_permissions(user, context) do
    role_permissions = get_role_permissions(user.roles)
    tenant_permissions = get_tenant_permissions(user, context.tenant_id)
    resource_permissions = get_resource_permissions(user, context.resource_type)
    
    merge_permissions([role_permissions, tenant_permissions, resource_permissions])
  end
end
```

### 3.3 Multi-Tenant Support

**Tenant isolation strategies:**
- Row-level security (RLS) in PostgreSQL
- Schema-based separation
- Application-level filtering
- Tenant context propagation

### 3.4 External Identity Providers

**OAuth2 integration:**
```elixir
# apps/prismatic_auth/lib/prismatic_auth/providers/oauth2.ex
defmodule PrismaticAuth.Providers.OAuth2 do
  def callback(provider, code, state) do
    with {:ok, token} <- exchange_code_for_token(provider, code, state),
         {:ok, user_info} <- fetch_user_info(provider, token),
         {:ok, user} <- find_or_create_user(user_info) do
      PrismaticAuth.Guardian.encode_and_sign(user)
    end
  end
end
```

## Task 4: Data Layer Consolidation

### 4.1 Schema Design

**Consolidated database schema addressing:**
- Table naming conflicts
- Column type mismatches  
- Foreign key relationship consolidation
- Index optimization
- Multi-tenant data isolation

### 4.2 Migration Strategy

**Blue-green database migration:**
```elixir
# apps/prismatic_data/lib/prismatic_data/migration/blue_green.ex
defmodule PrismaticData.Migration.BlueGreen do
  def execute_migration do
    # 1. Create green database
    create_green_database()
    
    # 2. Setup replication
    setup_replication()
    
    # 3. Sync data
    sync_data()
    
    # 4. Validate integrity
    validate_data_integrity()
    
    # 5. Switch traffic
    switch_traffic()
    
    # 6. Verify health
    verify_application_health()
  end
end
```

### 4.3 Repository Optimization

**Connection pooling and performance:**
```elixir
# config/config.exs
config :prismatic_data, PrismaticData.Repo,
  pool_size: 15,
  queue_target: 50,
  queue_interval: 1000,
  prepare: :named,
  parameters: [
    plan_cache_mode: "force_custom_plan"
  ]
```

## Task 5: Monitoring & Observability

### 5.1 Telemetry Setup

**Comprehensive instrumentation:**
```elixir
# apps/prismatic_monitoring/lib/prismatic_monitoring/telemetry.ex
defmodule PrismaticMonitoring.Telemetry do
  def setup do
    :telemetry.attach_many(
      "prismatic-metrics",
      [
        [:prismatic, :agent, :create],
        [:prismatic, :agent, :execute],
        [:prismatic, :cognitive, :analyze],
        [:phoenix, :router, :dispatch, :stop],
        [:vm, :memory]
      ],
      &handle_event/4,
      nil
    )
  end
end
```

### 5.2 Prometheus Metrics

**Business and system metrics:**
```elixir
# apps/prismatic_monitoring/lib/prismatic_monitoring/metrics.ex
defmodule PrismaticMonitoring.Metrics do
  use Prometheus.Metric
  
  def setup do
    Histogram.declare([
      name: :prismatic_agent_execution_duration,
      help: "Duration of agent executions",
      labels: [:agent_type],
      buckets: [0.1, 0.5, 1, 2, 5, 10, 30]
    ])
    
    Counter.declare([
      name: :prismatic_agent_executions_total,
      help: "Total number of agent executions",
      labels: [:agent_type, :status]
    ])
  end
end
```

### 5.3 Distributed Tracing

**OpenTelemetry integration:**
```elixir
# apps/prismatic_monitoring/lib/prismatic_monitoring/tracing.ex
defmodule PrismaticMonitoring.Tracing do
  def setup do
    OpentelemetryLoggerHandler.attach()
    OpentelemetryPhoenix.setup()
    OpentelemetryEcto.setup([:prismatic_data, :repo])
  end
  
  def trace_operation(name, fun, attributes \\ %{}) do
    span = start_span(name, attributes)
    
    try do
      result = fun.()
      OpenTelemetry.Span.set_status(span, :ok)
      result
    rescue
      error ->
        OpenTelemetry.Span.set_status(span, :error, to_string(error))
        reraise error, __STACKTRACE__
    after
      OpenTelemetry.Span.end_span(span)
    end
  end
end
```

### 5.4 Health Checks

**Comprehensive health monitoring:**
```elixir
# apps/prismatic_monitoring/lib/prismatic_monitoring/health_check.ex
defmodule PrismaticMonitoring.HealthCheck do
  def perform_health_check do
    checks = [
      database_connectivity: check_database(),
      cache_connectivity: check_cache(),
      external_services: check_external_services(),
      business_logic: check_business_logic(),
      performance_metrics: check_performance()
    ]
    
    %{
      status: determine_overall_status(checks),
      checks: checks,
      timestamp: DateTime.utc_now(),
      version: Application.spec(:prismatic_core, :vsn)
    }
  end
end
```

## Deliverables

- [ ] **Core Infrastructure Apps**: All umbrella apps created with proper structure
- [ ] **Business Logic Migration**: Core contexts migrated with domain boundaries
- [ ] **Authentication System**: Unified auth with RBAC and multi-tenant support
- [ ] **Data Layer**: Consolidated database with optimized access patterns
- [ ] **Monitoring Infrastructure**: Comprehensive observability and alerting

## Success Criteria

- [ ] All core features working in consolidated application
- [ ] Authentication system passes security audit
- [ ] 100% monitoring coverage for critical paths
- [ ] Database performance meets or exceeds legacy systems
- [ ] Zero data loss during migration process

## Risk Mitigation

- **Data Migration Risk**: Use blue-green deployment with real-time validation
- **Performance Risk**: Continuous benchmarking during migration
- **Security Risk**: Security audit at each milestone
- **Complexity Risk**: Incremental migration with rollback capability

## Next Steps

- Complete Phase 2 implementation
- Validate all systems with comprehensive testing
- Prepare for Phase 3: API Consolidation & Testing
- Document lessons learned and optimization opportunities

## Resources

- [Phase 1 Implementation Guide](phase-1-foundation-analysis.md)
- [Phase 3 Implementation Guide](phase-3-api-testing.md)
- [Enterprise Consolidation Strategy](../../ENTERPRISE_CONSOLIDATION_STRATEGY.md)