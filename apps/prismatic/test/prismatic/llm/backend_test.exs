defmodule Prismatic.LLM.BackendTest do
  use ExUnit.Case, async: true

  alias Prismatic.LLM.Backend
  alias Prismatic.LLM.Impl.TestBackend

  @moduletag :llm

  describe "Backend behavior" do
    test "TestBackend implements all required callbacks" do
      # Verify that TestBackend implements the Backend behavior
      assert function_exported?(TestBackend, :generate_response, 3)
      assert function_exported?(TestBackend, :validate_config, 1)
      assert function_exported?(TestBackend, :health_check, 1)
      assert function_exported?(TestBackend, :get_model_info, 1)
    end

    test "generate_response/3 returns expected format" do
      config = %{backend_type: :test, api_key: "test-key"}
      prompt = "Hello, world!"
      context = %{}

      result = TestBackend.generate_response(config, prompt, context)

      assert match?({:ok, response} when is_binary(response), result)
    end

    test "generate_response/3 with context" do
      config = %{backend_type: :test, api_key: "test-key"}
      prompt = "Hello"
      context = %{temperature: 0.5, max_tokens: 100}

      result = TestBackend.generate_response(config, prompt, context)

      assert match?({:ok, response} when is_binary(response), result)
    end

    test "validate_config/1 validates required fields" do
      valid_config = %{backend_type: :test, api_key: "test-key"}
      assert TestBackend.validate_config(valid_config) == :ok

      invalid_config = %{backend_type: :test}
      assert match?({:error, _}, TestBackend.validate_config(invalid_config))
    end

    test "health_check/1 returns status" do
      config = %{backend_type: :test, api_key: "test-key"}

      result = TestBackend.health_check(config)

      assert result == :ok
    end

    test "get_model_info/1 returns model information" do
      config = %{backend_type: :test, api_key: "test-key"}

      result = TestBackend.get_model_info(config)

      assert match?({:ok, %{name: _, provider: :test}}, result)
    end

    test "generate_response/3 handles error simulation" do
      config = %{backend_type: :test, api_key: "test-key"}
      prompt = "ERROR"  # Special prompt that triggers error in TestBackend
      context = %{}

      result = TestBackend.generate_response(config, prompt, context)

      assert match?({:error, _}, result)
    end
  end

  describe "Backend contract validation" do
    test "all backends should handle invalid configurations gracefully" do
      invalid_configs = [
        %{},  # Empty config
        %{backend_type: :test},  # Missing api_key
        %{api_key: "test"},  # Missing backend_type
        %{backend_type: :invalid, api_key: "test"}  # Invalid backend_type
      ]

      for config <- invalid_configs do
        result = TestBackend.validate_config(config)
        assert match?({:error, _}, result), "Config #{inspect(config)} should be invalid"
      end
    end

    test "backends should handle empty or nil prompts gracefully" do
      config = %{backend_type: :test, api_key: "test-key"}

      # Empty string
      result = TestBackend.generate_response(config, "", %{})
      assert match?({:ok, _} or {:error, _}, result)

      # This would cause an error due to pattern matching, but we test error handling
      assert_raise FunctionClauseError, fn ->
        TestBackend.generate_response(config, nil, %{})
      end
    end
  end
end
