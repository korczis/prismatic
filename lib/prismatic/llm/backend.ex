defmodule Prismatic.LLM.Backend do
  @moduledoc """
  LLM backend behavior specification for the Prismatic system.

  This module defines the behavior that all LLM backend implementations
  must support. It provides a unified interface for different LLM providers
  (OpenAI, Anthropic, local models, etc.) ensuring consistent integration
  across the Prismatic system.

  ## Status

  🚧 **PLACEHOLDER - PLANNED IMPLEMENTATION**

  This file is a placeholder created to resolve documentation links.
  The actual implementation is planned for Phase 1 of the Prismatic
  architecture development (see docs/architecture/README.md).

  ## Supported Backends

  - `:openai` - OpenAI GPT models
  - `:anthropic` - Anthropic Claude models
  - `:local` - Local model implementations
  - `:test` - Test backend for development

  ## Behavior Callbacks

  - `generate_response/3` - Generate response from prompt
  - `validate_config/1` - Validate backend configuration
  - `health_check/1` - Check backend availability
  - `get_model_info/1` - Get model capabilities

  ## Implementation Notes

  When implementing this behavior, ensure:
  - Proper error handling for network failures
  - Rate limiting and retry mechanisms
  - Configuration validation
  - Consistent response formatting
  - Timeout handling

  ## See Also

  - `docs/architecture/bulletproof-foundations.md` - Core architectural patterns
  - `docs/architecture/bulletproof-foundations-part2.md` - LLM backend specifications
  """

  @type config :: map()
  @type prompt :: String.t()
  @type context :: map()
  @type response :: String.t()
  @type model_info :: %{
    name: String.t(),
    max_tokens: integer(),
    supports_streaming: boolean(),
    cost_per_token: float()
  }

  @doc """
  Generate a response from the given prompt and context.

  ## Parameters

  - `config` - Backend configuration
  - `prompt` - The input prompt string
  - `context` - Additional context information

  ## Returns

  - `{:ok, response}` - Successfully generated response
  - `{:error, reason}` - Generation failed
  """
  @callback generate_response(config(), prompt(), context()) ::
    {:ok, response()} | {:error, term()}

  @doc """
  Validate the backend configuration.

  ## Parameters

  - `config` - Configuration to validate

  ## Returns

  - `:ok` - Configuration is valid
  - `{:error, reason}` - Configuration is invalid
  """
  @callback validate_config(config()) :: :ok | {:error, term()}

  @doc """
  Check if the backend is healthy and available.

  ## Parameters

  - `config` - Backend configuration

  ## Returns

  - `:ok` - Backend is healthy
  - `{:error, reason}` - Backend is unavailable
  """
  @callback health_check(config()) :: :ok | {:error, term()}

  @doc """
  Get information about the model capabilities.

  ## Parameters

  - `config` - Backend configuration

  ## Returns

  - `{:ok, model_info}` - Model information
  - `{:error, reason}` - Failed to get model info
  """
  @callback get_model_info(config()) :: {:ok, model_info()} | {:error, term()}

  @doc """
  Create a new backend configuration.

  ## Parameters

  - `backend_type` - Type of backend (:openai, :anthropic, :local, :test)
  - `options` - Backend-specific options

  ## Returns

  - `{:ok, config}` - Valid configuration
  - `{:error, reason}` - Invalid configuration
  """
  @spec create_config(atom(), map()) :: {:ok, config()} | {:error, term()}
  def create_config(backend_type, options \\ %{}) do
    base_config = %{
      backend_type: backend_type,
      timeout: 30_000,
      max_retries: 3,
      retry_delay: 1_000
    }

    config = Map.merge(base_config, options)

    case validate_backend_type(backend_type) do
      :ok -> {:ok, config}
      error -> error
    end
  end

  @doc """
  List all available backend types.

  ## Returns

  List of supported backend atoms.
  """
  @spec available_backends() :: [atom()]
  def available_backends do
    [:openai, :anthropic, :local, :test]
  end

  # Private helper functions

  defp validate_backend_type(backend_type) when backend_type in [:openai, :anthropic, :local, :test] do
    :ok
  end

  defp validate_backend_type(backend_type) do
    {:error, {:invalid_backend_type, backend_type}}
  end
end
