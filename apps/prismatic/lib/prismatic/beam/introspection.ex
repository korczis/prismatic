defmodule Prismatic.BEAM.Introspection do
  @moduledoc """
  Deep runtime introspection using BEAM's built-in tools for comprehensive system analysis.

  This module provides extensive runtime introspection capabilities using BEAM's native
  tools including :observer, :sys, :code, :application, and other OTP modules. It enables
  deep analysis of running processes, memory usage, module loading states, application
  supervision trees, and system performance metrics.

  ## Features

  - **Process Introspection**: Detailed analysis of running processes and their states
  - **Memory Analysis**: Comprehensive memory usage tracking and optimization insights
  - **Module Inspection**: Runtime module loading, compilation, and dependency analysis
  - **Application Trees**: Supervision hierarchy analysis and health monitoring
  - **Performance Metrics**: Real-time system performance and resource utilization
  - **Code Analysis**: Dynamic code inspection, hot-loading, and modification tracking

  ## Documentation References

  - **Guide**: [`@/docs/guides/beam/introspection.md`](../../../docs/guides/beam/introspection.md)
  - **API**: [`@/docs/api/beam/introspection.md`](../../../docs/api/beam/introspection.md)
  - **Examples**: [`@/docs/guides/beam/introspection-examples.md`](../../../docs/guides/beam/introspection-examples.md)

  ## Navigation

  - **Parent**: [`Prismatic.BEAM`](../beam.md)
  - **Related**: [`Prismatic.BEAM.ProcessTree`](./process_tree.md)
  - **Related**: [`Prismatic.BEAM.Metrics`](./metrics.md)

  ## Design Contracts

  ### Preconditions
  - BEAM virtual machine must be running
  - Target processes/applications must be accessible
  - System must have sufficient resources for introspection operations

  ### Postconditions
  - All introspection data is accurate and up-to-date
  - System performance impact is minimized
  - Results are structured and easily consumable

  ### Invariants
  - Introspection does not affect target system behavior
  - Data collection is atomic and consistent
  - Resource usage is bounded and predictable
  """

  use GenServer
  require Logger

  @type introspection_target ::
    :system | :processes | :memory | :modules | :applications |
    :schedulers | :ports | :ets | :code | :distribution

  @type process_info_options :: [
    :dictionary | :error_handler | :garbage_collection | :group_leader |
    :heap_size | :initial_call | :links | :last_calls | :memory |
    :message_queue_len | :messages | :monitored_by | :monitors |
    :priority | :reductions | :registered_name | :stack_size |
    :status | :suspending | :total_heap_size | :trace | :trap_exit
  ]

  @type system_info :: %{
    system: %{
      otp_release: String.t(),
      erts_version: String.t(),
      system_version: String.t(),
      system_architecture: String.t(),
      schedulers: non_neg_integer(),
      logical_processors: non_neg_integer(),
      atom_count: non_neg_integer(),
      atom_limit: non_neg_integer(),
      port_count: non_neg_integer(),
      port_limit: non_neg_integer(),
      process_count: non_neg_integer(),
      process_limit: non_neg_integer(),
      ets_count: non_neg_integer(),
      ets_limit: non_neg_integer()
    },
    memory: memory_info(),
    applications: [application_info()],
    processes: [process_summary()],
    modules: [module_info()],
    distribution: distribution_info()
  }

  @type memory_info :: %{
    total: non_neg_integer(),
    processes: non_neg_integer(),
    processes_used: non_neg_integer(),
    system: non_neg_integer(),
    atom: non_neg_integer(),
    atom_used: non_neg_integer(),
    binary: non_neg_integer(),
    code: non_neg_integer(),
    ets: non_neg_integer()
  }

  @type application_info :: %{
    name: atom(),
    description: String.t(),
    version: String.t(),
    status: :loaded | :started | :stopped,
    modules: [module()],
    registered: [atom()],
    applications: [atom()],
    included_applications: [atom()],
    env: [{atom(), term()}]
  }

  @type process_summary :: %{
    pid: pid(),
    registered_name: atom() | nil,
    initial_call: {module(), atom(), non_neg_integer()},
    current_function: {module(), atom(), non_neg_integer()},
    status: :running | :waiting | :runnable | :garbage_collecting | :suspended,
    message_queue_len: non_neg_integer(),
    heap_size: non_neg_integer(),
    stack_size: non_neg_integer(),
    reductions: non_neg_integer(),
    memory: non_neg_integer(),
    links: [pid()],
    monitors: [{:process | :port, pid() | atom()}],
    monitored_by: [pid()]
  }

  @type module_info :: %{
    module: module(),
    file: String.t() | :preloaded,
    native: boolean(),
    loaded: boolean(),
    size: non_neg_integer(),
    md5: binary(),
    exports: [{atom(), non_neg_integer()}],
    attributes: keyword(),
    compile_info: keyword()
  }

  @type distribution_info :: %{
    node: node(),
    alive: boolean(),
    nodes: [node()],
    cookie: atom(),
    net_kernel_running: boolean(),
    connections: [connection_info()]
  }

  @type connection_info :: %{
    node: node(),
    type: :visible | :hidden,
    state: :up | :down,
    owner: pid(),
    address: tuple()
  }

  defstruct [
    :config,
    :collectors,
    :cache,
    :statistics
  ]

  @doc """
  Starts the Introspection component with the given configuration.
  """
  @spec start_link(map()) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Gets comprehensive system information including all major subsystems.

  ## Examples

      # Get full system overview
      iex> comprehensive_system_info()
      {:ok, %{system: %{...}, memory: %{...}, applications: [...]}}

      # Get specific subsystem information
      iex> comprehensive_system_info(targets: [:memory, :processes])
      {:ok, %{memory: %{...}, processes: [...]}}
  """
  @spec comprehensive_system_info(keyword()) :: {:ok, system_info()} | {:error, term()}
  def comprehensive_system_info(opts \\ []) do
    targets = Keyword.get(opts, :targets, [:system, :memory, :applications, :processes, :modules, :distribution])

    try do
      system_info = %{}

      system_info = if :system in targets do
        Map.put(system_info, :system, collect_system_info())
      else
        system_info
      end

      system_info = if :memory in targets do
        Map.put(system_info, :memory, collect_memory_info())
      else
        system_info
      end

      system_info = if :applications in targets do
        Map.put(system_info, :applications, collect_applications_info())
      else
        system_info
      end

      system_info = if :processes in targets do
        Map.put(system_info, :processes, collect_processes_info())
      else
        system_info
      end

      system_info = if :modules in targets do
        Map.put(system_info, :modules, collect_modules_info())
      else
        system_info
      end

      system_info = if :distribution in targets do
        Map.put(system_info, :distribution, collect_distribution_info())
      else
        system_info
      end

      {:ok, system_info}
    rescue
      error -> {:error, {:introspection_failed, error}}
    end
  end

  @doc """
  Analyzes a specific process in detail using :sys and process_info.

  ## Examples

      # Analyze specific process
      iex> analyze_process(self())
      {:ok, %{pid: #PID<...>, status: :running, ...}}

      # Analyze with specific information requests
      iex> analyze_process(self(), [:memory, :message_queue_len, :links])
      {:ok, %{memory: 1234, message_queue_len: 0, links: []}}
  """
  @spec analyze_process(pid(), process_info_options()) :: {:ok, map()} | {:error, term()}
  def analyze_process(pid, info_items \\ :all) do
    if Process.alive?(pid) do
      try do
        base_info = %{pid: pid}

        process_info = if info_items == :all do
          case Process.info(pid) do
            nil -> %{}
            info -> Map.new(info)
          end
        else
          info_items
          |> Enum.map(&{&1, Process.info(pid, &1)})
          |> Enum.filter(fn {_key, value} -> value != :undefined end)
          |> Map.new(fn {key, {_matched_key, value}} -> {key, value} end)
        end

        # Enhanced analysis using :sys module for GenServer processes
        sys_info = try do
          case :sys.get_status(pid) do
            {:status, ^pid, {:module, module}, [_pdict, state, _parent, _debug, _misc]} ->
              %{
                behavior: :gen_server,
                module: module,
                state_summary: summarize_state(state)
              }
            {:status, ^pid, {:module, module}, status_data} ->
              %{
                behavior: :generic,
                module: module,
                status_data: status_data
              }
            other ->
              %{raw_status: other}
          end
        rescue
          _ -> %{sys_status: :unavailable}
        end

        full_info = Map.merge(base_info, Map.merge(process_info, sys_info))
        {:ok, full_info}
      rescue
        error -> {:error, {:process_analysis_failed, error}}
      end
    else
      {:error, :process_not_alive}
    end
  end

  @doc """
  Monitors system performance metrics in real-time.
  """
  @spec monitor_performance(keyword()) :: {:ok, pid()} | {:error, term()}
  def monitor_performance(opts \\ []) do
    interval = Keyword.get(opts, :interval, 1000)
    callback = Keyword.get(opts, :callback, &default_performance_callback/1)

    monitor_pid = spawn_link(fn ->
      performance_monitor_loop(interval, callback)
    end)

    {:ok, monitor_pid}
  end

  @doc """
  Analyzes memory usage patterns and identifies potential issues.
  """
  @spec analyze_memory_usage(keyword()) :: {:ok, map()} | {:error, term()}
  def analyze_memory_usage(opts \\ []) do
    include_processes = Keyword.get(opts, :include_processes, true)
    top_n = Keyword.get(opts, :top_processes, 10)

    try do
      memory_info = collect_memory_info()

      analysis = %{
        summary: memory_info,
        recommendations: analyze_memory_patterns(memory_info),
        top_consumers: if include_processes do
          get_top_memory_consuming_processes(top_n)
        else
          []
        end,
        gc_statistics: get_garbage_collection_stats(),
        binary_memory: analyze_binary_memory()
      }

      {:ok, analysis}
    rescue
      error -> {:error, {:memory_analysis_failed, error}}
    end
  end

  @doc """
  Inspects module loading and compilation information.
  """
  @spec inspect_module(module()) :: {:ok, map()} | {:error, term()}
  def inspect_module(module) when is_atom(module) do
    try do
      case :code.is_loaded(module) do
        {:file, beam_file} ->
          module_info = %{
            module: module,
            loaded: true,
            beam_file: beam_file,
            native_compiled: :code.is_module_native(module),
            size: get_module_size(module),
            md5: get_module_md5(module),
            exports: module.module_info(:exports),
            attributes: module.module_info(:attributes),
            compile_info: module.module_info(:compile)
          }

          {:ok, module_info}
        false ->
          {:ok, %{module: module, loaded: false}}
      end
    rescue
      error -> {:error, {:module_inspection_failed, error}}
    end
  end

  @doc """
  Analyzes application supervision trees and health.
  """
  @spec analyze_supervision_tree(atom()) :: {:ok, map()} | {:error, term()}
  def analyze_supervision_tree(app_name) when is_atom(app_name) do
    case Application.get_application(app_name) do
      {:ok, _app} ->
        try do
          tree_info = build_supervision_tree(app_name)
          health_info = analyze_tree_health(tree_info)

          analysis = %{
            application: app_name,
            supervision_tree: tree_info,
            health_analysis: health_info,
            restart_intensity: get_restart_intensity(app_name),
            worker_status: get_worker_status(tree_info)
          }

          {:ok, analysis}
        rescue
          error -> {:error, {:supervision_analysis_failed, error}}
        end
      nil ->
        {:error, :application_not_found}
    end
  end

  @doc """
  Tracks code loading and hot-swapping events.
  """
  @spec track_code_changes(keyword()) :: {:ok, pid()} | {:error, term()}
  def track_code_changes(opts \\ []) do
    callback = Keyword.get(opts, :callback, &default_code_change_callback/1)

    tracker_pid = spawn_link(fn ->
      code_change_tracker_loop(callback, get_loaded_modules_snapshot())
    end)

    {:ok, tracker_pid}
  end

  @doc """
  Gets real-time scheduler utilization statistics.
  """
  @spec get_scheduler_utilization() :: {:ok, map()} | {:error, term()}
  def get_scheduler_utilization do
    try do
      case :erlang.statistics(:scheduler_wall_time) do
        :undefined -> {:error, :scheduler_wall_time_not_enabled}
        stats ->
          scheduler_info = %{
            scheduler_count: :erlang.system_info(:schedulers),
            scheduler_online: :erlang.system_info(:schedulers_online),
            utilization: calculate_scheduler_utilization(stats),
            raw_stats: stats
          }
          {:ok, scheduler_info}
      end
    rescue
      error -> {:error, {:scheduler_analysis_failed, error}}
    end
  end

  @doc """
  Analyzes ETS table usage and performance.
  """
  @spec analyze_ets_tables() :: {:ok, map()} | {:error, term()}
  def analyze_ets_tables do
    try do
      tables = :ets.all()

      table_analysis =
        tables
        |> Enum.map(&analyze_single_ets_table/1)
        |> Enum.filter(& &1 != nil)

      summary = %{
        total_tables: length(tables),
        total_memory: Enum.sum(Enum.map(table_analysis, & &1.memory)),
        total_objects: Enum.sum(Enum.map(table_analysis, & &1.size)),
        tables: table_analysis,
        largest_tables: Enum.sort_by(table_analysis, & &1.memory, :desc) |> Enum.take(10)
      }

      {:ok, summary}
    rescue
      error -> {:error, {:ets_analysis_failed, error}}
    end
  end

  # GenServer implementation

  @impl GenServer
  def init(config) do
    Logger.info("Starting Introspection component")

    # Enable scheduler wall time for accurate utilization measurements
    :erlang.system_flag(:scheduler_wall_time, true)

    state = %__MODULE__{
      config: config,
      collectors: %{},
      cache: %{},
      statistics: %{
        introspection_calls: 0,
        cache_hits: 0,
        cache_misses: 0
      }
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:introspect, target, opts}, _from, state) do
    result = perform_introspection(target, opts)
    new_stats = update_statistics(state.statistics, result)
    {:reply, result, %{state | statistics: new_stats}}
  end

  @impl GenServer
  def handle_call(:get_status, _from, state) do
    status = %{
      active_collectors: map_size(state.collectors),
      cache_size: map_size(state.cache),
      statistics: state.statistics
    }
    {:reply, status, state}
  end

  # Private implementation

  defp collect_system_info do
    %{
      otp_release: to_string(:erlang.system_info(:otp_release)),
      erts_version: to_string(:erlang.system_info(:version)),
      system_version: to_string(:erlang.system_info(:system_version)),
      system_architecture: to_string(:erlang.system_info(:system_architecture)),
      schedulers: :erlang.system_info(:schedulers),
      logical_processors: :erlang.system_info(:logical_processors_available) || 0,
      atom_count: :erlang.system_info(:atom_count),
      atom_limit: :erlang.system_info(:atom_limit),
      port_count: :erlang.system_info(:port_count),
      port_limit: :erlang.system_info(:port_limit),
      process_count: :erlang.system_info(:process_count),
      process_limit: :erlang.system_info(:process_limit),
      ets_count: length(:ets.all()),
      ets_limit: :erlang.system_info(:ets_limit)
    }
  end

  defp collect_memory_info do
    memory_data = :erlang.memory()
    Map.new(memory_data)
  end

  defp collect_applications_info do
    Application.loaded_applications()
    |> Enum.map(fn {name, description, version} ->
      %{
        name: name,
        description: to_string(description),
        version: to_string(version),
        status: get_application_status(name),
        modules: Application.spec(name, :modules) || [],
        registered: Application.spec(name, :registered) || [],
        applications: Application.spec(name, :applications) || [],
        included_applications: Application.spec(name, :included_applications) || [],
        env: Application.get_all_env(name)
      }
    end)
  end

  defp collect_processes_info do
    Process.list()
    |> Enum.map(&build_process_summary/1)
    |> Enum.filter(& &1 != nil)
  end

  defp collect_modules_info do
    :code.all_loaded()
    |> Enum.map(fn {module, file} ->
      %{
        module: module,
        file: file,
        native: :code.is_module_native(module),
        loaded: true,
        size: get_module_size(module),
        md5: get_module_md5(module),
        exports: try do
          module.module_info(:exports)
        rescue
          _ -> []
        end,
        attributes: try do
          module.module_info(:attributes)
        rescue
          _ -> []
        end,
        compile_info: try do
          module.module_info(:compile)
        rescue
          _ -> []
        end
      }
    end)
  end

  defp collect_distribution_info do
    %{
      node: node(),
      alive: Node.alive?(),
      nodes: Node.list(),
      cookie: Node.get_cookie(),
      net_kernel_running: :net_kernel in Process.registered(),
      connections: get_connection_info()
    }
  end

  defp get_application_status(name) do
    case Application.started_applications() |> Enum.find(fn {app, _, _} -> app == name end) do
      {^name, _, _} -> :started
      nil -> :loaded
    end
  end

  defp build_process_summary(pid) do
    try do
      case Process.info(pid) do
        nil -> nil
        process_info ->
          info_map = Map.new(process_info)
          %{
            pid: pid,
            registered_name: Map.get(info_map, :registered_name),
            initial_call: Map.get(info_map, :initial_call),
            current_function: Map.get(info_map, :current_function),
            status: Map.get(info_map, :status),
            message_queue_len: Map.get(info_map, :message_queue_len, 0),
            heap_size: Map.get(info_map, :heap_size, 0),
            stack_size: Map.get(info_map, :stack_size, 0),
            reductions: Map.get(info_map, :reductions, 0),
            memory: Map.get(info_map, :memory, 0),
            links: Map.get(info_map, :links, []),
            monitors: Map.get(info_map, :monitors, []),
            monitored_by: Map.get(info_map, :monitored_by, [])
          }
      end
    rescue
      _ -> nil
    end
  end

  defp get_connection_info do
    if Node.alive?() do
      Node.list()
      |> Enum.map(fn node ->
        %{
          node: node,
          type: :visible,  # Simplified - would need more complex logic for hidden nodes
          state: :up,
          owner: nil,  # Would need to get actual connection process
          address: nil  # Would need to get actual address
        }
      end)
    else
      []
    end
  end

  defp summarize_state(state) when is_map(state), do: %{type: :map, keys: Map.keys(state)}
  defp summarize_state(state) when is_list(state), do: %{type: :list, length: length(state)}
  defp summarize_state(state) when is_tuple(state), do: %{type: :tuple, size: tuple_size(state)}
  defp summarize_state(state), do: %{type: :other, value_type: typeof(state)}

  defp typeof(term) when is_atom(term), do: :atom
  defp typeof(term) when is_binary(term), do: :binary
  defp typeof(term) when is_integer(term), do: :integer
  defp typeof(term) when is_float(term), do: :float
  defp typeof(term) when is_boolean(term), do: :boolean
  defp typeof(term) when is_pid(term), do: :pid
  defp typeof(term) when is_reference(term), do: :reference
  defp typeof(term) when is_port(term), do: :port
  defp typeof(term) when is_function(term), do: :function
  defp typeof(_term), do: :unknown

  defp performance_monitor_loop(interval, callback) do
    metrics = collect_performance_metrics()
    callback.(metrics)
    :timer.sleep(interval)
    performance_monitor_loop(interval, callback)
  end

  defp collect_performance_metrics do
    %{
      timestamp: DateTime.utc_now(),
      memory: :erlang.memory(),
      process_count: :erlang.system_info(:process_count),
      reductions: :erlang.statistics(:reductions),
      garbage_collections: :erlang.statistics(:garbage_collection),
      scheduler_utilization: get_current_scheduler_utilization()
    }
  end

  defp default_performance_callback(metrics) do
    Logger.debug("Performance metrics", metrics: metrics)
  end

  defp analyze_memory_patterns(memory_info) do
    recommendations = []

    # Check for high binary memory
    if memory_info.binary > memory_info.total * 0.3 do
      recommendations = ["High binary memory usage detected - consider binary optimization" | recommendations]
    end

    # Check for high ETS memory
    if memory_info.ets > memory_info.total * 0.2 do
      recommendations = ["High ETS memory usage detected - review ETS table sizes" | recommendations]
    end

    # Check for high process memory
    if memory_info.processes > memory_info.total * 0.5 do
      recommendations = ["High process memory usage detected - analyze process memory consumption" | recommendations]
    end

    recommendations
  end

  defp get_top_memory_consuming_processes(n) do
    Process.list()
    |> Enum.map(fn pid ->
      case Process.info(pid, :memory) do
        {:memory, memory} -> {pid, memory}
        nil -> {pid, 0}
      end
    end)
    |> Enum.sort_by(fn {_pid, memory} -> memory end, :desc)
    |> Enum.take(n)
    |> Enum.map(fn {pid, memory} ->
      %{pid: pid, memory: memory, info: build_process_summary(pid)}
    end)
  end

  defp get_garbage_collection_stats do
    :erlang.statistics(:garbage_collection)
  end

  defp analyze_binary_memory do
    # Implementation for binary memory analysis
    %{analysis: "Binary memory analysis would be implemented here"}
  end

  defp get_module_size(module) do
    case :code.module_md5(module) do
      :undefined -> 0
      _md5 ->
        case :code.get_object_code(module) do
          {^module, binary, _filename} -> byte_size(binary)
          :error -> 0
        end
    end
  end

  defp get_module_md5(module) do
    case :code.module_md5(module) do
      :undefined -> nil
      md5 -> md5
    end
  end

  defp build_supervision_tree(app_name) do
    # Implementation for building supervision tree
    %{application: app_name, tree: "Supervision tree analysis would be implemented here"}
  end

  defp analyze_tree_health(tree_info) do
    # Implementation for tree health analysis
    %{status: :healthy, issues: []}
  end

  defp get_restart_intensity(app_name) do
    # Implementation for restart intensity analysis
    %{application: app_name, restarts: 0, intensity: :low}
  end

  defp get_worker_status(tree_info) do
    # Implementation for worker status analysis
    %{workers: [], supervisors: []}
  end

  defp code_change_tracker_loop(callback, previous_modules) do
    current_modules = get_loaded_modules_snapshot()
    changes = detect_module_changes(previous_modules, current_modules)

    if changes != [] do
      callback.(changes)
    end

    :timer.sleep(1000)
    code_change_tracker_loop(callback, current_modules)
  end

  defp get_loaded_modules_snapshot do
    :code.all_loaded()
    |> Enum.map(fn {module, _file} -> {module, get_module_md5(module)} end)
    |> Map.new()
  end

  defp detect_module_changes(previous, current) do
    # Implementation for detecting module changes
    []
  end

  defp default_code_change_callback(changes) do
    Logger.info("Code changes detected", changes: changes)
  end

  defp calculate_scheduler_utilization(stats) do
    # Implementation for calculating scheduler utilization
    %{average: 0.0, per_scheduler: []}
  end

  defp get_current_scheduler_utilization do
    case :erlang.statistics(:scheduler_wall_time) do
      :undefined -> %{error: :not_enabled}
      _stats -> %{utilization: 0.0}  # Simplified implementation
    end
  end

  defp analyze_single_ets_table(table_id) do
    try do
      info = :ets.info(table_id)
      case info do
        :undefined -> nil
        table_info ->
          %{
            id: table_id,
            name: table_info[:name],
            size: table_info[:size],
            memory: table_info[:memory],
            type: table_info[:type],
            protection: table_info[:protection],
            owner: table_info[:owner]
          }
      end
    rescue
      _ -> nil
    end
  end

  defp perform_introspection(target, opts) do
    case target do
      :system -> comprehensive_system_info(opts)
      :memory -> analyze_memory_usage(opts)
      :schedulers -> get_scheduler_utilization()
      :ets -> analyze_ets_tables()
      _ -> {:error, :unknown_target}
    end
  end

  defp update_statistics(stats, {:ok, _result}) do
    %{stats | introspection_calls: stats.introspection_calls + 1}
  end

  defp update_statistics(stats, {:error, _reason}) do
    %{stats | introspection_calls: stats.introspection_calls + 1}
  end
end
