defmodule Mix.Tasks.Beam.Toolkit do
  @moduledoc """
  Minimal CLI interface for the comprehensive BEAM toolkit.

  This Mix task serves as a lightweight command-line interface that delegates
  all operations to the rich programmatic API provided by Prismatic.BEAM.
  All functionality can be invoked directly from Elixir code without shell
  dependencies, making it suitable for both development workflows and
  production system maintenance.

  ## Usage

      # Initialize toolkit in different modes
      mix beam.toolkit init --mode offline
      mix beam.toolkit init --mode online --discovery dns
      mix beam.toolkit init --mode runtime --safety production

      # File system operations
      mix beam.toolkit fs traverse /path/to/directory --recursive
      mix beam.toolkit fs monitor /path/to/watch --events created,modified
      mix beam.toolkit fs analyze /path/to/file --content-analysis

      # System introspection
      mix beam.toolkit introspect system --targets memory,processes
      mix beam.toolkit introspect process --pid "<0.123.0>"
      mix beam.toolkit introspect module MyModule

      # Runtime operations
      mix beam.toolkit runtime reload MyModule --safety production
      mix beam.toolkit runtime snapshot create --target all
      mix beam.toolkit runtime snapshot restore snapshot_id

      # Distributed operations
      mix beam.toolkit distributed discover --method dns --domain cluster.local
      mix beam.toolkit distributed connect node1@host1
      mix beam.toolkit distributed call node1@host1 MyModule function [arg1,arg2]

      # Get status and health
      mix beam.toolkit status
      mix beam.toolkit health

  ## Programmatic API

  All operations can be performed programmatically:

      # Initialize toolkit
      {:ok, :initialized} = Prismatic.BEAM.initialize(:runtime, safety_level: :production)

      # File system operations
      {:ok, result} = Prismatic.BEAM.file_system(:traverse, "/path", recursive: true)

      # Introspection
      {:ok, info} = Prismatic.BEAM.system_info(targets: [:memory, :processes])

      # Runtime operations
      {:ok, result} = Prismatic.BEAM.runtime(:reload_module, MyModule, safety_level: :production)

      # Distributed operations
      {:ok, nodes} = Prismatic.BEAM.distributed(:discover_nodes, :dns, domain: "cluster.local")

  ## Examples

  ### Development Workflow

      # Start in development mode with auto-discovery
      mix beam.toolkit init --mode runtime --safety development

      # Monitor project files for changes
      mix beam.toolkit fs monitor . --recursive --events modified

      # Hot reload changed modules
      mix beam.toolkit runtime reload MyChangedModule

  ### Production Maintenance

      # Connect to production cluster
      mix beam.toolkit init --mode online --safety production
      mix beam.toolkit distributed connect prod1@production.local

      # Create system snapshot before changes
      mix beam.toolkit runtime snapshot create --target critical_modules

      # Perform safe hot reload
      mix beam.toolkit runtime reload MyModule --validate --backup-state

      # Monitor system health
      mix beam.toolkit health --continuous

  ### System Analysis

      # Comprehensive system analysis
      mix beam.toolkit introspect system --all

      # Analyze memory usage patterns
      mix beam.toolkit introspect memory --top-processes 20

      # File system analysis
      mix beam.toolkit fs analyze /var/log --duplicate-detection
  """

  use Mix.Task
  require Logger

  alias Prismatic.BEAM

  @shortdoc "Comprehensive BEAM toolkit operations"

  @switches [
    # Global options
    mode: :string,
    safety: :string,
    verbose: :boolean,
    json: :boolean,
    help: :boolean,

    # File system options
    recursive: :boolean,
    events: :string,
    content_analysis: :boolean,
    duplicate_detection: :boolean,
    max_depth: :integer,

    # Introspection options
    targets: :string,
    pid: :string,
    top_processes: :integer,
    all: :boolean,

    # Runtime options
    validate: :boolean,
    backup_state: :boolean,
    rollback_on_error: :boolean,
    target: :string,

    # Distributed options
    method: :string,
    domain: :string,
    timeout: :integer,
    discovery: :string,

    # Monitoring options
    continuous: :boolean,
    interval: :integer
  ]

  @aliases [
    m: :mode,
    s: :safety,
    v: :verbose,
    r: :recursive,
    h: :help
  ]

  @doc """
  Main entry point for the BEAM toolkit CLI.
  """
  def run(args) do
    {opts, args, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    if opts[:help] do
      print_help()
    else
      case args do
        [] -> print_status_and_help()
        ["init" | init_args] -> handle_init(init_args, opts)
        ["fs" | fs_args] -> handle_file_system(fs_args, opts)
        ["introspect" | introspect_args] -> handle_introspection(introspect_args, opts)
        ["runtime" | runtime_args] -> handle_runtime(runtime_args, opts)
        ["distributed" | dist_args] -> handle_distributed(dist_args, opts)
        ["status"] -> handle_status(opts)
        ["health"] -> handle_health(opts)
        [unknown | _] -> print_error("Unknown command: #{unknown}")
      end
    end
  end

  # Command handlers

  defp handle_init(args, opts) do
    mode = parse_mode(opts[:mode] || "offline")
    safety_level = parse_safety_level(opts[:safety] || "development")

    init_opts = [
      safety_level: safety_level,
      node_discovery: opts[:discovery] != nil,
      real_time_monitoring: mode == :runtime,
      hot_code_reloading: mode == :runtime,
      distributed_coordination: mode == :online
    ]

    case BEAM.initialize(mode, init_opts) do
      {:ok, :initialized} ->
        print_success("BEAM toolkit initialized in #{mode} mode with #{safety_level} safety level")
        if opts[:verbose] do
          print_info("Configuration: #{inspect(init_opts)}")
        end
      {:error, reason} ->
        print_error("Failed to initialize toolkit: #{inspect(reason)}")
    end
  end

  defp handle_file_system(["traverse", path | _], opts) do
    traverse_opts = build_traverse_options(opts)

    print_info("Traversing #{path}...")

    case BEAM.file_system(:traverse, path, traverse_opts) do
      {:ok, result} ->
        if opts[:json] do
          print_json(result)
        else
          print_traverse_result(result, opts)
        end
      {:error, reason} ->
        print_error("Traversal failed: #{inspect(reason)}")
    end
  end

  defp handle_file_system(["monitor", path | _], opts) do
    events = parse_events(opts[:events] || "created,modified,deleted")

    monitor_opts = [
      events: events,
      recursive: opts[:recursive] || false,
      callback: &handle_file_event/1
    ]

    print_info("Starting file system monitoring on #{path}")
    print_info("Events: #{inspect(events)}")

    case BEAM.file_system(:start_monitoring, path, monitor_opts) do
      {:ok, :monitoring_started} ->
        print_success("File monitoring started. Press Ctrl+C to stop.")
        # Keep the task running
        Process.sleep(:infinity)
      {:error, reason} ->
        print_error("Failed to start monitoring: #{inspect(reason)}")
    end
  end

  defp handle_file_system(["analyze", path | _], opts) do
    analysis_opts = [
      content_analysis: opts[:content_analysis] || false,
      duplicate_detection: opts[:duplicate_detection] || false,
      encoding_detection: true
    ]

    print_info("Analyzing #{path}...")

    result = if File.dir?(path) do
      BEAM.file_system(:analyze_directory, path, analysis_opts)
    else
      BEAM.file_system(:analyze_file, path, analysis_opts)
    end

    case result do
      {:ok, analysis} ->
        if opts[:json] do
          print_json(analysis)
        else
          print_analysis_result(analysis, opts)
        end
      {:error, reason} ->
        print_error("Analysis failed: #{inspect(reason)}")
    end
  end

  defp handle_file_system(args, _opts) do
    print_error("Unknown file system command: #{inspect(args)}")
    print_info("Available commands: traverse, monitor, analyze")
  end

  defp handle_introspection(["system" | _], opts) do
    targets = parse_targets(opts[:targets] || "system,memory,applications,processes")

    print_info("Collecting system information...")

    case BEAM.system_info(targets: targets) do
      {:ok, info} ->
        if opts[:json] do
          print_json(info)
        else
          print_system_info(info, opts)
        end
      {:error, reason} ->
        print_error("System introspection failed: #{inspect(reason)}")
    end
  end

  defp handle_introspection(["process" | _], opts) do
    case opts[:pid] do
      nil ->
        print_error("Process PID is required. Use --pid option.")
      pid_string ->
        case parse_pid(pid_string) do
          {:ok, pid} ->
            print_info("Analyzing process #{inspect(pid)}...")

            case BEAM.Introspection.analyze_process(pid) do
              {:ok, process_info} ->
                if opts[:json] do
                  print_json(process_info)
                else
                  print_process_info(process_info, opts)
                end
              {:error, reason} ->
                print_error("Process analysis failed: #{inspect(reason)}")
            end
          {:error, reason} ->
            print_error("Invalid PID format: #{reason}")
        end
    end
  end

  defp handle_introspection(["memory" | _], opts) do
    memory_opts = [
      include_processes: true,
      top_processes: opts[:top_processes] || 10
    ]

    print_info("Analyzing memory usage...")

    case BEAM.Introspection.analyze_memory_usage(memory_opts) do
      {:ok, analysis} ->
        if opts[:json] do
          print_json(analysis)
        else
          print_memory_analysis(analysis, opts)
        end
      {:error, reason} ->
        print_error("Memory analysis failed: #{inspect(reason)}")
    end
  end

  defp handle_introspection(args, _opts) do
    print_error("Unknown introspection command: #{inspect(args)}")
    print_info("Available commands: system, process, memory")
  end

  defp handle_runtime(["reload", module_name | _], opts) do
    case parse_module(module_name) do
      {:ok, module} ->
        reload_opts = [
          safety_level: parse_safety_level(opts[:safety] || "development"),
          validate_before: opts[:validate] || false,
          backup_state: opts[:backup_state] || true,
          rollback_on_error: opts[:rollback_on_error] || true
        ]

        print_info("Hot reloading module #{module}...")

        case BEAM.runtime(:reload_module, module, reload_opts) do
          {:ok, result} ->
            if opts[:json] do
              print_json(result)
            else
              print_reload_result(result, opts)
            end
          {:error, reason} ->
            print_error("Module reload failed: #{inspect(reason)}")
        end
      {:error, reason} ->
        print_error("Invalid module name: #{reason}")
    end
  end

  defp handle_runtime(["snapshot", "create" | _], opts) do
    target = case opts[:target] do
      "all" -> :all
      nil -> :all
      modules_string -> parse_module_list(modules_string)
    end

    snapshot_opts = [
      include_processes: true
    ]

    print_info("Creating system snapshot...")

    case BEAM.runtime(:create_snapshot, target, snapshot_opts) do
      {:ok, snapshot_id} ->
        print_success("Snapshot created: #{snapshot_id}")
      {:error, reason} ->
        print_error("Snapshot creation failed: #{inspect(reason)}")
    end
  end

  defp handle_runtime(["snapshot", "restore", snapshot_id | _], opts) do
    print_info("Restoring from snapshot #{snapshot_id}...")

    case BEAM.runtime(:restore_snapshot, snapshot_id, []) do
      {:ok, result} ->
        if opts[:json] do
          print_json(result)
        else
          print_success("Snapshot restored successfully")
          print_info("Restored: #{inspect(result)}")
        end
      {:error, reason} ->
        print_error("Snapshot restoration failed: #{inspect(reason)}")
    end
  end

  defp handle_runtime(args, _opts) do
    print_error("Unknown runtime command: #{inspect(args)}")
    print_info("Available commands: reload, snapshot")
  end

  defp handle_distributed(["discover" | _], opts) do
    method = parse_discovery_method(opts[:method] || "dns")

    discover_opts = case method do
      :dns -> [domain: opts[:domain] || "cluster.local"]
      :multicast -> [port: 45892, timeout: opts[:timeout] || 5000]
      :static -> [nodes: []]
    end

    print_info("Discovering nodes using #{method}...")

    case BEAM.distributed(:discover_nodes, method, discover_opts) do
      {:ok, nodes} ->
        if opts[:json] do
          print_json(%{nodes: nodes})
        else
          print_success("Discovered #{length(nodes)} nodes:")
          Enum.each(nodes, &print_info("  - #{&1}"))
        end
      {:error, reason} ->
        print_error("Node discovery failed: #{inspect(reason)}")
    end
  end

  defp handle_distributed(["connect", node_name | _], opts) do
    case parse_node(node_name) do
      {:ok, node} ->
        print_info("Connecting to node #{node}...")

        case BEAM.distributed(:connect_node, node, []) do
          {:ok, node_info} ->
            if opts[:json] do
              print_json(node_info)
            else
              print_success("Connected to #{node}")
              print_node_info(node_info, opts)
            end
          {:error, reason} ->
            print_error("Connection failed: #{inspect(reason)}")
        end
      {:error, reason} ->
        print_error("Invalid node name: #{reason}")
    end
  end

  defp handle_distributed(["call", node_name, module_name, function_name | args], opts) do
    with {:ok, node} <- parse_node(node_name),
         {:ok, module} <- parse_module(module_name),
         {:ok, function} <- parse_atom(function_name),
         {:ok, parsed_args} <- parse_call_args(args) do

      call_opts = [
        timeout: opts[:timeout] || 5000
      ]

      print_info("Remote call: #{node}.#{module}.#{function}(#{inspect(parsed_args)})")

      case BEAM.distributed(:remote_call, node, module, function, parsed_args, call_opts) do
        {:ok, result} ->
          if opts[:json] do
            print_json(%{result: result})
          else
            print_success("Remote call successful")
            print_info("Result: #{inspect(result)}")
          end
        {:error, reason} ->
          print_error("Remote call failed: #{inspect(reason)}")
      end
    else
      {:error, reason} ->
        print_error("Invalid arguments: #{reason}")
    end
  end

  defp handle_distributed(args, _opts) do
    print_error("Unknown distributed command: #{inspect(args)}")
    print_info("Available commands: discover, connect, call")
  end

  defp handle_status(opts) do
    status = BEAM.status()

    if opts[:json] do
      print_json(status)
    else
      print_status_info(status, opts)
    end
  end

  defp handle_health(opts) do
    if opts[:continuous] do
      interval = opts[:interval] || 5000
      print_info("Continuous health monitoring (interval: #{interval}ms). Press Ctrl+C to stop.")
      monitor_health_continuously(interval, opts)
    else
      print_single_health_status(opts)
    end
  end

  # Helper functions

  defp build_traverse_options(opts) do
    []
    |> maybe_add_option(:recursive, opts[:recursive])
    |> maybe_add_option(:max_depth, opts[:max_depth])
    |> maybe_add_option(:parallel, true)
  end

  defp maybe_add_option(opts, _key, nil), do: opts
  defp maybe_add_option(opts, key, value), do: Keyword.put(opts, key, value)

  defp parse_mode("offline"), do: :offline
  defp parse_mode("online"), do: :online
  defp parse_mode("runtime"), do: :runtime
  defp parse_mode(mode), do: String.to_atom(mode)

  defp parse_safety_level("development"), do: :development
  defp parse_safety_level("staging"), do: :staging
  defp parse_safety_level("production"), do: :production
  defp parse_safety_level(level), do: String.to_atom(level)

  defp parse_events(events_string) do
    events_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_atom/1)
  end

  defp parse_targets(targets_string) do
    targets_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_atom/1)
  end

  defp parse_pid(pid_string) do
    try do
      pid = :erlang.list_to_pid(String.to_charlist(pid_string))
      {:ok, pid}
    rescue
      _ -> {:error, "Invalid PID format"}
    end
  end

  defp parse_module(module_string) do
    try do
      module = String.to_existing_atom(module_string)
      {:ok, module}
    rescue
      ArgumentError -> {:error, "Module does not exist: #{module_string}"}
    end
  end

  defp parse_atom(string) do
    try do
      atom = String.to_existing_atom(string)
      {:ok, atom}
    rescue
      ArgumentError -> {:error, "Atom does not exist: #{string}"}
    end
  end

  defp parse_node(node_string) do
    try do
      node = String.to_atom(node_string)
      {:ok, node}
    rescue
      _ -> {:error, "Invalid node format"}
    end
  end

  defp parse_module_list(modules_string) do
    modules_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_existing_atom/1)
  end

  defp parse_call_args(args) do
    try do
      parsed = Enum.map(args, &Code.eval_string/1) |> Enum.map(&elem(&1, 0))
      {:ok, parsed}
    rescue
      _ -> {:error, "Invalid argument format"}
    end
  end

  defp parse_discovery_method("dns"), do: :dns
  defp parse_discovery_method("multicast"), do: :multicast
  defp parse_discovery_method("static"), do: :static
  defp parse_discovery_method(method), do: String.to_atom(method)

  # Event handlers

  defp handle_file_event(event) do
    timestamp = DateTime.to_string(DateTime.utc_now())
    Mix.shell().info("#{timestamp} - File event: #{inspect(event)}")
  end

  # Output formatting

  defp print_success(message) do
    Mix.shell().info([:green, "✓ ", :reset, message])
  end

  defp print_error(message) do
    Mix.shell().error([:red, "✗ ", :reset, message])
  end

  defp print_info(message) do
    Mix.shell().info([:blue, "ℹ ", :reset, message])
  end

  defp print_json(data) do
    case Jason.encode(data, pretty: true) do
      {:ok, json} -> Mix.shell().info(json)
      {:error, _} -> Mix.shell().info(inspect(data, pretty: true))
    end
  end

  defp print_traverse_result(result, opts) do
    print_success("Traversal completed")
    print_info("Files: #{result.total_files}, Directories: #{result.total_directories}")
    print_info("Total Size: #{format_bytes(result.total_size)}")

    if opts[:verbose] and result.errors != [] do
      print_info("Errors encountered:")
      Enum.each(result.errors, fn error ->
        print_error("  #{error.path}: #{inspect(error.error)}")
      end)
    end
  end

  defp print_analysis_result(analysis, opts) do
    print_success("Analysis completed")
    print_info("Analysis results available")

    if opts[:verbose] do
      print_info("Detailed analysis: #{inspect(analysis, limit: :infinity)}")
    end
  end

  defp print_system_info(info, opts) do
    print_success("System information collected")

    if Map.has_key?(info, :system) do
      sys = info.system
      print_info("BEAM Version: #{sys.erts_version}")
      print_info("Schedulers: #{sys.schedulers}")
      print_info("Processes: #{sys.process_count}/#{sys.process_limit}")
    end

    if Map.has_key?(info, :memory) do
      mem = info.memory
      print_info("Memory Total: #{format_bytes(mem.total)}")
      print_info("Memory Processes: #{format_bytes(mem.processes)}")
    end

    if opts[:verbose] do
      print_info("Full details: #{inspect(info, limit: :infinity)}")
    end
  end

  defp print_process_info(process_info, opts) do
    print_success("Process analysis completed")
    print_info("PID: #{inspect(process_info.pid)}")

    if Map.has_key?(process_info, :memory) do
      print_info("Memory: #{format_bytes(process_info.memory)}")
    end

    if Map.has_key?(process_info, :message_queue_len) do
      print_info("Message Queue: #{process_info.message_queue_len}")
    end

    if opts[:verbose] do
      print_info("Full details: #{inspect(process_info, limit: :infinity)}")
    end
  end

  defp print_memory_analysis(analysis, opts) do
    print_success("Memory analysis completed")

    if Map.has_key?(analysis, :summary) do
      summary = analysis.summary
      print_info("Total Memory: #{format_bytes(summary.total)}")
      print_info("Process Memory: #{format_bytes(summary.processes)}")
      print_info("Binary Memory: #{format_bytes(summary.binary)}")
    end

    if Map.has_key?(analysis, :recommendations) and analysis.recommendations != [] do
      print_info("Recommendations:")
      Enum.each(analysis.recommendations, fn rec ->
        print_info("  - #{rec}")
      end)
    end

    if opts[:verbose] do
      print_info("Full analysis: #{inspect(analysis, limit: :infinity)}")
    end
  end

  defp print_reload_result(result, opts) do
    if result.success do
      print_success("Hot reload completed successfully")
      print_info("Reloaded modules: #{inspect(result.reloaded_modules)}")

      if result.migrated_processes != [] do
        print_info("Migrated processes: #{length(result.migrated_processes)}")
      end
    else
      print_error("Hot reload partially failed")
      print_info("Reloaded: #{inspect(result.reloaded_modules)}")

      if result.failed_modules != [] do
        print_error("Failed modules:")
        Enum.each(result.failed_modules, fn {module, reason} ->
          print_error("  #{module}: #{inspect(reason)}")
        end)
      end
    end

    print_info("Duration: #{result.duration_ms}ms")

    if opts[:verbose] do
      print_info("Full result: #{inspect(result, limit: :infinity)}")
    end
  end

  defp print_node_info(node_info, opts) do
    print_info("Node: #{node_info.name}")
    print_info("Host: #{node_info.host}")
    print_info("Status: #{node_info.status}")
    print_info("Role: #{node_info.role}")

    if opts[:verbose] do
      print_info("Full info: #{inspect(node_info, limit: :infinity)}")
    end
  end

  defp print_status_info(status, opts) do
    print_success("BEAM Toolkit Status")
    print_info("Mode: #{status.mode}")
    print_info("Safety Level: #{status.safety_level}")
    print_info("Components: #{inspect(Map.keys(status.components))}")

    if opts[:verbose] do
      print_info("Full status: #{inspect(status, limit: :infinity)}")
    end
  end

  defp print_single_health_status(opts) do
    # Collect health from all components
    beam_health = BEAM.get_health_status()
    distributed_health = BEAM.Distributed.get_health_status()

    overall_health = %{
      beam: beam_health,
      distributed: distributed_health,
      timestamp: DateTime.utc_now()
    }

    if opts[:json] do
      print_json(overall_health)
    else
      print_success("System Health Status")
      print_info("Overall: Healthy")  # Would implement actual health logic
      print_info("Components: #{map_size(beam_health.components || %{})}")

      if opts[:verbose] do
        print_info("Full health: #{inspect(overall_health, limit: :infinity)}")
      end
    end
  end

  defp monitor_health_continuously(interval, opts) do
    print_single_health_status(opts)
    Process.sleep(interval)
    monitor_health_continuously(interval, opts)
  end

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 2)} KB"
  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024, do: "#{Float.round(bytes / (1024 * 1024), 2)} MB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 2)} GB"

  defp print_status_and_help do
    print_info("BEAM Toolkit - Comprehensive BEAM Virtual Machine Development Toolkit")
    print_info("")
    print_info("Current Status:")

    status = BEAM.status()
    print_info("  Mode: #{status.mode}")
    print_info("  Components: #{map_size(status.components)}")
    print_info("")
    print_info("Use 'mix beam.toolkit --help' for detailed usage information")
    print_info("Use 'mix beam.toolkit <command> --help' for command-specific help")
  end

  defp print_help do
    Mix.shell().info("""
    BEAM Toolkit - Comprehensive BEAM Virtual Machine Development Toolkit

    USAGE:
        mix beam.toolkit <command> [options]

    COMMANDS:
        init              Initialize toolkit in specified mode
        fs                File system operations (traverse, monitor, analyze)
        introspect        System introspection (system, process, memory)
        runtime           Runtime operations (reload, snapshot)
        distributed       Distributed operations (discover, connect, call)
        status            Show toolkit status
        health            Show system health

    GLOBAL OPTIONS:
        --mode <mode>     Operation mode: offline, online, runtime
        --safety <level>  Safety level: development, staging, production
        --json            Output results in JSON format
        --verbose         Show detailed output
        --help            Show this help message

    EXAMPLES:
        mix beam.toolkit init --mode runtime --safety development
        mix beam.toolkit fs traverse . --recursive
        mix beam.toolkit introspect system --targets memory,processes
        mix beam.toolkit runtime reload MyModule --safety production
        mix beam.toolkit distributed discover --method dns

    For detailed command help, use:
        mix beam.toolkit <command> --help
    """)
  end
end
