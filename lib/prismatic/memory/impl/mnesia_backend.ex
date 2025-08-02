defmodule Prismatic.Memory.Impl.MnesiaBackend do
  @moduledoc """
  Mnesia backend implementation for persistent distributed storage.

  This backend uses Mnesia for long-term semantic and procedural memory with
  features like ACID transactions, distributed replication, and persistent
  storage. Ideal for data that needs to survive system restarts and be
  available across a distributed cluster.

  ## Features

  - **ACID Transactions**: Full transactional support with rollback
  - **Distributed Storage**: Automatic replication across cluster nodes
  - **Persistent Storage**: Data survives system restarts
  - **Schema Evolution**: Support for table schema changes
  - **Query Support**: Complex queries with QLC (Query List Comprehensions)
  - **Backup/Restore**: Built-in backup and restore capabilities

  ## Configuration

  ```elixir
  config = %{
    backend_type: :mnesia,
    name: :semantic_memory,
    table_name: :semantic_memory_table,
    disc_copies: [node()],      # Nodes with disk storage
    ram_copies: [],             # Nodes with RAM-only storage
    attributes: [:key, :memory_type, :value, :timestamp, :metadata],
    index: [:memory_type, :timestamp]
  }
  ```

  ## Table Schema

  The Mnesia backend uses a flexible schema:

  ```elixir
  {table_name, key, memory_type, value, timestamp, metadata}
  ```

  ## Usage Examples

  ### Basic Usage

      {:ok, config} = Memory.Protocol.create_config(:mnesia, %{
        name: :semantic_memory,
        table_name: :semantic_memory_table
      })

      {:ok, _} = Memory.Protocol.store(config, :semantic, "fact_123", fact_data)
      {:ok, data} = Memory.Protocol.retrieve(config, :semantic, "fact_123")

  ### With Metadata

      {:ok, config} = Memory.Protocol.create_config(:mnesia, %{
        name: :procedural_memory,
        table_name: :procedures,
        metadata: %{version: "1.0", source: "training"}
      })
  """

  @behaviour Prismatic.Memory.Protocol

  require Logger

  @default_attributes [:key, :memory_type, :value, :timestamp, :metadata]
  @default_table_name :prismatic_memory

  @doc """
  Stores data in the Mnesia backend.

  Uses transactions to ensure ACID properties and stores with metadata.
  """
  @impl true
  def store(config, memory_type, key, value) do
    Logger.debug("MnesiaBackend.store: #{memory_type}/#{key}")

    with {:ok, table_name} <- get_table_name(config),
         :ok <- ensure_table_exists(table_name, config) do

      timestamp = System.monotonic_time(:millisecond)
      metadata = Map.get(config, :metadata, %{})

      record = {table_name, key, memory_type, value, timestamp, metadata}

      transaction_result = :mnesia.transaction(fn ->
        :mnesia.write(record)
      end)

      case transaction_result do
        {:atomic, :ok} ->
          Logger.debug("MnesiaBackend: stored #{key} in #{table_name}")
          {:ok, config}

        {:aborted, reason} ->
          Logger.error("MnesiaBackend: store transaction aborted for #{key}: #{inspect(reason)}")
          {:error, {:transaction_aborted, reason}}
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Retrieves data from the Mnesia backend.
  """
  @impl true
  def retrieve(config, memory_type, key) do
    Logger.debug("MnesiaBackend.retrieve: #{memory_type}/#{key}")

    with {:ok, table_name} <- get_table_name(config),
         :ok <- ensure_table_exists(table_name, config) do

      transaction_result = :mnesia.transaction(fn ->
        retrieve_from_table(table_name, memory_type, key)
      end)

      handle_retrieve_result(transaction_result, key, table_name)
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Consolidates working memory to long-term storage.

  In Mnesia backend, this moves entries from working memory type
  to semantic memory type within the same table.
  """
  @impl true
  def consolidate(config) do
    Logger.debug("MnesiaBackend.consolidate")

    with {:ok, table_name} <- get_table_name(config),
         :ok <- ensure_table_exists(table_name, config) do

      transaction_result = :mnesia.transaction(fn ->
        # Find all working memory entries
        working_pattern = {table_name, :'$1', :working, :'$2', :'$3', :'$4'}
        working_records = :mnesia.match_object(working_pattern)

        # Move each record to semantic memory
        consolidated_count = Enum.reduce(working_records, 0, fn record, acc ->
          {^table_name, key, :working, value, _old_timestamp, metadata} = record

          # Delete old working memory record
          :mnesia.delete_object(record)

          # Create new semantic memory record
          new_timestamp = System.monotonic_time(:millisecond)
          semantic_record = {table_name, key, :semantic, value, new_timestamp, metadata}
          :mnesia.write(semantic_record)

          acc + 1
        end)

        consolidated_count
      end)

      case transaction_result do
        {:atomic, count} ->
          Logger.info("MnesiaBackend: consolidated #{count} entries")
          {:ok, config}

        {:aborted, reason} ->
          Logger.error("MnesiaBackend: consolidation transaction aborted: #{inspect(reason)}")
          {:error, {:consolidation_failed, reason}}
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Removes data from the Mnesia backend.
  """
  @impl true
  def forget(config, memory_type, key) do
    Logger.debug("MnesiaBackend.forget: #{memory_type}/#{key}")

    with {:ok, table_name} <- get_table_name(config),
         :ok <- ensure_table_exists(table_name, config) do

      transaction_result = :mnesia.transaction(fn ->
        delete_from_table(table_name, memory_type, key)
      end)

      handle_forget_result(transaction_result, key, table_name)
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Searches for entries matching a pattern.

  Uses Mnesia's pattern matching and QLC for efficient searches.
  """
  @impl true
  def search(config, memory_type, pattern) do
    Logger.debug("MnesiaBackend.search: #{memory_type}/#{pattern}")

    with {:ok, table_name} <- get_table_name(config),
         :ok <- ensure_table_exists(table_name, config) do

      mnesia_pattern = determine_search_pattern(table_name, memory_type, pattern)

      transaction_result = :mnesia.transaction(fn ->
        execute_search(mnesia_pattern, table_name, memory_type, pattern)
      end)

      handle_search_result(transaction_result, pattern)
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates the Mnesia backend configuration.
  """
  @impl true
  def validate_config(config) do
    required_fields = [:backend_type, :name]

    case check_required_fields(config, required_fields) do
      :ok ->
        if config.backend_type == :mnesia do
          validate_mnesia_specific_config(config)
        else
          {:error, {:invalid_backend_type, config.backend_type}}
        end

      error ->
        error
    end
  end

  @doc """
  Performs a health check on the Mnesia backend.
  """
  @impl true
  def health_check(config) do
    Logger.debug("MnesiaBackend.health_check")

    with {:ok, table_name} <- get_table_name(config),
         :ok <- ensure_table_exists(table_name, config) do

      test_key = "health_check_#{System.unique_integer()}"
      test_value = "health_check_value"

      transaction_result = :mnesia.transaction(fn ->
        # Test write
        record = {table_name, test_key, :working, test_value, System.monotonic_time(:millisecond), %{}}
        :mnesia.write(record)

        # Test read
        case :mnesia.read(table_name, test_key) do
          [{^table_name, ^test_key, :working, ^test_value, _, _}] ->
            # Test delete
            :mnesia.delete({table_name, test_key})
            :ok

          other ->
            Logger.error("MnesiaBackend: health check failed - unexpected read result: #{inspect(other)}")
            :error
        end
      end)

      case transaction_result do
        {:atomic, :ok} ->
          :ok

        {:atomic, :error} ->
          {:error, :health_check_failed}

        {:aborted, reason} ->
          Logger.error("MnesiaBackend: health check transaction aborted: #{inspect(reason)}")
          {:error, {:health_check_failed, reason}}
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets information about the Mnesia backend.
  """
  @impl true
  def get_backend_info(config) do
    {:ok, table_name} = get_table_name(config)

    try do
      table_info = case :mnesia.table_info(table_name, :all) do
        info when is_list(info) -> Enum.into(info, %{})
        _ -> %{}
      end

      info = %{
        backend_type: :mnesia,
        name: config.name,
        table_name: table_name,
        supports_ttl: false,
        supports_search: true,
        supports_consolidation: true,
        supports_transactions: true,
        supports_distribution: true,
        table_info: table_info,
        disc_copies: Map.get(config, :disc_copies, [node()]),
        ram_copies: Map.get(config, :ram_copies, []),
        attributes: Map.get(config, :attributes, @default_attributes)
      }

      {:ok, info}
    rescue
      error ->
        Logger.error("MnesiaBackend: failed to get backend info: #{inspect(error)}")
        {:error, {:backend_info_failed, error}}
    end
  end

  ## Private Implementation

  @spec retrieve_from_table(atom(), atom(), term()) :: {:ok, term()} | :not_found
  defp retrieve_from_table(table_name, memory_type, key) do
    case :mnesia.read(table_name, key) do
      [] ->
        :not_found

      [{^table_name, ^key, ^memory_type, value, _timestamp, _metadata}] ->
        {:ok, value}

      [{^table_name, ^key, other_type, _value, _timestamp, _metadata}] ->
        handle_type_mismatch(key, other_type, memory_type)

      records when is_list(records) ->
        find_matching_record(records, table_name, key, memory_type)
    end
  end

  @spec handle_type_mismatch(term(), atom(), atom()) :: :not_found
  defp handle_type_mismatch(key, other_type, expected_type) do
    Logger.warning("MnesiaBackend: key #{key} found but with different memory type #{other_type}, expected #{expected_type}")
    :not_found
  end

  @spec find_matching_record(list(), atom(), term(), atom()) :: {:ok, term()} | :not_found
  defp find_matching_record(records, table_name, key, memory_type) do
    case Enum.find(records, fn {_, _, type, _, _, _} -> type == memory_type end) do
      {^table_name, ^key, ^memory_type, value, _timestamp, _metadata} ->
        {:ok, value}

      nil ->
        :not_found
    end
  end

  @spec handle_retrieve_result(term(), term(), atom()) :: {:ok, term()} | {:error, term()}
  defp handle_retrieve_result(transaction_result, key, table_name) do
    case transaction_result do
      {:atomic, {:ok, value}} ->
        Logger.debug("MnesiaBackend: retrieved #{key} from #{table_name}")
        {:ok, value}

      {:atomic, :not_found} ->
        Logger.debug("MnesiaBackend: key #{key} not found in #{table_name}")
        {:error, :not_found}

      {:aborted, reason} ->
        Logger.error("MnesiaBackend: retrieve transaction aborted for #{key}: #{inspect(reason)}")
        {:error, {:transaction_aborted, reason}}
    end
  end

  @spec delete_from_table(atom(), atom(), term()) :: :ok | :not_found
  defp delete_from_table(table_name, memory_type, key) do
    case :mnesia.read(table_name, key) do
      [] ->
        :not_found

      records ->
        find_and_delete_record(records, memory_type)
    end
  end

  @spec find_and_delete_record(list(), atom()) :: :ok | :not_found
  defp find_and_delete_record(records, memory_type) do
    case Enum.find(records, fn {_, _, type, _, _, _} -> type == memory_type end) do
      nil ->
        :not_found

      record ->
        :mnesia.delete_object(record)
        :ok
    end
  end

  @spec handle_forget_result(term(), term(), atom()) :: {:ok, map()} | {:error, term()}
  defp handle_forget_result(transaction_result, key, table_name) do
    case transaction_result do
      {:atomic, :ok} ->
        Logger.debug("MnesiaBackend: deleted #{key} from #{table_name}")
        {:ok, %{}}

      {:atomic, :not_found} ->
        Logger.debug("MnesiaBackend: key #{key} not found for deletion")
        {:error, :not_found}

      {:aborted, reason} ->
        Logger.error("MnesiaBackend: delete transaction aborted for #{key}: #{inspect(reason)}")
        {:error, {:transaction_aborted, reason}}
    end
  end

  @spec determine_search_pattern(atom(), atom(), String.t()) :: :wildcard | tuple()
  defp determine_search_pattern(table_name, memory_type, pattern) do
    case String.contains?(pattern, "*") do
      true ->
        :wildcard

      false ->
        {table_name, pattern, memory_type, :'$1', :_, :_}
    end
  end

  @spec execute_search(:wildcard | tuple(), atom(), atom(), String.t()) :: [{term(), term()}]
  defp execute_search(:wildcard, table_name, memory_type, pattern) do
    search_with_wildcard(table_name, memory_type, pattern)
  end

  defp execute_search(exact_pattern, _table_name, _memory_type, _pattern) do
    matches = :mnesia.match_object(exact_pattern)
    Enum.map(matches, fn {_, key, _, value, _, _} -> {key, value} end)
  end

  @spec handle_search_result(term(), String.t()) :: {:ok, list()} | {:error, term()}
  defp handle_search_result(transaction_result, pattern) do
    case transaction_result do
      {:atomic, results} ->
        Logger.debug("MnesiaBackend: found #{length(results)} matches for pattern #{pattern}")
        {:ok, results}

      {:aborted, reason} ->
        Logger.error("MnesiaBackend: search transaction aborted: #{inspect(reason)}")
        {:error, {:search_failed, reason}}
    end
  end

  @spec get_table_name(map()) :: {:ok, atom()}
  defp get_table_name(config) do
    table_name = Map.get(config, :table_name, @default_table_name)
    {:ok, table_name}
  end

  @spec ensure_table_exists(atom(), map()) :: :ok | {:error, {:table_check_failed, %{:__exception__ => true, :__struct__ => atom(), atom() => term()}} | {:table_creation_failed, term()}}
  defp ensure_table_exists(table_name, config) do
    case :mnesia.table_info(table_name, :type) do
      {:aborted, {:no_exists, ^table_name, :type}} ->
        create_table(table_name, config)

      _type ->
        :ok
    end
  rescue
    error ->
      Logger.error("MnesiaBackend: error checking table existence: #{inspect(error)}")
      {:error, {:table_check_failed, error}}
  catch
    :exit, {:aborted, {:no_exists, ^table_name, :type}} ->
      create_table(table_name, config)
  end

  @spec create_table(atom(), map()) :: :ok | {:error, {:table_creation_failed, term()}}
  defp create_table(table_name, config) do
    attributes = Map.get(config, :attributes, @default_attributes)
    disc_copies = Map.get(config, :disc_copies, [node()])
    ram_copies = Map.get(config, :ram_copies, [])
    index = Map.get(config, :index, [:memory_type, :timestamp])

    table_options = [
      {:attributes, attributes},
      {:disc_copies, disc_copies},
      {:ram_copies, ram_copies},
      {:index, index},
      {:type, :bag}  # Allow multiple records with same key but different memory types
    ]

    case :mnesia.create_table(table_name, table_options) do
      {:atomic, :ok} ->
        Logger.info("MnesiaBackend: created table #{table_name}")
        :ok

      {:aborted, {:already_exists, ^table_name}} ->
        Logger.debug("MnesiaBackend: table #{table_name} already exists")
        :ok

      {:aborted, reason} ->
        Logger.error("MnesiaBackend: failed to create table #{table_name}: #{inspect(reason)}")
        {:error, {:table_creation_failed, reason}}
    end
  end

  @spec search_with_wildcard(atom(), atom(), String.t()) :: [{term(), term()}]
  defp search_with_wildcard(table_name, memory_type, pattern) do
    # Convert wildcard pattern to regex
    regex_pattern = pattern
    |> String.replace("*", ".*")
    |> then(&("^" <> &1 <> "$"))

    {:ok, regex} = Regex.compile(regex_pattern)

    # Use match_object for pattern matching instead of QLC for simplicity
    match_pattern = {table_name, :'$1', memory_type, :'$2', :_, :_}
    matches = :mnesia.match_object(match_pattern)

    # Filter by regex pattern
    Enum.filter(matches, fn {_, key, _, _value, _, _} ->
      Regex.match?(regex, to_string(key))
    end)
    |> Enum.map(fn {_, key, _, value, _, _} -> {key, value} end)
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

  @spec validate_mnesia_specific_config(map()) :: :ok | {:error, {:invalid_attributes, term()} | {:invalid_disc_copies, term()} | {:invalid_ram_copies, term()} | {:invalid_table_name, term()}}
  defp validate_mnesia_specific_config(config) do
    with :ok <- validate_table_name(config),
         :ok <- validate_attributes(config),
         :ok <- validate_disc_copies(config) do
      validate_ram_copies(config)
    end
  end

  @spec validate_table_name(map()) :: :ok | {:error, {:invalid_table_name, term()}}
  defp validate_table_name(config) do
    case Map.get(config, :table_name, @default_table_name) do
      name when is_atom(name) -> :ok
      name -> {:error, {:invalid_table_name, name}}
    end
  end

  @spec validate_attributes(map()) :: :ok | {:error, {:invalid_attributes, term()}}
  defp validate_attributes(config) do
    case Map.get(config, :attributes, @default_attributes) do
      attrs when is_list(attrs) ->
        if Enum.all?(attrs, &is_atom/1) do
          :ok
        else
          {:error, {:invalid_attributes, attrs}}
        end

      attrs ->
        {:error, {:invalid_attributes, attrs}}
    end
  end

  @spec validate_disc_copies(map()) :: :ok | {:error, {:invalid_disc_copies, term()}}
  defp validate_disc_copies(config) do
    case Map.get(config, :disc_copies, [node()]) do
      nodes when is_list(nodes) ->
        if Enum.all?(nodes, &is_atom/1) do
          :ok
        else
          {:error, {:invalid_disc_copies, nodes}}
        end

      nodes ->
        {:error, {:invalid_disc_copies, nodes}}
    end
  end

  @spec validate_ram_copies(map()) :: :ok | {:error, {:invalid_ram_copies, term()}}
  defp validate_ram_copies(config) do
    case Map.get(config, :ram_copies, []) do
      nodes when is_list(nodes) ->
        if Enum.all?(nodes, &is_atom/1) do
          :ok
        else
          {:error, {:invalid_ram_copies, nodes}}
        end

      nodes ->
        {:error, {:invalid_ram_copies, nodes}}
    end
  end
end
