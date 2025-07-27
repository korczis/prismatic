defmodule Prismatic.Memory.Protocol do
  @moduledoc """
  Memory system interface protocol for the Prismatic system.

  This protocol defines the contract for memory operations across different
  memory types (working, episodic, semantic, procedural). It ensures consistent
  memory management and data integrity across all memory implementations.

  ## Status

  🚧 **PLACEHOLDER - PLANNED IMPLEMENTATION**

  This file is a placeholder created to resolve documentation links.
  The actual implementation is planned for Phase 1 of the Prismatic
  architecture development (see docs/architecture/README.md).

  ## Memory Types

  - `:working` - Short-term working memory for active processing
  - `:episodic` - Long-term memory for specific experiences and events
  - `:semantic` - Long-term memory for facts and general knowledge
  - `:procedural` - Long-term memory for skills and procedures

  ## Protocol Methods

  - `store/4` - Store data in specified memory type
  - `retrieve/3` - Retrieve data from memory
  - `consolidate/1` - Move working memory to long-term storage
  - `forget/3` - Remove data from memory
  - `search/3` - Search memory with patterns

  ## Implementation Notes

  When implementing this protocol, ensure:
  - Thread safety for concurrent memory operations
  - Proper memory type isolation
  - Efficient storage and retrieval mechanisms
  - Compliance with formal contracts defined in Prismatic.Contracts.Memory

  ## See Also

  - `docs/architecture/bulletproof-foundations.md` - Core architectural patterns
  - `docs/architecture/bulletproof-foundations-part2.md` - Memory protocol contracts
  """

  @memory_types [:working, :episodic, :semantic, :procedural]

  @doc """
  Store data in the specified memory type.

  ## Parameters

  - `memory` - The memory instance
  - `type` - Memory type (#{inspect(@memory_types)})
  - `key` - Storage key (string)
  - `value` - Data to store

  ## Returns

  - `{:ok, updated_memory}` - Successfully stored data
  - `{:error, reason}` - Storage failed
  """
  @spec store(term(), atom(), String.t(), term()) :: {:ok, term()} | {:error, term()}
  def store(memory, type, key, value)

  @doc """
  Retrieve data from memory.

  ## Parameters

  - `memory` - The memory instance
  - `type` - Memory type (#{inspect(@memory_types)})
  - `key` - Storage key (string)

  ## Returns

  - `{:ok, value}` - Successfully retrieved data
  - `{:error, :not_found}` - Key not found
  - `{:error, reason}` - Retrieval failed
  """
  @spec retrieve(term(), atom(), String.t()) :: {:ok, term()} | {:error, term()}
  def retrieve(memory, type, key)

  @doc """
  Consolidate working memory to long-term storage.

  This operation moves appropriate data from working memory to
  long-term memory types based on consolidation rules.

  ## Parameters

  - `memory` - The memory instance

  ## Returns

  - `{:ok, consolidated_memory}` - Successfully consolidated
  - `{:error, reason}` - Consolidation failed
  """
  @spec consolidate(term()) :: {:ok, term()} | {:error, term()}
  def consolidate(memory)

  @doc """
  Remove data from memory.

  ## Parameters

  - `memory` - The memory instance
  - `type` - Memory type (#{inspect(@memory_types)})
  - `key` - Storage key (string)

  ## Returns

  - `{:ok, updated_memory}` - Successfully removed data
  - `{:error, :not_found}` - Key not found
  - `{:error, reason}` - Removal failed
  """
  @spec forget(term(), atom(), String.t()) :: {:ok, term()} | {:error, term()}
  def forget(memory, type, key)

  @doc """
  Search memory with pattern matching.

  ## Parameters

  - `memory` - The memory instance
  - `type` - Memory type (#{inspect(@memory_types)})
  - `pattern` - Search pattern (string with wildcards)

  ## Returns

  - `{:ok, results}` - List of matching key-value pairs
  - `{:error, reason}` - Search failed
  """
  @spec search(term(), atom(), String.t()) :: {:ok, list()} | {:error, term()}
  def search(memory, type, pattern)
end
