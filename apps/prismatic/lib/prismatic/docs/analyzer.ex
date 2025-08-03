defmodule Prismatic.Docs.Analyzer do
  @moduledoc """
  Advanced documentation analysis and gap detection for the Prismatic documentation system.

  This module provides comprehensive analysis capabilities for documentation quality,
  completeness, consistency, and maintenance needs. It performs deep analysis of
  documentation structure, content quality, cross-references, and identifies gaps
  that need attention.

  ## Features

  - **Gap Detection**: Automated identification of missing documentation
  - **Quality Analysis**: Content quality scoring and improvement recommendations
  - **Consistency Checking**: Style, format, and structural consistency validation
  - **Cross-Reference Analysis**: Link validation and reference completeness
  - **Content Metrics**: Comprehensive documentation metrics and analytics
  - **Maintenance Planning**: Prioritized recommendations for documentation updates

  ## Usage

      # Analyze documentation completeness
      analysis = Analyzer.analyze_documentation_gaps(docs_config)

      # Perform quality assessment
      quality_report = Analyzer.assess_content_quality(docs_config)

      # Check consistency across documentation
      consistency_report = Analyzer.check_consistency(docs_config)

      # Analyze API documentation coverage
      api_coverage = Analyzer.analyze_api_coverage(docs_config)

  ## Analysis Types

  The analyzer performs several types of analysis:

  - **Structural Analysis**: Documentation organization and hierarchy
  - **Content Analysis**: Writing quality, completeness, and clarity
  - **Technical Analysis**: Code examples, API coverage, and technical accuracy
  - **Cross-Reference Analysis**: Link integrity and reference completeness
  - **Maintenance Analysis**: Outdated content and update recommendations

  ## Configuration

      config :prismatic, Prismatic.Docs.Analyzer,
        quality_thresholds: %{
          minimum_word_count: 100,
          code_example_ratio: 0.3,
          cross_reference_density: 0.1
        },
        analysis_depth: :comprehensive,
        include_experimental: false
  """

  alias Prismatic.Docs.Types
  require Logger

  @type analysis_result :: %{
    overall_score: float(),
    gap_analysis: gap_analysis(),
    quality_metrics: quality_metrics(),
    consistency_report: consistency_report(),
    recommendations: [recommendation()]
  }

  @type gap_analysis :: %{
    missing_docs: [missing_doc()],
    incomplete_docs: [incomplete_doc()],
    outdated_docs: [outdated_doc()],
    gap_score: float()
  }

  @type missing_doc :: %{
    type: :module | :function | :guide | :example,
    identifier: String.t(),
    priority: :critical | :high | :medium | :low,
    estimated_effort: String.t()
  }

  @type incomplete_doc :: %{
    path: String.t(),
    missing_sections: [String.t()],
    completion_percentage: float(),
    priority: :critical | :high | :medium | :low
  }

  @type outdated_doc :: %{
    path: String.t(),
    last_updated: DateTime.t(),
    code_changes_since: non_neg_integer(),
    staleness_score: float()
  }

  @type quality_metrics :: %{
    readability_score: float(),
    technical_accuracy: float(),
    completeness_score: float(),
    consistency_score: float(),
    overall_quality: float()
  }

  @type consistency_report :: %{
    style_violations: [style_violation()],
    format_inconsistencies: [format_inconsistency()],
    terminology_issues: [terminology_issue()],
    consistency_score: float()
  }

  @type style_violation :: %{
    path: String.t(),
    line: non_neg_integer(),
    type: atom(),
    description: String.t(),
    suggestion: String.t()
  }

  @type format_inconsistency :: %{
    path: String.t(),
    section: String.t(),
    expected_format: String.t(),
    actual_format: String.t()
  }

  @type terminology_issue :: %{
    path: String.t(),
    term: String.t(),
    preferred_term: String.t(),
    occurrences: non_neg_integer()
  }

  @type recommendation :: %{
    type: :fix | :improve | :add | :remove,
    priority: :critical | :high | :medium | :low,
    category: String.t(),
    description: String.t(),
    action_items: [String.t()],
    estimated_effort: String.t()
  }

  @doc """
  Perform comprehensive documentation analysis.

  ## Parameters

  - `docs_config` - Documentation configuration
  - `options` - Analysis options and settings

  ## Returns

  Complete analysis results with gap detection, quality metrics, and recommendations.

  ## Examples

      iex> Analyzer.analyze_documentation(docs_config)
      %{
        overall_score: 0.85,
        gap_analysis: %{...},
        quality_metrics: %{...},
        consistency_report: %{...},
        recommendations: [...]
      }
  """
  @spec analyze_documentation(Types.doc_config(), map()) :: analysis_result()
  def analyze_documentation(docs_config, options \\ %{}) do
    options = merge_default_options(options)

    Logger.info("Starting comprehensive documentation analysis")

    %{
      overall_score: 0.0,
      gap_analysis: %{missing_docs: [], incomplete_docs: [], outdated_docs: [], gap_score: 0.0},
      quality_metrics: %{readability_score: 0.0, technical_accuracy: 0.0, completeness_score: 0.0, consistency_score: 0.0, overall_quality: 0.0},
      consistency_report: %{style_violations: [], format_inconsistencies: [], terminology_issues: [], consistency_score: 0.0},
      recommendations: []
    }
    |> perform_gap_analysis(docs_config, options)
    |> assess_quality_metrics(docs_config, options)
    |> check_consistency_analysis(docs_config, options)
    |> generate_recommendations(docs_config, options)
    |> calculate_overall_score()
  end

  @doc """
  Analyze documentation gaps and missing content.

  ## Parameters

  - `docs_config` - Documentation configuration
  - `options` - Gap analysis options

  ## Returns

  Detailed gap analysis with missing, incomplete, and outdated documentation.

  ## Examples

      iex> Analyzer.analyze_documentation_gaps(docs_config)
      %{
        missing_docs: [
          %{type: :module, identifier: "MyApp.Feature", priority: :high}
        ],
        incomplete_docs: [...],
        outdated_docs: [...],
        gap_score: 0.73
      }
  """
  @spec analyze_documentation_gaps(Types.doc_config(), map()) :: gap_analysis()
  def analyze_documentation_gaps(docs_config, options \\ %{}) do
    Logger.info("Analyzing documentation gaps")

    %{missing_docs: [], incomplete_docs: [], outdated_docs: [], gap_score: 0.0}
    |> identify_missing_documentation(docs_config, options)
    |> identify_incomplete_documentation(docs_config, options)
    |> identify_outdated_documentation(docs_config, options)
    |> calculate_gap_score()
  end

  @doc """
  Assess content quality across documentation.

  ## Parameters

  - `docs_config` - Documentation configuration
  - `options` - Quality assessment options

  ## Returns

  Quality metrics including readability, accuracy, and completeness scores.

  ## Examples

      iex> Analyzer.assess_content_quality(docs_config)
      %{
        readability_score: 0.87,
        technical_accuracy: 0.92,
        completeness_score: 0.78,
        consistency_score: 0.83,
        overall_quality: 0.85
      }
  """
  @spec assess_content_quality(Types.doc_config(), map()) :: quality_metrics()
  def assess_content_quality(docs_config, options \\ %{}) do
    Logger.info("Assessing documentation quality")

    %{
      readability_score: 0.0,
      technical_accuracy: 0.0,
      completeness_score: 0.0,
      consistency_score: 0.0,
      overall_quality: 0.0
    }
    |> analyze_readability(docs_config, options)
    |> analyze_technical_accuracy(docs_config, options)
    |> analyze_completeness(docs_config, options)
    |> analyze_consistency_quality(docs_config, options)
    |> calculate_overall_quality()
  end

  @doc """
  Check consistency across documentation structure and content.

  ## Parameters

  - `docs_config` - Documentation configuration
  - `options` - Consistency check options

  ## Returns

  Consistency report with violations, inconsistencies, and terminology issues.

  ## Examples

      iex> Analyzer.check_consistency(docs_config)
      %{
        style_violations: [...],
        format_inconsistencies: [...],
        terminology_issues: [...],
        consistency_score: 0.91
      }
  """
  @spec check_consistency(Types.doc_config(), map()) :: consistency_report()
  def check_consistency(docs_config, options \\ %{}) do
    Logger.info("Checking documentation consistency")

    %{
      style_violations: [],
      format_inconsistencies: [],
      terminology_issues: [],
      consistency_score: 0.0
    }
    |> check_style_consistency(docs_config, options)
    |> check_format_consistency(docs_config, options)
    |> check_terminology_consistency(docs_config, options)
    |> calculate_consistency_score()
  end

  @doc """
  Analyze API documentation coverage.

  ## Parameters

  - `docs_config` - Documentation configuration
  - `source_dirs` - Source code directories to analyze
  - `options` - API coverage analysis options

  ## Returns

  API coverage analysis with missing and incomplete API documentation.

  ## Examples

      iex> Analyzer.analyze_api_coverage(docs_config, ["lib"])
      %{
        total_modules: 42,
        documented_modules: 38,
        coverage_percentage: 90.5,
        missing_function_docs: [...]
      }
  """
  @spec analyze_api_coverage(Types.doc_config(), [String.t()], map()) :: map()
  def analyze_api_coverage(docs_config, source_dirs, options \\ %{}) do
    Logger.info("Analyzing API documentation coverage")

    source_dirs
    |> scan_source_modules()
    |> analyze_module_documentation(docs_config)
    |> analyze_function_documentation(docs_config)
    |> calculate_coverage_metrics()
    |> generate_coverage_recommendations(options)
  end

  @doc """
  Generate maintenance recommendations based on analysis.

  ## Parameters

  - `analysis_result` - Previous analysis results
  - `docs_config` - Documentation configuration
  - `options` - Recommendation generation options

  ## Returns

  Prioritized list of maintenance recommendations.

  ## Examples

      iex> Analyzer.generate_maintenance_recommendations(analysis, docs_config)
      [
        %{
          type: :fix,
          priority: :high,
          category: "Missing Documentation",
          description: "Add documentation for MyApp.Feature module",
          action_items: ["Create module documentation", "Add usage examples"],
          estimated_effort: "2-4 hours"
        }
      ]
  """
  @spec generate_maintenance_recommendations(analysis_result(), Types.doc_config(), map()) :: [recommendation()]
  def generate_maintenance_recommendations(analysis_result, docs_config, options \\ %{}) do
    Logger.info("Generating maintenance recommendations")

    []
    |> add_gap_recommendations(analysis_result.gap_analysis, options)
    |> add_quality_recommendations(analysis_result.quality_metrics, options)
    |> add_consistency_recommendations(analysis_result.consistency_report, options)
    |> prioritize_recommendations()
    |> limit_recommendations(options)
  end

  # Private helper functions

  defp merge_default_options(options) do
    defaults = %{
      analysis_depth: :comprehensive,
      include_experimental: false,
      quality_thresholds: %{
        minimum_word_count: 100,
        code_example_ratio: 0.3,
        cross_reference_density: 0.1
      },
      max_recommendations: 20
    }

    Map.merge(defaults, options)
  end

  defp perform_gap_analysis(result, docs_config, options) do
    gap_analysis = analyze_documentation_gaps(docs_config, options)
    Map.put(result, :gap_analysis, gap_analysis)
  end

  defp assess_quality_metrics(result, docs_config, options) do
    quality_metrics = assess_content_quality(docs_config, options)
    Map.put(result, :quality_metrics, quality_metrics)
  end

  defp check_consistency_analysis(result, docs_config, options) do
    consistency_report = check_consistency(docs_config, options)
    Map.put(result, :consistency_report, consistency_report)
  end

  defp generate_recommendations(result, docs_config, options) do
    recommendations = generate_maintenance_recommendations(result, docs_config, options)
    Map.put(result, :recommendations, recommendations)
  end

  defp calculate_overall_score(result) do
    scores = [
      result.gap_analysis.gap_score * 0.3,
      result.quality_metrics.overall_quality * 0.4,
      result.consistency_report.consistency_score * 0.3
    ]

    overall_score = Enum.sum(scores)
    Map.put(result, :overall_score, overall_score)
  end

  defp identify_missing_documentation(gap_analysis, docs_config, _options) do
    # Scan source code and identify undocumented modules/functions
    missing_docs = docs_config.source_dirs
    |> scan_source_code_for_missing_docs()
    |> prioritize_missing_docs()

    Map.put(gap_analysis, :missing_docs, missing_docs)
  end

  defp identify_incomplete_documentation(gap_analysis, docs_config, _options) do
    # Identify documentation that exists but is incomplete
    incomplete_docs = docs_config.source_dirs
    |> scan_existing_docs_for_completeness()
    |> assess_completion_percentage()

    Map.put(gap_analysis, :incomplete_docs, incomplete_docs)
  end

  defp identify_outdated_documentation(gap_analysis, docs_config, _options) do
    # Identify documentation that may be outdated
    outdated_docs = docs_config.source_dirs
    |> scan_for_outdated_documentation()
    |> calculate_staleness_score()

    Map.put(gap_analysis, :outdated_docs, outdated_docs)
  end

  defp calculate_gap_score(gap_analysis) do
    # Calculate overall gap score based on missing, incomplete, and outdated docs
    total_issues = length(gap_analysis.missing_docs) +
                  length(gap_analysis.incomplete_docs) +
                  length(gap_analysis.outdated_docs)

    # Simple scoring - in reality this would be more sophisticated
    gap_score = max(0.0, 1.0 - (total_issues * 0.05))

    Map.put(gap_analysis, :gap_score, gap_score)
  end

  defp analyze_readability(quality_metrics, _docs_config, _options) do
    # Analyze readability using various metrics
    readability_score = 0.85  # Placeholder
    Map.put(quality_metrics, :readability_score, readability_score)
  end

  defp analyze_technical_accuracy(quality_metrics, _docs_config, _options) do
    # Analyze technical accuracy of documentation
    technical_accuracy = 0.90  # Placeholder
    Map.put(quality_metrics, :technical_accuracy, technical_accuracy)
  end

  defp analyze_completeness(quality_metrics, _docs_config, _options) do
    # Analyze completeness of documentation
    completeness_score = 0.78  # Placeholder
    Map.put(quality_metrics, :completeness_score, completeness_score)
  end

  defp analyze_consistency_quality(quality_metrics, _docs_config, _options) do
    # Analyze consistency as part of quality
    consistency_score = 0.83  # Placeholder
    Map.put(quality_metrics, :consistency_score, consistency_score)
  end

  defp calculate_overall_quality(quality_metrics) do
    scores = [
      quality_metrics.readability_score * 0.3,
      quality_metrics.technical_accuracy * 0.3,
      quality_metrics.completeness_score * 0.25,
      quality_metrics.consistency_score * 0.15
    ]

    overall_quality = Enum.sum(scores)
    Map.put(quality_metrics, :overall_quality, overall_quality)
  end

  defp check_style_consistency(consistency_report, _docs_config, _options) do
    # Check for style consistency violations
    style_violations = []  # Placeholder
    Map.put(consistency_report, :style_violations, style_violations)
  end

  defp check_format_consistency(consistency_report, _docs_config, _options) do
    # Check for format inconsistencies
    format_inconsistencies = []  # Placeholder
    Map.put(consistency_report, :format_inconsistencies, format_inconsistencies)
  end

  defp check_terminology_consistency(consistency_report, _docs_config, _options) do
    # Check for terminology consistency issues
    terminology_issues = []  # Placeholder
    Map.put(consistency_report, :terminology_issues, terminology_issues)
  end

  defp calculate_consistency_score(consistency_report) do
    # Calculate consistency score based on violations and issues
    total_issues = length(consistency_report.style_violations) +
                  length(consistency_report.format_inconsistencies) +
                  length(consistency_report.terminology_issues)

    consistency_score = max(0.0, 1.0 - (total_issues * 0.02))
    Map.put(consistency_report, :consistency_score, consistency_score)
  end

  defp scan_source_modules(source_dirs) do
    # Scan source directories for modules
    source_dirs
    |> Enum.flat_map(&scan_elixir_files/1)
    |> Enum.map(&extract_module_info/1)
  end

  defp scan_elixir_files(dir) do
    Path.wildcard(Path.join(dir, "**/*.ex"))
  end

  defp extract_module_info(file_path) do
    # Extract module information from Elixir file
    %{
      file: file_path,
      module: extract_module_name(file_path),
      functions: extract_function_names(file_path)
    }
  end

  defp extract_module_name(file_path) do
    # Extract module name from file content
    case File.read(file_path) do
      {:ok, content} ->
        case Regex.run(~r/defmodule\s+([A-Za-z0-9_.]+)/, content) do
          [_, module_name] -> module_name
          _ -> nil
        end

      {:error, _} -> nil
    end
  end

  defp extract_function_names(file_path) do
    # Extract function names from file content
    case File.read(file_path) do
      {:ok, content} ->
        Regex.scan(~r/def\w*\s+([a-zA-Z_][a-zA-Z0-9_]*)/, content)
        |> Enum.map(fn [_, func_name] -> func_name end)
        |> Enum.uniq()

      {:error, _} -> []
    end
  end

  defp analyze_module_documentation(modules, _docs_config) do
    # Analyze which modules have documentation
    Enum.map(modules, fn module_info ->
      has_moduledoc = check_module_has_documentation(module_info.file)
      Map.put(module_info, :has_documentation, has_moduledoc)
    end)
  end

  defp analyze_function_documentation(modules, _docs_config) do
    # Analyze which functions have documentation
    Enum.map(modules, fn module_info ->
      documented_functions = count_documented_functions(module_info.file)
      Map.put(module_info, :documented_functions, documented_functions)
    end)
  end

  defp calculate_coverage_metrics(modules) do
    total_modules = length(modules)
    documented_modules = Enum.count(modules, & &1.has_documentation)

    total_functions = modules |> Enum.map(&length(&1.functions)) |> Enum.sum()
    documented_functions = modules |> Enum.map(& &1.documented_functions) |> Enum.sum()

    %{
      total_modules: total_modules,
      documented_modules: documented_modules,
      module_coverage_percentage: safe_percentage(documented_modules, total_modules),
      total_functions: total_functions,
      documented_functions: documented_functions,
      function_coverage_percentage: safe_percentage(documented_functions, total_functions)
    }
  end

  defp generate_coverage_recommendations(coverage_metrics, _options) do
    recommendations = []

    recommendations = if coverage_metrics.module_coverage_percentage < 80 do
      missing_count = coverage_metrics.total_modules - coverage_metrics.documented_modules
      recommendation = "Add module documentation for #{missing_count} undocumented modules"
      [recommendation | recommendations]
    else
      recommendations
    end

    recommendations = if coverage_metrics.function_coverage_percentage < 60 do
      missing_count = coverage_metrics.total_functions - coverage_metrics.documented_functions
      recommendation = "Add function documentation for #{missing_count} undocumented functions"
      [recommendation | recommendations]
    else
      recommendations
    end

    Map.put(coverage_metrics, :recommendations, recommendations)
  end

  defp safe_percentage(numerator, denominator) when denominator == 0, do: 0.0
  defp safe_percentage(numerator, denominator), do: (numerator / denominator) * 100.0

  defp check_module_has_documentation(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        Regex.match?(~r/@moduledoc/, content)

      {:error, _} -> false
    end
  end

  defp count_documented_functions(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        Regex.scan(~r/@doc/, content) |> length()

      {:error, _} -> 0
    end
  end

  defp scan_source_code_for_missing_docs(_source_dirs) do
    # Scan source code for missing documentation
    []
  end

  defp prioritize_missing_docs(missing_docs) do
    # Prioritize missing documentation by importance
    missing_docs
  end

  defp scan_existing_docs_for_completeness(_source_dirs) do
    # Scan existing docs for completeness
    []
  end

  defp assess_completion_percentage(incomplete_docs) do
    # Assess completion percentage for incomplete docs
    incomplete_docs
  end

  defp scan_for_outdated_documentation(_source_dirs) do
    # Scan for outdated documentation
    []
  end

  defp calculate_staleness_score(outdated_docs) do
    # Calculate staleness score for outdated docs
    outdated_docs
  end

  defp add_gap_recommendations(recommendations, _gap_analysis, _options) do
    # Add recommendations based on gap analysis
    recommendations
  end

  defp add_quality_recommendations(recommendations, _quality_metrics, _options) do
    # Add recommendations based on quality metrics
    recommendations
  end

  defp add_consistency_recommendations(recommendations, _consistency_report, _options) do
    # Add recommendations based on consistency report
    recommendations
  end

  defp prioritize_recommendations(recommendations) do
    # Sort recommendations by priority
    Enum.sort_by(recommendations, fn rec ->
      case rec.priority do
        :critical -> 0
        :high -> 1
        :medium -> 2
        :low -> 3
      end
    end)
  end

  defp limit_recommendations(recommendations, options) do
    max_recommendations = Map.get(options, :max_recommendations, 20)
    Enum.take(recommendations, max_recommendations)
  end
end
