defmodule Mix.Tasks.Docs.Shared.ProgressMonitorTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Docs.Shared.ProgressMonitor

  describe "start_monitor/2" do
    test "returns nil when disabled" do
      monitor_pid = ProgressMonitor.start_monitor(["test"], false)
      assert monitor_pid == nil
    end

    test "returns pid when enabled" do
      monitor_pid = ProgressMonitor.start_monitor(["test"], true)
      assert is_pid(monitor_pid)
      assert Process.alive?(monitor_pid)

      # Clean up
      ProgressMonitor.stop_monitor(monitor_pid)
    end

    test "starts monitor with correct sections" do
      sections = ["adrs", "examples", "trace"]
      monitor_pid = ProgressMonitor.start_monitor(sections, true)

      assert is_pid(monitor_pid)
      assert Process.alive?(monitor_pid)

      # Clean up
      ProgressMonitor.stop_monitor(monitor_pid)
    end
  end

  describe "stop_monitor/1" do
    test "handles nil monitor gracefully" do
      assert ProgressMonitor.stop_monitor(nil) == :ok
    end

    test "stops active monitor" do
      monitor_pid = ProgressMonitor.start_monitor(["test"], true)
      assert Process.alive?(monitor_pid)

      assert ProgressMonitor.stop_monitor(monitor_pid) == :ok

      # Give the process time to stop
      :timer.sleep(10)
      refute Process.alive?(monitor_pid)
    end
  end

  describe "update_section/2" do
    test "handles nil monitor gracefully" do
      assert ProgressMonitor.update_section(nil, "test") == :ok
    end

    test "sends message to active monitor" do
      monitor_pid = ProgressMonitor.start_monitor(["test"], true)

      assert ProgressMonitor.update_section(monitor_pid, "test_section") == :ok

      # Clean up
      ProgressMonitor.stop_monitor(monitor_pid)
    end
  end

  describe "update_progress/3" do
    test "handles nil monitor gracefully" do
      assert ProgressMonitor.update_progress(nil, "test", 50) == :ok
    end

    test "sends progress update to active monitor" do
      monitor_pid = ProgressMonitor.start_monitor(["test"], true)

      assert ProgressMonitor.update_progress(monitor_pid, "test", 25) == :ok
      assert ProgressMonitor.update_progress(monitor_pid, "test", 100) == :ok

      # Clean up
      ProgressMonitor.stop_monitor(monitor_pid)
    end

    test "validates progress range" do
      monitor_pid = ProgressMonitor.start_monitor(["test"], true)

      # Valid progress values should work
      assert ProgressMonitor.update_progress(monitor_pid, "test", 0) == :ok
      assert ProgressMonitor.update_progress(monitor_pid, "test", 50) == :ok
      assert ProgressMonitor.update_progress(monitor_pid, "test", 100) == :ok

      # Clean up
      ProgressMonitor.stop_monitor(monitor_pid)
    end
  end

  describe "complete_section/2" do
    test "handles nil monitor gracefully" do
      assert ProgressMonitor.complete_section(nil, "test") == :ok
    end

    test "sends completion message to active monitor" do
      monitor_pid = ProgressMonitor.start_monitor(["test"], true)

      assert ProgressMonitor.complete_section(monitor_pid, "test_section") == :ok

      # Clean up
      ProgressMonitor.stop_monitor(monitor_pid)
    end
  end

  describe "show_simple_progress/1" do
    test "displays progress message without errors" do
      # Should not raise any errors
      assert ProgressMonitor.show_simple_progress("Testing progress") == :ok
    end

    test "handles empty message" do
      assert ProgressMonitor.show_simple_progress("") == :ok
    end
  end

  describe "show_completion/2" do
    test "displays completion message with timing" do
      assert ProgressMonitor.show_completion("test task", 1000) == :ok
    end

    test "handles zero execution time" do
      assert ProgressMonitor.show_completion("test task", 0) == :ok
    end
  end

  describe "show_output_saved/1" do
    test "displays output file message" do
      assert ProgressMonitor.show_output_saved("/path/to/file.json") == :ok
    end

    test "handles relative paths" do
      assert ProgressMonitor.show_output_saved("output.json") == :ok
    end
  end

  describe "progress monitor lifecycle" do
    test "full lifecycle works correctly" do
      sections = ["adrs", "examples"]
      monitor_pid = ProgressMonitor.start_monitor(sections, true)

      # Update section
      ProgressMonitor.update_section(monitor_pid, "adrs")

      # Update progress
      ProgressMonitor.update_progress(monitor_pid, "adrs", 25)
      ProgressMonitor.update_progress(monitor_pid, "adrs", 75)

      # Complete section
      ProgressMonitor.complete_section(monitor_pid, "adrs")

      # Move to next section
      ProgressMonitor.update_section(monitor_pid, "examples")
      ProgressMonitor.update_progress(monitor_pid, "examples", 100)
      ProgressMonitor.complete_section(monitor_pid, "examples")

      # Stop monitor
      ProgressMonitor.stop_monitor(monitor_pid)

      # Give process time to stop
      :timer.sleep(10)
      refute Process.alive?(monitor_pid)
    end
  end

  describe "monitor process behavior" do
    test "monitor responds to messages correctly" do
      monitor_pid = ProgressMonitor.start_monitor(["test"], true)

      # Send messages and verify process is still alive
      ProgressMonitor.update_section(monitor_pid, "test")
      assert Process.alive?(monitor_pid)

      ProgressMonitor.update_progress(monitor_pid, "test", 50)
      assert Process.alive?(monitor_pid)

      ProgressMonitor.complete_section(monitor_pid, "test")
      assert Process.alive?(monitor_pid)

      # Stop should terminate the process
      ProgressMonitor.stop_monitor(monitor_pid)
      :timer.sleep(10)
      refute Process.alive?(monitor_pid)
    end

    test "monitor handles multiple rapid updates" do
      monitor_pid = ProgressMonitor.start_monitor(["test"], true)

      # Send rapid updates
      for i <- 1..10 do
        ProgressMonitor.update_progress(monitor_pid, "test", i * 10)
      end

      assert Process.alive?(monitor_pid)

      # Clean up
      ProgressMonitor.stop_monitor(monitor_pid)
    end
  end
end
