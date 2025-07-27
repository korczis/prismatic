defmodule Prismatic.Agent.Protocol do
  @moduledoc """
  Core agent behavior protocol for the Prismatic system.

  This protocol defines the essential interface that all agent implementations
  must support. It provides a contract for agent message processing, state
  management, configuration updates, and serialization.

  ## Status

  🚧 **PLACEHOLDER - PLANNED IMPLEMENTATION**

  This file is a placeholder created to resolve documentation links.
  The actual implementation is planned for Phase 1 of the Prismatic
  architecture development (see docs/architecture/README.md).

  ## Protocol Methods

  - `process_message/3` - Process incoming messages with context
  - `get_state/1` - Retrieve current agent state
  - `update_config/2` - Update agent configuration
  - `serialize/1` - Serialize agent for persistence

  ## Implementation Notes

  When implementing this protocol, ensure:
  - Thread safety for concurrent message processing
  - Proper error handling and recovery
  - State consistency across operations
  - Compliance with the formal contracts defined in Prismatic.Contracts.Agent

  ## See Also

  - `docs/architecture/bulletproof-foundations.md` - Core architectural patterns
  - `docs/architecture/bulletproof-foundations-part2.md` - Protocol specifications
  """

  @doc """
  Process a message with the given context.

  ## Parameters

  - `agent` - The agent instance
  - `message` - The message string to process
  - `context` - Context map containing additional information

  ## Returns

  - `{:ok, response}` - Successful processing with response
  - `{:error, reason}` - Processing failed with reason
  """
  @spec process_message(term(), String.t(), map()) :: {:ok, String.t()} | {:error, term()}
  def process_message(agent, message, context)

  @doc """
  Get the current state of the agent.

  ## Parameters

  - `agent` - The agent instance

  ## Returns

  - `{:ok, state}` - Current agent state
  - `{:error, reason}` - Failed to retrieve state
  """
  @spec get_state(term()) :: {:ok, map()} | {:error, term()}
  def get_state(agent)

  @doc """
  Update the agent's configuration.

  ## Parameters

  - `agent` - The agent instance
  - `config` - New configuration map

  ## Returns

  - `{:ok, updated_agent}` - Agent with updated configuration
  - `{:error, reason}` - Configuration update failed
  """
  @spec update_config(term(), map()) :: {:ok, term()} | {:error, term()}
  def update_config(agent, config)

  @doc """
  Serialize the agent for persistence or transmission.

  ## Parameters

  - `agent` - The agent instance

  ## Returns

  - `{:ok, serialized_data}` - Serialized agent data
  - `{:error, reason}` - Serialization failed
  """
  @spec serialize(term()) :: {:ok, binary()} | {:error, term()}
  def serialize(agent)
end
