# Documentation Navigation Implementation

## Overview

This document establishes the standardized navigation patterns and bidirectional linking strategy for the Prismatic ecosystem, ensuring seamless integration between code modules and their corresponding documentation.

## Core Principles

### 1. Bidirectional Documentation Linking

Every module must maintain explicit references to its documentation:

```elixir
defmodule YourModule do
  @moduledoc """
  Brief module description.
  
  ## Documentation References
  
  - **Guide**: [`@/docs/guides/your-domain/your-module.md`](../../../guides/your-domain/your-module.md)
  - **API**: [`@/docs/api/your-domain/your-module.md`](../../../api/your-domain/your-module.md)
  - **Tests**: [`@/test/your-domain/your-module_test.exs`](../../../test/your-domain/your-module_test.exs)
  - **Examples**: [`@/docs/examples/your-domain/your-module.md`](../../../examples/your-domain/your-module.md)
  
  ## Navigation
  
  - **Parent**: [`YourDomain`](./your-domain.md)
  - **Children**: See individual function documentation
  - **Related**: [`RelatedModule`](./related-module.md)
  """
end
```

### 2. Documentation File Structure

Each module requires corresponding documentation files following this hierarchy:

```
docs/
├── api/
│   └── your-domain/
│       └── your-module.md           # API documentation
├── guides/
│   └── your-domain/
│       └── your-module.md           # Usage guides
├── examples/
│   └── your-domain/
│       └── your-module.md           # Code examples
└── architecture/
    └── your-domain/
        └── your-module.md           # Architectural decisions
```

### 3. Root Module Pattern

Each source directory must contain a primary module that serves as the domain entry point:

```elixir
defmodule YourDomain do
  @moduledoc """
  Domain entry point for YourDomain functionality.
  
  ## Documentation Navigation
  
  This module follows the standardized navigation patterns defined in
  [`@/docs/guides/documentation/documentation-navigation-implementation.md`](../guides/documentation/documentation-navigation-implementation.md).
  
  ## Domain Structure
  
  - [`YourDomain.SubModule1`](./your-domain/sub-module1.md)
  - [`YourDomain.SubModule2`](./your-domain/sub-module2.md)
  - [`YourDomain.SubModule3`](./your-domain/sub-module3.md)
  
  ## Quick Links
  
  - **Domain Guide**: [`@/docs/guides/your-domain/README.md`](../../docs/guides/your-domain/README.md)
  - **API Reference**: [`@/docs/api/your-domain/README.md`](../../docs/api/your-domain/README.md)
  - **Test Suite**: [`@/test/your-domain/`](../../test/your-domain/)
  """
  
  # Domain-level functionality
end
```

## Scope Support Implementation

### File-Level Scopes

Mix tasks must support targeting specific files:

```bash
# Target specific file
mix prismatic.consolidation.analyze --scope=file --target="lib/code/analyzer.ex"

# Target multiple files with glob patterns
mix prismatic.consolidation.analyze --scope=file --target="lib/code/*.ex"

# Target files by modification date
mix prismatic.consolidation.analyze --scope=file --since="2024-01-01"
```

### Module-Name-Specific Scopes

Tasks must support targeting by module name:

```bash
# Target specific module
mix prismatic.consolidation.analyze --scope=module --target="Prismatic.Code.Analyzer"

# Target modules by namespace
mix prismatic.consolidation.analyze --scope=module --target="Prismatic.Code.*"

# Target modules implementing specific behaviour
mix prismatic.consolidation.analyze --scope=module --behaviour="GenServer"
```

### Hierarchical Scopes

Support nested scope combinations:

```bash
# App + module scope
mix prismatic.consolidation.analyze --scope=app:module --target="prismatic_core:Prismatic.Core.*"

# Umbrella + file scope  
mix prismatic.consolidation.analyze --scope=umbrella:file --target="apps/*/lib/**/*.ex"

# Project + dependency scope
mix prismatic.consolidation.analyze --scope=project:deps --target="phoenix:jason:plug"
```

## Implementation Requirements

### 1. Scope Resolution Engine

```elixir
defmodule Prismatic.Shared.ScopeResolver do
  @moduledoc """
  Centralized scope resolution for all Mix tasks.
  
  ## Documentation References
  
  - **Guide**: [`@/docs/guides/shared/scope-resolver.md`](../../docs/guides/shared/scope-resolver.md)
  - **Implementation**: This module
  """
  
  @type scope_type :: :project | :umbrella | :app | :file | :module | :deps
  @type scope_target :: String.t() | [String.t()] | :all
  @type scope_options :: keyword()
  
  @spec resolve_scope(scope_type(), scope_target(), scope_options()) :: 
    {:ok, [String.t()]} | {:error, term()}
  def resolve_scope(type, target, opts \\ [])
end
```

### 2. Documentation Validator

```elixir
defmodule Prismatic.Shared.DocumentationValidator do
  @moduledoc """
  Validates bidirectional documentation linking.
  
  ## Documentation References
  
  - **Guide**: [`@/docs/guides/shared/documentation-validator.md`](../../docs/guides/shared/documentation-validator.md)
  """
  
  @spec validate_module_documentation(module()) :: 
    {:ok, :valid} | {:error, [validation_error()]}
  def validate_module_documentation(module)
end
```

### 3. Navigation Generator

```elixir
defmodule Prismatic.Shared.NavigationGenerator do
  @moduledoc """
  Generates navigation links and documentation cross-references.
  
  ## Documentation References
  
  - **Guide**: [`@/docs/guides/shared/navigation-generator.md`](../../docs/guides/shared/navigation-generator.md)
  """
  
  @spec generate_module_navigation(module(), keyword()) :: String.t()
  def generate_module_navigation(module, opts \\ [])
end
```

## Mix Task Integration

All Mix tasks must integrate scope support through shared behaviours:

```elixir
defmodule Mix.Tasks.Prismatic.YourTask do
  use Mix.Task
  use Prismatic.Shared.ScopedTask  # Provides scope support
  use Prismatic.Shared.DocumentedTask  # Provides documentation integration
  
  @moduledoc """
  Task description.
  
  ## Documentation References
  
  - **Guide**: [`@/docs/guides/mix-tasks/your-task.md`](../../docs/guides/mix-tasks/your-task.md)
  - **Implementation**: This module
  """
  
  @shortdoc "Brief task description"
  
  @impl Mix.Task
  def run(args) do
    with {:ok, scope} <- parse_scope_options(args),
         {:ok, targets} <- resolve_targets(scope) do
      execute_on_targets(targets)
    else
      error -> handle_error(error)
    end
  end
end
```

## Standard Link Patterns

### Internal Documentation Links

- `@/docs/path/to/file.md` - Root-relative documentation path
- `@/lib/path/to/module.ex` - Root-relative source path  
- `@/test/path/to/test.exs` - Root-relative test path

### Cross-Reference Patterns

- `[ModuleName](path/to/docs.md)` - Module documentation link
- `[FunctionName/arity](path/to/docs.md#function-name)` - Function documentation link
- `[TypeName](path/to/docs.md#types)` - Type documentation link

### Navigation Helpers

- **Parent**: Link to containing namespace/domain
- **Children**: Links to sub-modules
- **Related**: Links to functionally related modules
- **Dependencies**: Links to required modules
- **Dependents**: Links to modules that depend on this one

## Validation Rules

1. Every `@moduledoc` must contain documentation references section
2. All documentation links must be valid and accessible
3. Referenced documentation files must exist
4. Cross-references must be bidirectional
5. Navigation structure must be consistent across domains
6. Examples must be tested and up-to-date

## Implementation Checklist

- [ ] Create scope resolution engine
- [ ] Implement documentation validator
- [ ] Build navigation generator
- [ ] Update all existing modules with documentation links
- [ ] Create missing documentation files
- [ ] Implement scope support in all Mix tasks
- [ ] Add comprehensive test coverage
- [ ] Generate architectural decision records (ADRs)
- [ ] Create feature tracking system
- [ ] Implement continuous validation in CI/CD

This standardized approach ensures that developers can navigate seamlessly between code and documentation, understand architectural decisions, and maintain consistency across the entire ecosystem.