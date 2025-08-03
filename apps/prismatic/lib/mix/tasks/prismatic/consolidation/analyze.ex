defmodule Mix.Tasks.Prismatic.Consolidation.Analyze do
  @moduledoc """
  Runs comprehensive dependency analysis for Phase 2 consolidation.

  This task performs deep dependency graph analysis across legacy projects,
  identifying conflicts, circular dependencies, and generating visualizations
  for the enterprise consolidation strategy.

  ## Usage

      mix prismatic.consolidation.analyze [OPTIONS]

  ## Options

    * `--projects, -p` - Comma-separated list of legacy project paths
      (default: ../prismatic-legacy,../prismatic-old)
    * `--format, -f` - Output format for visualizations (mermaid, dot)
    * `--output-dir, -o` - Output directory (default: consolidation/phase2/analysis)
    * `--max-depth` - Maximum dependency depth to analyze (default: 10)
    * `--include-transitive` - Include transitive dependencies (default: true)
    * `--verbose, -v` - Enable verbose logging
    * `--help, -h` - Show this help

  ## Examples

      # Basic dependency analysis
      mix prismatic.consolidation.analyze

      # Analyze specific projects with Mermaid visualization
      mix prismatic.consolidation.analyze \\
        --projects="../legacy-app,../old-system" \\
        --format=mermaid \\
        --output-dir=analysis/results

      # Deep analysis with verbose output
      mix prismatic.consolidation.analyze --max-depth=15 --verbose

  ## Output Files

  The task generates several analysis files:

    * `dependency_graph.json` - Complete dependency graph data
    * `dependency_graph.mmd` - Mermaid visualization (if --format=mermaid)
    * `conflicts_summary.json` - Summary of detected conflicts
    * `circular_dependencies.json` - List of circular dependencies
    * `analysis_report.md` - Human-readable analysis report

  ## Success Criteria

  The analysis is considered successful when:

    * All specified projects are successfully parsed
    * Dependency graph is constructed without errors
    * All conflicts are identified and catalogued
    * Output files are generated in the specified directory

  For troubleshooting, check the log files in `logs/consolidation.log`.
  """

  @shortdoc "Run comprehensive dependency analysis for Phase 2 consolidation"

  use Mix.Task
  require Logger

  alias Prismatic.Code.DependencyAnalyzer

  @switches [
    projects: :string,
    format: :string,
    output_dir: :string,
    max_depth: :integer,
    include_transitive: :boolean,
    verbose: :boolean,
    help: :boolean
  ]

  @aliases [
    p: :projects,
    f: :format,
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
      execute_analysis(options)
    end
  end

  defp execute_analysis(options) do
    Mix.shell().info([:blue, "🔍 Starting comprehensive dependency analysis", :reset])

    setup_logging(options)
    config = build_analysis_config(options)

    start_time = System.monotonic_time()

    case DependencyAnalyzer.build_dependency_graph(config.legacy_projects,
         target_architecture: config.target_architecture,
         include_transitive: config.include_transitive,
         max_depth: config.max_depth) do
      {:ok, dependency_graph} ->
        output_dir = ensure_output_directory(options[:output_dir] || "consolidation/phase2/analysis")

        # Save dependency graph
        save_analysis_result("dependency_graph.json", dependency_graph, output_dir)

        # Generate visualization if requested
        if options[:format] do
          generate_visualization(dependency_graph, options[:format], output_dir)
        end

        # Generate additional analysis files
        generate_analysis_files(dependency_graph, output_dir)

        duration = System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond)

        Mix.shell().info([
          :green, "✅ Analysis completed successfully in #{duration}ms", :reset, "\n",
          :cyan, "📈 Analysis Summary:", :reset, "\n",
          "  • Total nodes: #{dependency_graph.statistics.total_nodes}\n",
          "  • Total conflicts: #{dependency_graph.statistics.total_conflicts}\n",
          "  • Circular dependencies: #{length(dependency_graph.circular_dependencies)}\n",
          "  • Output directory: #{output_dir}"
        ])

      {:error, reason} ->
        Mix.shell().error([:red, "❌ Analysis failed: #{inspect(reason)}", :reset])
        System.halt(1)
    end
  end

  defp setup_logging(options) do
    if options[:verbose] do
      Logger.configure(level: :debug)
      Mix.shell().info([:yellow, "🔍 Verbose logging enabled", :reset])
    end
  end

  defp build_analysis_config(options) do
    legacy_projects = case options[:projects] do
      nil -> ["../prismatic-legacy", "../prismatic-old"]
      projects_string -> String.split(projects_string, ",") |> Enum.map(&String.trim/1)
    end

    %{
      legacy_projects: legacy_projects,
      target_architecture: get_target_architecture(),
      include_transitive: options[:include_transitive] || true,
      max_depth: options[:max_depth] || 10
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

  defp ensure_output_directory(path) do
    File.mkdir_p!(path)
    path
  end

  defp save_analysis_result(filename, data, output_dir) do
    file_path = Path.join(output_dir, filename)
    File.write!(file_path, Jason.encode!(data, pretty: true))
    Mix.shell().info("💾 Results saved to: #{file_path}")
  end

  defp generate_visualization(dependency_graph, format, output_dir) do
    format_atom = String.to_atom(format)

    case DependencyAnalyzer.visualize_graph(dependency_graph, format_atom) do
      {:ok, diagram} ->
        filename = "dependency_graph.#{format}"
        file_path = Path.join(output_dir, filename)
        File.write!(file_path, diagram)
        Mix.shell().info("📊 Dependency graph visualization saved to #{file_path}")
      {:error, reason} ->
        Mix.shell().error("Failed to generate #{format} visualization: #{inspect(reason)}")
    end
  end

  defp generate_analysis_files(dependency_graph, output_dir) do
    # Generate conflicts summary
    conflicts_summary = %{
      total_conflicts: dependency_graph.statistics.total_conflicts,
      conflict_types: dependency_graph.statistics.conflict_breakdown,
      critical_conflicts: filter_critical_conflicts(dependency_graph.conflicts)
    }
    save_analysis_result("conflicts_summary.json", conflicts_summary, output_dir)

    # Generate circular dependencies report
    save_analysis_result("circular_dependencies.json", dependency_graph.circular_dependencies, output_dir)

    # Generate human-readable report
    generate_analysis_report(dependency_graph, output_dir)
  end

  defp filter_critical_conflicts(conflicts) do
    Enum.filter(conflicts, &(&1.severity == :critical))
  end

  defp generate_analysis_report(dependency_graph, output_dir) do
    report = """
    # Dependency Analysis Report

    Generated: #{DateTime.utc_now()}

    ## Summary

    - **Total Dependencies**: #{dependency_graph.statistics.total_nodes}
    - **Total Conflicts**: #{dependency_graph.statistics.total_conflicts}
    - **Circular Dependencies**: #{length(dependency_graph.circular_dependencies)}

    ## Conflict Breakdown

    #{format_conflict_breakdown(dependency_graph.statistics.conflict_breakdown)}

    ## Critical Issues

    #{format_critical_issues(dependency_graph.conflicts)}

    ## Recommendations

    1. Prioritize resolution of critical conflicts
    2. Address circular dependencies first
    3. Use automated resolution tools where possible
    4. Validate changes thoroughly before deployment

    ---
    *Generated by Prismatic Phase 2 Dependency Analysis*
    """

    File.write!(Path.join(output_dir, "analysis_report.md"), report)
    Mix.shell().info("📑 Analysis report saved to #{output_dir}/analysis_report.md")
  end

  defp format_conflict_breakdown(breakdown) do
    breakdown
    |> Enum.map(fn {type, count} -> "- **#{type}**: #{count} conflicts" end)
    |> Enum.join("\n")
  end

  defp format_critical_issues(conflicts) do
    critical_conflicts = Enum.filter(conflicts, &(&1.severity == :critical))

    if length(critical_conflicts) > 0 do
      critical_conflicts
      |> Enum.take(5)  # Show top 5 critical issues
      |> Enum.map(fn conflict -> "- #{conflict.description}" end)
      |> Enum.join("\n")
    else
      "No critical issues detected."
    end
  end

  defp print_help do
    Mix.shell().info([
      :bright, "mix prismatic.consolidation.analyze", :reset, " - Dependency Analysis\n\n",
      "Runs comprehensive dependency analysis for Phase 2 consolidation.\n\n",

      :bright, "USAGE:", :reset, "\n",
      "  mix prismatic.consolidation.analyze [OPTIONS]\n\n",

      :bright, "OPTIONS:", :reset, "\n",
      "  --projects, -p PATHS       Comma-separated legacy project paths\n",
      "  --format, -f FORMAT        Visualization format (mermaid, dot)\n",
      "  --output-dir, -o DIR       Output directory\n",
      "  --max-depth DEPTH          Maximum dependency depth (default: 10)\n",
      "  --include-transitive       Include transitive dependencies\n",
      "  --verbose, -v              Enable verbose logging\n",
      "  --help, -h                 Show this help\n\n",

      :bright, "EXAMPLES:", :reset, "\n",
      "  # Basic analysis\n",
      "  mix prismatic.consolidation.analyze\n\n",
      "  # Custom projects with visualization\n",
      "  mix prismatic.consolidation.analyze -p \"../app1,../app2\" -f mermaid\n\n",
      "  # Deep analysis with verbose output\n",
      "  mix prismatic.consolidation.analyze --max-depth=15 --verbose\n\n"
    ])
  end
end
