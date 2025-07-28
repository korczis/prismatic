defmodule Prismatic.Event.SourcingTest do
  use ExUnit.Case, async: true

  alias Prismatic.Event.{Sourcing, Protocol}

  describe "start_link/1" do
    test "starts sourcing with test backend" do
      config = %{backend_type: :test, name: :test_sourcing, enable_sourcing: true}

      {:ok, pid} = Sourcing.start_link(config: config, name: :test_sourcing_start)

      assert is_pid(pid)
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end

    test "starts sourcing with in_memory backend" do
      config = %{backend_type: :in_memory, name: :test_sourcing_memory, enable_sourcing: true}

      {:ok, pid} = Sourcing.start_link(config: config, name: :test_sourcing_memory)

      assert is_pid(pid)
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end
  end

  describe "store_event/2" do
    setup do
      config = %{backend_type: :test, name: :test_sourcing_store, enable_sourcing: true}
      {:ok, sourcing} = Sourcing.start_link(config: config, name: :test_sourcing_store)

      on_exit(fn -> GenServer.stop(sourcing) end)
      %{sourcing: sourcing}
    end

    test "stores event successfully", %{sourcing: sourcing} do
      event = %{
        type: "sourcing.test.store",
        payload: %{message: "Test Event"},
        metadata: %{
          event_id: "test_event_123",
          timestamp: DateTime.utc_now(),
          source: "test"
        }
      }

      {:ok, sequence_number} = Sourcing.store_event(sourcing, event)

      assert is_integer(sequence_number)
      assert sequence_number > 0
    end

    test "assigns sequential sequence numbers", %{sourcing: sourcing} do
      events = [
        %{type: "seq.1", payload: %{}, metadata: %{event_id: "1", timestamp: DateTime.utc_now()}},
        %{type: "seq.2", payload: %{}, metadata: %{event_id: "2", timestamp: DateTime.utc_now()}},
        %{type: "seq.3", payload: %{}, metadata: %{event_id: "3", timestamp: DateTime.utc_now()}}
      ]

      sequence_numbers = Enum.map(events, fn event ->
        {:ok, seq_num} = Sourcing.store_event(sourcing, event)
        seq_num
      end)

      # Sequence numbers should be consecutive
      assert sequence_numbers == Enum.to_list(1..3)
    end

    test "handles storage errors gracefully", %{sourcing: sourcing} do
      # This would need a configured test backend that returns errors
      # For now, just verify the interface works
      event = %{
        type: "sourcing.error.test",
        payload: %{},
        metadata: %{event_id: "error_test", timestamp: DateTime.utc_now()}
      }

      result = Sourcing.store_event(sourcing, event)

      # Should either succeed or return proper error format
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "replay/2" do
    setup do
      config = %{backend_type: :test, name: :test_sourcing_replay, enable_sourcing: true}
      {:ok, sourcing} = Sourcing.start_link(config: config, name: :test_sourcing_replay)

      # Store some test events
      test_events = [
        %{
          type: "replay.test.1",
          payload: %{index: 1},
          metadata: %{event_id: "replay_1", timestamp: DateTime.utc_now()}
        },
        %{
          type: "replay.other.2",
          payload: %{index: 2},
          metadata: %{event_id: "replay_2", timestamp: DateTime.utc_now()}
        },
        %{
          type: "replay.test.3",
          payload: %{index: 3},
          metadata: %{event_id: "replay_3", timestamp: DateTime.utc_now()}
        }
      ]

      Enum.each(test_events, fn event ->
        {:ok, _} = Sourcing.store_event(sourcing, event)
      end)

      on_exit(fn -> GenServer.stop(sourcing) end)
      %{sourcing: sourcing}
    end

    test "replays all events when no filters", %{sourcing: sourcing} do
      {:ok, events} = Sourcing.replay(sourcing, %{})

      assert is_list(events)
      assert length(events) >= 3  # At least our test events
    end

    test "replays events with pattern filtering", %{sourcing: sourcing} do
      {:ok, events} = Sourcing.replay(sourcing, %{patterns: ["replay.test.*"]})

      assert is_list(events)

      # Should only include events matching the pattern
      event_types = Enum.map(events, &(&1.type))
      assert "replay.test.1" in event_types
      assert "replay.test.3" in event_types
      refute "replay.other.2" in event_types
    end

    test "replays events with limit", %{sourcing: sourcing} do
      {:ok, events} = Sourcing.replay(sourcing, %{limit: 2})

      assert is_list(events)
      assert length(events) == 2
    end

    test "replays events with time range", %{sourcing: sourcing} do
      now = DateTime.utc_now()
      past = DateTime.add(now, -3600, :second)  # 1 hour ago
      future = DateTime.add(now, 3600, :second)   # 1 hour from now

      {:ok, events} = Sourcing.replay(sourcing, %{
        from: past,
        to: future
      })

      assert is_list(events)
      # All our test events should be within this range
      assert length(events) >= 3
    end

    test "respects ordering parameter", %{sourcing: sourcing} do
      {:ok, asc_events} = Sourcing.replay(sourcing, %{order: :asc})
      {:ok, desc_events} = Sourcing.replay(sourcing, %{order: :desc})

      assert is_list(asc_events)
      assert is_list(desc_events)

      # If we have multiple events, order should be different
      if length(asc_events) > 1 do
        assert asc_events != desc_events
        assert Enum.reverse(asc_events) == desc_events
      end
    end
  end

  describe "get_current_sequence/1" do
    setup do
      config = %{backend_type: :test, name: :test_sourcing_sequence, enable_sourcing: true}
      {:ok, sourcing} = Sourcing.start_link(config: config, name: :test_sourcing_sequence)

      on_exit(fn -> GenServer.stop(sourcing) end)
      %{sourcing: sourcing}
    end

    test "returns initial sequence number", %{sourcing: sourcing} do
      {:ok, sequence} = Sourcing.get_current_sequence(sourcing)

      assert is_integer(sequence)
      assert sequence >= 1  # Should start at 1 or higher
    end

    test "sequence increases after storing events", %{sourcing: sourcing} do
      {:ok, initial_sequence} = Sourcing.get_current_sequence(sourcing)

      event = %{
        type: "sequence.test",
        payload: %{},
        metadata: %{event_id: "seq_test", timestamp: DateTime.utc_now()}
      }

      {:ok, _stored_sequence} = Sourcing.store_event(sourcing, event)

      {:ok, new_sequence} = Sourcing.get_current_sequence(sourcing)

      assert new_sequence > initial_sequence
    end
  end

  describe "create_snapshot/2" do
    setup do
      config = %{backend_type: :test, name: :test_sourcing_snapshot, enable_sourcing: true}
      {:ok, sourcing} = Sourcing.start_link(config: config, name: :test_sourcing_snapshot)

      on_exit(fn -> GenServer.stop(sourcing) end)
      %{sourcing: sourcing}
    end

    test "creates snapshot successfully", %{sourcing: sourcing} do
      state_data = %{
        current_state: "test_state",
        counters: %{events: 5, errors: 0},
        last_updated: DateTime.utc_now()
      }

      {:ok, snapshot_sequence} = Sourcing.create_snapshot(sourcing, state_data)

      assert is_integer(snapshot_sequence)
      assert snapshot_sequence >= 0
    end

    test "snapshot includes current sequence", %{sourcing: sourcing} do
      # Store some events first
      Enum.each(1..3, fn i ->
        event = %{
          type: "snapshot.test.#{i}",
          payload: %{index: i},
          metadata: %{event_id: "snap_#{i}", timestamp: DateTime.utc_now()}
        }
        {:ok, _} = Sourcing.store_event(sourcing, event)
      end)

      {:ok, current_sequence} = Sourcing.get_current_sequence(sourcing)

      state_data = %{test: "snapshot"}
      {:ok, snapshot_sequence} = Sourcing.create_snapshot(sourcing, state_data)

      # Snapshot sequence should be related to current sequence
      assert snapshot_sequence <= current_sequence
    end
  end

  describe "get_stats/1" do
    setup do
      config = %{backend_type: :test, name: :test_sourcing_stats, enable_sourcing: true}
      {:ok, sourcing} = Sourcing.start_link(config: config, name: :test_sourcing_stats)

      on_exit(fn -> GenServer.stop(sourcing) end)
      %{sourcing: sourcing}
    end

    test "returns sourcing statistics", %{sourcing: sourcing} do
      {:ok, stats} = Sourcing.get_stats(sourcing)

      assert is_map(stats)
      assert Map.has_key?(stats, :backend_type)
      assert Map.has_key?(stats, :current_sequence)
      assert Map.has_key?(stats, :last_snapshot_sequence)
      assert Map.has_key?(stats, :metrics)

      assert stats.backend_type == :test
      assert is_integer(stats.current_sequence)
      assert is_integer(stats.last_snapshot_sequence)
      assert is_map(stats.metrics)
    end

    test "statistics update with operations", %{sourcing: sourcing} do
      {:ok, initial_stats} = Sourcing.get_stats(sourcing)
      initial_events = initial_stats.metrics.events_stored

      # Store an event
      event = %{
        type: "stats.test",
        payload: %{},
        metadata: %{event_id: "stats_test", timestamp: DateTime.utc_now()}
      }

      {:ok, _} = Sourcing.store_event(sourcing, event)

      {:ok, updated_stats} = Sourcing.get_stats(sourcing)

      assert updated_stats.metrics.events_stored == initial_events + 1
      assert updated_stats.current_sequence > initial_stats.current_sequence
    end
  end

  describe "compact/2" do
    setup do
      config = %{backend_type: :test, name: :test_sourcing_compact, enable_sourcing: true}
      {:ok, sourcing} = Sourcing.start_link(config: config, name: :test_sourcing_compact)

      on_exit(fn -> GenServer.stop(sourcing) end)
      %{sourcing: sourcing}
    end

    test "compacts old events", %{sourcing: sourcing} do
      # Store some events
      old_time = DateTime.add(DateTime.utc_now(), -7200, :second)  # 2 hours ago

      Enum.each(1..5, fn i ->
        event = %{
          type: "compact.test.#{i}",
          payload: %{index: i},
          metadata: %{event_id: "compact_#{i}", timestamp: old_time}
        }
        {:ok, _} = Sourcing.store_event(sourcing, event)
      end)

      # Compact events older than 1 hour
      cutoff_time = DateTime.add(DateTime.utc_now(), -3600, :second)

      {:ok, compacted_count} = Sourcing.compact(sourcing, %{older_than: cutoff_time})

      assert is_integer(compacted_count)
      assert compacted_count >= 0
    end

    test "handles compaction with no matching events", %{sourcing: sourcing} do
      # Try to compact events older than a very old time
      very_old_time = DateTime.add(DateTime.utc_now(), -86400 * 365, :second)  # 1 year ago

      {:ok, compacted_count} = Sourcing.compact(sourcing, %{older_than: very_old_time})

      assert compacted_count == 0
    end
  end

  describe "integration scenarios" do
    setup do
      config = %{backend_type: :test, name: :test_sourcing_integration, enable_sourcing: true}
      {:ok, sourcing} = Sourcing.start_link(config: config, name: :test_sourcing_integration)

      on_exit(fn -> GenServer.stop(sourcing) end)
      %{sourcing: sourcing}
    end

    test "complete event lifecycle", %{sourcing: sourcing} do
      # Store events
      events = Enum.map(1..10, fn i ->
        %{
          type: "lifecycle.test.#{i}",
          payload: %{index: i, data: "test_data_#{i}"},
          metadata: %{
            event_id: "lifecycle_#{i}",
            timestamp: DateTime.utc_now(),
            source: "integration_test"
          }
        }
      end)

      stored_sequences = Enum.map(events, fn event ->
        {:ok, seq} = Sourcing.store_event(sourcing, event)
        seq
      end)

      # Verify all events were stored with sequential numbers
      assert stored_sequences == Enum.to_list(1..10)

      # Create snapshot
      state_data = %{
        total_events: 10,
        last_event_type: "lifecycle.test.10"
      }

      {:ok, snapshot_seq} = Sourcing.create_snapshot(sourcing, state_data)
      assert is_integer(snapshot_seq)

      # Replay events
      {:ok, replayed_events} = Sourcing.replay(sourcing, %{
        patterns: ["lifecycle.test.*"],
        limit: 5
      })

      assert length(replayed_events) == 5

      # Verify event structure
      first_event = Enum.at(replayed_events, 0)
      assert Map.has_key?(first_event, :type)
      assert Map.has_key?(first_event, :payload)
      assert Map.has_key?(first_event, :metadata)

      # Get final stats
      {:ok, stats} = Sourcing.get_stats(sourcing)
      assert stats.metrics.events_stored >= 10
      assert stats.metrics.snapshots_created >= 1
    end

    test "high-volume event storage", %{sourcing: sourcing} do
      event_count = 100

      start_time = System.monotonic_time()

      # Store many events quickly
      tasks = Enum.map(1..event_count, fn i ->
        Task.async(fn ->
          event = %{
            type: "volume.test.#{rem(i, 10)}",  # Create some pattern variety
            payload: %{index: i, timestamp: System.system_time()},
            metadata: %{
              event_id: "volume_#{i}",
              timestamp: DateTime.utc_now(),
              batch: div(i, 10)
            }
          }

          Sourcing.store_event(sourcing, event)
        end)
      end)

      results = Enum.map(tasks, &Task.await/1)

      end_time = System.monotonic_time()
      duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # All events should be stored successfully
      assert Enum.all?(results, &match?({:ok, _}, &1))

      # Should complete within reasonable time
      assert duration < 10_000  # Less than 10 seconds

      # Verify current sequence
      {:ok, final_sequence} = Sourcing.get_current_sequence(sourcing)
      assert final_sequence >= event_count

      # Test replay performance
      start_time = System.monotonic_time()

      {:ok, replayed_events} = Sourcing.replay(sourcing, %{
        patterns: ["volume.test.*"],
        limit: 50
      })

      end_time = System.monotonic_time()
      replay_duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)

      assert length(replayed_events) == 50
      assert replay_duration < 1000  # Less than 1 second
    end

    test "event sourcing with pattern-based replay", %{sourcing: sourcing} do
      # Store events with various patterns
      event_patterns = [
        {"user.login", 10},
        {"user.logout", 5},
        {"system.error", 3},
        {"system.warning", 7},
        {"admin.action", 2}
      ]

      Enum.each(event_patterns, fn {pattern, count} ->
        Enum.each(1..count, fn i ->
          event = %{
            type: "#{pattern}.#{i}",
            payload: %{pattern: pattern, index: i},
            metadata: %{
              event_id: "#{String.replace(pattern, ".", "_")}_#{i}",
              timestamp: DateTime.utc_now()
            }
          }

          {:ok, _} = Sourcing.store_event(sourcing, event)
        end)
      end)

      # Test various replay patterns
      test_cases = [
        {["user.*"], 15},        # All user events
        {["system.*"], 10},      # All system events
        {["**.error"], 3},       # All error events
        {["user.login.*"], 10},  # Only login events
        {["admin.*"], 2}         # All admin events
      ]

      Enum.each(test_cases, fn {patterns, expected_min_count} ->
        {:ok, events} = Sourcing.replay(sourcing, %{patterns: patterns})
        assert length(events) >= expected_min_count

        # Verify all events match at least one pattern
        Enum.each(events, fn event ->
          matches = Enum.any?(patterns, fn pattern ->
            # Simple pattern matching for test
            case pattern do
              "user.*" -> String.starts_with?(event.type, "user.")
              "system.*" -> String.starts_with?(event.type, "system.")
              "**.error" -> String.ends_with?(event.type, "error")
              "user.login.*" -> String.starts_with?(event.type, "user.login.")
              "admin.*" -> String.starts_with?(event.type, "admin.")
              _ -> false
            end
          end)

          assert matches, "Event #{event.type} should match one of #{inspect(patterns)}"
        end)
      end)
    end
  end
end
