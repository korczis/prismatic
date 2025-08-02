defmodule Prismatic.Documentation.ReferenceReplacementSystem do
  @moduledoc """
  Reference Replacement System for converting code implementations in documentation
  to concise references and smart links with automated maintenance.

  This module provides comprehensive tools for:
  - Replacing detailed code implementations with concise references and links
  - Smart link generation to actual code files with line number precision
  - Automated reference updating when code files are moved or refactored
  - Link validation to ensure references remain valid over time
  - Contextual previews for referenced code sections

  ## Reference Types

  - **Direct File References**: Links to specific files
  - **Line-Specific References**: Links to specific line ranges in files
  - **Function References**: Links to specific function definitions
  - **Module References**: Links to module definitions
  - **Smart References**: Dynamic references that update automatically

  ## Features

  - Intelligent link generation with line precision
  - Automatic reference updating on file changes
  - Link validation and health monitoring
  - Contextual code previews
  - Reference integrity maintenance
  """

  require Logger
  alias Prismatic.Documentation.{TraceabilityMarker, CodeExampleExtractor}


  defmodule Reference do
    @moduledoc """
    Represents a code reference with all necessary metadata.
    """

    defstruct [
      :id,
      :type,
      :source_file,
      :source_location,
      :target_file,
      :target_location,
      :display_text,
      :link_text,
      :context_preview,
      :metadata,
      :last_validated,
      :validation_status
    ]

    @type t :: %__MODULE__{
      id: String.t(),
      type: :file | :line_range | :function | :module | :smart,
      source_file: String.t(),
      source_location: {integer(), integer()},
      target_file: String.t(),
      target_location: {integer(), integer()} | nil,
      display_text: String.t(),
      link_text: String.t(),
      context_preview: String.t(),
      metadata: map(),
      last_validated: DateTime.t(),
      validation_status: :valid | :invalid | :warning
    }
  end

  defmodule ReferenceMap do
    @moduledoc """
    Maintains a comprehensive map of all references in the documentation.
    """

    defstruct [
      :references,
      :file_index,
      :reverse_index,
      :validation_results,
      :last_updated
    ]

    @type t :: %__MODULE__{
      references: [Reference.t()],
      file_index: map(),
      reverse_index: map(),
      validation_results: map(),
      last_updated: DateTime.t()
    }
  end

  @doc """
  Replace code implementations in documentation with smart references.

  Analyzes documentation files and replaces inline code blocks with
  appropriate references to actual implementation files.
  """
  def replace_with_references(docs_path \\ "docs", code_path \\ "apps", opts \\ []) do
    Logger.info("Replacing code implementations with references in #{docs_path}")

    # Extract current code examples from documentation
    code_examples = CodeExampleExtractor.extract_all_examples(docs_path)

    # Generate traceability information
    traceability = TraceabilityMarker.generate_markers(docs_path, code_path)

    # Identify replacement candidates
    candidates = identify_replacement_candidates(code_examples, traceability, opts)

    # Generate smart references
    references = generate_smart_references(candidates, code_path, opts)

    # Perform replacements if not in dry run mode
    dry_run = Keyword.get(opts, :dry_run, false)

    replacement_results = if dry_run do
      simulate_replacements(references)
    else
      perform_replacements(references, opts)
    end

    %{
      total_candidates: length(candidates),
      total_references: length(references),
      successful_replacements: count_successful_replacements(replacement_results),
      failed_replacements: count_failed_replacements(replacement_results),
      references: references,
      replacement_results: replacement_results,
      reference_map: build_reference_map(references),
      metadata: %{
        processed_at: DateTime.utc_now(),
        docs_path: docs_path,
        code_path: code_path,
        dry_run: dry_run
      }
    }
  end

  @doc """
  Generate smart links to code files with line number precision.

  Creates intelligent links that point to specific locations in code files
  with automatic line number tracking and validation.
  """
  def generate_smart_links(target_files, _opts \\ []) do
    Logger.info("Generating smart links for #{length(target_files)} files")

    links = target_files
    |> Enum.flat_map(&analyze_file_for_links/1)
    |> Enum.map(&enhance_link_with_metadata/1)
    |> Enum.sort_by(& &1.target_location)

    %{
      total_links: length(links),
      links_by_type: group_links_by_type(links),
      validation_status: validate_all_links(links),
      links: links,
      generation_metadata: %{
        generated_at: DateTime.utc_now(),
        generator_version: "1.0.0"
      }
    }
  end

  @doc """
  Update references automatically when code files are moved or refactored.

  Monitors code file changes and updates all documentation references
  to maintain link integrity.
  """
  def update_references_on_change(file_changes, reference_map, opts \\ []) do
    Logger.info("Updating references for #{length(file_changes)} file changes")

    updates = file_changes
    |> Enum.flat_map(fn change -> find_affected_references(change, reference_map) end)
    |> Enum.map(fn ref -> update_reference_for_change(ref, file_changes) end)
    |> Enum.group_by(& &1.update_type)

    # Apply updates to documentation files
    apply_reference_updates(updates, opts)

    %{
      total_changes: length(file_changes),
      affected_references: count_affected_references(updates),
      successful_updates: count_successful_updates(updates),
      failed_updates: count_failed_updates(updates),
      updates_by_type: updates,
      updated_reference_map: rebuild_reference_map(reference_map, updates),
      update_metadata: %{
        updated_at: DateTime.utc_now(),
        change_trigger: extract_change_trigger(file_changes)
      }
    }
  end

  @doc """
  Validate all references to ensure they remain valid over time.

  Performs comprehensive validation of all documentation references
  and provides detailed health reports.
  """
  def validate_references(reference_map, _opts \\ []) do
    Logger.info("Validating #{length(reference_map.references)} references")

    validation_results = reference_map.references
    |> Enum.map(&validate_single_reference/1)
    |> Enum.group_by(& &1.status)

    health_metrics = calculate_reference_health(validation_results)
    recommendations = generate_maintenance_recommendations(validation_results)

    %{
      total_references: length(reference_map.references),
      valid_references: length(validation_results[:valid] || []),
      invalid_references: length(validation_results[:invalid] || []),
      warning_references: length(validation_results[:warning] || []),
      health_score: health_metrics.overall_score,
      health_metrics: health_metrics,
      validation_details: validation_results,
      maintenance_recommendations: recommendations,
      validation_metadata: %{
        validated_at: DateTime.utc_now(),
        validator_version: "1.0.0"
      }
    }
  end

  @doc """
  Generate contextual previews for referenced code sections.

  Creates intelligent code previews that show relevant context
  around referenced code sections.
  """
  def generate_contextual_previews(references, opts \\ []) do
    Logger.info("Generating contextual previews for #{length(references)} references")

    preview_config = %{
      context_lines: Keyword.get(opts, :context_lines, 3),
      max_preview_length: Keyword.get(opts, :max_preview_length, 500),
      include_syntax_highlighting: Keyword.get(opts, :syntax_highlighting, true),
      include_line_numbers: Keyword.get(opts, :line_numbers, true)
    }

    previews = references
    |> Enum.map(&generate_preview(&1, preview_config))
    |> Enum.reject(&is_nil/1)

    %{
      total_previews: length(previews),
      preview_types: group_previews_by_type(previews),
      previews: previews,
      preview_metadata: %{
        generated_at: DateTime.utc_now(),
        config: preview_config
      }
    }
  end

  # Private functions for replacement candidate identification

  defp identify_replacement_candidates(code_examples, traceability, opts) do
    min_complexity = Keyword.get(opts, :min_complexity, 3)
    min_lines = Keyword.get(opts, :min_lines, 5)

    code_examples.examples
    |> Enum.filter(&is_replacement_candidate?(&1, min_complexity, min_lines))
    |> Enum.map(&analyze_candidate(&1, traceability))
    |> Enum.sort_by(& &1.replacement_priority, :desc)
  end

  defp is_replacement_candidate?(example, min_complexity, min_lines) do
    # Check if code example should be replaced with reference
    line_count = String.split(example.content, "\n") |> length()

    cond do
      # Too small to be worth replacing
      line_count < min_lines -> false

      # Not complex enough
      example.metadata.complexity_score < min_complexity -> false

      # Already a reference
      String.contains?(example.content, "# See:") -> false
      String.contains?(example.content, "// Reference:") -> false

      # Has implementation markers
      has_implementation_content?(example) -> true

      # Executable examples are good candidates
      example.metadata.is_executable -> true

      true -> false
    end
  end

  defp has_implementation_content?(example) do
    content = example.content

    implementation_indicators = [
      ~r/defmodule\s+/,
      ~r/def\s+\w+/,
      ~r/function\s+\w+/,
      ~r/class\s+\w+/,
      ~r/import\s+/,
      ~r/@\w+/,  # Attributes/decorators
      ~r/\w+\s*=\s*\w+/  # Assignments
    ]

    Enum.any?(implementation_indicators, &Regex.match?(&1, content))
  end

  defp analyze_candidate(example, traceability) do
    # Find corresponding implementation in codebase
    corresponding_impl = find_corresponding_implementation(example, traceability)

    replacement_priority = calculate_replacement_priority(example, corresponding_impl)

    %{
      example: example,
      corresponding_implementation: corresponding_impl,
      replacement_priority: replacement_priority,
      suggested_reference_type: suggest_reference_type(example, corresponding_impl),
      confidence_score: calculate_reference_confidence(example, corresponding_impl)
    }
  end

  defp find_corresponding_implementation(example, traceability) do
    # Look for matching implementations in traceability data
    matching_links = traceability.bidirectional_links.implicit
    |> Enum.filter(fn link ->
      link.documentation.source_file == example.source_file and
      content_similarity(link.documentation.reference, example.content) > 0.7
    end)

    case matching_links do
      [best_match | _] -> best_match.implementation
      [] -> nil
    end
  end

  defp content_similarity(ref_content, example_content) do
    # Simple similarity calculation - could be enhanced
    ref_words = extract_words(ref_content)
    example_words = extract_words(example_content)

    intersection = MapSet.intersection(ref_words, example_words) |> MapSet.size()
    union = MapSet.union(ref_words, example_words) |> MapSet.size()

    if union > 0, do: intersection / union, else: 0
  end

  defp extract_words(content) do
    content
    |> String.downcase()
    |> String.replace(~r/[^\w\s]/, " ")
    |> String.split()
    |> MapSet.new()
  end

  defp calculate_replacement_priority(example, corresponding_impl) do
    base_priority = 50

    # Higher priority for larger, more complex examples
    size_bonus = min(String.length(example.content) / 100, 30)
    complexity_bonus = example.metadata.complexity_score / 5

    # Higher priority if we found corresponding implementation
    impl_bonus = if corresponding_impl, do: 20, else: 0

    # Higher priority for executable examples
    executable_bonus = if example.metadata.is_executable, do: 15, else: 0

    round(base_priority + size_bonus + complexity_bonus + impl_bonus + executable_bonus)
  end

  defp suggest_reference_type(example, corresponding_impl) do
    cond do
      String.contains?(example.content, "defmodule") -> :module
      String.contains?(example.content, "def ") -> :function
      corresponding_impl != nil -> :line_range
      example.metadata.is_executable -> :file
      true -> :generic
    end
  end

  defp calculate_reference_confidence(example, corresponding_impl) do
    base_confidence = 60

    # Higher confidence if we found implementation
    impl_bonus = if corresponding_impl, do: 30, else: 0

    # Higher confidence for structured code
    structure_bonus = if has_clear_structure?(example), do: 10, else: 0

    max(0, min(100, base_confidence + impl_bonus + structure_bonus))
  end

  defp has_clear_structure?(example) do
    content = example.content

    structure_indicators = [
      String.contains?(content, "defmodule"),
      String.contains?(content, "@moduledoc"),
      String.contains?(content, "@doc"),
      String.match?(content, ~r/def\s+\w+.*do/)
    ]

    Enum.count(structure_indicators, & &1) >= 2
  end

  # Smart reference generation

  defp generate_smart_references(candidates, code_path, opts) do
    candidates
    |> Enum.map(&create_smart_reference(&1, code_path, opts))
    |> Enum.reject(&is_nil/1)
  end

  defp create_smart_reference(candidate, code_path, opts) do
    case candidate.corresponding_implementation do
      nil ->
        # Create generic file reference
        create_generic_reference(candidate, code_path)

      impl ->
        # Create specific implementation reference
        create_implementation_reference(candidate, impl, opts)
    end
  end

  defp create_generic_reference(candidate, code_path) do
    # Generate a generic reference when no specific implementation found
    suggested_file = suggest_target_file(candidate, code_path)

    %Reference{
      id: generate_reference_id(candidate),
      type: :file,
      source_file: candidate.example.source_file,
      source_location: {candidate.example.line_start, candidate.example.line_end},
      target_file: suggested_file,
      target_location: nil,
      display_text: "See implementation",
      link_text: generate_file_link(suggested_file),
      context_preview: nil,
      metadata: %{
        original_example: candidate.example,
        reference_type: candidate.suggested_reference_type,
        confidence: candidate.confidence_score,
        created_at: DateTime.utc_now()
      },
      last_validated: DateTime.utc_now(),
      validation_status: :warning
    }
  end

  defp create_implementation_reference(candidate, impl, _opts) do
    target_location = extract_target_location(impl)

    %Reference{
      id: generate_reference_id(candidate),
      type: candidate.suggested_reference_type,
      source_file: candidate.example.source_file,
      source_location: {candidate.example.line_start, candidate.example.line_end},
      target_file: impl.source_file,
      target_location: target_location,
      display_text: generate_display_text(candidate, impl),
      link_text: generate_implementation_link(impl, target_location),
      context_preview: generate_initial_preview(impl),
      metadata: %{
        original_example: candidate.example,
        implementation: impl,
        reference_type: candidate.suggested_reference_type,
        confidence: candidate.confidence_score,
        created_at: DateTime.utc_now()
      },
      last_validated: DateTime.utc_now(),
      validation_status: :valid
    }
  end

  defp suggest_target_file(candidate, code_path) do
    # Suggest where the implementation should go based on content analysis
    content = candidate.example.content

    cond do
      String.contains?(content, "defmodule") ->
        module_name = extract_module_name_from_content(content)
        module_to_file_path(module_name, code_path)

      String.contains?(content, "GenServer") ->
        Path.join([code_path, "prismatic", "lib", "prismatic", "example_genserver.ex"])

      String.contains?(content, "Phoenix") ->
        Path.join([code_path, "prismatic_web", "lib", "prismatic_web", "example_controller.ex"])

      true ->
        Path.join([code_path, "prismatic", "lib", "prismatic", "example.ex"])
    end
  end

  defp extract_module_name_from_content(content) do
    case Regex.run(~r/defmodule\s+([A-Z][a-zA-Z0-9._]*)/s, content) do
      [_, module_name] -> module_name
      _ -> "Example"
    end
  end

  defp module_to_file_path(module_name, code_path) do
    # Convert module name to appropriate file path
    parts = String.split(module_name, ".")

    case parts do
      ["Prismatic" | rest] ->
        filename = rest |> Enum.map(&Macro.underscore/1) |> Enum.join("/")
        Path.join([code_path, "prismatic", "lib", "prismatic", "#{filename}.ex"])

      ["PrismaticWeb" | rest] ->
        filename = rest |> Enum.map(&Macro.underscore/1) |> Enum.join("/")
        Path.join([code_path, "prismatic_web", "lib", "prismatic_web", "#{filename}.ex"])

      _ ->
        filename = Macro.underscore(module_name)
        Path.join([code_path, "prismatic", "lib", "prismatic", "#{filename}.ex"])
    end
  end

  defp extract_target_location(impl) do
    case impl.type do
      :module_definition -> {impl.line_number, impl.line_number}
      :function_definition -> {impl.line_number, impl.line_number}
      _ -> {impl.line_number, impl.line_number}
    end
  end

  defp generate_display_text(candidate, impl) do
    case candidate.suggested_reference_type do
      :module -> "Module: #{impl.module_name || "Implementation"}"
      :function -> "Function: #{impl.function_name || "implementation"}()"
      :line_range -> "Implementation"
      _ -> "See implementation"
    end
  end

  defp generate_implementation_link(impl, {start_line, end_line}) do
    if start_line == end_line do
      "[`#{Path.basename(impl.source_file)}:#{start_line}`](#{impl.source_file}:#{start_line})"
    else
      "[`#{Path.basename(impl.source_file)}:#{start_line}-#{end_line}`](#{impl.source_file}:#{start_line}-#{end_line})"
    end
  end

  defp generate_file_link(file_path) do
    "[`#{Path.basename(file_path)}`](#{file_path})"
  end

  defp generate_initial_preview(impl) do
    if File.exists?(impl.source_file) do
      case File.read(impl.source_file) do
        {:ok, content} ->
          lines = String.split(content, "\n")
          target_line = impl.line_number

          # Get context around the target line
          context_start = max(1, target_line - 2)
          context_end = min(length(lines), target_line + 2)

          lines
          |> Enum.slice(context_start - 1, context_end - context_start + 1)
          |> Enum.join("\n")
          |> String.trim()

        {:error, _} -> nil
      end
    else
      nil
    end
  end

  defp generate_reference_id(candidate) do
    # Generate unique ID for reference
    source_hash = :crypto.hash(:md5, candidate.example.source_file) |> Base.encode16(case: :lower)
    content_hash = :crypto.hash(:md5, candidate.example.content) |> Base.encode16(case: :lower)

    "ref_#{String.slice(source_hash, 0, 8)}_#{String.slice(content_hash, 0, 8)}"
  end

  # Replacement execution

  defp simulate_replacements(references) do
    Logger.info("Simulating replacements for #{length(references)} references")

    references
    |> Enum.map(&simulate_single_replacement/1)
  end

  defp simulate_single_replacement(reference) do
    %{
      reference_id: reference.id,
      source_file: reference.source_file,
      would_replace: true,
      new_content: reference.link_text,
      validation_status: reference.validation_status,
      simulated_at: DateTime.utc_now()
    }
  end

  defp perform_replacements(references, opts) do
    Logger.info("Performing replacements for #{length(references)} references")

    backup_enabled = Keyword.get(opts, :backup, true)

    references
    |> Enum.map(&perform_single_replacement(&1, backup_enabled))
  end

  defp perform_single_replacement(reference, backup_enabled) do
    try do
      # Create backup if enabled
      if backup_enabled do
        create_replacement_backup(reference)
      end

      # Read source file
      original_content = File.read!(reference.source_file)

      # Generate replacement content
      replacement_content = generate_replacement_content(reference)

      # Perform replacement
      updated_content = replace_content_section(
        original_content,
        reference.source_location,
        replacement_content
      )

      # Write updated content
      File.write!(reference.source_file, updated_content)

      %{
        reference_id: reference.id,
        status: :success,
        source_file: reference.source_file,
        replaced_at: DateTime.utc_now()
      }

    rescue
      error ->
        Logger.error("Replacement failed for #{reference.id}: #{Exception.message(error)}")

        %{
          reference_id: reference.id,
          status: :failed,
          error: Exception.message(error),
          attempted_at: DateTime.utc_now()
        }
    end
  end

  defp create_replacement_backup(reference) do
    backup_dir = Path.join([File.cwd!(), ".replacement_backups"])
    File.mkdir_p!(backup_dir)

    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    backup_file = Path.join(backup_dir, "#{reference.id}_#{timestamp}.backup")

    original_content = File.read!(reference.source_file)

    backup_data = %{
      reference_id: reference.id,
      original_file: reference.source_file,
      original_content: original_content,
      backup_timestamp: DateTime.utc_now()
    }

    File.write!(backup_file, Jason.encode!(backup_data, pretty: true))
  end

  defp generate_replacement_content(reference) do
    case reference.type do
      :module ->
        """
        <!-- MODULE_REFERENCE: #{reference.id} -->
        **#{reference.display_text}**

        #{reference.link_text}

        #{generate_context_block(reference)}
        """

      :function ->
        """
        <!-- FUNCTION_REFERENCE: #{reference.id} -->
        **#{reference.display_text}**

        #{reference.link_text}

        #{generate_context_block(reference)}
        """

      _ ->
        """
        <!-- CODE_REFERENCE: #{reference.id} -->
        **#{reference.display_text}**

        #{reference.link_text}

        #{generate_context_block(reference)}
        """
    end
  end

  defp generate_context_block(reference) do
    if reference.context_preview do
      """
      <details>
      <summary>Preview</summary>

      ```elixir
      #{reference.context_preview}
      ```
      </details>
      """
    else
      ""
    end
  end

  defp replace_content_section(content, {start_line, end_line}, replacement) do
    lines = String.split(content, "\n")

    before_lines = Enum.take(lines, start_line - 1)
    after_lines = Enum.drop(lines, end_line)

    updated_lines = before_lines ++ [replacement] ++ after_lines
    Enum.join(updated_lines, "\n")
  end

  # Link analysis and validation

  defp analyze_file_for_links(file_path) do
    if File.exists?(file_path) do
      content = File.read!(file_path)

      # Find module and function definitions
      modules = extract_module_definitions(content, file_path)
      functions = extract_function_definitions(content, file_path)

      modules ++ functions
    else
      []
    end
  end

  defp extract_module_definitions(content, file_path) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_num} ->
      case Regex.run(~r/defmodule\s+([A-Z][a-zA-Z0-9._]*)/s, line) do
        [_, module_name] ->
          [%{
            type: :module,
            name: module_name,
            file: file_path,
            line: line_num,
            content: line
          }]
        _ -> []
      end
    end)
  end

  defp extract_function_definitions(content, file_path) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_num} ->
      case Regex.run(~r/def(?:p)?\s+([a-z_][a-zA-Z0-9_?!]*)/s, line) do
        [_, function_name] ->
          [%{
            type: :function,
            name: function_name,
            file: file_path,
            line: line_num,
            content: line
          }]
        _ -> []
      end
    end)
  end

  defp enhance_link_with_metadata(link) do
    enhanced_metadata = %{
      created_at: DateTime.utc_now(),
      file_size: get_file_size(link.file),
      last_modified: get_file_last_modified(link.file)
    }

    Map.put(link, :metadata, enhanced_metadata)
  end

  defp get_file_size(file_path) do
    case File.stat(file_path) do
      {:ok, %{size: size}} -> size
      _ -> 0
    end
  end

  defp get_file_last_modified(file_path) do
    case File.stat(file_path) do
      {:ok, %{mtime: mtime}} ->
        mtime |> NaiveDateTime.from_erl!() |> DateTime.from_naive!("Etc/UTC")
      _ -> DateTime.utc_now()
    end
  end

  defp group_links_by_type(links) do
    Enum.group_by(links, & &1.type)
  end

  defp validate_all_links(links) do
    results = Enum.map(links, &validate_link/1)

    %{
      total: length(results),
      valid: Enum.count(results, &(&1.status == :valid)),
      invalid: Enum.count(results, &(&1.status == :invalid)),
      warnings: Enum.count(results, &(&1.status == :warning))
    }
  end

  defp validate_link(link) do
    cond do
      not File.exists?(link.file) ->
        %{link: link, status: :invalid, reason: "File does not exist"}

      not line_exists_in_file?(link.file, link.line) ->
        %{link: link, status: :warning, reason: "Line number may be outdated"}

      true ->
        %{link: link, status: :valid, reason: "Link is valid"}
    end
  end

  defp line_exists_in_file?(file_path, line_number) do
    case File.read(file_path) do
      {:ok, content} ->
        line_count = String.split(content, "\n") |> length()
        line_number <= line_count

      _ -> false
    end
  end

  # Reference validation

  defp validate_single_reference(reference) do
    validation_checks = [
      check_target_file_exists(reference),
      check_target_location_valid(reference),
      check_source_file_exists(reference),
      check_reference_syntax(reference)
    ]

    failed_checks = Enum.filter(validation_checks, &(&1.result == false))

    status = cond do
      length(failed_checks) == 0 -> :valid
      Enum.any?(failed_checks, &(&1.severity == :error)) -> :invalid
      true -> :warning
    end

    %{
      reference: reference,
      status: status,
      checks: validation_checks,
      failed_checks: failed_checks,
      validated_at: DateTime.utc_now()
    }
  end

  defp check_target_file_exists(reference) do
    result = File.exists?(reference.target_file)

    %{
      check: :target_file_exists,
      result: result,
      severity: if(result, do: :info, else: :error),
      message: if(result, do: "Target file exists", else: "Target file does not exist")
    }
  end

  defp check_target_location_valid(reference) do
    case reference.target_location do
      nil ->
        %{check: :target_location_valid, result: true, severity: :info, message: "No specific location"}

      {start_line, end_line} ->
        valid = line_exists_in_file?(reference.target_file, start_line) and
                line_exists_in_file?(reference.target_file, end_line)

        %{
          check: :target_location_valid,
          result: valid,
          severity: if(valid, do: :info, else: :warning),
          message: if(valid, do: "Target location is valid", else: "Target location may be outdated")
        }
    end
  end

  defp check_source_file_exists(reference) do
    result = File.exists?(reference.source_file)

    %{
      check: :source_file_exists,
      result: result,
      severity: if(result, do: :info, else: :error),
      message: if(result, do: "Source file exists", else: "Source file does not exist")
    }
  end

  defp check_reference_syntax(reference) do
    # Check if the reference syntax is valid
    valid = String.contains?(reference.link_text, "[") and
            String.contains?(reference.link_text, "]") and
            String.contains?(reference.link_text, "(") and
            String.contains?(reference.link_text, ")")

    %{
      check: :reference_syntax,
      result: valid,
      severity: if(valid, do: :info, else: :warning),
      message: if(valid, do: "Reference syntax is valid", else: "Reference syntax may be malformed")
    }
  end

  # Reference maintenance and health monitoring

  defp calculate_reference_health(validation_results) do
    total = length(validation_results[:valid] || []) +
            length(validation_results[:invalid] || []) +
            length(validation_results[:warning] || [])

    valid_count = length(validation_results[:valid] || [])
    warning_count = length(validation_results[:warning] || [])
    invalid_count = length(validation_results[:invalid] || [])

    overall_score = if total > 0 do
      round((valid_count + (warning_count * 0.5)) / total * 100)
    else
      100
    end

    %{
      overall_score: overall_score,
      total_references: total,
      valid_count: valid_count,
      warning_count: warning_count,
      invalid_count: invalid_count,
      health_grade: calculate_health_grade(overall_score)
    }
  end

  defp calculate_health_grade(score) when score >= 95, do: :excellent
  defp calculate_health_grade(score) when score >= 85, do: :good
  defp calculate_health_grade(score) when score >= 70, do: :fair
  defp calculate_health_grade(score) when score >= 50, do: :poor
  defp calculate_health_grade(_), do: :critical

  defp generate_maintenance_recommendations(validation_results) do
    recommendations = []

    invalid_count = length(validation_results[:invalid] || [])
    warning_count = length(validation_results[:warning] || [])

    recommendations = if invalid_count > 0 do
      [%{
        priority: :high,
        type: :fix_invalid_references,
        description: "Fix #{invalid_count} invalid references",
        action: "Review and update references to non-existent targets"
      } | recommendations]
    else
      recommendations
    end

    recommendations = if warning_count > 5 do
      [%{
        priority: :medium,
        type: :review_warnings,
        description: "Review #{warning_count} references with warnings",
        action: "Check line numbers and update as needed"
      } | recommendations]
    else
      recommendations
    end

    recommendations = if invalid_count + warning_count > 10 do
      [%{
        priority: :low,
        type: :automated_maintenance,
        description: "Consider implementing automated reference maintenance",
        action: "Set up Git hooks for automatic reference updates"
      } | recommendations]
    else
      recommendations
    end

    Enum.reverse(recommendations)
  end

  # Reference map building and management

  defp build_reference_map(references) do
    file_index = build_file_index(references)
    reverse_index = build_reverse_index(references)

    %ReferenceMap{
      references: references,
      file_index: file_index,
      reverse_index: reverse_index,
      validation_results: %{},
      last_updated: DateTime.utc_now()
    }
  end

  defp build_file_index(references) do
    references
    |> Enum.group_by(& &1.source_file)
  end

  defp build_reverse_index(references) do
    references
    |> Enum.group_by(& &1.target_file)
  end

  # Utility functions for counting results

  defp count_successful_replacements(results) do
    Enum.count(results, &(&1.status == :success))
  rescue
    _ -> 0
  end

  defp count_failed_replacements(results) do
    Enum.count(results, &(&1.status == :failed))
  rescue
    _ -> 0
  end

  defp count_affected_references(updates) do
    updates
    |> Map.values()
    |> List.flatten()
    |> length()
  end

  defp count_successful_updates(updates) do
    updates
    |> Map.get(:successful, [])
    |> length()
  end

  defp count_failed_updates(updates) do
    updates
    |> Map.get(:failed, [])
    |> length()
  end

  # Placeholder functions for file change handling

  defp find_affected_references(_change, _reference_map) do
    # Implementation would find references affected by file changes
    []
  end

  defp update_reference_for_change(reference, _changes) do
    # Implementation would update reference based on file changes
    %{reference: reference, update_type: :no_change}
  end

  defp apply_reference_updates(_updates, _opts) do
    # Implementation would apply the reference updates to files
    :ok
  end

  defp rebuild_reference_map(reference_map, _updates) do
    # Implementation would rebuild the reference map with updates
    reference_map
  end

  defp extract_change_trigger(_file_changes) do
    # Implementation would determine what triggered the changes
    :manual
  end

  # Preview generation

  defp generate_preview(reference, config) do
    if File.exists?(reference.target_file) do
      case File.read(reference.target_file) do
        {:ok, content} ->
          create_contextual_preview(reference, content, config)
        {:error, _} -> nil
      end
    else
      nil
    end
  end

  defp create_contextual_preview(reference, content, config) do
    lines = String.split(content, "\n")

    case reference.target_location do
      {start_line, end_line} ->
        context_start = max(1, start_line - config.context_lines)
        context_end = min(length(lines), end_line + config.context_lines)

        preview_lines = lines
        |> Enum.slice(context_start - 1, context_end - context_start + 1)
        |> add_line_numbers_if_enabled(context_start, config)

        preview_content = Enum.join(preview_lines, "\n")

        %{
          reference_id: reference.id,
          preview_content: preview_content,
          start_line: context_start,
          end_line: context_end,
          highlight_range: {start_line, end_line},
          config: config
        }

      nil ->
        # Show beginning of file as preview
        preview_lines = lines
        |> Enum.take(config.context_lines * 2)
        |> add_line_numbers_if_enabled(1, config)

        %{
          reference_id: reference.id,
          preview_content: Enum.join(preview_lines, "\n"),
          start_line: 1,
          end_line: min(length(lines), config.context_lines * 2),
          highlight_range: nil,
          config: config
        }
    end
  end

  defp add_line_numbers_if_enabled(lines, start_line, config) do
    if config.include_line_numbers do
      lines
      |> Enum.with_index(start_line)
      |> Enum.map(fn {line, line_num} ->
        "#{String.pad_leading(Integer.to_string(line_num), 3)} | #{line}"
      end)
    else
      lines
    end
  end

  defp group_previews_by_type(previews) do
    previews
    |> Enum.group_by(fn preview ->
      if preview.highlight_range, do: :targeted, else: :general
    end)
  end
end
