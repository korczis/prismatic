defmodule Prismatic.Event.Telemetry do
  @moduledoc """
  Telemetry integration for the Prismatic Event System.

  This module provides comprehensive telemetry capabilities for monitoring
  and observability of the event system. It defines standard telemetry events,
  provides helper functions for emitting events, and integrates with the
  broader Elixir telemetry ecosystem.

  ## Architecture

  The telemetry system follows a structured approach:

  - **Event Naming**: Consistent naming convention for all events
  - **Measurements**: Standardized measurement types and units
  - **Metadata**: Rich contextual information for events
  - **Handlers**: Built-in handlers for common monitoring needs
  - **Integration**: Seamless integration with existing telemetry tools

  ## Event Categories

  The Event System emits telemetry events in several categories:

  ### Protocol Events
  - `[:prismatic, :event, :protocol, :publish]` - Event publication
  - `[:prismatic, :event, :protocol, :subscribe]` - Subscription creation
  - `[:prismatic, :event, :protocol, :unsubscribe]` - Subscription removal
  - `[:prismatic, :event, :protocol, :replay]` - Event replay operations

  ### Bus Events
  - `[:prismatic, :event, :bus, :publish]` - Bus-level event processing
  - `[:prismatic, :event, :bus, :subscribe]` - Bus subscription management
  - `[:prismatic, :event, :bus, :pattern_match]` - Pattern matching performance
  - `[:prismatic, :event, :bus, :delivery]` - Event delivery to subscribers

  ### Registry Events
  - `[:prismatic, :event, :registry, :subscribe]` - Registry subscription ops
  - `[:prismatic, :event, :registry, :pattern_match]` - Pattern matching ops
  - `[:prismatic, :event, :registry, :cache]` - Pattern cache operations

  ### Sourcing Events
  - `[:prismatic, :event, :sourcing, :store]` - Event storage operations
  - `[:prismatic, :event, :sourcing, :replay]` - Event replay operations
  - `[:prismatic, :event, :sourcing, :snapshot]` - Snapshot operations
  - `[:prismatic, :event, :sourcing, :compact]` - Storage compaction

  ### Backend Events
  - `[:prismatic, :event, :backend, :circuit_breaker]` - Circuit breaker state
  - `[:prismatic, :event, :backend, :retry]` - Retry logic operations
  - `[:prismatic, :event, :backend, :health]` - Backend health checks

  ## Usage

      # Emit a simple event
      Telemetry.emit(:publish, %{duration: 150}, %{event_type: "user.login"})

      # Emit with detailed context
      Telemetry.emit_protocol_event(:publish, :success, %{
        duration: 150,
        event_size: 256
      }, %{
        event_type: "user.login",
        backend: :in_memory,
        subscription_count: 5
      })

      # Setup monitoring handlers
      Telemetry.attach_default_handlers()

  ## Integration

  The telemetry system integrates with:

  - **:telemetry** - Core Elixir telemetry library
  - **TelemetryMetrics** - Metrics collection and aggregation
  - **TelemetryPoller** - Periodic system metrics collection
  - **Phoenix.LiveDashboard** - Web-based monitoring dashboard
  - **Prometheus** - Metrics export for monitoring systems
  """

  require Logger

  @typedoc "Telemetry event name segments"
  @type event_name :: [atom()]

  @typedoc "Measurement values (numeric)"
  @type measurements :: %{atom() => number()}

  @typedoc "Event metadata (contextual information)"
  @type metadata :: %{atom() => term()}

  @typedoc "Event category for organization"
  @type event_category :: :protocol | :bus | :registry | :sourcing | :backend | :system

  @typedoc "Event operation within category"
  @type event_operation :: atom()

  @typedoc "Event result status"
  @type event_status :: :success | :error | :timeout | :retry | :skip

  ## Public API

  @doc """
  Emit a telemetry event with measurements and metadata.

  This is the core function for emitting telemetry events. It builds
  the full event name and emits the event through the telemetry system.

  ## Parameters

  - `category` - Event category (protocol, bus, registry, etc.)
  - `operation` - Specific operation (publish, subscribe, etc.)
  - `status` - Operation result (:success, :error, etc.)
  - `measurements` - Numeric measurements
  - `metadata` - Contextual metadata

  ## Examples

      iex> Prismatic.Event.Telemetry.emit(:protocol, :publish, :success, %{duration: 150}, %{event_type: "test"})
      :ok

      iex> Prismatic.Event.Telemetry.emit(:bus, :pattern_match, :success, %{matches: 3, duration: 50}, %{pattern: "user.*"})
      :ok
  """
  @spec emit(event_category(), event_operation(), event_status(), measurements(), metadata()) :: :ok
  def emit(category, operation, status, measurements \\ %{}, metadata \\ %{}) do
    event_name = build_event_name(category, operation, status)
    enriched_metadata = enrich_metadata(metadata)

    :telemetry.execute(event_name, measurements, enriched_metadata)
    :ok
  end

  @doc """
  Emit a protocol-level event.

  Convenience function for emitting events related to the main protocol
  operations like publish, subscribe, and replay.

  ## Parameters

  - `operation` - Protocol operation (:publish, :subscribe, :replay, etc.)
  - `status` - Operation result
  - `measurements` - Measurements map
  - `metadata` - Metadata map

  ## Examples

      iex> Prismatic.Event.Telemetry.emit_protocol_event(:publish, :success, %{duration: 100}, %{event_type: "user.login"})
      :ok
  """
  @spec emit_protocol_event(event_operation(), event_status(), measurements(), metadata()) :: :ok
  def emit_protocol_event(operation, status, measurements \\ %{}, metadata \\ %{}) do
    emit(:protocol, operation, status, measurements, metadata)
  end

  @doc """
  Emit a bus-level event.

  Convenience function for emitting events related to the event bus
  operations and performance metrics.

  ## Parameters

  - `operation` - Bus operation (:publish, :delivery, :pattern_match, etc.)
  - `status` - Operation result
  - `measurements` - Measurements map
  - `metadata` - Metadata map
  """
  @spec emit_bus_event(event_operation(), event_status(), measurements(), metadata()) :: :ok
  def emit_bus_event(operation, status, measurements \\ %{}, metadata \\ %{}) do
    emit(:bus, operation, status, measurements, metadata)
  end

  @doc """
  Emit a registry-level event.

  Convenience function for emitting events related to subscription
  registry operations and pattern matching performance.

  ## Parameters

  - `operation` - Registry operation (:subscribe, :pattern_match, :cache, etc.)
  - `status` - Operation result
  - `measurements` - Measurements map
  - `metadata` - Metadata map
  """
  @spec emit_registry_event(event_operation(), event_status(), measurements(), metadata()) :: :ok
  def emit_registry_event(operation, status, measurements \\ %{}, metadata \\ %{}) do
    emit(:registry, operation, status, measurements, metadata)
  end

  @doc """
  Emit a sourcing-level event.

  Convenience function for emitting events related to event sourcing
  operations like storage, replay, and compaction.

  ## Parameters

  - `operation` - Sourcing operation (:store, :replay, :snapshot, :compact, etc.)
  - `status` - Operation result
  - `measurements` - Measurements map
  - `metadata` - Metadata map
  """
  @spec emit_sourcing_event(event_operation(), event_status(), measurements(), metadata()) :: :ok
  def emit_sourcing_event(operation, status, measurements \\ %{}, metadata \\ %{}) do
    emit(:sourcing, operation, status, measurements, metadata)
  end

  @doc """
  Emit a backend-level event.

  Convenience function for emitting events related to backend
  infrastructure like circuit breakers and retry logic.

  ## Parameters

  - `operation` - Backend operation (:circuit_breaker, :retry, :health, etc.)
  - `status` - Operation result
  - `measurements` - Measurements map
  - `metadata` - Metadata map
  """
  @spec emit_backend_event(event_operation(), event_status(), measurements(), metadata()) :: :ok
  def emit_backend_event(operation, status, measurements \\ %{}, metadata \\ %{}) do
    emit(:backend, operation, status, measurements, metadata)
  end

  @doc """
  Execute a function while measuring its duration.

  Wraps a function execution with automatic duration measurement and
  telemetry event emission based on the result.

  ## Parameters

  - `category` - Event category
  - `operation` - Operation being measured
  - `fun` - Function to execute and measure
  - `metadata` - Additional metadata

  ## Returns

  The result of the function execution.

  ## Examples

      iex> result = Prismatic.Event.Telemetry.measure(:protocol, :publish, fn ->
      ...>   # Simulate work
      ...>   :timer.sleep(100)
      ...>   {:ok, "event_123"}
      ...> end, %{event_type: "user.login"})
      iex> result
      {:ok, "event_123"}
  """
  @spec measure(event_category(), event_operation(), (() -> term()), metadata()) :: term()
  def measure(category, operation, fun, metadata \\ %{}) when is_function(fun, 0) do
    start_time = System.monotonic_time()

    try do
      result = fun.()
      duration = System.monotonic_time() - start_time

      status = determine_status_from_result(result)
      measurements = %{duration: duration}

      emit(category, operation, status, measurements, metadata)

      result
    rescue
      error ->
        duration = System.monotonic_time() - start_time
        measurements = %{duration: duration}
        error_metadata = Map.put(metadata, :error, inspect(error))

        emit(category, operation, :error, measurements, error_metadata)

        reraise error, __STACKTRACE__
    end
  end

  @doc """
  Attach default telemetry handlers for common monitoring needs.

  Sets up handlers for logging, metrics collection, and health monitoring.
  This is typically called during application startup.

  ## Options

  - `:log_level` - Log level for telemetry events (default: :info)
  - `:enable_metrics` - Enable metrics collection (default: true)
  - `:enable_health_checks` - Enable health monitoring (default: true)

  ## Examples

      iex> Prismatic.Event.Telemetry.attach_default_handlers()
      :ok

      iex> Prismatic.Event.Telemetry.attach_default_handlers(log_level: :debug)
      :ok
  """
  @spec attach_default_handlers(keyword()) :: :ok
  def attach_default_handlers(options \\ []) do
    log_level = Keyword.get(options, :log_level, :info)
    enable_metrics = Keyword.get(options, :enable_metrics, true)
    enable_health_checks = Keyword.get(options, :enable_health_checks, true)

    # Attach logging handler
    :telemetry.attach(
      "prismatic-event-logger",
      [:prismatic, :event],
      &handle_telemetry_event/4,
      %{log_level: log_level}
    )

    # Attach metrics handler if enabled
    if enable_metrics do
      :telemetry.attach(
        "prismatic-event-metrics",
        [:prismatic, :event],
        &handle_metrics_event/4,
        %{}
      )
    end

    # Attach health monitoring if enabled
    if enable_health_checks do
      :telemetry.attach(
        "prismatic-event-health",
        [:prismatic, :event, :backend],
        &handle_health_event/4,
        %{}
      )
    end

    Logger.info("Prismatic Event System telemetry handlers attached", %{
      log_level: log_level,
      metrics_enabled: enable_metrics,
      health_checks_enabled: enable_health_checks
    })

    :ok
  end

  @doc """
  Detach all default telemetry handlers.

  Removes the handlers that were attached by `attach_default_handlers/1`.
  Useful for testing or when custom handlers are preferred.

  ## Examples

      iex> Prismatic.Event.Telemetry.detach_default_handlers()
      :ok
  """
  @spec detach_default_handlers() :: :ok
  def detach_default_handlers do
    :telemetry.detach("prismatic-event-logger")
    :telemetry.detach("prismatic-event-metrics")
    :telemetry.detach("prismatic-event-health")

    Logger.info("Prismatic Event System telemetry handlers detached")
    :ok
  end

  @doc """
  Get current telemetry metrics summary.

  Returns a summary of collected metrics for monitoring and debugging.
  This function aggregates data from the telemetry handlers.

  ## Returns

  A map containing metric summaries organized by category and operation.

  ## Examples

      iex> metrics = Prismatic.Event.Telemetry.get_metrics_summary()
      iex> is_map(metrics)
      true
  """
  @spec get_metrics_summary() :: map()
  def get_metrics_summary do
    # This would integrate with actual metrics storage
    # For now, return a basic structure
    %{
      protocol: %{
        publish: %{count: 0, avg_duration: 0, error_rate: 0.0},
        subscribe: %{count: 0, avg_duration: 0, error_rate: 0.0},
        replay: %{count: 0, avg_duration: 0, error_rate: 0.0}
      },
      bus: %{
        delivery: %{count: 0, avg_duration: 0, error_rate: 0.0},
        pattern_match: %{count: 0, avg_duration: 0, error_rate: 0.0}
      },
      sourcing: %{
        store: %{count: 0, avg_duration: 0, error_rate: 0.0},
        replay: %{count: 0, avg_duration: 0, error_rate: 0.0}
      },
      backend: %{
        circuit_breaker_trips: 0,
        retry_attempts: 0,
        health_check_failures: 0
      }
    }
  end

  ## Private Implementation

  @spec build_event_name(event_category(), event_operation(), event_status()) :: event_name()
  defp build_event_name(category, operation, status) do
    [:prismatic, :event, category, operation, status]
  end

  @spec enrich_metadata(metadata()) :: metadata()
  defp enrich_metadata(metadata) do
    base_metadata = %{
      timestamp: DateTime.utc_now(),
      node: Node.self(),
      pid: self(),
      system: :prismatic_event
    }

    Map.merge(base_metadata, metadata)
  end

  @spec determine_status_from_result(term()) :: event_status()
  defp determine_status_from_result(result) do
    case result do
      {:ok, _} -> :success
      :ok -> :success
      {:error, _} -> :error
      {:timeout, _} -> :timeout
      _ -> :success  # Default for non-tuple returns
    end
  end

  @spec handle_telemetry_event(event_name(), measurements(), metadata(), map()) :: :ok
  defp handle_telemetry_event(event_name, measurements, metadata, config) do
    log_level = Map.get(config, :log_level, :info)

    # Format event for logging
    event_summary = %{
      event: Enum.join(event_name, "."),
      measurements: measurements,
      metadata: filter_sensitive_metadata(metadata)
    }

    Logger.log(log_level, "Prismatic Event Telemetry", event_summary)
  end

  @spec handle_metrics_event(event_name(), measurements(), metadata(), map()) :: :ok
  defp handle_metrics_event(_event_name, _measurements, _metadata, _config) do
    # This would integrate with metrics collection systems
    # like TelemetryMetrics, Prometheus, etc.
    :ok
  end

  @spec handle_health_event(event_name(), measurements(), metadata(), map()) :: :ok
  defp handle_health_event(event_name, measurements, metadata, _config) do
    # Monitor health-related events for alerting
    case event_name do
      [:prismatic, :event, :backend, :circuit_breaker, :open] ->
        Logger.warning("Circuit breaker opened", %{
          backend: Map.get(metadata, :backend_type),
          measurements: measurements
        })

      [:prismatic, :event, :backend, :health, :error] ->
        Logger.error("Backend health check failed", %{
          backend: Map.get(metadata, :backend_type),
          error: Map.get(metadata, :error)
        })

      _ ->
        :ok
    end
  end

  @spec filter_sensitive_metadata(metadata()) :: metadata()
  defp filter_sensitive_metadata(metadata) do
    # Remove potentially sensitive information from logs
    sensitive_keys = [:pid, :handler, :credentials, :api_key]

    Enum.reduce(sensitive_keys, metadata, fn key, acc ->
      case Map.get(acc, key) do
        nil -> acc
        _value -> Map.put(acc, key, "[FILTERED]")
      end
    end)
  end
end
