defmodule Prismatic.LLM.Backend.MetricsCollector do
  @moduledoc """
  Comprehensive metrics collection and monitoring for LLM backend operations.

  This module provides real-time metrics collection, aggregation, and analysis
  for LLM backend performance, reliability, and usage patterns. It integrates
  with Elixir's Telemetry system for seamless monitoring and alerting.

  ## Features

  - **Request Metrics**: Latency, throughput, success/failure rates
  - **Token Tracking**: Usage patterns and cost analysis
  - **Error Classification**: Detailed error categorization and trends
  - **Circuit Breaker Monitoring**: State changes and reliability metrics
  - **Health Scoring**: Automated backend health assessment
  - **Telemetry Integration**: Real-time event emission for external monitoring

  ## Architecture

  The MetricsCollector runs as a GenServer that maintains both per-backend
  and global metrics. It processes events asynchronously to avoid impacting
  LLM backend performance while providing real-time insights.

  ## Usage Examples

  ### Basic Usage

      # Start the metrics collector
      {:ok, _pid} = MetricsCollector.start_link()

      # Record successful request
      MetricsCollector.record_request(:openai, :success, %{
        latency: 1200,
        tokens: 150,
        cost: 0.003
      })

      # Record failed request
      MetricsCollector.record_request(:anthropic, :error, :timeout)

      # Get backend metrics
      metrics = MetricsCollector.get_metrics(:openai)

      # Get global summary
      summary = MetricsCollector.get_summary()

  ### Integration with Circuit Breaker

      # Record circuit breaker events
      MetricsCollector.record_circuit_breaker_event(:openai, :open)
      MetricsCollector.record_circuit_breaker_event(:openai, :close)

  ### Telemetry Integration

      # Attach telemetry handler
      :telemetry.attach(
        "my-handler",
        [:prismatic, :llm, :backend, :request],
        &handle_request_event/4,
        nil
      )

  ## Metrics Structure

  ### Backend Metrics

      %{
        total_requests: 1250,
        successful_requests: 1180,
        failed_requests: 70,
        total_tokens: 125_000,
        total_cost: 2.50,
        average_latency: 850.5,
        min_latency: 120,
        max_latency: 3200,
        error_rate: 0.056,
        last_request_time: ~U[2025-01-27 10:30:00Z],
        error_breakdown: %{
          timeout: 25,
          rate_limit: 15,
          server_error: 30
        },
        circuit_breaker: %{
          state: :closed,
          opens: 2,
          closes: 2
        },
        health_score: 0.94
      }

  ### Global Metrics

      %{
        total_requests: 5000,
        successful_requests: 4750,
        failed_requests: 250,
        total_tokens: 500_000,
        total_cost: 10.25,
        average_latency: 920.3,
        error_rate: 0.05,
        requests_per_minute: 45.2,
        error_breakdown: %{...}
      }
  """

  use GenServer

  require Logger

  @telemetry_prefix [:prismatic, :llm, :backend]

  defstruct [
    :backend_metrics,
    :global_metrics,
    :start_time
  ]

  @typedoc "Backend identifier (e.g., :openai, :anthropic)"
  @type backend_name :: atom()

  @typedoc "Request result classification"
  @type request_result :: :success | :error

  @typedoc "Request data containing metrics information"
  @type request_data :: %{
    optional(:latency) => non_neg_integer(),
    optional(:tokens) => non_neg_integer(),
    optional(:cost) => float(),
    optional(:model) => String.t(),
    optional(:error_type) => atom()
  }

  @typedoc "Circuit breaker event types"
  @type circuit_breaker_event :: :open | :close | :half_open

  @typedoc "Backend-specific metrics"
  @type backend_metrics :: %{
    total_requests: non_neg_integer(),
    successful_requests: non_neg_integer(),
    failed_requests: non_neg_integer(),
    total_tokens: non_neg_integer(),
    total_cost: float(),
    average_latency: float(),
    min_latency: non_neg_integer() | nil,
    max_latency: non_neg_integer() | nil,
    error_rate: float(),
    last_request_time: integer() | nil,
    last_success_time: integer() | nil,
    last_error_time: integer() | nil,
    error_breakdown: %{atom() => non_neg_integer()},
    circuit_breaker: %{
      state: :closed | :open | :half_open,
      opens: non_neg_integer(),
      closes: non_neg_integer(),
      last_state_change: integer() | nil
    },
    health_score: float()
  }

  @typedoc "Global metrics across all backends"
  @type global_metrics :: %{
    total_requests: non_neg_integer(),
    successful_requests: non_neg_integer(),
    failed_requests: non_neg_integer(),
    total_tokens: non_neg_integer(),
    total_cost: float(),
    average_latency: float(),
    error_rate: float(),
    requests_per_minute: float(),
    last_request_time: integer() | nil,
    error_breakdown: %{atom() => non_neg_integer()}
  }

  ## Client API

  @doc """
  Starts the metrics collector GenServer.

  ## Options

  - `:name` - Process name (default: `__MODULE__`)
  - `:telemetry_prefix` - Custom telemetry event prefix

  ## Examples

      iex> {:ok, pid} = MetricsCollector.start_link()
      iex> is_pid(pid)
      true

      iex> {:ok, _pid} = MetricsCollector.start_link(name: :my_metrics)
      iex> Process.whereis(:my_metrics) != nil
      true
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Records a request result for the specified backend.

  This function asynchronously records request metrics including latency,
  token usage, cost, and error information. The data is used to calculate
  performance statistics and health scores.

  ## Parameters

  - `backend` - Backend identifier (e.g., `:openai`, `:anthropic`)
  - `result` - Request result (`:success` or `:error`)
  - `data` - Request metadata (latency, tokens, cost, etc.)

  ## Examples

      # Record successful request
      iex> MetricsCollector.record_request(:openai, :success, %{
      ...>   latency: 1200,
      ...>   tokens: 150,
      ...>   cost: 0.003
      ...> })
      :ok

      # Record failed request
      iex> MetricsCollector.record_request(:anthropic, :error, %{
      ...>   latency: 5000,
      ...>   error_type: :timeout
      ...> })
      :ok

      # Minimal success record
      iex> MetricsCollector.record_request(:test, :success, %{})
      :ok
  """
  @spec record_request(backend_name(), request_result(), request_data()) :: :ok
  def record_request(backend, result, data) when is_atom(backend) and result in [:success, :error] do
    timestamp = System.monotonic_time(:millisecond)
    GenServer.cast(__MODULE__, {:record_request, backend, result, data, timestamp})
  end

  @doc """
  Records a circuit breaker state change event.

  This function tracks circuit breaker transitions to monitor backend
  reliability and fault tolerance behavior.

  ## Parameters

  - `backend` - Backend identifier
  - `event` - Circuit breaker event (`:open`, `:close`, `:half_open`)

  ## Examples

      iex> MetricsCollector.record_circuit_breaker_event(:openai, :open)
      :ok

      iex> MetricsCollector.record_circuit_breaker_event(:anthropic, :close)
      :ok

      iex> MetricsCollector.record_circuit_breaker_event(:test, :half_open)
      :ok
  """
  @spec record_circuit_breaker_event(backend_name(), circuit_breaker_event()) :: :ok
  def record_circuit_breaker_event(backend, event)
      when is_atom(backend) and event in [:open, :close, :half_open] do
    timestamp = System.monotonic_time(:millisecond)
    GenServer.cast(__MODULE__, {:circuit_breaker_event, backend, event, timestamp})
  end

  @doc """
  Retrieves metrics for a specific backend.

  Returns comprehensive metrics including request counts, latency statistics,
  error rates, token usage, costs, and health scores.

  ## Parameters

  - `backend` - Backend identifier

  ## Returns

  Backend metrics map with current statistics.

  ## Examples

      iex> MetricsCollector.record_request(:test, :success, %{latency: 100, tokens: 50})
      iex> metrics = MetricsCollector.get_metrics(:test)
      iex> metrics.total_requests
      1
      iex> metrics.successful_requests
      1
      iex> metrics.average_latency
      100.0
  """
  @spec get_metrics(backend_name()) :: backend_metrics()
  def get_metrics(backend) when is_atom(backend) do
    GenServer.call(__MODULE__, {:get_metrics, backend})
  end

  @doc """
  Retrieves global metrics across all backends.

  Returns aggregated metrics combining data from all registered backends.

  ## Returns

  Global metrics map with system-wide statistics.

  ## Examples

      iex> MetricsCollector.record_request(:backend1, :success, %{tokens: 100})
      iex> MetricsCollector.record_request(:backend2, :success, %{tokens: 200})
      iex> global = MetricsCollector.get_global_metrics()
      iex> global.total_requests
      2
      iex> global.total_tokens
      300
  """
  @spec get_global_metrics() :: global_metrics()
  def get_global_metrics do
    GenServer.call(__MODULE__, :get_global_metrics)
  end

  @doc """
  Resets metrics for a specific backend.

  Clears all accumulated metrics for the specified backend, returning
  it to initial state. Useful for testing or periodic metric resets.

  ## Parameters

  - `backend` - Backend identifier to reset

  ## Examples

      iex> MetricsCollector.record_request(:test, :success, %{})
      iex> MetricsCollector.reset_metrics(:test)
      :ok
      iex> metrics = MetricsCollector.get_metrics(:test)
      iex> metrics.total_requests
      0
  """
  @spec reset_metrics(backend_name()) :: :ok
  def reset_metrics(backend) when is_atom(backend) do
    GenServer.call(__MODULE__, {:reset_metrics, backend})
  end

  @doc """
  Retrieves a comprehensive summary of all metrics.

  Returns a complete overview including global metrics, per-backend
  metrics, and system information like uptime.

  ## Returns

  Summary map containing:
  - `:global` - Global metrics
  - `:backends` - Map of backend-specific metrics
  - `:uptime` - System uptime in seconds

  ## Examples

      iex> summary = MetricsCollector.get_summary()
      iex> Map.has_key?(summary, :global)
      true
      iex> Map.has_key?(summary, :backends)
      true
      iex> Map.has_key?(summary, :uptime)
      true
  """
  @spec get_summary() :: %{
    global: global_metrics(),
    backends: %{backend_name() => backend_metrics()},
    uptime: non_neg_integer()
  }
  def get_summary do
    GenServer.call(__MODULE__, :get_summary)
  end

  ## Server Implementation

  @impl true
  def init(opts) do
    # Set up telemetry handlers
    telemetry_prefix = Keyword.get(opts, :telemetry_prefix, @telemetry_prefix)
    setup_telemetry_handlers(telemetry_prefix)

    state = %__MODULE__{
      backend_metrics: %{},
      global_metrics: init_global_metrics(),
      start_time: DateTime.utc_now()
    }

    Logger.info("LLM Backend MetricsCollector started")
    {:ok, state}
  end

  @impl true
  def handle_cast({:record_request, backend, result, data, timestamp}, state) do
    # Update backend-specific metrics
    backend_metrics = update_backend_metrics(state.backend_metrics, backend, result, data, timestamp)

    # Update global metrics
    global_metrics = update_global_metrics(state.global_metrics, result, data, timestamp)

    # Emit telemetry event
    emit_telemetry_event(:request, %{
      backend: backend,
      result: result,
      data: data,
      timestamp: timestamp
    })

    new_state = %{state |
      backend_metrics: backend_metrics,
      global_metrics: global_metrics
    }

    {:noreply, new_state}
  end

  def handle_cast({:circuit_breaker_event, backend, event, timestamp}, state) do
    # Update circuit breaker metrics
    backend_metrics = update_circuit_breaker_metrics(state.backend_metrics, backend, event, timestamp)

    # Emit telemetry event
    emit_telemetry_event(:circuit_breaker, %{
      backend: backend,
      event: event,
      timestamp: timestamp
    })

    new_state = %{state | backend_metrics: backend_metrics}
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:get_metrics, backend}, _from, state) do
    metrics = Map.get(state.backend_metrics, backend, init_backend_metrics())
    {:reply, metrics, state}
  end

  def handle_call(:get_global_metrics, _from, state) do
    {:reply, state.global_metrics, state}
  end

  def handle_call({:reset_metrics, backend}, _from, state) do
    backend_metrics = Map.put(state.backend_metrics, backend, init_backend_metrics())
    new_state = %{state | backend_metrics: backend_metrics}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_summary, _from, state) do
    summary = %{
      global: state.global_metrics,
      backends: state.backend_metrics,
      uptime: DateTime.diff(DateTime.utc_now(), state.start_time, :second)
    }

    {:reply, summary, state}
  end

  ## Private Implementation

  @spec setup_telemetry_handlers(list(atom())) :: :ok | {:error, :already_exists}
  defp setup_telemetry_handlers(prefix) do
    # Attach telemetry handlers for external monitoring systems
    :telemetry.attach_many(
      "prismatic-llm-metrics",
      [
        prefix ++ [:request],
        prefix ++ [:circuit_breaker]
      ],
      &handle_telemetry_event/4,
      nil
    )
  end

  @spec handle_telemetry_event(list(atom()), map(), map(), term()) :: :ok | nil
  defp handle_telemetry_event(event_name, _measurements, metadata, _config) do
    case event_name do
      [:prismatic, :llm, :backend, :request] ->
        if metadata.result == :error do
          Logger.warning("LLM Backend request failed: #{metadata.backend} - #{inspect(metadata.data)}")
        end

      [:prismatic, :llm, :backend, :circuit_breaker] ->
        Logger.info("Circuit breaker event: #{metadata.backend} - #{metadata.event}")

      _ ->
        :ok
    end
  end

  defp emit_telemetry_event(event_type, metadata) do
    event_name = @telemetry_prefix ++ [event_type]
    measurements = %{timestamp: System.monotonic_time(:millisecond)}

    :telemetry.execute(event_name, measurements, metadata)
  end

  defp init_global_metrics do
    %{
      total_requests: 0,
      successful_requests: 0,
      failed_requests: 0,
      total_tokens: 0,
      total_cost: 0.0,
      average_latency: 0.0,
      error_rate: 0.0,
      requests_per_minute: 0.0,
      last_request_time: nil,
      error_breakdown: %{}
    }
  end

  defp init_backend_metrics do
    %{
      total_requests: 0,
      successful_requests: 0,
      failed_requests: 0,
      total_tokens: 0,
      total_cost: 0.0,
      average_latency: 0.0,
      min_latency: nil,
      max_latency: nil,
      error_rate: 0.0,
      last_request_time: nil,
      last_success_time: nil,
      last_error_time: nil,
      error_breakdown: %{},
      circuit_breaker: %{
        state: :closed,
        opens: 0,
        closes: 0,
        last_state_change: nil
      },
      health_score: 1.0
    }
  end

  defp update_backend_metrics(backend_metrics, backend, result, data, timestamp) do
    current_metrics = Map.get(backend_metrics, backend, init_backend_metrics())

    updated_metrics =
      current_metrics
      |> increment_request_count(result)
      |> update_latency_metrics(data)
      |> update_token_metrics(data)
      |> update_cost_metrics(data)
      |> update_error_metrics(result, data)
      |> update_timestamps(result, timestamp)
      |> calculate_derived_metrics()

    Map.put(backend_metrics, backend, updated_metrics)
  end

  defp update_global_metrics(global_metrics, result, data, timestamp) do
    global_metrics
    |> increment_request_count(result)
    |> update_latency_metrics(data)
    |> update_token_metrics(data)
    |> update_cost_metrics(data)
    |> update_error_metrics(result, data)
    |> update_global_timestamps(timestamp)
    |> calculate_global_derived_metrics()
  end

  defp increment_request_count(metrics, :success) do
    %{metrics |
      total_requests: metrics.total_requests + 1,
      successful_requests: metrics.successful_requests + 1
    }
  end

  defp increment_request_count(metrics, :error) do
    %{metrics |
      total_requests: metrics.total_requests + 1,
      failed_requests: metrics.failed_requests + 1
    }
  end

  defp update_latency_metrics(metrics, %{latency: latency}) when is_number(latency) do
    new_average = calculate_running_average(
      metrics.average_latency,
      latency,
      metrics.total_requests + 1
    )

    %{metrics |
      average_latency: new_average,
      min_latency: min_or_nil(metrics.min_latency, latency),
      max_latency: max_or_nil(metrics.max_latency, latency)
    }
  end

  defp update_latency_metrics(metrics, _), do: metrics

  defp update_token_metrics(metrics, %{tokens: tokens}) when is_number(tokens) do
    %{metrics | total_tokens: metrics.total_tokens + tokens}
  end

  defp update_token_metrics(metrics, _), do: metrics

  defp update_cost_metrics(metrics, %{cost: cost}) when is_number(cost) do
    %{metrics | total_cost: metrics.total_cost + cost}
  end

  defp update_cost_metrics(metrics, _), do: metrics

  defp update_error_metrics(metrics, :error, %{error_type: error_type}) do
    error_key = classify_error(error_type)
    current_count = Map.get(metrics.error_breakdown, error_key, 0)

    %{metrics |
      error_breakdown: Map.put(metrics.error_breakdown, error_key, current_count + 1)
    }
  end

  defp update_error_metrics(metrics, :error, error_reason) do
    error_key = classify_error(error_reason)
    current_count = Map.get(metrics.error_breakdown, error_key, 0)

    %{metrics |
      error_breakdown: Map.put(metrics.error_breakdown, error_key, current_count + 1)
    }
  end

  defp update_error_metrics(metrics, :success, _), do: metrics

  defp update_timestamps(metrics, result, timestamp) do
    base_metrics = %{metrics | last_request_time: timestamp}

    case result do
      :success -> %{base_metrics | last_success_time: timestamp}
      :error -> %{base_metrics | last_error_time: timestamp}
    end
  end

  defp update_global_timestamps(metrics, timestamp) do
    %{metrics | last_request_time: timestamp}
  end

  defp calculate_derived_metrics(metrics) do
    error_rate = if metrics.total_requests > 0 do
      metrics.failed_requests / metrics.total_requests
    else
      0.0
    end

    health_score = calculate_health_score(metrics)

    %{metrics |
      error_rate: error_rate,
      health_score: health_score
    }
  end

  defp calculate_global_derived_metrics(metrics) do
    error_rate = if metrics.total_requests > 0 do
      metrics.failed_requests / metrics.total_requests
    else
      0.0
    end

    %{metrics | error_rate: error_rate}
  end

  defp calculate_health_score(metrics) do
    # Simple health score based on error rate and recency
    base_score = 1.0 - metrics.error_rate

    # Reduce score if there are recent errors
    if metrics.last_error_time do
      time_since_error = System.monotonic_time(:millisecond) - metrics.last_error_time
      if time_since_error < 60_000 do  # Less than 1 minute
        base_score * 0.8
      else
        base_score
      end
    else
      base_score
    end
  end

  defp update_circuit_breaker_metrics(backend_metrics, backend, event, timestamp) do
    current_metrics = Map.get(backend_metrics, backend, init_backend_metrics())

    circuit_breaker_metrics = case event do
      :open ->
        %{current_metrics.circuit_breaker |
          state: :open,
          opens: current_metrics.circuit_breaker.opens + 1,
          last_state_change: timestamp
        }

      :close ->
        %{current_metrics.circuit_breaker |
          state: :closed,
          closes: current_metrics.circuit_breaker.closes + 1,
          last_state_change: timestamp
        }

      :half_open ->
        %{current_metrics.circuit_breaker |
          state: :half_open,
          last_state_change: timestamp
        }
    end

    updated_metrics = %{current_metrics | circuit_breaker: circuit_breaker_metrics}
    Map.put(backend_metrics, backend, updated_metrics)
  end

  # Utility functions

  defp calculate_running_average(current_avg, new_value, count) when count > 1 do
    (current_avg * (count - 1) + new_value) / count
  end

  defp calculate_running_average(_, new_value, _), do: new_value / 1

  defp min_or_nil(nil, value), do: value
  defp min_or_nil(current, value), do: min(current, value)

  defp max_or_nil(nil, value), do: value
  defp max_or_nil(current, value), do: max(current, value)

  defp classify_error({:error, reason}), do: classify_error(reason)
  defp classify_error(:timeout), do: :timeout
  defp classify_error(:rate_limit_exceeded), do: :rate_limit
  defp classify_error({:api_error, status, _}) when status in 400..499, do: :client_error
  defp classify_error({:api_error, status, _}) when status in 500..599, do: :server_error
  defp classify_error(:circuit_breaker_open), do: :circuit_breaker
  defp classify_error(_), do: :unknown
end
