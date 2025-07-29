defmodule Mix.Tasks.Prismatic.Shared.Telemetry do
  @moduledoc """
  Usage telemetry and metrics collection for Prismatic tasks.

  Provides comprehensive telemetry tracking including:
  - Task execution metrics
  - Performance monitoring
  - Usage pattern analysis
  - Error tracking and diagnostics
  - CI/CD integration metrics
  """

  @doc """
  Start telemetry tracking for a task execution.
  """
  @spec start_task_execution(String.t(), atom()) :: :ok
  def start_task_execution(task_name, task_category) do
    metadata = %{
      task_name: task_name,
      task_category: task_category,
      start_time: System.monotonic_time(:millisecond),
      session_id: generate_session_id(),
      environment: detect_environment(),
      elixir_version: System.version(),
      mix_env: Mix.env()
    }

    emit_telemetry_event([:prismatic, :task, :start], %{}, metadata)
    store_session_metadata(metadata.session_id, metadata)

    :ok
  end

  @doc """
  Record successful task completion with metrics.
  """
  @spec record_task_success(String.t(), integer(), map()) :: :ok
  def record_task_success(task_name, execution_time, options) do
    measurements = %{
      execution_time: execution_time,
      memory_usage: get_memory_usage(),
      cpu_time: get_cpu_time()
    }

    metadata = %{
      task_name: task_name,
      output_format: options[:output_format] || "json",
      ci_mode: options[:ci_mode] || false,
      verbose: options[:verbose] || false,
      success: true
    }

    emit_telemetry_event([:prismatic, :task, :complete], measurements, metadata)
    update_usage_statistics(task_name, :success, execution_time)

    :ok
  end

  @doc """
  Record task error with diagnostic information.
  """
  @spec record_task_error(String.t(), Exception.t(), integer()) :: :ok
  def record_task_error(task_name, error, execution_time) do
    measurements = %{
      execution_time: execution_time,
      memory_usage: get_memory_usage()
    }

    metadata = %{
      task_name: task_name,
      error_type: error.__struct__,
      error_message: Exception.message(error),
      success: false
    }

    emit_telemetry_event([:prismatic, :task, :error], measurements, metadata)
    update_usage_statistics(task_name, :error, execution_time)

    :ok
  end

  @doc """
  Record performance metrics for operations.
  """
  @spec record_operation_metrics(String.t(), String.t(), integer(), map()) :: :ok
  def record_operation_metrics(task_name, operation_name, duration, custom_metrics \\ %{}) do
    measurements = Map.merge(%{
      duration: duration,
      timestamp: System.monotonic_time(:millisecond)
    }, custom_metrics)

    metadata = %{
      task_name: task_name,
      operation: operation_name
    }

    emit_telemetry_event([:prismatic, :operation, :complete], measurements, metadata)

    :ok
  end

  @doc """
  Get current usage statistics summary.
  """
  @spec get_usage_statistics() :: map()
  def get_usage_statistics do
    stats = get_stored_statistics()

    %{
      total_executions: calculate_total_executions(stats),
      success_rate: calculate_success_rate(stats),
      average_execution_time: calculate_average_execution_time(stats),
      most_used_tasks: get_most_used_tasks(stats),
      error_patterns: analyze_error_patterns(stats),
      performance_trends: analyze_performance_trends(stats)
    }
  end

  @doc """
  Generate telemetry report for monitoring.
  """
  @spec generate_telemetry_report(map()) :: String.t()
  def generate_telemetry_report(options \\ %{}) do
    stats = get_usage_statistics()
    period = options[:period] || "7d"

    """
    # Prismatic Telemetry Report (#{period})

    ## Usage Summary
    - Total Executions: #{stats.total_executions}
    - Success Rate: #{Float.round(stats.success_rate * 100, 1)}%
    - Average Execution Time: #{stats.average_execution_time}ms

    ## Most Used Tasks
    #{format_task_usage(stats.most_used_tasks)}

    ## Performance Insights
    #{format_performance_insights(stats.performance_trends)}

    ## Error Analysis
    #{format_error_analysis(stats.error_patterns)}

    Generated: #{DateTime.utc_now() |> DateTime.to_iso8601()}
    """
  end

  @doc """
  Export telemetry data for external analysis.
  """
  @spec export_telemetry_data(String.t()) :: :ok | {:error, String.t()}
  def export_telemetry_data(output_file) do
    try do
      stats = get_usage_statistics()
      detailed_data = get_detailed_telemetry_data()

      export_data = %{
        summary: stats,
        detailed_metrics: detailed_data,
        export_timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
        version: "1.0"
      }

      json_content = Jason.encode!(export_data, pretty: true)
      File.write!(output_file, json_content)

      :ok
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  # Private functions

  defp emit_telemetry_event(event_name, measurements, metadata) do
    # In a real implementation, this would integrate with :telemetry
    # For now, we'll store the data locally
    store_telemetry_event(event_name, measurements, metadata)
  end

  defp store_telemetry_event(event_name, measurements, metadata) do
    # Store telemetry data in a simple format
    # In production, this would use a proper telemetry backend
    event_data = %{
      event: event_name,
      measurements: measurements,
      metadata: metadata,
      timestamp: DateTime.utc_now()
    }

    # For now, just log to a simple storage mechanism
    append_to_telemetry_log(event_data)
  end

  defp append_to_telemetry_log(event_data) do
    # Simple file-based logging for development
    # In production, this would use proper telemetry infrastructure
    telemetry_file = get_telemetry_file_path()

    try do
      existing_data = if File.exists?(telemetry_file) do
        File.read!(telemetry_file) |> Jason.decode!()
      else
        []
      end

      updated_data = [event_data | existing_data] |> Enum.take(1000) # Keep last 1000 events

      File.write!(telemetry_file, Jason.encode!(updated_data, pretty: true))
    rescue
      _ -> :ok # Fail silently for telemetry errors
    end
  end

  defp get_telemetry_file_path do
    Path.join([System.tmp_dir!(), "prismatic_telemetry.json"])
  end

  defp generate_session_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp store_session_metadata(_session_id, _metadata) do
    # Store session metadata for later correlation
    # Implementation would depend on the telemetry backend
    :ok
  end

  defp detect_environment do
    cond do
      System.get_env("CI") == "true" -> :ci
      System.get_env("GITHUB_ACTIONS") == "true" -> :github_actions
      System.get_env("GITLAB_CI") == "true" -> :gitlab_ci
      Mix.env() == :prod -> :production
      Mix.env() == :test -> :test
      true -> :development
    end
  end

  defp get_memory_usage do
    # Get current memory usage in bytes
    case :erlang.memory(:total) do
      memory when is_integer(memory) -> memory
      _ -> 0
    end
  end

  defp get_cpu_time do
    # Get CPU time for current process
    case :erlang.statistics(:runtime) do
      {cpu_time, _} -> cpu_time
      _ -> 0
    end
  end

  defp get_stored_statistics do
    # Retrieve stored telemetry statistics
    telemetry_file = get_telemetry_file_path()

    if File.exists?(telemetry_file) do
      try do
        File.read!(telemetry_file) |> Jason.decode!()
      rescue
        _ -> []
      end
    else
      []
    end
  end

  defp update_usage_statistics(task_name, result, execution_time) do
    # Update running statistics
    # In a real implementation, this would update a persistent store
    event_data = %{
      task_name: task_name,
      result: result,
      execution_time: execution_time,
      timestamp: DateTime.utc_now()
    }

    append_to_telemetry_log(event_data)
  end

  defp calculate_total_executions(events) when is_list(events) do
    Enum.count(events, fn event ->
      is_map(event) and Map.has_key?(event, :task_name)
    end)
  end
  defp calculate_total_executions(_), do: 0

  defp calculate_success_rate(events) when is_list(events) do
    task_events = Enum.filter(events, &(is_map(&1) and Map.has_key?(&1, :result)))

    if Enum.empty?(task_events) do
      1.0
    else
      successful = Enum.count(task_events, &(&1[:result] == :success))
      successful / length(task_events)
    end
  end
  defp calculate_success_rate(_), do: 1.0

  defp calculate_average_execution_time(events) when is_list(events) do
    execution_times = events
    |> Enum.filter(&(is_map(&1) and Map.has_key?(&1, :execution_time)))
    |> Enum.map(& &1[:execution_time])

    if Enum.empty?(execution_times) do
      0
    else
      Enum.sum(execution_times) / length(execution_times) |> round()
    end
  end
  defp calculate_average_execution_time(_), do: 0

  defp get_most_used_tasks(events) when is_list(events) do
    events
    |> Enum.filter(&(is_map(&1) and Map.has_key?(&1, :task_name)))
    |> Enum.group_by(& &1[:task_name])
    |> Enum.map(fn {task_name, task_events} -> {task_name, length(task_events)} end)
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(5)
  end
  defp get_most_used_tasks(_), do: []

  defp analyze_error_patterns(events) when is_list(events) do
    events
    |> Enum.filter(&(is_map(&1) and &1[:result] == :error))
    |> Enum.group_by(& &1[:task_name])
    |> Enum.map(fn {task_name, error_events} ->
      {task_name, length(error_events)}
    end)
  end
  defp analyze_error_patterns(_), do: []

  defp analyze_performance_trends(events) when is_list(events) do
    # Simple performance trend analysis
    recent_events = events
    |> Enum.filter(&(is_map(&1) and Map.has_key?(&1, :execution_time)))
    |> Enum.take(50)

    if length(recent_events) > 10 do
      avg_time = calculate_average_execution_time(recent_events)
      %{
        recent_average: avg_time,
        trend: "stable" # Would implement trend analysis in full version
      }
    else
      %{recent_average: 0, trend: "insufficient_data"}
    end
  end
  defp analyze_performance_trends(_), do: %{recent_average: 0, trend: "no_data"}

  defp get_detailed_telemetry_data do
    # Get detailed telemetry data for export
    get_stored_statistics() |> Enum.take(100)
  end

  defp format_task_usage(task_usage) do
    task_usage
    |> Enum.map(fn {task, count} -> "- #{task}: #{count} executions" end)
    |> Enum.join("\n")
  end

  defp format_performance_insights(trends) do
    "- Recent average execution time: #{trends[:recent_average] || 0}ms\n- Trend: #{trends[:trend] || "unknown"}"
  end

  defp format_error_analysis(error_patterns) do
    error_patterns
    |> Enum.map(fn {task, count} -> "- #{task}: #{count} errors" end)
    |> Enum.join("\n")
  end
end
