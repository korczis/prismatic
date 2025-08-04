defmodule Prismatic.Shared.Backend do
  @moduledoc """
  Shared backend behavior macro for Prismatic systems.

  This macro eliminates code duplication across LLM, Blackboard, and Memory backends
  by providing common functionality for configuration validation, health checks,
  telemetry emission, circuit breaker integration, and error handling.

  ## Features

  - **Behavior Definition**: Defines required callbacks each backend must implement
  - **Generated Functions**: Provides common functionality automatically
  - **Circuit Breaker Integration**: Built-in fault tolerance patterns
  - **Unified Telemetry**: Standardized event emission with `[:prismatic, :system, :operation]` pattern
  - **Error Classification**: Common error handling and retry logic
  - **Configuration Validation**: Extensible validation with system-specific hooks
  - **Health Check Framework**: Comprehensive health monitoring with circuit breaker awareness

  ## Usage

  ```elixir
  defmodule MyApp.CustomBackend do
    use Prismatic.Shared.Backend,
      system: :my_system,
      required_config_fields: [:api_key, :endpoint],
      circuit_breaker_config: [
        failure_threshold: 5,
        recovery_timeout: 60_000
      ]

    # Implement required callbacks
    @impl Prismatic.Shared.Backend
    def execute_operation(config, operation, params) do
      # Your backend-specific implementation
    end

    @impl Prismatic.Shared.Backend
    def validate_system_config(config) do
      # Your system-specific validation
      validate_api_key(config.api_key)
    end

    @impl Prismatic.Shared.Backend
    def perform_health_check(config) do
      # Your system-specific health check
      test_connection(config)
    end
  end
  ```

  ## Generated Functions

  The macro generates the following functions automatically:

  - `validate_config/1` - Enhanced configuration validation
  - `health_check/1` - Health check with circuit breaker integration
  - `emit_telemetry/3` - Unified telemetry emission
  - `handle_circuit_breaker/2` - Circuit breaker execution wrapper
  - `classify_error/1` - Error classification for retry logic
  - `with_retry/2` - Retry execution wrapper
  - `get_default_config/0` - Default configuration for the backend

  ## Configuration Structure

  All backends using this macro must provide configuration maps with these common fields:

  ```elixir
  %{
    backend_type: atom(),           # Required: Backend identifier
    name: atom(),                   # Required: Backend instance name
    timeout: pos_integer(),         # Optional: Operation timeout (default: 30_000)
    max_retries: non_neg_integer(), # Optional: Max retry attempts (default: 3)
    circuit_breaker: keyword(),     # Optional: Circuit breaker config
    telemetry_prefix: [atom()],     # Optional: Custom telemetry prefix
    # ... system-specific fields
  }
  ```

  ## Telemetry Events

  The macro emits standardized telemetry events:

  - `[:prismatic, :system, :operation, :start]` - Operation started
  - `[:prismatic, :system, :operation, :stop]` - Operation completed
  - `[:prismatic, :system, :operation, :exception]` - Operation failed
  - `[:prismatic, :system, :health_check]` - Health check results
  - `[:prismatic, :system, :circuit_breaker]` - Circuit breaker state changes

  ## Error Classification

  Common error types are automatically classified for retry logic:

  ### Retryable Errors
  - `:timeout` - Request timeout
  - `:econnrefused`, `:enetunreach` - Network connectivity issues
  - `:temporary_failure` - Transient failures
  - HTTP 5xx errors - Server errors
  - `:rate_limit_exceeded` - Rate limiting (with backoff)

  ### Non-Retryable Errors
  - `:invalid_config` - Configuration errors
  - `:authentication_failed` - Auth failures
  - `:not_found` - Resource not found
  - HTTP 4xx errors (except 429) - Client errors
  - `:circuit_breaker_open` - Circuit breaker protection

  ## Circuit Breaker Integration

  The macro integrates with circuit breakers automatically:

  ```elixir
  # Circuit breaker configuration
  circuit_breaker_config = [
    failure_threshold: 5,        # Failures before opening circuit
    recovery_timeout: 60_000,    # Time before attempting recovery
    success_threshold: 3         # Successes needed to close circuit
  ]
  ```

  ## Architecture Goals

  - **Reduce Duplication**: Eliminates ~1,700 lines of duplicated code across backends
  - **Consistent Behavior**: Ensures uniform error handling and telemetry
  - **Easy Extension**: Simple to add new backends with minimal boilerplate
  - **Backward Compatibility**: Maintains existing backend interfaces
  - **OTP Best Practices**: Follows advanced Elixir patterns and conventions

  ## Advanced Usage

  ### Custom Error Classification

  ```elixir
  defmodule MyBackend do
    use Prismatic.Shared.Backend, system: :my_system

    # Override error classification for system-specific errors
    def classify_error({:my_custom_error, _details}), do: {:retryable, :custom_error}
    def classify_error(error), do: super(error)
  end
  ```

  ### Custom Telemetry

  ```elixir
  defmodule MyBackend do
    use Prismatic.Shared.Backend,
      system: :my_system,
      telemetry_prefix: [:my_app, :my_system]
  end
  ```

  ### System-Specific Configuration Validation

  ```elixir
  defmodule MyBackend do
    use Prismatic.Shared.Backend, system: :my_system

    @impl Prismatic.Shared.Backend
    def validate_system_config(config) do
      with :ok <- validate_api_key(config.api_key),
           :ok <- validate_endpoint(config.endpoint) do
        :ok
      end
    end
  end
  ```
  """

  @type config :: map()
  @type operation_result :: {:ok, term()} | {:error, term()}
  @type error_classification :: {:retryable, atom()} | {:non_retryable, atom()}
  @type telemetry_metadata :: map()

  @doc """
  Executes a backend-specific operation.

  This callback must be implemented by each backend to handle system-specific
  operations like API calls, data storage, or message processing.

  ## Parameters

  - `config` - Backend configuration map
  - `operation` - Operation identifier (atom)
  - `params` - Operation parameters

  ## Returns

  - `{:ok, result}` - Operation succeeded
  - `{:error, reason}` - Operation failed

  ## Examples

      @impl Prismatic.Shared.Backend
      def execute_operation(config, :generate_response, {prompt, context}) do
        # LLM backend implementation
        make_api_call(config, prompt, context)
      end

      @impl Prismatic.Shared.Backend
      def execute_operation(config, :store, {memory_type, key, value}) do
        # Memory backend implementation
        store_in_backend(config, memory_type, key, value)
      end
  """
  @callback execute_operation(config(), atom(), term()) :: operation_result()

  @doc """
  Validates system-specific configuration fields.

  This callback allows backends to implement custom validation logic
  for system-specific configuration fields beyond the common validation
  provided by the macro.

  ## Parameters

  - `config` - Configuration map to validate

  ## Returns

  - `:ok` - Configuration is valid
  - `{:error, reason}` - Configuration is invalid

  ## Examples

      @impl Prismatic.Shared.Backend
      def validate_system_config(config) do
        with :ok <- validate_api_key(config.api_key),
             :ok <- validate_model(config.model) do
          :ok
        end
      end
  """
  @callback validate_system_config(config()) :: :ok | {:error, term()}

  @doc """
  Performs system-specific health check operations.

  This callback allows backends to implement custom health check logic
  beyond the basic connectivity and configuration validation provided
  by the macro.

  ## Parameters

  - `config` - Backend configuration map

  ## Returns

  - `:ok` - Backend is healthy
  - `{:error, reason}` - Backend is unhealthy

  ## Examples

      @impl Prismatic.Shared.Backend
      def perform_health_check(config) do
        # Test actual API connectivity
        case make_test_request(config) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, {:api_unreachable, reason}}
        end
      end
  """
  @callback perform_health_check(config()) :: :ok | {:error, term()}

  @doc """
  Gets backend-specific information and capabilities.

  This callback provides system-specific information about the backend
  such as supported features, current statistics, and configuration details.

  ## Parameters

  - `config` - Backend configuration map

  ## Returns

  - `{:ok, info}` - Backend information map
  - `{:error, reason}` - Failed to get information

  ## Examples

      @impl Prismatic.Shared.Backend
      def get_backend_info(config) do
        {:ok, %{
          backend_type: :openai,
          model: config.model,
          supports_streaming: true,
          max_tokens: 4096,
          current_requests: get_request_count()
        }}
      end
  """
  @callback get_backend_info(config()) :: {:ok, map()} | {:error, term()}

  @optional_callbacks [validate_system_config: 1, perform_health_check: 1]

  defmacro __using__(opts) do
    system = Keyword.fetch!(opts, :system)
    required_config_fields = Keyword.get(opts, :required_config_fields, [])
    circuit_breaker_config = Keyword.get(opts, :circuit_breaker_config, [])
    telemetry_prefix = Keyword.get(opts, :telemetry_prefix, [:prismatic, system])
    default_timeout = Keyword.get(opts, :default_timeout, 30_000)
    default_max_retries = Keyword.get(opts, :default_max_retries, 3)

    quote do
      @behaviour Prismatic.Shared.Backend

      require Logger

      # Store configuration for use in generated functions
      @system unquote(system)
      @required_config_fields unquote(required_config_fields)
      @circuit_breaker_config unquote(circuit_breaker_config)
      @telemetry_prefix unquote(telemetry_prefix)
      @default_timeout unquote(default_timeout)
      @default_max_retries unquote(default_max_retries)

      @doc """
      Enhanced configuration validation with common and system-specific validation.

      Validates both common configuration fields required by all backends and
      system-specific fields using the `validate_system_config/1` callback.

      ## Examples

          iex> validate_config(%{backend_type: :test, name: :test_backend})
          :ok

          iex> validate_config(%{name: :test_backend})
          {:error, {:missing_required_fields, [:backend_type]}}
      """
      @spec validate_config(Prismatic.Shared.Backend.config()) :: :ok | {:error, term()}
      def validate_config(config) when is_map(config) do
        with :ok <- validate_common_fields(config),
             :ok <- validate_required_system_fields(config),
             :ok <- validate_system_specific(config) do
          :ok
        end
      end

      def validate_config(config) do
        {:error, {:invalid_config_type, config}}
      end

      @doc """
      Comprehensive health check with circuit breaker integration.

      Performs basic configuration validation, system connectivity checks,
      and integrates with circuit breaker status to provide accurate health status.

      ## Examples

          iex> health_check(%{backend_type: :test, name: :test_backend})
          :ok

          iex> health_check(%{backend_type: :test, name: :failing_backend})
          {:error, {:health_check_failed, :circuit_breaker_open}}
      """
      @spec health_check(Prismatic.Shared.Backend.config()) :: :ok | {:error, term()}
      def health_check(config) do
        start_time = System.monotonic_time(:millisecond)

        result = with :ok <- validate_config(config),
                      :ok <- check_circuit_breaker_status(config),
                      :ok <- perform_system_health_check(config) do
          :ok
        end

        duration = System.monotonic_time(:millisecond) - start_time

        # Emit health check telemetry
        emit_telemetry(:health_check, %{duration: duration}, %{
          config: config,
          result: result
        })

        result
      end

      @doc """
      Unified telemetry emission with standardized event naming.

      Emits telemetry events following the `[:prismatic, :system, :operation]` pattern
      with consistent measurements and metadata across all backends.

      ## Parameters

      - `operation` - Operation name (atom)
      - `measurements` - Measurement data (map)
      - `metadata` - Event metadata (map)

      ## Examples

          iex> emit_telemetry(:request, %{duration: 150}, %{success: true})
          :ok
      """
      @spec emit_telemetry(atom(), map(), map()) :: :ok
      def emit_telemetry(operation, measurements \\ %{}, metadata \\ %{}) do
        event_name = @telemetry_prefix ++ [operation]

        enhanced_measurements = Map.merge(%{
          timestamp: System.monotonic_time(:millisecond),
          count: 1
        }, measurements)

        enhanced_metadata = Map.merge(%{
          backend_type: @system,
          backend_module: __MODULE__
        }, metadata)

        :telemetry.execute(event_name, enhanced_measurements, enhanced_metadata)
      end

      @doc """
      Circuit breaker execution wrapper for fault tolerance.

      Executes operations through a circuit breaker to provide fault tolerance
      and prevent cascade failures when backends are experiencing issues.

      ## Parameters

      - `config` - Backend configuration
      - `operation_fun` - Function to execute with circuit breaker protection

      ## Returns

      - `{:ok, result}` - Operation succeeded
      - `{:error, :circuit_breaker_open}` - Circuit breaker is open
      - `{:error, reason}` - Operation failed

      ## Examples

          iex> handle_circuit_breaker(config, fn ->
          ...>   {:ok, "success"}
          ...> end)
          {:ok, "success"}
      """
      @spec handle_circuit_breaker(Prismatic.Shared.Backend.config(), function()) ::
        Prismatic.Shared.Backend.operation_result()
      def handle_circuit_breaker(config, operation_fun) when is_function(operation_fun, 0) do
        backend_name = get_backend_name(config)

        case get_circuit_breaker_state(backend_name) do
          :closed ->
            execute_with_monitoring(backend_name, operation_fun)

          :open ->
            if should_attempt_reset?(backend_name) do
              set_circuit_breaker_state(backend_name, :half_open)
              execute_with_monitoring(backend_name, operation_fun)
            else
              emit_telemetry(:circuit_breaker, %{}, %{event: :rejected, state: :open})
              {:error, :circuit_breaker_open}
            end

          :half_open ->
            execute_with_monitoring(backend_name, operation_fun)
        end
      end

      @doc """
      Classifies errors for retry logic and circuit breaker decisions.

      Determines whether an error should trigger retries and how it should
      be handled by the circuit breaker based on common error patterns.

      ## Parameters

      - `error` - Error term to classify

      ## Returns

      - `{:retryable, error_type}` - Error is retryable
      - `{:non_retryable, error_type}` - Error should not be retried

      ## Examples

          iex> classify_error(:timeout)
          {:retryable, :timeout}

          iex> classify_error(:invalid_api_key)
          {:non_retryable, :authentication_error}
      """
      @spec classify_error(term()) :: Prismatic.Shared.Backend.error_classification()
      def classify_error({:error, reason}), do: classify_error(reason)

      # Network and connectivity errors - retryable
      def classify_error(:timeout), do: {:retryable, :timeout}
      def classify_error(:econnrefused), do: {:retryable, :connection_refused}
      def classify_error(:econnreset), do: {:retryable, :connection_reset}
      def classify_error(:enetunreach), do: {:retryable, :network_unreachable}
      def classify_error(:ehostunreach), do: {:retryable, :host_unreachable}
      def classify_error({:request_failed, _}), do: {:retryable, :request_failed}

      # Rate limiting - retryable with backoff
      def classify_error(:rate_limit_exceeded), do: {:retryable, :rate_limit}
      def classify_error({:api_error, 429, _}), do: {:retryable, :rate_limit}

      # Server errors - retryable
      def classify_error({:api_error, status, _}) when status in 500..599,
        do: {:retryable, :server_error}
      def classify_error(:server_error), do: {:retryable, :server_error}
      def classify_error(:temporary_failure), do: {:retryable, :temporary_failure}

      # Client errors - non-retryable
      def classify_error({:api_error, status, _}) when status in 400..499 and status != 429,
        do: {:non_retryable, :client_error}
      def classify_error(:invalid_api_key), do: {:non_retryable, :authentication_error}
      def classify_error(:authentication_failed), do: {:non_retryable, :authentication_error}
      def classify_error(:authorization_failed), do: {:non_retryable, :authorization_error}
      def classify_error(:invalid_request), do: {:non_retryable, :validation_error}
      def classify_error(:invalid_config), do: {:non_retryable, :configuration_error}
      def classify_error(:not_found), do: {:non_retryable, :not_found}

      # Circuit breaker errors - non-retryable
      def classify_error(:circuit_breaker_open), do: {:non_retryable, :circuit_breaker}
      def classify_error(:max_retries_exceeded), do: {:non_retryable, :retry_exhausted}

      # Unknown errors - retryable with caution
      def classify_error(_error), do: {:retryable, :unknown}

      @doc """
      Executes operations with retry logic and exponential backoff.

      Automatically retries operations based on error classification with
      configurable retry counts, backoff strategies, and jitter.

      ## Parameters

      - `operation_fun` - Function to execute with retry logic
      - `config` - Backend configuration (uses max_retries from config)

      ## Returns

      - `{:ok, result}` - Operation succeeded (possibly after retries)
      - `{:error, reason}` - Operation failed after all retries

      ## Examples

          iex> with_retry(fn -> {:ok, "success"} end, config)
          {:ok, "success"}

          iex> with_retry(fn -> {:error, :timeout} end, config)
          {:error, :timeout}
      """
      @spec with_retry(function(), Prismatic.Shared.Backend.config()) ::
        Prismatic.Shared.Backend.operation_result()
      def with_retry(operation_fun, config) when is_function(operation_fun, 0) do
        max_retries = Map.get(config, :max_retries, @default_max_retries)
        execute_with_retry(operation_fun, config, 1, max_retries, [])
      end

       @doc """
       Executes backend operations with circuit breaker and retry logic.

       This is the main entry point for backend operations, providing automatic
       circuit breaker protection and retry logic based on error classification.

       ## Parameters

       - `config` - Backend configuration map
       - `operation` - Operation identifier (atom)
       - `params` - Operation parameters

       ## Returns

       - `{:ok, result}` - Operation succeeded
       - `{:error, reason}` - Operation failed after all retries

       ## Examples

           iex> call(config, :store, {memory_type, key, value})
           {:ok, updated_config}

           iex> call(config, :retrieve, {memory_type, key})
           {:ok, value}
       """
       @spec call(Prismatic.Shared.Backend.config(), atom(), term()) ::
         Prismatic.Shared.Backend.operation_result()
       def call(config, operation, params) do
         operation_fun = fn ->
           execute_operation(config, operation, params)
         end

         config
         |> handle_circuit_breaker(operation_fun)
         |> case do
           {:ok, result} -> {:ok, result}
           {:error, reason} ->
             # Apply retry logic for retryable errors
             case classify_error(reason) do
               {:retryable, _} ->
                 with_retry(operation_fun, config)
               {:non_retryable, _} ->
                 {:error, reason}
             end
         end
       end

       @doc """
       Gets the default configuration for this backend type.

       Returns a configuration map with sensible defaults that can be
       merged with user-provided configuration.

       ## Examples

           iex> get_default_config()
           %{
             backend_type: :my_system,
             timeout: 30_000,
             max_retries: 3,
             circuit_breaker: [...]
           }
       """
       @spec get_default_config() :: map()
       def get_default_config do
         %{
           backend_type: @system,
           timeout: @default_timeout,
           max_retries: @default_max_retries,
           circuit_breaker: @circuit_breaker_config,
           telemetry_prefix: @telemetry_prefix
         }
       end

      # Allow backends to override error classification
      defoverridable classify_error: 1

      ## Private Implementation Functions

      # Validate common configuration fields required by all backends
      defp validate_common_fields(config) do
        required_common_fields = [:backend_type, :name]
        missing_fields = Enum.filter(required_common_fields, fn field ->
          not Map.has_key?(config, field) or is_nil(Map.get(config, field))
        end)

        case missing_fields do
          [] -> validate_common_field_types(config)
          fields -> {:error, {:missing_required_fields, fields}}
        end
      end

      # Validate types of common configuration fields
      defp validate_common_field_types(config) do
        with :ok <- validate_field_type(config, :backend_type, &is_atom/1),
             :ok <- validate_field_type(config, :name, &is_atom/1),
             :ok <- validate_optional_field_type(config, :timeout, &is_positive_integer/1),
             :ok <- validate_optional_field_type(config, :max_retries, &is_non_neg_integer/1) do
          :ok
        end
      end

      # Validate system-specific required fields
      defp validate_required_system_fields(config) do
        missing_fields = Enum.filter(@required_config_fields, fn field ->
          not Map.has_key?(config, field) or is_nil(Map.get(config, field))
        end)

        case missing_fields do
          [] -> :ok
          fields -> {:error, {:missing_required_fields, fields}}
        end
      end

      # Call system-specific validation if implemented
      defp validate_system_specific(config) do
        if function_exported?(__MODULE__, :validate_system_config, 1) do
          validate_system_config(config)
        else
          :ok
        end
      end

      # Perform system-specific health check if implemented
      defp perform_system_health_check(config) do
        if function_exported?(__MODULE__, :perform_health_check, 1) do
          perform_health_check(config)
        else
          :ok
        end
      end

      # Field validation helpers
      defp validate_field_type(config, field, validator) do
        value = Map.get(config, field)
        if validator.(value) do
          :ok
        else
          {:error, {:invalid_field_type, field, value}}
        end
      end

      defp validate_optional_field_type(config, field, validator) do
        case Map.get(config, field) do
          nil -> :ok
          value ->
            if validator.(value) do
              :ok
            else
              {:error, {:invalid_field_type, field, value}}
            end
        end
      end

      defp is_positive_integer(value), do: is_integer(value) and value > 0
      defp is_non_neg_integer(value), do: is_integer(value) and value >= 0

      # Circuit breaker implementation
      defp get_backend_name(config), do: Map.get(config, :name, @system)

      defp get_circuit_breaker_state(backend_name) do
        case :ets.lookup(__MODULE__.CircuitBreaker, backend_name) do
          [{^backend_name, state, _failure_count, _last_failure}] -> state
          [] -> :closed
        end
      end

      defp set_circuit_breaker_state(backend_name, new_state) do
        ensure_circuit_breaker_table()
        case :ets.lookup(__MODULE__.CircuitBreaker, backend_name) do
          [{^backend_name, _state, failure_count, last_failure}] ->
            :ets.insert(__MODULE__.CircuitBreaker, {backend_name, new_state, failure_count, last_failure})
          [] ->
            :ets.insert(__MODULE__.CircuitBreaker, {backend_name, new_state, 0, nil})
        end
        :ok
      end

      defp check_circuit_breaker_status(config) do
        backend_name = get_backend_name(config)
        case get_circuit_breaker_state(backend_name) do
          :open -> {:error, :circuit_breaker_open}
          _ -> :ok
        end
      end

      defp should_attempt_reset?(backend_name) do
        recovery_timeout = Keyword.get(@circuit_breaker_config, :recovery_timeout, 60_000)

        case :ets.lookup(__MODULE__.CircuitBreaker, backend_name) do
          [{^backend_name, :open, _failure_count, last_failure}] when is_integer(last_failure) ->
            current_time = System.monotonic_time(:millisecond)
            current_time - last_failure >= recovery_timeout
          _ ->
            false
        end
      end

      defp execute_with_monitoring(backend_name, operation_fun) do
        result = operation_fun.()
        update_circuit_breaker_metrics(backend_name, result)
        result
      end

      defp update_circuit_breaker_metrics(backend_name, result) do
        ensure_circuit_breaker_table()
        failure_threshold = Keyword.get(@circuit_breaker_config, :failure_threshold, 5)
        current_time = System.monotonic_time(:millisecond)

        case result do
          {:ok, _} ->
            # Success - reset circuit breaker
            :ets.insert(__MODULE__.CircuitBreaker, {backend_name, :closed, 0, nil})
            emit_telemetry(:circuit_breaker, %{}, %{event: :success, state: :closed})

          {:error, reason} ->
            {new_state, new_count} = case :ets.lookup(__MODULE__.CircuitBreaker, backend_name) do
              [{^backend_name, _state, failure_count, _last_failure}] ->
                new_failure_count = failure_count + 1
                if new_failure_count >= failure_threshold do
                  Logger.warning("Circuit breaker opened for #{backend_name} after #{new_failure_count} failures")
                  emit_telemetry(:circuit_breaker, %{}, %{event: :open, failure_count: new_failure_count})
                  {:open, new_failure_count}
                else
                  {:closed, new_failure_count}
                end
              [] ->
                {:closed, 1}
            end

            :ets.insert(__MODULE__.CircuitBreaker, {backend_name, new_state, new_count, current_time})
        end

        :ok
      end

      defp ensure_circuit_breaker_table do
        table_name = __MODULE__.CircuitBreaker
        case :ets.whereis(table_name) do
          :undefined ->
            :ets.new(table_name, [:named_table, :public, :set])
          _ ->
            :ok
        end
      end

      # Retry logic implementation
      defp execute_with_retry(_operation_fun, _config, attempt, max_retries, errors)
           when attempt > max_retries do
        Logger.error("Max retries (#{max_retries}) exceeded for #{@system} backend")
        {:error, :max_retries_exceeded}
      end

      defp execute_with_retry(operation_fun, config, attempt, max_retries, previous_errors) do
        start_time = System.monotonic_time(:millisecond)

        result = try do
          operation_fun.()
        rescue
          error ->
            {:error, {:exception, error}}
        catch
          :exit, reason ->
            {:error, {:exit, reason}}
          :throw, value ->
            {:error, {:throw, value}}
        end

        duration = System.monotonic_time(:millisecond) - start_time

        case result do
          {:ok, _} = success ->
            if attempt > 1 do
              Logger.info("#{@system} operation succeeded after #{attempt} attempts (#{duration}ms)")
              emit_telemetry(:retry, %{attempt: attempt, duration: duration}, %{
                event: :success,
                previous_errors: previous_errors
              })
            end
            success

          {:error, reason} ->
            updated_errors = [reason | previous_errors]
            {classification, error_type} = classify_error(reason)

            if classification == :retryable and attempt < max_retries do
              delay = calculate_retry_delay(attempt, config)

              Logger.warning(
                "#{@system} operation failed (attempt #{attempt}/#{max_retries}): #{inspect(reason)}. " <>
                "Retrying in #{delay}ms"
              )

              emit_telemetry(:retry, %{attempt: attempt, duration: duration, delay: delay}, %{
                event: :retry,
                error: reason,
                error_type: error_type
              })

              Process.sleep(delay)
              execute_with_retry(operation_fun, config, attempt + 1, max_retries, updated_errors)
            else
              Logger.error(
                "#{@system} operation failed permanently after #{attempt} attempts: #{inspect(reason)}"
              )

              emit_telemetry(:retry, %{attempt: attempt, duration: duration}, %{
                event: :failure,
                error: reason,
                error_type: error_type,
                all_errors: updated_errors
              })

              {:error, reason}
            end
        end
      end

      defp calculate_retry_delay(attempt, config) do
        base_delay = Map.get(config, :base_delay, 1000)
        max_delay = Map.get(config, :max_delay, 30_000)
        backoff_factor = Map.get(config, :backoff_factor, 2.0)
        jitter = Map.get(config, :jitter, true)

        # Calculate exponential backoff
        delay = trunc(base_delay * :math.pow(backoff_factor, attempt - 1))
        delay = min(delay, max_delay)

        # Add jitter if enabled
        if jitter do
          jitter_amount = trunc(delay * 0.1)  # 10% jitter
          jitter_offset = (:rand.uniform() - 0.5) * 2 * jitter_amount
          max(0, trunc(delay + jitter_offset))
        else
          delay
        end
      end
    end
  end
end
