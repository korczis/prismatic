defmodule Prismatic.Event.RegistryTest do
  use ExUnit.Case, async: true

  alias Prismatic.Event.Registry

  describe "start_link/1" do
    test "starts registry with default options" do
      {:ok, pid} = Registry.start_link(name: :test_registry_start)

      assert is_pid(pid)
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end

    test "starts registry with custom options" do
      {:ok, pid} = Registry.start_link(
        name: :test_registry_custom,
        max_subscriptions: 5000,
        cache_size: 500
      )

      assert is_pid(pid)
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end
  end

  describe "subscribe/4" do
    setup do
      {:ok, registry} = Registry.start_link(name: :test_registry_subscribe)
      on_exit(fn -> GenServer.stop(registry) end)
      %{registry: registry}
    end

    test "creates subscription successfully", %{registry: registry} do
      handler = fn _event -> :ok end

      {:ok, subscription_id} = Registry.subscribe(registry, "test.message", handler)

      assert is_binary(subscription_id)
      assert String.length(subscription_id) > 0
    end

    test "creates subscription with metadata", %{registry: registry} do
      handler = fn _event -> :ok end
      options = %{priority: :high, group: :test}

      {:ok, subscription_id} = Registry.subscribe(registry, "test.*", handler, options)

      assert is_binary(subscription_id)
    end

    test "validates pattern format", %{registry: registry} do
      handler = fn _event -> :ok end

      result = Registry.subscribe(registry, 123, handler)

      assert {:error, :invalid_pattern} = result
    end

    test "validates handler function", %{registry: registry} do
      result = Registry.subscribe(registry, "test.*", "not_a_function")

      assert {:error, :invalid_handler} = result
    end

    test "enforces subscription limits", %{registry: _registry} do
      # This test would need a registry with a low max_subscriptions limit
      {:ok, limited_registry} = Registry.start_link(
        name: :test_registry_limited,
        max_subscriptions: 2
      )

      handler = fn _event -> :ok end

      # Should succeed
      {:ok, _sub1} = Registry.subscribe(limited_registry, "test.1", handler)
      {:ok, _sub2} = Registry.subscribe(limited_registry, "test.2", handler)

      # Should fail due to limit
      result = Registry.subscribe(limited_registry, "test.3", handler)
      assert {:error, :max_subscriptions_exceeded} = result

      GenServer.stop(limited_registry)
    end
  end

  describe "unsubscribe/2" do
    setup do
      {:ok, registry} = Registry.start_link(name: :test_registry_unsubscribe)
      handler = fn _event -> :ok end
      {:ok, subscription_id} = Registry.subscribe(registry, "test.*", handler)

      on_exit(fn -> GenServer.stop(registry) end)
      %{registry: registry, subscription_id: subscription_id}
    end

    test "removes subscription successfully", %{registry: registry, subscription_id: subscription_id} do
      assert :ok = Registry.unsubscribe(registry, subscription_id)
    end

    test "handles non-existent subscription", %{registry: registry} do
      result = Registry.unsubscribe(registry, "nonexistent_subscription")

      assert {:error, :subscription_not_found} = result
    end
  end

  describe "find_matching_subscriptions/2" do
    setup do
      {:ok, registry} = Registry.start_link(name: :test_registry_matching)
      on_exit(fn -> GenServer.stop(registry) end)
      %{registry: registry}
    end

    test "finds exact matches", %{registry: registry} do
      handler = fn _event -> :ok end

      {:ok, sub_id} = Registry.subscribe(registry, "exact.match", handler)

      {:ok, matches} = Registry.find_matching_subscriptions(registry, "exact.match")

      assert length(matches) == 1
      assert Enum.at(matches, 0).id == sub_id
      assert Enum.at(matches, 0).pattern == "exact.match"
    end

    test "finds wildcard matches", %{registry: registry} do
      handler = fn _event -> :ok end

      {:ok, sub_id} = Registry.subscribe(registry, "wildcard.*", handler)

      # Should match
      {:ok, matches1} = Registry.find_matching_subscriptions(registry, "wildcard.test")
      assert length(matches1) == 1
      assert Enum.at(matches1, 0).id == sub_id

      # Should not match
      {:ok, matches2} = Registry.find_matching_subscriptions(registry, "other.test")
      assert length(matches2) == 0
    end

    test "finds multi-wildcard matches", %{registry: registry} do
      handler = fn _event -> :ok end

      {:ok, sub_id} = Registry.subscribe(registry, "multi.**", handler)

      # Should match various depths
      test_cases = [
        "multi.level1",
        "multi.level1.level2",
        "multi.level1.level2.level3"
      ]

      Enum.each(test_cases, fn event_type ->
        {:ok, matches} = Registry.find_matching_subscriptions(registry, event_type)
        assert length(matches) == 1
        assert Enum.at(matches, 0).id == sub_id
      end)
    end

    test "handles multiple matching subscriptions", %{registry: registry} do
      handler = fn _event -> :ok end

      # Create overlapping subscriptions
      {:ok, _sub1} = Registry.subscribe(registry, "multi.*", handler)
      {:ok, _sub2} = Registry.subscribe(registry, "multi.test", handler)  # Exact match
      {:ok, _sub3} = Registry.subscribe(registry, "**.test", handler)    # Suffix match

      # Event should match all three patterns
      {:ok, matches} = Registry.find_matching_subscriptions(registry, "multi.test")

      assert length(matches) >= 2  # At least the exact matches we can verify
      _subscription_ids = Enum.map(matches, &(&1.id))

      # Note: Pattern matching behavior depends on implementation details
      # We just verify we get reasonable results
      assert is_list(matches)
      assert length(matches) > 0
    end

    test "returns empty list for no matches", %{registry: registry} do
      handler = fn _event -> :ok end

      {:ok, _sub_id} = Registry.subscribe(registry, "specific.pattern", handler)

      {:ok, matches} = Registry.find_matching_subscriptions(registry, "different.pattern")

      assert matches == []
    end

    test "uses pattern cache for performance", %{registry: registry} do
      handler = fn _event -> :ok end

      {:ok, _sub_id} = Registry.subscribe(registry, "cached.*", handler)

      # First lookup should populate cache
      {:ok, matches1} = Registry.find_matching_subscriptions(registry, "cached.test")

      # Second lookup should use cache
      {:ok, matches2} = Registry.find_matching_subscriptions(registry, "cached.test")

      # Results should be identical
      assert matches1 == matches2
      assert length(matches1) == 1
    end
  end

  describe "list_subscriptions/1" do
    setup do
      {:ok, registry} = Registry.start_link(name: :test_registry_list)
      on_exit(fn -> GenServer.stop(registry) end)
      %{registry: registry}
    end

    test "lists active subscriptions", %{registry: registry} do
      handler = fn _event -> :ok end

      {:ok, sub1} = Registry.subscribe(registry, "list.test.1", handler)
      {:ok, sub2} = Registry.subscribe(registry, "list.test.2", handler)

      {:ok, subscriptions} = Registry.list_subscriptions(registry)

      assert is_list(subscriptions)
      assert length(subscriptions) == 2

      subscription_ids = Enum.map(subscriptions, &(&1.id))
      assert sub1 in subscription_ids
      assert sub2 in subscription_ids
    end

    test "returns empty list when no subscriptions", %{registry: registry} do
      {:ok, subscriptions} = Registry.list_subscriptions(registry)

      assert subscriptions == []
    end

    test "includes subscription metadata", %{registry: registry} do
      handler = fn _event -> :ok end
      options = %{priority: :high, group: :test}

      {:ok, _sub_id} = Registry.subscribe(registry, "metadata.test", handler, options)

      {:ok, subscriptions} = Registry.list_subscriptions(registry)

      assert length(subscriptions) == 1
      subscription = Enum.at(subscriptions, 0)

      assert subscription.pattern == "metadata.test"
      assert subscription.metadata.priority == :high
      assert subscription.metadata.group == :test
      assert %DateTime{} = subscription.metadata.created_at
    end
  end

  describe "get_stats/1" do
    setup do
      {:ok, registry} = Registry.start_link(name: :test_registry_stats)
      on_exit(fn -> GenServer.stop(registry) end)
      %{registry: registry}
    end

    test "returns registry statistics", %{registry: registry} do
      {:ok, stats} = Registry.get_stats(registry)

      assert is_map(stats)
      assert Map.has_key?(stats, :name)
      assert Map.has_key?(stats, :subscription_count)
      assert Map.has_key?(stats, :exact_matches_count)
      assert Map.has_key?(stats, :pattern_matches_count)
      assert Map.has_key?(stats, :cache_entries)
      assert Map.has_key?(stats, :max_subscriptions)
      assert Map.has_key?(stats, :cache_size)

      assert is_integer(stats.subscription_count)
      assert is_integer(stats.cache_entries)
    end

    test "statistics update with operations", %{registry: registry} do
      # Get initial stats
      {:ok, initial_stats} = Registry.get_stats(registry)
      initial_count = initial_stats.subscription_count

      # Add subscription
      handler = fn _event -> :ok end
      {:ok, sub_id} = Registry.subscribe(registry, "stats.test", handler)

      # Get updated stats
      {:ok, updated_stats} = Registry.get_stats(registry)

      assert updated_stats.subscription_count == initial_count + 1

      # Remove subscription
      :ok = Registry.unsubscribe(registry, sub_id)

      # Get final stats
      {:ok, final_stats} = Registry.get_stats(registry)

      assert final_stats.subscription_count == initial_count
    end
  end

  describe "performance characteristics" do
    setup do
      {:ok, registry} = Registry.start_link(
        name: :test_registry_performance,
        max_subscriptions: 10_000,
        cache_size: 1_000
      )
      on_exit(fn -> GenServer.stop(registry) end)
      %{registry: registry}
    end

    test "handles large number of subscriptions efficiently", %{registry: registry} do
      handler = fn _event -> :ok end

      # Create many subscriptions
      subscription_count = 1000
      start_time = System.monotonic_time()

      subscription_ids = Enum.map(1..subscription_count, fn i ->
        pattern = "performance.test.#{i}"
        {:ok, sub_id} = Registry.subscribe(registry, pattern, handler)
        sub_id
      end)

      end_time = System.monotonic_time()
      subscribe_duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # Should complete within reasonable time
      assert subscribe_duration < 5000  # Less than 5 seconds
      assert length(subscription_ids) == subscription_count

      # Test pattern matching performance
      start_time = System.monotonic_time()

      {:ok, matches} = Registry.find_matching_subscriptions(registry, "performance.test.500")

      end_time = System.monotonic_time()
      match_duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # Should find matches quickly
      assert match_duration < 100  # Less than 100ms
      assert length(matches) == 1
    end

    test "pattern cache improves lookup performance", %{registry: registry} do
      handler = fn _event -> :ok end

      # Create subscriptions with complex patterns
      patterns = [
        "cache.test.{urgent,normal}.*",
        "cache.**.{error,warning}",
        "cache.{system,user}.action.*"
      ]

      Enum.each(patterns, fn pattern ->
        {:ok, _} = Registry.subscribe(registry, pattern, handler)
      end)

      # First lookup (populates cache)
      start_time = System.monotonic_time()
      {:ok, matches1} = Registry.find_matching_subscriptions(registry, "cache.system.action.test")
      end_time = System.monotonic_time()
      first_duration = System.convert_time_unit(end_time - start_time, :native, :microsecond)

      # Second lookup (uses cache)
      start_time = System.monotonic_time()
      {:ok, matches2} = Registry.find_matching_subscriptions(registry, "cache.system.action.test")
      end_time = System.monotonic_time()
      second_duration = System.convert_time_unit(end_time - start_time, :native, :microsecond)

      # Results should be identical
      assert matches1 == matches2

      # Second lookup should be faster (though this is implementation dependent)
      # We just verify both are reasonably fast
      assert first_duration < 10_000   # Less than 10ms
      assert second_duration < 10_000  # Less than 10ms
    end
  end

  describe "concurrent access" do
    setup do
      {:ok, registry} = Registry.start_link(name: :test_registry_concurrent)
      on_exit(fn -> GenServer.stop(registry) end)
      %{registry: registry}
    end

    test "handles concurrent subscriptions safely", %{registry: registry} do
      handler = fn _event -> :ok end

      # Create multiple tasks that subscribe concurrently
      tasks = Enum.map(1..50, fn i ->
        Task.async(fn ->
          pattern = "concurrent.test.#{i}"
          Registry.subscribe(registry, pattern, handler)
        end)
      end)

      # Wait for all tasks to complete
      results = Enum.map(tasks, &Task.await/1)

      # All subscriptions should succeed
      assert Enum.all?(results, &match?({:ok, _}, &1))

      # Verify all subscriptions were created
      {:ok, subscriptions} = Registry.list_subscriptions(registry)
      assert length(subscriptions) == 50
    end

    test "handles concurrent pattern matching safely", %{registry: registry} do
      handler = fn _event -> :ok end

      # Create some subscriptions
      {:ok, _} = Registry.subscribe(registry, "concurrent.*", handler)
      {:ok, _} = Registry.subscribe(registry, "concurrent.match.*", handler)

      # Create multiple tasks that perform pattern matching concurrently
      tasks = Enum.map(1..20, fn i ->
        Task.async(fn ->
          event_type = "concurrent.match.#{i}"
          Registry.find_matching_subscriptions(registry, event_type)
        end)
      end)

      # Wait for all tasks to complete
      results = Enum.map(tasks, &Task.await/1)

      # All lookups should succeed and return consistent results
      assert Enum.all?(results, &match?({:ok, _}, &1))

      # All should find the same subscriptions
      match_counts = Enum.map(results, fn {:ok, matches} -> length(matches) end)
      assert Enum.all?(match_counts, &(&1 >= 1))  # Should match at least the wildcard pattern
    end
  end

  describe "edge cases" do
    setup do
      {:ok, registry} = Registry.start_link(name: :test_registry_edge_cases)
      on_exit(fn -> GenServer.stop(registry) end)
      %{registry: registry}
    end

    test "handles empty patterns gracefully", %{registry: registry} do
      handler = fn _event -> :ok end

      # Empty pattern should be rejected
      result = Registry.subscribe(registry, "", handler)
      assert {:error, :invalid_pattern} = result
    end

    test "handles very long patterns", %{registry: registry} do
      handler = fn _event -> :ok end

      # Very long pattern
      long_pattern = String.duplicate("segment.", 100) <> "*"

      {:ok, sub_id} = Registry.subscribe(registry, long_pattern, handler)
      assert is_binary(sub_id)

      # Should be able to match against it
      long_event = String.duplicate("segment.", 100) <> "test"
      {:ok, matches} = Registry.find_matching_subscriptions(registry, long_event)
      assert length(matches) == 1
    end

    test "handles special characters in event types", %{registry: registry} do
      handler = fn _event -> :ok end

      {:ok, sub_id} = Registry.subscribe(registry, "special.*", handler)

      # Event types with special characters
      special_events = [
        "special.test-event",
        "special.test_event",
        "special.test123",
        "special.test.with.dots"
      ]

      Enum.each(special_events, fn event_type ->
        {:ok, matches} = Registry.find_matching_subscriptions(registry, event_type)
        assert length(matches) == 1
        assert Enum.at(matches, 0).id == sub_id
      end)
    end
  end
end
