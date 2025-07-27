defmodule Prismatic.LLM.Impl.AnthropicBackendTest do
  @moduledoc """
  Comprehensive test suite for the Anthropic backend implementation.

  This module tests the Anthropic-specific functionality including API integration,
  request formatting, response parsing, error handling, and Claude model-specific
  features like system messages and stop sequences.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Prismatic.TestHelpers
  import Prismatic.PropertyHelpers

  alias Prismatic.LLM.Impl.AnthropicBackend
  alias Prismatic.LLM.Backend.{CircuitBreaker, MetricsCollector, RetryLogic}

  # Set up mocks for each test
  setup :verify_on_exit!
  setup :setup_mocks

  # Mock HTTP client responses
  setup do
    # Mock successful Anthropic API response
    success_response = %{
      "content" => [
        %{
          "text" => "This is a test response from Claude.",
          "type" => "text"
        }
      ],
      "id" => "msg_test123",
      "model" => "claude-3-sonnet-20240229",
      "role" => "assistant",
      "stop_reason" => "end_turn",
      "stop_sequence" => nil,
      "type" => "message",
      "usage" => %{
        "input_tokens" => 12,
        "output_tokens" => 18
      }
    }

    # Mock error response
    error_response = %{
      "error" => %{
        "type" => "authentication_error",
        "message" => "Invalid API key"
      }
    }

    %{
      success_response: success_response,
      error_response: error_response
    }
  end

  describe "validate_config/1" do
    test "validates correct Anthropic configuration" do
      valid_config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890",
        model: "claude-3-sonnet-20240229",
        timeout: 30_000
      }

      assert :ok = AnthropicBackend.validate_config(valid_config)
    end

    test "rejects configuration with missing required fields" do
      # Missing backend_type
      config_no_type = %{
        api_key: "sk-ant-test123456789012345678901234567890"
      }
      assert {:error, {:missing_required_fields, fields}} =
        AnthropicBackend.validate_config(config_no_type)
      assert :backend_type in fields

      # Missing api_key
      config_no_key = %{
        backend_type: :anthropic
      }
      assert {:error, {:missing_required_fields, fields}} =
        AnthropicBackend.validate_config(config_no_key)
      assert :api_key in fields
    end

    test "validates API key format" do
      # Invalid API key format - too short
      config_short_key = %{
        backend_type: :anthropic,
        api_key: "sk-ant-short"
      }
      assert {:error, :invalid_api_key_format} =
        AnthropicBackend.validate_config(config_short_key)

      # Invalid API key format - wrong prefix
      config_wrong_prefix = %{
        backend_type: :anthropic,
        api_key: "sk-test123456789012345678901234567890"
      }
      assert {:error, :invalid_api_key_format} =
        AnthropicBackend.validate_config(config_wrong_prefix)

      # Non-string API key
      config_non_string = %{
        backend_type: :anthropic,
        api_key: 12_345
      }
      assert {:error, :invalid_api_key_format} =
        AnthropicBackend.validate_config(config_non_string)
    end

    test "accepts valid API key formats" do
      valid_keys = [
        "sk-ant-test123456789012345678901234567890",
        "sk-ant-api03-" <> String.duplicate("a", 40),
        "sk-ant-" <> String.duplicate("x", 50)
      ]

      for api_key <- valid_keys do
        config = %{
          backend_type: :anthropic,
          api_key: api_key
        }
        assert :ok = AnthropicBackend.validate_config(config)
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
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890",
        model: "claude-3-sonnet-20240229"
      }

      assert {:ok, result} = AnthropicBackend.generate_response(config, "Hello", %{})
      assert result == "This is a test response from Claude."
    end

    test "handles different context parameters", %{success_response: response} do
      expect(Req, :post, fn _url, opts ->
        # Verify request body contains context parameters
        body = Jason.decode!(opts[:body])

        assert body["temperature"] == 0.8
        assert body["max_tokens"] == 500
        assert body["model"] == "claude-3-haiku-20240307"

        # Verify messages format
        messages = body["messages"]
        assert length(messages) == 1
        assert List.first(messages)["role"] == "user"

        # Verify system message is separate
        assert body["system"] == "You are a helpful assistant."

        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890",
        model: "claude-3-haiku-20240307"
      }

      context = %{
        temperature: 0.8,
        max_tokens: 500,
        system_message: "You are a helpful assistant."
      }

      assert {:ok, _result} = AnthropicBackend.generate_response(config, "Test prompt", context)
    end

    test "handles conversation history", %{success_response: response} do
      expect(Req, :post, fn _url, opts ->
        body = Jason.decode!(opts[:body])
        messages = body["messages"]

        # Should have history + current message
        assert length(messages) == 3
        assert Enum.at(messages, 0)["role"] == "user"
        assert Enum.at(messages, 1)["role"] == "assistant"
        assert Enum.at(messages, 2)["role"] == "user"

        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      context = %{
        conversation_history: [
          %{role: "user", content: "Previous question"},
          %{role: "assistant", content: "Previous answer"}
        ]
      }

      assert {:ok, _result} = AnthropicBackend.generate_response(config, "Current question", context)
    end

    test "handles streaming requests", %{success_response: response} do
      expect(Req, :post, fn _url, opts ->
        body = Jason.decode!(opts[:body])
        assert body["stream"] == true

        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      context = %{stream: true}

      assert {:ok, _result} = AnthropicBackend.generate_response(config, "Stream test", context)
    end

    test "handles stop sequences", %{success_response: response} do
      expect(Req, :post, fn _url, opts ->
        body = Jason.decode!(opts[:body])
        assert body["stop_sequences"] == ["STOP", "END"]

        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      context = %{
        stop_sequences: ["STOP", "END"]
      }

      assert {:ok, _result} = AnthropicBackend.generate_response(config, "Test with stops", context)
    end

    test "handles API errors", %{error_response: error_response} do
      expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 401, body: error_response}}
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-invalid123456789012345678901234567890"
      }

      assert {:error, {:api_error, 401, ^error_response}} =
        AnthropicBackend.generate_response(config, "Test", %{})
    end

    test "handles network errors" do
      expect(Req, :post, fn _url, _opts ->
        {:error, :timeout}
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      assert {:error, {:request_failed, :timeout}} =
        AnthropicBackend.generate_response(config, "Test", %{})
    end

    test "validates configuration before making request" do
      invalid_config = %{
        backend_type: :anthropic,
        api_key: "invalid"
      }

      assert {:error, :invalid_api_key_format} =
        AnthropicBackend.generate_response(invalid_config, "Test", %{})
    end

    test "uses custom base URL when provided", %{success_response: response} do
      expect(Req, :post, fn url, _opts ->
        assert String.starts_with?(url, "https://custom-anthropic.example.com")
        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890",
        base_url: "https://custom-anthropic.example.com"
      }

      assert {:ok, _result} = AnthropicBackend.generate_response(config, "Test", %{})
    end

    test "includes proper headers in requests", %{success_response: response} do
      expect(Req, :post, fn _url, opts ->
        headers = opts[:headers]

        assert {"x-api-key", "sk-ant-test123456789012345678901234567890"} in headers
        assert {"anthropic-version", "2023-06-01"} in headers
        assert {"Content-Type", "application/json"} in headers
        assert {"User-Agent", "Prismatic-AI-Framework/1.0"} in headers

        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      assert {:ok, _result} = AnthropicBackend.generate_response(config, "Test", %{})
    end

    test "uses correct API endpoint" do
      expect(Req, :post, fn url, _opts ->
        assert String.ends_with?(url, "/v1/messages")
        {:ok, %{status: 200, body: %{"content" => [%{"text" => "test"}]}}}
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      assert {:ok, _result} = AnthropicBackend.generate_response(config, "Test", %{})
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
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      assert :ok = AnthropicBackend.health_check(config)
    end

    test "detects unhealthy backend", %{error_response: error_response} do
      expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 503, body: error_response}}
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      assert {:error, {:health_check_failed, {:api_error, 503, ^error_response}}} =
        AnthropicBackend.health_check(config)
    end

    test "validates configuration before health check" do
      invalid_config = %{
        backend_type: :anthropic,
        api_key: "invalid"
      }

      assert {:error, :invalid_api_key_format} =
        AnthropicBackend.health_check(invalid_config)
    end
  end

  describe "get_model_info/1" do
    test "returns correct model information for different Claude models" do
      test_cases = [
        {"claude-3-opus-20240229", 200_000, 0.000015, [:chat, :vision, :document_analysis, :code_generation, :reasoning]},
        {"claude-3-sonnet-20240229", 200_000, 0.000003, [:chat, :vision, :document_analysis, :code_generation, :reasoning]},
        {"claude-3-haiku-20240307", 200_000, 0.00000025, [:chat, :document_analysis, :code_generation]},
        {"claude-2.1", 200_000, 0.000008, [:chat, :document_analysis]},
        {"claude-2.0", 100_000, 0.000008, [:chat, :document_analysis]},
        {"claude-instant-1.2", 100_000, 0.0000008, [:chat, :document_analysis]},
        {"unknown-claude-model", 100_000, 0.000008, [:chat, :document_analysis]}
      ]

      for {model, expected_tokens, expected_cost, expected_capabilities} <- test_cases do
        config = %{
          backend_type: :anthropic,
          api_key: "sk-ant-test123456789012345678901234567890",
          model: model
        }

        assert {:ok, info} = AnthropicBackend.get_model_info(config)
        assert info.name == model
        assert info.max_tokens == expected_tokens
        assert info.cost_per_token == expected_cost
        assert info.capabilities == expected_capabilities
        assert info.provider == :anthropic
        assert info.supports_streaming == true
      end
    end

    test "uses default model when not specified" do
      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      assert {:ok, info} = AnthropicBackend.get_model_info(config)
      assert info.name == "claude-3-sonnet-20240229"
      assert info.max_tokens == 200_000
    end

    test "returns consistent model info structure" do
      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      assert {:ok, info} = AnthropicBackend.get_model_info(config)

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
        "content" => [
          %{
            "text" => "Parsed response content",
            "type" => "text"
          }
        ],
        "role" => "assistant"
      }

      expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      assert {:ok, "Parsed response content"} =
        AnthropicBackend.generate_response(config, "Test", %{})
    end

    test "handles response with whitespace" do
      response = %{
        "content" => [
          %{
            "text" => "  \n  Response with whitespace  \n  ",
            "type" => "text"
          }
        ]
      }

      expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      assert {:ok, "Response with whitespace"} =
        AnthropicBackend.generate_response(config, "Test", %{})
    end

    test "handles multiple content blocks" do
      response = %{
        "content" => [
          %{
            "text" => "First part",
            "type" => "text"
          },
          %{
            "text" => "Second part",
            "type" => "text"
          }
        ]
      }

      expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      # Should return the first text content
      assert {:ok, "First part"} =
        AnthropicBackend.generate_response(config, "Test", %{})
    end

    test "handles API error response" do
      error_response = %{
        "error" => %{
          "type" => "rate_limit_error",
          "message" => "Rate limit exceeded"
        }
      }

      expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 429, body: error_response}}
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      assert {:error, {:api_error, 429, ^error_response}} =
        AnthropicBackend.generate_response(config, "Test", %{})
    end

    test "handles malformed response" do
      malformed_response = %{
        "invalid" => "structure"
      }

      expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 200, body: malformed_response}}
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      assert {:error, {:invalid_response_format, ^malformed_response}} =
        AnthropicBackend.generate_response(config, "Test", %{})
    end
  end

  describe "Anthropic-specific features" do
    test "handles system messages correctly", %{success_response: response} do
      expect(Req, :post, fn _url, opts ->
        body = Jason.decode!(opts[:body])

        # System message should be in separate field, not in messages
        assert body["system"] == "You are Claude, an AI assistant."
        assert not Enum.any?(body["messages"], fn msg ->
          msg["role"] == "system"
        end)

        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      context = %{
        system_message: "You are Claude, an AI assistant."
      }

      assert {:ok, _result} = AnthropicBackend.generate_response(config, "Test", context)
    end

    test "handles conversation without system message", %{success_response: response} do
      expect(Req, :post, fn _url, opts ->
        body = Jason.decode!(opts[:body])

        # Should not have system field when no system message
        assert not Map.has_key?(body, "system")

        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      assert {:ok, _result} = AnthropicBackend.generate_response(config, "Test", %{})
    end

    test "formats messages correctly for Anthropic API", %{success_response: response} do
      expect(Req, :post, fn _url, opts ->
        body = Jason.decode!(opts[:body])
        messages = body["messages"]

        # All messages should have role and content
        for message <- messages do
          assert Map.has_key?(message, "role")
          assert Map.has_key?(message, "content")
          assert message["role"] in ["user", "assistant"]
        end

        {:ok, %{status: 200, body: response}}
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      context = %{
        conversation_history: [
          %{role: "user", content: "Hello"},
          %{role: "assistant", content: "Hi there!"}
        ]
      }

      assert {:ok, _result} = AnthropicBackend.generate_response(config, "How are you?", context)
    end
  end

  # Property-based tests
  describe "property-based tests" do
    property "validate_config is consistent for valid configurations" do
      check all api_key <- string(:alphanumeric, min_length: 25, max_length: 100),
                model <- member_of(["claude-3-opus-20240229", "claude-3-sonnet-20240229", "claude-3-haiku-20240307"]) do

        config = %{
          backend_type: :anthropic,
          api_key: "sk-ant-" <> api_key,
          model: model
        }

        result1 = AnthropicBackend.validate_config(config)
        result2 = AnthropicBackend.validate_config(config)

        assert result1 == result2
        assert result1 == :ok
      end
    end

    property "get_model_info returns consistent structure" do
      check all model <- member_of(["claude-3-opus-20240229", "claude-3-sonnet-20240229", "custom-claude"]) do
        config = %{
          backend_type: :anthropic,
          api_key: "sk-ant-test123456789012345678901234567890",
          model: model
        }

        assert {:ok, info} = AnthropicBackend.get_model_info(config)
        assert info.provider == :anthropic
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
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      # Make requests until circuit breaker opens
      for _i <- 1..6 do
        AnthropicBackend.generate_response(config, "Test", %{})
      end

      # Next request should be rejected by circuit breaker
      assert {:error, :circuit_breaker_open} =
        AnthropicBackend.generate_response(config, "Test", %{})
    end

    test "integrates with retry logic" do
      # Mock request that succeeds on retry
      expect(Req, :post, 2, fn _url, _opts ->
        case Process.get(:attempt_count, 0) do
          0 ->
            Process.put(:attempt_count, 1)
            {:error, :timeout}
          _ ->
            {:ok, %{status: 200, body: %{"content" => [%{"text" => "Success"}]}}}
        end
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890",
        max_retries: 2
      }

      assert {:ok, "Success"} = AnthropicBackend.generate_response(config, "Test", %{})
    end

    test "integrates with metrics collection" do
      expect(Req, :post, fn _url, _opts ->
        {:ok, %{status: 200, body: %{"content" => [%{"text" => "Test"}]}}}
      end)

      config = %{
        backend_type: :anthropic,
        api_key: "sk-ant-test123456789012345678901234567890"
      }

      # Record initial metrics
      initial_metrics = MetricsCollector.get_metrics(:anthropic)

      # Make request
      AnthropicBackend.generate_response(config, "Test", %{})

      # Verify metrics were updated
      final_metrics = MetricsCollector.get_metrics(:anthropic)
      assert final_metrics.total_requests > initial_metrics.total_requests
    end
  end

  # Doctests
  doctest AnthropicBackend, import: true
end
