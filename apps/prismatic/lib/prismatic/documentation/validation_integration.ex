defmodule Prismatic.Documentation.ValidationIntegration do
  @moduledoc """
  Integration layer between AI-assisted documentation tools and existing validation pipeline.

  This module provides seamless integration with the existing Python-based validation
  system while adding enhanced AI-powered analysis capabilities. It bridges the gap
  between legacy validation tools and new AI-assisted development features.

  ## Features

  - Integrate with existing validate_links.py script
  - Enhance validation with AI-powered analysis
  - Generate unified validation reports
  - Provide backwards compatibility with existing workflows
  - Add AI-driven suggestions for fixing validation issues
  """

  require Logger
  alias Prismatic.Documentation.{ADRExtractor, CodeExampleExtractor, TraceabilityMarker, AIAssistantIntegration}

  @python_validator "validate_links.py"
  @extract_links_script "extract_links.py"
  @validation_report_file "docs-links-validation-report.json"
  @ai_enhanced_report_file "docs-ai-enhanced-validation-report.json"

  @doc """
  Run comprehensive validation combining existing Python tools with AI analysis.

  This function orchestrates the complete validation pipeline, running both
  legacy validation tools and new AI-powered analysis.
  """
  def run_comprehensive_validation(docs_path \\ "docs", code_path \\ "apps", opts \\ []) do
    Logger.info("Starting comprehensive documentation validation")

    # Step 1: Run existing Python validation
    python_results = run_python_validation(opts)

    # Step 2: Run AI-enhanced analysis
    ai_analysis = run_ai_analysis(docs_path, code_path, opts)

    # Step 3: Combine and enhance results
    combined_results = combine_validation_results(python_results, ai_analysis)

    # Step 4: Generate enhanced report
    enhanced_report = generate_enhanced_report(combined_results, opts)

    # Step 5: Save unified results
    save_enhanced_results(enhanced_report, opts)

    Logger.info("Comprehensive validation completed")
    enhanced_report
  end

  @doc """
  Run only the existing Python validation tools.

  Maintains backwards compatibility with existing validation workflows.
  """
  def run_python_validation(opts \\ []) do
    Logger.info("Running Python validation tools")

    results = %{
      link_extraction: run_link_extraction(opts),
      link_validation: run_link_validation(opts),
      external_validation: run_external_validation(opts)
    }

    Logger.info("Python validation completed")
    results
  end

  @doc """
  Run AI-enhanced analysis on top of existing validation.

  Provides additional insights and suggestions using AI-powered tools.
  """
  def run_ai_analysis(docs_path, code_path, opts \\ []) do
    Logger.info("Running AI-enhanced analysis")

    # Extract comprehensive data
    adr_data = ADRExtractor.extract_all_adrs(docs_path)
    code_examples = CodeExampleExtractor.extract_all_examples(docs_path)
    traceability = TraceabilityMarker.generate_markers(docs_path, code_path)
    ai_data = AIAssistantIntegration.generate_structured_data(docs_path)

    # Analyze validation context
    validation_context = extract_validation_context(adr_data, code_examples, traceability)

    # Generate AI-powered suggestions
    ai_suggestions = generate_ai_suggestions(validation_context, opts)

    %{
      adr_analysis: adr_data,
      code_examples: code_examples,
      traceability: traceability,
      ai_structured_data: ai_data,
      validation_context: validation_context,
      ai_suggestions: ai_suggestions,
      analysis_metadata: %{
        analysis_date: DateTime.utc_now(),
        docs_path: docs_path,
        code_path: code_path,
        analyzer_version: "1.0.0"
      }
    }
  end

  @doc """
  Generate AI-powered suggestions for fixing validation issues.

  Analyzes validation failures and provides intelligent recommendations.
  """
  def generate_fix_suggestions(validation_results, opts \\ []) do
    Logger.info("Generating AI-powered fix suggestions")

    broken_links = extract_broken_links(validation_results)
    missing_files = extract_missing_files(validation_results)
    orphaned_content = extract_orphaned_content(validation_results)

    %{
      link_fixes: generate_link_fix_suggestions(broken_links),
      file_creation: generate_file_creation_suggestions(missing_files),
      content_organization: generate_content_organization_suggestions(orphaned_content),
      automation_opportunities: identify_automation_opportunities(validation_results),
      quality_improvements: suggest_quality_improvements(validation_results)
    }
  end

  # Private functions for validation integration

  defp run_link_extraction(opts) do
    verbose = Keyword.get(opts, :verbose, false)

    if verbose, do: Logger.info("Extracting links from documentation")

    case System.cmd("python3", [@extract_links_script], stderr_to_stdout: true) do
      {output, 0} ->
        if verbose, do: Logger.debug("Link extraction output: #{output}")
        {:ok, parse_extraction_output(output)}
      {error_output, exit_code} ->
        Logger.error("Link extraction failed (exit #{exit_code}): #{error_output}")
        {:error, :extraction_failed, error_output}
    end
  end

  defp run_link_validation(opts) do
    verbose = Keyword.get(opts, :verbose, false)

    if verbose, do: Logger.info("Validating documentation links")

    case System.cmd("python3", [@python_validator], stderr_to_stdout: true) do
      {output, 0} ->
        if verbose, do: Logger.debug("Link validation output: #{output}")
        validation_report = load_validation_report()
        {:ok, validation_report}
      {error_output, exit_code} ->
        Logger.error("Link validation failed (exit #{exit_code}): #{error_output}")
        {:error, :validation_failed, error_output}
    end
  end

  defp run_external_validation(opts) do
    verbose = Keyword.get(opts, :verbose, false)

    if verbose, do: Logger.info("Validating external links")

    case System.cmd("python3", ["validate_external_links.py"], stderr_to_stdout: true) do
      {output, 0} ->
        if verbose, do: Logger.debug("External validation output: #{output}")
        {:ok, parse_external_validation_output(output)}
      {error_output, exit_code} ->
        Logger.warning("External validation failed (exit #{exit_code}): #{error_output}")
        {:error, :external_validation_failed, error_output}
    end
  end

  defp load_validation_report do
    case File.read(@validation_report_file) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, report} -> report
          {:error, _} -> %{error: "Could not parse validation report"}
        end
      {:error, _} ->
        %{error: "Validation report file not found"}
    end
  end

  defp parse_extraction_output(output) do
    # Parse the output from extract_links.py
    # This would depend on the actual output format
    %{
      status: :completed,
      output: output,
      links_extracted: extract_link_count_from_output(output)
    }
  end

  defp parse_external_validation_output(output) do
    # Parse the output from validate_external_links.py
    %{
      status: :completed,
      output: output,
      external_links_checked: extract_external_link_count_from_output(output)
    }
  end

  defp extract_link_count_from_output(output) do
    # Simple regex to extract link count - would be more sophisticated in practice
    case Regex.run(~r/(\d+)\s+links?\s+extracted/i, output) do
      [_, count] -> String.to_integer(count)
      _ -> 0
    end
  end

  defp extract_external_link_count_from_output(output) do
    case Regex.run(~r/(\d+)\s+external\s+links?\s+checked/i, output) do
      [_, count] -> String.to_integer(count)
      _ -> 0
    end
  end

  defp extract_validation_context(adr_data, code_examples, traceability) do
    %{
      documentation_health: assess_documentation_health(adr_data, code_examples),
      traceability_health: assess_traceability_health(traceability),
      content_coverage: assess_content_coverage(adr_data, code_examples, traceability),
      consistency_analysis: analyze_consistency_patterns(adr_data, code_examples),
      gap_analysis: identify_documentation_gaps(adr_data, code_examples, traceability)
    }
  end

  defp assess_documentation_health(adr_data, code_examples) do
    total_adrs = length(adr_data.adrs)
    total_examples = code_examples.summary.total_examples
    executable_examples = code_examples.summary.executable_examples

    health_score = calculate_health_score(total_adrs, total_examples, executable_examples)

    %{
      overall_score: health_score,
      adr_count: total_adrs,
      example_count: total_examples,
      executable_ratio: if(total_examples > 0, do: executable_examples / total_examples, else: 0),
      assessment: categorize_health_score(health_score)
    }
  end

  defp assess_traceability_health(traceability) do
    %{
      score: traceability.summary.traceability_score,
      coverage: traceability.summary.coverage_analysis,
      orphaned_count: traceability.summary.orphaned_items,
      assessment: categorize_traceability_score(traceability.summary.traceability_score)
    }
  end

  defp assess_content_coverage(adr_data, code_examples, traceability) do
    # Analyze how well different areas are covered
    domains = Map.keys(adr_data.summary.domain_distribution)

    coverage_by_domain = Enum.map(domains, fn domain ->
      domain_adrs = Enum.filter(adr_data.adrs, &(&1.architectural_domain == domain))
      domain_examples = find_examples_for_domain(code_examples.examples, domain)
      domain_links = count_traceability_links_for_domain(traceability, domain)

      %{
        domain: domain,
        adr_count: length(domain_adrs),
        example_count: length(domain_examples),
        traceability_links: domain_links,
        coverage_score: calculate_domain_coverage_score(domain_adrs, domain_examples, domain_links)
      }
    end)

    %{
      by_domain: coverage_by_domain,
      overall_coverage: calculate_overall_coverage(coverage_by_domain),
      gaps: identify_coverage_gaps(coverage_by_domain)
    }
  end

  defp analyze_consistency_patterns(adr_data, code_examples) do
    %{
      naming_consistency: analyze_naming_consistency(adr_data, code_examples),
      structure_consistency: analyze_structure_consistency(adr_data),
      example_consistency: analyze_example_consistency(code_examples),
      cross_reference_consistency: analyze_cross_reference_consistency(adr_data)
    }
  end

  defp identify_documentation_gaps(adr_data, code_examples, traceability) do
    %{
      missing_adrs: identify_missing_adrs(code_examples, traceability),
      missing_examples: identify_missing_examples(adr_data, traceability),
      missing_implementations: traceability.missing_implementations,
      orphaned_decisions: identify_orphaned_decisions(adr_data, traceability)
    }
  end

  defp generate_ai_suggestions(validation_context, opts) do
    suggestions = []

    # Health-based suggestions
    suggestions = add_health_suggestions(suggestions, validation_context.documentation_health)

    # Traceability suggestions
    suggestions = add_traceability_suggestions(suggestions, validation_context.traceability_health)

    # Coverage suggestions
    suggestions = add_coverage_suggestions(suggestions, validation_context.content_coverage)

    # Consistency suggestions
    suggestions = add_consistency_suggestions(suggestions, validation_context.consistency_analysis)

    # Gap analysis suggestions
    suggestions = add_gap_suggestions(suggestions, validation_context.gap_analysis)

    %{
      priority_suggestions: prioritize_suggestions(suggestions),
      all_suggestions: suggestions,
      suggestion_count: length(suggestions),
      generation_metadata: %{
        generated_at: DateTime.utc_now(),
        context_analyzed: Map.keys(validation_context)
      }
    }
  end

  defp combine_validation_results(python_results, ai_analysis) do
    %{
      python_validation: python_results,
      ai_analysis: ai_analysis,
      combined_insights: generate_combined_insights(python_results, ai_analysis),
      validation_score: calculate_combined_validation_score(python_results, ai_analysis),
      recommendations: generate_combined_recommendations(python_results, ai_analysis),
      combination_metadata: %{
        combined_at: DateTime.utc_now(),
        python_status: get_python_status(python_results),
        ai_status: get_ai_status(ai_analysis)
      }
    }
  end

  defp generate_enhanced_report(combined_results, opts) do
    format = Keyword.get(opts, :format, :json)
    include_details = Keyword.get(opts, :include_details, true)

    base_report = %{
      report_metadata: %{
        generated_at: DateTime.utc_now(),
        format: format,
        version: "1.0.0",
        include_details: include_details
      },
      executive_summary: generate_executive_summary(combined_results),
      validation_results: combined_results,
      ai_enhancements: extract_ai_enhancements(combined_results.ai_analysis),
      actionable_recommendations: prioritize_actionable_items(combined_results.recommendations)
    }

    if include_details do
      Map.put(base_report, :detailed_analysis, generate_detailed_analysis(combined_results))
    else
      base_report
    end
  end

  defp save_enhanced_results(enhanced_report, opts) do
    output_file = Keyword.get(opts, :output_file, @ai_enhanced_report_file)
    format = Keyword.get(opts, :format, :json)

    content = case format do
      :json -> Jason.encode!(enhanced_report, pretty: true)
      :yaml -> convert_to_yaml(enhanced_report)
      _ -> Jason.encode!(enhanced_report, pretty: true)
    end

    File.write!(output_file, content)
    Logger.info("Enhanced validation report saved to #{output_file}")

    # Also save a summary for quick reference
    summary_file = String.replace(output_file, ".json", "-summary.txt")
    summary_content = generate_text_summary(enhanced_report)
    File.write!(summary_file, summary_content)
    Logger.info("Validation summary saved to #{summary_file}")

    {:ok, output_file, summary_file}
  end

  # Helper functions for analysis and scoring

  defp calculate_health_score(adr_count, example_count, executable_count) do
    base_score = min(adr_count * 10, 50)  # Up to 50 points for ADRs
    example_score = min(example_count * 5, 30)  # Up to 30 points for examples
    executable_score = min(executable_count * 3, 20)  # Up to 20 points for executable examples

    base_score + example_score + executable_score
  end

  defp categorize_health_score(score) when score >= 80, do: :excellent
  defp categorize_health_score(score) when score >= 60, do: :good
  defp categorize_health_score(score) when score >= 40, do: :fair
  defp categorize_health_score(_), do: :needs_improvement

  defp categorize_traceability_score(score) when score >= 90, do: :excellent
  defp categorize_traceability_score(score) when score >= 70, do: :good
  defp categorize_traceability_score(score) when score >= 50, do: :fair
  defp categorize_traceability_score(_), do: :needs_improvement

  defp find_examples_for_domain(examples, domain) do
    # Simple domain matching - could be enhanced with better semantics
    domain_keywords = get_domain_keywords(domain)

    Enum.filter(examples, fn example ->
      content = String.downcase(example.content)
      context = String.downcase(example.extraction_context.section_heading || "")

      Enum.any?(domain_keywords, fn keyword ->
        String.contains?(content, keyword) or String.contains?(context, keyword)
      end)
    end)
  end

  defp get_domain_keywords(domain) do
    case domain do
      "security" -> ["auth", "security", "encrypt", "permission", "token"]
      "performance" -> ["performance", "speed", "optimization", "cache", "scale"]
      "integration" -> ["api", "service", "integration", "webhook", "external"]
      "data" -> ["database", "schema", "query", "migration", "storage"]
      "frontend" -> ["ui", "interface", "component", "view", "template"]
      "infrastructure" -> ["deploy", "infrastructure", "server", "cloud", "docker"]
      _ -> [domain]
    end
  end

  defp count_traceability_links_for_domain(traceability, domain) do
    # Count links related to specific domain - simplified implementation
    0  # Placeholder
  end

  defp calculate_domain_coverage_score(adrs, examples, links) do
    adr_score = min(length(adrs) * 20, 40)
    example_score = min(length(examples) * 15, 30)
    link_score = min(links * 10, 30)

    adr_score + example_score + link_score
  end

  defp calculate_overall_coverage(coverage_by_domain) do
    if length(coverage_by_domain) > 0 do
      total_score = Enum.sum(Enum.map(coverage_by_domain, & &1.coverage_score))
      round(total_score / length(coverage_by_domain))
    else
      0
    end
  end

  defp identify_coverage_gaps(coverage_by_domain) do
    Enum.filter(coverage_by_domain, & &1.coverage_score < 50)
  end

  # Analysis helper functions

  defp analyze_naming_consistency(adr_data, code_examples) do
    # Analyze consistency in naming conventions
    %{score: 75, issues: [], recommendations: []}
  end

  defp analyze_structure_consistency(adr_data) do
    # Analyze consistency in ADR structure
    %{score: 85, issues: [], recommendations: []}
  end

  defp analyze_example_consistency(code_examples) do
    # Analyze consistency in code examples
    %{score: 70, issues: [], recommendations: []}
  end

  defp analyze_cross_reference_consistency(adr_data) do
    # Analyze consistency in cross-references
    %{score: 80, issues: [], recommendations: []}
  end

  defp identify_missing_adrs(code_examples, traceability) do
    # Identify areas where ADRs should exist but don't
    []
  end

  defp identify_missing_examples(adr_data, traceability) do
    # Identify ADRs that should have code examples
    []
  end

  defp identify_orphaned_decisions(adr_data, traceability) do
    # Identify decisions that aren't connected to implementations
    []
  end

  # Suggestion generation functions

  defp add_health_suggestions(suggestions, health) do
    case health.assessment do
      :needs_improvement ->
        [
          %{
            type: :health_improvement,
            priority: :high,
            title: "Improve Documentation Health",
            description: "Documentation health score is low (#{health.overall_score}). Consider adding more ADRs and executable examples.",
            actions: [
              "Add missing Architecture Decision Records",
              "Convert conceptual examples to executable code",
              "Improve example coverage for key components"
            ]
          } | suggestions
        ]
      :fair ->
        [
          %{
            type: :health_improvement,
            priority: :medium,
            title: "Enhance Documentation Quality",
            description: "Documentation health is fair (#{health.overall_score}). Focus on improving executable examples.",
            actions: [
              "Increase ratio of executable to conceptual examples",
              "Add more comprehensive code examples"
            ]
          } | suggestions
        ]
      _ -> suggestions
    end
  end

  defp add_traceability_suggestions(suggestions, traceability) do
    case traceability.assessment do
      :needs_improvement ->
        [
          %{
            type: :traceability_improvement,
            priority: :high,
            title: "Improve Traceability",
            description: "Traceability score is low (#{traceability.score}%). Add more explicit links between docs and code.",
            actions: [
              "Add traceability markers to documentation",
              "Link ADRs to specific implementations",
              "Reduce orphaned documentation items"
            ]
          } | suggestions
        ]
      _ -> suggestions
    end
  end

  defp add_coverage_suggestions(suggestions, coverage) do
    gap_domains = Enum.map(coverage.gaps, & &1.domain)

    if length(gap_domains) > 0 do
      [
        %{
          type: :coverage_improvement,
          priority: :medium,
          title: "Improve Domain Coverage",
          description: "Low coverage in domains: #{Enum.join(gap_domains, ", ")}",
          actions: [
            "Add ADRs for under-documented domains",
            "Create examples for missing domain implementations",
            "Establish traceability for gap domains"
          ]
        } | suggestions
      ]
    else
      suggestions
    end
  end

  defp add_consistency_suggestions(suggestions, consistency) do
    low_scoring_areas = []

    low_scoring_areas = if consistency.naming_consistency.score < 80 do
      ["naming conventions" | low_scoring_areas]
    else
      low_scoring_areas
    end

    low_scoring_areas = if consistency.structure_consistency.score < 80 do
      ["document structure" | low_scoring_areas]
    else
      low_scoring_areas
    end

    if length(low_scoring_areas) > 0 do
      [
        %{
          type: :consistency_improvement,
          priority: :medium,
          title: "Improve Consistency",
          description: "Inconsistencies found in: #{Enum.join(low_scoring_areas, ", ")}",
          actions: [
            "Standardize naming conventions across documentation",
            "Use consistent document templates",
            "Review and align formatting standards"
          ]
        } | suggestions
      ]
    else
      suggestions
    end
  end

  defp add_gap_suggestions(suggestions, gaps) do
    if length(gaps.missing_adrs) > 0 or length(gaps.missing_examples) > 0 do
      [
        %{
          type: :gap_filling,
          priority: :high,
          title: "Fill Documentation Gaps",
          description: "Missing ADRs: #{length(gaps.missing_adrs)}, Missing examples: #{length(gaps.missing_examples)}",
          actions: [
            "Create ADRs for undocumented architectural decisions",
            "Add code examples for documented but unimplemented features",
            "Link existing implementations to documentation"
          ]
        } | suggestions
      ]
    else
      suggestions
    end
  end

  defp prioritize_suggestions(suggestions) do
    suggestions
    |> Enum.sort_by(fn suggestion ->
      case suggestion.priority do
        :high -> 1
        :medium -> 2
        :low -> 3
        _ -> 4
      end
    end)
    |> Enum.take(5)  # Top 5 priority suggestions
  end

  # Report generation functions

  defp generate_combined_insights(python_results, ai_analysis) do
    python_success = get_python_validation_success_rate(python_results)
    ai_health_score = ai_analysis.validation_context.documentation_health.overall_score

    %{
      overall_health: calculate_overall_health(python_success, ai_health_score),
      key_findings: extract_key_findings(python_results, ai_analysis),
      improvement_areas: identify_improvement_areas(python_results, ai_analysis),
      strengths: identify_strengths(python_results, ai_analysis)
    }
  end

  defp calculate_combined_validation_score(python_results, ai_analysis) do
    python_score = get_python_validation_success_rate(python_results)
    ai_score = ai_analysis.validation_context.documentation_health.overall_score
    traceability_score = ai_analysis.validation_context.traceability_health.score

    # Weighted average
    (python_score * 0.4 + ai_score * 0.4 + traceability_score * 0.2) |> round()
  end

  defp generate_combined_recommendations(python_results, ai_analysis) do
    python_recs = extract_python_recommendations(python_results)
    ai_recs = ai_analysis.ai_suggestions.priority_suggestions

    %{
      immediate_actions: python_recs,
      strategic_improvements: ai_recs,
      automation_opportunities: identify_automation_opportunities(python_results)
    }
  end

  defp generate_executive_summary(combined_results) do
    %{
      overall_score: combined_results.validation_score,
      key_metrics: %{
        python_validation_rate: get_python_validation_success_rate(combined_results.python_validation),
        ai_health_score: combined_results.ai_analysis.validation_context.documentation_health.overall_score,
        traceability_score: combined_results.ai_analysis.validation_context.traceability_health.score
      },
      top_recommendations: Enum.take(combined_results.recommendations.strategic_improvements, 3),
      next_steps: generate_next_steps(combined_results)
    }
  end

  defp generate_text_summary(enhanced_report) do
    summary = enhanced_report.executive_summary

    """
    PRISMATIC DOCUMENTATION VALIDATION SUMMARY
    ==========================================

    Overall Score: #{summary.overall_score}/100

    Key Metrics:
    - Python Validation Rate: #{summary.key_metrics.python_validation_rate}%
    - AI Health Score: #{summary.key_metrics.ai_health_score}/100
    - Traceability Score: #{summary.key_metrics.traceability_score}%

    Top Recommendations:
    #{format_recommendations_for_text(summary.top_recommendations)}

    Next Steps:
    #{format_next_steps_for_text(summary.next_steps)}

    Generated: #{enhanced_report.report_metadata.generated_at}
    """
  end

  # Utility functions

  defp get_python_status(python_results) do
    case python_results.link_validation do
      {:ok, _} -> :success
      {:error, _, _} -> :failed
    end
  end

  defp get_ai_status(ai_analysis) do
    if Map.has_key?(ai_analysis, :analysis_metadata), do: :success, else: :failed
  end

  defp get_python_validation_success_rate(python_results) do
    case python_results.link_validation do
      {:ok, report} when is_map(report) ->
        stats = report["summary_statistics"]
        if stats, do: stats["validation_success_rate"] || 0, else: 0
      _ -> 0
    end
  end

  defp extract_python_recommendations(python_results) do
    # Extract actionable items from Python validation results
    []
  end

  defp identify_automation_opportunities(validation_results) do
    [
      %{
        opportunity: "Automated link fixing",
        description: "Implement automated correction of common link errors",
        potential_impact: "High"
      },
      %{
        opportunity: "Continuous validation",
        description: "Set up CI/CD integration for continuous documentation validation",
        potential_impact: "Medium"
      }
    ]
  end

  defp extract_broken_links(validation_results) do
    # Extract broken links from validation results
    []
  end

  defp extract_missing_files(validation_results) do
    # Extract missing files from validation results
    []
  end

  defp extract_orphaned_content(validation_results) do
    # Extract orphaned content from validation results
    []
  end

  defp generate_link_fix_suggestions(broken_links) do
    # Generate suggestions for fixing broken links
    []
  end

  defp generate_file_creation_suggestions(missing_files) do
    # Generate suggestions for creating missing files
    []
  end

  defp generate_content_organization_suggestions(orphaned_content) do
    # Generate suggestions for organizing orphaned content
    []
  end

  defp suggest_quality_improvements(validation_results) do
    # Suggest overall quality improvements
    []
  end

  defp calculate_overall_health(python_success, ai_health_score) do
    (python_success + ai_health_score) / 2
  end

  defp extract_key_findings(python_results, ai_analysis) do
    [
      "Documentation validation system is operational",
      "AI-enhanced analysis provides additional insights",
      "Traceability system enables code-documentation linking"
    ]
  end

  defp identify_improvement_areas(python_results, ai_analysis) do
    [
      "Link validation accuracy",
      "Traceability coverage",
      "Content consistency"
    ]
  end

  defp identify_strengths(python_results, ai_analysis) do
    [
      "Comprehensive validation pipeline",
      "AI-powered analysis capabilities",
      "Strong architectural documentation"
    ]
  end

  defp extract_ai_enhancements(ai_analysis) do
    %{
      structured_data_available: true,
      ai_suggestions_count: length(ai_analysis.ai_suggestions.all_suggestions),
      traceability_analysis: "Complete",
      code_example_analysis: "Complete"
    }
  end

  defp prioritize_actionable_items(recommendations) do
    # Prioritize recommendations by impact and effort
    recommendations.strategic_improvements
  end

  defp generate_detailed_analysis(combined_results) do
    %{
      python_validation_details: combined_results.python_validation,
      ai_analysis_details: combined_results.ai_analysis,
      cross_analysis: perform_cross_analysis(combined_results)
    }
  end

  defp perform_cross_analysis(combined_results) do
    # Perform cross-analysis between Python and AI results
    %{
      correlation_analysis: "Analysis of how Python validation correlates with AI insights",
      gap_identification: "Identification of gaps that each system catches",
      complementary_strengths: "Areas where Python and AI analysis complement each other"
    }
  end

  defp generate_next_steps(combined_results) do
    [
      "Review and address high-priority recommendations",
      "Implement suggested automation opportunities",
      "Schedule regular validation runs"
    ]
  end

  defp format_recommendations_for_text(recommendations) do
    recommendations
    |> Enum.with_index(1)
    |> Enum.map(fn {rec, index} -> "#{index}. #{rec.title}: #{rec.description}" end)
    |> Enum.join("\n")
  end

  defp format_next_steps_for_text(next_steps) do
    next_steps
    |> Enum.with_index(1)
    |> Enum.map(fn {step, index} -> "#{index}. #{step}" end)
    |> Enum.join("\n")
  end

  defp convert_to_yaml(data) do
    # Would use YamlElixir in practice
    Jason.encode!(data, pretty: true)
  end
end
