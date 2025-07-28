defmodule Prismatic.Event.TelemetryTest do
  use ExUnit.Case, async: true

  alias Prismatic.Event.Telemetry

  describe "emit/5" do
    test "emits telemetry events with correct structure" do
      # Setup telemetry handler to capture events
      test_pid = self()

      handler = fn event_name, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event_name, measurements, metadata})
      end

      :telemetry.attach("test-handler", [:prismatic, :event], handler, %{})

      # Emit test event
      Telemetry.emit(:protocol, :publish, :success, %{duration: 150}, %{event_type: "test"})

      # Verify event was emitted correctly
      assert_receive {:telemetry_event, event_name, measurements, metadata}

      assert event_name == [:prismatic, :event, :protocol, :publish, :success]
      assert measurements.duration == 150
      assert metadata.event_type == "test"
      assert metadata.system == :prismatic_event
      assert %DateTime{} = metadata.timestamp

      # Cleanup
      :telemetry.detach("test-handler")
    end

    test "enriches metadata with system information" do
      test_pid = self()

      handler = fn _event_name, _measurements, metadata, _config ->
        send(test_pid, {:metadata, metadata})
      end

      :telemetry.attach("test-enrichment", [:prismatic, :event], handler, %{})

      Telemetry.emit(:bus, :delivery, :success, %{}, %{custom: "value"})

      assert_receive {:metadata, metadata}

      # Check enriched fields
      assert metadata.custom == "value"  # Original metadata preserved
      assert %DateTime{} = metadata.timestamp
      assert metadata.node == Node.self()
      assert is_pid(metadata.pid)
      assert metadata.system == :prismatic_event

      :telemetry.detach("test-enrichment")
    end
  end

  describe "convenience functions" do
    setup do
      test_pid = self()

      handler = fn event_name, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event_name, measurements, metadata})
      end

      :telemetry.attach("test-convenience", [:prismatic, :event], handler, %{})

      on_exit(fn -> :telemetry.detach("test-convenience") end)

      %{test_pid: test_pid}
    end

    test "emit_protocol_event/4 creates correct event name", %{test_pid: _test_pid} do
      Telemetry.emit_protocol_event(:subscribe, :success, %{count: 5}, %{pattern: "test.*"})

      assert_receive {:telemetry_event, event_name, measurements, metadata}

      assert event_name == [:prismatic, :event, :protocol, :subscribe, :success]
      assert measurements.count == 5
      assert metadata.pattern == "test.*"
    end

    test "emit_bus_event/4 creates correct event name", %{test_pid: _test_pid} do
      Telemetry.emit_bus_event(:pattern_match, :success, %{matches: 3}, %{pattern: "user.*"})

      assert_receive {:telemetry_event, event_name, measurements, metadata}

      assert event_name == [:prismatic, :event, :bus, :pattern_match, :success]
      assert measurements.matches == 3
      assert metadata.pattern == "user.*"
    end

    test "emit_registry_event/4 creates correct event name", %{test_pid: _test_pid} do
      Telemetry.emit_registry_event(:cache, :hit, %{size: 100}, %{key: "pattern_123"})

      assert_receive {:telemetry_event, event_name, measurements, metadata}

      assert event_name == [:prismatic, :event, :registry, :cache, :hit]
      assert measurements.size == 100
      assert metadata.key == "pattern_123"
    end

    test "emit_sourcing_event/4 creates correct event name", %{test_pid: _test_pid} do
      Telemetry.emit_sourcing_event(:store, :success, %{sequence: 12345}, %{event_type: "user.login"})

      assert_receive {:telemetry_event, event_name, measurements, metadata}

      assert event_name == [:prismatic, :event, :sourcing, :store, :success]
      assert measurements.sequence == 12345
      assert metadata.event_type == "user.login"
    end

    test "emit_backend_event/4 creates correct event name", %{test_pid: _test_pid} do
      Telemetry.emit_backend_event(:circuit_breaker, :open, %{failures: 5}, %{backend: :in_memory})

      assert_receive {:telemetry_event, event_name, measurements, metadata}

      assert event_name == [:prismatic, :event, :backend, :circuit_breaker, :open]
      assert measurements.failures == 5
      assert metadata.backend == :in_memory
    end
  end

  describe "measure/4" do
    setup do
      test_pid = self()

      handler = fn event_name, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event_name, measurements, metadata})
      end

      :telemetry.attach("test-measure", [:prismatic, :event], handler, %{})

      on_exit(fn -> :telemetry.detach("test-measure") end)

      %{test_pid: test_pid}
    end

    test "measures successful function execution", %{test_pid: _test_pid} do
      result = Telemetry.measure(:protocol, :publish, fn ->
        :timer.sleep(10)  # Simulate work
        {:ok, "event_123"}
      end, %{event_type: "test.measure"})

      assert result == {:ok, "event_123"}

      assert_receive {:telemetry_event, event_name, measurements, metadata}

      assert event_name == [:prismatic, :event, :protocol, :publish, :success]
      assert is_integer(measurements.duration)
      assert measurements.duration > 0
      assert metadata.event_type == "test.measure"
    end

    test "measures failed function execution", %{test_pid: _test_pid} do
      result = Telemetry.measure(:protocol, :subscribe, fn ->
        {:error, :invalid_pattern}
      end, %{pattern: "invalid"})

      assert result == {:error, :invalid_pattern}

      assert_receive {:telemetry_event, event_name, measurements, metadata}

      assert event_name == [:prismatic, :event, :protocol, :subscribe, :error]
      assert is_integer(measurements.duration)
      assert metadata.pattern == "invalid"
    end

    test "handles function exceptions", %{test_pid: _test_pid} do
      assert_raise RuntimeError, "test error", fn ->
        Telemetry.measure(:bus, :delivery, fn ->
          raise "test error"
        end, %{subscriber: "test"})
      end

      assert_receive {:telemetry_event, event_name, measurements, metadata}

      assert event_name == [:prismatic, :event, :bus, :delivery, :error]
      assert is_integer(measurements.duration)
      assert metadata.subscriber == "test"
      assert String.contains?(metadata.error, "RuntimeError")
    end

    test "determines status from result correctly", %{test_pid: _test_pid} do
      # Test various result patterns
      test_cases = [
        {fn -> {:ok, "success"} end, :success},
        {fn -> :ok end, :success},
        {fn -> {:error, "failure"} end, :error},
        {fn -> {:timeout, "too slow"} end, :timeout},
        {fn -> "plain result" end, :success}
      ]

      Enum.each(test_cases, fn {fun, expected_status} ->
        Telemetry.measure(:test, :operation, fun, %{})

        assert_receive {:telemetry_event, event_name, _measurements, _metadata}

        [_prismatic, _event, _test, _operation, actual_status] = event_name
        assert actual_status == expected_status
      end)
    end
  end

  describe "default handlers" do
    test "attaches and detaches handlers successfully" do
      # Verify no handlers initially
      assert :telemetry.list_handlers([:prismatic, :event]) == []

      # Attach default handlers
      :ok = Telemetry.attach_default_handlers()

      # Verify handlers were attached
      handlers = :telemetry.list_handlers([:prismatic, :event])
      handler_ids = Enum.map(handlers, & &1.id)

      assert "prismatic-event-logger" in handler_ids
      assert "prismatic-event-metrics" in handler_ids
      assert "prismatic-event-health" in handler_ids

      # Detach handlers
      :ok = Telemetry.detach_default_handlers()

      # Verify handlers were removed
      assert :telemetry.list_handlers([:prismatic, :event]) == []
    end

    test "attaches handlers with custom options" do
      :ok = Telemetry.attach_default_handlers(
        log_level: :debug,
        enable_metrics: false,
        enable_health_checks: false
      )

      handlers = :telemetry.list_handlers([:prismatic, :event])
      handler_ids = Enum.map(handlers, & &1.id)

      # Only logger should be attached
      assert "prismatic-event-logger" in handler_ids
      refute "prismatic-event-metrics" in handler_ids
      refute "prismatic-event-health" in handler_ids

      :ok = Telemetry.detach_default_handlers()
    end
  end

  describe "get_metrics_summary/0" do
    test "returns metrics summary structure" do
      summary = Telemetry.get_metrics_summary()

      assert is_map(summary)
      assert Map.has_key?(summary, :protocol)
      assert Map.has_key?(summary, :bus)
      assert Map.has_key?(summary, :sourcing)
      assert Map.has_key?(summary, :backend)

      # Verify protocol metrics structure
      protocol_metrics = summary.protocol
      assert Map.has_key?(protocol_metrics, :publish)
      assert Map.has_key?(protocol_metrics, :subscribe)
      assert Map.has_key?(protocol_metrics, :replay)

      # Verify each metric has expected fields
      publish_metrics = protocol_metrics.publish
      assert Map.has_key?(publish_metrics, :count)
      assert Map.has_key?(publish_metrics, :avg_duration)
      assert Map.has_key?(publish_metrics, :error_rate)
    end
  end

  describe "integration scenarios" do
    test "telemetry works with real event operations" do
      # This would be an integration test with actual event system components
      # For now, we'll test the telemetry emission patterns

      test_pid = self()

      handler = fn event_name, measurements, metadata, _config ->
        send(test_pid, {:event, event_name, measurements, metadata})
      end

      :telemetry.attach("integration-test", [:prismatic, :event], handler, %{})

      # Simulate a complete event publication flow
      Telemetry.measure(:protocol, :publish, fn ->
        # Simulate protocol validation
        Telemetry.emit_protocol_event(:validate, :success, %{duration: 5}, %{})

        # Simulate bus processing
        Telemetry.emit_bus_event(:pattern_match, :success, %{matches: 3, duration: 10}, %{})
        Telemetry.emit_bus_event(:delivery, :success, %{subscribers: 3, duration: 15}, %{})

        # Simulate sourcing
        Telemetry.emit_sourcing_event(:store, :success, %{sequence: 12345, duration: 8}, %{})

        {:ok, "event_id_123"}
      end, %{event_type: "user.login"})

      # Verify all events were emitted in correct order
      events = receive_all_events([])

      assert length(events) >= 5  # At least the events we explicitly emitted

      # Check main measurement event
      main_event = Enum.find(events, fn {event_name, _, _} ->
        event_name == [:prismatic, :event, :protocol, :publish, :success]
      end)

      assert main_event != nil
      {_, measurements, metadata} = main_event
      assert is_integer(measurements.duration)
      assert metadata.event_type == "user.login"

      :telemetry.detach("integration-test")
    end

    test "telemetry handles high-frequency events" do
      _test_pid = self()
      event_count = :counters.new(1, [])

      handler = fn _event_name, _measurements, _metadata, _config ->
        :counters.add(event_count, 1, 1)
      end

      :telemetry.attach("high-frequency-test", [:prismatic, :event], handler, %{})

      # Emit many events quickly
      start_time = System.monotonic_time()

      Enum.each(1..1000, fn i ->
        Telemetry.emit(:protocol, :publish, :success, %{sequence: i}, %{})
      end)

      end_time = System.monotonic_time()
      duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # Verify all events were processed
      final_count = :counters.get(event_count, 1)
      assert final_count == 1000

      # Should complete quickly (adjust threshold as needed)
      assert duration < 1000  # Less than 1 second

      :telemetry.detach("high-frequency-test")
    end
  end

  # Helper function to receive all telemetry events
  defp receive_all_events(acc) do
    receive do
      {:event, event_name, measurements, metadata} ->
        receive_all_events([{event_name, measurements, metadata} | acc])
    after
      50 -> Enum.reverse(acc)  # Stop after 50ms of no events
    end
  end
end
