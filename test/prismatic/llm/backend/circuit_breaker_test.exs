defmodule Prismatic.LLM.Backend.CircuitBreakerTest do
  @moduledoc """
  Comprehensive test suite for the CircuitBreaker module.

  This module tests the circuit breaker pattern implementation including
  state transitions, failure detection, recovery mechanisms, metrics
  collection, and integration with the registry system.
  """

  use ExUnit.Case, async: false  # Circuit breaker uses global registry
  use ExUnitProperties

  import Prismatic.TestHelpers
  import Prismatic.PropertyHelpers

  alias Prismatic.LLM.Backend.CircuitBreaker
  alias Prismatic.LLM.CircuitBreakerRegistry

  # Setup and teardown for each test
  setup do
    # Start the circuit breaker registry
    {:ok, _registry_pid} = CircuitBreakerRegistry.start_link()

    # Generate unique backend name for each test
    backend_name = :"test_backend_#{:rand.uniform(1_000_000)}"

    # Start circuit breaker for this test
    {:ok, cb_pid} = CircuitBreaker.start_link(backend_name, [])

    on_exit(fn ->
      # Clean up processes
      if Process.alive?(cb_pid) do
        GenServer.stop(cb_pid)
      end
    end)

    %{backend_name: backend_name, cb_pid: cb_pid}
  end

  describe "start_link/2" do
    test "starts circuit breaker with default configuration" do
      backend_name = :test_start_default
      assert {:ok, pid} = CircuitBreaker.start_link(backend_name)
      assert Process.alive?(pid)

      # Should be registered in the registry
      assert [{^pid, _}] = Registry.lookup(CircuitBreakerRegistry, backend_name)

      GenServer.stop(pid)
    end

    test "starts circuit breaker with custom configuration" do
      backend_name = :test_start_custom
      opts = [
        failure_threshold: 10,
        recovery_timeout: 120_000,
        success_threshold: 5
      ]

      assert {:ok, pid} = CircuitBreaker.start_link(backend_name, opts)
      assert Process.alive?(pid)

      # Verify configuration was applied
      metrics = CircuitBreaker.get_metrics(backend_name)
      assert is_map(metrics)

      GenServer.stop(pid)
    end

    test "registers circuit breaker with unique name" do
      backend_name = :test_unique_registration
      assert {:ok, pid} = CircuitBreaker.start_link(backend_name)

      # Should be findable in registry
      assert [{^pid, _}] = Registry.lookup(CircuitBreakerRegistry, backend_name)

      GenServer.stop(pid)
    end
  end

  describe "call/2 - closed state" do
    test "executes function successfully in closed state", %{backend_name: backend_name} do
      test_function = fn -> {:ok, "success"} end

      assert {:ok, "success"} = CircuitBreaker.call(backend_name, test_function)
      assert :closed = CircuitBreaker.get_state(backend_name)
    end

    test "handles function errors in closed state", %{backend_name: backend_name} do
      test_function = fn -> {:error, :test_error} end

      assert {:error, :test_error} = CircuitBreaker.call(backend_name, test_function)
      assert :closed = CircuitBreaker.get_state(backend_name)
    end

    test "handles function exceptions in closed state", %{backend_name: backend_name} do
      test_function = fn -> raise "Test exception" end

      assert {:error, %RuntimeError{}} = CircuitBreaker.call(backend_name, test_function)
      assert :closed = CircuitBreaker.get_state(backend_name)
    end

    test "resets failure count on success", %{backend_name: backend_name} do
      # Cause some failures
      error_function = fn -> {:error, :test_error} end
      for _i <- 1..3 do
        CircuitBreaker.call(backend_name, error_function)
      end

      # Then succeed
      success_function = fn -> {:ok, "success"} end
      assert {:ok, "success"} = CircuitBreaker.call(backend_name, success_function)

      # Failure count should be reset
      metrics = CircuitBreaker.get_metrics(backend_name)
      assert metrics.failure_count == 0
    end
  end

  describe "call/2 - state transitions" do
    test "transitions from closed to open after threshold failures", %{backend_name: backend_name} do
      error_function = fn -> {:error, :test_error} end

      # Should start in closed state
      assert :closed = CircuitBreaker.get_state(backend_name)

      # Make failures up to threshold (default is 5)
      for i <- 1..5 do
        assert {:error, :test_error} = CircuitBreaker.call(backend_name, error_function)

        if i < 5 do
          assert :closed = CircuitBreaker.get_state(backend_name)
        else
          assert :open = CircuitBreaker.get_state(backend_name)
        end
      end
    end

    test "rejects calls immediately when open", %{backend_name: backend_name} do
      # Trip the circuit breaker
      error_function = fn -> {:error, :test_error} end
      for _i <- 1..5 do
        CircuitBreaker.call(backend_name, error_function)
      end

      assert :open = CircuitBreaker.get_state(backend_name)

      # Next call should be rejected immediately
      success_function = fn -> {:ok, "should not execute"} end
      assert {:error, :circuit_breaker_open} = CircuitBreaker.call(backend_name, success_function)
    end

    test "transitions from open to half-open after recovery timeout", %{backend_name: backend_name} do
      # Start with short recovery timeout
      GenServer.stop(Process.whereis({:via, Registry, {CircuitBreakerRegistry, backend_name}}))
      {:ok, _pid} = CircuitBreaker.start_link(backend_name, recovery_timeout: 100)

      # Trip the circuit breaker
      error_function = fn -> {:error, :test_error} end
      for _i <- 1..5 do
        CircuitBreaker.call(backend_name, error_function)
      end

      assert :open = CircuitBreaker.get_state(backend_name)

      # Wait for recovery timeout
      Process.sleep(150)

      # Next call should transition to half-open
      success_function = fn -> {:ok, "recovery test"} end
      assert {:ok, "recovery test"} = CircuitBreaker.call(backend_name, success_function)

      # Should now be closed after successful call in half-open
      assert :closed = CircuitBreaker.get_state(backend_name)
    end

    test "transitions from half-open to closed after success threshold", %{backend_name: backend_name} do
      # Start with custom success threshold
      GenServer.stop(Process.whereis({:via, Registry, {CircuitBreakerRegistry, backend_name}}))
      {:ok, _pid} = CircuitBreaker.start_link(backend_name, [
        recovery_timeout: 100,
        success_threshold: 3
      ])

      # Trip the circuit breaker
      error_function = fn -> {:error, :test_error} end
      for _i <- 1..5 do
        CircuitBreaker.call(backend_name, error_function)
      end

      # Wait for recovery
      Process.sleep(150)

      # Make successful calls to reach success threshold
      success_function = fn -> {:ok, "success"} end

      # First success should transition to half-open
      assert {:ok, "success"} = CircuitBreaker.call(backend_name, success_function)

      # Continue until success threshold is reached
      for _i <- 1..2 do
        assert {:ok, "success"} = CircuitBreaker.call(backend_name, success_function)
      end

      # Should now be closed
      assert :closed = CircuitBreaker.get_state(backend_name)
    end

    test "transitions from half-open back to open on failure", %{backend_name: backend_name} do
      # Start with short recovery timeout
      GenServer.stop(Process.whereis({:via, Registry, {CircuitBreakerRegistry, backend_name}}))
      {:ok, _pid} = CircuitBreaker.start_link(backend_name, recovery_timeout: 100)

      # Trip the circuit breaker
      error_function = fn -> {:error, :test_error} end
      for _i <- 1..5 do
        CircuitBreaker.call(backend_name, error_function)
      end

      # Wait for recovery
      Process.sleep(150)

      # Fail in half-open state
      assert {:error, :test_error} = CircuitBreaker.call(backend_name, error_function)

      # Should be back to open
      assert :open = CircuitBreaker.get_state(backend_name)
    end
  end

  describe "get_state/1" do
    test "returns current circuit breaker state", %{backend_name: backend_name} do
      # Should start closed
      assert :closed = CircuitBreaker.get_state(backend_name)

      # Trip to open
      error_function = fn -> {:error, :test_error} end
      for _i <- 1..5 do
        CircuitBreaker.call(backend_name, error_function)
      end

      assert :open = CircuitBreaker.get_state(backend_name)
    end
  end

  describe "get_metrics/1" do
    test "returns comprehensive metrics", %{backend_name: backend_name} do
      metrics = CircuitBreaker.get_metrics(backend_name)

      # Verify all expected fields are present
      assert Map.has_key?(metrics, :current_state)
      assert Map.has_key?(metrics, :failure_count)
      assert Map.has_key?(metrics, :success_count)
      assert Map.has_key?(metrics, :last_failure_time)
      assert Map.has_key?(metrics, :total_calls)
      assert Map.has_key?(metrics, :successful_calls)
      assert Map.has_key?(metrics, :failed_calls)
      assert Map.has_key?(metrics, :circuit_opens)
      assert Map.has_key?(metrics, :circuit_closes)
      assert Map.has_key?(metrics, :created_at)

      # Initial values
      assert metrics.current_state == :closed
      assert metrics.failure_count == 0
      assert metrics.success_count == 0
      assert metrics.total_calls == 0
    end

    test "updates metrics after operations", %{backend_name: backend_name} do
      # Make some successful calls
      success_function = fn -> {:ok, "success"} end
      for _i <- 1..3 do
        CircuitBreaker.call(backend_name, success_function)
      end

      # Make some failed calls
      error_function = fn -> {:error, :test_error} end
      for _i <- 1..2 do
        CircuitBreaker.call(backend_name, error_function)
      end

      metrics = CircuitBreaker.get_metrics(backend_name)
      assert metrics.total_calls == 5
      assert metrics.successful_calls == 3
      assert metrics.failed_calls == 2
      assert metrics.failure_count == 2  # Current consecutive failures
    end

    test "tracks circuit breaker state changes", %{backend_name: backend_name} do
      # Trip the circuit breaker
      error_function = fn -> {:error, :test_error} end
      for _i <- 1..5 do
        CircuitBreaker.call(backend_name, error_function)
      end

      metrics = CircuitBreaker.get_metrics(backend_name)
      assert metrics.circuit_opens == 1
      assert metrics.current_state == :open
    end
  end

  describe "reset/1" do
    test "resets circuit breaker to closed state", %{backend_name: backend_name} do
      # Trip the circuit breaker
      error_function = fn -> {:error, :test_error} end
      for _i <- 1..5 do
        CircuitBreaker.call(backend_name, error_function)
      end

      assert :open = CircuitBreaker.get_state(backend_name)

      # Reset the circuit breaker
      assert :ok = CircuitBreaker.reset(backend_name)

      # Should be closed now
      assert :closed = CircuitBreaker.get_state(backend_name)

      # Should accept calls again
      success_function = fn -> {:ok, "success after reset"} end
      assert {:ok, "success after reset"} = CircuitBreaker.call(backend_name, success_function)
    end

    test "resets failure and success counts", %{backend_name: backend_name} do
      # Make some calls to build up counts
      error_function = fn -> {:error, :test_error} end
      for _i <- 1..3 do
        CircuitBreaker.call(backend_name, error_function)
      end

      # Reset
      CircuitBreaker.reset(backend_name)

      # Metrics should be reset
      metrics = CircuitBreaker.get_metrics(backend_name)
      assert metrics.failure_count == 0
      assert metrics.success_count == 0
      assert metrics.last_failure_time == nil
    end
  end

  describe "configuration options" do
    test "respects custom failure threshold" do
      backend_name = :test_custom_threshold
      {:ok, _pid} = CircuitBreaker.start_link(backend_name, failure_threshold: 3)

      error_function = fn -> {:error, :test_error} end

      # Should trip after 3 failures instead of default 5
      for i <- 1..3 do
        CircuitBreaker.call(backend_name, error_function)

        if i < 3 do
          assert :closed = CircuitBreaker.get_state(backend_name)
        else
          assert :open = CircuitBreaker.get_state(backend_name)
        end
      end

      GenServer.stop(Process.whereis({:via, Registry, {CircuitBreakerRegistry, backend_name}}))
    end

    test "respects custom success threshold" do
      backend_name = :test_custom_success
      {:ok, _pid} = CircuitBreaker.start_link(backend_name, [
        recovery_timeout: 50,
        success_threshold: 2
      ])

      # Trip the circuit breaker
      error_function = fn -> {:error, :test_error} end
      for _i <- 1..5 do
        CircuitBreaker.call(backend_name, error_function)
      end

      # Wait for recovery
      Process.sleep(100)

      # Should close after 2 successes instead of default 3
      success_function = fn -> {:ok, "success"} end

      CircuitBreaker.call(backend_name, success_function)
      assert :half_open = CircuitBreaker.get_state(backend_name)

      CircuitBreaker.call(backend_name, success_function)
      assert :closed = CircuitBreaker.get_state(backend_name)

      GenServer.stop(Process.whereis({:via, Registry, {CircuitBreakerRegistry, backend_name}}))
    end
  end

  describe "concurrent access" do
    test "handles concurrent calls safely", %{backend_name: backend_name} do
      # Spawn multiple concurrent calls
      tasks = for i <- 1..20 do
        Task.async(fn ->
          if rem(i, 3) == 0 do
            # Some calls fail
            CircuitBreaker.call(backend_name, fn -> {:error, :test_error} end)
          else
            # Most calls succeed
            CircuitBreaker.call(backend_name, fn -> {:ok, "success #{i}"} end)
          end
        end)
      end

      # Wait for all to complete
      results = Task.await_many(tasks)

      # Should have mix of successes and errors
      successes = Enum.count(results, fn
        {:ok, _} -> true
        _ -> false
      end)

      errors = Enum.count(results, fn
        {:error, _} -> true
        _ -> false
      end)

      assert successes > 0
      assert errors > 0
      assert successes + errors == 20

      # Metrics should reflect all calls
      metrics = CircuitBreaker.get_metrics(backend_name)
      assert metrics.total_calls == 20
    end

    test "state transitions are atomic", %{backend_name: backend_name} do
      # This test ensures that state transitions don't race
      error_function = fn -> {:error, :test_error} end

      # Spawn tasks that will cause failures
      tasks = for _i <- 1..10 do
        Task.async(fn ->
          CircuitBreaker.call(backend_name, error_function)
        end)
      end

      Task.await_many(tasks)

      # Should be in a consistent state
      state = CircuitBreaker.get_state(backend_name)
      assert state in [:closed, :open, :half_open]

      # Metrics should be consistent
      metrics = CircuitBreaker.get_metrics(backend_name)
      assert metrics.total_calls == 10
      assert metrics.failed_calls == 10
    end
  end

  # Property-based tests
  describe "property-based tests" do
    property "circuit breaker always maintains valid state" do
      check all operations <- list_of(member_of([:success, :error]), min_length: 1, max_length: 20) do
        backend_name = :"prop_test_#{:rand.uniform(1_000_000)}"
        {:ok, _pid} = CircuitBreaker.start_link(backend_name)

        try do
          for operation <- operations do
            case operation do
              :success ->
                CircuitBreaker.call(backend_name, fn -> {:ok, "success"} end)
              :error ->
                CircuitBreaker.call(backend_name, fn -> {:error, :test_error} end)
            end
          end

          # State should always be valid
          state = CircuitBreaker.get_state(backend_name)
          assert state in [:closed, :open, :half_open]

          # Metrics should be consistent
          metrics = CircuitBreaker.get_metrics(backend_name)
          assert metrics.total_calls == length(operations)
          assert metrics.successful_calls + metrics.failed_calls == metrics.total_calls

        after
          GenServer.stop(Process.whereis({:via, Registry, {CircuitBreakerRegistry, backend_name}}))
        end
      end
    end

    property "failure count never exceeds threshold in closed state" do
      check all failure_threshold <- integer(1..10),
                num_failures <- integer(1..20) do

        backend_name = :"prop_test_#{:rand.uniform(1_000_000)}"
        {:ok, _pid} = CircuitBreaker.start_link(backend_name, failure_threshold: failure_threshold)

        try do
          error_function = fn -> {:error, :test_error} end

          for _i <- 1..num_failures do
            CircuitBreaker.call(backend_name, error_function)

            state = CircuitBreaker.get_state(backend_name)
            metrics = CircuitBreaker.get_metrics(backend_name)

            if state == :closed do
              assert metrics.failure_count < failure_threshold
            end
          end

        after
          GenServer.stop(Process.whereis({:via, Registry, {CircuitBreakerRegistry, backend_name}}))
        end
      end
    end
  end

  describe "error handling and edge cases" do
    test "handles function that returns non-tuple values", %{backend_name: backend_name} do
      weird_function = fn -> "just a string" end

      # Should treat non-error tuples as success
      assert {:ok, "just a string"} = CircuitBreaker.call(backend_name, weird_function)
    end

    test "handles function that throws", %{backend_name: backend_name} do
      throwing_function = fn -> throw(:test_throw) end

      assert {:error, {:throw, :test_throw}} = CircuitBreaker.call(backend_name, throwing_function)
    end

    test "handles function that exits", %{backend_name: backend_name} do
      exiting_function = fn -> exit(:test_exit) end

      assert {:error, {:exit, :test_exit}} = CircuitBreaker.call(backend_name, exiting_function)
    end

    test "handles very long running functions", %{backend_name: backend_name} do
      # Function that takes a while but eventually succeeds
      slow_function = fn ->
        Process.sleep(100)
        {:ok, "slow success"}
      end

      start_time = System.monotonic_time(:millisecond)
      assert {:ok, "slow success"} = CircuitBreaker.call(backend_name, slow_function)
      end_time = System.monotonic_time(:millisecond)

      # Should have taken at least the sleep time
      assert end_time - start_time >= 90
    end
  end

  # Integration tests
  describe "integration with registry" do
    test "circuit breaker is findable in registry", %{backend_name: backend_name} do
      # Should be registered
      assert [{pid, _}] = Registry.lookup(CircuitBreakerRegistry, backend_name)
      assert Process.alive?(pid)
    end

    test "multiple circuit breakers can coexist" do
      backend_names = [:cb1, :cb2, :cb3]
      pids = for name <- backend_names do
        {:ok, pid} = CircuitBreaker.start_link(name)
        pid
      end

      try do
        # All should be registered
        for {name, pid} <- Enum.zip(backend_names, pids) do
          assert [{^pid, _}] = Registry.lookup(CircuitBreakerRegistry, name)
        end

        # Each should maintain independent state
        CircuitBreaker.call(:cb1, fn -> {:error, :test_error} end)
        CircuitBreaker.call(:cb2, fn -> {:ok, "success"} end)

        # States should be independent
        cb1_metrics = CircuitBreaker.get_metrics(:cb1)
        cb2_metrics = CircuitBreaker.get_metrics(:cb2)

        assert cb1_metrics.failed_calls == 1
        assert cb2_metrics.successful_calls == 1
        assert cb1_metrics.successful_calls == 0
        assert cb2_metrics.failed_calls == 0

      after
        for pid <- pids do
          if Process.alive?(pid) do
            GenServer.stop(pid)
          end
        end
      end
    end
  end

  # Doctests
  doctest CircuitBreaker, import: true
end
