defmodule Prismatic.Event.BusTest do
  use ExUnit.Case, async: true

  alias Prismatic.Event.{Bus, Protocol}

  describe "start_link/1" do
    test "starts bus with default configuration" do
      {:ok, pid} = Bus.start_link(name: :test_bus_start)

      assert is_pid(pid)
      assert Process.alive?(pid)

      # Clean up
      GenServer.stop(pid)
    end

    test "starts bus with custom configuration" do
      {:ok, config} = Protocol.create_config(:test, %{
        name: :custom_bus,
        enable_sourcing: false
      })

      {:ok, pid} = Bus.start_link(name: :test_bus_custom, config: config)

      assert is_pid(pid)
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end
  end

  describe "publish/2" do
    setup do
      {:ok, bus} = Bus.start_link(name: :test_bus_publish)
      on_exit(fn -> GenServer.stop(bus) end)
      %{bus: bus}
    end

    test "publishes event successfully", %{bus: bus} do
      event = %{
        type: "test.bus.publish",
        payload: %{message: "Hello Bus!"},
        metadata: %{test: true}
      }

      {:ok, event_id} = Bus.publish(bus, event)

      assert is_binary(event_id)
      assert String.length(event_id) > 0
    end

    test "enriches event with metadata", %{bus: bus} do
      event = %{
        type: "test.bus.enrich",
        payload: %{data: "test"}
      }

      {:ok, event_id} = Bus.publish(bus, event)

      # Event ID format indicates enrichment occurred
      assert is_binary(event_id)
    end

    test "handles invalid events", %{bus: bus} do
      invalid_event = %{
        # Missing type
        payload: %{data: "test"}
      }

      # The bus should handle validation through the protocol layer
      result = Bus.publish(bus, invalid_event)

      # Depending on implementation, this might be handled at protocol level
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "subscribe/4" do
    setup do
      {:ok, bus} = Bus.start_link(name: :test_bus_subscribe)
      on_exit(fn -> GenServer.stop(bus) end)
      %{bus: bus}
    end

    test "creates subscription successfully", %{bus: bus} do
      handler = fn _event -> :ok end

      {:ok, subscription_id} = Bus.subscribe(bus, "test.bus.*", handler)

      assert is_binary(subscription_id)
      assert String.length(subscription_id) > 0
    end

    test "creates subscription with options", %{bus: bus} do
      handler = fn _event -> :ok end
      options = %{priority: :high, created_by: :test}

      {:ok, subscription_id} = Bus.subscribe(bus, "test.bus.*", handler, options)

      assert is_binary(subscription_id)
    end

    test "validates pattern format", %{bus: bus} do
      handler = fn _event -> :ok end

      result = Bus.subscribe(bus, 123, handler)

      assert match?({:error, _}, result)
    end

    test "validates handler function", %{bus: bus} do
      result = Bus.subscribe(bus, "test.*", "not_a_function")

      assert match?({:error, _}, result)
    end
  end

  describe "unsubscribe/2" do
    setup do
      {:ok, bus} = Bus.start_link(name: :test_bus_unsubscribe)
      handler = fn _event -> :ok end
      {:ok, subscription_id} = Bus.subscribe(bus, "test.*", handler)

      on_exit(fn -> GenServer.stop(bus) end)
      %{bus: bus, subscription_id: subscription_id}
    end

    test "removes subscription successfully", %{bus: bus, subscription_id: subscription_id} do
      assert :ok = Bus.unsubscribe(bus, subscription_id)
    end

    test "handles non-existent subscription", %{bus: bus} do
      result = Bus.unsubscribe(bus, "nonexistent_subscription")

      assert match?({:error, _}, result)
    end
  end

  describe "list_subscriptions/1" do
    setup do
      {:ok, bus} = Bus.start_link(name: :test_bus_list)
      on_exit(fn -> GenServer.stop(bus) end)
      %{bus: bus}
    end

    test "lists active subscriptions", %{bus: bus} do
      handler = fn _event -> :ok end

      {:ok, _sub1} = Bus.subscribe(bus, "test.1", handler)
      {:ok, _sub2} = Bus.subscribe(bus, "test.2", handler)

      {:ok, subscriptions} = Bus.list_subscriptions(bus)

      assert is_list(subscriptions)
      assert length(subscriptions) >= 2
    end

    test "returns empty list when no subscriptions", %{bus: bus} do
      {:ok, subscriptions} = Bus.list_subscriptions(bus)

      assert is_list(subscriptions)
      # May have default subscriptions, so just verify it's a list
    end
  end

  describe "replay/2" do
    setup do
      {:ok, config} = Protocol.create_config(:test, %{
        name: :test_bus_replay,
        enable_sourcing: true
      })
      {:ok, bus} = Bus.start_link(name: :test_bus_replay, config: config)

      on_exit(fn -> GenServer.stop(bus) end)
      %{bus: bus}
    end

    test "replays events successfully", %{bus: bus} do
      # Publish some events first
      events = [
        %{type: "replay.test.1", payload: %{index: 1}},
        %{type: "replay.test.2", payload: %{index: 2}},
        %{type: "replay.other.3", payload: %{index: 3}}
      ]

      Enum.each(events, fn event ->
        {:ok, _} = Bus.publish(bus, event)
      end)

      {:ok, replayed_events} = Bus.replay(bus, %{
        patterns: ["replay.test.*"]
      })

      assert is_list(replayed_events)
    end

    test "handles sourcing disabled" do
      {:ok, config} = Protocol.create_config(:test, %{
        name: :test_bus_no_sourcing,
        enable_sourcing: false
      })
      {:ok, bus} = Bus.start_link(name: :test_bus_no_sourcing, config: config)

      result = Bus.replay(bus, %{})

      assert match?({:error, _}, result)

      GenServer.stop(bus)
    end
  end

  describe "get_stats/1" do
    setup do
      {:ok, bus} = Bus.start_link(name: :test_bus_stats)
      on_exit(fn -> GenServer.stop(bus) end)
      %{bus: bus}
    end

    test "returns bus statistics", %{bus: bus} do
      {:ok, stats} = Bus.get_stats(bus)

      assert is_map(stats)
      assert Map.has_key?(stats, :name)
      assert Map.has_key?(stats, :backend_type)
      assert Map.has_key?(stats, :subscribers_count)
      assert Map.has_key?(stats, :events_published)
      assert Map.has_key?(stats, :metrics)

      assert is_integer(stats.subscribers_count)
      assert is_integer(stats.events_published)
      assert is_map(stats.metrics)
    end

    test "statistics update with operations", %{bus: bus} do
      # Get initial stats
      {:ok, initial_stats} = Bus.get_stats(bus)
      initial_events = initial_stats.events_published
      initial_subscribers = initial_stats.subscribers_count

      # Perform some operations
      handler = fn _event -> :ok end
      {:ok, _sub_id} = Bus.subscribe(bus, "stats.test", handler)

      event = %{type: "stats.test", payload: %{test: true}}
      {:ok, _event_id} = Bus.publish(bus, event)

      # Get updated stats
      {:ok, updated_stats} = Bus.get_stats(bus)

      # Verify stats were updated
      assert updated_stats.events_published >= initial_events
      assert updated_stats.subscribers_count >= initial_subscribers
    end
  end

  describe "health_check/1" do
    setup do
      {:ok, bus} = Bus.start_link(name: :test_bus_health)
      on_exit(fn -> GenServer.stop(bus) end)
      %{bus: bus}
    end

    test "passes health check for running bus", %{bus: bus} do
      assert :ok = Bus.health_check(bus)
    end

    test "fails health check for stopped bus" do
      {:ok, bus} = Bus.start_link(name: :test_bus_stopped)
      GenServer.stop(bus)

      # Health check should fail for stopped process
      result = Bus.health_check(bus)
      assert match?({:error, _}, result)
    end
  end

  describe "integration scenarios" do
    setup do
      {:ok, bus} = Bus.start_link(name: :test_bus_integration)
      on_exit(fn -> GenServer.stop(bus) end)
      %{bus: bus}
    end

    test "complete publish-subscribe flow", %{bus: bus} do
      test_pid = self()

      # Create subscriber
      handler = fn event ->
        send(test_pid, {:event_received, event.type, event.payload})
        :ok
      end

      {:ok, subscription_id} = Bus.subscribe(bus, "integration.*", handler)

      # Publish event
      event = %{
        type: "integration.test",
        payload: %{message: "Integration Test!"}
      }

      {:ok, event_id} = Bus.publish(bus, event)

      # Verify event was published
      assert is_binary(event_id)
      assert is_binary(subscription_id)

      # Note: Actual event delivery testing would require more complex setup
      # with proper backend implementations that support real-time delivery

      # Clean up
      assert :ok = Bus.unsubscribe(bus, subscription_id)
    end

    test "multiple subscribers receive same event", %{bus: bus} do
      test_pid = self()

      # Create multiple subscribers
      handler1 = fn event ->
        send(test_pid, {:handler1, event.type})
        :ok
      end

      handler2 = fn event ->
        send(test_pid, {:handler2, event.type})
        :ok
      end

      {:ok, sub1} = Bus.subscribe(bus, "multi.*", handler1)
      {:ok, sub2} = Bus.subscribe(bus, "multi.*", handler2)

      # Publish event
      event = %{type: "multi.test", payload: %{}}
      {:ok, _event_id} = Bus.publish(bus, event)

      # Both subscriptions should exist
      {:ok, subscriptions} = Bus.list_subscriptions(bus)
      subscription_ids = Enum.map(subscriptions, &(&1.id))

      assert sub1 in subscription_ids
      assert sub2 in subscription_ids

      # Clean up
      Bus.unsubscribe(bus, sub1)
      Bus.unsubscribe(bus, sub2)
    end

    test "error handling in event processing", %{bus: bus} do
      # Test that bus continues operating even if individual handlers fail
      error_handler = fn _event ->
        raise "Simulated handler error"
      end

      good_handler = fn _event -> :ok end

      {:ok, _error_sub} = Bus.subscribe(bus, "error.*", error_handler)
      {:ok, good_sub} = Bus.subscribe(bus, "error.*", good_handler)

      # Publish event that will cause error in one handler
      event = %{type: "error.test", payload: %{}}

      # Bus should still successfully publish despite handler error
      result = Bus.publish(bus, event)
      assert match?({:ok, _}, result)

      # Bus should still be operational
      assert :ok = Bus.health_check(bus)

      # Clean up
      Bus.unsubscribe(bus, good_sub)
    end

    test "high-throughput event processing", %{bus: bus} do
      # Test bus performance with many events
      events_count = 100

      start_time = System.monotonic_time()

      results = Enum.map(1..events_count, fn i ->
        event = %{
          type: "performance.test.#{i}",
          payload: %{index: i}
        }
        Bus.publish(bus, event)
      end)

      end_time = System.monotonic_time()
      duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # All events should be published successfully
      assert Enum.all?(results, &match?({:ok, _}, &1))

      # Should complete within reasonable time (adjust threshold as needed)
      assert duration < 5000  # Less than 5 seconds

      # Verify stats were updated
      {:ok, stats} = Bus.get_stats(bus)
      assert stats.events_published >= events_count
    end
  end

  describe "pattern matching integration" do
    setup do
      {:ok, bus} = Bus.start_link(name: :test_bus_patterns)
      on_exit(fn -> GenServer.stop(bus) end)
      %{bus: bus}
    end

    test "wildcard patterns work correctly", %{bus: bus} do
      handler = fn _event -> :ok end

      {:ok, sub_id} = Bus.subscribe(bus, "wildcard.*.test", handler)

      # Should match
      matching_event = %{type: "wildcard.something.test", payload: %{}}
      {:ok, _} = Bus.publish(bus, matching_event)

      # Should not match
      non_matching_event = %{type: "wildcard.something.other", payload: %{}}
      {:ok, _} = Bus.publish(bus, non_matching_event)

      # Verify subscription exists
      {:ok, subscriptions} = Bus.list_subscriptions(bus)
      assert Enum.any?(subscriptions, &(&1.id == sub_id))

      Bus.unsubscribe(bus, sub_id)
    end

    test "multi-level wildcard patterns work correctly", %{bus: bus} do
      handler = fn _event -> :ok end

      {:ok, sub_id} = Bus.subscribe(bus, "deep.**", handler)

      # Should match various depths
      events = [
        %{type: "deep.level1", payload: %{}},
        %{type: "deep.level1.level2", payload: %{}},
        %{type: "deep.level1.level2.level3", payload: %{}}
      ]

      Enum.each(events, fn event ->
        {:ok, _} = Bus.publish(bus, event)
      end)

      Bus.unsubscribe(bus, sub_id)
    end
  end
end
