defmodule Mix.Tasks.Docs.Tasks.AiData do
  @moduledoc """
  Generate AI-friendly structured data from documentation.

  This task creates optimized data formats for AI assistant
  consumption and interaction.

  ## Options

    * `--docs` - Documentation directory (default: docs)
    * `--format` - Output format: json, yaml, markdown (default: json)
    * `--file` - Output file path (default: ai-structured-data.json)
    * `--include-examples` - Include code examples (default: true)
    * `--include-traceability` - Include traceability data (default: true)
    * `--verbose` - Enable verbose output

  ## Examples

      mix docs.ai_data
      mix docs.ai_data --format yaml
      mix docs.ai_data --no-include-examples
  """

  use Mix.Task

  alias Prismatic.Documentation.AIAssistantIntegration
  alias Mix.Tasks.Docs.Shared.{Config, ErrorHandler, OutputFormatter, ProgressMonitor}

  @shortdoc "Generate AI-friendly structured data"

  @valid_formats ~w(json yaml markdown)

  @task_defaults %{
    format: "json",
    include_examples: true,
    include_traceability: true,
    file_prefix: "ai-structured-data"
  }

  @impl Mix.Task
  def run(args) do
    start_time = System.monotonic_time(:millisecond)

    ErrorHandler.safe_execute("ai_data", "task execution", fn ->
      case parse_and_validate_options(args) do
        {:ok, %{help: true}} ->
          show_comprehensive_help()

        {:ok, options} ->
          run_ai_data_generation(options, start_time)

        {:error, reason} ->
          ErrorHandler.handle_validation_error(reason, "ai_data")
      end
    end)
  end

  @doc false
  def parse_and_validate_options(args) do
    {options, _, invalid} = OptionParser.parse(args,
      switches: [
        docs: :string,
        format: :string,
        file: :string,
        include_examples: :boolean,
        include_traceability: :boolean,
        verbose: :boolean,
        help: :boolean
      ],
      aliases: [
        d: :docs,
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

      options[:format] && options[:format] not in @valid_formats ->
        {:error, "Invalid format '#{options[:format]}'. Available: #{Enum.join(@valid_formats, ", ")}"}

      options[:docs] && not File.dir?(options[:docs]) ->
        {:error, "Documentation directory '#{options[:docs]}' does not exist"}

      true ->
        :ok
    end
  end

  defp normalize_options(options) do
    base_config = Config.normalize_config(options, @task_defaults)

    Map.merge(base_config, %{
      ai_format: String.to_atom(options[:format] || "json"),
      include_examples: Keyword.get(options, :include_examples, true),
      include_traceability: Keyword.get(options, :include_traceability, true)
    })
  end

  defp run_ai_data_generation(options, start_time) do
    if options.verbose do
      Config.display_config(options, "AI data generation")
    end

    ProgressMonitor.show_simple_progress("Generating AI-structured data from #{options.docs_path}")

    # Ensure Mix application is started
    Mix.Task.run("app.start")

    # Validate file access
    ErrorHandler.validate_file_access(options.docs_path, "Documentation directory")
    ErrorHandler.validate_output_directory(options.output_file)

    ai_options = [
      format: options.ai_format,
      include_examples: options.include_examples,
      include_traceability: options.include_traceability
    ]

    result = AIAssistantIntegration.generate_structured_data(options.docs_path, ai_options)

    if options.verbose do
      print_ai_data_summary(result)
    end

    # Save results based on format
    case options.ai_format do
      :json ->
        case OutputFormatter.save_json_output(result, options.output_file) do
          :ok -> :ok
          error -> error
        end
      :yaml ->
        case OutputFormatter.save_yaml_output(result, options.output_file) do
          :ok -> :ok
          error -> error
        end
      _ ->
        case OutputFormatter.save_json_output(result, options.output_file) do
          :ok -> :ok
          error -> error
        end
    end
    |> case do
      :ok ->
        execution_time = System.monotonic_time(:millisecond) - start_time
        ProgressMonitor.show_completion("AI data generation", execution_time)
        ProgressMonitor.show_output_saved(options.output_file)

      {:error, reason} ->
        ErrorHandler.handle_file_error(reason, options.output_file)
    end

    if options.ci_mode do
      OutputFormatter.format_ci_summary(result, "ai_data")
    end
  end

  defp print_ai_data_summary(result) do
    Mix.shell().info("\n🤖 AI Data Summary:")
    Mix.shell().info("  Schema Version: #{result[:schema_version]}")
    Mix.shell().info("  Generation Time: #{result[:generation_timestamp]}")
    Mix.shell().info("  Source Path: #{result[:source_path]}")

    if Map.has_key?(result, :architecture_decisions) do
      Mix.shell().info("  Architecture Decisions: #{length(result[:architecture_decisions][:decisions])}")
    end

    if Map.has_key?(result, :code_examples) and map_size(result[:code_examples]) > 0 do
      Mix.shell().info("  Code Examples: #{length(result[:code_examples][:examples])}")
    end
  end

  defp show_comprehensive_help do
    Mix.shell().info(@moduledoc)
  end
end
