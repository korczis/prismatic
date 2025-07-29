defmodule Mix.Tasks.Docs.Shared.ConfigTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Docs.Shared.Config

  describe "defaults/0" do
    test "returns expected default configuration" do
      defaults = Config.defaults()

      assert defaults.docs_path == "docs"
      assert defaults.code_path == "apps"
      assert defaults.output_format == "json"
      assert defaults.output_file == nil
      assert defaults.ci_mode == false
      assert defaults.verbose == false
    end
  end

  describe "output_formats/0" do
    test "returns all supported output formats" do
      formats = Config.output_formats()

      assert "json" in formats
      assert "yaml" in formats
      assert "html" in formats
      assert "report" in formats
      assert length(formats) == 4
    end
  end

  describe "normalize_config/2" do
    test "merges user options with defaults" do
      options = [docs: "documentation", verbose: true]

      config = Config.normalize_config(options)

      assert config.docs_path == "documentation"
      assert config.code_path == "apps"  # default
      assert config.verbose == true
      assert config.ci_mode == false  # default
    end

    test "merges with task-specific defaults" do
      options = [output: "yaml"]
      task_defaults = %{file_prefix: "test-analysis", special_option: true}

      config = Config.normalize_config(options, task_defaults)

      assert config.output_format == "yaml"
      assert config.special_option == true
      assert String.contains?(config.output_file, "test-analysis")
    end

    test "generates output filename when not provided" do
      options = [output: "html"]

      config = Config.normalize_config(options)

      assert String.ends_with?(config.output_file, ".html")
      assert String.contains?(config.output_file, "docs-analysis")
    end
  end

  describe "validate_config/1" do
    setup do
      # Create temporary directories for testing
      docs_dir = "test_docs_#{:rand.uniform(1000)}"
      code_dir = "test_code_#{:rand.uniform(1000)}"
      File.mkdir_p!(docs_dir)
      File.mkdir_p!(code_dir)

      on_exit(fn ->
        File.rm_rf!(docs_dir)
        File.rm_rf!(code_dir)
      end)

      %{docs_dir: docs_dir, code_dir: code_dir}
    end

    test "returns :ok for valid configuration", %{docs_dir: docs_dir, code_dir: code_dir} do
      config = %{
        docs_path: docs_dir,
        code_path: code_dir,
        output_format: "json",
        output_file: "test.json"
      }

      assert Config.validate_config(config) == :ok
    end

    test "returns error for non-existent docs directory" do
      config = %{
        docs_path: "non_existent_dir",
        code_path: "apps",
        output_format: "json",
        output_file: "test.json"
      }

      assert {:error, message} = Config.validate_config(config)
      assert String.contains?(message, "Documentation directory")
    end

    test "returns error for invalid output format" do
      config = %{
        docs_path: "docs",
        output_format: "invalid_format",
        output_file: "test.json"
      }

      assert {:error, message} = Config.validate_config(config)
      assert String.contains?(message, "Invalid output format")
    end
  end

  describe "generate_output_filename/2" do
    test "generates filename with correct extension" do
      filename = Config.generate_output_filename("json", "test-prefix")

      assert String.ends_with?(filename, ".json")
      assert String.contains?(filename, "test-prefix")
    end

    test "handles different formats" do
      assert String.ends_with?(Config.generate_output_filename("yaml", "test"), ".yaml")
      assert String.ends_with?(Config.generate_output_filename("html", "test"), ".html")
      assert String.ends_with?(Config.generate_output_filename("report", "test"), ".txt")
      assert String.ends_with?(Config.generate_output_filename("unknown", "test"), ".txt")
    end

    test "includes timestamp in filename" do
      filename1 = Config.generate_output_filename("json", "test")
      :timer.sleep(10)  # Ensure different timestamp
      filename2 = Config.generate_output_filename("json", "test")

      assert filename1 != filename2
    end
  end

  describe "format_to_extension/1" do
    test "returns correct extensions for supported formats" do
      assert Config.format_to_extension("json") == "json"
      assert Config.format_to_extension("yaml") == "yaml"
      assert Config.format_to_extension("html") == "html"
      assert Config.format_to_extension("report") == "txt"
      assert Config.format_to_extension("unknown") == "txt"
    end
  end

  describe "display_config/2" do
    test "displays configuration without errors" do
      config = %{
        docs_path: "docs",
        code_path: "apps",
        output_format: "json",
        output_file: "test.json",
        ci_mode: false,
        verbose: true
      }

      # Should not raise any errors
      assert Config.display_config(config, "test task") == :ok
    end
  end
end
