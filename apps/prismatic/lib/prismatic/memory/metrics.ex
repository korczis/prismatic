defmodule Prismatic.Memory.Metrics do
  @moduledoc """
  Comprehensive metrics collection and monitoring for memory systems.

  This module provides detailed observability into memory system performance,
  usage patterns, and health metrics. It integrates with Telemetry for
  real-time monitoring and supports various metric types including counters,
  gauges, histograms, and custom metrics.

  ## Metric Categories

  - **Performance Metrics**: Operation latency, throughput, error rates
  - **Usage Metrics**: Memory utilization, entry counts, cache hit rates
  - **Health Metrics**: Circuit breaker states, backend availability
  - **Business Metrics**: Memory type usage, consolidation effectiveness
  - **System Metrics**: Memory pressure, eviction rates, cleanup cycles

  ## Examples

      # Initialize metrics collection
      {:ok, _} = MemoryMetrics.start_link()

      # Record operation metrics
      MemoryMetrics.record_operation(:store, :working, 15.2, :success)

      # Update usage metrics
      MemoryMetrics.update_usage(:working, %{entries: 1500, size_bytes: 1024000})

      # Get current metrics
      metrics = MemoryMetrics.get_metrics()

  """

  use GenServer
  require Logger

  @type metric_type :: :counter | :gauge | :histogram | :summary
  @type memory_type :: :working | :episodic | :semantic | :procedural
  @type operation_type :: :store | :retrieve | :search | :forget | :consolidate
  @type operation_result :: :success | :error | :timeout | :circuit_open
  @type backend_type :: :cachex | :nebulex | :mnesia | :layered | :test

  @type metric_value :: number()
  @type timestamp :: integer()
  @type duration_ms :: float()

  @type operation_metric :: %{
    operation: operation_type(),
    memory_type: memory_type(),
    backend_type: backend_type(),
    duration_ms: duration_ms(),
    result: operation_result(),
    timestamp: timestamp()
  }

  @type usage_metric :: %{
    memory_type: memory_type(),
    entries: non_neg_integer(),
    size_bytes: non_neg_integer(),
    hit_rate: float(),
    eviction_count: non_neg_integer(),
    timestamp: timestamp()
  }

  @type health_metric :: %{
    backend_type: backend_type(),
    status: :healthy | :degraded | :unhealthy,
    circuit_state: :closed | :open | :half_open,
    error_rate: float(),
    timestamp: timestamp()
  }

  @type metrics_summary :: %{
    operations: %{operation_type() => %{count: non_neg_integer(), avg_duration: float()}},
    usage: %{memory_type() => usage_metric()},
    health: %{backend_type() => health_metric()},
    system: %{
      total_entries: non_neg_integer(),
      total_size_bytes: non_neg_integer(),
      overall_hit_rate: float(),
      uptime_seconds: non_neg_integer()
    }
  }

  @doc """
  Start the metrics collection server.

  ## Options
  - `:telemetry_prefix` - Prefix for telemetry events (default: `[:prismatic, :memory]`)
  - `:collection_interval` - How often to collect system metrics in ms (default: 30_000)
  - `:retention_period` - How long to keep detailed metrics in ms (default: 1 hour)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Record an operation metric.

  ## Parameters
  - `operation` - Type of operation performed
  - `memory_type` - Memory type involved
  - `duration_ms` - Operation duration in milliseconds
  - `result` - Operation result status
  - `backend_type` - Backend type used (optional)

  ## Examples

      iex> MemoryMetrics.record_operation(:store, :working, 12.5, :success, :cachex)
      :ok

  """
  @spec record_operation(operation_type(), memory_type(), duration_ms(), operation_result()) :: :ok
  def record_operation(operation, memory_type, duration_ms, result) do
    GenServer.cast(__MODULE__, {:record_operation, operation, memory_type, duration_ms, result, :unknown})
  end

  @spec record_operation(operation_type(), memory_type(), duration_ms(), operation_result(), backend_type()) :: :ok
  def record_operation(operation, memory_type, duration_ms, result, backend_type) do
    GenServer.cast(__MODULE__, {:record_operation, operation, memory_type, duration_ms, result, backend_type})
  end

  @doc """
  Update usage metrics for a memory type.

  ## Parameters
  - `memory_type` - Memory type to update
  - `usage_data` - Map containing usage statistics

  ## Examples

      iex> usage = %{entries: 1000, size_bytes: 512000, hit_rate: 0.85, eviction_count: 50}
      iex> MemoryMetrics.update_usage(:working, usage)
      :ok

  """
  @spec update_usage(memory_type(), map()) :: :ok
  def update_usage(memory_type, usage_data) do
    GenServer.cast(__MODULE__, {:update_usage, memory_type, usage_data})
  end

  @doc """
  Update health metrics for a backend.

  ## Parameters
  - `backend_type` - Backend to update
  - `health_data` - Map containing health statistics

  ## Examples

      iex> health = %{status: :healthy, circuit_state: :closed, error_rate: 0.01}
      iex> MemoryMetrics.update_health(:cachex, health)
      :ok

  """
  @spec update_health(backend_type(), map()) :: :ok
  def update_health(backend_type, health_data) do
    GenServer.cast(__MODULE__, {:update_health, backend_type, health_data})
  end

  @doc """
  Get current metrics summary.

  ## Examples

      iex> metrics = MemoryMetrics.get_metrics()
      iex> is_map(metrics.operations)
      true
      iex> is_map(metrics.usage)
      true

  """
  @spec get_metrics() :: metrics_summary()
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  @doc """
  Get detailed operation metrics for a specific operation type.

  ## Parameters
  - `operation` - Operation type to get metrics for
  - `limit` - Maximum number of recent metrics to return (default: 100)

  ## Examples

      iex> recent_stores = MemoryMetrics.get_operation_details(:store, 50)
      iex> is_list(recent_stores)
      true

  """
  @spec get_operation_details(operation_type(), pos_integer()) :: [operation_metric()]
  def get_operation_details(operation, limit \\ 100) do
    GenServer.call(__MODULE__, {:get_operation_details, operation, limit})
  end

  @doc """
  Get performance percentiles for an operation type.

  ## Parameters
  - `operation` - Operation type
  - `memory_type` - Memory type (optional, nil for all)
  - `percentiles` - List of percentiles to calculate (default: [50, 90, 95, 99])

  ## Examples

      iex> percentiles = MemoryMetrics.get_percentiles(:store, :working, [50, 95, 99])
      iex> is_map(percentiles)
      true

  """
  @spec get_percentiles(operation_type(), memory_type() | nil, [number()]) :: %{number() => float()}
  def get_percentiles(operation, memory_type \\ nil, percentiles \\ [50, 90, 95, 99]) do
    GenServer.call(__MODULE__, {:get_percentiles, operation, memory_type, percentiles})
  end

  @doc """
  Reset all metrics (useful for testing).

  ## Examples

      iex> MemoryMetrics.reset_metrics()
      :ok

  """
  @spec reset_metrics() :: :ok
  def reset_metrics do
    GenServer.call(__MODULE__, :reset_metrics)
  end

  @doc """
  Export metrics in Prometheus format.

  ## Examples

      iex> prometheus_data = MemoryMetrics.export_prometheus()
      iex> is_binary(prometheus_data)
      true

  """
  @spec export_prometheus() :: String.t()
  def export_prometheus do
    GenServer.call(__MODULE__, :export_prometheus)
  end

  # GenServer callbacks

  @impl GenServer
  def init(opts) do
    telemetry_prefix = Keyword.get(opts, :telemetry_prefix, [:prismatic, :memory])
    collection_interval = Keyword.get(opts, :collection_interval, 30_000)
    retention_period = Keyword.get(opts, :retention_period, :timer.hours(1))

    # Attach telemetry handlers
    case attach_telemetry_handlers(telemetry_prefix) do
      :ok -> :ok
      {:error, :already_exists} ->
        Logger.debug("Telemetry handlers already attached")
        :ok
    end

    # Schedule periodic collection
    Process.send_after(self(), :collect_system_metrics, collection_interval)

    state = %{
      telemetry_prefix: telemetry_prefix,
      collection_interval: collection_interval,
      retention_period: retention_period,
      start_time: System.monotonic_time(:millisecond),
      operations: [],
      usage: %{},
      health: %{},
      operation_counts: %{},
      operation_durations: %{}
    }

    Logger.info("Memory metrics collection started")
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:record_operation, operation, memory_type, duration_ms, result, backend_type}, state) do
    timestamp = System.monotonic_time(:millisecond)

    operation_metric = %{
      operation: operation,
      memory_type: memory_type,
      backend_type: backend_type,
      duration_ms: duration_ms,
      result: result,
      timestamp: timestamp
    }

    # Emit telemetry event
    :telemetry.execute(
      state.telemetry_prefix ++ [:operation],
      %{duration: duration_ms, count: 1},
      %{operation: operation, memory_type: memory_type, result: result, backend_type: backend_type}
    )

    # Update state
    new_operations = [operation_metric | state.operations]
    |> Enum.take(1000)  # Keep only recent operations

    # Update aggregated counts
    count_key = {operation, memory_type, result}
    new_counts = Map.update(state.operation_counts, count_key, 1, &(&1 + 1))

    # Update duration tracking
    duration_key = {operation, memory_type}
    new_durations = Map.update(state.operation_durations, duration_key, [duration_ms], fn durations ->
      [duration_ms | Enum.take(durations, 999)]
    end)

    new_state = %{state |
      operations: new_operations,
      operation_counts: new_counts,
      operation_durations: new_durations
    }

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:update_usage, memory_type, usage_data}, state) do
    timestamp = System.monotonic_time(:millisecond)

    usage_metric = Map.merge(usage_data, %{
      memory_type: memory_type,
      timestamp: timestamp
    })

    # Emit telemetry event
    :telemetry.execute(
      state.telemetry_prefix ++ [:usage],
      Map.take(usage_metric, [:entries, :size_bytes, :hit_rate, :eviction_count]),
      %{memory_type: memory_type}
    )

    new_usage = Map.put(state.usage, memory_type, usage_metric)
    {:noreply, %{state | usage: new_usage}}
  end

  @impl GenServer
  def handle_cast({:update_health, backend_type, health_data}, state) do
    timestamp = System.monotonic_time(:millisecond)

    health_metric = Map.merge(health_data, %{
      backend_type: backend_type,
      timestamp: timestamp
    })

    # Emit telemetry event
    :telemetry.execute(
      state.telemetry_prefix ++ [:health],
      %{error_rate: Map.get(health_data, :error_rate, 0.0)},
      %{backend_type: backend_type, status: Map.get(health_data, :status, :unknown)}
    )

    new_health = Map.put(state.health, backend_type, health_metric)
    {:noreply, %{state | health: new_health}}
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, state) do
    current_time = System.monotonic_time(:millisecond)
    uptime_seconds = div(current_time - state.start_time, 1000)

    # Calculate operation summaries
    operation_summaries =
      state.operation_counts
      |> Enum.group_by(fn {{operation, _memory_type, _result}, _count} -> operation end)
      |> Enum.map(fn {operation, counts} ->
        total_count = counts |> Enum.map(fn {_key, count} -> count end) |> Enum.sum()

        avg_duration =
          case Map.get(state.operation_durations, {operation, :all}) do
            nil -> 0.0
            durations -> Enum.sum(durations) / length(durations)
          end

        {operation, %{count: total_count, avg_duration: avg_duration}}
      end)
      |> Enum.into(%{})

    # Calculate system totals
    total_entries = state.usage |> Map.values() |> Enum.map(&Map.get(&1, :entries, 0)) |> Enum.sum()
    total_size_bytes = state.usage |> Map.values() |> Enum.map(&Map.get(&1, :size_bytes, 0)) |> Enum.sum()

    overall_hit_rate =
      case state.usage |> Map.values() |> Enum.map(&Map.get(&1, :hit_rate, 0.0)) do
        [] -> 0.0
        rates -> Enum.sum(rates) / length(rates)
      end

    metrics = %{
      operations: operation_summaries,
      usage: state.usage,
      health: state.health,
      system: %{
        total_entries: total_entries,
        total_size_bytes: total_size_bytes,
        overall_hit_rate: overall_hit_rate,
        uptime_seconds: uptime_seconds
      }
    }

    {:reply, metrics, state}
  end

  @impl GenServer
  def handle_call({:get_operation_details, operation, limit}, _from, state) do
    details =
      state.operations
      |> Enum.filter(&(&1.operation == operation))
      |> Enum.take(limit)

    {:reply, details, state}
  end

  @impl GenServer
  def handle_call({:get_percentiles, operation, memory_type, percentiles}, _from, state) do
    durations =
      state.operations
      |> Enum.filter(fn metric ->
        metric.operation == operation and
        (memory_type == nil or metric.memory_type == memory_type)
      end)
      |> Enum.map(& &1.duration_ms)
      |> Enum.sort()

    percentile_values =
      percentiles
      |> Enum.map(fn p ->
        index = max(0, round(length(durations) * p / 100) - 1)
        value = Enum.at(durations, index, 0.0)
        {p, value}
      end)
      |> Enum.into(%{})

    {:reply, percentile_values, state}
  end

  @impl GenServer
  def handle_call(:reset_metrics, _from, state) do
    new_state = %{state |
      operations: [],
      usage: %{},
      health: %{},
      operation_counts: %{},
      operation_durations: %{}
    }

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:export_prometheus, _from, state) do
    prometheus_data = format_prometheus_metrics(state)
    {:reply, prometheus_data, state}
  end

  @impl GenServer
  def handle_info(:collect_system_metrics, state) do
    # Collect system-level metrics
    Logger.debug("Collecting system metrics")

    # Schedule next collection
    Process.send_after(self(), :collect_system_metrics, state.collection_interval)

    # Clean up old metrics
    cutoff_time = System.monotonic_time(:millisecond) - state.retention_period
    new_operations = Enum.filter(state.operations, &(&1.timestamp > cutoff_time))

    {:noreply, %{state | operations: new_operations}}
  end

  # Private functions

  @spec attach_telemetry_handlers([atom()]) :: :ok | {:error, :already_exists}
  defp attach_telemetry_handlers(prefix) do
    events = [
      prefix ++ [:operation],
      prefix ++ [:usage],
      prefix ++ [:health]
    ]

    :telemetry.attach_many(
      "memory-metrics-handler",
      events,
      &handle_telemetry_event/4,
      nil
    )
  end

  @spec handle_telemetry_event([atom()], map(), map(), any()) :: :ok
  defp handle_telemetry_event(event, measurements, metadata, _config) do
    Logger.debug("Telemetry event: #{inspect(event)}, measurements: #{inspect(measurements)}, metadata: #{inspect(metadata)}")
    :ok
  end

  @spec format_prometheus_metrics(map()) :: String.t()
  defp format_prometheus_metrics(state) do
    lines = []

    # Operation metrics
    operation_lines =
      state.operation_counts
      |> Enum.map(fn {{operation, memory_type, result}, count} ->
        "prismatic_memory_operations_total{operation=\"#{operation}\",memory_type=\"#{memory_type}\",result=\"#{result}\"} #{count}"
      end)

    # Usage metrics
    usage_lines =
      state.usage
      |> Enum.flat_map(fn {memory_type, usage} ->
        [
          "prismatic_memory_entries{memory_type=\"#{memory_type}\"} #{usage.entries}",
          "prismatic_memory_size_bytes{memory_type=\"#{memory_type}\"} #{usage.size_bytes}",
          "prismatic_memory_hit_rate{memory_type=\"#{memory_type}\"} #{usage.hit_rate}"
        ]
      end)

    # Health metrics
    health_lines =
      state.health
      |> Enum.flat_map(fn {backend_type, health} ->
        status_value = case health.status do
          :healthy -> 1
          :degraded -> 0.5
          :unhealthy -> 0
          _ -> 0
        end

        [
          "prismatic_memory_backend_health{backend_type=\"#{backend_type}\"} #{status_value}",
          "prismatic_memory_error_rate{backend_type=\"#{backend_type}\"} #{health.error_rate}"
        ]
      end)

    all_lines = lines ++ operation_lines ++ usage_lines ++ health_lines
    Enum.join(all_lines, "\n") <> "\n"
  end
end
