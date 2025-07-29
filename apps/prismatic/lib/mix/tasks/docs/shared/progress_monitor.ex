defmodule Mix.Tasks.Docs.Shared.ProgressMonitor do
  @moduledoc """
  Centralized progress monitoring for long-running documentation analysis tasks.

  Provides consistent progress tracking, section monitoring, and time estimation
  across all documentation analysis tasks.
  """

  @typedoc "Progress monitor state"
  @type state :: %{
    sections: [String.t()],
    current_section: String.t() | nil,
    progress: integer(),
    start_time: integer(),
    enabled: boolean()
  }

  @doc """
  Start a progress monitor for the given sections.
  """
  @spec start_monitor([String.t()], boolean()) :: pid() | nil
  def start_monitor(sections, enabled \\ true) do
    if enabled do
      spawn(fn ->
        progress_loop(%{
          sections: sections,
          current_section: nil,
          progress: 0,
          start_time: System.monotonic_time(:millisecond),
          enabled: true
        })
      end)
    else
      nil
    end
  end

  @doc """
  Stop the progress monitor.
  """
  @spec stop_monitor(pid() | nil) :: :ok
  def stop_monitor(nil), do: :ok
  def stop_monitor(pid) when is_pid(pid) do
    send(pid, :stop)
    :ok
  end

  @doc """
  Update the current section being processed.
  """
  @spec update_section(pid() | nil, String.t()) :: :ok
  def update_section(nil, _section), do: :ok
  def update_section(pid, section) when is_pid(pid) do
    send(pid, {:update_section, section})
    :ok
  end

  @doc """
  Update progress for the current section.
  """
  @spec update_progress(pid() | nil, String.t(), integer()) :: :ok
  def update_progress(nil, _section, _progress), do: :ok
  def update_progress(pid, section, progress) when is_pid(pid) and progress >= 0 and progress <= 100 do
    send(pid, {:update_progress, section, progress})
    :ok
  end

  @doc """
  Mark a section as completed.
  """
  @spec complete_section(pid() | nil, String.t()) :: :ok
  def complete_section(nil, _section), do: :ok
  def complete_section(pid, section) when is_pid(pid) do
    send(pid, {:complete_section, section})
    :ok
  end

  @doc """
  Display a simple progress indicator without full monitoring.
  """
  @spec show_simple_progress(String.t()) :: :ok
  def show_simple_progress(message) do
    Mix.shell().info([
      :blue, "🔄 ", :reset, message, :blue, "...", :reset
    ])
    :ok
  end

  @doc """
  Display completion message.
  """
  @spec show_completion(String.t(), integer()) :: :ok
  def show_completion(task_name, execution_time) do
    Mix.shell().info([
      :green, "✅ ", task_name, " completed in #{execution_time}ms", :reset
    ])
    :ok
  end

  @doc """
  Display file output message.
  """
  @spec show_output_saved(String.t()) :: :ok
  def show_output_saved(file_path) do
    Mix.shell().info([
      :blue, "📄 Results saved to: ", :cyan, file_path, :reset
    ])
    :ok
  end

  # Private functions

  defp progress_loop(state) do
    receive do
      {:update_section, section} ->
        Mix.shell().info([
          :blue, "🔄 Analyzing ", :cyan, section, :reset, "..."
        ])
        progress_loop(%{state | current_section: section})

      {:update_progress, section, progress} ->
        if state.current_section == section do
          show_progress_bar(progress)
        end
        progress_loop(%{state | progress: progress})

      {:complete_section, section} ->
        Mix.shell().info([
          :green, "✅ Completed ", :cyan, section, :reset, " analysis"
        ])
        progress_loop(state)

      :stop ->
        :ok

    after
      5000 ->
        # Periodic status update for long-running operations
        if state.current_section do
          elapsed = System.monotonic_time(:millisecond) - state.start_time
          Mix.shell().info([
            :light_black, "⏱️  Still processing #{state.current_section} (#{elapsed}ms elapsed)...", :reset
          ])
        end
        progress_loop(state)
    end
  end

  defp show_progress_bar(progress) when progress >= 0 and progress <= 100 do
    bar_width = 40
    filled = round(bar_width * progress / 100)
    empty = bar_width - filled

    bar = String.duplicate("█", filled) <> String.duplicate("░", empty)
    Mix.shell().info([
      "\r  [", :green, bar, :reset, "] #{progress}%"
    ], [:stderr])
  end
end
