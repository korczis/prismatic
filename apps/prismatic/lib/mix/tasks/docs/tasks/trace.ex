defmodule Mix.Tasks.Docs.Tasks.Trace do
  @moduledoc """
  Generate traceability markers between documentation and code.

  This task creates bidirectional references and validates
  cross-reference consistency between documentation and implementation.

  ## Options

    * `--docs` - Documentation directory (default: docs)
    * `--code` - Code directory (default: apps)
    * `--output` - Output format: json, yaml (default: json)
    * `--file` - Output file path (default: traceability-analysis.json)
    * `--matrix` - Generate traceability matrix
    * `--verbose` - Enable verbose output

  ## Examples

      mix docs.trace
      mix docs.trace --matrix --verbose
      mix docs.trace --docs documentation --code lib
  """

  use Mix.Task

  alias Prismatic.Documentation.TraceabilityMarker
  alias Mix.Tasks.Docs.Shared.{Config, ErrorHandler, OutputFormatter, ProgressMonitor}

  @shortdoc "Generate traceability markers"

  @task_defaults %{
    matrix: false,
    file_prefix: "traceability-analysis"
  }

  @impl Mix.Task
  def run(args) do
    start_time = System.monotonic_time(:millisecond)

    ErrorHandler.safe_execute("trace", "task execution", fn ->
      case parse_and_validate_options(args) do
        {:ok, %{help: true}} ->
          show_comprehensive_help()

        {:ok, options} ->
          run_traceability(options, start_time)

        {:error, reason} ->
          ErrorHandler.handle_validation_error(reason, "trace")
      end
    end)
  end

  @doc false
  def parse_and_validate_options(args) do
    {options, _, invalid} = OptionParser.parse(args,
      switches: [
        docs: :string,
        code: :string,
        output: :string,
        file: :string,
        matrix: :boolean,
        verbose: :boolean,
        help: :boolean
      ],
      aliases: [
        d: :docs,
        c: :code,
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

      options[:docs] && not File.dir?(options[:docs]) ->
        {:error, "Documentation directory '#{options[:docs]}' does not exist"}

      options[:code] && not File.dir?(options[:code]) ->
        {:error, "Code directory '#{options[:code]}' does not exist"}

      true ->
        :ok
    end
  end

  defp normalize_options(options) do
    base_config = Config.normalize_config(options, @task_defaults)

    Map.merge(base_config, %{
      matrix: options[:matrix] || false
    })
  end

  defp run_traceability(options, start_time) do
    if options.verbose do
      Config.display_config(options, "traceability")
    end

    ProgressMonitor.show_simple_progress("Generating traceability markers")
    Mix.shell().info("Documentation: #{options.docs_path}")
    Mix.shell().info("Code: #{options.code_path}")

    # Ensure Mix application is started
    Mix.Task.run("app.start")

    # Validate file access
    ErrorHandler.validate_file_access(options.docs_path, "Documentation directory")
    ErrorHandler.validate_file_access(options.code_path, "Code directory")
    ErrorHandler.validate_output_directory(options.output_file)

    result = TraceabilityMarker.generate_markers(options.docs_path, options.code_path)

    if options.verbose do
      print_traceability_summary(result)
    end

    if options.matrix do
      print_traceability_matrix(result[:traceability_matrix])
    end

    # Save results
    case OutputFormatter.save_results(result, options) do
      :ok ->
        execution_time = System.monotonic_time(:millisecond) - start_time
        ProgressMonitor.show_completion("Traceability analysis", execution_time)
        ProgressMonitor.show_output_saved(options.output_file)

      {:error, reason} ->
        ErrorHandler.handle_file_error(reason, options.output_file)
    end

    if options.ci_mode do
      OutputFormatter.format_ci_summary(result, "trace")
    end
  end

  defp print_traceability_summary(result) do
    Mix.shell().info("\n🔗 Traceability Summary:")
    Mix.shell().info("  Documentation References: #{result[:summary][:total_documentation_references]}")
    Mix.shell().info("  Code References: #{result[:summary][:total_code_references]}")
    Mix.shell().info("  Successful Links: #{result[:summary][:successful_links]}")
    Mix.shell().info("  Traceability Score: #{result[:summary][:traceability_score]}%")
    Mix.shell().info("  Orphaned Items: #{result[:summary][:orphaned_items]}")
  end

  defp print_traceability_matrix(nil), do: :ok
  defp print_traceability_matrix(matrix) do
    Mix.shell().info("\n📊 Traceability Matrix:")
    Mix.shell().info("Documentation Files → Code Files")

    Enum.each(matrix[:matrix], fn row ->
      doc_file = Path.basename(row[:documentation_file])
      Mix.shell().info("#{doc_file}: ")

      link_counts = Enum.map(row[:links], fn {_code_file, count} -> count end)
      total_links = Enum.sum(link_counts)

      Mix.shell().info("#{total_links} total links")
    end)
  end

  defp show_comprehensive_help do
    Mix.shell().info(@moduledoc)
  end
end
