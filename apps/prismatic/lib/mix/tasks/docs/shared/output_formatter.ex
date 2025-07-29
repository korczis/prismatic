defmodule Mix.Tasks.Docs.Shared.OutputFormatter do
  @moduledoc """
  Centralized output formatting and file handling for documentation analysis tasks.

  Provides consistent output formatting across JSON, YAML, HTML, and text report formats.
  Handles file writing operations with proper error handling and validation.
  """

  alias Mix.Tasks.Docs.Shared.Config

  @doc """
  Save analysis results in the specified format.
  """
  @spec save_results(map(), Config.config()) :: :ok | {:error, String.t()}
  def save_results(result, config) do
    case config.output_format do
      "json" -> save_json_output(result, config.output_file)
      "yaml" -> save_yaml_output(result, config.output_file)
      "html" -> save_html_output(result, config.output_file)
      "report" -> save_report_output(result, config.output_file)
      _ -> save_json_output(result, config.output_file)
    end
  rescue
    error ->
      {:error, "Failed to save output: #{Exception.message(error)}"}
  end

  @doc """
  Generate JSON output with pretty formatting.
  """
  @spec save_json_output(map(), String.t()) :: :ok
  def save_json_output(result, file_path) do
    json_content = Jason.encode!(result, pretty: true)
    File.write!(file_path, json_content)
    :ok
  end

  @doc """
  Generate YAML output, falling back to JSON if YAML library unavailable.
  """
  @spec save_yaml_output(map(), String.t()) :: :ok
  def save_yaml_output(result, file_path) do
    try do
      yaml_content = YamlElixir.write_to_string!(result)
      File.write!(file_path, yaml_content)
      :ok
    rescue
      UndefinedFunctionError ->
        Mix.shell().info("⚠️  YAML library not available, saving as JSON instead")
        json_file = String.replace(file_path, ".yaml", ".json")
        save_json_output(result, json_file)
    end
  end

  @doc """
  Generate HTML report with consistent styling.
  """
  @spec save_html_output(map(), String.t()) :: :ok
  def save_html_output(result, file_path) do
    html_content = generate_html_report(result)
    File.write!(file_path, html_content)
    :ok
  end

  @doc """
  Generate text report with consistent formatting.
  """
  @spec save_report_output(map(), String.t()) :: :ok
  def save_report_output(result, file_path) do
    report_content = generate_text_report(result)
    File.write!(file_path, report_content)
    :ok
  end

  @doc """
  Generate a generic HTML report template.
  """
  @spec generate_html_report(map()) :: String.t()
  def generate_html_report(result) do
    title = extract_report_title(result)
    timestamp = result[:analysis_timestamp] || result[:extraction_timestamp] || DateTime.utc_now() |> DateTime.to_iso8601()

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>#{title}</title>
        #{html_styles()}
    </head>
    <body>
        <div class="header">
            <h1>#{extract_report_icon(result)} #{title}</h1>
            <p class="timestamp">Generated: #{timestamp}</p>
        </div>

        <div class="summary-grid">
            #{generate_html_metrics(result)}
        </div>

        <div class="section">
            <h2>📋 Configuration</h2>
            <pre>#{format_configuration_for_html(result[:configuration])}</pre>
        </div>

        #{generate_html_content_sections(result)}

        <div class="section">
            <h2>📈 Next Steps</h2>
            <ul>
                <li>Review analysis results and identified issues</li>
                <li>Implement recommended improvements</li>
                <li>Establish regular monitoring and maintenance</li>
                <li>Integrate results into development workflow</li>
            </ul>
        </div>
    </body>
    </html>
    """
  end

  @doc """
  Generate a generic text report.
  """
  @spec generate_text_report(map()) :: String.t()
  def generate_text_report(result) do
    title = extract_report_title(result) |> String.upcase()
    timestamp = result[:analysis_timestamp] || result[:extraction_timestamp] || DateTime.utc_now() |> DateTime.to_iso8601()

    """
    ████████████████████████████████████████████████████████████████
    ██                                                            ██
    ██                #{String.pad_trailing(title, 44)}    ██
    ██                                                            ██
    ████████████████████████████████████████████████████████████████

    Generated: #{timestamp}
    #{if result[:analysis_version], do: "Analysis Version: #{result.analysis_version}", else: ""}

    ## SUMMARY
    =========

    #{generate_text_summary(result)}

    ## DETAILED RESULTS
    ==================

    #{format_result_content_for_text(result)}

    ## RECOMMENDATIONS
    =================

    #{generate_recommendations(result)}

    ████████████████████████████████████████████████████████████████
    """
  end

  @doc """
  Format CI summary output for automation.
  """
  @spec format_ci_summary(map(), String.t()) :: :ok
  def format_ci_summary(result, task_name) do
    ci_summary = %{
      status: "success",
      timestamp: result[:analysis_timestamp] || result[:extraction_timestamp] || DateTime.utc_now() |> DateTime.to_iso8601(),
      task: task_name,
      metrics: extract_ci_metrics(result),
      recommendations: extract_ci_recommendations(result)
    }

    Mix.shell().info("CI_#{String.upcase(task_name)}_SUMMARY=#{Jason.encode!(ci_summary)}")
    :ok
  end

  # Private helper functions

  defp html_styles do
    """
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
                color: rgba(255,255,255,0.8);
                font-size: 0.9rem;
            }
        </style>
    """
  end

  defp extract_report_title(result) do
    cond do
      Map.has_key?(result, :adrs) -> "Architecture Decision Records Analysis"
      Map.has_key?(result, :examples) -> "Code Examples Analysis"
      Map.has_key?(result, :trace) -> "Traceability Analysis"
      Map.has_key?(result, :ai) -> "AI Integration Data Analysis"
      true -> "Documentation Analysis Report"
    end
  end

  defp extract_report_icon(result) do
    cond do
      Map.has_key?(result, :adrs) -> "🏗️"
      Map.has_key?(result, :examples) -> "💻"
      Map.has_key?(result, :trace) -> "🔗"
      Map.has_key?(result, :ai) -> "🤖"
      true -> "🔍"
    end
  end

  defp generate_html_metrics(result) do
    metrics = extract_key_metrics(result)

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

  defp generate_html_content_sections(result) do
    # Generate content sections based on what's available in the result
    sections = []

    sections = if Map.has_key?(result, :summary) do
      [generate_summary_html_section(result.summary) | sections]
    else
      sections
    end

    sections = if Map.has_key?(result, :adrs) do
      [generate_adrs_html_section(result.adrs) | sections]
    else
      sections
    end

    sections = if Map.has_key?(result, :examples) do
      [generate_examples_html_section(result.examples) | sections]
    else
      sections
    end

    Enum.reverse(sections) |> Enum.join("")
  end

  defp generate_summary_html_section(summary) do
    """
    <div class="section">
        <h2>📊 Summary</h2>
        <pre>#{inspect(summary, pretty: true)}</pre>
    </div>
    """
  end

  defp generate_adrs_html_section(adrs) do
    count = if is_list(adrs), do: length(adrs), else: length(adrs[:adrs] || [])
    """
    <div class="section">
        <h2>🏗️ Architecture Decision Records</h2>
        <p>Found #{count} ADRs across the documentation system.</p>
        <pre>#{inspect(Map.take(adrs, [:summary]), pretty: true)}</pre>
    </div>
    """
  end

  defp generate_examples_html_section(examples) do
    count = if is_list(examples), do: length(examples), else: length(examples[:examples] || [])
    """
    <div class="section">
        <h2>💻 Code Examples Analysis</h2>
        <p>Analyzed #{count} code examples.</p>
        <pre>#{inspect(Map.take(examples, [:summary]), pretty: true)}</pre>
    </div>
    """
  end

  defp format_configuration_for_html(nil), do: "Configuration not available"
  defp format_configuration_for_html(config) when is_map(config) do
    Jason.encode!(config, pretty: true)
  end
  defp format_configuration_for_html(_), do: "Configuration not available"

  defp generate_text_summary(result) do
    metrics = extract_key_metrics(result)

    Enum.map(metrics, fn {value, label} ->
      "#{label}: #{value || 0}"
    end)
    |> Enum.join("\n")
  end

  defp format_result_content_for_text(result) do
    content_parts = []

    content_parts = if Map.has_key?(result, :summary) do
      ["Summary:\n#{inspect(result.summary, pretty: true)}" | content_parts]
    else
      content_parts
    end

    if Enum.empty?(content_parts) do
      "Detailed analysis results available in structured output formats."
    else
      Enum.reverse(content_parts) |> Enum.join("\n\n")
    end
  end

  defp generate_recommendations(_result) do
    """
    • Regular analysis should be integrated into CI/CD pipeline
    • Consider setting up automated alerts for critical issues
    • Establish quality gates based on analysis metrics
    • Review and address identified gaps and inconsistencies
    """
  end

  defp extract_key_metrics(result) do
    metrics = []

    metrics = if Map.has_key?(result, :adrs) do
      count = if is_list(result.adrs), do: length(result.adrs), else: length(result.adrs[:adrs] || [])
      [{count, "Architecture Decisions"} | metrics]
    else
      metrics
    end

    metrics = if Map.has_key?(result, :examples) do
      count = if is_list(result.examples), do: length(result.examples), else: length(result.examples[:examples] || [])
      [{count, "Code Examples"} | metrics]
    else
      metrics
    end

    metrics = if Map.has_key?(result, :trace) do
      count = get_in(result, [:trace, :summary, :successful_links]) || 0
      [{count, "Traceability Links"} | metrics]
    else
      metrics
    end

    if Enum.empty?(metrics) do
      [{1, "Analysis Complete"}]
    else
      Enum.reverse(metrics)
    end
  end

  defp extract_ci_metrics(result) do
    metrics = %{
      total_items: 0,
      success_rate: 100,
      analysis_sections: 1
    }

    metrics = if Map.has_key?(result, :adrs) do
      count = if is_list(result.adrs), do: length(result.adrs), else: length(result.adrs[:adrs] || [])
      Map.put(metrics, :adrs_count, count)
    else
      metrics
    end

    metrics = if Map.has_key?(result, :examples) do
      count = if is_list(result.examples), do: length(result.examples), else: length(result.examples[:examples] || [])
      Map.put(metrics, :examples_count, count)
    else
      metrics
    end

    metrics
  end

  defp extract_ci_recommendations(_result) do
    [
      "Integrate analysis results into development workflow",
      "Set up regular monitoring for documentation health",
      "Consider automation opportunities for identified issues"
    ]
  end
end
