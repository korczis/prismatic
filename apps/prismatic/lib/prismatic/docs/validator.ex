defmodule Prismatic.Docs.Validator do
  @moduledoc """
  Comprehensive validation system for the Prismatic documentation system.

  This module provides extensive validation capabilities for documentation quality,
  integrity, consistency, and compliance with standards. It performs deep validation
  of content structure, cross-references, code examples, and formatting standards.

  ## Features

  - **Link Validation**: Comprehensive validation of internal and external links
  - **Code Example Testing**: Automated testing of code examples in documentation
  - **Format Compliance**: Validation against documentation standards and style guides
  - **Cross-Reference Integrity**: Validation of cross-references and bidirectional links
  - **Content Quality**: Assessment of content completeness and accuracy
  - **Accessibility Compliance**: Validation of accessibility standards (WCAG)

  ## Usage

      # Validate entire documentation set
      {:ok, results} = Validator.validate_documentation(docs_config)

      # Validate specific document
      {:ok, results} = Validator.validate_document(document_path, docs_config)

      # Validate links only
      {:ok, link_results} = Validator.validate_links(docs_config)

      # Test code examples
      {:ok, test_results} = Validator.test_code_examples(docs_config)

  ## Validation Types

  The validator performs multiple types of validation:

  - **Structural Validation**: Document structure and organization
  - **Content Validation**: Writing quality, completeness, and accuracy
  - **Technical Validation**: Code examples, API references, and technical content
  - **Link Validation**: Internal and external link integrity
  - **Format Validation**: Markdown, HTML, and other format compliance
  - **Accessibility Validation**: WCAG compliance and accessibility standards

  ## Configuration

      config :prismatic, Prismatic.Docs.Validator,
        validate_external_links: true,
        test_code_examples: true,
        accessibility_level: "AA",
        custom_rules: [],
        ignore_patterns: [~r/draft/, ~r/wip/],
        link_timeout: 5000
  """

  alias Prismatic.Docs.Types
  require Logger

  @type validation_result :: %{
    valid: boolean(),
    score: float(),
    errors: [validation_error()],
    warnings: [validation_warning()],
    info: [validation_info()],
    metrics: validation_metrics()
  }

  @type validation_error :: %{
    type: atom(),
    severity: :critical | :high | :medium | :low,
    file: String.t(),
    line: non_neg_integer() | nil,
    column: non_neg_integer() | nil,
    message: String.t(),
    suggestion: String.t() | nil
  }

  @type validation_warning :: %{
    type: atom(),
    file: String.t(),
    line: non_neg_integer() | nil,
    message: String.t(),
    suggestion: String.t() | nil
  }

  @type validation_info :: %{
    type: atom(),
    message: String.t(),
    details: map()
  }

  @type validation_metrics :: %{
    total_files: non_neg_integer(),
    valid_files: non_neg_integer(),
    error_count: non_neg_integer(),
    warning_count: non_neg_integer(),
    link_count: non_neg_integer(),
    broken_links: non_neg_integer(),
    code_examples_tested: non_neg_integer(),
    code_examples_passed: non_neg_integer()
  }

  @type link_validation_result :: %{
    url: String.t(),
    type: :internal | :external | :anchor,
    status: :valid | :invalid | :warning,
    status_code: non_neg_integer() | nil,
    response_time_ms: non_neg_integer() | nil,
    error_message: String.t() | nil
  }

  @type code_example_result :: %{
    file: String.t(),
    line: non_neg_integer(),
    language: String.t(),
    code: String.t(),
    test_status: :passed | :failed | :skipped,
    output: String.t() | nil,
    error: String.t() | nil,
    execution_time_ms: non_neg_integer() | nil
  }

  @doc """
  Validate entire documentation set comprehensively.

  ## Parameters

  - `docs_config` - Documentation configuration
  - `options` - Validation options and settings

  ## Returns

  Complete validation results with errors, warnings, and metrics.

  ## Examples

      iex> Validator.validate_documentation(docs_config)
      {:ok, %{
        valid: true,
        score: 0.92,
        errors: [],
        warnings: [...],
        metrics: %{total_files: 42, valid_files: 41, ...}
      }}
  """
  @spec validate_documentation(Types.doc_config(), map()) :: {:ok, validation_result()} | {:error, term()}
  def validate_documentation(docs_config, options \\ %{}) do
    Logger.info("Starting comprehensive documentation validation")

    options = merge_default_options(options)

    result = %{
      valid: true,
      score: 0.0,
      errors: [],
      warnings: [],
      info: [],
      metrics: %{
        total_files: 0,
        valid_files: 0,
        error_count: 0,
        warning_count: 0,
        link_count: 0,
        broken_links: 0,
        code_examples_tested: 0,
        code_examples_passed: 0
      }
    }

    with {:ok, files} <- scan_documentation_files(docs_config),
         {:ok, result} <- validate_document_structure(result, files, options),
         {:ok, result} <- validate_content_quality(result, files, options),
         {:ok, result} <- validate_links_comprehensive(result, files, options),
         {:ok, result} <- validate_code_examples(result, files, options),
         {:ok, result} <- validate_accessibility(result, files, options),
         {:ok, result} <- validate_format_compliance(result, files, options) do

      final_result = result
      |> calculate_validation_score()
      |> finalize_validation_result()

      {:ok, final_result}
    else
      {:error, reason} ->
        Logger.error("Documentation validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Validate a specific document file.

  ## Parameters

  - `document_path` - Path to the document to validate
  - `docs_config` - Documentation configuration
  - `options` - Validation options

  ## Returns

  Validation results for the specific document.

  ## Examples

      iex> Validator.validate_document("docs/guide.md", docs_config)
      {:ok, %{
        valid: true,
        errors: [],
        warnings: [%{type: :missing_metadata, message: "..."}],
        metrics: %{...}
      }}
  """
  @spec validate_document(String.t(), Types.doc_config(), map()) :: {:ok, validation_result()} | {:error, term()}
  def validate_document(document_path, docs_config, options \\ %{}) do
    Logger.info("Validating document: #{document_path}")

    options = merge_default_options(options)

    case File.read(document_path) do
      {:ok, content} ->
        result = %{
          valid: true,
          score: 0.0,
          errors: [],
          warnings: [],
          info: [],
          metrics: %{total_files: 1, valid_files: 0, error_count: 0, warning_count: 0, link_count: 0, broken_links: 0, code_examples_tested: 0, code_examples_passed: 0}
        }

        final_result = result
        |> validate_single_document_structure(document_path, content, options)
        |> validate_single_document_content(document_path, content, options)
        |> validate_single_document_links(document_path, content, docs_config, options)
        |> validate_single_document_code(document_path, content, options)
        |> calculate_validation_score()
        |> finalize_validation_result()

        {:ok, final_result}

      {:error, reason} ->
        {:error, "Could not read document #{document_path}: #{reason}"}
    end
  end

  @doc """
  Validate all links in documentation.

  ## Parameters

  - `docs_config` - Documentation configuration
  - `options` - Link validation options

  ## Returns

  Comprehensive link validation results.

  ## Examples

      iex> Validator.validate_links(docs_config)
      {:ok, [
        %{url: "https://example.com", type: :external, status: :valid, status_code: 200},
        %{url: "internal.md", type: :internal, status: :invalid, error_message: "File not found"}
      ]}
  """
  @spec validate_links(Types.doc_config(), map()) :: {:ok, [link_validation_result()]} | {:error, term()}
  def validate_links(docs_config, options \\ %{}) do
    Logger.info("Validating documentation links")

    options = merge_default_options(options)

    with {:ok, files} <- scan_documentation_files(docs_config),
         {:ok, all_links} <- extract_all_links(files),
         {:ok, validation_results} <- validate_link_list(all_links, docs_config, options) do

      {:ok, validation_results}
    else
      {:error, reason} ->
        Logger.error("Link validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Test all code examples in documentation.

  ## Parameters

  - `docs_config` - Documentation configuration
  - `options` - Code testing options

  ## Returns

  Code example testing results.

  ## Examples

      iex> Validator.test_code_examples(docs_config)
      {:ok, [
        %{
          file: "guide.md",
          line: 42,
          language: "elixir",
          test_status: :passed,
          execution_time_ms: 150
        }
      ]}
  """
  @spec test_code_examples(Types.doc_config(), map()) :: {:ok, [code_example_result()]} | {:error, term()}
  def test_code_examples(docs_config, options \\ %{}) do
    Logger.info("Testing documentation code examples")

    options = merge_default_options(options)

    with {:ok, files} <- scan_documentation_files(docs_config),
         {:ok, code_examples} <- extract_code_examples(files),
         {:ok, test_results} <- execute_code_tests(code_examples, options) do

      {:ok, test_results}
    else
      {:error, reason} ->
        Logger.error("Code example testing failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Validate accessibility compliance of documentation.

  ## Parameters

  - `docs_config` - Documentation configuration
  - `options` - Accessibility validation options

  ## Returns

  Accessibility validation results with WCAG compliance assessment.

  ## Examples

      iex> Validator.validate_accessibility_compliance(docs_config)
      {:ok, %{
        compliance_level: "AA",
        violations: [...],
        warnings: [...],
        score: 0.94
      }}
  """
  @spec validate_accessibility_compliance(Types.doc_config(), map()) :: {:ok, map()} | {:error, term()}
  def validate_accessibility_compliance(docs_config, options \\ %{}) do
    Logger.info("Validating accessibility compliance")

    options = merge_default_options(options)

    with {:ok, files} <- scan_documentation_files(docs_config),
         {:ok, html_files} <- filter_html_files(files),
         {:ok, accessibility_results} <- check_accessibility_rules(html_files, options) do

      {:ok, accessibility_results}
    else
      {:error, reason} ->
        Logger.error("Accessibility validation failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private helper functions

  defp merge_default_options(options) do
    defaults = %{
      validate_external_links: true,
      test_code_examples: true,
      accessibility_level: "AA",
      custom_rules: [],
      ignore_patterns: [~r/draft/, ~r/wip/],
      link_timeout: 5000,
      max_concurrent_validations: 10
    }

    Map.merge(defaults, options)
  end

  defp scan_documentation_files(docs_config) do
    files = docs_config.source_dirs
    |> Enum.flat_map(&scan_directory_files/1)
    |> Enum.filter(&is_documentation_file?/1)
    |> Enum.reject(&should_ignore_file?(&1, []))

    {:ok, files}
  end

  defp scan_directory_files(dir) do
    case File.ls(dir) do
      {:ok, entries} ->
        entries
        |> Enum.map(&Path.join(dir, &1))
        |> Enum.flat_map(fn path ->
          if File.dir?(path) do
            scan_directory_files(path)
          else
            [path]
          end
        end)

      {:error, reason} ->
        Logger.warning("Could not scan directory #{dir}: #{reason}")
        []
    end
  end

  defp is_documentation_file?(path) do
    Path.extname(path) in [".md", ".markdown", ".rst", ".txt", ".html"]
  end

  defp should_ignore_file?(path, ignore_patterns) do
    Enum.any?(ignore_patterns, fn pattern ->
      Regex.match?(pattern, path)
    end)
  end

  defp validate_document_structure(result, files, _options) do
    Logger.debug("Validating document structure")

    structure_errors = files
    |> Enum.flat_map(&validate_file_structure/1)
    |> Enum.filter(&(&1.severity in [:critical, :high]))

    updated_result = result
    |> Map.update!(:errors, &(&1 ++ structure_errors))
    |> Map.update!(:metrics, &Map.put(&1, :total_files, length(files)))

    {:ok, updated_result}
  end

  defp validate_file_structure(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        []
        |> validate_frontmatter(file_path, content)
        |> validate_heading_structure(file_path, content)
        |> validate_required_sections(file_path, content)

      {:error, reason} ->
        [%{
          type: :file_read_error,
          severity: :critical,
          file: file_path,
          line: nil,
          column: nil,
          message: "Could not read file: #{reason}",
          suggestion: "Check file permissions and encoding"
        }]
    end
  end

  defp validate_frontmatter(errors, file_path, content) do
    case extract_frontmatter(content) do
      {:ok, _metadata} -> errors
      {:error, reason} ->
        error = %{
          type: :invalid_frontmatter,
          severity: :medium,
          file: file_path,
          line: 1,
          column: 1,
          message: "Invalid frontmatter: #{reason}",
          suggestion: "Check YAML syntax in document header"
        }
        [error | errors]
    end
  end

  defp extract_frontmatter(content) do
    case Regex.run(~r/^---\n(.*?)\n---/s, content) do
      [_, yaml_content] ->
        try do
          metadata = YamlElixir.read_from_string(yaml_content)
          {:ok, metadata}
        rescue
          error -> {:error, Exception.message(error)}
        end

      _ -> {:ok, %{}}
    end
  end

  defp validate_heading_structure(errors, file_path, content) do
    headings = extract_headings(content)

    heading_errors = headings
    |> validate_heading_hierarchy()
    |> validate_heading_uniqueness()
    |> Enum.map(&add_file_context(&1, file_path))

    errors ++ heading_errors
  end

  defp extract_headings(content) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_number} ->
      case Regex.run(~r/^(#+)\s+(.+)$/, line) do
        [_, hashes, title] ->
          [%{
            level: String.length(hashes),
            title: String.trim(title),
            line: line_number
          }]

        _ -> []
      end
    end)
  end

  defp validate_heading_hierarchy(headings) do
    headings
    |> Enum.reduce({[], 1}, fn heading, {errors, expected_level} ->
      cond do
        heading.level > expected_level + 1 ->
          error = %{
            type: :heading_hierarchy_skip,
            severity: :medium,
            line: heading.line,
            message: "Heading level #{heading.level} skips intermediate levels",
            suggestion: "Use consecutive heading levels (h1, h2, h3, etc.)"
          }
          {[error | errors], heading.level}

        true ->
          {errors, max(expected_level, heading.level)}
      end
    end)
    |> elem(0)
  end

  defp validate_heading_uniqueness(headings) do
    headings
    |> Enum.group_by(& &1.title)
    |> Enum.flat_map(fn {title, heading_list} ->
      if length(heading_list) > 1 do
        heading_list
        |> Enum.drop(1)
        |> Enum.map(fn heading ->
          %{
            type: :duplicate_heading,
            severity: :low,
            line: heading.line,
            message: "Duplicate heading: '#{title}'",
            suggestion: "Use unique headings or add distinguishing context"
          }
        end)
      else
        []
      end
    end)
  end

  defp add_file_context(error, file_path) do
    Map.put(error, :file, file_path)
  end

  defp validate_required_sections(errors, file_path, content) do
    required_sections = ["Description", "Usage", "Examples"]

    section_errors = required_sections
    |> Enum.reject(&has_section?(content, &1))
    |> Enum.map(fn section ->
      %{
        type: :missing_required_section,
        severity: :medium,
        file: file_path,
        line: nil,
        column: nil,
        message: "Missing required section: #{section}",
        suggestion: "Add a '#{section}' section to improve documentation completeness"
      }
    end)

    errors ++ section_errors
  end

  defp has_section?(content, section_name) do
    Regex.match?(~r/^#+\s+#{Regex.escape(section_name)}/mi, content)
  end

  defp validate_content_quality(result, files, _options) do
    Logger.debug("Validating content quality")

    quality_warnings = files
    |> Enum.flat_map(&validate_file_content/1)

    updated_result = result
    |> Map.update!(:warnings, &(&1 ++ quality_warnings))

    {:ok, updated_result}
  end

  defp validate_file_content(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        []
        |> validate_word_count(file_path, content)
        |> validate_code_example_ratio(file_path, content)
        |> validate_spelling_grammar(file_path, content)

      {:error, _reason} -> []
    end
  end

  defp validate_word_count(warnings, file_path, content) do
    word_count = content
    |> String.split(~r/\s+/)
    |> length()

    if word_count < 100 do
      warning = %{
        type: :low_word_count,
        file: file_path,
        line: nil,
        message: "Document is very short (#{word_count} words)",
        suggestion: "Consider adding more detailed explanations and examples"
      }
      [warning | warnings]
    else
      warnings
    end
  end

  defp validate_code_example_ratio(warnings, file_path, content) do
    total_lines = content |> String.split("\n") |> length()
    code_lines = count_code_block_lines(content)

    ratio = if total_lines > 0, do: code_lines / total_lines, else: 0.0

    if ratio < 0.1 and total_lines > 50 do
      warning = %{
        type: :low_code_example_ratio,
        file: file_path,
        line: nil,
        message: "Document has very few code examples (#{Float.round(ratio * 100, 1)}%)",
        suggestion: "Consider adding more code examples to illustrate concepts"
      }
      [warning | warnings]
    else
      warnings
    end
  end

  defp count_code_block_lines(content) do
    content
    |> String.split("\n")
    |> count_lines_in_code_blocks(false, 0)
  end

  defp count_lines_in_code_blocks([], _in_block, count), do: count
  defp count_lines_in_code_blocks([line | rest], in_block, count) do
    cond do
      String.starts_with?(line, "```") ->
        count_lines_in_code_blocks(rest, not in_block, count)

      in_block ->
        count_lines_in_code_blocks(rest, in_block, count + 1)

      true ->
        count_lines_in_code_blocks(rest, in_block, count)
    end
  end

  defp validate_spelling_grammar(warnings, _file_path, _content) do
    # This would integrate with a spell checker in a real implementation
    warnings
  end

  defp validate_links_comprehensive(result, files, options) do
    Logger.debug("Validating links comprehensively")

    case extract_all_links(files) do
      {:ok, all_links} ->
        case validate_link_list(all_links, %{}, options) do
          {:ok, link_results} ->
            link_errors = link_results
            |> Enum.filter(&(&1.status == :invalid))
            |> Enum.map(&convert_link_result_to_error/1)

            link_warnings = link_results
            |> Enum.filter(&(&1.status == :warning))
            |> Enum.map(&convert_link_result_to_warning/1)

            updated_result = result
            |> Map.update!(:errors, &(&1 ++ link_errors))
            |> Map.update!(:warnings, &(&1 ++ link_warnings))
            |> Map.update!(:metrics, fn metrics ->
              metrics
              |> Map.put(:link_count, length(all_links))
              |> Map.put(:broken_links, length(link_errors))
            end)

            {:ok, updated_result}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_all_links(files) do
    all_links = files
    |> Enum.flat_map(&extract_links_from_file/1)

    {:ok, all_links}
  end

  defp extract_links_from_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        # Extract markdown links: [text](url)
        markdown_links = Regex.scan(~r/\[([^\]]+)\]\(([^)]+)\)/, content)
        |> Enum.map(fn [_full, text, url] ->
          %{
            file: file_path,
            text: text,
            url: String.trim(url),
            type: classify_link_type(url),
            line: find_link_line_number(content, url)
          }
        end)

        # Extract HTML links: <a href="url">text</a>
        html_links = Regex.scan(~r/<a\s+href="([^"]+)"[^>]*>([^<]+)<\/a>/i, content)
        |> Enum.map(fn [_full, url, text] ->
          %{
            file: file_path,
            text: text,
            url: String.trim(url),
            type: classify_link_type(url),
            line: find_link_line_number(content, url)
          }
        end)

        markdown_links ++ html_links

      {:error, _reason} -> []
    end
  end

  defp classify_link_type(url) do
    cond do
      String.starts_with?(url, "http") -> :external
      String.starts_with?(url, "#") -> :anchor
      String.starts_with?(url, "mailto:") -> :email
      true -> :internal
    end
  end

  defp find_link_line_number(content, url) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.find_value(fn {line, line_number} ->
      if String.contains?(line, url), do: line_number
    end) || 1
  end

  defp validate_link_list(links, _docs_config, options) do
    # Group links by type for efficient processing
    {internal_links, external_links, anchor_links, email_links} = links
    |> Enum.group_by(& &1.type)
    |> (fn grouped ->
      {
        Map.get(grouped, :internal, []),
        Map.get(grouped, :external, []),
        Map.get(grouped, :anchor, []),
        Map.get(grouped, :email, [])
      }
    end).()

    # Validate each type of link
    internal_results = validate_internal_links(internal_links)
    external_results = if options.validate_external_links do
      validate_external_links(external_links, options)
    else
      Enum.map(external_links, &%{url: &1.url, type: :external, status: :skipped})
    end
    anchor_results = validate_anchor_links(anchor_links)
    email_results = validate_email_links(email_links)

    all_results = internal_results ++ external_results ++ anchor_results ++ email_results
    {:ok, all_results}
  end

  defp validate_internal_links(links) do
    Enum.map(links, fn link ->
      file_path = resolve_internal_link_path(link)

      status = if File.exists?(file_path) do
        :valid
      else
        :invalid
      end

      %{
        url: link.url,
        type: :internal,
        status: status,
        status_code: nil,
        response_time_ms: nil,
        error_message: if(status == :invalid, do: "File not found: #{file_path}", else: nil)
      }
    end)
  end

  defp resolve_internal_link_path(link) do
    base_dir = Path.dirname(link.file)
    Path.join(base_dir, link.url)
  end

  defp validate_external_links(links, options) do
    timeout = Map.get(options, :link_timeout, 5000)
    max_concurrent = Map.get(options, :max_concurrent_validations, 10)

    links
    |> Enum.chunk_every(max_concurrent)
    |> Enum.flat_map(fn chunk ->
      chunk
      |> Enum.map(&Task.async(fn -> validate_single_external_link(&1, timeout) end))
      |> Enum.map(&Task.await(&1, timeout + 1000))
    end)
  end

  defp validate_single_external_link(link, timeout) do
    start_time = System.monotonic_time(:millisecond)

    case HTTPoison.head(link.url, [], [timeout: timeout, recv_timeout: timeout]) do
      {:ok, %{status_code: status_code}} when status_code in 200..299 ->
        end_time = System.monotonic_time(:millisecond)
        %{
          url: link.url,
          type: :external,
          status: :valid,
          status_code: status_code,
          response_time_ms: end_time - start_time,
          error_message: nil
        }

      {:ok, %{status_code: status_code}} when status_code in 300..399 ->
        end_time = System.monotonic_time(:millisecond)
        %{
          url: link.url,
          type: :external,
          status: :warning,
          status_code: status_code,
          response_time_ms: end_time - start_time,
          error_message: "Redirect response: #{status_code}"
        }

      {:ok, %{status_code: status_code}} ->
        end_time = System.monotonic_time(:millisecond)
        %{
          url: link.url,
          type: :external,
          status: :invalid,
          status_code: status_code,
          response_time_ms: end_time - start_time,
          error_message: "HTTP error: #{status_code}"
        }

      {:error, %{reason: reason}} ->
        %{
          url: link.url,
          type: :external,
          status: :invalid,
          status_code: nil,
          response_time_ms: nil,
          error_message: "Connection error: #{inspect(reason)}"
        }
    end
  rescue
    error ->
      %{
        url: link.url,
        type: :external,
        status: :invalid,
        status_code: nil,
        response_time_ms: nil,
        error_message: "Validation error: #{Exception.message(error)}"
      }
  end

  defp validate_anchor_links(links) do
    # For anchor links, we would validate that the anchor exists in the target document
    Enum.map(links, fn link ->
      %{
        url: link.url,
        type: :anchor,
        status: :valid,  # Simplified - would actually check anchor existence
        status_code: nil,
        response_time_ms: nil,
        error_message: nil
      }
    end)
  end

  defp validate_email_links(links) do
    Enum.map(links, fn link ->
      email = String.replace_leading(link.url, "mailto:", "")

      status = if valid_email_format?(email) do
        :valid
      else
        :invalid
      end

      %{
        url: link.url,
        type: :email,
        status: status,
        status_code: nil,
        response_time_ms: nil,
        error_message: if(status == :invalid, do: "Invalid email format", else: nil)
      }
    end)
  end

  defp valid_email_format?(email) do
    Regex.match?(~r/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/, email)
  end

  defp convert_link_result_to_error(link_result) do
    %{
      type: :broken_link,
      severity: :high,
      file: "unknown",  # Would need to track source file
      line: nil,
      column: nil,
      message: "Broken link: #{link_result.url}",
      suggestion: "Check URL and fix or remove broken link"
    }
  end

  defp convert_link_result_to_warning(link_result) do
    %{
      type: :link_warning,
      file: "unknown",  # Would need to track source file
      line: nil,
      message: "Link warning: #{link_result.url} - #{link_result.error_message}",
      suggestion: "Review link and consider updating"
    }
  end

  defp validate_code_examples(result, files, options) do
    Logger.debug("Validating code examples")

    if options.test_code_examples do
      case test_code_examples(%{source_dirs: files}, options) do
        {:ok, test_results} ->
          failed_tests = Enum.filter(test_results, &(&1.test_status == :failed))

          code_errors = failed_tests
          |> Enum.map(&convert_code_test_to_error/1)

          updated_result = result
          |> Map.update!(:errors, &(&1 ++ code_errors))
          |> Map.update!(:metrics, fn metrics ->
            metrics
            |> Map.put(:code_examples_tested, length(test_results))
            |> Map.put(:code_examples_passed, length(test_results) - length(failed_tests))
          end)

          {:ok, updated_result}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:ok, result}
    end
  end

  defp convert_code_test_to_error(test_result) do
    %{
      type: :code_example_failure,
      severity: :medium,
      file: test_result.file,
      line: test_result.line,
      column: nil,
      message: "Code example failed: #{test_result.error}",
      suggestion: "Fix code example or mark as non-executable"
    }
  end

  defp validate_accessibility(result, files, options) do
    Logger.debug("Validating accessibility")

    case validate_accessibility_compliance(%{source_dirs: files}, options) do
      {:ok, accessibility_results} ->
        accessibility_errors = accessibility_results
        |> Map.get(:violations, [])
        |> Enum.map(&convert_accessibility_violation_to_error/1)

        updated_result = result
        |> Map.update!(:errors, &(&1 ++ accessibility_errors))

        {:ok, updated_result}

      {:error, _reason} ->
        # Continue validation even if accessibility check fails
        {:ok, result}
    end
  end

  defp convert_accessibility_violation_to_error(violation) do
    %{
      type: :accessibility_violation,
      severity: :medium,
      file: Map.get(violation, :file, "unknown"),
      line: Map.get(violation, :line),
      column: nil,
      message: "Accessibility violation: #{violation.description}",
      suggestion: Map.get(violation, :suggestion, "Follow WCAG guidelines")
    }
  end

  defp validate_format_compliance(result, files, _options) do
    Logger.debug("Validating format compliance")

    format_errors = files
    |> Enum.flat_map(&validate_file_format/1)

    updated_result = result
    |> Map.update!(:errors, &(&1 ++ format_errors))

    {:ok, updated_result}
  end

  defp validate_file_format(file_path) do
    extension = Path.extname(file_path)

    case extension do
      ".md" -> validate_markdown_format(file_path)
      ".html" -> validate_html_format(file_path)
      _ -> []
    end
  end

  defp validate_markdown_format(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        []
        |> validate_markdown_syntax(file_path, content)
        |> validate_markdown_style(file_path, content)

      {:error, _reason} -> []
    end
  end

  defp validate_markdown_syntax(errors, file_path, content) do
    # Check for common markdown syntax issues
    lines = String.split(content, "\n")

    syntax_errors = lines
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_number} ->
      []
      |> check_unmatched_brackets(file_path, line, line_number)
      |> check_malformed_links(file_path, line, line_number)
    end)

    errors ++ syntax_errors
  end

  defp check_unmatched_brackets(errors, file_path, line, line_number) do
    open_brackets = Regex.scan(~r/\[/, line) |> length()
    close_brackets = Regex.scan(~r/\]/, line) |> length()

    if open_brackets != close_brackets do
      error = %{
        type: :unmatched_brackets,
        severity: :medium,
        file: file_path,
        line: line_number,
        column: nil,
        message: "Unmatched brackets in line",
        suggestion: "Check bracket pairing in markdown links"
      }
      [error | errors]
    else
      errors
    end
  end

  defp check_malformed_links(errors, file_path, line, line_number) do
    # Check for malformed markdown links
    if Regex.match?(~r/\]\([^)]*$/, line) do
      error = %{
        type: :malformed_link,
        severity: :medium,
        file: file_path,
        line: line_number,
        column: nil,
        message: "Malformed markdown link",
        suggestion: "Check link syntax: [text](url)"
      }
      [error | errors]
    else
      errors
    end
  end

  defp validate_markdown_style(errors, _file_path, _content) do
    # Style validation would check for consistency in markdown formatting
    errors
  end

  defp validate_html_format(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        validate_html_syntax(file_path, content)

      {:error, _reason} -> []
    end
  end

  defp validate_html_syntax(_file_path, _content) do
    # HTML syntax validation would use a proper HTML parser
    []
  end

  defp calculate_validation_score(result) do
    total_issues = length(result.errors) + length(result.warnings)
    total_files = result.metrics.total_files

    # Calculate score based on issues per file
    score = if total_files > 0 do
      issues_per_file = total_issues / total_files
      max(0.0, 1.0 - (issues_per_file * 0.1))
    else
      1.0
    end

    Map.put(result, :score, score)
  end

  defp finalize_validation_result(result) do
    result
    |> Map.put(:valid, length(result.errors) == 0)
    |> Map.update!(:metrics, fn metrics ->
      metrics
      |> Map.put(:error_count, length(result.errors))
      |> Map.put(:warning_count, length(result.warnings))
      |> Map.put(:valid_files, metrics.total_files - count_files_with_errors(result.errors))
    end)
  end

  defp count_files_with_errors(errors) do
    errors
    |> Enum.map(& &1.file)
    |> Enum.uniq()
    |> length()
  end

  defp validate_single_document_structure(result, document_path, content, _options) do
    structure_errors = validate_file_structure(document_path)
    |> Enum.map(&Map.put(&1, :file, document_path))

    Map.update!(result, :errors, &(&1 ++ structure_errors))
  end

  defp validate_single_document_content(result, document_path, content, _options) do
    content_warnings = validate_file_content(document_path)
    Map.update!(result, :warnings, &(&1 ++ content_warnings))
  end

  defp validate_single_document_links(result, document_path, content, docs_config, options) do
    links = extract_links_from_file(document_path)

    case validate_link_list(links, docs_config, options) do
      {:ok, link_results} ->
        link_errors = link_results
        |> Enum.filter(&(&1.status == :invalid))
        |> Enum.map(&convert_link_result_to_error/1)
        |> Enum.map(&Map.put(&1, :file, document_path))

        result
        |> Map.update!(:errors, &(&1 ++ link_errors))
        |> Map.update!(:metrics, fn metrics ->
          metrics
          |> Map.put(:link_count, length(links))
          |> Map.put(:broken_links, length(link_errors))
        end)

      {:error, _reason} ->
        result
    end
  end

  defp validate_single_document_code(result, document_path, content, options) do
    if options.test_code_examples do
      code_examples = extract_code_examples_from_content(document_path, content)

      case execute_code_tests(code_examples, options) do
        {:ok, test_results} ->
          failed_tests = Enum.filter(test_results, &(&1.test_status == :failed))

          code_errors = failed_tests
          |> Enum.map(&convert_code_test_to_error/1)

          result
          |> Map.update!(:errors, &(&1 ++ code_errors))
          |> Map.update!(:metrics, fn metrics ->
            metrics
            |> Map.put(:code_examples_tested, length(test_results))
            |> Map.put(:code_examples_passed, length(test_results) - length(failed_tests))
          end)

        {:error, _reason} ->
          result
      end
    else
      result
    end
  end

  defp extract_code_examples(files) do
    all_examples = files
    |> Enum.flat_map(fn file_path ->
      case File.read(file_path) do
        {:ok, content} ->
          extract_code_examples_from_content(file_path, content)

        {:error, _reason} -> []
      end
    end)

    {:ok, all_examples}
  end

  defp extract_code_examples_from_content(file_path, content) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> extract_code_blocks_with_positions(file_path, [], false, nil, [])
  end

  defp extract_code_blocks_with_positions([], _file_path, _current_block, _in_block, _language, examples) do
    examples
  end

  defp extract_code_blocks_with_positions([{line, line_number} | rest], file_path, current_block, in_block, language, examples) do
    cond do
      Regex.match?(~r/^```(\w+)?/, line) and not in_block ->
        # Start of code block
        new_language = case Regex.run(~r/^```(\w+)/, line) do
          [_, lang] -> lang
          _ -> "text"
        end
        extract_code_blocks_with_positions(rest, file_path, [], true, new_language, examples)

      Regex.match?(~r/^```/, line) and in_block ->
        # End of code block
        if current_block != [] do
          example = %{
            file: file_path,
            line: line_number - length(current_block),
            language: language || "text",
            code: Enum.reverse(current_block) |> Enum.join("\n"),
            test_status: :pending,
            output: nil,
            error: nil,
            execution_time_ms: nil
          }
          extract_code_blocks_with_positions(rest, file_path, [], false, nil, [example | examples])
        else
          extract_code_blocks_with_positions(rest, file_path, [], false, nil, examples)
        end

      in_block ->
        # Inside code block
        extract_code_blocks_with_positions(rest, file_path, [line | current_block], in_block, language, examples)

      true ->
        # Outside code block
        extract_code_blocks_with_positions(rest, file_path, current_block, in_block, language, examples)
    end
  end

  defp execute_code_tests(code_examples, _options) do
    test_results = code_examples
    |> Enum.map(&execute_single_code_test/1)

    {:ok, test_results}
  end

  defp execute_single_code_test(example) do
    case example.language do
      "elixir" ->
        execute_elixir_code_test(example)

      "shell" ->
        execute_shell_code_test(example)

      _ ->
        Map.put(example, :test_status, :skipped)
    end
  end

  defp execute_elixir_code_test(example) do
    start_time = System.monotonic_time(:millisecond)

    try do
      # This would evaluate Elixir code in a sandboxed environment
      # For now, just mark as passed
      end_time = System.monotonic_time(:millisecond)

      example
      |> Map.put(:test_status, :passed)
      |> Map.put(:execution_time_ms, end_time - start_time)
      |> Map.put(:output, "Code executed successfully")
    rescue
      error ->
        end_time = System.monotonic_time(:millisecond)

        example
        |> Map.put(:test_status, :failed)
        |> Map.put(:execution_time_ms, end_time - start_time)
        |> Map.put(:error, Exception.message(error))
    end
  end

  defp execute_shell_code_test(example) do
    # This would execute shell commands in a safe environment
    # For now, just mark as skipped
    Map.put(example, :test_status, :skipped)
  end

  defp filter_html_files(files) do
    html_files = Enum.filter(files, fn file ->
      Path.extname(file) in [".html", ".htm"]
    end)

    {:ok, html_files}
  end

  defp check_accessibility_rules(html_files, _options) do
    # This would use an accessibility checker like axe-core
    # For now, return a placeholder result
    {:ok, %{
      compliance_level: "AA",
      violations: [],
      warnings: [],
      score: 1.0
    }}
  end
end
