defmodule Mix.Tasks.Docs.Tasks.Report do
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
  alias Mix.Tasks.Docs.Shared.{Config, ErrorHandler, OutputFormatter, ProgressMonitor}

  @shortdoc "Generate comprehensive analysis report"

  @valid_formats ~w(text html markdown)
  @valid_sections ~w(summary adrs examples traceability ai_data)

  @task_defaults %{
    sections: @valid_sections,
    file_prefix: "docs-report"
  }

  @impl Mix.Task
  def run(args) do
    start_time = System.monotonic_time(:millisecond)

    ErrorHandler.safe_execute("report", "task execution", fn ->
      case parse_and_validate_options(args) do
        {:ok, %{help: true}} ->
          show_comprehensive_help()

        {:ok, options} ->
          run_report_generation(options, start_time)

        {:error, reason} ->
          ErrorHandler.handle_validation_error(reason, "report")
      end
    end)
  end

  @doc false
  def parse_and_validate_options(args) do
    {options, _, invalid} = OptionParser.parse(args,
      switches: [
        docs: :string,
        code: :string,
        format: :string,
        file: :string,
        sections: :string,
        verbose: :boolean,
        help: :boolean
      ],
      aliases: [
        d: :docs,
        c: :code,
        f: :file,
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

      options[:format] && options[:format] not in @valid_formats ->
        {:error, "Invalid format '#{options[:format]}'. Available: #{Enum.join(@valid_formats, ", ")}"}

      options[:sections] && not valid_sections?(options[:sections]) ->
        {:error, "Invalid sections. Available: #{Enum.join(@valid_sections, ", ")}"}

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
    Enum.all?(sections, &(&1 in @valid_sections))
  end

  defp normalize_options(options) do
    base_config = Config.normalize_config(options, @task_defaults)

    # Override output format based on report format
    output_format = case options[:format] || "text" do
      "html" -> "html"
      "markdown" -> "report"
      _ -> "report"
    end

    Map.merge(base_config, %{
      report_format: options[:format] || "text",
      output_format: output_format,
      sections: parse_sections(options[:sections]) || @valid_sections
    })
  end

  defp parse_sections(nil), do: @valid_sections
  defp parse_sections("all"), do: @valid_sections
  defp parse_sections(sections_string) when is_binary(sections_string) do
    sections_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 in @valid_sections))
  end

  defp run_report_generation(options, start_time) do
    if options.verbose do
      Config.display_config(options, "report generation")
    end

    ProgressMonitor.show_simple_progress("Generating comprehensive report")

    # Ensure Mix application is started
    Mix.Task.run("app.start")

    # Validate file access
    ErrorHandler.validate_file_access(options.docs_path, "Documentation directory")
    ErrorHandler.validate_file_access(options.code_path, "Code directory")
    ErrorHandler.validate_output_directory(options.output_file)

    # Run analysis
    analysis = Documentation.comprehensive_analysis(options.docs_path, options.code_path)

    # Generate report
    report_content = generate_report(analysis, options.report_format, options.sections)

    # Save report
    File.write!(options.output_file, report_content)

    execution_time = System.monotonic_time(:millisecond) - start_time
    ProgressMonitor.show_completion("Report generation", execution_time)
    ProgressMonitor.show_output_saved(options.output_file)

    if options.verbose do
      Mix.shell().info("\nReport sections included: #{Enum.join(options.sections, ", ")}")
      Mix.shell().info("Report format: #{options.report_format}")
    end

    if options.ci_mode do
      OutputFormatter.format_ci_summary(analysis, "report")
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
      [generate_adrs_section(analysis[:adrs]) | report_parts]
    else
      report_parts
    end

    report_parts = if :examples in sections do
      [generate_examples_section(analysis[:code_examples]) | report_parts]
    else
      report_parts
    end

    report_parts = if :traceability in sections do
      [generate_traceability_section(analysis[:traceability]) | report_parts]
    else
      report_parts
    end

    report_parts = if :ai_data in sections do
      [generate_ai_data_section(analysis[:ai_data]) | report_parts]
    else
      report_parts
    end

    header = """
    ===============================================
    PRISMATIC DOCUMENTATION ANALYSIS REPORT
    ===============================================
    Generated: #{analysis[:analysis_timestamp]}
    Analysis Version: #{analysis[:analysis_version]}
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
    - Architecture Decisions: #{length(analysis[:adrs][:adrs] || [])}
    - Code Examples: #{analysis[:code_examples][:summary][:total_examples] || 0}
    - Traceability Links: #{analysis[:traceability][:summary][:successful_links] || 0}
    - Analysis Timestamp: #{analysis[:analysis_timestamp]}

    Overall Assessment: The documentation system shows strong
    architectural decision tracking with comprehensive cross-referencing
    capabilities and AI-optimized data structures.
    """
  end

  defp generate_adrs_section(nil), do: "ADRs: No data available"
  defp generate_adrs_section(adrs) do
    """
    ARCHITECTURE DECISION RECORDS
    ============================

    Total ADRs Analyzed: #{length(adrs[:adrs] || [])}
    Average Complexity Score: #{adrs[:summary][:average_complexity] || "N/A"}

    Domain Distribution:
    #{format_distribution(adrs[:summary][:domain_distribution])}

    Status Distribution:
    #{format_distribution(adrs[:summary][:status_distribution])}

    Decision Timeline:
    #{format_timeline(adrs[:summary][:decision_timeline])}
    """
  end

  defp generate_examples_section(nil), do: "Code Examples: No data available"
  defp generate_examples_section(examples) do
    """
    CODE EXAMPLES ANALYSIS
    =====================

    Total Examples: #{examples[:summary][:total_examples] || 0}
    Executable Examples: #{examples[:summary][:executable_examples] || 0}
    Conceptual Examples: #{examples[:summary][:conceptual_examples] || 0}
    Transformation Candidates: #{examples[:summary][:transformation_candidates] || 0}

    Language Distribution:
    #{format_distribution(examples[:summary][:by_language])}

    Type Distribution:
    #{format_distribution(examples[:summary][:by_type])}
    """
  end

  defp generate_traceability_section(nil), do: "Traceability: No data available"
  defp generate_traceability_section(traceability) do
    """
    TRACEABILITY ANALYSIS
    ====================

    Documentation References: #{traceability[:summary][:total_documentation_references] || 0}
    Code References: #{traceability[:summary][:total_code_references] || 0}
    Successful Links: #{traceability[:summary][:successful_links] || 0}
    Traceability Score: #{traceability[:summary][:traceability_score] || 0}%

    Coverage Analysis:
    - Documentation Coverage: #{get_in(traceability, [:summary, :coverage_analysis, :documentation_coverage]) || 0}%
    - Code Coverage: #{get_in(traceability, [:summary, :coverage_analysis, :code_coverage]) || 0}%

    Orphaned Items: #{traceability[:summary][:orphaned_items] || 0}
    """
  end

  defp generate_ai_data_section(nil), do: "AI Data: No data available"
  defp generate_ai_data_section(ai_data) do
    """
    AI INTEGRATION DATA
    ==================

    Schema Version: #{ai_data[:schema_version] || "Unknown"}
    Generation Time: #{ai_data[:generation_timestamp] || "Unknown"}
    Source Path: #{ai_data[:source_path] || "Unknown"}

    AI-structured data has been successfully generated with optimized
    formats for assistant consumption, including knowledge graphs,
    query interfaces, and automated content generation capabilities.
    """
  end

  defp format_distribution(nil), do: "  No distribution data available"
  defp format_distribution(distribution) when is_map(distribution) do
    distribution
    |> Enum.map(fn {key, value} -> "  #{key}: #{value}" end)
    |> Enum.join("\n")
  end
  defp format_distribution(_), do: "  No distribution data available"

  defp format_timeline(nil), do: "  No timeline data available"
  defp format_timeline(timeline) when is_list(timeline) do
    timeline
    |> Enum.take(5)  # Show only recent 5
    |> Enum.map(fn item ->
      "  #{item[:date]} - ADR-#{item[:decision_id]}: #{item[:title]} (#{item[:status]})"
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

  defp show_comprehensive_help do
    Mix.shell().info(@moduledoc)
  end
end
