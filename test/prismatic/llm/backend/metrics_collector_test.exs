defmodule Prismatic.LLM.Backend.MetricsCollectorTest do
  @moduledoc """
  Comprehensive test suite for the MetricsCollector module.

  This module tests the metrics collection system including request tracking,
  circuit breaker monitoring, telemetry integration, health scoring, and
  comprehensive analytics for LLM backend operations.
  """

  use ExUnit.Case, async: false  # MetricsCollector is a singleton GenServer
  use ExUnitProperties

  import Prismatic.TestHelpers
  import Prismatic.PropertyHelpers

  alias Prismatic.LLM.Backend.MetricsCollector

  # Setup and teardown for each test
  setup do
    # Start fresh MetricsCollector for each test
    case GenServer.whereis(MetricsCollector) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end

    {:ok, pid} = MetricsCollector.start_link()

    on_exit(fn ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)

    %{collector_pid: pid}
  end

  describe "start_link/1" do
    test "starts metrics collector with default configuration" do
      GenServer.stop(MetricsCollector)

      assert {:ok, pid} = MetricsCollector.start_link()
      assert Process.alive?(pid)
      assert GenServer.whereis(MetricsCollector) == pid
    end

    test "starts metrics collector with custom configuration" do
      GenServer.stop(MetricsCollector)

      opts = [name: :custom_metrics, telemetry_prefix: [:custom, :prefix]]
      assert {:ok, pid} = MetricsCollector.start_link(opts)
      assert Process.alive?(pid)
      assert GenServer.whereis(:custom_metrics) == pid

      GenServer.stop(pid)
    end
  end

  describe "record_request/3" do
    test "records successful request with basic data" do
      backend = :test_backend
      data = %{latency: 150, tokens: 100, cost: 0.002}

      assert :ok = MetricsCollector.record_request(backend, :success, data)

      metrics = MetricsCollector.get_metrics(backend)
      assert metrics.total_requests == 1
      assert metrics.successful_requests == 1
      assert metrics.failed_requests == 0
      assert metrics.total_tokens == 100
      assert metrics.total_cost == 0.002
      assert metrics.average_latency == 150.0
      assert metrics.min_latency == 150
      assert metrics.max_latency == 150
    end

    test "records failed request with error information" do
      backend = :test_backend
      data = %{latency: 5000, error_type: :timeout}

      assert :ok = MetricsCollector.record_request(backend, :error, data)

      metrics = MetricsCollector.get_metrics(backend)
      assert metrics.total_requests == 1
      assert metrics.successful_requests == 0
      assert metrics.failed_requests == 1
      assert metrics.error_breakdown[:timeout] == 1
      assert metrics.average_latency == 5000.0
    end

    test "accumulates metrics across multiple requests" do
      backend = :test_backend

      # Record multiple successful requests
      for i <- 1..5 do
        data = %{latency: i * 100, tokens: i * 10, cost: i * 0.001}
        MetricsCollector.record_request(backend, :success, data)
      end

      # Record some failed requests
      for i <- 1..3 do
        data = %{latency: i * 200, error_type: :rate_limit}
        MetricsCollector.record_request(backend, :error, data)
      end

      metrics = MetricsCollector.get_metrics(backend)
      assert metrics.total_requests == 8
      assert metrics.successful_requests == 5
      assert metrics.failed_requests == 3
      assert metrics.total_tokens == 150  # 10+20+30+40+50
      assert metrics.total_cost == 0.015  # 0.001+0.002+0.003+0.004+0.005
      assert metrics.error_breakdown[:rate_limit] == 3
    end

    test "calculates running average latency correctly" do
      backend = :test_backend

      # Record requests with different latencies
      latencies = [100, 200, 300, 400, 500]
      for latency <- latencies do
        data = %{latency: latency}
        MetricsCollector.record_request(backend, :success, data)
      end

      metrics = MetricsCollector.get_metrics(backend)
      expected_average = Enum.sum(latencies) / length(latencies)
      assert metrics.average_latency == expected_average
      assert metrics.min_latency == 100
      assert metrics.max_latency == 500
    end

    test "tracks min and max latencies correctly" do
      backend = :test_backend

      # Record requests in non-sequential order
      latencies = [300, 100, 500, 200, 400]
      for latency <- latencies do
        data = %{latency: latency}
        MetricsCollector.record_request(backend, :success, data)
      end

      metrics = MetricsCollector.get_metrics(backend)
      assert metrics.min_latency == 100
      assert metrics.max_latency == 500
    end

    test "handles requests without optional data" do
      backend = :test_backend

      # Request with minimal data
      assert :ok = MetricsCollector.record_request(backend, :success, %{})

      metrics = MetricsCollector.get_metrics(backend)
      assert metrics.total_requests == 1
      assert metrics.successful_requests == 1
      assert metrics.total_tokens == 0
      assert metrics.total_cost == 0.0
      assert metrics.average_latency == 0.0
    end

    test "classifies different error types correctly" do
      backend = :test_backend

      error_types = [
        :timeout,
        :rate_limit_exceeded,
        {:api_error, 500, "Server error"},
        {:api_error, 400, "Bad request"},
        :circuit_breaker_open,
        :unknown_error
      ]

      for error_type <- error_types do
        data = %{error_type: error_type}
        MetricsCollector.record_request(backend, :error, data)
      end

      metrics = MetricsCollector.get_metrics(backend)
      assert metrics.error_breakdown[:timeout] == 1
      assert metrics.error_breakdown[:rate_limit] == 1
      assert metrics.error_breakdown[:server_error] == 1
      assert metrics.error_breakdown[:client_error] == 1
      assert metrics.error_breakdown[:circuit_breaker] == 1
      assert metrics.error_breakdown[:unknown] == 1
    end

    test "updates timestamps correctly" do
      backend = :test_backend

      start_time = System.monotonic_time(:millisecond)

      # Record successful request
      MetricsCollector.record_request(backend, :success, %{})
      Process.sleep(10)

      # Record failed request
      MetricsCollector.record_request(backend, :error, %{error_type: :timeout})

      metrics = MetricsCollector.get_metrics(backend)

      assert metrics.last_request_time >= start_time
      assert metrics.last_success_time >= start_time
      assert metrics.last_error_time >= start_time
      assert metrics.last_error_time > metrics.last_success_time
    end
  end

  describe "record_circuit_breaker_event/2" do
    test "records circuit breaker open event" do
      backend = :test_backend

      assert :ok = MetricsCollector.record_circuit_breaker_event(backend, :open)

      metrics = MetricsCollector.get_metrics(backend)
      assert metrics.circuit_breaker.state == :open
      assert metrics.circuit_breaker.opens == 1
      assert metrics.circuit_breaker.closes == 0
      assert is_integer(metrics.circuit_breaker.last_state_change)
    end

    test "records circuit breaker close event" do
      backend = :test_backend

      # First open, then close
      MetricsCollector.record_circuit_breaker_event(backend, :open)
      MetricsCollector.record_circuit_breaker_event(backend, :close)

      metrics = MetricsCollector.get_metrics(backend)
      assert metrics.circuit_breaker.state == :closed
      assert metrics.circuit_breaker.opens == 1
      assert metrics.circuit_breaker.closes == 1
    end

    test "records circuit breaker half-open event" do
      backend = :test_backend

      assert :ok = MetricsCollector.record_circuit_breaker_event(backend, :half_open)

      metrics = MetricsCollector.get_metrics(backend)
      assert metrics.circuit_breaker.state == :half_open
    end

    test "tracks multiple circuit breaker state changes" do
      backend = :test_backend

      # Simulate multiple open/close cycles
      events = [:open, :close, :open, :half_open, :close]
      for event <- events do
        MetricsCollector.record_circuit_breaker_event(backend, event)
      end

      metrics = MetricsCollector.get_metrics(backend)
      assert metrics.circuit_breaker.state == :closed
      assert metrics.circuit_breaker.opens == 2
      assert metrics.circuit_breaker.closes == 2
    end
  end

  describe "get_metrics/1" do
    test "returns initialized metrics for new backend" do
      backend = :new_backend

      metrics = MetricsCollector.get_metrics(backend)

      # Verify all required fields are present with correct initial values
      assert metrics.total_requests == 0
      assert metrics.successful_requests == 0
      assert metrics.failed_requests == 0
      assert metrics.total_tokens == 0
      assert metrics.total_cost == 0.0
      assert metrics.average_latency == 0.0
      assert metrics.min_latency == nil
      assert metrics.max_latency == nil
      assert metrics.error_rate == 0.0
      assert metrics.last_request_time == nil
      assert metrics.last_success_time == nil
      assert metrics.last_error_time == nil
      assert metrics.error_breakdown == %{}
      assert metrics.circuit_breaker.state == :closed
      assert metrics.circuit_breaker.opens == 0
      assert metrics.circuit_breaker.closes == 0
      assert metrics.health_score == 1.0
    end

    test "calculates error rate correctly" do
      backend = :test_backend

      # 7 successes, 3 failures = 30% error rate
      for _i <- 1..7 do
        MetricsCollector.record_request(backend, :success, %{})
      end

      for _i <- 1..3 do
        MetricsCollector.record_request(backend, :error, %{error_type: :timeout})
      end

      metrics = MetricsCollector.get_metrics(backend)
      assert metrics.error_rate == 0.3
    end

    test "calculates health score based on error rate and recency" do
      backend = :test_backend

      # Record some successful requests
      for _i <- 1..8 do
        MetricsCollector.record_request(backend, :success, %{})
      end

      # Record some failures (20% error rate)
      for _i <- 1..2 do
        MetricsCollector.record_request(backend, :error, %{error_type: :timeout})
      end

      metrics = MetricsCollector.get_metrics(backend)

      # Health score should be reduced due to error rate
      assert metrics.health_score < 1.0
      assert metrics.health_score > 0.0

      # Should be approximately 1.0 - 0.2 = 0.8, but may be further reduced for recent errors
      assert metrics.health_score <= 0.8
    end
  end

  describe "get_global_metrics/0" do
    test "aggregates metrics across all backends" do
      # Record requests for multiple backends
      backends = [:backend1, :backend2, :backend3]

      for backend <- backends do
        # Each backend gets different amounts of requests
        for i <- 1..3 do
          data = %{tokens: i * 10, cost: i * 0.001}
          MetricsCollector.record_request(backend, :success, data)
        end

        # Add some failures
        MetricsCollector.record_request(backend, :error, %{error_type: :timeout})
      end

      global_metrics = MetricsCollector.get_global_metrics()

      # Should aggregate across all backends
      assert global_metrics.total_requests == 12  # 4 requests per backend * 3 backends
      assert global_metrics.successful_requests == 9  # 3 successes per backend * 3 backends
      assert global_metrics.failed_requests == 3  # 1 failure per backend * 3 backends
      assert global_metrics.total_tokens == 180  # (10+20+30) * 3 backends
      assert global_metrics.total_cost == 0.018  # (0.001+0.002+0.003) * 3 backends
      assert global_metrics.error_rate == 0.25  # 3 failures out of 12 requests
    end

    test "returns zero metrics when no requests recorded" do
      global_metrics = MetricsCollector.get_global_metrics()

      assert global_metrics.total_requests == 0
      assert global_metrics.successful_requests == 0
      assert global_metrics.failed_requests == 0
      assert global_metrics.total_tokens == 0
      assert global_metrics.total_cost == 0.0
      assert global_metrics.error_rate == 0.0
    end
  end

  describe "reset_metrics/1" do
    test "resets metrics for specific backend" do
      backend = :test_backend

      # Record some requests
      for _i <- 1..5 do
        data = %{latency: 100, tokens: 50, cost: 0.001}
        MetricsCollector.record_request(backend, :success, data)
      end

      # Verify metrics exist
      metrics_before = MetricsCollector.get_metrics(backend)
      assert metrics_before.total_requests == 5

      # Reset metrics
      assert :ok = MetricsCollector.reset_metrics(backend)

      # Verify metrics are reset
      metrics_after = MetricsCollector.get_metrics(backend)
      assert metrics_after.total_requests == 0
      assert metrics_after.successful_requests == 0
      assert metrics_after.total_tokens == 0
      assert metrics_after.total_cost == 0.0
      assert metrics_after.health_score == 1.0
    end

    test "reset does not affect other backends" do
      backend1 = :backend1
      backend2 = :backend2

      # Record requests for both backends
      MetricsCollector.record_request(backend1, :success, %{tokens: 100})
      MetricsCollector.record_request(backend2, :success, %{tokens: 200})

      # Reset only backend1
      MetricsCollector.reset_metrics(backend1)

      # Verify backend1 is reset but backend2 is not
      metrics1 = MetricsCollector.get_metrics(backend1)
      metrics2 = MetricsCollector.get_metrics(backend2)

      assert metrics1.total_requests == 0
      assert metrics2.total_requests == 1
      assert metrics2.total_tokens == 200
    end
  end

  describe "get_summary/0" do
    test "returns comprehensive summary with all metrics" do
      # Record requests for multiple backends
      MetricsCollector.record_request(:backend1, :success, %{tokens: 100})
      MetricsCollector.record_request(:backend2, :error, %{error_type: :timeout})

      summary = MetricsCollector.get_summary()

      # Verify summary structure
      assert Map.has_key?(summary, :global)
      assert Map.has_key?(summary, :backends)
      assert Map.has_key?(summary, :uptime)

      # Verify global metrics
      assert summary.global.total_requests == 2
      assert summary.global.successful_requests == 1
      assert summary.global.failed_requests == 1

      # Verify backend-specific metrics
      assert Map.has_key?(summary.backends, :backend1)
      assert Map.has_key?(summary.backends, :backend2)
      assert summary.backends[:backend1].total_tokens == 100

      # Verify uptime is reasonable
      assert is_integer(summary.uptime)
      assert summary.uptime >= 0
    end

    test "includes uptime calculation" do
      summary1 = MetricsCollector.get_summary()
      Process.sleep(100)
      summary2 = MetricsCollector.get_summary()

      assert summary2.uptime > summary1.uptime
    end
  end

  describe "telemetry integration" do
    test "emits telemetry events for requests" do
      # Set up telemetry handler
      test_pid = self()
      handler_id = "test-handler-#{:rand.uniform(1000)}"

      :telemetry.attach(
        handler_id,
        [:prismatic, :llm, :backend, :request],
        fn event_name, measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, event_name, measurements, metadata})
        end,
        nil
      )

      # Record a request
      backend = :test_backend
      data = %{latency: 150, tokens: 100}
      MetricsCollector.record_request(backend, :success, data)

      # Verify telemetry event was emitted
      assert_receive {:telemetry_event, [:prismatic, :llm, :backend, :request], measurements, metadata}

      assert Map.has_key?(measurements, :timestamp)
      assert metadata.backend == backend
      assert metadata.result == :success
      assert metadata.data == data

      :telemetry.detach(handler_id)
    end

    test "emits telemetry events for circuit breaker changes" do
      # Set up telemetry handler
      test_pid = self()
      handler_id = "test-cb-handler-#{:rand.uniform(1000)}"

      :telemetry.attach(
        handler_id,
        [:prismatic, :llm, :backend, :circuit_breaker],
        fn event_name, measurements, metadata, _config ->
          send(test_pid, {:telemetry_event, event_name, measurements, metadata})
        end,
        nil
      )

      # Record circuit breaker event
      backend = :test_backend
      MetricsCollector.record_circuit_breaker_event(backend, :open)

      # Verify telemetry event was emitted
      assert_receive {:telemetry_event, [:prismatic, :llm, :backend, :circuit_breaker], measurements, metadata}

      assert Map.has_key?(measurements, :timestamp)
      assert metadata.backend == backend
      assert metadata.event == :open

      :telemetry.detach(handler_id)
    end
  end

  # Property-based tests
  describe "property-based tests" do
    property "metrics always maintain consistency" do
      check all requests <- list_of(
        {member_of([:success, :error]),
         map_of(member_of([:latency, :tokens, :cost]), positive_integer())},
        min_length: 1, max_length: 50
      ) do

        backend = :"prop_test_#{:rand.uniform(1_000_000)}"

        for {result, data} <- requests do
          MetricsCollector.record_request(backend, result, data)
        end

        metrics = MetricsCollector.get_metrics(backend)

        # Basic consistency checks
        assert metrics.total_requests == length(requests)
        assert metrics.successful_requests + metrics.failed_requests == metrics.total_requests
        assert metrics.error_rate >= 0.0 and metrics.error_rate <= 1.0
        assert metrics.health_score >= 0.0 and metrics.health_score <= 1.0

        # If there are requests, some fields should be set
        if metrics.total_requests > 0 do
          assert is_integer(metrics.last_request_time)
        end
      end
    end

    property "global metrics equal sum of backend metrics" do
      check all backend_requests <- map_of(
        atom(:alphanumeric),
        list_of(member_of([:success, :error]), min_length: 1, max_length: 10),
        min_length: 1, max_length: 5
      ) do

        # Reset collector state
        for backend <- Map.keys(backend_requests) do
          MetricsCollector.reset_metrics(backend)
        end

        # Record requests for each backend
        for {backend, requests} <- backend_requests do
          for result <- requests do
            MetricsCollector.record_request(backend, result, %{tokens: 10})
          end
        end

        # Get global and individual metrics
        global_metrics = MetricsCollector.get_global_metrics()
        backend_metrics = for backend <- Map.keys(backend_requests) do
          MetricsCollector.get_metrics(backend)
        end

        # Verify global metrics equal sum of backend metrics
        total_requests = Enum.sum(Enum.map(backend_metrics, & &1.total_requests))
        total_successes = Enum.sum(Enum.map(backend_metrics, & &1.successful_requests))
        total_failures = Enum.sum(Enum.map(backend_metrics, & &1.failed_requests))
        total_tokens = Enum.sum(Enum.map(backend_metrics, & &1.total_tokens))

        assert global_metrics.total_requests == total_requests
        assert global_metrics.successful_requests == total_successes
        assert global_metrics.failed_requests == total_failures
        assert global_metrics.total_tokens == total_tokens
      end
    end
  end

  describe "concurrent access" do
    test "handles concurrent request recording safely" do
      backend = :concurrent_test

      # Spawn multiple processes recording requests concurrently
      tasks = for i <- 1..20 do
        Task.async(fn ->
          data = %{latency: i * 10, tokens: i}
          result = if rem(i, 3) == 0, do: :error, else: :success
          MetricsCollector.record_request(backend, result, data)
        end)
      end

      # Wait for all tasks to complete
      Task.await_many(tasks)

      # Verify metrics are consistent
      metrics = MetricsCollector.get_metrics(backend)
      assert metrics.total_requests == 20

      # Count expected successes and failures
      expected_failures = Enum.count(1..20, fn i -> rem(i, 3) == 0 end)
      expected_successes = 20 - expected_failures

      assert metrics.successful_requests == expected_successes
      assert metrics.failed_requests == expected_failures
    end

    test "handles concurrent backend access safely" do
      backends = for i <- 1..10, do: :"backend_#{i}"

      # Spawn tasks for different backends concurrently
      tasks = for backend <- backends do
        Task.async(fn ->
          for j <- 1..5 do
            data = %{tokens: j * 10}
            MetricsCollector.record_request(backend, :success, data)
          end
        end)
      end

      Task.await_many(tasks)

      # Verify each backend has correct metrics
      for backend <- backends do
        metrics = MetricsCollector.get_metrics(backend)
        assert metrics.total_requests == 5
        assert metrics.successful_requests == 5
        assert metrics.total_tokens == 150  # 10+20+30+40+50
      end

      # Verify global metrics
      global_metrics = MetricsCollector.get_global_metrics()
      assert global_metrics.total_requests == 50  # 5 requests * 10 backends
      assert global_metrics.total_tokens == 1500  # 150 tokens * 10 backends
    end
  end

  describe "edge cases and error handling" do
    test "handles very large numbers gracefully" do
      backend = :large_numbers_test

      large_data = %{
        latency: 999_999_999,
        tokens: 1_000_000,
        cost: 999.99
      }

      MetricsCollector.record_request(backend, :success, large_data)

      metrics = MetricsCollector.get_metrics(backend)
      assert metrics.average_latency == 999_999_999.0
      assert metrics.total_tokens == 1_000_000
      assert metrics.total_cost == 999.99
    end

    test "handles negative numbers appropriately" do
      backend = :negative_test

      # Negative values should be handled gracefully
      data = %{latency: -100, tokens: -50, cost: -0.01}

      MetricsCollector.record_request(backend, :success, data)

      metrics = MetricsCollector.get_metrics(backend)
      # System should handle negative values without crashing
      assert is_number(metrics.average_latency)
      assert is_number(metrics.total_tokens)
      assert is_number(metrics.total_cost)
    end

    test "handles malformed data gracefully" do
      backend = :malformed_test

      malformed_data = [
        %{latency: "not a number"},
        %{tokens: :atom},
        %{cost: %{nested: "map"}},
        %{unknown_field: "value"}
      ]

      # Should not crash on malformed data
      for data <- malformed_data do
        assert :ok = MetricsCollector.record_request(backend, :success, data)
      end

      metrics = MetricsCollector.get_metrics(backend)
      assert metrics.total_requests == 4
    end
  end

  # Doctests
  doctest MetricsCollector, import: true
end
