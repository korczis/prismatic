defmodule Prismatic.Event.Storage.Behaviour do
  @moduledoc """
  Behaviour definition for Event Sourcing storage backends.

  This module defines the contract that all event storage backends must
  implement to provide persistent storage for event sourcing functionality.
  It supports event storage, querying, snapshots, and compaction operations.

  ## Storage Operations

  - **Event Storage**: Persistent storage of events with metadata
  - **Event Querying**: Flexible querying with time and sequence filters
  - **Snapshot Management**: Periodic snapshots for performance
  - **Compaction**: Cleanup of old events to manage storage size

  ## Implementation Requirements

  All storage backends must implement the following callbacks:

  - `init_storage/1` - Initialize storage system
  - `store_event/2` - Store a single event
  - `query_events/2` - Query events with filters
  - `get_last_sequence_number/1` - Get current sequence number
  - `store_snapshot/2` - Store a snapshot
  - `get_latest_snapshot/2` - Retrieve latest snapshot
  - `compact_events/2` - Remove old events

  ## Available Backends

  - `TestBackend` - In-memory testing backend
  - `InMemoryBackend` - High-performance in-memory storage
  - `MnesiaBackend` - Distributed persistent storage (planned)
  - `PostgresBackend` - SQL database storage (planned)
  """

  alias Prismatic.Event.{Protocol, Sourcing}

  @doc """
  Initialize the storage backend.

  Sets up any necessary tables, connections, or resources needed
  for the storage backend to operate correctly.

  ## Parameters

  - `config` - Storage configuration

  ## Returns

  - `:ok` - Storage initialized successfully
  - `{:error, reason}` - Initialization failed
  """
  @callback init_storage(Protocol.config()) :: :ok | {:error, term()}

  @doc """
  Store an event in persistent storage.

  Stores the event with all metadata, ensuring it can be retrieved
  for replay operations. The event should be stored atomically.

  ## Parameters

  - `config` - Storage configuration
  - `stored_event` - Event with storage metadata

  ## Returns

  - `:ok` - Event stored successfully
  - `{:error, reason}` - Storage failed
  """
  @callback store_event(Protocol.config(), Sourcing.stored_event()) :: :ok | {:error, term()}

  @doc """
  Query events from storage based on criteria.

  Retrieves events matching the specified filters. Should support
  efficient querying for time ranges, sequence ranges, and limits.

  ## Parameters

  - `config` - Storage configuration
  - `options` - Query options map

  ## Query Options

  - `:from` - Start time (DateTime)
  - `:to` - End time (DateTime)
  - `:from_sequence` - Start sequence number
  - `:to_sequence` - End sequence number
  - `:limit` - Maximum number of events
  - `:order` - `:asc` or `:desc`

  ## Returns

  - `{:ok, events}` - Successfully retrieved events
  - `{:error, reason}` - Query failed
  """
  @callback query_events(Protocol.config(), map()) :: {:ok, [Sourcing.stored_event()]} | {:error, term()}

  @doc """
  Get the last sequence number used.

  Returns the highest sequence number that has been stored,
  used for determining the next sequence number to assign.

  ## Parameters

  - `config` - Storage configuration

  ## Returns

  - `sequence_number` - Last used sequence number (0 if none)
  """
  @callback get_last_sequence_number(Protocol.config()) :: non_neg_integer()

  @doc """
  Store a snapshot of system state.

  Stores a snapshot that can be used to speed up replay operations
  by providing a checkpoint in the event stream.

  ## Parameters

  - `config` - Storage configuration
  - `snapshot` - Snapshot data with metadata

  ## Returns

  - `:ok` - Snapshot stored successfully
  - `{:error, reason}` - Storage failed
  """
  @callback store_snapshot(Protocol.config(), Sourcing.snapshot()) :: :ok | {:error, term()}

  @doc """
  Get the latest snapshot before a sequence number.

  Retrieves the most recent snapshot that occurred before the
  specified sequence number, used for optimized replay.

  ## Parameters

  - `config` - Storage configuration
  - `before_sequence` - Maximum sequence number

  ## Returns

  - `{:ok, snapshot}` - Found snapshot
  - `{:error, :no_snapshots}` - No snapshots available
  - `{:error, reason}` - Retrieval failed
  """
  @callback get_latest_snapshot(Protocol.config(), non_neg_integer()) ::
    {:ok, Sourcing.snapshot()} | {:error, term()}

  @doc """
  Compact old events from storage.

  Removes old events according to the specified criteria to
  manage storage size and improve performance.

  ## Parameters

  - `config` - Storage configuration
  - `options` - Compaction options

  ## Compaction Options

  - `:older_than` - Remove events older than this DateTime
  - `:keep_snapshots` - Preserve events referenced by snapshots
  - `:batch_size` - Number of events to process at once

  ## Returns

  - `{:ok, removed_count}` - Number of events removed
  - `{:error, reason}` - Compaction failed
  """
  @callback compact_events(Protocol.config(), map()) :: {:ok, non_neg_integer()} | {:error, term()}
end
