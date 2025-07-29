defmodule Mix.Tasks.Docs.Tasks.ExtractAdrs do
  @moduledoc """
  Enterprise Architecture Decision Records (ADR) extraction and analysis.

  Advanced ADR processing system that discovers, parses, and analyzes Architecture
  Decision Records across documentation systems. Provides comprehensive metadata
  extraction, cross-referencing, and impact analysis for architectural governance.

  ## Features

  ### ADR Discovery
  - Automatic detection of ADR files using naming patterns
  - Support for multiple ADR formats (markdown, structured text)
  - Hierarchical organization analysis
  - Cross-document relationship mapping

  ### Metadata Extraction
  - Decision status tracking (Proposed, Accepted, Superseded, Deprecated)
  - Architectural domain classification
  - Impact scope analysis
  - Decision timeline construction

  ### Analysis Capabilities
  - Decision complexity scoring
  - Architectural domain distribution
  - Status lifecycle analysis
  - Supersession chain tracking
  - Cross-reference validation

  ## Options

    * `--docs PATH` - Documentation directory (default: docs)
    * `--output FORMAT` - Output format: json, yaml, html, report (default: json)
    * `--file PATH` - Output file path (auto-generated if not specified)
    * `--domain DOMAIN` - Filter by architectural domain (comma-separated)
    * `--status STATUS` - Filter by decision status (comma-separated)
    * `--include-superseded` - Include superseded decisions in analysis
    * `--complexity-threshold NUM` - Filter by minimum complexity score (1-10)
    * `--timeline` - Generate decision timeline visualization
    * `--cross-references` - Analyze cross-references between ADRs
    * `--ci` - CI/CD mode with structured output and exit codes
    * `--verbose` - Enable detailed diagnostic output

  ## Examples

  ### Basic Extraction
      # Extract all ADRs with default analysis
      mix docs.extract_adrs

      # Extract with detailed analysis
      mix docs.extract_adrs --verbose --cross-references --timeline

  ### Filtered Analysis
      # Security domain ADRs only
      mix docs.extract_adrs --domain security --output html

      # Accepted and proposed decisions
      mix docs.extract_adrs --status "Accepted,Proposed" --complexity-threshold 7

      # High-impact decisions with timeline
      mix docs.extract_adrs --complexity-threshold 8 --timeline --output report

  ### CI/CD Integration
      # Generate structured data for automation
      mix docs.extract_adrs --ci --output json --file adr-inventory.json

      # Quality gate analysis
      mix docs.extract_adrs --domain security --ci | jq '.summary.total_adrs >= 5'

  ## Output Formats

  - **json**: Machine-readable structured data with full metadata
  - **yaml**: Human-readable format for configuration management
  - **html**: Interactive web report with filtering and visualization
  - **report**: Formatted text report for terminal and documentation

  ## ADR Standards

  Supports multiple ADR formats:
  - Michael Nygard format (status/context/decision/consequences)
  - Y-Statements format (In the context of X, facing Y, we decided Z)
  - MADR format (Markdown Architecture Decision Records)
  - Custom organizational formats

  Related: [ADR Guidelines](docs/architecture/adr-guidelines.md)
  """

  use Mix.Task

  alias Prismatic.Documentation.ADRExtractor
  alias Mix.Tasks.Docs.Shared.{Config, ErrorHandler, OutputFormatter, ProgressMonitor}

  require Logger

  @shortdoc "Enterprise ADR extraction with domain filtering and impact analysis"

  # Available filters and options
  @valid_statuses ~w(Proposed Accepted Superseded Deprecated)
  @valid_domains ~w(security infrastructure data api frontend backend integration deployment)

  @task_defaults %{
    filter_domains: [],
    filter_statuses: [],
    include_superseded: false,
    complexity_threshold: 1,
    generate_timeline: false,
    analyze_cross_references: false,
    file_prefix: "adr-analysis"
  }

  @impl Mix.Task
  def run(args) do
    start_time = System.monotonic_time(:millisecond)

    ErrorHandler.safe_execute("extract_adrs", "task execution", fn ->
      case parse_and_validate_options(args) do
        {:ok, %{help: true}} ->
          show_comprehensive_help()

        {:ok, options} ->
          run_adr_extraction(options, start_time)

        {:error, reason} ->
          ErrorHandler.handle_validation_error(reason, "extract_adrs")
      end
    end)
  end

  @doc false
  def parse_and_validate_options(args) do
    {options, _, invalid} = OptionParser.parse(args,
      switches: [
        docs: :string,
        output: :string,
        file: :string,
        domain: :string,
        status: :string,
        include_superseded: :boolean,
        complexity_threshold: :integer,
        timeline: :boolean,
        cross_references: :boolean,
        ci: :boolean,
        verbose: :boolean,
        help: :boolean
      ],
      aliases: [
        d: :docs,
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

      options[:status] && not valid_statuses?(options[:status]) ->
        {:error, "Invalid status. Available: #{Enum.join(@valid_statuses, ", ")}"}

      options[:domain] && not valid_domains?(options[:domain]) ->
        {:error, "Invalid domain. Available: #{Enum.join(@valid_domains, ", ")}"}

      options[:complexity_threshold] && (options[:complexity_threshold] < 1 or options[:complexity_threshold] > 10) ->
        {:error, "Complexity threshold must be between 1 and 10"}

      options[:docs] && not File.dir?(options[:docs]) ->
        {:error, "Documentation directory '#{options[:docs]}' does not exist"}

      true ->
        :ok
    end
  end

  defp valid_statuses?(status_string) do
    statuses = String.split(status_string, ",") |> Enum.map(&String.trim/1)
    Enum.all?(statuses, &(&1 in @valid_statuses))
  end

  defp valid_domains?(domain_string) do
    domains = String.split(domain_string, ",") |> Enum.map(&String.trim/1)
    Enum.all?(domains, &(&1 in @valid_domains))
  end

  defp normalize_options(options) do
    base_config = Config.normalize_config(options, @task_defaults)

    Map.merge(base_config, %{
      filter_domains: parse_comma_list(options[:domain]),
      filter_statuses: parse_comma_list(options[:status]),
      include_superseded: options[:include_superseded] || false,
      complexity_threshold: options[:complexity_threshold] || 1,
      generate_timeline: options[:timeline] || false,
      analyze_cross_references: options[:cross_references] || false
    })
  end

  defp parse_comma_list(nil), do: []
  defp parse_comma_list(str) when is_binary(str) do
    String.split(str, ",") |> Enum.map(&String.trim/1)
  end

  defp run_adr_extraction(options, start_time) do
    if options.verbose do
      show_extraction_configuration(options)
    end

    ProgressMonitor.show_simple_progress("Discovering ADRs in #{options.docs_path}")

    # Ensure Mix application is started
    Mix.Task.run("app.start")

    # Validate file access
    ErrorHandler.validate_file_access(options.docs_path, "Documentation directory")
    ErrorHandler.validate_output_directory(options.output_file)

    # Perform extraction with enhanced features
    extraction_result = perform_enhanced_adr_extraction(options)

    if options.verbose do
      print_comprehensive_adr_summary(extraction_result)
    end

    # Save results in requested format
    case OutputFormatter.save_results(extraction_result, options) do
      :ok ->
        execution_time = System.monotonic_time(:millisecond) - start_time
        ProgressMonitor.show_completion("ADR extraction", execution_time)
        ProgressMonitor.show_output_saved(options.output_file)

      {:error, reason} ->
        ErrorHandler.handle_file_error(reason, options.output_file)
    end

    if options.ci_mode do
      OutputFormatter.format_ci_summary(extraction_result, "extract_adrs")
    end
  end

  defp show_extraction_configuration(options) do
    Mix.shell().info([
      :blue, "\n📋 ADR Extraction Configuration", :reset
    ])

    config_items = [
      {"Documentation Path", options.docs_path},
      {"Output Format", options.output_format},
      {"Output File", options.output_file},
      {"Domain Filters", if(Enum.empty?(options.filter_domains), do: "None", else: Enum.join(options.filter_domains, ", "))},
      {"Status Filters", if(Enum.empty?(options.filter_statuses), do: "None", else: Enum.join(options.filter_statuses, ", "))},
      {"Complexity Threshold", options.complexity_threshold},
      {"Include Superseded", if(options.include_superseded, do: "Yes", else: "No")},
      {"Generate Timeline", if(options.generate_timeline, do: "Yes", else: "No")},
      {"Cross-Reference Analysis", if(options.analyze_cross_references, do: "Yes", else: "No")}
    ]

    Enum.each(config_items, fn {label, value} ->
      Mix.shell().info("  #{label}: #{value}")
    end)
    Mix.shell().info("")
  end

  defp perform_enhanced_adr_extraction(options) do
    # Base ADR extraction
    base_result = ADRExtractor.extract_all_adrs(options.docs_path)

    # Apply filters
    filtered_result = apply_comprehensive_adr_filters(base_result, options)

    # Enhance with additional analysis
    enhanced_result = enhance_adr_analysis(filtered_result, options)

    enhanced_result
  end

  defp apply_comprehensive_adr_filters(result, options) do
    filtered_adrs = result.adrs

    # Domain filtering
    filtered_adrs = if not Enum.empty?(options.filter_domains) do
      Enum.filter(filtered_adrs, fn adr ->
        adr[:architectural_domain] in options.filter_domains
      end)
    else
      filtered_adrs
    end

    # Status filtering
    filtered_adrs = if not Enum.empty?(options.filter_statuses) do
      Enum.filter(filtered_adrs, fn adr ->
        adr[:status] in options.filter_statuses
      end)
    else
      filtered_adrs
    end

    # Complexity filtering
    filtered_adrs = Enum.filter(filtered_adrs, fn adr ->
      (adr[:complexity_score] || 1) >= options.complexity_threshold
    end)

    # Superseded filtering
    filtered_adrs = if not options.include_superseded do
      Enum.reject(filtered_adrs, fn adr ->
        adr[:status] == "Superseded"
      end)
    else
      filtered_adrs
    end

    %{result | adrs: filtered_adrs}
  end

  defp enhance_adr_analysis(result, options) do
    enhanced_result = result

    # Add timeline analysis if requested
    enhanced_result = if options.generate_timeline do
      timeline_data = generate_adr_timeline(result.adrs)
      Map.put(enhanced_result, :timeline, timeline_data)
    else
      enhanced_result
    end

    # Add cross-reference analysis if requested
    enhanced_result = if options.analyze_cross_references do
      cross_ref_data = analyze_adr_cross_references(result.adrs)
      Map.put(enhanced_result, :cross_references, cross_ref_data)
    else
      enhanced_result
    end

    # Add enhanced metadata
    enhanced_result = Map.merge(enhanced_result, %{
      extraction_timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      extraction_options: options,
      analysis_features: %{
        timeline_generated: options.generate_timeline,
        cross_references_analyzed: options.analyze_cross_references,
        filtering_applied: not (Enum.empty?(options.filter_domains) and Enum.empty?(options.filter_statuses))
      }
    })

    enhanced_result
  end

  defp generate_adr_timeline(adrs) do
    timeline_entries = adrs
    |> Enum.filter(fn adr -> Map.has_key?(adr, :decision_date) and adr[:decision_date] end)
    |> Enum.sort_by(fn adr -> adr[:decision_date] end)
    |> Enum.map(fn adr ->
      %{
        date: adr[:decision_date],
        adr_id: adr[:id],
        title: adr[:title],
        status: adr[:status],
        domain: adr[:architectural_domain],
        complexity: adr[:complexity_score] || 1
      }
    end)

    %{
      total_entries: length(timeline_entries),
      entries: timeline_entries,
      date_range: calculate_timeline_range(timeline_entries),
      domain_progression: analyze_domain_progression(timeline_entries)
    }
  end

  defp analyze_adr_cross_references(adrs) do
    # Create a map of ADR IDs to ADRs for quick lookup
    adr_map = Enum.into(adrs, %{}, fn adr -> {adr[:id], adr} end)

    cross_references = adrs
    |> Enum.flat_map(fn adr ->
      referenced_ids = extract_adr_references(adr[:content] || "")

      Enum.map(referenced_ids, fn ref_id ->
        %{
          from_adr: adr[:id],
          to_adr: ref_id,
          reference_type: determine_reference_type(adr[:content], ref_id),
          valid: Map.has_key?(adr_map, ref_id)
        }
      end)
    end)

    %{
      total_references: length(cross_references),
      valid_references: Enum.count(cross_references, & &1.valid),
      invalid_references: Enum.count(cross_references, &(not &1.valid)),
      reference_network: build_reference_network(cross_references),
      orphaned_adrs: find_orphaned_adrs(adrs, cross_references)
    }
  end

  defp extract_adr_references(content) do
    # Extract ADR references like "ADR-001", "ADR 002", etc.
    Regex.scan(~r/ADR[-\s]?(\d{3,4})/i, content)
    |> Enum.map(fn [_, id] -> "ADR-#{String.pad_leading(id, 3, "0")}" end)
    |> Enum.uniq()
  end

  defp determine_reference_type(content, ref_id) do
    cond do
      String.contains?(content, "supersedes #{ref_id}") -> :supersedes
      String.contains?(content, "superseded by #{ref_id}") -> :superseded_by
      String.contains?(content, "relates to #{ref_id}") -> :relates_to
      String.contains?(content, "depends on #{ref_id}") -> :depends_on
      true -> :references
    end
  end

  defp build_reference_network(cross_references) do
    # Group references to show the network structure
    Enum.group_by(cross_references, & &1.from_adr)
  end

  defp find_orphaned_adrs(adrs, cross_references) do
    referenced_ids = Enum.map(cross_references, & &1.to_adr) |> Enum.uniq()
    referencing_ids = Enum.map(cross_references, & &1.from_adr) |> Enum.uniq()
    all_referenced_ids = (referenced_ids ++ referencing_ids) |> Enum.uniq()

    adr_ids = Enum.map(adrs, & &1[:id])

    Enum.reject(adr_ids, fn id -> id in all_referenced_ids end)
  end

  defp calculate_timeline_range(timeline_entries) do
    if Enum.empty?(timeline_entries) do
      %{start_date: nil, end_date: nil, span_days: 0}
    else
      start_date = List.first(timeline_entries).date
      end_date = List.last(timeline_entries).date

      %{
        start_date: start_date,
        end_date: end_date,
        span_days: Date.diff(Date.from_iso8601!(end_date), Date.from_iso8601!(start_date))
      }
    end
  end

  defp analyze_domain_progression(timeline_entries) do
    timeline_entries
    |> Enum.group_by(& &1.domain)
    |> Enum.map(fn {domain, entries} ->
      %{
        domain: domain,
        decision_count: length(entries),
        first_decision: List.first(entries).date,
        last_decision: List.last(entries).date
      }
    end)
  end

  defp print_comprehensive_adr_summary(result) do
    Mix.shell().info([
      :blue, "\n📊 Comprehensive ADR Analysis Summary", :reset
    ])

    # Basic statistics
    total_adrs = length(result.adrs)
    Mix.shell().info("  📋 Total ADRs Found: #{total_adrs}")

    if Map.has_key?(result, :summary) do
      summary = result.summary

      if Map.has_key?(summary, :average_complexity) do
        Mix.shell().info("  📈 Average Complexity: #{summary.average_complexity}")
      end

      # Domain distribution
      if Map.has_key?(summary, :domain_distribution) do
        Mix.shell().info("\n  🏗️  Domain Distribution:")
        Enum.each(summary.domain_distribution, fn {domain, count} ->
          percentage = if total_adrs > 0, do: round(count / total_adrs * 100), else: 0
          Mix.shell().info("    #{domain}: #{count} (#{percentage}%)")
        end)
      end

      # Status distribution
      if Map.has_key?(summary, :status_distribution) do
        Mix.shell().info("\n  📊 Status Distribution:")
        Enum.each(summary.status_distribution, fn {status, count} ->
          percentage = if total_adrs > 0, do: round(count / total_adrs * 100), else: 0
          Mix.shell().info("    #{status}: #{count} (#{percentage}%)")
        end)
      end
    end

    # Timeline summary
    if Map.has_key?(result, :timeline) do
      timeline = result.timeline
      Mix.shell().info("\n  📅 Timeline Analysis:")
      Mix.shell().info("    Dated Decisions: #{timeline.total_entries}")

      if timeline.date_range.span_days > 0 do
        Mix.shell().info("    Decision Span: #{timeline.date_range.span_days} days")
        Mix.shell().info("    From: #{timeline.date_range.start_date}")
        Mix.shell().info("    To: #{timeline.date_range.end_date}")
      end
    end

    # Cross-reference summary
    if Map.has_key?(result, :cross_references) do
      cross_refs = result.cross_references
      Mix.shell().info("\n  🔗 Cross-Reference Analysis:")
      Mix.shell().info("    Total References: #{cross_refs.total_references}")
      Mix.shell().info("    Valid References: #{cross_refs.valid_references}")
      Mix.shell().info("    Invalid References: #{cross_refs.invalid_references}")
      Mix.shell().info("    Orphaned ADRs: #{length(cross_refs.orphaned_adrs)}")
    end
  end

  defp show_comprehensive_help do
    Mix.shell().info(@moduledoc)
  end
end
