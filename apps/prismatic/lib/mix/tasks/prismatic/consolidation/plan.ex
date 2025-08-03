defmodule Mix.Tasks.Prismatic.Consolidation.Plan do
  @moduledoc """
  Generates comprehensive migration plan for Phase 2 umbrella consolidation.

  This task creates a detailed migration plan that integrates with the 6-app umbrella
  architecture, providing dependency-aware sequencing, parallel execution opportunities,
  and comprehensive rollback strategies.

  ## Usage

      mix prismatic.consolidation.plan [OPTIONS]

  ## Options

    * `--projects, -p` - Comma-separated list of legacy project paths
      (default: ../prismatic-legacy,../prismatic-old)
    * `--parallel` - Enable parallel execution planning (default: true)
    * `--risk-tolerance, -r` - Risk tolerance: low, medium, high (default: medium)
    * `--migration-strategy` - Strategy: incremental, big-bang (default: incremental)
    * `--output-dir, -o` - Output directory (default: consolidation/phase2/migration)
    * `--generate-scripts` - Generate migration automation scripts (default: true)
    * `--validation-level` - Validation level: basic, standard, comprehensive (default: comprehensive)
    * `--verbose, -v` - Enable verbose logging
    * `--help, -h` - Show this help

  ## Target Architecture

  The migration plan integrates with the 6-app umbrella architecture:

    * **prismatic_core** - Agent management, cognitive modeling, knowledge systems
    * **prismatic_web** - Phoenix controllers, LiveView components, API endpoints
    * **prismatic_auth** - User management, session handling, RBAC system
    * **prismatic_data** - Ecto repositories, schema management, database clustering
    * **prismatic_distributed** - Node clustering, distributed PubSub, caching
    * **prismatic_monitoring** - Prometheus metrics, distributed tracing, health checks

  ## Examples

      # Generate basic migration plan
      mix prismatic.consolidation.plan

      # Conservative migration plan with low risk tolerance
      mix prismatic.consolidation.plan \\
        --risk-tolerance=low \\
        --migration-strategy=incremental \\
        --parallel=false

      # Custom projects with comprehensive validation
      mix prismatic.consolidation.plan \\
        --projects="../app1,../app2" \\
        --validation-level=comprehensive \\
        --output-dir=migration/custom

      # Generate migration plan with scripts
      mix prismatic.consolidation.plan --generate-scripts --verbose

  ## Migration Strategies

    * **Incremental** - Gradual migration with validation checkpoints (recommended)
    * **Big-Bang** - Complete migration in single phase (higher risk)

  ## Output Files

  The task generates comprehensive migration artifacts:

    * `migration_plan.json` - Complete migration plan with phases and dependencies
    * `scripts/` - Directory containing executable migration scripts
    * `execution_timeline.json` - Detailed timeline with duration estimates
    * `rollback_procedures.json` - Complete rollback plans for each phase
    * `validation_checkpoints.json` - Strategic validation points
    * `migration_report.md` - Human-readable migration plan

  ## Migration Phases

  The generated plan includes optimized migration phases:

    1. **Foundation Setup** - Core infrastructure and dependencies
    2. **Data Layer Migration** - Database schemas and repositories
    3. **Business Logic Migration** - Core application logic
    4. **API and Web Layer** - Controllers, endpoints, and UI components
    5. **Authentication Integration** - User management and security
    6. **Distributed Systems** - Clustering and communication
    7. **Monitoring Integration** - Metrics, tracing, and health checks

  ## Success Criteria

  The migration plan is considered complete when:

    * All legacy modules are mapped to target applications
    * Dependency ordering is validated and optimized
    * Parallel execution opportunities are identified
    * Rollback procedures are defined for each phase
    * Automation scripts are generated and validated

  For troubleshooting, check the log files in `logs/consolidation.log`.
  """

  @shortdoc "Generate migration plan for 6-app umbrella consolidation"

  use Mix.Task
  require Logger

  alias Prismatic.Code.MigrationPlanner

  @switches [
    projects: :string,
    parallel: :boolean,
    risk_tolerance: :string,
    migration_strategy: :string,
    output_dir: :string,
    generate_scripts: :boolean,
    validation_level: :string,
    verbose: :boolean,
    help: :boolean
  ]

  @aliases [
    p: :projects,
    r: :risk_tolerance,
    o: :output_dir,
    v: :verbose,
    h: :help
  ]

  @impl Mix.Task
  def run(args) do
    {options, _remaining_args, _invalid} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    if options[:help] do
      print_help()
    else
      execute_planning(options)
    end
  end

  defp execute_planning(options) do
    Mix.shell().info([:blue, "📋 Generating migration plan for umbrella consolidation", :reset])

    setup_logging(options)
    config = build_planning_config(options)

    start_time = System.monotonic_time()

    case MigrationPlanner.create_migration_plan(config.legacy_projects,
         target_architecture: config.target_architecture,
         migration_strategy: config.migration_strategy,
         risk_tolerance: config.risk_tolerance,
         parallel_execution: config.parallel_execution,
         validation_level: config.validation_level) do
      {:ok, migration_plan} ->
        output_dir = ensure_output_directory(options[:output_dir] || "consolidation/phase2/migration")

        # Save migration plan
        save_planning_result("migration_plan.json", migration_plan, output_dir)

        # Generate migration scripts if requested
        if options[:generate_scripts] != false do
          generate_migration_scripts(migration_plan, output_dir)
        end

        # Generate additional planning files
        generate_planning_files(migration_plan, output_dir)

        duration = System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond)

        Mix.shell().info([
          :green, "✅ Migration plan generated successfully in #{duration}ms", :reset, "\n",
          :cyan, "📋 Migration Plan Summary:", :reset, "\n",
          "  • Total phases: #{length(migration_plan.phases)}\n",
          "  • Estimated duration: #{migration_plan.metadata.estimated_duration}\n",
          "  • Risk assessment: #{migration_plan.metadata.risk_assessment}\n",
          "  • Parallel phases: #{count_parallel_phases(migration_plan.phases)}\n",
          "  • Output directory: #{output_dir}"
        ])

      {:error, reason} ->
        Mix.shell().error([:red, "❌ Migration planning failed: #{inspect(reason)}", :reset])
        System.halt(1)
    end
  end

  defp setup_logging(options) do
    if options[:verbose] do
      Logger.configure(level: :debug)
      Mix.shell().info([:yellow, "🔍 Verbose logging enabled", :reset])
    end
  end

  defp build_planning_config(options) do
    legacy_projects = case options[:projects] do
      nil -> ["../prismatic-legacy", "../prismatic-old"]
      projects_string -> String.split(projects_string, ",") |> Enum.map(&String.trim/1)
    end

    %{
      legacy_projects: legacy_projects,
      target_architecture: get_target_architecture(),
      migration_strategy: parse_migration_strategy(options[:migration_strategy]),
      risk_tolerance: parse_risk_tolerance(options[:risk_tolerance]),
      parallel_execution: options[:parallel] || true,
      validation_level: parse_validation_level(options[:validation_level])
    }
  end

  defp get_target_architecture do
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

  defp parse_migration_strategy(nil), do: :incremental
  defp parse_migration_strategy("incremental"), do: :incremental
  defp parse_migration_strategy("big-bang"), do: :big_bang
  defp parse_migration_strategy(_), do: :incremental

  defp parse_risk_tolerance(nil), do: :medium
  defp parse_risk_tolerance("low"), do: :low
  defp parse_risk_tolerance("medium"), do: :medium
  defp parse_risk_tolerance("high"), do: :high
  defp parse_risk_tolerance(_), do: :medium

  defp parse_validation_level(nil), do: :comprehensive
  defp parse_validation_level("basic"), do: :basic
  defp parse_validation_level("standard"), do: :standard
  defp parse_validation_level("comprehensive"), do: :comprehensive
  defp parse_validation_level(_), do: :comprehensive

  defp ensure_output_directory(path) do
    File.mkdir_p!(path)
    path
  end

  defp save_planning_result(filename, data, output_dir) do
    file_path = Path.join(output_dir, filename)
    File.write!(file_path, Jason.encode!(data, pretty: true))
    Mix.shell().info("💾 Migration plan saved to: #{file_path}")
  end

  defp generate_migration_scripts(migration_plan, output_dir) do
    scripts = MigrationPlanner.generate_migration_scripts(migration_plan)
    scripts_dir = Path.join(output_dir, "scripts")
    File.mkdir_p!(scripts_dir)

    # Save phase scripts
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

    Mix.shell().info("📜 Migration scripts generated in: #{scripts_dir}")
  end

  defp generate_planning_files(migration_plan, output_dir) do
    # Generate execution timeline
    timeline = generate_execution_timeline(migration_plan)
    save_planning_result("execution_timeline.json", timeline, output_dir)

    # Generate rollback procedures
    save_planning_result("rollback_procedures.json", migration_plan.rollback_strategies, output_dir)

    # Generate validation checkpoints
    save_planning_result("validation_checkpoints.json", migration_plan.validation_checkpoints, output_dir)

    # Generate human-readable report
    generate_migration_report(migration_plan, output_dir)
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

  defp count_parallel_phases(phases) do
    Enum.count(phases, &(length(&1.prerequisites) == 0))
  end

  defp generate_migration_report(migration_plan, output_dir) do
    report = """
    # Migration Plan Report

    Generated: #{DateTime.utc_now()}

    ## Overview

    - **Total Phases**: #{length(migration_plan.phases)}
    - **Estimated Duration**: #{migration_plan.metadata.estimated_duration}
    - **Risk Assessment**: #{migration_plan.metadata.risk_assessment}
    - **Migration Strategy**: #{migration_plan.metadata.migration_strategy}

    ## Phase Breakdown

    #{format_phase_breakdown(migration_plan.phases)}

    ## Target Architecture

    The migration plan consolidates legacy systems into a 6-app umbrella:

    - **prismatic_core** - Agent management, cognitive modeling, knowledge systems
    - **prismatic_web** - Phoenix controllers, LiveView components, API endpoints
    - **prismatic_auth** - User management, session handling, RBAC system
    - **prismatic_data** - Ecto repositories, schema management, database clustering
    - **prismatic_distributed** - Node clustering, distributed PubSub, caching
    - **prismatic_monitoring** - Prometheus metrics, distributed tracing, health checks

    ## Risk Mitigation

    #{format_risk_mitigation(migration_plan.risk_mitigation)}

    ## Rollback Strategy

    Complete rollback procedures are available for each phase with:
    - Automated rollback scripts
    - Data backup and restoration
    - Validation checkpoints
    - Emergency procedures

    ## Next Steps

    1. Review migration plan with stakeholders
    2. Execute dependency analysis if not complete
    3. Resolve any remaining conflicts
    4. Run migration validation
    5. Execute migration phases according to plan

    ---
    *Generated by Prismatic Phase 2 Migration Planning*
    """

    File.write!(Path.join(output_dir, "migration_report.md"), report)
    Mix.shell().info("📑 Migration report saved to #{output_dir}/migration_report.md")
  end

  defp format_phase_breakdown(phases) do
    phases
    |> Enum.map(fn phase ->
      """
      ### Phase #{phase.phase_number}: #{phase.phase_name}
      - **Target App**: #{phase.target_app}
      - **Effort**: #{phase.estimated_effort}
      - **Risk Level**: #{phase.risk_level}
      - **Prerequisites**: #{Enum.join(phase.prerequisites, ", ")}
      """
    end)
    |> Enum.join("\n")
  end

  defp format_risk_mitigation(risk_mitigation) when is_map(risk_mitigation) do
    risk_mitigation
    |> Enum.map(fn {risk, mitigation} ->
      "- **#{risk}**: #{mitigation}"
    end)
    |> Enum.join("\n")
  end
  defp format_risk_mitigation(_), do: "Comprehensive risk mitigation strategies included."

  defp print_help do
    Mix.shell().info([
      :bright, "mix prismatic.consolidation.plan", :reset, " - Migration Planning\n\n",
      "Generates comprehensive migration plan for Phase 2 umbrella consolidation.\n\n",

      :bright, "USAGE:", :reset, "\n",
      "  mix prismatic.consolidation.plan [OPTIONS]\n\n",

      :bright, "OPTIONS:", :reset, "\n",
      "  --projects, -p PATHS       Comma-separated legacy project paths\n",
      "  --parallel                 Enable parallel execution planning\n",
      "  --risk-tolerance, -r LVL   Risk tolerance (low/medium/high)\n",
      "  --migration-strategy STR   Strategy (incremental/big-bang)\n",
      "  --output-dir, -o DIR       Output directory\n",
      "  --generate-scripts         Generate migration automation scripts\n",
      "  --validation-level LVL     Validation level (basic/standard/comprehensive)\n",
      "  --verbose, -v              Enable verbose logging\n",
      "  --help, -h                 Show this help\n\n",

      :bright, "STRATEGIES:", :reset, "\n",
      "  incremental    Gradual migration with validation checkpoints (recommended)\n",
      "  big-bang       Complete migration in single phase (higher risk)\n\n",

      :bright, "EXAMPLES:", :reset, "\n",
      "  # Basic migration plan\n",
      "  mix prismatic.consolidation.plan\n\n",
      "  # Conservative approach\n",
      "  mix prismatic.consolidation.plan -r low --migration-strategy=incremental\n\n",
      "  # Custom projects with comprehensive validation\n",
      "  mix prismatic.consolidation.plan -p \"../app1,../app2\" --validation-level=comprehensive\n\n"
    ])
  end
end
