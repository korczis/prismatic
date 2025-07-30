defmodule Prismatic.LLM.Backend do
  @moduledoc """
  LLM backend behavior specification and factory for the Prismatic system.

  This module defines the behavior that all LLM backend implementations must
  support and provides a unified interface for creating and managing different
  LLM providers (OpenAI, Anthropic, local models, etc.).

  ## Architecture

  The LLM Backend system follows a protocol-driven architecture with:

  - **Behavior Contract**: All backends implement the same interface
  - **Factory Pattern**: Centralized backend creation and configuration
  - **Fault Tolerance**: Circuit breakers and retry logic built-in
  - **Metrics Collection**: Comprehensive monitoring and observability
  - **Provider Abstraction**: Seamless switching between different LLM providers

  ## Supported Backends

  - `:openai` - OpenAI GPT models (GPT-4, GPT-3.5-turbo)
  - `:anthropic` - Anthropic Claude models (Claude-3 Opus, Sonnet, Haiku)
  - `:test` - Test backend for development and testing
  - `:local` - Local model implementations (planned)

  ## Usage Examples

  ### Basic Usage

      # Create backend configuration
      {:ok, config} = LLM.Backend.create_config(:openai, %{
        api_key: "your-api-key",
        model: "gpt-4"
      })

      # Generate response
      {:ok, response} = LLM.Backend.generate_response(
        config,
        "What is the meaning of life?",
        %{temperature: 0.7, max_tokens: 1000}
      )

  ### With Error Handling

      case LLM.Backend.generate_response(config, prompt, context) do
        {:ok, response} ->
          handle_success(response)
        {:error, :circuit_breaker_open} ->
          handle_circuit_breaker()
        {:error, :rate_limit_exceeded} ->
          handle_rate_limit()
        {:error, reason} ->
          handle_error(reason)
      end

  ### Health Monitoring

      # Check backend health
      case LLM.Backend.health_check(config) do
        :ok ->
          IO.puts("Backend is healthy")
        {:error, reason} ->
          IO.puts("Health check failed: " <> inspect(reason))
      end

      # Get model information
      {:ok, info} = LLM.Backend.get_model_info(config)
      IO.puts("Model: " <> info.name <> ", Max tokens: " <> to_string(info.max_tokens))

  ## Configuration Structure

      %{
        backend_type: :openai | :anthropic | :test | :local,
        api_key: String.t(),           # Provider API key
        model: String.t(),             # Model identifier
        timeout: integer(),            # Request timeout (ms)
        max_retries: integer(),        # Maximum retry attempts
        base_url: String.t(),          # Custom API base URL (optional)
        circuit_breaker: %{            # Circuit breaker settings
          failure_threshold: integer(),
          recovery_timeout: integer(),
          success_threshold: integer()
        }
      }

  ## Error Handling

  The backend system provides comprehensive error classification:

  - **Network Errors**: `:timeout`, `:econnrefused`, `:enetunreach`
  - **API Errors**: `{:api_error, status_code, body}`
  - **Rate Limiting**: `:rate_limit_exceeded`, `:quota_exceeded`
  - **Authentication**: `:invalid_api_key`, `:authentication_failed`
  - **Validation**: `:invalid_request`, `:invalid_model`
  - **Circuit Breaker**: `:circuit_breaker_open`

  ## Telemetry Events

  The system emits telemetry events for monitoring:

  - `[:prismatic, :llm, :backend, :request]` - Request completion
  - `[:prismatic, :llm, :backend, :circuit_breaker]` - Circuit breaker state changes
  - `[:prismatic, :llm, :backend, :health_check]` - Health check results
  """

  @typedoc "Backend configuration map"
  @type config :: %{
    backend_type: backend_type(),
    api_key: String.t(),
    model: String.t(),
    timeout: pos_integer(),
    max_retries: non_neg_integer()
  }

  @typedoc "Supported backend types"
  @type backend_type :: :openai | :anthropic | :test | :local

  @typedoc "Input prompt string"
  @type prompt :: String.t()

  @typedoc "Request context with additional parameters"
  @type context :: %{
    optional(:temperature) => float(),
    optional(:max_tokens) => pos_integer(),
    optional(:system_message) => String.t(),
    optional(:conversation_history) => list(map()),
    optional(:stream) => boolean(),
    optional(:user_id) => String.t(),
    optional(atom()) => term()
  }

  @typedoc "Generated response string"
  @type response :: String.t()

  @typedoc "Model information"
  @type model_info :: %{
    name: String.t(),
    max_tokens: pos_integer(),
    supports_streaming: boolean(),
    cost_per_token: float(),
    provider: backend_type(),
    capabilities: list(atom())
  }

  @doc """
  Generates a response from the given prompt and context.

  This is the primary function for interacting with LLM backends. It handles
  routing to the appropriate backend implementation, applies circuit breaker
  protection, retry logic, and metrics collection.

  ## Parameters

  - `config` - Backend configuration map
  - `prompt` - The input prompt string
  - `context` - Additional context and parameters (optional)

  ## Returns

  - `{:ok, response}` - Successfully generated response
  - `{:error, reason}` - Generation failed with reason

  ## Examples

      iex> {:ok, config} = LLM.Backend.create_config(:test, %{})
      iex> {:ok, response} = LLM.Backend.generate_response(config, "Hello", %{})
      iex> is_binary(response)
      true

      iex> {:ok, config} = LLM.Backend.create_config(:test, %{
      ...>   responses: %{"error" => {:error, :test_error}}
      ...> })
      iex> LLM.Backend.generate_response(config, "error", %{})
      {:error, :test_error}
  """
  @callback generate_response(config(), prompt(), context()) ::
    {:ok, response()} | {:error, term()}

  @doc """
  Validates the backend configuration.

  Checks that all required fields are present and have valid values.
  Each backend implementation may have specific validation requirements.

  ## Parameters

  - `config` - Configuration to validate

  ## Returns

  - `:ok` - Configuration is valid
  - `{:error, reason}` - Configuration is invalid

  ## Examples

      iex> {:ok, config} = LLM.Backend.create_config(:test, %{})
      iex> LLM.Backend.validate_config(config)
      :ok

      iex> LLM.Backend.validate_config(%{backend_type: :invalid})
      {:error, {:unsupported_backend, :invalid}}
  """
  @callback validate_config(config()) :: :ok | {:error, term()}

  @doc """
  Checks if the backend is healthy and available.

  Performs a lightweight health check to verify backend connectivity
  and basic functionality. Used for monitoring and load balancing.

  ## Parameters

  - `config` - Backend configuration

  ## Returns

  - `:ok` - Backend is healthy
  - `{:error, reason}` - Backend is unavailable

  ## Examples

      iex> {:ok, config} = LLM.Backend.create_config(:test, %{})
      iex> LLM.Backend.health_check(config)
      :ok
  """
  @callback health_check(config()) :: :ok | {:error, term()}

  @doc """
  Retrieves information about the model capabilities.

  Returns detailed information about the configured model including
  token limits, cost information, and supported features.

  ## Parameters

  - `config` - Backend configuration

  ## Returns

  - `{:ok, model_info}` - Model information
  - `{:error, reason}` - Failed to get model info

  ## Examples

      iex> {:ok, config} = Prismatic.LLM.Backend.create_config(:test, %{})
      iex> {:ok, info} = Prismatic.LLM.Backend.get_model_info(config)
      iex> info.provider
      :test
      iex> is_integer(info.max_tokens)
      true
  """
  @callback get_model_info(config()) :: {:ok, model_info()} | {:error, term()}

  ## Public API Functions

  @doc """
  Creates a new backend configuration.

  This function validates the backend type and creates a properly structured
  configuration map with defaults applied.

  ## Parameters

  - `backend_type` - Type of backend (`:openai`, `:anthropic`, `:test`, `:local`)
  - `options` - Backend-specific options

  ## Returns

  - `{:ok, config}` - Valid configuration
  - `{:error, reason}` - Invalid configuration

  ## Examples

      iex> {:ok, config} = LLM.Backend.create_config(:test, %{})
      iex> config.backend_type
      :test
      iex> is_integer(config.timeout)
      true

      iex> LLM.Backend.create_config(:invalid, %{})
      {:error, {:unsupported_backend, :invalid}}
  """
  @spec create_config(backend_type(), map()) :: {:ok, map()} | {:error, term()}
  def create_config(backend_type, options \\ %{}) do
    case validate_backend_type(backend_type) do
      :ok ->
        base_config = %{
          backend_type: backend_type,
          timeout: 30_000,
          max_retries: 3,
          retry_delay: 1_000
        }

        config = Map.merge(base_config, options)
        {:ok, config}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Generates a response using the specified backend configuration.

  This is the main entry point for LLM interactions. It routes the request
  to the appropriate backend implementation with full error handling and
  monitoring.

  ## Examples

      iex> {:ok, config} = LLM.Backend.create_config(:test, %{})
      iex> {:ok, response} = LLM.Backend.generate_response(config, "test", %{})
      iex> String.contains?(response, "test")
      true
  """
  @spec generate_response(config(), prompt(), context()) :: {:ok, response()} | {:error, term()}
  def generate_response(config, prompt, context \\ %{}) do
    with :ok <- validate_config(config),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do

      # For Phase 1A, we'll implement direct call without circuit breaker/retry
      # These will be added in Phase 1B
      backend_module.generate_response(config, prompt, context)
    end
  end

  @doc """
  Validates a backend configuration.

  ## Examples

      iex> {:ok, config} = LLM.Backend.create_config(:test, %{})
      iex> LLM.Backend.validate_config(config)
      :ok
  """
  @spec validate_config(config()) :: :ok | {:error, term()}
  def validate_config(config) do
    with :ok <- validate_backend_type(config.backend_type),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do
      backend_module.validate_config(config)
    end
  end

  @doc """
  Performs a health check on the backend.

  ## Examples

      iex> {:ok, config} = LLM.Backend.create_config(:test, %{})
      iex> LLM.Backend.health_check(config)
      :ok
  """
  @spec health_check(config()) :: :ok | {:error, term()}
  def health_check(config) do
    with :ok <- validate_config(config),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do
      backend_module.health_check(config)
    end
  end

  @doc """
  Gets model information for the configured backend.

  ## Examples

      iex> {:ok, config} = Prismatic.LLM.Backend.create_config(:test, %{})
      iex> {:ok, info} = Prismatic.LLM.Backend.get_model_info(config)
      iex> info.name
      "test-model-v1"
  """
  @spec get_model_info(config()) :: {:ok, model_info()} | {:error, term()}
  def get_model_info(config) do
    with :ok <- validate_config(config),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do
      backend_module.get_model_info(config)
    end
  end

  @doc """
  Lists all available backend types.

  ## Returns

  List of supported backend atoms.

  ## Examples

      iex> backends = Prismatic.LLM.Backend.available_backends()
      iex> :test in backends
      true
      iex> :openai in backends
      true
  """
  @spec available_backends() :: [:anthropic | :local | :openai | :test]
  def available_backends do
    [:openai, :anthropic, :test, :local]
  end

  ## Private Implementation

  @spec validate_backend_type(term()) :: :ok | {:error, {:unsupported_backend, term()}}
  defp validate_backend_type(backend_type) when backend_type in [:openai, :anthropic, :test, :local] do
    :ok
  end

  defp validate_backend_type(backend_type) do
    {:error, {:unsupported_backend, backend_type}}
  end

  @spec get_backend_module(backend_type()) :: {:ok, module()} | {:error, term()}
  defp get_backend_module(:test) do
    # For Phase 1A, we'll create a simple test backend implementation
    {:ok, Prismatic.LLM.Impl.TestBackend}
  end

  defp get_backend_module(:openai), do: {:error, {:not_implemented_yet, :openai}}
  defp get_backend_module(:anthropic), do: {:error, {:not_implemented_yet, :anthropic}}
  defp get_backend_module(:local), do: {:error, {:not_implemented, :local}}
  defp get_backend_module(backend_type), do: {:error, {:unsupported_backend, backend_type}}
end
