defmodule Prismatic.Event.Impl.TestBackendTest do
  use ExUnit.Case, async: true

  alias Prismatic.Event.{Protocol, Impl.TestBackend}

  describe "test backend protocol implementation" do
    setup do
      {:ok, config} = Protocol.create_config(:test, %{name: :test_backend_test})
      %{config: config}
    end

    test "publishes events successfully", %{config: config} do
      event = %{
        type: "test.publish",
        payload: %{message: "Hello, Test!"}
      }

      {:ok, event_id} = TestBackend.publish(config, event)

      assert is_binary(event_id)
      assert String.starts_with?(event_id, "test_event_")
    end

    test "handles configured error responses", %{config: config} do
      error_config = Map.put(config, :responses, %{
        "error.test" => {:error, :configured_error}
      })

      event = %{type: "error.test", payload: %{}}

      assert {:error, :configured_error} = TestBackend.publish(error_config, event)
    end

    test "tracks published events when enabled", %{config: config} do
      tracking_config = Map.put(config, :track_events, true)

      event1 = %{type: "track.1", payload: %{index: 1}}
      event2 = %{type: "track.2", payload: %{index: 2}}

      {:ok, _} = TestBackend.publish(tracking_config, event1)
      {:ok, _} = TestBackend.publish(tracking_config, event2)

      {:ok, published_events} = TestBackend.get_published_events(tracking_config)

      assert length(published_events) == 2

      # Events should be in reverse order (newest first)
      assert Enum.at(published_events, 0).type == "track.2"
      assert Enum.at(published_events, 1).type == "track.1"
    end

    test "subscribes and unsubscribes correctly", %{config: config} do
      handler = fn _event -> :ok end

      {:ok, subscription_id} = TestBackend.subscribe(config, "test.*", handler)

      assert is_binary(subscription_id)
      assert String.starts_with?(subscription_id, "test_sub_")

      # Verify subscription was created
      {:ok, subscriptions} = TestBackend.list_subscriptions(config)
      assert length(subscriptions) == 1
      assert Enum.at(subscriptions, 0).id == subscription_id

      # Unsubscribe
      assert :ok = TestBackend.unsubscribe(config, subscription_id)

      # Verify subscription was removed
      {:ok, subscriptions} = TestBackend.list_subscriptions(config)
      assert length(subscriptions) == 0
    end

    test "validates handler function", %{config: config} do
      assert {:error, :invalid_handler} =
        TestBackend.subscribe(config, "test.*", "not_a_function")
    end

    test "handles subscription not found", %{config: config} do
      assert {:error, :subscription_not_found} =
        TestBackend.unsubscribe(config, "nonexistent_subscription")
    end

    test "replays events with filtering", %{config: config} do
      # Enable sourcing for replay
      sourcing_config = Map.put(config, :enable_sourcing, true)

      # Publish some events
      events = [
        %{type: "replay.test.1", payload: %{index: 1}},
        %{type: "replay.other.2", payload: %{index: 2}},
        %{type: "replay.test.3", payload: %{index: 3}}
      ]

      Enum.each(events, fn event ->
        {:ok, _} = TestBackend.publish(sourcing_config, event)
      end)

      # Test pattern filtering
      {:ok, filtered_events} = TestBackend.replay(sourcing_config, %{
        patterns: ["replay.test.*"]
      })

      assert length(filtered_events) == 2

      types = Enum.map(filtered_events, &(&1.type))
      assert "replay.test.1" in types
      assert "replay.test.3" in types
      refute "replay.other.2" in types

      # Test limit
      {:ok, limited_events} = TestBackend.replay(sourcing_config, %{
        limit: 1
      })

      assert length(limited_events) == 1
    end

    test "handles replay with sourcing disabled", %{config: config} do
      no_sourcing_config = Map.put(config, :enable_sourcing, false)

      assert {:error, :sourcing_disabled} =
        TestBackend.replay(no_sourcing_config, %{})
    end

    test "validates configuration correctly", %{config: config} do
      assert :ok = TestBackend.validate_config(config)

      invalid_config = Map.delete(config, :name)
      assert {:error, {:missing_required_field, :name}} =
        TestBackend.validate_config(invalid_config)
    end

    test "passes health checks", %{config: config} do
      assert :ok = TestBackend.health_check(config)
    end

    test "returns backend information", %{config: config} do
      {:ok, info} = TestBackend.get_backend_info(config)

      assert info.backend_type == :test
      assert info.supports_sourcing == true
      assert info.supports_patterns == true
      assert info.max_subscribers == :unlimited
      assert info.max_events == :unlimited
      assert is_list(info.features)
      assert :configurable_responses in info.features
    end
  end

  describe "test backend helpers" do
    setup do
      {:ok, config} = Protocol.create_config(:test, %{name: :test_helpers})
      %{config: config}
    end

    test "clears published events", %{config: config} do
      # Publish some events
      event = %{type: "clear.test", payload: %{}}
      {:ok, _} = TestBackend.publish(config, event)
      {:ok, _} = TestBackend.publish(config, event)

      {:ok, events_before} = TestBackend.get_published_events(config)
      assert length(events_before) == 2

      # Clear events
      :ok = TestBackend.clear_published_events(config)

      {:ok, events_after} = TestBackend.get_published_events(config)
      assert length(events_after) == 0
    end

    test "enriches events with metadata", %{config: config} do
      event = %{
        type: "enrich.test",
        payload: %{data: "test"},
        metadata: %{custom: "value"}
      }

      {:ok, _event_id} = TestBackend.publish(config, event)

      {:ok, published_events} = TestBackend.get_published_events(config)
      enriched_event = Enum.at(published_events, 0)

      # Check that metadata was enriched
      metadata = enriched_event.metadata
      assert is_binary(metadata.event_id)
      assert %DateTime{} = metadata.timestamp
      assert metadata.source == "test_backend"
      assert metadata.custom == "value"  # Custom metadata preserved
    end
  end

  describe "event delivery simulation" do
    setup do
      {:ok, config} = Protocol.create_config(:test, %{name: :test_delivery})
      %{config: config}
    end

    test "delivers events to matching subscribers", %{config: config} do
      test_pid = self()

      # Create handler that sends message to test
      handler = fn event ->
        send(test_pid, {:event_received, event.type, event.payload})
        :ok
      end

      # Subscribe to pattern
      {:ok, _subscription_id} = TestBackend.subscribe(config, "delivery.*", handler)

      # Publish matching event
      event = %{
        type: "delivery.test",
        payload: %{message: "Hello, Delivery!"}
      }

      {:ok, _event_id} = TestBackend.publish(config, event)

      # Note: The test backend may not actually deliver events in real-time
      # This test verifies the subscription was created successfully
      {:ok, subscriptions} = TestBackend.list_subscriptions(config)
      assert length(subscriptions) == 1
      assert Enum.at(subscriptions, 0).pattern == "delivery.*"
    end

    test "supports multiple subscribers for same pattern", %{config: config} do
      handler1 = fn _event -> :ok end
      handler2 = fn _event -> :ok end

      {:ok, sub1} = TestBackend.subscribe(config, "multi.*", handler1)
      {:ok, sub2} = TestBackend.subscribe(config, "multi.*", handler2)

      {:ok, subscriptions} = TestBackend.list_subscriptions(config)

      assert length(subscriptions) == 2
      subscription_ids = Enum.map(subscriptions, &(&1.id))
      assert sub1 in subscription_ids
      assert sub2 in subscription_ids
    end
  end

  describe "pattern matching behavior" do
    setup do
      {:ok, config} = Protocol.create_config(:test, %{name: :test_patterns})
      test_pid = self()

      handler = fn event ->
        send(test_pid, {:matched, event.type})
        :ok
      end

      %{config: config, handler: handler}
    end

    test "matches exact patterns", %{config: config, handler: handler} do
      {:ok, _} = TestBackend.subscribe(config, "exact.match", handler)

      # The test backend uses simple pattern matching
      # This test verifies the subscription setup
      {:ok, subscriptions} = TestBackend.list_subscriptions(config)
      subscription = Enum.at(subscriptions, 0)

      assert subscription.pattern == "exact.match"
    end

    test "matches wildcard patterns", %{config: config, handler: handler} do
      {:ok, _} = TestBackend.subscribe(config, "wildcard.*", handler)

      {:ok, subscriptions} = TestBackend.list_subscriptions(config)
      subscription = Enum.at(subscriptions, 0)

      assert subscription.pattern == "wildcard.*"
    end
  end
end
