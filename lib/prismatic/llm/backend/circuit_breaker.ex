defmodule Prismatic.LLM.Backend.CircuitBreaker do
  @moduledoc """
  Circuit breaker implementation for LLM backend fault tolerance.

  This module implements the circuit breaker pattern to prevent cascade failures
  when LLM backends become unavailable or start failing. It monitors backend
  performance and temporarily disables failing backends to allow recovery.

  ## States

  - `:closed` - Normal operation, requests pass through
  - `:open` - Backend is failing, requests are rejected immediately
  - `:half_open` - Testing if backend has recovered

  ## Configuration

  ```elixir
  config = %{
    failure_threshold: 5,      # Failures before opening circuit
    recovery_timeout: 60_000,  # Time before attempting recovery
    success_threshold: 3       # Successes needed to close circuit
  }
  ```
  """

  use GenServer

  require Logger

  defstruct [
    :name,
    :state,           # :closed, :open, :half_open
    :failure_count,
    :success_count,
    :last_failure_time,
    :failure_threshold,
    :recovery_timeout,
    :success_threshold,
    :metrics
  ]

  @type t :: %__MODULE__{}
  @type state :: :closed | :open | :half_open
  @type backend_name :: atom()

  @default_failure_threshold 5
  @default_recovery_timeout :timer.seconds(60)
  @default_success_threshold 3

  ## Client API

  @doc """
  Starts a circuit breaker for the given backend.
  """
  @spec start_link(backend_name(), keyword()) :: GenServer.on_start()
  def start_link(backend_name, opts \\ []) do
    GenServer.start_link(__MODULE__, {backend_name, opts}, name: via_tuple(backend_name))
  end

  @doc """
  Executes a function with circuit breaker protection.

  ## Examples

      iex> CircuitBreaker.call(:openai, fn -> {:ok, "success"} end)
      {:ok, "success"}

      iex> CircuitBreaker.call(:openai, fn -> {:error, :timeout} end)
      {:error, :timeout}
  """
  @spec call(backend_name(), function()) :: {:ok, term()} | {:error, term()}
  def call(backend_name, fun) when is_function(fun, 0) do
    GenServer.call(via_tuple(backend_name), {:call, fun})
  end

  @doc """
  Gets the current state of the circuit breaker.
  """
  @spec get_state(backend_name()) :: state()
  def get_state(backend_name) do
    GenServer.call(via_tuple(backend_name), :get_state)
  end

  @doc """
  Gets detailed metrics for the circuit breaker.
  """
  @spec get_metrics(backend_name()) :: map()
  def get_metrics(backend_name) do
    GenServer.call(via_tuple(backend_name), :get_metrics)
  end

  @doc """
  Resets the circuit breaker to closed state.
  """
  @spec reset(backend_name()) :: :ok
  def reset(backend_name) do
    GenServer.call(via_tuple(backend_name), :reset)
  end

  ## Server Implementation

  @impl true
  def init({backend_name, opts}) do
    state = %__MODULE__{
      name: backend_name,
      state: :closed,
      failure_count: 0,
      success_count: 0,
      last_failure_time: nil,
      failure_threshold: Keyword.get(opts, :failure_threshold, @default_failure_threshold),
      recovery_timeout: Keyword.get(opts, :recovery_timeout, @default_recovery_timeout),
      success_threshold: Keyword.get(opts, :success_threshold, @default_success_threshold),
      metrics: init_metrics()
    }

    Logger.info("Circuit breaker started for backend: #{backend_name}")
    {:ok, state}
  end

  @impl true
  def handle_call({:call, fun}, _from, %{state: :open} = state) do
    if should_attempt_reset?(state) do
      # Transition to half-open and try the call
      new_state = %{state | state: :half_open, success_count: 0}
      Logger.info("Circuit breaker #{state.name} transitioning to half-open")

      result = attempt_call(fun, new_state)
      {:reply, result, handle_call_result(result, new_state)}
    else
      # Circuit is open, reject immediately
      {:reply, {:error, :circuit_breaker_open}, state}
    end
  end

  def handle_call({:call, fun}, _from, state) do
    result = attempt_call(fun, state)
    new_state = handle_call_result(result, state)
    {:reply, result, new_state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state.state, state}
  end

  def handle_call(:get_metrics, _from, state) do
    metrics = Map.merge(state.metrics, %{
      current_state: state.state,
      failure_count: state.failure_count,
      success_count: state.success_count,
      last_failure_time: state.last_failure_time
    })

    {:reply, metrics, state}
  end

  def handle_call(:reset, _from, state) do
    new_state = %{state |
      state: :closed,
      failure_count: 0,
      success_count: 0,
      last_failure_time: nil
    }

    Logger.info("Circuit breaker #{state.name} manually reset")
    {:reply, :ok, new_state}
  end

  # Private helper functions

  defp via_tuple(backend_name) do
    {:via, Registry, {Prismatic.LLM.CircuitBreakerRegistry, backend_name}}
  end

  defp init_metrics do
    %{
      total_calls: 0,
      successful_calls: 0,
      failed_calls: 0,
      circuit_opens: 0,
      circuit_closes: 0,
      created_at: DateTime.utc_now()
    }
  end

  defp attempt_call(fun, state) do
    start_time = System.monotonic_time(:millisecond)

    try do
      result = fun.()
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Update metrics
      _updated_metrics = update_metrics(state.metrics, :success, duration)

      result
    rescue
      error ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        # Update metrics
        _updated_metrics = update_metrics(state.metrics, :error, duration)

        {:error, error}
    catch
      :exit, reason ->
        {:error, {:exit, reason}}
    end
  end

  defp handle_call_result({:ok, _result}, %{state: :half_open} = state) do
    new_success_count = state.success_count + 1

    if new_success_count >= state.success_threshold do
      # Reset to closed state
      Logger.info("Circuit breaker #{state.name} reset to closed state")

      %{state |
        state: :closed,
        failure_count: 0,
        success_count: 0,
        metrics: update_metrics(state.metrics, :circuit_close)
      }
    else
      %{state | success_count: new_success_count}
    end
  end

  defp handle_call_result({:ok, _result}, state) do
    # Success in closed state - reset failure count
    %{state | failure_count: 0}
  end

  defp handle_call_result({:error, _reason}, state) do
    new_failure_count = state.failure_count + 1
    new_state = %{state |
      failure_count: new_failure_count,
      last_failure_time: DateTime.utc_now()
    }

    if new_failure_count >= state.failure_threshold and state.state == :closed do
      # Trip the circuit breaker
      Logger.warning("Circuit breaker #{state.name} tripped to open state after #{new_failure_count} failures")

      %{new_state |
        state: :open,
        metrics: update_metrics(state.metrics, :circuit_open)
      }
    else
      new_state
    end
  end

  defp should_attempt_reset?(%{state: :open, last_failure_time: nil}), do: true
  defp should_attempt_reset?(%{state: :open, last_failure_time: last_failure, recovery_timeout: timeout}) do
    DateTime.diff(DateTime.utc_now(), last_failure, :millisecond) >= timeout
  end
  defp should_attempt_reset?(_), do: false

  defp update_metrics(metrics, :success, _duration) do
    %{metrics |
      total_calls: metrics.total_calls + 1,
      successful_calls: metrics.successful_calls + 1
    }
  end

  defp update_metrics(metrics, :error, _duration) do
    %{metrics |
      total_calls: metrics.total_calls + 1,
      failed_calls: metrics.failed_calls + 1
    }
  end

  defp update_metrics(metrics, :circuit_open) do
    %{metrics | circuit_opens: metrics.circuit_opens + 1}
  end

  defp update_metrics(metrics, :circuit_close) do
    %{metrics | circuit_closes: metrics.circuit_closes + 1}
  end
end
