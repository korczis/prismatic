defmodule Prismatic.LLM.Impl.AnthropicBackend do
  @moduledoc """
  Anthropic backend implementation for the Prismatic LLM system.

  This module provides integration with Anthropic's Claude models through their API.
  It uses the shared backend macro for automatic circuit breaker, retry logic,
  telemetry, and error handling functionality.

  ## Features

  - Support for Claude-3 Opus, Sonnet, and Haiku models
  - Streaming and non-streaming responses
  - Token usage tracking and cost estimation
  - Rate limiting and quota management
  - Automatic circuit breaker protection and retry logic
  - Comprehensive telemetry and error handling

  ## Configuration

  ```elixir
  config = %{
    backend_type: :anthropic,
    name: :anthropic_backend,
    api_key: "your-anthropic-api-key",
    model: "claude-3-sonnet-20240229",
    timeout: 30_000,
    max_retries: 3,
    base_url: "https://api.anthropic.com"
  }
  ```
  """

  use Prismatic.Shared.Backend,
    system: :llm,
    required_config_fields: [:api_key],
    circuit_breaker_config: [
      failure_threshold: 5,
      recovery_timeout: 60_000,
      success_threshold: 3
    ],
    telemetry_prefix: [:prismatic, :llm, :backend],
    default_timeout: 30_000,
    default_max_retries: 3

  require Logger

  @default_model "claude-3-sonnet-20240229"
  @default_max_tokens 4096
  @default_temperature 0.7
  @base_url "https://api.anthropic.com"
  @api_version "2023-06-01"

  ## Required Callback Implementations

  @impl Prismatic.Shared.Backend
  def execute_operation(config, :generate_response, {prompt, context}) do
    with {:ok, request_body} <- build_request_body(config, prompt, context),
         {:ok, response} <- make_api_request(config, request_body) do
      parse_response(response)
    end
  end

  def execute_operation(config, :get_model_info, _params) do
    model = Map.get(config, :model, @default_model)

    model_info = %{
      name: model,
      max_tokens: get_model_max_tokens(model),
      supports_streaming: true,
      cost_per_token: get_model_cost_per_token(model),
      provider: :anthropic,
      capabilities: get_model_capabilities(model)
    }

    {:ok, model_info}
  end

  @impl Prismatic.Shared.Backend
  def validate_system_config(config) do
    with :ok <- validate_api_key_format(config.api_key) do
      :ok
    end
  end

  @impl Prismatic.Shared.Backend
  def perform_health_check(config) do
    # Make a minimal API call to check connectivity
    test_request = %{
      model: Map.get(config, :model, @default_model),
      max_tokens: 1,
      messages: [%{role: "user", content: "test"}]
    }

    case make_api_request(config, test_request) do
      {:ok, _response} -> :ok
      {:error, reason} -> {:error, {:health_check_failed, reason}}
    end
  end

  @impl Prismatic.Shared.Backend
  def get_backend_info(config) do
    model = Map.get(config, :model, @default_model)

    info = %{
      backend_type: :anthropic,
      name: Map.get(config, :name, :anthropic_backend),
      model: model,
      max_tokens: get_model_max_tokens(model),
      supports_streaming: true,
      cost_per_token: get_model_cost_per_token(model),
      provider: :anthropic,
      capabilities: get_model_capabilities(model),
      base_url: Map.get(config, :base_url, @base_url),
      api_version: @api_version
    }

    {:ok, info}
  end

  ## Public API (maintains compatibility with original)

  def generate_response(config, prompt, context \\ %{}) do
    handle_circuit_breaker(config, fn ->
      with_retry(fn ->
        execute_operation(config, :generate_response, {prompt, context})
      end, config)
    end)
  end

  def get_model_info(config) do
    handle_circuit_breaker(config, fn ->
      execute_operation(config, :get_model_info, nil)
    end)
  end

  ## Enhanced Error Classification for Anthropic Operations

  # Anthropic-specific error classification
  def classify_error({:api_error, "invalid_request_error", _}), do: {:non_retryable, :validation_error}
  def classify_error({:api_error, "authentication_error", _}), do: {:non_retryable, :authentication_error}
  def classify_error({:api_error, "permission_error", _}), do: {:non_retryable, :authorization_error}
  def classify_error({:api_error, "not_found_error", _}), do: {:non_retryable, :not_found}
  def classify_error({:api_error, "rate_limit_error", _}), do: {:retryable, :rate_limit}
  def classify_error({:api_error, "api_error", _}), do: {:retryable, :server_error}
  def classify_error({:api_error, "overloaded_error", _}), do: {:retryable, :server_error}
  def classify_error({:api_error, status, _}) when status in 500..599, do: {:retryable, :server_error}
  def classify_error({:api_error, 429, _}), do: {:retryable, :rate_limit}
  def classify_error({:api_error, status, _}) when status in 400..499, do: {:non_retryable, :client_error}
  def classify_error(:invalid_api_key_format), do: {:non_retryable, :authentication_error}
  def classify_error({:request_failed, _}), do: {:retryable, :network_error}

  # Fall back to base classification
  def classify_error(error), do: super(error)

  ## Private Implementation (Anthropic-specific logic only)

  defp validate_api_key_format(api_key) when is_binary(api_key) do
    if String.starts_with?(api_key, "sk-ant-") and String.length(api_key) > 20 do
      :ok
    else
      {:error, :invalid_api_key_format}
    end
  end

  defp validate_api_key_format(_), do: {:error, :invalid_api_key_format}

  defp build_request_body(config, prompt, context) do
    model = Map.get(config, :model, @default_model)
    max_tokens = Map.get(context, :max_tokens, @default_max_tokens)
    temperature = Map.get(context, :temperature, @default_temperature)

    messages = format_messages(prompt, context)

    request_body = %{
      model: model,
      max_tokens: max_tokens,
      temperature: temperature,
      messages: messages
    }

    # Add optional parameters if present
    request_body =
      request_body
      |> maybe_add_system_message(context)
      |> maybe_add_stream(context)
      |> maybe_add_stop_sequences(context)

    {:ok, request_body}
  end

  defp format_messages(prompt, context) do
    conversation_history = Map.get(context, :conversation_history, [])

    # Add conversation history
    messages = conversation_history

    # Add current user message
    messages ++ [%{role: "user", content: prompt}]
  end

  defp maybe_add_system_message(request_body, context) do
    case Map.get(context, :system_message) do
      nil -> request_body
      system_message -> Map.put(request_body, :system, system_message)
    end
  end

  defp maybe_add_stream(request_body, context) do
    if Map.get(context, :stream, false) do
      Map.put(request_body, :stream, true)
    else
      request_body
    end
  end

  defp maybe_add_stop_sequences(request_body, context) do
    case Map.get(context, :stop_sequences) do
      nil -> request_body
      stop_sequences -> Map.put(request_body, :stop_sequences, stop_sequences)
    end
  end

  defp make_api_request(config, request_body) do
    timeout = Map.get(config, :timeout, 30_000)

    # Configure Anthropix client
    anthropix_config = [
      api_key: config.api_key,
      http_options: [receive_timeout: timeout]
    ]

    execute_anthropix_request(request_body, anthropix_config)
  end

  defp execute_anthropix_request(request_body, anthropix_config) do
    case Anthropix.completion(request_body, anthropix_config) do
      {:ok, response} ->
        {:ok, response}
      {:error, %{"error" => %{"message" => message, "type" => type}}} ->
        {:error, {:api_error, type, message}}
      {:error, %{status: status} = error} ->
        {:error, {:api_error, status, error}}
      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp parse_response(response_body) do
    case response_body do
      %{"content" => [%{"text" => content} | _]} ->
        {:ok, String.trim(content)}

      %{"error" => %{"message" => error_message}} ->
        {:error, {:api_error, error_message}}

      _ ->
        {:error, {:invalid_response_format, response_body}}
    end
  end

  defp get_model_max_tokens("claude-3-opus-20240229"), do: 200_000
  defp get_model_max_tokens("claude-3-sonnet-20240229"), do: 200_000
  defp get_model_max_tokens("claude-3-haiku-20240307"), do: 200_000
  defp get_model_max_tokens("claude-2.1"), do: 200_000
  defp get_model_max_tokens("claude-2.0"), do: 100_000
  defp get_model_max_tokens("claude-instant-1.2"), do: 100_000
  defp get_model_max_tokens(_), do: 100_000

  defp get_model_cost_per_token("claude-3-opus-20240229"), do: 0.000015
  defp get_model_cost_per_token("claude-3-sonnet-20240229"), do: 0.000003
  defp get_model_cost_per_token("claude-3-haiku-20240307"), do: 0.00000025
  defp get_model_cost_per_token("claude-2.1"), do: 0.000008
  defp get_model_cost_per_token("claude-2.0"), do: 0.000008
  defp get_model_cost_per_token("claude-instant-1.2"), do: 0.0000008
  defp get_model_cost_per_token(_), do: 0.000008

  defp get_model_capabilities("claude-3-opus-20240229") do
    [:chat, :vision, :document_analysis, :code_generation, :reasoning]
  end

  defp get_model_capabilities("claude-3-sonnet-20240229") do
    [:chat, :vision, :document_analysis, :code_generation, :reasoning]
  end

  defp get_model_capabilities("claude-3-haiku-20240307") do
    [:chat, :document_analysis, :code_generation]
  end

  defp get_model_capabilities(_) do
    [:chat, :document_analysis]
  end
end
