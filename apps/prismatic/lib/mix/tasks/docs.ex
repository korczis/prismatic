defmodule Mix.Tasks.Docs do
  @moduledoc """
  Backward compatibility alias for the legacy docs task.

  This task provides compatibility with the original monolithic docs.ex implementation
  by routing calls to the appropriate new prismatic.docs.* tasks.

  ## Migration Notice

  **DEPRECATED**: This task is provided for backward compatibility only.
  Please migrate to the new modular prismatic.docs.* tasks:

  - `mix docs` -> `mix prismatic.docs.analyze`
  - `mix docs --validate` -> `mix prismatic.docs.validate`
  - `mix docs --report` -> `mix prismatic.docs.report`
  - `mix docs --extract` -> `mix prismatic.docs.extract`

  ## Usage

      # Legacy usage (still supported)
      mix docs
      mix docs --validate
      mix docs --report

      # Recommended new usage
      mix prismatic.docs.analyze
      mix prismatic.docs.validate
      mix prismatic.docs.report

  ## Automatic Migration

  This compatibility layer automatically routes legacy commands to their
  new prismatic equivalents with appropriate option translation.
  """

  use Mix.Task

  alias Mix.Tasks.Prismatic.Docs.{Analyze, Validate, Report}
  alias Mix.Tasks.Prismatic.Shared.OutputFormatter

  @shortdoc "Legacy docs task (DEPRECATED - use prismatic.docs.* tasks)"

  @legacy_option_mappings %{
    # Map old options to new task/option combinations
    validate: {:validate, []},
    report: {:report, []},
    extract: {:extract, []},
    analyze: {:analyze, []},

    # Common options that translate directly
    input: :input,
    output: :output,
    format: :format,
    verbose: :verbose,
    dry_run: :dry_run
  }

  @impl Mix.Task
  def run(args) do
    # Show deprecation warning
    show_deprecation_warning()

    # Parse legacy arguments
    {opts, remaining_args, invalid} = OptionParser.parse(args,
      switches: [
        validate: :boolean,
        report: :boolean,
        extract: :boolean,
        analyze: :boolean,
        input: :string,
        output: :string,
        format: :string,
        verbose: :boolean,
        dry_run: :boolean,
        help: :boolean
      ],
      aliases: [
        v: :validate,
        r: :report,
        h: :help,
        i: :input,
        o: :output,
        f: :format
      ]
    )

    if opts[:help] do
      show_legacy_help()
    else
      # Determine which new task to route to
      {target_task, target_args} = determine_target_task(opts, remaining_args)

      # Show migration suggestion
      show_migration_suggestion(target_task, target_args)

      # Route to the appropriate new task
      route_to_new_task(target_task, target_args)
    end
  end

  # Private implementation

  defp show_deprecation_warning do
    OutputFormatter.display_warning("""
    DEPRECATION WARNING: The 'mix docs' task is deprecated.

    Please migrate to the new modular prismatic.docs.* tasks:
    • mix prismatic.docs.analyze - Comprehensive documentation analysis
    • mix prismatic.docs.validate - Link validation and consistency checks
    • mix prismatic.docs.report - Health reporting and dashboards
    • mix prismatic.docs.extract - Content extraction and processing

    This compatibility layer will be removed in a future version.
    """)
  end

  defp show_legacy_help do
    OutputFormatter.display_section_header("Legacy Docs Task Help")

    OutputFormatter.display_info("""
    DEPRECATED: This task provides backward compatibility only.

    Legacy Usage:
      mix docs                    # Default analysis (-> prismatic.docs.analyze)
      mix docs --validate         # Validation (-> prismatic.docs.validate)
      mix docs --report           # Reporting (-> prismatic.docs.report)
      mix docs --extract          # Extraction (-> prismatic.docs.extract)

    Recommended Migration:
      mix prismatic.docs.analyze  # Comprehensive multi-dimensional analysis
      mix prismatic.docs.validate # Link validation and consistency checks
      mix prismatic.docs.report   # Health reporting and dashboards
      mix prismatic.docs.extract  # Content extraction and processing

    For detailed help on new tasks:
      mix help prismatic.docs.analyze
      mix help prismatic.docs.validate
      mix help prismatic.docs.report
      mix help prismatic.docs.extract
    """)
  end

  defp determine_target_task(opts, remaining_args) do
    cond do
      opts[:validate] ->
        {:validate, build_target_args(opts, remaining_args, :validate)}

      opts[:report] ->
        {:report, build_target_args(opts, remaining_args, :report)}

      opts[:extract] ->
        {:extract, build_target_args(opts, remaining_args, :extract)}

      opts[:analyze] or true ->
        # Default to analyze if no specific task specified
        {:analyze, build_target_args(opts, remaining_args, :analyze)}
    end
  end

  defp build_target_args(opts, remaining_args, target_task) do
    # Remove the task-specific flag and translate other options
    task_opts = Map.drop(opts, [:validate, :report, :extract, :analyze])

    # Build argument list for new task
    translated_args = task_opts
    |> Enum.flat_map(fn {key, value} ->
      case value do
        true -> ["--#{key}"]
        false -> []
        nil -> []
        val -> ["--#{key}", to_string(val)]
      end
    end)

    translated_args ++ remaining_args
  end

  defp show_migration_suggestion(target_task, target_args) do
    new_command = case target_task do
      :analyze -> "mix prismatic.docs.analyze"
      :validate -> "mix prismatic.docs.validate"
      :report -> "mix prismatic.docs.report"
      :extract -> "mix prismatic.docs.extract"
    end

    full_command = if Enum.empty?(target_args) do
      new_command
    else
      "#{new_command} #{Enum.join(target_args, " ")}"
    end

    OutputFormatter.display_info("Routing to: #{full_command}")
    OutputFormatter.display_info("Consider using the new command directly for better performance and features.")
  end

  defp route_to_new_task(target_task, target_args) do
    case target_task do
      :analyze ->
        Analyze.run(target_args)
      :validate ->
        Validate.run(target_args)
      :report ->
        Report.run(target_args)
      :extract ->
        Mix.Tasks.Prismatic.Docs.Extract.run(target_args)
    end
  end
end
