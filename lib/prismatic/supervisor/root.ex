defmodule Prismatic.Supervisor.Root do
  @moduledoc """
  Root supervisor for the Prismatic system.

  This supervisor manages the top-level supervision tree for the entire
  Prismatic application. It provides fault isolation and recovery for
  all major system components through a hierarchical supervision strategy.

  ## Status

  🚧 **PLACEHOLDER - PLANNED IMPLEMENTATION**

  This file is a placeholder created to resolve documentation links.
  The actual implementation is planned for Phase 1 of the Prismatic
  architecture development (see docs/architecture/README.md).

  ## Supervision Tree Structure

  ```
  Prismatic.Supervisor.Root
  ├── Prismatic.Supervisor.Infrastructure
  ├── Prismatic.Supervisor.Data
  ├── Prismatic.Supervisor.Core
  │   ├── Prismatic.EventBus
  │   ├── Prismatic.Agent.Supervisor (Dynamic)
  │   ├── Prismatic.Society.Supervisor (Dynamic)
  │   └── Prismatic.Blackboard.Supervisor
  └── PrismaticWeb.Endpoint
  ```

  ## Supervision Strategy

  - **Strategy**: `:one_for_one`
  - **Restart**: `:permanent` for core services, `:transient` for dynamic components
  - **Shutdown**: Graceful shutdown with configurable timeouts
  - **Max Restarts**: 3 restarts in 5 seconds before escalation

  ## Implementation Notes

  When implementing this supervisor, ensure:
  - Proper child specification for all supervised processes
  - Graceful shutdown handling for all components
  - Health checks and monitoring integration
  - Configuration-driven supervision parameters
  - Proper error logging and alerting

  ## See Also

  - `docs/architecture/bulletproof-foundations.md` - Supervision architecture
  - `docs/architecture/bulletproof-foundations-part2.md` - Advanced supervision patterns
  """

  use Supervisor

  require Logger

  @doc """
  Start the root supervisor.

  ## Parameters

  - `init_arg` - Initialization arguments (typically empty list)

  ## Returns

  - `{:ok, pid}` - Supervisor started successfully
  - `{:error, reason}` - Failed to start supervisor
  """
  @spec start_link(term()) :: Supervisor.on_start()
  def start_link(init_arg) do
    Logger.info("Starting Prismatic Root Supervisor")
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @doc """
  Initialize the supervision tree.

  ## Parameters

  - `_init_arg` - Initialization arguments (unused)

  ## Returns

  Supervisor specification with child processes.
  """
  @impl true
  def init(_init_arg) do
    Logger.info("Initializing Prismatic supervision tree")

    children = [
      # Infrastructure layer - databases, caches, external connections
      {Prismatic.Supervisor.Infrastructure, []},

      # Data layer - repositories, data access
      {Prismatic.Supervisor.Data, []},

      # Core business logic layer
      {Prismatic.Supervisor.Core, []},

      # Web interface layer
      {PrismaticWeb.Endpoint, []}
    ]

    opts = [
      strategy: :one_for_one,
      max_restarts: 3,
      max_seconds: 5,
      name: __MODULE__
    ]

    Logger.info("Root supervisor initialized with #{length(children)} child supervisors")
    Supervisor.init(children, opts)
  end

  @doc """
  Get the current supervision tree status.

  ## Returns

  Map containing supervisor and child process information.
  """
  @spec get_status() :: map()
  def get_status do
    case Process.whereis(__MODULE__) do
      nil ->
        %{status: :not_running, children: []}

      pid ->
        children = Supervisor.which_children(__MODULE__)
        count_by_status =
          children
          |> Enum.group_by(fn {_id, _pid, _type, status} -> status end)
          |> Enum.map(fn {status, list} -> {status, length(list)} end)
          |> Map.new()

        %{
          status: :running,
          pid: pid,
          children_count: length(children),
          children_by_status: count_by_status,
          children: children
        }
    end
  end

  @doc """
  Gracefully shutdown the entire system.

  ## Parameters

  - `timeout` - Maximum time to wait for shutdown (default: 30 seconds)

  ## Returns

  - `:ok` - System shutdown successfully
  - `{:error, reason}` - Shutdown failed or timed out
  """
  @spec graceful_shutdown(timeout()) :: :ok | {:error, term()}
  def graceful_shutdown(timeout \\ 30_000) do
    Logger.info("Initiating graceful shutdown of Prismatic system")

    case Process.whereis(__MODULE__) do
      nil ->
        Logger.info("System already stopped")
        :ok

      pid ->
        # Send shutdown signal and wait for completion
        Process.exit(pid, :shutdown)

        # Wait for the supervisor to terminate
        ref = Process.monitor(pid)

        receive do
          {:DOWN, ^ref, :process, ^pid, _reason} ->
            Logger.info("Prismatic system shutdown completed")
            :ok
        after
          timeout ->
            Logger.error("Graceful shutdown timed out after #{timeout}ms")
            {:error, :shutdown_timeout}
        end
    end
  end
end
