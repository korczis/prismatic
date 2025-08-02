defmodule Mix.Tasks.Prismatic.Shared.OutputFormatter do
  @moduledoc """
  Enhanced output formatting with multi-format support and CI/CD integration.

  Provides comprehensive output formatting including:
  - Multiple output formats (JSON, YAML, HTML, Markdown, Report)
  - CI/CD friendly structured output
  - Progress indicators and status displays
  - Color-coded console output with fallbacks
  - Template-based report generation
  - Export capabilities for external tools
  """

  alias Mix.Tasks.Prismatic.Shared.Config

  @supported_formats [:json, :yaml, :html, :markdown, :report, :console]
  @status_colors %{
    success: :green,
    warning: :yellow,
    error: :red,
    info: :blue,
    debug: :cyan
  }

  @doc """
  Format and display results in the specified format.
  """
  @spec format_output(any(), atom(), keyword()) :: :ok
  def format_output(data, format, opts \\ []) do
    validate_format!(format)

    case format do
      :console -> format_console_output(data, opts)
      :json -> format_json_output(data, opts)
      :yaml -> format_yaml_output(data, opts)
      :html -> format_html_output(data, opts)
      :markdown -> format_markdown_output(data, opts)
      :report -> format_report_output(data, opts)
    end
  end

  @doc """
  Save formatted output to file with automatic format detection.
  """
  @spec save_output(any(), String.t(), keyword()) :: :ok | {:error, String.t()}
  def save_output(data, file_path, opts \\ []) do
    format = opts[:format] || detect_format_from_extension(file_path)
    validate_format!(format)

    output_content = case format do
      :json -> encode_json(data, opts)
      :yaml -> encode_yaml(data, opts)
      :html -> generate_html_content(data, opts)
      :markdown -> generate_markdown_content(data, opts)
      :report -> generate_report_content(data, opts)
      _ -> inspect(data, pretty: true)
    end

    case File.write(file_path, output_content) do
      :ok ->
        display_success("Output saved to #{file_path} (#{format})")
        :ok
      {:error, reason} ->
        {:error, "Failed to write to #{file_path}: #{reason}"}
    end
  end

  @doc """
  Display status message with appropriate styling.
  """
  @spec display_status(String.t(), atom(), keyword()) :: :ok
  def display_status(message, status, opts \\ []) do
    icon = get_status_icon(status)
    color = @status_colors[status] || :reset
    prefix = opts[:prefix] || ""

    if ci_mode?() do
      # CI-friendly output without colors
      Mix.shell().info("#{prefix}[#{String.upcase(Atom.to_string(status))}] #{message}")
    else
      # Colored output for interactive terminals
      Mix.shell().info([
        color, "#{icon} #{prefix}", :reset, message
      ])
    end
    :ok
  end

  @doc """
  Display success message with checkmark.
  """
  @spec display_success(String.t(), keyword()) :: :ok
  def display_success(message, opts \\ []) do
    display_status(message, :success, opts)
  end

  @doc """
  Display warning message with warning icon.
  """
  @spec display_warning(String.t(), keyword()) :: :ok
  def display_warning(message, opts \\ []) do
    display_status(message, :warning, opts)
  end

  @doc """
  Display error message with error icon.
  """
  @spec display_error(String.t(), keyword()) :: :ok
  def display_error(message, opts \\ []) do
    display_status(message, :error, opts)
  end

  @doc """
  Display info message with info icon.
  """
  @spec display_info(String.t(), keyword()) :: :ok
  def display_info(message, opts \\ []) do
    display_status(message, :info, opts)
  end

  @doc """
  Display debug message (only in verbose mode).
  """
  @spec display_debug(String.t(), keyword()) :: :ok
  def display_debug(message, opts \\ []) do
    if verbose_mode?() do
      display_status(message, :debug, opts)
    end
    :ok
  end

  @doc """
  Display structured table data.
  """
  @spec display_table([map()], [atom()], keyword()) :: :ok
  def display_table(data, columns, opts \\ []) do
    if Enum.empty?(data) do
      display_info("No data to display")
      :ok
    else
      headers = columns |> Enum.map(&String.capitalize(Atom.to_string(&1)))

      if ci_mode?() do
        display_table_ci(data, columns, headers, opts)
      else
        display_table_interactive(data, columns, headers, opts)
      end
      :ok
    end
  end

  @doc """
  Display progress summary with statistics.
  """
  @spec display_summary(map(), keyword()) :: :ok
  def display_summary(summary, opts \\ []) do
    title = opts[:title] || "Summary"

    display_section_header(title)

    # Display key metrics
    if Map.has_key?(summary, :total) do
      display_info("Total items processed: #{summary.total}")
    end

    if Map.has_key?(summary, :success) do
      display_success("Successful: #{summary.success}")
    end

    if Map.has_key?(summary, :warnings) and summary.warnings > 0 do
      display_warning("Warnings: #{summary.warnings}")
    end

    if Map.has_key?(summary, :errors) and summary.errors > 0 do
      display_error("Errors: #{summary.errors}")
    end

    # Display execution time if available
    if Map.has_key?(summary, :execution_time) do
      display_info("Execution time: #{summary.execution_time}ms")
    end

    # Display additional metrics
    additional_metrics = Map.drop(summary, [:total, :success, :warnings, :errors, :execution_time])
    unless Enum.empty?(additional_metrics) do
      Enum.each(additional_metrics, fn {key, value} ->
        display_info("#{String.capitalize(Atom.to_string(key))}: #{value}")
      end)
    end

    :ok
  end

  @doc """
  Display section header with separator.
  """
  @spec display_section_header(String.t(), keyword()) :: :ok
  def display_section_header(title, opts \\ []) do
    separator_char = opts[:separator] || "─"
    width = opts[:width] || 60

    separator = String.duplicate(separator_char, width)

    if ci_mode?() do
      Mix.shell().info("\n=== #{title} ===")
    else
      Mix.shell().info([
        :bright, "\n#{separator}", :reset
      ])
      Mix.shell().info([
        :bright, :blue, " #{title}", :reset
      ])
      Mix.shell().info([
        :bright, "#{separator}", :reset
      ])
    end
    :ok
  end

  @doc """
  Generate diff display for changes.
  """
  @spec display_diff(String.t(), String.t(), String.t()) :: :ok
  def display_diff(file_path, old_content, new_content) do
    display_section_header("Changes to #{file_path}")

    if ci_mode?() do
      display_diff_ci(old_content, new_content)
    else
      display_diff_interactive(old_content, new_content)
    end
    :ok
  end

  @doc """
  Export data in specified format for external tools.
  """
  @spec export_for_external_tool(any(), atom(), keyword()) :: String.t()
  def export_for_external_tool(data, format, opts \\ []) do
    case format do
      :json ->
        encode_json(data, Keyword.merge(opts, [pretty: false]))
      :yaml ->
        encode_yaml(data, opts)
      :csv ->
        encode_csv(data, opts)
      :xml ->
        encode_xml(data, opts)
      _ ->
        inspect(data, pretty: false)
    end
  end

  @doc """
  Check if output format is supported.
  """
  @spec supported_format?(atom()) :: boolean()
  def supported_format?(format) do
    format in @supported_formats
  end

  @doc """
  Get list of supported output formats.
  """
  @spec supported_formats() :: [atom()]
  def supported_formats, do: @supported_formats

  # Private functions

  defp validate_format!(format) do
    unless supported_format?(format) do
      raise ArgumentError, "Unsupported format: #{format}. Supported formats: #{inspect(@supported_formats)}"
    end
  end

  defp detect_format_from_extension(file_path) do
    case Path.extname(file_path) do
      ".json" -> :json
      ".yaml" -> :yaml
      ".yml" -> :yaml
      ".html" -> :html
      ".htm" -> :html
      ".md" -> :markdown
      ".markdown" -> :markdown
      _ -> :json
    end
  end

  defp format_console_output(data, opts) do
    case data do
      data when is_map(data) ->
        format_map_console(data, opts)
      data when is_list(data) ->
        format_list_console(data, opts)
      _ ->
        Mix.shell().info(inspect(data, pretty: true))
    end
  end

  defp format_map_console(data, opts) do
    indent = opts[:indent] || 0
    prefix = String.duplicate("  ", indent)

    Enum.each(data, fn {key, value} ->
      case value do
        value when is_map(value) ->
          Mix.shell().info("#{prefix}#{key}:")
          format_map_console(value, Keyword.put(opts, :indent, indent + 1))
        value when is_list(value) ->
          Mix.shell().info("#{prefix}#{key}:")
          format_list_console(value, Keyword.put(opts, :indent, indent + 1))
        _ ->
          Mix.shell().info("#{prefix}#{key}: #{inspect(value)}")
      end
    end)
  end

  defp format_list_console(data, opts) do
    indent = opts[:indent] || 0
    prefix = String.duplicate("  ", indent)

    data
    |> Enum.with_index()
    |> Enum.each(fn {item, index} ->
      case item do
        item when is_map(item) ->
          Mix.shell().info("#{prefix}#{index + 1}:")
          format_map_console(item, Keyword.put(opts, :indent, indent + 1))
        _ ->
          Mix.shell().info("#{prefix}• #{inspect(item)}")
      end
    end)
  end

  defp format_json_output(data, opts) do
    json_content = encode_json(data, opts)
    Mix.shell().info(json_content)
  end

  defp format_yaml_output(data, opts) do
    yaml_content = encode_yaml(data, opts)
    Mix.shell().info(yaml_content)
  end

  defp format_html_output(data, opts) do
    html_content = generate_html_content(data, opts)
    Mix.shell().info(html_content)
  end

  defp format_markdown_output(data, opts) do
    markdown_content = generate_markdown_content(data, opts)
    Mix.shell().info(markdown_content)
  end

  defp format_report_output(data, opts) do
    report_content = generate_report_content(data, opts)
    Mix.shell().info(report_content)
  end

  defp encode_json(data, opts) do
    pretty = Keyword.get(opts, :pretty, true)

    case Jason.encode(data, pretty: pretty) do
      {:ok, json} -> json
      {:error, reason} ->
        Mix.shell().error("Failed to encode JSON: #{inspect(reason)}")
        inspect(data, pretty: true)
    end
  end

  defp encode_yaml(data, opts) do
    # Basic YAML encoding - could be enhanced with proper YAML library
    case Code.ensure_loaded(YamlElixir) do
      {:module, YamlElixir} ->
        case YamlElixir.write_to_string(data) do
          {:ok, yaml} -> yaml
          {:error, reason} ->
            Mix.shell().error("Failed to encode YAML: #{inspect(reason)}")
            inspect(data, pretty: true)
        end
      _ ->
        # Fallback to basic key-value format
        generate_basic_yaml(data, opts)
    end
  end

  defp generate_basic_yaml(data, _opts) when is_map(data) do
    data
    |> Enum.map(fn {key, value} ->
      "#{key}: #{inspect(value)}"
    end)
    |> Enum.join("\n")
  end

  defp generate_basic_yaml(data, _opts) do
    inspect(data, pretty: true)
  end

  defp generate_html_content(data, opts) do
    title = opts[:title] || "Prismatic Report"

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>#{title}</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .container { max-width: 1200px; margin: 0 auto; }
            .header { border-bottom: 2px solid #333; padding-bottom: 20px; margin-bottom: 30px; }
            .section { margin-bottom: 30px; }
            .data { background: #f5f5f5; padding: 15px; border-radius: 5px; }
            pre { overflow-x: auto; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>#{title}</h1>
                <p>Generated on #{DateTime.utc_now() |> DateTime.to_string()}</p>
            </div>
            <div class="section">
                <h2>Data</h2>
                <div class="data">
                    <pre>#{encode_json(data, pretty: true)}</pre>
                </div>
            </div>
        </div>
    </body>
    </html>
    """
  end

  defp generate_markdown_content(data, opts) do
    title = opts[:title] || "Prismatic Report"

    """
    # #{title}

    Generated on #{DateTime.utc_now() |> DateTime.to_string()}

    ## Data

    ```json
    #{encode_json(data, pretty: true)}
    ```
    """
  end

  defp generate_report_content(data, opts) do
    title = opts[:title] || "Prismatic Report"
    timestamp = DateTime.utc_now() |> DateTime.to_string()

    """
    ═══════════════════════════════════════════════════════════════
     #{title}
    ═══════════════════════════════════════════════════════════════

    Generated: #{timestamp}

    #{format_data_for_report(data, 0)}

    ═══════════════════════════════════════════════════════════════
    """
  end

  defp format_data_for_report(data, indent) when is_map(data) do
    prefix = String.duplicate("  ", indent)

    data
    |> Enum.map(fn {key, value} ->
      case value do
        value when is_map(value) or is_list(value) ->
          "#{prefix}#{key}:\n#{format_data_for_report(value, indent + 1)}"
        _ ->
          "#{prefix}#{key}: #{inspect(value)}"
      end
    end)
    |> Enum.join("\n")
  end

  defp format_data_for_report(data, indent) when is_list(data) do
    prefix = String.duplicate("  ", indent)

    data
    |> Enum.with_index()
    |> Enum.map(fn {item, index} ->
      case item do
        item when is_map(item) or is_list(item) ->
          "#{prefix}#{index + 1}:\n#{format_data_for_report(item, indent + 1)}"
        _ ->
          "#{prefix}• #{inspect(item)}"
      end
    end)
    |> Enum.join("\n")
  end

  defp format_data_for_report(data, indent) do
    prefix = String.duplicate("  ", indent)
    "#{prefix}#{inspect(data)}"
  end

  defp encode_csv(data, _opts) when is_list(data) and length(data) > 0 do
    case hd(data) do
      item when is_map(item) ->
        headers = Map.keys(item)
        header_row = Enum.join(headers, ",")

        data_rows = Enum.map(data, fn row ->
          headers
          |> Enum.map(fn header -> Map.get(row, header, "") end)
          |> Enum.join(",")
        end)

        Enum.join([header_row | data_rows], "\n")
      _ ->
        Enum.join(data, "\n")
    end
  end

  defp encode_csv(data, _opts) when is_map(data) do
    data
    |> Enum.map(fn {key, value} -> "#{key},#{value}" end)
    |> Enum.join("\n")
  end

  defp encode_csv(data, _opts) do
    inspect(data)
  end

  defp encode_xml(data, _opts) do
    # Basic XML encoding - could be enhanced with proper XML library
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<data>#{inspect(data)}</data>"
  end

  defp get_status_icon(status) do
    case status do
      :success -> "✅"
      :warning -> "⚠️"
      :error -> "❌"
      :info -> "ℹ️"
      :debug -> "🔍"
      _ -> "•"
    end
  end

  defp ci_mode? do
    System.get_env("CI") == "true" or
    System.get_env("GITHUB_ACTIONS") == "true" or
    System.get_env("GITLAB_CI") == "true" or
    not (IO.ANSI.enabled?())
  end

  defp verbose_mode? do
    System.get_env("MIX_DEBUG") == "1" or
    System.get_env("VERBOSE") == "1"
  end

  defp display_table_ci(data, columns, headers, _opts) do
    Mix.shell().info(Enum.join(headers, " | "))
    Mix.shell().info(String.duplicate("-", length(headers) * 10))

    Enum.each(data, fn row ->
      values = Enum.map(columns, fn col ->
        to_string(Map.get(row, col, ""))
      end)
      Mix.shell().info(Enum.join(values, " | "))
    end)
  end

  defp display_table_interactive(data, columns, headers, _opts) do
    # Calculate column widths
    col_widths = calculate_column_widths(data, columns, headers)

    # Display header
    header_row = headers
    |> Enum.zip(col_widths)
    |> Enum.map(fn {header, width} -> String.pad_trailing(header, width) end)
    |> Enum.join(" │ ")

    Mix.shell().info([
      :bright, "│ #{header_row} │", :reset
    ])

    # Display separator
    separator = col_widths
    |> Enum.map(fn width -> String.duplicate("─", width) end)
    |> Enum.join("─┼─")

    Mix.shell().info("├─#{separator}─┤")

    # Display data rows
    Enum.each(data, fn row ->
      data_row = columns
      |> Enum.zip(col_widths)
      |> Enum.map(fn {col, width} ->
        value = to_string(Map.get(row, col, ""))
        String.pad_trailing(value, width)
      end)
      |> Enum.join(" │ ")

      Mix.shell().info("│ #{data_row} │")
    end)
  end

  defp calculate_column_widths(data, columns, headers) do
    # Start with header widths
    header_widths = Enum.map(headers, &String.length/1)

    # Calculate max width for each column based on data
    data_widths = columns
    |> Enum.map(fn col ->
      data
      |> Enum.map(fn row ->
        row |> Map.get(col, "") |> to_string() |> String.length()
      end)
      |> Enum.max(fn -> 0 end)
    end)

    # Use the maximum of header and data widths
    header_widths
    |> Enum.zip(data_widths)
    |> Enum.map(fn {header_width, data_width} ->
      max(header_width, data_width)
    end)
  end

  defp display_diff_ci(old_content, new_content) do
    old_lines = String.split(old_content, "\n")
    new_lines = String.split(new_content, "\n")

    Mix.shell().info("--- OLD")
    Mix.shell().info("+++ NEW")

    # Simple line-by-line diff
    max_lines = max(length(old_lines), length(new_lines))

    0..(max_lines - 1)
    |> Enum.each(fn i ->
      old_line = Enum.at(old_lines, i, "")
      new_line = Enum.at(new_lines, i, "")

      cond do
        old_line == new_line ->
          Mix.shell().info("  #{new_line}")
        old_line != "" and new_line == "" ->
          Mix.shell().info("- #{old_line}")
        old_line == "" and new_line != "" ->
          Mix.shell().info("+ #{new_line}")
        true ->
          Mix.shell().info("- #{old_line}")
          Mix.shell().info("+ #{new_line}")
      end
    end)
  end

  defp display_diff_interactive(old_content, new_content) do
    old_lines = String.split(old_content, "\n")
    new_lines = String.split(new_content, "\n")

    Mix.shell().info([
      :red, "--- OLD", :reset
    ])
    Mix.shell().info([
      :green, "+++ NEW", :reset
    ])

    # Simple line-by-line diff with colors
    max_lines = max(length(old_lines), length(new_lines))

    0..(max_lines - 1)
    |> Enum.each(fn i ->
      old_line = Enum.at(old_lines, i, "")
      new_line = Enum.at(new_lines, i, "")

      cond do
        old_line == new_line ->
          Mix.shell().info("  #{new_line}")
        old_line != "" and new_line == "" ->
          Mix.shell().info([
            :red, "- #{old_line}", :reset
          ])
        old_line == "" and new_line != "" ->
          Mix.shell().info([
            :green, "+ #{new_line}", :reset
          ])
        true ->
          Mix.shell().info([
            :red, "- #{old_line}", :reset
          ])
          Mix.shell().info([
            :green, "+ #{new_line}", :reset
          ])
      end
    end)
  end
end
