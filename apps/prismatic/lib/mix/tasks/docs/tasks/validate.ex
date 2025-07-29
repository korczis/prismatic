defmodule Mix.Tasks.Docs.Tasks.Validate do
  @moduledoc """
  Validate documentation links and cross-references.

  This task integrates with the existing validation pipeline
  to check documentation consistency and link integrity.

  ## Options

    * `--docs` - Documentation directory (default: docs)
    * `--fix` - Attempt to fix broken links automatically
    * `--report` - Generate detailed validation report
    * `--verbose` - Enable verbose output

  ## Examples

      mix docs.validate
      mix docs.validate --fix --verbose
      mix docs.validate --report
  """

  use Mix.Task

  alias Mix.Tasks.Docs.Shared.{Config, ErrorHandler, OutputFormatter, ProgressMonitor}

  @shortdoc "Validate documentation consistency"

  @task_defaults %{
    fix: false,
    report: false,
    file_prefix: "validation-report"
  }

  @impl Mix.Task
  def run(args) do
    start_time = System.monotonic_time(:millisecond)

    ErrorHandler.safe_execute("validate", "task execution", fn ->
      case parse_and_validate_options(args) do
        {:ok, %{help: true}} ->
          show_comprehensive_help()

        {:ok, options} ->
          run_validation(options, start_time)

        {:error, reason} ->
          ErrorHandler.handle_validation_error(reason, "validate")
      end
    end)
  end

  @doc false
  def parse_and_validate_options(args) do
    {options, _, invalid} = OptionParser.parse(args,
      switches: [
        docs: :string,
        fix: :boolean,
        report: :boolean,
        verbose: :boolean,
        help: :boolean
      ],
      aliases: [
        d: :docs,
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

      options[:docs] && not File.dir?(options[:docs]) ->
        {:error, "Documentation directory '#{options[:docs]}' does not exist"}

      true ->
        :ok
    end
  end

  defp normalize_options(options) do
    base_config = Config.normalize_config(options, @task_defaults)

    Map.merge(base_config, %{
      fix: options[:fix] || false,
      report: options[:report] || false
    })
  end

  defp run_validation(options, start_time) do
    if options.verbose do
      Config.display_config(options, "validation")
    end

    ProgressMonitor.show_simple_progress("Validating documentation in #{options.docs_path}")

    # Validate file access
    ErrorHandler.validate_file_access(options.docs_path, "Documentation directory")

    # Run existing Python validation script
    case System.cmd("python3", ["validate_links.py"], stderr_to_stdout: true) do
      {output, 0} ->
        execution_time = System.monotonic_time(:millisecond) - start_time
        ProgressMonitor.show_completion("Documentation validation", execution_time)

        if options.verbose do
          Mix.shell().info(output)
        end

        if options.report do
          generate_validation_report(options)
        end

      {output, exit_code} ->
        Mix.shell().error("❌ Documentation validation failed (exit code: #{exit_code})")
        Mix.shell().error(output)

        if options.ci_mode do
          System.halt(exit_code)
        else
          System.halt(exit_code)
        end
    end
  end

  defp generate_validation_report(options) do
    # Read the validation report if it exists
    report_file = "docs-links-validation-report.json"

    if File.exists?(report_file) do
      case File.read(report_file) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, report} ->
              print_validation_summary(report)

              # Save enhanced report if requested
              if options.report do
                enhanced_report = enhance_validation_report(report)

                case OutputFormatter.save_results(enhanced_report, options) do
                  :ok ->
                    ProgressMonitor.show_output_saved(options.output_file)
                  {:error, reason} ->
                    ErrorHandler.display_warning("Could not save validation report: #{reason}")
                end
              end

            {:error, _} ->
              ErrorHandler.display_warning("Could not parse validation report")
          end
        {:error, _} ->
          ErrorHandler.display_warning("Could not read validation report")
      end
    else
      ErrorHandler.display_warning("No validation report found")
    end
  end

  defp enhance_validation_report(report) do
    Map.merge(report, %{
      "enhanced_timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "validation_recommendations" => generate_validation_recommendations(report),
      "next_steps" => generate_next_steps(report)
    })
  end

  defp generate_validation_recommendations(report) do
    recommendations = []

    stats = report["summary_statistics"] || %{}
    broken_links = stats["broken_links"] || 0
    total_links = stats["total_internal_links"] || 1

    recommendations = if broken_links > 0 do
      ["Fix #{broken_links} broken links to improve documentation integrity" | recommendations]
    else
      recommendations
    end

    success_rate = stats["validation_success_rate"] || 100
    recommendations = if success_rate < 95 do
      ["Improve link validation success rate (currently #{success_rate}%)" | recommendations]
    else
      recommendations
    end

    recommendations = if length(report["critical_issues"] || []) > 0 do
      ["Address #{length(report["critical_issues"])} critical issues" | recommendations]
    else
      recommendations
    end

    if Enum.empty?(recommendations) do
      ["Documentation validation is healthy - maintain current quality"]
    else
      Enum.reverse(recommendations)
    end
  end

  defp generate_next_steps(report) do
    steps = [
      "Review and fix any broken links identified in the report",
      "Consider implementing automated link checking in CI/CD pipeline",
      "Establish regular documentation health monitoring",
      "Update documentation guidelines to prevent future link issues"
    ]

    # Add specific steps based on issues found
    if length(report["critical_issues"] || []) > 0 do
      ["Address critical issues as high priority" | steps]
    else
      steps
    end
  end

  defp print_validation_summary(report) do
    stats = report["summary_statistics"] || %{}

    Mix.shell().info("\n📋 Validation Report Summary:")
    Mix.shell().info("  Total Links: #{stats["total_internal_links"]}")
    Mix.shell().info("  Valid Links: #{stats["valid_links"]}")
    Mix.shell().info("  Broken Links: #{stats["broken_links"]}")
    Mix.shell().info("  Success Rate: #{stats["validation_success_rate"]}%")

    if report["critical_issues"] && length(report["critical_issues"]) > 0 do
      Mix.shell().info("\n⚠️  Critical Issues:")
      Enum.each(report["critical_issues"], fn issue ->
        Mix.shell().info("    - #{issue["reason"]}")
      end)
    end
  end

  defp show_comprehensive_help do
    Mix.shell().info(@moduledoc)
  end
end
