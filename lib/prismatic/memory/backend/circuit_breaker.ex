defmodule Prismatic.Memory.Backend.CircuitBreaker do
  @moduledoc """
  Circuit breaker implementation for memory backend operations.

  Provides fault tolerance by monitoring failures and preventing cascading failures
  when backends are experiencing issues. Uses a simple state machine with three states:
  - `:closed` - Normal operation, requests pass through
  - `:open` - Failures detected, requests fail fast
  - `:half_open` - Testing if backend has recovered

  ## Examples

      iex> CircuitBreaker.call(:test_backend, fn -> :ok end)
      :ok

      iex> CircuitBreaker.call(:failing_backend, fn -> raise "error" end)
      {:error, :circuit_open}

  """

  use GenServer
  require Logger

  @type state :: :closed | :open | :half_open
  @type backend_name :: atom()
  @type operation :: (() -> any())
  @type result :: any() | {:error, :circuit_open}

  @doc """
  Execute an operation through the circuit breaker.

  ## Parameters
  - `backend_name` - Name of the backend to track
  - `operation` - Function to execute

  ## Returns
  - Result of the operation if circuit is closed
  - `{:error, :circuit_open}` if circuit is open
  """
  @spec call(backend_name(), operation()) :: result()
  def call(backend_name, operation) when is_atom(backend_name) and is_function(operation, 0) do
    case get_state(backend_name) do
      :closed ->
        execute_with_monitoring(backend_name, operation)

      :open ->
        if should_attempt_reset?(backend_name) do
          set_state(backend_name, :half_open)
          execute_with_monitoring(backend_name, operation)
        else
          {:error, :circuit_open}
        end

      :half_open ->
        execute_with_monitoring(backend_name, operation)
    end
  end

  @doc """
  Get the current state of a circuit breaker.
  """
  @spec get_state(backend_name()) :: state()
  def get_state(backend_name) do
    case :ets.lookup(__MODULE__, backend_name) do
      [{^backend_name, state, _failure_count, _last_failure}] -> state
      [] -> :closed
    end
  end

  @doc """
  Reset a circuit breaker to closed state.
  """
  @spec reset(backend_name()) :: :ok
  def reset(backend_name) do
    :ets.insert(__MODULE__, {backend_name, :closed, 0, nil})
    :ok
  end

  @doc """
  Start the circuit breaker registry.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # GenServer callbacks

  @impl GenServer
  def init(_opts) do
    _table = :ets.new(__MODULE__, [:named_table, :public, :set])
    {:ok, %{}}
  end

  # Private functions

  @spec execute_with_monitoring(backend_name(), operation()) :: result()
  defp execute_with_monitoring(backend_name, operation) do
    result = operation.()
    record_success(backend_name)
    result
  rescue
    error ->
      record_failure(backend_name, error)
      reraise error, __STACKTRACE__
  catch
    :throw, value ->
      record_failure(backend_name, {:throw, value})
      throw(value)

    :exit, reason ->
      record_failure(backend_name, {:exit, reason})
      exit(reason)
  end

  @spec record_success(backend_name()) :: :ok
  defp record_success(backend_name) do
    :ets.insert(__MODULE__, {backend_name, :closed, 0, nil})
    :ok
  end

  @spec record_failure(backend_name(), any()) :: :ok
  defp record_failure(backend_name, _error) do
    current_time = System.monotonic_time(:millisecond)

    {new_state, new_count} =
      case :ets.lookup(__MODULE__, backend_name) do
        [{^backend_name, _state, failure_count, _last_failure}] ->
          new_failure_count = failure_count + 1
          if new_failure_count >= failure_threshold() do
            Logger.warning("Circuit breaker opened for #{backend_name} after #{new_failure_count} failures")
            {:open, new_failure_count}
          else
            {:closed, new_failure_count}
          end
        [] ->
          {:closed, 1}
      end

    :ets.insert(__MODULE__, {backend_name, new_state, new_count, current_time})
    :ok
  end

  @spec set_state(backend_name(), state()) :: :ok
  defp set_state(backend_name, new_state) do
    case :ets.lookup(__MODULE__, backend_name) do
      [{^backend_name, _state, failure_count, last_failure}] ->
        :ets.insert(__MODULE__, {backend_name, new_state, failure_count, last_failure})
      [] ->
        :ets.insert(__MODULE__, {backend_name, new_state, 0, nil})
    end
    :ok
  end

  @spec should_attempt_reset?(backend_name()) :: boolean()
  defp should_attempt_reset?(backend_name) do
    case :ets.lookup(__MODULE__, backend_name) do
      [{^backend_name, :open, _failure_count, last_failure}] when is_integer(last_failure) ->
        current_time = System.monotonic_time(:millisecond)
        current_time - last_failure >= reset_timeout()
      _ ->
        false
    end
  end

  @spec failure_threshold() :: pos_integer()
  defp failure_threshold do
    Application.get_env(:prismatic, :circuit_breaker_failure_threshold, 5)
  end

  @spec reset_timeout() :: pos_integer()
  defp reset_timeout do
    Application.get_env(:prismatic, :circuit_breaker_reset_timeout, 60_000)
  end
end
