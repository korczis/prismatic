defmodule Prismatic.LLM.Impl.OpenAIBackendTest do
  @moduledoc """
  Comprehensive test suite for the OpenAI backend implementation.

  This module tests the OpenAI-specific functionality including API integration,
  request formatting, response parsing, error handling, and model-specific
  features like function calling and streaming.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Prismatic.TestHelpers
  import Prismatic.PropertyHelpers

  alias Prismatic.LLM.Impl.OpenAIBackend
  alias Prismatic.LLM.Backend.MetricsCollector

  # Set up mocks for each test
  setup :verify_on_exit!
  setup :setup_mocks

  # Mock HTTP client responses
  setup do
    # Mock successful OpenAI API response
    success_response = %{
      "choices" => [
        %{
          "message" => %{
            "content" => "This is a test response from OpenAI GPT-4.",
            "role" => "assistant"
          },
          "finish_reason" => "stop"
        }
      ],
      "usage" => %{
        "prompt_tokens" => 10,
        "completion_tokens" => 15,
        "total_tokens" => 25
      }
    }

    # Mock error response
    error_response = %{
      "error" => %{
        "message" => "Invalid API key provided",
        "type" => "invalid_request_error",
        "code" => "invalid_api_key"
      }
    }

    %{
      success_response: success_response,
      error_response: error_response
    }
  end

  describe "validate_config/1" do
    test "validates correct OpenAI configuration" do
      valid_config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890",
        model: "gpt-4",
        timeout: 30_000
      }

      assert :ok = OpenAIBackend.validate_config(valid_config)
    end

    test "rejects configuration with missing required fields" do
      # Missing backend_type
      config_no_type = %{
        api_key: "sk-test123456789012345678901234567890"
      }
      assert {:error, {:missing_required_fields, fields}} =
        OpenAIBackend.validate_config(config_no_type)
      assert :backend_type in fields

      # Missing api_key
      config_no_key = %{
        backend_type: :openai
      }
      assert {:error, {:missing_required_fields, fields}} =
        OpenAIBackend.validate_config(config_no_key)
      assert :api_key in fields
    end

    test "validates API key format" do
      # Invalid API key format - too short
      config_short_key = %{
        backend_type: :openai,
        api_key: "sk-short"
      }
      assert {:error, :invalid_api_key_format} =
        OpenAIBackend.validate_config(config_short_key)

      # Invalid API key format - wrong prefix
      config_wrong_prefix = %{
        backend_type: :openai,
        api_key: "invalid-test123456789012345678901234567890"
      }
      assert {:error, :invalid_api_key_format} =
        OpenAIBackend.validate_config(config_wrong_prefix)

      # Non-string API key
      config_non_string = %{
        backend_type: :openai,
        api_key: 12_345
      }
      assert {:error, :invalid_api_key_format} =
        OpenAIBackend.validate_config(config_non_string)
    end

    test "accepts valid API key formats" do
      valid_keys = [
        "sk-test123456789012345678901234567890",
        "sk-proj-abcdefghijklmnopqrstuvwxyz1234567890",
        "sk-" <> String.duplicate("a", 40)
      ]

      for api_key <- valid_keys do
        config = %{
          backend_type: :openai,
          api_key: api_key
        }
        assert :ok = OpenAIBackend.validate_config(config)
      end
    end
  end

  describe "generate_response/3" do
    test "generates response with valid configuration", %{success_response: response} do
      # Mock HTTP request
      expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890",
        model: "gpt-4"
      }

      assert {:ok, result} = OpenAIBackend.generate_response(config, "Hello", %{})
      assert result == "This is a test response from OpenAI GPT-4."
    end

    test "handles different context parameters", %{success_response: response} do
      expect(Req, :post, fn _url, opts ->
        # Verify request body contains context parameters
        body = Jason.decode!(opts[:body])

        assert body["temperature"] == 0.8
        assert body["max_tokens"] == 500
        assert body["model"] == "gpt-3.5-turbo"

        # Verify messages format
        messages = body["messages"]
        assert length(messages) == 2
        assert List.first(messages)["role"] == "system"
        assert List.last(messages)["role"] == "user"

        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890",
        model: "gpt-3.5-turbo"
      }

      context = %{
        temperature: 0.8,
        max_tokens: 500,
        system_message: "You are a helpful assistant."
      }

      assert {:ok, _result} = OpenAIBackend.generate_response(config, "Test prompt", context)
    end

    test "handles conversation history", %{success_response: response} do
      expect(Req, :post, fn _url, opts ->
        body = Jason.decode!(opts[:body])
        messages = body["messages"]

        # Should have system + history + current message
        assert length(messages) == 4
        assert Enum.at(messages, 0)["role"] == "system"
        assert Enum.at(messages, 1)["role"] == "user"
        assert Enum.at(messages, 2)["role"] == "assistant"
        assert Enum.at(messages, 3)["role"] == "user"

        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890"
      }

      context = %{
        system_message: "You are helpful.",
        conversation_history: [
          %{role: "user", content: "Previous question"},
          %{role: "assistant", content: "Previous answer"}
        ]
      }

      assert {:ok, _result} = OpenAIBackend.generate_response(config, "Current question", context)
    end

    test "handles streaming requests", %{success_response: response} do
      expect(Req, :post, fn _url, opts ->
        body = Jason.decode!(opts[:body])
        assert body["stream"] == true

        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890"
      }

      context = %{stream: true}

      assert {:ok, _result} = OpenAIBackend.generate_response(config, "Stream test", context)
    end

    test "handles function calling", %{success_response: response} do
      expect(Req, :post, fn _url, opts ->
        body = Jason.decode!(opts[:body])
        assert Map.has_key?(body, "functions")
        assert is_list(body["functions"])

        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890"
      }

      context = %{
        functions: [
          %{
            name: "get_weather",
            description: "Get weather information",
            parameters: %{
              type: "object",
              properties: %{
                location: %{type: "string"}
              }
            }
          }
        ]
      }

      assert {:ok, _result} = OpenAIBackend.generate_response(config, "What's the weather?", context)
    end

    test "handles user ID parameter", %{success_response: response} do
      expect(Req, :post, fn _url, opts ->
        body = Jason.decode!(opts[:body])
        assert body["user"] == "user-123"

        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890"
      }

      context = %{user_id: "user-123"}

      assert {:ok, _result} = OpenAIBackend.generate_response(config, "Test", context)
    end

    test "handles API errors", %{error_response: error_response} do
      expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 401, body: error_response}}
      end)

      config = %{
        backend_type: :openai,
        api_key: "sk-invalid123456789012345678901234567890"
      }

      assert {:error, {:api_error, 401, ^error_response}} =
        OpenAIBackend.generate_response(config, "Test", %{})
    end

    test "handles network errors" do
      expect(Req, :post, fn _url, _opts ->
        {:error, :timeout}
      end)

      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890"
      }

      assert {:error, {:request_failed, :timeout}} =
        OpenAIBackend.generate_response(config, "Test", %{})
    end

    test "validates configuration before making request" do
      invalid_config = %{
        backend_type: :openai,
        api_key: "invalid"
      }

      assert {:error, :invalid_api_key_format} =
        OpenAIBackend.generate_response(invalid_config, "Test", %{})
    end

    test "uses custom base URL when provided", %{success_response: response} do
      expect(Req, :post, fn url, _opts ->
        assert String.starts_with?(url, "https://custom-api.example.com")
        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890",
        base_url: "https://custom-api.example.com/v1"
      }

      assert {:ok, _result} = OpenAIBackend.generate_response(config, "Test", %{})
    end

    test "includes proper headers in requests", %{success_response: response} do
      expect(Req, :post, fn _url, opts ->
        headers = opts[:headers]

        assert {"Authorization", "Bearer sk-test123456789012345678901234567890"} in headers
        assert {"Content-Type", "application/json"} in headers
        assert {"User-Agent", "Prismatic-AI-Framework/1.0"} in headers

        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890"
      }

      assert {:ok, _result} = OpenAIBackend.generate_response(config, "Test", %{})
    end
  end

  describe "health_check/1" do
    test "performs successful health check", %{success_response: response} do
      expect(Req, :post, fn _url, opts ->
        # Verify it's a minimal test request
        body = Jason.decode!(opts[:body])
        assert body["max_tokens"] == 1
        assert body["messages"] == [%{"role" => "user", "content" => "test"}]

        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890"
      }

      assert :ok = OpenAIBackend.health_check(config)
    end

    test "detects unhealthy backend", %{error_response: error_response} do
      expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 503, body: error_response}}
      end)

      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890"
      }

      assert {:error, {:health_check_failed, {:api_error, 503, ^error_response}}} =
        OpenAIBackend.health_check(config)
    end

    test "validates configuration before health check" do
      invalid_config = %{
        backend_type: :openai,
        api_key: "invalid"
      }

      assert {:error, :invalid_api_key_format} =
        OpenAIBackend.health_check(invalid_config)
    end
  end

  describe "get_model_info/1" do
    test "returns correct model information for different models" do
      test_cases = [
        {"gpt-4", 8192, 0.00003, [:chat, :function_calling, :json_mode, :vision]},
        {"gpt-4-32k", 32_768, 0.00006, [:chat]},
        {"gpt-3.5-turbo", 4096, 0.000002, [:chat, :function_calling, :json_mode]},
        {"gpt-3.5-turbo-16k", 16_384, 0.000004, [:chat]},
        {"unknown-model", 4096, 0.00002, [:chat]}
      ]

      for {model, expected_tokens, expected_cost, expected_capabilities} <- test_cases do
        config = %{
          backend_type: :openai,
          api_key: "sk-test123456789012345678901234567890",
          model: model
        }

        assert {:ok, info} = OpenAIBackend.get_model_info(config)
        assert info.name == model
        assert info.max_tokens == expected_tokens
        assert info.cost_per_token == expected_cost
        assert info.capabilities == expected_capabilities
        assert info.provider == :openai
        assert info.supports_streaming == true
      end
    end

    test "uses default model when not specified" do
      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890"
      }

      assert {:ok, info} = OpenAIBackend.get_model_info(config)
      assert info.name == "gpt-4"
      assert info.max_tokens == 8192
    end

    test "returns consistent model info structure" do
      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890"
      }

      assert {:ok, info} = OpenAIBackend.get_model_info(config)

      # Verify all required fields are present
      assert Map.has_key?(info, :name)
      assert Map.has_key?(info, :max_tokens)
      assert Map.has_key?(info, :supports_streaming)
      assert Map.has_key?(info, :cost_per_token)
      assert Map.has_key?(info, :provider)
      assert Map.has_key?(info, :capabilities)

      # Verify field types
      assert is_binary(info.name)
      assert is_integer(info.max_tokens)
      assert is_boolean(info.supports_streaming)
      assert is_number(info.cost_per_token)
      assert is_atom(info.provider)
      assert is_list(info.capabilities)
    end
  end

  describe "response parsing" do
    test "parses successful response correctly" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "content" => "Parsed response content",
              "role" => "assistant"
            }
          }
        ]
      }

      expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890"
      }

      assert {:ok, "Parsed response content"} =
        OpenAIBackend.generate_response(config, "Test", %{})
    end

    test "handles response with whitespace" do
      response = %{
        "choices" => [
          %{
            "message" => %{
              "content" => "  \n  Response with whitespace  \n  ",
              "role" => "assistant"
            }
          }
        ]
      }

      expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890"
      }

      assert {:ok, "Response with whitespace"} =
        OpenAIBackend.generate_response(config, "Test", %{})
    end

    test "handles API error response" do
      error_response = %{
        "error" => %{
          "message" => "Rate limit exceeded",
          "type" => "rate_limit_error"
        }
      }

      expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 429, body: error_response}}
      end)

      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890"
      }

      assert {:error, {:api_error, 429, ^error_response}} =
        OpenAIBackend.generate_response(config, "Test", %{})
    end

    test "handles malformed response" do
      malformed_response = %{
        "invalid" => "structure"
      }

      expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 200, body: malformed_response}}
      end)

      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890"
      }

      assert {:error, {:invalid_response_format, ^malformed_response}} =
        OpenAIBackend.generate_response(config, "Test", %{})
    end
  end

  # Property-based tests
  describe "property-based tests" do
    property "validate_config is consistent for valid configurations" do
      check all api_key <- string(:alphanumeric, min_length: 25, max_length: 100),
                model <- member_of(["gpt-4", "gpt-3.5-turbo", "gpt-4-32k"]) do

        config = %{
          backend_type: :openai,
          api_key: "sk-" <> api_key,
          model: model
        }

        result1 = OpenAIBackend.validate_config(config)
        result2 = OpenAIBackend.validate_config(config)

        assert result1 == result2
        assert result1 == :ok
      end
    end

    property "get_model_info returns consistent structure" do
      check all model <- member_of(["gpt-4", "gpt-3.5-turbo", "custom-model"]) do
        config = %{
          backend_type: :openai,
          api_key: "sk-test123456789012345678901234567890",
          model: model
        }

        assert {:ok, info} = OpenAIBackend.get_model_info(config)
        assert info.provider == :openai
        assert is_binary(info.name)
        assert is_integer(info.max_tokens)
        assert info.max_tokens > 0
        assert is_number(info.cost_per_token)
        assert info.cost_per_token >= 0
      end
    end
  end

  describe "integration with supporting modules" do
    test "integrates with circuit breaker" do
      # Mock failing requests to trip circuit breaker
      expect(Req, :post, 6, fn _url, _opts ->
        {:error, :timeout}
      end)

      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890"
      }

      # Make requests until circuit breaker opens
      for _i <- 1..6 do
        OpenAIBackend.generate_response(config, "Test", %{})
      end

      # Next request should be rejected by circuit breaker
      assert {:error, :circuit_breaker_open} =
        OpenAIBackend.generate_response(config, "Test", %{})
    end

    test "integrates with retry logic" do
      # Mock request that succeeds on retry
      expect(Req, :post, 2, fn _url, _opts ->
        case Process.get(:attempt_count, 0) do
          0 ->
            Process.put(:attempt_count, 1)
            {:error, :timeout}
          _ ->
            {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => "Success"}}]}}}
        end
      end)

      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890",
        max_retries: 2
      }

      assert {:ok, "Success"} = OpenAIBackend.generate_response(config, "Test", %{})
    end

    test "integrates with metrics collection" do
      expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => "Test"}}]}}}
      end)

      config = %{
        backend_type: :openai,
        api_key: "sk-test123456789012345678901234567890"
      }

      # Record initial metrics
      initial_metrics = MetricsCollector.get_metrics(:openai)

      # Make request
      OpenAIBackend.generate_response(config, "Test", %{})

      # Verify metrics were updated
      final_metrics = MetricsCollector.get_metrics(:openai)
      assert final_metrics.total_requests > initial_metrics.total_requests
    end
  end

  # Doctests
  doctest OpenAIBackend, import: true
end
