defmodule Prismatic.Memory.Impl.TestBackend do
  @moduledoc """
  Test backend implementation for the Memory Protocol.

  This backend provides a simple in-memory implementation for testing
  and development purposes. It supports all memory protocol operations
  with configurable responses for testing error conditions.

  ## Features

  - **In-Memory Storage**: Simple ETS-based storage
  - **Configurable Responses**: Mock specific responses for testing
  - **Pattern Matching**: Basic wildcard search support
  - **Memory Type Isolation**: Separate storage per memory type
  - **Comprehensive Logging**: Detailed operation logging for debugging

  ## Configuration

  ```elixir
  config = %{
    backend_type: :test,
    name: :test_memory,
    responses: %{
      "error_key" => {:error, :storage_full},
      "timeout_key" => {:error, :timeout}
    },
    max_entries: 1000,
    ttl: nil
  }
  ```

  ## Usage Examples

  ### Basic Usage

      {:ok, config} = Memory.Protocol.create_config(:test, %{})
      {:ok, _} = Memory.Protocol.store(config, :working, "key", "value")
      {:ok, value} = Memory.Protocol.retrieve(config, :working, "key")

  ### Error Testing

      config = %{
        backend_type: :test,
        responses: %{
          "fail_key" => {:error, :storage_full}
        }
      }
      {:error, :storage_full} = Memory.Protocol.store(config, :working, "fail_key", "value")
  """

  @behaviour Prismatic.Memory.Protocol

  require Logger

  @typedoc "Test backend state"
  @type state :: %{
    table: :ets.tid(),
    config: map(),
    stats: map()
  }

  @doc """
  Stores data in the test backend.

  Checks for configured mock responses first, then stores in ETS table.
  """
  @impl true
  def store(config, memory_type, key, value) do
    Logger.debug("TestBackend.store: #{memory_type}/#{key}")

    # Check for mock responses
    case get_mock_response(config, key) do
      nil ->
        # Normal storage operation
        table = get_or_create_table(config)
        storage_key = {memory_type, key}

        # Check capacity limits
        case check_capacity(table, config) do
          :ok ->
            :ets.insert(table, {storage_key, value, System.monotonic_time(:millisecond)})
            update_stats(config, :store_success)
            {:ok, config}

          {:error, reason} ->
            update_stats(config, :store_error)
            {:error, reason}
        end

      mock_response ->
        Logger.debug("TestBackend: returning mock response for #{key}")
        update_stats(config, :mock_response)
        mock_response
    end
  end

  @doc """
  Retrieves data from the test backend.
  """
  @impl true
  def retrieve(config, memory_type, key) do
    Logger.debug("TestBackend.retrieve: #{memory_type}/#{key}")

    # Check for mock responses
    case get_mock_response(config, key) do
      nil ->
        table = get_or_create_table(config)
        storage_key = {memory_type, key}

        case :ets.lookup(table, storage_key) do
          [{^storage_key, value, _timestamp}] ->
            update_stats(config, :retrieve_success)
            {:ok, value}

          [] ->
            update_stats(config, :retrieve_not_found)
            {:error, :not_found}
        end

      mock_response ->
        Logger.debug("TestBackend: returning mock response for #{key}")
        update_stats(config, :mock_response)
        mock_response
    end
  end

  @doc """
  Consolidates working memory to long-term storage.

  In the test backend, this moves entries from :working to :semantic memory type.
  """
  @impl true
  def consolidate(config) do
    Logger.debug("TestBackend.consolidate")

    table = get_or_create_table(config)

    # Find all working memory entries
    working_pattern = {{:working, :'$1'}, :'$2', :'$3'}
    working_entries = :ets.match(table, working_pattern)

    # Move to semantic memory
    consolidated_count = Enum.reduce(working_entries, 0, fn [key, value, _timestamp], acc ->
      semantic_key = {:semantic, key}
      :ets.insert(table, {semantic_key, value, System.monotonic_time(:millisecond)})
      :ets.delete(table, {:working, key})
      acc + 1
    end)

    Logger.info("TestBackend: consolidated #{consolidated_count} entries")
    update_stats(config, :consolidate_success)
    {:ok, config}
  end

  @doc """
  Removes data from the test backend.
  """
  @impl true
  def forget(config, memory_type, key) do
    Logger.debug("TestBackend.forget: #{memory_type}/#{key}")

    # Check for mock responses
    case get_mock_response(config, key) do
      nil ->
        table = get_or_create_table(config)
        storage_key = {memory_type, key}

        case :ets.lookup(table, storage_key) do
          [{^storage_key, _value, _timestamp}] ->
            :ets.delete(table, storage_key)
            update_stats(config, :forget_success)
            {:ok, config}

          [] ->
            update_stats(config, :forget_not_found)
            {:error, :not_found}
        end

      mock_response ->
        Logger.debug("TestBackend: returning mock response for #{key}")
        update_stats(config, :mock_response)
        mock_response
    end
  end

  @doc """
  Searches for entries matching a pattern.

  Supports basic wildcard matching with '*' character.
  """
  @impl true
  def search(config, memory_type, pattern) do
    Logger.debug("TestBackend.search: #{memory_type}/#{pattern}")

    table = get_or_create_table(config)

    # Convert pattern to regex
    regex_pattern = pattern
    |> String.replace("*", ".*")
    |> then(&("^" <> &1 <> "$"))

    {:ok, regex} = Regex.compile(regex_pattern)

    # Search for matching entries
    search_pattern = {{memory_type, :'$1'}, :'$2', :_}
    all_entries = :ets.match(table, search_pattern)

    results = Enum.filter(all_entries, fn [key, _value] ->
      key_str = to_string(key)
      Regex.match?(regex, key_str)
    end)
    |> Enum.map(fn [key, value] -> {key, value} end)

    update_stats(config, :search_success)
    {:ok, results}
  end

  @doc """
  Validates the test backend configuration.
  """
  @impl true
  def validate_config(config) do
    required_fields = [:backend_type, :name]

    case check_required_fields(config, required_fields) do
      :ok ->
        if config.backend_type == :test do
          :ok
        else
          {:error, {:invalid_backend_type, config.backend_type}}
        end

      error ->
        error
    end
  end

  @doc """
  Performs a health check on the test backend.
  """
  @impl true
  def health_check(config) do
    Logger.debug("TestBackend.health_check")

    try do
      table = get_or_create_table(config)

      # Test basic operations
      test_key = {:health_check, "test_#{System.unique_integer()}"}
      test_value = "health_check_value"

      :ets.insert(table, {test_key, test_value, System.monotonic_time(:millisecond)})

      case :ets.lookup(table, test_key) do
        [{^test_key, ^test_value, _}] ->
          :ets.delete(table, test_key)
          update_stats(config, :health_check_success)
          :ok

        _ ->
          update_stats(config, :health_check_error)
          {:error, :health_check_failed}
      end
    rescue
      error ->
        Logger.error("TestBackend health check failed: #{inspect(error)}")
        update_stats(config, :health_check_error)
        {:error, {:health_check_exception, error}}
    end
  end

  @doc """
  Gets information about the test backend.
  """
  @impl true
  def get_backend_info(config) do
    table = get_or_create_table(config)
    entry_count = :ets.info(table, :size)
    memory_usage = :ets.info(table, :memory) * :erlang.system_info(:wordsize)

    info = %{
      backend_type: :test,
      name: config.name,
      max_entries: Map.get(config, :max_entries, :unlimited),
      current_entries: entry_count,
      memory_usage_bytes: memory_usage,
      supports_ttl: false,
      supports_search: true,
      supports_consolidation: true,
      stats: get_stats(config)
    }

    {:ok, info}
  end

  ## Private Implementation

  @spec get_or_create_table(map()) :: :ets.tid() | atom()
  defp get_or_create_table(config) do
    table_name = :"test_memory_#{config.name}"

    case :ets.whereis(table_name) do
      :undefined ->
        :ets.new(table_name, [:named_table, :public, :set])

      table ->
        table
    end
  end

  @spec get_mock_response(map(), term()) :: {:ok, term()} | {:error, term()} | nil
  defp get_mock_response(config, key) do
    responses = Map.get(config, :responses, %{})
    key_str = to_string(key)
    Map.get(responses, key_str)
  end

  @spec check_capacity(:ets.tid(), map()) :: :ok | {:error, :storage_full}
  defp check_capacity(table, config) do
    case Map.get(config, :max_entries) do
      nil -> :ok
      max_entries when is_integer(max_entries) ->
        current_size = :ets.info(table, :size)
        if current_size >= max_entries do
          {:error, :storage_full}
        else
          :ok
        end
      _ -> :ok
    end
  end

  @spec check_required_fields(map(), [atom()]) :: :ok | {:error, {:missing_field, atom()}}
  defp check_required_fields(config, required_fields) do
    missing_field = Enum.find(required_fields, fn field ->
      not Map.has_key?(config, field)
    end)

    case missing_field do
      nil -> :ok
      field -> {:error, {:missing_field, field}}
    end
  end

  @spec update_stats(
    map(),
    :consolidate_success
    | :forget_not_found
    | :forget_success
    | :health_check_error
    | :health_check_success
    | :mock_response
    | :retrieve_not_found
    | :retrieve_success
    | :search_success
    | :store_error
    | :store_success
  ) :: :ok
  defp update_stats(config, operation) do
    stats_table = get_stats_table(config)
    _counter = :ets.update_counter(stats_table, operation, 1, {operation, 0})
    :ok
  end

  @spec get_stats(map()) :: map()
  defp get_stats(config) do
    stats_table = get_stats_table(config)

    :ets.tab2list(stats_table)
    |> Enum.into(%{})
  end

  @spec get_stats_table(map()) :: :ets.tid() | atom()
  defp get_stats_table(config) do
    table_name = :"test_memory_stats_#{config.name}"

    case :ets.whereis(table_name) do
      :undefined ->
        :ets.new(table_name, [:named_table, :public, :set])

      table ->
        table
    end
  end
end
