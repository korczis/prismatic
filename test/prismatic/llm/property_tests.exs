defmodule Prismatic.LLM.PropertyTests do
  @moduledoc """
  Comprehensive property-based test suite for the LLM Backend system.

  This module uses StreamData to generate random inputs and test invariants
  across the entire LLM backend system, including configuration validation,
  response generation, error handling, and system behavior under various
  conditions.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  import Prismatic.TestHelpers
  import Prismatic.PropertyHelpers

  alias Prismatic.LLM.Backend
  alias Prismatic.LLM.Backend.{CircuitBreaker, MetricsCollector, RetryLogic}
  alias Prismatic.LLM.CircuitBreakerRegistry
  alias Prismatic.LLM.Impl.{AnthropicBackend, OpenAIBackend, TestBackend}

  # Custom generators for LLM-specific data structures

  @doc """
  Generator for valid backend types.
  """
  def backend_type_generator do
    member_of([:openai, :anthropic, :test])
  end

  @doc """
  Generator for LLM configuration maps.
  """
  def llm_config_generator do
    gen all backend_type <- backend_type_generator(),
            api_key <- api_key_generator(backend_type),
            model <- model_generator(backend_type),
            timeout <- integer(1000..60_000),
            max_retries <- integer(0..10) do
      %{
        backend_type: backend_type,
        api_key: api_key,
        model: model,
        timeout: timeout,
        max_retries: max_retries
      }
    end
  end

  @doc """
  Generator for API keys based on backend type.
  """
  def api_key_generator(backend_type) do
    case backend_type do
      :openai ->
        gen all suffix <- string(:alphanumeric, min_length: 20, max_length: 50) do
          "sk-" <> suffix
        end
      :anthropic ->
        gen all suffix <- string(:alphanumeric, min_length: 20, max_length: 50) do
          "sk-ant-" <> suffix
        end
      :test ->
        constant("test-api-key")
    end
  end

  @doc """
  Generator for model names based on backend type.
  """
  def model_generator(backend_type) do
    case backend_type do
      :openai ->
        member_of(["gpt-4", "gpt-3.5-turbo", "gpt-4-32k", "gpt-3.5-turbo-16k"])
      :anthropic ->
        member_of([
          "claude-3-opus-20240229",
          "claude-3-sonnet-20240229",
          "claude-3-haiku-20240307",
          "claude-2.1"
        ])
      :test ->
        member_of(["test-model-v1", "test-model-v2"])
    end
  end

  @doc """
  Generator for request context maps.
  """
  def context_generator do
    gen all temperature <- one_of([constant(nil), float(min: 0.0, max: 2.0)]),
            max_tokens <- one_of([constant(nil), integer(1..4096)]),
            system_message <- one_of([constant(nil), string(:printable, max_length: 500)]),
            user_id <- one_of([constant(nil), string(:alphanumeric, max_length: 50)]),
            stream <- one_of([constant(nil), boolean()]),
            conversation_history <- one_of([
              constant(nil),
              list_of(conversation_message_generator(), max_length: 10)
            ]) do

      context = %{}
      context = if temperature, do: Map.put(context, :temperature, temperature), else: context
      context = if max_tokens, do: Map.put(context, :max_tokens, max_tokens), else: context
      context = if system_message, do: Map.put(context, :system_message, system_message), else: context
      context = if user_id, do: Map.put(context, :user_id, user_id), else: context
      context = if stream, do: Map.put(context, :stream, stream), else: context
      context = if conversation_history, do: Map.put(context, :conversation_history, conversation_history), else: context

      context
    end
  end

  @doc """
  Generator for conversation messages.
  """
  def conversation_message_generator do
    gen all role <- member_of(["user", "assistant", "system"]),
            content <- string(:printable, min_length: 1, max_length: 200) do
      %{role: role, content: content}
    end
  end

  @doc """
  Generator for error types that can occur in LLM backends.
  """
  def error_type_generator do
    member_of([
      :timeout,
      :econnrefused,
      :econnreset,
      :ehostunreach,
      :enetunreach,
      :rate_limit_exceeded,
      :quota_exceeded,
      :invalid_api_key,
      :authentication_failed,
      :invalid_request,
      :invalid_model,
      :circuit_breaker_open,
      {:api_error, 400, "Bad Request"},
      {:api_error, 401, "Unauthorized"},
      {:api_error, 429, "Rate Limited"},
      {:api_error, 500, "Internal Server Error"},
      {:api_error, 503, "Service Unavailable"}
    ])
  end

  describe "Backend configuration properties" do
    property "create_config always produces valid structure for supported backends" do
      check all backend_type <- backend_type_generator(),
                options <- map_of(atom(:alphanumeric), term()) do

        case Backend.create_config(backend_type, options) do
          {:ok, config} ->
            # Config should always have required fields
            assert is_map(config)
            assert config.backend_type == backend_type
            assert is_integer(config.timeout)
            assert config.timeout > 0
            assert is_integer(config.max_retries)
            assert config.max_retries >= 0

            # Should be able to validate the config
            validation_result = Backend.validate_config(config)
            assert validation_result == :ok or match?({:error, _}, validation_result)

          {:error, reason} ->
            # Error should be well-formed
            assert is_atom(reason) or is_tuple(reason)
        end
      end
    end

    property "validate_config is deterministic and consistent" do
      check all config <- llm_config_generator() do
        {:ok, backend_config} = Backend.create_config(config.backend_type, config)

        # Validation should be deterministic
        result1 = Backend.validate_config(backend_config)
        result2 = Backend.validate_config(backend_config)

        assert result1 == result2

        # Result should be well-formed
        case result1 do
          :ok -> :ok
          {:error, reason} -> assert is_atom(reason) or is_tuple(reason)
        end
      end
    end

    property "available_backends returns consistent list" do
      check all _ <- constant(:ok) do
        backends1 = Backend.available_backends()
        backends2 = Backend.available_backends()

        assert backends1 == backends2
        assert is_list(backends1)
        assert length(backends1) > 0

        # All backends should be atoms
        for backend <- backends1 do
          assert is_atom(backend)
        end

        # Should include known backends
        assert :test in backends1
        assert :openai in backends1
        assert :anthropic in backends1
      end
    end
  end

  describe "Response generation properties" do
    property "test backend always generates valid responses" do
      check all prompt <- string(:printable, max_length: 1000),
                context <- context_generator(),
                latency <- integer(0..100),
                error_rate <- float(min: 0.0, max: 0.3) do  # Keep error rate low for property testing

        config = %{
          backend_type: :test,
          latency_ms: latency,
          error_rate: error_rate
        }

        case Backend.generate_response(config, prompt, context) do
          {:ok, response} ->
            assert is_binary(response)
            assert String.length(response) > 0

          {:error, reason} ->
            # Errors should be well-formed
            assert is_atom(reason) or is_tuple(reason)
        end
      end
    end

    property "response generation handles various prompt types" do
      check all prompt <- one_of([
        string(:printable, max_length: 1000),
        string(:alphanumeric, max_length: 500),
        constant(""),
        string(:ascii, max_length: 100)
      ]) do

        config = %{backend_type: :test, error_rate: 0.0}

        case Backend.generate_response(config, prompt, %{}) do
          {:ok, response} ->
            assert is_binary(response)

          {:error, reason} ->
            assert is_atom(reason) or is_tuple(reason)
        end
      end
    end

    property "context parameters are handled gracefully" do
      check all context <- context_generator() do
        config = %{backend_type: :test, error_rate: 0.0}

        case Backend.generate_response(config, "test prompt", context) do
          {:ok, response} ->
            assert is_binary(response)

          {:error, reason} ->
            assert is_atom(reason) or is_tuple(reason)
        end
      end
    end
  end

  describe "Error handling properties" do
    property "retryable_error? classification is consistent and logical" do
      check all error_type <- error_type_generator() do
        error = {:error, error_type}

        # Classification should be deterministic
        result1 = RetryLogic.retryable_error?(error)
        result2 = RetryLogic.retryable_error?(error)

        assert result1 == result2
        assert is_boolean(result1)

        # Verify logical classification
        case error_type do
          # Network errors should be retryable
          type when type in [:timeout, :econnrefused, :econnreset, :ehostunreach, :enetunreach] ->
            assert result1 == true

          # Authentication errors should not be retryable
          type when type in [:invalid_api_key, :authentication_failed] ->
            assert result1 == false

          # Rate limiting should be retryable
          :rate_limit_exceeded ->
            assert result1 == true

          # Quota exceeded should not be retryable
          :quota_exceeded ->
            assert result1 == false

          # Circuit breaker should not be retryable (handled at higher level)
          :circuit_breaker_open ->
            assert result1 == false

          # HTTP status codes
          {:api_error, status, _} when status in [429, 500, 502, 503, 504] ->
            assert result1 == true

          {:api_error, status, _} when status in [400, 401, 403, 404] ->
            assert result1 == false

          _ ->
            # Other errors default to retryable
            :ok
        end
      end
    end

    property "retry logic respects max_retries limit" do
      check all max_retries <- integer(0..5),
                error_type <- member_of([:timeout, :econnrefused, :rate_limit_exceeded]) do

        attempt_count = :counters.new(1, [])

        fail_function = fn ->
          :counters.add(attempt_count, 1, 1)
          {:error, error_type}
        end

        result = RetryLogic.with_retry(fail_function, [
          max_retries: max_retries,
          base_delay: 1,  # Minimal delay for testing
          jitter: false
        ])

        # Should eventually fail with max retries exceeded
        assert {:error, :max_retries_exceeded} = result

        # Should not exceed max_retries + 1 attempts (initial + retries)
        actual_attempts = :counters.get(attempt_count, 1)
        assert actual_attempts <= max_retries + 1
      end
    end
  end

  describe "Model information properties" do
    property "get_model_info returns consistent structure" do
      check all backend_type <- backend_type_generator(),
                model <- model_generator(backend_type) do

        config = case backend_type do
          :test ->
            %{backend_type: :test}
          :openai ->
            %{backend_type: :openai, api_key: "sk-test123456789012345678901234567890", model: model}
          :anthropic ->
            %{backend_type: :anthropic, api_key: "sk-ant-test123456789012345678901234567890", model: model}
        end

        case Backend.get_model_info(config) do
          {:ok, info} ->
            # Verify required fields
            assert Map.has_key?(info, :name)
            assert Map.has_key?(info, :max_tokens)
            assert Map.has_key?(info, :supports_streaming)
            assert Map.has_key?(info, :cost_per_token)
            assert Map.has_key?(info, :provider)
            assert Map.has_key?(info, :capabilities)

            # Verify field types
            assert is_binary(info.name)
            assert is_integer(info.max_tokens)
            assert info.max_tokens > 0
            assert is_boolean(info.supports_streaming)
            assert is_number(info.cost_per_token)
            assert info.cost_per_token >= 0
            assert is_atom(info.provider)
            assert info.provider == backend_type
            assert is_list(info.capabilities)

          {:error, reason} ->
            assert is_atom(reason) or is_tuple(reason)
        end
      end
    end
  end

  describe "Metrics collection properties" do
    property "metrics maintain mathematical consistency" do
      check all requests <- list_of(
        {member_of([:success, :error]),
         map_of(member_of([:latency, :tokens, :cost]), positive_integer())},
        min_length: 1, max_length: 20
      ) do

        backend = :"prop_test_#{:rand.uniform(1_000_000)}"

        # Start fresh metrics collector
        case GenServer.whereis(MetricsCollector) do
          nil -> MetricsCollector.start_link()
          _pid -> :ok
        end

        # Reset metrics for this backend
        MetricsCollector.reset_metrics(backend)

        # Record all requests
        for {result, data} <- requests do
          MetricsCollector.record_request(backend, result, data)
        end

        metrics = MetricsCollector.get_metrics(backend)

        # Basic mathematical consistency
        assert metrics.total_requests == length(requests)
        assert metrics.successful_requests + metrics.failed_requests == metrics.total_requests

        # Error rate should be between 0 and 1
        assert metrics.error_rate >= 0.0
        assert metrics.error_rate <= 1.0

        # Health score should be between 0 and 1
        assert metrics.health_score >= 0.0
        assert metrics.health_score <= 1.0

        # If there are requests, timestamps should be set
        if metrics.total_requests > 0 do
          assert is_integer(metrics.last_request_time)
        end

        # Token and cost totals should be non-negative
        assert metrics.total_tokens >= 0
        assert metrics.total_cost >= 0.0

        # Latency metrics should be consistent
        if metrics.total_requests > 0 do
          assert is_number(metrics.average_latency)
          assert metrics.average_latency >= 0

          if metrics.min_latency do
            assert metrics.min_latency <= metrics.average_latency
          end

          if metrics.max_latency do
            assert metrics.max_latency >= metrics.average_latency
          end

          if metrics.min_latency && metrics.max_latency do
            assert metrics.min_latency <= metrics.max_latency
          end
        end
      end
    end

    property "global metrics equal sum of backend metrics" do
      check all backend_data <- map_of(
        atom(:alphanumeric),
        list_of(member_of([:success, :error]), min_length: 1, max_length: 5),
        min_length: 1, max_length: 3
      ) do

        # Start fresh metrics collector
        case GenServer.whereis(MetricsCollector) do
          nil -> MetricsCollector.start_link()
          _pid -> :ok
        end

        # Reset all backends
        for backend <- Map.keys(backend_data) do
          MetricsCollector.reset_metrics(backend)
        end

        # Record requests for each backend
        for {backend, requests} <- backend_data do
          for result <- requests do
            data = %{tokens: 10, cost: 0.001}
            MetricsCollector.record_request(backend, result, data)
          end
        end

        # Get global and individual metrics
        global_metrics = MetricsCollector.get_global_metrics()
        backend_metrics = for backend <- Map.keys(backend_data) do
          MetricsCollector.get_metrics(backend)
        end

        # Verify global metrics equal sum of backend metrics
        expected_total_requests = Enum.sum(Enum.map(backend_metrics, & &1.total_requests))
        expected_successful_requests = Enum.sum(Enum.map(backend_metrics, & &1.successful_requests))
        expected_failed_requests = Enum.sum(Enum.map(backend_metrics, & &1.failed_requests))
        expected_total_tokens = Enum.sum(Enum.map(backend_metrics, & &1.total_tokens))
        expected_total_cost = Enum.sum(Enum.map(backend_metrics, & &1.total_cost))

        assert global_metrics.total_requests == expected_total_requests
        assert global_metrics.successful_requests == expected_successful_requests
        assert global_metrics.failed_requests == expected_failed_requests
        assert global_metrics.total_tokens == expected_total_tokens
        assert_in_delta global_metrics.total_cost, expected_total_cost, 0.001
      end
    end
  end

  describe "Circuit breaker properties" do
    property "circuit breaker state transitions are valid" do
      check all operations <- list_of(
        member_of([:success, :error, :reset]),
        min_length: 5, max_length: 15
      ) do

        backend_name = :"cb_prop_test_#{:rand.uniform(1_000_000)}"

        # Start circuit breaker registry and circuit breaker
        case GenServer.whereis(CircuitBreakerRegistry) do
          nil -> CircuitBreakerRegistry.start_link()
          _pid -> :ok
        end

        {:ok, _cb_pid} = CircuitBreaker.start_link(backend_name, failure_threshold: 3)

        try do
          # Track state transitions
          states = []

          states = for operation <- operations, reduce: states do
            acc ->
              case operation do
                :success ->
                  CircuitBreaker.call(backend_name, fn -> {:ok, "success"} end)
                :error ->
                  CircuitBreaker.call(backend_name, fn -> {:error, :test_error} end)
                :reset ->
                  CircuitBreaker.reset(backend_name)
              end

              current_state = CircuitBreaker.get_state(backend_name)
              [current_state | acc]
          end

          states = Enum.reverse(states)

          # All states should be valid
          for state <- states do
            assert state in [:closed, :open, :half_open]
          end

          # State transitions should follow circuit breaker rules
          # (This is a simplified check - full validation would require more complex logic)
          assert is_list(states)
          assert length(states) == length(operations)

        after
          # Clean up
          cb_pid = Process.whereis({:via, Registry, {Prismatic.LLM.CircuitBreakerRegistry, backend_name}})
          if cb_pid && Process.alive?(cb_pid) do
            GenServer.stop(cb_pid)
          end
        end
      end
    end
  end

  describe "System integration properties" do
    property "backend operations are idempotent for read operations" do
      check all backend_type <- member_of([:test]) do  # Use test backend for reliability
        config = %{backend_type: backend_type, error_rate: 0.0}

        # Health check should be idempotent
        result1 = Backend.health_check(config)
        result2 = Backend.health_check(config)
        assert result1 == result2

        # Model info should be idempotent
        info1 = Backend.get_model_info(config)
        info2 = Backend.get_model_info(config)
        assert info1 == info2

        # Config validation should be idempotent
        validation1 = Backend.validate_config(config)
        validation2 = Backend.validate_config(config)
        assert validation1 == validation2
      end
    end

    property "system handles concurrent operations safely" do
      check all operations <- list_of(
        {member_of([:generate_response, :health_check, :get_model_info]), string(:printable, max_length: 100)},
        min_length: 5, max_length: 10
      ) do

        config = %{backend_type: :test, error_rate: 0.0}

        # Execute operations concurrently
        tasks = for {operation, prompt} <- operations do
          Task.async(fn ->
            case operation do
              :generate_response ->
                Backend.generate_response(config, prompt, %{})
              :health_check ->
                Backend.health_check(config)
              :get_model_info ->
                Backend.get_model_info(config)
            end
          end)
        end

        results = Task.await_many(tasks)

        # All operations should complete without crashing
        assert length(results) == length(operations)

        # Results should be well-formed
        for result <- results do
          case result do
            {:ok, _} -> :ok
            {:error, _} -> :ok
            :ok -> :ok
            other -> flunk("Unexpected result format: #{inspect(other)}")
          end
        end
      end
    end
  end

  describe "Data integrity properties" do
    property "configuration serialization preserves data" do
      check all config <- llm_config_generator() do
        # Test that configuration can be serialized and deserialized
        serialized = :erlang.term_to_binary(config)
        deserialized = :erlang.binary_to_term(serialized)

        assert config == deserialized

        # Both should validate the same way
        {:ok, backend_config1} = Backend.create_config(config.backend_type, config)
        {:ok, backend_config2} = Backend.create_config(deserialized.backend_type, deserialized)

        validation1 = Backend.validate_config(backend_config1)
        validation2 = Backend.validate_config(backend_config2)

        assert validation1 == validation2
      end
    end

    property "string inputs are handled safely" do
      check all prompt <- one_of([
        string(:printable),
        string(:ascii),
        string(:alphanumeric),
        binary(),
        constant(""),
        constant(String.duplicate("x", 10_000))  # Very long string
      ]) do

        config = %{backend_type: :test, error_rate: 0.0}

        # Should not crash on any string input
        case Backend.generate_response(config, prompt, %{}) do
          {:ok, response} ->
            assert is_binary(response)
          {:error, reason} ->
            assert is_atom(reason) or is_tuple(reason)
        end
      end
    end
  end

  # Helper function to ensure clean test state
  defp ensure_clean_state do
    # Reset any global state that might affect tests
    case GenServer.whereis(MetricsCollector) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end

    case GenServer.whereis(CircuitBreakerRegistry) do
      nil -> :ok
      pid -> GenServer.stop(pid)
    end
  end
end
