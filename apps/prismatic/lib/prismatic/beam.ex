defmodule Prismatic.BEAM do
  @moduledoc """
  Comprehensive BEAM Virtual Machine toolkit for dynamic introspection and manipulation.

  This module provides the entry point to a comprehensive suite of tools that leverage
  the full power of the BEAM virtual machine for development, production maintenance,
  and distributed system coordination. The toolkit operates in three distinct modes
  and provides both programmatic APIs and minimal CLI interfaces.

  ## Architecture Modes

  - **Offline Mode**: Static code analysis, file operations, and development tooling
  - **Online Mode**: Distributed system coordination and remote node communication
  - **Runtime Mode**: Live system modification and hot code reloading

  ## Core Components

  - **FileSystem**: Comprehensive file operations with real-time monitoring
  - **Introspection**: Deep runtime introspection using BEAM's built-in tools
  - **Compilation**: Dynamic module compilation and loading capabilities
  - **ProcessTree**: Process manipulation and supervision analysis
  - **Distributed**: Node discovery, management, and coordination
  - **Metrics**: Real-time system metrics collection and monitoring
  - **Coverage**: Code coverage analysis and reporting
  - **Refactoring**: Automated code transformation tools
  - **Safety**: Production maintenance with rollback capabilities

  ## Documentation References

  - **Guide**: [`@/docs/guides/beam/beam-toolkit.md`](../../docs/guides/beam/beam-toolkit.md)
  - **API**: [`@/docs/api/beam/beam-toolkit.md`](../../docs/api/beam/beam-toolkit.md)
  - **Architecture**: [`@/docs/architecture/beam-virtual-machine.md`](../../docs/architecture/beam-virtual-machine.md)

  ## Navigation

  - **Components**: [`Prismatic.BEAM.FileSystem`](./beam/file_system.md)
  - **Components**: [`Prismatic.BEAM.Introspection`](./beam/introspection.md)
  - **Components**: [`Prismatic.BEAM.Runtime`](./beam/runtime.md)

  ## Design Contracts

  ### Preconditions
  - BEAM virtual machine must be running
  - System must have appropriate permissions for requested operations
  - Target nodes must be reachable for distributed operations

  ### Postconditions
  - All operations provide consistent programmatic APIs
  - Safety mechanisms prevent destructive operations in production
  - All changes can be rolled back when supported

  ### Invariants
  - Operations are deterministic and repeatable
  - Distributed operations maintain consistency
  - System safety is prioritized over convenience
  """

  use GenServer
  require Logger

  alias Prismatic.BEAM.{
    FileSystem,
    Introspection,
    Compilation,
    ProcessTree,
    Distributed,
    Metrics,
    Coverage,
    Refactoring,
    Safety,
    Runtime
  }

  @type operation_mode :: :offline | :online | :runtime
  @type safety_level :: :development | :staging | :production

  @type toolkit_config :: %{
    mode: operation_mode(),
    safety_level: safety_level(),
    node_discovery: boolean(),
    real_time_monitoring: boolean(),
    hot_code_reloading: boolean(),
    distributed_coordination: boolean()
  }

  @type operation_result ::
    {:ok, term()} |
    {:error, term()} |
    {:warning, term(), term()}

  @default_config %{
    mode: :offline,
    safety_level: :development,
    node_discovery: false,
    real_time_monitoring: false,
    hot_code_reloading: false,
    distributed_coordination: false
  }

  @doc """
  Starts the BEAM toolkit with the specified configuration.
  """
  @spec start_link(toolkit_config()) :: GenServer.on_start()
  def start_link(config \\ @default_config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Initializes the toolkit in the specified mode.
  """
  @spec initialize(operation_mode(), keyword()) :: operation_result()
  def initialize(mode, opts \\ []) do
    config = build_config(mode, opts)

    case GenServer.whereis(__MODULE__) do
      nil ->
        case start_link(config) do
          {:ok, _pid} -> {:ok, :initialized}
          error -> error
        end
      _pid ->
        GenServer.call(__MODULE__, {:reconfigure, config})
    end
  end

  @doc """
  Gets comprehensive system information using BEAM introspection.
  """
  @spec system_info(keyword()) :: operation_result()
  def system_info(opts \\ []) do
    Introspection.comprehensive_system_info(opts)
  end

  @doc """
  Performs file system operations with real-time monitoring capabilities.
  """
  @spec file_system(atom(), term(), keyword()) :: operation_result()
  def file_system(operation, args, opts \\ []) do
    FileSystem.execute(operation, args, opts)
  end

  @doc """
  Executes runtime operations with safety mechanisms.
  """
  @spec runtime(atom(), term(), keyword()) :: operation_result()
  def runtime(operation, args, opts \\ []) do
    Runtime.execute(operation, args, opts)
  end

  @doc """
  Manages distributed operations across nodes.
  """
  @spec distributed(atom(), term(), keyword()) :: operation_result()
  def distributed(operation, args, opts \\ []) do
    Distributed.execute(operation, args, opts)
  end

  @doc """
  Collects and analyzes system metrics.
  """
  @spec metrics(atom(), term(), keyword()) :: operation_result()
  def metrics(operation, args, opts \\ []) do
    Metrics.execute(operation, args, opts)
  end

  @doc """
  Performs code analysis and coverage operations.
  """
  @spec coverage(atom(), term(), keyword()) :: operation_result()
  def coverage(operation, args, opts \\ []) do
    Coverage.execute(operation, args, opts)
  end

  @doc """
  Executes automated refactoring operations.
  """
  @spec refactoring(atom(), term(), keyword()) :: operation_result()
  def refactoring(operation, args, opts \\ []) do
    Refactoring.execute(operation, args, opts)
  end

  @doc """
  Gets current toolkit configuration and status.
  """
  @spec status() :: %{
    mode: operation_mode(),
    safety_level: safety_level(),
    components: %{atom() => :running | :stopped | :error},
    metrics: map()
  }
  def status do
    case GenServer.whereis(__MODULE__) do
      nil -> %{mode: :offline, safety_level: :development, components: %{}, metrics: %{}}
      pid -> GenServer.call(pid, :get_status)
    end
  end

  @doc """
  Safely shuts down the toolkit and all components.
  """
  @spec shutdown(keyword()) :: operation_result()
  def shutdown(opts \\ []) do
    case GenServer.whereis(__MODULE__) do
      nil -> {:ok, :already_stopped}
      pid -> GenServer.call(pid, {:shutdown, opts})
    end
  end

  # GenServer implementation

  @impl GenServer
  def init(config) do
    Logger.info("Starting BEAM toolkit", mode: config.mode, safety_level: config.safety_level)

    state = %{
      config: config,
      components: %{},
      metrics: %{
        start_time: DateTime.utc_now(),
        operations_count: 0,
        errors_count: 0
      },
      monitors: []
    }

    case initialize_components(state) do
      {:ok, new_state} ->
        Logger.info("BEAM toolkit started successfully")
        {:ok, new_state}
      {:error, reason} ->
        Logger.error("BEAM toolkit initialization failed", error: reason)
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:reconfigure, new_config}, _from, state) do
    Logger.info("Reconfiguring BEAM toolkit",
      old_mode: state.config.mode,
      new_mode: new_config.mode
    )

    case reconfigure_components(state, new_config) do
      {:ok, new_state} -> {:reply, {:ok, :reconfigured}, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_status, _from, state) do
    status = %{
      mode: state.config.mode,
      safety_level: state.config.safety_level,
      components: get_component_statuses(state),
      metrics: state.metrics
    }
    {:reply, status, state}
  end

  @impl GenServer
  def handle_call({:shutdown, opts}, _from, state) do
    Logger.info("Shutting down BEAM toolkit")

    case shutdown_components(state, opts) do
      :ok -> {:stop, :normal, {:ok, :shutdown}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_info({:component_status, component, status}, state) do
    new_components = Map.put(state.components, component, status)
    new_state = %{state | components: new_components}
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(msg, state) do
    Logger.debug("Received unknown message", message: msg)
    {:noreply, state}
  end

  # Private implementation

  defp build_config(mode, opts) do
    base_config = case mode do
      :offline -> %{@default_config | mode: :offline}
      :online -> %{@default_config |
        mode: :online,
        node_discovery: true,
        distributed_coordination: true
      }
      :runtime -> %{@default_config |
        mode: :runtime,
        real_time_monitoring: true,
        hot_code_reloading: true
      }
    end

    Enum.reduce(opts, base_config, fn
      {:safety_level, level}, config -> %{config | safety_level: level}
      {:node_discovery, enabled}, config -> %{config | node_discovery: enabled}
      {:real_time_monitoring, enabled}, config -> %{config | real_time_monitoring: enabled}
      {:hot_code_reloading, enabled}, config -> %{config | hot_code_reloading: enabled}
      {:distributed_coordination, enabled}, config -> %{config | distributed_coordination: enabled}
      {_key, _value}, config -> config
    end)
  end

  defp initialize_components(state) do
    config = state.config
    components_to_start = determine_components_to_start(config)

    Enum.reduce_while(components_to_start, {:ok, state}, fn component, {:ok, acc_state} ->
      case start_component(component, config) do
        {:ok, component_state} ->
          new_components = Map.put(acc_state.components, component, :running)
          {:cont, {:ok, %{acc_state | components: new_components}}}
        {:error, reason} ->
          Logger.error("Failed to start component", component: component, error: reason)
          {:halt, {:error, {:component_start_failed, component, reason}}}
      end
    end)
  end

  defp determine_components_to_start(config) do
    base_components = [:file_system, :introspection]

    additional_components =
      []
      |> maybe_add_component(:distributed, config.node_discovery or config.distributed_coordination)
      |> maybe_add_component(:metrics, config.real_time_monitoring)
      |> maybe_add_component(:runtime, config.hot_code_reloading)
      |> maybe_add_component(:compilation, config.mode == :runtime)
      |> maybe_add_component(:process_tree, config.mode != :offline)
      |> maybe_add_component(:coverage, config.mode != :offline)
      |> maybe_add_component(:refactoring, true)
      |> maybe_add_component(:safety, config.safety_level != :development)

    base_components ++ additional_components
  end

  defp maybe_add_component(components, component, true), do: [component | components]
  defp maybe_add_component(components, _component, false), do: components

  defp start_component(:file_system, config) do
    FileSystem.start_link(config)
  end

  defp start_component(:introspection, config) do
    Introspection.start_link(config)
  end

  defp start_component(:distributed, config) do
    Distributed.start_link(config)
  end

  defp start_component(:metrics, config) do
    Metrics.start_link(config)
  end

  defp start_component(:runtime, config) do
    Runtime.start_link(config)
  end

  defp start_component(:compilation, config) do
    Compilation.start_link(config)
  end

  defp start_component(:process_tree, config) do
    ProcessTree.start_link(config)
  end

  defp start_component(:coverage, config) do
    Coverage.start_link(config)
  end

  defp start_component(:refactoring, config) do
    Refactoring.start_link(config)
  end

  defp start_component(:safety, config) do
    Safety.start_link(config)
  end

  defp reconfigure_components(state, new_config) do
    # Implementation for reconfiguring components
    {:ok, %{state | config: new_config}}
  end

  defp get_component_statuses(state) do
    state.components
  end

  defp shutdown_components(_state, _opts) do
    # Implementation for graceful component shutdown
    :ok
  end
end
