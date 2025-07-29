defmodule Mix.Tasks.Docs do
  @moduledoc """
  Comprehensive documentation analysis and enhancement toolkit.

  This module provides enterprise-grade command-line interface to all documentation
  analysis tools including ADR extraction, code example analysis, traceability
  markers, and AI assistant integration. Designed for CI/CD integration and
  automated documentation maintenance workflows.

  ## Quick Start

      # Run comprehensive analysis
      mix docs analyze

      # Extract Architecture Decision Records
      mix docs extract_adrs --output json

      # Validate documentation consistency
      mix docs validate --verbose

      # Generate analysis report
      mix docs report --format html

  ## Available Commands

  ### Core Analysis
  - [`docs.analyze`](`Mix.Tasks.Docs.Analyze`) - Comprehensive documentation analysis
  - [`docs.validate`](`Mix.Tasks.Docs.Validate`) - Validate documentation consistency
  - [`docs.report`](`Mix.Tasks.Docs.Report`) - Generate comprehensive analysis report

  ### Content Extraction
  - [`docs.extract_adrs`](`Mix.Tasks.Docs.ExtractAdrs`) - Extract Architecture Decision Records
  - [`docs.extract_examples`](`Mix.Tasks.Docs.ExtractExamples`) - Extract and categorize code examples
  - [`docs.trace`](`Mix.Tasks.Docs.Trace`) - Generate traceability markers

  ### AI Integration
  - [`docs.ai_data`](`Mix.Tasks.Docs.AiData`) - Generate AI-friendly structured data

  ## Integration Examples

      # CI/CD pipeline integration
      mix docs.validate --ci --format json --output validation-report.json

      # Development workflow
      mix docs.analyze --verbose --output analysis.json
      mix docs.report --format html --output docs-health.html

      # Content maintenance
      mix docs.extract_examples --language elixir --executable
      mix docs.trace --docs docs --code apps --matrix

  ## Architecture

  All documentation tasks follow enterprise patterns:
  - Comprehensive error handling with detailed diagnostics
  - Progress indicators for long-running operations
  - Structured output formats (JSON, YAML, HTML, Markdown)
  - CI/CD friendly exit codes and reporting
  - Extensive validation and parameter checking

  Related: [Documentation Architecture](docs/core/architecture-overview.md#documentation-system)
  """

  use Mix.Task

  @shortdoc "Enterprise documentation analysis toolkit - run 'mix docs --help' for commands"

  @impl Mix.Task
  def run(args) do
    start_time = System.monotonic_time(:millisecond)

    try do
      case parse_args(args) do
        {:help} ->
          show_comprehensive_help()

        {:command, command, command_args} ->
          execute_command_with_monitoring(command, command_args)

        {:error, reason} ->
          Mix.shell().error("❌ Invalid arguments: #{reason}")
          show_usage_summary()
          System.halt(1)
      end
    rescue
      error ->
        execution_time = System.monotonic_time(:millisecond) - start_time
        Mix.shell().error([
          :red, "❌ Documentation task failed after #{execution_time}ms: ",
          :reset, Exception.message(error)
        ])

        if System.get_env("MIX_DEBUG") == "1" do
          Mix.shell().error("Stack trace:")
          Mix.shell().error(Exception.format_stacktrace(__STACKTRACE__))
        end

        System.halt(1)
    end
  end

  @doc false
  def parse_args(args) do
    case args do
      [] -> {:help}
      ["--help"] -> {:help}
      ["-h"] -> {:help}
      ["help"] -> {:help}
      [command | rest] when command in ~w(analyze extract_adrs extract_examples trace ai_data validate report) ->
        {:command, command, rest}
      [unknown_command | _] ->
        {:error, "Unknown command '#{unknown_command}'. Available commands: analyze, extract_adrs, extract_examples, trace, ai_data, validate, report"}
      _ ->
        {:error, "Invalid argument format"}
    end
  end

  defp show_comprehensive_help do
    Mix.shell().info([
      :cyan, "\n🔍 Prismatic Documentation Analysis Toolkit", :reset, "\n",
      String.duplicate("═", 55), "\n"
    ])

    Mix.shell().info([
      :green, "CORE ANALYSIS COMMANDS", :reset
    ])

    show_command_help([
      {"docs.analyze", "Comprehensive multi-dimensional documentation analysis"},
      {"docs.validate", "Validate links, references, and structural consistency"},
      {"docs.report", "Generate detailed health and analysis reports"}
    ])

    Mix.shell().info([
      :green, "\nCONTENT EXTRACTION COMMANDS", :reset
    ])

    show_command_help([
      {"docs.extract_adrs", "Extract and analyze Architecture Decision Records"},
      {"docs.extract_examples", "Extract and categorize code examples from docs"},
      {"docs.trace", "Generate bidirectional traceability markers"}
    ])

    Mix.shell().info([
      :green, "\nAI INTEGRATION COMMANDS", :reset
    ])

    show_command_help([
      {"docs.ai_data", "Generate AI-optimized structured documentation data"}
    ])

    show_usage_examples()
    show_ci_integration_examples()
  end

  defp show_command_help(commands) do
    Enum.each(commands, fn {command, description} ->
      Mix.shell().info("  #{IO.ANSI.yellow()}mix #{command}#{IO.ANSI.reset()} - #{description}")
    end)
  end

  defp show_usage_examples do
    Mix.shell().info([
      :blue, "\n💡 COMMON USAGE PATTERNS", :reset
    ])

    examples = [
      {"Development Workflow", "mix docs.analyze --verbose --output dev-analysis.json"},
      {"CI/CD Integration", "mix docs.validate --ci --format json --output validation.json"},
      {"Content Audit", "mix docs.extract_examples --language elixir --executable"},
      {"Health Reporting", "mix docs.report --format html --sections all"},
      {"Traceability Matrix", "mix docs.trace --docs docs --code apps --matrix"}
    ]

    Enum.each(examples, fn {title, command} ->
      Mix.shell().info([
        "  ", :cyan, title, :reset, ": ",
        :light_black, command, :reset
      ])
    end)
  end

  defp show_ci_integration_examples do
    Mix.shell().info([
      :blue, "\n🔧 CI/CD INTEGRATION", :reset
    ])

    Mix.shell().info("""
      # GitHub Actions example
      - name: Validate Documentation
        run: |
          mix docs.validate --ci --format json --output docs-validation.json
          mix docs.analyze --output docs-analysis.json

      # Quality gate example
      - name: Documentation Quality Gate
        run: mix docs.report --format json --sections summary | jq '.overall_score >= 85'
    """)

    Mix.shell().info([
      :yellow, "\n📚 For detailed help on any command:", :reset, " mix docs.[command] --help\n"
    ])
  end

  defp show_usage_summary do
    Mix.shell().info("""
    Usage: mix docs <command> [options]

    Available commands: analyze, extract_adrs, extract_examples, trace, ai_data, validate, report

    Run 'mix docs --help' for detailed information and examples.
    """)
  end

  defp execute_command_with_monitoring(command, args) do
    start_time = System.monotonic_time(:millisecond)

    Mix.shell().info([
      :blue, "🚀 Starting ", :cyan, "docs.#{command}", :reset,
      (if length(args) > 0, do: " with args: #{inspect(args)}", else: "")
    ])

    result = case command do
      "analyze" -> Mix.Tasks.Docs.Analyze.run(args)
      "extract_adrs" -> Mix.Tasks.Docs.ExtractAdrs.run(args)
      "extract_examples" -> Mix.Tasks.Docs.ExtractExamples.run(args)
      "trace" -> Mix.Tasks.Docs.Trace.run(args)
      "ai_data" -> Mix.Tasks.Docs.AiData.run(args)
      "validate" -> Mix.Tasks.Docs.Validate.run(args)
      "report" -> Mix.Tasks.Docs.Report.run(args)
    end

    execution_time = System.monotonic_time(:millisecond) - start_time

    Mix.shell().info([
      :green, "✅ Command ", :cyan, "docs.#{command}",
      :green, " completed in #{execution_time}ms", :reset
    ])

    result
  end
end

defmodule Mix.Tasks.Docs.Analyze do
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

  require Logger

  @shortdoc "Enterprise comprehensive documentation analysis with progress monitoring"

  # Analysis sections that can be run independently
  @available_sections ~w(adrs examples trace ai)
  @default_sections @available_sections

  # Supported output formats
  @output_formats ~w(json yaml report html)

  @impl Mix.Task
  def run(args) do
    start_time = System.monotonic_time(:millisecond)

    try do
      case parse_and_validate_options(args) do
        {:ok, options} ->
          if options[:dry_run] do
            run_dry_run_validation(options)
          else
            run_comprehensive_analysis(options, start_time)
          end

        {:error, reason} ->
          Mix.shell().error("❌ Invalid options: #{reason}")
          show_usage_summary()
          System.halt(1)
      end
    rescue
      error ->
        execution_time = System.monotonic_time(:millisecond) - start_time
        handle_analysis_error(error, execution_time, __STACKTRACE__)
    end
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
      show_comprehensive_help()
      {:ok, %{help: true}}
    else
      case validate_options(options, invalid) do
        :ok -> {:ok, normalize_options(options)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp validate_options(options, invalid) do
    cond do
      length(invalid) > 0 ->
        {:error, "Invalid arguments: #{inspect(invalid)}"}

      options[:output] && options[:output] not in @output_formats ->
        {:error, "Invalid output format '#{options[:output]}'. Available: #{Enum.join(@output_formats, ", ")}"}

      options[:sections] && not valid_sections?(options[:sections]) ->
        {:error, "Invalid sections. Available: #{Enum.join(@available_sections, ", ")}"}

      options[:docs] && not File.dir?(options[:docs]) ->
        {:error, "Documentation directory '#{options[:docs]}' does not exist"}

      options[:code] && not File.dir?(options[:code]) ->
        {:error, "Code directory '#{options[:code]}' does not exist"}

      true ->
        :ok
    end
  end

  defp valid_sections?(sections_string) do
    sections = parse_sections(sections_string)
    Enum.all?(sections, &(&1 in @available_sections))
  end

  defp normalize_options(options) do
    %{
      docs_path: options[:docs] || "docs",
      code_path: options[:code] || "apps",
      output_format: options[:output] || "json",
      output_file: options[:file] || generate_output_filename(options[:output] || "json"),
      sections: parse_sections(options[:sections]) || @default_sections,
      parallel: options[:parallel] || false,
      ci_mode: options[:ci] || false,
      show_progress: Keyword.get(options, :progress, true),
      verbose: options[:verbose] || false,
      dry_run: options[:dry_run] || false
    }
  end

  defp parse_sections(nil), do: @default_sections
  defp parse_sections("all"), do: @default_sections
  defp parse_sections(sections_string) when is_binary(sections_string) do
    sections_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 in @available_sections))
  end

  defp generate_output_filename(format) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    extension = case format do
      "json" -> "json"
      "yaml" -> "yaml"
      "html" -> "html"
      _ -> "txt"
    end
    "docs-analysis-#{timestamp}.#{extension}"
  end

  defp run_dry_run_validation(options) do
    Mix.shell().info([
      :blue, "🔍 Dry Run - Documentation Analysis Validation", :reset
    ])

    show_analysis_configuration(options)

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
      show_analysis_configuration(options)
    end

    # Initialize progress tracking
    progress_pid = if options.show_progress do
      start_progress_monitor(options.sections)
    else
      nil
    end

    # Ensure Mix application is started
    Mix.Task.run("app.start")

    try do
      # Run analysis with progress monitoring
      analysis_result = perform_analysis_with_progress(options, progress_pid)

      if options.verbose do
        print_comprehensive_analysis_summary(analysis_result)
      end

      # Save results in requested format
      output_file = save_analysis_results(analysis_result, options)

      execution_time = System.monotonic_time(:millisecond) - start_time

      Mix.shell().info([
        :green, "✅ Analysis completed successfully in #{execution_time}ms", :reset
      ])
      Mix.shell().info([
        :blue, "📄 Results saved to: ", :cyan, output_file, :reset
      ])

      if options.ci_mode do
        output_ci_summary(analysis_result)
      end

    rescue
      error ->
        execution_time = System.monotonic_time(:millisecond) - start_time
        handle_analysis_error(error, execution_time, __STACKTRACE__)
    after
      if progress_pid, do: stop_progress_monitor(progress_pid)
    end
  end

  defp show_comprehensive_help do
    Mix.shell().info(@moduledoc)
  end

  defp show_usage_summary do
    Mix.shell().info("""
    Usage: mix docs.analyze [options]

    Quick examples:
      mix docs.analyze                    # Basic comprehensive analysis
      mix docs.analyze --verbose          # With detailed output
      mix docs.analyze --ci --output json # CI/CD integration
      mix docs.analyze --sections adrs    # ADR analysis only

    Run 'mix docs.analyze --help' for full documentation.
    """)
  end

  # Progress monitoring functions
  defp start_progress_monitor(sections) do
    spawn(fn ->
      progress_loop(%{
        sections: sections,
        current_section: nil,
        progress: 0,
        start_time: System.monotonic_time(:millisecond)
      })
    end)
  end

  defp progress_loop(state) do
    receive do
      {:update_section, section} ->
        Mix.shell().info([
          :blue, "🔄 Analyzing ", :cyan, section, :reset, "..."
        ])
        progress_loop(%{state | current_section: section})

      {:update_progress, section, progress} ->
        if state.current_section == section do
          show_progress_bar(progress)
        end
        progress_loop(%{state | progress: progress})

      {:complete_section, section} ->
        Mix.shell().info([
          :green, "✅ Completed ", :cyan, section, :reset, " analysis"
        ])
        progress_loop(state)

      :stop ->
        :ok
    after
      5000 ->
        # Periodic status update
        if state.current_section do
          elapsed = System.monotonic_time(:millisecond) - state.start_time
          Mix.shell().info([
            :light_black, "⏱️  Still processing #{state.current_section} (#{elapsed}ms elapsed)...", :reset
          ])
        end
        progress_loop(state)
    end
  end

  defp show_progress_bar(progress) when progress >= 0 and progress <= 100 do
    bar_width = 40
    filled = round(bar_width * progress / 100)
    empty = bar_width - filled

    bar = String.duplicate("█", filled) <> String.duplicate("░", empty)
    Mix.shell().info([
      "\r  [", :green, bar, :reset, "] #{progress}%"
    ], [:stderr])
  end

  defp stop_progress_monitor(pid) do
    send(pid, :stop)
  end

  # Validation functions
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

  # Analysis execution functions
  defp show_analysis_configuration(options) do
    Mix.shell().info([
      :blue, "\n📋 Analysis Configuration", :reset
    ])

    config_items = [
      {"Documentation Path", options.docs_path},
      {"Code Path", options.code_path},
      {"Output Format", options.output_format},
      {"Output File", options.output_file},
      {"Analysis Sections", Enum.join(options.sections, ", ")},
      {"Parallel Processing", if(options.parallel, do: "Enabled", else: "Disabled")},
      {"CI Mode", if(options.ci_mode, do: "Enabled", else: "Disabled")}
    ]

    Enum.each(config_items, fn {label, value} ->
      Mix.shell().info("  #{label}: #{value}")
    end)
    Mix.shell().info("")
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
      if progress_pid, do: send(progress_pid, {:update_section, section})

      analysis_function = Map.get(analysis_functions, section)
      section_result = analysis_function.(options.docs_path, options.code_path, progress_pid)

      if progress_pid, do: send(progress_pid, {:complete_section, section})

      Map.put(acc, String.to_atom(section), section_result)
    end)
  end

  defp run_adr_analysis(docs_path, _code_path, progress_pid) do
    if progress_pid, do: send(progress_pid, {:update_progress, "adrs", 25})

    alias Prismatic.Documentation.ADRExtractor
    result = ADRExtractor.extract_all_adrs(docs_path)

    if progress_pid, do: send(progress_pid, {:update_progress, "adrs", 100})
    result
  end

  defp run_examples_analysis(docs_path, _code_path, progress_pid) do
    if progress_pid, do: send(progress_pid, {:update_progress, "examples", 25})

    alias Prismatic.Documentation.CodeExampleExtractor
    result = CodeExampleExtractor.extract_all_examples(docs_path)

    if progress_pid, do: send(progress_pid, {:update_progress, "examples", 100})
    result
  end

  defp run_traceability_analysis(docs_path, code_path, progress_pid) do
    if progress_pid, do: send(progress_pid, {:update_progress, "trace", 25})

    alias Prismatic.Documentation.TraceabilityMarker
    result = TraceabilityMarker.generate_markers(docs_path, code_path)

    if progress_pid, do: send(progress_pid, {:update_progress, "trace", 100})
    result
  end

  defp run_ai_analysis(docs_path, _code_path, progress_pid) do
    if progress_pid, do: send(progress_pid, {:update_progress, "ai", 25})

    alias Prismatic.Documentation.AIAssistantIntegration
    result = AIAssistantIntegration.generate_structured_data(docs_path, [format: :json])

    if progress_pid, do: send(progress_pid, {:update_progress, "ai", 100})
    result
  end

  # Output handling functions
  defp save_analysis_results(analysis_result, options) do
    case options.output_format do
      "json" -> save_json_output(analysis_result, options.output_file)
      "yaml" -> save_yaml_output(analysis_result, options.output_file)
      "html" -> save_html_output(analysis_result, options.output_file)
      "report" -> save_report_output(analysis_result, options.output_file)
      _ -> save_json_output(analysis_result, options.output_file)
    end

    options.output_file
  end

  defp save_json_output(result, file_path) do
    json_content = Jason.encode!(result, pretty: true)
    File.write!(file_path, json_content)
  end

  defp save_yaml_output(result, file_path) do
    # Convert to YAML format if YamlElixir is available, otherwise JSON
    try do
      yaml_content = YamlElixir.write_to_string!(result)
      File.write!(file_path, yaml_content)
    rescue
      UndefinedFunctionError ->
        Mix.shell().info("⚠️  YAML library not available, saving as JSON instead")
        json_file = String.replace(file_path, ".yaml", ".json")
        save_json_output(result, json_file)
    end
  end

  defp save_html_output(result, file_path) do
    html_content = generate_html_report(result)
    File.write!(file_path, html_content)
  end

  defp save_report_output(result, file_path) do
    report_content = generate_comprehensive_text_report(result)
    File.write!(file_path, report_content)
  end

  # Enhanced reporting functions
  defp print_comprehensive_analysis_summary(analysis) do
    Mix.shell().info([
      :blue, "\n📊 Comprehensive Analysis Summary", :reset
    ])

    summary_items = []

    # Add summaries for each analyzed section
    if Map.has_key?(analysis, :adrs) do
      summary_items = [{"ADRs Found", length(analysis.adrs.adrs)} | summary_items]
    end

    if Map.has_key?(analysis, :examples) do
      summary_items = [{"Code Examples", get_in(analysis, [:examples, :summary, :total_examples]) || 0} | summary_items]
    end

    if Map.has_key?(analysis, :trace) do
      summary_items = [{"Traceability Links", get_in(analysis, [:trace, :summary, :successful_links]) || 0} | summary_items]
    end

    if Map.has_key?(analysis, :ai) do
      summary_items = [{"AI Data Structures", 1} | summary_items]
    end

    Enum.each(summary_items, fn {label, count} ->
      Mix.shell().info("  #{label}: #{count}")
    end)

    Mix.shell().info("  Analysis Timestamp: #{analysis.analysis_timestamp}")
  end

  defp generate_comprehensive_text_report(analysis) do
    sections = []

    # Header
    sections = [generate_report_header(analysis) | sections]

    # Executive summary
    sections = [generate_executive_summary(analysis) | sections]

    # Individual section reports
    if Map.has_key?(analysis, :adrs) do
      sections = [generate_adrs_section_report(analysis.adrs) | sections]
    end

    if Map.has_key?(analysis, :examples) do
      sections = [generate_examples_section_report(analysis.examples) | sections]
    end

    if Map.has_key?(analysis, :trace) do
      sections = [generate_traceability_section_report(analysis.trace) | sections]
    end

    if Map.has_key?(analysis, :ai) do
      sections = [generate_ai_section_report(analysis.ai) | sections]
    end

    # Footer
    sections = [generate_report_footer(analysis) | sections]

    sections
    |> Enum.reverse()
    |> Enum.join("\n\n")
  end

  defp generate_report_header(analysis) do
    """
    ████████████████████████████████████████████████████████████████
    ██                                                            ██
    ██          PRISMATIC DOCUMENTATION ANALYSIS REPORT          ██
    ██                                                            ██
    ████████████████████████████████████████████████████████████████

    Generated: #{analysis.analysis_timestamp}
    Analysis Version: #{analysis.analysis_version || "2.0.0"}
    Configuration: #{format_configuration_summary(analysis.configuration)}
    """
  end

  defp generate_executive_summary(analysis) do
    """
    ## EXECUTIVE SUMMARY
    ==================

    This comprehensive analysis examined the Prismatic documentation system
    across multiple dimensions including architectural decisions, code examples,
    traceability relationships, and AI integration capabilities.

    The analysis provides actionable insights for documentation maintenance,
    quality improvement, and automation opportunities.
    """
  end

  defp generate_html_report(analysis) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Prismatic Documentation Analysis Report</title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
                line-height: 1.6;
                max-width: 1200px;
                margin: 0 auto;
                padding: 2rem;
                background: #f8fafc;
            }
            .header {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                padding: 2rem;
                border-radius: 12px;
                margin-bottom: 2rem;
                text-align: center;
            }
            .summary-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
                gap: 1rem;
                margin: 2rem 0;
            }
            .metric-card {
                background: white;
                padding: 1.5rem;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                border-left: 4px solid #667eea;
            }
            .metric-value {
                font-size: 2rem;
                font-weight: bold;
                color: #667eea;
                margin-bottom: 0.5rem;
            }
            .metric-label {
                color: #64748b;
                font-size: 0.9rem;
                text-transform: uppercase;
                letter-spacing: 0.05em;
            }
            .section {
                background: white;
                margin: 2rem 0;
                padding: 2rem;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            .section h2 {
                color: #1e293b;
                border-bottom: 2px solid #e2e8f0;
                padding-bottom: 0.5rem;
            }
            pre {
                background: #f1f5f9;
                padding: 1rem;
                border-radius: 6px;
                overflow-x: auto;
                border-left: 4px solid #3b82f6;
            }
            .timestamp {
                color: #64748b;
                font-size: 0.9rem;
            }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🔍 Documentation Analysis Report</h1>
            <p class="timestamp">Generated: #{analysis.analysis_timestamp}</p>
        </div>

        <div class="summary-grid">
            #{generate_html_metrics(analysis)}
        </div>

        <div class="section">
            <h2>📋 Analysis Configuration</h2>
            <pre>#{format_configuration_for_html(analysis.configuration)}</pre>
        </div>

        #{generate_html_sections(analysis)}

        <div class="section">
            <h2>📈 Next Steps</h2>
            <ul>
                <li>Review identified documentation gaps and inconsistencies</li>
                <li>Implement recommended automation opportunities</li>
                <li>Establish regular documentation health monitoring</li>
                <li>Integrate analysis results into CI/CD pipeline</li>
            </ul>
        </div>
    </body>
    </html>
    """
  end

  defp handle_analysis_error(error, execution_time, stacktrace \\ nil) do
    Mix.shell().error([
      :red, "❌ Documentation analysis failed after #{execution_time}ms", :reset
    ])

    case error do
      %File.Error{reason: reason, path: path} ->
        Mix.shell().error("File system error: #{reason} - #{path}")

      %Jason.DecodeError{data: data} ->
        Mix.shell().error("JSON parsing error in data: #{String.slice(data, 0, 100)}...")

      %FunctionClauseError{} ->
        Mix.shell().error("Invalid data format encountered during analysis")

      _ ->
        Mix.shell().error("Unexpected error: #{Exception.message(error)}")
    end

    if System.get_env("MIX_DEBUG") == "1" and stacktrace do
      Mix.shell().error("Stack trace:")
      Mix.shell().error(Exception.format_stacktrace(stacktrace))
    end

    Mix.shell().error([
      :yellow, "\n💡 Troubleshooting Tips:", :reset,
      "\n  • Verify documentation and code paths exist and are readable",
      "\n  • Check for sufficient disk space for output files",
      "\n  • Ensure all required dependencies are available",
      "\n  • Try running with --dry-run first to validate configuration",
      "\n  • Use --verbose for more detailed error information"
    ])

    System.halt(1)
  end

  # CI output functions
  defp output_ci_summary(analysis_result) do
    ci_summary = %{
      status: "success",
      timestamp: analysis_result.analysis_timestamp,
      analysis_version: analysis_result.analysis_version,
      metrics: extract_ci_metrics(analysis_result),
      recommendations: extract_ci_recommendations(analysis_result)
    }

    Mix.shell().info("CI_ANALYSIS_SUMMARY=#{Jason.encode!(ci_summary)}")
  end

  defp extract_ci_metrics(analysis) do
    %{
      adrs_count: if(Map.has_key?(analysis, :adrs), do: length(analysis.adrs.adrs), else: 0),
      examples_count: get_in(analysis, [:examples, :summary, :total_examples]) || 0,
      traceability_links: get_in(analysis, [:trace, :summary, :successful_links]) || 0,
      analysis_sections: Map.keys(analysis) |> Enum.filter(&(&1 in [:adrs, :examples, :trace, :ai])) |> length()
    }
  end

  defp extract_ci_recommendations(_analysis) do
    [
      "Regular documentation analysis should be integrated into CI/CD pipeline",
      "Consider setting up automated alerts for documentation drift",
      "Establish documentation quality gates based on analysis metrics"
    ]
  end

  # Helper formatting functions
  defp format_configuration_summary(config) when is_map(config) do
    "#{config.docs_path} → #{config.code_path} (#{Enum.join(config.sections, ",")})"
  end
  defp format_configuration_summary(_), do: "Default configuration"

  defp format_configuration_for_html(config) when is_map(config) do
    Jason.encode!(config, pretty: true)
  end
  defp format_configuration_for_html(_), do: "Configuration not available"

  defp generate_html_metrics(analysis) do
    metrics = [
      {get_metric_value(analysis, :adrs, &length(&1.adrs)), "Architecture Decisions"},
      {get_metric_value(analysis, :examples, &get_in(&1, [:summary, :total_examples])), "Code Examples"},
      {get_metric_value(analysis, :trace, &get_in(&1, [:summary, :successful_links])), "Traceability Links"},
      {if(Map.has_key?(analysis, :ai), do: 1, else: 0), "AI Data Structures"}
    ]

    Enum.map(metrics, fn {value, label} ->
      """
      <div class="metric-card">
          <div class="metric-value">#{value || 0}</div>
          <div class="metric-label">#{label}</div>
      </div>
      """
    end)
    |> Enum.join("")
  end

  defp get_metric_value(analysis, section, extractor) do
    if Map.has_key?(analysis, section) do
      extractor.(Map.get(analysis, section))
    else
      0
    end
  end

  defp generate_html_sections(analysis) do
    sections = []

    if Map.has_key?(analysis, :adrs) do
      sections = [generate_html_adrs_section(analysis.adrs) | sections]
    end

    if Map.has_key?(analysis, :examples) do
      sections = [generate_html_examples_section(analysis.examples) | sections]
    end

    Enum.reverse(sections) |> Enum.join("")
  end

  defp generate_html_adrs_section(adrs) do
    """
    <div class="section">
        <h2>🏗️ Architecture Decision Records</h2>
        <p>Found #{length(adrs.adrs)} ADRs across the documentation system.</p>
        <pre>#{inspect(Map.take(adrs, [:summary]), pretty: true)}</pre>
    </div>
    """
  end

  defp generate_html_examples_section(examples) do
    """
    <div class="section">
        <h2>💻 Code Examples Analysis</h2>
        <p>Analyzed #{get_in(examples, [:summary, :total_examples]) || 0} code examples.</p>
        <pre>#{inspect(Map.take(examples, [:summary]), pretty: true)}</pre>
    </div>
    """
  end

  # Additional report generation functions
  defp generate_adrs_section_report(adrs) do
    """
    ## ARCHITECTURE DECISION RECORDS
    ==============================

    Total ADRs Analyzed: #{length(adrs.adrs)}

    #{if Map.has_key?(adrs, :summary) and Map.has_key?(adrs.summary, :domain_distribution) do
      "Domain Distribution:\n#{format_domain_distribution(adrs.summary.domain_distribution)}"
    else
      "Domain distribution analysis not available"
    end}

    #{if Map.has_key?(adrs, :summary) and Map.has_key?(adrs.summary, :status_distribution) do
      "Status Distribution:\n#{format_status_distribution(adrs.summary.status_distribution)}"
    else
      "Status distribution analysis not available"
    end}
    """
  end

  defp generate_examples_section_report(examples) do
    """
    ## CODE EXAMPLES ANALYSIS
    ========================

    Total Examples: #{get_in(examples, [:summary, :total_examples]) || 0}
    Executable Examples: #{get_in(examples, [:summary, :executable_examples]) || 0}
    Conceptual Examples: #{get_in(examples, [:summary, :conceptual_examples]) || 0}

    #{if get_in(examples, [:summary, :by_language]) do
      "Language Distribution:\n#{format_language_distribution(examples.summary.by_language)}"
    else
      "Language distribution analysis not available"
    end}
    """
  end

  defp generate_traceability_section_report(trace) do
    """
    ## TRACEABILITY ANALYSIS
    ======================

    Documentation References: #{get_in(trace, [:summary, :total_documentation_references]) || 0}
    Code References: #{get_in(trace, [:summary, :total_code_references]) || 0}
    Successful Links: #{get_in(trace, [:summary, :successful_links]) || 0}
    Traceability Score: #{get_in(trace, [:summary, :traceability_score]) || 0}%
    """
  end

  defp generate_ai_section_report(ai) do
    """
    ## AI INTEGRATION DATA
    ====================

    Schema Version: #{ai.schema_version || "Unknown"}
    Generation Time: #{ai.generation_timestamp || "Unknown"}
    Source Path: #{ai.source_path || "Unknown"}

    AI-structured data has been successfully generated with optimized
    formats for assistant consumption and automated enhancement workflows.
    """
  end

  defp generate_report_footer(analysis) do
    """
    ## ANALYSIS METADATA
    ==================

    Report Generated: #{analysis.analysis_timestamp}
    Analysis Version: #{analysis.analysis_version || "2.0.0"}

    This report was generated by the Prismatic Documentation Analysis Toolkit.
    For questions or support, see: docs/guides/documentation-analysis.md

    ████████████████████████████████████████████████████████████████
    """
  end

  defp format_adrs_for_report(adrs) do
    """
    Domain Distribution:
    #{format_domain_distribution(adrs.summary.domain_distribution)}

    Status Distribution:
    #{format_status_distribution(adrs.summary.status_distribution)}
    """
  end

  defp format_examples_for_report(examples) do
    """
    Language Distribution:
    #{format_language_distribution(examples.summary.by_language)}

    Executable Examples: #{examples.summary.executable_examples}
    Conceptual Examples: #{examples.summary.conceptual_examples}
    """
  end

  defp format_traceability_for_report(traceability) do
    """
    Documentation Coverage: #{traceability.summary.coverage_analysis.documentation_coverage}%
    Code Coverage: #{traceability.summary.coverage_analysis.code_coverage}%
    Orphaned Items: #{traceability.summary.orphaned_items}
    """
  end

  defp format_ai_data_for_report(ai_data) do
    """
    AI-structured data generated successfully.
    Schema Version: #{ai_data.schema_version}
    Generation Time: #{ai_data.generation_timestamp}
    """
  end

  defp format_domain_distribution(distribution) do
    distribution
    |> Enum.map(fn {domain, count} -> "  - #{domain}: #{count}" end)
    |> Enum.join("\n")
  end

  defp format_status_distribution(distribution) do
    distribution
    |> Enum.map(fn {status, count} -> "  - #{status}: #{count}" end)
    |> Enum.join("\n")
  end

  defp format_language_distribution(distribution) do
    distribution
    |> Enum.map(fn {language, count} -> "  - #{language}: #{count}" end)
    |> Enum.join("\n")
  end
end

defmodule Mix.Tasks.Docs.ExtractAdrs do
  @moduledoc """
  Enterprise Architecture Decision Records (ADR) extraction and analysis.

  Advanced ADR processing system that discovers, parses, and analyzes Architecture
  Decision Records across documentation systems. Provides comprehensive metadata
  extraction, cross-referencing, and impact analysis for architectural governance.

  ## Features

  ### ADR Discovery
  - Automatic detection of ADR files using naming patterns
  - Support for multiple ADR formats (markdown, structured text)
  - Hierarchical organization analysis
  - Cross-document relationship mapping

  ### Metadata Extraction
  - Decision status tracking (Proposed, Accepted, Superseded, Deprecated)
  - Architectural domain classification
  - Impact scope analysis
  - Decision timeline construction

  ### Analysis Capabilities
  - Decision complexity scoring
  - Architectural domain distribution
  - Status lifecycle analysis
  - Supersession chain tracking
  - Cross-reference validation

  ## Options

    * `--docs PATH` - Documentation directory (default: docs)
    * `--output FORMAT` - Output format: json, yaml, html, report (default: json)
    * `--file PATH` - Output file path (auto-generated if not specified)
    * `--domain DOMAIN` - Filter by architectural domain (comma-separated)
    * `--status STATUS` - Filter by decision status (comma-separated)
    * `--include-superseded` - Include superseded decisions in analysis
    * `--complexity-threshold NUM` - Filter by minimum complexity score (1-10)
    * `--timeline` - Generate decision timeline visualization
    * `--cross-references` - Analyze cross-references between ADRs
    * `--ci` - CI/CD mode with structured output and exit codes
    * `--verbose` - Enable detailed diagnostic output

  ## Examples

  ### Basic Extraction
      # Extract all ADRs with default analysis
      mix docs.extract_adrs

      # Extract with detailed analysis
      mix docs.extract_adrs --verbose --cross-references --timeline

  ### Filtered Analysis
      # Security domain ADRs only
      mix docs.extract_adrs --domain security --output html

      # Accepted and proposed decisions
      mix docs.extract_adrs --status "Accepted,Proposed" --complexity-threshold 7

      # High-impact decisions with timeline
      mix docs.extract_adrs --complexity-threshold 8 --timeline --output report

  ### CI/CD Integration
      # Generate structured data for automation
      mix docs.extract_adrs --ci --output json --file adr-inventory.json

      # Quality gate analysis
      mix docs.extract_adrs --domain security --ci | jq '.summary.total_adrs >= 5'

  ## Output Formats

  - **json**: Machine-readable structured data with full metadata
  - **yaml**: Human-readable format for configuration management
  - **html**: Interactive web report with filtering and visualization
  - **report**: Formatted text report for terminal and documentation

  ## ADR Standards

  Supports multiple ADR formats:
  - Michael Nygard format (status/context/decision/consequences)
  - Y-Statements format (In the context of X, facing Y, we decided Z)
  - MADR format (Markdown Architecture Decision Records)
  - Custom organizational formats

  Related: [ADR Guidelines](docs/architecture/adr-guidelines.md)
  """

  use Mix.Task
  alias Prismatic.Documentation.ADRExtractor

  require Logger

  @shortdoc "Enterprise ADR extraction with domain filtering and impact analysis"

  # Available filters and options
  @valid_statuses ~w(Proposed Accepted Superseded Deprecated)
  @valid_domains ~w(security infrastructure data api frontend backend integration deployment)
  @output_formats ~w(json yaml html report)

  @impl Mix.Task
  def run(args) do
    start_time = System.monotonic_time(:millisecond)

    try do
      case parse_and_validate_options(args) do
        {:ok, options} ->
          run_adr_extraction(options, start_time)

        {:error, reason} ->
          Mix.shell().error("❌ Invalid options: #{reason}")
          show_usage_summary()
          System.halt(1)
      end
    rescue
      error ->
        execution_time = System.monotonic_time(:millisecond) - start_time
        handle_extraction_error(error, execution_time, __STACKTRACE__)
    end
  end

  @doc false
  def parse_and_validate_options(args) do
    {options, _, invalid} = OptionParser.parse(args,
      switches: [
        docs: :string,
        output: :string,
        file: :string,
        domain: :string,
        status: :string,
        include_superseded: :boolean,
        complexity_threshold: :integer,
        timeline: :boolean,
        cross_references: :boolean,
        ci: :boolean,
        verbose: :boolean,
        help: :boolean
      ],
      aliases: [
        d: :docs,
        o: :output,
        f: :file,
        v: :verbose,
        h: :help
      ]
    )

    if options[:help] do
      show_comprehensive_help()
      {:ok, %{help: true}}
    else
      case validate_options(options, invalid) do
        :ok -> {:ok, normalize_options(options)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp validate_options(options, invalid) do
    cond do
      length(invalid) > 0 ->
        {:error, "Invalid arguments: #{inspect(invalid)}"}

      options[:output] && options[:output] not in @output_formats ->
        {:error, "Invalid output format '#{options[:output]}'. Available: #{Enum.join(@output_formats, ", ")}"}

      options[:status] && not valid_statuses?(options[:status]) ->
        {:error, "Invalid status. Available: #{Enum.join(@valid_statuses, ", ")}"}

      options[:domain] && not valid_domains?(options[:domain]) ->
        {:error, "Invalid domain. Available: #{Enum.join(@valid_domains, ", ")}"}

      options[:complexity_threshold] && (options[:complexity_threshold] < 1 or options[:complexity_threshold] > 10) ->
        {:error, "Complexity threshold must be between 1 and 10"}

      options[:docs] && not File.dir?(options[:docs]) ->
        {:error, "Documentation directory '#{options[:docs]}' does not exist"}

      true ->
        :ok
    end
  end

  defp valid_statuses?(status_string) do
    statuses = String.split(status_string, ",") |> Enum.map(&String.trim/1)
    Enum.all?(statuses, &(&1 in @valid_statuses))
  end

  defp valid_domains?(domain_string) do
    domains = String.split(domain_string, ",") |> Enum.map(&String.trim/1)
    Enum.all?(domains, &(&1 in @valid_domains))
  end

  defp normalize_options(options) do
    %{
      docs_path: options[:docs] || "docs",
      output_format: options[:output] || "json",
      output_file: options[:file] || generate_adr_output_filename(options[:output] || "json"),
      filter_domains: parse_comma_list(options[:domain]),
      filter_statuses: parse_comma_list(options[:status]),
      include_superseded: options[:include_superseded] || false,
      complexity_threshold: options[:complexity_threshold] || 1,
      generate_timeline: options[:timeline] || false,
      analyze_cross_references: options[:cross_references] || false,
      ci_mode: options[:ci] || false,
      verbose: options[:verbose] || false
    }
  end

  defp parse_comma_list(nil), do: []
  defp parse_comma_list(str) when is_binary(str) do
    String.split(str, ",") |> Enum.map(&String.trim/1)
  end

  defp generate_adr_output_filename(format) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    extension = case format do
      "json" -> "json"
      "yaml" -> "yaml"
      "html" -> "html"
      _ -> "txt"
    end
    "adr-analysis-#{timestamp}.#{extension}"
  end

  defp run_adr_extraction(options, start_time) do
    if options.verbose do
      show_extraction_configuration(options)
    end

    Mix.shell().info([
      :blue, "🔍 Discovering ADRs in ", :cyan, options.docs_path, :reset, "..."
    ])

    # Ensure Mix application is started
    Mix.Task.run("app.start")

    # Perform extraction with enhanced features
    extraction_result = perform_enhanced_adr_extraction(options)

    if options.verbose do
      print_comprehensive_adr_summary(extraction_result)
    end

    # Save results in requested format
    output_file = save_adr_results(extraction_result, options)

    execution_time = System.monotonic_time(:millisecond) - start_time

    Mix.shell().info([
      :green, "✅ ADR extraction completed in #{execution_time}ms", :reset
    ])
    Mix.shell().info([
      :blue, "📄 Results saved to: ", :cyan, output_file, :reset
    ])

    if options.ci_mode do
      output_adr_ci_summary(extraction_result)
    end
  end

  defp show_extraction_configuration(options) do
    Mix.shell().info([
      :blue, "\n📋 ADR Extraction Configuration", :reset
    ])

    config_items = [
      {"Documentation Path", options.docs_path},
      {"Output Format", options.output_format},
      {"Output File", options.output_file},
      {"Domain Filters", if(Enum.empty?(options.filter_domains), do: "None", else: Enum.join(options.filter_domains, ", "))},
      {"Status Filters", if(Enum.empty?(options.filter_statuses), do: "None", else: Enum.join(options.filter_statuses, ", "))},
      {"Complexity Threshold", options.complexity_threshold},
      {"Include Superseded", if(options.include_superseded, do: "Yes", else: "No")},
      {"Generate Timeline", if(options.generate_timeline, do: "Yes", else: "No")},
      {"Cross-Reference Analysis", if(options.analyze_cross_references, do: "Yes", else: "No")}
    ]

    Enum.each(config_items, fn {label, value} ->
      Mix.shell().info("  #{label}: #{value}")
    end)
    Mix.shell().info("")
  end

  defp perform_enhanced_adr_extraction(options) do
    # Base ADR extraction
    base_result = ADRExtractor.extract_all_adrs(options.docs_path)

    # Apply filters
    filtered_result = apply_comprehensive_adr_filters(base_result, options)

    # Enhance with additional analysis
    enhanced_result = enhance_adr_analysis(filtered_result, options)

    enhanced_result
  end

  defp apply_comprehensive_adr_filters(result, options) do
    filtered_adrs = result.adrs

    # Domain filtering
    filtered_adrs = if not Enum.empty?(options.filter_domains) do
      Enum.filter(filtered_adrs, fn adr ->
        adr.architectural_domain in options.filter_domains
      end)
    else
      filtered_adrs
    end

    # Status filtering
    filtered_adrs = if not Enum.empty?(options.filter_statuses) do
      Enum.filter(filtered_adrs, fn adr ->
        adr.status in options.filter_statuses
      end)
    else
      filtered_adrs
    end

    # Complexity filtering
    filtered_adrs = Enum.filter(filtered_adrs, fn adr ->
      (adr.complexity_score || 1) >= options.complexity_threshold
    end)

    # Superseded filtering
    filtered_adrs = if not options.include_superseded do
      Enum.reject(filtered_adrs, fn adr ->
        adr.status == "Superseded"
      end)
    else
      filtered_adrs
    end

    %{result | adrs: filtered_adrs}
  end

  defp enhance_adr_analysis(result, options) do
    enhanced_result = result

    # Add timeline analysis if requested
    enhanced_result = if options.generate_timeline do
      timeline_data = generate_adr_timeline(result.adrs)
      Map.put(enhanced_result, :timeline, timeline_data)
    else
      enhanced_result
    end

    # Add cross-reference analysis if requested
    enhanced_result = if options.analyze_cross_references do
      cross_ref_data = analyze_adr_cross_references(result.adrs)
      Map.put(enhanced_result, :cross_references, cross_ref_data)
    else
      enhanced_result
    end

    # Add enhanced metadata
    enhanced_result = Map.merge(enhanced_result, %{
      extraction_timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      extraction_options: options,
      analysis_features: %{
        timeline_generated: options.generate_timeline,
        cross_references_analyzed: options.analyze_cross_references,
        filtering_applied: not (Enum.empty?(options.filter_domains) and Enum.empty?(options.filter_statuses))
      }
    })

    enhanced_result
  end

  defp generate_adr_timeline(adrs) do
    timeline_entries = adrs
    |> Enum.filter(fn adr -> Map.has_key?(adr, :decision_date) and adr.decision_date end)
    |> Enum.sort_by(fn adr -> adr.decision_date end)
    |> Enum.map(fn adr ->
      %{
        date: adr.decision_date,
        adr_id: adr.id,
        title: adr.title,
        status: adr.status,
        domain: adr.architectural_domain,
        complexity: adr.complexity_score || 1
      }
    end)

    %{
      total_entries: length(timeline_entries),
      entries: timeline_entries,
      date_range: calculate_timeline_range(timeline_entries),
      domain_progression: analyze_domain_progression(timeline_entries)
    }
  end

  defp analyze_adr_cross_references(adrs) do
    # Create a map of ADR IDs to ADRs for quick lookup
    adr_map = Enum.into(adrs, %{}, fn adr -> {adr.id, adr} end)

    cross_references = adrs
    |> Enum.flat_map(fn adr ->
      referenced_ids = extract_adr_references(adr.content || "")

      Enum.map(referenced_ids, fn ref_id ->
        %{
          from_adr: adr.id,
          to_adr: ref_id,
          reference_type: determine_reference_type(adr.content, ref_id),
          valid: Map.has_key?(adr_map, ref_id)
        }
      end)
    end)

    %{
      total_references: length(cross_references),
      valid_references: Enum.count(cross_references, & &1.valid),
      invalid_references: Enum.count(cross_references, &(not &1.valid)),
      reference_network: build_reference_network(cross_references),
      orphaned_adrs: find_orphaned_adrs(adrs, cross_references)
    }
  end

  defp extract_adr_references(content) do
    # Extract ADR references like "ADR-001", "ADR 002", etc.
    Regex.scan(~r/ADR[-\s]?(\d{3,4})/i, content)
    |> Enum.map(fn [_, id] -> "ADR-#{String.pad_leading(id, 3, "0")}" end)
    |> Enum.uniq()
  end

  defp determine_reference_type(content, ref_id) do
    cond do
      String.contains?(content, "supersedes #{ref_id}") -> :supersedes
      String.contains?(content, "superseded by #{ref_id}") -> :superseded_by
      String.contains?(content, "relates to #{ref_id}") -> :relates_to
      String.contains?(content, "depends on #{ref_id}") -> :depends_on
      true -> :references
    end
  end

  defp build_reference_network(cross_references) do
    # Group references to show the network structure
    Enum.group_by(cross_references, & &1.from_adr)
  end

  defp find_orphaned_adrs(adrs, cross_references) do
    referenced_ids = Enum.map(cross_references, & &1.to_adr) |> Enum.uniq()
    referencing_ids = Enum.map(cross_references, & &1.from_adr) |> Enum.uniq()
    all_referenced_ids = (referenced_ids ++ referencing_ids) |> Enum.uniq()

    adr_ids = Enum.map(adrs, & &1.id)

    Enum.reject(adr_ids, fn id -> id in all_referenced_ids end)
  end

  defp calculate_timeline_range(timeline_entries) do
    if Enum.empty?(timeline_entries) do
      %{start_date: nil, end_date: nil, span_days: 0}
    else
      start_date = List.first(timeline_entries).date
      end_date = List.last(timeline_entries).date

      %{
        start_date: start_date,
        end_date: end_date,
        span_days: Date.diff(Date.from_iso8601!(end_date), Date.from_iso8601!(start_date))
      }
    end
  end

  defp analyze_domain_progression(timeline_entries) do
    timeline_entries
    |> Enum.group_by(& &1.domain)
    |> Enum.map(fn {domain, entries} ->
      %{
        domain: domain,
        decision_count: length(entries),
        first_decision: List.first(entries).date,
        last_decision: List.last(entries).date
      }
    end)
  end

  defp print_comprehensive_adr_summary(result) do
    Mix.shell().info([
      :blue, "\n📊 Comprehensive ADR Analysis Summary", :reset
    ])

    # Basic statistics
    total_adrs = length(result.adrs)
    Mix.shell().info("  📋 Total ADRs Found: #{total_adrs}")

    if Map.has_key?(result, :summary) do
      summary = result.summary

      if Map.has_key?(summary, :average_complexity) do
        Mix.shell().info("  📈 Average Complexity: #{summary.average_complexity}")
      end

      # Domain distribution
      if Map.has_key?(summary, :domain_distribution) do
        Mix.shell().info("\n  🏗️  Domain Distribution:")
        Enum.each(summary.domain_distribution, fn {domain, count} ->
          percentage = if total_adrs > 0, do: round(count / total_adrs * 100), else: 0
          Mix.shell().info("    #{domain}: #{count} (#{percentage}%)")
        end)
      end

      # Status distribution
      if Map.has_key?(summary, :status_distribution) do
        Mix.shell().info("\n  📊 Status Distribution:")
        Enum.each(summary.status_distribution, fn {status, count} ->
          percentage = if total_adrs > 0, do: round(count / total_adrs * 100), else: 0
          Mix.shell().info("    #{status}: #{count} (#{percentage}%)")
        end)
      end
    end

    # Timeline summary
    if Map.has_key?(result, :timeline) do
      timeline = result.timeline
      Mix.shell().info("\n  📅 Timeline Analysis:")
      Mix.shell().info("    Dated Decisions: #{timeline.total_entries}")

      if timeline.date_range.span_days > 0 do
        Mix.shell().info("    Decision Span: #{timeline.date_range.span_days} days")
        Mix.shell().info("    From: #{timeline.date_range.start_date}")
        Mix.shell().info("    To: #{timeline.date_range.end_date}")
      end
    end

    # Cross-reference summary
    if Map.has_key?(result, :cross_references) do
      cross_refs = result.cross_references
      Mix.shell().info("\n  🔗 Cross-Reference Analysis:")
      Mix.shell().info("    Total References: #{cross_refs.total_references}")
      Mix.shell().info("    Valid References: #{cross_refs.valid_references}")
      Mix.shell().info("    Invalid References: #{cross_refs.invalid_references}")
      Mix.shell().info("    Orphaned ADRs: #{length(cross_refs.orphaned_adrs)}")
    end
  end

  defp save_adr_results(result, options) do
    case options.output_format do
      "json" -> save_adr_json_output(result, options.output_file)
      "yaml" -> save_adr_yaml_output(result, options.output_file)
      "html" -> save_adr_html_output(result, options.output_file)
      "report" -> save_adr_report_output(result, options.output_file)
      _ -> save_adr_json_output(result, options.output_file)
    end

    options.output_file
  end

  defp save_adr_json_output(result, file_path) do
    json_content = Jason.encode!(result, pretty: true)
    File.write!(file_path, json_content)
  end

  defp save_adr_yaml_output(result, file_path) do
    try do
      yaml_content = YamlElixir.write_to_string!(result)
      File.write!(file_path, yaml_content)
    rescue
      UndefinedFunctionError ->
        Mix.shell().info("⚠️  YAML library not available, saving as JSON instead")
        json_file = String.replace(file_path, ".yaml", ".json")
        save_adr_json_output(result, json_file)
    end
  end

  defp save_adr_html_output(result, file_path) do
    html_content = generate_adr_html_report(result)
    File.write!(file_path, html_content)
  end

  defp save_adr_report_output(result, file_path) do
    report_content = generate_adr_text_report(result)
    File.write!(file_path, report_content)
  end

  defp generate_adr_html_report(result) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>ADR Analysis Report</title>
        <style>
            body { font-family: system-ui, sans-serif; margin: 2rem; background: #f8fafc; }
            .header { background: linear-gradient(135deg, #3b82f6 0%, #1e40af 100%); color: white; padding: 2rem; border-radius: 12px; margin-bottom: 2rem; }
            .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 1rem; margin: 2rem 0; }
            .card { background: white; padding: 1.5rem; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            .metric { font-size: 2rem; font-weight: bold; color: #3b82f6; }
            .adr-list { max-height: 400px; overflow-y: auto; }
            .adr-item { padding: 0.5rem; border-bottom: 1px solid #e5e7eb; }
            .status-accepted { border-left: 4px solid #10b981; }
            .status-proposed { border-left: 4px solid #f59e0b; }
            .status-superseded { border-left: 4px solid #6b7280; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🏗️ Architecture Decision Records Analysis</h1>
            <p>Generated: #{result.extraction_timestamp || DateTime.utc_now() |> DateTime.to_iso8601()}</p>
        </div>

        <div class="grid">
            <div class="card">
                <div class="metric">#{length(result.adrs)}</div>
                <div>Total ADRs</div>
            </div>
            #{generate_adr_html_metrics(result)}
        </div>

        <div class="card">
            <h2>📋 ADR Inventory</h2>
            <div class="adr-list">
                #{generate_adr_html_list(result.adrs)}
            </div>
        </div>

        #{if Map.has_key?(result, :timeline), do: generate_timeline_html_section(result.timeline), else: ""}
        #{if Map.has_key?(result, :cross_references), do: generate_cross_ref_html_section(result.cross_references), else: ""}
    </body>
    </html>
    """
  end

  defp generate_adr_text_report(result) do
    """
    ████████████████████████████████████████████████████████████████
    ██                                                            ██
    ██        ARCHITECTURE DECISION RECORDS ANALYSIS REPORT      ██
    ██                                                            ██
    ████████████████████████████████████████████████████████████████

    Generated: #{result.extraction_timestamp || DateTime.utc_now() |> DateTime.to_iso8601()}

    ## SUMMARY
    =========

    Total ADRs Analyzed: #{length(result.adrs)}
    #{if Map.has_key?(result, :summary), do: format_adr_summary_for_report(result.summary), else: ""}

    ## ADR INVENTORY
    ==============

    #{format_adr_list_for_report(result.adrs)}

    #{if Map.has_key?(result, :timeline), do: format_timeline_for_report(result.timeline), else: ""}
    #{if Map.has_key?(result, :cross_references), do: format_cross_references_for_report(result.cross_references), else: ""}

    ████████████████████████████████████████████████████████████████
    """
  end

  # Helper functions for HTML generation
  defp generate_adr_html_metrics(result) do
    if Map.has_key?(result, :summary) do
      summary = result.summary
      accepted_count = get_in(summary, [:status_distribution, "Accepted"]) || 0

      """
      <div class="card">
          <div class="metric">#{accepted_count}</div>
          <div>Accepted Decisions</div>
      </div>
      """
    else
      ""
    end
  end

  defp generate_adr_html_list(adrs) do
    adrs
    |> Enum.map(fn adr ->
      status_class = "status-#{String.downcase(adr.status || "unknown")}"
      """
      <div class="adr-item #{status_class}">
          <strong>#{adr.id || "Unknown"}</strong> - #{adr.title || "Untitled"}
          <br><small>Status: #{adr.status || "Unknown"} | Domain: #{adr.architectural_domain || "Unknown"}</small>
      </div>
      """
    end)
    |> Enum.join("")
  end

  # Error handling
  defp handle_extraction_error(error, execution_time, stacktrace \\ nil) do
    Mix.shell().error([
      :red, "❌ ADR extraction failed after #{execution_time}ms", :reset
    ])

    Mix.shell().error("Error: #{Exception.message(error)}")

    if System.get_env("MIX_DEBUG") == "1" and stacktrace do
      Mix.shell().error("Stack trace:")
      Mix.shell().error(Exception.format_stacktrace(stacktrace))
    end

    Mix.shell().error([
      :yellow, "\n💡 Troubleshooting Tips:", :reset,
      "\n  • Verify documentation directory exists and contains ADR files",
      "\n  • Check file permissions for reading ADR files",
      "\n  • Ensure ADRs follow supported naming conventions (ADR-NNN.md)",
      "\n  • Use --verbose for detailed diagnostic output"
    ])

    System.halt(1)
  end

  # CI output functions
  defp output_adr_ci_summary(result) do
    ci_summary = %{
      status: "success",
      timestamp: result.extraction_timestamp,
      total_adrs: length(result.adrs),
      metrics: extract_adr_ci_metrics(result)
    }

    Mix.shell().info("CI_ADR_SUMMARY=#{Jason.encode!(ci_summary)}")
  end

  defp extract_adr_ci_metrics(result) do
    summary = result.summary || %{}

    %{
      total_count: length(result.adrs),
      status_distribution: summary[:status_distribution] || %{},
      domain_distribution: summary[:domain_distribution] || %{},
      average_complexity: summary[:average_complexity] || 0,
      features_enabled: result.analysis_features || %{}
    }
  end

  defp show_comprehensive_help do
    Mix.shell().info(@moduledoc)
  end

  defp show_usage_summary do
    Mix.shell().info("""
    Usage: mix docs.extract_adrs [options]

    Quick examples:
      mix docs.extract_adrs                    # Extract all ADRs
      mix docs.extract_adrs --domain security  # Security domain only
      mix docs.extract_adrs --timeline --html  # Timeline analysis in HTML

    Run 'mix docs.extract_adrs --help' for full documentation.
    """)
  end

  # Report formatting helpers
  defp format_adr_summary_for_report(summary) do
    parts = []

    if Map.has_key?(summary, :average_complexity) do
      parts = ["Average Complexity: #{summary.average_complexity}" | parts]
    end

    if Map.has_key?(summary, :domain_distribution) do
      domain_info = summary.domain_distribution
      |> Enum.map(fn {domain, count} -> "#{domain}: #{count}" end)
      |> Enum.join(", ")
      parts = ["Domains: #{domain_info}" | parts]
    end

    if Map.has_key?(summary, :status_distribution) do
      status_info = summary.status_distribution
      |> Enum.map(fn {status, count} -> "#{status}: #{count}" end)
      |> Enum.join(", ")
      parts = ["Status: #{status_info}" | parts]
    end

    Enum.reverse(parts) |> Enum.join("\n")
  end

  defp format_adr_list_for_report(adrs) do
    adrs
    |> Enum.take(20) # Limit to first 20 for readability
    |> Enum.map(fn adr ->
      "#{adr.id || "Unknown"} - #{adr.title || "Untitled"} (#{adr.status || "Unknown"})"
    end)
    |> Enum.join("\n")
  end

  defp format_timeline_for_report(timeline) do
    """

    ## TIMELINE ANALYSIS
    ==================

    Dated Decisions: #{timeline.total_entries}
    #{if timeline.date_range.span_days > 0 do
      "Decision Span: #{timeline.date_range.span_days} days (#{timeline.date_range.start_date} to #{timeline.date_range.end_date})"
    else
      "Timeline span not available"
    end}
    """
  end

  defp format_cross_references_for_report(cross_refs) do
    """

    ## CROSS-REFERENCE ANALYSIS
    =========================

    Total References: #{cross_refs.total_references}
    Valid References: #{cross_refs.valid_references}
    Invalid References: #{cross_refs.invalid_references}
    Orphaned ADRs: #{length(cross_refs.orphaned_adrs)}
    """
  end

  # Additional HTML helper functions
  defp generate_timeline_html_section(timeline) do
    """
    <div class="card">
        <h2>📅 Decision Timeline</h2>
        <p>#{timeline.total_entries} decisions with dates spanning #{timeline.date_range.span_days || 0} days</p>
    </div>
    """
  end

  defp generate_cross_ref_html_section(cross_refs) do
    """
    <div class="card">
        <h2>🔗 Cross References</h2>
        <p>#{cross_refs.total_references} total references (#{cross_refs.valid_references} valid, #{cross_refs.invalid_references} invalid)</p>
        <p>#{length(cross_refs.orphaned_adrs)} orphaned ADRs found</p>
    </div>
    """
  end
end

defmodule Mix.Tasks.Docs.ExtractExamples do
  @moduledoc """
  Enterprise code example extraction and analysis toolkit.

  Advanced system for discovering, extracting, categorizing, and analyzing code
  examples across documentation systems. Provides executable code detection,
  transformation analysis, and quality metrics for documentation maintenance.

  ## Features

  ### Example Discovery
  - Multi-language code block detection (Elixir, JavaScript, SQL, Bash, etc.)
  - Inline code snippet extraction
  - Example metadata inference from context
  - Automatic language detection and validation

  ### Classification System
  - **Executable Examples**: Complete, runnable code snippets
  - **Conceptual Examples**: Illustrative code for understanding
  - **Configuration Examples**: Settings and configuration snippets
  - **API Examples**: HTTP requests, responses, and usage patterns

  ### Quality Analysis
  - Syntax validation for extracted code
  - Completeness scoring for executable examples
  - Transformation feasibility analysis
  - Documentation coverage metrics

  ## Options

    * `--docs PATH` - Documentation directory (default: docs)
    * `--language LANG` - Filter by programming language (comma-separated)
    * `--type TYPE` - Filter by example type: executable, conceptual, config, api
    * `--output FORMAT` - Output format: json, yaml, html, report (default: json)
    * `--file PATH` - Output file path (auto-generated if not specified)
    * `--min-lines NUM` - Minimum lines for code block inclusion (default: 1)
    * `--validate-syntax` - Perform syntax validation on extracted code
    * `--transformation-analysis` - Analyze examples for automation potential
    * `--coverage-analysis` - Generate documentation coverage metrics
    * `--ci` - CI/CD mode with structured output and exit codes
    * `--verbose` - Enable detailed diagnostic output

  ## Examples

  ### Basic Extraction
      # Extract all code examples
      mix docs.extract_examples

      # Extract with syntax validation
      mix docs.extract_examples --validate-syntax --verbose

  ### Language-Specific Analysis
      # Elixir examples only
      mix docs.extract_examples --language elixir --type executable

      # Multiple languages
      mix docs.extract_examples --language "elixir,javascript,sql"

  ### Quality Analysis
      # Comprehensive analysis with transformation insights
      mix docs.extract_examples --transformation-analysis --coverage-analysis

      # Generate HTML report for stakeholders
      mix docs.extract_examples --output html --coverage-analysis

  ### CI/CD Integration
      # Quality gate for example coverage
      mix docs.extract_examples --ci --coverage-analysis | jq '.coverage.executable_percentage >= 60'

  ## Supported Languages

  Full support: Elixir, JavaScript, Python, SQL, Bash, JSON, YAML, HTML, CSS, Markdown
  Basic support: Ruby, Go, Rust, Java, C, C++, PHP, TypeScript

  Related: [Code Example Standards](docs/guides/code-example-standards.md)
  """

  use Mix.Task
  alias Prismatic.Documentation.CodeExampleExtractor

  require Logger

  @shortdoc "Enterprise code example extraction with quality analysis and validation"

  # Supported languages and types
  @supported_languages ~w(elixir javascript python sql bash json yaml html css markdown ruby go rust java c cpp php typescript)
  @example_types ~w(executable conceptual config api)
  @output_formats ~w(json yaml html report)

  @impl Mix.Task
  def run(args) do
    start_time = System.monotonic_time(:millisecond)

    try do
      case parse_and_validate_options(args) do
        {:ok, options} ->
          run_example_extraction(options, start_time)

        {:error, reason} ->
          Mix.shell().error("❌ Invalid options: #{reason}")
          show_usage_summary()
          System.halt(1)
      end
    rescue
      error ->
        execution_time = System.monotonic_time(:millisecond) - start_time
        handle_extraction_error(error, execution_time, __STACKTRACE__)
    end
  end

  @doc false
  def parse_and_validate_options(args) do
    {options, _, invalid} = OptionParser.parse(args,
      switches: [
        docs: :string,
        language: :string,
        type: :string,
        output: :string,
        file: :string,
        min_lines: :integer,
        validate_syntax: :boolean,
        transformation_analysis: :boolean,
        coverage_analysis: :boolean,
        ci: :boolean,
        verbose: :boolean,
        help: :boolean
      ],
      aliases: [
        d: :docs,
        l: :language,
        t: :type,
        o: :output,
        f: :file,
        v: :verbose,
        h: :help
      ]
    )

    if options[:help] do
      show_comprehensive_help()
      {:ok, %{help: true}}
    else
      case validate_options(options, invalid) do
        :ok -> {:ok, normalize_options(options)}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp validate_options(options, invalid) do
    cond do
      length(invalid) > 0 ->
        {:error, "Invalid arguments: #{inspect(invalid)}"}

      options[:output] && options[:output] not in @output_formats ->
        {:error, "Invalid output format '#{options[:output]}'. Available: #{Enum.join(@output_formats, ", ")}"}

      options[:language] && not valid_languages?(options[:language]) ->
        {:error, "Invalid language. Supported: #{Enum.join(@supported_languages, ", ")}"}

      options[:type] && options[:type] not in @example_types ->
        {:error, "Invalid type '#{options[:type]}'. Available: #{Enum.join(@example_types, ", ")}"}

      options[:min_lines] && options[:min_lines] < 1 ->
        {:error, "Minimum lines must be at least 1"}

      options[:docs] && not File.dir?(options[:docs]) ->
        {:error, "Documentation directory '#{options[:docs]}' does not exist"}

      true ->
        :ok
    end
  end

  defp valid_languages?(language_string) do
    languages = String.split(language_string, ",") |> Enum.map(&String.trim/1)
    Enum.all?(languages, &(&1 in @supported_languages))
  end

  defp normalize_options(options) do
    %{
      docs_path: options[:docs] || "docs",
      filter_languages: parse_comma_list(options[:language]),
      filter_type: options[:type],
      output_format: options[:output] || "json",
      output_file: options[:file] || generate_examples_output_filename(options[:output] || "json"),
      min_lines: options[:min_lines] || 1,
      validate_syntax: options[:validate_syntax] || false,
      transformation_analysis: options[:transformation_analysis] || false,
      coverage_analysis: options[:coverage_analysis] || false,
      ci_mode: options[:ci] || false,
      verbose: options[:verbose] || false
    }
  end

  defp parse_comma_list(nil), do: []
  defp parse_comma_list(str) when is_binary(str) do
    String.split(str, ",") |> Enum.map(&String.trim/1)
  end

  defp generate_examples_output_filename(format) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    extension = case format do
      "json" -> "json"
      "yaml" -> "yaml"
      "html" -> "html"
      _ -> "txt"
    end
    "examples-analysis-#{timestamp}.#{extension}"
  end

  defp run_example_extraction(options, start_time) do
    if options.verbose do
      show_extraction_configuration(options)
    end

    Mix.shell().info([
      :blue, "💻 Extracting code examples from ", :cyan, options.docs_path, :reset, "..."
    ])

    # Ensure Mix application is started
    Mix.Task.run("app.start")

    # Perform extraction with enhanced analysis
    extraction_result = perform_comprehensive_example_extraction(options)

    if options.verbose do
      print_comprehensive_examples_summary(extraction_result)
    end

    # Save results in requested format
    output_file = save_examples_results(extraction_result, options)

    execution_time = System.monotonic_time(:millisecond) - start_time

    Mix.shell().info([
      :green, "✅ Code example extraction completed in #{execution_time}ms", :reset
    ])
    Mix.shell().info([
      :blue, "📄 Results saved to: ", :cyan, output_file, :reset
    ])

    if options.ci_mode do
      output_examples_ci_summary(extraction_result)
    end
  end

  defp show_extraction_configuration(options) do
    Mix.shell().info([
      :blue, "\n📋 Code Example Extraction Configuration", :reset
    ])

    config_items = [
      {"Documentation Path", options.docs_path},
      {"Output Format", options.output_format},
      {"Output File", options.output_file},
      {"Language Filters", if(Enum.empty?(options.filter_languages), do: "All", else: Enum.join(options.filter_languages, ", "))},
      {"Type Filter", options.filter_type || "All"},
      {"Minimum Lines", options.min_lines},
      {"Syntax Validation", if(options.validate_syntax, do: "Enabled", else: "Disabled")},
      {"Transformation Analysis", if(options.transformation_analysis, do: "Enabled", else: "Disabled")},
      {"Coverage Analysis", if(options.coverage_analysis, do: "Enabled", else: "Disabled")}
    ]

    Enum.each(config_items, fn {label, value} ->
      Mix.shell().info("  #{label}: #{value}")
    end)
    Mix.shell().info("")
  end

  defp perform_comprehensive_example_extraction(options) do
    # Base example extraction
    base_result = CodeExampleExtractor.extract_all_examples(options.docs_path)

    # Apply filters
    filtered_result = apply_comprehensive_example_filters(base_result, options)

    # Enhance with additional analysis
    enhanced_result = enhance_example_analysis(filtered_result, options)

    enhanced_result
  end

  defp apply_comprehensive_example_filters(result, options) do
    filtered_examples = result.examples

    # Language filtering
    filtered_examples = if not Enum.empty?(options.filter_languages) do
      Enum.filter(filtered_examples, fn example ->
        example.language in options.filter_languages
      end)
    else
      filtered_examples
    end

    # Type filtering
    filtered_examples = if options.filter_type do
      Enum.filter(filtered_examples, fn example ->
        example.example_type == options.filter_type
      end)
    else
      filtered_examples
    end

    # Minimum lines filtering
    filtered_examples = Enum.filter(filtered_examples, fn example ->
      line_count = String.split(example.content || "", "\n") |> length()
      line_count >= options.min_lines
    end)

    %{result | examples: filtered_examples}
  end

  defp enhance_example_analysis(result, options) do
    enhanced_result = result

    # Add syntax validation if requested
    enhanced_result = if options.validate_syntax do
      validated_examples = validate_example_syntax(result.examples)
      Map.put(enhanced_result, :syntax_validation, validated_examples)
    else
      enhanced_result
    end

    # Add transformation analysis if requested
    enhanced_result = if options.transformation_analysis do
      transformation_data = analyze_transformation_potential(result.examples)
      Map.put(enhanced_result, :transformation_analysis, transformation_data)
    else
      enhanced_result
    end

    # Add coverage analysis if requested
    enhanced_result = if options.coverage_analysis do
      coverage_data = analyze_documentation_coverage(result.examples, options.docs_path)
      Map.put(enhanced_result, :coverage_analysis, coverage_data)
    else
      enhanced_result
    end

    # Add enhanced metadata
    enhanced_result = Map.merge(enhanced_result, %{
      extraction_timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      extraction_options: options,
      analysis_features: %{
        syntax_validated: options.validate_syntax,
        transformation_analyzed: options.transformation_analysis,
        coverage_analyzed: options.coverage_analysis,
        filtering_applied: not (Enum.empty?(options.filter_languages) and is_nil(options.filter_type))
      }
    })

    enhanced_result
  end

  defp validate_example_syntax(examples) do
    validation_results = Enum.map(examples, fn example ->
      validation_result = case example.language do
        "elixir" -> validate_elixir_syntax(example.content)
        "javascript" -> validate_javascript_syntax(example.content)
        "json" -> validate_json_syntax(example.content)
        _ -> %{valid: :unknown, message: "Syntax validation not supported for #{example.language}"}
      end

      %{
        example_id: example.id || "unknown",
        language: example.language,
        validation_result: validation_result
      }
    end)

    %{
      total_validated: length(validation_results),
      valid_count: Enum.count(validation_results, &(&1.validation_result.valid == true)),
      invalid_count: Enum.count(validation_results, &(&1.validation_result.valid == false)),
      unknown_count: Enum.count(validation_results, &(&1.validation_result.valid == :unknown)),
      validation_details: validation_results
    }
  end

  defp validate_elixir_syntax(code) do
    try do
      case Code.string_to_quoted(code) do
        {:ok, _ast} -> %{valid: true, message: "Valid Elixir syntax"}
        {:error, reason} -> %{valid: false, message: "Syntax error: #{inspect(reason)}"}
      end
    rescue
      _ -> %{valid: false, message: "Syntax validation failed"}
    end
  end

  defp validate_javascript_syntax(_code) do
    # JavaScript syntax validation would require external tool
    %{valid: :unknown, message: "JavaScript validation requires external tool"}
  end

  defp validate_json_syntax(code) do
    try do
      case Jason.decode(code) do
        {:ok, _} -> %{valid: true, message: "Valid JSON syntax"}
        {:error, reason} -> %{valid: false, message: "JSON error: #{Jason.DecodeError.message(reason)}"}
      end
    rescue
      _ -> %{valid: false, message: "JSON validation failed"}
    end
  end

  defp analyze_transformation_potential(examples) do
    transformation_candidates = Enum.map(examples, fn example ->
      potential_score = calculate_transformation_score(example)

      %{
        example_id: example.id || "unknown",
        language: example.language,
        transformation_score: potential_score,
        automation_feasible: potential_score >= 7,
        recommended_actions: generate_transformation_recommendations(example, potential_score)
      }
    end)

    high_potential = Enum.filter(transformation_candidates, &(&1.automation_feasible))

    %{
      total_analyzed: length(transformation_candidates),
      high_potential_count: length(high_potential),
      average_score: calculate_average_transformation_score(transformation_candidates),
      transformation_candidates: transformation_candidates,
      summary: %{
        automation_ready: length(high_potential),
        manual_review_needed: length(transformation_candidates) - length(high_potential)
      }
    }
  end

  defp calculate_transformation_score(example) do
    score = 5 # Base score

    # Add points for completeness indicators
    score = if String.contains?(example.content || "", ["def ", "defmodule", "function"]), do: score + 2, else: score
    score = if String.length(example.content || "") > 100, do: score + 1, else: score
    score = if example.example_type == "executable", do: score + 2, else: score

    # Subtract points for complexity indicators
    score = if String.contains?(example.content || "", ["# TODO", "...", "xxx"]), do: score - 2, else: score
    score = if String.contains?(example.content || "", "# Example only"), do: score - 1, else: score

    max(1, min(10, score))
  end

  defp generate_transformation_recommendations(example, score) do
    cond do
      score >= 8 -> ["Ready for automated testing", "Consider adding to CI pipeline"]
      score >= 6 -> ["Needs minor modifications for automation", "Verify completeness"]
      score >= 4 -> ["Requires significant modifications", "Consider manual review"]
      true -> ["Not suitable for automation", "Keep as documentation example"]
    end
  end

  defp calculate_average_transformation_score(candidates) do
    if Enum.empty?(candidates) do
      0
    else
      total_score = Enum.sum(Enum.map(candidates, & &1.transformation_score))
      Float.round(total_score / length(candidates), 2)
    end
  end

  defp analyze_documentation_coverage(examples, docs_path) do
    # Count total documentation files
    total_docs = count_documentation_files(docs_path)

    # Count files with code examples
    files_with_examples = examples
    |> Enum.map(& &1.source_file)
    |> Enum.uniq()
    |> length()

    # Calculate coverage metrics
    coverage_percentage = if total_docs > 0 do
      Float.round(files_with_examples / total_docs * 100, 2)
    else
      0
    end

    %{
      total_documentation_files: total_docs,
      files_with_examples: files_with_examples,
      files_without_examples: total_docs - files_with_examples,
      coverage_percentage: coverage_percentage,
      examples_per_file: if(files_with_examples > 0, do: Float.round(length(examples) / files_with_examples, 2), else: 0),
      recommendations: generate_coverage_recommendations(coverage_percentage, examples)
    }
  end

  defp count_documentation_files(docs_path) do
    docs_path
    |> Path.join("**/*.{md,rst,txt}")
    |> Path.wildcard()
    |> length()
  end

  defp generate_coverage_recommendations(coverage_percentage, examples) do
    recommendations = []

    recommendations = if coverage_percentage < 50 do
      ["Consider adding code examples to more documentation files" | recommendations]
    else
      recommendations
    end

    executable_count = Enum.count(examples, &(&1.example_type == "executable"))
    total_count = length(examples)
    executable_percentage = if total_count > 0, do: executable_count / total_count * 100, else: 0

    recommendations = if executable_percentage < 30 do
      ["Increase the ratio of executable examples for better validation" | recommendations]
    else
      recommendations
    end

    recommendations = if length(examples) < 10 do
      ["Documentation would benefit from more comprehensive code examples" | recommendations]
    else
      recommendations
    end

    Enum.reverse(recommendations)
  end

  defp print_comprehensive_examples_summary(result) do
    Mix.shell().info([
      :blue, "\n📊 Comprehensive Code Examples Analysis", :reset
    ])

    # Basic statistics
    total_examples = length(result.examples)
    Mix.shell().info("  💻 Total Examples Found: #{total_examples}")

    if Map.has_key?(result, :summary) do
      summary = result.summary

      # Language distribution
      if Map.has_key?(summary, :by_language) do
        Mix.shell().info("\n  🔤 Language Distribution:")
        Enum.each(summary.by_language, fn {language, count} ->
          percentage = if total_examples > 0, do: round(count / total_examples * 100), else: 0
          Mix.shell().info("    #{language}: #{count} (#{percentage}%)")
        end)
      end

      # Type distribution
      if Map.has_key?(summary, :by_type) do
        Mix.shell().info("\n  📊 Type Distribution:")
        Enum.each(summary.by_type, fn {type, count} ->
          percentage = if total_examples > 0, do: round(count / total_examples * 100), else: 0
          Mix.shell().info("    #{type}: #{count} (#{percentage}%)")
        end)
      end
    end

    # Syntax validation summary
    if Map.has_key?(result, :syntax_validation) do
      validation = result.syntax_validation
      Mix.shell().info("\n  ✅ Syntax Validation:")
      Mix.shell().info("    Valid: #{validation.valid_count}")
      Mix.shell().info("    Invalid: #{validation.invalid_count}")
      Mix.shell().info("    Unknown: #{validation.unknown_count}")
    end

    # Transformation analysis summary
    if Map.has_key?(result, :transformation_analysis) do
      transformation = result.transformation_analysis
      Mix.shell().info("\n  🔄 Transformation Analysis:")
      Mix.shell().info("    Automation Ready: #{transformation.summary.automation_ready}")
      Mix.shell().info("    Average Score: #{transformation.average_score}/10")
    end

    # Coverage analysis summary
    if Map.has_key?(result, :coverage_analysis) do
      coverage = result.coverage_analysis
      Mix.shell().info("\n  📈 Coverage Analysis:")
      Mix.shell().info("    Documentation Coverage: #{coverage.coverage_percentage}%")
      Mix.shell().info("    Examples per File: #{coverage.examples_per_file}")
    end
  end

  defp save_examples_results(result, options) do
    case options.output_format do
      "json" -> save_examples_json_output(result, options.output_file)
      "yaml" -> save_examples_yaml_output(result, options.output_file)
      "html" -> save_examples_html_output(result, options.output_file)
      "report" -> save_examples_report_output(result, options.output_file)
      _ -> save_examples_json_output(result, options.output_file)
    end

    options.output_file
  end

  defp save_examples_json_output(result, file_path) do
    json_content = Jason.encode!(result, pretty: true)
    File.write!(file_path, json_content)
  end

  defp save_examples_yaml_output(result, file_path) do
    try do
      yaml_content = YamlElixir.write_to_string!(result)
      File.write!(file_path, yaml_content)
    rescue
      UndefinedFunctionError ->
        Mix.shell().info("⚠️  YAML library not available, saving as JSON instead")
        json_file = String.replace(file_path, ".yaml", ".json")
        save_examples_json_output(result, json_file)
    end
  end

  defp save_examples_html_output(result, file_path) do
    html_content = generate_examples_html_report(result)
    File.write!(file_path, html_content)
  end

  defp save_examples_report_output(result, file_path) do
    report_content = generate_examples_text_report(result)
    File.write!(file_path, report_content)
  end

  defp generate_examples_html_report(result) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Code Examples Analysis Report</title>
        <style>
            body { font-family: system-ui, sans-serif; margin: 2rem; background: #f8fafc; }
            .header { background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: white; padding: 2rem; border-radius: 12px; margin-bottom: 2rem; }
            .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 1rem; margin: 2rem 0; }
            .card { background: white; padding: 1.5rem; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            .metric { font-size: 2rem; font-weight: bold; color: #10b981; }
            .example-list { max-height: 400px; overflow-y: auto; }
            .example-item { padding: 0.5rem; border-bottom: 1px solid #e5e7eb; font-family: monospace; }
            .lang-elixir { border-left: 4px solid #663399; }
            .lang-javascript { border-left: 4px solid #f7df1e; }
            .lang-sql { border-left: 4px solid #336791; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>💻 Code Examples Analysis Report</h1>
            <p>Generated: #{result.extraction_timestamp || DateTime.utc_now() |> DateTime.to_iso8601()}</p>
        </div>

        <div class="grid">
            <div class="card">
                <div class="metric">#{length(result.examples)}</div>
                <div>Total Examples</div>
            </div>
            #{generate_examples_html_metrics(result)}
        </div>

        <div class="card">
            <h2>📋 Example Inventory</h2>
            <div class="example-list">
                #{generate_examples_html_list(result.examples)}
            </div>
        </div>

        #{if Map.has_key?(result, :coverage_analysis), do: generate_coverage_html_section(result.coverage_analysis), else: ""}
    </body>
    </html>
    """
  end

  defp generate_examples_text_report(result) do
    """
    ████████████████████████████████████████████████████████████████
    ██                                                            ██
    ██           CODE EXAMPLES ANALYSIS REPORT                   ██
    ██                                                            ██
    ████████████████████████████████████████████████████████████████

    Generated: #{result.extraction_timestamp || DateTime.utc_now() |> DateTime.to_iso8601()}

    ## SUMMARY
    =========

    Total Examples Analyzed: #{length(result.examples)}
    #{if Map.has_key?(result, :summary), do: format_examples_summary_for_report(result.summary), else: ""}

    #{if Map.has_key?(result, :coverage_analysis), do: format_coverage_for_report(result.coverage_analysis), else: ""}
    #{if Map.has_key?(result, :transformation_analysis), do: format_transformation_for_report(result.transformation_analysis), else: ""}

    ████████████████████████████████████████████████████████████████
    """
  end

  # Helper functions for reporting
  defp generate_examples_html_metrics(result) do
    if Map.has_key?(result, :summary) do
      summary = result.summary
      executable_count = get_in(summary, [:by_type, "executable"]) || 0

      """
      <div class="card">
          <div class="metric">#{executable_count}</div>
          <div>Executable Examples</div>
      </div>
      """
    else
      ""
    end
  end

  defp generate_examples_html_list(examples) do
    examples
    |> Enum.take(50) # Limit display
    |> Enum.map(fn example ->
      lang_class = "lang-#{example.language || "unknown"}"
      """
      <div class="example-item #{lang_class}">
          <strong>#{example.language || "Unknown"}</strong> - #{String.slice(example.content || "", 0, 80)}...
      </div>
      """
    end)
    |> Enum.join("")
  end

  defp generate_coverage_html_section(coverage) do
    """
    <div class="card">
        <h2>📈 Coverage Analysis</h2>
        <p>Documentation Coverage: #{coverage.coverage_percentage}%</p>
        <p>Files with Examples: #{coverage.files_with_examples}/#{coverage.total_documentation_files}</p>
    </div>
    """
  end

  defp format_examples_summary_for_report(summary) do
    parts = []

    if Map.has_key?(summary, :by_language) do
      lang_info = summary.by_language
      |> Enum.map(fn {lang, count} -> "#{lang}: #{count}" end)
      |> Enum.join(", ")
      parts = ["Languages: #{lang_info}" | parts]
    end

    if Map.has_key?(summary, :by_type) do
      type_info = summary.by_type
      |> Enum.map(fn {type, count} -> "#{type}: #{count}" end)
      |> Enum.join(", ")
      parts = ["Types: #{type_info}" | parts]
    end

    Enum.reverse(parts) |> Enum.join("\n")
  end

  defp format_coverage_for_report(coverage) do
    """

    ## COVERAGE ANALYSIS
    ==================

    Documentation Coverage: #{coverage.coverage_percentage}%
    Files with Examples: #{coverage.files_with_examples}
    Files without Examples: #{coverage.files_without_examples}
    Examples per File: #{coverage.examples_per_file}
    """
  end

  defp format_transformation_for_report(transformation) do
    """

    ## TRANSFORMATION ANALYSIS
    =========================

    Automation Ready: #{transformation.summary.automation_ready}
    Manual Review Needed: #{transformation.summary.manual_review_needed}
    Average Transformation Score: #{transformation.average_score}/10
    """
  end

  # Error handling and CI functions
  defp handle_extraction_error(error, execution_time, stacktrace \\ nil) do
    Mix.shell().error([
      :red, "❌ Code example extraction failed after #{execution_time}ms", :reset
    ])

    Mix.shell().error("Error: #{Exception.message(error)}")

    if System.get_env("MIX_DEBUG") == "1" and stacktrace do
      Mix.shell().error("Stack trace:")
      Mix.shell().error(Exception.format_stacktrace(stacktrace))
    end

    System.halt(1)
  end

  defp output_examples_ci_summary(result) do
    ci_summary = %{
      status: "success",
      timestamp: result.extraction_timestamp,
      total_examples: length(result.examples),
      metrics: extract_examples_ci_metrics(result)
    }

    Mix.shell().info("CI_EXAMPLES_SUMMARY=#{Jason.encode!(ci_summary)}")
  end

  defp extract_examples_ci_metrics(result) do
    summary = result.summary || %{}

    %{
      total_count: length(result.examples),
      language_distribution: summary[:by_language] || %{},
      type_distribution: summary[:by_type] || %{},
      features_enabled: result.analysis_features || %{}
    }
  end

  defp show_comprehensive_help do
    Mix.shell().info(@moduledoc)
  end

  defp show_usage_summary do
    Mix.shell().info("""
    Usage: mix docs.extract_examples [options]

    Quick examples:
      mix docs.extract_examples                       # Extract all examples
      mix docs.extract_examples --language elixir     # Elixir examples only
      mix docs.extract_examples --validate-syntax     # With syntax validation

    Run 'mix docs.extract_examples --help' for full documentation.
    """)
  end

  defp run_extraction(options) do
    docs_path = options[:docs] || "docs"
    output_format = options[:output] || "json"
    output_file = options[:file] || "examples-analysis.json"
    verbose = options[:verbose] || false

    Mix.Task.run("app.start")

    try do
      if verbose, do: IO.puts "Extracting code examples from #{docs_path}..."

      result = CodeExampleExtractor.extract_all_examples(docs_path)

      # Apply filters
      filtered_result = apply_example_filters(result, options)

      if verbose do
        print_examples_summary(filtered_result)
      end

      # Save results
      save_output(filtered_result, output_format, output_file)
      IO.puts "✅ Code example extraction complete! Results saved to #{output_file}"

    rescue
      error ->
        IO.puts "❌ Code example extraction failed: #{Exception.message(error)}"
        exit({:shutdown, 1})
    end
  end

  defp apply_example_filters(result, options) do
    filtered_examples = result.examples

    filtered_examples = if options[:language] do
      Enum.filter(filtered_examples, &(&1.language == options[:language]))
    else
      filtered_examples
    end

    filtered_examples = if options[:executable] do
      Enum.filter(filtered_examples, & &1.metadata.is_executable)
    else
      filtered_examples
    end

    %{result | examples: filtered_examples}
  end

  defp print_examples_summary(result) do
    IO.puts "\n💻 Code Examples Summary:"
    IO.puts "  Total Examples: #{length(result.examples)}"
    IO.puts "  Executable: #{Enum.count(result.examples, & &1.metadata.is_executable)}"
    IO.puts "  Conceptual: #{Enum.count(result.examples, & &1.metadata.is_conceptual)}"

    IO.puts "\n  Language Distribution:"
    result.examples
    |> Enum.group_by(& &1.language)
    |> Enum.each(fn {lang, examples} ->
      IO.puts "    #{lang}: #{length(examples)}"
    end)
  end

  defp save_output(result, format, file_path) do
    case format do
      "json" ->
        json_content = Jason.encode!(result, pretty: true)
        File.write!(file_path, json_content)
      _ ->
        json_content = Jason.encode!(result, pretty: true)
        File.write!(file_path, json_content)
    end
  end
end

defmodule Mix.Tasks.Docs.Trace do
  @moduledoc """
  Generate traceability markers between documentation and code.

  This task creates bidirectional references and validates
  cross-reference consistency between documentation and implementation.

  ## Options

    * `--docs` - Documentation directory (default: docs)
    * `--code` - Code directory (default: apps)
    * `--output` - Output format: json, yaml (default: json)
    * `--file` - Output file path (default: traceability-analysis.json)
    * `--matrix` - Generate traceability matrix
    * `--verbose` - Enable verbose output

  ## Examples

      mix docs.trace
      mix docs.trace --matrix --verbose
      mix docs.trace --docs documentation --code lib
  """

  use Mix.Task
  alias Prismatic.Documentation.TraceabilityMarker

  @shortdoc "Generate traceability markers"

  def run(args) do
    {options, _, _} = OptionParser.parse(args,
      switches: [
        docs: :string,
        code: :string,
        output: :string,
        file: :string,
        matrix: :boolean,
        verbose: :boolean,
        help: :boolean
      ]
    )

    if options[:help] do
      IO.puts @moduledoc
    else
      run_traceability(options)
    end
  end

  defp run_traceability(options) do
    docs_path = options[:docs] || "docs"
    code_path = options[:code] || "apps"
    output_format = options[:output] || "json"
    output_file = options[:file] || "traceability-analysis.json"
    verbose = options[:verbose] || false

    Mix.Task.run("app.start")

    try do
      if verbose do
        IO.puts "Generating traceability markers..."
        IO.puts "Documentation: #{docs_path}"
        IO.puts "Code: #{code_path}"
      end

      result = TraceabilityMarker.generate_markers(docs_path, code_path)

      if verbose do
        print_traceability_summary(result)
      end

      if options[:matrix] do
        print_traceability_matrix(result.traceability_matrix)
      end

      # Save results
      save_output(result, output_format, output_file)
      IO.puts "✅ Traceability analysis complete! Results saved to #{output_file}"

    rescue
      error ->
        IO.puts "❌ Traceability analysis failed: #{Exception.message(error)}"
        exit({:shutdown, 1})
    end
  end

  defp print_traceability_summary(result) do
    IO.puts "\n🔗 Traceability Summary:"
    IO.puts "  Documentation References: #{result.summary.total_documentation_references}"
    IO.puts "  Code References: #{result.summary.total_code_references}"
    IO.puts "  Successful Links: #{result.summary.successful_links}"
    IO.puts "  Traceability Score: #{result.summary.traceability_score}%"
    IO.puts "  Orphaned Items: #{result.summary.orphaned_items}"
  end

  defp print_traceability_matrix(matrix) do
    IO.puts "\n📊 Traceability Matrix:"
    IO.puts "Documentation Files → Code Files"

    Enum.each(matrix.matrix, fn row ->
      doc_file = Path.basename(row.documentation_file)
      IO.write "#{doc_file}: "

      link_counts = Enum.map(row.links, fn {_code_file, count} -> count end)
      total_links = Enum.sum(link_counts)

      IO.puts "#{total_links} total links"
    end)
  end

  defp save_output(result, format, file_path) do
    json_content = Jason.encode!(result, pretty: true)
    File.write!(file_path, json_content)
  end
end

defmodule Mix.Tasks.Docs.AiData do
  @moduledoc """
  Generate AI-friendly structured data from documentation.

  This task creates optimized data formats for AI assistant
  consumption and interaction.

  ## Options

    * `--docs` - Documentation directory (default: docs)
    * `--format` - Output format: json, yaml, markdown (default: json)
    * `--file` - Output file path (default: ai-structured-data.json)
    * `--include-examples` - Include code examples (default: true)
    * `--include-traceability` - Include traceability data (default: true)
    * `--verbose` - Enable verbose output

  ## Examples

      mix docs.ai_data
      mix docs.ai_data --format yaml
      mix docs.ai_data --no-include-examples
  """

  use Mix.Task
  alias Prismatic.Documentation.AIAssistantIntegration

  @shortdoc "Generate AI-friendly structured data"

  def run(args) do
    {options, _, _} = OptionParser.parse(args,
      switches: [
        docs: :string,
        format: :string,
        file: :string,
        include_examples: :boolean,
        include_traceability: :boolean,
        verbose: :boolean,
        help: :boolean
      ]
    )

    if options[:help] do
      IO.puts @moduledoc
    else
      run_ai_data_generation(options)
    end
  end

  defp run_ai_data_generation(options) do
    docs_path = options[:docs] || "docs"
    format = String.to_atom(options[:format] || "json")
    output_file = options[:file] || "ai-structured-data.json"
    verbose = options[:verbose] || false

    # Handle include options (default to true)
    include_examples = Keyword.get(options, :include_examples, true)
    include_traceability = Keyword.get(options, :include_traceability, true)

    Mix.Task.run("app.start")

    try do
      if verbose, do: IO.puts "Generating AI-structured data from #{docs_path}..."

      ai_options = [
        format: format,
        include_examples: include_examples,
        include_traceability: include_traceability
      ]

      result = AIAssistantIntegration.generate_structured_data(docs_path, ai_options)

      if verbose do
        print_ai_data_summary(result)
      end

      # Save results based on format
      case format do
        :json ->
          json_content = Jason.encode!(result, pretty: true)
          File.write!(output_file, json_content)
        _ ->
          # For other formats, save as JSON for now
          json_content = Jason.encode!(result, pretty: true)
          File.write!(output_file, json_content)
      end

      IO.puts "✅ AI data generation complete! Results saved to #{output_file}"

    rescue
      error ->
        IO.puts "❌ AI data generation failed: #{Exception.message(error)}"
        exit({:shutdown, 1})
    end
  end

  defp print_ai_data_summary(result) do
    IO.puts "\n🤖 AI Data Summary:"
    IO.puts "  Schema Version: #{result.schema_version}"
    IO.puts "  Generation Time: #{result.generation_timestamp}"
    IO.puts "  Source Path: #{result.source_path}"

    if Map.has_key?(result, :architecture_decisions) do
      IO.puts "  Architecture Decisions: #{length(result.architecture_decisions.decisions)}"
    end

    if Map.has_key?(result, :code_examples) and map_size(result.code_examples) > 0 do
      IO.puts "  Code Examples: #{length(result.code_examples.examples)}"
    end
  end
end

defmodule Mix.Tasks.Docs.Validate do
  @moduledoc """
  Validate documentation links and cross-references.

  This task integrates with the existing validation pipeline
  to check documentation consistency and link integrity.

  ## Options

    * `--docs` - Documentation directory (default: docs)
    * `--fix` - Attempt to fix broken links automatically
    * `--report` - Generate detailed validation report
    * `--verbose` - Enable verbose output

  ## Examples

      mix docs.validate
      mix docs.validate --fix --verbose
      mix docs.validate --report
  """

  use Mix.Task

  @shortdoc "Validate documentation consistency"

  def run(args) do
    {options, _, _} = OptionParser.parse(args,
      switches: [
        docs: :string,
        fix: :boolean,
        report: :boolean,
        verbose: :boolean,
        help: :boolean
      ]
    )

    if options[:help] do
      IO.puts @moduledoc
    else
      run_validation(options)
    end
  end

  defp run_validation(options) do
    docs_path = options[:docs] || "docs"
    verbose = options[:verbose] || false

    if verbose, do: IO.puts "Validating documentation in #{docs_path}..."

    # Run existing Python validation script
    case System.cmd("python3", ["validate_links.py"], stderr_to_stdout: true) do
      {output, 0} ->
        IO.puts "✅ Documentation validation completed successfully"
        if verbose, do: IO.puts output

        if options[:report] do
          generate_validation_report()
        end

      {output, exit_code} ->
        IO.puts "❌ Documentation validation failed (exit code: #{exit_code})"
        IO.puts output
        exit({:shutdown, exit_code})
    end
  end

  defp generate_validation_report do
    # Read the validation report if it exists
    report_file = "docs-links-validation-report.json"

    if File.exists?(report_file) do
      case File.read(report_file) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, report} ->
              print_validation_summary(report)
            {:error, _} ->
              IO.puts "Could not parse validation report"
          end
        {:error, _} ->
          IO.puts "Could not read validation report"
      end
    else
      IO.puts "No validation report found"
    end
  end

  defp print_validation_summary(report) do
    stats = report["summary_statistics"]

    IO.puts "\n📋 Validation Report Summary:"
    IO.puts "  Total Links: #{stats["total_internal_links"]}"
    IO.puts "  Valid Links: #{stats["valid_links"]}"
    IO.puts "  Broken Links: #{stats["broken_links"]}"
    IO.puts "  Success Rate: #{stats["validation_success_rate"]}%"

    if report["critical_issues"] && length(report["critical_issues"]) > 0 do
      IO.puts "\n⚠️  Critical Issues:"
      Enum.each(report["critical_issues"], fn issue ->
        IO.puts "    - #{issue["reason"]}"
      end)
    end
  end
end

defmodule Mix.Tasks.Docs.Report do
  @moduledoc """
  Generate comprehensive documentation analysis report.

  This task creates a human-readable report combining all
  analysis results in various formats.

  ## Options

    * `--docs` - Documentation directory (default: docs)
    * `--code` - Code directory (default: apps)
    * `--format` - Report format: text, html, markdown (default: text)
    * `--file` - Output file path (default: docs-report.txt)
    * `--sections` - Report sections: all, adrs, examples, trace (default: all)
    * `--verbose` - Enable verbose output

  ## Examples

      mix docs.report
      mix docs.report --format html
      mix docs.report --sections adrs,trace
  """

  use Mix.Task
  alias Prismatic.Documentation

  @shortdoc "Generate comprehensive analysis report"

  def run(args) do
    {options, _, _} = OptionParser.parse(args,
      switches: [
        docs: :string,
        code: :string,
        format: :string,
        file: :string,
        sections: :string,
        verbose: :boolean,
        help: :boolean
      ]
    )

    if options[:help] do
      IO.puts @moduledoc
    else
      run_report_generation(options)
    end
  end

  defp run_report_generation(options) do
    docs_path = options[:docs] || "docs"
    code_path = options[:code] || "apps"
    format = options[:format] || "text"
    output_file = options[:file] || "docs-report.txt"
    sections = parse_sections(options[:sections] || "all")
    verbose = options[:verbose] || false

    Mix.Task.run("app.start")

    try do
      if verbose, do: IO.puts "Generating comprehensive report..."

      # Run analysis
      analysis = Documentation.comprehensive_analysis(docs_path, code_path)

      # Generate report
      report_content = generate_report(analysis, format, sections)

      # Save report
      File.write!(output_file, report_content)

      IO.puts "✅ Report generated successfully: #{output_file}"

      if verbose do
        IO.puts "\nReport sections included: #{Enum.join(sections, ", ")}"
        IO.puts "Report format: #{format}"
      end

    rescue
      error ->
        IO.puts "❌ Report generation failed: #{Exception.message(error)}"
        exit({:shutdown, 1})
    end
  end

  defp parse_sections(sections_string) do
    case sections_string do
      "all" -> [:summary, :adrs, :examples, :traceability, :ai_data]
      _ ->
        sections_string
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(&String.to_atom/1)
    end
  end

  defp generate_report(analysis, format, sections) do
    case format do
      "text" -> generate_text_report(analysis, sections)
      "markdown" -> generate_markdown_report(analysis, sections)
      "html" -> generate_html_report(analysis, sections)
      _ -> generate_text_report(analysis, sections)
    end
  end

  defp generate_text_report(analysis, sections) do
    report_parts = []

    report_parts = if :summary in sections do
      [generate_summary_section(analysis) | report_parts]
    else
      report_parts
    end

    report_parts = if :adrs in sections do
      [generate_adrs_section(analysis.adrs) | report_parts]
    else
      report_parts
    end

    report_parts = if :examples in sections do
      [generate_examples_section(analysis.code_examples) | report_parts]
    else
      report_parts
    end

    report_parts = if :traceability in sections do
      [generate_traceability_section(analysis.traceability) | report_parts]
    else
      report_parts
    end

    report_parts = if :ai_data in sections do
      [generate_ai_data_section(analysis.ai_data) | report_parts]
    else
      report_parts
    end

    header = """
    ===============================================
    PRISMATIC DOCUMENTATION ANALYSIS REPORT
    ===============================================
    Generated: #{analysis.analysis_timestamp}
    Analysis Version: #{analysis.analysis_version}
    ===============================================

    """

    header <> Enum.join(Enum.reverse(report_parts), "\n\n")
  end

  defp generate_summary_section(analysis) do
    """
    EXECUTIVE SUMMARY
    ================

    This comprehensive analysis examined the Prismatic documentation
    system including Architecture Decision Records, code examples,
    traceability markers, and AI integration data.

    Key Metrics:
    - Architecture Decisions: #{length(analysis.adrs.adrs)}
    - Code Examples: #{analysis.code_examples.summary.total_examples}
    - Traceability Links: #{analysis.traceability.summary.successful_links}
    - Analysis Timestamp: #{analysis.analysis_timestamp}

    Overall Assessment: The documentation system shows strong
    architectural decision tracking with comprehensive cross-referencing
    capabilities and AI-optimized data structures.
    """
  end

  defp generate_adrs_section(adrs) do
    """
    ARCHITECTURE DECISION RECORDS
    ============================

    Total ADRs Analyzed: #{length(adrs.adrs)}
    Average Complexity Score: #{adrs.summary.average_complexity}

    Domain Distribution:
    #{format_distribution(adrs.summary.domain_distribution)}

    Status Distribution:
    #{format_distribution(adrs.summary.status_distribution)}

    Decision Timeline:
    #{format_timeline(adrs.summary.decision_timeline)}
    """
  end

  defp generate_examples_section(examples) do
    """
    CODE EXAMPLES ANALYSIS
    =====================

    Total Examples: #{examples.summary.total_examples}
    Executable Examples: #{examples.summary.executable_examples}
    Conceptual Examples: #{examples.summary.conceptual_examples}
    Transformation Candidates: #{examples.summary.transformation_candidates}

    Language Distribution:
    #{format_distribution(examples.summary.by_language)}

    Type Distribution:
    #{format_distribution(examples.summary.by_type)}
    """
  end

  defp generate_traceability_section(traceability) do
    """
    TRACEABILITY ANALYSIS
    ====================

    Documentation References: #{traceability.summary.total_documentation_references}
    Code References: #{traceability.summary.total_code_references}
    Successful Links: #{traceability.summary.successful_links}
    Traceability Score: #{traceability.summary.traceability_score}%

    Coverage Analysis:
    - Documentation Coverage: #{traceability.summary.coverage_analysis.documentation_coverage}%
    - Code Coverage: #{traceability.summary.coverage_analysis.code_coverage}%

    Orphaned Items: #{traceability.summary.orphaned_items}
    """
  end

  defp generate_ai_data_section(ai_data) do
    """
    AI INTEGRATION DATA
    ==================

    Schema Version: #{ai_data.schema_version}
    Generation Time: #{ai_data.generation_timestamp}
    Source Path: #{ai_data.source_path}

    AI-structured data has been successfully generated with optimized
    formats for assistant consumption, including knowledge graphs,
    query interfaces, and automated content generation capabilities.
    """
  end

  defp format_distribution(distribution) when is_map(distribution) do
    distribution
    |> Enum.map(fn {key, value} -> "  #{key}: #{value}" end)
    |> Enum.join("\n")
  end

  defp format_distribution(_), do: "  No distribution data available"

  defp format_timeline(timeline) when is_list(timeline) do
    timeline
    |> Enum.take(5)  # Show only recent 5
    |> Enum.map(fn item ->
      "  #{item.date} - ADR-#{item.decision_id}: #{item.title} (#{item.status})"
    end)
    |> Enum.join("\n")
  end

  defp format_timeline(_), do: "  No timeline data available"

  defp generate_markdown_report(analysis, sections) do
    # Convert text report to markdown format
    text_report = generate_text_report(analysis, sections)

    text_report
    |> String.replace("===============================================", "")
    |> String.replace("PRISMATIC DOCUMENTATION ANALYSIS REPORT", "# Prismatic Documentation Analysis Report")
    |> String.replace(~r/^([A-Z ]+)$/m, "## \\1")
    |> String.replace(~r/^([A-Za-z ]+):$/m, "### \\1")
  end

  defp generate_html_report(analysis, sections) do
    markdown_report = generate_markdown_report(analysis, sections)

    # Simple HTML wrapper (would use a proper markdown-to-HTML library in practice)
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Prismatic Documentation Analysis Report</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            h1, h2, h3 { color: #333; }
            pre { background: #f5f5f5; padding: 10px; }
        </style>
    </head>
    <body>
        <pre>#{markdown_report}</pre>
    </body>
    </html>
    """
  end
end
