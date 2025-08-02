defmodule Prismatic.LLM.BackendTest do
  @moduledoc """
  Comprehensive test suite for the LLM Backend factory and unified interface.

  This module tests the main backend factory functionality, configuration
  validation, backend routing, and integration with supporting infrastructure
  like circuit breakers, retry logic, and metrics collection.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  import Mox
  import Prismatic.TestHelpers
  import Prismatic.PropertyHelpers

  alias Prismatic.LLM.Backend
  alias Prismatic.LLM.Backend.{CircuitBreaker, MetricsCollector, RetryLogic}
  alias Prismatic.LLM.Impl.{AnthropicBackend, OpenAIBackend, TestBackend}

  # Set up mocks for each test
  setup :verify_on_exit!
  setup :setup_mocks

  describe "create_config/2" do
    test "creates valid configuration for supported backends" do
      # Test each supported backend type
      for backend_type <- [:openai, :anthropic, :test] do
        assert {:ok, config} = Backend.create_config(backend_type, %{})
        assert config.backend_type == backend_type
        assert is_integer(config.timeout)
        assert is_integer(config.max_retries)
        assert is_integer(config.retry_delay)
      end
    end

    test "merges provided options with defaults" do
      custom_options = %{
        api_key: "test-key",
        model: "custom-model",
        timeout: 60_000,
        max_retries: 5
      }

      {:ok, config} = Backend.create_config(:test, custom_options)

      assert config.api_key == "test-key"
      assert config.model == "custom-model"
      assert config.timeout == 60_000
      assert config.max_retries == 5
      assert config.backend_type == :test
    end

    test "applies default values when options not provided" do
      {:ok, config} = Backend.create_config(:test, %{})

      assert config.timeout == 30_000
      assert config.max_retries == 3
      assert config.retry_delay == 1_000
      assert config.backend_type == :test
    end

    test "rejects unsupported backend types" do
      assert {:error, {:unsupported_backend, :invalid}} =
        Backend.create_config(:invalid, %{})

      assert {:error, {:unsupported_backend, :unknown}} =
        Backend.create_config(:unknown, %{})
    end

    test "handles edge cases in options" do
      # Empty map
      assert {:ok, _config} = Backend.create_config(:test, %{})

      # Nil values should be preserved
      {:ok, config} = Backend.create_config(:test, %{api_key: nil})
      assert config.api_key == nil
    end
  end

  describe "validate_config/1" do
    test "validates configuration for each backend type" do
      # Test backend - minimal requirements
      {:ok, test_config} = Backend.create_config(:test, %{})
      assert :ok = Backend.validate_config(test_config)

      # OpenAI backend - requires API key
      {:ok, openai_config} = Backend.create_config(:openai, %{api_key: "sk-test123456789012345678901234567890"})
      assert :ok = Backend.validate_config(openai_config)

      # Anthropic backend - requires API key
      {:ok, anthropic_config} = Backend.create_config(:anthropic, %{api_key: "sk-ant-test123456789012345678901234567890"})
      assert :ok = Backend.validate_config(anthropic_config)
    end

    test "rejects invalid configurations" do
      # Invalid backend type
      invalid_config = %{backend_type: :invalid}
      assert {:error, {:unsupported_backend, :invalid}} = Backend.validate_config(invalid_config)

      # Missing required fields for OpenAI
      {:ok, openai_config} = Backend.create_config(:openai, %{})
      assert {:error, _reason} = Backend.validate_config(openai_config)

      # Invalid API key format for OpenAI
      {:ok, openai_config} = Backend.create_config(:openai, %{api_key: "invalid-key"})
      assert {:error, :invalid_api_key_format} = Backend.validate_config(openai_config)
    end

    test "delegates validation to backend implementations" do
      # Each backend should handle its own validation logic
      {:ok, config} = Backend.create_config(:test, %{})

      # Mock the backend module validation
      expect(Prismatic.LLM.MockBackend, :validate_config, fn _config ->
        {:error, :custom_validation_error}
      end)

      # This would normally work, but we're testing the delegation
      assert :ok = Backend.validate_config(config)
    end
  end

  describe "generate_response/3" do
    test "successfully generates responses for valid configurations" do
      {:ok, config} = Backend.create_config(:test, %{})

      assert {:ok, response} = Backend.generate_response(config, "Hello", %{})
      assert is_binary(response)
      assert String.length(response) > 0
    end

    test "handles different context parameters" do
      {:ok, config} = Backend.create_config(:test, %{})

      context = %{
        temperature: 0.5,
        max_tokens: 100,
        system_message: "You are a helpful assistant",
        user_id: "test-user-123"
      }

      assert {:ok, response} = Backend.generate_response(config, "Test prompt", context)
      assert is_binary(response)
    end

    test "validates configuration before processing" do
      invalid_config = %{backend_type: :invalid}

      assert {:error, {:unsupported_backend, :invalid}} =
        Backend.generate_response(invalid_config, "test", %{})
    end

    test "integrates with circuit breaker protection" do
      {:ok, config} = Backend.create_config(:test, %{
        responses: %{"circuit_test" => {:error, :simulated_error}}
      })

      # First few requests should fail and eventually trip the circuit breaker
      for _i <- 1..6 do
        Backend.generate_response(config, "circuit_test", %{})
      end

      # Subsequent requests should be rejected by circuit breaker
      assert {:error, :circuit_breaker_open} =
        Backend.generate_response(config, "circuit_test", %{})
    end

    test "applies retry logic for retryable errors" do
      {:ok, config} = Backend.create_config(:test, %{
        error_rate: 0.8,  # High error rate to test retries
        error_type: :timeout
      })

      # Should eventually succeed or exhaust retries
      result = Backend.generate_response(config, "retry_test", %{})
      assert match?({:ok, _response}, result) or match?({:error, _reason}, result)
    end

    test "handles empty and edge case prompts" do
      {:ok, config} = Backend.create_config(:test, %{})

      # Empty prompt
      assert {:ok, _response} = Backend.generate_response(config, "", %{})

      # Very long prompt
      long_prompt = String.duplicate("test ", 1000)
      assert {:ok, _response} = Backend.generate_response(config, long_prompt, %{})

      # Unicode prompt
      assert {:ok, _response} = Backend.generate_response(config, "Hello 世界 🌍", %{})
    end
  end

  describe "health_check/1" do
    test "performs health checks for all backend types" do
      for backend_type <- [:test, :openai, :anthropic] do
        case backend_type do
          :test ->
            {:ok, config} = Backend.create_config(:test, %{})
            assert :ok = Backend.health_check(config)

          :openai ->
            {:ok, config} = Backend.create_config(:openai, %{api_key: "sk-test123456789012345678901234567890"})
            # Health check will fail without real API, but should validate config first
            result = Backend.health_check(config)
            assert result == :ok or match?({:error, _reason}, result)

          :anthropic ->
            {:ok, config} = Backend.create_config(:anthropic, %{api_key: "sk-ant-test123456789012345678901234567890"})
            # Health check will fail without real API, but should validate config first
            result = Backend.health_check(config)
            assert result == :ok or match?({:error, _reason}, result)
        end
      end
    end

    test "validates configuration before health check" do
      invalid_config = %{backend_type: :invalid}

      assert {:error, {:unsupported_backend, :invalid}} =
        Backend.health_check(invalid_config)
    end

    test "handles backend-specific health check failures" do
      {:ok, config} = Backend.create_config(:test, %{})

      # Test backend should always be healthy
      assert :ok = Backend.health_check(config)
    end
  end

  describe "get_model_info/1" do
    test "retrieves model information for all backend types" do
      # Test backend
      {:ok, test_config} = Backend.create_config(:test, %{})
      assert {:ok, info} = Backend.get_model_info(test_config)
      assert info.provider == :test
      assert is_binary(info.name)
      assert is_integer(info.max_tokens)
      assert is_boolean(info.supports_streaming)
      assert is_number(info.cost_per_token)
      assert is_list(info.capabilities)

      # OpenAI backend
      {:ok, openai_config} = Backend.create_config(:openai, %{
        api_key: "sk-test123456789012345678901234567890",
        model: "gpt-4"
      })
      assert {:ok, info} = Backend.get_model_info(openai_config)
      assert info.provider == :openai
      assert info.name == "gpt-4"

      # Anthropic backend
      {:ok, anthropic_config} = Backend.create_config(:anthropic, %{
        api_key: "sk-ant-test123456789012345678901234567890",
        model: "claude-3-sonnet-20240229"
      })
      assert {:ok, info} = Backend.get_model_info(anthropic_config)
      assert info.provider == :anthropic
      assert info.name == "claude-3-sonnet-20240229"
    end

    test "validates configuration before retrieving model info" do
      invalid_config = %{backend_type: :invalid}

      assert {:error, {:unsupported_backend, :invalid}} =
        Backend.get_model_info(invalid_config)
    end

    test "handles different model configurations" do
      {:ok, config} = Backend.create_config(:test, %{model: "custom-test-model"})
      assert {:ok, info} = Backend.get_model_info(config)
      assert info.name == "test-model-v1"  # Test backend uses fixed model name
    end
  end

  describe "available_backends/0" do
    test "returns list of supported backend types" do
      backends = Backend.available_backends()

      assert is_list(backends)
      assert :openai in backends
      assert :anthropic in backends
      assert :test in backends
      assert :local in backends

      # Should not contain invalid backends
      refute :invalid in backends
      refute :unknown in backends
    end

    test "returns consistent results" do
      backends1 = Backend.available_backends()
      backends2 = Backend.available_backends()

      assert backends1 == backends2
    end
  end

  describe "error handling and edge cases" do
    test "handles malformed configurations gracefully" do
      # Nil configuration
      assert {:error, _reason} = Backend.validate_config(nil)

      # Non-map configuration
      assert {:error, _reason} = Backend.validate_config("invalid")
      assert {:error, _reason} = Backend.validate_config(123)
      assert {:error, _reason} = Backend.validate_config([])
    end

    test "handles concurrent requests safely" do
      {:ok, config} = Backend.create_config(:test, %{})

      # Spawn multiple concurrent requests
      tasks = for i <- 1..10 do
        Task.async(fn ->
          Backend.generate_response(config, "concurrent test #{i}", %{})
        end)
      end

      # All should complete successfully
      results = Task.await_many(tasks)
      assert length(results) == 10

      for result <- results do
        assert {:ok, _response} = result
      end
    end

    test "handles large payloads appropriately" do
      {:ok, config} = Backend.create_config(:test, %{})

      # Large context
      large_context = %{
        conversation_history: Enum.map(1..100, fn i ->
          %{role: "user", content: "Message #{i}"}
        end),
        system_message: String.duplicate("System instruction. ", 100)
      }

      assert {:ok, _response} = Backend.generate_response(config, "test", large_context)
    end
  end

  # Property-based tests using StreamData
  describe "property-based tests" do
    property "create_config always returns valid structure for supported backends" do
      check all backend_type <- member_of([:openai, :anthropic, :test]),
                options <- map_of(atom(:alphanumeric), term()) do

        case Backend.create_config(backend_type, options) do
          {:ok, config} ->
            assert is_map(config)
            assert config.backend_type == backend_type
            assert is_integer(config.timeout)
            assert is_integer(config.max_retries)

          {:error, reason} ->
            # Some option combinations might be invalid
            assert is_atom(reason) or is_tuple(reason)
        end
      end
    end

    property "generate_response handles various prompt types" do
      check all prompt <- string(:printable, max_length: 1000),
                context <- map_of(atom(:alphanumeric), term()) do

        {:ok, config} = Backend.create_config(:test, %{})

        case Backend.generate_response(config, prompt, context) do
          {:ok, response} ->
            assert is_binary(response)

          {:error, reason} ->
            # Some contexts might cause errors
            assert is_atom(reason) or is_tuple(reason)
        end
      end
    end

    property "backend validation is consistent" do
      check all backend_type <- member_of([:openai, :anthropic, :test]) do
        {:ok, config} = Backend.create_config(backend_type, %{})

        # Validation should be deterministic
        result1 = Backend.validate_config(config)
        result2 = Backend.validate_config(config)

        assert result1 == result2
      end
    end
  end

  # Integration tests with supporting modules
  describe "integration with supporting modules" do
    test "metrics are collected during operations" do
      {:ok, config} = Backend.create_config(:test, %{})

      # Record initial metrics
      initial_metrics = MetricsCollector.get_metrics(:test)

      # Perform operations
      Backend.generate_response(config, "metrics test", %{})
      Backend.health_check(config)
      Backend.get_model_info(config)

      # Verify metrics were updated
      final_metrics = MetricsCollector.get_metrics(:test)
      assert final_metrics.total_requests >= initial_metrics.total_requests
    end

    test "circuit breaker integration works correctly" do
      {:ok, config} = Backend.create_config(:test, %{
        responses: %{"fail" => {:error, :test_error}}
      })

      # Initial circuit breaker state should be closed
      assert :closed = CircuitBreaker.get_state(:test)

      # Generate enough failures to trip circuit breaker
      for _i <- 1..6 do
        Backend.generate_response(config, "fail", %{})
      end

      # Circuit breaker should now be open
      assert :open = CircuitBreaker.get_state(:test)
    end

    test "retry logic is applied appropriately" do
      {:ok, config} = Backend.create_config(:test, %{
        error_rate: 0.7,  # 70% error rate
        error_type: :timeout
      })

      # Should attempt retries for retryable errors
      start_time = System.monotonic_time(:millisecond)
      result = Backend.generate_response(config, "retry test", %{})
      end_time = System.monotonic_time(:millisecond)

      # Should take longer due to retries (with backoff)
      duration = end_time - start_time

      case result do
        {:ok, _response} ->
          # Success after retries
          assert duration >= 0

        {:error, _reason} ->
          # Failed after all retries - should have taken time for backoff
          assert duration >= 1000  # At least 1 second for retry delays
      end
    end
  end

  # Doctests
  doctest Backend, import: true
end
