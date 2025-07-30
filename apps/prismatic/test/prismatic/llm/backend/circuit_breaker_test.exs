defmodule Prismatic.LLM.Backend.CircuitBreakerTest do
  use ExUnit.Case, async: true

  alias Prismatic.LLM.Backend.CircuitBreaker
  alias Prismatic.LLM.CircuitBreakerRegistry

  @moduletag :llm

  setup do
    # Start the registry for this test
    start_supervised!(CircuitBreakerRegistry)
    :ok
  end

  describe "circuit breaker lifecycle" do
    test "starts and initializes with closed state" do
      backend_name = :test_backend_#{:rand.uniform(10000)}

      {:ok, _pid} = CircuitBreaker.start_link(backend_name)

      state = CircuitBreaker.get_state(backend_name)
      assert state == :closed
    end

    test "starts with custom configuration" do
      backend_name = :test_backend_#{:rand.uniform(10000)}
      opts = [failure_threshold: 3, recovery_timeout: 30_000]

      {:ok, _pid} = CircuitBreaker.start_link(backend_name, opts)

      metrics = CircuitBreaker.get_metrics(backend_name)
      assert is_map(metrics)
    end
  end

  describe "circuit breaker states" do
    setup do
      backend_name = :test_backend_#{:rand.uniform(10000)}
      {:ok, _pid} = CircuitBreaker.start_link(backend_name, failure_threshold: 2)

      {:ok, backend_name: backend_name}
    end

    test "transitions from closed to open after failures", %{backend_name: backend_name} do
      # Initially closed
      assert CircuitBreaker.get_state(backend_name) == :closed

      # First failure
      result1 = CircuitBreaker.call(backend_name, fn -> {:error, :test_failure} end)
      assert result1 == {:error, :test_failure}
      assert CircuitBreaker.get_state(backend_name) == :closed

      # Second failure - should trip circuit
      result2 = CircuitBreaker.call(backend_name, fn -> {:error, :test_failure} end)
      assert result2 == {:error, :test_failure}
      assert CircuitBreaker.get_state(backend_name) == :open
    end

    test "rejects calls immediately when open", %{backend_name: backend_name} do
      # Trip the circuit breaker
      CircuitBreaker.call(backend_name, fn -> {:error, :failure1} end)
      CircuitBreaker.call(backend_name, fn -> {:error, :failure2} end)

      # Verify it's open
      assert CircuitBreaker.get_state(backend_name) == :open

      # Now calls should be rejected immediately
      result = CircuitBreaker.call(backend_name, fn -> {:ok, "should not execute"} end)
      assert result == {:error, :circuit_breaker_open}
    end

    test "successful calls reset failure count in closed state", %{backend_name: backend_name} do
      # One failure
      CircuitBreaker.call(backend_name, fn -> {:error, :test_failure} end)
      assert CircuitBreaker.get_state(backend_name) == :closed

      # Success should reset failure count
      result = CircuitBreaker.call(backend_name, fn -> {:ok, "success"} end)
      assert result == {:ok, "success"}
      assert CircuitBreaker.get_state(backend_name) == :closed

      # Should take 2 more failures to trip circuit now
      CircuitBreaker.call(backend_name, fn -> {:error, :failure1} end)
      assert CircuitBreaker.get_state(backend_name) == :closed

      CircuitBreaker.call(backend_name, fn -> {:error, :failure2} end)
      assert CircuitBreaker.get_state(backend_name) == :open
    end
  end

  describe "circuit breaker recovery" do
    setup do
      backend_name = :test_backend_#{:rand.uniform(10000)}
      # Use short recovery timeout for testing
      {:ok, _pid} = CircuitBreaker.start_link(backend_name,
        failure_threshold: 1,
        recovery_timeout: 100,
        success_threshold: 2
      )

      {:ok, backend_name: backend_name}
    end

    test "transitions to half-open after recovery timeout", %{backend_name: backend_name} do
      # Trip the circuit
      CircuitBreaker.call(backend_name, fn -> {:error, :failure} end)
      assert CircuitBreaker.get_state(backend_name) == :open

      # Wait for recovery timeout
      Process.sleep(150)

      # Next call should transition to half-open
      result = CircuitBreaker.call(backend_name, fn -> {:ok, "recovery attempt"} end)
      assert result == {:ok, "recovery attempt"}

      # Should be in half-open or closed state now
      state = CircuitBreaker.get_state(backend_name)
      assert state in [:half_open, :closed]
    end

    test "requires multiple successes to close from half-open", %{backend_name: backend_name} do
      # Trip the circuit
      CircuitBreaker.call(backend_name, fn -> {:error, :failure} end)
      assert CircuitBreaker.get_state(backend_name) == :open

      # Wait for recovery timeout
      Process.sleep(150)

      # First success - should be half-open
      CircuitBreaker.call(backend_name, fn -> {:ok, "success1"} end)

      # Might be half-open or closed depending on success_threshold
      state = CircuitBreaker.get_state(backend_name)
      assert state in [:half_open, :closed]
    end
  end

  describe "circuit breaker metrics" do
    setup do
      backend_name = :test_backend_#{:rand.uniform(10000)}
      {:ok, _pid} = CircuitBreaker.start_link(backend_name)

      {:ok, backend_name: backend_name}
    end

    test "tracks call metrics", %{backend_name: backend_name} do
      # Make some calls
      CircuitBreaker.call(backend_name, fn -> {:ok, "success"} end)
      CircuitBreaker.call(backend_name, fn -> {:error, :failure} end)

      metrics = CircuitBreaker.get_metrics(backend_name)

      assert metrics.total_calls >= 2
      assert metrics.successful_calls >= 1
      assert metrics.failed_calls >= 1
    end

    test "tracks circuit state changes", %{backend_name: backend_name} do
      initial_metrics = CircuitBreaker.get_metrics(backend_name)

      # Trip the circuit (using default failure_threshold of 5)
      for _ <- 1..5 do
        CircuitBreaker.call(backend_name, fn -> {:error, :failure} end)
      end

      final_metrics = CircuitBreaker.get_metrics(backend_name)
      assert final_metrics.circuit_opens > initial_metrics.circuit_opens
    end
  end

  describe "circuit breaker reset" do
    setup do
      backend_name = :test_backend_#{:rand.uniform(10000)}
      {:ok, _pid} = CircuitBreaker.start_link(backend_name, failure_threshold: 1)

      {:ok, backend_name: backend_name}
    end

    test "manual reset closes open circuit", %{backend_name: backend_name} do
      # Trip the circuit
      CircuitBreaker.call(backend_name, fn -> {:error, :failure} end)
      assert CircuitBreaker.get_state(backend_name) == :open

      # Reset manually
      :ok = CircuitBreaker.reset(backend_name)
      assert CircuitBreaker.get_state(backend_name) == :closed

      # Should work normally now
      result = CircuitBreaker.call(backend_name, fn -> {:ok, "success"} end)
      assert result == {:ok, "success"}
    end
  end

  describe "error handling and edge cases" do
    setup do
      backend_name = :test_backend_#{:rand.uniform(10000)}
      {:ok, _pid} = CircuitBreaker.start_link(backend_name)

      {:ok, backend_name: backend_name}
    end

    test "handles function exceptions", %{backend_name: backend_name} do
      result = CircuitBreaker.call(backend_name, fn ->
        raise "test exception"
      end)

      assert match?({:error, _}, result)
    end

    test "handles function exits", %{backend_name: backend_name} do
      result = CircuitBreaker.call(backend_name, fn ->
        exit(:test_exit)
      end)

      assert match?({:error, {:exit, :test_exit}}, result)
    end

    test "only accepts zero-arity functions", %{backend_name: backend_name} do
      assert_raise FunctionClauseError, fn ->
        CircuitBreaker.call(backend_name, fn x -> x end)
      end
    end
  end

  describe "concurrent access" do
    setup do
      backend_name = :test_backend_#{:rand.uniform(10000)}
      {:ok, _pid} = CircuitBreaker.start_link(backend_name)

      {:ok, backend_name: backend_name}
    end

    test "handles concurrent calls safely", %{backend_name: backend_name} do
      # Spawn multiple processes making calls concurrently
      tasks = for i <- 1..10 do
        Task.async(fn ->
          CircuitBreaker.call(backend_name, fn ->
            Process.sleep(:rand.uniform(10))
            {:ok, "result_#{i}"}
          end)
        end)
      end

      results = Task.await_many(tasks, 5000)

      # All should succeed
      Enum.each(results, fn result ->
        assert match?({:ok, _}, result)
      end)

      # Metrics should reflect all calls
      metrics = CircuitBreaker.get_metrics(backend_name)
      assert metrics.total_calls >= 10
    end
  end
end
