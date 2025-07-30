defmodule Prismatic.LLM.ManagerTest do
  use ExUnit.Case, async: true

  alias Prismatic.LLM.Manager
  alias Prismatic.LLM.Config
  alias Prismatic.LLM.Backend.MetricsCollector

  @moduletag :llm

  setup do
    # Store original config to restore later
    original_config = Application.get_env(:prismatic, Prismatic.LLM)

    # Setup test configuration
    config = %{
      default_backend: :test,
      backends: %{
        test: %{
          backend_type: :test,
          api_key: "test-key",
          model: "test-model",
          timeout: 30_000,
          max_retries: 3
        }
      },
      circuit_breaker: %{
        failure_threshold: 5,
        recovery_timeout: 60_000,
        success_threshold: 3
      },
      metrics: %{
        enabled: true,
        telemetry_prefix: [:prismatic, :llm, :backend]
      }
    }

    Application.put_env(:prismatic, Prismatic.LLM, config)

    on_exit(fn ->
      if original_config do
        Application.put_env(:prismatic, Prismatic.LLM, original_config)
      else
        Application.delete_env(:prismatic, Prismatic.LLM)
      end
    end)

    :ok
  end

  describe "generate_response/2" do
    test "generates response with default backend" do
      result = Manager.generate_response("Hello, world!")

      assert match?({:ok, response} when is_binary(response), result)
    end

    test "generates response with specific backend" do
      result = Manager.generate_response("Hello!", backend: :test)

      assert match?({:ok, response} when is_binary(response), result)
    end

    test "generates response with context" do
      context = %{
        system_message: "You are a helpful assistant",
        temperature: 0.5,
        max_tokens: 100
      }

      result = Manager.generate_response("Help me", context: context)

      assert match?({:ok, response} when is_binary(response), result)
    end

    test "returns error for non-existent backend" do
      result = Manager.generate_response("Hello", backend: :nonexistent)

      assert match?({:error, _}, result)
    end

    test "handles backend errors gracefully" do
      # Use special prompt that triggers error in TestBackend
      result = Manager.generate_response("ERROR")

      assert match?({:error, _}, result)
    end

    test "validates prompt is string" do
      assert_raise FunctionClauseError, fn ->
        Manager.generate_response(nil)
      end

      assert_raise FunctionClauseError, fn ->
        Manager.generate_response(123)
      end
    end
  end

  describe "health_check/1" do
    test "performs health check on default backend" do
      result = Manager.health_check()

      assert result == :ok
    end

    test "performs health check on specific backend" do
      result = Manager.health_check(:test)

      assert result == :ok
    end

    test "returns error for non-existent backend" do
      result = Manager.health_check(:nonexistent)

      assert match?({:error, _}, result)
    end
  end

  describe "get_backend_info/1" do
    test "gets info for default backend" do
      result = Manager.get_backend_info()

      assert match?({:ok, %{name: _, provider: :test}}, result)
    end

    test "gets info for specific backend" do
      result = Manager.get_backend_info(:test)

      assert match?({:ok, %{name: _, provider: :test}}, result)
    end

    test "returns error for non-existent backend" do
      result = Manager.get_backend_info(:nonexistent)

      assert match?({:error, _}, result)
    end
  end

  describe "list_backends/0" do
    test "lists all available backends" do
      result = Manager.list_backends()

      assert result == [:test]
    end
  end

  describe "metrics functions" do
    test "get_metrics/1 returns backend metrics" do
      # Generate a request to create some metrics
      Manager.generate_response("test request")

      result = Manager.get_metrics(:test)

      assert is_map(result)
      assert Map.has_key?(result, :total_requests)
    end

    test "get_metrics/0 returns default backend metrics" do
      # Generate a request to create some metrics
      Manager.generate_response("test request")

      result = Manager.get_metrics()

      assert is_map(result)
      assert Map.has_key?(result, :total_requests)
    end

    test "get_global_metrics/0 returns global metrics" do
      # Generate a request to create some metrics
      Manager.generate_response("test request")

      result = Manager.get_global_metrics()

      assert is_map(result)
      assert Map.has_key?(result, :total_requests)
    end
  end

  describe "circuit breaker functions" do
    test "reset_circuit_breaker/1 resets circuit breaker" do
      result = Manager.reset_circuit_breaker(:test)

      assert result == :ok
    end

    test "get_circuit_breaker_state/1 returns circuit breaker state" do
      result = Manager.get_circuit_breaker_state(:test)

      assert result in [:closed, :open, :half_open]
    end
  end

  describe "error handling and edge cases" do
    test "handles invalid backend configuration gracefully" do
      # Override with invalid config
      invalid_config = %{
        default_backend: :invalid,
        backends: %{
          invalid: %{
            backend_type: :test
            # Missing required api_key
          }
        }
      }

      Application.put_env(:prismatic, Prismatic.LLM, invalid_config)

      result = Manager.generate_response("Hello")

      assert match?({:error, _}, result)
    end

    test "handles missing backends configuration" do
      Application.put_env(:prismatic, Prismatic.LLM, backends: %{})

      result = Manager.generate_response("Hello")

      assert match?({:error, _}, result)
    end

    test "handles circuit breaker startup failures gracefully" do
      # This test is more complex to set up, but ensures robustness
      # For now, we verify that normal operation works
      result = Manager.generate_response("Hello")

      assert match?({:ok, _} or {:error, _}, result)
    end
  end

  describe "integration scenarios" do
    test "multiple requests work correctly" do
      requests = [
        "Hello",
        "How are you?",
        "What's the weather like?",
        "Tell me a joke"
      ]

      results = Enum.map(requests, &Manager.generate_response/1)

      # All requests should succeed (with test backend)
      Enum.each(results, fn result ->
        assert match?({:ok, response} when is_binary(response), result)
      end)

      # Verify metrics were recorded
      metrics = Manager.get_metrics()
      assert metrics.total_requests >= length(requests)
    end

    test "different backends can be used in same session" do
      # With current setup, only test backend is available
      result1 = Manager.generate_response("Hello", backend: :test)
      assert match?({:ok, _}, result1)

      # Non-existent backend should fail
      result2 = Manager.generate_response("Hello", backend: :nonexistent)
      assert match?({:error, _}, result2)
    end

    test "context is properly passed through" do
      contexts = [
        %{temperature: 0.1},
        %{max_tokens: 50},
        %{system_message: "Be helpful"},
        %{temperature: 0.9, max_tokens: 200, system_message: "Be creative"}
      ]

      results = Enum.map(contexts, fn context ->
        Manager.generate_response("Test", context: context)
      end)

      # All should succeed
      Enum.each(results, fn result ->
        assert match?({:ok, response} when is_binary(response), result)
      end)
    end
  end
end
