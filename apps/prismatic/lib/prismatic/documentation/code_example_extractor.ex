defmodule Prismatic.Documentation.CodeExampleExtractor do
  @moduledoc """
  Code example extraction and transformation framework.

  This module provides comprehensive code example parsing, categorization,
  and transformation from documentation to executable implementations.

  ## Features

  - Extract code blocks from markdown documentation
  - Distinguish between conceptual examples and production-ready code
  - Transform documentation code to executable implementations
  - Validate syntactic correctness of extracted code
  - Categorize examples by language and purpose
  """

  require Logger

  @inline_code_pattern ~r/`([^`]+)`/
  @file_reference_pattern ~r/(?:file|filename|path):\s*([^\s\n]+)/i

  @doc """
  Extract all code examples from the specified documentation directory.

  Returns categorized code examples with metadata and transformation information.
  """
  def extract_all_examples(docs_path) do
    Logger.info("Starting code example extraction from #{docs_path}")

    doc_files = find_documentation_files(docs_path)
    Logger.info("Found #{length(doc_files)} documentation files")

    examples =
      doc_files
      |> Enum.flat_map(&extract_examples_from_file/1)
      |> Enum.with_index(1)
      |> Enum.map(fn {example, index} -> Map.put(example, :id, index) end)

    %{
      summary: generate_summary(examples),
      examples: examples,
      categorization: categorize_examples(examples),
      transformations: generate_transformations(examples),
      validation: validate_examples(examples),
      extraction_metadata: %{
        extraction_date: DateTime.utc_now(),
        total_examples: length(examples),
        docs_path: docs_path,
        extractor_version: "1.0.0"
      }
    }
  end

  @doc """
  Extract code examples from a single documentation file.

  Returns a list of code examples with metadata.
  """
  def extract_examples_from_file(file_path) do
    Logger.debug("Extracting code examples from #{file_path}")

    content = File.read!(file_path)

    code_blocks = extract_code_blocks(content)
    inline_code = extract_inline_code(content)

    (code_blocks ++ inline_code)
    |> Enum.map(fn example ->
      example
      |> Map.put(:source_file, file_path)
      |> Map.put(:extraction_context, extract_context_around_code(content, example))
      |> Map.put(:metadata, generate_example_metadata(example, content))
    end)
  end

  # Private functions for code extraction

  defp find_documentation_files(docs_path) do
    docs_path
    |> Path.join("**/*.md")
    |> Path.wildcard()
    |> Enum.sort()
  end

  defp extract_code_blocks(content) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> extract_code_blocks_with_line_numbers([])
  end

  defp extract_code_blocks_with_line_numbers([], acc), do: Enum.reverse(acc)

  defp extract_code_blocks_with_line_numbers([{line, line_num} | rest], acc) do
    case String.match?(line, ~r/^```/) do
      true ->
        {code_block, remaining_lines} = extract_single_code_block([{line, line_num} | rest])
        extract_code_blocks_with_line_numbers(remaining_lines, [code_block | acc])
      false ->
        extract_code_blocks_with_line_numbers(rest, acc)
    end
  end

  defp extract_single_code_block([{opening_line, start_line} | lines]) do
    language = extract_language_from_fence(opening_line)

    {code_lines, remaining_lines} =
      lines
      |> Enum.split_while(fn {line, _} -> not String.match?(line, ~r/^```\s*$/) end)

    # Remove the closing fence from remaining lines
    remaining_lines =
      case remaining_lines do
        [{_closing_fence, _} | rest] -> rest
        _ -> remaining_lines
      end

    code_content =
      code_lines
      |> Enum.map(fn {line, _} -> line end)
      |> Enum.join("\n")

    end_line = start_line + length(code_lines) + 1

    code_block = %{
      type: :code_block,
      language: language,
      content: code_content,
      start_line: start_line,
      end_line: end_line,
      raw_content: opening_line <> "\n" <> code_content <> "\n```"
    }

    {code_block, remaining_lines}
  end

  defp extract_language_from_fence(fence_line) do
    case Regex.run(~r/^```([a-zA-Z0-9+-]*)\s*/, fence_line) do
      [_, ""] -> "text"
      [_, lang] -> String.downcase(lang)
      _ -> "text"
    end
  end

  defp extract_inline_code(content) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_num} ->
      extract_inline_code_from_line(line, line_num)
    end)
  end

  defp extract_inline_code_from_line(line, line_num) do
    Regex.scan(@inline_code_pattern, line, return: :index)
    |> Enum.map(fn [{start_pos, _length}, {code_start, code_length}] ->
      code_content = String.slice(line, code_start, code_length)

      %{
        type: :inline_code,
        language: infer_language_from_inline_code(code_content),
        content: code_content,
        start_line: line_num,
        end_line: line_num,
        start_pos: start_pos,
        raw_content: "`#{code_content}`",
        line_content: line
      }
    end)
  end

  defp infer_language_from_inline_code(code) do
    cond do
      Regex.match?(~r/^[A-Z][a-zA-Z0-9._]*$/, code) -> "elixir_module"
      Regex.match?(~r/^[a-z_][a-z_0-9]*$/, code) -> "identifier"
      Regex.match?(~r/\.(ex|exs)$/, code) -> "elixir_file"
      Regex.match?(~r/^mix\s+/, code) -> "mix_command"
      Regex.match?(~r/^git\s+/, code) -> "git_command"
      Regex.match?(~r/^\$\s+/, code) -> "shell_command"
      String.contains?(code, "/") -> "path"
      true -> "text"
    end
  end

  defp extract_context_around_code(content, example) do
    lines = String.split(content, "\n")
    start_line = example.start_line

    # Extract context lines before and after the code
    context_before =
      lines
      |> Enum.slice(max(0, start_line - 4), 3)
      |> Enum.join("\n")

    context_after =
      lines
      |> Enum.slice(example.end_line, 3)
      |> Enum.join("\n")

    %{
      before: String.trim(context_before),
      after: String.trim(context_after),
      section_heading: find_nearest_heading(lines, start_line)
    }
  end

  defp find_nearest_heading(lines, target_line) do
    lines
    |> Enum.slice(0, target_line - 1)
    |> Enum.reverse()
    |> Enum.find(&String.match?(&1, ~r/^\#{1,6}\s+/))
    |> case do
      nil -> nil
      heading -> String.trim(String.replace(heading, ~r/^\#{1,6}\s*/, ""))
    end
  end

  defp generate_example_metadata(example, content) do
    %{
      complexity_score: calculate_complexity_score(example),
      is_executable: is_executable_code?(example),
      is_conceptual: is_conceptual_example?(example, content),
      has_file_reference: has_file_reference?(example),
      requires_transformation: requires_transformation?(example),
      estimated_lines: count_lines(example.content),
      contains_placeholders: contains_placeholders?(example.content),
      validation_status: :pending
    }
  end

  defp calculate_complexity_score(example) do
    base_score = count_lines(example.content)

    # Add complexity for different factors
    language_bonus = case example.language do
      "elixir" -> 5
      "javascript" -> 3
      "sql" -> 4
      "bash" -> 2
      _ -> 1
    end

    structure_bonus = cond do
      String.contains?(example.content, ["defmodule", "def "]) -> 10
      String.contains?(example.content, ["function", "class", "struct"]) -> 8
      String.contains?(example.content, ["if", "case", "for", "while"]) -> 5
      true -> 0
    end

    base_score + language_bonus + structure_bonus
  end

  defp is_executable_code?(example) do
    case example.language do
      "elixir" ->
        String.contains?(example.content, ["def", "defmodule", "defp"]) or
        (String.trim(example.content) |> String.starts_with?(~w[IO. Enum. String. Map. List.]))
      "javascript" ->
        String.contains?(example.content, ["function", "const", "let", "var"]) or
        String.contains?(example.content, "=>")
      "sql" ->
        String.match?(example.content, ~r/^\s*(SELECT|INSERT|UPDATE|DELETE|CREATE|ALTER)/i)
      "bash" ->
        String.starts_with?(String.trim(example.content), ["$", "mix", "npm", "git"])
      _ -> false
    end
  end

  defp is_conceptual_example?(example, _content) do
    context_keywords = [
      "example", "for example", "like this", "such as", "conceptual",
      "pseudo", "simplified", "illustration", "demonstrates"
    ]

    context_text = example.extraction_context.before <> " " <> example.extraction_context.after

    Enum.any?(context_keywords, &String.contains?(String.downcase(context_text), &1))
  end

  defp has_file_reference?(example) do
    Regex.match?(@file_reference_pattern, example.raw_content) or
    String.contains?(example.content, [".ex", ".exs", ".md", ".json", ".yml"])
  end

  defp requires_transformation?(example) do
    example.metadata.is_conceptual and
    example.metadata.is_executable and
    example.metadata.contains_placeholders
  end

  defp count_lines(content) do
    content
    |> String.split("\n")
    |> length()
  end

  defp contains_placeholders?(content) do
    placeholder_patterns = [
      ~r/\{\{[^}]+\}\}/,     # {{placeholder}}
      ~r/\[[^\]]*\]/,       # [placeholder]
      ~r/<[^>]*>/,          # <placeholder>
      ~r/YOUR_[A-Z_]+/,     # YOUR_VALUE
      ~r/\.\.\./            # ...
    ]

    Enum.any?(placeholder_patterns, &Regex.match?(&1, content))
  end

  defp generate_summary(examples) do
    total_count = length(examples)

    %{
      total_examples: total_count,
      by_type: count_by_type(examples),
      by_language: count_by_language(examples),
      executable_examples: count_executable_examples(examples),
      conceptual_examples: count_conceptual_examples(examples),
      transformation_candidates: count_transformation_candidates(examples),
      average_complexity: calculate_average_complexity(examples)
    }
  end

  defp count_by_type(examples) do
    examples
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, examples} -> {type, length(examples)} end)
    |> Enum.into(%{})
  end

  defp count_by_language(examples) do
    examples
    |> Enum.group_by(& &1.language)
    |> Enum.map(fn {lang, examples} -> {lang, length(examples)} end)
    |> Enum.into(%{})
  end

  defp count_executable_examples(examples) do
    Enum.count(examples, & &1.metadata.is_executable)
  end

  defp count_conceptual_examples(examples) do
    Enum.count(examples, & &1.metadata.is_conceptual)
  end

  defp count_transformation_candidates(examples) do
    Enum.count(examples, & &1.metadata.requires_transformation)
  end

  defp calculate_average_complexity(examples) do
    if length(examples) > 0 do
      total_complexity = Enum.sum(Enum.map(examples, & &1.metadata.complexity_score))
      round(total_complexity / length(examples))
    else
      0
    end
  end

  defp categorize_examples(examples) do
    %{
      by_language: Enum.group_by(examples, & &1.language),
      by_type: Enum.group_by(examples, & &1.type),
      by_complexity: categorize_by_complexity(examples),
      by_purpose: categorize_by_purpose(examples),
      executable: Enum.filter(examples, & &1.metadata.is_executable),
      conceptual: Enum.filter(examples, & &1.metadata.is_conceptual),
      transformation_ready: Enum.filter(examples, & &1.metadata.requires_transformation)
    }
  end

  defp categorize_by_complexity(examples) do
    %{
      low: Enum.filter(examples, & &1.metadata.complexity_score < 10),
      medium: Enum.filter(examples, & &1.metadata.complexity_score >= 10 and &1.metadata.complexity_score < 25),
      high: Enum.filter(examples, & &1.metadata.complexity_score >= 25)
    }
  end

  defp categorize_by_purpose(examples) do
    examples
    |> Enum.group_by(&infer_purpose/1)
  end

  defp infer_purpose(example) do
    content = String.downcase(example.content)
    context = String.downcase(example.extraction_context.section_heading || "")

    cond do
      String.contains?(content, ["test", "assert", "expect"]) -> :testing
      String.contains?(content, ["config", "configuration", "setup"]) -> :configuration
      String.contains?(content, ["def ", "defmodule", "function"]) -> :implementation
      String.contains?(context, ["install", "setup", "getting started"]) -> :setup
      String.contains?(context, ["example", "usage", "how to"]) -> :usage
      String.contains?(content, ["mix", "npm", "git", "$"]) -> :command
      true -> :general
    end
  end

  defp generate_transformations(examples) do
    transformation_candidates = Enum.filter(examples, & &1.metadata.requires_transformation)

    Enum.map(transformation_candidates, &generate_single_transformation/1)
  end

  defp generate_single_transformation(example) do
    %{
      example_id: example.id,
      original_content: example.content,
      transformed_content: transform_to_executable(example),
      transformation_type: determine_transformation_type(example),
      confidence_score: calculate_transformation_confidence(example),
      required_dependencies: extract_required_dependencies(example),
      transformation_notes: generate_transformation_notes(example)
    }
  end

  defp transform_to_executable(example) do
    content = example.content

    # Apply transformation rules based on language and patterns
    case example.language do
      "elixir" -> transform_elixir_code(content)
      "javascript" -> transform_javascript_code(content)
      "sql" -> transform_sql_code(content)
      "bash" -> transform_bash_code(content)
      _ -> content
    end
  end

  defp transform_elixir_code(content) do
    content
    |> replace_placeholders()
    |> ensure_module_structure()
    |> add_missing_imports()
  end

  defp transform_javascript_code(content) do
    content
    |> replace_placeholders()
    |> ensure_proper_syntax()
  end

  defp transform_sql_code(content) do
    content
    |> replace_placeholders()
    |> ensure_table_references()
  end

  defp transform_bash_code(content) do
    content
    |> replace_placeholders()
    |> ensure_executable_commands()
  end

  defp replace_placeholders(content) do
    content
    |> String.replace(~r/\{\{([^}]+)\}\}/, fn _, placeholder ->
      generate_placeholder_value(placeholder)
    end)
    |> String.replace(~r/YOUR_([A-Z_]+)/, fn _, var ->
      generate_variable_value(var)
    end)
  end

  defp generate_placeholder_value(placeholder) do
    case String.downcase(placeholder) do
      "name" -> "example_name"
      "id" -> "1"
      "email" -> "user@example.com"
      "password" -> "secure_password"
      "url" -> "https://example.com"
      _ -> "example_value"
    end
  end

  defp generate_variable_value(var) do
    case String.downcase(var) do
      "api_key" -> "your_api_key_here"
      "database_url" -> "postgres://localhost/example_db"
      "port" -> "4000"
      _ -> "your_#{String.downcase(var)}_here"
    end
  end

  defp ensure_module_structure(content) do
    if String.contains?(content, "def ") and not String.contains?(content, "defmodule") do
      """
      defmodule ExampleModule do
        #{content}
      end
      """
    else
      content
    end
  end

  defp add_missing_imports(content) do
    # Add common imports if they seem to be needed
    imports = []

    imports = if String.contains?(content, "Logger.") and not String.contains?(content, "require Logger") do
      ["require Logger" | imports]
    else
      imports
    end

    if length(imports) > 0 do
      Enum.join(imports, "\n") <> "\n\n" <> content
    else
      content
    end
  end

  defp ensure_proper_syntax(content) do
    # Basic JavaScript syntax fixes
    content
    |> String.replace(~r/;?\s*$/, ";")
  end

  defp ensure_table_references(content) do
    # Replace generic table names with example ones
    content
    |> String.replace(~r/YOUR_TABLE/i, "example_table")
    |> String.replace(~r/TABLE_NAME/i, "users")
  end

  defp ensure_executable_commands(content) do
    # Ensure bash commands are properly formatted
    content
    |> String.replace(~r/^\s*/, "$ ", global: false) # Add $ prefix if missing
  end

  defp determine_transformation_type(example) do
    cond do
      example.metadata.contains_placeholders -> :placeholder_replacement
      example.metadata.is_conceptual -> :conceptual_to_concrete
      String.contains?(example.content, "...") -> :completion
      true -> :cleanup
    end
  end

  defp calculate_transformation_confidence(example) do
    base_score = 50

    # Increase confidence for well-structured code
    structure_bonus = if example.metadata.is_executable, do: 30, else: 0

    # Decrease confidence for complex placeholders
    placeholder_penalty = if example.metadata.contains_placeholders, do: -20, else: 0

    # Language-specific adjustments
    language_bonus = case example.language do
      "elixir" -> 10
      "sql" -> 15
      "bash" -> 5
      _ -> 0
    end

    max(0, min(100, base_score + structure_bonus + placeholder_penalty + language_bonus))
  end

  defp extract_required_dependencies(example) do
    content = example.content

    # Extract dependencies based on language
    case example.language do
      "elixir" -> extract_elixir_dependencies(content)
      "javascript" -> extract_javascript_dependencies(content)
      _ -> []
    end
  end

  defp extract_elixir_dependencies(content) do
    deps = []

    deps = if String.contains?(content, "Phoenix."), do: [:phoenix | deps], else: deps
    deps = if String.contains?(content, "Ecto."), do: [:ecto | deps], else: deps
    deps = if String.contains?(content, "Jason."), do: [:jason | deps], else: deps
    deps = if String.contains?(content, "HTTPoison."), do: [:httpoison | deps], else: deps

    Enum.uniq(deps)
  end

  defp extract_javascript_dependencies(content) do
    # Simple pattern matching for common libraries
    deps = []

    deps = if String.contains?(content, "axios"), do: ["axios" | deps], else: deps
    deps = if String.contains?(content, "lodash"), do: ["lodash" | deps], else: deps
    deps = if String.contains?(content, "react"), do: ["react" | deps], else: deps

    Enum.uniq(deps)
  end

  defp generate_transformation_notes(example) do
    notes = []

    notes = if example.metadata.contains_placeholders do
      ["Replace placeholders with actual values" | notes]
    else
      notes
    end

    notes = if example.metadata.is_conceptual do
      ["This is a conceptual example - may need additional implementation details" | notes]
    else
      notes
    end

    notes = if length(extract_required_dependencies(example)) > 0 do
      ["Add required dependencies to your project" | notes]
    else
      notes
    end

    Enum.reverse(notes)
  end

  defp validate_examples(examples) do
    executable_examples = Enum.filter(examples, & &1.metadata.is_executable)

    validation_results = Enum.map(executable_examples, &validate_single_example/1)

    %{
      total_validated: length(validation_results),
      syntax_valid: Enum.count(validation_results, & &1.syntax_valid),
      syntax_errors: Enum.reject(validation_results, & &1.syntax_valid),
      validation_summary: generate_validation_summary(validation_results)
    }
  end

  defp validate_single_example(example) do
    case example.language do
      "elixir" -> validate_elixir_syntax(example)
      "javascript" -> validate_javascript_syntax(example)
      "sql" -> validate_sql_syntax(example)
      _ -> %{example_id: example.id, syntax_valid: true, errors: []}
    end
  end

  defp validate_elixir_syntax(example) do
    try do
      Code.string_to_quoted!(example.content)
      %{example_id: example.id, syntax_valid: true, errors: []}
    rescue
      e ->
        %{
          example_id: example.id,
          syntax_valid: false,
          errors: [%{type: :syntax_error, message: Exception.message(e)}]
        }
    end
  end

  defp validate_javascript_syntax(_example) do
    # Basic validation - would need a JavaScript parser for real validation
    %{example_id: nil, syntax_valid: true, errors: []}
  end

  defp validate_sql_syntax(_example) do
    # Basic validation - would need a SQL parser for real validation
    %{example_id: nil, syntax_valid: true, errors: []}
  end

  defp generate_validation_summary(validation_results) do
    total = length(validation_results)
    valid = Enum.count(validation_results, & &1.syntax_valid)

    %{
      success_rate: if(total > 0, do: round((valid / total) * 100), else: 0),
      common_errors: extract_common_errors(validation_results)
    }
  end

  defp extract_common_errors(validation_results) do
    validation_results
    |> Enum.reject(& &1.syntax_valid)
    |> Enum.flat_map(& &1.errors)
    |> Enum.group_by(& &1.type)
    |> Enum.map(fn {type, errors} -> {type, length(errors)} end)
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
  end
end
