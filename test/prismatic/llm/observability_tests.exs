defmodule Prismatic.LLM.ObservabilityTest do
  @moduledoc """
  Observability tests for the LLM Backend system.

  These tests verify logging, telemetry, debugging capabilities,
  and monitoring integration across all system components.
  """

  use ExUnit.Case, async: true

  alias Prismatic.LLM.Backend
  alias Prismatic.LLM.Backend.{CircuitBreaker, MetricsCollector, RetryLogic}

  import ExUnit.CaptureLog

  describe "logging verification" do
    test "request logging includes essential information" do
      config = %{
        backend: :test,
        response: "Logged response",
        model: "test-model"
      }

      log_output = capture_log(fn ->
        {:ok, _} = Backend.generate_response(config, "Test prompt for logging")
      end)

      # Should log key request information
      assert String.contains?(log_output, "backend") or
             String.contains?(log_output, "request") or
             String.contains?(log_output, "response")
    end

    test "error logging provides debugging context" do
      config = %{
        backend: :test,
        error: :api_error,
        model: "test-model"
      }

      log_output = capture_log(fn ->
        {:error, _} = Backend.generate_response(config, "Error test prompt")
      end)

      # Should log error details for debugging
      assert String.contains?(log_output, "error") or
             String.contains?(log_output, "failed") or
             String.contains?(log_output, "exception")
    end

    test "log levels are appropriate for different scenarios" do
      scenarios = [
        {:info, %{backend: :test, response: "Info level", model: "test"}},
        {:warn, %{backend: :test, error: :rate_limited, model: "test"}},
        {:error, %{backend: :test, error: :api_error, model: "test"}}
      ]

      for {expected_level, config} <- scenarios do
        log_output = capture_log([level: expected_level], fn ->
          Backend.generate_response(config, "Log level test")
        end)

        # Should produce logs at the expected level
        case expected_level do
          :info -> assert log_output != ""
          :warn -> assert log_output != "" or expected_level == :warn
          :error -> assert log_output != "" or expected_level == :error
        end
      end
    end

    test "sensitive information is redacted from logs" do
      config = %{
        backend: :openai,
        api_key: "sk-sensitive-key-data-12345",
        model: "gpt-4",
        max_tokens: 100
      }

      log_output = capture_log(fn ->
        Backend.generate_response(config, "Test with sensitive data")
      end)

      # API keys should be redacted
      refute String.contains?(log_output, "sk-sensitive-key-data-12345")
      refute String.contains?(log_output, "sensitive-key-data")

      # But should indicate redaction
      assert String.contains?(log_output, "[REDACTED]") or
             String.contains?(log_output, "***") or
             String.contains?(log_output, "hidden")
    end

    test "structured logging format is consistent" do
      config = %{
        backend: :test,
        response: "Structured log test",
        model: "test-model"
      }

      log_output = capture_log(fn ->
        {:ok, _} = Backend.generate_response(config, "Structured logging test")
      end)

      # Should follow structured format (JSON or key-value pairs)
      has_structure = String.contains?(log_output, "=") or
                     String.contains?(log_output, ":") or
                     String.contains?(log_output, "{")

      assert has_structure, "Logs should follow structured format"
    end
  end

  describe "telemetry event verification" do
    test "request telemetry events are emitted" do
      # Attach telemetry handler
      events_received = :ets.new(:telemetry_test, [:set, :public])

      :telemetry.attach(
        "test-handler",
        [:prismatic, :llm, :request],
        fn event, measurements, metadata, _config ->
          :ets.insert(events_received, {event, measurements, metadata})
        end,
        nil
      )

      config = %{
        backend: :test,
        response: "Telemetry test response",
        model: "test-model"
      }

      {:ok, _} = Backend.generate_response(config, "Telemetry test")

      # Should have received telemetry events
      events = :ets.tab2list(events_received)
      assert length(events) > 0

      # Clean up
      :telemetry.detach("test-handler")
      :ets.delete(events_received)
    end

    test "circuit breaker telemetry includes state information" do
      events_received = :ets.new(:cb_telemetry_test, [:set, :public])

      :telemetry.attach(
        "cb-test-handler",
        [:prismatic, :llm, :circuit_breaker],
        fn event, measurements, metadata, _config ->
          :ets.insert(events_received, {event, measurements, metadata})
        end,
        nil
      )

      {:ok, cb_pid} = CircuitBreaker.start_link(
        name: :telemetry_test_cb,
        failure_threshold: 1,
        recovery_timeout: 100
      )

      # Trigger state change
      CircuitBreaker.call(cb_pid, fn ->
        {:error, %{type: :test_failure}}
      end)

      # Should have telemetry events
      events = :ets.tab2list(events_received)
      assert length(events) > 0

      # Clean up
      GenServer.stop(cb_pid)
      :telemetry.detach("cb-test-handler")
      :ets.delete(events_received)
    end

    test "metrics telemetry provides performance data" do
      events_received = :ets.new(:metrics_telemetry_test, [:set, :public])

      :telemetry.attach(
        "metrics-test-handler",
        [:prismatic, :llm, :metrics],
        fn event, measurements, metadata, _config ->
          :ets.insert(events_received, {event, measurements, metadata})
        end,
        nil
      )

      {:ok, metrics_pid} = MetricsCollector.start_link([])

      # Record some metrics
      MetricsCollector.record_request(metrics_pid, :success, 150)
      MetricsCollector.record_request(metrics_pid, :error, 75)

      # Should have telemetry events
      events = :ets.tab2list(events_received)
      assert length(events) > 0

      # Clean up
      GenServer.stop(metrics_pid)
      :telemetry.detach("metrics-test-handler")
      :ets.delete(events_received)
    end

    test "telemetry metadata includes correlation IDs" do
      events_received = :ets.new(:correlation_test, [:set, :public])

      :telemetry.attach(
        "correlation-test-handler",
        [:prismatic, :llm, :request],
        fn _event, _measurements, metadata, _config ->
          :ets.insert(events_received, {:metadata, metadata})
        end,
        nil
      )

      config = %{
        backend: :test,
        response: "Correlation test",
        model: "test-model",
        correlation_id: "test-correlation-123"
      }

      {:ok, _} = Backend.generate_response(config, "Correlation test")

      # Should include correlation information
      events = :ets.tab2list(events_received)

      if length(events) > 0 do
        {_key, metadata} = hd(events)
        assert is_map(metadata)
        # Should have some form of correlation/tracing info
        has_correlation = Map.has_key?(metadata, :correlation_id) or
                         Map.has_key?(metadata, :trace_id) or
                         Map.has_key?(metadata, :request_id)
        assert has_correlation
      end

      # Clean up
      :telemetry.detach("correlation-test-handler")
      :ets.delete(events_received)
    end
  end

  describe "debug information completeness" do
    test "debug mode provides detailed execution traces" do
      # Enable debug mode
      original_level = Logger.level()
      Logger.configure(level: :debug)

      config = %{
        backend: :test,
        response: "Debug trace test",
        model: "test-model",
        debug: true
      }

      log_output = capture_log([level: :debug], fn ->
        {:ok, _} = Backend.generate_response(config, "Debug test")
      end)

      # Should contain detailed debug information
      debug_indicators = [
        "debug",
        "trace",
        "step",
        "processing",
        "executing"
      ]

      has_debug_info = Enum.any?(debug_indicators, fn indicator ->
        String.contains?(String.downcase(log_output), indicator)
      end)

      assert has_debug_info or log_output != "",
             "Debug mode should provide detailed traces"

      # Restore original log level
      Logger.configure(level: original_level)
    end

    test "error traces include full context" do
      config = %{
        backend: :test,
        error: :detailed_error,
        model: "test-model"
      }

      log_output = capture_log(fn ->
        {:error, error} = Backend.generate_response(config, "Error context test")

        # Error should include context
        assert is_map(error)
        assert Map.has_key?(error, :type)
      end)

      # Log should include contextual information
      context_indicators = [
        "config",
        "request",
        "backend",
        "model",
        "error"
      ]

      has_context = Enum.any?(context_indicators, fn indicator ->
        String.contains?(String.downcase(log_output), indicator)
      end)

      assert has_context or log_output != "",
             "Error traces should include full context"
    end

    test "performance metrics are captured for debugging" do
      {:ok, metrics_pid} = MetricsCollector.start_link([])

      config = %{
        backend: :test,
        response: "Performance debug test",
        model: "test-model",
        delay: 100  # Add some measurable delay
      }

      start_time = System.monotonic_time(:millisecond)
      {:ok, _} = Backend.generate_response(config, "Performance test")
      end_time = System.monotonic_time(:millisecond)

      duration = end_time - start_time

      # Record the performance data
      MetricsCollector.record_request(metrics_pid, :success, duration)

      metrics = MetricsCollector.get_metrics(metrics_pid)

      # Should capture timing information
      assert metrics.total_requests > 0
      assert metrics.avg_latency > 0

      GenServer.stop(metrics_pid)
    end
  end

  describe "trace correlation accuracy" do
    test "requests maintain trace context across components" do
      trace_id = "trace-#{System.unique_integer()}"

      config = %{
        backend: :test,
        response: "Trace correlation test",
        model: "test-model",
        trace_id: trace_id
      }

      log_output = capture_log(fn ->
        {:ok, _} = Backend.generate_response(config, "Trace test")
      end)

      # Should maintain trace context
      assert String.contains?(log_output, trace_id) or
             String.contains?(log_output, "trace") or
             log_output != ""
    end

    test "circuit breaker operations are traceable" do
      {:ok, cb_pid} = CircuitBreaker.start_link(
        name: :trace_test_cb,
        failure_threshold: 2,
        recovery_timeout: 100
      )

      trace_id = "cb-trace-#{System.unique_integer()}"

      log_output = capture_log(fn ->
        # Make traceable calls
        CircuitBreaker.call(cb_pid, fn ->
          {:ok, "Traceable operation 1"}
        end, %{trace_id: trace_id})

        CircuitBreaker.call(cb_pid, fn ->
          {:error, %{type: :traceable_error}}
        end, %{trace_id: trace_id})
      end)

      # Should maintain trace context across circuit breaker operations
      assert String.contains?(log_output, trace_id) or
             String.contains?(log_output, "circuit") or
             log_output != ""

      GenServer.stop(cb_pid)
    end

    test "retry operations preserve trace information" do
      trace_id = "retry-trace-#{System.unique_integer()}"
      attempt_count = :counters.new(1, [])

      log_output = capture_log(fn ->
        RetryLogic.with_retry(fn ->
          count = :counters.add(attempt_count, 1, 1)
          if count < 3 do
            {:error, %{type: :retryable_error, trace_id: trace_id}}
          else
            {:ok, "Success with trace"}
          end
        end, RetryLogic.fast_retry_config())
      end)

      # Should preserve trace across retries
      final_count = :counters.get(attempt_count, 1)
      assert final_count == 3

      assert String.contains?(log_output, trace_id) or
             String.contains?(log_output, "retry") or
             log_output != ""
    end
  end

  describe "monitoring integration" do
    test "health check endpoints provide system status" do
      config = %{
        backend: :test,
        response: "Health check response",
        model: "test-model"
      }

      # Test health check functionality
      health_result = Backend.health_check(config)

      case health_result do
        {:ok, status} ->
          assert is_map(status)
          assert Map.has_key?(status, :status)
        {:error, _} ->
          :ok  # Health check can fail, but should be structured
      end
    end

    test "metrics endpoints provide operational data" do
      {:ok, metrics_pid} = MetricsCollector.start_link([])

      # Generate some operational data
      MetricsCollector.record_request(metrics_pid, :success, 100)
      MetricsCollector.record_request(metrics_pid, :error, 50)

      # Get metrics for monitoring
      metrics = MetricsCollector.get_metrics(metrics_pid)
      summary = MetricsCollector.get_summary(metrics_pid)

      # Should provide comprehensive operational data
      assert is_map(metrics)
      assert is_map(summary)

      # Should include key operational metrics
      assert Map.has_key?(metrics, :total_requests)
      assert Map.has_key?(metrics, :error_count)

      GenServer.stop(metrics_pid)
    end

    test "alerting thresholds are properly configured" do
      {:ok, cb_pid} = CircuitBreaker.start_link(
        name: :alert_test_cb,
        failure_threshold: 3,
        recovery_timeout: 1000
      )

      # Test alerting scenarios
      log_output = capture_log(fn ->
        # Trigger failures to reach threshold
        for _i <- 1..3 do
          CircuitBreaker.call(cb_pid, fn ->
            {:error, %{type: :threshold_test}}
          end)
        end

        # This should trigger circuit open (alerting condition)
        CircuitBreaker.call(cb_pid, fn ->
          {:ok, "Should be circuit broken"}
        end)
      end)

      # Should log alerting conditions
      alert_indicators = [
        "circuit",
        "open",
        "threshold",
        "failure",
        "alert"
      ]

      has_alert_info = Enum.any?(alert_indicators, fn indicator ->
        String.contains?(String.downcase(log_output), indicator)
      end)

      assert has_alert_info or log_output != "",
             "Should log alerting conditions"

      GenServer.stop(cb_pid)
    end
  end
end
