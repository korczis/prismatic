defmodule Prismatic.LLM.Backend.RetryLogic do
  @moduledoc """
  Retry logic implementation for LLM backend resilience.

  This module provides configurable retry mechanisms with exponential backoff,
  jitter, and intelligent error classification to improve the reliability of
  LLM backend operations.

  ## Features

  - Exponential backoff with configurable base delay
  - Jitter to prevent thundering herd problems
  - Intelligent error classification (retryable vs non-retryable)
  - Maximum retry limits and timeout handling
  - Comprehensive metrics and logging

  ## Configuration

  ```elixir
  opts = [
    max_retries: 3,
    base_delay: 1000,
    max_delay: 30_000,
    backoff_factor: 2.0,
    jitter: true
  ]
  ```
  """

  require Logger

  @type retry_opts :: [
    max_retries: non_neg_integer(),
    base_delay: non_neg_integer(),
    max_delay: non_neg_integer(),
    backoff_factor: float(),
    jitter: boolean()
  ]

  @default_max_retries 3
  @default_base_delay 1000
  @default_max_delay 30_000
  @default_backoff_factor 2.0
  @default_jitter true

  @doc """
  Executes a function with retry logic.

  ## Examples

      iex> RetryLogic.with_retry(fn -> {:ok, "success"} end, max_retries: 3)
      {:ok, "success"}

      iex> RetryLogic.with_retry(fn -> {:error, :timeout} end, max_retries: 2)
      {:error, :timeout}
  """
  @spec with_retry(function(), retry_opts()) :: {:ok, term()} | {:error, term()}
  def with_retry(fun, opts \\ []) when is_function(fun, 0) do
    max_retries = Keyword.get(opts, :max_retries, @default_max_retries)
    base_delay = Keyword.get(opts, :base_delay, @default_base_delay)
    max_delay = Keyword.get(opts, :max_delay, @default_max_delay)
    backoff_factor = Keyword.get(opts, :backoff_factor, @default_backoff_factor)
    jitter = Keyword.get(opts, :jitter, @default_jitter)

    retry_state = %{
      attempt: 0,
      max_retries: max_retries,
      base_delay: base_delay,
      max_delay: max_delay,
      backoff_factor: backoff_factor,
      jitter: jitter,
      start_time: System.monotonic_time(:millisecond)
    }

    execute_with_retry(fun, retry_state)
  end

  @doc """
  Determines if an error is retryable based on error classification.

  ## Examples

      iex> RetryLogic.retryable_error?({:error, :timeout})
      true

      iex> RetryLogic.retryable_error?({:error, :invalid_api_key})
      false
  """
  @spec retryable_error?(term()) :: boolean()
  def retryable_error?({:error, reason}) do
    network_error?(reason) or
    retryable_api_error?(reason) or
    rate_limit_error?(reason) or
    generic_retryable_error?(reason)
  end

  def retryable_error?(_), do: false

  # Helper functions for error classification

  defp network_error?(reason) do
    case reason do
      :timeout -> true
      :econnrefused -> true
      :econnreset -> true
      :ehostunreach -> true
      :enetunreach -> true
      {:request_failed, _} -> true
      _ -> false
    end
  end

  defp retryable_api_error?(reason) do
    case reason do
      {:api_error, status, _body} when status in [429, 500, 502, 503, 504] -> true
      _ -> false
    end
  end

  defp rate_limit_error?(reason) do
    case reason do
      :rate_limit_exceeded -> true
      _ -> false
    end
  end

  defp generic_retryable_error?(reason) do
    not non_retryable_error?(reason)
  end

  defp non_retryable_error?(reason) do
    non_retryable_api_error?(reason) or
    quota_error?(reason) or
    authentication_error?(reason) or
    validation_error?(reason) or
    circuit_breaker_error?(reason)
  end

  defp non_retryable_api_error?(reason) do
    case reason do
      {:api_error, status, _body} when status in [400, 401, 403, 404] -> true
      _ -> false
    end
  end

  defp quota_error?(reason) do
    reason == :quota_exceeded
  end

  defp authentication_error?(reason) do
    reason in [:invalid_api_key, :authentication_failed, :authorization_failed]
  end

  defp validation_error?(reason) do
    reason in [:invalid_request, :invalid_model, :invalid_parameters]
  end

  defp circuit_breaker_error?(reason) do
    reason == :circuit_breaker_open
  end

  # Private helper functions

  defp execute_with_retry(_fun, %{attempt: attempt, max_retries: max_retries})
       when attempt > max_retries do
    Logger.warning("Max retries (#{max_retries}) exceeded")
    {:error, :max_retries_exceeded}
  end

  defp execute_with_retry(fun, state) do
    attempt_start = System.monotonic_time(:millisecond)

    case safe_execute(fun) do
      {:ok, _result} = success ->
        log_success(state, attempt_start)
        success

      {:error, reason} = error ->
        if retryable_error?(error) and state.attempt < state.max_retries do
          log_retry_attempt(state, reason, attempt_start)
          delay = calculate_delay(state)
          Process.sleep(delay)

          new_state = %{state | attempt: state.attempt + 1}
          execute_with_retry(fun, new_state)
        else
          log_final_failure(state, reason, attempt_start)
          error
        end
    end
  end

  defp safe_execute(fun) do
    case fun.() do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
      result -> {:ok, result}  # Assume success if not explicitly an error tuple
    end
  rescue
    error ->
      {:error, {:exception, error}}
  catch
    :exit, reason ->
      {:error, {:exit, reason}}
    :throw, value ->
      {:error, {:throw, value}}
  end

  defp calculate_delay(%{attempt: attempt, base_delay: base_delay, max_delay: max_delay,
                        backoff_factor: factor, jitter: jitter}) do
    # Calculate exponential backoff
    delay = base_delay * :math.pow(factor, attempt)
    delay = min(delay, max_delay)

    # Add jitter if enabled
    if jitter do
      jitter_amount = delay * 0.1  # 10% jitter
      jitter_offset = (:rand.uniform() - 0.5) * 2 * jitter_amount
      max(0, round(delay + jitter_offset))
    else
      round(delay)
    end
  end

  defp log_success(state, attempt_start) do
    _duration = System.monotonic_time(:millisecond) - attempt_start
    total_duration = System.monotonic_time(:millisecond) - state.start_time

    if state.attempt > 0 do
      Logger.info("Retry succeeded after #{state.attempt} attempts (#{total_duration}ms total)")
    end
  end

  defp log_retry_attempt(state, reason, attempt_start) do
    duration = System.monotonic_time(:millisecond) - attempt_start
    delay = calculate_delay(state)

    Logger.warning("Retry attempt #{state.attempt + 1}/#{state.max_retries} failed: #{inspect(reason)} " <>
                "(#{duration}ms), retrying in #{delay}ms")
  end

  defp log_final_failure(state, reason, attempt_start) do
    _duration = System.monotonic_time(:millisecond) - attempt_start
    total_duration = System.monotonic_time(:millisecond) - state.start_time

    if retryable_error?({:error, reason}) do
      Logger.error("All retry attempts failed after #{state.attempt} attempts " <>
                   "(#{total_duration}ms total): #{inspect(reason)}")
    else
      Logger.debug("Non-retryable error: #{inspect(reason)}")
    end
  end

  @doc """
  Creates a retry configuration optimized for LLM API calls.

  ## Examples

      iex> config = RetryLogic.llm_retry_config()
      iex> config[:max_retries]
      3
  """
  def llm_retry_config(overrides \\ []) do
    base_config = [
      max_retries: 3,
      base_delay: 1000,      # 1 second
      max_delay: 30_000,     # 30 seconds
      backoff_factor: 2.0,
      jitter: true
    ]

    Keyword.merge(base_config, overrides)
  end

  @doc """
  Creates a retry configuration for high-frequency operations.

  Uses shorter delays and fewer retries for operations that need to be fast.
  """
  def fast_retry_config(overrides \\ []) do
    base_config = [
      max_retries: 2,
      base_delay: 100,       # 100ms
      max_delay: 2_000,      # 2 seconds
      backoff_factor: 1.5,
      jitter: true
    ]

    Keyword.merge(base_config, overrides)
  end

  @doc """
  Creates a retry configuration for critical operations.

  Uses more retries and longer timeouts for operations that must succeed.
  """
  def critical_retry_config(overrides \\ []) do
    base_config = [
      max_retries: 5,
      base_delay: 2000,      # 2 seconds
      max_delay: 60_000,     # 1 minute
      backoff_factor: 2.5,
      jitter: true
    ]

    Keyword.merge(base_config, overrides)
  end

  @doc """
  Wraps a function with retry logic and returns a new function.

  ## Examples

      iex> retryable_fn = RetryLogic.make_retryable(fn -> {:ok, "success"} end, max_retries: 2)
      iex> retryable_fn.()
      {:ok, "success"}
  """
  def make_retryable(fun, opts \\ []) when is_function(fun, 0) do
    fn -> with_retry(fun, opts) end
  end
end
