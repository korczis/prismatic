defmodule Mix.Tasks.Docs.Sync do
  @moduledoc """
  Comprehensive documentation-code synchronization system.

  This module provides command-line interface to all Phase 3 synchronization
  tools including code migration, reference replacement, bidirectional sync,
  version control integration, and drift prevention.

  ## Available Commands

  - `mix docs.sync` - Main synchronization dashboard and control
  - `mix docs.migrate_code` - Code migration framework operations
  - `mix docs.replace_references` - Reference replacement system
  - `mix docs.sync_bidirectional` - Bidirectional synchronization engine
  - `mix docs.setup_git_hooks` - Version control integration setup
  - `mix docs.monitor_drift` - Drift prevention and monitoring
  - `mix docs.health_report` - Generate comprehensive health reports
  """

  use Mix.Task

  @shortdoc "Comprehensive documentation-code synchronization (see --help for specific commands)"

  def run(args) do
    case args do
      [] ->
        show_help()
      ["--help"] ->
        show_help()
      [command | rest] ->
        execute_command(command, rest)
    end
  end

  defp show_help do
    IO.puts """
    #{IO.ANSI.cyan()}Prismatic Documentation-Code Synchronization System#{IO.ANSI.reset()}

    Available commands:
      mix docs.sync                 - Interactive synchronization dashboard
      mix docs.migrate_code         - Code migration framework operations
      mix docs.replace_references   - Reference replacement system
      mix docs.sync_bidirectional   - Bidirectional synchronization engine
      mix docs.setup_git_hooks      - Version control integration setup
      mix docs.monitor_drift        - Drift prevention and monitoring
      mix docs.health_report        - Generate comprehensive health reports

    Use 'mix docs.[command] --help' for command-specific options.

    #{IO.ANSI.yellow()}Quick Start Examples:#{IO.ANSI.reset()}
      mix docs.sync                           # Interactive dashboard
      mix docs.migrate_code --analyze         # Analyze migration candidates
      mix docs.replace_references --preview   # Preview reference replacements
      mix docs.sync_bidirectional --monitor   # Start real-time monitoring
      mix docs.setup_git_hooks --install      # Install Git hooks
      mix docs.monitor_drift --continuous     # Start drift monitoring
      mix docs.health_report --period=7d      # Generate 7-day health report

    #{IO.ANSI.green()}System Status:#{IO.ANSI.reset()}
      Run 'mix docs.sync status' for current synchronization health.
    """
  end

  defp execute_command(command, args) do
    case command do
      "migrate_code" -> Mix.Tasks.Docs.MigrateCode.run(args)
      "replace_references" -> Mix.Tasks.Docs.ReplaceReferences.run(args)
      "sync_bidirectional" -> Mix.Tasks.Docs.SyncBidirectional.run(args)
      "setup_git_hooks" -> Mix.Tasks.Docs.SetupGitHooks.run(args)
      "monitor_drift" -> Mix.Tasks.Docs.MonitorDrift.run(args)
      "health_report" -> Mix.Tasks.Docs.HealthReport.run(args)
      "status" -> show_sync_status()
      _ ->
        IO.puts "Unknown command: #{command}"
        show_help()
    end
  end

  defp show_sync_status do
    Mix.Task.run("app.start")

    IO.puts "#{IO.ANSI.cyan()}🔄 Synchronization System Status#{IO.ANSI.reset()}"
    IO.puts "═══════════════════════════════════════"

    # Check drift prevention system status
    try do
      alias Prismatic.Documentation.DriftPreventionSystem
      drift_analysis = DriftPreventionSystem.detect_drift()

      health_score = drift_analysis.overall_metrics.overall_health_score
      risk_level = drift_analysis.overall_metrics.risk_level

      {color, icon} = case risk_level do
        :low -> {IO.ANSI.green(), "✅"}
        :medium -> {IO.ANSI.yellow(), "⚠️"}
        :high -> {IO.ANSI.red(), "❌"}
        :critical -> {IO.ANSI.red(), "🚨"}
      end

      IO.puts "#{color}#{icon} Overall Health Score: #{health_score}% (#{risk_level})#{IO.ANSI.reset()}"
      IO.puts "📊 Analysis completed at: #{drift_analysis.analyzed_at}"

      if length(drift_analysis.alerts) > 0 do
        IO.puts "\n⚠️  Active Alerts: #{length(drift_analysis.alerts)}"
        Enum.take(drift_analysis.alerts, 3)
        |> Enum.each(fn alert ->
          IO.puts "   • #{alert.description}"
        end)
      else
        IO.puts "\n✅ No active alerts"
      end

    rescue
      _ ->
        IO.puts "❌ Could not retrieve system status"
    end

    IO.puts "\nRun 'mix docs.health_report' for detailed analysis."
  end
end

defmodule Mix.Tasks.Docs.MigrateCode do
  @moduledoc """
  Code Migration Framework operations.

  This task provides tools for identifying, analyzing, and executing code
  migrations from documentation to appropriate codebase locations.

  ## Options

    * `--analyze` - Analyze migration candidates without executing
    * `--execute` - Execute pending migrations
    * `--validate` - Validate migration candidates
    * `--rollback` - Rollback recent migrations
    * `--docs` - Documentation directory (default: docs)
    * `--code` - Code directory (default: apps)
    * `--output` - Output format: json, report (default: report)
    * `--file` - Output file path (default: migration-analysis.json)
    * `--dry-run` - Show what would be done without executing
    * `--verbose` - Enable verbose output

  ## Examples

      mix docs.migrate_code --analyze
      mix docs.migrate_code --execute --dry-run
      mix docs.migrate_code --rollback --migration-id abc123
      mix docs.migrate_code --validate --verbose
  """

  use Mix.Task
  alias Prismatic.Documentation.CodeMigrationFramework

  @shortdoc "Code migration framework operations"

  def run(args) do
    {options, _, _} = OptionParser.parse(args,
      switches: [
        analyze: :boolean,
        execute: :boolean,
        validate: :boolean,
        rollback: :boolean,
        docs: :string,
        code: :string,
        output: :string,
        file: :string,
        migration_id: :string,
        dry_run: :boolean,
        verbose: :boolean,
        help: :boolean
      ],
      aliases: [
        a: :analyze,
        e: :execute,
        v: :verbose,
        h: :help
      ]
    )

    if options[:help] do
      show_help()
    else
      run_migration_operations(options)
    end
  end

  defp show_help do
    IO.puts @moduledoc
  end

  defp run_migration_operations(options) do
    docs_path = options[:docs] || "docs"
    code_path = options[:code] || "apps"
    output_format = options[:output] || "report"
    output_file = options[:file] || "migration-analysis.json"
    verbose = options[:verbose] || false
    dry_run = options[:dry_run] || false

    Mix.Task.run("app.start")

    try do
      cond do
        options[:analyze] ->
          run_migration_analysis(docs_path, code_path, output_format, output_file, verbose)

        options[:execute] ->
          run_migration_execution(docs_path, code_path, dry_run, verbose)

        options[:validate] ->
          run_migration_validation(docs_path, code_path, verbose)

        options[:rollback] ->
          run_migration_rollback(options[:migration_id], verbose)

        true ->
          IO.puts "Please specify an operation: --analyze, --execute, --validate, or --rollback"
          show_help()
      end

    rescue
      error ->
        IO.puts "❌ Migration operation failed: #{Exception.message(error)}"
        if verbose do
          IO.puts Exception.format_stacktrace(__STACKTRACE__)
        end
        exit({:shutdown, 1})
    end
  end

  defp run_migration_analysis(docs_path, code_path, output_format, output_file, verbose) do
    if verbose, do: IO.puts "🔍 Analyzing migration candidates..."

    candidates = CodeMigrationFramework.identify_migration_candidates(docs_path, code_path)

    if verbose do
      IO.puts "📊 Migration Analysis Results:"
      IO.puts "   Total candidates: #{length(candidates.candidates)}"
      IO.puts "   High priority: #{Enum.count(candidates.candidates, &(&1.priority == :high))}"
      IO.puts "   Medium priority: #{Enum.count(candidates.candidates, &(&1.priority == :medium))}"
      IO.puts "   Low priority: #{Enum.count(candidates.candidates, &(&1.priority == :low))}"
    end

    # Save results
    case output_format do
      "json" ->
        json_content = Jason.encode!(candidates, pretty: true)
        File.write!(output_file, json_content)
      "report" ->
        report_content = generate_migration_report(candidates)
        File.write!(String.replace(output_file, ".json", ".txt"), report_content)
    end

    IO.puts "✅ Migration analysis complete! Results saved to #{output_file}"
  end

  defp run_migration_execution(docs_path, code_path, dry_run, verbose) do
    if verbose, do: IO.puts "🚀 #{if dry_run, do: "Simulating", else: "Executing"} migrations..."

    # First identify candidates
    candidates = CodeMigrationFramework.identify_migration_candidates(docs_path, code_path)

    if length(candidates.candidates) == 0 do
      IO.puts "ℹ️  No migration candidates found."
    else
      # Create migration plan
      migration_plan = CodeMigrationFramework.create_migration_plan(candidates.candidates)

      if verbose do
        IO.puts "📋 Migration Plan:"
        Enum.each(migration_plan.steps, fn step ->
          IO.puts "   • #{step.description} (#{step.step_type})"
        end)
      end

      if dry_run do
        IO.puts "🔍 Dry run complete. #{length(migration_plan.steps)} steps would be executed."
      else
        # Execute migrations
        result = CodeMigrationFramework.execute_migration(migration_plan)

        case result.status do
          :success ->
            IO.puts "✅ Migration completed successfully!"
            if verbose do
              IO.puts "   Steps completed: #{result.completed_steps}"
              IO.puts "   Migration ID: #{result.migration_id}"
            end
          :failed ->
            IO.puts "❌ Migration failed: #{result.error_message}"
            IO.puts "   Rollback initiated: #{result.rollback_initiated}"
          _ ->
            IO.puts "⚠️  Migration completed with warnings"
        end
      end
    end
  end

  defp run_migration_validation(docs_path, code_path, verbose) do
    if verbose, do: IO.puts "🔍 Validating migration system..."

    validation_result = CodeMigrationFramework.validate_migration_system(docs_path, code_path)

    IO.puts "📋 Migration System Validation:"
    IO.puts "   Overall Status: #{if validation_result.valid, do: "✅ Valid", else: "❌ Invalid"}"
    IO.puts "   Checks Passed: #{validation_result.checks_passed}/#{validation_result.total_checks}"

    if length(validation_result.issues) > 0 do
      IO.puts "\n⚠️  Issues Found:"
      Enum.each(validation_result.issues, fn issue ->
        IO.puts "   • #{issue.severity}: #{issue.description}"
      end)
    end

    if length(validation_result.recommendations) > 0 do
      IO.puts "\n💡 Recommendations:"
      Enum.each(validation_result.recommendations, fn rec ->
        IO.puts "   • #{rec}"
      end)
    end
  end

  defp run_migration_rollback(migration_id, verbose) do
    if is_nil(migration_id) do
      IO.puts "❌ Migration ID required for rollback. Use --migration-id option."
    else
      if verbose, do: IO.puts "🔄 Rolling back migration #{migration_id}..."

      result = CodeMigrationFramework.rollback_migration(migration_id)

      case result.status do
        :success ->
          IO.puts "✅ Migration #{migration_id} rolled back successfully!"
        :failed ->
          IO.puts "❌ Rollback failed: #{result.error_message}"
        :not_found ->
          IO.puts "❌ Migration #{migration_id} not found"
      end
    end
  end

  defp generate_migration_report(candidates) do
    """
    # Code Migration Analysis Report
    Generated: #{DateTime.utc_now()}

    ## Summary
    - Total Migration Candidates: #{length(candidates.candidates)}
    - High Priority: #{Enum.count(candidates.candidates, &(&1.priority == :high))}
    - Medium Priority: #{Enum.count(candidates.candidates, &(&1.priority == :medium))}
    - Low Priority: #{Enum.count(candidates.candidates, &(&1.priority == :low))}

    ## Migration Candidates

    #{format_migration_candidates(candidates.candidates)}

    ## Recommendations

    #{format_migration_recommendations(candidates)}
    """
  end

  defp format_migration_candidates(candidates) do
    candidates
    |> Enum.with_index(1)
    |> Enum.map(fn {candidate, index} ->
      """
      ### #{index}. #{candidate.title}
      - **Source**: #{candidate.source_file}:#{candidate.source_line}
      - **Target**: #{candidate.target_location}
      - **Priority**: #{candidate.priority}
      - **Language**: #{candidate.language}
      - **Complexity**: #{candidate.complexity_score}/10
      - **Description**: #{candidate.description}
      """
    end)
    |> Enum.join("\n")
  end

  defp format_migration_recommendations(candidates) do
    high_priority_count = Enum.count(candidates.candidates, &(&1.priority == :high))

    recommendations = []

    recommendations = if high_priority_count > 0 do
      ["Start with #{high_priority_count} high-priority candidates for maximum impact" | recommendations]
    else
      recommendations
    end

    recommendations = ["Review migration plan before executing to ensure alignment with project goals" | recommendations]
    recommendations = ["Consider creating backup before executing migrations" | recommendations]

    recommendations
    |> Enum.with_index(1)
    |> Enum.map(fn {rec, index} -> "#{index}. #{rec}" end)
    |> Enum.join("\n")
  end
end

defmodule Mix.Tasks.Docs.ReplaceReferences do
  @moduledoc """
  Reference Replacement System operations.

  This task provides tools for replacing detailed code implementations in
  documentation with concise references and smart links.

  ## Options

    * `--analyze` - Analyze reference replacement candidates
    * `--preview` - Preview replacement operations
    * `--execute` - Execute reference replacements
    * `--validate` - Validate existing references
    * `--docs` - Documentation directory (default: docs)
    * `--code` - Code directory (default: apps)
    * `--output` - Output format: json, report (default: report)
    * `--file` - Output file path (default: reference-analysis.json)
    * `--dry-run` - Show what would be done without executing
    * `--verbose` - Enable verbose output

  ## Examples

      mix docs.replace_references --analyze
      mix docs.replace_references --preview --verbose
      mix docs.replace_references --execute --dry-run
      mix docs.replace_references --validate
  """

  use Mix.Task
  alias Prismatic.Documentation.ReferenceReplacementSystem

  @shortdoc "Reference replacement system operations"

  def run(args) do
    {options, _, _} = OptionParser.parse(args,
      switches: [
        analyze: :boolean,
        preview: :boolean,
        execute: :boolean,
        validate: :boolean,
        docs: :string,
        code: :string,
        output: :string,
        file: :string,
        dry_run: :boolean,
        verbose: :boolean,
        help: :boolean
      ]
    )

    if options[:help] do
      show_help()
    else
      run_reference_operations(options)
    end
  end

  defp show_help do
    IO.puts @moduledoc
  end

  defp run_reference_operations(options) do
    docs_path = options[:docs] || "docs"
    code_path = options[:code] || "apps"
    output_format = options[:output] || "report"
    output_file = options[:file] || "reference-analysis.json"
    verbose = options[:verbose] || false
    dry_run = options[:dry_run] || false

    Mix.Task.run("app.start")

    try do
      cond do
        options[:analyze] ->
          run_reference_analysis(docs_path, code_path, output_format, output_file, verbose)

        options[:preview] ->
          run_reference_preview(docs_path, code_path, verbose)

        options[:execute] ->
          run_reference_execution(docs_path, code_path, dry_run, verbose)

        options[:validate] ->
          run_reference_validation(docs_path, code_path, verbose)

        true ->
          IO.puts "Please specify an operation: --analyze, --preview, --execute, or --validate"
          show_help()
      end

    rescue
      error ->
        IO.puts "❌ Reference operation failed: #{Exception.message(error)}"
        if verbose do
          IO.puts Exception.format_stacktrace(__STACKTRACE__)
        end
        exit({:shutdown, 1})
    end
  end

  defp run_reference_analysis(docs_path, code_path, output_format, output_file, verbose) do
    if verbose, do: IO.puts "🔍 Analyzing reference replacement candidates..."

    candidates = ReferenceReplacementSystem.identify_replacement_candidates(docs_path, code_path)

    if verbose do
      IO.puts "📊 Reference Analysis Results:"
      IO.puts "   Total candidates: #{length(candidates.candidates)}"
      IO.puts "   Code blocks: #{Enum.count(candidates.candidates, &(&1.content_type == :code_block))}"
      IO.puts "   Inline code: #{Enum.count(candidates.candidates, &(&1.content_type == :inline_code))}"
      IO.puts "   Detailed explanations: #{Enum.count(candidates.candidates, &(&1.content_type == :detailed_explanation))}"
    end

    # Save results
    case output_format do
      "json" ->
        json_content = Jason.encode!(candidates, pretty: true)
        File.write!(output_file, json_content)
      "report" ->
        report_content = generate_reference_report(candidates)
        File.write!(String.replace(output_file, ".json", ".txt"), report_content)
    end

    IO.puts "✅ Reference analysis complete! Results saved to #{output_file}"
  end

  defp run_reference_preview(docs_path, code_path, verbose) do
    if verbose, do: IO.puts "👀 Previewing reference replacements..."

    candidates = ReferenceReplacementSystem.identify_replacement_candidates(docs_path, code_path)

    if length(candidates.candidates) == 0 do
      IO.puts "ℹ️  No reference replacement candidates found."
    else
      IO.puts "🔄 Reference Replacement Preview:"
      IO.puts "═══════════════════════════════════"

      candidates.candidates
      |> Enum.take(5) # Show first 5 for preview
      |> Enum.with_index(1)
      |> Enum.each(fn {candidate, index} ->
        IO.puts "\n#{index}. #{candidate.source_file}:#{candidate.source_line}"
        IO.puts "   Type: #{candidate.content_type}"
        IO.puts "   Current (#{String.length(candidate.original_content)} chars):"
        IO.puts "   #{String.slice(candidate.original_content, 0, 100)}..."

        # Generate preview of replacement
        replacement = ReferenceReplacementSystem.generate_smart_reference(candidate)
        IO.puts "   Replacement (#{String.length(replacement.reference_text)} chars):"
        IO.puts "   #{replacement.reference_text}"
        IO.puts "   ─────────────────────────────────"
      end)

      if length(candidates.candidates) > 5 do
        IO.puts "\n... and #{length(candidates.candidates) - 5} more candidates"
      end
    end
  end

  defp run_reference_execution(docs_path, code_path, dry_run, verbose) do
    if verbose, do: IO.puts "🚀 #{if dry_run, do: "Simulating", else: "Executing"} reference replacements..."

    candidates = ReferenceReplacementSystem.identify_replacement_candidates(docs_path, code_path)

    if length(candidates.candidates) == 0 do
      IO.puts "ℹ️  No reference replacement candidates found."
    else
      if dry_run do
        IO.puts "🔍 Dry run: #{length(candidates.candidates)} replacements would be executed."

        # Show summary of what would happen
        content_savings = candidates.candidates
        |> Enum.map(fn candidate ->
          replacement = ReferenceReplacementSystem.generate_smart_reference(candidate)
          String.length(candidate.original_content) - String.length(replacement.reference_text)
        end)
        |> Enum.sum()

        IO.puts "   Content reduction: #{content_savings} characters"
      else
        # Execute replacements
        result = ReferenceReplacementSystem.execute_replacements(candidates.candidates)

        case result.status do
          :success ->
            IO.puts "✅ Reference replacements completed successfully!"
            if verbose do
              IO.puts "   Replacements made: #{result.successful_replacements}"
              IO.puts "   Content reduction: #{result.content_reduction} characters"
              IO.puts "   New references created: #{result.references_created}"
            end
          :failed ->
            IO.puts "❌ Reference replacement failed: #{result.error_message}"
          _ ->
            IO.puts "⚠️  Reference replacement completed with warnings"
        end
      end
    end
  end

  defp run_reference_validation(docs_path, code_path, verbose) do
    if verbose, do: IO.puts "🔍 Validating existing references..."

    validation_result = ReferenceReplacementSystem.validate_references(docs_path, code_path)

    IO.puts "📋 Reference Validation Results:"
    IO.puts "   Total references: #{validation_result.total_references}"
    IO.puts "   Valid references: #{validation_result.valid_references}"
    IO.puts "   Broken references: #{validation_result.broken_references}"
    IO.puts "   Success rate: #{validation_result.success_rate}%"

    if length(validation_result.issues) > 0 do
      IO.puts "\n⚠️  Issues Found:"
      Enum.each(validation_result.issues, fn issue ->
        IO.puts "   • #{issue.severity}: #{issue.description} (#{issue.file}:#{issue.line})"
      end)
    end

    if length(validation_result.recommendations) > 0 do
      IO.puts "\n💡 Recommendations:"
      Enum.each(validation_result.recommendations, fn rec ->
        IO.puts "   • #{rec}"
      end)
    end
  end

  defp generate_reference_report(candidates) do
    """
    # Reference Replacement Analysis Report
    Generated: #{DateTime.utc_now()}

    ## Summary
    - Total Replacement Candidates: #{length(candidates.candidates)}
    - Code Blocks: #{Enum.count(candidates.candidates, &(&1.content_type == :code_block))}
    - Inline Code: #{Enum.count(candidates.candidates, &(&1.content_type == :inline_code))}
    - Detailed Explanations: #{Enum.count(candidates.candidates, &(&1.content_type == :detailed_explanation))}

    ## Potential Content Reduction
    #{calculate_content_reduction(candidates.candidates)}

    ## Replacement Candidates

    #{format_reference_candidates(candidates.candidates)}
    """
  end

  defp calculate_content_reduction(candidates) do
    total_original = candidates
    |> Enum.map(&String.length(&1.original_content))
    |> Enum.sum()

    estimated_replacement = candidates
    |> Enum.map(fn candidate ->
      # Estimate replacement size (typically much smaller)
      case candidate.content_type do
        :code_block -> 150  # Smart reference with link
        :inline_code -> 50   # Short reference
        :detailed_explanation -> 100  # Concise reference
        _ -> 75
      end
    end)
    |> Enum.sum()

    reduction = total_original - estimated_replacement
    percentage = if total_original > 0, do: round(reduction / total_original * 100), else: 0

    """
    - Original content: #{total_original} characters
    - Estimated after replacement: #{estimated_replacement} characters
    - Potential reduction: #{reduction} characters (#{percentage}%)
    """
  end

  defp format_reference_candidates(candidates) do
    candidates
    |> Enum.take(10) # Show first 10 in report
    |> Enum.with_index(1)
    |> Enum.map(fn {candidate, index} ->
      """
      ### #{index}. #{Path.basename(candidate.source_file)}:#{candidate.source_line}
      - **Type**: #{candidate.content_type}
      - **Language**: #{candidate.language || "N/A"}
      - **Size**: #{String.length(candidate.original_content)} characters
      - **Complexity**: #{candidate.complexity_score}/10
      - **Preview**: #{String.slice(candidate.original_content, 0, 100)}...
      """
    end)
    |> Enum.join("\n")
  end
end

defmodule Mix.Tasks.Docs.SyncBidirectional do
  @moduledoc """
  Bidirectional Synchronization Engine operations.

  This task provides tools for real-time monitoring and automated updates
  for code-to-documentation and documentation-to-code changes.

  ## Options

    * `--monitor` - Start real-time synchronization monitoring
    * `--sync` - Perform one-time bidirectional synchronization
    * `--status` - Show synchronization status
    * `--conflicts` - Show and resolve synchronization conflicts
    * `--docs` - Documentation directory (default: docs)
    * `--code` - Code directory (default: apps)
    * `--interval` - Monitoring interval in seconds (default: 60)
    * `--auto-resolve` - Automatically resolve simple conflicts
    * `--verbose` - Enable verbose output

  ## Examples

      mix docs.sync_bidirectional --monitor
      mix docs.sync_bidirectional --sync --verbose
      mix docs.sync_bidirectional --status
      mix docs.sync_bidirectional --conflicts --auto-resolve
  """

  use Mix.Task
  alias Prismatic.Documentation.BidirectionalSynchronizationEngine

  @shortdoc "Bidirectional synchronization engine operations"

  def run(args) do
    {options, _, _} = OptionParser.parse(args,
      switches: [
        monitor: :boolean,
        sync: :boolean,
        status: :boolean,
        conflicts: :boolean,
        docs: :string,
        code: :string,
        interval: :integer,
        auto_resolve: :boolean,
        verbose: :boolean,
        help: :boolean
      ]
    )

    if options[:help] do
      show_help()
    else
      run_sync_operations(options)
    end
  end

  defp show_help do
    IO.puts @moduledoc
  end

  defp run_sync_operations(options) do
    docs_path = options[:docs] || "docs"
    code_path = options[:code] || "apps"
    interval = options[:interval] || 60
    auto_resolve = options[:auto_resolve] || false
    verbose = options[:verbose] || false

    Mix.Task.run("app.start")

    try do
      cond do
        options[:monitor] ->
          run_sync_monitoring(docs_path, code_path, interval, auto_resolve, verbose)

        options[:sync] ->
          run_one_time_sync(docs_path, code_path, auto_resolve, verbose)

        options[:status] ->
          show_sync_status(docs_path, code_path, verbose)

        options[:conflicts] ->
          handle_sync_conflicts(docs_path, code_path, auto_resolve, verbose)

        true ->
          IO.puts "Please specify an operation: --monitor, --sync, --status, or --conflicts"
          show_help()
      end

    rescue
      error ->
        IO.puts "❌ Synchronization operation failed: #{Exception.message(error)}"
        if verbose do
          IO.puts Exception.format_stacktrace(__STACKTRACE__)
        end
        exit({:shutdown, 1})
    end
  end

  defp run_sync_monitoring(docs_path, code_path, interval, auto_resolve, verbose) do
    IO.puts "🔄 Starting bidirectional synchronization monitoring..."
    IO.puts "   Documentation: #{docs_path}"
    IO.puts "   Code: #{code_path}"
    IO.puts "   Interval: #{interval} seconds"
    IO.puts "   Auto-resolve conflicts: #{auto_resolve}"

    monitoring_config = [
      docs_path: docs_path,
      code_path: code_path,
      monitoring_interval: interval,
      auto_resolve_conflicts: auto_resolve,
      verbose: verbose
    ]

    sync_monitor = BidirectionalSynchronizationEngine.start_monitoring(monitoring_config)

    IO.puts "✅ Monitoring started (PID: #{inspect(sync_monitor.monitor_pid)})"
    IO.puts "Press Ctrl+C to stop monitoring..."

    # Keep the process alive
    Process.sleep(:infinity)
  end

  defp run_one_time_sync(docs_path, code_path, auto_resolve, verbose) do
    if verbose, do: IO.puts "🔄 Performing bidirectional synchronization..."

    sync_result = BidirectionalSynchronizationEngine.perform_sync(docs_path, code_path, [
      auto_resolve_conflicts: auto_resolve,
      verbose: verbose
    ])

    IO.puts "📊 Synchronization Results:"
    IO.puts "   Code → Documentation: #{sync_result.code_to_docs_changes} changes"
    IO.puts "   Documentation → Code: #{sync_result.docs_to_code_changes} changes"
    IO.puts "   Conflicts detected: #{sync_result.conflicts_detected}"
    IO.puts "   Conflicts resolved: #{sync_result.conflicts_resolved}"

    if sync_result.conflicts_detected > sync_result.conflicts_resolved do
      IO.puts "\n⚠️  #{sync_result.conflicts_detected - sync_result.conflicts_resolved} conflicts require manual resolution"
      IO.puts "Run 'mix docs.sync_bidirectional --conflicts' to resolve them"
    end

    case sync_result.status do
      :success ->
        IO.puts "✅ Synchronization completed successfully!"
      :partial ->
        IO.puts "⚠️  Synchronization completed with some issues"
      :failed ->
        IO.puts "❌ Synchronization failed: #{sync_result.error_message}"
    end
  end

  defp show_sync_status(docs_path, code_path, verbose) do
    if verbose, do: IO.puts "📊 Checking synchronization status..."

    status = BidirectionalSynchronizationEngine.get_sync_status(docs_path, code_path)

    IO.puts "🔄 Bidirectional Synchronization Status"
    IO.puts "═══════════════════════════════════════"

    # Overall health
    {color, icon} = case status.health_level do
      :excellent -> {IO.ANSI.green(), "✅"}
      :good -> {IO.ANSI.green(), "✅"}
      :warning -> {IO.ANSI.yellow(), "⚠️"}
      :critical -> {IO.ANSI.red(), "❌"}
    end

    IO.puts "#{color}#{icon} Overall Health: #{status.health_level} (#{status.sync_score}%)#{IO.ANSI.reset()}"

    # Last sync info
    IO.puts "📅 Last Sync: #{status.last_sync_time}"
    IO.puts "🔍 Pending Changes: #{status.pending_changes}"
    IO.puts "⚠️  Active Conflicts: #{status.active_conflicts}"

    # Component status
    IO.puts "\n📊 Component Status:"
    IO.puts "   Code → Docs sync: #{status.code_to_docs_status}"
    IO.puts "   Docs → Code sync: #{status.docs_to_code_status}"
    IO.puts "   Conflict resolution: #{status.conflict_resolution_status}"

    if length(status.recent_activities) > 0 do
      IO.puts "\n📝 Recent Activities:"
      status.recent_activities
      |> Enum.take(5)
      |> Enum.each(fn activity ->
        IO.puts "   • #{activity.timestamp}: #{activity.description}"
      end)
    end
  end

  defp handle_sync_conflicts(docs_path, code_path, auto_resolve, verbose) do
    if verbose, do: IO.puts "🔍 Checking for synchronization conflicts..."

    conflicts = BidirectionalSynchronizationEngine.get_conflicts(docs_path, code_path)

    if length(conflicts.conflicts) == 0 do
      IO.puts "✅ No synchronization conflicts found."
    else
      IO.puts "⚠️  Found #{length(conflicts.conflicts)} synchronization conflicts:"
      IO.puts "═══════════════════════════════════════════════════════"

      conflicts.conflicts
      |> Enum.with_index(1)
      |> Enum.each(fn {conflict, index} ->
        IO.puts "\n#{index}. #{conflict.conflict_type} in #{conflict.file_path}"
        IO.puts "   Source: #{conflict.source}"
        IO.puts "   Description: #{conflict.description}"
        IO.puts "   Severity: #{conflict.severity}"

        if auto_resolve and conflict.auto_resolvable do
          IO.puts "   🔧 Auto-resolving..."
          resolution_result = BidirectionalSynchronizationEngine.resolve_conflict(conflict.conflict_id, :auto)

          case resolution_result.status do
            :resolved ->
              IO.puts "   ✅ Conflict resolved automatically"
            :failed ->
              IO.puts "   ❌ Auto-resolution failed: #{resolution_result.error}"
          end
        else
          IO.puts "   ⚠️  Manual resolution required"

          if conflict.suggested_resolution do
            IO.puts "   💡 Suggestion: #{conflict.suggested_resolution}"
          end
        end
      end)

      unresolved_count = conflicts.conflicts
      |> Enum.count(fn conflict ->
        not auto_resolve or not conflict.auto_resolvable
      end)

      if unresolved_count > 0 do
        IO.puts "\n⚠️  #{unresolved_count} conflicts require manual resolution."
        IO.puts "Review each conflict and use appropriate resolution commands."
      end
    end
  end
end

defmodule Mix.Tasks.Docs.SetupGitHooks do
  @moduledoc """
  Version Control Integration setup and management.

  This task provides tools for installing Git hooks and integrating with
  CI/CD pipelines for automated synchronization validation.

  ## Options

    * `--install` - Install Git hooks for synchronization
    * `--uninstall` - Remove installed Git hooks
    * `--status` - Show Git hooks status
    * `--ci-setup` - Setup CI/CD pipeline integration
    * `--provider` - CI provider: github, gitlab, jenkins, azure (default: github)
    * `--hooks` - Specific hooks to install: pre-commit, post-commit, pre-push
    * `--verbose` - Enable verbose output

  ## Examples

      mix docs.setup_git_hooks --install
      mix docs.setup_git_hooks --ci-setup --provider github
      mix docs.setup_git_hooks --status
      mix docs.setup_git_hooks --uninstall --hooks pre-commit,post-commit
  """

  use Mix.Task
  alias Prismatic.Documentation.VersionControlIntegration

  @shortdoc "Version control integration setup and management"

  def run(args) do
    {options, _, _} = OptionParser.parse(args,
      switches: [
        install: :boolean,
        uninstall: :boolean,
        status: :boolean,
        ci_setup: :boolean,
        provider: :string,
        hooks: :string,
        verbose: :boolean,
        help: :boolean
      ]
    )

    if options[:help] do
      show_help()
    else
      run_git_operations(options)
    end
  end

  defp show_help do
    IO.puts @moduledoc
  end

  defp run_git_operations(options) do
    provider = String.to_atom(options[:provider] || "github")
    hooks = parse_hooks(options[:hooks])
    verbose = options[:verbose] || false

    Mix.Task.run("app.start")

    try do
      cond do
        options[:install] ->
          install_git_hooks(hooks, verbose)

        options[:uninstall] ->
          uninstall_git_hooks(hooks, verbose)

        options[:status] ->
          show_git_hooks_status(verbose)

        options[:ci_setup] ->
          setup_ci_integration(provider, verbose)

        true ->
          IO.puts "Please specify an operation: --install, --uninstall, --status, or --ci-setup"
          show_help()
      end

    rescue
      error ->
        IO.puts "❌ Git operation failed: #{Exception.message(error)}"
        if verbose do
          IO.puts Exception.format_stacktrace(__STACKTRACE__)
        end
        exit({:shutdown, 1})
    end
  end

  defp install_git_hooks(hooks, verbose) do
    if verbose do
      IO.puts "🔧 Installing Git hooks for documentation synchronization..."
      IO.puts "   Hooks: #{Enum.join(hooks, ", ")}"
    end

    hook_config = %{
      enabled_hooks: hooks,
      validation_enabled: true,
      auto_sync_enabled: true,
      notification_enabled: true
    }

    result = VersionControlIntegration.install_git_hooks(hook_config)

    case result.status do
      :success ->
        IO.puts "✅ Git hooks installed successfully!"
        if verbose do
          IO.puts "   Installed hooks: #{Enum.join(result.installed_hooks, ", ")}"
          IO.puts "   Hook directory: #{result.hooks_directory}"
        end

        IO.puts "\n📋 Hooks Overview:"
        Enum.each(result.installed_hooks, fn hook ->
          IO.puts "   • #{hook}: Validates documentation synchronization"
        end)

      :failed ->
        IO.puts "❌ Hook installation failed: #{result.error_message}"

      :partial ->
        IO.puts "⚠️  Some hooks failed to install: #{result.error_message}"
    end
  end

  defp uninstall_git_hooks(hooks, verbose) do
    if verbose do
      IO.puts "🗑️  Removing Git hooks..."
      IO.puts "   Hooks: #{Enum.join(hooks, ", ")}"
    end

    result = VersionControlIntegration.uninstall_git_hooks(hooks)

    case result.status do
      :success ->
        IO.puts "✅ Git hooks removed successfully!"
        if verbose do
          IO.puts "   Removed hooks: #{Enum.join(result.removed_hooks, ", ")}"
        end

      :failed ->
        IO.puts "❌ Hook removal failed: #{result.error_message}"

      :partial ->
        IO.puts "⚠️  Some hooks failed to remove: #{result.error_message}"
    end
  end

  defp show_git_hooks_status(verbose) do
    if verbose, do: IO.puts "📊 Checking Git hooks status..."

    status = VersionControlIntegration.get_hooks_status()

    IO.puts "🔧 Git Hooks Status"
    IO.puts "══════════════════"

    IO.puts "Repository: #{status.repository_path}"
    IO.puts "Hooks directory: #{status.hooks_directory}"
    IO.puts "Total hooks: #{status.total_hooks}"
    IO.puts "Active hooks: #{status.active_hooks}"

    if length(status.installed_hooks) > 0 do
      IO.puts "\n✅ Installed Hooks:"
      Enum.each(status.installed_hooks, fn hook ->
        IO.puts "   • #{hook.name}: #{hook.status} (last run: #{hook.last_execution})"
      end)
    else
      IO.puts "\n❌ No documentation sync hooks installed"
      IO.puts "Run 'mix docs.setup_git_hooks --install' to install hooks"
    end

    if length(status.hook_logs) > 0 and verbose do
      IO.puts "\n📝 Recent Hook Activity:"
      status.hook_logs
      |> Enum.take(5)
      |> Enum.each(fn log ->
        IO.puts "   #{log.timestamp}: #{log.hook} - #{log.result}"
      end)
    end
  end

  defp setup_ci_integration(provider, verbose) do
    if verbose do
      IO.puts "🔧 Setting up CI/CD integration..."
      IO.puts "   Provider: #{provider}"
    end

    ci_config = %{
      provider: provider,
      validation_enabled: true,
      auto_sync_enabled: false,  # Usually disabled in CI
      notification_enabled: true,
      fail_on_drift: true
    }

    result = VersionControlIntegration.setup_ci_integration(ci_config)

    case result.status do
      :success ->
        IO.puts "✅ CI/CD integration setup successfully!"
        if verbose do
          IO.puts "   Provider: #{result.provider}"
          IO.puts "   Config file: #{result.config_file}"
          IO.puts "   Validation jobs: #{length(result.validation_jobs)}"
        end

        IO.puts "\n📋 CI Integration Overview:"
        IO.puts "   • Documentation validation on pull requests"
        IO.puts "   • Synchronization drift detection"
        IO.puts "   • Automated health reporting"

        if result.next_steps and length(result.next_steps) > 0 do
          IO.puts "\n⚠️  Next Steps:"
          Enum.each(result.next_steps, fn step ->
            IO.puts "   #{step}"
          end)
        end

      :failed ->
        IO.puts "❌ CI integration setup failed: #{result.error_message}"

      :partial ->
        IO.puts "⚠️  CI integration partially configured: #{result.error_message}"
    end
  end

  defp parse_hooks(hooks_string) do
    case hooks_string do
      nil -> [:pre_commit, :post_commit, :pre_push]  # Default hooks
      "" -> [:pre_commit, :post_commit, :pre_push]
      _ ->
        hooks_string
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(&String.replace(&1, "-", "_"))
        |> Enum.map(&String.to_atom/1)
    end
  end
end

defmodule Mix.Tasks.Docs.MonitorDrift do
  @moduledoc """
  Drift Prevention System monitoring and management.

  This task provides tools for proactive detection and prevention of
  documentation-code synchronization drift.

  ## Options

    * `--continuous` - Start continuous drift monitoring
    * `--analyze` - Perform one-time drift analysis
    * `--predict` - Run predictive drift analysis
    * `--fix` - Apply automated fixes for detected drift
    * `--dashboard` - Launch interactive drift dashboard
    * `--interval` - Monitoring interval in seconds (default: 3600)
    * `--threshold` - Drift score threshold (default: 85)
    * `--auto-fix` - Enable automatic fixing of drift issues
    * `--verbose` - Enable verbose output

  ## Examples

      mix docs.monitor_drift --continuous
      mix docs.monitor_drift --analyze --verbose
      mix docs.monitor_drift --predict --threshold 80
      mix docs.monitor_drift --fix --auto-fix
  """

  use Mix.Task
  alias Prismatic.Documentation.DriftPreventionSystem

  @shortdoc "Drift prevention system monitoring and management"

  def run(args) do
    {options, _, _} = OptionParser.parse(args,
      switches: [
        continuous: :boolean,
        analyze: :boolean,
        predict: :boolean,
        fix: :boolean,
        dashboard: :boolean,
        interval: :integer,
        threshold: :integer,
        auto_fix: :boolean,
        verbose: :boolean,
        help: :boolean
      ]
    )

    if options[:help] do
      show_help()
    else
      run_drift_operations(options)
    end
  end

  defp show_help do
    IO.puts @moduledoc
  end

  defp run_drift_operations(options) do
    interval = options[:interval] || 3600
    threshold = options[:threshold] || 85
    auto_fix = options[:auto_fix] || false
    verbose = options[:verbose] || false

    Mix.Task.run("app.start")

    try do
      cond do
        options[:continuous] ->
          start_continuous_monitoring(interval, threshold, auto_fix, verbose)

        options[:analyze] ->
          run_drift_analysis(threshold, verbose)

        options[:predict] ->
          run_predictive_analysis(verbose)

        options[:fix] ->
          apply_drift_fixes(auto_fix, verbose)

        options[:dashboard] ->
          launch_drift_dashboard(verbose)

        true ->
          IO.puts "Please specify an operation: --continuous, --analyze, --predict, --fix, or --dashboard"
          show_help()
      end

    rescue
      error ->
        IO.puts "❌ Drift monitoring operation failed: #{Exception.message(error)}"
        if verbose do
          IO.puts Exception.format_stacktrace(__STACKTRACE__)
        end
        exit({:shutdown, 1})
    end
  end

  defp start_continuous_monitoring(interval, threshold, auto_fix, verbose) do
    IO.puts "🔄 Starting continuous drift monitoring..."
    IO.puts "   Monitoring interval: #{interval} seconds"
    IO.puts "   Drift threshold: #{threshold}%"
    IO.puts "   Auto-fix enabled: #{auto_fix}"

    monitoring_config = [
      health_check_interval: interval,
      drift_threshold: threshold,
      auto_fix_enabled: auto_fix,
      verbose: verbose
    ]

    monitoring_system = DriftPreventionSystem.start_drift_monitoring(monitoring_config)

    IO.puts "✅ Drift monitoring started (PID: #{inspect(monitoring_system.monitor_pid)})"
    IO.puts "   Metrics collector: Active"
    IO.puts "   Prediction engine: #{if monitoring_system.monitoring_config.prediction_enabled, do: "Active", else: "Disabled"}"
    IO.puts "   Alert system: Active"

    IO.puts "\nPress Ctrl+C to stop monitoring..."

    # Keep the process alive and show periodic updates
    monitor_loop(monitoring_system, verbose)
  end

  defp monitor_loop(monitoring_system, verbose) do
    receive do
      {:monitor_update, stats} ->
        if verbose do
          IO.puts "📊 #{DateTime.utc_now()}: Health Score #{stats.health_score}%, Risk: #{stats.risk_level}"
        end
        monitor_loop(monitoring_system, verbose)
    after
      30_000 -> # Show status every 30 seconds
        if verbose do
          IO.puts "🔄 Monitoring active... (#{DateTime.utc_now()})"
        end
        monitor_loop(monitoring_system, verbose)
    end
  end

  defp run_drift_analysis(threshold, verbose) do
    if verbose, do: IO.puts "🔍 Performing comprehensive drift analysis..."

    analysis_result = DriftPreventionSystem.detect_drift([threshold: threshold])

    IO.puts "📊 Drift Analysis Results"
    IO.puts "════════════════════════"

    overall_score = analysis_result.overall_metrics.overall_health_score
    risk_level = analysis_result.overall_metrics.risk_level

    {color, icon} = case risk_level do
      :low -> {IO.ANSI.green(), "✅"}
      :medium -> {IO.ANSI.yellow(), "⚠️"}
      :high -> {IO.ANSI.red(), "❌"}
      :critical -> {IO.ANSI.red(), "🚨"}
    end

    IO.puts "#{color}#{icon} Overall Health Score: #{overall_score}% (#{risk_level} risk)#{IO.ANSI.reset()}"

    # Component scores
    IO.puts "\n📋 Component Analysis:"
    IO.puts "   Content drift: #{analysis_result.overall_metrics.content_drift_score}%"
    IO.puts "   Reference drift: #{analysis_result.overall_metrics.reference_drift_score}%"
    IO.puts "   Structural drift: #{analysis_result.overall_metrics.structural_drift_score}%"
    IO.puts "   Semantic drift: #{analysis_result.overall_metrics.semantic_drift_score}%"
    IO.puts "   Temporal drift: #{analysis_result.overall_metrics.temporal_drift_score}%"

    # Alerts
    if length(analysis_result.alerts) > 0 do
      IO.puts "\n⚠️  Active Alerts (#{length(analysis_result.alerts)}):"
      analysis_result.alerts
      |> Enum.take(5)
      |> Enum.each(fn alert ->
        alert_color = case alert.severity do
          :critical -> IO.ANSI.red()
          :error -> IO.ANSI.red()
          :warning -> IO.ANSI.yellow()
          :info -> IO.ANSI.blue()
        end

        IO.puts "   #{alert_color}• #{alert.description}#{IO.ANSI.reset()}"
      end)

      if length(analysis_result.alerts) > 5 do
        IO.puts "   ... and #{length(analysis_result.alerts) - 5} more alerts"
      end
    else
      IO.puts "\n✅ No active alerts"
    end

    # Recommendations
    if length(analysis_result.recommendations) > 0 do
      IO.puts "\n💡 Recommendations:"
      Enum.each(analysis_result.recommendations, fn rec ->
        IO.puts "   • #{rec}"
      end)
    end

    IO.puts "\nAnalysis completed in #{analysis_result.analysis_time_ms}ms"
  end

  defp run_predictive_analysis(verbose) do
    if verbose, do: IO.puts "🔮 Running predictive drift analysis..."

    prediction_result = DriftPreventionSystem.predict_future_drift(7, [verbose: verbose])

    IO.puts "🔮 Predictive Drift Analysis (7-day forecast)"
    IO.puts "═══════════════════════════════════════════════"

    if prediction_result.predictions_available do
      IO.puts "📈 Predicted Trends:"
      IO.puts "   Overall health: #{prediction_result.predictions.overall_prediction.predicted_value}% (confidence: #{Float.round(prediction_result.predictions.overall_prediction.confidence * 100, 1)}%)"
      IO.puts "   Content drift: #{prediction_result.predictions.content_prediction.predicted_value}% (confidence: #{Float.round(prediction_result.predictions.content_prediction.confidence * 100, 1)}%)"
      IO.puts "   Reference drift: #{prediction_result.predictions.reference_prediction.predicted_value}% (confidence: #{Float.round(prediction_result.predictions.reference_prediction.confidence * 100, 1)}%)"
      IO.puts "   Structural drift: #{prediction_result.predictions.structural_prediction.predicted_value}% (confidence: #{Float.round(prediction_result.predictions.structural_prediction.confidence * 100, 1)}%)"

      # Predictive alerts
      if length(prediction_result.predictive_alerts) > 0 do
        IO.puts "\n⚠️  Predictive Alerts:"
        Enum.each(prediction_result.predictive_alerts, fn alert ->
          IO.puts "   • #{alert.description} (confidence: #{Float.round(alert.confidence_level * 100, 1)}%)"
        end)
      else
        IO.puts "\n✅ No concerning trends predicted"
      end

      # Confidence assessment
      overall_confidence = prediction_result.confidence_scores.overall_confidence
      confidence_color = if overall_confidence > 0.8, do: IO.ANSI.green(), else: IO.ANSI.yellow()

      IO.puts "\n📊 Prediction Confidence: #{confidence_color}#{Float.round(overall_confidence * 100, 1)}%#{IO.ANSI.reset()}"

    else
      IO.puts "❌ Predictive analysis not available: #{prediction_result.reason}"
      IO.puts "   Ensure sufficient historical data is available"
    end
  end

  defp apply_drift_fixes(auto_fix, verbose) do
    if verbose, do: IO.puts "🔧 Applying drift fixes..."

    # First analyze drift to identify issues
    drift_analysis = DriftPreventionSystem.detect_drift()

    if drift_analysis.overall_metrics.overall_health_score > 90 do
      IO.puts "✅ System health is excellent (#{drift_analysis.overall_metrics.overall_health_score}%). No fixes needed."
    else
      # Generate fixes
      fixes_result = DriftPreventionSystem.generate_automated_fixes(drift_analysis.drift_analysis, [
        auto_fix_enabled: auto_fix,
        verbose: verbose
      ])

      IO.puts "🔧 Drift Fix Analysis"
      IO.puts "═══════════════════════"

      total_fixes = length(fixes_result.categorized_fixes.automatic) +
                    length(fixes_result.categorized_fixes.semi_automatic) +
                    length(fixes_result.categorized_fixes.manual)

      IO.puts "Total fixes identified: #{total_fixes}"
      IO.puts "   Automatic fixes: #{length(fixes_result.categorized_fixes.automatic)}"
      IO.puts "   Semi-automatic fixes: #{length(fixes_result.categorized_fixes.semi_automatic)}"
      IO.puts "   Manual fixes required: #{length(fixes_result.categorized_fixes.manual)}"

      # Show automatic fixes
      if length(fixes_result.categorized_fixes.automatic) > 0 do
        IO.puts "\n🤖 Automatic Fixes:"
        Enum.each(fixes_result.categorized_fixes.automatic, fn fix ->
          IO.puts "   • #{fix.description} (#{fix.estimated_effort})"
        end)

        if auto_fix and fixes_result.execution_results.executed do
          IO.puts "\n✅ Executed #{fixes_result.execution_results.successful} automatic fixes"
          if fixes_result.execution_results.failed > 0 do
            IO.puts "❌ #{fixes_result.execution_results.failed} fixes failed"
          end
        else
          IO.puts "\n💡 Run with --auto-fix to execute automatic fixes"
        end
      end

      # Show manual fixes
      if length(fixes_result.categorized_fixes.manual) > 0 do
        IO.puts "\n👤 Manual Fixes Required:"
        fixes_result.categorized_fixes.manual
        |> Enum.take(5)
        |> Enum.each(fn fix ->
          IO.puts "   • #{fix.description} (#{fix.estimated_effort})"
        end)
      end
    end
  end

  defp launch_drift_dashboard(verbose) do
    if verbose, do: IO.puts "📊 Launching interactive drift dashboard..."

    IO.puts "🚀 Drift Prevention Dashboard"
    IO.puts "═══════════════════════════════"
    IO.puts "Interactive dashboard functionality would be implemented here."
    IO.puts "This would provide:"
    IO.puts "   • Real-time drift metrics"
    IO.puts "   • Interactive charts and graphs"
    IO.puts "   • Alert management interface"
    IO.puts "   • Fix execution controls"
    IO.puts "   • Historical trend analysis"
    IO.puts ""
    IO.puts "For now, use the individual commands:"
    IO.puts "   mix docs.monitor_drift --analyze"
    IO.puts "   mix docs.monitor_drift --predict"
    IO.puts "   mix docs.monitor_drift --fix"
  end
end

defmodule Mix.Tasks.Docs.HealthReport do
  @moduledoc """
  Generate comprehensive synchronization health reports.

  This task creates detailed health reports including trends, predictions,
  and actionable recommendations for maintaining sync quality.

  ## Options

    * `--period` - Reporting period: 1d, 7d, 30d (default: 7d)
    * `--format` - Report format: text, json, html, markdown (default: markdown)
    * `--output` - Output file path (default: health-report.md)
    * `--sections` - Report sections: all, summary, trends, predictions (default: all)
    * `--save` - Save report to file (default: true)
    * `--verbose` - Enable verbose output

  ## Examples

      mix docs.health_report
      mix docs.health_report --period 30d --format html
      mix docs.health_report --sections summary,trends
      mix docs.health_report --period 1d --format json --output today-report.json
  """

  use Mix.Task
  alias Prismatic.Documentation.DriftPreventionSystem

  @shortdoc "Generate comprehensive synchronization health reports"

  def run(args) do
    {options, _, _} = OptionParser.parse(args,
      switches: [
        period: :string,
        format: :string,
        output: :string,
        sections: :string,
        save: :boolean,
        verbose: :boolean,
        help: :boolean
      ]
    )

    if options[:help] do
      show_help()
    else
      run_health_report(options)
    end
  end

  defp show_help do
    IO.puts @moduledoc
  end

  defp run_health_report(options) do
    period = parse_period(options[:period] || "7d")
    format = options[:format] || "markdown"
    output_file = options[:output] || "health-report.#{get_file_extension(format)}"
    sections = parse_sections(options[:sections] || "all")
    save_report = Keyword.get(options, :save, true)
    verbose = options[:verbose] || false

    Mix.Task.run("app.start")

    try do
      if verbose do
        IO.puts "📊 Generating health report..."
        IO.puts "   Period: #{period}"
        IO.puts "   Format: #{format}"
        IO.puts "   Sections: #{Enum.join(sections, ", ")}"
      end

      # Calculate reporting period
      period_end = DateTime.utc_now()
      period_start = DateTime.add(period_end, -period, :day)
      reporting_period = {period_start, period_end}

      # Generate comprehensive health report
      health_report = DriftPreventionSystem.generate_health_report(reporting_period, [
        save_report: save_report,
        output_dir: Path.dirname(output_file),
        verbose: verbose
      ])

      # Display summary
      display_health_summary(health_report, verbose)

      # Save in requested format if specified
      if save_report and output_file != health_report.report_id do
        save_custom_format_report(health_report, format, output_file, sections)
      end

      IO.puts "\n✅ Health report generated successfully!"
      if save_report do
        IO.puts "📄 Report saved to: #{output_file}"
      end

    rescue
      error ->
        IO.puts "❌ Health report generation failed: #{Exception.message(error)}"
        if verbose do
          IO.puts Exception.format_stacktrace(__STACKTRACE__)
        end
        exit({:shutdown, 1})
    end
  end

  defp parse_period(period_string) do
    case period_string do
      "1d" -> 1
      "7d" -> 7
      "30d" -> 30
      _ -> 7  # Default to 7 days
    end
  end

  defp get_file_extension(format) do
    case format do
      "json" -> "json"
      "html" -> "html"
      "markdown" -> "md"
      "text" -> "txt"
      _ -> "md"
    end
  end

  defp parse_sections(sections_string) do
    case sections_string do
      "all" -> [:summary, :trends, :predictions, :recommendations, :metrics]
      _ ->
        sections_string
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(&String.to_atom/1)
    end
  end

  defp display_health_summary(health_report, verbose) do
    IO.puts "\n📊 Health Report Summary"
    IO.puts "═══════════════════════════"
    IO.puts "Report ID: #{health_report.report_id}"
    IO.puts "Generated: #{health_report.generated_at}"
    IO.puts "Period: #{elem(health_report.reporting_period, 0)} to #{elem(health_report.reporting_period, 1)}"

    overall_score = health_report.overall_health_score
    {color, icon} = cond do
      overall_score >= 90 -> {IO.ANSI.green(), "✅"}
      overall_score >= 80 -> {IO.ANSI.yellow(), "⚠️"}
      overall_score >= 70 -> {IO.ANSI.red(), "❌"}
      true -> {IO.ANSI.red(), "🚨"}
    end

    IO.puts "#{color}#{icon} Overall Health Score: #{overall_score}%#{IO.ANSI.reset()}"

    if verbose do
      IO.puts "\n📋 Component Scores:"
      Enum.each(health_report.component_health_scores, fn {component, score} ->
        IO.puts "   #{component}: #{score}%"
      end)

      IO.puts "\n🔧 Available Fixes: #{length(health_report.automated_fixes_available)}"
      IO.puts "👤 Manual Interventions: #{length(health_report.manual_interventions_required)}"
    end
  end

  defp save_custom_format_report(health_report, format, output_file, sections) do
    content = case format do
      "json" ->
        Jason.encode!(health_report, pretty: true)
      "html" ->
        generate_html_health_report(health_report, sections)
      "markdown" ->
        generate_markdown_health_report(health_report, sections)
      "text" ->
        generate_text_health_report(health_report, sections)
      _ ->
        generate_markdown_health_report(health_report, sections)
    end

    File.write!(output_file, content)
  end

  defp generate_markdown_health_report(health_report, sections) do
    """
    # Documentation Synchronization Health Report

    **Report ID:** #{health_report.report_id}
    **Generated:** #{health_report.generated_at}
    **Reporting Period:** #{elem(health_report.reporting_period, 0)} to #{elem(health_report.reporting_period, 1)}

    ## Executive Summary

    Overall Health Score: **#{health_report.overall_health_score}%**

    #{if :summary in sections, do: generate_summary_section_md(health_report), else: ""}
    #{if :trends in sections, do: generate_trends_section_md(health_report), else: ""}
    #{if :predictions in sections, do: generate_predictions_section_md(health_report), else: ""}
    #{if :recommendations in sections, do: generate_recommendations_section_md(health_report), else: ""}
    #{if :metrics in sections, do: generate_metrics_section_md(health_report), else: ""}
    """
  end

  defp generate_html_health_report(health_report, sections) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Health Report - #{health_report.report_id}</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
            .header { background: #f5f5f5; padding: 20px; border-radius: 5px; }
            .score { font-size: 2em; font-weight: bold; color: #2ecc71; }
            .section { margin: 20px 0; }
            .metric { background: #ecf0f1; padding: 10px; margin: 5px 0; border-radius: 3px; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>Documentation Synchronization Health Report</h1>
            <p><strong>Report ID:</strong> #{health_report.report_id}</p>
            <p><strong>Generated:</strong> #{health_report.generated_at}</p>
            <div class="score">Overall Health: #{health_report.overall_health_score}%</div>
        </div>

        <div class="section">
            <h2>Component Health Scores</h2>
            #{Enum.map(health_report.component_health_scores, fn {component, score} ->
              "<div class=\"metric\"><strong>#{component}:</strong> #{score}%</div>"
            end) |> Enum.join("")}
        </div>
    </body>
    </html>
    """
  end

  defp generate_text_health_report(health_report, sections) do
    """
    DOCUMENTATION SYNCHRONIZATION HEALTH REPORT
    ===========================================

    Report ID: #{health_report.report_id}
    Generated: #{health_report.generated_at}
    Reporting Period: #{elem(health_report.reporting_period, 0)} to #{elem(health_report.reporting_period, 1)}

    EXECUTIVE SUMMARY
    ================

    Overall Health Score: #{health_report.overall_health_score}%

    COMPONENT HEALTH SCORES
    ======================

    #{Enum.map(health_report.component_health_scores, fn {component, score} ->
      "#{component}: #{score}%"
    end) |> Enum.join("\n")}

    AUTOMATED FIXES AVAILABLE
    ========================

    #{length(health_report.automated_fixes_available)} automated fixes available

    MANUAL INTERVENTIONS REQUIRED
    =============================

    #{length(health_report.manual_interventions_required)} manual interventions required
    """
  end

  # Helper functions for markdown sections
  defp generate_summary_section_md(health_report) do
    """
    ## Summary

    - Overall Health Score: #{health_report.overall_health_score}%
    - Automated Fixes Available: #{length(health_report.automated_fixes_available)}
    - Manual Interventions Required: #{length(health_report.manual_interventions_required)}
    """
  end

  defp generate_trends_section_md(health_report) do
    """
    ## Trends Analysis

    Historical trend analysis shows the evolution of synchronization health over the reporting period.

    #{if Map.has_key?(health_report, :drift_trends) do
      "- Trend Direction: #{health_report.drift_trends[:overall_direction] || "Stable"}"
    else
      "- Trend data not available for this period"
    end}
    """
  end

  defp generate_predictions_section_md(health_report) do
    """
    ## Predictive Analysis

    #{if Map.has_key?(health_report, :predictive_analysis) do
      "Predictive analysis suggests continued #{health_report.predictive_analysis[:trend_direction] || "stable"} performance."
    else
      "Predictive analysis not available - insufficient historical data."
    end}
    """
  end

  defp generate_recommendations_section_md(health_report) do
    """
    ## Recommendations

    #{if length(health_report.improvement_recommendations) > 0 do
      health_report.improvement_recommendations
      |> Enum.with_index(1)
      |> Enum.map(fn {rec, index} -> "#{index}. #{rec[:description] || rec}" end)
      |> Enum.join("\n")
    else
      "No specific recommendations at this time. System health is within acceptable parameters."
    end}
    """
  end

  defp generate_metrics_section_md(health_report) do
    """
    ## Detailed Metrics

    ### Component Health Scores

    #{Enum.map(health_report.component_health_scores, fn {component, score} ->
      "- **#{component}**: #{score}%"
    end) |> Enum.join("\n")}

    ### Historical Comparison

    #{if Map.has_key?(health_report, :historical_comparison) and map_size(health_report.historical_comparison) > 0 do
      "Historical comparison data available showing performance trends."
    else
      "No historical comparison data available for this reporting period."
    end}
    """
  end
end
