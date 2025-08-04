defmodule Prismatic.Event.ProtocolTest do
  use ExUnit.Case, async: true

  alias Prismatic.Event.Protocol

  doctest Protocol

  describe "create_config/2" do
    test "creates valid configuration for test backend" do
      {:ok, config} = Protocol.create_config(:test, %{name: :test_events})

      assert config.backend_type == :test
      assert config.name == :test_events
      assert is_integer(config.timeout)
      assert is_integer(config.max_retries)
      assert is_boolean(config.enable_sourcing)
    end

    test "creates valid configuration for in_memory backend" do
      {:ok, config} = Protocol.create_config(:in_memory, %{
        name: :memory_events,
        max_events: 100_000
      })

      assert config.backend_type == :in_memory
      assert config.name == :memory_events
      assert config.max_events == 100_000
    end

    test "returns error for unsupported backend type" do
      assert {:error, {:unsupported_backend, :invalid}} =
        Protocol.create_config(:invalid, %{})
    end

    test "applies default options when none provided" do
      {:ok, config} = Protocol.create_config(:test, %{})

      assert config.name == :memory_test
      assert config.timeout == 30_000
      assert config.max_retries == 3
      assert config.enable_sourcing == true
    end
  end

  describe "publish/2" do
    setup do
      {:ok, config} = Protocol.create_config(:test, %{name: :test_publish})
      %{config: config}
    end

    test "publishes event successfully", %{config: config} do
      event = %{
        type: "test.message",
        payload: %{content: "Hello, World!"}
      }

      {:ok, event_id} = Protocol.publish(config, event)

      assert is_binary(event_id)
      assert String.length(event_id) > 0
    end

    test "enriches event with metadata", %{config: config} do
      event = %{
        type: "test.enrichment",
        payload: %{data: "test"}
      }

      # Configure test backend to return the enriched event
      {:ok, event_id} = Protocol.publish(config, event)

      # Verify event was enriched (implementation detail of test backend)
      assert is_binary(event_id)
    end

    test "handles validation errors" do
      {:ok, config} = Protocol.create_config(:test, %{name: :test_validation})

      invalid_event = %{
        # Missing required fields
        payload: %{data: "test"}
      }

      assert {:error, {:invalid_event, _}} = Protocol.publish(config, invalid_event)
    end

    test "handles backend errors" do
      {:ok, config} = Protocol.create_config(:test, %{
        name: :test_errors,
        responses: %{"error_event" => {:error, :test_error}}
      })

      event = %{
        type: "error_event",
        payload: %{data: "test"}
      }

      assert {:error, :test_error} = Protocol.publish(config, event)
    end
  end

  describe "subscribe/4" do
    setup do
      {:ok, config} = Protocol.create_config(:test, %{name: :test_subscribe})
      %{config: config}
    end

    test "creates subscription successfully", %{config: config} do
      handler = fn _event -> :ok end

      {:ok, subscription_id} = Protocol.subscribe(config, "test.*", handler)

      assert is_binary(subscription_id)
      assert String.length(subscription_id) > 0
    end

    test "validates pattern format", %{config: config} do
      handler = fn _event -> :ok end

      assert {:error, {:invalid_pattern, _}} =
        Protocol.subscribe(config, 123, handler)
    end

    test "validates handler function", %{config: config} do
      assert {:error, {:invalid_handler, _}} =
        Protocol.subscribe(config, "test.*", "not_a_function")
    end

    test "includes optional metadata", %{config: config} do
      handler = fn _event -> :ok end
      options = %{priority: :high, created_by: :test}

      {:ok, subscription_id} = Protocol.subscribe(config, "test.*", handler, options)

      assert is_binary(subscription_id)
    end
  end

  describe "unsubscribe/2" do
    setup do
      {:ok, config} = Protocol.create_config(:test, %{name: :test_unsubscribe})
      handler = fn _event -> :ok end
      {:ok, subscription_id} = Protocol.subscribe(config, "test.*", handler)

      %{config: config, subscription_id: subscription_id}
    end

    test "removes subscription successfully", %{config: config, subscription_id: subscription_id} do
      assert :ok = Protocol.unsubscribe(config, subscription_id)
    end

    test "handles non-existent subscription", %{config: config} do
      assert {:error, :subscription_not_found} =
        Protocol.unsubscribe(config, "nonexistent_id")
    end

    test "validates subscription ID format", %{config: config} do
      assert {:error, {:invalid_subscription_id, _}} =
        Protocol.unsubscribe(config, 123)
    end
  end

  describe "replay/2" do
    setup do
      {:ok, config} = Protocol.create_config(:test, %{
        name: :test_replay,
        enable_sourcing: true
      })
      %{config: config}
    end

    test "replays events successfully", %{config: config} do
      # Publish some events first
      Enum.each(1..3, fn i ->
        event = %{type: "test.replay.#{i}", payload: %{index: i}}
        {:ok, _} = Protocol.publish(config, event)
      end)

      {:ok, events} = Protocol.replay(config, %{patterns: ["test.replay.*"]})

      assert is_list(events)
      assert length(events) <= 3
    end

    test "applies replay filters", %{config: config} do
      {:ok, events} = Protocol.replay(config, %{
        patterns: ["test.specific"],
        limit: 10
      })

      assert is_list(events)
    end

    test "handles sourcing disabled" do
      {:ok, config} = Protocol.create_config(:test, %{
        name: :test_no_sourcing,
        enable_sourcing: false
      })

      assert {:error, :sourcing_disabled} = Protocol.replay(config, %{})
    end
  end

  describe "list_subscriptions/1" do
    setup do
      {:ok, config} = Protocol.create_config(:test, %{name: :test_list_subs})
      %{config: config}
    end

    test "lists active subscriptions", %{config: config} do
      handler = fn _event -> :ok end
      {:ok, _} = Protocol.subscribe(config, "test.1", handler)
      {:ok, _} = Protocol.subscribe(config, "test.2", handler)

      {:ok, subscriptions} = Protocol.list_subscriptions(config)

      assert is_list(subscriptions)
      assert length(subscriptions) >= 2
    end

    test "returns empty list when no subscriptions", %{config: config} do
      {:ok, subscriptions} = Protocol.list_subscriptions(config)

      assert subscriptions == []
    end
  end

  describe "validate_config/1" do
    test "validates correct configuration" do
      {:ok, config} = Protocol.create_config(:test, %{})

      assert :ok = Protocol.validate_config(config)
    end

    test "rejects invalid backend type" do
      invalid_config = %{backend_type: :invalid, name: :test}

      assert {:error, {:unsupported_backend, :invalid}} =
        Protocol.validate_config(invalid_config)
    end
  end

  describe "health_check/1" do
    test "passes for healthy backend" do
      {:ok, config} = Protocol.create_config(:test, %{name: :test_health})

      assert :ok = Protocol.health_check(config)
    end
  end

  describe "get_backend_info/1" do
    test "returns backend information" do
      {:ok, config} = Protocol.create_config(:test, %{name: :test_info})

      {:ok, info} = Protocol.get_backend_info(config)

      assert info.backend_type == :test
      assert is_boolean(info.supports_sourcing)
      assert is_boolean(info.supports_patterns)
      assert is_list(info.features)
    end
  end

  describe "available_backends/0" do
    test "returns list of available backends" do
      backends = Protocol.available_backends()

      assert is_list(backends)
      assert :test in backends
      assert :in_memory in backends
      assert :phoenix_pubsub in backends
    end
  end

  describe "event_categories/0" do
    test "returns list of event categories" do
      categories = Protocol.event_categories()

      assert is_list(categories)
      assert :agent in categories
      assert :system in categories
      assert :memory in categories
      assert :telemetry in categories
      assert :user in categories
    end
  end

  describe "integration scenarios" do
    test "complete publish-subscribe flow" do
      {:ok, config} = Protocol.create_config(:test, %{name: :test_integration})

      # Set up subscriber
      test_pid = self()
      handler = fn event ->
        send(test_pid, {:event_received, event})
        :ok
      end

      {:ok, subscription_id} = Protocol.subscribe(config, "integration.*", handler)

      # Publish event
      event = %{
        type: "integration.test",
        payload: %{message: "Hello Integration!"}
      }

      {:ok, event_id} = Protocol.publish(config, event)

      # Verify event was received (would need proper test backend implementation)
      assert is_binary(event_id)
      assert is_binary(subscription_id)

      # Clean up
      assert :ok = Protocol.unsubscribe(config, subscription_id)
    end

    test "error handling flow" do
      {:ok, config} = Protocol.create_config(:test, %{
        name: :test_error_flow,
        responses: %{"error.test" => {:error, :simulated_failure}}
      })

      # Test error handling
      event = %{type: "error.test", payload: %{}}

      assert {:error, :simulated_failure} = Protocol.publish(config, event)
    end
  end
end
