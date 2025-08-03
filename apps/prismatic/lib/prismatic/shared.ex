defmodule Prismatic.Shared do
  @moduledoc """
  Shared utilities and common functionality for the Prismatic ecosystem.

  This module serves as the entry point for all shared functionality including
  scope resolution, documentation validation, navigation generation, and common
  patterns used throughout the Prismatic umbrella application.

  ## Documentation References

  - **Guide**: [`@/docs/guides/shared/README.md`](../../docs/guides/shared/README.md)
  - **API**: [`@/docs/api/shared/README.md`](../../docs/api/shared/README.md)
  - **Tests**: [`@/test/prismatic/shared/`](../../test/prismatic/shared/)
  - **Navigation**: [`@/docs/guides/documentation/documentation-navigation-implementation.md`](../../docs/guides/documentation/documentation-navigation-implementation.md)

  ## Navigation

  - **Parent**: [`Prismatic`](../prismatic.md)
  - **Children**:
    - [`Prismatic.Shared.ScopeResolver`](./shared/scope_resolver.md)
    - [`Prismatic.Shared.DocumentationValidator`](./shared/documentation_validator.md)
    - [`Prismatic.Shared.NavigationGenerator`](./shared/navigation_generator.md)
    - [`Prismatic.Shared.ScopedTask`](./shared/scoped_task.md)
    - [`Prismatic.Shared.DocumentedTask`](./shared/documented_task.md)
    - [`Prismatic.Shared.ContractValidator`](./shared/contract_validator.md)
    - [`Prismatic.Shared.TelemetryReporter`](./shared/telemetry_reporter.md)
  - **Related**: [`Prismatic.Code`](../code.md), [`Mix.Tasks.Prismatic`](../mix/tasks/prismatic.md)

  ## Design Contracts

  ### Preconditions
  - All shared modules must follow design-by-contract methodology
  - Modules must implement comprehensive error handling
  - All public APIs must have proper type specifications

  ### Postconditions
  - Shared functionality is consistent across all consuming modules
  - Error handling follows enterprise-grade patterns
  - Performance characteristics are documented and benchmarked

  ### Invariants
  - Shared modules maintain zero dependencies on domain-specific logic
  - All functionality is thoroughly tested with property-based testing
  - Documentation is automatically validated for consistency
  """

  @doc """
  Returns version information for the shared module ecosystem.
  """
  @spec version() :: String.t()
  def version, do: "1.0.0"

  @doc """
  Returns list of all available shared modules with their capabilities.
  """
  @spec modules() :: [module_info()]
  def modules do
    [
      %{
        module: Prismatic.Shared.ScopeResolver,
        capability: :scope_resolution,
        description: "Comprehensive scope resolution for Mix tasks"
      },
      %{
        module: Prismatic.Shared.DocumentationValidator,
        capability: :documentation_validation,
        description: "Validates bidirectional documentation linking"
      },
      %{
        module: Prismatic.Shared.NavigationGenerator,
        capability: :navigation_generation,
        description: "Generates navigation links and cross-references"
      },
      %{
        module: Prismatic.Shared.ScopedTask,
        capability: :scoped_task_behaviour,
        description: "Provides scope support for Mix tasks"
      },
      %{
        module: Prismatic.Shared.DocumentedTask,
        capability: :documented_task_behaviour,
        description: "Provides documentation integration for Mix tasks"
      },
      %{
        module: Prismatic.Shared.ContractValidator,
        capability: :design_by_contract,
        description: "Validates preconditions, postconditions, and invariants"
      },
      %{
        module: Prismatic.Shared.TelemetryReporter,
        capability: :telemetry_reporting,
        description: "Structured logging with correlation IDs and metrics"
      }
    ]
  end

  @type module_info :: %{
    module: module(),
    capability: atom(),
    description: String.t()
  }

  @doc """
  Validates that all shared modules are properly loaded and functional.
  """
  @spec health_check() :: {:ok, :healthy} | {:error, [module_error()]}
  def health_check do
    modules()
    |> Enum.map(&check_module_health/1)
    |> Enum.reject(&match?({:ok, _}, &1))
    |> case do
      [] -> {:ok, :healthy}
      errors -> {:error, errors}
    end
  end

  @type module_error :: %{
    module: module(),
    error: term()
  }

  defp check_module_health(%{module: module}) do
    try do
      Code.ensure_loaded!(module)
      {:ok, module}
    rescue
      error -> %{module: module, error: error}
    end
  end
end
