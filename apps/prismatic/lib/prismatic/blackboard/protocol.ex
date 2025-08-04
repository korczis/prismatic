defmodule Prismatic.Blackboard.Protocol do
  @moduledoc """
  Blackboard system interface protocol for the Prismatic AI Agent Framework.

  This protocol defines the contract for blackboard operations across different
  backend implementations. It provides a unified interface for posting, reading,
  and managing knowledge objects in a shared coordination space for multi-agent
  systems with pattern matching, access control, and event integration.

  ## Architecture

  The Blackboard Protocol system follows a protocol-driven architecture with:

  - **Behavior Contract**: All backends implement the same interface
  - **Factory Pattern**: Centralized backend creation and configuration
  - **Knowledge Objects**: Structured representation of shared information
  - **Pattern Matching**: Advanced pattern-based knowledge querying
  - **Rule Engine**: Event-driven processing of knowledge changes
  - **Access Control**: Fine-grained permissions for agent access
  - **Event Integration**: Publishes blackboard changes as events
  - **Memory Integration**: Uses memory backends for persistence
  - **Fault Tolerance**: Circuit breakers and retry logic built-in

  ## Knowledge Categories

  The system supports different categories of knowledge:

  - `:facts` - Factual information and assertions
  - `:goals` - Objectives and targets for agents
  - `:plans` - Action sequences and strategies
  - `:observations` - Sensory data and environmental information
  - `:hypotheses` - Tentative conclusions and theories
  - `:constraints` - Rules and limitations
  - `:resources` - Available tools and capabilities

  ## Supported Backends

  - `:memory` - Uses existing memory system for persistence
  - `:distributed` - Distributed blackboard across nodes
  - `:test` - Test backend for development and testing

  ## Usage Examples

  ### Basic Usage

      # Create blackboard configuration
      {:ok, config} = Prismatic.Blackboard.Protocol.create_config(:memory, %{
        name: :agent_blackboard,
        memory_backend: :layered,
        enable_events: true,
        enable_rules: true
      })

      # Post knowledge to blackboard
      knowledge = %{
        id: "task_001",
        category: :goals,
        content: %{
          objective: "analyze_document",
          priority: :high,
          deadline: ~U[2024-01-01 12:00:00Z]
        },
        metadata: %{source: "agent_alice", confidence: 0.9}
      }

      {:ok, knowledge_id} = Prismatic.Blackboard.Protocol.post(config, knowledge)

      # Read knowledge from blackboard
      {:ok, retrieved} = Prismatic.Blackboard.Protocol.read(config, knowledge_id)

      # Query knowledge by pattern
      {:ok, results} = Prismatic.Blackboard.Protocol.query(config, %{
        category: :goals,
        pattern: %{priority: :high}
      })

  ### With Access Control

      # Post knowledge with access control
      {:ok, knowledge_id} = Prismatic.Blackboard.Protocol.post(config, knowledge, %{
        agent_id: "agent_alice",
        permissions: [:read, :write]
      })

      # Read with access control
      {:ok, retrieved} = Prismatic.Blackboard.Protocol.read(config, knowledge_id, %{
        agent_id: "agent_bob"
      })

  ## Configuration Structure

      %{
        backend_type: :memory | :distributed | :test,
        name: atom(),                    # Blackboard instance name
        timeout: integer(),              # Request timeout (ms)
        max_retries: integer(),          # Maximum retry attempts
        memory_backend: atom(),          # Underlying memory backend type
        enable_events: boolean(),        # Publish blackboard changes as events
        enable_rules: boolean(),         # Enable rule engine processing
        enable_access_control: boolean(), # Enable access control checks
        max_knowledge_objects: integer() | nil, # Maximum knowledge objects
        rule_engine_config: map(),       # Rule engine configuration
        access_control_config: map(),    # Access control configuration
        event_config: map()              # Event system configuration
      }

  ## Error Handling

  The blackboard system provides comprehensive error classification:

  - **Knowledge Errors**: `:invalid_knowledge`, `:knowledge_not_found`, `:duplicate_knowledge`
  - **Access Errors**: `:access_denied`, `:invalid_agent`, `:insufficient_permissions`
  - **Storage Errors**: `:storage_full`, `:write_failed`, `:read_failed`
  - **Pattern Errors**: `:invalid_pattern`, `:pattern_too_complex`
  - **Rule Errors**: `:rule_execution_failed`, `:invalid_rule`
  - **Integration**: `:memory_backend_error`, `:event_system_error`

  ## Telemetry Events

  The system emits telemetry events for monitoring:

  - `[:prismatic, :blackboard, :protocol, :post]` - Knowledge posting completion
  - `[:prismatic, :blackboard, :protocol, :read]` - Knowledge reading completion
  - `[:prismatic, :blackboard, :protocol, :query]` - Knowledge querying completion
  - `[:prismatic, :blackboard, :protocol, :rule_triggered]` - Rule execution events
  - `[:prismatic, :blackboard, :protocol, :access_check]` - Access control checks
  """

  alias Prismatic.Blackboard.{KnowledgeObject, AccessControl, RuleEngine}
  alias Prismatic.Memory.Protocol, as: MemoryProtocol
  alias Prismatic.Event.Protocol, as: EventProtocol

  @typedoc "Blackboard backend configuration map"
  @type config :: %{
    backend_type: backend_type(),
    name: atom(),
    timeout: pos_integer(),
    max_retries: non_neg_integer(),
    memory_backend: atom(),
    enable_events: boolean(),
    enable_rules: boolean(),
    enable_access_control: boolean(),
    max_knowledge_objects: pos_integer() | nil,
    rule_engine_config: map(),
    access_control_config: map(),
    event_config: map()
  }

  @typedoc "Supported backend types"
  @type backend_type :: :memory | :distributed | :test

  @typedoc "Knowledge categories for organization"
  @type knowledge_category :: :facts | :goals | :plans | :observations | :hypotheses | :constraints | :resources

  @typedoc "Unique knowledge object identifier"
  @type knowledge_id :: String.t()

  @typedoc "Agent identifier for access control"
  @type agent_id :: String.t()

  @typedoc "Knowledge query pattern"
  @type query_pattern :: %{
    optional(:category) => knowledge_category(),
    optional(:pattern) => map(),
    optional(:metadata) => map(),
    optional(:limit) => pos_integer(),
    optional(:order) => :asc | :desc
  }

  @typedoc "Knowledge query results"
  @type query_results :: [KnowledgeObject.t()]

  @typedoc "Access context for operations"
  @type access_context :: %{
    optional(:agent_id) => agent_id(),
    optional(:permissions) => [AccessControl.permission()],
    optional(:metadata) => map()
  }

  @typedoc "Backend information structure"
  @type backend_info :: %{
    backend_type: backend_type(),
    name: atom(),
    supports_persistence: boolean(),
    supports_events: boolean(),
    supports_rules: boolean(),
    supports_access_control: boolean(),
    max_knowledge_objects: pos_integer() | :unlimited,
    features: [atom()]
  }

  @knowledge_categories [:facts, :goals, :plans, :observations, :hypotheses, :constraints, :resources]

  @doc """
  Post knowledge to the blackboard.

  This is the primary function for adding knowledge objects to the blackboard.
  It handles validation, access control, persistence, event publishing, and
  rule engine triggering.

  ## Parameters

  - `config` - Blackboard configuration
  - `knowledge` - Knowledge object to post (can be map or KnowledgeObject struct)
  - `context` - Optional access context for permissions

  ## Returns

  - `{:ok, knowledge_id}` - Successfully posted knowledge
  - `{:error, reason}` - Posting failed with reason

  ## Examples

      iex> {:ok, config} = Prismatic.Blackboard.Protocol.create_config(:test, %{})
      iex> knowledge = %{category: :facts, content: %{fact: "sky is blue"}}
      iex> {:ok, knowledge_id} = Prismatic.Blackboard.Protocol.post(config, knowledge)
      iex> is_binary(knowledge_id)
      true
  """
  @callback post(config(), KnowledgeObject.t() | map(), access_context()) ::
    {:ok, knowledge_id()} | {:error, term()}

  @doc """
  Read knowledge from the blackboard.

  Retrieves a specific knowledge object by its ID with access control checks.

  ## Parameters

  - `config` - Blackboard configuration
  - `knowledge_id` - ID of knowledge to retrieve
  - `context` - Optional access context for permissions

  ## Returns

  - `{:ok, knowledge_object}` - Successfully retrieved knowledge
  - `{:error, :not_found}` - Knowledge not found
  - `{:error, reason}` - Retrieval failed

  ## Examples

      iex> {:ok, config} = Prismatic.Blackboard.Protocol.create_config(:test, %{})
      iex> knowledge = %{category: :facts, content: %{fact: "test"}}
      iex> {:ok, knowledge_id} = Prismatic.Blackboard.Protocol.post(config, knowledge)
      iex> {:ok, retrieved} = Prismatic.Blackboard.Protocol.read(config, knowledge_id)
      iex> retrieved.content.fact
      "test"
  """
  @callback read(config(), knowledge_id(), access_context()) ::
    {:ok, KnowledgeObject.t()} | {:error, term()}

  @doc """
  Update existing knowledge on the blackboard.

  Modifies an existing knowledge object with access control and event publishing.

  ## Parameters

  - `config` - Blackboard configuration
  - `knowledge_id` - ID of knowledge to update
  - `updates` - Map of fields to update
  - `context` - Optional access context for permissions

  ## Returns

  - `{:ok, updated_knowledge}` - Successfully updated knowledge
  - `{:error, reason}` - Update failed

  ## Examples

      iex> {:ok, config} = Prismatic.Blackboard.Protocol.create_config(:test, %{})
      iex> knowledge = %{category: :facts, content: %{value: 1}}
      iex> {:ok, knowledge_id} = Prismatic.Blackboard.Protocol.post(config, knowledge)
      iex> {:ok, updated} = Prismatic.Blackboard.Protocol.update(config, knowledge_id, %{content: %{value: 2}})
      iex> updated.content.value
      2
  """
  @callback update(config(), knowledge_id(), map(), access_context()) ::
    {:ok, KnowledgeObject.t()} | {:error, term()}

  @doc """
  Remove knowledge from the blackboard.

  Deletes a knowledge object with access control checks and event publishing.

  ## Parameters

  - `config` - Blackboard configuration
  - `knowledge_id` - ID of knowledge to remove
  - `context` - Optional access context for permissions

  ## Returns

  - `:ok` - Successfully removed knowledge
  - `{:error, reason}` - Removal failed

  ## Examples

      iex> {:ok, config} = Prismatic.Blackboard.Protocol.create_config(:test, %{})
      iex> knowledge = %{category: :facts, content: %{temp: "data"}}
      iex> {:ok, knowledge_id} = Prismatic.Blackboard.Protocol.post(config, knowledge)
      iex> :ok = Prismatic.Blackboard.Protocol.remove(config, knowledge_id)
      :ok
  """
  @callback remove(config(), knowledge_id(), access_context()) ::
    :ok | {:error, term()}

  @doc """
  Query knowledge using pattern matching.

  Searches for knowledge objects matching the given pattern and criteria.

  ## Parameters

  - `config` - Blackboard configuration
  - `pattern` - Query pattern with filters and options
  - `context` - Optional access context for permissions

  ## Returns

  - `{:ok, results}` - List of matching knowledge objects
  - `{:error, reason}` - Query failed

  ## Examples

      iex> {:ok, config} = Prismatic.Blackboard.Protocol.create_config(:test, %{})
      iex> knowledge = %{category: :goals, content: %{priority: :high}}
      iex> {:ok, _} = Prismatic.Blackboard.Protocol.post(config, knowledge)
      iex> {:ok, results} = Prismatic.Blackboard.Protocol.query(config, %{category: :goals})
      iex> length(results) >= 1
      true
  """
  @callback query(config(), query_pattern(), access_context()) ::
    {:ok, query_results()} | {:error, term()}

  @doc """
  Subscribe to blackboard changes matching a pattern.

  Registers for notifications when knowledge objects matching the pattern
  are added, updated, or removed.

  ## Parameters

  - `config` - Blackboard configuration
  - `pattern` - Pattern to match for notifications
  - `handler` - Function to call when changes occur
  - `context` - Optional access context for permissions

  ## Returns

  - `{:ok, subscription_id}` - Successfully subscribed
  - `{:error, reason}` - Subscription failed
  """
  @callback subscribe(config(), query_pattern(), function(), access_context()) ::
    {:ok, String.t()} | {:error, term()}

  @doc """
  Unsubscribe from blackboard changes.

  Removes a previously registered subscription.

  ## Parameters

  - `config` - Blackboard configuration
  - `subscription_id` - ID of subscription to remove

  ## Returns

  - `:ok` - Successfully unsubscribed
  - `{:error, reason}` - Unsubscription failed
  """
  @callback unsubscribe(config(), String.t()) :: :ok | {:error, term()}

  @doc """
  Add a rule to the rule engine.

  Registers a rule that will be triggered when matching knowledge changes occur.

  ## Parameters

  - `config` - Blackboard configuration
  - `rule` - Rule definition
  - `context` - Optional access context for permissions

  ## Returns

  - `{:ok, rule_id}` - Successfully added rule
  - `{:error, reason}` - Rule addition failed
  """
  @callback add_rule(config(), RuleEngine.rule(), access_context()) ::
    {:ok, String.t()} | {:error, term()}

  @doc """
  Remove a rule from the rule engine.

  Unregisters a previously added rule.

  ## Parameters

  - `config` - Blackboard configuration
  - `rule_id` - ID of rule to remove
  - `context` - Optional access context for permissions

  ## Returns

  - `:ok` - Successfully removed rule
  - `{:error, reason}` - Rule removal failed
  """
  @callback remove_rule(config(), String.t(), access_context()) :: :ok | {:error, term()}

  @doc """
  Validates the blackboard configuration.

  Checks that all required fields are present and have valid values.

  ## Parameters

  - `config` - Configuration to validate

  ## Returns

  - `:ok` - Configuration is valid
  - `{:error, reason}` - Configuration is invalid
  """
  @callback validate_config(config()) :: :ok | {:error, term()}

  @doc """
  Checks if the blackboard backend is healthy and available.

  Performs a lightweight health check to verify backend connectivity.

  ## Parameters

  - `config` - Blackboard configuration

  ## Returns

  - `:ok` - Backend is healthy
  - `{:error, reason}` - Backend is unavailable
  """
  @callback health_check(config()) :: :ok | {:error, term()}

  @doc """
  Retrieves information about the blackboard backend capabilities.

  Returns detailed information about the configured backend including
  capacity limits, supported features, and performance characteristics.

  ## Parameters

  - `config` - Blackboard configuration

  ## Returns

  - `{:ok, backend_info}` - Backend information
  - `{:error, reason}` - Failed to get backend info
  """
  @callback get_backend_info(config()) :: {:ok, backend_info()} | {:error, term()}

  ## Public API Functions

  @doc """
  Creates a new blackboard backend configuration.

  This function validates the backend type and creates a properly structured
  configuration map with defaults applied.

  ## Parameters

  - `backend_type` - Type of backend (`:memory`, `:distributed`, `:test`)
  - `options` - Backend-specific options

  ## Returns

  - `{:ok, config}` - Valid configuration
  - `{:error, reason}` - Invalid configuration

  ## Examples

      iex> {:ok, config} = Prismatic.Blackboard.Protocol.create_config(:test, %{})
      iex> config.backend_type
      :test
      iex> is_integer(config.timeout)
      true
  """
  @spec create_config(backend_type(), map()) :: {:ok, config()} | {:error, term()}
  def create_config(backend_type, options \\ %{}) do
    case validate_backend_type(backend_type) do
      :ok ->
        base_config = %{
          backend_type: backend_type,
          name: Map.get(options, :name, :"blackboard_#{backend_type}"),
          timeout: 30_000,
          max_retries: 3,
          memory_backend: :layered,
          enable_events: true,
          enable_rules: true,
          enable_access_control: false,
          max_knowledge_objects: nil,
          rule_engine_config: %{},
          access_control_config: %{},
          event_config: %{}
        }

        config = Map.merge(base_config, options)
        {:ok, config}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Posts knowledge using the specified blackboard configuration.

  ## Examples

      iex> {:ok, config} = Prismatic.Blackboard.Protocol.create_config(:test, %{})
      iex> knowledge = %{category: :facts, content: %{test: "value"}}
      iex> {:ok, knowledge_id} = Prismatic.Blackboard.Protocol.post(config, knowledge)
      iex> is_binary(knowledge_id)
      true
  """
  @spec post(config(), KnowledgeObject.t() | map(), access_context()) :: {:ok, knowledge_id()} | {:error, term()}
  def post(config, knowledge, context \\ %{}) do
    with :ok <- validate_config(config),
         {:ok, knowledge_obj} <- normalize_knowledge(knowledge),
         :ok <- validate_knowledge_object(knowledge_obj),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do
      backend_module.post(config, knowledge_obj, context)
    end
  end

  @doc """
  Reads knowledge using the specified blackboard configuration.

  ## Examples

      iex> {:ok, config} = Prismatic.Blackboard.Protocol.create_config(:test, %{})
      iex> knowledge = %{category: :facts, content: %{test: "value"}}
      iex> {:ok, knowledge_id} = Prismatic.Blackboard.Protocol.post(config, knowledge)
      iex> {:ok, retrieved} = Prismatic.Blackboard.Protocol.read(config, knowledge_id)
      iex> retrieved.content.test
      "value"
  """
  @spec read(config(), knowledge_id(), access_context()) :: {:ok, KnowledgeObject.t()} | {:error, term()}
  def read(config, knowledge_id, context \\ %{}) do
    with :ok <- validate_config(config),
         :ok <- validate_knowledge_id(knowledge_id),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do
      backend_module.read(config, knowledge_id, context)
    end
  end

  @doc """
  Updates knowledge using the specified blackboard configuration.

  ## Examples

      iex> {:ok, config} = Prismatic.Blackboard.Protocol.create_config(:test, %{})
      iex> knowledge = %{category: :facts, content: %{value: 1}}
      iex> {:ok, knowledge_id} = Prismatic.Blackboard.Protocol.post(config, knowledge)
      iex> {:ok, updated} = Prismatic.Blackboard.Protocol.update(config, knowledge_id, %{content: %{value: 2}})
      iex> updated.content.value
      2
  """
  @spec update(config(), knowledge_id(), map(), access_context()) :: {:ok, KnowledgeObject.t()} | {:error, term()}
  def update(config, knowledge_id, updates, context \\ %{}) do
    with :ok <- validate_config(config),
         :ok <- validate_knowledge_id(knowledge_id),
         :ok <- validate_updates(updates),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do
      backend_module.update(config, knowledge_id, updates, context)
    end
  end

  @doc """
  Removes knowledge using the specified blackboard configuration.

  ## Examples

      iex> {:ok, config} = Prismatic.Blackboard.Protocol.create_config(:test, %{})
      iex> knowledge = %{category: :facts, content: %{temp: "data"}}
      iex> {:ok, knowledge_id} = Prismatic.Blackboard.Protocol.post(config, knowledge)
      iex> :ok = Prismatic.Blackboard.Protocol.remove(config, knowledge_id)
      :ok
  """
  @spec remove(config(), knowledge_id(), access_context()) :: :ok | {:error, term()}
  def remove(config, knowledge_id, context \\ %{}) do
    with :ok <- validate_config(config),
         :ok <- validate_knowledge_id(knowledge_id),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do
      backend_module.remove(config, knowledge_id, context)
    end
  end

  @doc """
  Queries knowledge using the specified blackboard configuration.

  ## Examples

      iex> {:ok, config} = Prismatic.Blackboard.Protocol.create_config(:test, %{})
      iex> knowledge = %{category: :goals, content: %{priority: :high}}
      iex> {:ok, _} = Prismatic.Blackboard.Protocol.post(config, knowledge)
      iex> {:ok, results} = Prismatic.Blackboard.Protocol.query(config, %{category: :goals})
      iex> length(results) >= 1
      true
  """
  @spec query(config(), query_pattern(), access_context()) :: {:ok, query_results()} | {:error, term()}
  def query(config, pattern, context \\ %{}) do
    with :ok <- validate_config(config),
         :ok <- validate_query_pattern(pattern),
         {:ok, backend_module} <- get_backend_module(config.backend_type) do
      backend_module.query(config, pattern, context)
    end
  end

  @doc """
  Lists all available backend types.

  ## Returns

  List of supported backend atoms.

  ## Examples

      iex> backends = Prismatic.Blackboard.Protocol.available_backends()
      iex> :test in backends
      true
      iex> :memory in backends
      true
  """
  @spec available_backends() :: [:memory | :distributed | :test]
  def available_backends do
    [:memory, :distributed, :test]
  end

  @doc """
  Lists all supported knowledge categories.

  ## Returns

  List of supported knowledge category atoms.

  ## Examples

      iex> categories = Prismatic.Blackboard.Protocol.knowledge_categories()
      iex> :facts in categories
      true
      iex> :goals in categories
      true
  """
  @spec knowledge_categories() :: [:constraints | :facts | :goals | :hypotheses | :observations | :plans | :resources]
  def knowledge_categories do
    @knowledge_categories
  end

  ## Private Implementation

  @spec validate_backend_type(term()) :: :ok | {:error, {:unsupported_backend, term()}}
  defp validate_backend_type(backend_type) when backend_type in [:memory, :distributed, :test] do
    :ok
  end

  defp validate_backend_type(backend_type) do
    {:error, {:unsupported_backend, backend_type}}
  end

  @spec validate_config(config()) :: :ok | {:error, term()}
  defp validate_config(%{backend_type: backend_type} = config) when is_map(config) do
    validate_backend_type(backend_type)
  end

  defp validate_config(config) do
    {:error, {:invalid_config, config}}
  end

  @spec normalize_knowledge(KnowledgeObject.t() | map()) :: {:ok, KnowledgeObject.t()} | {:error, term()}
  defp normalize_knowledge(%KnowledgeObject{} = knowledge), do: {:ok, knowledge}

  defp normalize_knowledge(knowledge) when is_map(knowledge) do
    try do
      knowledge_obj = struct(KnowledgeObject, knowledge)
      {:ok, knowledge_obj}
    rescue
      ArgumentError -> {:error, {:invalid_knowledge_structure, knowledge}}
    end
  end

  defp normalize_knowledge(knowledge) do
    {:error, {:invalid_knowledge, knowledge}}
  end

  @spec validate_knowledge_object(KnowledgeObject.t()) :: :ok | {:error, term()}
  defp validate_knowledge_object(%KnowledgeObject{category: category}) when category in @knowledge_categories do
    :ok
  end

  defp validate_knowledge_object(%KnowledgeObject{category: category}) do
    {:error, {:invalid_category, category}}
  end

  defp validate_knowledge_object(knowledge) do
    {:error, {:invalid_knowledge_object, knowledge}}
  end

  @spec validate_knowledge_id(term()) :: :ok | {:error, {:invalid_knowledge_id, term()}}
  defp validate_knowledge_id(knowledge_id) when is_binary(knowledge_id) do
    :ok
  end

  defp validate_knowledge_id(knowledge_id) do
    {:error, {:invalid_knowledge_id, knowledge_id}}
  end

  @spec validate_updates(term()) :: :ok | {:error, {:invalid_updates, term()}}
  defp validate_updates(updates) when is_map(updates) do
    :ok
  end

  defp validate_updates(updates) do
    {:error, {:invalid_updates, updates}}
  end

  @spec validate_query_pattern(term()) :: :ok | {:error, {:invalid_pattern, term()}}
  defp validate_query_pattern(pattern) when is_map(pattern) do
    :ok
  end

  defp validate_query_pattern(pattern) do
    {:error, {:invalid_pattern, pattern}}
  end

  @spec get_backend_module(backend_type()) :: {:ok, module()} | {:error, term()}
  defp get_backend_module(:memory), do: {:ok, Prismatic.Blackboard.Impl.MemoryBackend}
  defp get_backend_module(:distributed), do: {:error, {:not_implemented, :distributed}}
  defp get_backend_module(:test), do: {:ok, Prismatic.Blackboard.Impl.TestBackend}
  defp get_backend_module(backend_type), do: {:error, {:unsupported_backend, backend_type}}
end
