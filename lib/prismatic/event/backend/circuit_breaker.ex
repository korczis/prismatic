defmodule Prismatic.Event.Backend.CircuitBreaker do
  @moduledoc """
  Circuit breaker implementation for Event System backend protection.

  This module provides fault tolerance for event system operations by
  implementing the circuit breaker pattern. It prevents cascading failures
  by temporarily stopping requests to failing backends and allowing them
  to recover.

  ## Circuit Breaker States

  - **Closed**: Normal operation, all requests pass through
  - **Open**: Backend is failing, requests are rejected immediately
  - **Half-Open**: Testing recovery, limited requests allowed

  ## Configuration

  Circuit breakers are configured with:

  - `failure_threshold`: Number of failures before opening (default: 5)
  - `recovery_timeout`: Time before attempting recovery (default: 60s)
  - `success_threshold`: Successes needed to close in half-open (default: 2)

  ## Usage

  The circuit breaker is typically used by the Event Protocol layer:

      CircuitBreaker.call(:in_memory, fn ->
        backend_module.publish(config, event)
      end)

  ## Architecture

  Each backend type has its own circuit breaker instance, managed by
  a registry for efficient lookup and isolation of failures.
  """

  use GenServer
  require Logger

  alias Prismatic.Event.CircuitBreakerRegistry

  @type state :: :closed | :open | :half_open
  @type circuit_state :: %{
    state: state(),
    failure_count: non_neg_integer(),
    success_count: non_neg_integer(),
    last_failure_time: DateTime.t() | nil,
    failure_threshold: pos_integer(),
    recovery_timeout: pos_integer(),
    success_threshold: pos_integer()
  }

  @default_failure_threshold 5
  @default_recovery_timeout 60_000
  @default_success_threshold 2

  ## Public API

  @doc """
  Execute a function with circuit breaker protection.

  The function will be executed if the circuit is closed or half-open.
  If the circuit is open, an error is returned immediately.

  ## Parameters

  - `backend_type` - Backend type for circuit identification
  - `fun` - Function to execute

  ## Returns

  - `{:ok, result}` - Function succeeded
  - `{:error, :circuit_breaker_open}` - Circuit is open
  - `{:error, reason}` - Function failed

  ## Examples

      iex> fun = fn -> {:ok, "success"} end
      iex> {:ok, result} = Prismatic.Event.Backend.CircuitBreaker.call(:test, fun)
      iex> result
      "success"

      # When circuit is open
      iex> {:error, :circuit_breaker_open} = Prismatic.Event.Backend.CircuitBreaker.call(:failing_backend, fn -> {:ok, "test"} end)
      {:error, :circuit_breaker_open}
  """
  @spec call(Protocol.backend_type(), (() -> term())) :: {:ok, term()} | {:error, term()}
  def call(backend_type, fun) when is_function(fun, 0) do
    case get_or_create_circuit_breaker(backend_type) do
      {:ok, pid} ->
        GenServer.call(pid, {:execute, fun})
      {:error, reason} ->
        Logger.error("Failed to get circuit breaker", %{backend_type: backend_type, reason: reason})
        {:error, reason}
    end
  end

  @doc """
  Get the current state of a circuit breaker.

  ## Parameters

  - `backend_type` - Backend type for circuit identification

  ## Returns

  - `{:ok, state}` - Current circuit state
  - `{:error, reason}` - Failed to get state

  ## Examples

      iex> {:ok, state} = Prismatic.Event.Backend.CircuitBreaker.state(:test)
      iex> state
      :closed
  """
  @spec state(Protocol.backend_type()) :: {:ok, state()} | {:error, term()}
  def state(backend_type) do
    case get_or_create_circuit_breaker(backend_type) do
      {:ok, pid} ->
        {:ok, GenServer.call(pid, :get_state)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Reset a circuit breaker to closed state.

  Useful for manual recovery or testing scenarios.

  ## Parameters

  - `backend_type` - Backend type for circuit identification

  ## Returns

  - `:ok` - Circuit reset successfully
  - `{:error, reason}` - Reset failed

  ## Examples

      iex> :ok = Prismatic.Event.Backend.CircuitBreaker.reset(:test)
      :ok
  """
  @spec reset(Protocol.backend_type()) :: :ok | {:error, term()}
  def reset(backend_type) do
    case get_or_create_circuit_breaker(backend_type) do
      {:ok, pid} ->
        GenServer.call(pid, :reset)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Start a circuit breaker for a specific backend type.

  ## Parameters

  - `backend_type` - Backend type identifier
  - `opts` - Configuration options

  ## Returns

  - `{:ok, pid}` - Circuit breaker started
  - `{:error, reason}` - Start failed

  ## Examples

      iex> {:ok, pid} = Prismatic.Event.Backend.CircuitBreaker.start_link(:test)
      iex> is_pid(pid)
      true
  """
  @spec start_link(Protocol.backend_type(), keyword()) :: GenServer.on_start()
  def start_link(backend_type, opts \\ []) do
    GenServer.start_link(__MODULE__, {backend_type, opts})
  end

  ## GenServer Callbacks

  @impl GenServer
  def init({backend_type, opts}) do
    # Register with the circuit breaker registry
    case Registry.register(CircuitBreakerRegistry, backend_type, nil) do
      {:ok, _} ->
        state = %{
          backend_type: backend_type,
          state: :closed,
          failure_count: 0,
          success_count: 0,
          last_failure_time: nil,
          failure_threshold: Keyword.get(opts, :failure_threshold, @default_failure_threshold),
          recovery_timeout: Keyword.get(opts, :recovery_timeout, @default_recovery_timeout),
          success_threshold: Keyword.get(opts, :success_threshold, @default_success_threshold)
        }

        Logger.debug("Circuit breaker started", %{backend_type: backend_type})
        {:ok, state}

      {:error, {:already_registered, _pid}} ->
        {:stop, :already_registered}
    end
  end

  @impl GenServer
  def handle_call({:execute, fun}, _from, state) do
    case state.state do
      :closed ->
        execute_function(fun, state)

      :half_open ->
        execute_function(fun, state)

      :open ->
        if should_attempt_reset?(state) do
          new_state = %{state | state: :half_open, success_count: 0}
          execute_function(fun, new_state)
        else
          emit_telemetry(:circuit_breaker_reject, state)
          {:reply, {:error, :circuit_breaker_open}, state}
        end
    end
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state.state, state}
  end

  @impl GenServer
  def handle_call(:reset, _from, state) do
    new_state = %{state |
      state: :closed,
      failure_count: 0,
      success_count: 0,
      last_failure_time: nil
    }

    Logger.info("Circuit breaker reset", %{backend_type: state.backend_type})
    emit_telemetry(:circuit_breaker_reset, new_state)

    {:reply, :ok, new_state}
  end

  ## Private Implementation

  @spec get_or_create_circuit_breaker(Protocol.backend_type()) :: {:ok, pid()} | {:error, term()}
  defp get_or_create_circuit_breaker(backend_type) do
    case Registry.lookup(CircuitBreakerRegistry, backend_type) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        # Start new circuit breaker
        case start_link(backend_type) do
          {:ok, pid} ->
            {:ok, pid}
          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @spec execute_function(function(), circuit_state()) :: {:reply, term(), circuit_state()}
  defp execute_function(fun, state) do
    start_time = System.monotonic_time()

    try do
      case fun.() do
        {:ok, result} ->
          duration = System.monotonic_time() - start_time
          new_state = handle_success(state)
          emit_telemetry(:circuit_breaker_success, state, %{duration: duration})
          {:reply, {:ok, result}, new_state}

        {:error, reason} ->
          duration = System.monotonic_time() - start_time
          new_state = handle_failure(state)
          emit_telemetry(:circuit_breaker_failure, state, %{duration: duration, reason: reason})
          {:reply, {:error, reason}, new_state}

        other ->
          # Treat non-tuple returns as success
          duration = System.monotonic_time() - start_time
          new_state = handle_success(state)
          emit_telemetry(:circuit_breaker_success, state, %{duration: duration})
          {:reply, {:ok, other}, new_state}
      end
    rescue
      error ->
        duration = System.monotonic_time() - start_time
        new_state = handle_failure(state)
        emit_telemetry(:circuit_breaker_exception, state, %{
          duration: duration,
          error: inspect(error)
        })
        {:reply, {:error, {:exception, error}}, new_state}
    end
  end

  @spec handle_success(circuit_state()) :: circuit_state()
  defp handle_success(state) do
    case state.state do
      :closed ->
        # Reset failure count on success
        %{state | failure_count: 0}

      :half_open ->
        new_success_count = state.success_count + 1
        if new_success_count >= state.success_threshold do
          # Close the circuit
          Logger.info("Circuit breaker closed after recovery", %{
            backend_type: state.backend_type,
            success_count: new_success_count
          })
          emit_telemetry(:circuit_breaker_close, state)
          %{state |
            state: :closed,
            failure_count: 0,
            success_count: 0,
            last_failure_time: nil
          }
        else
          %{state | success_count: new_success_count}
        end

      :open ->
        # Shouldn't happen, but handle gracefully
        state
    end
  end

  @spec handle_failure(circuit_state()) :: circuit_state()
  defp handle_failure(state) do
    new_failure_count = state.failure_count + 1
    new_last_failure_time = DateTime.utc_now()

    new_state = %{state |
      failure_count: new_failure_count,
      last_failure_time: new_last_failure_time
    }

    case state.state do
      :closed ->
        if new_failure_count >= state.failure_threshold do
          # Open the circuit
          Logger.warning("Circuit breaker opened", %{
            backend_type: state.backend_type,
            failure_count: new_failure_count,
            threshold: state.failure_threshold
          })
          emit_telemetry(:circuit_breaker_open, new_state)
          %{new_state | state: :open}
        else
          new_state
        end

      :half_open ->
        # Go back to open on any failure in half-open
        Logger.warning("Circuit breaker returned to open state", %{
          backend_type: state.backend_type
        })
        emit_telemetry(:circuit_breaker_open, new_state)
        %{new_state | state: :open, success_count: 0}

      :open ->
        new_state
    end
  end

  @spec should_attempt_reset?(circuit_state()) :: boolean()
  defp should_attempt_reset?(state) do
    if state.last_failure_time do
      elapsed = DateTime.diff(DateTime.utc_now(), state.last_failure_time, :millisecond)
      elapsed >= state.recovery_timeout
    else
      true
    end
  end

  @spec emit_telemetry(atom(), circuit_state(), map()) :: :ok
  defp emit_telemetry(event_type, state, extra_measurements \\ %{}) do
    measurements = Map.merge(%{
      failure_count: state.failure_count,
      success_count: state.success_count
    }, extra_measurements)

    metadata = %{
      backend_type: state.backend_type,
      circuit_state: state.state
    }

    :telemetry.execute(
      [:prismatic, :event, :backend, :circuit_breaker, event_type],
      measurements,
      metadata
    )
  end
end
