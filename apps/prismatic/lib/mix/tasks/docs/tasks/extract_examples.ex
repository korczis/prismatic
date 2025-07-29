defmodule Mix.Tasks.Docs.Tasks.ExtractExamples do
  @moduledoc """
  Enterprise code example extraction and analysis toolkit.

  Advanced system for discovering, extracting, categorizing, and analyzing code
  examples across documentation systems. Provides executable code detection,
  transformation analysis, and quality metrics for documentation maintenance.

  ## Features

  ### Example Discovery
  - Multi-language code block detection (Elixir, JavaScript, SQL, Bash, etc.)
  - Inline code snippet extraction
  - Example metadata inference from context
  - Automatic language detection and validation

  ### Classification System
  - **Executable Examples**: Complete, runnable code snippets
  - **Conceptual Examples**: Illustrative code for understanding
  - **Configuration Examples**: Settings and configuration snippets
  - **API Examples**: HTTP requests, responses, and usage patterns

  ### Quality Analysis
  - Syntax validation for extracted code
  - Completeness scoring for executable examples
  - Transformation feasibility analysis
  - Documentation coverage metrics

  ## Options

    * `--docs PATH` - Documentation directory (default: docs)
    * `--language LANG` - Filter by programming language (comma-separated)
    * `--type TYPE` - Filter by example type: executable, conceptual, config, api
    * `--output FORMAT` - Output format: json, yaml, html, report (default: json)
    * `--file PATH` - Output file path (auto-generated if not specified)
    * `--min-lines NUM` - Minimum lines for code block inclusion (default: 1)
    * `--validate-syntax` - Perform syntax validation on extracted code
    * `--transformation-analysis` - Analyze examples for automation potential
    * `--coverage-analysis` - Generate documentation coverage metrics
    * `--ci` - CI/CD mode with structured output and exit codes
    * `--verbose` - Enable detailed diagnostic output

  ## Examples

  ### Basic Extraction
      # Extract all code examples
      mix docs.extract_examples

      # Extract with syntax validation
      mix docs.extract_examples --validate-syntax --verbose

  ### Language-Specific Analysis
      # Elixir examples only
      mix docs.extract_examples --language elixir --type executable

      # Multiple languages
      mix docs.extract_examples --language "elixir,javascript,sql"

  ### Quality Analysis
      # Comprehensive analysis with transformation insights
      mix docs.extract_examples --transformation-analysis --coverage-analysis

      # Generate HTML report for stakeholders
      mix docs.extract_examples --output html --coverage-analysis

  ### CI/CD Integration
      # Quality gate for example coverage
      mix docs.extract_examples --ci --coverage-analysis | jq '.coverage.executable_percentage >= 60'

  ## Supported Languages

  Full support: Elixir, JavaScript, Python, SQL, Bash, JSON, YAML, HTML, CSS, Markdown
  Basic support: Ruby, Go, Rust, Java, C, C++, PHP, TypeScript

  Related: [Code Example Standards](docs/guides/code-example-standards.md)
  """

  use Mix.Task

  alias Prismatic.Documentation.CodeExampleExtractor
  alias Mix.Tasks.Docs.Shared.{Config, ErrorHandler, OutputFormatter, ProgressMonitor}

  require Logger

  @shortdoc "Enterprise code example extraction with quality analysis and validation"

  # Supported languages and types
  @supported_languages ~w(elixir javascript python sql bash json yaml html css markdown ruby go rust java c cpp php typescript)
  @example_types ~w(executable conceptual config api)

  @task_defaults %{
    filter_languages: [],
    filter_type: nil,
    min_lines: 1,
    validate_syntax: false,
    transformation_analysis: false,
    coverage_analysis: false,
    file_prefix: "examples-analysis"
  }

  @impl Mix.Task
  def run(args) do
    start_time = System.monotonic_time(:millisecond)

    ErrorHandler.safe_execute("extract_examples", "task execution", fn ->
      case parse_and_validate_options(args) do
        {:ok, %{help: true}} ->
          show_comprehensive_help()

        {:ok, options} ->
          run_example_extraction(options, start_time)

        {:error, reason} ->
          ErrorHandler.handle_validation_error(reason, "extract_examples")
      end
    end)
  end

  @doc false
  def parse_and_validate_options(args) do
    {options, _, invalid} = OptionParser.parse(args,
      switches: [
        docs: :string,
        language: :string,
        type: :string,
        output: :string,
        file: :string,
        min_lines: :integer,
        validate_syntax: :boolean,
        transformation_analysis: :boolean,
        coverage_analysis: :boolean,
        ci: :boolean,
        verbose: :boolean,
        help: :boolean
      ],
      aliases: [
        d: :docs,
        l: :language,
        t: :type,
        o: :output,
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

      options[:output] && options[:output] not in Config.output_formats() ->
        {:error, "Invalid output format '#{options[:output]}'. Available: #{Enum.join(Config.output_formats(), ", ")}"}

      options[:language] && not valid_languages?(options[:language]) ->
        {:error, "Invalid language. Supported: #{Enum.join(@supported_languages, ", ")}"}

      options[:type] && options[:type] not in @example_types ->
        {:error, "Invalid type '#{options[:type]}'. Available: #{Enum.join(@example_types, ", ")}"}

      options[:min_lines] && options[:min_lines] < 1 ->
        {:error, "Minimum lines must be at least 1"}

      options[:docs] && not File.dir?(options[:docs]) ->
        {:error, "Documentation directory '#{options[:docs]}' does not exist"}

      true ->
        :ok
    end
  end

  defp valid_languages?(language_string) do
    languages = String.split(language_string, ",") |> Enum.map(&String.trim/1)
    Enum.all?(languages, &(&1 in @supported_languages))
  end

  defp normalize_options(options) do
    base_config = Config.normalize_config(options, @task_defaults)

    Map.merge(base_config, %{
      filter_languages: parse_comma_list(options[:language]),
      filter_type: options[:type],
      min_lines: options[:min_lines] || 1,
      validate_syntax: options[:validate_syntax] || false,
      transformation_analysis: options[:transformation_analysis] || false,
      coverage_analysis: options[:coverage_analysis] || false
    })
  end

  defp parse_comma_list(nil), do: []
  defp parse_comma_list(str) when is_binary(str) do
    String.split(str, ",") |> Enum.map(&String.trim/1)
  end

  defp run_example_extraction(options, start_time) do
    if options.verbose do
      show_extraction_configuration(options)
    end

    ProgressMonitor.show_simple_progress("Extracting code examples from #{options.docs_path}")

    # Ensure Mix application is started
    Mix.Task.run("app.start")

    # Validate file access
    ErrorHandler.validate_file_access(options.docs_path, "Documentation directory")
    ErrorHandler.validate_output_directory(options.output_file)

    # Perform extraction with enhanced analysis
    extraction_result = perform_comprehensive_example_extraction(options)

    if options.verbose do
      print_comprehensive_examples_summary(extraction_result)
    end

    # Save results in requested format
    case OutputFormatter.save_results(extraction_result, options) do
      :ok ->
        execution_time = System.monotonic_time(:millisecond) - start_time
        ProgressMonitor.show_completion("Code example extraction", execution_time)
        ProgressMonitor.show_output_saved(options.output_file)

      {:error, reason} ->
        ErrorHandler.handle_file_error(reason, options.output_file)
    end

    if options.ci_mode do
      OutputFormatter.format_ci_summary(extraction_result, "extract_examples")
    end
  end

  defp show_extraction_configuration(options) do
    Mix.shell().info([
      :blue, "\n📋 Code Example Extraction Configuration", :reset
    ])

    config_items = [
      {"Documentation Path", options.docs_path},
      {"Output Format", options.output_format},
      {"Output File", options.output_file},
      {"Language Filters", if(Enum.empty?(options.filter_languages), do: "All", else: Enum.join(options.filter_languages, ", "))},
      {"Type Filter", options.filter_type || "All"},
      {"Minimum Lines", options.min_lines},
      {"Syntax Validation", if(options.validate_syntax, do: "Enabled", else: "Disabled")},
      {"Transformation Analysis", if(options.transformation_analysis, do: "Enabled", else: "Disabled")},
      {"Coverage Analysis", if(options.coverage_analysis, do: "Enabled", else: "Disabled")}
    ]

    Enum.each(config_items, fn {label, value} ->
      Mix.shell().info("  #{label}: #{value}")
    end)
    Mix.shell().info("")
  end

  defp perform_comprehensive_example_extraction(options) do
    # Base example extraction
    base_result = CodeExampleExtractor.extract_all_examples(options.docs_path)

    # Apply filters
    filtered_result = apply_comprehensive_example_filters(base_result, options)

    # Enhance with additional analysis
    enhanced_result = enhance_example_analysis(filtered_result, options)

    enhanced_result
  end

  defp apply_comprehensive_example_filters(result, options) do
    filtered_examples = result.examples

    # Language filtering
    filtered_examples = if not Enum.empty?(options.filter_languages) do
      Enum.filter(filtered_examples, fn example ->
        example[:language] in options.filter_languages
      end)
    else
      filtered_examples
    end

    # Type filtering
    filtered_examples = if options.filter_type do
      Enum.filter(filtered_examples, fn example ->
        example[:example_type] == options.filter_type
      end)
    else
      filtered_examples
    end

    # Minimum lines filtering
    filtered_examples = Enum.filter(filtered_examples, fn example ->
      line_count = String.split(example[:content] || "", "\n") |> length()
      line_count >= options.min_lines
    end)

    %{result | examples: filtered_examples}
  end

  defp enhance_example_analysis(result, options) do
    enhanced_result = result

    # Add syntax validation if requested
    enhanced_result = if options.validate_syntax do
      validated_examples = validate_example_syntax(result.examples)
      Map.put(enhanced_result, :syntax_validation, validated_examples)
    else
      enhanced_result
    end

    # Add transformation analysis if requested
    enhanced_result = if options.transformation_analysis do
      transformation_data = analyze_transformation_potential(result.examples)
      Map.put(enhanced_result, :transformation_analysis, transformation_data)
    else
      enhanced_result
    end

    # Add coverage analysis if requested
    enhanced_result = if options.coverage_analysis do
      coverage_data = analyze_documentation_coverage(result.examples, options.docs_path)
      Map.put(enhanced_result, :coverage_analysis, coverage_data)
    else
      enhanced_result
    end

    # Add enhanced metadata
    enhanced_result = Map.merge(enhanced_result, %{
      extraction_timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      extraction_options: options,
      analysis_features: %{
        syntax_validated: options.validate_syntax,
        transformation_analyzed: options.transformation_analysis,
        coverage_analyzed: options.coverage_analysis,
        filtering_applied: not (Enum.empty?(options.filter_languages) and is_nil(options.filter_type))
      }
    })

    enhanced_result
  end

  defp validate_example_syntax(examples) do
    validation_results = Enum.map(examples, fn example ->
      validation_result = case example[:language] do
        "elixir" -> validate_elixir_syntax(example[:content])
        "javascript" -> validate_javascript_syntax(example[:content])
        "json" -> validate_json_syntax(example[:content])
        _ -> %{valid: :unknown, message: "Syntax validation not supported for #{example[:language]}"}
      end

      %{
        example_id: example[:id] || "unknown",
        language: example[:language],
        validation_result: validation_result
      }
    end)

    %{
      total_validated: length(validation_results),
      valid_count: Enum.count(validation_results, &(&1.validation_result.valid == true)),
      invalid_count: Enum.count(validation_results, &(&1.validation_result.valid == false)),
      unknown_count: Enum.count(validation_results, &(&1.validation_result.valid == :unknown)),
      validation_details: validation_results
    }
  end

  defp validate_elixir_syntax(code) do
    try do
      case Code.string_to_quoted(code) do
        {:ok, _ast} -> %{valid: true, message: "Valid Elixir syntax"}
        {:error, reason} -> %{valid: false, message: "Syntax error: #{inspect(reason)}"}
      end
    rescue
      _ -> %{valid: false, message: "Syntax validation failed"}
    end
  end

  defp validate_javascript_syntax(_code) do
    # JavaScript syntax validation would require external tool
    %{valid: :unknown, message: "JavaScript validation requires external tool"}
  end

  defp validate_json_syntax(code) do
    try do
      case Jason.decode(code) do
        {:ok, _} -> %{valid: true, message: "Valid JSON syntax"}
        {:error, reason} -> %{valid: false, message: "JSON error: #{Jason.DecodeError.message(reason)}"}
      end
    rescue
      _ -> %{valid: false, message: "JSON validation failed"}
    end
  end

  defp analyze_transformation_potential(examples) do
    transformation_candidates = Enum.map(examples, fn example ->
      potential_score = calculate_transformation_score(example)

      %{
        example_id: example[:id] || "unknown",
        language: example[:language],
        transformation_score: potential_score,
        automation_feasible: potential_score >= 7,
        recommended_actions: generate_transformation_recommendations(example, potential_score)
      }
    end)

    high_potential = Enum.filter(transformation_candidates, &(&1.automation_feasible))

    %{
      total_analyzed: length(transformation_candidates),
      high_potential_count: length(high_potential),
      average_score: calculate_average_transformation_score(transformation_candidates),
      transformation_candidates: transformation_candidates,
      summary: %{
        automation_ready: length(high_potential),
        manual_review_needed: length(transformation_candidates) - length(high_potential)
      }
    }
  end

  defp calculate_transformation_score(example) do
    score = 5 # Base score

    # Add points for completeness indicators
    score = if String.contains?(example[:content] || "", ["def ", "defmodule", "function"]), do: score + 2, else: score
    score = if String.length(example[:content] || "") > 100, do: score + 1, else: score
    score = if example[:example_type] == "executable", do: score + 2, else: score

    # Subtract points for complexity indicators
    score = if String.contains?(example[:content] || "", ["# TODO", "...", "xxx"]), do: score - 2, else: score
    score = if String.contains?(example[:content] || "", "# Example only"), do: score - 1, else: score

    max(1, min(10, score))
  end

  defp generate_transformation_recommendations(_example, score) do
    cond do
      score >= 8 -> ["Ready for automated testing", "Consider adding to CI pipeline"]
      score >= 6 -> ["Needs minor modifications for automation", "Verify completeness"]
      score >= 4 -> ["Requires significant modifications", "Consider manual review"]
      true -> ["Not suitable for automation", "Keep as documentation example"]
    end
  end

  defp calculate_average_transformation_score(candidates) do
    if Enum.empty?(candidates) do
      0
    else
      total_score = Enum.sum(Enum.map(candidates, & &1.transformation_score))
      Float.round(total_score / length(candidates), 2)
    end
  end

  defp analyze_documentation_coverage(examples, docs_path) do
    # Count total documentation files
    total_docs = count_documentation_files(docs_path)

    # Count files with code examples
    files_with_examples = examples
    |> Enum.map(& &1[:source_file])
    |> Enum.uniq()
    |> length()

    # Calculate coverage metrics
    coverage_percentage = if total_docs > 0 do
      Float.round(files_with_examples / total_docs * 100, 2)
    else
      0
    end

    %{
      total_documentation_files: total_docs,
      files_with_examples: files_with_examples,
      files_without_examples: total_docs - files_with_examples,
      coverage_percentage: coverage_percentage,
      examples_per_file: if(files_with_examples > 0, do: Float.round(length(examples) / files_with_examples, 2), else: 0),
      recommendations: generate_coverage_recommendations(coverage_percentage, examples)
    }
  end

  defp count_documentation_files(docs_path) do
    docs_path
    |> Path.join("**/*.{md,rst,txt}")
    |> Path.wildcard()
    |> length()
  end

  defp generate_coverage_recommendations(coverage_percentage, examples) do
    recommendations = []

    recommendations = if coverage_percentage < 50 do
      ["Consider adding code examples to more documentation files" | recommendations]
    else
      recommendations
    end

    executable_count = Enum.count(examples, &(&1[:example_type] == "executable"))
    total_count = length(examples)
    executable_percentage = if total_count > 0, do: executable_count / total_count * 100, else: 0

    recommendations = if executable_percentage < 30 do
      ["Increase the ratio of executable examples for better validation" | recommendations]
    else
      recommendations
    end

    recommendations = if length(examples) < 10 do
      ["Documentation would benefit from more comprehensive code examples" | recommendations]
    else
      recommendations
    end

    Enum.reverse(recommendations)
  end

  defp print_comprehensive_examples_summary(result) do
    Mix.shell().info([
      :blue, "\n📊 Comprehensive Code Examples Analysis", :reset
    ])

    # Basic statistics
    total_examples = length(result.examples)
    Mix.shell().info("  💻 Total Examples Found: #{total_examples}")

    if Map.has_key?(result, :summary) do
      summary = result.summary

      # Language distribution
      if Map.has_key?(summary, :by_language) do
        Mix.shell().info("\n  🔤 Language Distribution:")
        Enum.each(summary.by_language, fn {language, count} ->
          percentage = if total_examples > 0, do: round(count / total_examples * 100), else: 0
          Mix.shell().info("    #{language}: #{count} (#{percentage}%)")
        end)
      end

      # Type distribution
      if Map.has_key?(summary, :by_type) do
        Mix.shell().info("\n  📊 Type Distribution:")
        Enum.each(summary.by_type, fn {type, count} ->
          percentage = if total_examples > 0, do: round(count / total_examples * 100), else: 0
          Mix.shell().info("    #{type}: #{count} (#{percentage}%)")
        end)
      end
    end

    # Syntax validation summary
    if Map.has_key?(result, :syntax_validation) do
      validation = result.syntax_validation
      Mix.shell().info("\n  ✅ Syntax Validation:")
      Mix.shell().info("    Valid: #{validation.valid_count}")
      Mix.shell().info("    Invalid: #{validation.invalid_count}")
      Mix.shell().info("    Unknown: #{validation.unknown_count}")
    end

    # Transformation analysis summary
    if Map.has_key?(result, :transformation_analysis) do
      transformation = result.transformation_analysis
      Mix.shell().info("\n  🔄 Transformation Analysis:")
      Mix.shell().info("    Automation Ready: #{transformation.summary.automation_ready}")
      Mix.shell().info("    Average Score: #{transformation.average_score}/10")
    end

    # Coverage analysis summary
    if Map.has_key?(result, :coverage_analysis) do
      coverage = result.coverage_analysis
      Mix.shell().info("\n  📈 Coverage Analysis:")
      Mix.shell().info("    Documentation Coverage: #{coverage.coverage_percentage}%")
      Mix.shell().info("    Examples per File: #{coverage.examples_per_file}")
    end
  end

  defp show_comprehensive_help do
    Mix.shell().info(@moduledoc)
  end
end
