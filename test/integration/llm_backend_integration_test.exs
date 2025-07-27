defmodule Integration.LLMBackendIntegrationTest do
  @moduledoc """
  Comprehensive integration test suite for the LLM Backend system.

  This module tests end-to-end workflows including the interaction between
  all components: Backend factory, implementations, circuit breakers, retry logic,
  metrics collection, and registry management. These tests verify that the
  entire system works together correctly under various scenarios.
  """

  use ExUnit.Case, async: false  # Integration tests need sequential execution
  use ExUnitProperties

  import ExUnit.CaptureLog
  import Prismatic.TestHelpers
  import Prismatic.PropertyHelpers

  alias Prismatic.LLM.Backend
  alias Prismatic.LLM.Backend.{CircuitBreaker, MetricsCollector, RetryLogic}
  alias Prismatic.LLM.CircuitBreakerRegistry
  alias Prismatic.LLM.Impl.TestBackend

  # Setup comprehensive test environment
  setup_all do
    # Start all required services
    {:ok, _registry_pid} = CircuitBreakerRegistry.start_link()
    {:ok, _metrics_pid} = MetricsCollector.start_link()

    on_exit(fn ->
      # Clean up all services
      case GenServer.whereis(MetricsCollector) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end

      case GenServer.whereis(CircuitBreakerRegistry) do
        nil -> :ok
        pid -> GenServer.stop(pid)
      end
    end)

    :ok
  end

  setup do
    # Reset metrics for each test
    backends = [:test_backend, :integration_test, :workflow_test, :scenario_test]
    for backend <- backends do
      MetricsCollector.reset_metrics(backend)
    end

    :ok
  end

  describe "end-to-end successful workflows" do
    test "complete successful request workflow with all components" do
      # Create backend configuration
      {:ok, config} = Backend.create_config(:test, %{
        responses: %{"integration_test" => "Integration test successful!"},
        latency_ms: 10
      })

      # Validate configuration
      assert :ok = Backend.validate_config(config)

      # Check backend health
      assert :ok = Backend.health_check(config)

      # Get model information
      assert {:ok, model_info} = Backend.get_model_info(config)
      assert model_info.provider == :test

      # Generate response
      assert {:ok, response} = Backend.generate_response(config, "integration_test", %{
        temperature: 0.7,
        max_tokens: 100,
        user_id: "integration_user"
      })

      assert response == "Integration test successful!"

      # Verify metrics were collected
      metrics = MetricsCollector.get_metrics(:test)
      assert metrics.total_requests >= 1
      assert metrics.successful_requests >= 1

      # Verify circuit breaker is in healthy state
      assert :closed = CircuitBreaker.get_state(:test)
    end

    test "multi-backend workflow with different providers" do
      # Test multiple backends in sequence
      backends_and_configs = [
        {:test, %{responses: %{"test1" => "Test backend response"}}},
        {:test, %{responses: %{"test2" => "Another test response"}, latency_ms: 5}}
      ]

      results = for {{backend_type, options}, index} <- Enum.with_index(backends_and_configs, 1) do
        {:ok, config} = Backend.create_config(backend_type, options)

        # Each backend should work independently
        assert :ok = Backend.health_check(config)
        {:ok, response} = Backend.generate_response(config, "test#{index}", %{})

        {backend_type, response}
      end

      # Verify all backends worked
      assert length(results) == 2
      for {backend_type, response} <- results do
        assert backend_type == :test
        assert is_binary(response)
        assert String.length(response) > 0
      end

      # Verify global metrics include all requests
      global_metrics = MetricsCollector.get_global_metrics()
      assert global_metrics.total_requests >= 2
    end

    test "conversation workflow with context preservation" do
      {:ok, config} = Backend.create_config(:test, %{
        responses: %{
          "hello" => "Hello! How can I help you?",
          "follow_up" => "I understand your follow-up question."
        }
      })

      # Initial conversation
      assert {:ok, response1} = Backend.generate_response(config, "hello", %{
        user_id: "conversation_user"
      })

      # Follow-up with conversation history
      conversation_history = [
        %{role: "user", content: "hello"},
        %{role: "assistant", content: response1}
      ]

      assert {:ok, response2} = Backend.generate_response(config, "follow_up", %{
        user_id: "conversation_user",
        conversation_history: conversation_history,
        system_message: "You are a helpful assistant."
      })

      # Verify responses
      assert String.contains?(response1, "Hello")
      assert String.contains?(response2, "follow-up")

      # Verify metrics tracked both requests
      metrics = MetricsCollector.get_metrics(:test)
      assert metrics.total_requests >= 2
      assert metrics.successful_requests >= 2
    end
  end

  describe "error handling and recovery workflows" do
    test "circuit breaker integration with retry logic" do
      # Configure backend to fail initially then succeed
      {:ok, config} = Backend.create_config(:test, %{
        error_rate: 0.8,  # High error rate to trigger circuit breaker
        error_type: :timeout,
        responses: %{"recovery_test" => "Recovered successfully"}
      })

      # Make requests that will fail and trip circuit breaker
      failure_results = for _i <- 1..6 do
        Backend.generate_response(config, "recovery_test", %{})
      end

      # Most should fail due to high error rate
      failures = Enum.count(failure_results, fn
        {:error, _} -> true
        _ -> false
      end)

      assert failures >= 3  # Should have some failures

      # Circuit breaker should eventually open
      # (May take a few attempts due to randomness in error simulation)
      eventually_open = Enum.any?(1..3, fn _ ->
        Process.sleep(10)
        CircuitBreaker.get_state(:test) == :open
      end)

      if eventually_open do
        # Subsequent requests should be rejected by circuit breaker
        assert {:error, :circuit_breaker_open} =
          Backend.generate_response(config, "recovery_test", %{})
      end

      # Reset circuit breaker and reduce error rate for recovery
      CircuitBreaker.reset(:test)
      {:ok, recovery_config} = Backend.create_config(:test, %{
        error_rate: 0.0,  # No errors for recovery
        responses: %{"recovery_test" => "Recovered successfully"}
      })

      # Should work after recovery
      assert {:ok, "Recovered successfully"} =
        Backend.generate_response(recovery_config, "recovery_test", %{})

      # Verify metrics captured the entire workflow
      metrics = MetricsCollector.get_metrics(:test)
      assert metrics.total_requests >= 7
      assert metrics.failed_requests >= 3
    end

    test "retry logic with eventual success" do
      # Create a backend that fails twice then succeeds
      attempt_count = :counters.new(1, [])

      {:ok, config} = Backend.create_config(:test, %{
        responses: %{
          "retry_test" => fn _prompt, _context ->
            count = :counters.get(attempt_count, 1)
            :counters.add(attempt_count, 1, 1)

            case count do
              0 -> {:error, :timeout}
              1 -> {:error, :econnrefused}
              _ -> "Success after retries!"
            end
          end
        }
      })

      # Should eventually succeed after retries
      assert {:ok, "Success after retries!"} =
        Backend.generate_response(config, "retry_test", %{})

      # Should have made multiple attempts
      final_count = :counters.get(attempt_count, 1)
      assert final_count >= 3

      # Verify metrics show the retries
      metrics = MetricsCollector.get_metrics(:test)
      assert metrics.total_requests >= 1
      assert metrics.successful_requests >= 1
    end

    test "graceful degradation under high load" do
      # Simulate high load with concurrent requests
      {:ok, config} = Backend.create_config(:test, %{
        latency_ms: 20,  # Some latency to simulate real conditions
        responses: %{"load_test" => "Load test response"}
      })

      # Spawn many concurrent requests
      tasks = for i <- 1..50 do
        Task.async(fn ->
          Backend.generate_response(config, "load_test", %{
            user_id: "load_user_#{i}",
            request_id: i
          })
        end)
      end

      # Wait for all requests to complete
      results = Task.await_many(tasks, 10_000)  # 10 second timeout

      # Analyze results
      successes = Enum.count(results, fn
        {:ok, _} -> true
        _ -> false
      end)

      errors = Enum.count(results, fn
        {:error, _} -> true
        _ -> false
      end)

      # Should handle most requests successfully
      assert successes >= 40  # At least 80% success rate
      assert successes + errors == 50

      # Verify metrics captured all requests
      metrics = MetricsCollector.get_metrics(:test)
      assert metrics.total_requests >= 50

      # System should remain stable
      assert :closed = CircuitBreaker.get_state(:test)
    end
  end

  describe "metrics and monitoring workflows" do
    test "comprehensive metrics collection across operations" do
      {:ok, config} = Backend.create_config(:test, %{
        responses: %{
          "metrics_test" => "Metrics collection test"
        },
        latency_ms: 15
      })

      # Perform various operations
      operations = [
        {:health_check, fn -> Backend.health_check(config) end},
        {:model_info, fn -> Backend.get_model_info(config) end},
        {:generate_response, fn -> Backend.generate_response(config, "metrics_test", %{tokens: 50, cost: 0.001}) end},
        {:generate_response, fn -> Backend.generate_response(config, "metrics_test", %{tokens: 75, cost: 0.0015}) end}
      ]

      # Execute operations and track timing
      start_time = System.monotonic_time(:millisecond)

      results = for {operation_type, operation} <- operations do
        result = operation.()
        {operation_type, result}
      end

      end_time = System.monotonic_time(:millisecond)

      # Verify all operations succeeded
      for {operation_type, result} <- results do
        case operation_type do
          :health_check -> assert result == :ok
          :model_info -> assert {:ok, _info} = result
          :generate_response -> assert {:ok, _response} = result
        end
      end

      # Verify comprehensive metrics
      metrics = MetricsCollector.get_metrics(:test)
      assert metrics.total_requests >= 2  # Two generate_response calls
      assert metrics.successful_requests >= 2
      assert metrics.total_tokens >= 125  # 50 + 75
      assert metrics.total_cost >= 0.0025  # 0.001 + 0.0015
      assert metrics.average_latency > 0

      # Verify global metrics
      global_metrics = MetricsCollector.get_global_metrics()
      assert global_metrics.total_requests >= 2
      assert global_metrics.total_tokens >= 125

      # Verify timing is reasonable
      total_duration = end_time - start_time
      assert total_duration >= 30  # Should take at least 2 * 15ms latency
    end

    test "metrics aggregation across multiple backends" do
      # Create multiple backend instances
      backend_configs = [
        {:backend1, %{responses: %{"test" => "Backend 1"}, latency_ms: 10}},
        {:backend2, %{responses: %{"test" => "Backend 2"}, latency_ms: 15}},
        {:backend3, %{responses: %{"test" => "Backend 3"}, latency_ms: 5}}
      ]

      # Make requests to each backend
      for {_backend_name, options} <- backend_configs do
        {:ok, config} = Backend.create_config(:test, options)

        # Make multiple requests per backend
        for i <- 1..3 do
          data = %{tokens: i * 10, cost: i * 0.001}
          Backend.generate_response(config, "test", data)
        end
      end

      # Verify individual backend metrics
      for {_backend_name, _options} <- backend_configs do
        metrics = MetricsCollector.get_metrics(:test)
        # Note: All using :test backend type, so metrics will be combined
        assert metrics.total_requests >= 3
      end

      # Verify global aggregation
      global_metrics = MetricsCollector.get_global_metrics()
      assert global_metrics.total_requests >= 9  # 3 backends * 3 requests
      assert global_metrics.total_tokens >= 180  # Sum of all token counts
      assert global_metrics.successful_requests >= 9
    end

    test "health scoring and circuit breaker metrics integration" do
      {:ok, config} = Backend.create_config(:test, %{
        error_rate: 0.3,  # 30% error rate
        error_type: :timeout
      })

      # Make requests to generate mixed success/failure pattern
      for _i <- 1..20 do
        Backend.generate_response(config, "health_test", %{})
      end

      # Get comprehensive metrics
      metrics = MetricsCollector.get_metrics(:test)
      cb_metrics = CircuitBreaker.get_metrics(:test)

      # Verify health scoring reflects error rate
      assert metrics.error_rate > 0.1  # Should have some errors
      assert metrics.health_score < 1.0  # Should be reduced due to errors

      # Verify circuit breaker metrics are integrated
      assert cb_metrics.total_calls >= 20
      assert cb_metrics.failed_calls > 0

      # Health score should correlate with error patterns
      if metrics.error_rate > 0.5 do
        assert metrics.health_score < 0.5
      end
    end
  end

  describe "configuration and validation workflows" do
    test "configuration validation across all backend types" do
      backend_types = [:test, :openai, :anthropic]

      for backend_type <- backend_types do
        # Test valid configuration
        valid_options = case backend_type do
          :test -> %{}
          :openai -> %{api_key: "sk-test123456789012345678901234567890"}
          :anthropic -> %{api_key: "sk-ant-test123456789012345678901234567890"}
        end

        {:ok, config} = Backend.create_config(backend_type, valid_options)
        assert :ok = Backend.validate_config(config)

        # Test invalid configuration
        case backend_type do
          :test ->
            # Test backend should always validate
            :ok
          :openai ->
            {:ok, invalid_config} = Backend.create_config(backend_type, %{api_key: "invalid"})
            assert {:error, :invalid_api_key_format} = Backend.validate_config(invalid_config)
          :anthropic ->
            {:ok, invalid_config} = Backend.create_config(backend_type, %{api_key: "invalid"})
            assert {:error, :invalid_api_key_format} = Backend.validate_config(invalid_config)
        end
      end
    end

    test "dynamic configuration updates" do
      # Start with one configuration
      {:ok, config1} = Backend.create_config(:test, %{
        responses: %{"dynamic_test" => "Original response"},
        latency_ms: 10
      })

      assert {:ok, "Original response"} =
        Backend.generate_response(config1, "dynamic_test", %{})

      # Update configuration
      {:ok, config2} = Backend.create_config(:test, %{
        responses: %{"dynamic_test" => "Updated response"},
        latency_ms: 20
      })

      # Should use new configuration
      start_time = System.monotonic_time(:millisecond)
      assert {:ok, "Updated response"} =
        Backend.generate_response(config2, "dynamic_test", %{})
      end_time = System.monotonic_time(:millisecond)

      # Should respect new latency
      duration = end_time - start_time
      assert duration >= 15  # Should take at least ~20ms

      # Verify metrics tracked both configurations
      metrics = MetricsCollector.get_metrics(:test)
      assert metrics.total_requests >= 2
    end
  end

  describe "fault tolerance and resilience workflows" do
    test "system recovery after component failures" do
      {:ok, config} = Backend.create_config(:test, %{
        responses: %{"resilience_test" => "System is resilient"}
      })

      # Verify system works initially
      assert {:ok, _response} = Backend.generate_response(config, "resilience_test", %{})

      # Simulate metrics collector failure and restart
      metrics_pid = GenServer.whereis(MetricsCollector)
      GenServer.stop(metrics_pid)

      # System should handle missing metrics collector gracefully
      assert {:ok, _response} = Backend.generate_response(config, "resilience_test", %{})

      # Restart metrics collector
      {:ok, _new_metrics_pid} = MetricsCollector.start_link()

      # System should work with new metrics collector
      assert {:ok, _response} = Backend.generate_response(config, "resilience_test", %{})

      # Verify new metrics are being collected
      metrics = MetricsCollector.get_metrics(:test)
      assert metrics.total_requests >= 1
    end

    test "graceful handling of malformed inputs" do
      {:ok, config} = Backend.create_config(:test, %{
        responses: %{"malformed_test" => "Handled gracefully"}
      })

      # Test various malformed inputs
      malformed_inputs = [
        {"", %{}},  # Empty prompt
        {"normal prompt", %{temperature: "not_a_number"}},  # Invalid context
        {"normal prompt", %{max_tokens: -1}},  # Negative values
        {String.duplicate("x", 10_000), %{}},  # Very long prompt
        {"normal prompt", %{conversation_history: "not_a_list"}},  # Invalid history
        {"normal prompt", %{user_id: nil}},  # Nil values
      ]

      # System should handle all gracefully without crashing
      for {prompt, context} <- malformed_inputs do
        case Backend.generate_response(config, prompt, context) do
          {:ok, response} ->
            assert is_binary(response)
          {:error, reason} ->
            assert is_atom(reason) or is_tuple(reason)
        end
      end

      # System should still be functional
      assert {:ok, "Handled gracefully"} =
        Backend.generate_response(config, "malformed_test", %{})
    end
  end

  describe "performance and scalability workflows" do
    test "system performance under sustained load" do
      {:ok, config} = Backend.create_config(:test, %{
        responses: %{"perf_test" => "Performance test response"},
        latency_ms: 5  # Low latency for performance testing
      })

      # Measure baseline performance
      start_time = System.monotonic_time(:millisecond)

      # Make sustained requests
      request_count = 100
      tasks = for i <- 1..request_count do
        Task.async(fn ->
          Backend.generate_response(config, "perf_test", %{request_id: i})
        end)
      end

      results = Task.await_many(tasks, 30_000)  # 30 second timeout
      end_time = System.monotonic_time(:millisecond)

      # Analyze performance
      total_duration = end_time - start_time
      successful_requests = Enum.count(results, fn
        {:ok, _} -> true
        _ -> false
      end)

      # Performance assertions
      assert successful_requests >= request_count * 0.95  # 95% success rate
      assert total_duration < 10_000  # Should complete within 10 seconds

      # Calculate throughput
      throughput = successful_requests / (total_duration / 1000)  # requests per second
      assert throughput > 10  # Should handle at least 10 requests per second

      # Verify metrics accuracy under load
      metrics = MetricsCollector.get_metrics(:test)
      assert metrics.total_requests >= successful_requests
      assert metrics.successful_requests >= successful_requests * 0.95
    end

    test "memory usage stability during extended operation" do
      {:ok, config} = Backend.create_config(:test, %{
        responses: %{"memory_test" => "Memory stability test"}
      })

      # Get initial memory usage
      initial_memory = :erlang.memory(:total)

      # Perform extended operations
      for batch <- 1..10 do
        # Make batch of requests
        tasks = for i <- 1..20 do
          Task.async(fn ->
            Backend.generate_response(config, "memory_test", %{
              batch: batch,
              request: i,
              data: String.duplicate("x", 100)  # Some data to process
            })
          end)
        end

        Task.await_many(tasks)

        # Force garbage collection periodically
        if rem(batch, 3) == 0 do
          :erlang.garbage_collect()
        end
      end

      # Get final memory usage
      :erlang.garbage_collect()  # Force GC before measurement
      final_memory = :erlang.memory(:total)

      # Memory growth should be reasonable
      memory_growth = final_memory - initial_memory
      memory_growth_mb = memory_growth / (1024 * 1024)

      # Should not have excessive memory growth (less than 50MB)
      assert memory_growth_mb < 50

      # Verify system is still functional
      assert {:ok, "Memory stability test"} =
        Backend.generate_response(config, "memory_test", %{})
    end
  end

  # Property-based integration tests
  describe "property-based integration tests" do
    property "system maintains consistency under random operations" do
      check all operations <- list_of(
        {member_of([:generate_response, :health_check, :get_model_info, :reset_circuit_breaker]),
         string(:printable, max_length: 100)},
        min_length: 5, max_length: 15
      ) do

        {:ok, config} = Backend.create_config(:test, %{
          error_rate: 0.1,  # Low error rate for stability
          responses: %{"prop_test" => "Property test response"}
        })

        # Execute random operations
        for {operation, data} <- operations do
          case operation do
            :generate_response ->
              Backend.generate_response(config, data, %{})
            :health_check ->
              Backend.health_check(config)
            :get_model_info ->
              Backend.get_model_info(config)
            :reset_circuit_breaker ->
              CircuitBreaker.reset(:test)
          end
        end

        # System should remain in consistent state
        assert Backend.health_check(config) == :ok
        assert {:ok, _info} = Backend.get_model_info(config)

        # Circuit breaker should be in valid state
        cb_state = CircuitBreaker.get_state(:test)
        assert cb_state in [:closed, :open, :half_open]

        # Metrics should be consistent
        metrics = MetricsCollector.get_metrics(:test)
        assert metrics.total_requests >= 0
        assert metrics.successful_requests + metrics.failed_requests == metrics.total_requests
      end
    end
  end

  # Helper functions for integration tests

end
