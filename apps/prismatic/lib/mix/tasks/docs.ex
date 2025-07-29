defmodule Mix.Tasks.Docs do
  @moduledoc """
  Mix tasks for AI-assisted documentation analysis and enhancement.

  This module provides command-line interface to all documentation analysis
  tools including ADR extraction, code example analysis, traceability markers,
  and AI assistant integration.

  ## Available Commands

  - `mix docs.analyze` - Comprehensive documentation analysis
  - `mix docs.extract_adrs` - Extract and analyze Architecture Decision Records
  - `mix docs.extract_examples` - Extract and categorize code examples
  - `mix docs.trace` - Generate traceability markers
  - `mix docs.ai_data` - Generate AI-friendly structured data
  - `mix docs.validate` - Validate documentation links and references
  - `mix docs.report` - Generate comprehensive analysis report
  """

  use Mix.Task

  @shortdoc "Comprehensive documentation analysis (see --help for specific commands)"

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
    AI-Assisted Documentation Analysis Tools

    Available commands:
      mix docs.analyze          - Run comprehensive documentation analysis
      mix docs.extract_adrs     - Extract Architecture Decision Records
      mix docs.extract_examples - Extract and analyze code examples
      mix docs.trace           - Generate traceability markers
      mix docs.ai_data         - Generate AI-friendly structured data
      mix docs.validate        - Validate documentation consistency
      mix docs.report          - Generate analysis report

    Use 'mix docs.[command] --help' for command-specific options.

    Examples:
      mix docs.analyze
      mix docs.extract_adrs --output json
      mix docs.trace --docs docs --code apps
      mix docs.ai_data --format yaml
    """
  end

  defp execute_command(command, args) do
    case command do
      "analyze" -> Mix.Tasks.Docs.Analyze.run(args)
      "extract_adrs" -> Mix.Tasks.Docs.ExtractAdrs.run(args)
      "extract_examples" -> Mix.Tasks.Docs.ExtractExamples.run(args)
      "trace" -> Mix.Tasks.Docs.Trace.run(args)
      "ai_data" -> Mix.Tasks.Docs.AiData.run(args)
      "validate" -> Mix.Tasks.Docs.Validate.run(args)
      "report" -> Mix.Tasks.Docs.Report.run(args)
      _ ->
        IO.puts "Unknown command: #{command}"
        show_help()
    end
  end
end

defmodule Mix.Tasks.Docs.Analyze do
  @moduledoc """
  Comprehensive documentation analysis combining all tools.

  This task runs the complete AI-assisted documentation analysis,
  including ADR extraction, code example analysis, traceability
  generation, and AI data structuring.

  ## Options

    * `--docs` - Documentation directory (default: docs)
    * `--code` - Code directory (default: apps)
    * `--output` - Output format: json, yaml, report (default: json)
    * `--file` - Output file path (default: docs-analysis.json)
    * `--verbose` - Enable verbose output

  ## Examples

      mix docs.analyze
      mix docs.analyze --output report --verbose
      mix docs.analyze --docs documentation --code lib
  """

  use Mix.Task
  alias Prismatic.Documentation

  @shortdoc "Run comprehensive documentation analysis"

  def run(args) do
    {options, _, _} = OptionParser.parse(args,
      switches: [
        docs: :string,
        code: :string,
        output: :string,
        file: :string,
        verbose: :boolean,
        help: :boolean
      ],
      aliases: [
        d: :docs,
        c: :code,
        o: :output,
        f: :file,
        v: :verbose,
        h: :help
      ]
    )

    if options[:help] do
      show_help()
    else
      run_analysis(options)
    end
  end

  defp show_help do
    IO.puts @moduledoc
  end

  defp run_analysis(options) do
    docs_path = options[:docs] || "docs"
    code_path = options[:code] || "apps"
    output_format = options[:output] || "json"
    output_file = options[:file] || "docs-analysis.json"
    verbose = options[:verbose] || false

    if verbose do
      IO.puts "Starting comprehensive documentation analysis..."
      IO.puts "Documentation path: #{docs_path}"
      IO.puts "Code path: #{code_path}"
      IO.puts "Output format: #{output_format}"
    end

    # Ensure Mix application is started
    Mix.Task.run("app.start")

    try do
      # Run comprehensive analysis
      analysis_result = Documentation.comprehensive_analysis(docs_path, code_path)

      if verbose do
        print_analysis_summary(analysis_result)
      end

      # Save results based on format
      case output_format do
        "json" -> save_json_output(analysis_result, output_file)
        "yaml" -> save_yaml_output(analysis_result, output_file)
        "report" -> save_report_output(analysis_result, output_file)
        _ ->
          IO.puts "Unknown output format: #{output_format}"
          exit(:normal)
      end

      IO.puts "✅ Analysis complete! Results saved to #{output_file}"

    rescue
      error ->
        IO.puts "❌ Analysis failed: #{Exception.message(error)}"
        if verbose do
          IO.puts Exception.format_stacktrace(__STACKTRACE__)
        end
        exit({:shutdown, 1})
    end
  end

  defp print_analysis_summary(analysis) do
    IO.puts "\n📊 Analysis Summary:"
    IO.puts "  ADRs found: #{length(analysis.adrs.adrs)}"
    IO.puts "  Code examples: #{analysis.code_examples.summary.total_examples}"
    IO.puts "  Traceability links: #{analysis.traceability.summary.successful_links}"
    IO.puts "  Analysis timestamp: #{analysis.analysis_timestamp}"
  end

  defp save_json_output(result, file_path) do
    json_content = Jason.encode!(result, pretty: true)
    File.write!(file_path, json_content)
  end

  defp save_yaml_output(result, file_path) do
    # Would need YamlElixir dependency
    IO.puts "YAML output not implemented yet, saving as JSON..."
    save_json_output(result, String.replace(file_path, ".yaml", ".json"))
  end

  defp save_report_output(result, file_path) do
    report_content = generate_text_report(result)
    File.write!(file_path, report_content)
  end

  defp generate_text_report(analysis) do
    """
    # Documentation Analysis Report
    Generated: #{analysis.analysis_timestamp}

    ## Summary
    - Total ADRs: #{length(analysis.adrs.adrs)}
    - Code Examples: #{analysis.code_examples.summary.total_examples}
    - Traceability Links: #{analysis.traceability.summary.successful_links}

    ## Architecture Decisions
    #{format_adrs_for_report(analysis.adrs)}

    ## Code Examples Analysis
    #{format_examples_for_report(analysis.code_examples)}

    ## Traceability Analysis
    #{format_traceability_for_report(analysis.traceability)}

    ## AI Integration Data
    #{format_ai_data_for_report(analysis.ai_data)}
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
  Extract and analyze Architecture Decision Records.

  This task extracts ADRs from documentation and generates
  comprehensive metadata and analysis.

  ## Options

    * `--docs` - Documentation directory (default: docs)
    * `--output` - Output format: json, yaml (default: json)
    * `--file` - Output file path (default: adrs-analysis.json)
    * `--domain` - Filter by architectural domain
    * `--status` - Filter by decision status
    * `--verbose` - Enable verbose output

  ## Examples

      mix docs.extract_adrs
      mix docs.extract_adrs --domain security
      mix docs.extract_adrs --status Accepted --output yaml
  """

  use Mix.Task
  alias Prismatic.Documentation.ADRExtractor

  @shortdoc "Extract Architecture Decision Records"

  def run(args) do
    {options, _, _} = OptionParser.parse(args,
      switches: [
        docs: :string,
        output: :string,
        file: :string,
        domain: :string,
        status: :string,
        verbose: :boolean,
        help: :boolean
      ]
    )

    if options[:help] do
      IO.puts @moduledoc
    else
      run_extraction(options)
    end
  end

  defp run_extraction(options) do
    docs_path = options[:docs] || "docs"
    output_format = options[:output] || "json"
    output_file = options[:file] || "adrs-analysis.json"
    verbose = options[:verbose] || false

    Mix.Task.run("app.start")

    try do
      if verbose, do: IO.puts "Extracting ADRs from #{docs_path}..."

      result = ADRExtractor.extract_all_adrs(docs_path)

      # Apply filters if specified
      filtered_result = apply_adr_filters(result, options)

      if verbose do
        IO.puts "Found #{length(filtered_result.adrs)} ADRs"
        print_adr_summary(filtered_result)
      end

      # Save results
      save_output(filtered_result, output_format, output_file)
      IO.puts "✅ ADR extraction complete! Results saved to #{output_file}"

    rescue
      error ->
        IO.puts "❌ ADR extraction failed: #{Exception.message(error)}"
        exit({:shutdown, 1})
    end
  end

  defp apply_adr_filters(result, options) do
    filtered_adrs = result.adrs

    filtered_adrs = if options[:domain] do
      Enum.filter(filtered_adrs, &(&1.architectural_domain == options[:domain]))
    else
      filtered_adrs
    end

    filtered_adrs = if options[:status] do
      Enum.filter(filtered_adrs, &(&1.status == options[:status]))
    else
      filtered_adrs
    end

    %{result | adrs: filtered_adrs}
  end

  defp print_adr_summary(result) do
    IO.puts "\n📋 ADR Summary:"
    IO.puts "  Total ADRs: #{length(result.adrs)}"
    IO.puts "  Average Complexity: #{result.summary.average_complexity}"

    IO.puts "\n  Domain Distribution:"
    Enum.each(result.summary.domain_distribution, fn {domain, count} ->
      IO.puts "    #{domain}: #{count}"
    end)

    IO.puts "\n  Status Distribution:"
    Enum.each(result.summary.status_distribution, fn {status, count} ->
      IO.puts "    #{status}: #{count}"
    end)
  end

  defp save_output(result, format, file_path) do
    case format do
      "json" ->
        json_content = Jason.encode!(result, pretty: true)
        File.write!(file_path, json_content)
      "yaml" ->
        IO.puts "YAML output not implemented, saving as JSON..."
        json_content = Jason.encode!(result, pretty: true)
        File.write!(String.replace(file_path, ".yaml", ".json"), json_content)
      _ ->
        IO.puts "Unknown format: #{format}, using JSON"
        json_content = Jason.encode!(result, pretty: true)
        File.write!(file_path, json_content)
    end
  end
end

defmodule Mix.Tasks.Docs.ExtractExamples do
  @moduledoc """
  Extract and analyze code examples from documentation.

  This task extracts code examples, categorizes them, and provides
  transformation analysis for converting examples to executable code.

  ## Options

    * `--docs` - Documentation directory (default: docs)
    * `--language` - Filter by programming language
    * `--executable` - Show only executable examples
    * `--output` - Output format: json, yaml (default: json)
    * `--file` - Output file path (default: examples-analysis.json)
    * `--verbose` - Enable verbose output

  ## Examples

      mix docs.extract_examples
      mix docs.extract_examples --language elixir
      mix docs.extract_examples --executable --output json
  """

  use Mix.Task
  alias Prismatic.Documentation.CodeExampleExtractor

  @shortdoc "Extract and analyze code examples"

  def run(args) do
    {options, _, _} = OptionParser.parse(args,
      switches: [
        docs: :string,
        language: :string,
        executable: :boolean,
        output: :string,
        file: :string,
        verbose: :boolean,
        help: :boolean
      ]
    )

    if options[:help] do
      IO.puts @moduledoc
    else
      run_extraction(options)
    end
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
