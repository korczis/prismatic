defmodule Prismatic.LLM.ConfigTest do
  use ExUnit.Case, async: true

  alias Prismatic.LLM.Config

  @moduletag :llm

  setup do
    # Store original config to restore later
    original_config = Application.get_env(:prismatic, Prismatic.LLM)

    on_exit(fn ->
      if original_config do
        Application.put_env(:prismatic, Prismatic.LLM, original_config)
      else
        Application.delete_env(:prismatic, Prismatic.LLM)
      end
    end)

    :ok
  end

  describe "get_backend_config/0" do
    test "returns default backend configuration" do
      setup_test_config()

      result = Config.get_backend_config()

      assert match?(%{backend_type: :test}, result)
      assert result.api_key == "test-key"
    end

    test "returns error when no default backend configured" do
      Application.put_env(:prismatic, Prismatic.LLM, backends: %{})

      result = Config.get_backend_config()

      assert match?({:error, _}, result)
    end
  end

  describe "get_backend_config/1" do
    test "returns specific backend configuration" do
      setup_test_config()

      result = Config.get_backend_config(:test)

      assert match?(%{backend_type: :test}, result)
      assert result.api_key == "test-key"
    end

    test "returns error for non-existent backend" do
      setup_test_config()

      result = Config.get_backend_config(:nonexistent)

      assert match?({:error, {:backend_not_found, :nonexistent, _}}, result)
    end

    test "resolves environment variables" do
      System.put_env("TEST_API_KEY", "resolved-key")

      config = %{
        default_backend: :env_test,
        backends: %{
          env_test: %{
            backend_type: :test,
            api_key: {:system, "TEST_API_KEY"},
            model: "test-model"
          }
        }
      }

      Application.put_env(:prismatic, Prismatic.LLM, config)

      result = Config.get_backend_config(:env_test)

      assert match?(%{api_key: "resolved-key"}, result)

      System.delete_env("TEST_API_KEY")
    end

    test "uses default value when environment variable not set" do
      config = %{
        default_backend: :env_test,
        backends: %{
          env_test: %{
            backend_type: :test,
            api_key: {:system, "NONEXISTENT_KEY", "default-value"},
            model: "test-model"
          }
        }
      }

      Application.put_env(:prismatic, Prismatic.LLM, config)

      result = Config.get_backend_config(:env_test)

      assert match?(%{api_key: "default-value"}, result)
    end

    test "returns error when required environment variable missing" do
      config = %{
        default_backend: :env_test,
        backends: %{
          env_test: %{
            backend_type: :test,
            api_key: {:system, "MISSING_KEY"},
            model: "test-model"
          }
        }
      }

      Application.put_env(:prismatic, Prismatic.LLM, config)

      result = Config.get_backend_config(:env_test)

      assert match?({:error, {:config_resolution_failed, :env_test, _}}, result)
    end
  end

  describe "list_backends/0" do
    test "returns all configured backend names" do
      setup_test_config()

      result = Config.list_backends()

      assert result == [:test]
    end

    test "returns empty list when no backends configured" do
      Application.put_env(:prismatic, Prismatic.LLM, backends: %{})

      result = Config.list_backends()

      assert result == []
    end
  end

  describe "get_default_backend/0" do
    test "returns configured default backend" do
      setup_test_config()

      result = Config.get_default_backend()

      assert result == :test
    end
  end

  describe "get_circuit_breaker_config/0" do
    test "returns circuit breaker configuration" do
      setup_test_config()

      result = Config.get_circuit_breaker_config()

      assert match?(%{failure_threshold: 5}, result)
      assert match?(%{recovery_timeout: 60_000}, result)
      assert match?(%{success_threshold: 3}, result)
    end
  end

  describe "get_metrics_config/0" do
    test "returns metrics configuration" do
      setup_test_config()

      result = Config.get_metrics_config()

      assert match?(%{enabled: true}, result)
      assert match?(%{telemetry_prefix: [:prismatic, :llm, :backend]}, result)
    end
  end

  describe "validate_config/0" do
    test "validates complete configuration successfully" do
      setup_test_config()

      result = Config.validate_config()

      assert result == :ok
    end

    test "returns error for missing backends" do
      Application.put_env(:prismatic, Prismatic.LLM, backends: %{})

      result = Config.validate_config()

      assert match?({:error, :no_backends_configured}, result)
    end

    test "returns error for invalid backend configuration" do
      config = %{
        default_backend: :invalid,
        backends: %{
          invalid: %{
            backend_type: :test
            # Missing required api_key
          }
        }
      }

      Application.put_env(:prismatic, Prismatic.LLM, config)

      result = Config.validate_config()

      assert match?({:error, {:backend_validation_failures, _}}, result)
    end

    test "returns error for unsupported backend type" do
      config = %{
        default_backend: :unsupported,
        backends: %{
          unsupported: %{
            backend_type: :unsupported_type,
            api_key: "test-key"
          }
        }
      }

      Application.put_env(:prismatic, Prismatic.LLM, config)

      result = Config.validate_config()

      assert match?({:error, {:backend_validation_failures, _}}, result)
    end
  end

  describe "backend_available?/1" do
    test "returns true for configured and valid backend" do
      setup_test_config()

      result = Config.backend_available?(:test)

      assert result == true
    end

    test "returns false for non-existent backend" do
      setup_test_config()

      result = Config.backend_available?(:nonexistent)

      assert result == false
    end

    test "returns false for invalid backend configuration" do
      config = %{
        default_backend: :invalid,
        backends: %{
          invalid: %{
            backend_type: :test
            # Missing required api_key
          }
        }
      }

      Application.put_env(:prismatic, Prismatic.LLM, config)

      result = Config.backend_available?(:invalid)

      assert result == false
    end
  end

  # Helper function to set up test configuration
  defp setup_test_config do
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
  end
end
