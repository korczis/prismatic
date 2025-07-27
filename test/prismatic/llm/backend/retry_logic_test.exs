defmodule Prismatic.LLM.Backend.RetryLogicTest do
  @moduledoc """
  Comprehensive test suite for the RetryLogic module.

  This module tests the retry logic implementation including exponential backoff,
  jitter, error classification, retry limits, and various retry configurations
  for different use cases.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  import ExUnit.CaptureLog

  alias Prismatic.LLM.Backend.RetryLogic

  describe "with_retry/2" do
    test "executes function successfully on first attempt" do
      success_function = fn -> {:ok, "success"} end

      assert {:ok, "success"} = RetryLogic.with_retry(success_function)
    end

    test "returns function result directly when not a tuple" do
      simple_function = fn -> "simple result" end

      assert {:ok, "simple result"} = RetryLogic.with_retry(simple_function)
    end

    test "retries on retryable errors" do
      # Function that fails twice then succeeds
      test_pid = self()
      counter_function = fn ->
        send(test_pid, :attempt)

        case Process.get(:attempt_count, 0) do
          0 ->
            Process.put(:attempt_count, 1)
            {:error, :timeout}
          1 ->
            Process.put(:attempt_count, 2)
            {:error, :econnrefused}
          _ ->
            {:ok, "success after retries"}
        end
      end

      assert {:ok, "success after retries"} = RetryLogic.with_retry(counter_function, max_retries: 3)

      # Should have made 3 attempts
      assert_received :attempt
      assert_received :attempt
      assert_received :attempt
    end

    test "stops retrying on non-retryable errors" do
      test_pid = self()
      non_retryable_function = fn ->
        send(test_pid, :attempt)
        {:error, :invalid_api_key}
      end

      assert {:error, :invalid_api_key} = RetryLogic.with_retry(non_retryable_function, max_retries: 3)

      # Should have made only 1 attempt
      assert_received :attempt
      refute_received :attempt
    end

    test "respects max_retries limit" do
      test_pid = self()
      always_fail_function = fn ->
        send(test_pid, :attempt)
        {:error, :timeout}
      end

      assert {:error, :max_retries_exceeded} = RetryLogic.with_retry(always_fail_function, max_retries: 2)

      # Should have made 3 attempts (initial + 2 retries)
      assert_received :attempt
      assert_received :attempt
      assert_received :attempt
      refute_received :attempt
    end

    test "applies exponential backoff" do
      test_pid = self()
      fail_function = fn ->
        send(test_pid, {:attempt, System.monotonic_time(:millisecond)})
        {:error, :timeout}
      end

      _start_time = System.monotonic_time(:millisecond)
      RetryLogic.with_retry(fail_function, max_retries: 2, base_delay: 100, jitter: false)

      # Collect timestamps
      timestamps = []
      timestamps = receive_timestamp(timestamps)
      timestamps = receive_timestamp(timestamps)
      timestamps = receive_timestamp(timestamps)

      timestamps = Enum.reverse(timestamps)

      # Check delays between attempts
      delay1 = Enum.at(timestamps, 1) - Enum.at(timestamps, 0)
      delay2 = Enum.at(timestamps, 2) - Enum.at(timestamps, 1)

      # First delay should be ~100ms, second should be ~200ms (exponential backoff)
      assert delay1 >= 90 and delay1 <= 150
      assert delay2 >= 180 and delay2 <= 250
    end

    test "applies jitter to reduce thundering herd" do
      # Run multiple retry attempts and check that delays vary
      delays = for _i <- 1..10 do
        test_pid = self()
        fail_function = fn ->
          send(test_pid, {:attempt, System.monotonic_time(:millisecond)})
          {:error, :timeout}
        end

        RetryLogic.with_retry(fail_function, max_retries: 1, base_delay: 100, jitter: true)

        # Get the two timestamps
        {_, time1} = receive do {:attempt, t} -> {:attempt, t} end
        {_, time2} = receive do {:attempt, t} -> {:attempt, t} end

        time2 - time1
      end

      # With jitter, delays should vary
      unique_delays = Enum.uniq(delays)
      assert length(unique_delays) > 1, "Jitter should cause variation in delays"
    end

    test "handles function exceptions" do
      exception_function = fn -> raise "Test exception" end

      assert {:error, {:exception, %RuntimeError{}}} =
        RetryLogic.with_retry(exception_function, max_retries: 1)
    end

    test "handles function exits" do
      exit_function = fn -> exit(:test_exit) end

      assert {:error, {:exit, :test_exit}} =
        RetryLogic.with_retry(exit_function, max_retries: 1)
    end

    test "handles function throws" do
      throw_function = fn -> throw(:test_throw) end

      assert {:error, {:throw, :test_throw}} =
        RetryLogic.with_retry(throw_function, max_retries: 1)
    end

    test "respects max_delay limit" do
      test_pid = self()
      fail_function = fn ->
        send(test_pid, {:attempt, System.monotonic_time(:millisecond)})
        {:error, :timeout}
      end

      # High backoff factor but low max_delay
      RetryLogic.with_retry(fail_function, [
        max_retries: 3,
        base_delay: 100,
        backoff_factor: 10.0,
        max_delay: 150,
        jitter: false
      ])

      # Collect timestamps
      timestamps = []
      timestamps = receive_timestamp(timestamps)
      timestamps = receive_timestamp(timestamps)
      timestamps = receive_timestamp(timestamps)
      timestamps = receive_timestamp(timestamps)

      timestamps = Enum.reverse(timestamps)

      # All delays should be capped at max_delay
      for i <- 1..3 do
        delay = Enum.at(timestamps, i) - Enum.at(timestamps, i - 1)
        assert delay <= 200, "Delay #{delay} should be capped by max_delay"
      end
    end
  end

  describe "retryable_error?/1" do
    test "identifies retryable network errors" do
      retryable_errors = [
        {:error, :timeout},
        {:error, :econnrefused},
        {:error, :econnreset},
        {:error, :ehostunreach},
        {:error, :enetunreach},
        {:error, {:request_failed, :some_reason}}
      ]

      for error <- retryable_errors do
        assert RetryLogic.retryable_error?(error), "#{inspect(error)} should be retryable"
      end
    end

    test "identifies retryable HTTP status codes" do
      retryable_http_errors = [
        {:error, {:api_error, 429, "Rate limited"}},
        {:error, {:api_error, 500, "Internal server error"}},
        {:error, {:api_error, 502, "Bad gateway"}},
        {:error, {:api_error, 503, "Service unavailable"}},
        {:error, {:api_error, 504, "Gateway timeout"}}
      ]

      for error <- retryable_http_errors do
        assert RetryLogic.retryable_error?(error), "#{inspect(error)} should be retryable"
      end
    end

    test "identifies non-retryable HTTP status codes" do
      non_retryable_http_errors = [
        {:error, {:api_error, 400, "Bad request"}},
        {:error, {:api_error, 401, "Unauthorized"}},
        {:error, {:api_error, 403, "Forbidden"}},
        {:error, {:api_error, 404, "Not found"}}
      ]

      for error <- non_retryable_http_errors do
        refute RetryLogic.retryable_error?(error), "#{inspect(error)} should not be retryable"
      end
    end

    test "identifies retryable rate limiting errors" do
      assert RetryLogic.retryable_error?({:error, :rate_limit_exceeded})
    end

    test "identifies non-retryable quota errors" do
      refute RetryLogic.retryable_error?({:error, :quota_exceeded})
    end

    test "identifies non-retryable authentication errors" do
      non_retryable_auth_errors = [
        {:error, :invalid_api_key},
        {:error, :authentication_failed},
        {:error, :authorization_failed}
      ]

      for error <- non_retryable_auth_errors do
        refute RetryLogic.retryable_error?(error), "#{inspect(error)} should not be retryable"
      end
    end

    test "identifies non-retryable validation errors" do
      non_retryable_validation_errors = [
        {:error, :invalid_request},
        {:error, :invalid_model},
        {:error, :invalid_parameters}
      ]

      for error <- non_retryable_validation_errors do
        refute RetryLogic.retryable_error?(error), "#{inspect(error)} should not be retryable"
      end
    end

    test "identifies non-retryable circuit breaker errors" do
      refute RetryLogic.retryable_error?({:error, :circuit_breaker_open})
    end

    test "treats unknown errors as retryable by default" do
      unknown_errors = [
        {:error, :unknown_error},
        {:error, :custom_error},
        {:error, {:complex, :error, :structure}}
      ]

      for error <- unknown_errors do
        assert RetryLogic.retryable_error?(error), "#{inspect(error)} should be retryable by default"
      end
    end

    test "handles non-error tuples" do
      non_errors = [
        {:ok, "success"},
        "not a tuple",
        123,
        %{key: "value"}
      ]

      for non_error <- non_errors do
        refute RetryLogic.retryable_error?(non_error), "#{inspect(non_error)} should not be considered an error"
      end
    end
  end

  describe "configuration presets" do
    test "llm_retry_config/1 provides sensible defaults" do
      config = RetryLogic.llm_retry_config()

      assert config[:max_retries] == 3
      assert config[:base_delay] == 1000
      assert config[:max_delay] == 30_000
      assert config[:backoff_factor] == 2.0
      assert config[:jitter] == true
    end

    test "llm_retry_config/1 accepts overrides" do
      overrides = [max_retries: 5, base_delay: 2000]
      config = RetryLogic.llm_retry_config(overrides)

      assert config[:max_retries] == 5
      assert config[:base_delay] == 2000
      assert config[:max_delay] == 30_000  # Should keep default
    end

    test "fast_retry_config/1 provides fast retry settings" do
      config = RetryLogic.fast_retry_config()

      assert config[:max_retries] == 2
      assert config[:base_delay] == 100
      assert config[:max_delay] == 2_000
      assert config[:backoff_factor] == 1.5
      assert config[:jitter] == true
    end

    test "critical_retry_config/1 provides aggressive retry settings" do
      config = RetryLogic.critical_retry_config()

      assert config[:max_retries] == 5
      assert config[:base_delay] == 2000
      assert config[:max_delay] == 60_000
      assert config[:backoff_factor] == 2.5
      assert config[:jitter] == true
    end

    test "config presets work with with_retry/2" do
      test_pid = self()
      fail_function = fn ->
        send(test_pid, :attempt)
        {:error, :timeout}
      end

      # Test each config preset
      configs = [
        RetryLogic.llm_retry_config(),
        RetryLogic.fast_retry_config(),
        RetryLogic.critical_retry_config()
      ]

      for config <- configs do
        RetryLogic.with_retry(fail_function, config)

        # Should have made attempts according to config
        max_retries = config[:max_retries]
        for _i <- 1..(max_retries + 1) do
          assert_received :attempt
        end
      end
    end
  end

  describe "make_retryable/2" do
    test "creates retryable function wrapper" do
      original_function = fn -> {:ok, "success"} end
      retryable_function = RetryLogic.make_retryable(original_function, max_retries: 2)

      assert is_function(retryable_function, 0)
      assert {:ok, "success"} = retryable_function.()
    end

    test "retryable function applies retry logic" do
      test_pid = self()
      fail_function = fn ->
        send(test_pid, :attempt)
        {:error, :timeout}
      end

      retryable_function = RetryLogic.make_retryable(fail_function, max_retries: 2)

      assert {:error, :max_retries_exceeded} = retryable_function.()

      # Should have made 3 attempts
      assert_received :attempt
      assert_received :attempt
      assert_received :attempt
    end
  end

  describe "logging behavior" do
    test "logs retry attempts" do
      fail_function = fn -> {:error, :timeout} end

      log_output = capture_log(fn ->
        RetryLogic.with_retry(fail_function, max_retries: 2, base_delay: 10)
      end)

      assert log_output =~ "Retry attempt"
      assert log_output =~ "timeout"
      assert log_output =~ "retrying in"
    end

    test "logs successful retry" do
      counter_function = fn ->
        case Process.get(:attempt_count, 0) do
          0 ->
            Process.put(:attempt_count, 1)
            {:error, :timeout}
          _ ->
            {:ok, "success"}
        end
      end

      log_output = capture_log(fn ->
        RetryLogic.with_retry(counter_function, max_retries: 2, base_delay: 10)
      end)

      assert log_output =~ "Retry succeeded"
    end

    test "logs final failure after all retries" do
      fail_function = fn -> {:error, :timeout} end

      log_output = capture_log(fn ->
        RetryLogic.with_retry(fail_function, max_retries: 1, base_delay: 10)
      end)

      assert log_output =~ "All retry attempts failed"
    end

    test "logs non-retryable errors at debug level" do
      non_retryable_function = fn -> {:error, :invalid_api_key} end

      log_output = capture_log([level: :debug], fn ->
        RetryLogic.with_retry(non_retryable_function, max_retries: 2)
      end)

      assert log_output =~ "Non-retryable error"
      assert log_output =~ "invalid_api_key"
    end
  end

  # Property-based tests
  describe "property-based tests" do
    property "retry logic never exceeds max_retries" do
      check all max_retries <- integer(0..10) do
        test_pid = self()
        fail_function = fn ->
          send(test_pid, :attempt)
          {:error, :timeout}
        end

        RetryLogic.with_retry(fail_function, max_retries: max_retries, base_delay: 1)

        # Count attempts
        attempt_count = count_messages(:attempt, 0)

        # Should never exceed max_retries + 1 (initial attempt + retries)
        assert attempt_count <= max_retries + 1
      end
    end

    property "exponential backoff increases delays" do
      check all base_delay <- integer(10..100),
                backoff_factor <- float(min: 1.1, max: 5.0),
                max_attempts <- integer(2..5) do

        test_pid = self()
        fail_function = fn ->
          send(test_pid, {:attempt, System.monotonic_time(:millisecond)})
          {:error, :timeout}
        end

        RetryLogic.with_retry(fail_function, [
          max_retries: max_attempts - 1,
          base_delay: base_delay,
          backoff_factor: backoff_factor,
          jitter: false,
          max_delay: 10_000
        ])

        # Collect timestamps
        timestamps = collect_timestamps(max_attempts, [])

        if length(timestamps) >= 2 do
          # Check that delays generally increase (allowing for some variance)
          delays = for i <- 1..(length(timestamps) - 1) do
            Enum.at(timestamps, i) - Enum.at(timestamps, i - 1)
          end

          # At least some delays should increase
          increasing_pairs = for i <- 1..(length(delays) - 1) do
            Enum.at(delays, i) >= Enum.at(delays, i - 1) * 0.8  # Allow some tolerance
          end

          assert Enum.any?(increasing_pairs)
        end
      end
    end

    property "retryable_error? classification is consistent" do
      check all error_type <- member_of([
        :timeout, :econnrefused, :invalid_api_key, :rate_limit_exceeded,
        :quota_exceeded, :circuit_breaker_open, :unknown_error
      ]) do

        error = {:error, error_type}

        # Classification should be consistent
        result1 = RetryLogic.retryable_error?(error)
        result2 = RetryLogic.retryable_error?(error)

        assert result1 == result2
        assert is_boolean(result1)
      end
    end
  end

  describe "edge cases and error handling" do
    test "handles zero max_retries" do
      fail_function = fn -> {:error, :timeout} end

      assert {:error, :max_retries_exceeded} =
        RetryLogic.with_retry(fail_function, max_retries: 0)
    end

    test "handles zero base_delay" do
      test_pid = self()
      fail_function = fn ->
        send(test_pid, {:attempt, System.monotonic_time(:millisecond)})
        {:error, :timeout}
      end

      start_time = System.monotonic_time(:millisecond)
      RetryLogic.with_retry(fail_function, max_retries: 2, base_delay: 0)
      end_time = System.monotonic_time(:millisecond)

      # Should complete quickly with no delays
      assert end_time - start_time < 100
    end

    test "handles very large delays gracefully" do
      # This test ensures large delays don't cause integer overflow
      fail_function = fn -> {:error, :timeout} end

      # Should not crash with large delay values
      result = RetryLogic.with_retry(fail_function, [
        max_retries: 1,
        base_delay: 1_000_000,
        max_delay: 100  # Should be capped
      ])

      assert {:error, :max_retries_exceeded} = result
    end

    test "handles negative backoff_factor" do
      fail_function = fn -> {:error, :timeout} end

      # Should handle gracefully (delays might be weird but shouldn't crash)
      result = RetryLogic.with_retry(fail_function, [
        max_retries: 1,
        base_delay: 100,
        backoff_factor: -1.0
      ])

      assert {:error, :max_retries_exceeded} = result
    end

    test "handles concurrent retry operations" do
      # Multiple retry operations should not interfere with each other
      tasks = for _i <- 1..10 do
        Task.async(fn ->
          fail_function = fn -> {:error, :timeout} end
          RetryLogic.with_retry(fail_function, max_retries: 2, base_delay: 10)
        end)
      end

      results = Task.await_many(tasks)

      # All should fail with max retries exceeded
      for result <- results do
        assert {:error, :max_retries_exceeded} = result
      end
    end
  end

  # Helper functions for tests
  defp receive_timestamp(timestamps) do
    receive do
      {:attempt, timestamp} -> [timestamp | timestamps]
    after
      1000 -> timestamps
    end
  end

  defp count_messages(message, count) do
    receive do
      ^message -> count_messages(message, count + 1)
    after
      10 -> count
    end
  end

  defp collect_timestamps(0, acc), do: Enum.reverse(acc)
  defp collect_timestamps(count, acc) do
    receive do
      {:attempt, timestamp} -> collect_timestamps(count - 1, [timestamp | acc])
    after
      1000 -> Enum.reverse(acc)
    end
  end

  # Doctests
  doctest RetryLogic, import: true
end
