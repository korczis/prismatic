defmodule Prismatic.LLM.PerformanceEdgeTest do
  @moduledoc """
  Performance edge case tests for the LLM Backend system.

  These tests verify system behavior under extreme performance conditions,
  high concurrency, large payloads, and resource-intensive scenarios.
  """

  use ExUnit.Case, async: false  # Performance tests need isolation

  alias Prismatic.LLM.Backend
  alias Prismatic.LLM.Backend.{CircuitBreaker, MetricsCollector, RetryLogic}

  import ExUnit.CaptureLog

  describe "large payload handling" do
    test "handles extremely large prompts efficiently" do
      # Test with progressively larger prompts
      sizes = [1_000, 10_000, 100_000, 500_000]

      for size <- sizes do
        large_prompt = String.duplicate("This is a test prompt. ", div(size, 20))

        config = %{
          backend: :test,
          response: "Handled large prompt successfully",
          model: "test-model"
        }

        {time_microseconds, result} = :timer.tc(fn ->
          Backend.generate_response(config, large_prompt)
        end)

        # Should complete within reasonable time (< 1 second for any size)
        assert time_microseconds < 1_000_000,
               "Large prompt (#{size} chars) took too long: #{time_microseconds}μs"

        case result do
          {:ok, _response} -> :ok
          {:error, %{type: :request_too_large}} -> :ok
          {:error, %{type: :timeout}} -> :ok
          other -> flunk("Unexpected result for large prompt: #{inspect(other)}")
        end
      end
    end

    test "handles very large response payloads" do
      # Test with large response configurations
      large_response = String.duplicate("Response data ", 50_000)  # ~650KB

      config = %{
        backend: :test,
        response: large_response,
        model: "test-model"
      }

      {time_microseconds, result} = :timer.tc(fn ->
        Backend.generate_response(config, "Generate large response")
      end)

      # Should handle large responses efficiently
      assert time_microseconds < 2_000_000  # Less than 2 seconds

      case result do
        {:ok, response} ->
          assert is_binary(response)
          assert byte_size(response) > 0
        {:error, %{type: :response_too_large}} ->
          :ok  # Acceptable to reject very large responses
      end
    end

    test "memory usage remains stable with large payloads" do
      initial_memory = :erlang.memory(:total)

      # Process multiple large requests
      for _i <- 1..10 do
        large_prompt = String.duplicate("Memory test prompt ", 5_000)

        config = %{
          backend: :test,
          response: "Memory test response",
          model: "test-model"
        }

        {:ok, _} = Backend.generate_response(config, large_prompt)

        # Force garbage collection
        :erlang.garbage_collect()
      end

      final_memory = :erlang.memory(:total)
      memory_growth = final_memory - initial_memory

      # Memory growth should be reasonable (less than 50MB)
      assert memory_growth < 50_000_000,
             "Excessive memory growth: #{memory_growth} bytes"
    end
  end

  describe "high concurrency scenarios" do
    test "handles extreme concurrency without degradation" do
      concurrency_levels = [10, 50, 100, 200]

      for concurrency <- concurrency_levels do
        config = %{
          backend: :test,
          response: "Concurrent response",
          model: "test-model"
        }

        {time_microseconds, results} = :timer.tc(fn ->
          tasks = for i <- 1..concurrency do
            Task.async(fn ->
              Backend.generate_response(config, "Concurrent request #{i}")
            end)
          end

          Task.await_many(tasks, 10_000)
        end)

        # All requests should complete
        assert length(results) == concurrency

        # Most should succeed
        successes = Enum.count(results, fn
          {:ok, _} -> true
          _ -> false
        end)

        success_rate = successes / concurrency
        assert success_rate > 0.8,
               "Low success rate at concurrency #{concurrency}: #{success_rate}"

        # Average response time should be reasonable
        avg_time_per_request = time_microseconds / concurrency
        assert avg_time_per_request < 100_000,  # Less than 100ms average
               "High latency at concurrency #{concurrency}: #{avg_time_per_request}μs"
      end
    end

    test "circuit breaker performs under high concurrency" do
      {:ok, cb_pid} = CircuitBreaker.start_link(
        name: :perf_test_cb,
        failure_threshold: 10,
        recovery_timeout: 1000
      )

      # Test with 100 concurrent requests
      tasks = for i <- 1..100 do
        Task.async(fn ->
          CircuitBreaker.call(cb_pid, fn ->
            # Simulate some work
            Process.sleep(1)
            {:ok, "Request #{i} completed"}
          end)
        end)
      end

      {time_microseconds, results} = :timer.tc(fn ->
        Task.await_many(tasks, 5000)
      end)

      # All should complete
      assert length(results) == 100

      # Circuit breaker should handle the load
      successes = Enum.count(results, fn
        {:ok, _} -> true
        _ -> false
      end)

      assert successes > 90  # At least 90% success rate

      # Should complete in reasonable time
      assert time_microseconds < 3_000_000  # Less than 3 seconds

      GenServer.stop(cb_pid)
    end

    test "metrics collection scales with high request volume" do
      {:ok, metrics_pid} = MetricsCollector.start_link([])

      # Record many metrics concurrently
      tasks = for i <- 1..1000 do
        Task.async(fn ->
          status = if rem(i, 10) == 0, do: :error, else: :success
          latency = :rand.uniform(100)
          MetricsCollector.record_request(metrics_pid, status, latency)
        end)
      end

      {time_microseconds, _results} = :timer.tc(fn ->
        Task.await_many(tasks, 5000)
      end)

      # Should handle high volume efficiently
      assert time_microseconds < 2_000_000  # Less than 2 seconds

      # Verify metrics are accurate
      metrics = MetricsCollector.get_metrics(metrics_pid)
      assert metrics.total_requests == 1000
      assert metrics.error_count == 100  # Every 10th request was an error

      GenServer.stop(metrics_pid)
    end
  end

  describe "long-running operation handling" do
    test "handles operations that approach timeout limits" do
      config = %{
        backend: :test,
        delay: 4900,  # Just under 5 second timeout
        response: "Long operation completed",
        model: "test-model"
      }

      {time_microseconds, result} = :timer.tc(fn ->
        Backend.generate_response(config, "Long running operation")
      end)

      # Should complete successfully
      assert {:ok, _} = result

      # Should take approximately the expected time
      assert time_microseconds > 4_800_000  # At least 4.8 seconds
      assert time_microseconds < 6_000_000  # Less than 6 seconds
    end

    test "properly times out operations that exceed limits" do
      config = %{
        backend: :test,
        delay: 6000,  # Exceeds 5 second timeout
        response: "Should not reach here",
        model: "test-model"
      }

      {time_microseconds, result} = :timer.tc(fn ->
        Backend.generate_response(config, "Operation that will timeout")
      end)

      # Should timeout
      assert {:error, %{type: :timeout}} = result

      # Should timeout around the limit
      assert time_microseconds > 4_900_000  # At least 4.9 seconds
      assert time_microseconds < 6_000_000  # Less than 6 seconds
    end

    test "retry logic performs efficiently with multiple attempts" do
      attempt_count = :counters.new(1, [])

      config = %{
        backend: :test,
        model: "test-model",
        custom_handler: fn _prompt ->
          count = :counters.add(attempt_count, 1, 1)
          if count < 4 do
            {:error, %{type: :temporary_failure, retryable: true}}
          else
            {:ok, "Success after retries"}
          end
        end
      }

      {time_microseconds, result} = :timer.tc(fn ->
        RetryLogic.with_retry(fn ->
          Backend.generate_response(config, "Retry test")
        end, RetryLogic.llm_retry_config())
      end)

      # Should eventually succeed
      assert {:ok, "Success after retries"} = result

      # Should have made multiple attempts efficiently
      final_count = :counters.get(attempt_count, 1)
      assert final_count == 4

      # Total time should include backoff but be reasonable
      assert time_microseconds > 1_000_000  # At least 1 second (due to backoff)
      assert time_microseconds < 10_000_000  # Less than 10 seconds
    end
  end

  describe "resource cleanup verification" do
    test "processes are properly cleaned up after operations" do
      initial_process_count = length(Process.list())

      # Perform many operations that create temporary processes
      for _i <- 1..50 do
        config = %{
          backend: :test,
          response: "Cleanup test response",
          model: "test-model"
        }

        {:ok, _} = Backend.generate_response(config, "Cleanup test")
      end

      # Force garbage collection and wait
      :erlang.garbage_collect()
      Process.sleep(100)

      final_process_count = length(Process.list())
      process_growth = final_process_count - initial_process_count

      # Should not have significant process leakage
      assert process_growth < 10,
             "Process leak detected: #{process_growth} new processes"
    end

    test "ETS tables are cleaned up properly" do
      initial_tables = :ets.all()
      initial_count = length(initial_tables)

      # Create and use multiple metrics collectors
      pids = for i <- 1..10 do
        {:ok, pid} = MetricsCollector.start_link([])

        # Use the collector
        MetricsCollector.record_request(pid, :success, 100)
        _metrics = MetricsCollector.get_metrics(pid)

        pid
      end

      # Stop all collectors
      for pid <- pids do
        GenServer.stop(pid)
      end

      # Wait for cleanup
      Process.sleep(100)

      final_tables = :ets.all()
      final_count = length(final_tables)

      # Should not have table leakage
      table_growth = final_count - initial_count
      assert table_growth <= 1,  # Allow for one persistent table
             "ETS table leak detected: #{table_growth} new tables"
    end

    test "memory is released after large operations" do
      :erlang.garbage_collect()
      initial_memory = :erlang.memory(:total)

      # Perform memory-intensive operations
      large_data = String.duplicate("x", 1_000_000)

      for _i <- 1..20 do
        config = %{
          backend: :test,
          response: large_data,
          model: "test-model"
        }

        {:ok, _response} = Backend.generate_response(config, large_data)
      end

      # Force cleanup
      :erlang.garbage_collect()
      Process.sleep(100)

      final_memory = :erlang.memory(:total)
      memory_growth = final_memory - initial_memory

      # Memory growth should be minimal after cleanup
      assert memory_growth < 10_000_000,  # Less than 10MB growth
             "Memory not properly released: #{memory_growth} bytes retained"
    end
  end

  describe "performance regression detection" do
    test "baseline performance metrics are maintained" do
      # Establish baseline with simple operations
      simple_config = %{
        backend: :test,
        response: "Simple response",
        model: "test-model"
      }

      baseline_times = for _i <- 1..10 do
        {time, {:ok, _}} = :timer.tc(fn ->
          Backend.generate_response(simple_config, "Simple prompt")
        end)
        time
      end

      avg_baseline = Enum.sum(baseline_times) / length(baseline_times)

      # Baseline should be very fast (< 10ms)
      assert avg_baseline < 10_000,
             "Baseline performance regression: #{avg_baseline}μs average"

      # Test with slightly more complex operations
      complex_config = %{
        backend: :test,
        response: String.duplicate("Complex response ", 100),
        model: "test-model"
      }

      complex_times = for _i <- 1..10 do
        {time, {:ok, _}} = :timer.tc(fn ->
          Backend.generate_response(complex_config, String.duplicate("Complex prompt ", 50))
        end)
        time
      end

      avg_complex = Enum.sum(complex_times) / length(complex_times)

      # Complex operations should still be reasonable (< 50ms)
      assert avg_complex < 50_000,
             "Complex operation performance regression: #{avg_complex}μs average"

      # Complex should not be more than 10x slower than baseline
      performance_ratio = avg_complex / avg_baseline
      assert performance_ratio < 10,
             "Performance ratio too high: #{performance_ratio}x"
    end

    test "concurrent performance scales linearly" do
      config = %{
        backend: :test,
        response: "Scaling test response",
        model: "test-model"
      }

      # Test different concurrency levels
      concurrency_results = for concurrency <- [1, 5, 10, 20] do
        {total_time, _results} = :timer.tc(fn ->
          tasks = for i <- 1..concurrency do
            Task.async(fn ->
              Backend.generate_response(config, "Scaling test #{i}")
            end)
          end

          Task.await_many(tasks, 5000)
        end)

        avg_time_per_request = total_time / concurrency
        {concurrency, avg_time_per_request}
      end

      # Performance should not degrade significantly with concurrency
      [{_, baseline_time} | rest] = concurrency_results

      for {concurrency, avg_time} <- rest do
        degradation_factor = avg_time / baseline_time
        assert degradation_factor < 3.0,
               "Performance degradation at concurrency #{concurrency}: #{degradation_factor}x slower"
      end
    end
  end
end
