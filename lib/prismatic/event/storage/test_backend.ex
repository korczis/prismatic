defmodule Prismatic.Event.Storage.TestBackend do
  @moduledoc """
  Test storage backend for Event Sourcing.

  This module provides a simple in-memory storage implementation for testing
  event sourcing functionality. It supports all storage operations with
  configurable responses for testing various scenarios.

  ## Features

  - **Configurable Responses**: Pre-configure responses for testing
  - **Event Tracking**: Track all stored events for verification
  - **Snapshot Support**: Basic snapshot storage and retrieval
  - **Query Support**: Simple event querying capabilities
  - **No Persistence**: All data is lost when process stops

  ## Usage

  Primarily used in tests and development environments where persistence
  is not required and predictable behavior is needed for testing.
  """

  @behaviour Prismatic.Event.Storage.Behaviour

  @type storage_state :: %{
    events: [Prismatic.Event.Sourcing.stored_event()],
    snapshots: [Prismatic.Event.Sourcing.snapshot()],
    last_sequence: non_neg_integer(),
    responses: map()
  }

  ## Storage Behaviour Implementation

  @impl true
  def init_storage(config) do
    # Initialize in-memory storage tables if needed
    storage_name = :"#{config.name}_test_storage"

    case :ets.whereis(storage_name) do
      :undefined ->
        :ets.new(storage_name, [:named_table, :public, :ordered_set])
        :ok
      _ ->
        :ok
    end
  end

  @impl true
  def store_event(config, stored_event) do
    storage_name = :"#{config.name}_test_storage"

    # Check for configured error responses
    case get_configured_response(config, :store_event) do
      nil ->
        :ets.insert(storage_name, {stored_event.sequence_number, stored_event})
        :ok
      response ->
        response
    end
  end

  @impl true
  def query_events(config, options) do
    storage_name = :"#{config.name}_test_storage"

    case get_configured_response(config, :query_events) do
      nil ->
        # Retrieve all events and apply filtering
        all_events = :ets.tab2list(storage_name)
        |> Enum.map(fn {_seq, event} -> event end)
        |> apply_query_filters(options)

        {:ok, all_events}
      response ->
        response
    end
  end

  @impl true
  def get_last_sequence_number(config) do
    storage_name = :"#{config.name}_test_storage"

    case :ets.last(storage_name) do
      :'$end_of_table' -> 0
      last_key -> last_key
    end
  end

  @impl true
  def store_snapshot(config, snapshot) do
    storage_name = :"#{config.name}_test_storage"
    snapshot_key = {:snapshot, snapshot.sequence_number}

    case get_configured_response(config, :store_snapshot) do
      nil ->
        :ets.insert(storage_name, {snapshot_key, snapshot})
        :ok
      response ->
        response
    end
  end

  @impl true
  def get_latest_snapshot(config, before_sequence) do
    storage_name = :"#{config.name}_test_storage"

    # Find the latest snapshot before the given sequence
    snapshots = :ets.select(storage_name, [
      {{{:snapshot, :'$1'}, :'$2'},
       [{:'<', :'$1', before_sequence}],
       [:'$2']}
    ])
    |> Enum.sort_by(&(&1.sequence_number), :desc)

    case snapshots do
      [latest | _] -> {:ok, latest}
      [] -> {:error, :no_snapshots}
    end
  end

  @impl true
  def compact_events(config, options) do
    storage_name = :"#{config.name}_test_storage"

    case get_configured_response(config, :compact_events) do
      nil ->
        # Simple compaction: remove events older than specified time
        cutoff_time = Map.get(options, :older_than, DateTime.add(DateTime.utc_now(), -86400, :second))

        events_to_remove = :ets.select(storage_name, [
          {{"$1", "$2"},
           [{:is_integer, "$1"}, {"<", {:map_get, :timestamp, {:map_get, :metadata, "$2"}}, cutoff_time}],
           ["$1"]}
        ])

        removed_count = length(events_to_remove)
        Enum.each(events_to_remove, &:ets.delete(storage_name, &1))

        {:ok, removed_count}
      response ->
        response
    end
  end

  ## Test Helper Functions

  @doc """
  Get all stored events for testing verification.
  """
  @spec get_all_events(Prismatic.Event.Protocol.config()) :: [Prismatic.Event.Sourcing.stored_event()]
  def get_all_events(config) do
    storage_name = :"#{config.name}_test_storage"

    :ets.tab2list(storage_name)
    |> Enum.filter(fn {key, _} -> is_integer(key) end)
    |> Enum.map(fn {_seq, event} -> event end)
    |> Enum.sort_by(&(&1.sequence_number))
  end

  @doc """
  Clear all stored data for testing.
  """
  @spec clear_storage(Prismatic.Event.Protocol.config()) :: :ok
  def clear_storage(config) do
    storage_name = :"#{config.name}_test_storage"
    :ets.delete_all_objects(storage_name)
    :ok
  end

  @doc """
  Configure specific responses for testing error conditions.
  """
  @spec configure_response(Prismatic.Event.Protocol.config(), atom(), term()) :: :ok
  def configure_response(config, operation, response) do
    responses_key = :"#{config.name}_test_responses"

    current_responses = case :ets.whereis(responses_key) do
      :undefined ->
        :ets.new(responses_key, [:named_table, :public, :set])
        %{}
      _ ->
        case :ets.lookup(responses_key, :responses) do
          [{:responses, responses}] -> responses
          [] -> %{}
        end
    end

    updated_responses = Map.put(current_responses, operation, response)
    :ets.insert(responses_key, {:responses, updated_responses})
    :ok
  end

  ## Private Implementation

  @spec get_configured_response(Prismatic.Event.Protocol.config(), atom()) :: term() | nil
  defp get_configured_response(config, operation) do
    responses_key = :"#{config.name}_test_responses"

    case :ets.whereis(responses_key) do
      :undefined -> nil
      _ ->
        case :ets.lookup(responses_key, :responses) do
          [{:responses, responses}] -> Map.get(responses, operation)
          [] -> nil
        end
    end
  end

  @spec apply_query_filters([Prismatic.Event.Sourcing.stored_event()], map()) ::
    [Prismatic.Event.Sourcing.stored_event()]
  defp apply_query_filters(events, options) do
    events
    |> filter_by_time_range(Map.get(options, :from), Map.get(options, :to))
    |> filter_by_sequence_range(Map.get(options, :from_sequence), Map.get(options, :to_sequence))
    |> maybe_limit(Map.get(options, :limit))
    |> maybe_order(Map.get(options, :order, :asc))
  end

  @spec filter_by_time_range([Prismatic.Event.Sourcing.stored_event()], DateTime.t() | nil, DateTime.t() | nil) ::
    [Prismatic.Event.Sourcing.stored_event()]
  defp filter_by_time_range(events, nil, nil), do: events
  defp filter_by_time_range(events, from_time, to_time) do
    Enum.filter(events, fn event ->
      timestamp = event.timestamp

      from_check = if from_time, do: DateTime.compare(timestamp, from_time) != :lt, else: true
      to_check = if to_time, do: DateTime.compare(timestamp, to_time) != :gt, else: true

      from_check and to_check
    end)
  end

  @spec filter_by_sequence_range([Prismatic.Event.Sourcing.stored_event()], non_neg_integer() | nil, non_neg_integer() | nil) ::
    [Prismatic.Event.Sourcing.stored_event()]
  defp filter_by_sequence_range(events, nil, nil), do: events
  defp filter_by_sequence_range(events, from_seq, to_seq) do
    Enum.filter(events, fn event ->
      sequence = event.sequence_number

      from_check = if from_seq, do: sequence >= from_seq, else: true
      to_check = if to_seq, do: sequence <= to_seq, else: true

      from_check and to_check
    end)
  end

  @spec maybe_limit([Prismatic.Event.Sourcing.stored_event()], pos_integer() | nil) ::
    [Prismatic.Event.Sourcing.stored_event()]
  defp maybe_limit(events, nil), do: events
  defp maybe_limit(events, limit), do: Enum.take(events, limit)

  @spec maybe_order([Prismatic.Event.Sourcing.stored_event()], :asc | :desc) ::
    [Prismatic.Event.Sourcing.stored_event()]
  defp maybe_order(events, :asc), do: Enum.sort_by(events, &(&1.sequence_number))
  defp maybe_order(events, :desc), do: Enum.sort_by(events, &(&1.sequence_number), :desc)
end
