defmodule Prismatic.DocumentationTest do
  use ExUnit.Case, async: true
  alias Prismatic.Documentation

  describe "extract_all_adrs/1" do
    test "returns structured ADR data" do
      # Create a temporary test directory structure
      test_dir = setup_test_docs()

      result = Documentation.extract_all_adrs(test_dir)

      assert is_map(result)
      assert Map.has_key?(result, :summary)
      assert Map.has_key?(result, :adrs)
      assert Map.has_key?(result, :categorization)
      assert Map.has_key?(result, :relationships)
      assert Map.has_key?(result, :lifecycle)

      cleanup_test_docs(test_dir)
    end
  end

  describe "extract_code_examples/1" do
    test "returns structured code examples data" do
      test_dir = setup_test_docs()

      result = Documentation.extract_code_examples(test_dir)

      assert is_map(result)
      assert Map.has_key?(result, :summary)
      assert Map.has_key?(result, :examples)
      assert Map.has_key?(result, :categorization)
      assert Map.has_key?(result, :transformations)
      assert Map.has_key?(result, :validation)

      cleanup_test_docs(test_dir)
    end
  end

  describe "generate_traceability_markers/2" do
    test "returns traceability analysis" do
      docs_dir = setup_test_docs()
      code_dir = setup_test_code()

      result = Documentation.generate_traceability_markers(docs_dir, code_dir)

      assert is_map(result)
      assert Map.has_key?(result, :summary)
      assert Map.has_key?(result, :documentation_references)
      assert Map.has_key?(result, :code_references)
      assert Map.has_key?(result, :bidirectional_links)

      cleanup_test_docs(docs_dir)
      cleanup_test_docs(code_dir)
    end
  end

  describe "generate_ai_data/1" do
    test "returns AI-structured data" do
      test_dir = setup_test_docs()

      result = Documentation.generate_ai_data(test_dir)

      assert is_map(result)
      assert Map.has_key?(result, :metadata)
      assert Map.has_key?(result, :schema_version)
      assert Map.has_key?(result, :generation_timestamp)

      cleanup_test_docs(test_dir)
    end
  end

  describe "comprehensive_analysis/2" do
    test "returns complete analysis structure" do
      docs_dir = setup_test_docs()
      code_dir = setup_test_code()

      result = Documentation.comprehensive_analysis(docs_dir, code_dir)

      assert is_map(result)
      assert Map.has_key?(result, :adrs)
      assert Map.has_key?(result, :code_examples)
      assert Map.has_key?(result, :traceability)
      assert Map.has_key?(result, :ai_data)
      assert Map.has_key?(result, :analysis_timestamp)
      assert Map.has_key?(result, :analysis_version)

      assert result.analysis_version == "1.0.0"

      cleanup_test_docs(docs_dir)
      cleanup_test_docs(code_dir)
    end
  end

  # Helper functions for test setup
  defp setup_test_docs do
    test_dir = System.tmp_dir!() |> Path.join("test_docs_#{:rand.uniform(10000)}")
    File.mkdir_p!(test_dir)

    # Create a sample ADR file
    adr_content = """
    # ADR-0001: Test Decision

    **Status**: Accepted
    **Date**: 2024-01-15

    ## Summary
    This is a test ADR for unit testing purposes.

    ## Context
    We need to test the ADR extraction functionality.

    ## Decision
    We will use this test ADR to validate the extraction process.

    ## Consequences

    ### Positive Consequences
    - Tests pass successfully
    - Extraction works correctly

    ### Negative Consequences
    - Additional test maintenance
    """

    File.write!(Path.join(test_dir, "adr-0001-test-decision.md"), adr_content)

    # Create a sample documentation file with code examples
    doc_content = """
    # Test Documentation

    This is a test documentation file.

    ## Code Example

    ```elixir
    defmodule TestModule do
      def test_function do
        :ok
      end
    end
    ```

    ## Inline Code

    Use `TestModule.test_function()` to test the functionality.

    ## Configuration

    ```json
    {
      "test": true,
      "value": 42
    }
    ```
    """

    File.write!(Path.join(test_dir, "test-doc.md"), doc_content)

    test_dir
  end

  defp setup_test_code do
    test_dir = System.tmp_dir!() |> Path.join("test_code_#{:rand.uniform(10000)}")
    File.mkdir_p!(test_dir)

    # Create a sample Elixir module
    code_content = """
    defmodule TestModule do
      @moduledoc \"\"\"
      Test module for documentation analysis.
      \"\"\"

      @doc \"\"\"
      Test function that returns :ok.
      \"\"\"
      def test_function do
        :ok
      end

      defp private_function do
        :private
      end
    end
    """

    File.write!(Path.join(test_dir, "test_module.ex"), code_content)

    test_dir
  end

  defp cleanup_test_docs(test_dir) do
    if File.exists?(test_dir) do
      File.rm_rf!(test_dir)
    end
  end
end
