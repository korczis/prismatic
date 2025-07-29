defmodule Mix.Tasks.Docs.Tasks.Analyze do
  @moduledoc """
  Enterprise-grade comprehensive documentation analysis engine.

  Performs multi-dimensional analysis of documentation including ADR extraction,
  code example analysis, traceability generation, and AI data structuring.
  Designed for CI/CD integration with progress monitoring and detailed reporting.

  ## Analysis Dimensions

  ### Architecture Analysis
  - Extract and analyze Architecture Decision Records (ADRs)
  - Identify decision patterns and architectural domains
  - Generate decision timeline and impact analysis

  ### Content Analysis
  - Extract and categorize code examples by language and type
  - Identify executable vs conceptual examples
  - Analyze transformation candidates for automation

  ### Traceability Analysis
  - Generate bidirectional documentation-code traceability
  - Identify orphaned documentation and code
  - Calculate coverage metrics and sync health scores

  ### AI Integration Analysis
  - Generate AI-optimized structured data formats
  - Create knowledge graphs for automated processing
  - Prepare content for automated enhancement workflows

  ## Options

    * `--docs PATH` - Documentation directory (default: docs)
    * `--code PATH` - Code directory (default: apps)
    * `--output FORMAT` - Output format: json, yaml, report, html (default: json)
    * `--file PATH` - Output file path (auto-generated if not specified)
    * `--sections LIST` - Analysis sections: all, adrs, examples, trace, ai (default: all)
    * `--parallel` - Enable parallel processing for large datasets
    * `--ci` - CI/CD mode with structured output and exit codes
    * `--progress` - Show detailed progress indicators (default: true)
    * `--verbose` - Enable verbose diagnostic output
    * `--dry-run` - Validate inputs without performing analysis

  ## Examples

  ### Basic Analysis
      # Quick comprehensive analysis
      mix docs.analyze

      # Verbose analysis with progress monitoring
      mix docs.analyze --verbose --progress

      # Analysis with custom paths
      mix docs.analyze --docs documentation --code lib

  ### CI/CD Integration
      # CI-friendly analysis with JSON output
      mix docs.analyze --ci --output json --file analysis-report.json

      # HTML report for stakeholders
      mix docs.analyze --output html --file docs-health-report.html

  ### Selective Analysis
      # Only ADR and traceability analysis
      mix docs.analyze --sections adrs,trace --output report

      # Performance-optimized analysis
      mix docs.analyze --parallel --sections examples,ai

  ## Performance

  For large documentation sets (>1000 files):
  - Use `--parallel` for concurrent processing
  - Specify `--sections` to limit analysis scope
  - Consider `--dry-run` for input validation

  ## Output Formats

  - **json**: Machine-readable structured data for automation
  - **yaml**: Human-readable structured data for configuration
  - **report**: Formatted text report for terminal viewing
  - **html**: Rich interactive report for stakeholder presentation

  Related: [Documentation Analysis Architecture](docs/guides/documentation-analysis.md)
  """

  use Mix.Task

  alias Prismatic.Documentation
  alias Mix.Tasks.Docs.Shared.{Config, ErrorHandler, OutputFormatter, ProgressMonitor}

  require Logger

  @shortdoc "Enterprise comprehensive documentation analysis with progress monitoring"

  # Analysis sections that can be run independently
  @available_sections ~w(adrs examples trace ai)
  @default_sections @available_sections

  @task_defaults %{
    sections: @default_sections,
    parallel: false,
    show_progress: true,
    dry_run: false,
    file_prefix: "docs-analysis"
  }

  @impl Mix.Task
  def run(args) do
    start_time = System.monotonic_time(:millisecond)

    ErrorHandler.safe_execute("analyze", "task execution", fn ->
      case parse_and_validate_options(args) do
        {:ok, %{help: true}} ->
          show_comprehensive_help()

        {:ok, options} ->
          if options[:dry_run] do
            run_dry_run_validation(options)
          else
            run_comprehensive_analysis(options, start_time)
          end

        {:error, reason} ->
          ErrorHandler.handle_validation_error(reason, "analyze")
      end
    end)
  end

  @doc false
  def parse_and_validate_options(args) do
    {options, _, invalid} = OptionParser.parse(args,
      switches: [
        docs: :string,
        code: :string,
        output: :string,
        file: :string,
        sections: :string,
        parallel: :boolean,
        ci: :boolean,
        progress: :boolean,
        verbose: :boolean,
        dry_run: :boolean,
        help: :boolean
      ],
      aliases: [
        d: :docs,
        c: :code,
        o: :output,
        f: :file,
        s: :sections,
        p: :parallel,
        v: :verbose,
        h: :help
      ]
    )

    if options[:help] do
      {:ok, %{help: true}}
    else
      case validate_options(options, invalid) do
        :ok -> {:ok, normalize_options(options)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # Private functions

  defp validate_options(options, invalid) do
    cond do
      length(invalid) > 0 ->
        {:error, "Invalid arguments: #{inspect(invalid)}"}

      options[:output] && options[:output] not in Config.output_formats() ->
        {:error, "Invalid output format '#{options[:output]}'. Available: #{Enum.join(Config.output_formats(), ", ")}"}

      options[:sections] && not valid_sections?(options[:sections]) ->
        {:error, "Invalid sections. Available: #{Enum.join(@available_sections, ", ")}"}

      true ->
        with :ok <- validate_paths(options) do
          :ok
        end
    end
  end

  defp valid_sections?(sections_string) do
    sections = parse_sections(sections_string)
    Enum.all?(sections, &(&1 in @available_sections))
  end

  defp validate_paths(options) do
    cond do
      options[:docs] && not File.dir?(options[:docs]) ->
        {:error, "Documentation directory '#{options[:docs]}' does not exist"}

      options[:code] && not File.dir?(options[:code]) ->
        {:error, "Code directory '#{options[:code]}' does not exist"}

      true ->
        :ok
    end
  end

  defp normalize_options(options) do
    base_config = Config.normalize_config(options, @task_defaults)

    Map.merge(base_config, %{
      sections: parse_sections(options[:sections]) || @default_sections,
      parallel: options[:parallel] || false,
      show_progress: Keyword.get(options, :progress, true),
      dry_run: options[:dry_run] || false
    })
  end

  defp parse_sections(nil), do: @default_sections
  defp parse_sections("all"), do: @default_sections
  defp parse_sections(sections_string) when is_binary(sections_string) do
    sections_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 in @available_sections))
  end

  defp run_dry_run_validation(options) do
    Mix.shell().info([
      :blue, "🔍 Dry Run - Documentation Analysis Validation", :reset
    ])

    Config.display_config(options, "analysis")

    validation_results = [
      validate_file_access(options),
      validate_dependencies(),
      estimate_analysis_time(options)
    ]

    if Enum.all?(validation_results, &(&1.status == :ok)) do
      Mix.shell().info([
        :green, "✅ All validations passed. Ready to run analysis.", :reset
      ])
    else
      failed_validations = Enum.filter(validation_results, &(&1.status != :ok))
      Mix.shell().error("❌ Validation failed:")
      Enum.each(failed_validations, fn result ->
        Mix.shell().error("  • #{result.message}")
      end)
      if options.ci_mode, do: System.halt(1)
    end
  end

  defp run_comprehensive_analysis(options, start_time) do
    if options.verbose do
      Config.display_config(options, "analysis")
    end

    # Initialize progress tracking
    progress_pid = ProgressMonitor.start_monitor(options.sections, options.show_progress)

    # Ensure Mix application is started
    Mix.Task.run("app.start")

    try do
      # Validate file access
      ErrorHandler.validate_file_access(options.docs_path, "Documentation directory")
      ErrorHandler.validate_file_access(options.code_path, "Code directory")
      ErrorHandler.validate_output_directory(options.output_file)

      # Run analysis with progress monitoring
      analysis_result = perform_analysis_with_progress(options, progress_pid)

      if options.verbose do
        print_comprehensive_analysis_summary(analysis_result)
      end

      # Save results in requested format
      case OutputFormatter.save_results(analysis_result, options) do
        :ok ->
          execution_time = System.monotonic_time(:millisecond) - start_time
          ProgressMonitor.show_completion("Analysis", execution_time)
          ProgressMonitor.show_output_saved(options.output_file)

        {:error, reason} ->
          ErrorHandler.handle_file_error(reason, options.output_file)
      end

      if options.ci_mode do
        OutputFormatter.format_ci_summary(analysis_result, "analyze")
      end

    rescue
      error ->
        execution_time = System.monotonic_time(:millisecond) - start_time
        ErrorHandler.handle_task_error(error, execution_time, "analysis", __STACKTRACE__)
    after
      ProgressMonitor.stop_monitor(progress_pid)
    end
  end

  defp perform_analysis_with_progress(options, progress_pid) do
    analysis_functions = %{
      "adrs" => &run_adr_analysis/3,
      "examples" => &run_examples_analysis/3,
      "trace" => &run_traceability_analysis/3,
      "ai" => &run_ai_analysis/3
    }

    results = %{
      analysis_timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      analysis_version: "2.0.0",
      configuration: options
    }

    Enum.reduce(options.sections, results, fn section, acc ->
      ProgressMonitor.update_section(progress_pid, section)

      analysis_function = Map.get(analysis_functions, section)
      section_result = analysis_function.(options.docs_path, options.code_path, progress_pid)

      ProgressMonitor.complete_section(progress_pid, section)

      Map.put(acc, String.to_atom(section), section_result)
    end)
  end

  defp run_adr_analysis(docs_path, _code_path, progress_pid) do
    ProgressMonitor.update_progress(progress_pid, "adrs", 25)

    alias Prismatic.Documentation.ADRExtractor
    result = ADRExtractor.extract_all_adrs(docs_path)

    ProgressMonitor.update_progress(progress_pid, "adrs", 100)
    result
  end

  defp run_examples_analysis(docs_path, _code_path, progress_pid) do
    ProgressMonitor.update_progress(progress_pid, "examples", 25)

    alias Prismatic.Documentation.CodeExampleExtractor
    result = CodeExampleExtractor.extract_all_examples(docs_path)

    ProgressMonitor.update_progress(progress_pid, "examples", 100)
    result
  end

  defp run_traceability_analysis(docs_path, code_path, progress_pid) do
    ProgressMonitor.update_progress(progress_pid, "trace", 25)

    alias Prismatic.Documentation.TraceabilityMarker
    result = TraceabilityMarker.generate_markers(docs_path, code_path)

    ProgressMonitor.update_progress(progress_pid, "trace", 100)
    result
  end

  defp run_ai_analysis(docs_path, _code_path, progress_pid) do
    ProgressMonitor.update_progress(progress_pid, "ai", 25)

    alias Prismatic.Documentation.AIAssistantIntegration
    result = AIAssistantIntegration.generate_structured_data(docs_path, [format: :json])

    ProgressMonitor.update_progress(progress_pid, "ai", 100)
    result
  end

  defp validate_file_access(options) do
    cond do
      not File.dir?(options.docs_path) ->
        %{status: :error, message: "Documentation directory '#{options.docs_path}' not accessible"}

      not File.dir?(options.code_path) ->
        %{status: :error, message: "Code directory '#{options.code_path}' not accessible"}

      not File.dir?(Path.dirname(options.output_file)) ->
        %{status: :error, message: "Output directory '#{Path.dirname(options.output_file)}' not writable"}

      true ->
        %{status: :ok, message: "All file paths accessible"}
    end
  end

  defp validate_dependencies do
    required_modules = [
      Prismatic.Documentation,
      Prismatic.Documentation.ADRExtractor,
      Prismatic.Documentation.CodeExampleExtractor,
      Prismatic.Documentation.TraceabilityMarker,
      Prismatic.Documentation.AIAssistantIntegration
    ]

    missing_modules = Enum.reject(required_modules, fn module ->
      Code.ensure_loaded?(module)
    end)

    if Enum.empty?(missing_modules) do
      %{status: :ok, message: "All required dependencies available"}
    else
      %{status: :error, message: "Missing modules: #{inspect(missing_modules)}"}
    end
  end

  defp estimate_analysis_time(options) do
    docs_file_count = count_documentation_files(options.docs_path)
    code_file_count = count_code_files(options.code_path)

    # Rough estimation based on file counts and enabled sections
    base_time = (docs_file_count * 100 + code_file_count * 50) # ms per file
    section_multiplier = case length(options.sections) do
      1 -> 0.3
      2 -> 0.6
      3 -> 0.8
      _ -> 1.0
    end

    estimated_time = round(base_time * section_multiplier)

    %{
      status: :info,
      message: "Estimated analysis time: #{estimated_time}ms (#{docs_file_count} docs, #{code_file_count} code files)"
    }
  end

  defp count_documentation_files(docs_path) do
    docs_path
    |> Path.join("**/*.{md,rst,txt}")
    |> Path.wildcard()
    |> length()
  end

  defp count_code_files(code_path) do
    code_path
    |> Path.join("**/*.{ex,exs}")
    |> Path.wildcard()
    |> length()
  end

  defp print_comprehensive_analysis_summary(analysis) do
    Mix.shell().info([
      :blue, "\n📊 Comprehensive Analysis Summary", :reset
    ])

    summary_items = []

    # Add summaries for each analyzed section
    summary_items = if Map.has_key?(analysis, :adrs) do
      [{"ADRs Found", length(analysis.adrs.adrs)} | summary_items]
    else
      summary_items
    end

    summary_items = if Map.has_key?(analysis, :examples) do
      [{"Code Examples", get_in(analysis, [:examples, :summary, :total_examples]) || 0} | summary_items]
    else
      summary_items
    end

    summary_items = if Map.has_key?(analysis, :trace) do
      [{"Traceability Links", get_in(analysis, [:trace, :summary, :successful_links]) || 0} | summary_items]
    else
      summary_items
    end

    summary_items = if Map.has_key?(analysis, :ai) do
      [{"AI Data Structures", 1} | summary_items]
    else
      summary_items
    end

    Enum.each(summary_items, fn {label, count} ->
      Mix.shell().info("  #{label}: #{count}")
    end)

    Mix.shell().info("  Analysis Timestamp: #{analysis.analysis_timestamp}")
  end

  defp show_comprehensive_help do
    Mix.shell().info(@moduledoc)
  end
end
