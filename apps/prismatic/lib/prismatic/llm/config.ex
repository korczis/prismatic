defmodule Prismatic.LLM.Config do
  @moduledoc """
  Configuration management for the Prismatic LLM system.

  This module provides centralized configuration management for LLM backends,
  supporting multiple providers with environment-specific settings and
  runtime configuration validation.

  ## Configuration Structure

  The LLM system expects configuration in the following format:

  ```elixir
  config :prismatic, Prismatic.LLM,
    default_backend: :openai,
    backends: %{
      openai: %{
        backend_type: :openai,
        api_key: {:system, "OPENAI_API_KEY"},
        model: "gpt-4",
        timeout: 30_000,
        max_retries: 3,
        base_url: "https://api.openai.com/v1"
      },
      anthropic: %{
        backend_type: :anthropic,
        api_key: {:system, "ANTHROPIC_API_KEY"},
        model: "claude-3-sonnet-20240229",
        timeout: 30_000,
        max_retries: 3,
        base_url: "https://api.anthropic.com"
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
  ```

  ## Usage Examples

      # Get default backend configuration
      config = Prismatic.LLM.Config.get_backend_config()

      # Get specific backend configuration
      config = Prismatic.LLM.Config.get_backend_config(:anthropic)

      # Get all available backends
      backends = Prismatic.LLM.Config.list_backends()

      # Validate configuration
      :ok = Prismatic.LLM.Config.validate_config()
  """

  require Logger

  @default_config %{
    default_backend: :openai,
    backends: %{},
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

  @type backend_name :: atom()
  @type backend_config :: %{
    backend_type: atom(),
    api_key: String.t(),
    model: String.t(),
    timeout: non_neg_integer(),
    max_retries: non_neg_integer(),
    base_url: String.t()
  }

  @doc """
  Gets the configuration for the default backend.

  Returns the backend configuration for the system's default backend,
  with all environment variables resolved and settings validated.

  ## Examples

      iex> config = Prismatic.LLM.Config.get_backend_config()
      iex> Map.has_key?(config, :backend_type)
      true
  """
  @spec get_backend_config() :: backend_config() | {:error, term()}
  def get_backend_config do
    default_backend = get_default_backend()
    get_backend_config(default_backend)
  end

  @doc """
  Gets the configuration for a specific backend.

  Returns the backend configuration with all environment variables
  resolved and settings validated.

  ## Parameters

  - `backend_name` - The name of the backend to retrieve configuration for

  ## Examples

      iex> config = Prismatic.LLM.Config.get_backend_config(:openai)
      iex> config.backend_type
      :openai
  """
  @spec get_backend_config(backend_name()) :: backend_config() | {:error, term()}
  def get_backend_config(backend_name) when is_atom(backend_name) do
    case get_raw_backend_config(backend_name) do
      {:ok, raw_config} ->
        case resolve_config(raw_config) do
          {:ok, resolved_config} ->
            case validate_backend_config(resolved_config) do
              :ok -> resolved_config
              {:error, reason} -> {:error, {:invalid_config, backend_name, reason}}
            end

          {:error, reason} ->
            {:error, {:config_resolution_failed, backend_name, reason}}
        end

      {:error, reason} ->
        {:error, {:backend_not_found, backend_name, reason}}
    end
  end

  @doc """
  Lists all configured backend names.

  ## Examples

      iex> backends = Prismatic.LLM.Config.list_backends()
      iex> is_list(backends)
      true
  """
  @spec list_backends() :: [backend_name()]
  def list_backends do
    config = get_llm_config()
    Map.keys(config.backends)
  end

  @doc """
  Gets the name of the default backend.

  ## Examples

      iex> default = Prismatic.LLM.Config.get_default_backend()
      iex> is_atom(default)
      true
  """
  @spec get_default_backend() :: backend_name()
  def get_default_backend do
    config = get_llm_config()
    config.default_backend
  end

  @doc """
  Gets circuit breaker configuration.

  ## Examples

      iex> config = Prismatic.LLM.Config.get_circuit_breaker_config()
      iex> Map.has_key?(config, :failure_threshold)
      true
  """
  @spec get_circuit_breaker_config() :: map()
  def get_circuit_breaker_config do
    config = get_llm_config()
    config.circuit_breaker
  end

  @doc """
  Gets metrics configuration.

  ## Examples

      iex> config = Prismatic.LLM.Config.get_metrics_config()
      iex> Map.has_key?(config, :enabled)
      true
  """
  @spec get_metrics_config() :: map()
  def get_metrics_config do
    config = get_llm_config()
    config.metrics
  end

  @doc """
  Validates the entire LLM system configuration.

  Checks all backends, circuit breaker settings, and metrics configuration
  for completeness and correctness.

  ## Examples

      iex> Prismatic.LLM.Config.validate_config()
      :ok
  """
  @spec validate_config() :: :ok | {:error, term()}
  def validate_config do
    with :ok <- validate_structure(),
         :ok <- validate_backends(),
         :ok <- validate_circuit_breaker_config(),
         :ok <- validate_metrics_config() do
      :ok
    end
  end

  @doc """
  Checks if a backend is configured and available.

  ## Parameters

  - `backend_name` - The name of the backend to check

  ## Examples

      iex> Prismatic.LLM.Config.backend_available?(:openai)
      true
  """
  @spec backend_available?(backend_name()) :: boolean()
  def backend_available?(backend_name) when is_atom(backend_name) do
    case get_backend_config(backend_name) do
      {:error, _} -> false
      _config -> true
    end
  end

  ## Private Implementation

  defp get_llm_config do
    case Application.get_env(:prismatic, Prismatic.LLM) do
      nil ->
        Logger.warning("No LLM configuration found, using defaults")
        @default_config

      config ->
        Map.merge(@default_config, Map.new(config))
    end
  end

  defp get_raw_backend_config(backend_name) do
    config = get_llm_config()

    case Map.get(config.backends, backend_name) do
      nil -> {:error, :not_configured}
      backend_config -> {:ok, backend_config}
    end
  end

  defp resolve_config(config, resolved \\ %{})

  defp resolve_config(config, resolved) when is_map(config) do
    try do
      resolved_config =
        config
        |> Enum.reduce(resolved, fn {key, value}, acc ->
          Map.put(acc, key, resolve_value(value))
        end)

      {:ok, resolved_config}
    rescue
      error -> {:error, {:resolution_error, error}}
    end
  end

  defp resolve_value({:system, env_var}) when is_binary(env_var) do
    case System.get_env(env_var) do
      nil -> raise "Environment variable #{env_var} is not set"
      value -> value
    end
  end

  defp resolve_value({:system, env_var, default}) when is_binary(env_var) do
    System.get_env(env_var, default)
  end

  defp resolve_value(value), do: value

  defp validate_backend_config(config) do
    required_fields = [:backend_type, :api_key]

    with :ok <- validate_required_fields(config, required_fields),
         :ok <- validate_backend_type(config.backend_type),
         :ok <- validate_api_key(config.api_key) do
      :ok
    end
  end

  defp validate_required_fields(config, required_fields) do
    missing_fields = Enum.filter(required_fields, fn field ->
      not Map.has_key?(config, field) or is_nil(Map.get(config, field))
    end)

    case missing_fields do
      [] -> :ok
      fields -> {:error, {:missing_required_fields, fields}}
    end
  end

  defp validate_backend_type(backend_type) when backend_type in [:openai, :anthropic, :test] do
    :ok
  end

  defp validate_backend_type(backend_type) do
    {:error, {:unsupported_backend_type, backend_type}}
  end

  defp validate_api_key(api_key) when is_binary(api_key) and byte_size(api_key) > 0 do
    :ok
  end

  defp validate_api_key(_) do
    {:error, :invalid_api_key}
  end

  defp validate_structure do
    config = get_llm_config()

    required_keys = [:default_backend, :backends, :circuit_breaker, :metrics]
    missing_keys = Enum.filter(required_keys, fn key ->
      not Map.has_key?(config, key)
    end)

    case missing_keys do
      [] -> :ok
      keys -> {:error, {:missing_config_sections, keys}}
    end
  end

  defp validate_backends do
    backends = list_backends()

    if Enum.empty?(backends) do
      {:error, :no_backends_configured}
    else
      validate_all_backends(backends)
    end
  end

  defp validate_all_backends(backends) do
    validation_results = Enum.map(backends, fn backend ->
      case get_backend_config(backend) do
        {:error, reason} -> {backend, {:error, reason}}
        _config -> {backend, :ok}
      end
    end)

    failed_backends = Enum.filter(validation_results, fn {_backend, result} ->
      match?({:error, _}, result)
    end)

    case failed_backends do
      [] -> :ok
      failures -> {:error, {:backend_validation_failures, failures}}
    end
  end

  defp validate_circuit_breaker_config do
    config = get_circuit_breaker_config()
    required_keys = [:failure_threshold, :recovery_timeout, :success_threshold]

    missing_keys = Enum.filter(required_keys, fn key ->
      not Map.has_key?(config, key)
    end)

    case missing_keys do
      [] -> :ok
      keys -> {:error, {:missing_circuit_breaker_config, keys}}
    end
  end

  defp validate_metrics_config do
    config = get_metrics_config()
    required_keys = [:enabled, :telemetry_prefix]

    missing_keys = Enum.filter(required_keys, fn key ->
      not Map.has_key?(config, key)
    end)

    case missing_keys do
      [] -> :ok
      keys -> {:error, {:missing_metrics_config, keys}}
    end
  end
end
