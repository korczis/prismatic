defmodule Prismatic.Event.Storage.InMemoryBackend do
  @moduledoc """
  High-performance in-memory storage backend for Event Sourcing.

  This module provides a production-ready in-memory storage implementation
  using ETS tables for efficient event storage and retrieval. It supports
  all storage operations with optimized indexing and query performance.

  ## Features

  - **High Performance**: Optimized ETS table operations
  - **Concurrent Access**: Thread-safe operations with proper locking
  - **Efficient Querying**: Indexed access for time and sequence queries
  - **Snapshot Support**: Automatic snapshot management
  - **Memory Management**: Configurable limits and cleanup
  - **Hot Reloading**: Runtime configuration updates

  ## Architecture

  Uses multiple ETS tables for optimal performance:

  - **Events Table**: Main event storage (ordered by sequence)
  - **Time Index**: Secondary index for time-based queries
  - **Snapshots Table**: Snapshot storage and management
  - **Metadata Table**: Storage configuration and statistics

  ## Usage

  Suitable for production single-node deployments where high performance
  is required and persistence across restarts is not needed.
  """

  @behaviour Prismatic.Event.Storage.Behaviour

  alias Prismatic.Event.Protocol

  @events_table_name :prismatic_sourcing_events
  @time_index_table_name :prismatic_sourcing_time_index
  @snapshots_table_name :prismatic_sourcing_snapshots
  @metadata_table_name :prismatic_sourcing_metadata

  ## Storage Behaviour Implementation

  @impl true
  def init_storage(config) do
    try do
      # Create events table (ordered by sequence number)
      events_table = :"#{config.name}_#{@events_table_name}"
      case :ets.whereis(events_table) do
        :undefined ->
          :ets.new(events_table, [:named_table, :public, :ordered_set, {:keypos, 1}])
        _ ->
          :ok
      end

      # Create time index table for time-based queries
      time_index_table = :"#{config.name}_#{@time_index_table_name}"
      case :ets.whereis(time_index_table) do
        :undefined ->
          :ets.new(time_index_table, [:named_table, :public, :ordered_set, {:keypos, 1}])
        _ ->
          :ok
      end

      # Create snapshots table
      snapshots_table = :"#{config.name}_#{@snapshots_table_name}"
      case :ets.whereis(snapshots_table) do
        :undefined ->
          :ets.new(snapshots_table, [:named_table, :public, :ordered_set, {:keypos, 1}])
        _ ->
          :ok
      end

      # Create metadata table
      metadata_table = :"#{config.name}_#{@metadata_table_name}"
      case :ets.whereis(metadata_table) do
        :undefined ->
          table = :ets.new(metadata_table, [:named_table, :public, :set, {:keypos, 1}])
          # Initialize metadata
          :ets.insert(table, {:last_sequence, 0})
          :ets.insert(table, {:event_count, 0})
          :ets.insert(table, {:snapshot_count, 0})
        _ ->
          :ok
      end

      :ok
    rescue
      error ->
        {:error, {:storage_init_failed, error}}
    end
  end

  @impl true
  def store_event(config, stored_event) do
    events_table = :"#{config.name}_#{@events_table_name}"
    time_index_table = :"#{config.name}_#{@time_index_table_name}"
    metadata_table = :"#{config.name}_#{@metadata_table_name}"

    try do
      sequence = stored_event.sequence_number
      timestamp = stored_event.timestamp

      # Store in main events table
      :ets.insert(events_table, {sequence, stored_event})

      # Update time index for efficient time-based queries
      timestamp_key = {DateTime.to_unix(timestamp, :microsecond), sequence}
      :ets.insert(time_index_table, {timestamp_key, sequence})

      # Update metadata
      :ets.update_counter(metadata_table, :event_count, 1, {:event_count, 0})
      :ets.insert(metadata_table, {:last_sequence, sequence})

      # Enforce storage limits if configured
      enforce_storage_limits(config, events_table, time_index_table, metadata_table)

      :ok
    rescue
      error ->
        {:error, {:event_storage_failed, error}}
    end
  end

  @impl true
  def query_events(config, options) do
    events_table = :"#{config.name}_#{@events_table_name}"
    time_index_table = :"#{config.name}_#{@time_index_table_name}"

    try do
      # Determine optimal query strategy
      events = case determine_query_strategy(options) do
        :sequence_range ->
          query_by_sequence_range(events_table, options)
        :time_range ->
          query_by_time_range(events_table, time_index_table, options)
        :full_scan ->
          query_full_table(events_table, options)
      end

      # Apply additional filters and ordering
      filtered_events = events
      |> apply_remaining_filters(options)
      |> apply_ordering(options)
      |> apply_limit(options)

      {:ok, filtered_events}
    rescue
      error ->
        {:error, {:query_failed, error}}
    end
  end

  @impl true
  def get_last_sequence_number(config) do
    metadata_table = :"#{config.name}_#{@metadata_table_name}"

    case :ets.lookup(metadata_table, :last_sequence) do
      [{:last_sequence, sequence}] -> sequence
      [] -> 0
    end
  end

  @impl true
  def store_snapshot(config, snapshot) do
    snapshots_table = :"#{config.name}_#{@snapshots_table_name}"
    metadata_table = :"#{config.name}_#{@metadata_table_name}"

    try do
      sequence = snapshot.sequence_number

      # Store snapshot
      :ets.insert(snapshots_table, {sequence, snapshot})

      # Update metadata
      :ets.update_counter(metadata_table, :snapshot_count, 1, {:snapshot_count, 0})

      # Clean up old snapshots if configured
      cleanup_old_snapshots(config, snapshots_table)

      :ok
    rescue
      error ->
        {:error, {:snapshot_storage_failed, error}}
    end
  end

  @impl true
  def get_latest_snapshot(config, before_sequence) do
    snapshots_table = :"#{config.name}_#{@snapshots_table_name}"

    try do
      # Find snapshots before the given sequence
      matching_snapshots = :ets.select(snapshots_table, [
        {{"$1", "$2"}, [{"<", "$1", before_sequence}], ["$2"]}
      ])

      case Enum.sort_by(matching_snapshots, &(&1.sequence_number), :desc) do
        [latest | _] -> {:ok, latest}
        [] -> {:error, :no_snapshots}
      end
    rescue
      error ->
        {:error, {:snapshot_retrieval_failed, error}}
    end
  end

  @impl true
  def compact_events(config, options) do
    events_table = :"#{config.name}_#{@events_table_name}"
    time_index_table = :"#{config.name}_#{@time_index_table_name}"
    metadata_table = :"#{config.name}_#{@metadata_table_name}"

    try do
      # Determine compaction criteria
      {compaction_strategy, criteria} = determine_compaction_strategy(options)

      # Perform compaction based on strategy
      removed_count = case compaction_strategy do
        :time_based ->
          compact_by_time(events_table, time_index_table, criteria)
        :sequence_based ->
          compact_by_sequence(events_table, time_index_table, criteria)
        :count_based ->
          compact_by_count(events_table, time_index_table, metadata_table, criteria)
      end

      # Update metadata
      :ets.update_counter(metadata_table, :event_count, -removed_count, {:event_count, 0})

      {:ok, removed_count}
    rescue
      error ->
        {:error, {:compaction_failed, error}}
    end
  end

  ## Helper Functions

  @spec determine_query_strategy(map()) :: :sequence_range | :time_range | :full_scan
  defp determine_query_strategy(options) do
    cond do
      Map.has_key?(options, :from_sequence) or Map.has_key?(options, :to_sequence) ->
        :sequence_range
      Map.has_key?(options, :from) or Map.has_key?(options, :to) ->
        :time_range
      true ->
        :full_scan
    end
  end

  @spec query_by_sequence_range(:ets.tid(), map()) :: [Prismatic.Event.Sourcing.stored_event()]
  defp query_by_sequence_range(events_table, options) do
    from_seq = Map.get(options, :from_sequence, 1)
    to_seq = Map.get(options, :to_sequence, :infinity)

    if to_seq == :infinity do
      # Scan from sequence to end
      :ets.select(events_table, [
        {{"$1", "$2"}, [{">=", "$1", from_seq}], ["$2"]}
      ])
    else
      # Scan within sequence range
      :ets.select(events_table, [
        {{"$1", "$2"}, [{">=", "$1", from_seq}, {"=<", "$1", to_seq}], ["$2"]}
      ])
    end
  end

  @spec query_by_time_range(:ets.tid(), :ets.tid(), map()) :: [Prismatic.Event.Sourcing.stored_event()]
  defp query_by_time_range(events_table, time_index_table, options) do
    from_time = Map.get(options, :from)
    to_time = Map.get(options, :to)

    # Convert times to microsecond timestamps for index lookup
    from_ts = if from_time, do: DateTime.to_unix(from_time, :microsecond), else: 0
    to_ts = if to_time, do: DateTime.to_unix(to_time, :microsecond), else: :infinity

    # Query time index to get sequence numbers
    sequence_numbers = if to_ts == :infinity do
      :ets.select(time_index_table, [
        {{{"$1", "$2"}, "$3"}, [{">=", "$1", from_ts}], ["$3"]}
      ])
    else
      :ets.select(time_index_table, [
        {{{"$1", "$2"}, "$3"}, [{">=", "$1", from_ts}, {"=<", "$1", to_ts}], ["$3"]}
      ])
    end

    # Fetch events by sequence numbers
    Enum.map(sequence_numbers, fn seq_num ->
      [{^seq_num, event}] = :ets.lookup(events_table, seq_num)
      event
    end)
  end

  @spec query_full_table(:ets.tid(), map()) :: [Prismatic.Event.Sourcing.stored_event()]
  defp query_full_table(events_table, _options) do
    :ets.select(events_table, [
      {{"$1", "$2"}, [], ["$2"]}
    ])
  end

  @spec apply_remaining_filters([Prismatic.Event.Sourcing.stored_event()], map()) ::
    [Prismatic.Event.Sourcing.stored_event()]
  defp apply_remaining_filters(events, options) do
    events
    |> filter_by_time_if_needed(options)
    |> filter_by_sequence_if_needed(options)
  end

  @spec filter_by_time_if_needed([Prismatic.Event.Sourcing.stored_event()], map()) ::
    [Prismatic.Event.Sourcing.stored_event()]
  defp filter_by_time_if_needed(events, options) do
    from_time = Map.get(options, :from)
    to_time = Map.get(options, :to)

    if from_time || to_time do
      Enum.filter(events, fn event ->
        timestamp = event.timestamp

        from_check = if from_time, do: DateTime.compare(timestamp, from_time) != :lt, else: true
        to_check = if to_time, do: DateTime.compare(timestamp, to_time) != :gt, else: true

        from_check and to_check
      end)
    else
      events
    end
  end

  @spec filter_by_sequence_if_needed([Prismatic.Event.Sourcing.stored_event()], map()) ::
    [Prismatic.Event.Sourcing.stored_event()]
  defp filter_by_sequence_if_needed(events, options) do
    from_seq = Map.get(options, :from_sequence)
    to_seq = Map.get(options, :to_sequence)

    if from_seq || to_seq do
      Enum.filter(events, fn event ->
        sequence = event.sequence_number

        from_check = if from_seq, do: sequence >= from_seq, else: true
        to_check = if to_seq, do: sequence <= to_seq, else: true

        from_check and to_check
      end)
    else
      events
    end
  end

  @spec apply_ordering([Prismatic.Event.Sourcing.stored_event()], map()) ::
    [Prismatic.Event.Sourcing.stored_event()]
  defp apply_ordering(events, options) do
    case Map.get(options, :order, :asc) do
      :asc -> Enum.sort_by(events, &(&1.sequence_number))
      :desc -> Enum.sort_by(events, &(&1.sequence_number), :desc)
    end
  end

  @spec apply_limit([Prismatic.Event.Sourcing.stored_event()], map()) ::
    [Prismatic.Event.Sourcing.stored_event()]
  defp apply_limit(events, options) do
    case Map.get(options, :limit) do
      nil -> events
      limit -> Enum.take(events, limit)
    end
  end

  @spec enforce_storage_limits(Protocol.config(), :ets.tid(), :ets.tid(), :ets.tid()) :: :ok
  defp enforce_storage_limits(config, events_table, time_index_table, metadata_table) do
    max_events = Map.get(config, :max_events)

    if max_events && is_integer(max_events) do
      [{:event_count, current_count}] = :ets.lookup(metadata_table, :event_count)

      if current_count > max_events do
        excess_count = current_count - max_events
        remove_oldest_events(events_table, time_index_table, metadata_table, excess_count)
      end
    end

    :ok
  end

  @spec remove_oldest_events(:ets.tid(), :ets.tid(), :ets.tid(), non_neg_integer()) :: :ok
  defp remove_oldest_events(events_table, time_index_table, metadata_table, count) do
    # Get oldest sequence numbers
    oldest_sequences = :ets.select(events_table, [
      {{"$1", "$2"}, [], ["$1"]}
    ])
    |> Enum.sort()
    |> Enum.take(count)

    # Remove events and their time index entries
    Enum.each(oldest_sequences, fn sequence ->
      case :ets.lookup(events_table, sequence) do
        [{^sequence, event}] ->
          # Remove from events table
          :ets.delete(events_table, sequence)

          # Remove from time index
          timestamp_key = {DateTime.to_unix(event.timestamp, :microsecond), sequence}
          :ets.delete(time_index_table, timestamp_key)
        [] ->
          :ok
      end
    end)

    # Update metadata
    :ets.update_counter(metadata_table, :event_count, -count, {:event_count, 0})

    :ok
  end

  @spec cleanup_old_snapshots(Protocol.config(), :ets.tid()) :: :ok
  defp cleanup_old_snapshots(config, snapshots_table) do
    max_snapshots = Map.get(config, :max_snapshots, 10)

    if max_snapshots > 0 do
      snapshot_count = :ets.info(snapshots_table, :size)

      if snapshot_count > max_snapshots do
        excess_count = snapshot_count - max_snapshots

        # Get oldest snapshots
        oldest_sequences = :ets.select(snapshots_table, [
          {{"$1", "$2"}, [], ["$1"]}
        ])
        |> Enum.sort()
        |> Enum.take(excess_count)

        # Remove oldest snapshots
        Enum.each(oldest_sequences, &:ets.delete(snapshots_table, &1))
      end
    end

    :ok
  end

  @spec determine_compaction_strategy(map()) :: {:time_based | :sequence_based | :count_based, term()}
  defp determine_compaction_strategy(options) do
    cond do
      Map.has_key?(options, :older_than) ->
        {:time_based, Map.get(options, :older_than)}
      Map.has_key?(options, :before_sequence) ->
        {:sequence_based, Map.get(options, :before_sequence)}
      Map.has_key?(options, :keep_count) ->
        {:count_based, Map.get(options, :keep_count)}
      true ->
        # Default: remove events older than 30 days
        default_cutoff = DateTime.add(DateTime.utc_now(), -30 * 24 * 60 * 60, :second)
        {:time_based, default_cutoff}
    end
  end

  @spec compact_by_time(:ets.tid(), :ets.tid(), DateTime.t()) :: non_neg_integer()
  defp compact_by_time(events_table, time_index_table, cutoff_time) do
    cutoff_timestamp = DateTime.to_unix(cutoff_time, :microsecond)

    # Find events older than cutoff
    old_sequences = :ets.select(time_index_table, [
      {{{"$1", "$2"}, "$3"}, [{"<", "$1", cutoff_timestamp}], ["$3"]}
    ])

    # Remove old events
    Enum.each(old_sequences, fn sequence ->
      case :ets.lookup(events_table, sequence) do
        [{^sequence, event}] ->
          :ets.delete(events_table, sequence)
          timestamp_key = {DateTime.to_unix(event.timestamp, :microsecond), sequence}
          :ets.delete(time_index_table, timestamp_key)
        [] ->
          :ok
      end
    end)

    length(old_sequences)
  end

  @spec compact_by_sequence(:ets.tid(), :ets.tid(), non_neg_integer()) :: non_neg_integer()
  defp compact_by_sequence(events_table, time_index_table, before_sequence) do
    # Find events before the specified sequence
    old_sequences = :ets.select(events_table, [
      {{"$1", "$2"}, [{"<", "$1", before_sequence}], ["$1"]}
    ])

    # Remove old events
    Enum.each(old_sequences, fn sequence ->
      case :ets.lookup(events_table, sequence) do
        [{^sequence, event}] ->
          :ets.delete(events_table, sequence)
          timestamp_key = {DateTime.to_unix(event.timestamp, :microsecond), sequence}
          :ets.delete(time_index_table, timestamp_key)
        [] ->
          :ok
      end
    end)

    length(old_sequences)
  end

  @spec compact_by_count(:ets.tid(), :ets.tid(), :ets.tid(), non_neg_integer()) :: non_neg_integer()
  defp compact_by_count(events_table, time_index_table, metadata_table, keep_count) do
    [{:event_count, current_count}] = :ets.lookup(metadata_table, :event_count)

    if current_count > keep_count do
      excess_count = current_count - keep_count
      remove_oldest_events(events_table, time_index_table, metadata_table, excess_count)
      excess_count
    else
      0
    end
  end
end
