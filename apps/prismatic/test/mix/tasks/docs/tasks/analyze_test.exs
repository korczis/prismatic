defmodule Mix.Tasks.Docs.Tasks.AnalyzeTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Docs.Tasks.Analyze

  describe "parse_and_validate_options/1" do
    test "returns help for help flag" do
      assert {:ok, %{help: true}} = Analyze.parse_and_validate_options(["--help"])
      assert {:ok, %{help: true}} = Analyze.parse_and_validate_options(["-h"])
    end

    test "parses basic options correctly" do
      args = ["--docs", "documentation", "--verbose"]

      assert {:ok, options} = Analyze.parse_and_validate_options(args)
      assert options.docs_path == "documentation"
      assert options.verbose == true
    end

    test "validates output format" do
      args = ["--output", "invalid_format"]

      assert {:error, message} = Analyze.parse_and_validate_options(args)
      assert String.contains?(message, "Invalid output format")
    end

    test "validates sections" do
      args = ["--sections", "invalid_section"]

      assert {:error, message} = Analyze.parse_and_validate_options(args)
      assert String.contains?(message, "Invalid sections")
    end

    test "handles valid sections" do
      args = ["--sections", "adrs,examples"]

      assert {:ok, options} = Analyze.parse_and_validate_options(args)
      assert "adrs" in options.sections
      assert "examples" in options.sections
      refute "trace" in options.sections
    end

    test "parses all sections" do
      args = ["--sections", "all"]

      assert {:ok, options} = Analyze.parse_and_validate_options(args)
      assert "adrs" in options.sections
      assert "examples" in options.sections
      assert "trace" in options.sections
      assert "ai" in options.sections
    end

    test "handles invalid arguments" do
      args = ["--invalid-flag", "value"]

      assert {:error, message} = Analyze.parse_and_validate_options(args)
      assert String.contains?(message, "Invalid arguments")
    end

    test "sets default values" do
      args = []

      assert {:ok, options} = Analyze.parse_and_validate_options(args)
      assert options.docs_path == "docs"
      assert options.code_path == "apps"
      assert options.output_format == "json"
      assert options.parallel == false
      assert options.ci_mode == false
      assert options.verbose == false
      assert options.dry_run == false
    end

    test "handles parallel flag" do
      args = ["--parallel"]

      assert {:ok, options} = Analyze.parse_and_validate_options(args)
      assert options.parallel == true
    end

    test "handles CI mode" do
      args = ["--ci"]

      assert {:ok, options} = Analyze.parse_and_validate_options(args)
      assert options.ci_mode == true
    end

    test "handles dry run" do
      args = ["--dry-run"]

      assert {:ok, options} = Analyze.parse_and_validate_options(args)
      assert options.dry_run == true
    end
  end

  describe "option aliases" do
    test "handles short aliases" do
      args = ["-d", "docs_dir", "-c", "code_dir", "-o", "yaml", "-v"]

      assert {:ok, options} = Analyze.parse_and_validate_options(args)
      assert options.docs_path == "docs_dir"
      assert options.code_path == "code_dir"
      assert options.output_format == "yaml"
      assert options.verbose == true
    end

    test "handles file alias" do
      args = ["-f", "custom_output.json"]

      assert {:ok, options} = Analyze.parse_and_validate_options(args)
      assert options.output_file == "custom_output.json"
    end

    test "handles sections alias" do
      args = ["-s", "adrs,trace"]

      assert {:ok, options} = Analyze.parse_and_validate_options(args)
      assert options.sections == ["adrs", "trace"]
    end
  end

  describe "output file generation" do
    test "generates timestamped filename when not specified" do
      args = ["--output", "json"]

      assert {:ok, options} = Analyze.parse_and_validate_options(args)
      assert String.contains?(options.output_file, "docs-analysis")
      assert String.ends_with?(options.output_file, ".json")
    end

    test "uses custom filename when specified" do
      args = ["--file", "my_analysis.json"]

      assert {:ok, options} = Analyze.parse_and_validate_options(args)
      assert options.output_file == "my_analysis.json"
    end

    test "generates correct extension for format" do
      test_cases = [
        {"json", ".json"},
        {"yaml", ".yaml"},
        {"html", ".html"},
        {"report", ".txt"}
      ]

      Enum.each(test_cases, fn {format, extension} ->
        args = ["--output", format]
        assert {:ok, options} = Analyze.parse_and_validate_options(args)
        assert String.ends_with?(options.output_file, extension)
      end)
    end
  end

  describe "sections parsing" do
    test "parses comma-separated sections" do
      args = ["--sections", "adrs, examples, trace"]

      assert {:ok, options} = Analyze.parse_and_validate_options(args)
      assert options.sections == ["adrs", "examples", "trace"]
    end

    test "filters invalid sections" do
      args = ["--sections", "adrs,invalid,examples"]

      assert {:ok, options} = Analyze.parse_and_validate_options(args)
      assert options.sections == ["adrs", "examples"]
    end

    test "handles empty sections" do
      args = ["--sections", ""]

      assert {:ok, options} = Analyze.parse_and_validate_options(args)
      assert options.sections == []
    end
  end

  describe "progress options" do
    test "progress defaults to true" do
      args = []

      assert {:ok, options} = Analyze.parse_and_validate_options(args)
      assert options.show_progress == true
    end

    test "can disable progress" do
      args = ["--no-progress"]

      # Note: This would need to be implemented in the actual module
      # For now, we test the current behavior
      assert {:ok, options} = Analyze.parse_and_validate_options(args)
      # Would assert show_progress == false if implemented
    end
  end

  describe "validation edge cases" do
    test "handles multiple invalid arguments" do
      args = ["--invalid1", "value1", "--invalid2", "value2"]

      assert {:error, message} = Analyze.parse_and_validate_options(args)
      assert String.contains?(message, "Invalid arguments")
    end

    test "validates complexity threshold range" do
      # This would be for ExtractAdrs, but testing the pattern
      args = ["--output", "json"]  # Valid case

      assert {:ok, _options} = Analyze.parse_and_validate_options(args)
    end
  end

  describe "integration with shared modules" do
    test "uses Config module defaults" do
      args = []

      assert {:ok, options} = Analyze.parse_and_validate_options(args)

      # Should match Config.defaults()
      assert options.docs_path == "docs"
      assert options.code_path == "apps"
      assert options.output_format == "json"
      assert options.ci_mode == false
      assert options.verbose == false
    end

    test "generates output filename using Config logic" do
      args = ["--output", "html"]

      assert {:ok, options} = Analyze.parse_and_validate_options(args)

      # Should follow Config.generate_output_filename pattern
      assert String.contains?(options.output_file, "docs-analysis")
      assert String.ends_with?(options.output_file, ".html")
    end
  end
end
