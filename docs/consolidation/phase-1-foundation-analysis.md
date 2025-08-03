# Phase 1: Foundation & Analysis Implementation Guide

## Overview

This document provides detailed implementation guidance for Phase 1 of the Enterprise Phoenix Umbrella Consolidation Strategy, focusing on legacy codebase discovery, migration tooling, and development environment setup.

## Timeline: Week 1-2

## Objectives

- Complete legacy codebase analysis
- Set up development environment
- Create migration tooling
- Establish foundation for Phase 2

## Task 1: Legacy Codebase Discovery

### 1.1 Create Legacy Codebase Analysis Tooling

**Location**: `lib/consolidation/code_analyzer.ex`

```elixir
defmodule PrismaticConsolidation.CodeAnalyzer do
  @moduledoc """
  Comprehensive static analysis for legacy code migration.
  Uses Elixir AST parsing for deep code analysis.
  """
  
  def analyze_legacy_codebase(app_path) do
    %{
      modules: extract_modules(app_path),
      dependencies: analyze_dependencies(app_path),
      database_schemas: extract_schemas(app_path),
      api_endpoints: extract_endpoints(app_path),
      business_logic: identify_business_logic(app_path),
      technical_debt: assess_technical_debt(app_path),
      test_coverage: analyze_test_coverage(app_path),
      performance_hotspots: identify_performance_issues(app_path)
    }
  end
  
  # Implementation details from strategy document...
end
```

**Actions:**
- [ ] Create the analyzer module with AST parsing capabilities
- [ ] Implement module extraction and dependency analysis
- [ ] Add schema detection for Ecto models
- [ ] Include endpoint discovery for Phoenix controllers
- [ ] Generate complexity metrics

### 1.2 Analyze Legacy Applications

**Prismatic-Legacy Analysis:**
```bash
# Run analysis on legacy application
mix consolidation.analyze --app ../prismatic-legacy --output analysis/legacy_report.json
```

**Prismatic-Old Analysis:**
```bash
# Run analysis on old application  
mix consolidation.analyze --app ../prismatic-old --output analysis/old_report.json
```

**Current Application Analysis:**
```bash
# Run analysis on current umbrella
mix consolidation.analyze --app . --output analysis/current_report.json
```

### 1.3 Generate Dependency Conflict Matrix

Create `analysis/dependency_conflicts.md` with:
- Version conflicts across applications
- Incompatible dependencies
- Resolution strategies
- Migration priorities

### 1.4 Document Database Schemas

**Output:** `analysis/schema_analysis.md`
- Table inventories from each application
- Column conflicts and type mismatches
- Foreign key relationships
- Index definitions
- Migration strategies

### 1.5 Create Feature Inventory

**Output:** `analysis/feature_matrix.md`
- Feature comparison across applications
- Functionality gaps
- Consolidation opportunities
- Business logic duplication

## Task 2: Migration Tooling

### 2.1 Code Migration Utilities

**Location**: `lib/consolidation/migration_utils.ex`

```elixir
defmodule PrismaticConsolidation.MigrationUtils do
  @moduledoc """
  Utilities for automated code migration and transformation.
  """
  
  def migrate_module(source_path, target_app, target_context) do
    # Parse source module
    # Transform for target context
    # Generate target module
    # Update references
  end
  
  def resolve_namespace_conflicts(modules) do
    # Detect naming conflicts
    # Generate resolution strategies
    # Apply namespace transformations
  end
end
```

### 2.2 Database Schema Tooling

**Location**: `lib/consolidation/schema_merger.ex`

```elixir
defmodule PrismaticConsolidation.SchemaMerger do
  @moduledoc """
  Tools for analyzing and merging database schemas.
  """
  
  def compare_schemas(schema_a, schema_b) do
    # Compare table structures
    # Identify conflicts
    # Generate merge strategy
  end
  
  def generate_consolidated_migration(schemas) do
    # Create unified migration
    # Handle data preservation
    # Include rollback strategy
  end
end
```

### 2.3 Dependency Resolution Framework

**Location**: `lib/consolidation/dependency_resolver.ex`

```elixir
defmodule PrismaticConsolidation.DependencyResolver do
  @moduledoc """
  Automated dependency conflict resolution.
  """
  
  def resolve_conflicts(dependency_analysis) do
    # Find compatible versions
    # Generate update strategies
    # Create migration plan
  end
end
```

### 2.4 Testing Framework

**Location**: `test/consolidation/migration_test.exs`

```elixir
defmodule PrismaticConsolidation.MigrationTest do
  use ExUnit.Case
  
  describe "module migration" do
    test "preserves functionality after migration" do
      # Test business logic preservation
      # Verify API compatibility  
      # Check performance metrics
    end
  end
end
```

## Task 3: Development Environment Enhancement

### 3.1 Umbrella Structure Updates

**Target Structure:**
```
apps/
├── prismatic_core/          # Core business logic
├── prismatic_web/           # Web interface (existing)
├── prismatic_auth/          # Authentication & authorization
├── prismatic_data/          # Data access & persistence
├── prismatic_monitoring/    # Observability & operations
└── prismatic_distributed/   # Distributed systems (future)
```

### 3.2 Unified Dependency Management

**Update root `mix.exs`:**
```elixir
defp deps do
  [
    # Core Phoenix dependencies
    {:phoenix, "~> 1.8.0"},
    {:ecto, "~> 3.11"},
    {:jason, "~> 1.4"},
    
    # Consolidated AI/ML dependencies
    {:openai_ex, "~> 0.9.0"},
    {:nx, "~> 0.9.0"},
    {:bumblebee, "~> 0.6.0"},
    
    # Add new dependencies from strategy...
  ]
end
```

### 3.3 Development Tooling Configuration

**Enhanced `.credo.exs`:**
```elixir
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "lib/",
          "apps/*/lib/",
          "test/",
          "apps/*/test/"
        ]
      },
      checks: [
        # Consolidation-specific checks
        {Credo.Check.Design.AliasUsage, [max_aliases: 3]},
        {Credo.Check.Readability.ModuleDoc, []},
        # Add umbrella-specific rules...
      ]
    }
  ]
}
```

### 3.4 Migration Documentation Templates

**Create:** `docs/consolidation/templates/`
- `migration_checklist.md`
- `module_migration_template.md`
- `testing_template.md`
- `rollback_template.md`

## Deliverables

- [ ] **Legacy Analysis Reports**: Complete analysis of all three applications
- [ ] **Dependency Conflict Matrix**: Identified conflicts with resolution strategies
- [ ] **Feature Inventory**: Comprehensive feature comparison and consolidation plan
- [ ] **Migration Tooling**: Automated tools for code and schema migration
- [ ] **Enhanced Development Environment**: Updated umbrella structure with tooling
- [ ] **Documentation Framework**: Templates and guidelines for migration process

## Success Criteria

- [ ] 100% legacy code analyzed and cataloged
- [ ] All dependency conflicts identified with resolution planned
- [ ] Migration tooling passes validation tests
- [ ] Development environment supports parallel migration work
- [ ] Documentation framework established for team collaboration

## Next Steps

Upon completion of Phase 1:
1. Review analysis results with stakeholders
2. Prioritize migration order based on dependency analysis
3. Begin Phase 2: Core Infrastructure Migration
4. Start parallel development using established tooling

## Risk Mitigation

- **Analysis Accuracy**: Validate automated analysis with manual review
- **Tool Reliability**: Test migration utilities on sample modules first
- **Timeline Risk**: Focus on critical path analysis first
- **Complexity Management**: Break down complex modules into smaller tasks

## Resources

- [Enterprise Consolidation Strategy](../../ENTERPRISE_CONSOLIDATION_STRATEGY.md)
- [Architecture Analysis](../architecture/README.md)
- [Phase 2 Implementation Guide](phase-2-core-infrastructure.md)