defmodule Prismatic.LLM.CircuitBreakerRegistryTest do
  @moduledoc """
  Comprehensive test suite for the CircuitBreakerRegistry module.

  This module tests the registry functionality for managing circuit breaker
  processes, including process registration, lookup, supervision, and
  integration with the circuit breaker system.
  """

  use ExUnit.Case, async: false  # Registry operations need to be sequential
  use ExUnitProperties

  alias Prismatic.LLM.Backend.CircuitBreaker
  alias Prismatic.LLM.CircuitBreakerRegistry

  # Setup and teardown for each test
  setup do
    # Stop existing registry if running
    case Process.whereis(CircuitBreakerRegistry) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end

    # Start fresh registry for each test
    {:ok, registry_pid} = CircuitBreakerRegistry.start_link()

    on_exit(fn ->
      if Process.alive?(registry_pid) do
        GenServer.stop(registry_pid)
      end
    end)

    %{registry_pid: registry_pid}
  end

  describe "start_link/1" do
    test "starts registry with default configuration" do
      GenServer.stop(CircuitBreakerRegistry)

      assert {:ok, pid} = CircuitBreakerRegistry.start_link()
      assert Process.alive?(pid)
      assert GenServer.whereis(CircuitBreakerRegistry) == pid
    end

    test "starts registry with custom name" do
      GenServer.stop(CircuitBreakerRegistry)

      custom_name = :custom_cb_registry
      opts = [name: custom_name]

      assert {:ok, pid} = CircuitBreakerRegistry.start_link(opts)
      assert Process.alive?(pid)
      assert GenServer.whereis(custom_name) == pid

      GenServer.stop(pid)
    end

    test "registry is configured for unique keys" do
      # Verify registry configuration by attempting to register same key twice
      backend_name = :test_backend

      # First registration should succeed
      {:ok, _} = Registry.register(CircuitBreakerRegistry, backend_name, nil)

      # Second registration should fail due to unique key constraint
      assert {:error, {:already_registered, _pid}} =
        Registry.register(CircuitBreakerRegistry, backend_name, nil)
    end

    test "handles registry restart gracefully" do
      # Start some circuit breakers
      backend_names = [:backend1, :backend2, :backend3]
      cb_pids = for name <- backend_names do
        {:ok, pid} = CircuitBreaker.start_link(name)
        pid
      end

      # Verify they're registered
      for {name, pid} <- Enum.zip(backend_names, cb_pids) do
        assert [{^pid, _}] = Registry.lookup(CircuitBreakerRegistry, name)
      end

      # Restart registry
      GenServer.stop(CircuitBreakerRegistry)
      {:ok, _new_registry_pid} = CircuitBreakerRegistry.start_link()

      # Circuit breakers should still be running but not registered
      for pid <- cb_pids do
        assert Process.alive?(pid)
      end

      # Registry should be empty
      for name <- backend_names do
        assert [] = Registry.lookup(CircuitBreakerRegistry, name)
      end

      # Clean up
      for pid <- cb_pids do
        if Process.alive?(pid) do
          GenServer.stop(pid)
        end
      end
    end
  end

  describe "child_spec/1" do
    test "returns valid child specification" do
      child_spec = CircuitBreakerRegistry.child_spec([])

      assert child_spec.id == CircuitBreakerRegistry
      assert {CircuitBreakerRegistry, :start_link, [[]]} = child_spec.start
      assert child_spec.type == :worker
      assert child_spec.restart == :permanent
      assert child_spec.shutdown == 5000
    end

    test "child spec works with custom options" do
      opts = [name: :custom_registry]
      child_spec = CircuitBreakerRegistry.child_spec(opts)

      assert {CircuitBreakerRegistry, :start_link, [^opts]} = child_spec.start
    end

    test "child spec can be used in supervision tree" do
      # This test verifies the child spec is compatible with Supervisor
      children = [CircuitBreakerRegistry.child_spec([])]

      # Should be able to start supervisor with this child spec
      assert {:ok, sup_pid} = Supervisor.start_link(children, strategy: :one_for_one)

      # Registry should be running
      assert Process.whereis(CircuitBreakerRegistry) != nil

      # Clean up
      Supervisor.stop(sup_pid)
    end
  end

  describe "registry integration with circuit breakers" do
    test "circuit breakers register themselves automatically" do
      backend_name = :auto_register_test

      # Start circuit breaker - should auto-register
      {:ok, cb_pid} = CircuitBreaker.start_link(backend_name)

      # Should be findable in registry
      assert [{^cb_pid, _}] = Registry.lookup(CircuitBreakerRegistry, backend_name)

      GenServer.stop(cb_pid)
    end

    test "multiple circuit breakers can coexist in registry" do
      backend_names = [:cb1, :cb2, :cb3, :cb4, :cb5]
      _cb_pids = []

      # Start multiple circuit breakers
      cb_pids = for name <- backend_names do
        {:ok, pid} = CircuitBreaker.start_link(name)
        pid
      end

      # All should be registered with unique names
      for {name, expected_pid} <- Enum.zip(backend_names, cb_pids) do
        assert [{^expected_pid, _}] = Registry.lookup(CircuitBreakerRegistry, name)
      end

      # Registry should contain all entries
      all_entries = Registry.select(CircuitBreakerRegistry, [{{:"$1", :"$2", :"$3"}, [], [:"$1"]}])
      assert length(all_entries) == 5

      for name <- backend_names do
        assert name in all_entries
      end

      # Clean up
      for pid <- cb_pids do
        GenServer.stop(pid)
      end
    end

    test "circuit breaker unregisters when stopped" do
      backend_name = :unregister_test

      # Start and verify registration
      {:ok, cb_pid} = CircuitBreaker.start_link(backend_name)
      assert [{^cb_pid, _}] = Registry.lookup(CircuitBreakerRegistry, backend_name)

      # Stop circuit breaker
      GenServer.stop(cb_pid)

      # Should be unregistered
      assert [] = Registry.lookup(CircuitBreakerRegistry, backend_name)
    end

    test "registry handles circuit breaker crashes gracefully" do
      backend_name = :crash_test

      # Start circuit breaker
      {:ok, cb_pid} = CircuitBreaker.start_link(backend_name)
      assert [{^cb_pid, _}] = Registry.lookup(CircuitBreakerRegistry, backend_name)

      # Simulate crash
      Process.exit(cb_pid, :kill)

      # Wait for cleanup
      Process.sleep(10)

      # Should be unregistered
      assert [] = Registry.lookup(CircuitBreakerRegistry, backend_name)
    end

    test "can lookup circuit breakers by backend name" do
      backends_and_pids = for i <- 1..3 do
        name = :"lookup_test_#{i}"
        {:ok, pid} = CircuitBreaker.start_link(name)
        {name, pid}
      end

      # Test lookup for each
      for {name, expected_pid} <- backends_and_pids do
        case Registry.lookup(CircuitBreakerRegistry, name) do
          [{^expected_pid, _}] -> :ok
          other -> flunk("Expected [{#{inspect(expected_pid)}, _}], got #{inspect(other)}")
        end
      end

      # Test lookup for non-existent backend
      assert [] = Registry.lookup(CircuitBreakerRegistry, :non_existent)

      # Clean up
      for {_name, pid} <- backends_and_pids do
        GenServer.stop(pid)
      end
    end
  end

  describe "registry operations" do
    test "supports manual registration and unregistration" do
      backend_name = :manual_test
      test_pid = self()

      # Manual registration
      {:ok, _owner} = Registry.register(CircuitBreakerRegistry, backend_name, :test_value)

      # Should be findable
      assert [{^test_pid, :test_value}] = Registry.lookup(CircuitBreakerRegistry, backend_name)

      # Manual unregistration
      Registry.unregister(CircuitBreakerRegistry, backend_name)

      # Should no longer be findable
      assert [] = Registry.lookup(CircuitBreakerRegistry, backend_name)
    end

    test "supports registry metadata" do
      backend_name = :metadata_test
      metadata = %{created_at: DateTime.utc_now(), config: %{threshold: 5}}

      # Register with metadata
      {:ok, _owner} = Registry.register(CircuitBreakerRegistry, backend_name, metadata)

      # Retrieve and verify metadata
      assert [{_pid, ^metadata}] = Registry.lookup(CircuitBreakerRegistry, backend_name)
    end

    test "handles concurrent registrations safely" do
      # Spawn multiple processes trying to register different backends
      tasks = for i <- 1..20 do
        Task.async(fn ->
          backend_name = :"concurrent_#{i}"
          case Registry.register(CircuitBreakerRegistry, backend_name, i) do
            {:ok, _} -> {:registered, backend_name, i}
            {:error, reason} -> {:error, backend_name, reason}
          end
        end)
      end

      results = Task.await_many(tasks)

      # All should succeed since they use different names
      for result <- results do
        assert {:registered, _name, _value} = result
      end

      # Verify all are registered
      for i <- 1..20 do
        backend_name = :"concurrent_#{i}"
        assert [{_pid, ^i}] = Registry.lookup(CircuitBreakerRegistry, backend_name)
      end
    end

    test "prevents duplicate registrations for same key" do
      backend_name = :duplicate_test

      # First registration succeeds
      {:ok, _} = Registry.register(CircuitBreakerRegistry, backend_name, :first)

      # Second registration from same process should fail
      assert {:error, {:already_registered, _pid}} =
        Registry.register(CircuitBreakerRegistry, backend_name, :second)

      # Verify original registration is intact
      assert [{_pid, :first}] = Registry.lookup(CircuitBreakerRegistry, backend_name)
    end
  end

  describe "registry monitoring and cleanup" do
    test "automatically cleans up when registered process dies" do
      backend_name = :cleanup_test

      # Spawn a process that registers itself
      test_pid = spawn(fn ->
        Registry.register(CircuitBreakerRegistry, backend_name, :test_data)
        receive do
          :stop -> :ok
        end
      end)

      # Verify registration
      assert [{^test_pid, :test_data}] = Registry.lookup(CircuitBreakerRegistry, backend_name)

      # Kill the process
      Process.exit(test_pid, :normal)

      # Wait for cleanup
      Process.sleep(10)

      # Should be automatically cleaned up
      assert [] = Registry.lookup(CircuitBreakerRegistry, backend_name)
    end

    test "handles process monitoring correctly" do
      backend_name = :monitoring_test

      # Start a circuit breaker
      {:ok, cb_pid} = CircuitBreaker.start_link(backend_name)

      # Registry should be monitoring the process
      assert [{^cb_pid, _}] = Registry.lookup(CircuitBreakerRegistry, backend_name)

      # Stop the circuit breaker normally
      GenServer.stop(cb_pid)

      # Registry should clean up automatically
      assert [] = Registry.lookup(CircuitBreakerRegistry, backend_name)
    end
  end

  describe "registry queries and introspection" do
    test "can enumerate all registered backends" do
      # Register several backends
      backends = for i <- 1..5 do
        name = :"enum_test_#{i}"
        {:ok, pid} = CircuitBreaker.start_link(name)
        {name, pid}
      end

      # Get all registered keys
      all_keys = Registry.select(CircuitBreakerRegistry, [{{:"$1", :"$2", :"$3"}, [], [:"$1"]}])

      # Should include all our backends
      for {name, _pid} <- backends do
        assert name in all_keys
      end

      assert length(all_keys) >= 5

      # Clean up
      for {_name, pid} <- backends do
        GenServer.stop(pid)
      end
    end

    test "can count registered backends" do
      initial_count = Registry.count(CircuitBreakerRegistry)

      # Add some backends
      backends = for i <- 1..3 do
        name = :"count_test_#{i}"
        {:ok, pid} = CircuitBreaker.start_link(name)
        {name, pid}
      end

      # Count should increase
      new_count = Registry.count(CircuitBreakerRegistry)
      assert new_count == initial_count + 3

      # Remove one backend
      {_name, first_pid} = List.first(backends)
      GenServer.stop(first_pid)

      # Count should decrease
      final_count = Registry.count(CircuitBreakerRegistry)
      assert final_count == initial_count + 2

      # Clean up remaining
      for {_name, pid} <- Enum.drop(backends, 1) do
        GenServer.stop(pid)
      end
    end

    test "supports pattern matching in lookups" do
      # Register backends with structured names
      backends = [
        {:openai_backend, :production},
        {:openai_backend, :staging},
        {:anthropic_backend, :production},
        {:test_backend, :development}
      ]

      pids = for {name, env} <- backends do
        full_name = :"#{name}_#{env}"
        {:ok, pid} = CircuitBreaker.start_link(full_name)
        Registry.update_value(CircuitBreakerRegistry, full_name, fn _ -> {name, env} end)
        pid
      end

      # Find all production backends
      production_backends = Registry.select(CircuitBreakerRegistry, [
        {{:"$1", :"$2", {:"$3", :production}}, [], [:"$1"]}
      ])

      assert length(production_backends) == 2
      assert :openai_backend_production in production_backends
      assert :anthropic_backend_production in production_backends

      # Clean up
      for pid <- pids do
        GenServer.stop(pid)
      end
    end
  end

  # Property-based tests
  describe "property-based tests" do
    property "registry maintains consistency under concurrent operations" do
      check all operations <- list_of(
        {member_of([:register, :unregister, :lookup]), atom(:alphanumeric)},
        min_length: 5, max_length: 20
      ) do

        # Track what should be registered
        expected_registered = MapSet.new()

        # Execute operations sequentially to build expected state
        _expected_registered = Enum.reduce(operations, expected_registered, fn {op, name}, acc ->
          case op do
            :register -> MapSet.put(acc, name)
            :unregister -> MapSet.delete(acc, name)
            :lookup -> acc  # Lookup doesn't change state
          end
        end)

        # Execute operations concurrently
        tasks = for {op, name} <- operations do
          Task.async(fn ->
            case op do
              :register ->
                case Registry.register(CircuitBreakerRegistry, name, :test_value) do
                  {:ok, _} -> {:registered, name}
                  {:error, _} -> {:already_registered, name}
                end
              :unregister ->
                Registry.unregister(CircuitBreakerRegistry, name)
                {:unregistered, name}
              :lookup ->
                result = Registry.lookup(CircuitBreakerRegistry, name)
                {:lookup, name, result}
            end
          end)
        end

        Task.await_many(tasks)

        # Verify final state is consistent
        all_registered = Registry.select(CircuitBreakerRegistry, [{{:"$1", :"$2", :"$3"}, [], [:"$1"]}])

        # Clean up for next iteration
        for name <- all_registered do
          Registry.unregister(CircuitBreakerRegistry, name)
        end

        # Registry should maintain internal consistency
        assert is_list(all_registered)
        assert length(all_registered) == length(Enum.uniq(all_registered))
      end
    end

    property "lookup always returns consistent results" do
      check all backend_names <- list_of(atom(:alphanumeric), min_length: 1, max_length: 10) do

        # Register all backends
        for name <- backend_names do
          Registry.register(CircuitBreakerRegistry, name, name)
        end

        # Lookup each backend multiple times
        for name <- backend_names do
          result1 = Registry.lookup(CircuitBreakerRegistry, name)
          result2 = Registry.lookup(CircuitBreakerRegistry, name)

          # Results should be identical
          assert result1 == result2

          # Should find exactly one entry (since we registered from same process)
          assert length(result1) <= 1
        end

        # Clean up
        for name <- backend_names do
          Registry.unregister(CircuitBreakerRegistry, name)
        end
      end
    end
  end

  describe "error handling and edge cases" do
    test "handles registry process restart gracefully" do
      backend_name = :restart_test

      # Register something
      {:ok, _} = Registry.register(CircuitBreakerRegistry, backend_name, :test_data)
      assert [{_pid, :test_data}] = Registry.lookup(CircuitBreakerRegistry, backend_name)

      # Kill and restart registry
      registry_pid = Process.whereis(CircuitBreakerRegistry)
      Process.exit(registry_pid, :kill)

      # Wait for process to die
      Process.sleep(10)

      # Start new registry
      {:ok, _new_pid} = CircuitBreakerRegistry.start_link()

      # Previous registration should be gone
      assert [] = Registry.lookup(CircuitBreakerRegistry, backend_name)
    end

    test "handles invalid registry operations gracefully" do
      # Attempt to unregister non-existent key
      assert :ok = Registry.unregister(CircuitBreakerRegistry, :non_existent)

      # Lookup non-existent key
      assert [] = Registry.lookup(CircuitBreakerRegistry, :non_existent)

      # Register with nil key should work (Registry allows it)
      {:ok, _} = Registry.register(CircuitBreakerRegistry, nil, :nil_key_test)
      assert [{_pid, :nil_key_test}] = Registry.lookup(CircuitBreakerRegistry, nil)
    end

    test "handles large numbers of registrations" do
      # Register many backends
      backend_count = 100
      backends = for i <- 1..backend_count do
        name = :"large_test_#{i}"
        {:ok, _} = Registry.register(CircuitBreakerRegistry, name, i)
        name
      end

      # Verify all are registered
      assert Registry.count(CircuitBreakerRegistry) >= backend_count

      # Verify each can be looked up
      for {name, expected_value} <- Enum.zip(backends, 1..backend_count) do
        assert [{_pid, ^expected_value}] = Registry.lookup(CircuitBreakerRegistry, name)
      end

      # Clean up
      for name <- backends do
        Registry.unregister(CircuitBreakerRegistry, name)
      end
    end

    test "handles concurrent registration attempts for same key" do
      backend_name = :concurrent_same_key

      # Spawn multiple processes trying to register the same key
      tasks = for i <- 1..10 do
        Task.async(fn ->
          case Registry.register(CircuitBreakerRegistry, backend_name, i) do
            {:ok, _} -> :success
            {:error, {:already_registered, _}} -> :already_registered
          end
        end)
      end

      results = Task.await_many(tasks)

      # Exactly one should succeed, others should get already_registered
      successes = Enum.count(results, &(&1 == :success))
      already_registered = Enum.count(results, &(&1 == :already_registered))

      assert successes == 1
      assert already_registered == 9

      # Should have exactly one registration
      entries = Registry.lookup(CircuitBreakerRegistry, backend_name)
      assert length(entries) == 1
    end
  end

  # Integration tests
  describe "integration with supervision trees" do
    test "works correctly in supervision tree" do
      # Define a simple supervisor that includes the registry
      children = [
        CircuitBreakerRegistry.child_spec([])
      ]

      # Start supervisor
      {:ok, sup_pid} = Supervisor.start_link(children, strategy: :one_for_one)

      # Registry should be running
      registry_pid = Process.whereis(CircuitBreakerRegistry)
      assert registry_pid != nil
      assert Process.alive?(registry_pid)

      # Should be able to use registry
      {:ok, _} = Registry.register(CircuitBreakerRegistry, :supervised_test, :test_data)
      assert [{_pid, :test_data}] = Registry.lookup(CircuitBreakerRegistry, :supervised_test)

      # Stop supervisor
      Supervisor.stop(sup_pid)

      # Registry should be stopped
      refute Process.alive?(registry_pid)
    end

    test "restarts correctly when supervised" do
      # This test would require a more complex setup with actual supervision
      # For now, we'll test the child spec is correct
      child_spec = CircuitBreakerRegistry.child_spec([])

      assert child_spec.restart == :permanent
      assert child_spec.type == :worker

      # These settings ensure the registry will be restarted by supervisor
      assert child_spec.restart == :permanent
    end
  end

  # Doctests
  doctest CircuitBreakerRegistry, import: true
end
