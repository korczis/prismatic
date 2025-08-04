defmodule Prismatic.LLM.Impl.AnthropicBackend do
  @moduledoc """
  Anthropic backend implementation for the Prismatic LLM system.

  This module provides integration with Anthropic's Claude models through their API.
  It implements the `Prismatic.LLM.Backend` behavior with full support for
  circuit breakers, retries, and comprehensive error handling.

  ## Features

  - Support for Claude-3 Opus, Sonnet, and Haiku models
  - Streaming and non-streaming responses
  - Token usage tracking and cost estimation
  - Rate limiting and quota management
  - Comprehensive error handling and recovery

  ## Configuration

  ```elixir
  config = %{
    backend_type: :anthropic,
    api_key: "your-anthropic-api-key",
    model: "claude-3-sonnet-20240229",
    timeout: 30_000,
    max_retries: 3,
    base_url: "https://api.anthropic.com"
  }
  ```
  """

  @behaviour Prismatic.LLM.Backend

  require Logger

  alias Prismatic.LLM.Backend.{CircuitBreaker, MetricsCollector, RetryLogic}

  @default_model "claude-3-sonnet-20240229"
  @default_timeout 30_000
  @default_max_tokens 4096
  @default_temperature 0.7
  @base_url "https://api.anthropic.com"
  @api_version "2023-06-01"

  @impl true
  def generate_response(config, prompt, context \\ %{}) do
    with :ok <- validate_config(config),
         {:ok, request_body} <- build_request_body(config, prompt, context),
         {:ok, response} <- make_api_request(config, request_body) do

      # Track metrics
      MetricsCollector.record_request(:anthropic, :success, response)

      parse_response(response)
    else
      {:error, reason} = error ->
        MetricsCollector.record_request(:anthropic, :error, reason)
        Logger.error("Anthropic API request failed: #{inspect(reason)}")
        error
    end
  end

  @impl true
  def validate_config(config) do
    required_fields = [:backend_type, :api_key]

    case validate_required_fields(config, required_fields) do
      :ok -> validate_api_key_format(config.api_key)
      error -> error
    end
  end

  @impl true
  def health_check(config) do
    with :ok <- validate_config(config) do
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
  end

  @impl true
  def get_model_info(config) do
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

  # Private helper functions

  defp validate_required_fields(config, required_fields) do
    missing_fields = Enum.filter(required_fields, fn field ->
      not Map.has_key?(config, field) or is_nil(Map.get(config, field))
    end)

    case missing_fields do
      [] -> :ok
      fields -> {:error, {:missing_required_fields, fields}}
    end
  end

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
    timeout = Map.get(config, :timeout, @default_timeout)

    # Configure Anthropix client
    anthropix_config = [
      api_key: config.api_key,
      http_options: [receive_timeout: timeout]
    ]

    # Use circuit breaker and retry logic
    CircuitBreaker.call(:anthropic, fn ->
      RetryLogic.with_retry(fn ->
        execute_anthropix_request(request_body, anthropix_config)
      end, max_retries: Map.get(config, :max_retries, 3))
    end)
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
