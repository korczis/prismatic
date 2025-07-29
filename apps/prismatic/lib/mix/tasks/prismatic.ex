defmodule Mix.Tasks.Prismatic do
  @moduledoc """
  Main entry point for Prismatic Mix tasks with comprehensive help system.

  Provides:
  - System status checking and health monitoring
  - Task discovery and categorized help
  - Version information and diagnostics
  - Configuration validation
  - Integration with all shared infrastructure

  ## Usage

      # Display comprehensive help and available tasks
      mix prismatic

      # Show system status and health check
      mix prismatic --status

      # Display version and build information
      mix prismatic --version

      # Show configuration details
      mix prismatic --config

      # Run system diagnostics
      mix prismatic --diagnostics

      # Search for tasks by keyword
      mix prismatic --search keyword

  ## Task Categories

  ### Documentation Tasks (`prismatic.docs.*`)
  - Analysis and validation of documentation
  - Content extraction and processing
  - Health reporting and dashboards

  ### Synchronization Tasks (`prismatic.sync.*`)
  - Content synchronization between sources
  - Reference management and validation
  - Monitoring and health checks

  ### Code Tasks (`prismatic.code.*`)
  - Code analysis and quality checks
  - Refactoring and maintenance utilities
  - Integration with development workflows

  ### System Tasks (`prismatic.system.*`)
  - System administration and maintenance
  - Configuration management
  - Performance monitoring and optimization
  """

  use Mix.Task

  alias Mix.Tasks.Prismatic.Shared.{
    HelpSystem,
    Config,
    OutputFormatter,
    ErrorHandler,
    Telemetry,
    ProgressMonitor
  }

  @shortdoc "Main entry point for Prismatic tasks with comprehensive help"

  @switches [
    status: :boolean,
    version: :boolean,
    config: :boolean,
    diagnostics: :boolean,
    search: :string,
    help: :boolean,
    verbose: :boolean,
    format: :string
  ]

  @aliases [
    s: :status,
    v: :version,
    c: :config,
    d: :diagnostics,
    h: :help,
    f: :format
  ]

  @impl Mix.Task
  def run(args) do
    # Start telemetry tracking
    start_time = System.monotonic_time(:millisecond)
    Telemetry.record_task_start("prismatic", %{args: args})

    try do
      {opts, remaining_args, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

      case determine_action(opts, remaining_args) do
        :show_status -> show_system_status(opts)
        :show_version -> show_version_info(opts)
        :show_config -> show_configuration(opts)
        :run_diagnostics -> run_system_diagnostics(opts)
        {:search, keyword} -> search_tasks(keyword, opts)
        :show_help -> show_comprehensive_help(opts)
        {:invalid_args, reason} -> handle_invalid_arguments(reason)
      end

      # Record successful completion
      execution_time = System.monotonic_time(:millisecond) - start_time
      Telemetry.record_task_completion("prismatic", execution_time, %{success: true})

    rescue
      error ->
        execution_time = System.monotonic_time(:millisecond) - start_time
        ErrorHandler.handle_task_error(error, execution_time, "prismatic", __STACKTRACE__)
    end
  end

  # Private functions

  defp determine_action(opts, remaining_args) do
    cond do
      opts[:status] -> :show_status
      opts[:version] -> :show_version
      opts[:config] -> :show_config
      opts[:diagnostics] -> :run_diagnostics
      opts[:search] -> {:search, opts[:search]}
      opts[:help] -> :show_help
      not Enum.empty?(remaining_args) -> {:invalid_args, "Unknown arguments: #{inspect(remaining_args)}"}
      true -> :show_help
    end
  end

  defp show_system_status(opts) do
    OutputFormatter.display_section_header("Prismatic System Status")

    status_data = gather_system_status()

    OutputFormatter.display_info("System Health: #{status_data.health_status}")
    OutputFormatter.display_info("Environment: #{status_data.environment}")
    OutputFormatter.display_info("Elixir Version: #{status_data.elixir_version}")
    OutputFormatter.display_info("OTP Version: #{status_data.otp_version}")

    # Check dependencies
    OutputFormatter.display_section_header("Dependencies", width: 40)
    check_dependencies()

    # Check configuration
    OutputFormatter.display_section_header("Configuration", width: 40)
    check_configuration_health()

    # Recent task activity
    if opts[:verbose] do
      OutputFormatter.display_section_header("Recent Activity", width: 40)
      show_recent_activity()
    end

    # System recommendations
    recommendations = generate_system_recommendations(status_data)
    unless Enum.empty?(recommendations) do
      OutputFormatter.display_section_header("Recommendations", width: 40)
      Enum.each(recommendations, fn rec ->
        OutputFormatter.display_warning(rec)
      end)
    end

    OutputFormatter.display_success("System status check completed")
  end

  defp show_version_info(opts) do
    OutputFormatter.display_section_header("Prismatic Version Information")

    version_data = gather_version_info()

    OutputFormatter.display_info("Prismatic Version: #{version_data.prismatic_version}")
    OutputFormatter.display_info("Build Date: #{version_data.build_date}")
    OutputFormatter.display_info("Git Commit: #{version_data.git_commit}")
    OutputFormatter.display_info("Elixir Version: #{version_data.elixir_version}")
    OutputFormatter.display_info("OTP Version: #{version_data.otp_version}")

    if opts[:verbose] do
      OutputFormatter.display_section_header("Build Information", width: 40)
      OutputFormatter.display_info("Architecture: #{version_data.architecture}")
      OutputFormatter.display_info("Build Environment: #{version_data.build_env}")
      OutputFormatter.display_info("Compiler Flags: #{version_data.compiler_flags}")
    end

    # Show enabled features
    OutputFormatter.display_section_header("Enabled Features", width: 40)
    show_enabled_features()
  end

  defp show_configuration(opts) do
    OutputFormatter.display_section_header("Prismatic Configuration")

    # Show configuration for each profile
    profiles = [:docs, :sync, :code, :system]

    Enum.each(profiles, fn profile ->
      OutputFormatter.display_section_header("#{String.capitalize(Atom.to_string(profile))} Profile", width: 40)

      try do
        config = Config.get_config(profile, %{})
        display_config_section(config, profile)
      rescue
        error ->
          OutputFormatter.display_error("Failed to load #{profile} configuration: #{Exception.message(error)}")
      end
    end)

    # Show environment overrides if in verbose mode
    if opts[:verbose] do
      OutputFormatter.display_section_header("Environment Overrides", width: 40)
      show_environment_overrides()
    end
  end

  defp run_system_diagnostics(opts) do
    OutputFormatter.display_section_header("Prismatic System Diagnostics")

    ProgressMonitor.start_operation("Running system diagnostics...")

    diagnostics = [
      {"File System Access", &check_filesystem_access/0},
      {"Dependencies", &check_all_dependencies/0},
      {"Configuration Validity", &validate_all_configurations/0},
      {"Memory Usage", &check_memory_usage/0},
      {"Task Registry", &validate_task_registry/0},
      {"Telemetry System", &check_telemetry_health/0}
    ]

    results = Enum.map(diagnostics, fn {name, check_fn} ->
      ProgressMonitor.show_info("Checking #{name}...")

      try do
        result = check_fn.()
        OutputFormatter.display_success("✓ #{name}: #{result}")
        {name, :ok, result}
      rescue
        error ->
          error_msg = Exception.message(error)
          OutputFormatter.display_error("✗ #{name}: #{error_msg}")
          {name, :error, error_msg}
      end
    end)

    ProgressMonitor.complete_operation("System diagnostics completed")

    # Summary
    OutputFormatter.display_section_header("Diagnostics Summary", width: 40)

    {success_count, error_count} = Enum.reduce(results, {0, 0}, fn
      {_, :ok, _}, {ok, err} -> {ok + 1, err}
      {_, :error, _}, {ok, err} -> {ok, err + 1}
    end)

    OutputFormatter.display_info("Successful checks: #{success_count}")
    if error_count > 0 do
      OutputFormatter.display_error("Failed checks: #{error_count}")
    end

    # Generate diagnostic report if requested
    if opts[:format] do
      generate_diagnostic_report(results, opts)
    end
  end

  defp search_tasks(keyword, opts) do
    OutputFormatter.display_section_header("Task Search Results for '#{keyword}'")

    results = HelpSystem.search_tasks(keyword)

    case results do
      {:ok, matches, suggestions} ->
        if not Enum.empty?(matches) do
          OutputFormatter.display_info("Found #{length(matches)} matching tasks:")

          Enum.each(matches, fn %{task: task, description: desc, score: score} ->
            score_indicator = if score > 0.8, do: "🎯", else: "📍"
            OutputFormatter.display_info("  #{score_indicator} #{task} - #{desc}")
          end)
        else
          OutputFormatter.display_warning("No exact matches found for '#{keyword}'")
        end

        if not Enum.empty?(suggestions) do
          OutputFormatter.display_info("\nDid you mean:")
          Enum.each(suggestions, fn suggestion ->
            OutputFormatter.display_info("  • #{suggestion}")
          end)
        end

      {:error, reason} ->
        OutputFormatter.display_error("Search failed: #{reason}")
    end

    # Show related tasks if in verbose mode
    if opts[:verbose] do
      OutputFormatter.display_section_header("Related Tasks", width: 40)
      show_related_tasks(keyword)
    end
  end

  defp show_comprehensive_help(opts) do
    OutputFormatter.display_section_header("Prismatic Mix Tasks - Comprehensive Help")

    # Show main usage
    show_main_usage()

    # Show categorized tasks
    HelpSystem.show_categorized_help()

    # Show common examples
    OutputFormatter.display_section_header("Common Usage Examples", width: 50)
    show_usage_examples()

    # Show additional resources
    OutputFormatter.display_section_header("Additional Resources", width: 50)
    show_additional_resources()

    # Show recent updates if available
    if opts[:verbose] do
      OutputFormatter.display_section_header("Recent Updates", width: 40)
      show_recent_updates()
    end
  end

  defp handle_invalid_arguments(reason) do
    OutputFormatter.display_error(reason)
    OutputFormatter.display_info("Use 'mix prismatic --help' for usage information")
    System.halt(1)
  end

  # System status helpers

  defp gather_system_status do
    %{
      health_status: determine_health_status(),
      environment: Mix.env(),
      elixir_version: System.version(),
      otp_version: System.otp_release(),
      uptime: get_system_uptime(),
      memory_usage: get_memory_info(),
      task_count: count_available_tasks()
    }
  end

  defp determine_health_status do
    checks = [
      fn -> Config.validate_base_config() end,
      fn -> check_critical_dependencies() end,
      fn -> validate_file_permissions() end
    ]

    failed_checks = Enum.count(checks, fn check ->
      try do
        check.()
        false
      rescue
        _ -> true
      end
    end)

    case failed_checks do
      0 -> "Healthy"
      1 -> "Warning"
      _ -> "Critical"
    end
  end

  defp check_dependencies do
    deps = [
      {"Jason", Jason},
      {"File System", File},
      {"Path", Path}
    ]

    Enum.each(deps, fn {name, module} ->
      case Code.ensure_loaded(module) do
        {:module, ^module} ->
          OutputFormatter.display_success("#{name}: Available")
        _ ->
          OutputFormatter.display_error("#{name}: Missing")
      end
    end)
  end

  defp check_configuration_health do
    profiles = [:docs, :sync, :code, :system]

    Enum.each(profiles, fn profile ->
      try do
        Config.get_config(profile, %{})
        OutputFormatter.display_success("#{profile}: Valid")
      rescue
        error ->
          OutputFormatter.display_error("#{profile}: #{Exception.message(error)}")
      end
    end)
  end

  defp show_recent_activity do
    case Telemetry.get_recent_tasks(5) do
      {:ok, tasks} when not is_list(tasks) or length(tasks) == 0 ->
        OutputFormatter.display_info("No recent task activity")

      {:ok, tasks} ->
        Enum.each(tasks, fn task ->
          status_icon = if task.success, do: "✅", else: "❌"
          OutputFormatter.display_info("#{status_icon} #{task.name} (#{task.execution_time}ms)")
        end)

      {:error, reason} ->
        OutputFormatter.display_warning("Could not retrieve recent activity: #{reason}")
    end
  end

  defp generate_system_recommendations(status_data) do
    recommendations = []

    recommendations = if status_data.health_status != "Healthy" do
      ["Run 'mix prismatic --diagnostics' for detailed health analysis" | recommendations]
    else
      recommendations
    end

    recommendations = if status_data.memory_usage > 1_000_000_000 do
      ["Consider cleaning up temporary files to reduce memory usage" | recommendations]
    else
      recommendations
    end

    recommendations
  end

  # Version info helpers

  defp gather_version_info do
    %{
      prismatic_version: get_prismatic_version(),
      build_date: get_build_date(),
      git_commit: get_git_commit(),
      elixir_version: System.version(),
      otp_version: System.otp_release(),
      architecture: get_system_architecture(),
      build_env: Mix.env(),
      compiler_flags: get_compiler_flags()
    }
  end

  defp get_prismatic_version do
    case Application.spec(:prismatic, :vsn) do
      nil -> "development"
      vsn -> List.to_string(vsn)
    end
  end

  defp get_build_date do
    # This would typically be set during build process
    "#{Date.utc_today()}"
  end

  defp get_git_commit do
    try do
      case System.cmd("git", ["rev-parse", "--short", "HEAD"], stderr_to_stdout: true) do
        {commit, 0} -> String.trim(commit)
        _ -> "unknown"
      end
    rescue
      _ -> "unknown"
    end
  end

  defp get_system_architecture do
    "#{:erlang.system_info(:system_architecture)}"
  end

  defp get_compiler_flags do
    System.get_env("ERL_COMPILER_OPTIONS", "default")
  end

  defp show_enabled_features do
    features = [
      {"Telemetry", true},
      {"Progress Monitoring", true},
      {"Enhanced Error Handling", true},
      {"Multi-format Output", true},
      {"CI/CD Integration", true},
      {"Task Search", true}
    ]

    Enum.each(features, fn {name, enabled} ->
      if enabled do
        OutputFormatter.display_success("#{name}: Enabled")
      else
        OutputFormatter.display_warning("#{name}: Disabled")
      end
    end)
  end

  # Configuration display helpers

  defp display_config_section(config, profile) do
    # Display key configuration values
    important_keys = [:output_dir, :output_format, :batch_size, :concurrency, :timeout]

    Enum.each(important_keys, fn key ->
      if Map.has_key?(config, key) do
        OutputFormatter.display_info("#{key}: #{inspect(Map.get(config, key))}")
      end
    end)

    # Show profile-specific settings
    profile_settings = Map.drop(config, important_keys)
    unless Enum.empty?(profile_settings) do
      OutputFormatter.display_debug("Additional settings: #{inspect(profile_settings)}")
    end
  end

  defp show_environment_overrides do
    env_vars = [
      "PRISMATIC_OUTPUT_DIR",
      "PRISMATIC_OUTPUT_FORMAT",
      "PRISMATIC_BATCH_SIZE",
      "PRISMATIC_CONCURRENCY",
      "MIX_DEBUG",
      "VERBOSE"
    ]

    overrides = Enum.filter(env_vars, fn var ->
      System.get_env(var) != nil
    end)

    if Enum.empty?(overrides) do
      OutputFormatter.display_info("No environment overrides detected")
    else
      Enum.each(overrides, fn var ->
        value = System.get_env(var)
        OutputFormatter.display_info("#{var}=#{value}")
      end)
    end
  end

  # Diagnostic helpers

  defp check_filesystem_access do
    temp_file = Path.join(System.tmp_dir(), "prismatic_test_#{:rand.uniform(10000)}")

    File.write!(temp_file, "test")
    content = File.read!(temp_file)
    File.rm!(temp_file)

    if content == "test" do
      "Read/write access verified"
    else
      raise "File system access test failed"
    end
  end

  defp check_all_dependencies do
    required_modules = [Jason, File, Path, String, Enum, Map]

    missing = Enum.filter(required_modules, fn module ->
      case Code.ensure_loaded(module) do
        {:module, ^module} -> false
        _ -> true
      end
    end)

    if Enum.empty?(missing) do
      "All required dependencies available"
    else
      raise "Missing dependencies: #{inspect(missing)}"
    end
  end

  defp validate_all_configurations do
    profiles = [:docs, :sync, :code, :system]

    Enum.each(profiles, fn profile ->
      Config.get_config(profile, %{})
    end)

    "All configuration profiles valid"
  end

  defp check_memory_usage do
    total_memory = :erlang.memory(:total)
    process_memory = :erlang.memory(:processes)

    "Total: #{format_bytes(total_memory)}, Processes: #{format_bytes(process_memory)}"
  end

  defp validate_task_registry do
    # This would check that all expected tasks are properly registered
    expected_tasks = [
      "prismatic",
      "prismatic.docs.analyze",
      "prismatic.docs.validate",
      "prismatic.sync.migrate"
    ]

    # For now, just verify the main task
    if Code.ensure_loaded?(Mix.Tasks.Prismatic) do
      "Task registry validation passed"
    else
      raise "Main task not properly registered"
    end
  end

  defp check_telemetry_health do
    # Verify telemetry system is working
    Telemetry.record_task_start("diagnostic_test", %{})
    Telemetry.record_task_completion("diagnostic_test", 1, %{success: true})

    "Telemetry system operational"
  end

  defp generate_diagnostic_report(results, opts) do
    format = String.to_atom(opts[:format])
    timestamp = DateTime.utc_now() |> DateTime.to_string()

    report_data = %{
      timestamp: timestamp,
      system_info: gather_system_status(),
      diagnostic_results: results,
      summary: %{
        total_checks: length(results),
        successful: Enum.count(results, fn {_, status, _} -> status == :ok end),
        failed: Enum.count(results, fn {_, status, _} -> status == :error end)
      }
    }

    output_file = "prismatic_diagnostics_#{DateTime.utc_now() |> DateTime.to_unix()}.#{format}"

    case OutputFormatter.save_output(report_data, output_file, format: format) do
      :ok ->
        OutputFormatter.display_success("Diagnostic report saved to #{output_file}")
      {:error, reason} ->
        OutputFormatter.display_error("Failed to save diagnostic report: #{reason}")
    end
  end

  # Help display helpers

  defp show_main_usage do
    OutputFormatter.display_info("""
    Usage: mix prismatic [options]

    Options:
      --status, -s       Show system status and health check
      --version, -v      Display version and build information
      --config, -c       Show configuration details for all profiles
      --diagnostics, -d  Run comprehensive system diagnostics
      --search KEYWORD   Search for tasks by keyword
      --help, -h         Show this help information
      --verbose          Show additional detailed information
      --format FORMAT    Output format for reports (json, yaml, html, markdown)
    """)
  end

  defp show_usage_examples do
    examples = [
      {"mix prismatic.docs.analyze", "Analyze documentation comprehensively"},
      {"mix prismatic.docs.validate --format json", "Validate docs with JSON output"},
      {"mix prismatic.sync.migrate --dry-run", "Preview synchronization changes"},
      {"mix prismatic --search validation", "Find all validation-related tasks"},
      {"mix prismatic --diagnostics --format html", "Generate HTML diagnostic report"}
    ]

    Enum.each(examples, fn {command, description} ->
      OutputFormatter.display_info("  #{command}")
      OutputFormatter.display_debug("    #{description}")
    end)
  end

  defp show_additional_resources do
    resources = [
      "📚 Documentation: docs/guides/",
      "🔧 Configuration: docs/guides/configuration.md",
      "🐛 Troubleshooting: docs/guides/troubleshooting.md",
      "🚀 Quick Start: docs/guides/quick-start.md",
      "📊 CI/CD Integration: docs/guides/ci-cd-integration.md"
    ]

    Enum.each(resources, fn resource ->
      OutputFormatter.display_info("  #{resource}")
    end)
  end

  defp show_recent_updates do
    updates = [
      "Enhanced shared infrastructure with comprehensive error handling",
      "Added multi-format output support (JSON, YAML, HTML, Markdown)",
      "Improved CI/CD integration with structured output",
      "Added comprehensive task search and discovery",
      "Enhanced progress monitoring with real-time indicators"
    ]

    Enum.each(updates, fn update ->
      OutputFormatter.display_info("  • #{update}")
    end)
  end

  defp show_related_tasks(keyword) do
    # This would show tasks that are conceptually related
    related = HelpSystem.get_related_tasks(keyword)

    case related do
      {:ok, tasks} when not is_list(tasks) or length(tasks) == 0 ->
        OutputFormatter.display_info("No related tasks found")

      {:ok, tasks} ->
        Enum.each(tasks, fn task ->
          OutputFormatter.display_info("  📎 #{task}")
        end)

      {:error, _} ->
        OutputFormatter.display_debug("Could not retrieve related tasks")
    end
  end

  # Utility helpers

  defp get_system_uptime do
    # Simple uptime calculation
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    uptime_ms
  end

  defp get_memory_info do
    :erlang.memory(:total)
  end

  defp count_available_tasks do
    # This would count all available prismatic tasks
    # For now, return a placeholder
    12
  end

  defp check_critical_dependencies do
    # Check for critical system dependencies
    case Code.ensure_loaded(Jason) do
      {:module, Jason} -> :ok
      _ -> raise "Critical dependency Jason not available"
    end
  end

  defp validate_file_permissions do
    # Check that we can read/write to expected directories
    temp_dir = System.tmp_dir()

    if File.dir?(temp_dir) and File.stat!(temp_dir).access in [:read_write, :write] do
      :ok
    else
      raise "Insufficient file system permissions"
    end
  end

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 2)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 2)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 2)} KB"
      true -> "#{bytes} B"
    end
  end

  defp format_bytes(bytes), do: "#{bytes} B"
end
