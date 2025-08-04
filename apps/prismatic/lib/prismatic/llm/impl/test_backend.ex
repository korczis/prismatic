defmodule Prismatic.LLM.Impl.TestBackend do
  @moduledoc """
  Test backend implementation for the Prismatic LLM system.

  This module provides a test implementation that can be used for development,
  testing, and demonstration purposes. It implements the `Prismatic.LLM.Backend`
  behavior with configurable responses and predictable behavior.

  ## Features

  - Configurable responses for different prompts
  - Deterministic behavior for testing
  - Simulated latency and error conditions
  - Token usage simulation
  - No external API dependencies

  ## Configuration

  ```elixir
  config = %{
    backend_type: :test,
    responses: %{
      "hello" => "Hello! How can I help you today?",
      "error" => {:error, :simulated_error}
    },
    latency_ms: 100,
    error_rate: 0.0
  }
  ```
  """

  @behaviour Prismatic.LLM.Backend

  require Logger

  @default_response "This is a test response from the Prismatic test backend."
  @default_latency 50
  @model_name "test-model-v1"
  @max_tokens 4096

  @impl true
  def generate_response(config, prompt, context \\ %{}) do
    with :ok <- validate_config(config) do
      # Simulate latency
      simulate_latency(config)

      # Check for error simulation
      case maybe_simulate_error(config) do
        :ok ->
          response = get_response_for_prompt(config, prompt, context)
          {:ok, response}
        error ->
          error
      end
    end
  end

  @impl true
  def validate_config(config) do
    if Map.get(config, :backend_type) == :test do
      :ok
    else
      {:error, :invalid_backend_type}
    end
  end

  @impl true
  def health_check(_config) do
    # Test backend is always healthy
    :ok
  end

  @impl true
  def get_model_info(_config) do
    model_info = %{
      name: @model_name,
      max_tokens: @max_tokens,
      supports_streaming: false,
      cost_per_token: 0.0,
      provider: :test,
      capabilities: [:chat, :testing, :deterministic]
    }

    {:ok, model_info}
  end

  # Private helper functions

  defp simulate_latency(config) do
    latency = Map.get(config, :latency_ms, @default_latency)
    if latency > 0 do
      Process.sleep(latency)
    end
  end

  defp maybe_simulate_error(config) do
    error_rate = Map.get(config, :error_rate, 0.0)

    if :rand.uniform() < error_rate do
      error_type = Map.get(config, :error_type, :simulated_error)
      {:error, error_type}
    else
      :ok
    end
  end

  defp get_response_for_prompt(config, prompt, context) do
    responses = Map.get(config, :responses, %{})

    # Check for exact match first
    case Map.get(responses, prompt) do
      nil ->
        # Check for pattern matches
        find_pattern_response(responses, prompt, context)

      {:error, reason} ->
        # Configured error response
        {:error, reason}

      response when is_binary(response) ->
        # Direct string response
        enhance_response(response, context)

      response when is_function(response, 2) ->
        # Function response
        response.(prompt, context)

      response ->
        # Fallback to string representation
        to_string(response)
    end
  end

  defp find_pattern_response(responses, prompt, context) do
    # Look for pattern-based responses
    pattern_response =
      responses
      |> Enum.find(fn {pattern, _response} ->
        String.contains?(String.downcase(prompt), String.downcase(pattern))
      end)

    case pattern_response do
      {_pattern, response} when is_binary(response) ->
        enhance_response(response, context)

      {_pattern, response} when is_function(response, 2) ->
        response.(prompt, context)

      nil ->
        # Use default response with context enhancement
        enhance_response(@default_response, context)
    end
  end

  defp enhance_response(base_response, context) do
    response = base_response

    # Add context-based enhancements
    response = maybe_add_user_reference(response, context)
    response = maybe_add_conversation_context(response, context)
    response = maybe_add_timestamp(response, context)

    response
  end

  defp maybe_add_user_reference(response, context) do
    case Map.get(context, :user_name) do
      nil -> response
      user_name -> "#{response} (Hello, #{user_name}!)"
    end
  end

  defp maybe_add_conversation_context(response, context) do
    conversation_history = Map.get(context, :conversation_history, [])

    if length(conversation_history) > 0 do
      "#{response} [Context: #{length(conversation_history)} previous messages]"
    else
      response
    end
  end

  defp maybe_add_timestamp(response, context) do
    if Map.get(context, :include_timestamp, false) do
      timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
      "#{response} [Generated at: #{timestamp}]"
    else
      response
    end
  end

  @doc """
  Creates a test configuration with common response patterns.

  ## Examples

      iex> config = Prismatic.LLM.Impl.TestBackend.create_test_config()
      iex> {:ok, response} = Prismatic.LLM.Impl.TestBackend.generate_response(config, "hello", %{})
      iex> response
      "Hello! How can I help you today?"
  """
  def create_test_config(opts \\ []) do
    base_config = %{
      backend_type: :test,
      latency_ms: Keyword.get(opts, :latency_ms, @default_latency),
      error_rate: Keyword.get(opts, :error_rate, 0.0),
      responses: %{
        "hello" => "Hello! How can I help you today?",
        "hi" => "Hi there! What can I do for you?",
        "goodbye" => "Goodbye! Have a great day!",
        "bye" => "See you later!",
        "help" => "I'm here to help! What do you need assistance with?",
        "test" => "This is a test response. Everything is working correctly!",
        "error" => fn _prompt, _context -> {:error, :simulated_test_error} end,
        "math" => fn prompt, _context ->
          if String.contains?(prompt, "2 + 2") do
            "2 + 2 equals 4."
          else
            "I can help with basic math problems."
          end
        end,
        "weather" => "I'm a test backend, so I can't check real weather, but I can pretend it's sunny!",
        "time" => fn _prompt, context ->
          if Map.get(context, :include_timestamp, false) do
            "The current time is #{DateTime.utc_now() |> DateTime.to_iso8601()}"
          else
            "I can tell you the time if you enable timestamps in the context."
          end
        end
      }
    }

    # Merge with custom options
    custom_responses = Keyword.get(opts, :responses, %{})
    updated_responses = Map.merge(base_config.responses, custom_responses)

    %{base_config | responses: updated_responses}
  end

  @doc """
  Creates a deterministic test configuration for property-based testing.

  This configuration ensures consistent, predictable responses for testing.
  """
  def create_deterministic_config do
    %{
      backend_type: :test,
      latency_ms: 0,
      error_rate: 0.0,
      responses: %{
        # Deterministic responses for property testing
        "deterministic_test" => "DETERMINISTIC_RESPONSE",
        "property_test" => fn prompt, _context ->
          # Generate deterministic response based on prompt hash
          hash = :erlang.phash2(prompt)
          "Property test response: #{hash}"
        end
      }
    }
  end

  @doc """
  Creates a test configuration that simulates various error conditions.
  """
  def create_error_simulation_config do
    %{
      backend_type: :test,
      latency_ms: 10,
      error_rate: 0.3,  # 30% error rate
      error_type: :simulated_network_error,
      responses: %{
        "always_error" => {:error, :forced_error},
        "timeout" => fn _prompt, _context ->
          Process.sleep(5000)  # Simulate timeout
          "This should timeout"
        end,
        "rate_limit" => {:error, :rate_limit_exceeded},
        "invalid_response" => {:error, :invalid_api_response}
      }
    }
  end
end
