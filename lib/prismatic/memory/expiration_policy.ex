defmodule Prismatic.Memory.ExpirationPolicy do
  @moduledoc """
  Expiration policy management for memory systems.

  This module provides comprehensive TTL (Time-To-Live) and eviction policies
  for memory backends. It supports various expiration strategies and automatic
  cleanup mechanisms to maintain optimal memory usage.

  ## Expiration Strategies

  - **TTL-based**: Entries expire after a fixed time period
  - **LRU (Least Recently Used)**: Evict least recently accessed entries
  - **LFU (Least Frequently Used)**: Evict least frequently accessed entries
  - **Size-based**: Evict entries when memory limit is reached
  - **Custom**: User-defined expiration logic

  ## Examples

      # Create TTL policy
      policy = ExpirationPolicy.create_ttl_policy(:timer.minutes(30))

      # Check if entry should expire
      ExpirationPolicy.should_expire?(policy, entry_metadata)
      #=> true

      # Apply eviction policy
      {:ok, evicted_keys} = ExpirationPolicy.apply_eviction(policy, memory_state)

  """

  require Logger

  @type policy_type :: :ttl | :lru | :lfu | :size_based | :custom
  @type ttl_duration :: pos_integer() | :infinity
  @type max_size :: pos_integer() | :infinity
  @type priority :: non_neg_integer()
  @type timestamp :: integer()

  @type policy :: %{
    type: policy_type(),
    ttl: ttl_duration(),
    max_size: max_size(),
    priority_threshold: priority(),
    custom_function: (any() -> boolean()) | nil,
    cleanup_interval: pos_integer()
  }

  @type entry_metadata :: %{
    created_at: timestamp(),
    accessed_at: timestamp(),
    access_count: non_neg_integer(),
    size_bytes: non_neg_integer(),
    priority: priority(),
    custom_data: map()
  }

  @type memory_entry :: %{
    key: String.t(),
    value: any(),
    metadata: entry_metadata()
  }

  @type eviction_result :: {:ok, [String.t()]} | {:error, any()}

  @doc """
  Creates a TTL-based expiration policy.

  ## Parameters
  - `ttl` - Time-to-live in milliseconds or `:infinity`

  ## Examples

      iex> policy = ExpirationPolicy.create_ttl_policy(:timer.minutes(30))
      iex> policy.type
      :ttl
      iex> policy.ttl
      1800000

  """
  @spec create_ttl_policy(ttl_duration()) :: policy()
  def create_ttl_policy(ttl) do
    %{
      type: :ttl,
      ttl: ttl,
      max_size: :infinity,
      priority_threshold: 0,
      custom_function: nil,
      cleanup_interval: :timer.minutes(5)
    }
  end

  @doc """
  Creates an LRU (Least Recently Used) expiration policy.

  ## Parameters
  - `max_size` - Maximum number of entries to keep

  ## Examples

      iex> policy = ExpirationPolicy.create_lru_policy(1000)
      iex> policy.type
      :lru
      iex> policy.max_size
      1000

  """
  @spec create_lru_policy(max_size()) :: policy()
  def create_lru_policy(max_size) do
    %{
      type: :lru,
      ttl: :infinity,
      max_size: max_size,
      priority_threshold: 0,
      custom_function: nil,
      cleanup_interval: :timer.minutes(10)
    }
  end

  @doc """
  Creates an LFU (Least Frequently Used) expiration policy.

  ## Parameters
  - `max_size` - Maximum number of entries to keep

  ## Examples

      iex> policy = ExpirationPolicy.create_lfu_policy(1000)
      iex> policy.type
      :lfu
      iex> policy.max_size
      1000

  """
  @spec create_lfu_policy(max_size()) :: policy()
  def create_lfu_policy(max_size) do
    %{
      type: :lfu,
      ttl: :infinity,
      max_size: max_size,
      priority_threshold: 0,
      custom_function: nil,
      cleanup_interval: :timer.minutes(10)
    }
  end

  @doc """
  Creates a size-based expiration policy.

  ## Parameters
  - `max_size` - Maximum number of entries
  - `ttl` - Optional TTL for entries

  ## Examples

      iex> policy = ExpirationPolicy.create_size_policy(5000, :timer.hours(1))
      iex> policy.type
      :size_based
      iex> policy.max_size
      5000

  """
  @spec create_size_policy(max_size(), ttl_duration()) :: policy()
  def create_size_policy(max_size, ttl \\ :infinity) do
    %{
      type: :size_based,
      ttl: ttl,
      max_size: max_size,
      priority_threshold: 0,
      custom_function: nil,
      cleanup_interval: :timer.minutes(15)
    }
  end

  @doc """
  Creates a custom expiration policy.

  ## Parameters
  - `custom_function` - Function that determines if entry should expire
  - `cleanup_interval` - How often to run cleanup

  ## Examples

      custom_fn = fn metadata ->
        metadata.access_count < 5 and
        System.monotonic_time(:millisecond) - metadata.created_at > :timer.hours(1)
      end

      policy = ExpirationPolicy.create_custom_policy(custom_fn, :timer.minutes(5))

  """
  @spec create_custom_policy((entry_metadata() -> boolean()), pos_integer()) :: policy()
  def create_custom_policy(custom_function, cleanup_interval \\ :timer.minutes(5)) do
    %{
      type: :custom,
      ttl: :infinity,
      max_size: :infinity,
      priority_threshold: 0,
      custom_function: custom_function,
      cleanup_interval: cleanup_interval
    }
  end

  @doc """
  Checks if an entry should expire based on the policy.

  ## Parameters
  - `policy` - Expiration policy
  - `metadata` - Entry metadata

  ## Examples

      iex> policy = ExpirationPolicy.create_ttl_policy(:timer.minutes(30))
      iex> old_metadata = %{created_at: System.monotonic_time(:millisecond) - :timer.hours(1)}
      iex> ExpirationPolicy.should_expire?(policy, old_metadata)
      true

  """
  @spec should_expire?(policy(), entry_metadata()) :: boolean()
  def should_expire?(policy, metadata) do
    case policy.type do
      :ttl ->
        should_expire_ttl?(policy.ttl, metadata.created_at)

      :lru ->
        # LRU expiration is handled during eviction, not per-entry
        false

      :lfu ->
        # LFU expiration is handled during eviction, not per-entry
        false

      :size_based ->
        should_expire_ttl?(policy.ttl, metadata.created_at)

      :custom ->
        if policy.custom_function do
          policy.custom_function.(metadata)
        else
          false
        end
    end
  end

  @doc """
  Applies eviction policy to a collection of memory entries.

  Returns a list of keys that should be evicted to maintain policy compliance.

  ## Parameters
  - `policy` - Expiration policy
  - `entries` - List of memory entries

  ## Examples

      entries = [
        %{key: "key1", metadata: %{access_count: 1, accessed_at: old_time}},
        %{key: "key2", metadata: %{access_count: 10, accessed_at: recent_time}}
      ]

      {:ok, evicted} = ExpirationPolicy.apply_eviction(lru_policy, entries)

  """
  @spec apply_eviction(policy(), [memory_entry()]) :: eviction_result()
  def apply_eviction(policy, entries) when is_list(entries) do
    evicted_keys =
      case policy.type do
        :ttl ->
          apply_ttl_eviction(policy, entries)

        :lru ->
          apply_lru_eviction(policy, entries)

        :lfu ->
          apply_lfu_eviction(policy, entries)

        :size_based ->
          apply_size_based_eviction(policy, entries)

        :custom ->
          apply_custom_eviction(policy, entries)
      end

    Logger.debug("Evicted #{length(evicted_keys)} entries using #{policy.type} policy")
    {:ok, evicted_keys}

  rescue
    error ->
      Logger.error("Eviction failed: #{inspect(error)}")
      {:error, {:eviction_failed, error}}
  end

  @doc """
  Creates entry metadata for a new memory entry.

  ## Parameters
  - `size_bytes` - Size of the entry in bytes
  - `priority` - Priority level (higher = more important)
  - `custom_data` - Additional custom metadata

  ## Examples

      iex> metadata = ExpirationPolicy.create_entry_metadata(1024, 5, %{category: "user_data"})
      iex> metadata.size_bytes
      1024
      iex> metadata.priority
      5

  """
  @spec create_entry_metadata(non_neg_integer(), priority(), map()) :: entry_metadata()
  def create_entry_metadata(size_bytes, priority \\ 0, custom_data \\ %{}) do
    current_time = System.monotonic_time(:millisecond)

    %{
      created_at: current_time,
      accessed_at: current_time,
      access_count: 1,
      size_bytes: size_bytes,
      priority: priority,
      custom_data: custom_data
    }
  end

  @doc """
  Updates entry metadata when an entry is accessed.

  ## Parameters
  - `metadata` - Current entry metadata

  ## Examples

      iex> old_metadata = ExpirationPolicy.create_entry_metadata(1024)
      iex> new_metadata = ExpirationPolicy.update_access(old_metadata)
      iex> new_metadata.access_count
      2

  """
  @spec update_access(entry_metadata()) :: entry_metadata()
  def update_access(metadata) do
    %{metadata |
      accessed_at: System.monotonic_time(:millisecond),
      access_count: metadata.access_count + 1
    }
  end

  @doc """
  Calculates the total size of entries in bytes.

  ## Parameters
  - `entries` - List of memory entries

  ## Examples

      iex> entries = [
      ...>   %{metadata: %{size_bytes: 1024}},
      ...>   %{metadata: %{size_bytes: 2048}}
      ...> ]
      iex> ExpirationPolicy.calculate_total_size(entries)
      3072

  """
  @spec calculate_total_size([memory_entry()]) :: non_neg_integer() | float()
  def calculate_total_size(entries) do
    entries
    |> Enum.map(& &1.metadata.size_bytes)
    |> Enum.sum()
  end

  # Private functions

  @spec should_expire_ttl?(ttl_duration(), timestamp()) :: boolean()
  defp should_expire_ttl?(:infinity, _created_at), do: false
  defp should_expire_ttl?(ttl, created_at) do
    current_time = System.monotonic_time(:millisecond)
    current_time - created_at > ttl
  end

  @spec apply_ttl_eviction(policy(), [memory_entry()]) :: [String.t()]
  defp apply_ttl_eviction(policy, entries) do
    entries
    |> Enum.filter(fn entry ->
      should_expire_ttl?(policy.ttl, entry.metadata.created_at)
    end)
    |> Enum.map(& &1.key)
  end

  @spec apply_lru_eviction(policy(), [memory_entry()]) :: [String.t()]
  defp apply_lru_eviction(policy, entries) do
    if length(entries) > policy.max_size do
      excess_count = length(entries) - policy.max_size

      entries
      |> Enum.sort_by(& &1.metadata.accessed_at, :asc)
      |> Enum.take(excess_count)
      |> Enum.map(& &1.key)
    else
      []
    end
  end

  @spec apply_lfu_eviction(policy(), [memory_entry()]) :: [String.t()]
  defp apply_lfu_eviction(policy, entries) do
    if length(entries) > policy.max_size do
      excess_count = length(entries) - policy.max_size

      entries
      |> Enum.sort_by(& &1.metadata.access_count, :asc)
      |> Enum.take(excess_count)
      |> Enum.map(& &1.key)
    else
      []
    end
  end

  @spec apply_size_based_eviction(policy(), [memory_entry()]) :: [String.t()]
  defp apply_size_based_eviction(policy, entries) do
    # First apply TTL if configured
    ttl_evicted = apply_ttl_eviction(policy, entries)
    remaining_entries = Enum.reject(entries, fn entry -> entry.key in ttl_evicted end)

    # Then apply size-based eviction
    if length(remaining_entries) > policy.max_size do
      excess_count = length(remaining_entries) - policy.max_size

      size_evicted =
        remaining_entries
        |> Enum.sort_by(fn entry ->
          # Sort by priority (desc) then by access time (asc)
          {-entry.metadata.priority, entry.metadata.accessed_at}
        end)
        |> Enum.take(-excess_count)  # Take from the end (lowest priority, oldest access)
        |> Enum.map(& &1.key)

      ttl_evicted ++ size_evicted
    else
      ttl_evicted
    end
  end

  @spec apply_custom_eviction(policy(), [memory_entry()]) :: [String.t()]
  defp apply_custom_eviction(policy, entries) do
    if policy.custom_function do
      entries
      |> Enum.filter(fn entry ->
        policy.custom_function.(entry.metadata)
      end)
      |> Enum.map(& &1.key)
    else
      []
    end
  end
end
