defmodule Mix.Tasks.Prismatic.Shared.ProgressMonitor do
  @moduledoc """
  Enhanced progress monitoring with real-time updates and telemetry integration.

  Provides comprehensive progress tracking for long-running operations with:
  - Real-time progress indicators
  - Task execution telemetry
  - Performance metrics collection
  - CI/CD friendly output modes
  """

  @doc """
  Start monitoring for a specific task.
  """
  @spec start_task_monitoring(String.t()) :: pid() | nil
  def start_task_monitoring(task_name) do
    spawn(fn ->
      monitor_loop(%{
        task_name: task_name,
        start_time: System.monotonic_time(:millisecond),
        status: :running,
        last_update: System.monotonic_time(:millisecond)
      })
    end)
  end

  @doc """
  Stop task monitoring.
  """
  @spec stop_task_monitoring(pid()) :: :ok
  def stop_task_monitoring(monitor_pid) when is_pid(monitor_pid) do
    send(monitor_pid, :stop)
    :ok
  end
  def stop_task_monitoring(_), do: :ok

  @doc """
  Show task completion message.
  """
  @spec show_task_completion(String.t()) :: :ok
  def show_task_completion(task_name) do
    Mix.shell().info([
      :green, "✅ Task ", :cyan, task_name, :reset, " completed successfully"
    ])
    :ok
  end

  @doc """
  Show completion with execution time.
  """
  @spec show_completion(String.t(), integer()) :: :ok
  def show_completion(task_name, execution_time) do
    Mix.shell().info([
      :green, "✅ Task ", :cyan, task_name, :reset,
      " completed in ", :yellow, "#{execution_time}ms", :reset
    ])
    :ok
  end

  @doc """
  Update progress for a specific operation.
  """
  @spec update_progress(pid(), String.t(), integer()) :: :ok
  def update_progress(monitor_pid, operation, progress) when is_pid(monitor_pid) do
    send(monitor_pid, {:progress_update, operation, progress})
    :ok
  end
  def update_progress(_, _, _), do: :ok

  @doc """
  Update status message for current operation.
  """
  @spec update_status(pid(), String.t()) :: :ok
  def update_status(monitor_pid, status_message) when is_pid(monitor_pid) do
    send(monitor_pid, {:status_update, status_message})
    :ok
  end
  def update_status(_, _), do: :ok

  @doc """
  Show immediate progress indicator (for quick operations).
  """
  @spec show_progress_indicator(String.t()) :: :ok
  def show_progress_indicator(message) do
    Mix.shell().info([
      :blue, "🔄 ", :reset, message, "..."
    ])
    :ok
  end

  @doc """
  Show step completion (for multi-step operations).
  """
  @spec show_step_completion(String.t()) :: :ok
  def show_step_completion(step_name) do
    Mix.shell().info([
      :green, "✓ ", :reset, step_name
    ])
    :ok
  end

  @doc """
  Show success message.
  """
  @spec show_success(String.t()) :: :ok
  def show_success(message) do
    Mix.shell().info([
      :green, "✅ ", :reset, message
    ])
    :ok
  end

  @doc """
  Show warning message.
  """
  @spec show_warning(String.t()) :: :ok
  def show_warning(message) do
    Mix.shell().info([
      :yellow, "⚠️  Warning: ", :reset, message
    ])
    :ok
  end

  @doc """
  Show error message.
  """
  @spec show_error(String.t()) :: :ok
  def show_error(message) do
    Mix.shell().error([
      :red, "❌ Error: ", :reset, message
    ])
    :ok
  end

  @doc """
  Show informational message.
  """
  @spec show_info(String.t()) :: :ok
  def show_info(message) do
    Mix.shell().info([
      :blue, "ℹ️  ", :reset, message
    ])
    :ok
  end

  @doc """
  Display progress bar for percentage-based operations.
  """
  @spec show_progress_bar(integer(), String.t()) :: :ok
  def show_progress_bar(progress, message \\ "") when progress >= 0 and progress <= 100 do
    bar_width = 30
    filled = round(bar_width * progress / 100)
    empty = bar_width - filled

    bar = String.duplicate("█", filled) <> String.duplicate("░", empty)

    Mix.shell().info([
      "\r  [", :green, bar, :reset, "] #{progress}% #{message}"
    ], [:stderr])
    :ok
  end

  @doc """
  Display spinner for indeterminate operations.
  """
  @spec show_spinner(String.t()) :: :ok
  def show_spinner(message) do
    frames = ~w(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
    frame = Enum.at(frames, rem(System.monotonic_time(:millisecond), length(frames)))

    Mix.shell().info([
      "\r  ", :blue, frame, :reset, " #{message}..."
    ], [:stderr])
    :ok
  end

  @doc """
  Start a long-running operation with progress indication.
  """
  @spec start_operation(String.t()) :: :ok
  def start_operation(operation_name) do
    if not ci_mode?() do
      show_progress_indicator(operation_name)
    end
    :ok
  end

  @doc """
  Mark operation as completed with success message.
  """
  @spec complete_operation(String.t()) :: :ok
  def complete_operation(completion_message) do
    if not ci_mode?() do
      show_step_completion(completion_message)
    end
    :ok
  end

  # Private functions

  defp monitor_loop(state) do
    receive do
      {:progress_update, operation, progress} ->
        if not ci_mode?() do
          show_progress_bar(progress, operation)
        end
        monitor_loop(%{state | last_update: System.monotonic_time(:millisecond)})

      {:status_update, status_message} ->
        if not ci_mode?() do
          show_info(status_message)
        end
        monitor_loop(%{state | last_update: System.monotonic_time(:millisecond)})

      :stop ->
        :ok

    after
      2000 ->
        # Show periodic status if no updates
        if not ci_mode?() and should_show_heartbeat?(state) do
          elapsed = System.monotonic_time(:millisecond) - state.start_time
          show_spinner("#{state.task_name} (#{format_duration(elapsed)})")
        end
        monitor_loop(state)
    end
  end

  defp ci_mode?() do
    System.get_env("CI") == "true" or System.get_env("GITHUB_ACTIONS") == "true"
  end

  defp should_show_heartbeat?(state) do
    # Show heartbeat every 5 seconds if no recent updates
    elapsed_since_update = System.monotonic_time(:millisecond) - state.last_update
    elapsed_since_update > 5000
  end

  defp format_duration(milliseconds) when milliseconds < 1000 do
    "#{milliseconds}ms"
  end
  defp format_duration(milliseconds) when milliseconds < 60_000 do
    seconds = div(milliseconds, 1000)
    "#{seconds}s"
  end
  defp format_duration(milliseconds) do
    minutes = div(milliseconds, 60_000)
    seconds = div(rem(milliseconds, 60_000), 1000)
    "#{minutes}m #{seconds}s"
  end
end
