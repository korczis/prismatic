defmodule Mix.Tasks.Code.Analyze do
  @moduledoc """
  Mix task for analyzing Elixir codebases using the Prismatic Code Analyzer.

  This task provides comprehensive analysis of Elixir projects including:
  - AST-based module analysis
  - Dependency relationships
  - Database schemas (Ecto)
  - API endpoints (Phoenix)
  - Technical debt assessment
  - Test coverage analysis

  ## Usage

      mix code.analyze [OPTIONS]

  ## Scope Options

    * `--scope` - Analysis scope: umbrella, app, project (optional, defaults based on context)
    * `--path` - Path to analyze (optional, defaults to current directory or umbrella)
    * `--apps` - Comma-separated list of umbrella apps to analyze (optional, defaults to all)

  ## Analysis Options

    * `--depth` - Analysis depth: surface, standard, deep (optional, defaults to standard)
    * `--exclude` - Comma-separated list of patterns to exclude (optional)
    * `--include-hotspots` - Include performance hotspot analysis (optional, defaults to true)

  ## Output Options

    * `--output` - Output file path (optional, defaults to analysis/report.json)
    * `--format` - Output format: json, yaml, markdown (optional, defaults to json)
    * `--verbose` - Enable verbose logging (optional)

  ## Examples

      # Analyze current umbrella (all apps)
      mix code.analyze

      # Analyze specific umbrella apps
      mix code.analyze --apps "prismatic_core,prismatic_web"

      # Analyze external project
      mix code.analyze --path ../other-project --scope project

      # Generate detailed markdown report
      mix code.analyze --format markdown --depth deep --output analysis.md

      # Quick surface analysis
      mix code.analyze --depth surface --exclude "test/**,spec/**"

  ## Output

  The analysis generates a comprehensive report including:
  - Module inventory and complexity metrics
  - Dependency analysis and conflict detection
  - Database schema mapping
  - API endpoint catalog
  - Technical debt assessment
  - Test coverage analysis
  - Performance hotspot identification
  - Migration recommendations
  """

  use Mix.Task
  require Logger

  alias Prismatic.Code.Analyzer

  @switches [
    path: :string,
    scope: :string,
    apps: :string,
    exclude: :string,
    depth: :string,
    output: :string,
    format: :string,
    verbose: :boolean,
    include_hotspots: :boolean,
    help: :boolean
  ]

  @aliases [
    p: :path,
    s: :scope,
    a: :apps,
    e: :exclude,
    d: :depth,
    o: :output,
    f: :format,
    v: :verbose,
    h: :help
  ]

  @default_output "analysis/report.json"
  @supported_formats ["json", "yaml", "markdown"]

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
    start_time = System.monotonic_time()

    with {:ok, config} <- validate_and_parse_options(options),
         :ok <- setup_logging(config),
         :ok <- ensure_output_directory(config.output),
         {:ok, analysis_result} <- perform_analysis(config),
         :ok <- save_analysis_report(analysis_result, config) do

      duration = System.monotonic_time() - start_time
      duration_ms = System.convert_time_unit(duration, :native, :millisecond)

      # Calculate totals across all projects
      totals = calculate_analysis_totals(analysis_result)

      Mix.shell().info([
        :green, "✅ Analysis completed successfully in #{duration_ms}ms",
        :reset, "\n",
        "📊 Report saved to: ", :bright, config.output,
        :reset, "\n",
        "📈 Analyzed #{totals.total_modules} modules, ",
        "#{totals.total_dependencies} dependencies across #{totals.project_count} project(s)"
      ])

      print_summary(analysis_result)
    else
      {:error, reason} ->
        Mix.shell().error([:red, "❌ Analysis failed: #{format_error(reason)}", :reset])
        System.halt(1)
    end
  end

  defp validate_and_parse_options(options) do
    with {:ok, analysis_config} <- validate_analysis_options(options),
         {:ok, output_path} <- validate_output_path(options),
         {:ok, format} <- validate_format(options) do

      config = %{
        analysis_config: analysis_config,
        output: output_path,
        format: format,
        verbose: Keyword.get(options, :verbose, false),
        include_hotspots: Keyword.get(options, :include_hotspots, true),
        exclude_patterns: parse_exclude_patterns(options),
        depth: parse_depth(options)
      }

      {:ok, config}
    end
  end

  defp validate_analysis_options(options) do
    scope = parse_scope(options)
    path = parse_path(options, scope)
    apps = parse_apps(options)

    case scope do
      :umbrella ->
        if Mix.Project.umbrella?() or umbrella_detected?() do
          {:ok, %{scope: :umbrella, path: :umbrella, apps: apps}}
        else
          {:error, "Umbrella scope requested but not in an umbrella project"}
        end

      :app ->
        case apps do
          [app_name] when is_atom(app_name) ->
            {:ok, %{scope: :app, path: app_name, apps: apps}}
          _ ->
            {:error, "App scope requires exactly one app name"}
        end

      :project ->
        case path do
          nil -> {:error, "Project scope requires --path option"}
          project_path ->
            expanded_path = Path.expand(project_path)
            cond do
              not File.exists?(expanded_path) ->
                {:error, "Project path does not exist: #{project_path}"}

              not File.dir?(expanded_path) ->
                {:error, "Project path is not a directory: #{project_path}"}

              not File.exists?(Path.join(expanded_path, "mix.exs")) ->
                {:error, "No mix.exs found in project path: #{project_path}"}

              true ->
                {:ok, %{scope: :project, path: expanded_path, apps: []}}
            end
        end
    end
  end

  defp parse_scope(options) do
    case Keyword.get(options, :scope) do
      nil ->
        # Auto-detect scope based on context
        cond do
          Mix.Project.umbrella?() or umbrella_detected?() -> :umbrella
          true -> :project
        end

      "umbrella" -> :umbrella
      "app" -> :app
      "project" -> :project
      other ->
        Mix.shell().error("Invalid scope '#{other}', defaulting to project")
        :project
    end
  end

  defp parse_path(options, scope) do
    case Keyword.get(options, :path) do
      nil ->
        case scope do
          :project -> File.cwd!()
          _ -> nil
        end
      path -> path
    end
  end

  defp parse_apps(options) do
    case Keyword.get(options, :apps) do
      nil -> :all
      apps_string ->
        apps_string
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.map(&String.to_atom/1)
    end
  end

  defp parse_depth(options) do
    case Keyword.get(options, :depth, "standard") do
      "surface" -> :surface
      "standard" -> :standard
      "deep" -> :deep
      other ->
        Mix.shell().error("Invalid depth '#{other}', defaulting to standard")
        :standard
    end
  end

  defp umbrella_detected? do
    try do
      mix_exs_path = Path.join(File.cwd!(), "mix.exs")
      if File.exists?(mix_exs_path) do
        content = File.read!(mix_exs_path)
        String.contains?(content, "apps_path:")
      else
        false
      end
    rescue
      _ -> false
    end
  end

  defp validate_output_path(options) do
    output_path = Keyword.get(options, :output, @default_output)
    expanded_path = Path.expand(output_path)

    # Ensure the output directory exists
    output_dir = Path.dirname(expanded_path)

    case File.mkdir_p(output_dir) do
      :ok -> {:ok, expanded_path}
      {:error, reason} -> {:error, "Cannot create output directory: #{reason}"}
    end
  end

  defp validate_format(options) do
    format = Keyword.get(options, :format, "json")

    if format in @supported_formats do
      {:ok, format}
    else
      {:error, "Unsupported format '#{format}'. Supported formats: #{Enum.join(@supported_formats, ", ")}"}
    end
  end

  defp parse_exclude_patterns(options) do
    case Keyword.get(options, :exclude) do
      nil -> []
      exclude_string ->
        exclude_string
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
    end
  end

  defp setup_logging(config) do
    if config.verbose do
      Logger.configure(level: :debug)
      Mix.shell().info([:yellow, "🔍 Verbose logging enabled", :reset])
    end

    :ok
  end

  defp ensure_output_directory(output_path) do
    output_dir = Path.dirname(output_path)

    case File.mkdir_p(output_dir) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to create output directory: #{reason}"}
    end
  end

  defp perform_analysis(config) do
    analysis_target = describe_analysis_target(config.analysis_config)

    Mix.shell().info([
      :blue, "🔍 Starting analysis of: ", :bright, analysis_target, :reset
    ])

    if config.verbose do
      Mix.shell().info([
        :yellow, "📋 Configuration:", :reset, "\n",
        "  • Scope: #{config.analysis_config.scope}\n",
        "  • Target: #{analysis_target}\n",
        "  • Output: #{config.output}\n",
        "  • Format: #{config.format}\n",
        "  • Depth: #{config.depth}\n",
        "  • Include Hotspots: #{config.include_hotspots}\n",
        "  • Exclude Patterns: #{inspect(config.exclude_patterns)}"
      ])
    end

    # Build analysis options for the Analyzer
    analyzer_opts = [
      scope: config.analysis_config.scope,
      include_apps: config.analysis_config.apps,
      exclude_patterns: config.exclude_patterns,
      depth: config.depth
    ]

    case Analyzer.analyze_codebase(config.analysis_config.path, analyzer_opts) do
      {:ok, result} ->
        processed_result = post_process_analysis(result, config)
        {:ok, processed_result}

      error -> error
    end
  end

  defp describe_analysis_target(%{scope: :umbrella, apps: :all}) do
    "umbrella (all apps)"
  end

  defp describe_analysis_target(%{scope: :umbrella, apps: apps}) when is_list(apps) do
    "umbrella apps: #{Enum.join(Enum.map(apps, &to_string/1), ", ")}"
  end

  defp describe_analysis_target(%{scope: :app, path: app_name}) do
    "umbrella app: #{app_name}"
  end

  defp describe_analysis_target(%{scope: :project, path: path}) do
    "project: #{path}"
  end

  defp post_process_analysis(result, config) do
    result
    |> maybe_filter_hotspots(config.include_hotspots)
    |> maybe_exclude_patterns(config)
    |> add_analysis_metadata(config)
  end

  defp maybe_filter_hotspots(result, false) do
    # Filter hotspots from all projects in the result
    Map.new(result, fn {project_key, project_result} ->
      {project_key, Map.delete(project_result, :performance_hotspots)}
    end)
  end

  defp maybe_filter_hotspots(result, true), do: result

  defp maybe_exclude_patterns(result, config) do
    if Enum.empty?(config.exclude_patterns) do
      result
    else
      # Filter out modules and files matching excluded patterns from all projects
      Map.new(result, fn {project_key, project_result} ->
        modules = Enum.reject(project_result.modules || [], fn module ->
          Enum.any?(config.exclude_patterns, &String.contains?(module.file, &1))
        end)

        files = Enum.reject(project_result.files || [], fn file ->
          Enum.any?(config.exclude_patterns, &String.contains?(file, &1))
        end)

        updated_result = Map.merge(project_result, %{modules: modules, files: files})
        {project_key, updated_result}
      end)
    end
  end

  defp add_analysis_metadata(result, config) do
    metadata = %{
      analyzer_version: get_analyzer_version(),
      analysis_timestamp: DateTime.utc_now(),
      analysis_config: %{
        scope: config.analysis_config.scope,
        target: describe_analysis_target(config.analysis_config),
        format: config.format,
        depth: config.depth,
        include_hotspots: config.include_hotspots,
        exclude_patterns: config.exclude_patterns
      }
    }

    # Add metadata to the top level of the result
    Map.put(result, :metadata, metadata)
  end

  defp save_analysis_report(analysis_result, config) do
    Mix.shell().info([:blue, "💾 Saving report to: ", :bright, config.output, :reset])

    case config.format do
      "json" -> save_json_report(analysis_result, config.output)
      "yaml" -> save_yaml_report(analysis_result, config.output)
      "markdown" -> save_markdown_report(analysis_result, config.output)
    end
  end

  defp save_json_report(analysis_result, output_path) do
    json_content = Jason.encode!(analysis_result, pretty: true)

    case File.write(output_path, json_content) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to write JSON report: #{reason}"}
    end
  end

  defp save_yaml_report(analysis_result, output_path) do
    # Would need to add yaml dependency for full implementation
    case YamlElixir.write_to_file(analysis_result, output_path) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to write YAML report: #{reason}"}
    end
  rescue
    UndefinedFunctionError ->
      {:error, "YAML format requires yaml_elixir dependency. Please add it to your mix.exs"}
  end

  defp save_markdown_report(analysis_result, output_path) do
    markdown_content = generate_markdown_report(analysis_result)

    case File.write(output_path, markdown_content) do
      :ok -> :ok
      {:error, reason} -> {:error, "Failed to write Markdown report: #{reason}"}
    end
  end

  defp generate_markdown_report(analysis_result) do
    metadata = analysis_result.metadata
    projects = Map.delete(analysis_result, :metadata)
    totals = calculate_analysis_totals(analysis_result)

    """
    # Code Analysis Report

    Generated on: #{metadata.analysis_timestamp}
    Analyzer Version: #{metadata.analyzer_version}
    Analysis Target: #{metadata.analysis_config.target}
    Analysis Scope: #{metadata.analysis_config.scope}

    ## Overview

    - **Total Projects:** #{totals.project_count}
    - **Total Modules:** #{totals.total_modules}
    - **Total Dependencies:** #{totals.total_dependencies}
    - **Total Schemas:** #{totals.total_schemas}
    - **Total Endpoints:** #{totals.total_endpoints}

    #{Enum.map(projects, fn {project_key, project_result} ->
      generate_project_section(project_key, project_result)
    end) |> Enum.join("\n")}

    ---

    *Report generated by Prismatic Code Analyzer*
    """
  end

  defp generate_project_section(project_key, project_result) do
    """
    ## Project: #{project_key}

    ### Overview
    - **Total Modules:** #{get_in(project_result, [:overview, :total_modules]) || 0}
    - **Total Files:** #{get_in(project_result, [:overview, :total_files]) || 0}
    - **Total Dependencies:** #{get_in(project_result, [:overview, :total_dependencies]) || 0}
    - **Total Schemas:** #{get_in(project_result, [:overview, :total_schemas]) || 0}
    - **Total Endpoints:** #{get_in(project_result, [:overview, :total_endpoints]) || 0}

    #{if get_in(project_result, [:overview, :largest_module]) do
      largest = project_result.overview.largest_module
      """
      ### Largest Module
      - **Name:** #{largest.name}
      - **Lines:** #{largest.line_count}
      """
    else
      ""
    end}

    #{if get_in(project_result, [:overview, :most_complex_module]) do
      complex = project_result.overview.most_complex_module
      """
      ### Most Complex Module
      - **Name:** #{complex.name}
      - **Complexity Score:** #{complex.complexity_score}
      """
    else
      ""
    end}

    #{if get_in(project_result, [:technical_debt]) do
      debt = project_result.technical_debt
      """
      ### Technical Debt
      - **Overall Score:** #{debt.overall_score}
      - **Complexity Issues:** #{length(debt.complexity_issues || [])}
      - **Documentation Coverage:** #{get_in(debt, [:documentation_issues, :coverage_percentage]) || "N/A"}%
      - **TODO Comments:** #{length(debt.todo_comments || [])}
      """
    else
      ""
    end}

    #{if get_in(project_result, [:test_coverage]) do
      coverage = project_result.test_coverage
      """
      ### Test Coverage
      - **Coverage Percentage:** #{coverage.coverage_percentage}%
      - **Total Test Files:** #{coverage.total_test_files}
      - **Missing Tests:** #{length(coverage.missing_tests || [])}
      """
    else
      ""
    end}

    #{if Map.has_key?(project_result, :performance_hotspots) and length(project_result.performance_hotspots) > 0 do
      """
      ### Performance Hotspots
      #{Enum.map(project_result.performance_hotspots, fn hotspot ->
        "- **#{hotspot.module}**: #{hotspot.issue} - #{hotspot.recommendation}"
      end) |> Enum.join("\n")}
      """
    else
      ""
    end}

    #{if get_in(project_result, [:technical_debt, :recommendations]) do
      """
      ### Recommendations
      #{Enum.map(project_result.technical_debt.recommendations, fn rec ->
        "- #{rec}"
      end) |> Enum.join("\n")}
      """
    else
      ""
    end}
    """
  end

  defp calculate_analysis_totals(analysis_result) do
    # Get projects from the analysis result
    projects = analysis_result.projects || []

    totals = Enum.reduce(projects, %{total_modules: 0, total_dependencies: 0, total_schemas: 0, total_endpoints: 0, project_count: 0}, fn project_result, acc ->
      %{
        total_modules: acc.total_modules + (get_in(project_result, [:overview, :total_modules]) || 0),
        total_dependencies: acc.total_dependencies + (get_in(project_result, [:overview, :total_dependencies]) || 0),
        total_schemas: acc.total_schemas + (get_in(project_result, [:overview, :total_schemas]) || 0),
        total_endpoints: acc.total_endpoints + (get_in(project_result, [:overview, :total_endpoints]) || 0),
        project_count: acc.project_count + 1
      }
    end)

    totals
  end

  defp print_summary(analysis_result) do
    totals = calculate_analysis_totals(analysis_result)

    Mix.shell().info([
      :cyan, "\n📊 Analysis Summary:", :reset, "\n",
      "  • Projects: #{totals.project_count}\n",
      "  • Modules: #{totals.total_modules}\n",
      "  • Dependencies: #{totals.total_dependencies}\n",
      "  • Schemas: #{totals.total_schemas}\n",
      "  • Endpoints: #{totals.total_endpoints}"
    ])

    # Show summary for each project
    projects = analysis_result.projects || []

    Enum.each(projects, fn project_result ->
      Mix.shell().info([
        :bright, "\n  #{project_result.name}:", :reset, "\n",
        "    • Modules: #{get_in(project_result, [:overview, :total_modules]) || 0}\n",
        "    • Dependencies: #{get_in(project_result, [:overview, :total_dependencies]) || 0}\n",
        "    • Technical Debt Score: #{get_in(project_result, [:technical_debt, :overall_score]) || "N/A"}\n",
        "    • Test Coverage: #{get_in(project_result, [:test_coverage, :coverage_percentage]) || "N/A"}%"
      ])

      # Check for performance hotspots in this project
      if Map.has_key?(project_result, :performance_hotspots) and
         length(project_result.performance_hotspots) > 0 do
        Mix.shell().info([
          :yellow, "    ⚠️  Performance Hotspots: #{length(project_result.performance_hotspots)}", :reset
        ])
      end

      # Check for high technical debt in this project
      if get_in(project_result, [:technical_debt, :overall_score]) &&
         project_result.technical_debt.overall_score > 50 do
        Mix.shell().info([
          :red, "    🚨 High Technical Debt Detected", :reset
        ])
      end
    end)
  end

  defp format_error({:invalid_path, message}), do: message
  defp format_error({:invalid_project, message}), do: message
  defp format_error({:module_extraction_failed, error}), do: "Module extraction failed: #{inspect(error)}"
  defp format_error({:dependency_analysis_failed, error}), do: "Dependency analysis failed: #{inspect(error)}"
  defp format_error({:schema_extraction_failed, error}), do: "Schema extraction failed: #{inspect(error)}"
  defp format_error({:endpoint_extraction_failed, error}), do: "Endpoint extraction failed: #{inspect(error)}"
  defp format_error({:technical_debt_assessment_failed, error}), do: "Technical debt assessment failed: #{inspect(error)}"
  defp format_error({:test_coverage_analysis_failed, error}), do: "Test coverage analysis failed: #{inspect(error)}"
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)

  defp get_analyzer_version do
    case Application.spec(:prismatic, :vsn) do
      nil -> "unknown"
      version -> to_string(version)
    end
  end

  defp print_help do
    Mix.shell().info([
      :bright, "mix code.analyze", :reset, " - Analyze Elixir codebases\n\n",

      :bright, "USAGE:", :reset, "\n",
      "  mix code.analyze [OPTIONS]\n\n",

      :bright, "SCOPE OPTIONS:", :reset, "\n",
      "  --scope SCOPE               Analysis scope: umbrella|app|project (auto-detected)\n",
      "  --path, -p PATH             Path to analyze (optional, defaults to current directory)\n",
      "  --apps, -a APPS             Comma-separated list of umbrella apps (optional, defaults to all)\n\n",

      :bright, "ANALYSIS OPTIONS:", :reset, "\n",
      "  --depth, -d DEPTH           Analysis depth: surface|standard|deep (default: standard)\n",
      "  --exclude, -e PATTERNS      Comma-separated patterns to exclude (optional)\n",
      "  --include-hotspots          Include performance hotspot analysis (default: true)\n\n",

      :bright, "OUTPUT OPTIONS:", :reset, "\n",
      "  --output, -o FILE           Output file path (default: analysis/report.json)\n",
      "  --format, -f FORMAT         Output format: json|yaml|markdown (default: json)\n",
      "  --verbose, -v               Enable verbose logging\n",
      "  --help, -h                  Show this help message\n\n",

      :bright, "EXAMPLES:", :reset, "\n",
      "  # Analyze current umbrella (all apps)\n",
      "  mix code.analyze\n\n",
      "  # Analyze specific umbrella apps\n",
      "  mix code.analyze --apps \"prismatic_core,prismatic_web\"\n\n",
      "  # Analyze external project\n",
      "  mix code.analyze --path ../other-project --scope project\n\n",
      "  # Generate detailed markdown report\n",
      "  mix code.analyze --format markdown --depth deep --output analysis.md\n\n",
      "  # Quick surface analysis with exclusions\n",
      "  mix code.analyze --depth surface --exclude \"test/**,spec/**\"\n\n",

      :bright, "OUTPUT:", :reset, "\n",
      "  The analysis generates comprehensive reports including module analysis,\n",
      "  dependency mapping, schema extraction, technical debt assessment,\n",
      "  test coverage analysis, and performance hotspot identification.\n",
      "  \n",
      "  Reports can be generated in JSON, YAML, or Markdown format and include\n",
      "  actionable recommendations for code improvements and consolidation.\n"
    ])
  end
end
