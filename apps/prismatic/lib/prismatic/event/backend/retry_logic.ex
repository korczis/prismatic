defmodule Prismatic.Event.Backend.RetryLogic do
  @moduledoc """
  Retry logic implementation for Event System backend operations.

  This module provides configurable retry mechanisms for event system operations,
  implementing exponential backoff, jitter, and circuit breaker integration
  for robust error handling and recovery.

  ## Retry Strategies

  - **Exponential Backoff**: Delays increase exponentially between retries
  - **Linear Backoff**: Delays increase linearly between retries
  - **Fixed Delay**: Constant delay between retries
  - **Immediate**: No delay between retries (for testing)

  ## Configuration

  Retry policies are configured with:

  - `max_retries`: Maximum number of retry attempts (default: 3)
  - `base_delay`: Base delay in milliseconds (default: 1000)
  - `max_delay`: Maximum delay in milliseconds (default: 30000)
  - `strategy`: Retry strategy (default: :exponential_backoff)
  - `jitter`: Add randomness to delays (default: true)

  ## Usage

  Retry logic is typically used by the Event Protocol layer:

      RetryLogic.with_retry(fn ->
        backend_module.publish(config, event)
      end, RetryLogic.event_retry_config())

  ## Error Classification

  The retry logic classifies errors into:

  - **Retryable**: Temporary failures that may succeed on retry
  - **Non-retryable**: Permanent failures that won't succeed on retry
  - **Circuit Breaker**: Failures handled by circuit breaker
  """

  require Logger

  @type retry_strategy :: :exponential_backoff | :linear_backoff | :fixed_delay | :immediate
  @type retry_config :: %{
    max_retries: non_neg_integer(),
    base_delay: pos_integer(),
    max_delay: pos_integer(),
    strategy: retry_strategy(),
    jitter: boolean()
  }

  @type error_classification :: :retryable | :non_retryable | :circuit_breaker

  @default_config %{
    max_retries: 3,
    base_delay: 1_000,
    max_delay: 30_000,
    strategy: :exponential_backoff,
    jitter: true
  }

  ## Public API

  @doc """
  Execute a function with retry logic.

  Attempts to execute the given function, retrying on retryable failures
  according to the specified retry configuration.

  ## Parameters

  - `fun` - Function to execute (must return {:ok, result} or {:error, reason})
  - `config` - Retry configuration map

  ## Returns

  - `{:ok, result}` - Function succeeded (possibly after retries)
  - `{:error, reason}` - Function failed after all retry attempts

  ## Examples

      iex> config = Prismatic.Event.Backend.RetryLogic.event_retry_config()
      iex> fun = fn -> {:ok, "success"} end
      iex> {:ok, result} = Prismatic.Event.Backend.RetryLogic.with_retry(fun, config)
      iex> result
      "success"

      # With retryable failure that eventually succeeds
      iex> attempts = :counters.new(1, [])
      iex> fun = fn ->
      ...>   :counters.add(attempts, 1, 1)
      ...>   if :counters.get(attempts, 1) < 3 do
      ...>     {:error, :timeout}
      ...>   else
      ...>     {:ok, "success after retries"}
      ...>   end
      ...> end
      iex> {:ok, result} = Prismatic.Event.Backend.RetryLogic.with_retry(fun, config)
      iex> result
      "success after retries"
  """
  @spec with_retry((() -> {:ok, term()} | {:error, term()}), retry_config()) ::
    {:ok, term()} | {:error, term()}
  def with_retry(fun, config \\ @default_config) when is_function(fun, 0) do
    execute_with_retry(fun, config, 0)
  end

  @doc """
  Get default retry configuration for event operations.

  Returns a sensible default configuration for event system operations
  with exponential backoff and jitter.

  ## Returns

  - `retry_config` - Default event retry configuration

  ## Examples

      iex> config = Prismatic.Event.Backend.RetryLogic.event_retry_config()
      iex> config.max_retries
      3
      iex> config.strategy
      :exponential_backoff
  """
  @spec event_retry_config() :: retry_config()
  def event_retry_config do
    @default_config
  end

  @doc """
  Get retry configuration optimized for memory operations.

  Returns a configuration suitable for memory system integration
  with faster retries for transient failures.

  ## Returns

  - `retry_config` - Memory-optimized retry configuration

  ## Examples

      iex> config = Prismatic.Event.Backend.RetryLogic.memory_retry_config()
      iex> config.base_delay
      500
      iex> config.max_retries
      5
  """
  @spec memory_retry_config() :: retry_config()
  def memory_retry_config do
    %{@default_config |
      max_retries: 5,
      base_delay: 500,
      max_delay: 10_000
    }
  end

  @doc """
  Get retry configuration optimized for LLM operations.

  Returns a configuration suitable for LLM backend integration
  with longer delays to handle rate limiting.

  ## Returns

  - `retry_config` - LLM-optimized retry configuration

  ## Examples

      iex> config = Prismatic.Event.Backend.RetryLogic.llm_retry_config()
      iex> config.base_delay
      2000
      iex> config.max_delay
      60000
  """
  @spec llm_retry_config() :: retry_config()
  def llm_retry_config do
    %{@default_config |
      max_retries: 4,
      base_delay: 2_000,
      max_delay: 60_000,
      strategy: :exponential_backoff
    }
  end

  @doc """
  Classify an error for retry decisions.

  Determines whether an error should trigger a retry attempt
  based on the error type and context.

  ## Parameters

  - `error` - Error term to classify

  ## Returns

  - `:retryable` - Error may succeed on retry
  - `:non_retryable` - Error is permanent
  - `:circuit_breaker` - Error should be handled by circuit breaker

  ## Examples

      iex> Prismatic.Event.Backend.RetryLogic.classify_error(:timeout)
      :retryable

      iex> Prismatic.Event.Backend.RetryLogic.classify_error(:invalid_event)
      :non_retryable

      iex> Prismatic.Event.Backend.RetryLogic.classify_error(:circuit_breaker_open)
      :circuit_breaker
  """
  @spec classify_error(term()) :: error_classification()
  def classify_error(error) do
    case error do
      # Network and temporary errors - retryable
      :timeout -> :retryable
      :econnrefused -> :retryable
      :enetunreach -> :retryable
      :ehostunreach -> :retryable
      :enotconn -> :retryable
      :closed -> :retryable
      :socket_closed_remotely -> :retryable
      {:error, :timeout} -> :retryable
      {:error, :econnrefused} -> :retryable
      {:error, :enetunreach} -> :retryable

      # Storage temporary errors - retryable
      :storage_full -> :retryable
      :write_failed -> :retryable
      :read_failed -> :retryable
      :lock_timeout -> :retryable
      :backend_unavailable -> :retryable

      # Circuit breaker errors - handled separately
      :circuit_breaker_open -> :circuit_breaker

      # Rate limiting - retryable with backoff
      :rate_limit_exceeded -> :retryable
      :quota_exceeded -> :retryable
      {:error, :rate_limit_exceeded} -> :retryable

      # Validation and configuration errors - non-retryable
      :invalid_event -> :non_retryable
      :invalid_pattern -> :non_retryable
      :invalid_handler -> :non_retryable
      :invalid_subscription_id -> :non_retryable
      :invalid_config -> :non_retryable
      :unauthorized -> :non_retryable
      :permission_denied -> :non_retryable
      :not_found -> :non_retryable
      :subscription_not_found -> :non_retryable

      # Server errors - may be retryable
      {:api_error, status, _body} when status >= 500 -> :retryable
      {:api_error, status, _body} when status >= 400 -> :non_retryable

      # Default: classify unknown errors as retryable
      _ -> :retryable
    end
  end

  @doc """
  Calculate delay for a specific retry attempt.

  Computes the delay before the next retry attempt based on
  the retry strategy and attempt number.

  ## Parameters

  - `attempt` - Current attempt number (0-based)
  - `config` - Retry configuration

  ## Returns

  - `delay_ms` - Delay in milliseconds

  ## Examples

      iex> config = Prismatic.Event.Backend.RetryLogic.event_retry_config()
      iex> delay = Prismatic.Event.Backend.RetryLogic.calculate_delay(0, config)
      iex> delay >= 1000 and delay <= 2000  # base_delay with jitter
      true

      iex> config = %{config | jitter: false}
      iex> delay = Prismatic.Event.Backend.RetryLogic.calculate_delay(1, config)
      iex> delay
      2000  # exponential backoff: base_delay * 2^attempt
  """
  @spec calculate_delay(non_neg_integer(), retry_config()) :: non_neg_integer()
  def calculate_delay(attempt, config) do
    base_delay = case config.strategy do
      :exponential_backoff ->
        config.base_delay * :math.pow(2, attempt)

      :linear_backoff ->
        config.base_delay * (attempt + 1)

      :fixed_delay ->
        config.base_delay

      :immediate ->
        0
    end

    # Apply maximum delay limit
    capped_delay = min(trunc(base_delay), config.max_delay)

    # Apply jitter if enabled
    if config.jitter and capped_delay > 0 do
      jitter_range = max(1, div(capped_delay, 4))  # ±25% jitter
      random_offset = :rand.uniform(jitter_range * 2) - jitter_range
      max(0, capped_delay + random_offset)
    else
      capped_delay
    end
  end

  ## Private Implementation

  @spec execute_with_retry(function(), retry_config(), non_neg_integer()) ::
    {:ok, term()} | {:error, term()}
  defp execute_with_retry(fun, config, attempt) do
    start_time = System.monotonic_time()

    case fun.() do
      {:ok, result} ->
        if attempt > 0 do
          duration = System.monotonic_time() - start_time
          emit_telemetry(:retry_success, %{
            attempt: attempt,
            duration: duration
          })
        end
        {:ok, result}

      {:error, reason} ->
        duration = System.monotonic_time() - start_time

        case classify_error(reason) do
          :non_retryable ->
            emit_telemetry(:retry_failed_non_retryable, %{
              attempt: attempt,
              duration: duration,
              reason: reason
            })
            {:error, reason}

          :circuit_breaker ->
            emit_telemetry(:retry_failed_circuit_breaker, %{
              attempt: attempt,
              duration: duration
            })
            {:error, reason}

          :retryable ->
            if attempt < config.max_retries do
              delay = calculate_delay(attempt, config)

              Logger.debug("Retrying operation", %{
                attempt: attempt + 1,
                max_retries: config.max_retries,
                delay: delay,
                reason: reason
              })

              emit_telemetry(:retry_attempt, %{
                attempt: attempt,
                delay: delay,
                duration: duration,
                reason: reason
              })

              if delay > 0 do
                :timer.sleep(delay)
              end

              execute_with_retry(fun, config, attempt + 1)
            else
              emit_telemetry(:retry_exhausted, %{
                attempt: attempt,
                duration: duration,
                reason: reason
              })
              {:error, reason}
            end
        end

      # Handle non-tuple returns as success
      other ->
        if attempt > 0 do
          duration = System.monotonic_time() - start_time
          emit_telemetry(:retry_success, %{
            attempt: attempt,
            duration: duration
          })
        end
        {:ok, other}
    end
  end

  @spec emit_telemetry(atom(), map()) :: :ok
  defp emit_telemetry(event_type, measurements) do
    :telemetry.execute(
      [:prismatic, :event, :backend, :retry, event_type],
      measurements,
      %{}
    )
  end
end
