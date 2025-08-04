defmodule Prismatic.Blackboard.AccessControl do
  @moduledoc """
  Access Control system for the Prismatic Blackboard System.

  This module provides fine-grained access control for blackboard operations,
  ensuring that agents can only perform operations they are authorized for.
  It follows the same patterns as the Event and Memory systems with comprehensive
  validation and policy enforcement.

  ## Permission Model

  The access control system uses a capability-based security model:

  - **Agents** are identified by unique agent IDs
  - **Permissions** define what operations an agent can perform
  - **Resources** are knowledge objects with access control metadata
  - **Policies** define rules for granting permissions

  ## Permission Types

  The system supports three levels of permissions:

  - `:read` - Can read knowledge objects
  - `:write` - Can create, update, and delete knowledge objects
  - `:admin` - Can modify access control settings and permissions

  ## Access Levels

  Knowledge objects can have different access levels:

  - `:public` - Readable by any agent
  - `:private` - Only accessible by the owner
  - `:restricted` - Access controlled by explicit permissions

  ## Usage Examples

  ### Basic Permission Checks

      # Check if agent can read a knowledge object
      context = %{agent_id: "agent_alice", permissions: [:read]}
      knowledge = %{metadata: %{access_level: :public}}

      case AccessControl.authorize(context, :read, knowledge) do
        :ok ->
          # Agent is authorized
          perform_read_operation()
        {:error, :access_denied} ->
          # Agent lacks permission
          handle_access_denied()
      end

  ### Agent Validation

      case AccessControl.validate_agent("agent_alice") do
        :ok ->
          # Agent ID is valid
          continue_operation()
        {:error, :invalid_agent} ->
          # Invalid agent ID
          handle_invalid_agent()
      end

  ### Permission Management

      # Grant permissions to an agent
      {:ok, updated_permissions} = AccessControl.grant_permission(
        "agent_alice",
        :write,
        "knowledge_123"
      )

      # Revoke permissions
      :ok = AccessControl.revoke_permission(
        "agent_alice",
        :write,
        "knowledge_123"
      )

  ## Configuration

  Access control can be configured with various policies:

      config = %{
        enable_access_control: true,
        default_access_level: :private,
        admin_agents: ["system_admin"],
        permission_inheritance: true,
        audit_enabled: true
      }

  ## Integration with Blackboard

  The access control system integrates seamlessly with blackboard operations:

      # Post knowledge with access control
      {:ok, knowledge_id} = Blackboard.Protocol.post(config, knowledge, %{
        agent_id: "agent_alice",
        permissions: [:read, :write]
      })

      # Read knowledge with access control validation
      {:ok, knowledge} = Blackboard.Protocol.read(config, knowledge_id, %{
        agent_id: "agent_bob"
      })

  ## Audit and Monitoring

  All access control decisions are logged for security auditing:

      # Access granted
      [:prismatic, :blackboard, :access_control, :granted]

      # Access denied
      [:prismatic, :blackboard, :access_control, :denied]

      # Permission modified
      [:prismatic, :blackboard, :access_control, :permission_changed]
  """

  require Logger

  alias Prismatic.Blackboard.KnowledgeObject

  @typedoc "Permission types for blackboard operations"
  @type permission :: :read | :write | :admin

  @typedoc "Access levels for knowledge objects"
  @type access_level :: :public | :private | :restricted

  @typedoc "Agent identifier for access control"
  @type agent_id :: String.t()

  @typedoc "Knowledge object identifier"
  @type knowledge_id :: String.t()

  @typedoc "Access control context"
  @type access_context :: %{
    required(:agent_id) => agent_id(),
    required(:permissions) => [permission()],
    optional(:metadata) => map(),
    optional(:timestamp) => DateTime.t()
  }

  @typedoc "Permission grant structure"
  @type permission_grant :: %{
    agent_id: agent_id(),
    permission: permission(),
    resource_id: knowledge_id() | :global,
    granted_by: agent_id(),
    granted_at: DateTime.t(),
    expires_at: DateTime.t() | nil
  }

  @typedoc "Access control configuration"
  @type config :: %{
    enable_access_control: boolean(),
    default_access_level: access_level(),
    admin_agents: [agent_id()],
    permission_inheritance: boolean(),
    audit_enabled: boolean(),
    permission_cache_ttl: pos_integer()
  }

  @valid_permissions [:read, :write, :admin]
  @valid_access_levels [:public, :private, :restricted]

  ## Public API

  @doc """
  Authorize an agent to perform an operation on a resource.

  This is the main authorization function that checks if an agent has
  the required permissions to perform a specific operation.

  ## Parameters

  - `context` - Access control context with agent ID and permissions
  - `operation` - Operation to authorize (`:read`, `:write`, `:admin`)
  - `resource` - Knowledge object or resource metadata

  ## Returns

  - `:ok` - Authorization granted
  - `{:error, :access_denied}` - Authorization denied
  - `{:error, reason}` - Authorization failed

  ## Examples

      iex> context = %{agent_id: "agent_alice", permissions: [:read]}
      iex> resource = %{metadata: %{access_level: :public}}
      iex> AccessControl.authorize(context, :read, resource)
      :ok

      iex> context = %{agent_id: "agent_bob", permissions: [:read]}
      iex> resource = %{metadata: %{access_level: :private, owner: "agent_alice"}}
      iex> AccessControl.authorize(context, :read, resource)
      {:error, :access_denied}
  """
  @spec authorize(access_context(), permission(), map() | KnowledgeObject.t()) :: :ok | {:error, term()}
  def authorize(context, operation, resource) do
    with :ok <- validate_context(context),
         :ok <- validate_permission(operation),
         :ok <- validate_resource(resource) do

      case perform_authorization(context, operation, resource) do
        :ok ->
          emit_audit_event(:granted, context, operation, resource)
          :ok

        {:error, reason} = error ->
          emit_audit_event(:denied, context, operation, resource, reason)
          error
      end
    end
  end

  @doc """
  Validate an agent ID format and existence.

  ## Parameters

  - `agent_id` - Agent identifier to validate

  ## Returns

  - `:ok` - Agent ID is valid
  - `{:error, :invalid_agent}` - Agent ID is invalid

  ## Examples

      iex> AccessControl.validate_agent("agent_alice")
      :ok

      iex> AccessControl.validate_agent("")
      {:error, :invalid_agent}

      iex> AccessControl.validate_agent(nil)
      {:error, :invalid_agent}
  """
  @spec validate_agent(term()) :: :ok | {:error, :invalid_agent}
  def validate_agent(agent_id) when is_binary(agent_id) and byte_size(agent_id) > 0 do
    if String.match?(agent_id, ~r/^[a-zA-Z0-9_-]+$/) do
      :ok
    else
      {:error, :invalid_agent}
    end
  end

  def validate_agent(_), do: {:error, :invalid_agent}

  @doc """
  Check if an agent has a specific permission.

  ## Parameters

  - `context` - Access control context
  - `permission` - Permission to check

  ## Returns

  - `boolean()` - True if agent has permission

  ## Examples

      iex> context = %{agent_id: "agent_alice", permissions: [:read, :write]}
      iex> AccessControl.has_permission?(context, :read)
      true

      iex> AccessControl.has_permission?(context, :admin)
      false
  """
  @spec has_permission?(access_context(), permission()) :: boolean()
  def has_permission?(%{permissions: permissions}, permission) when is_list(permissions) do
    permission in permissions
  end

  def has_permission?(_, _), do: false

  @doc """
  Check if an agent is an administrator.

  ## Parameters

  - `agent_id` - Agent identifier
  - `config` - Access control configuration (optional)

  ## Returns

  - `boolean()` - True if agent is admin

  ## Examples

      iex> config = %{admin_agents: ["system_admin"]}
      iex> AccessControl.is_admin?("system_admin", config)
      true

      iex> AccessControl.is_admin?("regular_agent", config)
      false
  """
  @spec is_admin?(agent_id(), config()) :: boolean()
  def is_admin?(agent_id, config \\ %{}) do
    admin_agents = Map.get(config, :admin_agents, [])
    agent_id in admin_agents
  end

  @doc """
  Grant a permission to an agent for a specific resource.

  ## Parameters

  - `agent_id` - Agent to grant permission to
  - `permission` - Permission to grant
  - `resource_id` - Resource identifier (or `:global`)
  - `granted_by` - Agent granting the permission (optional)
  - `options` - Additional options (optional)

  ## Returns

  - `{:ok, permission_grant}` - Permission granted successfully
  - `{:error, reason}` - Permission grant failed

  ## Examples

      iex> {:ok, grant} = AccessControl.grant_permission(
      ...>   "agent_alice",
      ...>   :read,
      ...>   "knowledge_123"
      ...> )
      iex> grant.agent_id
      "agent_alice"
      iex> grant.permission
      :read
  """
  @spec grant_permission(agent_id(), permission(), knowledge_id() | :global, agent_id(), map()) ::
    {:ok, permission_grant()} | {:error, term()}
  def grant_permission(agent_id, permission, resource_id, granted_by \\ "system", options \\ %{}) do
    with :ok <- validate_agent(agent_id),
         :ok <- validate_permission(permission) do

      grant = %{
        agent_id: agent_id,
        permission: permission,
        resource_id: resource_id,
        granted_by: granted_by,
        granted_at: DateTime.utc_now(),
        expires_at: Map.get(options, :expires_at)
      }

      # In a real implementation, this would be stored in a database
      # For now, we just return the grant structure
      emit_audit_event(:permission_granted, %{agent_id: granted_by}, permission, %{target_agent: agent_id, resource_id: resource_id})
      {:ok, grant}
    end
  end

  @doc """
  Revoke a permission from an agent for a specific resource.

  ## Parameters

  - `agent_id` - Agent to revoke permission from
  - `permission` - Permission to revoke
  - `resource_id` - Resource identifier (or `:global`)
  - `revoked_by` - Agent revoking the permission (optional)

  ## Returns

  - `:ok` - Permission revoked successfully
  - `{:error, reason}` - Permission revocation failed

  ## Examples

      iex> AccessControl.revoke_permission("agent_alice", :read, "knowledge_123")
      :ok
  """
  @spec revoke_permission(agent_id(), permission(), knowledge_id() | :global, agent_id()) ::
    :ok | {:error, term()}
  def revoke_permission(agent_id, permission, resource_id, revoked_by \\ "system") do
    with :ok <- validate_agent(agent_id),
         :ok <- validate_permission(permission) do

      # In a real implementation, this would remove from database
      emit_audit_event(:permission_revoked, %{agent_id: revoked_by}, permission, %{target_agent: agent_id, resource_id: resource_id})
      :ok
    end
  end

  @doc """
  Create a default access control configuration.

  ## Parameters

  - `options` - Configuration options

  ## Returns

  - `config()` - Access control configuration

  ## Examples

      iex> config = AccessControl.default_config()
      iex> config.enable_access_control
      true
      iex> config.default_access_level
      :private
  """
  @spec default_config(map()) :: config()
  def default_config(options \\ %{}) do
    %{
      enable_access_control: Map.get(options, :enable_access_control, true),
      default_access_level: Map.get(options, :default_access_level, :private),
      admin_agents: Map.get(options, :admin_agents, ["system_admin"]),
      permission_inheritance: Map.get(options, :permission_inheritance, false),
      audit_enabled: Map.get(options, :audit_enabled, true),
      permission_cache_ttl: Map.get(options, :permission_cache_ttl, :timer.minutes(30))
    }
  end

  @doc """
  Apply access control to a knowledge object.

  Sets appropriate access level and ownership metadata.

  ## Parameters

  - `knowledge_obj` - Knowledge object to secure
  - `context` - Access control context
  - `access_level` - Desired access level (optional)

  ## Returns

  - `{:ok, secured_knowledge_object}` - Object with access control applied
  - `{:error, reason}` - Failed to apply access control

  ## Examples

      iex> knowledge = %KnowledgeObject{category: :facts, content: %{test: "data"}}
      iex> context = %{agent_id: "agent_alice", permissions: [:write]}
      iex> {:ok, secured} = AccessControl.secure_knowledge_object(knowledge, context)
      iex> secured.metadata.owner
      "agent_alice"
  """
  @spec secure_knowledge_object(KnowledgeObject.t(), access_context(), access_level()) ::
    {:ok, KnowledgeObject.t()} | {:error, term()}
  def secure_knowledge_object(%KnowledgeObject{} = knowledge_obj, context, access_level \\ :private) do
    with :ok <- validate_context(context),
         :ok <- validate_access_level(access_level) do

      security_metadata = %{
        owner: context.agent_id,
        access_level: access_level,
        created_by: context.agent_id,
        access_control_version: 1
      }

      updated_metadata = Map.merge(knowledge_obj.metadata || %{}, security_metadata)

      {:ok, %{knowledge_obj | metadata: updated_metadata}}
    end
  end

  @doc """
  Get the effective permissions for an agent on a resource.

  ## Parameters

  - `agent_id` - Agent identifier
  - `resource_id` - Resource identifier
  - `config` - Access control configuration (optional)

  ## Returns

  - `{:ok, [permission()]}` - List of effective permissions
  - `{:error, reason}` - Failed to get permissions

  ## Examples

      iex> {:ok, permissions} = AccessControl.get_effective_permissions("agent_alice", "knowledge_123")
      iex> is_list(permissions)
      true
  """
  @spec get_effective_permissions(agent_id(), knowledge_id(), config()) ::
    {:ok, [permission()]} | {:error, term()}
  def get_effective_permissions(agent_id, resource_id, config \\ %{}) do
    with :ok <- validate_agent(agent_id) do
      # In a real implementation, this would query the permission store
      # For now, return basic permissions based on admin status
      permissions = if is_admin?(agent_id, config) do
        [:read, :write, :admin]
      else
        [:read]
      end

      {:ok, permissions}
    end
  end

  @doc """
  List all valid permission types.

  ## Returns

  - `[permission()]` - List of valid permissions

  ## Examples

      iex> permissions = AccessControl.valid_permissions()
      iex> :read in permissions
      true
      iex> :write in permissions
      true
  """
  @spec valid_permissions() :: [permission()]
  def valid_permissions, do: @valid_permissions

  @doc """
  List all valid access levels.

  ## Returns

  - `[access_level()]` - List of valid access levels

  ## Examples

      iex> levels = AccessControl.valid_access_levels()
      iex> :public in levels
      true
      iex> :private in levels
      true
  """
  @spec valid_access_levels() :: [access_level()]
  def valid_access_levels, do: @valid_access_levels

  ## Private Implementation

  @spec perform_authorization(access_context(), permission(), map()) :: :ok | {:error, term()}
  defp perform_authorization(context, operation, resource) do
    # Check if agent has the required permission
    if has_permission?(context, operation) do
      # Check resource-level access control
      case get_resource_access_level(resource) do
        :public ->
          # Public resources are readable by anyone with read permission
          if operation == :read do
            :ok
          else
            check_ownership_or_admin(context, resource)
          end

        :private ->
          # Private resources require ownership or admin
          check_ownership_or_admin(context, resource)

        :restricted ->
          # Restricted resources require explicit permissions
          check_explicit_permissions(context, operation, resource)

        _ ->
          # Default to private access
          check_ownership_or_admin(context, resource)
      end
    else
      {:error, :insufficient_permissions}
    end
  end

  @spec check_ownership_or_admin(access_context(), map()) :: :ok | {:error, term()}
  defp check_ownership_or_admin(context, resource) do
    owner = get_resource_owner(resource)

    cond do
      context.agent_id == owner -> :ok
      has_permission?(context, :admin) -> :ok
      true -> {:error, :access_denied}
    end
  end

  @spec check_explicit_permissions(access_context(), permission(), map()) :: :ok | {:error, term()}
  defp check_explicit_permissions(context, operation, _resource) do
    # In a real implementation, this would check a permission database
    # For now, only allow if agent has admin permission
    if has_permission?(context, :admin) do
      :ok
    else
      {:error, :access_denied}
    end
  end

  @spec get_resource_access_level(map()) :: access_level()
  defp get_resource_access_level(%{metadata: %{access_level: level}}) when level in @valid_access_levels do
    level
  end
  defp get_resource_access_level(%KnowledgeObject{metadata: %{access_level: level}}) when level in @valid_access_levels do
    level
  end
  defp get_resource_access_level(_), do: :private

  @spec get_resource_owner(map()) :: agent_id() | nil
  defp get_resource_owner(%{metadata: %{owner: owner}}) when is_binary(owner), do: owner
  defp get_resource_owner(%KnowledgeObject{metadata: %{owner: owner}}) when is_binary(owner), do: owner
  defp get_resource_owner(_), do: nil

  @spec validate_context(term()) :: :ok | {:error, term()}
  defp validate_context(%{agent_id: agent_id, permissions: permissions}) when is_binary(agent_id) and is_list(permissions) do
    with :ok <- validate_agent(agent_id),
         :ok <- validate_permissions_list(permissions) do
      :ok
    end
  end
  defp validate_context(context), do: {:error, {:invalid_context, context}}

  @spec validate_permission(term()) :: :ok | {:error, {:invalid_permission, term()}}
  defp validate_permission(permission) when permission in @valid_permissions, do: :ok
  defp validate_permission(permission), do: {:error, {:invalid_permission, permission}}

  @spec validate_permissions_list([term()]) :: :ok | {:error, term()}
  defp validate_permissions_list(permissions) when is_list(permissions) do
    case Enum.find(permissions, &(&1 not in @valid_permissions)) do
      nil -> :ok
      invalid -> {:error, {:invalid_permission, invalid}}
    end
  end
  defp validate_permissions_list(permissions), do: {:error, {:invalid_permissions_list, permissions}}

  @spec validate_access_level(term()) :: :ok | {:error, {:invalid_access_level, term()}}
  defp validate_access_level(level) when level in @valid_access_levels, do: :ok
  defp validate_access_level(level), do: {:error, {:invalid_access_level, level}}

  @spec validate_resource(term()) :: :ok | {:error, term()}
  defp validate_resource(%KnowledgeObject{}), do: :ok
  defp validate_resource(%{} = resource) when map_size(resource) > 0, do: :ok
  defp validate_resource(resource), do: {:error, {:invalid_resource, resource}}

  @spec emit_audit_event(atom(), access_context(), permission(), map(), term()) :: :ok
  defp emit_audit_event(event_type, context, operation, resource, reason \\ nil) do
    metadata = %{
      agent_id: Map.get(context, :agent_id),
      operation: operation,
      resource_type: get_resource_type(resource),
      reason: reason,
      timestamp: DateTime.utc_now()
    }

    :telemetry.execute(
      [:prismatic, :blackboard, :access_control, event_type],
      %{count: 1},
      metadata
    )
  end

  @spec get_resource_type(map()) :: String.t()
  defp get_resource_type(%KnowledgeObject{}), do: "knowledge_object"
  defp get_resource_type(%{}), do: "resource"
  defp get_resource_type(_), do: "unknown"
end
