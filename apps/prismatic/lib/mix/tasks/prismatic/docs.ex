defmodule Mix.Tasks.Prismatic.Docs do
  @moduledoc """
  Comprehensive documentation system tasks with automated tooling and standardized navigation.

  This task provides command-line access to the Prismatic documentation system,
  enabling automated documentation generation, analysis, validation, and maintenance
  through Mix commands integrated with the broader Prismatic tooling ecosystem.

  ## Available Commands

  - `mix prismatic.docs generate` - Generate comprehensive documentation
  - `mix prismatic.docs analyze` - Analyze documentation gaps and issues
  - `mix prismatic.docs validate` - Validate links and code examples
  - `mix prismatic.docs update` - Update cross-references and navigation
  - `mix prismatic.docs search` - Search documentation content
  - `mix prismatic.docs index` - Build or update search indexes

  ## Examples

      # Generate all documentation formats
      mix prismatic.docs generate

      # Generate specific format with validation
      mix prismatic.docs generate --format html --validate

      # Analyze documentation coverage
      mix prismatic.docs analyze --coverage

      # Validate all links and examples
      mix prismatic.docs validate --strict

      # Update cross-references after file moves
      mix prismatic.docs update --rebuild-refs

      # Search documentation content
      mix prismatic.docs search "GenServer patterns"

      # Build search index
      mix prismatic.docs index --incremental

  ## Configuration

  The documentation system can be configured via Mix config:

      config :prismatic, Prismatic.Docs,
        source_dirs: ["lib", "apps"],
        output_dir: "doc",
        formats: [:html, :pdf],
        validation: %{
          validate_links: true,
          test_code_examples: true,
          strict_mode: false
        },
        github: %{
          repository: "prismatic/prismatic",
          branch: "main"
        }

  ## Integration

  This task integrates with:
  - ExDoc for documentation generation
  - GitHub for issue and PR cross-references
  - CI/CD pipelines for automated validation
  - Search engines for content indexing
  - Code analysis tools for completeness checking
  """

  use Mix.Task

  alias Prismatic.Docs
  require Logger

  @shortdoc "Comprehensive documentation system with automated tooling"

  @switches [
    format: [:string, :keep],
    output: :string,
    validate: :boolean,
    coverage: :boolean,
    strict: :boolean,
    rebuild_refs: :boolean,
    incremental: :boolean,
    help: :boolean
  ]

  @aliases [
    f: :format,
    o: :output,
    v: :validate,
    c: :coverage,
    s: :strict,
    r: :rebuild_refs,
    i: :incremental,
    h: :help
  ]

  @impl Mix.Task
  def run(args) do
    {opts, parsed_args, _invalid} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    if opts[:help] do
      show_help()
    else
      ensure_started()
      execute_command(parsed_args, opts)
    end
  end

  defp show_help do
    Mix.shell().info("""

    #{@moduledoc}

    ## Usage

        mix prismatic.docs <command> [options]

    ## Commands

        generate    Generate comprehensive documentation
        analyze     Analyze documentation gaps and issues
        validate    Validate links and code examples
        update      Update cross-references and navigation
        search      Search documentation content
        index       Build or update search indexes

    ## Options

        -f, --format FORMAT     Output format (html, pdf, epub, json, markdown) [multiple]
        -o, --output DIR        Output directory
        -v, --validate          Validate generated documentation
        -c, --coverage          Include coverage analysis
        -s, --strict            Use strict validation mode
        -r, --rebuild-refs      Rebuild all cross-references
        -i, --incremental       Incremental processing
        -h, --help              Show this help

    ## Examples

        mix prismatic.docs generate --format html --validate
        mix prismatic.docs analyze --coverage
        mix prismatic.docs validate --strict
        mix prismatic.docs search "error handling"

    """)
  end

  defp ensure_started do
    Application.ensure_all_started(:prismatic)

    config = Application.get_env(:prismatic, Prismatic.Docs, %{})

    case Docs.start_link(config) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} ->
        Mix.shell().error("Failed to start documentation system: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp execute_command([], _opts) do
    Mix.shell().info("No command specified. Use --help for usage information.")
  end

  defp execute_command(["generate" | _], opts) do
    Mix.shell().info("Generating comprehensive documentation...")

    formats = parse_formats(opts[:format])
    generate_opts = build_generate_opts(opts, formats)

    case Docs.generate_documentation(generate_opts) do
      {:ok, report} ->
        display_generation_results(report)
        if report.status == :success do
          Mix.shell().info("Documentation generation completed successfully!")
        else
          Mix.shell().error("Documentation generation completed with issues.")
          System.halt(1)
        end

      {:error, reason} ->
        Mix.shell().error("Documentation generation failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp execute_command(["analyze" | _], opts) do
    Mix.shell().info("Analyzing documentation...")

    analyze_opts = build_analyze_opts(opts)

    case Docs.analyze_documentation(analyze_opts) do
      {:ok, analysis} ->
        display_analysis_results(analysis, opts[:coverage])

      {:error, reason} ->
        Mix.shell().error("Documentation analysis failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp execute_command(["validate" | _], opts) do
    Mix.shell().info("Validating documentation...")

    validate_opts = build_validate_opts(opts)

    case Docs.validate_documentation(validate_opts) do
      {:ok, validation} ->
        display_validation_results(validation)

        if validation.completeness_score < 80 and opts[:strict] do
          Mix.shell().error("Validation failed: completeness score too low in strict mode")
          System.halt(1)
        end

      {:error, reason} ->
        Mix.shell().error("Documentation validation failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp execute_command(["update" | _], opts) do
    Mix.shell().info("Updating cross-references...")

    update_opts = build_update_opts(opts)

    case Docs.update_cross_references(update_opts) do
      {:ok, update_result} ->
        Mix.shell().info("Updated #{update_result.updated_files} files")
        if update_result.broken_references > 0 do
          Mix.shell().warn("Found #{update_result.broken_references} broken references")
        end

      {:error, reason} ->
        Mix.shell().error("Cross-reference update failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp execute_command(["search" | rest], opts) do
    query = Enum.join(rest, " ")

    if String.trim(query) == "" do
      Mix.shell().error("Search query required")
      System.halt(1)
    end

    Mix.shell().info("Searching documentation for: #{query}")

    case Docs.search_documentation(query, []) do
      {:ok, search_results} ->
        display_search_results(search_results)

      {:error, reason} ->
        Mix.shell().error("Documentation search failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp execute_command(["index" | _], opts) do
    Mix.shell().info("Building search index...")

    index_opts = [incremental: opts[:incremental] || false]

    case Docs.build_search_index(index_opts) do
      {:ok, index_result} ->
        if opts[:incremental] do
          Mix.shell().info("Updated search index for #{index_result.updated_documents} documents")
        else
          Mix.shell().info("Built search index for #{index_result.indexed_documents} documents")
        end

      {:error, reason} ->
        Mix.shell().error("Search index build failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp execute_command([command | _], _opts) do
    Mix.shell().error("Unknown command: #{command}")
    Mix.shell().info("Use --help for available commands")
    System.halt(1)
  end

  # Helper functions for option parsing and result display

  defp parse_formats(nil), do: [:html]
  defp parse_formats(formats) when is_list(formats) do
    Enum.map(formats, &String.to_atom/1)
  end
  defp parse_formats(format) when is_binary(format) do
    [String.to_atom(format)]
  end

  defp build_generate_opts(opts, formats) do
    [
      formats: formats,
      output_dir: opts[:output],
      validate: opts[:validate] || false
    ]
    |> Enum.filter(fn {_k, v} -> v != nil end)
  end

  defp build_analyze_opts(opts) do
    [
      coverage: opts[:coverage] || false
    ]
    |> Enum.filter(fn {_k, v} -> v != nil end)
  end

  defp build_validate_opts(opts) do
    [
      strict_mode: opts[:strict] || false
    ]
    |> Enum.filter(fn {_k, v} -> v != nil end)
  end

  defp build_update_opts(opts) do
    [
      rebuild_all: opts[:rebuild_refs] || false
    ]
    |> Enum.filter(fn {_k, v} -> v != nil end)
  end

  defp display_generation_results(report) do
    Mix.shell().info("")
    Mix.shell().info("=== Documentation Generation Results ===")
    Mix.shell().info("Status: #{report.status}")
    Mix.shell().info("Generated files: #{length(report.generated_files)}")

    if length(report.generated_files) > 0 do
      Mix.shell().info("Files generated:")
      Enum.each(report.generated_files, fn file ->
        Mix.shell().info("  - #{file}")
      end)
    end

    if map_size(report.validation_results) > 0 do
      Mix.shell().info("")
      Mix.shell().info("Validation Results:")
      Mix.shell().info("  Links checked: #{report.validation_results.links_checked}")
      Mix.shell().info("  Broken links: #{length(report.validation_results.broken_links)}")
      Mix.shell().info("  Code examples tested: #{report.validation_results.code_examples_tested}")
      Mix.shell().info("  Failing examples: #{length(report.validation_results.failing_examples)}")
    end

    Mix.shell().info("Documentation coverage: #{Float.round(report.statistics.coverage_percentage, 1)}%")
    Mix.shell().info("")
  end

  defp display_analysis_results(analysis, show_coverage) do
    Mix.shell().info("")
    Mix.shell().info("=== Documentation Analysis Results ===")
    Mix.shell().info("Total modules: #{analysis.total_modules}")
    Mix.shell().info("Documented modules: #{analysis.documented_modules}")
    Mix.shell().info("Missing documentation: #{length(analysis.missing_docs)}")

    if show_coverage do
      Mix.shell().info("Coverage score: #{Float.round(analysis.coverage_score, 1)}%")
    end

    if length(analysis.broken_links) > 0 do
      Mix.shell().info("")
      Mix.shell().warn("Broken links found:")
      Enum.each(analysis.broken_links, fn link ->
        Mix.shell().warn("  - #{link}")
      end)
    end

    if length(analysis.missing_docs) > 0 do
      Mix.shell().info("")
      Mix.shell().info("Modules missing documentation:")
      Enum.each(analysis.missing_docs, fn module ->
        Mix.shell().info("  - #{module}")
      end)
    end

    Mix.shell().info("")
  end

  defp display_validation_results(validation) do
    Mix.shell().info("")
    Mix.shell().info("=== Documentation Validation Results ===")
    Mix.shell().info("Links checked: #{validation.links_checked}")
    Mix.shell().info("Broken links: #{length(validation.broken_links)}")
    Mix.shell().info("Code examples tested: #{validation.code_examples_tested}")
    Mix.shell().info("Failing examples: #{length(validation.failing_examples)}")
    Mix.shell().info("Completeness score: #{Float.round(validation.completeness_score, 1)}%")

    if length(validation.broken_links) > 0 do
      Mix.shell().info("")
      Mix.shell().warn("Broken links:")
      Enum.each(validation.broken_links, fn link ->
        Mix.shell().warn("  - #{link.source_file}:#{link.line}: #{link.target}")
      end)
    end

    if length(validation.failing_examples) > 0 do
      Mix.shell().info("")
      Mix.shell().error("Failing code examples:")
      Enum.each(validation.failing_examples, fn example ->
        Mix.shell().error("  - #{example.source_file}:#{example.line}: #{example.error}")
      end)
    end

    Mix.shell().info("")
  end

  defp display_search_results(search_results) do
    Mix.shell().info("")
    Mix.shell().info("=== Search Results ===")
    Mix.shell().info("Query: #{search_results.query}")
    Mix.shell().info("Total results: #{search_results.total}")

    if search_results.total > 0 do
      Mix.shell().info("")
      Mix.shell().info("Results:")
      Enum.each(search_results.results, fn result ->
        Mix.shell().info("  - #{result}")
      end)
    else
      Mix.shell().info("No results found.")
    end

    Mix.shell().info("")
  end
end
