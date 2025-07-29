defmodule Mix.Tasks.DocsSync do
  @moduledoc """
  Backward compatibility alias for the legacy docs_sync task.

  This task provides compatibility with the original monolithic docs_sync.ex implementation
  by routing calls to the appropriate new prismatic.sync.* tasks.

  ## Migration Notice

  **DEPRECATED**: This task is provided for backward compatibility only.
  Please migrate to the new modular prismatic.sync.* tasks:

  - `mix docs_sync` -> `mix prismatic.sync.migrate`
  - `mix docs_sync --health` -> `mix prismatic.sync.health`
  - `mix docs_sync --monitor` -> `mix prismatic.sync.health --continuous`

  ## Usage

      # Legacy usage (still supported)
      mix docs_sync --source docs/ --target output/
      mix docs_sync --health
      mix docs_sync --monitor

      # Recommended new usage
      mix prismatic.sync.migrate --source docs/ --target output/
      mix prismatic.sync.health
      mix prismatic.sync.health --continuous

  ## Automatic Migration

  This compatibility layer automatically routes legacy commands to their
  new prismatic equivalents with appropriate option translation.
  """

  use Mix.Task

  alias Mix.Tasks.Prismatic.Sync.{Migrate, Health}
  alias Mix.Tasks.Prismatic.Shared.OutputFormatter

  @shortdoc "Legacy docs_sync task (DEPRECATED - use prismatic.sync.* tasks)"

  @impl Mix.Task
  def run(args) do
    # Show deprecation warning
    show_deprecation_warning()

    # Parse legacy arguments
    {opts, remaining_args, _invalid} = OptionParser.parse(args,
      switches: [
        health: :boolean,
        monitor: :boolean,
        source: :string,
        target: :string,
        strategy: :string,
        conflicts: :string,
        bidirectional: :boolean,
        dry_run: :boolean,
        verbose: :boolean,
        help: :boolean
      ],
      aliases: [
        h: :help,
        s: :source,
        t: :target,
        m: :monitor,
        v: :verbose
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
    DEPRECATION WARNING: The 'mix docs_sync' task is deprecated.

    Please migrate to the new modular prismatic.sync.* tasks:
    • mix prismatic.sync.migrate - Comprehensive content synchronization and migration
    • mix prismatic.sync.health - Synchronization health monitoring and diagnostics

    This compatibility layer will be removed in a future version.
    """)
  end

  defp show_legacy_help do
    OutputFormatter.display_section_header("Legacy Docs Sync Task Help")

    OutputFormatter.display_info("""
    DEPRECATED: This task provides backward compatibility only.

    Legacy Usage:
      mix docs_sync --source docs/ --target output/  # Migration (-> prismatic.sync.migrate)
      mix docs_sync --health                          # Health check (-> prismatic.sync.health)
      mix docs_sync --monitor                         # Monitoring (-> prismatic.sync.health --continuous)

    Recommended Migration:
      mix prismatic.sync.migrate --source docs/ --target output/  # Content synchronization and migration
      mix prismatic.sync.health                                   # Health monitoring and diagnostics
      mix prismatic.sync.health --continuous                      # Continuous monitoring

    For detailed help on new tasks:
      mix help prismatic.sync.migrate
      mix help prismatic.sync.health
    """)
  end

  defp determine_target_task(opts, remaining_args) do
    cond do
      opts[:health] ->
        {:health, build_target_args(opts, remaining_args, :health)}

      opts[:monitor] ->
        # Monitor maps to health with continuous mode
        monitor_args = build_target_args(opts, remaining_args, :monitor)
        {:health, ["--continuous" | monitor_args]}

      opts[:source] || opts[:target] || true ->
        # Default to migrate if source/target specified or no specific task
        {:migrate, build_target_args(opts, remaining_args, :migrate)}
    end
  end

  defp build_target_args(opts, remaining_args, target_task) do
    # Remove the task-specific flags and translate other options
    task_opts = Map.drop(opts, [:health, :monitor])

    # Special handling for monitor -> continuous
    task_opts = if target_task == :monitor do
      Map.put(task_opts, :continuous, true)
    else
      task_opts
    end

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
      :migrate -> "mix prismatic.sync.migrate"
      :health -> "mix prismatic.sync.health"
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
      :migrate ->
        Migrate.run(target_args)
      :health ->
        Health.run(target_args)
    end
  end
end
