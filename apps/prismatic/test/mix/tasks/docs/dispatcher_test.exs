defmodule Mix.Tasks.Docs.DispatcherTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Docs.Dispatcher

  describe "parse_args/1" do
    test "returns help for empty args" do
      assert Dispatcher.parse_args([]) == {:help}
    end

    test "returns help for help flags" do
      assert Dispatcher.parse_args(["--help"]) == {:help}
      assert Dispatcher.parse_args(["-h"]) == {:help}
      assert Dispatcher.parse_args(["help"]) == {:help}
    end

    test "returns command for valid commands" do
      assert Dispatcher.parse_args(["analyze"]) == {:command, "analyze", []}
      assert Dispatcher.parse_args(["extract_adrs"]) == {:command, "extract_adrs", []}
      assert Dispatcher.parse_args(["extract_examples"]) == {:command, "extract_examples", []}
      assert Dispatcher.parse_args(["trace"]) == {:command, "trace", []}
      assert Dispatcher.parse_args(["ai_data"]) == {:command, "ai_data", []}
      assert Dispatcher.parse_args(["validate"]) == {:command, "validate", []}
      assert Dispatcher.parse_args(["report"]) == {:command, "report", []}
    end

    test "returns command with arguments" do
      assert Dispatcher.parse_args(["analyze", "--verbose"]) ==
        {:command, "analyze", ["--verbose"]}

      assert Dispatcher.parse_args(["extract_adrs", "--domain", "security", "--verbose"]) ==
        {:command, "extract_adrs", ["--domain", "security", "--verbose"]}
    end

    test "returns error for unknown command" do
      assert {:error, message} = Dispatcher.parse_args(["unknown_command"])
      assert String.contains?(message, "Unknown command 'unknown_command'")
      assert String.contains?(message, "Available commands:")
    end

    test "returns error for invalid argument format" do
      assert {:error, "Invalid argument format"} = Dispatcher.parse_args([:invalid, :format])
    end
  end

  describe "show_comprehensive_help/0" do
    test "displays help without errors" do
      # Should not raise any errors
      assert Dispatcher.show_comprehensive_help() == :ok
    end
  end

  describe "show_usage_summary/0" do
    test "displays usage summary without errors" do
      # Should not raise any errors
      assert Dispatcher.show_usage_summary() == :ok
    end
  end

  describe "run/1" do
    test "shows help for empty args" do
      # We can't easily test the actual run function due to Mix.shell() dependencies
      # and System.halt() calls, but we can test the parsing logic
      assert Dispatcher.parse_args([]) == {:help}
    end

    test "parses analyze command correctly" do
      assert Dispatcher.parse_args(["analyze", "--verbose"]) ==
        {:command, "analyze", ["--verbose"]}
    end
  end

  describe "command validation" do
    test "all documented commands are valid" do
      documented_commands = ~w(analyze extract_adrs extract_examples trace ai_data validate report)

      Enum.each(documented_commands, fn command ->
        assert {:command, ^command, []} = Dispatcher.parse_args([command])
      end)
    end

    test "command names are consistent" do
      # Test that command names follow expected patterns
      valid_commands = ~w(analyze extract_adrs extract_examples trace ai_data validate report)

      Enum.each(valid_commands, fn command ->
        # Commands should be lowercase with underscores
        assert command =~ ~r/^[a-z_]+$/

        # Should parse successfully
        assert {:command, ^command, []} = Dispatcher.parse_args([command])
      end)
    end
  end

  describe "error handling" do
    test "provides helpful error messages for typos" do
      typos = [
        "analze",     # missing 'y'
        "analize",    # common misspelling
        "extact_adrs", # missing 'r'
        "valdiate"    # transposed letters
      ]

      Enum.each(typos, fn typo ->
        assert {:error, message} = Dispatcher.parse_args([typo])
        assert String.contains?(message, "Unknown command")
        assert String.contains?(message, "Available commands:")
      end)
    end

    test "handles mixed case commands" do
      mixed_case_commands = ["Analyze", "EXTRACT_ADRS", "Trace"]

      Enum.each(mixed_case_commands, fn command ->
        assert {:error, message} = Dispatcher.parse_args([command])
        assert String.contains?(message, "Unknown command")
      end)
    end
  end

  describe "argument passing" do
    test "preserves argument order" do
      args = ["--docs", "custom_docs", "--verbose", "--output", "json"]
      assert {:command, "analyze", ^args} = Dispatcher.parse_args(["analyze" | args])
    end

    test "handles various argument formats" do
      test_cases = [
        {["analyze", "--help"], {:command, "analyze", ["--help"]}},
        {["extract_adrs", "-v"], {:command, "extract_adrs", ["-v"]}},
        {["trace", "--matrix", "--verbose"], {:command, "trace", ["--matrix", "--verbose"]}},
        {["validate", "--fix", "--report"], {:command, "validate", ["--fix", "--report"]}}
      ]

      Enum.each(test_cases, fn {input, expected} ->
        assert Dispatcher.parse_args(input) == expected
      end)
    end
  end

  describe "integration behavior" do
    test "command parsing is consistent with actual commands" do
      # This test ensures that the dispatcher knows about all the commands
      # that actually exist as task modules
      expected_commands = [
        "analyze",
        "extract_adrs",
        "extract_examples",
        "trace",
        "ai_data",
        "validate",
        "report"
      ]

      Enum.each(expected_commands, fn command ->
        assert {:command, ^command, []} = Dispatcher.parse_args([command])
      end)
    end
  end
end
