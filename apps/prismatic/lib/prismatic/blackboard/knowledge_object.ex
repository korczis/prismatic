defmodule Prismatic.Blackboard.KnowledgeObject do
  @moduledoc """
  Knowledge Object structure for the Prismatic Blackboard System.

  A KnowledgeObject represents a unit of knowledge that can be stored, retrieved,
  and manipulated within the blackboard system. It follows the same patterns
  as the Event and Memory systems with comprehensive validation and helper utilities.

  ## Structure

  Each KnowledgeObject contains:

  - `id` - Unique identifier for the knowledge object
  - `category` - Category of knowledge (facts, goals, plans, etc.)
  - `content` - The actual knowledge data
  - `metadata` - Additional information about the knowledge
  - `created_at` - Timestamp when the object was created
  - `updated_at` - Timestamp when the object was last updated

  ## Knowledge Categories

  The system supports different categories of knowledge:

  - `:facts` - Factual information and assertions
  - `:goals` - Objectives and targets for agents
  - `:plans` - Action sequences and strategies
  - `:observations` - Sensory data and environmental information
  - `:hypotheses` - Tentative conclusions and theories
  - `:constraints` - Rules and limitations
  - `:resources` - Available tools and capabilities

  ## Usage Examples

  ### Creating Knowledge Objects

      # From a map
      knowledge_map = %{
        category: :facts,
        content: %{fact: "The sky is blue", confidence: 0.9},
        metadata: %{source: "agent_alice", timestamp: DateTime.utc_now()}
      }

      {:ok, knowledge_obj} = KnowledgeObject.new(knowledge_map)

      # Direct struct creation
      knowledge_obj = %KnowledgeObject{
        id: "fact_001",
        category: :facts,
        content: %{fact: "Water boils at 100°C"},
        metadata: %{source: "physics_database"},
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

  ### Validation

      iex> KnowledgeObject.validate(knowledge_obj)
      :ok

      iex> invalid_obj = %KnowledgeObject{category: :invalid}
      iex> KnowledgeObject.validate(invalid_obj)
      {:error, {:invalid_category, :invalid}}

  ### Updating Knowledge Objects

      iex> updated_obj = KnowledgeObject.update(knowledge_obj, %{
      ...>   content: %{fact: "Water boils at 100°C at sea level"},
      ...>   metadata: %{source: "updated_physics_database"}
      ...> })

  ## Metadata Structure

  The metadata map can contain any additional information:

      %{
        source: "agent_id",           # Source of the knowledge
        confidence: 0.0..1.0,         # Confidence level
        timestamp: DateTime.t(),      # When the knowledge was acquired
        tags: [String.t()],          # Categorical tags
        relations: [String.t()],     # Related knowledge IDs
        access_level: :public | :private | :restricted,
        expires_at: DateTime.t(),    # Optional expiration
        version: pos_integer()       # Version number
      }

  ## Serialization

  KnowledgeObjects can be serialized to/from maps for storage and transmission:

      iex> map = KnowledgeObject.to_map(knowledge_obj)
      iex> {:ok, restored_obj} = KnowledgeObject.from_map(map)

  """

  @enforce_keys [:category, :content]
  defstruct [
    :id,
    :category,
    :content,
    :metadata,
    :created_at,
    :updated_at
  ]

  @typedoc "Knowledge categories for organization"
  @type category :: :facts | :goals | :plans | :observations | :hypotheses | :constraints | :resources

  @typedoc "Unique knowledge identifier"
  @type knowledge_id :: String.t()

  @typedoc "Knowledge content - any structured data"
  @type content :: map() | list() | String.t() | number() | boolean()

  @typedoc "Knowledge metadata with optional fields"
  @type metadata :: %{
    optional(:source) => String.t(),
    optional(:confidence) => float(),
    optional(:timestamp) => DateTime.t(),
    optional(:tags) => [String.t()],
    optional(:relations) => [knowledge_id()],
    optional(:access_level) => :public | :private | :restricted,
    optional(:expires_at) => DateTime.t(),
    optional(:version) => pos_integer(),
    optional(atom()) => term()
  }

  @typedoc "KnowledgeObject struct type"
  @type t :: %__MODULE__{
    id: knowledge_id() | nil,
    category: category(),
    content: content(),
    metadata: metadata() | nil,
    created_at: DateTime.t() | nil,
    updated_at: DateTime.t() | nil
  }

  @valid_categories [:facts, :goals, :plans, :observations, :hypotheses, :constraints, :resources]

  ## Public API

  @doc """
  Create a new KnowledgeObject from a map or keyword list.

  Automatically generates an ID and timestamps if not provided.

  ## Parameters

  - `attrs` - Map or keyword list with knowledge attributes

  ## Returns

  - `{:ok, knowledge_object}` - Successfully created object
  - `{:error, reason}` - Creation failed

  ## Examples

      iex> {:ok, obj} = KnowledgeObject.new(%{
      ...>   category: :facts,
      ...>   content: %{fact: "test"}
      ...> })
      iex> obj.category
      :facts
      iex> is_binary(obj.id)
      true

      iex> KnowledgeObject.new(%{category: :invalid})
      {:error, {:invalid_category, :invalid}}
  """
  @spec new(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs_map = if is_list(attrs), do: Enum.into(attrs, %{}), else: attrs

    now = DateTime.utc_now()

    knowledge_obj = %__MODULE__{
      id: Map.get(attrs_map, :id) || generate_id(),
      category: Map.get(attrs_map, :category),
      content: Map.get(attrs_map, :content),
      metadata: Map.get(attrs_map, :metadata, %{}),
      created_at: Map.get(attrs_map, :created_at, now),
      updated_at: Map.get(attrs_map, :updated_at, now)
    }

    case validate(knowledge_obj) do
      :ok -> {:ok, knowledge_obj}
      {:error, reason} -> {:error, reason}
    end
  end

  def new(attrs) do
    {:error, {:invalid_attributes, attrs}}
  end

  @doc """
  Create a new KnowledgeObject from a map, raising on error.

  ## Parameters

  - `attrs` - Map or keyword list with knowledge attributes

  ## Returns

  - `knowledge_object` - Successfully created object

  ## Raises

  - `ArgumentError` - If creation fails

  ## Examples

      iex> obj = KnowledgeObject.new!(%{
      ...>   category: :facts,
      ...>   content: %{fact: "test"}
      ...> })
      iex> obj.category
      :facts
  """
  @spec new!(map() | keyword()) :: t()
  def new!(attrs) do
    case new(attrs) do
      {:ok, knowledge_obj} -> knowledge_obj
      {:error, reason} -> raise ArgumentError, "Failed to create KnowledgeObject: #{inspect(reason)}"
    end
  end

  @doc """
  Validate a KnowledgeObject structure.

  Checks that all required fields are present and valid.

  ## Parameters

  - `knowledge_obj` - KnowledgeObject to validate

  ## Returns

  - `:ok` - Object is valid
  - `{:error, reason}` - Object is invalid

  ## Examples

      iex> obj = %KnowledgeObject{category: :facts, content: %{test: "data"}}
      iex> KnowledgeObject.validate(obj)
      :ok

      iex> obj = %KnowledgeObject{category: :invalid, content: %{}}
      iex> KnowledgeObject.validate(obj)
      {:error, {:invalid_category, :invalid}}
  """
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{} = knowledge_obj) do
    with :ok <- validate_category(knowledge_obj.category),
         :ok <- validate_content(knowledge_obj.content),
         :ok <- validate_metadata(knowledge_obj.metadata),
         :ok <- validate_timestamps(knowledge_obj) do
      :ok
    end
  end

  def validate(obj) do
    {:error, {:invalid_knowledge_object, obj}}
  end

  @doc """
  Update a KnowledgeObject with new values.

  Automatically updates the `updated_at` timestamp.

  ## Parameters

  - `knowledge_obj` - KnowledgeObject to update
  - `updates` - Map of fields to update

  ## Returns

  - `{:ok, updated_knowledge_object}` - Successfully updated
  - `{:error, reason}` - Update failed

  ## Examples

      iex> obj = KnowledgeObject.new!(%{category: :facts, content: %{value: 1}})
      iex> {:ok, updated} = KnowledgeObject.update(obj, %{content: %{value: 2}})
      iex> updated.content.value
      2
      iex> updated.updated_at != obj.updated_at
      true
  """
  @spec update(t(), map()) :: {:ok, t()} | {:error, term()}
  def update(%__MODULE__{} = knowledge_obj, updates) when is_map(updates) do
    updated_obj = %{knowledge_obj |
      id: Map.get(updates, :id, knowledge_obj.id),
      category: Map.get(updates, :category, knowledge_obj.category),
      content: Map.get(updates, :content, knowledge_obj.content),
      metadata: merge_metadata(knowledge_obj.metadata, Map.get(updates, :metadata)),
      created_at: Map.get(updates, :created_at, knowledge_obj.created_at),
      updated_at: Map.get(updates, :updated_at, DateTime.utc_now())
    }

    case validate(updated_obj) do
      :ok -> {:ok, updated_obj}
      {:error, reason} -> {:error, reason}
    end
  end

  def update(obj, updates) do
    {:error, {:invalid_update, %{object: obj, updates: updates}}}
  end

  @doc """
  Convert a KnowledgeObject to a map for serialization.

  ## Parameters

  - `knowledge_obj` - KnowledgeObject to convert

  ## Returns

  - `map()` - Map representation

  ## Examples

      iex> obj = KnowledgeObject.new!(%{category: :facts, content: %{test: "data"}})
      iex> map = KnowledgeObject.to_map(obj)
      iex> map.category
      :facts
      iex> is_map(map)
      true
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = knowledge_obj) do
    %{
      id: knowledge_obj.id,
      category: knowledge_obj.category,
      content: knowledge_obj.content,
      metadata: knowledge_obj.metadata,
      created_at: knowledge_obj.created_at,
      updated_at: knowledge_obj.updated_at
    }
  end

  @doc """
  Create a KnowledgeObject from a map representation.

  ## Parameters

  - `map` - Map representation of a KnowledgeObject

  ## Returns

  - `{:ok, knowledge_object}` - Successfully created
  - `{:error, reason}` - Creation failed

  ## Examples

      iex> map = %{category: :facts, content: %{test: "data"}}
      iex> {:ok, obj} = KnowledgeObject.from_map(map)
      iex> obj.category
      :facts
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(map) when is_map(map) do
    new(map)
  end

  def from_map(obj) do
    {:error, {:invalid_map, obj}}
  end

  @doc """
  Check if a KnowledgeObject has expired based on metadata.

  ## Parameters

  - `knowledge_obj` - KnowledgeObject to check

  ## Returns

  - `boolean()` - True if expired, false otherwise

  ## Examples

      iex> obj = KnowledgeObject.new!(%{
      ...>   category: :facts,
      ...>   content: %{test: "data"},
      ...>   metadata: %{expires_at: DateTime.add(DateTime.utc_now(), -3600)}
      ...> })
      iex> KnowledgeObject.expired?(obj)
      true
  """
  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{metadata: %{expires_at: expires_at}}) when not is_nil(expires_at) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  def expired?(%__MODULE__{}), do: false

  @doc """
  Get the age of a KnowledgeObject in seconds.

  ## Parameters

  - `knowledge_obj` - KnowledgeObject to check

  ## Returns

  - `non_neg_integer()` - Age in seconds

  ## Examples

      iex> obj = KnowledgeObject.new!(%{category: :facts, content: %{test: "data"}})
      iex> age = KnowledgeObject.age_seconds(obj)
      iex> is_integer(age) and age >= 0
      true
  """
  @spec age_seconds(t()) :: non_neg_integer()
  def age_seconds(%__MODULE__{created_at: created_at}) when not is_nil(created_at) do
    DateTime.diff(DateTime.utc_now(), created_at, :second)
  end

  def age_seconds(%__MODULE__{}), do: 0

  @doc """
  List all valid knowledge categories.

  ## Returns

  - `[category()]` - List of valid categories

  ## Examples

      iex> categories = KnowledgeObject.valid_categories()
      iex> :facts in categories
      true
      iex> :goals in categories
      true
  """
  @spec valid_categories() :: [category()]
  def valid_categories, do: @valid_categories

  ## Private Implementation

  @spec validate_category(term()) :: :ok | {:error, {:invalid_category, term()}}
  defp validate_category(category) when category in @valid_categories, do: :ok
  defp validate_category(category), do: {:error, {:invalid_category, category}}

  @spec validate_content(term()) :: :ok | {:error, {:invalid_content, term()}}
  defp validate_content(nil), do: {:error, {:invalid_content, nil}}
  defp validate_content(_content), do: :ok

  @spec validate_metadata(term()) :: :ok | {:error, {:invalid_metadata, term()}}
  defp validate_metadata(nil), do: :ok
  defp validate_metadata(%{} = metadata) do
    # Validate specific metadata fields if present
    with :ok <- validate_confidence(Map.get(metadata, :confidence)),
         :ok <- validate_access_level(Map.get(metadata, :access_level)),
         :ok <- validate_expires_at(Map.get(metadata, :expires_at)) do
      :ok
    end
  end
  defp validate_metadata(metadata), do: {:error, {:invalid_metadata, metadata}}

  @spec validate_confidence(term()) :: :ok | {:error, {:invalid_confidence, term()}}
  defp validate_confidence(nil), do: :ok
  defp validate_confidence(confidence) when is_number(confidence) and confidence >= 0.0 and confidence <= 1.0, do: :ok
  defp validate_confidence(confidence), do: {:error, {:invalid_confidence, confidence}}

  @spec validate_access_level(term()) :: :ok | {:error, {:invalid_access_level, term()}}
  defp validate_access_level(nil), do: :ok
  defp validate_access_level(level) when level in [:public, :private, :restricted], do: :ok
  defp validate_access_level(level), do: {:error, {:invalid_access_level, level}}

  @spec validate_expires_at(term()) :: :ok | {:error, {:invalid_expires_at, term()}}
  defp validate_expires_at(nil), do: :ok
  defp validate_expires_at(%DateTime{}), do: :ok
  defp validate_expires_at(expires_at), do: {:error, {:invalid_expires_at, expires_at}}

  @spec validate_timestamps(t()) :: :ok | {:error, term()}
  defp validate_timestamps(%__MODULE__{created_at: nil}), do: {:error, {:missing_created_at}}
  defp validate_timestamps(%__MODULE__{updated_at: nil}), do: {:error, {:missing_updated_at}}
  defp validate_timestamps(%__MODULE__{created_at: %DateTime{}, updated_at: %DateTime{}}), do: :ok
  defp validate_timestamps(obj), do: {:error, {:invalid_timestamps, obj}}

  @spec merge_metadata(metadata() | nil, metadata() | nil) :: metadata()
  defp merge_metadata(nil, nil), do: %{}
  defp merge_metadata(existing, nil), do: existing || %{}
  defp merge_metadata(nil, new), do: new || %{}
  defp merge_metadata(existing, new), do: Map.merge(existing || %{}, new || %{})

  @spec generate_id() :: knowledge_id()
  defp generate_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
    |> then(&("knowledge_#{&1}"))
  end
end
