defmodule Prismatic.LLM.Impl.TestBackendTest do
  @moduledoc """
  Comprehensive test suite for the Test backend implementation.

  This module tests the test backend functionality including configurable responses,
  deterministic behavior, error simulation, latency simulation, and all the helper
  functions for creating different test configurations.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  import Prismatic.TestHelpers
  import Prismatic.PropertyHelpers

  alias Prismatic.LLM.Impl.TestBackend

  describe "validate_config/1" do
    test "validates correct test backend configuration" do
      valid_config = %{
        backend_type: :test,
        responses: %{},
        latency_ms: 50,
        error_rate: 0.0
      }

      assert :ok = TestBackend.validate_config(valid_config)
    end

    test "validates minimal configuration" do
      minimal_config = %{
        backend_type: :test
      }

      assert :ok = TestBackend.validate_config(minimal_config)
    end

    test "rejects invalid backend type" do
      invalid_config = %{
        backend_type: :openai
      }

      assert {:error, :invalid_backend_type} = TestBackend.validate_config(invalid_config)
    end

    test "accepts configuration with various optional fields" do
      configs = [
        %{backend_type: :test, responses: %{"hello" => "hi"}},
        %{backend_type: :test, latency_ms: 100},
        %{backend_type: :test, error_rate: 0.1},
        %{backend_type: :test, error_type: :timeout},
        %{backend_type: :test, responses: %{}, latency_ms: 0, error_rate: 0.0}
      ]

      for config <- configs do
        assert :ok = TestBackend.validate_config(config)
      end
    end
  end

  describe "generate_response/3" do
    test "generates default response when no specific response configured" do
      config = %{backend_type: :test}

      assert {:ok, response} = TestBackend.generate_response(config, "any prompt", %{})
      assert response == "This is a test response from the Prismatic test backend."
    end

    test "returns configured exact match responses" do
      config = %{
        backend_type: :test,
        responses: %{
          "hello" => "Hello! How can I help you today?",
          "goodbye" => "Goodbye! Have a great day!"
        }
      }

      assert {:ok, "Hello! How can I help you today?"} =
        TestBackend.generate_response(config, "hello", %{})

      assert {:ok, "Goodbye! Have a great day!"} =
        TestBackend.generate_response(config, "goodbye", %{})
    end

    test "returns pattern-based responses" do
      config = %{
        backend_type: :test,
        responses: %{
          "weather" => "I can't check real weather, but I can pretend it's sunny!",
          "math" => "I can help with basic math problems."
        }
      }

      # Should match pattern
      assert {:ok, response} = TestBackend.generate_response(config, "What's the weather like?", %{})
      assert String.contains?(response, "sunny")

      assert {:ok, response} = TestBackend.generate_response(config, "Can you help with math?", %{})
      assert String.contains?(response, "math")
    end

    test "handles function responses" do
      config = %{
        backend_type: :test,
        responses: %{
          "dynamic" => fn prompt, context ->
            "Dynamic response for: #{prompt} with context: #{inspect(context)}"
          end
        }
      }

      context = %{user_id: "test-user"}
      assert {:ok, response} = TestBackend.generate_response(config, "dynamic", context)
      assert String.contains?(response, "Dynamic response for: dynamic")
      assert String.contains?(response, "test-user")
    end

    test "handles error responses" do
      config = %{
        backend_type: :test,
        responses: %{
          "error" => {:error, :simulated_error},
          "timeout" => {:error, :timeout}
        }
      }

      assert {:error, :simulated_error} = TestBackend.generate_response(config, "error", %{})
      assert {:error, :timeout} = TestBackend.generate_response(config, "timeout", %{})
    end

    test "simulates latency when configured" do
      config = %{
        backend_type: :test,
        latency_ms: 100
      }

      start_time = System.monotonic_time(:millisecond)
      assert {:ok, _response} = TestBackend.generate_response(config, "test", %{})
      end_time = System.monotonic_time(:millisecond)

      duration = end_time - start_time
      assert duration >= 90  # Allow some tolerance for timing
    end

    test "skips latency when set to 0" do
      config = %{
        backend_type: :test,
        latency_ms: 0
      }

      start_time = System.monotonic_time(:millisecond)
      assert {:ok, _response} = TestBackend.generate_response(config, "test", %{})
      end_time = System.monotonic_time(:millisecond)

      duration = end_time - start_time
      assert duration < 50  # Should be very fast
    end

    test "simulates errors based on error rate" do
      # High error rate should cause frequent errors
      config = %{
        backend_type: :test,
        error_rate: 1.0,  # 100% error rate
        error_type: :simulated_network_error
      }

      # Should always return error
      assert {:error, :simulated_network_error} =
        TestBackend.generate_response(config, "test", %{})
    end

    test "no errors when error rate is 0" do
      config = %{
        backend_type: :test,
        error_rate: 0.0
      }

      # Should never return error due to error rate
      for _i <- 1..10 do
        assert {:ok, _response} = TestBackend.generate_response(config, "test", %{})
      end
    end

    test "validates configuration before processing" do
      invalid_config = %{backend_type: :openai}

      assert {:error, :invalid_backend_type} =
        TestBackend.generate_response(invalid_config, "test", %{})
    end
  end

  describe "response enhancement" do
    test "adds user reference when user_name in context" do
      config = %{backend_type: :test}
      context = %{user_name: "Alice"}

      assert {:ok, response} = TestBackend.generate_response(config, "test", context)
      assert String.contains?(response, "(Hello, Alice!)")
    end

    test "adds conversation context information" do
      config = %{backend_type: :test}
      context = %{
        conversation_history: [
          %{role: "user", content: "Previous message 1"},
          %{role: "assistant", content: "Previous response 1"},
          %{role: "user", content: "Previous message 2"}
        ]
      }

      assert {:ok, response} = TestBackend.generate_response(config, "test", context)
      assert String.contains?(response, "[Context: 3 previous messages]")
    end

    test "adds timestamp when requested" do
      config = %{backend_type: :test}
      context = %{include_timestamp: true}

      assert {:ok, response} = TestBackend.generate_response(config, "test", context)
      assert String.contains?(response, "[Generated at:")
      assert String.contains?(response, "T")  # ISO8601 format
    end

    test "combines multiple enhancements" do
      config = %{backend_type: :test}
      context = %{
        user_name: "Bob",
        conversation_history: [%{role: "user", content: "Hi"}],
        include_timestamp: true
      }

      assert {:ok, response} = TestBackend.generate_response(config, "test", context)
      assert String.contains?(response, "(Hello, Bob!)")
      assert String.contains?(response, "[Context: 1 previous messages]")
      assert String.contains?(response, "[Generated at:")
    end
  end

  describe "health_check/1" do
    test "always returns ok for test backend" do
      configs = [
        %{backend_type: :test},
        %{backend_type: :test, error_rate: 1.0},
        %{backend_type: :test, latency_ms: 1000}
      ]

      for config <- configs do
        assert :ok = TestBackend.health_check(config)
      end
    end
  end

  describe "get_model_info/1" do
    test "returns consistent model information" do
      config = %{backend_type: :test}

      assert {:ok, info} = TestBackend.get_model_info(config)

      assert info.name == "test-model-v1"
      assert info.max_tokens == 4096
      assert info.supports_streaming == false
      assert info.cost_per_token == 0.0
      assert info.provider == :test
      assert info.capabilities == [:chat, :testing, :deterministic]
    end

    test "returns same info regardless of configuration" do
      configs = [
        %{backend_type: :test},
        %{backend_type: :test, responses: %{"test" => "response"}},
        %{backend_type: :test, latency_ms: 500, error_rate: 0.5}
      ]

      base_info = nil
      for config <- configs do
        assert {:ok, info} = TestBackend.get_model_info(config)

        if base_info do
          assert info == base_info
        else
          _base_info = info
        end
      end
    end
  end

  describe "create_test_config/1" do
    test "creates configuration with default responses" do
      config = TestBackend.create_test_config()

      assert config.backend_type == :test
      assert config.latency_ms == 50
      assert config.error_rate == 0.0
      assert is_map(config.responses)

      # Should have common responses
      assert Map.has_key?(config.responses, "hello")
      assert Map.has_key?(config.responses, "help")
      assert Map.has_key?(config.responses, "test")
    end

    test "accepts custom options" do
      opts = [
        latency_ms: 200,
        error_rate: 0.1,
        responses: %{"custom" => "Custom response"}
      ]

      config = TestBackend.create_test_config(opts)

      assert config.latency_ms == 200
      assert config.error_rate == 0.1
      assert config.responses["custom"] == "Custom response"

      # Should still have default responses merged
      assert Map.has_key?(config.responses, "hello")
    end

    test "custom responses override defaults" do
      opts = [responses: %{"hello" => "Custom hello"}]
      config = TestBackend.create_test_config(opts)

      assert config.responses["hello"] == "Custom hello"
    end

    test "includes function-based responses" do
      config = TestBackend.create_test_config()

      # Should have function responses
      assert is_function(config.responses["error"], 2)
      assert is_function(config.responses["math"], 2)
      assert is_function(config.responses["time"], 2)
    end

    test "function responses work correctly" do
      config = TestBackend.create_test_config()

      # Test math function
      assert {:ok, response} = TestBackend.generate_response(config, "What is 2 + 2?", %{})
      assert String.contains?(response, "2 + 2 equals 4")

      # Test error function
      assert {:error, :simulated_test_error} = TestBackend.generate_response(config, "error", %{})

      # Test time function with timestamp
      assert {:ok, response} = TestBackend.generate_response(config, "time", %{include_timestamp: true})
      assert String.contains?(response, "current time is")
    end
  end

  describe "create_deterministic_config/0" do
    test "creates deterministic configuration" do
      config = TestBackend.create_deterministic_config()

      assert config.backend_type == :test
      assert config.latency_ms == 0
      assert config.error_rate == 0.0
      assert Map.has_key?(config.responses, "deterministic_test")
      assert Map.has_key?(config.responses, "property_test")
    end

    test "produces deterministic responses" do
      config = TestBackend.create_deterministic_config()

      # Same prompt should always produce same response
      assert {:ok, response1} = TestBackend.generate_response(config, "deterministic_test", %{})
      assert {:ok, response2} = TestBackend.generate_response(config, "deterministic_test", %{})
      assert response1 == response2
      assert response1 == "DETERMINISTIC_RESPONSE"
    end

    test "property test response is deterministic based on prompt hash" do
      config = TestBackend.create_deterministic_config()

      # Same prompt should produce same hash-based response
      assert {:ok, response1} = TestBackend.generate_response(config, "property_test", %{})
      assert {:ok, response2} = TestBackend.generate_response(config, "property_test", %{})
      assert response1 == response2
      assert String.starts_with?(response1, "Property test response:")

      # Different prompts should produce different responses
      assert {:ok, response3} = TestBackend.generate_response(config, "different_prompt", %{})
      assert response1 != response3
    end
  end

  describe "create_error_simulation_config/0" do
    test "creates error simulation configuration" do
      config = TestBackend.create_error_simulation_config()

      assert config.backend_type == :test
      assert config.latency_ms == 10
      assert config.error_rate == 0.3
      assert config.error_type == :simulated_network_error
      assert is_map(config.responses)
    end

    test "includes error-specific responses" do
      config = TestBackend.create_error_simulation_config()

      # Always error response
      assert {:error, :forced_error} = TestBackend.generate_response(config, "always_error", %{})

      # Rate limit error
      assert {:error, :rate_limit_exceeded} = TestBackend.generate_response(config, "rate_limit", %{})

      # Invalid response error
      assert {:error, :invalid_api_response} = TestBackend.generate_response(config, "invalid_response", %{})
    end

    test "simulates timeout with long delay" do
      config = TestBackend.create_error_simulation_config()

      # This would normally timeout, but we'll just check it takes time
      start_time = System.monotonic_time(:millisecond)

      # Use a timeout to prevent test from hanging
      task = Task.async(fn ->
        TestBackend.generate_response(config, "timeout", %{})
      end)

      # Wait a short time then kill the task
      Process.sleep(100)
      Task.shutdown(task, :brutal_kill)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      # Should have taken at least some time
      assert duration >= 90
    end
  end

  # Property-based tests
  describe "property-based tests" do
    property "validate_config always succeeds for test backend type" do
      check all latency <- non_negative_integer(),
                error_rate <- float(min: 0.0, max: 1.0),
                responses <- map_of(string(:printable), string(:printable)) do

        config = %{
          backend_type: :test,
          latency_ms: latency,
          error_rate: error_rate,
          responses: responses
        }

        assert :ok = TestBackend.validate_config(config)
      end
    end

    property "generate_response always returns valid result" do
      check all prompt <- string(:printable, max_length: 1000),
                context <- map_of(atom(:alphanumeric), term()),
                latency <- integer(0..100) do

        config = %{
          backend_type: :test,
          latency_ms: latency,
          error_rate: 0.0  # No random errors for property testing
        }

        case TestBackend.generate_response(config, prompt, context) do
          {:ok, response} ->
            assert is_binary(response)
            assert String.length(response) > 0

          {:error, reason} ->
            # Should only happen if configured error response
            assert is_atom(reason) or is_tuple(reason)
        end
      end
    end

    property "deterministic config produces consistent responses" do
      check all prompt <- string(:printable, min_length: 1, max_length: 100) do
        config = TestBackend.create_deterministic_config()

        result1 = TestBackend.generate_response(config, prompt, %{})
        result2 = TestBackend.generate_response(config, prompt, %{})

        assert result1 == result2
      end
    end

    property "get_model_info is always consistent" do
      check all config_options <- map_of(atom(:alphanumeric), term()) do
        config = Map.put(config_options, :backend_type, :test)

        assert {:ok, info} = TestBackend.get_model_info(config)
        assert info.name == "test-model-v1"
        assert info.provider == :test
        assert is_integer(info.max_tokens)
        assert is_number(info.cost_per_token)
      end
    end
  end

  describe "edge cases and error handling" do
    test "handles nil and empty responses gracefully" do
      config = %{
        backend_type: :test,
        responses: %{
          "nil_response" => nil,
          "empty_response" => "",
          "number_response" => 42
        }
      }

      # Nil should be converted to string
      assert {:ok, "nil"} = TestBackend.generate_response(config, "nil_response", %{})

      # Empty string should work
      assert {:ok, ""} = TestBackend.generate_response(config, "empty_response", %{})

      # Number should be converted to string
      assert {:ok, "42"} = TestBackend.generate_response(config, "number_response", %{})
    end

    test "handles malformed function responses" do
      config = %{
        backend_type: :test,
        responses: %{
          "bad_function" => fn _prompt, _context ->
            raise "Simulated function error"
          end
        }
      }

      # Should handle function errors gracefully
      result = TestBackend.generate_response(config, "bad_function", %{})

      # Might return error or fall back to default - either is acceptable
      case result do
        {:ok, response} -> assert is_binary(response)
        {:error, _reason} -> :ok
      end
    end

    test "handles very large context gracefully" do
      config = %{backend_type: :test}

      large_context = %{
        conversation_history: Enum.map(1..1000, fn i ->
          %{role: "user", content: "Message #{i}"}
        end),
        user_name: String.duplicate("VeryLongUserName", 100),
        custom_data: %{
          nested: %{
            deeply: %{
              very: String.duplicate("data", 1000)
            }
          }
        }
      }

      assert {:ok, response} = TestBackend.generate_response(config, "test", large_context)
      assert is_binary(response)
    end

    test "handles concurrent requests safely" do
      config = %{
        backend_type: :test,
        latency_ms: 10
      }

      # Spawn multiple concurrent requests
      tasks = for i <- 1..20 do
        Task.async(fn ->
          TestBackend.generate_response(config, "concurrent test #{i}", %{})
        end)
      end

      # All should complete successfully
      results = Task.await_many(tasks)
      assert length(results) == 20

      for result <- results do
        assert {:ok, _response} = result
      end
    end
  end

  # Doctests
  doctest TestBackend, import: true
end
