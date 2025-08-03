defmodule Prismatic.Documentation.ADRExtractor do
  @moduledoc """
  Architecture Decision Record (ADR) extraction and metadata system.

  This module provides comprehensive ADR parsing, metadata extraction,
  and structured data generation for AI-assisted development workflows.

  ## Features

  - Parse ADR files and extract structured metadata
  - Categorize decisions by architectural domain
  - Generate JSON/YAML output formats
  - Cross-reference related ADRs and documentation
  - Track decision lifecycle and status changes
  """

  require Logger

  @adr_pattern ~r/^adr-(\d+)-(.+)\.md$/i
  @status_pattern ~r/\*\*Status\*\*:\s*([^\s\*]+)/i
  @date_pattern ~r/\*\*Date\*\*:\s*(\d{4}-\d{2}-\d{2})/i
  @supersedes_pattern ~r/\*\*Supersedes\*\*:\s*([^\s\*]+)/i
  @superseded_by_pattern ~r/\*\*Superseded by\*\*:\s*([^\s\*]+)/i

  @doc """
  Extract all ADRs from the specified documentation directory.

  Returns a comprehensive structure with all ADR metadata and analysis.
  """
  def extract_all_adrs(docs_path) do
    Logger.info("Starting ADR extraction from #{docs_path}")

    adr_files = find_adr_files(docs_path)
    Logger.info("Found #{length(adr_files)} ADR files")

    adrs = Enum.map(adr_files, &extract_adr_metadata/1)

    %{
      summary: generate_summary(adrs),
      adrs: adrs,
      categorization: categorize_adrs(adrs),
      relationships: analyze_relationships(adrs),
      lifecycle: analyze_lifecycle(adrs),
      extraction_metadata: %{
        extraction_date: DateTime.utc_now(),
        total_adrs: length(adrs),
        docs_path: docs_path,
        extractor_version: "1.0.0"
      }
    }
  end

  @doc """
  Extract metadata from a single ADR file.

  Returns structured metadata including decision context, alternatives,
  consequences, and implementation details.
  """
  def extract_adr_metadata(file_path) do
    Logger.debug("Extracting metadata from #{file_path}")

    content = File.read!(file_path)

    %{
      file_path: file_path,
      decision_id: extract_decision_id(file_path),
      title: extract_title(content),
      status: extract_status(content),
      date: extract_date(content),
      authors: extract_authors(content),
      reviewers: extract_reviewers(content),
      supersedes: extract_supersedes(content),
      superseded_by: extract_superseded_by(content),
      summary: extract_summary(content),
      context: extract_context(content),
      decision: extract_decision(content),
      alternatives: extract_alternatives(content),
      consequences: extract_consequences(content),
      implementation: extract_implementation(content),
      related_decisions: extract_related_decisions(content),
      architectural_domain: categorize_domain(content),
      cross_references: extract_cross_references(content),
      code_references: extract_code_references(content),
      metadata: %{
        word_count: count_words(content),
        complexity_score: calculate_complexity_score(content),
        last_modified: get_file_modification_time(file_path),
        sections: extract_sections(content)
      }
    }
  end

  # Private functions for metadata extraction

  defp find_adr_files(docs_path) do
    docs_path
    |> Path.join("**/*.md")
    |> Path.wildcard()
    |> Enum.filter(&String.match?(Path.basename(&1), @adr_pattern))
    |> Enum.sort()
  end

  defp extract_decision_id(file_path) do
    case Regex.run(@adr_pattern, Path.basename(file_path)) do
      [_, id, _] -> String.to_integer(id)
      _ -> nil
    end
  end

  defp extract_title(content) do
    case Regex.run(~r/^#\s*(.+)$/m, content) do
      [_, title] -> String.trim(title)
      _ -> nil
    end
  end

  defp extract_status(content) do
    case Regex.run(@status_pattern, content) do
      [_, status] -> String.trim(status)
      _ -> "Unknown"
    end
  end

  defp extract_date(content) do
    case Regex.run(@date_pattern, content) do
      [_, date] -> Date.from_iso8601!(date)
      _ -> nil
    end
  end

  defp extract_authors(content) do
    case Regex.run(~r/\*\*Authors\*\*:\s*(.+)/i, content) do
      [_, authors] ->
        authors
        |> String.split([",", ";"])
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
      _ -> []
    end
  end

  defp extract_reviewers(content) do
    case Regex.run(~r/\*\*Reviewers\*\*:\s*(.+)/i, content) do
      [_, reviewers] ->
        reviewers
        |> String.split([",", ";"])
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
      _ -> []
    end
  end

  defp extract_supersedes(content) do
    case Regex.run(@supersedes_pattern, content) do
      [_, ref] when ref != "None" -> String.trim(ref)
      _ -> nil
    end
  end

  defp extract_superseded_by(content) do
    case Regex.run(@superseded_by_pattern, content) do
      [_, ref] when ref != "None" -> String.trim(ref)
      _ -> nil
    end
  end

  defp extract_summary(content) do
    extract_section_content(content, "Summary")
  end

  defp extract_context(content) do
    extract_section_content(content, "Context")
  end

  defp extract_decision(content) do
    extract_section_content(content, "Decision")
  end

  defp extract_alternatives(content) do
    content
    |> extract_section_content("Alternatives Considered")
    |> parse_alternatives()
  end

  defp extract_consequences(content) do
    %{
      positive: extract_subsection_content(content, "Positive Consequences"),
      negative: extract_subsection_content(content, "Negative Consequences"),
      mitigation: extract_subsection_content(content, "Mitigation Strategies")
    }
  end

  defp extract_implementation(content) do
    extract_section_content(content, ["Implementation", "Implementation Plan", "Implementation Guidelines"])
  end

  defp extract_related_decisions(content) do
    content
    |> extract_section_content(["Related Decisions", "Related ADRs"])
    |> parse_related_decisions()
  end

  defp extract_cross_references(content) do
    # Extract markdown links to other documentation
    Regex.scan(~r/\[([^\]]+)\]\(([^)]+\.md(?:#[^)]*)?)\)/, content)
    |> Enum.map(fn [_, text, link] -> %{text: text, link: link} end)
  end

  defp extract_code_references(content) do
    # Extract references to code files and modules
    code_patterns = [
      ~r/`([A-Z][a-zA-Z0-9._]*)`/,  # Module names
      ~r/\b([a-z_]+\.ex)\b/,        # Elixir files
      ~r/\b([a-z_]+\.exs)\b/,       # Elixir script files
      ~r/apps\/([a-z_]+)/           # App references
    ]

    Enum.flat_map(code_patterns, fn pattern ->
      Regex.scan(pattern, content)
      |> Enum.map(fn [_, match] -> match end)
    end)
    |> Enum.uniq()
  end

  defp extract_sections(content) do
    Regex.scan(~r/^(\#{1,6})\s*(.+)$/m, content)
    |> Enum.map(fn [_full_match, hashes, title] ->
      level = String.length(hashes)
      %{title: String.trim(title), level: level}
    end)
  end


  defp extract_section_content(content, section_names) when is_list(section_names) do
    Enum.find_value(section_names, fn name ->
      extract_section_content(content, name)
    end) || ""
  end

  defp extract_section_content(content, section_name) do
    pattern = ~r/\#{2,6}\s*#{Regex.escape(section_name)}\s*\n(.*?)(?=\n\#{2,6}|\z)/s
    case Regex.run(pattern, content) do
      [_, section_content] -> String.trim(section_content)
      _ -> ""
    end
  end

  defp extract_subsection_content(content, subsection_name) do
    pattern = ~r/\#{3,6}\s*#{Regex.escape(subsection_name)}\s*\n(.*?)(?=\n\#{2,6}|\z)/s
    case Regex.run(pattern, content) do
      [_, subsection_content] -> String.trim(subsection_content)
      _ -> ""
    end
  end

  defp parse_alternatives(alternatives_text) do
    # Parse alternatives section into structured data
    alternatives_text
    |> String.split(~r/###?\s*Alternative\s*\d+/i)
    |> Enum.drop(1)  # Remove content before first alternative
    |> Enum.with_index(1)
    |> Enum.map(fn {alt_text, index} ->
      parse_single_alternative(alt_text, index)
    end)
  end

  defp parse_single_alternative(alt_text, index) do
    %{
      index: index,
      name: extract_alternative_name(alt_text),
      description: extract_alternative_description(alt_text),
      pros: extract_alternative_pros(alt_text),
      cons: extract_alternative_cons(alt_text),
      rejection_reason: extract_rejection_reason(alt_text)
    }
  end

  defp extract_alternative_name(alt_text) do
    case Regex.run(~r/:\s*(.+)/, alt_text) do
      [_, name] -> String.trim(name)
      _ -> "Unnamed Alternative"
    end
  end

  defp extract_alternative_description(alt_text) do
    case Regex.run(~r/\*\*Description:\*\*\s*(.+?)(?=\*\*Pros:|\*\*Cons:|\z)/s, alt_text) do
      [_, desc] -> String.trim(desc)
      _ -> ""
    end
  end

  defp extract_alternative_pros(alt_text) do
    case Regex.run(~r/\*\*Pros:\*\*\s*(.*?)(?=\*\*Cons:|\*\*Why rejected:|\z)/s, alt_text) do
      [_, pros] -> parse_bullet_points(pros)
      _ -> []
    end
  end

  defp extract_alternative_cons(alt_text) do
    case Regex.run(~r/\*\*Cons:\*\*\s*(.*?)(?=\*\*Why rejected:|\z)/s, alt_text) do
      [_, cons] -> parse_bullet_points(cons)
      _ -> []
    end
  end

  defp extract_rejection_reason(alt_text) do
    case Regex.run(~r/\*\*Why rejected:\*\*\s*(.+)/s, alt_text) do
      [_, reason] -> String.trim(reason)
      _ -> ""
    end
  end

  defp parse_bullet_points(text) do
    text
    |> String.split(~r/\n\s*[-*]\s*/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_related_decisions(related_text) do
    # Extract ADR references from related decisions section
    Regex.scan(~r/ADR-(\d+)[:\s]*([^\n]*)/i, related_text)
    |> Enum.map(fn [_, id, description] ->
      %{id: String.to_integer(id), description: String.trim(description)}
    end)
  end

  defp categorize_domain(content) do
    content_lower = String.downcase(content)

    cond do
      String.contains?(content_lower, ["security", "authentication", "authorization", "encryption"]) ->
        "security"
      String.contains?(content_lower, ["performance", "scaling", "optimization", "cache"]) ->
        "performance"
      String.contains?(content_lower, ["integration", "api", "service", "microservice"]) ->
        "integration"
      String.contains?(content_lower, ["database", "storage", "persistence", "schema"]) ->
        "data"
      String.contains?(content_lower, ["ui", "frontend", "user interface", "experience"]) ->
        "frontend"
      String.contains?(content_lower, ["infrastructure", "deployment", "devops", "cloud"]) ->
        "infrastructure"
      String.contains?(content_lower, ["architecture", "structure", "organization", "module"]) ->
        "architecture"
      true ->
        "general"
    end
  end

  defp count_words(content) do
    content
    |> String.split(~r/\s+/)
    |> length()
  end

  defp calculate_complexity_score(content) do
    # Simple complexity scoring based on various factors
    base_score = count_words(content) / 100

    # Add complexity for alternatives
    alternatives_bonus = length(Regex.scan(~r/###?\s*Alternative/i, content)) * 10

    # Add complexity for consequences
    consequences_bonus = if String.contains?(content, ["Positive Consequences", "Negative Consequences"]), do: 15, else: 0

    # Add complexity for implementation details
    implementation_bonus = if String.contains?(content, ["Implementation", "Phase"]), do: 10, else: 0

    round(base_score + alternatives_bonus + consequences_bonus + implementation_bonus)
  end

  defp get_file_modification_time(file_path) do
    case File.stat(file_path) do
      {:ok, %{mtime: mtime}} ->
        mtime
        |> NaiveDateTime.from_erl!()
        |> DateTime.from_naive!("Etc/UTC")
      _ -> DateTime.utc_now()
    end
  end

  defp generate_summary(adrs) do
    total_count = length(adrs)
    status_counts = count_by_status(adrs)
    domain_counts = count_by_domain(adrs)

    %{
      total_adrs: total_count,
      status_distribution: status_counts,
      domain_distribution: domain_counts,
      average_complexity: calculate_average_complexity(adrs),
      decision_timeline: generate_timeline(adrs)
    }
  end

  defp count_by_status(adrs) do
    adrs
    |> Enum.group_by(& &1.status)
    |> Enum.map(fn {status, adrs} -> {status, length(adrs)} end)
    |> Enum.into(%{})
  end

  defp count_by_domain(adrs) do
    adrs
    |> Enum.group_by(& &1.architectural_domain)
    |> Enum.map(fn {domain, adrs} -> {domain, length(adrs)} end)
    |> Enum.into(%{})
  end

  defp calculate_average_complexity(adrs) do
    if length(adrs) > 0 do
      total_complexity = Enum.sum(Enum.map(adrs, & &1.metadata.complexity_score))
      round(total_complexity / length(adrs))
    else
      0
    end
  end

  defp generate_timeline(adrs) do
    adrs
    |> Enum.filter(& &1.date)
    |> Enum.sort_by(& &1.date, Date)
    |> Enum.map(fn adr ->
      %{
        date: adr.date,
        decision_id: adr.decision_id,
        title: adr.title,
        status: adr.status
      }
    end)
  end

  defp categorize_adrs(adrs) do
    %{
      by_domain: Enum.group_by(adrs, & &1.architectural_domain),
      by_status: Enum.group_by(adrs, & &1.status),
      by_complexity: categorize_by_complexity(adrs)
    }
  end

  defp categorize_by_complexity(adrs) do
    %{
      low: Enum.filter(adrs, & &1.metadata.complexity_score < 30),
      medium: Enum.filter(adrs, & &1.metadata.complexity_score >= 30 and &1.metadata.complexity_score < 60),
      high: Enum.filter(adrs, & &1.metadata.complexity_score >= 60)
    }
  end

  defp analyze_relationships(adrs) do
    # Build relationship graph
    relationships = Enum.flat_map(adrs, fn adr ->
      supersedes_relationships(adr) ++ related_relationships(adr)
    end)

    %{
      supersession_chain: build_supersession_chain(adrs),
      related_clusters: find_related_clusters(relationships),
      orphaned_decisions: find_orphaned_decisions(adrs, relationships)
    }
  end

  defp supersedes_relationships(adr) do
    cond do
      adr.supersedes -> [%{from: adr.decision_id, to: extract_adr_id(adr.supersedes), type: :supersedes}]
      adr.superseded_by -> [%{from: extract_adr_id(adr.superseded_by), to: adr.decision_id, type: :supersedes}]
      true -> []
    end
  end

  defp related_relationships(adr) do
    Enum.map(adr.related_decisions, fn related ->
      %{from: adr.decision_id, to: related.id, type: :related}
    end)
  end

  defp extract_adr_id(adr_reference) do
    case Regex.run(~r/ADR-(\d+)/i, adr_reference) do
      [_, id] -> String.to_integer(id)
      _ -> nil
    end
  end

  defp build_supersession_chain(adrs) do
    # Build chains of superseded decisions
    supersession_pairs =
      adrs
      |> Enum.filter(& &1.supersedes)
      |> Enum.map(fn adr -> {extract_adr_id(adr.supersedes), adr.decision_id} end)
      |> Enum.reject(fn {old_id, _} -> is_nil(old_id) end)

    build_chains(supersession_pairs)
  end

  defp build_chains(pairs) do
    # Simple chain building - could be enhanced for complex graphs
    pairs
    |> Enum.group_by(fn {old_id, _} -> old_id end)
    |> Enum.map(fn {_, chain_pairs} ->
      Enum.map(chain_pairs, fn {old_id, new_id} -> %{superseded: old_id, supersedes: new_id} end)
    end)
  end

  defp find_related_clusters(relationships) do
    # Group related ADRs into clusters
    relationships
    |> Enum.filter(& &1.type == :related)
    |> Enum.group_by(& &1.from)
    |> Enum.map(fn {adr_id, relations} ->
      %{
        primary_adr: adr_id,
        related_adrs: Enum.map(relations, & &1.to)
      }
    end)
  end

  defp find_orphaned_decisions(adrs, relationships) do
    # Find ADRs with no relationships
    connected_ids =
      relationships
      |> Enum.flat_map(fn rel -> [rel.from, rel.to] end)
      |> Enum.uniq()

    adrs
    |> Enum.reject(fn adr -> adr.decision_id in connected_ids end)
    |> Enum.map(& &1.decision_id)
  end

  defp analyze_lifecycle(adrs) do
    %{
      active_decisions: Enum.filter(adrs, & &1.status == "Accepted"),
      deprecated_decisions: Enum.filter(adrs, & &1.status in ["Deprecated", "Superseded"]),
      proposed_decisions: Enum.filter(adrs, & &1.status == "Proposed"),
      lifecycle_metrics: calculate_lifecycle_metrics(adrs)
    }
  end

  defp calculate_lifecycle_metrics(adrs) do
    dates =
      adrs
      |> Enum.filter(& &1.date)
      |> Enum.map(& &1.date)
      |> Enum.sort(Date)

    %{
      decision_velocity: calculate_decision_velocity(dates),
      avg_time_to_acceptance: calculate_avg_time_to_acceptance(adrs),
      oldest_decision: List.first(dates),
      newest_decision: List.last(dates)
    }
  end

  defp calculate_decision_velocity(dates) when length(dates) > 1 do
    first_date = List.first(dates)
    last_date = List.last(dates)
    days_span = Date.diff(last_date, first_date)

    if days_span > 0 do
      length(dates) / (days_span / 30)  # Decisions per month
    else
      0
    end
  end

  defp calculate_decision_velocity(_), do: 0

  defp calculate_avg_time_to_acceptance(_adrs) do
    # This would require tracking proposal -> acceptance timeline
    # For now, return a placeholder
    0
  end
end
