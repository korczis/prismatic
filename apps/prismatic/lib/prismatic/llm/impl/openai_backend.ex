defmodule Prismatic.LLM.Impl.OpenAIBackend do
  @moduledoc """
  OpenAI backend implementation for the Prismatic LLM system.

  This module provides integration with OpenAI's GPT models through their API.
  It implements the `Prismatic.LLM.Backend` behavior with full support for
  circuit breakers, retries, and comprehensive error handling.

  ## Features

  - Support for GPT-4, GPT-3.5-turbo, and other OpenAI models
  - Streaming and non-streaming responses
  - Token usage tracking and cost estimation
  - Rate limiting and quota management
  - Comprehensive error handling and recovery

  ## Configuration

  ```elixir
  config = %{
    backend_type: :openai,
    api_key: "your-openai-api-key",
    model: "gpt-4",
    timeout: 30_000,
    max_retries: 3,
    base_url: "https://api.openai.com/v1"
  }
  ```
  """

  @behaviour Prismatic.LLM.Backend

  require Logger

  alias Prismatic.LLM.Backend.{CircuitBreaker, MetricsCollector, RetryLogic}

  @default_model "gpt-4"
  @default_timeout 30_000
  @default_max_tokens 4096
  @default_temperature 0.7
  @base_url "https://api.openai.com/v1"

  @impl true
  def generate_response(config, prompt, context \\ %{}) do
    with :ok <- validate_config(config),
         {:ok, request_body} <- build_request_body(config, prompt, context),
         {:ok, response} <- make_api_request(config, request_body) do

      # Track metrics
      MetricsCollector.record_request(:openai, :success, response)

      parse_response(response)
    else
      {:error, reason} = error ->
        MetricsCollector.record_request(:openai, :error, reason)
        Logger.error("OpenAI API request failed: #{inspect(reason)}")
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
        messages: [%{role: "user", content: "test"}],
        max_tokens: 1
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
      provider: :openai,
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
    if String.starts_with?(api_key, "sk-") and String.length(api_key) > 20 do
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
      messages: messages,
      max_tokens: max_tokens,
      temperature: temperature
    }

    # Add optional parameters if present
    request_body =
      request_body
      |> maybe_add_stream(context)
      |> maybe_add_functions(context)
      |> maybe_add_user_id(context)

    {:ok, request_body}
  end

  defp format_messages(prompt, context) do
    system_message = Map.get(context, :system_message)
    conversation_history = Map.get(context, :conversation_history, [])

    messages = []

    # Add system message if present
    messages = if system_message do
      [%{role: "system", content: system_message} | messages]
    else
      messages
    end

    # Add conversation history
    messages = messages ++ conversation_history

    # Add current user message
    messages ++ [%{role: "user", content: prompt}]
  end

  defp maybe_add_stream(request_body, context) do
    if Map.get(context, :stream, false) do
      Map.put(request_body, :stream, true)
    else
      request_body
    end
  end

  defp maybe_add_functions(request_body, context) do
    case Map.get(context, :functions) do
      nil -> request_body
      functions -> Map.put(request_body, :functions, functions)
    end
  end

  defp maybe_add_user_id(request_body, context) do
    case Map.get(context, :user_id) do
      nil -> request_body
      user_id -> Map.put(request_body, :user, user_id)
    end
  end

  defp make_api_request(config, request_body) do
    url = build_api_url(config)
    headers = build_headers(config)
    timeout = Map.get(config, :timeout, @default_timeout)

    json_body = Jason.encode!(request_body)

    # Use circuit breaker and retry logic
    CircuitBreaker.call(:openai, fn ->
      RetryLogic.with_retry(fn ->
        execute_http_request(url, json_body, headers, timeout)
      end, max_retries: Map.get(config, :max_retries, 3))
    end)
  end

  defp execute_http_request(url, json_body, headers, timeout) do
    case Req.post(url,
      body: json_body,
      headers: headers,
      receive_timeout: timeout,
      retry: false  # We handle retries ourselves
    ) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}
      {:ok, %{status: status, body: body}} ->
        {:error, {:api_error, status, body}}
      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp build_api_url(config) do
    base_url = Map.get(config, :base_url, @base_url)
    "#{base_url}/chat/completions"
  end

  defp build_headers(config) do
    [
      {"Authorization", "Bearer #{config.api_key}"},
      {"Content-Type", "application/json"},
      {"User-Agent", "Prismatic-AI-Framework/1.0"}
    ]
  end

  defp parse_response(response_body) do
    case response_body do
      %{"choices" => [%{"message" => %{"content" => content}} | _]} ->
        {:ok, String.trim(content)}

      %{"error" => %{"message" => error_message}} ->
        {:error, {:api_error, error_message}}

      _ ->
        {:error, {:invalid_response_format, response_body}}
    end
  end

  defp get_model_max_tokens("gpt-4"), do: 8192
  defp get_model_max_tokens("gpt-4-32k"), do: 32_768
  defp get_model_max_tokens("gpt-3.5-turbo"), do: 4096
  defp get_model_max_tokens("gpt-3.5-turbo-16k"), do: 16_384
  defp get_model_max_tokens(_), do: 4096

  defp get_model_cost_per_token("gpt-4"), do: 0.00003
  defp get_model_cost_per_token("gpt-4-32k"), do: 0.00006
  defp get_model_cost_per_token("gpt-3.5-turbo"), do: 0.000002
  defp get_model_cost_per_token("gpt-3.5-turbo-16k"), do: 0.000004
  defp get_model_cost_per_token(_), do: 0.00002

  defp get_model_capabilities("gpt-4") do
    [:chat, :function_calling, :json_mode, :vision]
  end

  defp get_model_capabilities("gpt-3.5-turbo") do
    [:chat, :function_calling, :json_mode]
  end

  defp get_model_capabilities(_) do
    [:chat]
  end
end
