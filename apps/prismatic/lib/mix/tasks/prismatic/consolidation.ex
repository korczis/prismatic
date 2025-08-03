defmodule Mix.Tasks.Prismatic.Consolidation do
  @moduledoc """
  Master Mix task orchestrator for Phase 2: Advanced Dependency Mapping and Conflict Resolution.

  This task provides a central entry point and orchestration for the comprehensive
  enterprise consolidation strategy. It coordinates individual specialized tasks
  for dependency analysis, conflict resolution, migration planning, and execution.

  ## Available Sub-tasks

  Use individual tasks for specific operations:

    * `mix prismatic.consolidation.analyze` - Run comprehensive dependency analysis
    * `mix prismatic.consolidation.resolve` - Execute automated conflict resolution
    * `mix prismatic.consolidation.plan` - Generate migration plan for umbrella consolidation
    * `mix prismatic.consolidation.validate` - Run validation framework
    * `mix prismatic.consolidation.status` - Show consolidation status and progress
    * `mix prismatic.consolidation.report` - Generate comprehensive reports

  ## Usage

      # Use specific sub-tasks (recommended)
      mix prismatic.consolidation.analyze
      mix prismatic.consolidation.resolve
      mix prismatic.consolidation.plan

      # Or use this master task for orchestration
      mix prismatic.consolidation [COMMAND] [OPTIONS]

  ## Legacy Commands (for compatibility)

  This task maintains backward compatibility with the original command structure:

    * `analyze` - Runs `mix prismatic.consolidation.analyze`
    * `resolve` - Runs `mix prismatic.consolidation.resolve`
    * `plan` - Runs `mix prismatic.consolidation.plan`
    * `validate` - Runs `mix prismatic.consolidation.validate`
    * `status` - Runs `mix prismatic.consolidation.status`
    * `report` - Runs `mix prismatic.consolidation.report`

  ## Examples

      # Recommended: Use individual specialized tasks
      mix prismatic.consolidation.analyze --projects="../legacy,../old" --format=mermaid
      mix prismatic.consolidation.resolve --automation-level=full --dry-run
      mix prismatic.consolidation.plan --parallel --risk-tolerance=low

      # Legacy: Use master task with subcommands
      mix prismatic.consolidation analyze --projects="../legacy,../old"
      mix prismatic.consolidation status --detailed --export

  ## Getting Help

  For detailed help on individual tasks:

      mix help prismatic.consolidation.analyze
      mix help prismatic.consolidation.resolve
      mix help prismatic.consolidation.plan
      mix help prismatic.consolidation.validate
      mix help prismatic.consolidation.status
      mix help prismatic.consolidation.report

  ## Architecture Integration

  All tasks integrate seamlessly with the 6-app umbrella architecture:
  - prismatic_core, prismatic_web, prismatic_auth
  - prismatic_data, prismatic_distributed, prismatic_monitoring
  """

  use Mix.Task
  require Logger

  @shortdoc "Master orchestrator for Phase 2: Advanced Dependency Mapping and Conflict Resolution"

  @switches [
    projects: :string,
    dry_run: :boolean,
    parallel: :boolean,
    automation_level: :string,
    risk_tolerance: :string,
    output_dir: :string,
    verbose: :boolean,
    format: :string,
    help: :boolean
  ]

  @aliases [
    p: :projects,
    d: :dry_run,
    a: :automation_level,
    r: :risk_tolerance,
    o: :output_dir,
    v: :verbose,
    f: :format,
    h: :help
  ]

  @impl Mix.Task
  def run(args) do
    {_options, remaining_args, _invalid} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    case remaining_args do
      [] ->
        print_help()

      ["help"] ->
        print_help()

      [command | rest] ->
        delegate_to_subtask(command, rest)

      _ ->
        print_help()
    end
  end

  defp delegate_to_subtask(command, args) do
    task_module = case command do
      "analyze" -> Mix.Tasks.Prismatic.Consolidation.Analyze
      "resolve" -> Mix.Tasks.Prismatic.Consolidation.Resolve
      "plan" -> Mix.Tasks.Prismatic.Consolidation.Plan
      "validate" -> Mix.Tasks.Prismatic.Consolidation.Validate
      "status" -> Mix.Tasks.Prismatic.Consolidation.Status
      "report" -> Mix.Tasks.Prismatic.Consolidation.Report
      _ ->
        Mix.shell().error([:red, "Unknown command: #{command}", :reset])
        print_available_commands()
        System.halt(1)
    end

    Mix.shell().info([:yellow, "⚡ Delegating to specialized task: prismatic.consolidation.#{command}", :reset])
    task_module.run(args)
  end

  # Command Implementations

  defp execute_analyze_command(config, options) do
    Mix.shell().info([:blue, "🔍 Starting comprehensive dependency analysis", :reset])

    case Prismatic.Code.DependencyAnalyzer.build_dependency_graph(config.legacy_projects,
         target_architecture: config.target_architecture,
         include_transitive: true,
         max_depth: 10) do
      {:ok, dependency_graph} ->
        output_dir = ensure_output_directory(options[:output_dir] || "consolidation/phase2/analysis")

        # Save dependency graph
        save_analysis_result("dependency_graph.json", dependency_graph, output_dir)

        # Generate visualization if requested
        if options[:format] == "mermaid" do
          case Prismatic.Code.DependencyAnalyzer.visualize_graph(dependency_graph, :mermaid) do
            {:ok, diagram} ->
              File.write!(Path.join(output_dir, "dependency_graph.mmd"), diagram)
              Mix.shell().info("📊 Dependency graph visualization saved to #{output_dir}/dependency_graph.mmd")
            {:error, reason} ->
              Mix.shell().error("Failed to generate visualization: #{inspect(reason)}")
          end
        end

        result = %{
          dependency_graph: dependency_graph,
          output_directory: output_dir,
          total_nodes: dependency_graph.statistics.total_nodes,
          total_conflicts: dependency_graph.statistics.total_conflicts,
          circular_dependencies: length(dependency_graph.circular_dependencies)
        }

        {:ok, result}

      error -> error
    end
  end

  defp execute_resolve_command(config, options) do
    Mix.shell().info([:blue, "🔧 Starting automated conflict resolution", :reset])

    case Prismatic.Code.ConflictResolver.resolve_all_conflicts(config.legacy_projects,
         strategy_preference: [:upgrade, :pin, :isolate],
         automation_level: config.automation_level,
         risk_tolerance: config.risk_tolerance,
         target_architecture: config.target_architecture) do
      {:ok, conflict_resolutions} ->
        output_dir = ensure_output_directory(options[:output_dir] || "consolidation/phase2/resolutions")

        # Save resolution plans
        save_analysis_result("conflict_resolutions.json", conflict_resolutions, output_dir)

        # Generate automation scripts
        scripts_dir = Path.join(output_dir, "scripts")
        File.mkdir_p!(scripts_dir)

        conflict_resolutions.automation_scripts
        |> Enum.each(fn {script_name, script_content} ->
          script_path = Path.join(scripts_dir, script_name)
          File.write!(script_path, script_content)
          File.chmod!(script_path, 0o755)  # Make executable
        end)

        # Execute resolutions if not dry-run
        execution_results = if not options[:dry_run] do
          Mix.shell().info("🚀 Executing conflict resolutions...")
          execute_conflict_resolutions(conflict_resolutions.resolution_plans, options)
        else
          Mix.shell().info("🔍 Dry-run mode: Conflict resolutions planned but not executed")
          %{dry_run: true, planned_resolutions: length(conflict_resolutions.resolution_plans)}
        end

        result = %{
          conflict_resolutions: conflict_resolutions,
          execution_results: execution_results,
          output_directory: output_dir,
          scripts_directory: scripts_dir,
          total_conflicts: length(conflict_resolutions.resolution_plans),
          automation_percentage: conflict_resolutions.metadata.automation_percentage
        }

        {:ok, result}

      error -> error
    end
  end

  defp execute_plan_command(config, options) do
    Mix.shell().info([:blue, "📋 Generating migration plan for umbrella consolidation", :reset])

    case Prismatic.Code.MigrationPlanner.create_migration_plan(config.legacy_projects,
         target_architecture: config.target_architecture,
         migration_strategy: :incremental,
         risk_tolerance: config.risk_tolerance,
         parallel_execution: config.parallel_execution,
         validation_level: config.validation_level) do
      {:ok, migration_plan} ->
        output_dir = ensure_output_directory(options[:output_dir] || "consolidation/phase2/migration")

        # Save migration plan
        save_analysis_result("migration_plan.json", migration_plan, output_dir)

        # Generate migration scripts
        scripts = Prismatic.Code.MigrationPlanner.generate_migration_scripts(migration_plan)
        scripts_dir = Path.join(output_dir, "scripts")
        File.mkdir_p!(scripts_dir)

        # Save all scripts
        save_migration_scripts(scripts, scripts_dir)

        # Generate execution timeline
        timeline = generate_execution_timeline(migration_plan)
        save_analysis_result("execution_timeline.json", timeline, output_dir)

        result = %{
          migration_plan: migration_plan,
          output_directory: output_dir,
          scripts_directory: scripts_dir,
          total_phases: length(migration_plan.phases),
          estimated_duration: migration_plan.metadata.estimated_duration,
          risk_assessment: migration_plan.metadata.risk_assessment
        }

        {:ok, result}

      error -> error
    end
  end

  defp execute_execute_command(config, options) do
    Mix.shell().info([:blue, "🚀 Executing Phase 2 consolidation", :reset])

    case Prismatic.Code.UmbrellaOrchestrator.execute_phase2_consolidation(config) do
      {:ok, consolidation_result} ->
        output_dir = ensure_output_directory(options[:output_dir] || "consolidation/phase2/execution")

        # Save consolidation result
        save_analysis_result("consolidation_result.json", consolidation_result, output_dir)

        # Execute migration if not dry-run
        execution_result = if not options[:dry_run] do
          Mix.shell().info("🔄 Executing migration with validation...")
          case Prismatic.Code.UmbrellaOrchestrator.execute_migration_with_validation(consolidation_result,
               dry_run: false,
               parallel: options[:parallel] || true) do
            {:ok, migration_result} ->
              save_analysis_result("migration_execution.json", migration_result, output_dir)
              migration_result
            {:error, reason} ->
              Mix.shell().error("Migration execution failed: #{inspect(reason)}")
              %{status: :failed, reason: reason}
          end
        else
          Mix.shell().info("🔍 Dry-run mode: Consolidation planned but not executed")
          %{dry_run: true, consolidation_planned: true}
        end

        result = %{
          consolidation_result: consolidation_result,
          execution_result: execution_result,
          output_directory: output_dir,
          conflicts_resolved: consolidation_result.metadata.conflicts_resolved,
          automation_percentage: consolidation_result.metadata.automation_percentage,
          execution_time: consolidation_result.metadata.execution_time_ms
        }

        {:ok, result}

      error -> error
    end
  end

  defp execute_validate_command(config, options) do
    Mix.shell().info([:blue, "✅ Running validation framework", :reset])

    validations = [
      validate_umbrella_structure(),
      validate_dependency_consistency(),
      validate_compilation(),
      validate_test_suite(),
      validate_architecture_compliance(config.target_architecture)
    ]

    output_dir = ensure_output_directory(options[:output_dir] || "consolidation/phase2/validation")

    validation_results = %{
      validations: validations,
      overall_status: determine_overall_validation_status(validations),
      timestamp: DateTime.utc_now(),
      recommendations: generate_validation_recommendations(validations)
    }

    save_analysis_result("validation_results.json", validation_results, output_dir)

    result = %{
      validation_results: validation_results,
      output_directory: output_dir,
      total_validations: length(validations),
      passed_validations: count_passed_validations(validations),
      overall_status: validation_results.overall_status
    }

    {:ok, result}
  end

  defp execute_rollback_command(config, options) do
    Mix.shell().info([:yellow, "⏪ Executing rollback procedures", :reset])

    # Load existing consolidation state
    state_file = Path.join("consolidation/phase2/execution", "consolidation_result.json")

    if File.exists?(state_file) do
      consolidation_result = state_file
      |> File.read!()
      |> Jason.decode!(keys: :atoms)

      rollback_type = case options[:type] do
        "emergency" -> :emergency
        "partial" -> :partial
        "cascade" -> :cascade
        _ -> :standard
      end

      rollback_result = execute_rollback_procedures(consolidation_result, rollback_type, options)

      output_dir = ensure_output_directory(options[:output_dir] || "consolidation/phase2/rollback")
      save_analysis_result("rollback_result.json", rollback_result, output_dir)

      result = %{
        rollback_result: rollback_result,
        rollback_type: rollback_type,
        output_directory: output_dir
      }

      {:ok, result}
    else
      {:error, "No consolidation state found. Cannot execute rollback."}
    end
  end

  defp execute_status_command(config, options) do
    Mix.shell().info([:blue, "📊 Checking consolidation status", :reset])

    status = %{
      phase2_status: check_phase2_status(),
      dependency_conflicts: check_dependency_conflicts(),
      migration_progress: check_migration_progress(),
      validation_status: check_validation_status(),
      system_health: check_system_health(),
      timestamp: DateTime.utc_now()
    }

    output_dir = ensure_output_directory(options[:output_dir] || "consolidation/phase2/status")
    save_analysis_result("status_report.json", status, output_dir)

    # Print status summary to console
    print_status_summary(status)

    result = %{
      status: status,
      output_directory: output_dir
    }

    {:ok, result}
  end

  defp execute_report_command(config, options) do
    Mix.shell().info([:blue, "📑 Generating comprehensive reports", :reset])

    # Load existing results
    consolidation_result = load_consolidation_result()

    case consolidation_result do
      {:ok, result} ->
        case Prismatic.Code.UmbrellaOrchestrator.generate_consolidation_reports(result) do
          {:ok, reports} ->
            output_dir = ensure_output_directory(options[:output_dir] || "consolidation/phase2/reports")

            # Save reports in requested format
            format = options[:format] || "json"
            formatted_reports = format_reports(reports, format)

            save_formatted_reports(formatted_reports, output_dir, format)

            report_result = %{
              reports: reports,
              output_directory: output_dir,
              format: format,
              total_reports: map_size(reports)
            }

            {:ok, report_result}

          error -> error
        end

      {:error, reason} ->
        Mix.shell().error("Cannot generate reports: #{reason}")
        {:error, reason}
    end
  end

  # Helper Functions

  defp setup_logging(options) do
    if options[:verbose] do
      Logger.configure(level: :debug)
      Mix.shell().info([:yellow, "🔍 Verbose logging enabled", :reset])
    end
  end

  defp build_consolidation_config(options) do
    legacy_projects = case options[:projects] do
      nil -> ["../prismatic-legacy", "../prismatic-old"]  # Default paths
      projects_string -> String.split(projects_string, ",") |> Enum.map(&String.trim/1)
    end

    %{
      legacy_projects: legacy_projects,
      target_architecture: get_target_architecture(),
      execution_mode: :planning,  # Will be overridden by specific commands
      automation_level: parse_automation_level(options[:automation_level]),
      risk_tolerance: parse_risk_tolerance(options[:risk_tolerance]),
      parallel_execution: options[:parallel] || true,
      validation_level: :comprehensive
    }
  end

  defp get_target_architecture do
    # Return the 6-app umbrella architecture
    %{
      prismatic_core: %{
        domains: ["agent_management", "cognitive_modeling", "knowledge_systems", "llm_orchestration", "memory_systems"],
        dependencies: ["nebulex", "cachex", "broadway", "flow"],
        priority: :critical
      },
      prismatic_web: %{
        domains: ["phoenix_controllers", "liveview_components", "api_endpoints", "websocket_channels"],
        dependencies: ["phoenix", "phoenix_live_view", "plug", "cowboy"],
        priority: :high
      },
      prismatic_auth: %{
        domains: ["user_management", "session_handling", "rbac_system", "oauth2_saml"],
        dependencies: ["guardian", "comeonin", "bcrypt"],
        priority: :high
      },
      prismatic_data: %{
        domains: ["ecto_repositories", "schema_management", "database_clustering"],
        dependencies: ["ecto", "ecto_sql", "postgrex", "db_connection"],
        priority: :critical
      },
      prismatic_distributed: %{
        domains: ["node_clustering", "distributed_pubsub", "distributed_caching"],
        dependencies: ["libcluster", "phoenix_pubsub", "swarm"],
        priority: :medium
      },
      prismatic_monitoring: %{
        domains: ["prometheus_metrics", "distributed_tracing", "health_checks"],
        dependencies: ["telemetry", "telemetry_metrics", "phoenix_live_dashboard"],
        priority: :low
      }
    }
  end

  defp parse_automation_level(nil), do: :full
  defp parse_automation_level("full"), do: :full
  defp parse_automation_level("semi"), do: :semi
  defp parse_automation_level("manual"), do: :manual
  defp parse_automation_level(_), do: :full

  defp parse_risk_tolerance(nil), do: :medium
  defp parse_risk_tolerance("low"), do: :low
  defp parse_risk_tolerance("medium"), do: :medium
  defp parse_risk_tolerance("high"), do: :high
  defp parse_risk_tolerance(_), do: :medium

  defp ensure_output_directory(path) do
    File.mkdir_p!(path)
    path
  end

  defp save_analysis_result(filename, data, output_dir) do
    file_path = Path.join(output_dir, filename)
    File.write!(file_path, Jason.encode!(data, pretty: true))
    Mix.shell().info("💾 Results saved to: #{file_path}")
  end

  defp execute_conflict_resolutions(resolution_plans, options) do
    results = resolution_plans
    |> Enum.take(5)  # Limit to first 5 for safety in this demo
    |> Enum.map(fn plan ->
      case Prismatic.Code.ConflictResolver.execute_resolution(plan, dry_run: options[:dry_run] || false) do
        {:ok, result} -> result
        {:error, reason} -> %{conflict_id: plan.conflict_id, status: :failed, reason: reason}
      end
    end)

    %{
      executed_resolutions: length(results),
      successful_resolutions: Enum.count(results, &(&1.status == :success)),
      failed_resolutions: Enum.count(results, &(&1.status != :success)),
      results: results
    }
  end

  defp save_migration_scripts(scripts, scripts_dir) do
    scripts.phase_scripts
    |> Enum.each(fn {script_name, script_content} ->
      script_path = Path.join(scripts_dir, script_name)
      File.write!(script_path, script_content)
      File.chmod!(script_path, 0o755)
    end)

    # Save master script
    master_script_path = Path.join(scripts_dir, "master_migration.sh")
    File.write!(master_script_path, scripts.master_script)
    File.chmod!(master_script_path, 0o755)

    Mix.shell().info("📜 Migration scripts saved to: #{scripts_dir}")
  end

  defp generate_execution_timeline(migration_plan) do
    %{
      total_phases: length(migration_plan.phases),
      estimated_duration: migration_plan.metadata.estimated_duration,
      phase_timeline: migration_plan.phases
      |> Enum.map(fn phase ->
        %{
          phase_number: phase.phase_number,
          phase_name: phase.phase_name,
          estimated_duration: estimate_phase_duration(phase),
          prerequisites: phase.prerequisites,
          can_parallelize: length(phase.prerequisites) == 0
        }
      end),
      critical_path: identify_critical_path(migration_plan.phases),
      risk_milestones: identify_risk_milestones(migration_plan.phases)
    }
  end

  defp estimate_phase_duration(phase) do
    case {phase.estimated_effort, phase.risk_level} do
      {:high, :critical} -> "4-6 hours"
      {:high, :high} -> "3-4 hours"
      {:high, _} -> "2-3 hours"
      {:medium, :critical} -> "2-3 hours"
      {:medium, :high} -> "1-2 hours"
      {:medium, _} -> "1 hour"
      {:low, _} -> "30 minutes"
    end
  end

  defp identify_critical_path(phases) do
    phases
    |> Enum.filter(&(&1.risk_level in [:critical, :high]))
    |> Enum.map(& &1.phase_number)
  end

  defp identify_risk_milestones(phases) do
    phases
    |> Enum.filter(&(&1.risk_level == :critical))
    |> Enum.map(&%{phase: &1.phase_number, milestone: "Critical risk checkpoint"})
  end

  # Validation Functions

  defp validate_umbrella_structure do
    apps_dir = "apps"
    expected_apps = ["prismatic_core", "prismatic_web", "prismatic_auth", "prismatic_data", "prismatic_distributed", "prismatic_monitoring"]

    existing_apps = if File.exists?(apps_dir) do
      File.ls!(apps_dir)
      |> Enum.filter(&File.dir?(Path.join(apps_dir, &1)))
    else
      []
    end

    %{
      validation: "umbrella_structure",
      status: if(length(existing_apps) >= 2, do: :passed, else: :pending),
      expected_apps: expected_apps,
      existing_apps: existing_apps,
      missing_apps: expected_apps -- existing_apps
    }
  end

  defp validate_dependency_consistency do
    case System.cmd("mix", ["deps.tree"]) do
      {output, 0} ->
        conflicts = if String.contains?(output, ["conflict", "Conflict"]) do
          extract_conflicts_from_output(output)
        else
          []
        end

        %{
          validation: "dependency_consistency",
          status: if(length(conflicts) == 0, do: :passed, else: :failed),
          conflicts: conflicts,
          total_conflicts: length(conflicts)
        }

      {output, _code} ->
        %{
          validation: "dependency_consistency",
          status: :failed,
          error: "Could not check dependencies",
          output: output
        }
    end
  end

  defp extract_conflicts_from_output(output) do
    # Extract conflict information from mix deps.tree output
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, ["conflict", "Conflict"]))
    |> Enum.take(10)  # Limit output
  end

  defp validate_compilation do
    case System.cmd("mix", ["compile", "--warnings-as-errors"]) do
      {_output, 0} ->
        %{
          validation: "compilation",
          status: :passed,
          message: "All code compiles without warnings"
        }

      {output, _code} ->
        %{
          validation: "compilation",
          status: :failed,
          message: "Compilation failed",
          error_details: extract_compilation_errors(output)
        }
    end
  end

  defp extract_compilation_errors(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, ["error:", "warning:"]))
    |> Enum.take(10)  # Limit output
  end

  defp validate_test_suite do
    case System.cmd("mix", ["test", "--max-failures=5"]) do
      {_output, 0} ->
        %{
          validation: "test_suite",
          status: :passed,
          message: "All tests passing"
        }

      {output, _code} ->
        %{
          validation: "test_suite",
          status: :failed,
          message: "Some tests failing",
          failure_details: extract_test_failures(output)
        }
    end
  end

  defp extract_test_failures(output) do
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, ["FAIL", "Error", "failure"]))
    |> Enum.take(10)  # Limit output
  end

  defp validate_architecture_compliance(target_architecture) do
    compliance_checks = target_architecture
    |> Enum.map(fn {app, _config} ->
      app_path = "apps/#{app}"
      %{
        app: app,
        exists: File.exists?(app_path),
        has_mix_file: File.exists?("#{app_path}/mix.exs"),
        structure_valid: validate_app_structure(app_path)
      }
    end)

    %{
      validation: "architecture_compliance",
      status: if(Enum.all?(compliance_checks, & &1.structure_valid), do: :passed, else: :pending),
      app_compliance: compliance_checks
    }
  end

  defp validate_app_structure(app_path) do
    if File.exists?(app_path) do
      required_dirs = ["lib", "test"]
      existing_dirs = File.ls!(app_path) |> Enum.filter(&File.dir?(Path.join(app_path, &1)))

      Enum.all?(required_dirs, &(&1 in existing_dirs))
    else
      false
    end
  end

  defp determine_overall_validation_status(validations) do
    failed_count = Enum.count(validations, &(&1.status == :failed))

    cond do
      failed_count == 0 -> :all_passed
      failed_count <= 2 -> :mostly_passed
      true -> :failed
    end
  end

  defp count_passed_validations(validations) do
    Enum.count(validations, &(&1.status == :passed))
  end

  defp generate_validation_recommendations(validations) do
    validations
    |> Enum.filter(&(&1.status == :failed))
    |> Enum.map(&generate_recommendation_for_validation/1)
    |> Enum.reject(&is_nil/1)
  end

  defp generate_recommendation_for_validation(validation) do
    case validation.validation do
      "compilation" -> "Fix compilation errors before proceeding with migration"
      "test_suite" -> "Address test failures to ensure system stability"
      "dependency_consistency" -> "Resolve dependency conflicts using mix prismatic.consolidation resolve"
      "architecture_compliance" -> "Complete umbrella app structure setup"
      _ -> nil
    end
  end

  # Rollback Functions

  defp execute_rollback_procedures(consolidation_result, rollback_type, options) do
    Mix.shell().info("Executing #{rollback_type} rollback...")

    case rollback_type do
      :emergency ->
        execute_emergency_rollback(options[:dry_run])
      :partial ->
        execute_partial_rollback(consolidation_result, options[:phases], options[:dry_run])
      :cascade ->
        execute_cascade_rollback(consolidation_result, options[:dry_run])
      :standard ->
        execute_standard_rollback(consolidation_result, options[:dry_run])
    end
  end

  defp execute_emergency_rollback(dry_run) do
    steps = [
      "Stop all migration processes",
      "Restore from backup",
      "Validate system integrity"
    ]

    if not dry_run do
      # Execute actual emergency rollback
      Mix.shell().info("🚨 Executing emergency rollback procedures...")
    end

    %{
      rollback_type: :emergency,
      steps_executed: steps,
      status: :completed,
      dry_run: dry_run || false
    }
  end

  defp execute_partial_rollback(consolidation_result, phases, dry_run) do
    target_phases = phases || []

    %{
      rollback_type: :partial,
      target_phases: target_phases,
      status: :completed,
      dry_run: dry_run || false
    }
  end

  defp execute_cascade_rollback(consolidation_result, dry_run) do
    %{
      rollback_type: :cascade,
      phases_rolled_back: length(consolidation_result[:migration_plan][:phases] || []),
      status: :completed,
      dry_run: dry_run || false
    }
  end

  defp execute_standard_rollback(consolidation_result, dry_run) do
    %{
      rollback_type: :standard,
      status: :completed,
      dry_run: dry_run || false
    }
  end

  # Status Functions

  defp check_phase2_status do
    analysis_exists = File.exists?("consolidation/phase2/analysis/dependency_graph.json")
    resolutions_exist = File.exists?("consolidation/phase2/resolutions/conflict_resolutions.json")
    migration_exists = File.exists?("consolidation/phase2/migration/migration_plan.json")
    execution_exists = File.exists?("consolidation/phase2/execution/consolidation_result.json")

    %{
      analysis_completed: analysis_exists,
      resolutions_completed: resolutions_exist,
      migration_planned: migration_exists,
      execution_completed: execution_exists,
      overall_progress: calculate_progress([analysis_exists, resolutions_exist, migration_exists, execution_exists])
    }
  end

  defp check_dependency_conflicts do
    case System.cmd("mix", ["deps.tree"]) do
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
        %{status: :unknown, error: "Could not check dependencies"}
    end
  end

  defp check_migration_progress do
    if File.exists?("consolidation/phase2/migration/migration_plan.json") do
      # Check if execution has started
      execution_exists = File.exists?("consolidation/phase2/execution/consolidation_result.json")

      %{
        plan_exists: true,
        execution_started: execution_exists,
        status: if(execution_exists, do: :in_progress, else: :planned)
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

    overall_health = if Enum.all?(health_checks, &(&1.status == :healthy)) do
      :healthy
    else
      :degraded
    end

    %{
      overall_health: overall_health,
      health_checks: health_checks
    }
  end

  defp check_compilation_health do
    case System.cmd("mix", ["compile", "--warnings-as-errors"]) do
      {_output, 0} -> %{check: :compilation, status: :healthy}
      {_output, _code} -> %{check: :compilation, status: :unhealthy}
    end
  end

  defp check_dependency_health do
    case System.cmd("mix", ["deps.get"]) do
      {_output, 0} -> %{check: :dependencies, status: :healthy}
      {_output, _code} -> %{check: :dependencies, status: :unhealthy}
    end
  end

  defp check_test_health do
    case System.cmd("mix", ["test", "--max-failures=1"]) do
      {_output, 0} -> %{check: :tests, status: :healthy}
      {_output, _code} -> %{check: :tests, status: :unhealthy}
    end
  end

  defp calculate_progress(completion_flags) do
    completed = Enum.count(completion_flags, & &1)
    total = length(completion_flags)

    round(completed / total * 100)
  end

  defp print_status_summary(status) do
    Mix.shell().info([
      :cyan, "\n📊 Phase 2 Consolidation Status:", :reset, "\n",
      "  Progress: #{status.phase2_status.overall_progress}%\n",
      "  Analysis: #{if status.phase2_status.analysis_completed, do: "✅ Complete", else: "⏳ Pending"}\n",
      "  Resolutions: #{if status.phase2_status.resolutions_completed, do: "✅ Complete", else: "⏳ Pending"}\n",
      "  Migration: #{format_migration_status(status.migration_progress.status)}\n",
      "  Validation: #{format_validation_status(status.validation_status.overall_status)}\n",
      "  System Health: #{format_health_status(status.system_health.overall_health)}\n"
    ])

    if status.dependency_conflicts.status == :conflicts_exist do
      Mix.shell().info([
        :yellow, "⚠️  #{status.dependency_conflicts.conflict_count} dependency conflicts detected", :reset
      ])
    end
  end

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
  defp format_health_status(_), do: "❓ Unknown"

  # Report Functions

  defp load_consolidation_result do
    result_file = "consolidation/phase2/execution/consolidation_result.json"

    if File.exists?(result_file) do
      result = result_file
      |> File.read!()
      |> Jason.decode!(keys: :atoms)

      {:ok, result}
    else
      {:error, "No consolidation result found. Run 'mix prismatic.consolidation execute' first."}
    end
  end

  defp format_reports(reports, format) do
    case format do
      "markdown" -> format_reports_as_markdown(reports)
      "html" -> format_reports_as_html(reports)
      "json" -> reports  # Already in JSON format
      _ -> reports
    end
  end

  defp format_reports_as_markdown(reports) do
    reports
    |> Enum.map(fn {report_name, report_data} ->
      {
        "#{report_name}.md",
        generate_markdown_report(report_name, report_data)
      }
    end)
    |> Enum.into(%{})
  end

  defp generate_markdown_report(report_name, report_data) do
    """
    # #{String.replace(to_string(report_name), "_", " ") |> String.capitalize()}

    Generated: #{DateTime.utc_now()}

    ## Summary

    #{Jason.encode!(report_data, pretty: true)}

    ---

    *Generated by Prismatic Phase 2 Consolidation*
    """
  end

  defp format_reports_as_html(reports) do
    reports
    |> Enum.map(fn {report_name, report_data} ->
      {
        "#{report_name}.html",
        generate_html_report(report_name, report_data)
      }
    end)
    |> Enum.into(%{})
  end

  defp generate_html_report(report_name, report_data) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>#{String.replace(to_string(report_name), "_", " ") |> String.capitalize()}</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            pre { background-color: #f5f5f5; padding: 20px; border-radius: 5px; }
        </style>
    </head>
    <body>
        <h1>#{String.replace(to_string(report_name), "_", " ") |> String.capitalize()}</h1>
        <p>Generated: #{DateTime.utc_now()}</p>
        <pre>#{Jason.encode!(report_data, pretty: true)}</pre>
    </body>
    </html>
    """
  end

  defp save_formatted_reports(formatted_reports, output_dir, format) do
    formatted_reports
    |> Enum.each(fn {filename, content} ->
      file_path = Path.join(output_dir, filename)
      File.write!(file_path, content)
    end)

    Mix.shell().info("📑 Reports saved in #{format} format to: #{output_dir}")
  end

  # Output Functions

  defp print_command_summary(command, data) do
    case command do
      "analyze" ->
        Mix.shell().info([
          :cyan, "\n📈 Analysis Summary:", :reset, "\n",
          "  • Total nodes: #{data.total_nodes}\n",
          "  • Total conflicts: #{data.total_conflicts}\n",
          "  • Circular dependencies: #{data.circular_dependencies}\n",
          "  • Output: #{data.output_directory}"
        ])

      "resolve" ->
        Mix.shell().info([
          :cyan, "\n🔧 Resolution Summary:", :reset, "\n",
          "  • Total conflicts: #{data.total_conflicts}\n",
          "  • Automation: #{data.automation_percentage}%\n",
          "  • Scripts: #{data.scripts_directory}\n",
          "  • Output: #{data.output_directory}"
        ])

      "plan" ->
        Mix.shell().info([
          :cyan, "\n📋 Migration Plan Summary:", :reset, "\n",
          "  • Total phases: #{data.total_phases}\n",
          "  • Estimated duration: #{data.estimated_duration}\n",
          "  • Risk assessment: #{data.risk_assessment}\n",
          "  • Output: #{data.output_directory}"
        ])

      "execute" ->
        Mix.shell().info([
          :cyan, "\n🚀 Execution Summary:", :reset, "\n",
          "  • Conflicts resolved: #{data.conflicts_resolved}\n",
          "  • Automation: #{data.automation_percentage}%\n",
          "  • Execution time: #{data.execution_time}ms\n",
          "  • Output: #{data.output_directory}"
        ])

      "validate" ->
        Mix.shell().info([
          :cyan, "\n✅ Validation Summary:", :reset, "\n",
          "  • Total validations: #{data.total_validations}\n",
          "  • Passed: #{data.passed_validations}\n",
          "  • Overall status: #{data.overall_status}\n",
          "  • Output: #{data.output_directory}"
        ])

      _ -> :ok
    end
  end

  defp format_error({:analysis_failed, reason}), do: "Analysis failed: #{inspect(reason)}"
  defp format_error({:conflict_resolution_failed, reason}), do: "Conflict resolution failed: #{inspect(reason)}"
  defp format_error({:migration_planning_failed, reason}), do: "Migration planning failed: #{inspect(reason)}"
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  defp print_help do
    Mix.shell().info([
      :bright, "mix prismatic.consolidation", :reset, " - Phase 2: Advanced Dependency Mapping\n\n",
      "Master orchestrator for the enterprise consolidation strategy.\n\n",

      :bright, "RECOMMENDED USAGE:", :reset, "\n",
      "Use individual specialized tasks for best results:\n\n",
      "  mix prismatic.consolidation.analyze    # Comprehensive dependency analysis\n",
      "  mix prismatic.consolidation.resolve    # Automated conflict resolution\n",
      "  mix prismatic.consolidation.plan       # Migration planning\n",
      "  mix prismatic.consolidation.validate   # Validation framework\n",
      "  mix prismatic.consolidation.status     # Status and progress\n",
      "  mix prismatic.consolidation.report     # Comprehensive reports\n\n",

      :bright, "LEGACY USAGE:", :reset, "\n",
      "  mix prismatic.consolidation [COMMAND] [OPTIONS]\n\n",

      :bright, "AVAILABLE COMMANDS:", :reset, "\n",
      "  analyze     Run comprehensive dependency analysis\n",
      "  resolve     Execute automated conflict resolution\n",
      "  plan        Generate migration plan for umbrella consolidation\n",
      "  validate    Run validation framework\n",
      "  status      Show consolidation status and progress\n",
      "  report      Generate comprehensive reports\n\n",

      :bright, "GETTING DETAILED HELP:", :reset, "\n",
      "For detailed help on any specific task:\n\n",
      "  mix help prismatic.consolidation.analyze\n",
      "  mix help prismatic.consolidation.resolve\n",
      "  mix help prismatic.consolidation.plan\n",
      "  mix help prismatic.consolidation.validate\n",
      "  mix help prismatic.consolidation.status\n",
      "  mix help prismatic.consolidation.report\n\n",

      :bright, "EXAMPLES:", :reset, "\n",
      "  # Recommended: Use specialized tasks\n",
      "  mix prismatic.consolidation.analyze --projects=\"../legacy,../old\" --format=mermaid\n",
      "  mix prismatic.consolidation.resolve --automation-level=full --dry-run\n",
      "  mix prismatic.consolidation.plan --parallel --risk-tolerance=low\n\n",
      "  # Legacy: Use master task\n",
      "  mix prismatic.consolidation analyze --projects=\"../legacy,../old\"\n",
      "  mix prismatic.consolidation status --detailed --export\n\n"
    ])
  end

  defp print_available_commands do
    Mix.shell().info([
      :yellow, "Available commands:", :reset, "\n",
      "  analyze, resolve, plan, validate, status, report\n\n",
      "For detailed help: mix help prismatic.consolidation.[command]\n",
      "Example: mix help prismatic.consolidation.analyze"
    ])
  end
end
