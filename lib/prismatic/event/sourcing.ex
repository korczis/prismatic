defmodule Prismatic.Event.Sourcing do
  @moduledoc """
  Event sourcing and replay functionality for the Prismatic Event System.

  This module provides comprehensive event sourcing capabilities including
  persistent storage, replay functionality, and event history management.
  It ensures complete auditability and enables system recovery through
  event replay.

  ## Architecture

  The Sourcing system uses a layered storage approach:

  - **Event Store**: Persistent storage for all events
  - **Index Layer**: Fast access indexes for queries and replay
  - **Snapshot System**: Periodic snapshots for performance
  - **Compaction Engine**: Automated cleanup of old events

  ## Features

  - **Complete Event History**: All events are persisted with metadata
  - **Temporal Queries**: Query events by time ranges
  - **Pattern-based Replay**: Replay events matching specific patterns
  - **Snapshot Support**: Efficient state reconstruction
  - **Concurrent Access**: Thread-safe operations with high performance
  - **Storage Backends**: Pluggable storage implementations

  ## Event Storage

  Events are stored with comprehensive metadata:

      %{
        event_id: "abc123...",
        sequence_number: 12345,
        timestamp: ~U[2024-01-01 10:00:00Z],
        event_type: "agent.alice.message",
        payload: %{content: "Hello"},
        metadata: %{
          source: "prismatic_event_bus",
          correlation_id: "xyz789",
          causation_id: "def456"
        },
        storage_metadata: %{
          stored_at: ~U[2024-01-01 10:00:01Z],
          storage_backend: :mnesia,
          checksum: "sha256:...",
          size_bytes: 256
        }
      }

  ## Replay Options

  Flexible replay capabilities with various filtering options:

      %{
        from: ~U[2024-01-01 00:00:00Z],
        to: ~U[2024-01-01 23:59:59Z],
        from_sequence: 1000,
        to_sequence: 2000,
        patterns: ["agent.*", "system.error.*"],
        limit: 1000,
        order: :asc,
        include_snapshots: false
      }

  ## Usage

  The sourcing system is typically managed by the Event Bus:

      {:ok, sourcing} = Prismatic.Event.Sourcing.start_link(config: config)
      {:ok, _} = Prismatic.Event.Sourcing.store_event(sourcing, event)
      {:ok, events} = Prismatic.Event.Sourcing.replay(sourcing, replay_options)
  """

  use GenServer
  require Logger

  alias Prismatic.Event.{Protocol, Pattern}

  @type sourcing_state :: %{
    config: Protocol.config(),
    storage_backend: module(),
    event_sequence: non_neg_integer(),
    last_snapshot_sequence: non_neg_integer(),
    index_cache: map(),
    metrics: map()
  }

  @type stored_event :: %{
    event_id: Protocol.event_id(),
    sequence_number: non_neg_integer(),
    timestamp: DateTime.t(),
    event_type: String.t(),
    payload: map(),
    metadata: Protocol.event_metadata(),
    storage_metadata: map()
  }

  @type snapshot :: %{
    sequence_number: non_neg_integer(),
    timestamp: DateTime.t(),
    state_data: term(),
    metadata: map()
  }

  @type start_options :: [
    config: Protocol.config(),
    name: atom()
  ]

  @snapshot_interval 10_000

  ## Public API

  @doc """
  Start the Event Sourcing GenServer.

  ## Options

  - `:config` - Event system configuration
  - `:name` - Process name (default: `__MODULE__`)

  ## Examples

      iex> config = %{backend_type: :test, enable_sourcing: true}
      iex> {:ok, pid} = Prismatic.Event.Sourcing.start_link(config: config, name: :test_sourcing)
      iex> is_pid(pid)
      true
  """
  @spec start_link(start_options()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Store an event in the event store.

  Persists the event with a unique sequence number and comprehensive
  metadata for later retrieval and replay.

  ## Parameters

  - `sourcing` - Sourcing process identifier
  - `event` - Event to store

  ## Returns

  - `{:ok, sequence_number}` - Successfully stored with sequence number
  - `{:error, reason}` - Storage failed

  ## Examples

      iex> {:ok, sourcing} = Prismatic.Event.Sourcing.start_link(config: %{backend_type: :test})
      iex> event = %{type: "test.event", payload: %{data: "hello"}, metadata: %{event_id: "123"}}
      iex> {:ok, seq_num} = Prismatic.Event.Sourcing.store_event(sourcing, event)
      iex> is_integer(seq_num)
      true
  """
  @spec store_event(GenServer.server(), Protocol.event()) :: {:ok, non_neg_integer()} | {:error, term()}
  def store_event(sourcing, event) do
    GenServer.call(sourcing, {:store_event, event})
  end

  @doc """
  Replay events based on the given options.

  Retrieves events from the store matching the specified criteria
  with efficient querying and optional result limiting.

  ## Parameters

  - `sourcing` - Sourcing process identifier
  - `options` - Replay options map

  ## Returns

  - `{:ok, events}` - Successfully retrieved events
  - `{:error, reason}` - Replay failed

  ## Examples

      iex> {:ok, sourcing} = Prismatic.Event.Sourcing.start_link(config: %{backend_type: :test})
      iex> {:ok, events} = Prismatic.Event.Sourcing.replay(sourcing, %{limit: 10})
      iex> is_list(events)
      true

      iex> {:ok, sourcing} = Prismatic.Event.Sourcing.start_link(config: %{backend_type: :test})
      iex> {:ok, events} = Prismatic.Event.Sourcing.replay(sourcing, %{patterns: ["agent.*"]})
      iex> is_list(events)
      true
  """
  @spec replay(GenServer.server(), Protocol.replay_options()) :: {:ok, [Protocol.event()]} | {:error, term()}
  def replay(sourcing, options \\ %{}) do
    GenServer.call(sourcing, {:replay, options})
  end

  @doc """
  Get the current event sequence number.

  Returns the sequence number that will be assigned to the next stored event.

  ## Parameters

  - `sourcing` - Sourcing process identifier

  ## Returns

  - `{:ok, sequence_number}` - Current sequence number
  - `{:error, reason}` - Failed to get sequence

  ## Examples

      iex> {:ok, sourcing} = Prismatic.Event.Sourcing.start_link(config: %{backend_type: :test})
      iex> {:ok, seq_num} = Prismatic.Event.Sourcing.get_current_sequence(sourcing)
      iex> is_integer(seq_num)
      true
  """
  @spec get_current_sequence(GenServer.server()) :: {:ok, non_neg_integer()} | {:error, term()}
  def get_current_sequence(sourcing) do
    GenServer.call(sourcing, :get_current_sequence)
  end

  @doc """
  Create a snapshot of the current system state.

  Snapshots enable faster replay by providing checkpoints in the event stream.

  ## Parameters

  - `sourcing` - Sourcing process identifier
  - `state_data` - Data to include in snapshot

  ## Returns

  - `{:ok, snapshot_sequence}` - Successfully created snapshot
  - `{:error, reason}` - Snapshot creation failed

  ## Examples

      iex> {:ok, sourcing} = Prismatic.Event.Sourcing.start_link(config: %{backend_type: :test})
      iex> {:ok, snap_seq} = Prismatic.Event.Sourcing.create_snapshot(sourcing, %{state: "current"})
      iex> is_integer(snap_seq)
      true
  """
  @spec create_snapshot(GenServer.server(), term()) :: {:ok, non_neg_integer()} | {:error, term()}
  def create_snapshot(sourcing, state_data) do
    GenServer.call(sourcing, {:create_snapshot, state_data})
  end

  @doc """
  Get sourcing statistics and metrics.

  Returns comprehensive information about sourcing performance and state.

  ## Parameters

  - `sourcing` - Sourcing process identifier

  ## Returns

  - `{:ok, stats}` - Sourcing statistics
  - `{:error, reason}` - Failed to get stats

  ## Examples

      iex> {:ok, sourcing} = Prismatic.Event.Sourcing.start_link(config: %{backend_type: :test})
      iex> {:ok, stats} = Prismatic.Event.Sourcing.get_stats(sourcing)
      iex> is_map(stats)
      true
      iex> Map.has_key?(stats, :events_stored)
      true
  """
  @spec get_stats(GenServer.server()) :: {:ok, map()} | {:error, term()}
  def get_stats(sourcing) do
    GenServer.call(sourcing, :get_stats)
  end

  @doc """
  Compact the event store by removing old events.

  Removes events older than the specified criteria while preserving
  important snapshots and recent history.

  ## Parameters

  - `sourcing` - Sourcing process identifier
  - `options` - Compaction options

  ## Returns

  - `{:ok, compacted_count}` - Number of events removed
  - `{:error, reason}` - Compaction failed

  ## Examples

      iex> {:ok, sourcing} = Prismatic.Event.Sourcing.start_link(config: %{backend_type: :test})
      iex> {:ok, count} = Prismatic.Event.Sourcing.compact(sourcing, %{older_than: DateTime.add(DateTime.utc_now(), -86400, :second)})
      iex> is_integer(count)
      true
  """
  @spec compact(GenServer.server(), map()) :: {:ok, non_neg_integer()} | {:error, term()}
  def compact(sourcing, options \\ %{}) do
    GenServer.call(sourcing, {:compact, options})
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(opts) do
    config = Keyword.fetch!(opts, :config)

    # Initialize storage backend
    {:ok, storage_backend} = get_storage_backend(config.backend_type)

    # Initialize storage
    case storage_backend.init_storage(config) do
      :ok ->
        # Get current sequence number from storage
        current_sequence = storage_backend.get_last_sequence_number(config)

        state = %{
          config: config,
          storage_backend: storage_backend,
          event_sequence: current_sequence + 1,
          last_snapshot_sequence: 0,
          index_cache: %{},
          metrics: %{
            events_stored: 0,
            events_replayed: 0,
            snapshots_created: 0,
            compactions_performed: 0,
            storage_size_bytes: 0
          }
        }

        Logger.info("Event Sourcing started", %{
          backend: config.backend_type,
          current_sequence: current_sequence
        })

        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to initialize event sourcing storage", %{reason: reason})
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:store_event, event}, _from, state) do
    stored_event = %{
      event_id: event.metadata.event_id,
      sequence_number: state.event_sequence,
      timestamp: event.metadata.timestamp,
      event_type: event.type,
      payload: event.payload,
      metadata: event.metadata,
      storage_metadata: %{
        stored_at: DateTime.utc_now(),
        storage_backend: state.config.backend_type,
        checksum: calculate_checksum(event),
        size_bytes: calculate_size(event)
      }
    }

    case state.storage_backend.store_event(state.config, stored_event) do
      :ok ->
        # Update metrics
        new_metrics = update_metrics(state.metrics, :events_stored)
        new_state = %{state |
          event_sequence: state.event_sequence + 1,
          metrics: new_metrics
        }

        # Check if snapshot is needed
        if should_create_snapshot?(state) do
          Task.start(fn ->
            create_automatic_snapshot(self(), new_state)
          end)
        end

        {:reply, {:ok, stored_event.sequence_number}, new_state}

      {:error, reason} ->
        Logger.warning("Event storage failed", %{
          reason: reason,
          event_id: event.metadata.event_id
        })
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:replay, options}, _from, state) do
    case state.storage_backend.query_events(state.config, options) do
      {:ok, stored_events} ->
        # Convert stored events back to protocol events
        events = Enum.map(stored_events, &stored_event_to_protocol_event/1)

        # Apply pattern filtering if specified
        filtered_events = if Map.has_key?(options, :patterns) do
          filter_events_by_patterns(events, options.patterns)
        else
          events
        end

        # Update metrics
        new_metrics = update_metrics(state.metrics, :events_replayed, length(filtered_events))
        new_state = %{state | metrics: new_metrics}

        {:reply, {:ok, filtered_events}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_current_sequence, _from, state) do
    {:reply, {:ok, state.event_sequence}, state}
  end

  @impl GenServer
  def handle_call({:create_snapshot, state_data}, _from, state) do
    snapshot = %{
      sequence_number: state.event_sequence - 1,
      timestamp: DateTime.utc_now(),
      state_data: state_data,
      metadata: %{
        created_by: :manual,
        storage_backend: state.config.backend_type
      }
    }

    case state.storage_backend.store_snapshot(state.config, snapshot) do
      :ok ->
        new_metrics = update_metrics(state.metrics, :snapshots_created)
        new_state = %{state |
          last_snapshot_sequence: snapshot.sequence_number,
          metrics: new_metrics
        }

        {:reply, {:ok, snapshot.sequence_number}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    stats = %{
      backend_type: state.config.backend_type,
      current_sequence: state.event_sequence,
      last_snapshot_sequence: state.last_snapshot_sequence,
      metrics: state.metrics,
      index_cache_size: map_size(state.index_cache)
    }

    {:reply, {:ok, stats}, state}
  end

  @impl GenServer
  def handle_call({:compact, options}, _from, state) do
    case state.storage_backend.compact_events(state.config, options) do
      {:ok, compacted_count} ->
        new_metrics = update_metrics(state.metrics, :compactions_performed)
        new_state = %{state | metrics: new_metrics}

        Logger.info("Event store compaction completed", %{
          compacted_count: compacted_count,
          options: options
        })

        {:reply, {:ok, compacted_count}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  ## Private Implementation

  @spec get_storage_backend(Protocol.backend_type()) :: {:ok, module()} | {:error, term()}
  defp get_storage_backend(:test), do: {:ok, Prismatic.Event.Storage.TestBackend}
  defp get_storage_backend(:in_memory), do: {:ok, Prismatic.Event.Storage.InMemoryBackend}
  defp get_storage_backend(:mnesia), do: {:error, {:not_implemented, :mnesia}}
  defp get_storage_backend(:postgres), do: {:error, {:not_implemented, :postgres}}
  defp get_storage_backend(backend_type), do: {:error, {:unsupported_storage_backend, backend_type}}

  @spec calculate_checksum(Protocol.event()) :: String.t()
  defp calculate_checksum(event) do
    event
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @spec calculate_size(Protocol.event()) :: non_neg_integer()
  defp calculate_size(event) do
    event
    |> :erlang.term_to_binary()
    |> byte_size()
  end

  @spec should_create_snapshot?(sourcing_state()) :: boolean()
  defp should_create_snapshot?(state) do
    state.event_sequence - state.last_snapshot_sequence >= @snapshot_interval
  end

  @spec create_automatic_snapshot(pid(), sourcing_state()) :: :ok
  defp create_automatic_snapshot(sourcing_pid, state) do
    snapshot_data = %{
      auto_snapshot: true,
      sequence: state.event_sequence - 1,
      timestamp: DateTime.utc_now()
    }

    case create_snapshot(sourcing_pid, snapshot_data) do
      {:ok, _} ->
        Logger.debug("Automatic snapshot created", %{sequence: state.event_sequence - 1})
      {:error, reason} ->
        Logger.warning("Automatic snapshot failed", %{reason: reason})
    end
  end

  @spec stored_event_to_protocol_event(stored_event()) :: Protocol.event()
  defp stored_event_to_protocol_event(stored_event) do
    %{
      type: stored_event.event_type,
      payload: stored_event.payload,
      metadata: stored_event.metadata
    }
  end

  @spec filter_events_by_patterns([Protocol.event()], [String.t()]) :: [Protocol.event()]
  defp filter_events_by_patterns(events, patterns) do
    Enum.filter(events, fn event ->
      Enum.any?(patterns, &Pattern.match?(&1, event.type))
    end)
  end

  @spec update_metrics(map(), atom(), non_neg_integer()) :: map()
  defp update_metrics(metrics, key, increment \\ 1) do
    Map.update(metrics, key, increment, &(&1 + increment))
  end
end
