# API Design Guidelines

Comprehensive guidelines for designing consistent, maintainable, and secure APIs in the Prismatic project using Phoenix and Elixir.

## ⏱️ Time Estimates

📖 Reading time: 30 minutes | 🔧 Implementation time: 3-5 hours | 📊 Skill level: Intermediate

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../../README.md) > [Guides](../README.md) > [Development](README.md) > API Design Guidelines

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to development guides
- **🏠 [Documentation Home](../../README.md)** - Main documentation index
- **🔍 [Search Documentation](../../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Coding Standards](coding-standards.md) - Code quality standards that support API development
- [Testing Strategy](testing-strategy.md) - API testing patterns and strategies
- [Error Handling & Logging](error-handling-logging.md) - API error handling and logging patterns
- [Security Guidelines](../security/security-guidelines.md) - API security implementation patterns
- [Performance Optimization](../performance/performance-optimization.md) - API performance considerations
- [CI/CD Implementation](../workflow/ci-cd-implementation.md) - API deployment and testing automation
<!-- NAV_END -->

---

## Table of Contents

1. [Overview](#overview)
2. [REST API Design Principles](#rest-api-design-principles)
3. [Phoenix Controller Patterns](#phoenix-controller-patterns)
4. [JSON API Response Standards](#json-api-response-standards)
5. [Error Handling and HTTP Status Codes](#error-handling-and-http-status-codes)
6. [Authentication and Authorization](#authentication-and-authorization)
7. [API Versioning Strategies](#api-versioning-strategies)
8. [Input Validation and Sanitization](#input-validation-and-sanitization)
9. [Rate Limiting and Throttling](#rate-limiting-and-throttling)
10. [API Documentation Standards](#api-documentation-standards)
11. [OpenAPI/Swagger Integration](#openapiswagger-integration)
12. [GraphQL Considerations](#graphql-considerations)
13. [Performance Optimization](#performance-optimization)
14. [Security Best Practices](#security-best-practices)
15. [Testing API Endpoints](#testing-api-endpoints)
16. [Common Anti-Patterns](#common-anti-patterns)
17. [Troubleshooting](#troubleshooting)

---

## Overview

Well-designed APIs are crucial for system integration, client applications, and third-party development. This guide establishes standards for creating APIs that are consistent, secure, performant, and maintainable within the Prismatic ecosystem.

### Why This Matters

- **Developer Experience**: Consistent, predictable API behavior
- **Integration Success**: Clear contracts for client applications
- **Maintainability**: Standardized patterns reduce complexity
- **Security**: Consistent security implementation across endpoints
- **Performance**: Optimized data transfer and caching strategies

### Scope

This guide covers:
- RESTful API design with Phoenix controllers
- JSON API response formatting
- Authentication and authorization patterns
- Error handling and status codes
- API versioning and backward compatibility
- Performance optimization techniques
- Documentation and testing strategies

---

## REST API Design Principles

### Resource-Oriented Design

Design APIs around resources, not actions:

```elixir
# ✅ Good - Resource-oriented endpoints
GET    /api/v1/articles           # List articles
POST   /api/v1/articles           # Create article
GET    /api/v1/articles/123       # Get specific article
PUT    /api/v1/articles/123       # Update article
DELETE /api/v1/articles/123       # Delete article

# Nested resources for relationships
GET    /api/v1/articles/123/comments    # Comments for article
POST   /api/v1/articles/123/comments    # Add comment to article

# ❌ Avoid - Action-oriented endpoints
POST   /api/v1/create_article
POST   /api/v1/delete_article/123
GET    /api/v1/get_user_articles/456
```

### HTTP Methods and Semantics

Use HTTP methods according to their intended semantics:

```elixir
defmodule PrismaticWeb.Api.V1.ArticleController do
  use PrismaticWeb, :controller
  
  # GET - Safe, idempotent, cacheable
  def index(conn, params) do
    articles = Content.list_articles(params)
    render(conn, :index, articles: articles)
  end
  
  # POST - Creates new resource, not idempotent
  def create(conn, %{"article" => article_params}) do
    case Content.create_article(article_params) do
      {:ok, article} ->
        conn
        |> put_status(:created)
        |> put_resp_header("location", ~p"/api/v1/articles/#{article}")
        |> render(:show, article: article)
      
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, changeset: changeset)
    end
  end
  
  # PUT - Complete resource replacement, idempotent
  def update(conn, %{"id" => id, "article" => article_params}) do
    article = Content.get_article!(id)
    
    case Content.update_article(article, article_params) do
      {:ok, article} ->
        render(conn, :show, article: article)
      
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, changeset: changeset)
    end
  end
  
  # PATCH - Partial resource update, idempotent
  def partial_update(conn, %{"id" => id, "article" => article_params}) do
    article = Content.get_article!(id)
    
    case Content.update_article(article, article_params) do
      {:ok, article} ->
        render(conn, :show, article: article)
      
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, changeset: changeset)
    end
  end
  
  # DELETE - Resource removal, idempotent
  def delete(conn, %{"id" => id}) do
    article = Content.get_article!(id)
    
    case Content.delete_article(article) do
      {:ok, _article} ->
        send_resp(conn, :no_content, "")
      
      {:error, _reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Unable to delete article"})
    end
  end
end
```

### URL Design Standards

Follow consistent URL patterns:

```elixir
# ✅ Good - Consistent, predictable patterns
/api/v1/users                    # Collection
/api/v1/users/123                # Resource
/api/v1/users/123/articles       # Nested collection
/api/v1/users/123/articles/456   # Nested resource

# Query parameters for filtering, sorting, pagination
/api/v1/articles?status=published&sort=created_at&page=2&per_page=20

# ❌ Avoid - Inconsistent patterns
/api/v1/user                     # Singular collection name
/api/v1/users/123/getArticles    # Camel case, action in URL
/api/v1/users-articles           # Unclear relationship
```

---

## Phoenix Controller Patterns

### Standard Controller Structure

Organize controllers with consistent patterns:

```elixir
defmodule PrismaticWeb.Api.V1.ArticleController do
  use PrismaticWeb, :controller
  
  alias Prismatic.Content
  alias Prismatic.Content.Article
  
  # Plugs for common functionality
  plug :authenticate_api_user
  plug :authorize_resource when action in [:show, :update, :delete]
  plug :rate_limit, max_requests: 100, window: :minute
  
  action_fallback PrismaticWeb.Api.FallbackController
  
  @doc """
  Lists articles with filtering, sorting, and pagination.
  
  ## Query Parameters
  - `status`: Filter by publication status
  - `tag`: Filter by tag
  - `sort`: Sort field (created_at, updated_at, title)
  - `order`: Sort direction (asc, desc)
  - `page`: Page number (default: 1)
  - `per_page`: Items per page (default: 20, max: 100)
  
  ## Example Request
      GET /api/v1/articles?status=published&sort=created_at&order=desc&page=1&per_page=20
  """
  def index(conn, params) do
    with {:ok, filters} <- validate_filters(params),
         {:ok, pagination} <- validate_pagination(params) do
      
      articles = Content.list_articles(filters, pagination)
      total_count = Content.count_articles(filters)
      
      conn
      |> put_pagination_headers(pagination, total_count)
      |> render(:index, %{articles: articles, meta: build_meta(pagination, total_count)})
    end
  end
  
  def show(conn, %{"id" => id}) do
    article = Content.get_article!(id)
    render(conn, :show, article: article)
  end
  
  def create(conn, %{"article" => article_params}) do
    current_user = conn.assigns.current_user
    
    with {:ok, article} <- Content.create_article(current_user, article_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/v1/articles/#{article}")
      |> render(:show, article: article)
    end
  end
  
  # Private helper functions
  defp validate_filters(params) do
    valid_statuses = ["draft", "published", "archived"]
    
    filters = %{}
    
    filters = 
      case Map.get(params, "status") do
        status when status in valid_statuses -> Map.put(filters, :status, String.to_atom(status))
        nil -> filters
        _ -> return {:error, :invalid_status}
      end
    
    filters = 
      case Map.get(params, "tag") do
        tag when is_binary(tag) -> Map.put(filters, :tag, tag)
        nil -> filters
        _ -> {:error, :invalid_tag}
      end
    
    {:ok, filters}
  end
  
  defp validate_pagination(params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    per_page = Map.get(params, "per_page", "20") |> String.to_integer()
    
    cond do
      page < 1 -> {:error, :invalid_page}
      per_page < 1 or per_page > 100 -> {:error, :invalid_per_page}
      true -> {:ok, %{page: page, per_page: per_page}}
    end
  end
  
  defp put_pagination_headers(conn, pagination, total_count) do
    total_pages = ceil(total_count / pagination.per_page)
    
    conn
    |> put_resp_header("x-total-count", to_string(total_count))
    |> put_resp_header("x-total-pages", to_string(total_pages))
    |> put_resp_header("x-current-page", to_string(pagination.page))
    |> put_resp_header("x-per-page", to_string(pagination.per_page))
  end
end
```

### Fallback Controller for Error Handling

Centralize error handling with fallback controllers:

```elixir
defmodule PrismaticWeb.Api.FallbackController do
  use PrismaticWeb, :controller
  
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{
      error: %{
        code: "not_found",
        message: "The requested resource was not found",
        details: %{}
      }
    })
  end
  
  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{
      error: %{
        code: "unauthorized",
        message: "Authentication is required to access this resource",
        details: %{}
      }
    })
  end
  
  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> json(%{
      error: %{
        code: "forbidden",
        message: "You don't have permission to access this resource",
        details: %{}
      }
    })
  end
  
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error: %{
        code: "validation_failed",
        message: "The request data failed validation",
        details: format_changeset_errors(changeset)
      }
    })
  end
  
  def call(conn, {:error, :rate_limit_exceeded}) do
    conn
    |> put_status(:too_many_requests)
    |> put_resp_header("retry-after", "60")
    |> json(%{
      error: %{
        code: "rate_limit_exceeded",
        message: "Too many requests. Please slow down.",
        details: %{retry_after: 60}
      }
    })
  end
  
  # Catch-all for unexpected errors
  def call(conn, error) do
    # Log the unexpected error for debugging
    require Logger
    Logger.error("Unexpected API error: #{inspect(error)}")
    
    conn
    |> put_status(:internal_server_error)
    |> json(%{
      error: %{
        code: "internal_error",
        message: "An unexpected error occurred",
        details: %{}
      }
    })
  end
  
  defp format_changeset_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
```

---

## JSON API Response Standards

### Response Structure

Use consistent response formats across all endpoints:

```elixir
defmodule PrismaticWeb.Api.V1.ArticleJSON do
  alias Prismatic.Content.Article
  
  @doc """
  Renders a list of articles with pagination metadata.
  """
  def index(%{articles: articles, meta: meta}) do
    %{
      data: for(article <- articles, do: data(article)),
      meta: meta,
      links: %{
        self: "/api/v1/articles"
      }
    }
  end
  
  @doc """
  Renders a single article.
  """
  def show(%{article: article}) do
    %{
      data: data(article),
      links: %{
        self: "/api/v1/articles/#{article.id}"
      }
    }
  end
  
  @doc """
  Renders validation errors.
  """
  def error(%{changeset: changeset}) do
    %{
      error: %{
        code: "validation_failed",
        message: "The request data failed validation",
        details: format_errors(changeset)
      }
    }
  end
  
  # Private data transformation function
  defp data(%Article{} = article) do
    %{
      id: article.id,
      type: "article",
      attributes: %{
        title: article.title,
        content: article.content,
        excerpt: article.excerpt,
        status: article.status,
        published_at: article.published_at,
        created_at: article.inserted_at,
        updated_at: article.updated_at
      },
      relationships: relationships(article),
      links: %{
        self: "/api/v1/articles/#{article.id}"
      }
    }
  end
  
  defp relationships(%Article{} = article) do
    %{
      author: %{
        data: %{
          id: article.author_id,
          type: "user"
        },
        links: %{
          related: "/api/v1/users/#{article.author_id}"
        }
      },
      comments: %{
        links: %{
          related: "/api/v1/articles/#{article.id}/comments"
        }
      }
    }
  end
  
  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
```

### Pagination Standards

Implement consistent pagination across all list endpoints:

```elixir
defmodule PrismaticWeb.Api.PaginationHelpers do
  @moduledoc """
  Helper functions for API pagination.
  """
  
  @default_per_page 20
  @max_per_page 100
  
  def build_pagination_meta(page, per_page, total_count) do
    total_pages = ceil(total_count / per_page)
    
    %{
      pagination: %{
        page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: total_pages,
        has_next: page < total_pages,
        has_prev: page > 1
      }
    }
  end
  
  def build_pagination_links(conn, page, per_page, total_count) do
    base_url = "#{conn.scheme}://#{conn.host}:#{conn.port}#{conn.request_path}"
    total_pages = ceil(total_count / per_page)
    
    links = %{self: build_link(base_url, conn.query_params, page, per_page)}
    
    links = 
      if page > 1 do
        links
        |> Map.put(:first, build_link(base_url, conn.query_params, 1, per_page))
        |> Map.put(:prev, build_link(base_url, conn.query_params, page - 1, per_page))
      else
        links
      end
    
    links = 
      if page < total_pages do
        links
        |> Map.put(:next, build_link(base_url, conn.query_params, page + 1, per_page))
        |> Map.put(:last, build_link(base_url, conn.query_params, total_pages, per_page))
      else
        links
      end
    
    links
  end
  
  defp build_link(base_url, query_params, page, per_page) do
    updated_params = 
      query_params
      |> Map.put("page", to_string(page))
      |> Map.put("per_page", to_string(per_page))
      |> URI.encode_query()
    
    "#{base_url}?#{updated_params}"
  end
  
  def validate_pagination_params(%{"page" => page, "per_page" => per_page}) do
    with {page_int, ""} <- Integer.parse(page),
         {per_page_int, ""} <- Integer.parse(per_page),
         true <- page_int > 0,
         true <- per_page_int > 0 and per_page_int <= @max_per_page do
      {:ok, %{page: page_int, per_page: per_page_int}}
    else
      _ -> {:error, :invalid_pagination}
    end
  end
  
  def validate_pagination_params(params) do
    page = Map.get(params, "page", "1")
    per_page = Map.get(params, "per_page", to_string(@default_per_page))
    
    validate_pagination_params(%{"page" => page, "per_page" => per_page})
  end
end
```

---

## Error Handling and HTTP Status Codes

### Standard HTTP Status Codes

Use appropriate status codes consistently:

```elixir
defmodule PrismaticWeb.Api.StatusCodes do
  @moduledoc """
  Standard HTTP status codes for API responses.
  """
  
  # Success codes (2xx)
  @success_codes %{
    ok: 200,                    # GET requests that return data
    created: 201,               # POST requests that create resources
    accepted: 202,              # Async operations accepted
    no_content: 204             # DELETE or PUT with no response body
  }
  
  # Client error codes (4xx)
  @client_error_codes %{
    bad_request: 400,           # Invalid request syntax or parameters
    unauthorized: 401,          # Authentication required
    forbidden: 403,             # Authenticated but not authorized
    not_found: 404,             # Resource doesn't exist
    method_not_allowed: 405,    # HTTP method not supported for resource
    not_acceptable: 406,        # Cannot produce response in requested format
    conflict: 409,              # Resource conflict (e.g., duplicate creation)
    gone: 410,                  # Resource previously existed but is gone
    unprocessable_entity: 422,  # Validation errors
    too_many_requests: 429      # Rate limit exceeded
  }
  
  # Server error codes (5xx)
  @server_error_codes %{
    internal_server_error: 500, # Unexpected server error
    not_implemented: 501,       # Feature not implemented
    bad_gateway: 502,           # Upstream service error
    service_unavailable: 503,   # Service temporarily unavailable
    gateway_timeout: 504        # Upstream service timeout
  }
end

# Usage in controllers
defmodule PrismaticWeb.Api.V1.ArticleController do
  use PrismaticWeb, :controller
  
  def create(conn, %{"article" => article_params}) do
    case Content.create_article(article_params) do
      {:ok, article} ->
        conn
        |> put_status(:created)  # 201
        |> render(:show, article: article)
      
      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)  # 422
        |> render(:error, changeset: changeset)
    end
  end
  
  def show(conn, %{"id" => id}) do
    case Content.get_article(id) do
      nil ->
        conn
        |> put_status(:not_found)  # 404
        |> json(%{error: %{code: "not_found", message: "Article not found"}})
      
      article ->
        render(conn, :show, article: article)  # 200
    end
  end
end
```

### Error Response Format

Standardize error responses across all endpoints:

```elixir
defmodule PrismaticWeb.Api.ErrorResponse do
  @moduledoc """
  Standardized error response formatting for APIs.
  """
  
  @doc """
  Builds a standardized error response.
  
  ## Parameters
  - `code`: Machine-readable error code
  - `message`: Human-readable error message
  - `details`: Additional error details (optional)
  - `meta`: Additional metadata (optional)
  """
  def build_error(code, message, details \\ %{}, meta \\ %{}) do
    error = %{
      code: code,
      message: message,
      details: details
    }
    
    response = %{error: error}
    
    if meta != %{} do
      Map.put(response, :meta, meta)
    else
      response
    end
  end
  
  # Predefined error responses
  def not_found(resource \\ "resource") do
    build_error(
      "not_found",
      "The requested #{resource} was not found"
    )
  end
  
  def unauthorized do
    build_error(
      "unauthorized",
      "Authentication is required to access this resource"
    )
  end
  
  def forbidden do
    build_error(
      "forbidden",
      "You don't have permission to access this resource"
    )
  end
  
  def validation_failed(changeset) do
    build_error(
      "validation_failed",
      "The request data failed validation",
      format_changeset_errors(changeset)
    )
  end
  
  def rate_limit_exceeded(retry_after \\ 60) do
    build_error(
      "rate_limit_exceeded",
      "Too many requests. Please slow down.",
      %{},
      %{retry_after: retry_after}
    )
  end
  
  def internal_error do
    build_error(
      "internal_error",
      "An unexpected error occurred. Please try again later."
    )
  end
  
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
```

---

## Authentication and Authorization

### JWT Authentication

Implement JWT-based authentication for stateless API access:

```elixir
defmodule Prismatic.Auth.JWT do
  @moduledoc """
  JWT token handling for API authentication.
  """
  
  use Joken.Config
  
  alias Prismatic.Accounts
  
  @impl Joken.Config
  def token_config do
    default_claims(skip: [:aud, :iss])
    |> add_claim("sub", nil, &validate_user_exists/3)
    |> add_claim("scope", nil, &validate_scope/3)
  end
  
  def generate_token(user, scope \\ "api:read api:write") do
    extra_claims = %{
      "sub" => user.id,
      "email" => user.email,
      "scope" => scope,
      "exp" => current_time() + (4 * 60 * 60)  # 4 hours
    }
    
    generate_and_sign(extra_claims)
  end
  
  def verify_token(token) do
    with {:ok, claims} <- verify_and_validate(token) do
      user = Accounts.get_user!(claims["sub"])
      {:ok, user, claims}
    end
  end
  
  defp validate_user_exists(user_id, _claims, _context) do
    case Accounts.get_user(user_id) do
      nil -> {:error, "User not found"}
      _user -> :ok
    end
  end
  
  defp validate_scope(scope, _claims, _context) when is_binary(scope) do
    valid_scopes = ["api:read", "api:write", "api:admin"]
    
    requested_scopes = String.split(scope, " ")
    
    if Enum.all?(requested_scopes, &(&1 in valid_scopes)) do
      :ok
    else
      {:error, "Invalid scope"}
    end
  end
  
  defp current_time, do: DateTime.utc_now() |> DateTime.to_unix()
end

# Authentication plug
defmodule PrismaticWeb.Api.AuthPlug do
  import Plug.Conn
  import Phoenix.Controller
  
  alias Prismatic.Auth.JWT
  alias PrismaticWeb.Api.ErrorResponse
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        case JWT.verify_token(token) do
          {:ok, user, claims} ->
            conn
            |> assign(:current_user, user)
            |> assign(:token_claims, claims)
          
          {:error, _reason} ->
            conn
            |> put_status(:unauthorized)
            |> json(ErrorResponse.unauthorized())
            |> halt()
        end
      
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(ErrorResponse.unauthorized())
        |> halt()
    end
  end
end
```

### Scope-Based Authorization

Implement fine-grained authorization with scopes:

```elixir
defmodule PrismaticWeb.Api.AuthorizationPlug do
  import Plug.Conn
  import Phoenix.Controller
  
  alias PrismaticWeb.Api.ErrorResponse
  
  def init(opts), do: opts
  
  def call(conn, required_scopes) when is_list(required_scopes) do
    token_claims = conn.assigns[:token_claims] || %{}
    user_scopes = String.split(token_claims["scope"] || "", " ")
    
    if has_required_scopes?(user_scopes, required_scopes) do
      conn
    else
      conn
      |> put_status(:forbidden)
      |> json(ErrorResponse.forbidden())
      |> halt()
    end
  end
  
  def call(conn, required_scope) when is_binary(required_scope) do
    call(conn, [required_scope])
  end
  
  defp has_required_scopes?(user_scopes, required_scopes) do
    Enum.all?(required_scopes, &(&1 in user_scopes))
  end
end

# Usage in controllers
defmodule PrismaticWeb.Api.V1.ArticleController do
  use PrismaticWeb, :controller
  
  plug PrismaticWeb.Api.AuthPlug
  plug PrismaticWeb.Api.AuthorizationPlug, ["api:read"] when action in [:index, :show]
  plug PrismaticWeb.Api.AuthorizationPlug, ["api:write"] when action in [:create, :update, :delete]
  
  # Controller actions...
end
```

---

## API Versioning Strategies

### URL Path Versioning

Use URL path versioning for clear API evolution:

```elixir
# Router configuration
defmodule PrismaticWeb.Router do
  use PrismaticWeb, :router
  
  pipeline :api do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers
  end
  
  # API v1
  scope "/api/v1", PrismaticWeb.Api.V1, as: :api_v1 do
    pipe_through :api
    
    resources "/articles", ArticleController, except: [:new, :edit]
    resources "/users", UserController, except: [:new, :edit]
  end
  
  # API v2 with breaking changes
  scope "/api/v2", PrismaticWeb.Api.V2, as: :api_v2 do
    pipe_through :api
    
    resources "/articles", ArticleController, except: [:new, :edit]
    resources "/users", UserController, except: [:new, :edit]
  end
  
  # Default to latest version (optional)
  scope "/api", PrismaticWeb.Api.V2, as: :api do
    pipe_through :api
    
    resources "/articles", ArticleController, except: [:new, :edit]
  end
end
```

### Version-Specific Controllers

Maintain separate controllers for different API versions:

```elixir
# V1 Controller
defmodule PrismaticWeb.Api.V1.ArticleController do
  use PrismaticWeb, :controller
  
  def index(conn, params) do
    # V1 implementation
    articles = Content.list_articles_v1(params)
    render(conn, :index, articles: articles)
  end
end

# V2 Controller with breaking changes
defmodule PrismaticWeb.Api.V2.ArticleController do
  use PrismaticWeb, :controller
  
  def index(conn, params) do
    # V2 implementation with different response format
    articles = Content.list_articles_v2(params)
    render(conn, :index, articles: articles)
  end
end

# Shared business logic in contexts
defmodule Prismatic.Content do
  def list_articles_v1(params) do
    # V1-specific business logic and filtering
    list_articles(params)
    |> Enum.map(&format_for_v1/1)
  end
  
  def list_articles_v2(params) do
    # V2-specific business logic and filtering
    list_articles(params)
    |> Enum.map(&format_for_v2/1)
  end
  
  defp list_articles(params) do
    # Core business logic shared between versions
  end
end
```

### Deprecation Strategy

Implement graceful API deprecation:

```elixir
defmodule PrismaticWeb.Api.DeprecationPlug do
  import Plug.Conn
  
  def init(opts), do: opts
  
  def call(conn, opts) do
    version = opts[:version]
    sunset_date = opts[:sunset_date]
    replacement = opts[:replacement]
    
    conn
    |> put_resp_header("deprecation", "true")
    |> put_resp_header("sunset", sunset_date)
    |> put_resp_header("link", "<#{replacement}>; rel=\"successor-version\"")
  end
end

# Usage in deprecated controllers
defmodule PrismaticWeb.Api.V1.ArticleController do
  use PrismaticWeb, :controller
  
  plug PrismaticWeb.Api.DeprecationPlug, 
    version: "v1",
    sunset_date: "Sat, 31 Dec 2024 23:59:59 GMT",
    replacement: "/api/v2/articles"
  
  # Controller actions...
end
```

---

## Input Validation and Sanitization

### Request Validation

Validate all incoming request data:

```elixir
defmodule PrismaticWeb.Api.V1.ArticleController do
  use PrismaticWeb, :controller
  
  alias Prismatic.Content
  
  def create(conn, params) do
    with {:ok, article_params} <- validate_article_params(params),
         {:ok, article} <- Content.create_article(article_params) do
      
      conn
      |> put_status(:created)
      |> render(:show, article: article)
    else
      {:error, :invalid_params} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: %{code: "invalid_params", message: "Invalid request parameters"}})
      
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(:error, changeset: changeset)
    end
  end
  
  defp validate_article_params(%{"article" => article_params}) do
    required_fields = ["title", "content"]
    optional_fields = ["excerpt", "tags", "status"]
    allowed_fields = required_fields ++ optional_fields
    
    # Check for required fields
    missing_fields = Enum.filter(required_fields, &(not Map.has_key?(article_params, &1)))
    
    if missing_fields != [] do
      {:error, :missing_required_fields}
    else
      # Filter allowed fields and sanitize
      sanitized_params = 
        article_params
        |> Map.take(allowed_fields)
        |> sanitize_article_params()
      
      {:ok, sanitized_params}
    end
  end
  
  defp validate_article_params(_params) do
    {:error, :invalid_params}
  end
  
  defp sanitize_article_params(params) do
    params
    |> sanitize_string_field("title", max_length: 200)
    |> sanitize_string_field("content", max_length: 50_000)
    |> sanitize_string_field("excerpt", max_length: 500)
    |> sanitize_tags_field("tags")
    |> sanitize_status_field("status")
  end
  
  defp sanitize_string_field(params, field, opts \\ []) do
    case Map.get(params, field) do
      nil -> params
      value when is_binary(value) ->
        max_length = Keyword.get(opts, :max_length, 1000)
        
        sanitized = 
          value
          |> String.trim()
          |> String.slice(0, max_length)
          |> HtmlSanitizeEx.basic_html()  # Remove dangerous HTML
        
        Map.put(params, field, sanitized)
      
      _ -> Map.delete(params, field)  # Remove invalid data
    end
  end
  
  defp sanitize_tags_field(params, field) do
    case Map.get(params, field) do
      tags when is_list(tags) ->
        sanitized_tags = 
          tags
          |> Enum.filter(&is_binary/1)
          |> Enum.map(&String.trim/1)
          |> Enum.filter(&(String.length(&1) > 0))
          |> Enum.take(10)  # Limit to 10 tags
        
        Map.put(params, field, sanitized_tags)
      
      _ -> Map.delete(params, field)
    end
  end
  
  defp sanitize_status_field(params, field) do
    valid_statuses = ["draft", "published", "archived"]
    
    case Map.get(params, field) do
      status when status in valid_statuses ->
        Map.put(params, field, status)
      
      _ -> Map.put(params, field, "draft")  # Default to draft
    end
  end
end
```

### Query Parameter Validation

Validate query parameters for filtering and pagination:

```elixir
defmodule PrismaticWeb.Api.QueryValidation do
  @moduledoc """
  Helper functions for validating API query parameters.
  """
  
  def validate_filters(params, allowed_filters) do
    filters = 
      params
      |> Map.take(allowed_filters)
      |> Enum.reduce(%{}, fn {key, value}, acc ->
        case validate_filter(key, value) do
          {:ok, validated_value} -> Map.put(acc, String.to_atom(key), validated_value)
          :error -> acc
        end
      end)
    
    {:ok, filters}
  end
  
  def validate_sorting(params, allowed_fields) do
    sort_field = Map.get(params, "sort", "id")
    sort_order = Map.get(params, "order", "asc")
    
    cond do
      sort_field not in allowed_fields ->
        {:error, :invalid_sort_field}
      
      sort_order not in ["asc", "desc"] ->
        {:error, :invalid_sort_order}
      
      true ->
        {:ok, %{field: String.to_atom(sort_field), order: String.to_atom(sort_order)}}
    end
  end
  
  def validate_pagination(params) do
    page = Map.get(params, "page", "1")
    per_page = Map.get(params, "per_page", "20")
    
    with {page_int, ""} <- Integer.parse(page),
         {per_page_int, ""} <- Integer.parse(per_page),
         true <- page_int > 0,
         true <- per_page_int > 0 and per_page_int <= 100 do
      {:ok, %{page: page_int, per_page: per_page_int}}
    else
      _ -> {:error, :invalid_pagination}
    end
  end
  
  defp validate_filter("status", value) when value in ["draft", "published", "archived"] do
    {:ok, String.to_atom(value)}
  end
  
  defp validate_filter("tag", value) when is_binary(value) and byte_size(value) <= 50 do
    {:ok, String.trim(value)}
  end
  
  defp validate_filter("author_id", value) do
    case Integer.parse(value) do
      {author_id, ""} when author_id > 0 -> {:ok, author_id}
      _ -> :error
    end
  end
  
  defp validate_filter(_key, _value), do: :error
end
```

---

## Rate Limiting and Throttling

### Plug-Based Rate Limiting

Implement rate limiting using plugs:

```elixir
defmodule PrismaticWeb.Api.RateLimitPlug do
  import Plug.Conn
  import Phoenix.Controller
  
  alias PrismaticWeb.Api.ErrorResponse
  
  def init(opts), do: opts
  
  def call(conn, opts) do
    key = build_rate_limit_key(conn, opts)
    window = Keyword.get(opts, :window, :minute)
    max_requests = Keyword.get(opts, :max_requests, 60)
    
    case check_rate_limit(key, window, max_requests) do
      {:ok, remaining} ->
        conn
        |> put_resp_header("x-ratelimit-limit", to_string(max_requests))
        |> put_resp_header("x-ratelimit-remaining", to_string(remaining))
        |> put_resp_header("x-ratelimit-reset", to_string(reset_time(window)))
      
      {:error, :rate_limit_exceeded, retry_after} ->
        conn
        |> put_status(:too_many_requests)
        |> put_resp_header("retry-after", to_string(retry_after))
        |> json(ErrorResponse.rate_limit_exceeded(retry_after))
        |> halt()
    end
  end
  
  defp build_rate_limit_key(conn, opts) do
    strategy = Keyword.get(opts, :strategy, :ip)
    
    case strategy do
      :ip ->
        client_ip = conn.remote_ip |> :inet.ntoa() |> to_string()
        "rate_limit:ip:#{client_ip}"
      
      :user ->
        user_id = conn.assigns[:current_user]&.id || "anonymous"
        "rate_limit:user:#{user_id}"
      
      :api_key ->
        api_key = get_req_header(conn, "x-api-key") |> List.first() || "no_key"
        "rate_limit:api_key:#{api_key}"
    end
  end
  
  defp check_rate_limit(key, window, max_requests) do
    window_seconds = window_to_seconds(window)
    current_time = System.system_time(:second)
    window_start = current_time - rem(current_time, window_seconds)
    
    # Use Redis or ETS for rate limit storage
    case Prismatic.RateLimit.increment(key, window_start, window_seconds) do
      count when count <= max_requests -> 
        {:ok, max_requests - count}
      
      _count -> 
        retry_after = window_start + window_seconds - current_time
        {:error, :rate_limit_exceeded, retry_after}
    end
  end
  
  defp window_to_seconds(:second), do: 1
  defp window_to_seconds(:minute), do: 60
  defp window_to_seconds(:hour), do: 3600
  
  defp reset_time(window) do
    window_seconds = window_to_seconds(window)
    current_time = System.system_time(:second)
    current_time - rem(current_time, window_seconds) + window_seconds
  end
end

# Rate limit storage using ETS (for single-node deployments)
defmodule Prismatic.RateLimit do
  use GenServer
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  def increment(key, window_start, window_seconds) do
    GenServer.call(__MODULE__, {:increment, key, window_start, window_seconds})
  end
  
  def init(_opts) do
    table = :ets.new(:rate_limits, [:set, :public, :named_table])
    
    # Clean up expired entries every minute
    :timer.send_interval(60_000, self(), :cleanup)
    
    {:ok, %{table: table}}
  end
  
  def handle_call({:increment, key, window_start, window_seconds}, _from, state) do
    window_key = "#{key}:#{window_start}"
    
    count = case :ets.lookup(:rate_limits, window_key) do
      [{^window_key, current_count, _expiry}] -> current_count + 1
      [] -> 1
    end
    
    expiry = window_start + window_seconds + 60  # Grace period
    :ets.insert(:rate_limits, {window_key, count, expiry})
    
    {:reply, count, state}
  end
  
  def handle_info(:cleanup, state) do
    current_time = System.system_time(:second)
    
    # Delete expired entries
    :ets.select_delete(:rate_limits, [
      {{'$1', '$2', '$3'}, [{:'<', '$3', current_time}], [true]}
    ])
    
    {:noreply, state}
  end
end
```

### Usage in Controllers

Apply rate limiting to specific endpoints:

```elixir
defmodule PrismaticWeb.Api.V1.ArticleController do
  use PrismaticWeb, :controller
  
  # Different rate limits for different operations
  plug PrismaticWeb.Api.RateLimitPlug, 
    max_requests: 100, 
    window: :minute,
    strategy: :user when action in [:index, :show]
  
  plug PrismaticWeb.Api.RateLimitPlug,
    max_requests: 10,
    window: :minute,
    strategy: :user when action in [:create, :update, :delete]
  
  # Controller actions...
end
```

---

## API Documentation Standards

### Controller Documentation

Document all API endpoints comprehensively:

```elixir
defmodule PrismaticWeb.Api.V1.ArticleController do
  use PrismaticWeb, :controller
  
  @moduledoc """
  API endpoints for managing articles.
  
  All endpoints require authentication via Bearer token in the Authorization header.
  
  ## Rate Limits
  - Read operations: 100 requests per minute per user
  - Write operations: 10 requests per minute per user
  
  ## Error Responses
  All errors follow the standard format:
  ```json
  {
    "error": {
      "code": "error_code",
      "message": "Human readable message",
      "details": {}
    }
  }
  ```
  """
  
  @doc """
  Lists articles with filtering, sorting, and pagination.
  
  ## Parameters
  - `status` (string, optional): Filter by status (`draft`, `published`, `archived`)
  - `tag` (string, optional): Filter by tag
  - `author_id` (integer, optional): Filter by author ID
  - `sort` (string, optional): Sort field (`created_at`, `updated_at`, `title`)
  - `order` (string, optional): Sort direction (`asc`, `desc`)
  - `page` (integer, optional): Page number (default: 1)
  - `per_page` (integer, optional): Items per page (default: 20, max: 100)
  
  ## Response
  Returns a paginated list of articles with metadata.
  
  ## Example Request
      GET /api/v1/articles?status=published&sort=created_at&order=desc&page=1&per_page=20
  
  ## Example Response
  ```json
  {
    "data": [
      {
        "id": 123,
        "type": "article",
        "attributes": {
          "title": "Sample Article",
          "content": "Article content...",
          "status": "published",
          "published_at": "2024-01-15T10:30:00Z",
          "created_at": "2024-01-15T09:00:00Z",
          "updated_at": "2024-01-15T10:30:00Z"
        },
        "relationships": {
          "author": {
            "data": {"id": 456, "type": "user"}
          }
        }
      }
    ],
    "meta": {
      "pagination": {
        "page": 1,
        "per_page": 20,
        "total_count": 150,
        "total_pages": 8
      }
    }
  }
  ```
  
  ## Status Codes
  - `200 OK`: Success
  - `400 Bad Request`: Invalid parameters
  - `401 Unauthorized`: Authentication required
  - `403 Forbidden`: Insufficient permissions
  """
  def index(conn, params) do
    # Implementation...
  end
  
  @doc """
  Creates a new article.
  
  ## Parameters
  Request body should contain an `article` object with:
  - `title` (string, required): Article title (max 200 characters)
  - `content` (string, required): Article content (max 50,000 characters)
  - `excerpt` (string, optional): Brief excerpt (max 500 characters)
  - `tags` (array of strings, optional): Article tags (max 10 tags)
  - `status` (string, optional): Article status (`draft`, `published`) - defaults to `draft`
  
  ## Example Request
  ```json
  {
    "article": {
      "title": "New Article",
      "content": "This is the article content...",
      "excerpt": "Brief description",
      "tags": ["elixir", "api"],
      "status": "draft"
    }
  }
  ```
  
  ## Status Codes
  - `201 Created`: Article created successfully
  - `400 Bad Request`: Invalid request format
  - `401 Unauthorized`: Authentication required
  - `403 Forbidden`: Insufficient permissions
  - `422 Unprocessable Entity`: Validation errors
  """
  def create(conn, params) do
    # Implementation...
  end
end
```

---

## OpenAPI/Swagger Integration

### OpenAPI Specification Generation

Generate API documentation from code annotations:

```elixir
# mix.exs
defp deps do
  [
    {:open_api_spex, "~> 3.5"},
    # other deps...
  ]
end

# API specification module
defmodule PrismaticWeb.ApiSpec do
  alias OpenApiSpex.{Info, OpenApi, Paths, Server}
  alias PrismaticWeb.{Endpoint, Router}
  
  def spec do
    %OpenApi{
      servers: [
        Server.from_endpoint(Endpoint)
      ],
      info: %Info{
        title: "Prismatic API",
        version: "1.0.0",
        description: """
        Prismatic API provides programmatic access to articles, users, and other resources.
        
        ## Authentication
        All API requests require authentication using a Bearer token:
        ```
        Authorization: Bearer YOUR_API_TOKEN
        ```
        
        ## Rate Limiting
        API requests are rate limited by user and operation type.
        """
      },
      paths: Paths.from_router(Router)
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end

# Schema definitions
defmodule PrismaticWeb.Schemas.Article do
  require OpenApiSpex
  alias OpenApiSpex.Schema
  
  OpenApiSpex.schema(%{
    title: "Article",
    description: "An article resource",
    type: :object,
    properties: %{
      id: %Schema{type: :integer, description: "Unique identifier"},
      title: %Schema{type: :string, description: "Article title", maxLength: 200},
      content: %Schema{type: :string, description: "Article content", maxLength: 50000},
      excerpt: %Schema{type: :string, description: "Brief excerpt", maxLength: 500},
      status: %Schema{type: :string, enum: ["draft", "published", "archived"]},
      tags: %Schema{type: :array, items: %Schema{type: :string}},
      published_at: %Schema{type: :string, format: :"date-time", nullable: true},
      created_at: %Schema{type: :string, format: :"date-time"},
      updated_at: %Schema{type: :string, format: :"date-time"}
    },
    required: [:id, :title, :content, :status, :created_at, :updated_at],
    example: %{
      id: 123,
      title: "Sample Article",
      content: "This is the article content...",
      excerpt: "Brief description",
      status: "published",
      tags: ["elixir", "api"],
      published_at: "2024-01-15T10:30:00Z",
      created_at: "2024-01-15T09:00:00Z",
      updated_at: "2024-01-15T10:30:00Z"
    }
  })
end

# Controller with OpenAPI annotations
defmodule PrismaticWeb.Api.V1.ArticleController do
  use PrismaticWeb, :controller
  use OpenApiSpex.ControllerSpecs
  
  alias PrismaticWeb.Schemas
  
  operation :index,
    summary: "List articles",
    description: "Returns a paginated list of articles with filtering options",
    parameters: [
      status: [
        in: :query,
        description: "Filter by status",
        schema: %OpenApiSpex.Schema{type: :string, enum: ["draft", "published", "archived"]}
      ],
      page: [
        in: :query,
        description: "Page number",
        schema: %OpenApiSpex.Schema{type: :integer, minimum: 1, default: 1}
      ]
    ],
    responses: [
      ok: {"Article list", "application/json", Schemas.ArticleList}
    ]
  
  def index(conn, params) do
    # Implementation...
  end
  
  operation :create,
    summary: "Create article",
    description: "Creates a new article",
    request_body: {"Article params", "application/json", Schemas.ArticleParams},
    responses: [
      created: {"Created article", "application/json", Schemas.Article},
      unprocessable_entity: {"Validation errors", "application/json", Schemas.ErrorResponse}
    ]
  
  def create(conn, params) do
    # Implementation...
  end
end
```

---

## GraphQL Considerations

### When to Use GraphQL

Consider GraphQL for APIs that benefit from:
- Complex, nested data relationships
- Clients with varying data requirements
- Real-time subscriptions
- Strong typing requirements

### GraphQL with Absinthe

Implement GraphQL alongside REST APIs:

```elixir
# mix.exs
defp deps do
  [
    {:absinthe, "~> 1.7"},
    {:absinthe_plug, "~> 1.5"},
    {:absinthe_phoenix, "~> 2.0"},
    # other deps...
  ]
end

# GraphQL schema
defmodule PrismaticWeb.Schema do
  use Absinthe.Schema
  
  alias PrismaticWeb.Resolvers
  
  object :article do
    field :id, non_null(:id)
    field :title, non_null(:string)
    field :content, non_null(:string)
    field :excerpt, :string
    field :status, non_null(:string)
    field :published_at, :datetime
    field :inserted_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)
    
    field :author, non_null(:user) do
      resolve &Resolvers.Articles.get_author/3
    end
    
    field :comments, list_of(:comment) do
      resolve &Resolvers.Articles.list_comments/3
    end
  end
  
  object :user do
    field :id, non_null(:id)
    field :name, non_null(:string)
    field :email, non_null(:string)
  end
  
  query do
    field :articles, list_of(:article) do
      arg :status, :string
      arg :limit, :integer, default_value: 20
      
      resolve &Resolvers.Articles.list_articles/3
    end
    
    field :article, :article do
      arg :id, non_null(:id)
      
      resolve &Resolvers.Articles.get_article/3
    end
  end
  
  mutation do
    field :create_article, :article do
      arg :input, non_null(:article_input)
      
      resolve &Resolvers.Articles.create_article/3
    end
  end
  
  input_object :article_input do
    field :title, non_null(:string)
    field :content, non_null(:string)
    field :excerpt, :string
    field :status, :string, default_value: "draft"
  end
end

# Resolvers
defmodule PrismaticWeb.Resolvers.Articles do
  alias Prismatic.Content
  
  def list_articles(_parent, args, %{context: %{current_user: user}}) do
    articles = Content.list_articles_for_user(user, args)
    {:ok, articles}
  end
  
  def get_article(_parent, %{id: id}, %{context: %{current_user: user}}) do
    case Content.get_user_article(user, id) do
      nil -> {:error, "Article not found"}
      article -> {:ok, article}
    end
  end
  
  def create_article(_parent, %{input: input}, %{context: %{current_user: user}}) do
    Content.create_article(user, input)
  end
  
  def get_author(article, _args, _context) do
    {:ok, Content.get_article_author(article)}
  end
end
```

---

## Performance Optimization

### Database Query Optimization

Optimize database queries for API performance:

```elixir
defmodule Prismatic.Content do
  import Ecto.Query
  
  alias Prismatic.Repo
  alias Prismatic.Content.Article
  
  def list_articles(filters \\ %{}, pagination \\ %{}) do
    base_query()
    |> apply_filters(filters)
    |> apply_sorting(Map.get(filters, :sort, %{field: :inserted_at, order: :desc}))
    |> apply_pagination(pagination)
    |> preload_associations()
    |> Repo.all()
  end
  
  defp base_query do
    from(a in Article, as: :article)
  end
  
  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn {key, value}, query ->
      case key do
        :status when value in [:draft, :published, :archived] ->
          where(query, [article: a], a.status == ^value)
        
        :tag when is_binary(value) ->
          where(query, [article: a], ^value in a.tags)
        
        :author_id when is_integer(value) ->
          where(query, [article: a], a.author_id == ^value)
        
        :search when is_binary(value) ->
          search_term = "%#{value}%"
          where(query, [article: a], 
            ilike(a.title, ^search_term) or 
            ilike(a.content, ^search_term)
          )
        
        _ -> query
      end
    end)
  end
  
  defp apply_sorting(query, %{field: field, order: order}) 
       when field in [:inserted_at, :updated_at, :title] and order in [:asc, :desc] do
    order_by(query, [article: a], [{^order, field(a, ^field)}])
  end
  
  defp apply_sorting(query, _), do: order_by(query, [article: a], desc: a.inserted_at)
  
  defp apply_pagination(query, %{page: page, per_page: per_page}) do
    offset = (page - 1) * per_page
    
    query
    |> limit(^per_page)
    |> offset(^offset)
  end
  
  defp apply_pagination(query, _), do: limit(query, 20)
  
  defp preload_associations(query) do
    preload(query, [:author, :tags])
  end
  
  # Optimized count query
  def count_articles(filters \\ %{}) do
    base_query()
    |> apply_filters(filters)
    |> select([article: a], count(a.id))
    |> Repo.one()
  end
end
```

### Response Caching

Implement caching for expensive operations:

```elixir
defmodule PrismaticWeb.Api.CachePlug do
  import Plug.Conn
  
  def init(opts), do: opts
  
  def call(conn, opts) do
    if cacheable_request?(conn) do
      cache_key = build_cache_key(conn)
      ttl = Keyword.get(opts, :ttl, 300)  # 5 minutes default
      
      case Prismatic.Cache.get(cache_key) do
        {:ok, cached_response} ->
          conn
          |> put_resp_header("x-cache", "HIT")
          |> send_cached_response(cached_response)
          |> halt()
        
        {:error, :not_found} ->
          conn
          |> put_resp_header("x-cache", "MISS")
          |> register_before_send(fn conn ->
            cache_response(conn, cache_key, ttl)
          end)
      end
    else
      conn
    end
  end
  
  defp cacheable_request?(conn) do
    conn.method == "GET" and 
    get_req_header(conn, "authorization") != [] and
    get_req_header(conn, "cache-control") != ["no-cache"]
  end
  
  defp build_cache_key(conn) do
    user_id = conn.assigns[:current_user]&.id || "anonymous"
    query_string = conn.query_string
    
    "api_cache:#{user_id}:#{conn.request_path}:#{:crypto.hash(:md5, query_string) |> Base.encode16()}"
  end
  
  defp cache_response(conn, cache_key, ttl) do
    if conn.status == 200 do
      response_data = %{
        status: conn.status,
        headers: Enum.into(conn.resp_headers, %{}),
        body: conn.resp_body
      }
      
      Prismatic.Cache.put(cache_key, response_data, ttl)
    end
    
    conn
  end
  
  defp send_cached_response(conn, cached_response) do
    conn
    |> merge_resp_headers(cached_response.headers)
    |> send_resp(cached_response.status, cached_response.body)
  end
end
```

### Connection Pooling and Timeouts

Configure database connections for optimal performance:

```elixir
# config/config.exs
config :prismatic, Prismatic.Repo,
  pool_size: 15,
  timeout: 15_000,
  ownership_timeout: 20_000,
  queue_target: 50,
  queue_interval: 1_000
```

---

## Security Best Practices

### Input Sanitization

Always sanitize user inputs to prevent security vulnerabilities:

```elixir
defmodule PrismaticWeb.Api.SecurityHelpers do
  @moduledoc """
  Security helpers for API input sanitization and validation.
  """
  
  def sanitize_html(input) when is_binary(input) do
    HtmlSanitizeEx.basic_html(input)
  end
  
  def sanitize_html(input), do: input
  
  def validate_uuid(uuid) when is_binary(uuid) do
    case Ecto.UUID.cast(uuid) do
      {:ok, valid_uuid} -> {:ok, valid_uuid}
      :error -> {:error, :invalid_uuid}
    end
  end
  
  def validate_email(email) when is_binary(email) do
    if Regex.match?(~r/^[^\s]+@[^\s]+\.[^\s]+$/, email) do
      {:ok, String.downcase(email)}
    else
      {:error, :invalid_email}
    end
  end
  
  def sanitize_filename(filename) when is_binary(filename) do
    filename
    |> String.replace(~r/[^\w\-_\.]/, "")
    |> String.slice(0, 255)
  end
end
```

### SQL Injection Prevention

Use parameterized queries and Ecto's built-in protections:

```elixir
# ✅ Good - Parameterized query
def search_articles(search_term) do
  from(a in Article, where: ilike(a.title, ^"%#{search_term}%"))
  |> Repo.all()
end

# ❌ Dangerous - String interpolation (vulnerable to injection)
def search_articles_bad(search_term) do
  query = "SELECT * FROM articles WHERE title ILIKE '%#{search_term}%'"
  Ecto.Adapters.SQL.query!(Repo, query, [])
end
```

### CORS Configuration

Configure CORS properly for API security:

```elixir
# config/config.exs
config :cors_plug,
  origin: ["https://app.prismatic.com", "https://staging.prismatic.com"],
  max_age: 86400,
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  headers: ["Authorization", "Content-Type", "Accept", "Origin", "User-Agent", "DNT", "Cache-Control", "X-Mx-ReqToken", "Keep-Alive", "X-Requested-With", "If-Modified-Since", "X-CSRF-Token"]

# In router
pipeline :api do
  plug CORSPlug
  plug :accepts, ["json"]
  plug :put_secure_browser_headers
end
```

---

## Testing API Endpoints

### Integration Testing

Test complete API workflows:

```elixir
defmodule PrismaticWeb.Api.V1.ArticleControllerTest do
  use PrismaticWeb.ConnCase, async: true
  
  import Prismatic.TestSupport.Fixtures
  
  describe "POST /api/v1/articles" do
    setup [:create_authenticated_conn]
    
    test "creates article with valid data", %{conn: conn, user: user} do
      article_params = %{
        title: "Test Article",
        content: "This is test content",
        tags: ["test", "api"]
      }
      
      conn = post(conn, ~p"/api/v1/articles", article: article_params)
      
      assert %{
        "data" => %{
          "id" => article_id,
          "type" => "article",
          "attributes" => %{
            "title" => "Test Article",
            "content" => "This is test content",
            "status" => "draft"
          }
        }
      } = json_response(conn, 201)
      
      # Verify in database
      article = Prismatic.Content.get_article!(article_id)
      assert article.author_id == user.id
    end
    
    test "returns validation errors for invalid data", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/articles", article: %{title: ""})
      
      assert %{
        "error" => %{
          "code" => "validation_failed",
          "details" => %{
            "title" => ["can't be blank"]
          }
        }
      } = json_response(conn, 422)
    end
  end
  
  describe "GET /api/v1/articles" do
    setup [:create_authenticated_conn]
    
    test "returns paginated articles", %{conn: conn, user: user} do
      # Create test data
      articles = for i <- 1..25 do
        article_fixture(user, %{title: "Article #{i}"})
      end
      
      conn = get(conn, ~p"/api/v1/articles", %{page: 1, per_page: 10})
      
      response = json_response(conn, 200)
      
      assert %{
        "data" => data,
        "meta" => %{
          "pagination" => %{
            "page" => 1,
            "per_page" => 10,
            "total_count" => 25,
            "total_pages" => 3
          }
        }
      } = response
      
      assert length(data) == 10
    end
    
    test "filters articles by status", %{conn: conn, user: user} do
      article_fixture(user, %{status: :published})
      article_fixture(user, %{status: :draft})
      
      conn = get(conn, ~p"/api/v1/articles", %{status: "published"})
      
      response = json_response(conn, 200)
      assert length(response["data"]) == 1
      assert List.first(response["data"])["attributes"]["status"] == "published"
    end
  end
  
  defp create_authenticated_conn(_context) do
    user = user_fixture()
    token = Prismatic.Auth.JWT.generate_token(user)
    
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("accept", "application/json")
    
    %{conn: conn, user: user}
  end
end
```

### Performance Testing

Test API performance under load:

```elixir
defmodule PrismaticWeb.Api.PerformanceTest do
  use PrismaticWeb.ConnCase
  
  @tag :performance
  test "article listing performance" do
    user = user_fixture()
    token = Prismatic.Auth.JWT.generate_token(user)
    
    # Create large dataset
    for i <- 1..1000 do
      article_fixture(user, %{title: "Article #{i}"})
    end
    
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("accept", "application/json")
    
    # Measure response time
    start_time = System.monotonic_time(:millisecond)
    
    conn = get(conn, ~p"/api/v1/articles", %{per_page: 50})
    
    end_time = System.monotonic_time(:millisecond)
    response_time = end_time - start_time
    
    assert json_response(conn, 200)
    assert response_time < 200  # Should respond within 200ms
  end
end
```

---

## Common Anti-Patterns

### 1. Exposing Implementation Details

```elixir
# ❌ Avoid - Exposing database IDs and internal structure
def show(conn, %{"id" => id}) do
  article = Repo.get!(Article, id) |> Repo.preload(:author)
  json(conn, article)  # Exposes all internal fields
end

# ✅ Better - Controlled data exposure
def show(conn, %{"id" => id}) do
  article = Content.get_article!(id)
  render(conn, :show, article: article)  # Uses view for controlled serialization
end
```

### 2. Inconsistent Error Handling

```elixir
# ❌ Avoid - Inconsistent error responses
def create(conn, params) do
  case Content.create_article(params) do
    {:ok, article} -> json(conn, article)
    {:error, _} -> json(conn, %{error: "Something went wrong"})  # Vague error
  end
end

# ✅ Better - Consistent error handling with fallback controller
def create(conn, %{"article" => article_params}) do
  with {:ok, article} <- Content.create_article(article_params) do
    conn
    |> put_status(:created)
    |> render(:show, article: article)
  end
  # Errors handled by fallback controller
end
```

### 3. Ignoring HTTP Semantics

```elixir
# ❌ Avoid - Misusing HTTP methods
def delete_article(conn, %{"id" => id}) do
  # Using GET for destructive operation
  Content.delete_article!(id)
  json(conn, %{message: "Deleted"})
end

# ✅ Better - Proper HTTP method usage
def delete(conn, %{"id" => id}) do
  article = Content.get_article!(id)
  
  case Content.delete_article(article) do
    {:ok, _} -> send_resp(conn, :no_content, "")
    {:error, _} -> {:error, :unprocessable_entity}
  end
end
```

### 4. Poor Resource Modeling

```elixir
# ❌ Avoid - Action-oriented endpoints
post "/api/v1/send_email"
post "/api/v1/calculate_shipping"
get "/api/v1/get_user_orders"

# ✅ Better - Resource-oriented design
post "/api/v1/emails"           # Send email
post "/api/v1/shipping_quotes"  # Calculate shipping
get "/api/v1/users/123/orders"  # Get user orders
```

---

## Troubleshooting

### Common Issues

#### CORS Errors

**Problem**: Browser blocks API requests due to CORS policy

**Solution**:
```elixir
# Ensure CORS is properly configured
config :cors_plug,
  origin: ["http://localhost:3000", "https://yourapp.com"],
  max_age: 86400,
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  headers: ["Authorization", "Content-Type", "Accept"]

# Add OPTIONS handling for preflight requests
options "*", &send_resp(&1, 200, "")
```

#### Authentication Failures

**Problem**: Valid tokens are being rejected

**Debugging**:
```elixir
# Add debugging to authentication plug
def call(conn, _opts) do
  case get_req_header(conn, "authorization") do
    ["Bearer " <> token] ->
      IO.inspect(token, label: "Received token")
      
      case JWT.verify_token(token) do
        {:ok, user, claims} ->
          IO.inspect(claims, label: "Token claims")
          assign(conn, :current_user, user)
        
        {:error, reason} ->
          IO.inspect(reason, label: "Token verification failed")
          unauthorized_response(conn)
      end
    
    headers ->
      IO.inspect(headers, label: "Authorization headers")
      unauthorized_response(conn)
  end
end
```

#### Performance Issues

**Problem**: API responses are slow

**Investigation**:
```elixir
# Add request timing
defmodule PrismaticWeb.Api.TimingPlug do
  import Plug.Conn
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    start_time = System.monotonic_time()
    
    register_before_send(conn, fn conn ->
      end_time = System.monotonic_time()
      duration = System.convert_time_unit(end_time - start_time, :native, :microsecond)
      
      put_resp_header(conn, "x-response-time", "#{duration}μs")
    end)
  end
end

# Profile database queries
config :logger, level: :debug

# Check for N+1 queries
def index(conn, params) do
  articles =
    Article
    |> preload([:author, :comments])  # Explicit preloading
    |> Repo.all()
  
  render(conn, :index, articles: articles)
end
```

#### Rate Limiting Issues

**Problem**: Legitimate users hitting rate limits

**Solutions**:
```elixir
# Implement different limits for different user types
defp get_rate_limit(user) do
  case user.subscription_type do
    :premium -> {max_requests: 1000, window: :hour}
    :basic -> {max_requests: 100, window: :hour}
    :free -> {max_requests: 50, window: :hour}
  end
end

# Add rate limit bypass for critical operations
plug :bypass_rate_limit when action in [:health_check, :status]
```

### Debugging Tools

#### Request/Response Logging

```elixir
defmodule PrismaticWeb.Api.LoggingPlug do
  require Logger
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    start_time = System.monotonic_time()
    
    Logger.info("""
    API Request:
    Method: #{conn.method}
    Path: #{conn.request_path}
    Query: #{conn.query_string}
    Headers: #{inspect(conn.req_headers)}
    """)
    
    register_before_send(conn, fn conn ->
      end_time = System.monotonic_time()
      duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)
      
      Logger.info("""
      API Response:
      Status: #{conn.status}
      Duration: #{duration}ms
      """)
      
      conn
    end)
  end
end
```

#### API Testing Tools

Use tools for API testing and debugging:

```bash
# cURL examples for testing
curl -X GET "http://localhost:4000/api/v1/articles" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Accept: application/json"

curl -X POST "http://localhost:4000/api/v1/articles" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"article":{"title":"Test","content":"Content"}}'

# HTTPie (more user-friendly)
http GET localhost:4000/api/v1/articles \
  Authorization:"Bearer YOUR_TOKEN"

http POST localhost:4000/api/v1/articles \
  Authorization:"Bearer YOUR_TOKEN" \
  article:='{"title":"Test","content":"Content"}'
```

---

## Related Documentation

- **[Testing Strategy](testing-strategy.md)** - Comprehensive testing strategies for API endpoints
- **[Error Handling & Logging](error-handling-logging.md)** - Error handling patterns and logging strategies
- **[Security Guidelines](../security/security-guidelines.md)** - Security implementation patterns for APIs
- **[Performance Optimization](../performance/performance-optimization.md)** - Performance optimization techniques
- **[Coding Standards](coding-standards.md)** - Code quality standards for API development
- **[CI/CD Implementation](../workflow/ci-cd-implementation.md)** - Automated testing and deployment for APIs

---

**💡 Pro Tip**: Start with simple, consistent patterns and gradually add complexity as needed. Focus on creating APIs that are predictable and self-documenting. Remember that good API design is about creating excellent developer experiences - both for your team and for API consumers.