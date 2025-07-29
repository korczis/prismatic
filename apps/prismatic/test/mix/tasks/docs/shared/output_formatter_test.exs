defmodule Mix.Tasks.Docs.Shared.OutputFormatterTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Docs.Shared.OutputFormatter

  @test_result %{
    analysis_timestamp: "2023-01-01T00:00:00Z",
    analysis_version: "2.0.0",
    adrs: %{adrs: [%{id: "ADR-001", title: "Test ADR"}]},
    examples: %{examples: [%{id: "ex1", language: "elixir"}]},
    summary: %{total_items: 2}
  }

  describe "save_results/2" do
    setup do
      temp_dir = "test_output_#{:rand.uniform(1000)}"
      File.mkdir_p!(temp_dir)

      on_exit(fn ->
        File.rm_rf!(temp_dir)
      end)

      %{temp_dir: temp_dir}
    end

    test "saves JSON output successfully", %{temp_dir: temp_dir} do
      config = %{
        output_format: "json",
        output_file: Path.join(temp_dir, "test.json")
      }

      assert OutputFormatter.save_results(@test_result, config) == :ok
      assert File.exists?(config.output_file)

      content = File.read!(config.output_file)
      assert {:ok, parsed} = Jason.decode(content)
      assert parsed["analysis_timestamp"] == @test_result.analysis_timestamp
    end

    test "saves YAML output successfully", %{temp_dir: temp_dir} do
      config = %{
        output_format: "yaml",
        output_file: Path.join(temp_dir, "test.yaml")
      }

      assert OutputFormatter.save_results(@test_result, config) == :ok
      assert File.exists?(config.output_file)
    end

    test "saves HTML output successfully", %{temp_dir: temp_dir} do
      config = %{
        output_format: "html",
        output_file: Path.join(temp_dir, "test.html")
      }

      assert OutputFormatter.save_results(@test_result, config) == :ok
      assert File.exists?(config.output_file)

      content = File.read!(config.output_file)
      assert String.contains?(content, "<!DOCTYPE html>")
      assert String.contains?(content, @test_result.analysis_timestamp)
    end

    test "saves report output successfully", %{temp_dir: temp_dir} do
      config = %{
        output_format: "report",
        output_file: Path.join(temp_dir, "test.txt")
      }

      assert OutputFormatter.save_results(@test_result, config) == :ok
      assert File.exists?(config.output_file)

      content = File.read!(config.output_file)
      assert String.contains?(content, "ANALYSIS REPORT")
    end

    test "returns error for invalid file path" do
      config = %{
        output_format: "json",
        output_file: "/invalid/path/test.json"
      }

      assert {:error, message} = OutputFormatter.save_results(@test_result, config)
      assert String.contains?(message, "Failed to save output")
    end
  end

  describe "save_json_output/2" do
    setup do
      temp_dir = "test_json_#{:rand.uniform(1000)}"
      File.mkdir_p!(temp_dir)

      on_exit(fn ->
        File.rm_rf!(temp_dir)
      end)

      %{temp_dir: temp_dir}
    end

    test "creates valid JSON file", %{temp_dir: temp_dir} do
      file_path = Path.join(temp_dir, "test.json")

      assert OutputFormatter.save_json_output(@test_result, file_path) == :ok
      assert File.exists?(file_path)

      content = File.read!(file_path)
      assert {:ok, parsed} = Jason.decode(content)
      assert is_map(parsed)
    end
  end

  describe "generate_html_report/1" do
    test "generates valid HTML structure" do
      html = OutputFormatter.generate_html_report(@test_result)

      assert String.contains?(html, "<!DOCTYPE html>")
      assert String.contains?(html, "<html lang=\"en\">")
      assert String.contains?(html, "</html>")
      assert String.contains?(html, @test_result.analysis_timestamp)
    end

    test "includes analysis data in HTML" do
      html = OutputFormatter.generate_html_report(@test_result)

      assert String.contains?(html, "Architecture Decisions")
      assert String.contains?(html, "Code Examples")
    end
  end

  describe "generate_text_report/1" do
    test "generates formatted text report" do
      text = OutputFormatter.generate_text_report(@test_result)

      assert String.contains?(text, "ANALYSIS REPORT")
      assert String.contains?(text, @test_result.analysis_timestamp)
      assert String.contains?(text, "SUMMARY")
      assert String.contains?(text, "RECOMMENDATIONS")
    end

    test "handles missing data gracefully" do
      minimal_result = %{analysis_timestamp: "2023-01-01T00:00:00Z"}

      text = OutputFormatter.generate_text_report(minimal_result)

      assert String.contains?(text, "ANALYSIS REPORT")
      assert String.contains?(text, "2023-01-01T00:00:00Z")
    end
  end

  describe "format_ci_summary/2" do
    test "outputs CI summary to shell" do
      # Capture shell output
      captured_output = capture_io(fn ->
        OutputFormatter.format_ci_summary(@test_result, "test_task")
      end)

      assert String.contains?(captured_output, "CI_TEST_TASK_SUMMARY=")
      assert String.contains?(captured_output, "\"status\":\"success\"")
    end

    test "includes timestamp and metrics in CI summary" do
      captured_output = capture_io(fn ->
        OutputFormatter.format_ci_summary(@test_result, "analyze")
      end)

      assert String.contains?(captured_output, @test_result.analysis_timestamp)
      assert String.contains?(captured_output, "\"task\":\"analyze\"")
    end
  end

  # Helper function to capture IO output
  defp capture_io(fun) do
    original_stdout = Process.whereis(:standard_io)
    {:ok, capture_pid} = StringIO.open("")
    Process.register(capture_pid, :captured_io)

    try do
      Process.unregister(:standard_io)
      Process.register(capture_pid, :standard_io)
      fun.()

      {_, output} = StringIO.contents(capture_pid)
      output
    after
      Process.unregister(:standard_io)
      if Process.alive?(original_stdout) do
        Process.register(original_stdout, :standard_io)
      end
      StringIO.close(capture_pid)
    end
  end
end
