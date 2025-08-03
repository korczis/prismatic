defmodule Mix.Tasks.Prismatic.Docs.Extract do
  @moduledoc """
  Extract and process content from documentation sources.

  Provides comprehensive content extraction including:
  - Link extraction and cataloging
  - Code examples and snippets extraction
  - Table of contents generation
  - Metadata and frontmatter extraction
  - Cross-reference mapping
  - API documentation extraction
  - Template and pattern identification
  - Multi-format content processing

  ## Usage

      # Extract all content types from documentation
      mix prismatic.docs.extract

      # Extract specific content types
      mix prismatic.docs.extract --types links,examples,toc

      # Extract from specific directory with custom output
      mix prismatic.docs.extract --input docs/ --output extracts/

      # Extract with filtering and processing
      mix prismatic.docs.extract --filter "*.md" --process --validate

      # Generate structured output for analysis
      mix prismatic.docs.extract --format json --structured

  ## Extraction Types

  ### Links (`--types links`)
  - Internal documentation links
  - External reference links
  - Cross-reference relationships
  - Link metadata and context
  - Broken link identification

  ### Examples (`--types examples`)
  - Code blocks and snippets
  - Usage examples and patterns
  - Configuration samples
  - Test cases and scenarios
  - Interactive examples

  ### Table of Contents (`--types toc`)
  - Document structure mapping
  - Heading hierarchy extraction
  - Navigation structure
  - Section relationships
  - Auto-generated TOC data

  ### Metadata (`--types metadata`)
  - Frontmatter and YAML headers
  - Document properties
  - Author and timestamp information
  - Tags and categorization
  - Custom metadata fields

  ### API Documentation (`--types api`)
  - Function and method documentation
  - Parameter descriptions
  - Return value specifications
  - Usage examples
  - Type information

  ### Cross-references (`--types xrefs`)
  - Inter-document relationships
  - Reference mappings
  - Dependency graphs
  - Citation networks
  - Link hierarchies
  """

  use Mix.Tasks.Prismatic.Shared.TaskBehaviour,
    profile: :docs,
    description: "Extract and process content from documentation sources"

  @extraction_types [
    :links,
    :examples,
    :toc,
    :metadata,
    :api,
    :xrefs,
    :images,
    :tables
  ]

  @impl true
  def run(args) do
    IO.puts("Documentation extraction task called with args: #{inspect(args)}")
  end

  # Add required functions to satisfy compilation
  @impl true
  def get_option_parser_config do
    []
  end

  @impl true
  def get_task_defaults do
    %{}
  end

  # Private implementation

  defp validate_arguments!(opts, remaining_args) do
    if not Enum.empty?(remaining_args) do
      raise ArgumentError, "Unknown arguments: #{inspect(remaining_args)}. Use --help for usage information."
    end

    if opts[:types] do
      requested_types = parse_extraction_types(opts[:types])
      invalid_types = requested_types -- @extraction_types

      unless Enum.empty?(invalid_types) do
        raise ArgumentError, """
        Invalid extraction types: #{inspect(invalid_types)}

        Available types: #{inspect(@extraction_types)}
        """
      end
    end

    if opts[:output] do
      ErrorHandler.validate_output_directory(opts[:output])
    end
  end

  defp parse_extraction_types(types) when is_binary(types) do
    types
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_atom/1)
  end

  defp parse_extraction_types(types) when is_list(types), do: types
  defp parse_extraction_types(types), do: [types]

  defp preview_extraction(config, extraction_types, opts) do
    OutputFormatter.display_section_header("Content Extraction Preview")

    # Show scope
    input_path = config.input || "docs/"
    file_count = count_documentation_files(input_path)

    OutputFormatter.display_info("Input directory: #{input_path}")
    OutputFormatter.display_info("Documentation files: #{file_count}")
    OutputFormatter.display_info("Extraction types: #{inspect(extraction_types)}")
    OutputFormatter.display_info("Output format: #{config.output_format}")

    if opts[:output] do
      OutputFormatter.display_info("Output directory: #{opts[:output]}")
    end

    # Show extraction plan
    OutputFormatter.display_section_header("Extraction Plan", width: 40)
    show_extraction_plan(extraction_types, file_count, opts)

    # Estimate processing time
    estimated_time = estimate_extraction_time(file_count, extraction_types)
    OutputFormatter.display_info("Estimated processing time: #{estimated_time}")

    OutputFormatter.display_success("Dry run completed. Use without --dry-run to execute extraction.")
  end

  defp execute_extraction(config, extraction_types, opts) do
    ProgressMonitor.start_operation("Starting documentation content extraction...")

    input_path = config.input || "docs/"
    output_path = opts[:output] || "extracts/"

    # Discover and validate input files
    files = discover_documentation_files(input_path)
    ProgressMonitor.show_info("Found #{length(files)} documentation files")

    # Initialize extraction context
    extraction_context = initialize_extraction_context(config, extraction_types, files, output_path)

    # Execute extraction by type
    results = execute_type_extraction(extraction_context, extraction_types, opts)

    # Process and structure results
    structured_results = structure_extraction_results(results, extraction_context, opts)

    # Output results
    output_extraction_results(structured_results, extraction_context, opts)

    # Display summary
    display_extraction_summary(structured_results, opts)

    ProgressMonitor.complete_operation("Content extraction completed successfully")
  end

  defp discover_documentation_files(input_path) do
    ErrorHandler.validate_file_access(input_path, "documentation directory")

    extensions = [".md", ".markdown", ".mdx", ".rst", ".txt", ".adoc"]

    input_path
    |> Path.expand()
    |> discover_files_recursively(extensions)
    |> Enum.sort()
  rescue
    error ->
      ErrorHandler.handle_task_error(error, 0, "docs.extract.discovery")
  end

  defp discover_files_recursively(path, extensions) do
    if File.dir?(path) do
      path
      |> File.ls!()
      |> Enum.flat_map(fn file ->
        file_path = Path.join(path, file)

        cond do
          File.dir?(file_path) ->
            discover_files_recursively(file_path, extensions)
          File.regular?(file_path) and Path.extname(file) in extensions ->
            [file_path]
          true ->
            []
        end
      end)
    else
      []
    end
  end

  defp initialize_extraction_context(config, extraction_types, files, output_path) do
    %{
      config: config,
      extraction_types: extraction_types,
      files: files,
      file_count: length(files),
      output_path: output_path,
      start_time: System.monotonic_time(:millisecond),
      extraction_cache: %{},
      extracted_data: %{},
      processing_errors: [],
      statistics: %{}
    }
  end

  defp execute_type_extraction(context, extraction_types, opts) do
    total_types = length(extraction_types)

    extraction_types
    |> Enum.with_index(1)
    |> Enum.reduce(%{}, fn {extraction_type, index}, results ->
      ProgressMonitor.show_info("Extracting #{extraction_type} (#{index}/#{total_types})...")

      type_result = ErrorHandler.safe_execute(
        "docs.extract",
        Atom.to_string(extraction_type),
        fn -> extract_content_type(extraction_type, context, opts) end
      )

      Map.put(results, extraction_type, type_result)
    end)
  end

  defp extract_content_type(:links, context, _opts) do
    ProgressMonitor.show_info("Extracting links and references...")

    # Extract all links from all files
    all_links = context.files
    |> Enum.flat_map(&extract_file_links/1)
    |> Enum.uniq_by(& &1.url)

    # Categorize and analyze links
    categorized_links = categorize_extracted_links(all_links)
    link_metadata = analyze_link_metadata(all_links, context.files)

    %{
      total_links: length(all_links),
      internal_links: categorized_links.internal,
      external_links: categorized_links.external,
      anchor_links: categorized_links.anchor,
      reference_links: categorized_links.reference,
      link_metadata: link_metadata,
      cross_references: build_cross_reference_graph(all_links),
      statistics: calculate_link_statistics(all_links, categorized_links)
    }
  end

  defp extract_content_type(:examples, context, _opts) do
    ProgressMonitor.show_info("Extracting code examples and snippets...")

    # Extract code blocks and examples from all files
    all_examples = context.files
    |> Enum.flat_map(&extract_file_examples/1)
    |> Enum.with_index(1)
    |> Enum.map(fn {example, index} -> Map.put(example, :id, "example_#{index}") end)

    # Analyze and categorize examples
    categorized_examples = categorize_examples(all_examples)
    example_metadata = analyze_example_metadata(all_examples)

    %{
      total_examples: length(all_examples),
      code_blocks: categorized_examples.code_blocks,
      inline_code: categorized_examples.inline_code,
      configurations: categorized_examples.configurations,
      usage_patterns: categorized_examples.usage_patterns,
      languages: extract_programming_languages(all_examples),
      example_metadata: example_metadata,
      statistics: calculate_example_statistics(all_examples, categorized_examples)
    }
  end

  defp extract_content_type(:toc, context, _opts) do
    ProgressMonitor.show_info("Extracting table of contents and structure...")

    # Extract heading structure from all files
    all_headings = context.files
    |> Enum.map(&extract_file_headings/1)
    |> Enum.filter(fn file_headings -> not Enum.empty?(file_headings.headings) end)

    # Build hierarchical structure
    document_structure = build_document_structure(all_headings)
    navigation_tree = build_navigation_tree(all_headings)

    %{
      total_documents: length(all_headings),
      document_structure: document_structure,
      navigation_tree: navigation_tree,
      heading_statistics: calculate_heading_statistics(all_headings),
      depth_analysis: analyze_heading_depth(all_headings),
      auto_toc: generate_auto_toc(navigation_tree)
    }
  end

  defp extract_content_type(:metadata, context, _opts) do
    ProgressMonitor.show_info("Extracting metadata and frontmatter...")

    # Extract metadata from all files
    all_metadata = context.files
    |> Enum.map(&extract_file_metadata/1)
    |> Enum.filter(fn file_meta -> not Enum.empty?(file_meta.metadata) end)

    # Analyze metadata patterns
    metadata_schema = analyze_metadata_schema(all_metadata)
    metadata_consistency = check_metadata_consistency(all_metadata)

    %{
      total_files_with_metadata: length(all_metadata),
      metadata_entries: all_metadata,
      schema: metadata_schema,
      consistency_report: metadata_consistency,
      common_fields: extract_common_metadata_fields(all_metadata),
      statistics: calculate_metadata_statistics(all_metadata)
    }
  end

  defp extract_content_type(:api, context, _opts) do
    ProgressMonitor.show_info("Extracting API documentation...")

    # Extract API documentation patterns
    api_docs = context.files
    |> Enum.flat_map(&extract_api_documentation/1)
    |> Enum.filter(fn api_entry -> not is_nil(api_entry) end)

    # Organize by type and analyze
    organized_api = organize_api_documentation(api_docs)
    api_coverage = analyze_api_coverage(api_docs)

    %{
      total_api_entries: length(api_docs),
      functions: organized_api.functions,
      methods: organized_api.methods,
      classes: organized_api.classes,
      modules: organized_api.modules,
      coverage_analysis: api_coverage,
      documentation_completeness: assess_api_documentation_completeness(api_docs),
      statistics: calculate_api_statistics(api_docs)
    }
  end

  defp extract_content_type(:xrefs, context, _opts) do
    ProgressMonitor.show_info("Extracting cross-references and relationships...")

    # Build cross-reference graph
    xref_graph = build_cross_reference_graph(context.files)
    dependency_map = build_dependency_map(context.files)

    %{
      cross_reference_graph: xref_graph,
      dependency_map: dependency_map,
      relationship_matrix: build_relationship_matrix(xref_graph),
      reference_statistics: calculate_xref_statistics(xref_graph),
      orphaned_documents: identify_orphaned_documents(xref_graph, context.files),
      highly_connected: identify_highly_connected_documents(xref_graph)
    }
  end

  defp extract_content_type(:images, context, _opts) do
    ProgressMonitor.show_info("Extracting image references and metadata...")

    # Extract image references from all files
    all_images = context.files
    |> Enum.flat_map(&extract_file_images/1)
    |> Enum.uniq_by(& &1.src)

    # Analyze image usage and metadata
    image_analysis = analyze_image_usage(all_images, context.files)
    accessibility_check = check_image_accessibility(all_images)

    %{
      total_images: length(all_images),
      image_references: all_images,
      usage_analysis: image_analysis,
      accessibility: accessibility_check,
      broken_images: identify_broken_images(all_images),
      optimization_opportunities: identify_image_optimization_opportunities(all_images),
      statistics: calculate_image_statistics(all_images)
    }
  end

  defp extract_content_type(:tables, context, _opts) do
    ProgressMonitor.show_info("Extracting table data and structure...")

    # Extract tables from all files
    all_tables = context.files
    |> Enum.flat_map(&extract_file_tables/1)
    |> Enum.with_index(1)
    |> Enum.map(fn {table, index} -> Map.put(table, :id, "table_#{index}") end)

    # Analyze table structure and content
    table_analysis = analyze_table_structure(all_tables)
    accessibility_analysis = analyze_table_accessibility(all_tables)

    %{
      total_tables: length(all_tables),
      tables: all_tables,
      structure_analysis: table_analysis,
      accessibility_analysis: accessibility_analysis,
      data_patterns: identify_table_data_patterns(all_tables),
      statistics: calculate_table_statistics(all_tables)
    }
  end

  # File extraction helpers

  defp extract_file_links(file_path) do
    content = File.read!(file_path)

    # Extract different types of links
    markdown_links = Regex.scan(~r/\[([^\]]*)\]\(([^)]+)\)/, content, capture: :all_but_first)
    reference_links = extract_reference_links(content)
    bare_urls = Regex.scan(~r/https?:\/\/[^\s<>"{}|\\^`[\]]+/, content)

    # Combine and normalize with context
    all_links = markdown_links ++ reference_links ++ bare_urls

    all_links
    |> Enum.map(fn link_data ->
      %{
        url: normalize_link_url(link_data),
        text: extract_link_text(link_data),
        type: determine_link_type(link_data),
        source_file: file_path,
        line_number: find_link_line_number(content, link_data),
        context: extract_link_context(content, link_data)
      }
    end)
  end

  defp extract_file_examples(file_path) do
    content = File.read!(file_path)

    # Extract code blocks
    code_blocks = Regex.scan(~r/```(\w+)?\n(.*?)```/s, content, capture: :all_but_first)
    |> Enum.map(fn [lang, code] ->
      %{
        type: :code_block,
        language: lang,
        content: String.trim(code),
        source_file: file_path
      }
    end)

    # Extract inline code
    inline_code = Regex.scan(~r/`([^`]+)`/, content, capture: :all_but_first)
    |> Enum.map(fn [code] ->
      %{
        type: :inline_code,
        content: code,
        source_file: file_path
      }
    end)

    # Extract configuration examples
    config_examples = extract_configuration_examples(content, file_path)

    code_blocks ++ inline_code ++ config_examples
  end

  defp extract_file_headings(file_path) do
    content = File.read!(file_path)

    # Extract headings with levels
    headings = Regex.scan(~r/^(#+)\s+(.+)$/m, content, capture: :all_but_first)
    |> Enum.map(fn [hashes, heading_text] ->
      %{
        level: String.length(hashes),
        text: String.trim(heading_text),
        anchor: generate_heading_anchor(heading_text),
        line_number: find_heading_line_number(content, heading_text)
      }
    end)

    %{
      file: file_path,
      headings: headings,
      max_depth: calculate_max_heading_depth(headings),
      structure: build_heading_hierarchy(headings)
    }
  end

  defp extract_file_metadata(file_path) do
    content = File.read!(file_path)

    # Extract YAML frontmatter
    yaml_metadata = case Regex.run(~r/^---\n(.*?)\n---/s, content, capture: :all_but_first) do
      [yaml_content] -> parse_yaml_metadata(yaml_content)
      _ -> %{}
    end

    # Extract other metadata patterns
    title = extract_title_from_content(content)
    description = extract_description_from_content(content)

    %{
      file: file_path,
      metadata: yaml_metadata,
      title: title,
      description: description,
      has_frontmatter: not Enum.empty?(yaml_metadata),
      file_stats: get_file_statistics(file_path)
    }
  end

  defp extract_api_documentation(file_path) do
    content = File.read!(file_path)

    # Look for API documentation patterns
    api_patterns = [
      ~r/###?\s+`?([A-Z]\w*\.[a-z]\w*\([^)]*\))`?/,  # Method signatures
      ~r/###?\s+`?([a-z_]\w*\([^)]*\))`?/,           # Function signatures
      ~r/###?\s+`?class\s+(\w+)`?/,                  # Class definitions
      ~r/###?\s+`?module\s+(\w+)`?/                  # Module definitions
    ]

    api_patterns
    |> Enum.flat_map(fn pattern ->
      Regex.scan(pattern, content, capture: :all_but_first)
      |> Enum.map(fn [signature] ->
        %{
          signature: signature,
          type: determine_api_type(signature),
          source_file: file_path,
          documentation: extract_api_documentation_text(content, signature)
        }
      end)
    end)
  end

  defp extract_file_images(file_path) do
    content = File.read!(file_path)

    # Extract image references
    Regex.scan(~r/!\[([^\]]*)\]\(([^)]+)\)/, content, capture: :all_but_first)
    |> Enum.map(fn [alt_text, src] ->
      %{
        src: src,
        alt_text: alt_text,
        type: determine_image_type(src),
        source_file: file_path,
        has_alt_text: not String.trim(alt_text) == "",
        line_number: find_image_line_number(content, src)
      }
    end)
  end

  defp extract_file_tables(file_path) do
    content = File.read!(file_path)

    # Extract markdown tables
    table_pattern = ~r/\|.*\|.*\n\|[\s\-:|]*\|\n(\|.*\|.*\n)*/m

    Regex.scan(table_pattern, content)
    |> Enum.map(fn [table_content] ->
      rows = String.split(table_content, "\n") |> Enum.filter(&String.contains?(&1, "|"))
      headers = parse_table_headers(List.first(rows))
      data_rows = parse_table_data_rows(Enum.drop(rows, 2))

      %{
        source_file: file_path,
        headers: headers,
        rows: data_rows,
        column_count: length(headers),
        row_count: length(data_rows),
        has_headers: not Enum.empty?(headers)
      }
    end)
  end

  # Analysis and processing helpers

  defp categorize_extracted_links(links) do
    Enum.group_by(links, & &1.type)
  end

  defp analyze_link_metadata(links, files) do
    %{
      total_unique_domains: count_unique_domains(links),
      most_linked_domains: get_most_linked_domains(links, 10),
      internal_link_distribution: %{},
      broken_link_candidates: []
    }
  end

  defp categorize_examples(examples) do
    Enum.group_by(examples, & &1.type)
  end

  defp analyze_example_metadata(examples) do
    languages = examples
    |> Enum.map(fn ex -> Map.get(ex, :language, "unknown") end)
    |> Enum.frequencies()

    %{
      languages_used: languages,
      most_common_language: Enum.max_by(languages, fn {_lang, count} -> count end, fn -> {"none", 0} end),
      average_example_length: calculate_average_example_length(examples),
      examples_by_file: Enum.group_by(examples, & &1.source_file)
    }
  end


  defp build_document_structure(file_headings) do
    file_headings
    |> Enum.map(fn file_heading ->
      %{
        file: file_heading.file,
        structure: file_heading.structure,
        max_depth: file_heading.max_depth,
        heading_count: length(file_heading.headings)
      }
    end)
  end

  defp build_navigation_tree(file_headings) do
    # Build a hierarchical navigation tree
    file_headings
    |> Enum.reduce(%{}, fn file_heading, tree ->
      Map.put(tree, file_heading.file, build_file_navigation(file_heading.headings))
    end)
  end

  # Structure and output helpers

  defp structure_extraction_results(results, context, opts) do
    %{
      extraction_metadata: %{
        timestamp: DateTime.utc_now(),
        execution_time_ms: System.monotonic_time(:millisecond) - context.start_time,
        files_processed: context.file_count,
        extraction_types: context.extraction_types,
        output_path: context.output_path
      },
      results: results,
      statistics: calculate_overall_statistics(results, context),
      summary: generate_extraction_summary(results, context)
    }
  end

  defp output_extraction_results(structured_results, context, opts) do
    output_path = context.output_path

    # Create output directory if it doesn't exist
    File.mkdir_p!(output_path)

    # Output results for each extraction type
    Enum.each(structured_results.results, fn {extraction_type, data} ->
      output_file = Path.join(output_path, "#{extraction_type}.json")

      case OutputFormatter.save_output(data, output_file, format: :json) do
        :ok ->
          OutputFormatter.display_success("#{extraction_type} data saved to #{output_file}")
        {:error, reason} ->
          OutputFormatter.display_error("Failed to save #{extraction_type} data: #{reason}")
      end
    end)

    # Output combined summary
    summary_file = Path.join(output_path, "extraction_summary.json")

    case OutputFormatter.save_output(structured_results, summary_file, format: :json) do
      :ok ->
        OutputFormatter.display_success("Extraction summary saved to #{summary_file}")
      {:error, reason} ->
        OutputFormatter.display_error("Failed to save summary: #{reason}")
    end
  end

  defp display_extraction_summary(results, opts) do
    OutputFormatter.display_section_header("Extraction Summary")

    metadata = results.extraction_metadata
    OutputFormatter.display_info("Files processed: #{metadata.files_processed}")
    OutputFormatter.display_info("Extraction types: #{Enum.join(metadata.extraction_types, ", ")}")
    OutputFormatter.display_info("Execution time: #{metadata.execution_time_ms}ms")

    # Display key statistics
    OutputFormatter.display_section_header("Key Statistics", width: 40)

    Enum.each(results.results, fn {extraction_type, data} ->
      count = get_extraction_count(extraction_type, data)
      OutputFormatter.display_info("#{extraction_type}: #{count} items")
    end)

    # Display summary insights
    unless Enum.empty?(results.summary) do
      OutputFormatter.display_section_header("Summary Insights", width: 40)

      Enum.each(results.summary, fn insight ->
        OutputFormatter.display_info("• #{insight}")
      end)
    end
  end

  # Utility and helper functions

  defp count_documentation_files(input_path) do
    if File.dir?(input_path) do
      discover_documentation_files(input_path) |> length()
    else
      0
    end
  rescue
    _ -> 0
  end

  defp show_extraction_plan(extraction_types, file_count, opts) do
    Enum.each(extraction_types, fn extraction_type ->
      description = get_extraction_type_description(extraction_type)
      OutputFormatter.display_info("#{extraction_type}: #{description}")
    end)

    OutputFormatter.display_info("\nTotal operations: #{length(extraction_types) * file_count}")

    if opts[:process] do
      OutputFormatter.display_info("Processing and validation enabled")
    end
  end

  defp get_extraction_type_description(extraction_type) do
    case extraction_type do
      :links -> "Extract and catalog all links and references"
      :examples -> "Extract code examples and usage patterns"
      :toc -> "Extract table of contents and document structure"
      :metadata -> "Extract frontmatter and document metadata"
      :api -> "Extract API documentation and signatures"
      :xrefs -> "Extract cross-references and relationships"
      :images -> "Extract image references and metadata"
      :tables -> "Extract table data and structure"
      _ -> "Extract content type"
    end
  end

  defp estimate_extraction_time(file_count, extraction_types) do
    base_time_per_file = 80 # ms
    type_multiplier = length(extraction_types) * 0.4

    estimated_ms = file_count * base_time_per_file * type_multiplier

    cond do
      estimated_ms < 1000 -> "< 1 second"
      estimated_ms < 60000 -> "#{round(estimated_ms / 1000)} seconds"
      true -> "#{round(estimated_ms / 60000)} minutes"
    end
  end

  # Placeholder implementations for complex functions
  # These would be implemented with proper logic in a real system

  defp extract_reference_links(content) do
    # Extract reference-style links: [link text][ref] and [ref]: url
    reference_definitions = Regex.scan(~r/^\[([^\]]+)\]:\s*(.+)$/m, content, capture: :all_but_first)
    reference_uses = Regex.scan(~r/\[([^\]]*)\]\[([^\]]+)\]/, content, capture: :all_but_first)

    # Build reference map
    ref_map = Map.new(reference_definitions, fn [ref, url] -> {ref, url} end)

    # Map reference uses to actual URLs
    Enum.map(reference_uses, fn [text, ref] ->
      url = Map.get(ref_map, ref, "")
      [text, url]
    end)
  end

  defp normalize_link_url([text, url]), do: String.trim(url)
  defp normalize_link_url([url]), do: String.trim(url)
  defp normalize_link_url(url) when is_binary(url), do: String.trim(url)
  defp normalize_link_url(_), do: ""

  defp extract_link_text([text, _url]), do: text
  defp extract_link_text([url]), do: url
  defp extract_link_text(text) when is_binary(text), do: text
  defp extract_link_text(_), do: ""

  defp determine_link_type(link_data) do
    url = normalize_link_url(link_data)

    cond do
      String.starts_with?(url, "http://") or String.starts_with?(url, "https://") -> :external
      String.starts_with?(url, "#") -> :anchor
      String.starts_with?(url, "/") or String.contains?(url, ".md") -> :internal
      String.contains?(url, "][") -> :reference
      true -> :unknown
    end
  end

  defp find_link_line_number(_content, _link_data), do: 1
  defp extract_link_context(_content, _link_data), do: ""

  defp extract_configuration_examples(content, file_path) do
    # Extract YAML/JSON configuration blocks
    yaml_configs = Regex.scan(~r/```ya?ml\n(.*?)```/s, content, capture: :all_but_first)
    |> Enum.map(fn [config] ->
      %{
        type: :yaml_config,
        language: "yaml",
        content: String.trim(config),
        source_file: file_path
      }
    end)

    json_configs = Regex.scan(~r/```json\n(.*?)```/s, content, capture: :all_but_first)
    |> Enum.map(fn [config] ->
      %{
        type: :json_config,
        language: "json",
        content: String.trim(config),
        source_file: file_path
      }
    end)

    # Extract environment variable examples
    env_configs = Regex.scan(~r/```(?:bash|shell|sh)\n(.*?(?:export\s+\w+=|[A-Z_]+=).*?)```/s, content, capture: :all_but_first)
    |> Enum.map(fn [config] ->
      %{
        type: :env_config,
        language: "bash",
        content: String.trim(config),
        source_file: file_path
      }
    end)

    yaml_configs ++ json_configs ++ env_configs
  end

  defp generate_heading_anchor(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  defp find_heading_line_number(content, heading) do
    content
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.find_index(fn {line, _} -> String.contains?(line, heading) end)
    |> case do
      nil -> 1
      index -> index + 1
    end
  end

  defp calculate_max_heading_depth(headings) do
    headings
    |> Enum.map(& &1.level)
    |> Enum.max(fn -> 0 end)
  end

  defp build_heading_hierarchy(headings) do
    # Build proper nested structure
    headings
    |> Enum.reduce([], fn heading, acc ->
      build_hierarchy_node(heading, acc)
    end)
  end

  defp build_hierarchy_node(heading, acc) do
    case acc do
      [] -> [%{heading | children: []}]
      [current | rest] ->
        if heading.level > current.level do
          # Child of current heading
          updated_current = %{current | children: build_hierarchy_node(heading, current.children)}
          [updated_current | rest]
        else
          # Sibling or parent level
          [%{heading | children: []} | acc]
        end
    end
  end

  defp parse_yaml_metadata(yaml_content) do
    # Simplified YAML parsing - would use proper YAML library
    yaml_content
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      case String.split(line, ":", parts: 2) do
        [key, value] -> Map.put(acc, String.trim(key), String.trim(value))
        _ -> acc
      end
    end)
  end

  defp extract_title_from_content(content) do
    case Regex.run(~r/^#\s+(.+)$/m, content, capture: :all_but_first) do
      [title] -> String.trim(title)
      _ -> nil
    end
  end

  defp extract_description_from_content(_content), do: nil
  defp get_file_statistics(file_path) do
    case File.stat(file_path) do
      {:ok, stats} -> %{size: stats.size, modified: stats.mtime}
      _ -> %{size: 0, modified: nil}
    end
  end

  defp determine_api_type(signature) do
    cond do
      String.contains?(signature, "class ") -> :class
      String.contains?(signature, "module ") -> :module
      String.contains?(signature, ".") -> :method
      String.contains?(signature, "(") -> :function
      true -> :unknown
    end
  end

  defp extract_api_documentation_text(_content, _signature), do: ""
  defp determine_image_type(src) do
    case Path.extname(src) do
      ext when ext in [".jpg", ".jpeg", ".png", ".gif", ".svg", ".webp"] -> :standard
      _ -> :unknown
    end
  end

  defp find_image_line_number(_content, _src), do: 1

  defp parse_table_headers(header_row) do
    header_row
    |> String.split("|")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
  end

  defp parse_table_data_rows(rows) do
    rows
    |> Enum.map(fn row ->
      row
      |> String.split("|")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))
    end)
  end

  # Statistics and analysis helpers
  defp calculate_link_statistics(links, categorized) do
    total_links = length(links)
    external_count = length(Map.get(categorized, :external, []))
    internal_count = length(Map.get(categorized, :internal, []))
    anchor_count = length(Map.get(categorized, :anchor, []))

    %{
      total_links: total_links,
      external_links: external_count,
      internal_links: internal_count,
      anchor_links: anchor_count,
      external_ratio: (if total_links > 0, do: external_count / total_links, else: 0),
      internal_ratio: (if total_links > 0, do: internal_count / total_links, else: 0),
      unique_domains: count_unique_domains(links),
      broken_links_detected: 0 # Would be implemented with actual link checking
    }
  end

  defp calculate_example_statistics(examples, categorized) do
    total_examples = length(examples)
    code_blocks = length(Map.get(categorized, :code_block, []))
    inline_code = length(Map.get(categorized, :inline_code, []))

    languages = examples
    |> Enum.map(&Map.get(&1, :language, "unknown"))
    |> Enum.filter(&(&1 != "unknown" and &1 != ""))
    |> Enum.frequencies()

    avg_length = if total_examples > 0 do
      total_chars = examples
      |> Enum.map(&String.length(Map.get(&1, :content, "")))
      |> Enum.sum()
      total_chars / total_examples
    else
      0
    end

    %{
      total_examples: total_examples,
      code_blocks: code_blocks,
      inline_code: inline_code,
      languages_used: Map.keys(languages),
      language_distribution: languages,
      average_length: Float.round(avg_length, 1),
      most_used_language: get_most_frequent_language(languages)
    }
  end

  defp calculate_heading_statistics(headings) do
    all_headings = Enum.flat_map(headings, & &1.headings)

    level_distribution = all_headings
    |> Enum.map(& &1.level)
    |> Enum.frequencies()

    %{
      total_documents: length(headings),
      total_headings: length(all_headings),
      level_distribution: level_distribution,
      average_headings_per_doc: (if length(headings) > 0, do: length(all_headings) / length(headings), else: 0),
      deepest_level: Enum.max(Map.keys(level_distribution), fn -> 0 end)
    }
  end

  defp analyze_heading_depth(headings) do
    depth_analysis = headings
    |> Enum.map(fn file_headings ->
      depths = Enum.map(file_headings.headings, & &1.level)
      %{
        file: file_headings.file,
        max_depth: Enum.max(depths, fn -> 0 end),
        min_depth: Enum.min(depths, fn -> 1 end),
        depth_range: Enum.max(depths, fn -> 0 end) - Enum.min(depths, fn -> 1 end)
      }
    end)

    %{
      per_file_analysis: depth_analysis,
      overall_max_depth: Enum.max(Enum.map(depth_analysis, & &1.max_depth), fn -> 0 end),
      files_with_deep_nesting: Enum.count(depth_analysis, &(&1.max_depth > 4)),
      average_max_depth: (if length(depth_analysis) > 0 do
        Enum.sum(Enum.map(depth_analysis, & &1.max_depth)) / length(depth_analysis)
      else
        0
      end)
    }
  end

  defp generate_auto_toc(tree) do
    %{
      toc_entries: generate_toc_entries(tree),
      toc_html: generate_toc_html(tree),
      toc_markdown: generate_toc_markdown(tree),
      navigation_structure: extract_navigation_structure(tree)
    }
  end

  defp analyze_metadata_schema(metadata) do
    all_fields = metadata
    |> Enum.flat_map(fn file_meta -> Map.keys(file_meta.metadata) end)
    |> Enum.frequencies()

    field_types = metadata
    |> Enum.reduce(%{}, fn file_meta, acc ->
      Enum.reduce(file_meta.metadata, acc, fn {key, value}, field_acc ->
        type = determine_field_type(value)
        Map.update(field_acc, key, [type], fn types -> [type | types] end)
      end)
    end)
    |> Map.new(fn {key, types} -> {key, Enum.frequencies(types)} end)

    %{
      total_files_with_metadata: length(metadata),
      all_fields: Map.keys(all_fields),
      field_frequencies: all_fields,
      field_types: field_types,
      common_fields: Enum.filter(all_fields, fn {_, freq} -> freq > length(metadata) * 0.5 end),
      schema_consistency: calculate_schema_consistency(field_types)
    }
  end

  defp check_metadata_consistency(metadata) do
    if Enum.empty?(metadata) do
      %{consistent: true, issues: []}
    else
      # Check for common field patterns
      common_fields = extract_common_metadata_fields(metadata)

      issues = metadata
      |> Enum.flat_map(fn file_meta ->
        missing_fields = common_fields -- Map.keys(file_meta.metadata)
        Enum.map(missing_fields, fn field ->
          "#{file_meta.file}: Missing common field '#{field}'"
        end)
      end)

      %{
        consistent: Enum.empty?(issues),
        issues: issues,
        consistency_score: (if length(metadata) > 0 do
          (length(metadata) * length(common_fields) - length(issues)) / (length(metadata) * length(common_fields)) * 100
        else
          100
        end)
      }
    end
  end

  defp extract_common_metadata_fields(metadata) do
    threshold = length(metadata) * 0.6 # Fields present in 60% of files

    metadata
    |> Enum.flat_map(fn file_meta -> Map.keys(file_meta.metadata) end)
    |> Enum.frequencies()
    |> Enum.filter(fn {_, freq} -> freq >= threshold end)
    |> Enum.map(fn {field, _} -> field end)
  end

  defp calculate_metadata_statistics(metadata) do
    if Enum.empty?(metadata) do
      %{total_files: 0, total_fields: 0, average_fields_per_file: 0}
    else
      total_fields = metadata
      |> Enum.map(fn file_meta -> map_size(file_meta.metadata) end)
      |> Enum.sum()

      %{
        total_files: length(metadata),
        total_fields: total_fields,
        average_fields_per_file: total_fields / length(metadata),
        files_with_frontmatter: Enum.count(metadata, & &1.has_frontmatter),
        frontmatter_usage: Enum.count(metadata, & &1.has_frontmatter) / length(metadata) * 100
      }
    end
  end
  defp organize_api_documentation(docs), do: Enum.group_by(docs, & &1.type)
  defp analyze_api_coverage(_docs), do: %{}
  defp assess_api_documentation_completeness(_docs), do: %{}
  defp calculate_api_statistics(_docs), do: %{}
  defp build_cross_reference_graph(_files), do: %{}
  defp build_dependency_map(_files), do: %{}
  defp build_relationship_matrix(_graph), do: %{}
  defp calculate_xref_statistics(_graph), do: %{}
  defp identify_orphaned_documents(_graph, _files), do: []
  defp identify_highly_connected_documents(_graph), do: []
  defp analyze_image_usage(_images, _files), do: %{}
  defp check_image_accessibility(_images), do: %{}
  defp identify_broken_images(_images), do: []
  defp identify_image_optimization_opportunities(_images), do: []
  defp calculate_image_statistics(_images), do: %{}
  defp analyze_table_structure(_tables), do: %{}
  defp analyze_table_accessibility(_tables), do: %{}
  defp identify_table_data_patterns(_tables), do: []
  defp calculate_table_statistics(_tables), do: %{}

  defp count_unique_domains(links) do
    links
    |> Enum.filter(fn link -> link.type == :external end)
    |> Enum.map(fn link -> extract_domain(link.url) end)
    |> Enum.uniq()
    |> length()
  end

  defp extract_domain(url) do
    case URI.parse(url) do
      %URI{host: host} when not is_nil(host) -> host
      _ -> "unknown"
    end
  end

  defp get_most_linked_domains(links, limit) do
    links
    |> Enum.filter(fn link -> link.type == :external end)
    |> Enum.map(fn link -> extract_domain(link.url) end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_domain, count} -> count end, :desc)
    |> Enum.take(limit)
  end

  defp extract_programming_languages(examples) do
    examples
    |> Enum.map(fn ex -> Map.get(ex, :language, "unknown") end)
    |> Enum.filter(&(&1 != "unknown" and &1 != ""))
    |> Enum.uniq()
  end

  defp calculate_average_example_length(examples) do
    if Enum.empty?(examples) do
      0
    else
      total_length = examples
      |> Enum.map(fn ex -> String.length(Map.get(ex, :content, "")) end)
      |> Enum.sum()

      total_length / length(examples)
    end
  end

  defp build_file_navigation(headings) do
    # Build hierarchical navigation for a single file
    headings
    |> Enum.reduce([], fn heading, nav ->
      [%{
        text: heading.text,
        anchor: heading.anchor,
        level: heading.level
      } | nav]
    end)
    |> Enum.reverse()
  end

  defp calculate_overall_statistics(results, context) do
    %{
      total_files_processed: context.file_count,
      total_extraction_types: length(context.extraction_types),
      processing_time_ms: System.monotonic_time(:millisecond) - context.start_time,
      extraction_counts: Map.new(results, fn {type, data} -> {type, get_extraction_count(type, data)} end)
    }
  end

  defp generate_extraction_summary(results, context) do
    insights = []

    # Add insights based on extraction results
    insights = if Map.has_key?(results, :links) do
      link_count = get_extraction_count(:links, results[:links])
      ["Found #{link_count} links across documentation" | insights]
    else
      insights
    end

    insights = if Map.has_key?(results, :examples) do
      example_count = get_extraction_count(:examples, results[:examples])
      ["Extracted #{example_count} code examples and snippets" | insights]
    else
      insights
    end

    insights
  end

  defp get_extraction_count(extraction_type, data) do
    case extraction_type do
      :links -> Map.get(data, :total_links, 0)
      :examples -> Map.get(data, :total_examples, 0)
      :toc -> Map.get(data, :total_documents, 0)
      :metadata -> Map.get(data, :total_files_with_metadata, 0)
      :api -> Map.get(data, :total_api_entries, 0)
      :images -> Map.get(data, :total_images, 0)
      :tables -> Map.get(data, :total_tables, 0)
      _ -> 0
    end
  end

  # Helper functions for the new implementations

  defp get_most_frequent_language(languages) do
    case Enum.max_by(languages, fn {_, count} -> count end, fn -> {nil, 0} end) do
      {nil, 0} -> nil
      {lang, _count} -> lang
    end
  end

  defp generate_toc_entries(tree) do
    tree
    |> Enum.flat_map(fn {_file, navigation} ->
      Enum.map(navigation, fn nav_item ->
        %{
          text: nav_item.text,
          anchor: nav_item.anchor,
          level: nav_item.level
        }
      end)
    end)
  end

  defp generate_toc_html(tree) do
    entries = generate_toc_entries(tree)

    entries
    |> Enum.map(fn entry ->
      indent = String.duplicate("  ", entry.level - 1)
      "#{indent}<li><a href=\"##{entry.anchor}\">#{entry.text}</a></li>"
    end)
    |> Enum.join("\n")
    |> then(fn content -> "<ul>\n#{content}\n</ul>" end)
  end

  defp generate_toc_markdown(tree) do
    entries = generate_toc_entries(tree)

    entries
    |> Enum.map(fn entry ->
      indent = String.duplicate("  ", entry.level - 1)
      "#{indent}- [#{entry.text}](##{entry.anchor})"
    end)
    |> Enum.join("\n")
  end

  defp extract_navigation_structure(tree) do
    Map.new(tree, fn {file, navigation} ->
      {Path.basename(file), %{
        file: file,
        sections: length(navigation),
        max_depth: Enum.max(Enum.map(navigation, & &1.level), fn -> 0 end),
        navigation: navigation
      }}
    end)
  end

  defp determine_field_type(value) do
    cond do
      is_binary(value) -> :string
      is_integer(value) -> :integer
      is_float(value) -> :float
      is_boolean(value) -> :boolean
      is_list(value) -> :list
      is_map(value) -> :map
      true -> :unknown
    end
  end

  defp calculate_schema_consistency(field_types) do
    # Calculate how consistent field types are across files
    consistency_scores = Map.new(field_types, fn {field, type_frequencies} ->
      total_occurrences = Enum.sum(Map.values(type_frequencies))
      most_common_count = Enum.max(Map.values(type_frequencies), fn -> 0 end)

      consistency = if total_occurrences > 0 do
        most_common_count / total_occurrences * 100
      else
        100
      end

      {field, Float.round(consistency, 1)}
    end)

    if Enum.empty?(consistency_scores) do
      100
    else
      Enum.sum(Map.values(consistency_scores)) / map_size(consistency_scores)
    end
  end
end
