defmodule Prismatic.Memory.Manager do
  @moduledoc """
  Memory Manager coordinates the multi-layered memory system.

  The MemoryManager acts as the primary interface for the memory system,
  orchestrating operations across different memory layers and providing
  a unified API for memory operations.

  ## Memory Layers

  The system supports four types of memory:
  - **Working Memory** - Short-term, high-speed cache (Cachex)
  - **Episodic Memory** - Medium-term distributed cache (Nebulex)
  - **Semantic Memory** - Long-term persistent storage (Mnesia)
  - **Procedural Memory** - Specialized storage for procedures and patterns

  ## Examples

      iex> {:ok, manager} = MemoryManager.start_link()
      iex> MemoryManager.store(manager, "key", %{data: "value"}, :working)
      :ok

      iex> MemoryManager.retrieve(manager, "key", :working)
      {:ok, %{data: "value"}}

  """

  use GenServer
  require Logger

  alias Prismatic.Memory.Impl.{CachexBackend, MnesiaBackend, NebulexBackend}
  alias Prismatic.Memory.Protocol

  @type memory_type :: :working | :episodic | :semantic | :procedural
  @type memory_key :: String.t()
  @type memory_value :: any()
  @type memory_metadata :: map()
  @type manager_state :: %{
    backends: %{memory_type() => module()},
    configs: %{memory_type() => map()}
  }

  @doc """
  Start the Memory Manager.

  ## Options
  - `:backends` - Map of memory types to backend modules
  - `:configs` - Map of memory types to backend configurations
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Store a value in the specified memory layer.

  ## Parameters
  - `manager` - Manager process or name
  - `key` - Memory key
  - `value` - Value to store
  - `memory_type` - Type of memory to use
  - `metadata` - Optional metadata (default: %{})

  ## Examples

      iex> MemoryManager.store(:memory_manager, "user:123", %{name: "Alice"}, :working)
      :ok

  """
  @spec store(GenServer.server(), memory_key(), memory_value(), memory_type(), memory_metadata()) ::
    :ok | {:error, any()}
  def store(manager, key, value, memory_type, metadata \\ %{}) do
    GenServer.call(manager, {:store, key, value, memory_type, metadata})
  end

  @doc """
  Retrieve a value from the specified memory layer.

  ## Parameters
  - `manager` - Manager process or name
  - `key` - Memory key
  - `memory_type` - Type of memory to search

  ## Examples

      iex> MemoryManager.retrieve(:memory_manager, "user:123", :working)
      {:ok, %{name: "Alice"}}

  """
  @spec retrieve(GenServer.server(), memory_key(), memory_type()) ::
    {:ok, memory_value()} | {:error, :not_found} | {:error, any()}
  def retrieve(manager, key, memory_type) do
    GenServer.call(manager, {:retrieve, key, memory_type})
  end

  @doc """
  Search across memory layers using a query.

  ## Parameters
  - `manager` - Manager process or name
  - `query` - Search query
  - `memory_types` - List of memory types to search (default: all)

  ## Examples

      iex> MemoryManager.search(:memory_manager, %{name: "Alice"}, [:working, :episodic])
      {:ok, [%{key: "user:123", value: %{name: "Alice"}, metadata: %{}}]}

  """
  @spec search(GenServer.server(), map(), [memory_type()]) ::
    {:ok, [Protocol.memory_entry()]} | {:error, any()}
  def search(manager, query, memory_types \\ [:working, :episodic, :semantic, :procedural]) do
    GenServer.call(manager, {:search, query, memory_types})
  end

  @doc """
  Forget (delete) a value from the specified memory layer.

  ## Parameters
  - `manager` - Manager process or name
  - `key` - Memory key
  - `memory_type` - Type of memory to delete from

  ## Examples

      iex> MemoryManager.forget(:memory_manager, "user:123", :working)
      :ok

  """
  @spec forget(GenServer.server(), memory_key(), memory_type()) :: :ok | {:error, any()}
  def forget(manager, key, memory_type) do
    GenServer.call(manager, {:forget, key, memory_type})
  end

  @doc """
  Consolidate memories across layers.

  This operation moves memories from faster, temporary layers to slower,
  more permanent layers based on access patterns and retention policies.

  ## Parameters
  - `manager` - Manager process or name
  - `memory_types` - List of memory types to consolidate (default: all)

  ## Examples

      iex> MemoryManager.consolidate(:memory_manager)
      :ok

  """
  @spec consolidate(GenServer.server(), [memory_type()]) :: :ok | {:error, any()}
  def consolidate(manager, memory_types \\ [:working, :episodic, :semantic, :procedural]) do
    GenServer.call(manager, {:consolidate, memory_types})
  end

  @doc """
  Get memory statistics for monitoring and debugging.

  ## Parameters
  - `manager` - Manager process or name

  ## Examples

      iex> MemoryManager.stats(:memory_manager)
      %{
        working: %{entries: 150, size_bytes: 1024000},
        episodic: %{entries: 500, size_bytes: 5120000},
        semantic: %{entries: 1000, size_bytes: 10240000}
      }

  """
  @spec stats(GenServer.server()) :: map()
  def stats(manager) do
    GenServer.call(manager, :stats)
  end

  # GenServer callbacks

  @impl GenServer
  def init(opts) do
    # Default backend configurations
    backends = Keyword.get(opts, :backends, default_backends())
    configs = Keyword.get(opts, :configs, default_configs())

    # Initialize backends
    case initialize_backends(backends, configs) do
      :ok ->
        state = %{
          backends: backends,
          configs: configs
        }

        Logger.info("Memory Manager started with backends: #{inspect(Map.keys(backends))}")
        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to initialize Memory Manager: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:store, key, value, memory_type, metadata}, _from, state) do
    case get_backend_config(state, memory_type) do
      {:ok, config} ->
        result = Protocol.store(config, key, value, metadata)
        {:reply, result, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:retrieve, key, memory_type}, _from, state) do
    case get_backend_config(state, memory_type) do
      {:ok, config} ->
        result = Protocol.retrieve(config, memory_type, key)
        {:reply, result, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:search, query, memory_types}, _from, state) do
    results =
      memory_types
      |> Enum.map(fn memory_type ->
        search_single_memory_type(state, memory_type, query)
      end)
      |> List.flatten()

    {:reply, {:ok, results}, state}
  end

  @impl GenServer
  def handle_call({:forget, key, memory_type}, _from, state) do
    case get_backend_config(state, memory_type) do
      {:ok, config} ->
        result = Protocol.forget(config, memory_type, key)
        {:reply, result, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:consolidate, memory_types}, _from, state) do
    results =
      memory_types
      |> Enum.map(fn memory_type ->
        case get_backend_config(state, memory_type) do
          {:ok, config} ->
            Protocol.consolidate(config)
          {:error, reason} ->
            {:error, reason}
        end
      end)

    # Return error if any consolidation failed
    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> {:reply, :ok, state}
      error -> {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call(:stats, _from, state) do
    stats =
      state.backends
      |> Enum.map(fn {memory_type, _backend} ->
        case get_backend_config(state, memory_type) do
          {:ok, _config} ->
            # Get basic stats - this would be implemented by each backend
            {memory_type, %{entries: 0, size_bytes: 0}}
          {:error, _} ->
            {memory_type, %{entries: 0, size_bytes: 0, error: true}}
        end
      end)
      |> Enum.into(%{})

    {:reply, stats, state}
  end

  # Private functions

  @spec default_backends() :: %{
    :episodic => Prismatic.Memory.Impl.NebulexBackend,
    :procedural => Prismatic.Memory.Impl.MnesiaBackend,
    :semantic => Prismatic.Memory.Impl.MnesiaBackend,
    :working => Prismatic.Memory.Impl.CachexBackend
  }
  defp default_backends do
    %{
      working: CachexBackend,
      episodic: NebulexBackend,
      semantic: MnesiaBackend,
      procedural: MnesiaBackend
    }
  end

  @spec default_configs() :: %{
    :episodic => %{
      :backend_type => :nebulex,
      :max_retries => 3,
      :max_size => 100_000,
      :name => :episodic_memory,
      :timeout => 30_000,
      :ttl => non_neg_integer()
    },
    :procedural => %{
      :backend_type => :mnesia,
      :max_retries => 3,
      :max_size => nil,
      :name => :procedural_memory,
      :timeout => 30_000,
      :ttl => nil
    },
    :semantic => %{
      :backend_type => :mnesia,
      :max_retries => 3,
      :max_size => nil,
      :name => :semantic_memory,
      :timeout => 30_000,
      :ttl => nil
    },
    :working => %{
      :backend_type => :cachex,
      :max_retries => 3,
      :max_size => 10_000,
      :name => :working_memory,
      :timeout => 30_000,
      :ttl => non_neg_integer()
    }
  }
  defp default_configs do
    %{
      working: %{
        backend_type: :cachex,
        name: :working_memory,
        timeout: 30_000,
        max_retries: 3,
        ttl: :timer.minutes(30),
        max_size: 10_000
      },
      episodic: %{
        backend_type: :nebulex,
        name: :episodic_memory,
        timeout: 30_000,
        max_retries: 3,
        ttl: :timer.hours(24),
        max_size: 100_000
      },
      semantic: %{
        backend_type: :mnesia,
        name: :semantic_memory,
        timeout: 30_000,
        max_retries: 3,
        ttl: nil,
        max_size: nil
      },
      procedural: %{
        backend_type: :mnesia,
        name: :procedural_memory,
        timeout: 30_000,
        max_retries: 3,
        ttl: nil,
        max_size: nil
      }
    }
  end

  @spec initialize_backends(%{memory_type() => module()}, %{memory_type() => Protocol.config()}) ::
    :ok | {:error, any()}
  defp initialize_backends(backends, configs) do
    # For now, just validate that all backends have configs
    missing_configs =
      backends
      |> Map.keys()
      |> Enum.reject(&Map.has_key?(configs, &1))

    case missing_configs do
      [] -> :ok
      missing -> {:error, {:missing_configs, missing}}
    end
  end

  @spec search_single_memory_type(manager_state(), memory_type(), map()) :: [Prismatic.Memory.Protocol.memory_entry()]
  defp search_single_memory_type(state, memory_type, query) do
    with {:ok, config} <- get_backend_config(state, memory_type),
         {:ok, entries} <- Protocol.search(config, memory_type, query) do
      entries
    else
      {:error, _} -> []
    end
  end

  @spec get_backend_config(manager_state(), memory_type()) ::
    {:ok, Protocol.config()} | {:error, :unknown_memory_type}
  defp get_backend_config(state, memory_type) do
    case Map.get(state.configs, memory_type) do
      nil -> {:error, :unknown_memory_type}
      config -> {:ok, config}
    end
  end
end
