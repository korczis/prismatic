defmodule Mix.Tasks.Prismatic.Consolidation.Status do
  @moduledoc """
  Shows comprehensive status and progress of Phase 2 consolidation.

  This task provides real-time status information about the consolidation progress,
  including analysis completion, conflict resolution status, migration progress,
  validation results, and overall system health.

  ## Usage

      mix prismatic.consolidation.status [OPTIONS]

  ## Options

    * `--output-dir, -o` - Output directory for status reports (default: consolidation/phase2/status)
    * `--format, -f` - Output format: console, json, markdown (default: console)
    * `--detailed, -d` - Show detailed status information
    * `--refresh-interval` - Auto-refresh interval in seconds (for continuous monitoring)
    * `--dashboard` - Launch interactive dashboard mode
    * `--export` - Export status to file
    * `--verbose, -v` - Enable verbose output
    * `--help, -h` - Show this help

  ## Status Categories

  The task reports on several key areas:

    * **Phase 2 Progress** - Overall consolidation progress percentage
    * **Analysis Status** - Dependency analysis completion and results
    * **Conflict Resolution** - Resolution progress and automation rate
    * **Migration Planning** - Migration plan status and readiness
    * **Validation Status** - Validation framework results
    * **System Health** - Compilation, tests, and dependency health

  ## Examples

      # Basic status check
      mix prismatic.consolidation.status

      # Detailed status with JSON export
      mix prismatic.consolidation.status --detailed --format=json --export

      # Continuous monitoring (refreshes every 30 seconds)
      mix prismatic.consolidation.status --refresh-interval=30

  ## Status Indicators

  The status uses clear visual indicators:

    * ✅ **Complete** - Task completed successfully
    * 🚀 **In Progress** - Task currently executing
    * ⏳ **Pending** - Task not yet started
    * ⚠️  **Warning** - Task completed with issues
    * ❌ **Failed** - Task failed or has critical issues

  For detailed troubleshooting, use `--verbose` flag or check log files.
  """

  @shortdoc "Show consolidation status and progress"

  use Mix.Task
  require Logger

  @switches [
    output_dir: :string,
    format: :string,
    detailed: :boolean,
    refresh_interval: :integer,
    dashboard: :boolean,
    export: :boolean,
    verbose: :boolean,
    help: :boolean
  ]

  @aliases [
    o: :output_dir,
    f: :format,
    d: :detailed,
    v: :verbose,
    h: :help
  ]

  @impl Mix.Task
  def run(args) do
    {options, _remaining_args, _invalid} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    if options[:help] do
      print_help()
    else
      if options[:dashboard] do
        launch_dashboard(options)
      elsif options[:refresh_interval] do
        continuous_monitoring(options)
      else
        show_status(options)
      end
    end
  end

  defp show_status(options) do
    Mix.shell().info([:blue, "📊 Checking Phase 2 consolidation status", :reset])

    status = collect_status_information()

    case options[:format] do
      "json" -> output_json_status(status, options)
      "markdown" -> output_markdown_status(status, options)
      _ -> output_console_status(status, options)
    end

    if options[:export] do
      export_status_files(status, options)
    end

    # Set appropriate exit code based on status
    exit_code = determine_exit_code(status)
    if exit_code != 0 do
      System.halt(exit_code)
    end
  end

  defp collect_status_information do
    %{
      timestamp: DateTime.utc_now(),
      phase2_status: check_phase2_status(),
      dependency_conflicts: check_dependency_conflicts(),
      migration_progress: check_migration_progress(),
      validation_status: check_validation_status(),
      system_health: check_system_health()
    }
  end

  defp check_phase2_status do
    analysis_exists = File.exists?("consolidation/phase2/analysis/dependency_graph.json")
    resolutions_exist = File.exists?("consolidation/phase2/resolutions/conflict_resolutions.json")
    migration_exists = File.exists?("consolidation/phase2/migration/migration_plan.json")
    execution_exists = File.exists?("consolidation/phase2/execution/consolidation_result.json")

    completed_tasks = [analysis_exists, resolutions_exist, migration_exists, execution_exists]
    progress = calculate_progress(completed_tasks)

    %{
      overall_progress: progress,
      analysis_completed: analysis_exists,
      resolutions_completed: resolutions_exist,
      migration_planned: migration_exists,
      execution_completed: execution_exists,
      current_phase: determine_current_phase(completed_tasks)
    }
  end

  defp check_dependency_conflicts do
    case System.cmd("mix", ["deps.tree"], stderr_to_stdout: true) do
      {output, 0} ->
        conflicts = if String.contains?(output, ["conflict", "Conflict"]) do
          extract_conflicts_from_output(output)
        else
          []
        end

        %{
          status: if(length(conflicts) == 0, do: :resolved, else: :conflicts_exist),
          conflict_count: length(conflicts),
          conflicts: conflicts
        }

      {_output, _code} ->
        %{status: :unknown, error: "Could not check dependencies", conflict_count: 0}
    end
  end

  defp check_migration_progress do
    if File.exists?("consolidation/phase2/migration/migration_plan.json") do
      execution_exists = File.exists?("consolidation/phase2/execution/consolidation_result.json")

      migration_status = cond do
        execution_exists -> :completed
        File.exists?("consolidation/phase2/execution") -> :in_progress
        true -> :planned
      end

      %{
        plan_exists: true,
        execution_started: execution_exists,
        status: migration_status
      }
    else
      %{
        plan_exists: false,
        execution_started: false,
        status: :not_started
      }
    end
  end

  defp check_validation_status do
    validation_file = "consolidation/phase2/validation/validation_results.json"

    if File.exists?(validation_file) do
      validation_data = validation_file
      |> File.read!()
      |> Jason.decode!(keys: :atoms)

      %{
        validations_run: true,
        overall_status: validation_data.overall_status,
        last_run: validation_data.timestamp
      }
    else
      %{
        validations_run: false,
        overall_status: :unknown,
        last_run: nil
      }
    end
  end

  defp check_system_health do
    health_checks = [
      check_compilation_health(),
      check_dependency_health(),
      check_test_health()
    ]

    overall_health = cond do
      Enum.all?(health_checks, &(&1.status == :healthy)) -> :healthy
      Enum.any?(health_checks, &(&1.status == :critical)) -> :critical
      true -> :degraded
    end

    %{
      overall_health: overall_health,
      health_checks: health_checks
    }
  end

  defp output_console_status(status, options) do
    Mix.shell().info([
      :cyan, "\n📊 Phase 2 Consolidation Status Report", :reset, "\n",
      :cyan, "Generated: #{DateTime.to_string(status.timestamp)}", :reset, "\n\n",

      :bright, "🎯 Overall Progress: #{status.phase2_status.overall_progress}%", :reset, "\n\n",

      "📈 Analysis: #{format_status_icon(status.phase2_status.analysis_completed)} ",
      if(status.phase2_status.analysis_completed, do: "Complete", else: "Pending"), "\n",

      "🔧 Conflict Resolution: #{format_status_icon(status.phase2_status.resolutions_completed)} ",
      if(status.phase2_status.resolutions_completed, do: "Complete", else: "Pending"), "\n",

      "📋 Migration Planning: #{format_status_icon(status.phase2_status.migration_planned)} ",
      format_migration_status(status.migration_progress.status), "\n",

      "✅ Validation: #{format_validation_status(status.validation_status.overall_status)}\n",

      "🏥 System Health: #{format_health_status(status.system_health.overall_health)}\n\n"
    ])

    if status.dependency_conflicts.status == :conflicts_exist do
      Mix.shell().info([
        :yellow, "⚠️  #{status.dependency_conflicts.conflict_count} dependency conflicts detected", :reset, "\n"
      ])
    end

    if options[:detailed] do
      show_detailed_status(status)
    end

    show_next_steps(status)
  end

  defp show_detailed_status(status) do
    Mix.shell().info([
      :bright, "\n📋 Detailed Status Information", :reset, "\n"
    ])

    # System health details
    Mix.shell().info([
      "System Health Details:\n"
    ])

    status.system_health.health_checks
    |> Enum.each(fn check ->
      Mix.shell().info([
        "  • #{check.check}: #{format_health_status(check.status)}\n"
      ])
    end)
  end

  defp show_next_steps(status) do
    next_steps = determine_next_steps(status)

    if length(next_steps) > 0 do
      Mix.shell().info([
        :bright, "\n🚀 Recommended Next Steps:", :reset, "\n"
      ])

      next_steps
      |> Enum.with_index(1)
      |> Enum.each(fn {step, index} ->
        Mix.shell().info("  #{index}. #{step}\n")
      end)
    end
  end

  defp determine_next_steps(status) do
    cond do
      not status.phase2_status.analysis_completed ->
        ["Run dependency analysis: mix prismatic.consolidation.analyze"]

      not status.phase2_status.resolutions_completed ->
        ["Execute conflict resolution: mix prismatic.consolidation.resolve"]

      not status.phase2_status.migration_planned ->
        ["Generate migration plan: mix prismatic.consolidation.plan"]

      status.dependency_conflicts.status == :conflicts_exist ->
        ["Resolve remaining dependency conflicts"]

      status.system_health.overall_health != :healthy ->
        ["Address system health issues", "Run validation: mix prismatic.consolidation.validate"]

      not status.phase2_status.execution_completed ->
        ["Execute consolidation: mix prismatic.consolidation.execute --dry-run"]

      true ->
        ["Phase 2 consolidation appears complete!", "Generate final reports: mix prismatic.consolidation.report"]
    end
  end

  # Helper functions for status checking
  defp calculate_progress(completion_flags) do
    completed = Enum.count(completion_flags, & &1)
    total = length(completion_flags)
    round(completed / total * 100)
  end

  defp determine_current_phase([true, false, false, false]), do: "Conflict Resolution"
  defp determine_current_phase([true, true, false, false]), do: "Migration Planning"
  defp determine_current_phase([true, true, true, false]), do: "Execution"
  defp determine_current_phase([true, true, true, true]), do: "Complete"
  defp determine_current_phase(_), do: "Analysis"

  defp extract_conflicts_from_output(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, ["conflict", "Conflict"]))
    |> Enum.take(10)
  end

  defp check_compilation_health do
    case System.cmd("mix", ["compile", "--warnings-as-errors"], stderr_to_stdout: true) do
      {_output, 0} -> %{check: :compilation, status: :healthy, message: "Compilation successful"}
      {output, _code} -> %{check: :compilation, status: :unhealthy, message: "Compilation failed", details: String.slice(output, 0, 200)}
    end
  end

  defp check_dependency_health do
    case System.cmd("mix", ["deps.get"], stderr_to_stdout: true) do
      {_output, 0} -> %{check: :dependencies, status: :healthy, message: "Dependencies resolved"}
      {output, _code} -> %{check: :dependencies, status: :unhealthy, message: "Dependency issues", details: String.slice(output, 0, 200)}
    end
  end

  defp check_test_health do
    case System.cmd("mix", ["test", "--max-failures=1"], stderr_to_stdout: true) do
      {_output, 0} -> %{check: :tests, status: :healthy, message: "All tests passing"}
      {output, _code} -> %{check: :tests, status: :unhealthy, message: "Test failures", details: String.slice(output, 0, 200)}
    end
  end

  defp format_status_icon(true), do: "✅"
  defp format_status_icon(false), do: "⏳"

  defp format_migration_status(:not_started), do: "⏳ Not Started"
  defp format_migration_status(:planned), do: "📋 Planned"
  defp format_migration_status(:in_progress), do: "🚀 In Progress"
  defp format_migration_status(:completed), do: "✅ Complete"
  defp format_migration_status(_), do: "❓ Unknown"

  defp format_validation_status(:all_passed), do: "✅ All Passed"
  defp format_validation_status(:mostly_passed), do: "⚠️ Mostly Passed"
  defp format_validation_status(:failed), do: "❌ Failed"
  defp format_validation_status(_), do: "⏳ Pending"

  defp format_health_status(:healthy), do: "✅ Healthy"
  defp format_health_status(:degraded), do: "⚠️ Degraded"
  defp format_health_status(:critical), do: "🔴 Critical"
  defp format_health_status(:unhealthy), do: "❌ Unhealthy"
  defp format_health_status(_), do: "❓ Unknown"

  defp output_json_status(status, _options) do
    json_output = Jason.encode!(status, pretty: true)
    Mix.shell().info(json_output)
  end

  defp output_markdown_status(status, _options) do
    markdown = """
    # Phase 2 Consolidation Status

    **Generated:** #{DateTime.to_string(status.timestamp)}

    ## Overall Progress: #{status.phase2_status.overall_progress}%

    ### Component Status
    - Analysis: #{if status.phase2_status.analysis_completed, do: "✅ Complete", else: "⏳ Pending"}
    - Conflict Resolution: #{if status.phase2_status.resolutions_completed, do: "✅ Complete", else: "⏳ Pending"}
    - Migration Planning: #{format_migration_status(status.migration_progress.status)}
    - System Health: #{format_health_status(status.system_health.overall_health)}

    ### Dependency Conflicts
    - Status: #{status.dependency_conflicts.status}
    - Count: #{status.dependency_conflicts.conflict_count}

    ### Next Steps
    #{determine_next_steps(status) |> Enum.map(&("- #{&1}")) |> Enum.join("\n")}
    """

    Mix.shell().info(markdown)
  end

  defp export_status_files(status, options) do
    output_dir = ensure_output_directory(options[:output_dir] || "consolidation/phase2/status")

    # Export JSON status
    json_file = Path.join(output_dir, "status_report.json")
    File.write!(json_file, Jason.encode!(status, pretty: true))

    Mix.shell().info("📁 Status exported to: #{output_dir}")
  end

  defp determine_exit_code(status) do
    cond do
      status.system_health.overall_health == :critical -> 2
      status.system_health.overall_health == :unhealthy -> 1
      status.dependency_conflicts.status == :conflicts_exist and status.dependency_conflicts.conflict_count > 10 -> 1
      true -> 0
    end
  end

  defp ensure_output_directory(path) do
    File.mkdir_p!(path)
    path
  end

  defp continuous_monitoring(options) do
    interval = options[:refresh_interval] * 1000  # Convert to milliseconds
    Mix.shell().info("🔄 Starting continuous monitoring (refresh every #{options[:refresh_interval]}s)")
    Mix.shell().info("Press Ctrl+C to stop")

    monitor_loop(options, interval)
  end

  defp monitor_loop(options, interval) do
    # Clear screen and show status
    IO.write("\e[2J\e[H")  # ANSI clear screen and move cursor to top
    show_status(options)

    :timer.sleep(interval)
    monitor_loop(options, interval)
  end

  defp launch_dashboard(_options) do
    Mix.shell().info("🚧 Dashboard mode not yet implemented")
    Mix.shell().info("Use --refresh-interval for continuous monitoring")
  end

  defp print_help do
    Mix.shell().info([
      :bright, "mix prismatic.consolidation.status", :reset, " - Consolidation Status\n\n",
      "Shows comprehensive status and progress of Phase 2 consolidation.\n\n",

      :bright, "USAGE:", :reset, "\n",
      "  mix prismatic.consolidation.status [OPTIONS]\n\n",

      :bright, "OPTIONS:", :reset, "\n",
      "  --output-dir, -o DIR       Output directory for status reports\n",
      "  --format, -f FORMAT        Output format (console/json/markdown)\n",
      "  --detailed, -d             Show detailed status information\n",
      "  --refresh-interval SEC     Auto-refresh interval in seconds\n",
      "  --dashboard                Launch interactive dashboard\n",
      "  --export                   Export status to files\n",
      "  --verbose, -v              Enable verbose output\n",
      "  --help, -h                 Show this help\n\n",

      :bright, "EXAMPLES:", :reset, "\n",
      "  # Basic status check\n",
      "  mix prismatic.consolidation.status\n\n",
      "  # Detailed status with export\n",
      "  mix prismatic.consolidation.status --detailed --export\n\n",
      "  # Continuous monitoring\n",
      "  mix prismatic.consolidation.status --refresh-interval=30\n\n",
      "  # JSON output for automation\n",
      "  mix prismatic.consolidation.status --format=json\n\n"
    ])
  end
end
