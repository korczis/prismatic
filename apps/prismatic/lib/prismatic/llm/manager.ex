defmodule Prismatic.LLM.Manager do
  @moduledoc """
  High-level manager for the Prismatic LLM system.

  This module provides a convenient interface for interacting with LLM backends,
  handling configuration, circuit breakers, and metrics automatically.

  ## Usage Examples

      # Generate response using default backend
      {:ok, response} = Prismatic.LLM.Manager.generate_response("Hello, world!")

      # Generate response with specific backend
      {:ok, response} = Prismatic.LLM.Manager.generate_response("Hello!", backend: :anthropic)

      # Generate response with context
      context = %{
        system_message: "You are a helpful assistant",
        temperature: 0.5,
        max_tokens: 100
      }
      {:ok, response} = Prismatic.LLM.Manager.generate_response("Help me", context: context)

      # Check backend health
      :ok = Prismatic.LLM.Manager.health_check(:openai)

      # Get backend information
      {:ok, info} = Prismatic.LLM.Manager.get_backend_info(:openai)
  """

  require Logger

  alias Prismatic.LLM.{Backend, Config}
  alias Prismatic.LLM.Impl.{OpenAIBackend, AnthropicBackend, TestBackend}
  alias Prismatic.LLM.Backend.{CircuitBreaker, MetricsCollector}

  @type backend_name :: atom()
  @type prompt :: String.t()
  @type context :: map()
  @type generate_opts :: [
    backend: backend_name(),
    context: context()
  ]

  @doc """
  Generates a response using the specified or default LLM backend.

  ## Parameters

  - `prompt` - The input text to send to the LLM
  - `opts` - Options including backend selection and context

  ## Options

  - `:backend` - Specific backend to use (defaults to configured default)
  - `:context` - Additional context for the request

  ## Examples

      iex> {:ok, response} = Prismatic.LLM.Manager.generate_response("Hello!")
      iex> is_binary(response)
      true

      iex> {:ok, response} = Prismatic.LLM.Manager.generate_response("Hi", backend: :test)
      iex> is_binary(response)
      true
  """
  @spec generate_response(prompt(), generate_opts()) :: {:ok, String.t()} | {:error, term()}
  def generate_response(prompt, opts \\ []) when is_binary(prompt) do
    backend_name = Keyword.get(opts, :backend, Config.get_default_backend())
    context = Keyword.get(opts, :context, %{})

    with {:ok, config} <- get_backend_config(backend_name),
         {:ok, backend_module} <- get_backend_module(backend_name),
         {:ok, circuit_breaker_pid} <- ensure_circuit_breaker(backend_name) do

      # Execute the request with circuit breaker protection
      CircuitBreaker.call(backend_name, fn ->
        backend_module.generate_response(config, prompt, context)
      end)
    else
      {:error, reason} = error ->
        Logger.error("Failed to generate response: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Performs a health check on the specified or default backend.

  ## Parameters

  - `backend_name` - Backend to check (defaults to configured default)

  ## Examples

      iex> Prismatic.LLM.Manager.health_check()
      :ok

      iex> Prismatic.LLM.Manager.health_check(:test)
      :ok
  """
  @spec health_check(backend_name() | nil) :: :ok | {:error, term()}
  def health_check(backend_name \\ nil) do
    backend_name = backend_name || Config.get_default_backend()

    with {:ok, config} <- get_backend_config(backend_name),
         {:ok, backend_module} <- get_backend_module(backend_name) do
      backend_module.health_check(config)
    end
  end

  @doc """
  Gets information about a specific backend.

  ## Parameters

  - `backend_name` - Backend to get information for (defaults to configured default)

  ## Examples

      iex> {:ok, info} = Prismatic.LLM.Manager.get_backend_info()
      iex> Map.has_key?(info, :name)
      true
  """
  @spec get_backend_info(backend_name() | nil) :: {:ok, map()} | {:error, term()}
  def get_backend_info(backend_name \\ nil) do
    backend_name = backend_name || Config.get_default_backend()

    with {:ok, config} <- get_backend_config(backend_name),
         {:ok, backend_module} <- get_backend_module(backend_name) do
      backend_module.get_model_info(config)
    end
  end

  @doc """
  Lists all available backends.

  ## Examples

      iex> backends = Prismatic.LLM.Manager.list_backends()
      iex> is_list(backends)
      true
  """
  @spec list_backends() :: [backend_name()]
  def list_backends do
    Config.list_backends()
  end

  @doc """
  Gets metrics for a specific backend.

  ## Parameters

  - `backend_name` - Backend to get metrics for (defaults to configured default)

  ## Examples

      iex> metrics = Prismatic.LLM.Manager.get_metrics()
      iex> Map.has_key?(metrics, :total_requests)
      true
  """
  @spec get_metrics(backend_name() | nil) :: map()
  def get_metrics(backend_name \\ nil) do
    backend_name = backend_name || Config.get_default_backend()
    MetricsCollector.get_metrics(backend_name)
  end

  @doc """
  Gets global metrics across all backends.

  ## Examples

      iex> metrics = Prismatic.LLM.Manager.get_global_metrics()
      iex> Map.has_key?(metrics, :total_requests)
      true
  """
  @spec get_global_metrics() :: map()
  def get_global_metrics do
    MetricsCollector.get_global_metrics()
  end

  @doc """
  Resets circuit breaker for a specific backend.

  ## Parameters

  - `backend_name` - Backend to reset circuit breaker for

  ## Examples

      iex> Prismatic.LLM.Manager.reset_circuit_breaker(:test)
      :ok
  """
  @spec reset_circuit_breaker(backend_name()) :: :ok
  def reset_circuit_breaker(backend_name) when is_atom(backend_name) do
    CircuitBreaker.reset(backend_name)
  end

  @doc """
  Gets the current state of a backend's circuit breaker.

  ## Parameters

  - `backend_name` - Backend to check circuit breaker state for

  ## Examples

      iex> state = Prismatic.LLM.Manager.get_circuit_breaker_state(:test)
      iex> state in [:closed, :open, :half_open]
      true
  """
  @spec get_circuit_breaker_state(backend_name()) :: :closed | :open | :half_open
  def get_circuit_breaker_state(backend_name) when is_atom(backend_name) do
    CircuitBreaker.get_state(backend_name)
  end

  ## Private Implementation

  defp get_backend_config(backend_name) do
    case Config.get_backend_config(backend_name) do
      {:error, reason} = error ->
        Logger.error("Failed to get backend config for #{backend_name}: #{inspect(reason)}")
        error

      config ->
        {:ok, config}
    end
  end

  defp get_backend_module(backend_name) do
    case Config.get_backend_config(backend_name) do
      {:error, reason} ->
        {:error, reason}

      config ->
        case config.backend_type do
          :openai -> {:ok, OpenAIBackend}
          :anthropic -> {:ok, AnthropicBackend}
          :test -> {:ok, TestBackend}
          unknown -> {:error, {:unsupported_backend_type, unknown}}
        end
    end
  end

  defp ensure_circuit_breaker(backend_name) do
    circuit_breaker_config = Config.get_circuit_breaker_config()

    case CircuitBreaker.get_state(backend_name) do
      state when state in [:closed, :open, :half_open] ->
        {:ok, :already_started}

      _error ->
        # Circuit breaker doesn't exist, start it
        case CircuitBreaker.start_link(backend_name, Map.to_list(circuit_breaker_config)) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          {:error, reason} = error ->
            Logger.error("Failed to start circuit breaker for #{backend_name}: #{inspect(reason)}")
            error
        end
    end
  rescue
    # Handle case where circuit breaker process doesn't exist
    _ ->
      circuit_breaker_config = Config.get_circuit_breaker_config()
      case CircuitBreaker.start_link(backend_name, Map.to_list(circuit_breaker_config)) do
        {:ok, pid} -> {:ok, pid}
        {:error, {:already_started, pid}} -> {:ok, pid}
        {:error, reason} = error ->
          Logger.error("Failed to start circuit breaker for #{backend_name}: #{inspect(reason)}")
          error
      end
  end
end
