defmodule Prismatic.Memory.Backend.RetryLogic do
  @moduledoc """
  Retry logic implementation for Memory backend resilience.

  This module provides configurable retry mechanisms for memory operations
  that may fail due to transient issues like network timeouts, temporary
  unavailability, or resource contention.

  ## Features

  - **Exponential Backoff**: Progressively longer delays between retries
  - **Jitter**: Random variation to prevent thundering herd
  - **Configurable Limits**: Maximum attempts and timeout controls
  - **Error Classification**: Different retry strategies for different errors
  - **Telemetry Integration**: Metrics and monitoring for retry behavior

  ## Configuration

  ```elixir
  config = %{
    max_attempts: 3,
    base_delay: 1000,        # Base delay in milliseconds
    max_delay: 30_000,       # Maximum delay in milliseconds
    backoff_factor: 2.0,     # Exponential backoff multiplier
    jitter: true,            # Add random jitter
    retryable_errors: [      # Errors that should trigger retry
      :timeout,
      :econnrefused,
      :enetunreach,
      :storage_full
    ]
  }
  ```

  ## Usage Examples

  ### Basic Retry

      RetryLogic.with_retry(fn ->
        make_memory_call()
      end, RetryLogic.memory_retry_config())

  ### Custom Configuration

      config = %{
        max_attempts: 5,
        base_delay: 500,
        retryable_errors: [:timeout, :storage_full]
      }

      RetryLogic.with_retry(fn ->
        risky_operation()
      end, config)
  """

  require Logger

  @typedoc "Retry configuration"
  @type config :: %{
    max_attempts: pos_integer(),
    base_delay: pos_integer(),
    max_delay: pos_integer(),
    backoff_factor: float(),
    jitter: boolean(),
    retryable_errors: [atom()]
  }

  @typedoc "Function to retry"
  @type retryable_function :: (() -> {:ok, term()} | {:error, term()})

  @default_config %{
    max_attempts: 3,
    base_delay: 1_000,
    max_delay: 30_000,
    backoff_factor: 2.0,
    jitter: true,
    retryable_errors: [
      :timeout,
      :econnrefused,
      :enetunreach,
      :storage_full,
      :write_failed,
      :read_failed,
      :temporary_failure
    ]
  }

  @doc """
  Executes a function with retry logic.

  Attempts to execute the given function, retrying on configured errors
  with exponential backoff and jitter.

  ## Parameters

  - `fun` - Function to execute (must return `{:ok, result}` or `{:error, reason}`)
  - `config` - Retry configuration (optional, uses defaults if not provided)

  ## Returns

  - `{:ok, result}` - Function succeeded
  - `{:error, reason}` - Function failed after all retry attempts

  ## Examples

      iex> RetryLogic.with_retry(fn -> {:ok, "success"} end)
      {:ok, "success"}

      iex> RetryLogic.with_retry(fn -> {:error, :not_retryable} end)
      {:error, :not_retryable}

      iex> attempts = Agent.start_link(fn -> 0 end)
      iex> {:ok, pid} = attempts
      iex> RetryLogic.with_retry(fn ->
      ...>   count = Agent.get_and_update(pid, fn x -> {x + 1, x + 1} end)
      ...>   if count < 3, do: {:error, :timeout}, else: {:ok, "success"}
      ...> end, %{max_attempts: 5, base_delay: 1})
      {:ok, "success"}
  """
  @spec with_retry(retryable_function()) :: {:ok, term()} | {:error, term()}
  def with_retry(fun) when is_function(fun, 0) do
    with_retry(fun, @default_config)
  end

  @spec with_retry(retryable_function(), config()) :: {:ok, term()} | {:error, term()}
  def with_retry(fun, config) when is_function(fun, 0) do
    merged_config = Map.merge(@default_config, config)
    do_retry(fun, merged_config, 1, [])
  end

  @doc """
  Returns the default memory retry configuration.

  This configuration is optimized for memory backend operations with
  reasonable defaults for most use cases.

  ## Returns

  Default retry configuration map.

  ## Examples

      iex> config = RetryLogic.memory_retry_config()
      iex> config.max_attempts
      3
      iex> config.base_delay
      1000
  """
  @spec memory_retry_config() :: config()
  def memory_retry_config do
    @default_config
  end

  @doc """
  Returns a retry configuration optimized for LLM backend operations.

  LLM operations typically have longer timeouts and may benefit from
  more aggressive retry strategies due to rate limiting.

  ## Returns

  LLM-optimized retry configuration map.

  ## Examples

      iex> config = RetryLogic.llm_retry_config()
      iex> config.max_attempts
      5
      iex> config.base_delay
      2000
  """
  @spec llm_retry_config() :: config()
  def llm_retry_config do
    %{
      max_attempts: 5,
      base_delay: 2_000,
      max_delay: 60_000,
      backoff_factor: 2.0,
      jitter: true,
      retryable_errors: [
        :timeout,
        :econnrefused,
        :enetunreach,
        :rate_limit_exceeded,
        :server_error,
        :temporary_failure
      ]
    }
  end

  @doc """
  Checks if an error is retryable based on the configuration.

  ## Parameters

  - `error` - Error term to check
  - `config` - Retry configuration

  ## Returns

  - `true` - Error is retryable
  - `false` - Error should not be retried

  ## Examples

      iex> config = RetryLogic.memory_retry_config()
      iex> RetryLogic.retryable_error?(:timeout, config)
      true

      iex> RetryLogic.retryable_error?(:invalid_key, config)
      false
  """
  @spec retryable_error?(term(), config()) :: boolean()
  def retryable_error?(error, config) do
    error_atom = extract_error_atom(error)
    error_atom in config.retryable_errors
  end

  @doc """
  Calculates the delay for a given attempt number.

  Uses exponential backoff with optional jitter to determine
  how long to wait before the next retry attempt.

  ## Parameters

  - `attempt` - Current attempt number (1-based)
  - `config` - Retry configuration

  ## Returns

  Delay in milliseconds.

  ## Examples

      iex> config = %{base_delay: 1000, backoff_factor: 2.0, max_delay: 10000, jitter: false}
      iex> RetryLogic.calculate_delay(1, config)
      1000

      iex> RetryLogic.calculate_delay(2, config)
      2000

      iex> RetryLogic.calculate_delay(10, config)
      10000
  """
  @spec calculate_delay(pos_integer(), config()) :: pos_integer()
  def calculate_delay(attempt, config) when attempt > 0 do
    base_delay = config.base_delay
    backoff_factor = config.backoff_factor
    max_delay = config.max_delay

    # Calculate exponential backoff
    delay = trunc(base_delay * :math.pow(backoff_factor, attempt - 1))

    # Apply maximum delay limit
    capped_delay = min(delay, max_delay)

    # Add jitter if enabled
    if config.jitter do
      add_jitter(capped_delay)
    else
      capped_delay
    end
  end

  ## Private Implementation

  @spec do_retry(retryable_function(), config(), pos_integer(), [term()]) ::
    {:ok, term()} | {:error, term()}
  defp do_retry(fun, config, attempt, previous_errors) do
    start_time = System.monotonic_time(:millisecond)

    case fun.() do
      {:ok, _result} = success ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        # Log successful retry if this wasn't the first attempt
        if attempt > 1 do
          Logger.info("Memory operation succeeded after #{attempt} attempts (#{duration}ms)")
        end

        # Emit telemetry
        emit_retry_telemetry(:success, %{
          attempt: attempt,
          duration: duration,
          previous_errors: previous_errors
        })

        success

      {:error, reason} = error ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time
        updated_errors = [reason | previous_errors]

        # Check if we should retry
        if attempt < config.max_attempts and retryable_error?(reason, config) do
          delay = calculate_delay(attempt, config)

          Logger.warning(
            "Memory operation failed (attempt #{attempt}/#{config.max_attempts}): #{inspect(reason)}. " <>
            "Retrying in #{delay}ms"
          )

          # Emit telemetry for retry attempt
          emit_retry_telemetry(:retry, %{
            attempt: attempt,
            duration: duration,
            error: reason,
            delay: delay
          })

          # Wait before retrying
          Process.sleep(delay)

          # Recursive retry
          do_retry(fun, config, attempt + 1, updated_errors)
        else
          # No more retries or non-retryable error
          Logger.error(
            "Memory operation failed permanently after #{attempt} attempts: #{inspect(reason)}"
          )

          # Emit telemetry for final failure
          emit_retry_telemetry(:failure, %{
            attempt: attempt,
            duration: duration,
            error: reason,
            all_errors: updated_errors
          })

          error
        end
    end
  end

  @spec extract_error_atom(term()) :: atom()
  defp extract_error_atom({:error, reason}), do: extract_error_atom(reason)
  defp extract_error_atom(reason) when is_atom(reason), do: reason
  defp extract_error_atom({reason, _}) when is_atom(reason), do: reason
  defp extract_error_atom(%{__exception__: true} = exception) do
    exception.__struct__
    |> Module.split()
    |> List.last()
    |> String.downcase()
    |> String.to_atom()
  end
  defp extract_error_atom(_), do: :unknown_error

  @spec add_jitter(pos_integer()) :: pos_integer() | float()
  defp add_jitter(delay) do
    # Add up to 25% jitter
    jitter_range = trunc(delay * 0.25)
    jitter = :rand.uniform(jitter_range + 1) - 1
    delay + jitter
  end

  @spec emit_retry_telemetry(atom(), map()) :: :ok
  defp emit_retry_telemetry(event_type, metadata) do
    event_name = [:prismatic, :memory, :backend, :retry, event_type]
    measurements = %{timestamp: System.monotonic_time(:millisecond)}

    :telemetry.execute(event_name, measurements, metadata)
  end
end
