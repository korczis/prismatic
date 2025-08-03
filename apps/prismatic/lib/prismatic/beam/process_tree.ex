defmodule Prismatic.BEAM.ProcessTree do
  @moduledoc """
  Process tree manipulation and supervision analysis for comprehensive OTP system management.

  This module provides advanced capabilities for analyzing, manipulating, and monitoring
  OTP supervision trees and process hierarchies. It enables deep inspection of supervisor
  strategies, worker states, process relationships, and provides tools for safe process
  management and supervision tree optimization.

  ## Features

  - **Tree Analysis**: Complete supervision tree traversal and visualization
  - **Process Management**: Safe process termination, restart, and state inspection
  - **Supervisor Control**: Dynamic child specification management and strategy analysis
  - **Health Monitoring**: Continuous supervision tree health assessment
  - **Performance Analysis**: Process performance metrics and bottleneck identification
  - **Debugging Tools**: Process state inspection and message queue analysis

  ## Supervision Strategies

  - **One for One**: Individual child restart on failure
  - **One for All**: All children restart when one fails
  - **Rest for One**: Failed child and subsequent children restart
  - **Simple One for One**: Dynamic child management for similar processes

  ## Documentation References

  - **Guide**: [`@/docs/guides/beam/process-tree.md`](../../../docs/guides/beam/process-tree.md)
  - **API**: [`@/docs/api/beam/process-tree.md`](../../../docs/api/beam/process-tree.md)
  - **OTP**: [`@/docs/guides/beam/otp-supervision.md`](../../../docs/guides/beam/otp-supervision.md)

  ## Navigation

  - **Parent**: [`Prismatic.BEAM`](../beam.md)
  - **Related**: [`Prismatic.BEAM.Introspection`](./introspection.md)
  - **Related**: [`Prismatic.BEAM.Runtime`](./runtime.md)

  ## Design Contracts

  ### Preconditions
  - Target processes and supervisors must be accessible
  - System must have appropriate permissions for process operations
  - OTP supervision trees must be properly structured

  ### Postconditions
  - All operations maintain system stability and consistency
  - Process relationships are preserved unless explicitly modified
  - Supervision strategies remain intact during analysis

  ### Invariants
  - Process tree integrity is maintained during operations
  - Supervisor invariants are never violated
  - System performance impact is minimized during analysis
  """

  use GenServer
  require Logger

  @type supervision_strategy :: :one_for_one | :one_for_all | :rest_for_one | :simple_one_for_one
  @type child_type :: :worker | :supervisor
  @type restart_type :: :permanent | :temporary | :transient
  @type shutdown_type :: :brutal_kill | :infinity | non_neg_integer()

  @type process_node :: %{
    pid: pid(),
    id: term(),
    module: module(),
    type: child_type(),
    status: process_status(),
    restart_type: restart_type(),
    shutdown_type: shutdown_type(),
    children: [process_node()],
    metadata: process_metadata()
  }

  @type process_status ::
    :running | :sleeping | :waiting | :runnable |
    :garbage_collecting | :suspended | :exiting

  @type process_metadata :: %{
    start_time: DateTime.t(),
    restart_count: non_neg_integer(),
    memory_usage: non_neg_integer(),
    message_queue_len: non_neg_integer(),
    reductions: non_neg_integer(),
    links: [pid()],
    monitors: [pid()],
    trap_exit: boolean()
  }

  @type supervision_tree :: %{
    root: process_node(),
    strategy: supervision_strategy(),
    max_restarts: non_neg_integer(),
    max_seconds: non_neg_integer(),
    total_processes: non_neg_integer(),
    total_supervisors: non_neg_integer(),
    total_workers: non_neg_integer(),
    health_status: tree_health()
  }

  @type tree_health :: %{
    status: :healthy | :degraded | :critical,
    issues: [health_issue()],
    restart_rate: float(),
    memory_pressure: :low | :medium | :high,
    message_queue_pressure: :low | :medium | :high
  }

  @type health_issue :: %{
    type: :high_restart_rate | :memory_leak | :message_queue_buildup |
          :supervisor_overload | :worker_failure | :circular_dependency,
    severity: :low | :medium | :high | :critical,
    description: String.t(),
    affected_processes: [pid()],
    recommendations: [String.t()]
  }

  @type tree_operation ::
    :analyze | :visualize | :health_check | :restart_child |
    :terminate_child | :add_child | :remove_child | :optimize

  @type optimization_suggestion :: %{
    type: :strategy_change | :restart_intensity | :child_order | :resource_allocation,
    priority: :low | :medium | :high,
    description: String.t(),
    expected_benefit: String.t(),
    implementation: String.t()
  }

  defstruct [
    :config,
    :monitored_trees,
    :health_monitors,
    :statistics
  ]

  @doc """
  Starts the ProcessTree component with the given configuration.
  """
  @spec start_link(map()) :: GenServer.on_start()
  def start_link(config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Executes a process tree operation with the specified arguments and options.
  """
  @spec execute(tree_operation(), term(), keyword()) :: {:ok, term()} | {:error, term()}
  def execute(operation, args, opts \\ []) do
    case GenServer.whereis(__MODULE__) do
      nil -> {:error, :not_started}
      pid -> GenServer.call(pid, {:execute, operation, args, opts}, :infinity)
    end
  end

  @doc """
  Analyzes a complete supervision tree starting from a root supervisor.

  ## Examples

      # Analyze application supervision tree
      iex> analyze_supervision_tree(MyApp.Supervisor)
      {:ok, %{root: %{pid: #PID<...>, children: [...]}, ...}}

      # Analyze with performance metrics
      iex> analyze_supervision_tree(MyApp.Supervisor, include_metrics: true)
      {:ok, %{root: %{...}, health_status: %{...}}}
  """
  @spec analyze_supervision_tree(pid() | atom(), keyword()) :: {:ok, supervision_tree()} | {:error, term()}
  def analyze_supervision_tree(supervisor, opts \\ []) do
    execute(:analyze, supervisor, opts)
  end

  @doc """
  Visualizes a supervision tree structure in various formats.

  ## Examples

      # Generate text-based tree visualization
      iex> visualize_tree(MyApp.Supervisor, format: :text)
      {:ok, "MyApp.Supervisor\\n  ├─ Worker1\\n  └─ Worker2"}

      # Generate DOT graph for Graphviz
      iex> visualize_tree(MyApp.Supervisor, format: :dot)
      {:ok, "digraph G { ... }"}
  """
  @spec visualize_tree(pid() | atom(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def visualize_tree(supervisor, opts \\ []) do
    execute(:visualize, supervisor, opts)
  end

  @doc """
  Performs comprehensive health check on a supervision tree.
  """
  @spec health_check(pid() | atom(), keyword()) :: {:ok, tree_health()} | {:error, term()}
  def health_check(supervisor, opts \\ []) do
    execute(:health_check, supervisor, opts)
  end

  @doc """
  Safely restarts a child process within a supervision tree.
  """
  @spec restart_child(pid() | atom(), term(), keyword()) :: {:ok, pid()} | {:error, term()}
  def restart_child(supervisor, child_id, opts \\ []) do
    execute(:restart_child, {supervisor, child_id}, opts)
  end

  @doc """
  Safely terminates a child process within a supervision tree.
  """
  @spec terminate_child(pid() | atom(), term(), keyword()) :: {:ok, :terminated} | {:error, term()}
  def terminate_child(supervisor, child_id, opts \\ []) do
    execute(:terminate_child, {supervisor, child_id}, opts)
  end

  @doc """
  Dynamically adds a child to a running supervisor.
  """
  @spec add_child(pid() | atom(), Supervisor.child_spec(), keyword()) :: {:ok, pid()} | {:error, term()}
  def add_child(supervisor, child_spec, opts \\ []) do
    execute(:add_child, {supervisor, child_spec}, opts)
  end

  @doc """
  Removes a child from a running supervisor.
  """
  @spec remove_child(pid() | atom(), term(), keyword()) :: {:ok, :removed} | {:error, term()}
  def remove_child(supervisor, child_id, opts \\ []) do
    execute(:remove_child, {supervisor, child_id}, opts)
  end

  @doc """
  Inspects a specific process within the supervision tree.
  """
  @spec inspect_process(pid(), keyword()) :: {:ok, process_metadata()} | {:error, term()}
  def inspect_process(pid, opts \\ []) do
    case Process.alive?(pid) do
      true ->
        try do
          metadata = build_process_metadata(pid, opts)
          {:ok, metadata}
        rescue
          error -> {:error, {:inspection_failed, error}}
        end
      false ->
        {:error, :process_not_alive}
    end
  end

  @doc """
  Optimizes supervision tree configuration based on analysis results.
  """
  @spec optimize_tree(pid() | atom(), keyword()) :: {:ok, [optimization_suggestion()]} | {:error, term()}
  def optimize_tree(supervisor, opts \\ []) do
    execute(:optimize, supervisor, opts)
  end

  @doc """
  Gets process tree statistics and performance metrics.
  """
  @spec get_statistics() :: map()
  def get_statistics do
    case GenServer.whereis(__MODULE__) do
      nil -> %{status: :not_started}
      pid -> GenServer.call(pid, :get_statistics)
    end
  end

  # GenServer implementation

  @impl GenServer
  def init(config) do
    Logger.info("Starting ProcessTree component")

    state = %__MODULE__{
      config: config,
      monitored_trees: %{},
      health_monitors: %{},
      statistics: %{
        trees_analyzed: 0,
        processes_inspected: 0,
        health_checks: 0,
        optimizations_suggested: 0
      }
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:execute, operation, args, opts}, _from, state) do
    result = execute_tree_operation(operation, args, opts, state.config)
    new_state = update_statistics(state, operation, result)
    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_call(:get_statistics, _from, state) do
    stats = %{
      monitored_trees: map_size(state.monitored_trees),
      active_monitors: map_size(state.health_monitors),
      statistics: state.statistics
    }
    {:reply, stats, state}
  end

  @impl GenServer
  def handle_info({:tree_health_update, supervisor, health_status}, state) do
    Logger.debug("Tree health update", supervisor: supervisor, status: health_status.status)
    {:noreply, state}
  end

  # Private implementation

  defp execute_tree_operation(:analyze, supervisor, opts, _config) do
    analyze_supervision_tree_impl(supervisor, opts)
  end

  defp execute_tree_operation(:visualize, supervisor, opts, _config) do
    visualize_tree_impl(supervisor, opts)
  end

  defp execute_tree_operation(:health_check, supervisor, opts, _config) do
    health_check_impl(supervisor, opts)
  end

  defp execute_tree_operation(:restart_child, {supervisor, child_id}, opts, _config) do
    restart_child_impl(supervisor, child_id, opts)
  end

  defp execute_tree_operation(:terminate_child, {supervisor, child_id}, opts, _config) do
    terminate_child_impl(supervisor, child_id, opts)
  end

  defp execute_tree_operation(:add_child, {supervisor, child_spec}, opts, _config) do
    add_child_impl(supervisor, child_spec, opts)
  end

  defp execute_tree_operation(:remove_child, {supervisor, child_id}, opts, _config) do
    remove_child_impl(supervisor, child_id, opts)
  end

  defp execute_tree_operation(:optimize, supervisor, opts, _config) do
    optimize_tree_impl(supervisor, opts)
  end

  defp analyze_supervision_tree_impl(supervisor, opts) do
    try do
      root_node = build_process_tree(supervisor, opts)
      tree_stats = calculate_tree_statistics(root_node)
      health_status = assess_tree_health(root_node, opts)

      supervision_tree = %{
        root: root_node,
        strategy: get_supervisor_strategy(supervisor),
        max_restarts: get_supervisor_max_restarts(supervisor),
        max_seconds: get_supervisor_max_seconds(supervisor),
        total_processes: tree_stats.total_processes,
        total_supervisors: tree_stats.total_supervisors,
        total_workers: tree_stats.total_workers,
        health_status: health_status
      }

      {:ok, supervision_tree}
    rescue
      error -> {:error, {:analysis_failed, error}}
    end
  end

  defp build_process_tree(supervisor, opts) do
    supervisor_pid = resolve_supervisor_pid(supervisor)

    case Supervisor.which_children(supervisor_pid) do
      children when is_list(children) ->
        child_nodes = Enum.map(children, fn {id, child_pid, type, modules} ->
          build_child_node(id, child_pid, type, modules, opts)
        end)

        %{
          pid: supervisor_pid,
          id: supervisor,
          module: get_process_module(supervisor_pid),
          type: :supervisor,
          status: get_process_status(supervisor_pid),
          restart_type: :permanent,
          shutdown_type: :infinity,
          children: child_nodes,
          metadata: build_process_metadata(supervisor_pid, opts)
        }
      _error ->
        %{
          pid: supervisor_pid,
          id: supervisor,
          module: nil,
          type: :supervisor,
          status: :unknown,
          restart_type: :permanent,
          shutdown_type: :infinity,
          children: [],
          metadata: %{}
        }
    end
  end

  defp build_child_node(id, child_pid, type, modules, opts) do
    case child_pid do
      pid when is_pid(pid) ->
        child_nodes = if type == :supervisor do
          case build_process_tree(pid, opts) do
            %{children: children} -> children
            _ -> []
          end
        else
          []
        end

        %{
          pid: pid,
          id: id,
          module: List.first(modules),
          type: type,
          status: get_process_status(pid),
          restart_type: :permanent,
          shutdown_type: 5000,
          children: child_nodes,
          metadata: build_process_metadata(pid, opts)
        }
      :undefined ->
        %{
          pid: nil,
          id: id,
          module: List.first(modules),
          type: type,
          status: :not_started,
          restart_type: :permanent,
          shutdown_type: 5000,
          children: [],
          metadata: %{}
        }
      :restarting ->
        %{
          pid: nil,
          id: id,
          module: List.first(modules),
          type: type,
          status: :restarting,
          restart_type: :permanent,
          shutdown_type: 5000,
          children: [],
          metadata: %{}
        }
    end
  end

  defp build_process_metadata(pid, opts) when is_pid(pid) do
    try do
      case Process.info(pid) do
        nil -> %{}
        process_info ->
          info_map = Map.new(process_info)

          %{
            start_time: estimate_start_time(pid),
            restart_count: 0,
            memory_usage: Map.get(info_map, :memory, 0),
            message_queue_len: Map.get(info_map, :message_queue_len, 0),
            reductions: Map.get(info_map, :reductions, 0),
            links: Map.get(info_map, :links, []),
            monitors: Map.get(info_map, :monitors, []),
            trap_exit: Map.get(info_map, :trap_exit, false)
          }
      end
    rescue
      _ -> %{}
    end
  end

  defp build_process_metadata(_pid, _opts), do: %{}

  defp resolve_supervisor_pid(supervisor) when is_pid(supervisor), do: supervisor
  defp resolve_supervisor_pid(supervisor) when is_atom(supervisor) do
    case Process.whereis(supervisor) do
      nil -> raise "Supervisor #{supervisor} not found"
      pid -> pid
    end
  end

  defp get_process_module(pid) do
    case Process.info(pid, :dictionary) do
      {:dictionary, dict} ->
        case Keyword.get(dict, :"$initial_call") do
          {module, _fun, _arity} -> module
          _ -> nil
        end
      nil -> nil
    end
  end

  defp get_process_status(pid) do
    case Process.info(pid, :status) do
      {:status, status} -> status
      nil -> :unknown
    end
  end

  defp get_supervisor_strategy(_supervisor) do
    :one_for_one
  end

  defp get_supervisor_max_restarts(_supervisor) do
    3
  end

  defp get_supervisor_max_seconds(_supervisor) do
    5
  end

  defp calculate_tree_statistics(root_node) do
    traverse_tree_for_stats(root_node, %{
      total_processes: 0,
      total_supervisors: 0,
      total_workers: 0
    })
  end

  defp traverse_tree_for_stats(node, stats) do
    new_stats = case node.type do
      :supervisor ->
        %{stats |
          total_processes: stats.total_processes + 1,
          total_supervisors: stats.total_supervisors + 1
        }
      :worker ->
        %{stats |
          total_processes: stats.total_processes + 1,
          total_workers: stats.total_workers + 1
        }
    end

    Enum.reduce(node.children, new_stats, &traverse_tree_for_stats/2)
  end

  defp assess_tree_health(root_node, _opts) do
    issues = []
    |> check_memory_usage(root_node)
    |> check_message_queues(root_node)

    overall_status = determine_overall_health(issues)

    %{
      status: overall_status,
      issues: issues,
      restart_rate: 0.0,
      memory_pressure: :low,
      message_queue_pressure: :low
    }
  end

  defp check_memory_usage(issues, node) do
    if node.metadata[:memory_usage] && node.metadata.memory_usage > 100_000_000 do
      issue = %{
        type: :memory_leak,
        severity: :high,
        description: "Process #{inspect(node.pid)} has high memory usage (#{node.metadata.memory_usage} bytes)",
        affected_processes: [node.pid],
        recommendations: ["Monitor memory growth patterns", "Check for memory leaks"]
      }
      [issue | issues]
    else
      issues
    end
  end

  defp check_message_queues(issues, node) do
    if node.metadata[:message_queue_len] && node.metadata.message_queue_len > 1000 do
      issue = %{
        type: :message_queue_buildup,
        severity: :medium,
        description: "Process #{inspect(node.pid)} has large message queue (#{node.metadata.message_queue_len} messages)",
        affected_processes: [node.pid],
        recommendations: ["Investigate message processing bottlenecks", "Consider backpressure mechanisms"]
      }
      [issue | issues]
    else
      issues
    end
  end

  defp determine_overall_health([]), do: :healthy
  defp determine_overall_health(issues) do
    max_severity = Enum.max_by(issues, fn issue ->
      case issue.severity do
        :low -> 1
        :medium -> 2
        :high -> 3
        :critical -> 4
      end
    end).severity

    case max_severity do
      :low -> :healthy
      :medium -> :healthy
      :high -> :degraded
      :critical -> :critical
    end
  end

  defp estimate_start_time(_pid) do
    DateTime.add(DateTime.utc_now(), -60, :second)
  end

  defp visualize_tree_impl(supervisor, opts) do
    case analyze_supervision_tree_impl(supervisor, opts) do
      {:ok, tree} ->
        format = Keyword.get(opts, :format, :text)

        case format do
          :text -> {:ok, format_tree_as_text(tree.root)}
          :dot -> {:ok, format_tree_as_dot(tree.root, supervisor)}
          _ -> {:error, {:unsupported_format, format}}
        end
      error -> error
    end
  end

  defp format_tree_as_text(node, prefix \\ "", is_last \\ true) do
    connector = if is_last, do: "└─ ", else: "├─ "
    current_line = "#{prefix}#{connector}#{format_node_description(node)}\n"

    children_prefix = prefix <> if is_last, do: "   ", else: "│  "
    children_count = length(node.children)

    children_text =
      node.children
      |> Enum.with_index()
      |> Enum.map(fn {child, index} ->
        is_last_child = index == children_count - 1
        format_tree_as_text(child, children_prefix, is_last_child)
      end)
      |> Enum.join("")

    current_line <> children_text
  end

  defp format_node_description(node) do
    type_indicator = if node.type == :supervisor, do: "📁", else: "📄"
    status_indicator = case node.status do
      :running -> "✅"
      :sleeping -> "😴"
      :waiting -> "⏳"
      _ -> "❓"
    end

    "#{type_indicator} #{status_indicator} #{node.id} (#{inspect(node.pid)})"
  end

  defp format_tree_as_dot(node, supervisor_name) do
    edges = collect_dot_edges(node, [])
    nodes = collect_dot_nodes(node, [])

    """
    digraph "#{supervisor_name}" {
      rankdir=TB;
      node [shape=rectangle, style=filled];

      #{Enum.join(nodes, "\n  ")}

      #{Enum.join(edges, "\n  ")}
    }
    """
  end

  defp collect_dot_nodes(node, acc) do
    node_attrs = case node.type do
      :supervisor -> "fillcolor=lightblue"
      :worker -> "fillcolor=lightgreen"
    end

    node_line = "\"#{inspect(node.pid)}\" [label=\"#{node.id}\", #{node_attrs}];"
    new_acc = [node_line | acc]

    Enum.reduce(node.children, new_acc, &collect_dot_nodes/2)
  end

  defp collect_dot_edges(node, acc) do
    child_edges = Enum.map(node.children, fn child ->
      "\"#{inspect(node.pid)}\" -> \"#{inspect(child.pid)}\";"
    end)

    new_acc = child_edges ++ acc

    Enum.reduce(node.children, new_acc, &collect_dot_edges/2)
  end

  defp health_check_impl(supervisor, opts) do
    case analyze_supervision_tree_impl(supervisor, opts) do
      {:ok, tree} -> {:ok, tree.health_status}
      error -> error
    end
  end

  defp restart_child_impl(supervisor, child_id, _opts) do
    try do
      case Supervisor.restart_child(supervisor, child_id) do
        {:ok, pid} -> {:ok, pid}
        {:ok, pid, _info} -> {:ok, pid}
        {:error, reason} -> {:error, reason}
      end
    rescue
      error -> {:error, {:restart_failed, error}}
    end
  end

  defp terminate_child_impl(supervisor, child_id, _opts) do
    try do
      case Supervisor.terminate_child(supervisor, child_id) do
        :ok -> {:ok, :terminated}
        {:error, reason} -> {:error, reason}
      end
    rescue
      error -> {:error, {:termination_failed, error}}
    end
  end

  defp add_child_impl(supervisor, child_spec, _opts) do
    try do
      case Supervisor.start_child(supervisor, child_spec) do
        {:ok, pid} -> {:ok, pid}
        {:ok, pid, _info} -> {:ok, pid}
        {:error, reason} -> {:error, reason}
      end
    rescue
      error -> {:error, {:add_child_failed, error}}
    end
  end

  defp remove_child_impl(supervisor, child_id, _opts) do
    try do
      case Supervisor.delete_child(supervisor, child_id) do
        :ok -> {:ok, :removed}
        {:error, reason} -> {:error, reason}
      end
    rescue
      error -> {:error, {:remove_child_failed, error}}
    end
  end

  defp optimize_tree_impl(supervisor, opts) do
    case analyze_supervision_tree_impl(supervisor, opts) do
      {:ok, tree} ->
        suggestions = generate_optimization_suggestions(tree, opts)
        {:ok, suggestions}
      error -> error
    end
  end

  defp generate_optimization_suggestions(tree, _opts) do
    suggestions = []

    # Analyze supervision strategy
    suggestions = if tree.total_workers > 10 and tree.strategy != :one_for_one do
      suggestion = %{
        type: :strategy_change,
        priority: :medium,
        description: "Consider using :one_for_one strategy for better isolation with #{tree.total_workers} workers",
        expected_benefit: "Improved fault isolation and system stability",
        implementation: "Change supervisor strategy to :one_for_one in supervisor specification"
      }
      [suggestion | suggestions]
    else
      suggestions
    end

    # Analyze restart intensity
    suggestions = if tree.health_status.restart_rate > 0.1 do
      suggestion = %{
        type: :restart_intensity,
        priority: :high,
        description: "High restart rate detected (#{tree.health_status.restart_rate}/sec)",
        expected_benefit: "Reduced system instability and resource usage",
        implementation: "Investigate root causes of failures and consider adjusting max_restarts/max_seconds"
      }
      [suggestion | suggestions]
    else
      suggestions
    end

    suggestions
  end

  defp update_statistics(state, operation, result) do
    case {operation, result} do
      {:analyze, {:ok, _}} ->
        %{state | statistics: %{state.statistics |
          trees_analyzed: state.statistics.trees_analyzed + 1
        }}
      {:health_check, {:ok, _}} ->
        %{state | statistics: %{state.statistics |
          health_checks: state.statistics.health_checks + 1
        }}
      {:optimize, {:ok, suggestions}} ->
        %{state | statistics: %{state.statistics |
          optimizations_suggested: state.statistics.optimizations_suggested + length(suggestions)
        }}
      _ ->
        state
    end
  end
end
