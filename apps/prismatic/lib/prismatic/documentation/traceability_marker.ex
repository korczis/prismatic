defmodule Prismatic.Documentation.TraceabilityMarker do
  @moduledoc """
  Traceability marker system for bidirectional documentation-code linking.

  This module provides comprehensive traceability between documentation sections
  and corresponding code implementations, enabling automated cross-reference
  validation and detection of orphaned documentation or missing implementations.

  ## Features

  - Create bidirectional references between docs and code
  - Track implementation links automatically
  - Validate cross-reference consistency
  - Detect orphaned documentation and missing implementations
  - Generate traceability matrices and reports
  """

  require Logger

  @traceability_marker_pattern ~r/<!--\s*TRACE:([^->]+)-->/
  @code_reference_pattern ~r/@doc\s+.*?TRACE:([^"']+)/s
  @implementation_pattern ~r/defmodule\s+([A-Z][a-zA-Z0-9._]*)/
  @function_pattern ~r/def(?:p)?\s+([a-z_][a-zA-Z0-9_?!]*)/

  @doc """
  Generate traceability markers between documentation and code.

  Creates bidirectional references and validates existing links.
  """
  def generate_markers(docs_path, code_path) do
    Logger.info("Generating traceability markers between #{docs_path} and #{code_path}")

    doc_files = find_documentation_files(docs_path)
    code_files = find_code_files(code_path)

    Logger.info("Found #{length(doc_files)} documentation files and #{length(code_files)} code files")

    doc_references = extract_documentation_references(doc_files)
    code_references = extract_code_references(code_files)

    %{
      summary: generate_traceability_summary(doc_references, code_references),
      documentation_references: doc_references,
      code_references: code_references,
      bidirectional_links: create_bidirectional_links(doc_references, code_references),
      validation_results: validate_traceability(doc_references, code_references),
      orphaned_items: find_orphaned_items(doc_references, code_references),
      missing_implementations: find_missing_implementations(doc_references, code_references),
      traceability_matrix: generate_traceability_matrix(doc_references, code_references),
      generation_metadata: %{
        generation_date: DateTime.utc_now(),
        docs_path: docs_path,
        code_path: code_path,
        generator_version: "1.0.0"
      }
    }
  end

  @doc """
  Validate existing traceability links between documentation and code.

  Returns validation results with broken links and suggestions.
  """
  def validate_existing_traceability(docs_path, code_path) do
    markers = generate_markers(docs_path, code_path)

    %{
      total_links: count_total_links(markers),
      valid_links: count_valid_links(markers),
      broken_links: extract_broken_links(markers),
      validation_score: calculate_validation_score(markers),
      recommendations: generate_recommendations(markers)
    }
  end

  # Private functions for traceability generation

  defp find_documentation_files(docs_path) do
    docs_path
    |> Path.join("**/*.md")
    |> Path.wildcard()
    |> Enum.sort()
  end

  defp find_code_files(code_path) do
    code_path
    |> Path.join("**/*.{ex,exs}")
    |> Path.wildcard()
    |> Enum.sort()
  end

  defp extract_documentation_references(doc_files) do
    Enum.flat_map(doc_files, &extract_doc_references_from_file/1)
  end

  defp extract_doc_references_from_file(file_path) do
    Logger.debug("Extracting documentation references from #{file_path}")

    content = File.read!(file_path)

    explicit_markers = extract_explicit_traceability_markers(content, file_path)
    implicit_references = extract_implicit_code_references(content, file_path)
    section_references = extract_section_based_references(content, file_path)

    explicit_markers ++ implicit_references ++ section_references
  end

  defp extract_explicit_traceability_markers(content, file_path) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_num} ->
      case Regex.run(@traceability_marker_pattern, line) do
        [_, trace_id] ->
          [%{
            type: :explicit_marker,
            source_file: file_path,
            line_number: line_num,
            trace_id: String.trim(trace_id),
            context: extract_context_around_line(content, line_num),
            marker_content: line
          }]
        _ -> []
      end
    end)
  end

  defp extract_implicit_code_references(content, file_path) do
    # Extract references to modules, functions, and files
    code_patterns = [
      {~r/`([A-Z][a-zA-Z0-9._]+)`/, :module_reference},
      {~r/`([a-z_][a-zA-Z0-9_?!]*)\(\)`/, :function_reference},
      {~r/`([a-z_]+\.ex(?:s)?)`/, :file_reference},
      {~r/\bapps\/([a-z_]+)/, :app_reference}
    ]

    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_num} ->
      Enum.flat_map(code_patterns, fn {pattern, ref_type} ->
        Regex.scan(pattern, line)
        |> Enum.map(fn [_full_match, reference] ->
          %{
            type: :implicit_reference,
            reference_type: ref_type,
            source_file: file_path,
            line_number: line_num,
            reference: reference,
            line_content: line,
            context: extract_context_around_line(content, line_num)
          }
        end)
      end)
    end)
  end

  defp extract_section_based_references(content, file_path) do
    # Extract references based on section headings that suggest implementation
    implementation_headings = [
      "implementation", "code", "example", "usage", "api", "module", "function"
    ]

    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_num} ->
      case Regex.run(~r/^(\#{1,6})\s*(.+)$/, line) do
        [_, hashes, heading] ->
          heading_lower = String.downcase(heading)
          if Enum.any?(implementation_headings, &String.contains?(heading_lower, &1)) do
            [%{
              type: :section_reference,
              source_file: file_path,
              line_number: line_num,
              heading: heading,
              level: String.length(hashes),
              section_content: extract_section_content(content, line_num),
              potential_implementations: extract_potential_implementations(heading)
            }]
          else
            []
          end
        _ -> []
      end
    end)
  end

  defp extract_context_around_line(content, line_num) do
    lines = String.split(content, "\n")

    before =
      lines
      |> Enum.slice(max(0, line_num - 3), 2)
      |> Enum.join("\n")

    after_lines =
      lines
      |> Enum.slice(line_num, 2)
      |> Enum.join("\n")

    %{
      before: String.trim(before),
      after: String.trim(after_lines),
      section_heading: find_section_heading(lines, line_num)
    }
  end

  defp find_section_heading(lines, target_line) do
    lines
    |> Enum.slice(0, target_line - 1)
    |> Enum.reverse()
    |> Enum.find(&String.match?(&1, ~r/^\#{1,6}\s+/))
    |> case do
      nil -> nil
      heading -> String.trim(String.replace(heading, ~r/^\#{1,6}\s*/, ""))
    end
  end

  defp extract_section_content(content, heading_line) do
    lines = String.split(content, "\n")

    # Get content until next heading or end of file
    content_lines =
      lines
      |> Enum.slice(heading_line, length(lines) - heading_line)
      |> Enum.take_while(&(not String.match?(&1, ~r/^\#{1,6}\s+/)))

    content_lines
    |> Enum.join("\n")
    |> String.trim()
  end

  defp extract_potential_implementations(heading) do
    heading_lower = String.downcase(heading)

    # Extract potential module/function names from heading
    potential_names =
      heading_lower
      |> String.replace(~r/[^a-z0-9_\s]/, "")
      |> String.split()
      |> Enum.reject(&(&1 in ["implementation", "code", "example", "usage", "api", "the", "of", "for", "and"]))
      |> Enum.map(&String.replace(&1, " ", "_"))

    %{
      module_candidates: generate_module_candidates(potential_names),
      function_candidates: generate_function_candidates(potential_names)
    }
  end

  defp generate_module_candidates(names) do
    names
    |> Enum.map(&Macro.camelize/1)
    |> Enum.map(fn name -> "Prismatic.#{name}" end)
  end

  defp generate_function_candidates(names) do
    names
    |> Enum.map(&String.replace(&1, " ", "_"))
  end

  defp extract_code_references(code_files) do
    Enum.flat_map(code_files, &extract_code_references_from_file/1)
  end

  defp extract_code_references_from_file(file_path) do
    Logger.debug("Extracting code references from #{file_path}")

    content = File.read!(file_path)

    explicit_traces = extract_explicit_trace_markers(content, file_path)
    module_definitions = extract_module_definitions(content, file_path)
    function_definitions = extract_function_definitions(content, file_path)

    explicit_traces ++ module_definitions ++ function_definitions
  end

  defp extract_explicit_trace_markers(content, file_path) do
    Regex.scan(@code_reference_pattern, content)
    |> Enum.map(fn [_full_match, trace_id] ->
      %{
        type: :explicit_trace,
        source_file: file_path,
        trace_id: String.trim(trace_id),
        context: :code_documentation
      }
    end)
  end

  defp extract_module_definitions(content, file_path) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, line_num} ->
      case Regex.run(@implementation_pattern, line) do
        [_, module_name] ->
          [%{
            type: :module_definition,
            source_file: file_path,
            line_number: line_num,
            module_name: module_name,
            full_line: line,
            documentation: extract_module_documentation(content, line_num)
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
      case Regex.run(@function_pattern, line) do
        [_, function_name] ->
          [%{
            type: :function_definition,
            source_file: file_path,
            line_number: line_num,
            function_name: function_name,
            full_line: line,
            documentation: extract_function_documentation(content, line_num),
            visibility: if(String.contains?(line, "defp"), do: :private, else: :public)
          }]
        _ -> []
      end
    end)
  end

  defp extract_module_documentation(content, module_line) do
    lines = String.split(content, "\n")

    # Look for @moduledoc before the module definition
    preceding_lines =
      lines
      |> Enum.slice(0, module_line - 1)
      |> Enum.reverse()
      |> Enum.take_while(&(String.trim(&1) != ""))

    doc_content =
      preceding_lines
      |> Enum.filter(&String.contains?(&1, "@moduledoc"))
      |> List.first()

    case doc_content do
      nil -> nil
      doc -> extract_doc_string(doc)
    end
  end

  defp extract_function_documentation(content, function_line) do
    lines = String.split(content, "\n")

    # Look for @doc before the function definition
    preceding_lines =
      lines
      |> Enum.slice(max(0, function_line - 10), min(10, function_line - 1))
      |> Enum.reverse()
      |> Enum.take_while(&(String.trim(&1) != ""))

    doc_content =
      preceding_lines
      |> Enum.filter(&String.contains?(&1, "@doc"))
      |> List.first()

    case doc_content do
      nil -> nil
      doc -> extract_doc_string(doc)
    end
  end

  defp extract_doc_string(doc_line) do
    case Regex.run(~r/@doc\s+"([^"]+)"/, doc_line) do
      [_, doc_string] -> doc_string
      _ ->
        case Regex.run(~r/@doc\s+"""([^"]+)"""/, doc_line) do
          [_, doc_string] -> doc_string
          _ -> nil
        end
    end
  end

  defp create_bidirectional_links(doc_references, code_references) do
    explicit_links = create_explicit_links(doc_references, code_references)
    implicit_links = create_implicit_links(doc_references, code_references)

    %{
      explicit: explicit_links,
      implicit: implicit_links,
      total_links: length(explicit_links) + length(implicit_links)
    }
  end

  defp create_explicit_links(doc_references, code_references) do
    doc_markers = Enum.filter(doc_references, &(&1.type == :explicit_marker))
    code_markers = Enum.filter(code_references, &(&1.type == :explicit_trace))

    Enum.flat_map(doc_markers, fn doc_marker ->
      Enum.filter_map(code_markers,
        &(&1.trace_id == doc_marker.trace_id),
        fn code_marker ->
          %{
            link_type: :explicit,
            documentation: doc_marker,
            implementation: code_marker,
            trace_id: doc_marker.trace_id,
            confidence: 100
          }
        end)
    end)
  end

  defp create_implicit_links(doc_references, code_references) do
    implicit_doc_refs = Enum.filter(doc_references, &(&1.type == :implicit_reference))
    code_definitions = Enum.filter(code_references, &(&1.type in [:module_definition, :function_definition]))

    Enum.flat_map(implicit_doc_refs, fn doc_ref ->
      find_matching_implementations(doc_ref, code_definitions)
    end)
  end

  defp find_matching_implementations(doc_ref, code_definitions) do
    case doc_ref.reference_type do
      :module_reference ->
        find_module_matches(doc_ref, code_definitions)
      :function_reference ->
        find_function_matches(doc_ref, code_definitions)
      :file_reference ->
        find_file_matches(doc_ref, code_definitions)
      _ -> []
    end
  end

  defp find_module_matches(doc_ref, code_definitions) do
    module_definitions = Enum.filter(code_definitions, &(&1.type == :module_definition))

    Enum.filter_map(module_definitions,
      &module_name_matches?(&1.module_name, doc_ref.reference),
      fn module_def ->
        %{
          link_type: :implicit_module,
          documentation: doc_ref,
          implementation: module_def,
          confidence: calculate_match_confidence(doc_ref.reference, module_def.module_name)
        }
      end)
  end

  defp find_function_matches(doc_ref, code_definitions) do
    function_definitions = Enum.filter(code_definitions, &(&1.type == :function_definition))

    Enum.filter_map(function_definitions,
      &function_name_matches?(&1.function_name, doc_ref.reference),
      fn function_def ->
        %{
          link_type: :implicit_function,
          documentation: doc_ref,
          implementation: function_def,
          confidence: calculate_match_confidence(doc_ref.reference, function_def.function_name)
        }
      end)
  end

  defp find_file_matches(doc_ref, code_definitions) do
    # Match file references to actual files
    referenced_file = doc_ref.reference

    Enum.filter_map(code_definitions,
      &file_path_matches?(&1.source_file, referenced_file),
      fn code_def ->
        %{
          link_type: :implicit_file,
          documentation: doc_ref,
          implementation: code_def,
          confidence: calculate_file_match_confidence(code_def.source_file, referenced_file)
        }
      end)
  end

  defp module_name_matches?(module_name, reference) do
    # Check if module name matches reference (with various formats)
    simple_name = module_name |> String.split(".") |> List.last()

    String.downcase(simple_name) == String.downcase(reference) or
    String.downcase(module_name) == String.downcase(reference)
  end

  defp function_name_matches?(function_name, reference) do
    String.downcase(function_name) == String.downcase(reference)
  end

  defp file_path_matches?(file_path, reference) do
    Path.basename(file_path) == reference or
    String.contains?(file_path, reference)
  end

  defp calculate_match_confidence(reference, implementation) do
    if String.downcase(reference) == String.downcase(implementation) do
      100
    else
      # Simple similarity calculation
      similarity = string_similarity(String.downcase(reference), String.downcase(implementation))
      round(similarity * 100)
    end
  end

  defp calculate_file_match_confidence(file_path, reference) do
    if Path.basename(file_path) == reference do
      100
    else
      similarity = string_similarity(Path.basename(file_path), reference)
      round(similarity * 100)
    end
  end

  defp string_similarity(str1, str2) do
    # Simple Jaccard similarity
    set1 = String.graphemes(str1) |> MapSet.new()
    set2 = String.graphemes(str2) |> MapSet.new()

    intersection = MapSet.intersection(set1, set2) |> MapSet.size()
    union = MapSet.union(set1, set2) |> MapSet.size()

    if union == 0, do: 0, else: intersection / union
  end

  defp validate_traceability(doc_references, code_references) do
    bidirectional_links = create_bidirectional_links(doc_references, code_references)

    %{
      total_documentation_references: length(doc_references),
      total_code_references: length(code_references),
      successful_links: count_successful_links(bidirectional_links),
      high_confidence_links: count_high_confidence_links(bidirectional_links),
      low_confidence_links: count_low_confidence_links(bidirectional_links),
      validation_score: calculate_traceability_score(doc_references, code_references, bidirectional_links)
    }
  end

  defp count_successful_links(bidirectional_links) do
    length(bidirectional_links.explicit) + length(bidirectional_links.implicit)
  end

  defp count_high_confidence_links(bidirectional_links) do
    all_links = bidirectional_links.explicit ++ bidirectional_links.implicit
    Enum.count(all_links, &(&1.confidence >= 80))
  end

  defp count_low_confidence_links(bidirectional_links) do
    all_links = bidirectional_links.explicit ++ bidirectional_links.implicit
    Enum.count(all_links, &(&1.confidence < 50))
  end

  defp calculate_traceability_score(doc_references, code_references, bidirectional_links) do
    total_references = length(doc_references) + length(code_references)
    successful_links = count_successful_links(bidirectional_links)

    if total_references == 0 do
      0
    else
      round((successful_links / total_references) * 100)
    end
  end

  defp find_orphaned_items(doc_references, code_references) do
    bidirectional_links = create_bidirectional_links(doc_references, code_references)
    all_links = bidirectional_links.explicit ++ bidirectional_links.implicit

    linked_doc_refs = Enum.map(all_links, & &1.documentation) |> MapSet.new()
    linked_code_refs = Enum.map(all_links, & &1.implementation) |> MapSet.new()

    orphaned_docs =
      doc_references
      |> Enum.reject(&MapSet.member?(linked_doc_refs, &1))

    orphaned_code =
      code_references
      |> Enum.reject(&MapSet.member?(linked_code_refs, &1))

    %{
      orphaned_documentation: orphaned_docs,
      orphaned_code: orphaned_code,
      orphaned_count: length(orphaned_docs) + length(orphaned_code)
    }
  end

  defp find_missing_implementations(doc_references, code_references) do
    section_refs = Enum.filter(doc_references, &(&1.type == :section_reference))

    Enum.flat_map(section_refs, fn section_ref ->
      find_missing_for_section(section_ref, code_references)
    end)
  end

  defp find_missing_for_section(section_ref, code_references) do
    potential_impls = section_ref.potential_implementations

    missing_modules = find_missing_modules(potential_impls.module_candidates, code_references)
    missing_functions = find_missing_functions(potential_impls.function_candidates, code_references)

    missing_modules ++ missing_functions
  end

  defp find_missing_modules(candidates, code_references) do
    existing_modules =
      code_references
      |> Enum.filter(&(&1.type == :module_definition))
      |> Enum.map(& &1.module_name)
      |> MapSet.new()

    candidates
    |> Enum.reject(&MapSet.member?(existing_modules, &1))
    |> Enum.map(fn missing_module ->
      %{
        type: :missing_module,
        name: missing_module,
        suggested_location: suggest_module_location(missing_module)
      }
    end)
  end

  defp find_missing_functions(candidates, code_references) do
    existing_functions =
      code_references
      |> Enum.filter(&(&1.type == :function_definition))
      |> Enum.map(& &1.function_name)
      |> MapSet.new()

    candidates
    |> Enum.reject(&MapSet.member?(existing_functions, &1))
    |> Enum.map(fn missing_function ->
      %{
        type: :missing_function,
        name: missing_function,
        suggested_location: suggest_function_location(missing_function)
      }
    end)
  end

  defp suggest_module_location(module_name) do
    # Simple heuristic for suggesting module location
    app_name = String.split(module_name, ".") |> Enum.at(1, "prismatic")
    filename = Macro.underscore(module_name) <> ".ex"

    "apps/#{app_name}/lib/#{filename}"
  end

  defp suggest_function_location(function_name) do
    # Suggest adding to most relevant existing module
    "Consider adding to appropriate module based on functionality"
  end

  defp generate_traceability_matrix(doc_references, code_references) do
    bidirectional_links = create_bidirectional_links(doc_references, code_references)

    # Create a matrix showing relationships
    doc_files = doc_references |> Enum.map(& &1.source_file) |> Enum.uniq()
    code_files = code_references |> Enum.map(& &1.source_file) |> Enum.uniq()

    matrix =
      for doc_file <- doc_files do
        row = for code_file <- code_files do
          count_links_between_files(doc_file, code_file, bidirectional_links)
        end
        %{documentation_file: doc_file, links: Enum.zip(code_files, row)}
      end

    %{
      matrix: matrix,
      documentation_files: doc_files,
      code_files: code_files,
      total_connections: calculate_total_connections(matrix)
    }
  end

  defp count_links_between_files(doc_file, code_file, bidirectional_links) do
    all_links = bidirectional_links.explicit ++ bidirectional_links.implicit

    Enum.count(all_links, fn link ->
      link.documentation.source_file == doc_file and
      link.implementation.source_file == code_file
    end)
  end

  defp calculate_total_connections(matrix) do
    matrix
    |> Enum.flat_map(& &1.links)
    |> Enum.map(fn {_, count} -> count end)
    |> Enum.sum()
  end

  defp generate_traceability_summary(doc_references, code_references) do
    bidirectional_links = create_bidirectional_links(doc_references, code_references)
    validation_results = validate_traceability(doc_references, code_references)
    orphaned_items = find_orphaned_items(doc_references, code_references)

    %{
      total_documentation_references: length(doc_references),
      total_code_references: length(code_references),
      successful_links: count_successful_links(bidirectional_links),
      traceability_score: validation_results.validation_score,
      orphaned_items: orphaned_items.orphaned_count,
      coverage_analysis: %{
        documentation_coverage: calculate_documentation_coverage(doc_references, bidirectional_links),
        code_coverage: calculate_code_coverage(code_references, bidirectional_links)
      }
    }
  end

  defp calculate_documentation_coverage(doc_references, bidirectional_links) do
    if length(doc_references) == 0 do
      0
    else
      linked_docs = length(bidirectional_links.explicit) + length(bidirectional_links.implicit)
      round((linked_docs / length(doc_references)) * 100)
    end
  end

  defp calculate_code_coverage(code_references, bidirectional_links) do
    if length(code_references) == 0 do
      0
    else
      linked_code = length(bidirectional_links.explicit) + length(bidirectional_links.implicit)
      round((linked_code / length(code_references)) * 100)
    end
  end

  # Validation helper functions

  defp count_total_links(markers) do
    markers.bidirectional_links.total_links
  end

  defp count_valid_links(markers) do
    markers.validation_results.successful_links
  end

  defp extract_broken_links(markers) do
    markers.orphaned_items.orphaned_documentation ++
    markers.orphaned_items.orphaned_code
  end

  defp calculate_validation_score(markers) do
    markers.validation_results.validation_score
  end

  defp generate_recommendations(markers) do
    recommendations = []

    # Add recommendations based on analysis
    recommendations = if markers.orphaned_items.orphaned_count > 0 do
      ["Review orphaned documentation and code for missing links" | recommendations]
    else
      recommendations
    end

    recommendations = if markers.validation_results.validation_score < 70 do
      ["Consider adding more explicit traceability markers" | recommendations]
    else
      recommendations
    end

    recommendations = if length(markers.missing_implementations) > 0 do
      ["Implement missing modules and functions referenced in documentation" | recommendations]
    else
      recommendations
    end

    Enum.reverse(recommendations)
  end
end
