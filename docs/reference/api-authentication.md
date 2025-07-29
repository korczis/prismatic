# API Authentication

Comprehensive reference for authentication and authorization mechanisms in the Prismatic API, including token management, permission systems, and security best practices.

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > [Reference](README.md) > API Authentication

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to reference index
- **🏠 [Documentation Home](../README.md)** - Main documentation index
- **🔍 [Search Documentation](glossary.md)** - Find terms and concepts

### Related Documentation

- [API Endpoints](api-endpoints.md) - Complete API endpoint reference
- [Security Guidelines](../guides/security-guidelines.md) - Security implementation best practices
- [ADR-0003: Security Model](../architecture/adr-0003-security-model.md) - Security architecture decisions
- [System Diagrams](../architecture/system-diagrams.md) - Authentication flow diagrams
- [Database Schema](database-schema.md) - User and permission data models
<!-- NAV_END -->

## Overview

The Prismatic API uses a multi-layered authentication and authorization system designed to provide secure access while maintaining performance and usability. This document provides comprehensive technical details for implementing and using the authentication system.

## Authentication Methods

### JWT Bearer Token Authentication

#### Overview
Primary authentication method for API access using JSON Web Tokens (JWT) with RS256 signing.

#### Token Structure
```json
{
  "header": {
    "alg": "RS256",
    "typ": "JWT",
    "kid": "prismatic-key-1"
  },
  "payload": {
    "sub": "user_123456",
    "iss": "https://api.prismatic.example.com",
    "aud": "prismatic-api",
    "exp": 1642234800,
    "iat": 1642231200,
    "jti": "token_unique_id",
    "scope": "read write",
    "role": "user",
    "org_id": "org_789"
  }
}
```

#### Token Claims Reference
- `sub` (subject) - User identifier
- `iss` (issuer) - API issuer URL
- `aud` (audience) - API audience identifier
- `exp` (expiration) - Token expiration timestamp
- `iat` (issued at) - Token issuance timestamp
- `jti` (JWT ID) - Unique token identifier for revocation
- `scope` - Space-separated list of granted scopes
- `role` - User's primary role
- `org_id` - Organization identifier (for multi-tenant access)

### Session-Based Authentication

#### Overview
Used for web interface interactions with server-side session management.

#### Session Configuration
```elixir
# Session configuration
config :prismatic_web, PrismaticWeb.Endpoint,
  session: [
    store: :cookie,
    key: "_prismatic_key",
    signing_salt: "secure_signing_salt",
    encryption_salt: "secure_encryption_salt",
    max_age: 86400,  # 24 hours
    secure: true,
    http_only: true,
    same_site: "Lax"
  ]
```

#### Session Data Structure
```elixir
# Session data stored server-side
%{
  "user_id" => "123456",
  "role" => "user",
  "org_id" => "org_789",
  "last_activity" => ~U[2024-01-15 10:30:00Z],
  "csrf_token" => "secure_csrf_token",
  "mfa_verified" => true
}
```

## Authentication Flows

### Login Flow

#### Standard Login
```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "secure_password",
  "remember_me": true
}
```

**Success Response:**
```json
{
  "data": {
    "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refresh_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
    "token_type": "Bearer",
    "expires_in": 3600,
    "scope": "read write",
    "user": {
      "id": "123456",
      "email": "user@example.com",
      "role": "user",
      "org_id": "org_789"
    }
  }
}
```

**Error Response:**
```json
{
  "errors": [
    {
      "status": "401",
      "code": "INVALID_CREDENTIALS",
      "title": "Authentication Failed",
      "detail": "Invalid email or password"
    }
  ]
}
```

#### Multi-Factor Authentication Flow
```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "secure_password"
}
```

**MFA Required Response:**
```json
{
  "data": {
    "mfa_required": true,
    "mfa_token": "temp_mfa_token_123",
    "available_methods": ["totp", "sms"],
    "expires_in": 300
  }
}
```

**MFA Verification:**
```http
POST /api/auth/mfa/verify
Content-Type: application/json

{
  "mfa_token": "temp_mfa_token_123",
  "method": "totp",
  "code": "123456"
}
```

### Token Refresh Flow

#### Refresh Access Token
```http
POST /api/auth/refresh
Content-Type: application/json

{
  "refresh_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Success Response:**
```json
{
  "data": {
    "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
    "token_type": "Bearer",
    "expires_in": 3600,
    "scope": "read write"
  }
}
```

### Logout Flow

#### Token Revocation
```http
DELETE /api/auth/logout
Authorization: Bearer <access_token>
```

**Response:**
```http
HTTP/1.1 204 No Content
```

## Authorization System

### Role-Based Access Control (RBAC)

#### System Roles
```elixir
# Role hierarchy and permissions
@roles %{
  "super_admin" => %{
    level: 100,
    permissions: ["*"],
    description: "Full system access"
  },
  "org_admin" => %{
    level: 80,
    permissions: ["manage:org", "manage:users", "read:*", "write:*"],
    description: "Organization administrator"
  },
  "editor" => %{
    level: 60,
    permissions: ["read:*", "write:posts", "write:comments"],
    description: "Content editor"
  },
  "user" => %{
    level: 20,
    permissions: ["read:own", "write:own"],
    description: "Regular user"
  },
  "viewer" => %{
    level: 10,
    permissions: ["read:assigned"],
    description: "Read-only access"
  }
}
```

#### Custom Permissions
```elixir
# Permission format: action:resource:scope
# Examples:
# - "read:post:own"           # Read own posts
# - "write:post:org"          # Write posts in organization
# - "delete:user:all"         # Delete any user
# - "manage:billing:org"      # Manage organization billing

defmodule Prismatic.Permissions do
  @permissions [
    # User permissions
    "read:user:own",
    "read:user:org",
    "read:user:all",
    "write:user:own",
    "write:user:org", 
    "delete:user:org",
    "delete:user:all",
    
    # Post permissions
    "read:post:public",
    "read:post:own",
    "read:post:org",
    "write:post:own",
    "write:post:org",
    "publish:post:own",
    "publish:post:org",
    "delete:post:own",
    "delete:post:org",
    
    # Administrative permissions
    "manage:org:own",
    "manage:billing:org",
    "manage:settings:org",
    "view:analytics:org",
    "manage:integrations:org"
  ]
end
```

### Scope-Based Authorization

#### API Scopes
```elixir
# OAuth 2.0 style scopes for API access
@scopes %{
  "read" => "Read access to user's data",
  "write" => "Write access to user's data", 
  "admin" => "Administrative access",
  "profile" => "Access to user profile information",
  "posts" => "Access to posts and content",
  "analytics" => "Access to analytics data",
  "billing" => "Access to billing information"
}
```

#### Scope Validation
```elixir
# Scope checking in API endpoints
defmodule PrismaticWeb.Auth.ScopeValidator do
  def validate_scope(token, required_scope) do
    with {:ok, claims} <- verify_token(token),
         scopes <- get_scopes(claims),
         true <- required_scope in scopes do
      :ok
    else
      false -> {:error, :insufficient_scope}
      error -> error
    end
  end
  
  defp get_scopes(%{"scope" => scope_string}) do
    String.split(scope_string, " ")
  end
end
```

## Permission Checking

### Context-Based Authorization

#### Implementation Example
```elixir
defmodule Prismatic.Authorization do
  @doc """
  Check if user can perform action on resource
  """
  def can?(user, action, resource, context \\ %{}) do
    with :ok <- check_user_status(user),
         :ok <- check_role_permission(user, action, resource),
         :ok <- check_resource_access(user, resource, context),
         :ok <- check_organization_access(user, resource, context) do
      audit_authorization_success(user, action, resource)
      :ok
    else
      {:error, reason} = error ->
        audit_authorization_failure(user, action, resource, reason)
        error
    end
  end
  
  defp check_role_permission(user, action, resource) do
    permission = "#{action}:#{resource}:#{get_scope(user, resource)}"
    
    if permission in get_user_permissions(user) do
      :ok
    else
      {:error, :insufficient_permissions}
    end
  end
  
  defp check_resource_access(user, %{user_id: resource_user_id}, _context) 
       when user.id == resource_user_id do
    :ok  # User owns the resource
  end
  
  defp check_resource_access(user, resource, context) do
    if resource.org_id == user.org_id do
      :ok  # Same organization
    else
      {:error, :resource_not_accessible}
    end
  end
end
```

### Plug-based Authorization

#### Authentication Plug
```elixir
defmodule PrismaticWeb.Auth.AuthenticationPlug do
  import Plug.Conn
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user} <- authenticate_token(token) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{
          error: %{
            code: "AUTHENTICATION_REQUIRED",
            message: "Valid authentication token required"
          }
        })
        |> halt()
    end
  end
end
```

#### Authorization Plug
```elixir
defmodule PrismaticWeb.Auth.AuthorizationPlug do
  import Plug.Conn
  
  def init(opts), do: opts
  
  def call(conn, action: action, resource: resource) do
    user = conn.assigns.current_user
    
    case Prismatic.Authorization.can?(user, action, resource) do
      :ok -> 
        conn
      {:error, reason} ->
        conn
        |> put_status(:forbidden)
        |> Phoenix.Controller.json(%{
          error: %{
            code: "INSUFFICIENT_PERMISSIONS",
            message: "You don't have permission to #{action} #{resource}"
          }
        })
        |> halt()
    end
  end
end
```

## Token Management

### Token Generation

#### Access Token Generation
```elixir
defmodule Prismatic.Auth.TokenGenerator do
  @access_token_ttl 3600  # 1 hour
  @refresh_token_ttl 2_592_000  # 30 days
  
  def generate_access_token(user) do
    claims = %{
      "sub" => user.id,
      "iss" => get_issuer(),
      "aud" => get_audience(),
      "exp" => DateTime.utc_now() |> DateTime.add(@access_token_ttl, :second) |> DateTime.to_unix(),
      "iat" => DateTime.utc_now() |> DateTime.to_unix(),
      "jti" => generate_jti(),
      "scope" => build_user_scopes(user),
      "role" => user.role,
      "org_id" => user.org_id
    }
    
    sign_token(claims)
  end
  
  def generate_refresh_token(user) do
    %RefreshToken{
      user_id: user.id,
      token_hash: generate_secure_hash(),
      expires_at: DateTime.add(DateTime.utc_now(), @refresh_token_ttl, :second),
      created_at: DateTime.utc_now()
    }
    |> Repo.insert!()
  end
end
```

### Token Validation

#### JWT Validation
```elixir
defmodule Prismatic.Auth.TokenValidator do
  def validate_access_token(token) do
    with {:ok, claims} <- verify_jwt_signature(token),
         :ok <- check_token_expiration(claims),
         :ok <- check_token_revocation(claims["jti"]),
         {:ok, user} <- get_user(claims["sub"]),
         :ok <- check_user_status(user) do
      {:ok, user, claims}
    else
      {:error, :expired} -> {:error, :token_expired}
      {:error, :revoked} -> {:error, :token_revoked}
      error -> error
    end
  end
  
  defp verify_jwt_signature(token) do
    case Guardian.decode_and_verify(token) do
      {:ok, claims} -> {:ok, claims}
      {:error, reason} -> {:error, reason}
    end
  end
  
  defp check_token_revocation(jti) do
    case Redis.get("revoked_token:#{jti}") do
      nil -> :ok
      _ -> {:error, :revoked}
    end
  end
end
```

### Token Revocation

#### Individual Token Revocation
```elixir
def revoke_token(token) do
  with {:ok, claims} <- decode_token(token),
       jti <- claims["jti"],
       exp <- claims["exp"] do
    # Store revoked token until expiration
    ttl = exp - DateTime.utc_now() |> DateTime.to_unix()
    Redis.setex("revoked_token:#{jti}", ttl, "revoked")
    
    audit_token_revocation(claims["sub"], jti, "manual_revocation")
    :ok
  end
end
```

#### User Session Revocation
```elixir
def revoke_all_user_tokens(user_id) do
  # Update user's token generation counter
  user = Repo.get!(User, user_id)
  Ecto.Changeset.change(user, %{token_generation: user.token_generation + 1})
  |> Repo.update!()
  
  # Delete all refresh tokens
  from(rt in RefreshToken, where: rt.user_id == ^user_id)
  |> Repo.delete_all()
  
  audit_token_revocation(user_id, "all", "admin_revocation")
  :ok
end
```

## Security Best Practices

### Token Security

#### Secure Token Storage
```javascript
// Client-side token storage recommendations

// ✅ Recommended: Secure, httpOnly cookie (server-set)
// No JavaScript access, automatic CSRF protection
document.cookie = "auth_token=...; Secure; HttpOnly; SameSite=Strict";

// ✅ Alternative: sessionStorage for SPA
// Cleared when tab closes
sessionStorage.setItem('auth_token', token);

// ❌ Avoid: localStorage for sensitive tokens
// Persists across sessions, XSS vulnerable
localStorage.setItem('auth_token', token); // DON'T DO THIS
```

#### Token Transmission
```http
# ✅ Always use HTTPS for token transmission
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...

# ✅ Include in request headers, not URL parameters
GET /api/users HTTP/1.1
Authorization: Bearer <token>

# ❌ Never include tokens in URLs
GET /api/users?token=<token>  # DON'T DO THIS
```

### Rate Limiting

#### Authentication Rate Limits
```elixir
# Rate limiting configuration
@rate_limits %{
  login: {5, :minute},           # 5 attempts per minute per IP
  password_reset: {3, :hour},    # 3 reset requests per hour per email
  mfa_verify: {10, :minute},     # 10 MFA attempts per minute per user
  token_refresh: {20, :hour}     # 20 refresh attempts per hour per token
}
```

#### Implementation
```elixir
defmodule PrismaticWeb.Auth.RateLimiter do
  def check_rate_limit(action, identifier) do
    {limit, window} = get_rate_limit(action)
    key = "rate_limit:#{action}:#{identifier}"
    
    case Redis.get(key) do
      nil ->
        Redis.setex(key, window_seconds(window), 1)
        :ok
      count when count < limit ->
        Redis.incr(key)
        :ok
      _ ->
        {:error, :rate_limit_exceeded}
    end
  end
end
```

### Audit Logging

#### Authentication Events
```elixir
defmodule Prismatic.Auth.AuditLogger do
  def log_auth_event(event_type, user_id, details \\ %{}) do
    %AuthEvent{
      event_type: event_type,
      user_id: user_id,
      ip_address: get_client_ip(),
      user_agent: get_user_agent(),
      details: details,
      timestamp: DateTime.utc_now()
    }
    |> Repo.insert!()
    |> maybe_trigger_security_alert()
  end
  
  # Event types
  # - :login_success
  # - :login_failure  
  # - :logout
  # - :token_refresh
  # - :password_change
  # - :mfa_enabled
  # - :permission_denied
end
```

## Error Handling

### Authentication Errors

#### Common Error Responses
```json
// Invalid credentials
{
  "errors": [
    {
      "status": "401",
      "code": "INVALID_CREDENTIALS",
      "title": "Authentication Failed",
      "detail": "The provided credentials are invalid"
    }
  ]
}

// Expired token
{
  "errors": [
    {
      "status": "401", 
      "code": "TOKEN_EXPIRED",
      "title": "Token Expired",
      "detail": "The access token has expired",
      "meta": {
        "expired_at": "2024-01-15T11:00:00Z"
      }
    }
  ]
}

// Insufficient permissions
{
  "errors": [
    {
      "status": "403",
      "code": "INSUFFICIENT_PERMISSIONS", 
      "title": "Access Denied",
      "detail": "You don't have permission to perform this action",
      "meta": {
        "required_permission": "write:post:org",
        "user_permissions": ["read:post:own", "write:post:own"]
      }
    }
  ]
}
```

### Rate Limiting Errors
```json
{
  "errors": [
    {
      "status": "429",
      "code": "RATE_LIMIT_EXCEEDED",
      "title": "Too Many Requests",
      "detail": "Rate limit exceeded for login attempts",
      "meta": {
        "retry_after": 60,
        "limit": 5,
        "window": "1 minute"
      }
    }
  ]
}
```

## Testing Authentication

### Unit Tests
```elixir
defmodule Prismatic.AuthTest do
  use Prismatic.DataCase
  
  describe "authenticate_user/2" do
    test "authenticates user with valid credentials" do
      user = insert(:user, password: "valid_password")
      
      assert {:ok, auth_data} = Auth.authenticate_user(user.email, "valid_password")
      assert auth_data.access_token
      assert auth_data.refresh_token
    end
    
    test "rejects invalid credentials" do
      user = insert(:user, password: "valid_password")
      
      assert {:error, :invalid_credentials} = 
        Auth.authenticate_user(user.email, "wrong_password")
    end
  end
  
  describe "authorize_action/3" do
    test "allows user to read own posts" do
      user = insert(:user, role: "user")
      post = insert(:post, user: user)
      
      assert :ok = Auth.authorize_action(user, :read, post)
    end
    
    test "denies user from deleting others' posts" do
      user = insert(:user, role: "user")
      other_post = insert(:post)
      
      assert {:error, :insufficient_permissions} = 
        Auth.authorize_action(user, :delete, other_post)
    end
  end
end
```

### Integration Tests
```elixir
defmodule PrismaticWeb.AuthIntegrationTest do
  use PrismaticWeb.ConnCase
  
  test "requires authentication for protected endpoints" do
    conn = get(conn, "/api/users")
    assert json_response(conn, 401)
  end
  
  test "accepts valid bearer token" do
    user = insert(:user)
    token = generate_valid_token(user)
    
    conn = 
      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get("/api/users")
    
    assert json_response(conn, 200)
  end
  
  test "rejects expired token" do
    user = insert(:user)
    expired_token = generate_expired_token(user)
    
    conn =
      conn
      |> put_req_header("authorization", "Bearer #{expired_token}")
      |> get("/api/users")
    
    assert json_response(conn, 401)
  end
end
```

## Related Documentation

- [API Endpoints](api-endpoints.md) - Complete API reference with authentication examples
- [Security Guidelines](../guides/security-guidelines.md) - Comprehensive security implementation guide
- [ADR-0003: Security Model](../architecture/adr-0003-security-model.md) - Security architecture decisions and rationale
- [System Diagrams](../architecture/system-diagrams.md) - Visual representation of authentication flows
- [Database Schema](database-schema.md) - User, role, and permission data structures
- [Developer Experience](../guides/developer-experience.md) - Authentication setup in development environment

---

**This authentication system is designed for security, scalability, and maintainability. Regular security reviews and updates are essential to maintain effectiveness against evolving threats.**