# Error Handling & Logging Guide

Comprehensive error handling patterns and logging strategies for building resilient, observable systems in the Prismatic project.

## ⏱️ Time Estimates

📖 Reading time: 25 minutes | 🔧 Implementation time: 3-4 hours | 📊 Skill level: Intermediate

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../../README.md) > [Guides](../README.md) > [Development](README.md) > Error Handling & Logging

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to development guides
- **🏠 [Documentation Home](../../README.md)** - Main documentation index
- **🔍 [Search Documentation](../../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Testing Strategy](testing-strategy.md) - Testing error scenarios and edge cases
- [API Design Guidelines](api-design-guidelines.md) - API error handling patterns
- [Coding Standards](coding-standards.md) - Code quality standards that support error handling
- [Performance Optimization](../performance/performance-optimization.md) - Performance monitoring and error tracking
- [Security Guidelines](../security/security-guidelines.md) - Security-related error handling
- [Deployment Procedures](../deployment/deployment-procedures.md) - Production error monitoring and response
<!-- NAV_END -->

---

## Table of Contents

1. [Overview](#overview)
2. [Elixir Error Handling Patterns](#elixir-error-handling-patterns)
3. [Phoenix Error Handling](#phoenix-error-handling)
4. [Custom Error Pages](#custom-error-pages)
5. [Structured Logging](#structured-logging)
6. [Error Monitoring and Alerting](#error-monitoring-and-alerting)
7. [Recovery Strategies](#recovery-strategies)
8. [Testing Error Scenarios](#testing-error-scenarios)
9. [Performance Impact](#performance-impact)
10. [Production Best Practices](#production-best-practices)
11. [Common Anti-Patterns](#common-anti-patterns)
12. [Troubleshooting](#troubleshooting)

---

## Overview

Effective error handling and logging are critical for building resilient systems that provide good user experiences and enable rapid problem resolution. This guide establishes patterns for graceful error handling, comprehensive logging, and effective error recovery in the Prismatic project.

### Why This Matters

- **System Reliability**: Graceful handling of failures prevents system crashes
- **User Experience**: Clear, helpful error messages guide users
- **Debugging Efficiency**: Comprehensive logs enable quick problem resolution
- **Monitoring**: Early detection of issues before they impact users
- **Compliance**: Proper logging supports audit requirements and debugging

### Scope

This guide covers:
- Elixir error handling patterns (try/catch, with statements, tagged tuples)
- Phoenix controller and plug error handling
- Custom error pages and user-friendly error messages
- Structured logging strategies
- Error monitoring and alerting systems
- Recovery and fault tolerance patterns
- Testing error scenarios

---

## Elixir Error Handling Patterns

### Tagged Tuple Pattern

Use consistent tagged tuple patterns for predictable error handling:

```elixir
defmodule Prismatic.Content do
  @moduledoc """
  Content management with consistent error handling patterns.
  """
  
  alias Prismatic.Content.Article
  alias Prismatic.Repo
  
  @doc """
  Creates an article with comprehensive error handling.
  
  Returns:
  - `{:ok, article}` on success
  - `{:error, changeset}` on validation errors
  - `{:error, :rate_limited}` when rate limit exceeded
  - `{:error, :storage_full}` when storage quota exceeded
  """
  def create_article(user, attrs) do
    with :ok <- check_rate_limit(user),
         :ok <- check_storage_quota(user),
         {:ok, article} <- do_create_article(user, attrs) do
      {:ok, article}
    else
      {:error, :rate_limited} = error -> 
        log_rate_limit_violation(user)
        error
        
      {:error, :storage_full} = error ->
        log_storage_quota_exceeded(user)
        error
        
      {:error, %Ecto.Changeset{}} = error ->
        log_validation_error(user, attrs, error)
        error
        
      {:error, reason} ->
        log_unexpected_error(__MODULE__, :create_article, reason, %{user_id: user.id, attrs: attrs})
        {:error, :internal_error}
    end
  end
  
  defp do_create_article(user, attrs) do
    %Article{}
    |> Article.changeset(attrs)
    |> Ecto.Changeset.put_assoc(:author, user)
    |> Repo.insert()
  end
  
  defp check_rate_limit(user) do
    case Prismatic.RateLimit.check_limit(user, :article_creation) do
      :ok -> :ok
      :error -> {:error, :rate_limited}
    end
  end
  
  defp check_storage_quota(user) do
    case Prismatic.Storage.check_quota(user) do
      :ok -> :ok
      :error -> {:error, :storage_full}
    end
  end
end
```

### With Statement for Pipeline Error Handling

Use `with` statements for complex operations with multiple failure points:

```elixir
defmodule Prismatic.Orders do
  require Logger
  
  def process_order(user, order_params) do
    with {:ok, validated_items} <- validate_order_items(order_params),
         {:ok, pricing} <- calculate_pricing(validated_items),
         {:ok, payment_result} <- process_payment(user, pricing),
         {:ok, order} <- create_order(user, validated_items, payment_result),
         :ok <- update_inventory(validated_items),
         :ok <- send_confirmation_email(user, order) do
      
      Logger.info("Order processed successfully", 
        order_id: order.id, 
        user_id: user.id, 
        amount: pricing.total
      )
      
      {:ok, order}
    else
      {:error, :invalid_items} = error ->
        Logger.warning("Order validation failed", user_id: user.id, items: order_params[:items])
        error
        
      {:error, :payment_declined} = error ->
        Logger.warning("Payment declined", 
          user_id: user.id, 
          amount: order_params[:total]
        )
        error
        
      {:error, :insufficient_inventory} = error ->
        Logger.warning("Insufficient inventory", 
          user_id: user.id, 
          items: validated_items
        )
        error
        
      {:error, reason} = error ->
        Logger.error("Unexpected order processing error", 
          reason: reason, 
          user_id: user.id, 
          order_params: order_params
        )
        
        # Don't expose internal errors to users
        {:error, :processing_failed}
    end
  end
  
  defp validate_order_items(params) do
    # Validation logic that returns {:ok, items} or {:error, :invalid_items}
  end
  
  defp calculate_pricing(items) do
    # Pricing calculation that returns {:ok, pricing} or {:error, reason}
  end
  
  defp process_payment(user, pricing) do
    # Payment processing that returns {:ok, result} or {:error, :payment_declined}
  end
end
```

### Try/Catch for Exception Handling

Use try/catch sparingly, primarily for external service calls:

```elixir
defmodule Prismatic.ExternalApi do
  require Logger
  
  def fetch_user_data(user_id) do
    try do
      response = HTTPoison.get!("#{base_url()}/users/#{user_id}", headers(), timeout: 5000)
      
      case response.status_code do
        200 -> 
          {:ok, Jason.decode!(response.body)}
        404 -> 
          {:error, :not_found}
        status when status >= 500 ->
          {:error, :service_unavailable}
        _ ->
          {:error, :unexpected_response}
      end
    rescue
      HTTPoison.Error ->
        Logger.error("HTTP request failed", 
          service: "external_api",
          endpoint: "/users/#{user_id}",
          error: "connection_error"
        )
        {:error, :connection_failed}
        
      Jason.DecodeError ->
        Logger.error("JSON decode failed", 
          service: "external_api",
          endpoint: "/users/#{user_id}",
          error: "invalid_json"
        )
        {:error, :invalid_response}
        
      exception ->
        Logger.error("Unexpected exception in external API call", 
          service: "external_api",
          endpoint: "/users/#{user_id}",
          exception: Exception.format(:error, exception, __STACKTRACE__)
        )
        {:error, :internal_error}
    end
  end
end
```

### GenServer Error Handling

Implement robust error handling in GenServer processes:

```elixir
defmodule Prismatic.Workers.EmailProcessor do
  use GenServer
  require Logger
  
  # Client API
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def process_email(email_data) do
    GenServer.cast(__MODULE__, {:process_email, email_data})
  end
  
  # Server callbacks
  def init(opts) do
    state = %{
      max_retries: Keyword.get(opts, :max_retries, 3),
      retry_delay: Keyword.get(opts, :retry_delay, 1000),
      failed_emails: []
    }
    
    {:ok, state}
  end
  
  def handle_cast({:process_email, email_data}, state) do
    case send_email(email_data) do
      :ok ->
        Logger.info("Email sent successfully", email_id: email_data.id)
        {:noreply, state}
        
      {:error, reason} ->
        Logger.warning("Email send failed", 
          email_id: email_data.id, 
          reason: reason,
          retry_count: email_data.retry_count || 0
        )
        
        handle_email_failure(email_data, reason, state)
    end
  end
  
  def handle_info({:retry_email, email_data}, state) do
    Logger.info("Retrying email send", 
      email_id: email_data.id, 
      retry_count: email_data.retry_count
    )
    
    GenServer.cast(self(), {:process_email, email_data})
    {:noreply, state}
  end
  
  # Handle unexpected errors gracefully
  def handle_info({:EXIT, _pid, reason}, state) do
    Logger.error("Linked process died", reason: reason)
    {:noreply, state}
  end
  
  def handle_info(unexpected_message, state) do
    Logger.warning("Unexpected message received", message: unexpected_message)
    {:noreply, state}
  end
  
  # Prevent GenServer crashes from stopping the entire process
  def terminate(reason, state) do
    Logger.error("EmailProcessor terminating", 
      reason: reason, 
      failed_emails_count: length(state.failed_emails)
    )
    
    # Optionally persist failed emails for manual processing
    if length(state.failed_emails) > 0 do
      Prismatic.FailedJobs.store_failed_emails(state.failed_emails)
    end
    
    :ok
  end
  
  defp handle_email_failure(email_data, reason, state) do
    retry_count = (email_data.retry_count || 0) + 1
    
    if retry_count <= state.max_retries do
      # Schedule retry
      updated_email = Map.put(email_data, :retry_count, retry_count)
      Process.send_after(self(), {:retry_email, updated_email}, state.retry_delay)
      {:noreply, state}
    else
      # Max retries exceeded, add to failed list
      Logger.error("Email permanently failed", 
        email_id: email_data.id, 
        final_reason: reason,
        retry_count: retry_count
      )
      
      failed_emails = [email_data | state.failed_emails]
      {:noreply, %{state | failed_emails: failed_emails}}
    end
  end
  
  defp send_email(email_data) do
    # Implementation that returns :ok or {:error, reason}
  end
end
```

---

## Phoenix Error Handling

### Controller Error Handling

Handle errors gracefully in Phoenix controllers:

```elixir
defmodule PrismaticWeb.ArticleController do
  use PrismaticWeb, :controller
  
  require Logger
  
  # Use action_fallback for consistent error handling
  action_fallback PrismaticWeb.FallbackController
  
  def show(conn, %{"id" => id}) do
    case Prismatic.Content.get_article(id) do
      {:ok, article} ->
        render(conn, :show, article: article)
        
      {:error, :not_found} ->
        Logger.info("Article not found", article_id: id, user_id: get_current_user_id(conn))
        {:error, :not_found}
        
      {:error, :unauthorized} ->
        Logger.warning("Unauthorized article access", 
          article_id: id, 
          user_id: get_current_user_id(conn)
        )
        {:error, :unauthorized}
        
      {:error, reason} ->
        Logger.error("Unexpected error retrieving article", 
          article_id: id, 
          user_id: get_current_user_id(conn),
          reason: reason
        )
        {:error, :internal_error}
    end
  end
  
  def create(conn, %{"article" => article_params}) do
    current_user = conn.assigns.current_user
    
    case Prismatic.Content.create_article(current_user, article_params) do
      {:ok, article} ->
        Logger.info("Article created", 
          article_id: article.id, 
          user_id: current_user.id
        )
        
        conn
        |> put_status(:created)
        |> render(:show, article: article)
        
      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.info("Article validation failed", 
          user_id: current_user.id,
          errors: format_changeset_errors(changeset)
        )
        {:error, changeset}
        
      {:error, :rate_limited} ->
        Logger.warning("Article creation rate limited", user_id: current_user.id)
        {:error, :rate_limited}
        
      {:error, reason} ->
        Logger.error("Article creation failed", 
          user_id: current_user.id,
          params: sanitize_params(article_params),
          reason: reason
        )
        {:error, :internal_error}
    end
  end
  
  defp get_current_user_id(conn) do
    case conn.assigns[:current_user] do
      %{id: id} -> id
      _ -> nil
    end
  end
  
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
  
  defp sanitize_params(params) do
    # Remove sensitive data from logs
    Map.drop(params, ["password", "credit_card", "ssn"])
  end
end
```

### Fallback Controller

Centralize error handling with fallback controllers:

```elixir
defmodule PrismaticWeb.FallbackController do
  use PrismaticWeb, :controller
  
  require Logger
  
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(html: PrismaticWeb.ErrorHTML, json: PrismaticWeb.ErrorJSON)
    |> render(:"404")
  end
  
  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> put_view(html: PrismaticWeb.ErrorHTML, json: PrismaticWeb.ErrorJSON)
    |> render(:"401")
  end
  
  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> put_view(html: PrismaticWeb.ErrorHTML, json: PrismaticWeb.ErrorJSON)
    |> render(:"403")
  end
  
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(html: PrismaticWeb.ChangesetHTML, json: PrismaticWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end
  
  def call(conn, {:error, :rate_limited}) do
    conn
    |> put_status(:too_many_requests)
    |> put_resp_header("retry-after", "60")
    |> put_view(html: PrismaticWeb.ErrorHTML, json: PrismaticWeb.ErrorJSON)
    |> render(:"429")
  end
  
  def call(conn, {:error, :internal_error}) do
    # Log the error but don't expose internal details
    request_id = Logger.metadata()[:request_id] || "unknown"
    
    Logger.error("Internal error in fallback controller", 
      request_id: request_id,
      path: conn.request_path,
      method: conn.method
    )
    
    conn
    |> put_status(:internal_server_error)
    |> put_view(html: PrismaticWeb.ErrorHTML, json: PrismaticWeb.ErrorJSON)
    |> render(:"500")
  end
  
  # Catch-all for unexpected errors
  def call(conn, error) do
    request_id = Logger.metadata()[:request_id] || "unknown"
    
    Logger.error("Unexpected error in fallback controller", 
      error: error,
      request_id: request_id,
      path: conn.request_path,
      method: conn.method
    )
    
    conn
    |> put_status(:internal_server_error)
    |> put_view(html: PrismaticWeb.ErrorHTML, json: PrismaticWeb.ErrorJSON)
    |> render(:"500")
  end
end
```

### Plug Error Handling

Handle errors in plugs with proper logging:

```elixir
defmodule PrismaticWeb.AuthPlug do
  import Plug.Conn
  import Phoenix.Controller
  
  require Logger
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    case get_session(conn, :user_id) do
      nil ->
        handle_unauthenticated(conn)
        
      user_id ->
        case load_user(user_id) do
          {:ok, user} ->
            assign(conn, :current_user, user)
            
          {:error, :not_found} ->
            Logger.warning("User not found in session", user_id: user_id)
            handle_invalid_session(conn)
            
          {:error, :deactivated} ->
            Logger.info("Deactivated user attempted access", user_id: user_id)
            handle_deactivated_user(conn)
            
          {:error, reason} ->
            Logger.error("Error loading user", user_id: user_id, reason: reason)
            handle_auth_error(conn)
        end
    end
  end
  
  defp load_user(user_id) do
    case Prismatic.Accounts.get_user(user_id) do
      nil -> {:error, :not_found}
      %{active: false} = _user -> {:error, :deactivated}
      user -> {:ok, user}
    end
  end
  
  defp handle_unauthenticated(conn) do
    case get_format(conn) do
      "json" ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
        |> halt()
        
      _ ->
        conn
        |> put_flash(:error, "Please log in to continue")
        |> redirect(to: ~p"/login")
        |> halt()
    end
  end
  
  defp handle_invalid_session(conn) do
    conn
    |> clear_session()
    |> handle_unauthenticated()
  end
  
  defp handle_deactivated_user(conn) do
    conn
    |> clear_session()
    |> put_flash(:error, "Your account has been deactivated")
    |> redirect(to: ~p"/")
    |> halt()
  end
  
  defp handle_auth_error(conn) do
    case get_format(conn) do
      "json" ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Authentication system error"})
        |> halt()
        
      _ ->
        conn
        |> put_flash(:error, "Authentication system error. Please try again.")
        |> redirect(to: ~p"/")
        |> halt()
    end
  end
end
```

---

## Custom Error Pages

### User-Friendly Error Pages

Create helpful error pages that guide users:

```elixir
# lib/prismatic_web/controllers/error_html.ex
defmodule PrismaticWeb.ErrorHTML do
  use PrismaticWeb, :html
  
  def render("404.html", assigns) do
    ~H"""
    <div class="error-page">
      <div class="error-container">
        <div class="error-code">404</div>
        <div class="error-title">Page Not Found</div>
        <div class="error-message">
          The page you're looking for doesn't exist or has been moved.
        </div>
        
        <div class="error-actions">
          <.link navigate={~p"/"} class="btn btn-primary">
            Go Home
          </.link>
          
          <.link navigate={~p"/search"} class="btn btn-secondary">
            Search
          </.link>
          
          <button onclick="history.back()" class="btn btn-secondary">
            Go Back
          </button>
        </div>
        
        <div class="error-help">
          <p>If you believe this is an error, please <.link navigate={~p"/contact"}>contact support</.link>.</p>
        </div>
      </div>
    </div>
    """
  end
  
  def render("500.html", assigns) do
    request_id = assigns[:request_id] || "unknown"
    
    ~H"""
    <div class="error-page">
      <div class="error-container">
        <div class="error-code">500</div>
        <div class="error-title">Something Went Wrong</div>
        <div class="error-message">
          We're experiencing technical difficulties. Our team has been notified.
        </div>
        
        <div class="error-actions">
          <.link navigate={~p"/"} class="btn btn-primary">
            Go Home
          </.link>
          
          <button onclick="location.reload()" class="btn btn-secondary">
            Try Again
          </button>
        </div>
        
        <div class="error-help">
          <p>
            If the problem persists, please <.link navigate={~p"/contact"}>contact support</.link>
            and include this reference ID: <code class="request-id"><%= request_id %></code>
          </p>
        </div>
      </div>
    </div>
    """
  end
  
  def render("401.html", assigns) do
    ~H"""
    <div class="error-page">
      <div class="error-container">
        <div class="error-code">401</div>
        <div class="error-title">Access Denied</div>
        <div class="error-message">
          You need to log in to access this page.
        </div>
        
        <div class="error-actions">
          <.link navigate={~p"/login"} class="btn btn-primary">
            Log In
          </.link>
          
          <.link navigate={~p"/register"} class="btn btn-secondary">
            Sign Up
          </.link>
        </div>
      </div>
    </div>
    """
  end
end
```

### JSON Error Responses

Provide consistent JSON error responses for APIs:

```elixir
defmodule PrismaticWeb.ErrorJSON do
  def render("404.json", _assigns) do
    %{
      error: %{
        code: "not_found",
        message: "The requested resource was not found",
        details: %{}
      }
    }
  end
  
  def render("401.json", _assigns) do
    %{
      error: %{
        code: "unauthorized",
        message: "Authentication is required to access this resource",
        details: %{}
      }
    }
  end
  
  def render("403.json", _assigns) do
    %{
      error: %{
        code: "forbidden",
        message: "You don't have permission to access this resource",
        details: %{}
      }
    }
  end
  
  def render("429.json", _assigns) do
    %{
      error: %{
        code: "rate_limited",
        message: "Too many requests. Please slow down.",
        details: %{
          retry_after: 60
        }
      }
    }
  end
  
  def render("500.json", assigns) do
    request_id = assigns[:request_id] || "unknown"
    
    %{
      error: %{
        code: "internal_error",
        message: "An unexpected error occurred",
        details: %{
          request_id: request_id
        }
      }
    }
  end
end

defmodule PrismaticWeb.ChangesetJSON do
  def render("error.json", %{changeset: changeset}) do
    %{
      error: %{
        code: "validation_failed",
        message: "The request data failed validation",
        details: format_errors(changeset)
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

---

## Structured Logging

### Logger Configuration

Configure structured logging for production observability:

```elixir
# config/config.exs
import Config

config :logger,
  backends: [:console],
  level: :info,
  metadata: [:request_id, :user_id, :session_id]

# config/dev.exs
config :logger,
  level: :debug,
  format: "$time $metadata[$level] $message\n"

# config/prod.exs
config :logger,
  level: :info,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id, :user_id, :session_id, :module, :function, :line]

# For production JSON logging
config :logger_json,
  level: :info,
  metadata: [:request_id, :user_id, :session_id, :module, :function, :line]
```

### Application-Level Logging

Implement consistent logging patterns across the application:

```elixir
defmodule Prismatic.LoggingHelpers do
  @moduledoc """
  Helper functions for consistent application logging.
  """
  
  require Logger
  
  @doc """
  Logs user actions with consistent metadata.
  """
  def log_user_action(user, action, resource, metadata \\ %{}) do
    Logger.info("User action performed", [
      user_id: user.id,
      action: action,
      resource: resource,
      timestamp: DateTime.utc_now()
    ] ++ Map.to_list(metadata))
  end
  
  @doc """
  Logs security events with appropriate severity.
  """
  def log_security_event(event_type, severity, details \\ %{}) do
    log_level = case severity do
      :low -> :info
      :medium -> :warning
      :high -> :error
      :critical -> :error
    end
    
    Logger.log(log_level, "Security event detected", [
      event_type: event_type,
      severity: severity,
      timestamp: DateTime.utc_now()
    ] ++ Map.to_list(details))
  end
  
  @doc """
  Logs performance metrics for monitoring.
  """
  def log_performance(operation, duration_ms, metadata \\ %{}) do
    Logger.info("Performance metric", [
      operation: operation,
      duration_ms: duration_ms,
      timestamp: DateTime.utc_now()
    ] ++ Map.to_list(metadata))
  end
  
  @doc """
  Logs business events for analytics and audit trails.
  """
  def log_business_event(event, entity_type, entity_id, metadata \\ %{}) do
    Logger.info("Business event", [
      event: event,
      entity_type: entity_type,
      entity_id: entity_id,
      timestamp: DateTime.utc_now()
    ] ++ Map.to_list(metadata))
  end
end
```

### Context-Aware Logging

Add context to logs throughout request processing:

```elixir
defmodule PrismaticWeb.LoggingPlug do
  import Plug.Conn
  require Logger
  
  def init(opts), do: opts
  
  def call(conn, _opts) do
    request_id = get_req_header(conn, "x-request-id") 
                 |> List.first() 
                 || Ecto.UUID.generate()
    
    user_id = case conn.assigns[:current_user] do
      %{id: id} -> id
      _ -> nil
    end
    
    session_id = get_session(conn, :session_id)
    
    Logger.metadata(
      request_id: request_id,
      user_id: user_id,
      session_id: session_id
    )
    
    start_time = System.monotonic_time()
    
    conn = put_resp_header(conn, "x-request-id", request_id)
    
    register_before_send(conn, fn conn ->
      end_time = System.monotonic_time()
      duration = System.convert_time_unit(end_time - start_time, :native, :microsecond)
      
      Logger.info("Request completed", [
        method: conn.method,
        path: conn.request_path,
        status: conn.status,
        duration_μs: duration,
        user_agent: get_req_header(conn, "user-agent") |> List.first()
      ])
      
      conn
    end)
  end
end
```

### Business Logic Logging

Log important business events for audit trails:

```elixir
defmodule Prismatic.Content do
  require Logger
  alias Prismatic.LoggingHelpers
  
  def create_article(user, attrs) do
    case do_create_article(user, attrs) do
      {:ok, article} = result ->
        LoggingHelpers.log_user_action(user, :create, :article, %{
          article_id: article.id,
          title: article.title,
          status: article.status
        })
        
        LoggingHelpers.log_business_event(:article_created, :article, article.id, %{
          author_id: user.id,
          status: article.status,
          word_count: count_words(article.content)
        })
        
        result
        
      {:error, changeset} = error ->
        Logger.warning("Article creation failed", [
          user_id: user.id,
          errors: format_changeset_errors(changeset),
          attempted_title: attrs["title"]
        ])
        
        error
    end
  end
  
  def update_article(article, attrs) do
    old_status = article.status
    
    case do_update_article(article, attrs) do
      {:ok, updated_article} = result ->
        LoggingHelpers.log_user_action(article.author, :update, :article, %{
          article_id: article.id,
          title: updated_article.title,
          status_changed: old_status != updated_article.status
        })
        
        if old_status != updated_article.status do
          LoggingHelpers.log_business_event(:article_status_changed, :article, article.id, %{
            old_status: old_status,
            new_status: updated_article.status,
            author_id: article.author_id
          })
        end
        
        result
        
      error ->
        Logger.warning("Article update failed", [
          article_id: article.id,
          author_id: article.author_id,
          error: error
        ])
        
        error
    end
  end
  
  def delete_article(article) do
    case do_delete_article(article) do
      {:ok, deleted_article} = result ->
        LoggingHelpers.log_user_action(article.author, :delete, :article, %{
          article_id: article.id,
          title: article.title
        })
        
        LoggingHelpers.log_business_event(:article_deleted, :article, article.id, %{
          author_id: article.author_id,
          title: article.title,
          status: article.status
        })
        
        result
        
      error ->
        Logger.error("Article deletion failed", [
          article_id: article.id,
          author_id: article.author_id,
          error: error
        ])
        
        error
    end
  end
end
```

---

## Error Monitoring and Alerting

### External Error Tracking

Integrate with error tracking services:

```elixir
# Add to mix.exs
defp deps do
  [
    {:sentry, "~> 8.0"},
    {:honeybadger, "~> 0.15"}
  ]
end

# config/config.exs
config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: Mix.env(),
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  tags: %{
    env: System.get_env("DEPLOYMENT_ENV", "unknown")
  },
  included_environments: [:prod, :staging]

# Custom error reporter
defmodule Prismatic.ErrorReporter do
  require Logger
  
  def report_error(kind, reason, stacktrace, metadata \\ %{}) do
    # Log locally first
    Logger.error("Application error", [
      kind: kind,
      reason: inspect(reason),
      stacktrace: Exception.format_stacktrace(stacktrace),
      metadata: metadata
    ])
    
    # Report to external service
    case Mix.env() do
      env when env in [:prod, :staging] ->
        Sentry.capture_exception(reason,
          stacktrace: stacktrace,
          tags: Map.merge(%{kind: kind}, metadata),
          extra: %{
            environment: env,
            timestamp: DateTime.utc_now()
          }
        )
        
      _ ->
        :ok  # Don't report in development/test
    end
  end
  
  def report_message(level, message, metadata \\ %{}) do
    Logger.log(level, message, Map.to_list(metadata))
    
    if level in [:error, :warn] and Mix.env() in [:prod, :staging] do
      Sentry.capture_message(message,
        level: level,
        tags: metadata,
        extra: %{
          environment: Mix.env(),
          timestamp: DateTime.utc_now()
        }
      )
    end
  end
end
```

### Custom Telemetry Events

Create custom telemetry events for monitoring:

```elixir
defmodule Prismatic.Telemetry do
  @moduledoc """
  Custom telemetry events for application monitoring.
  """
  
  def error_occurred(error_type, details \\ %{}) do
    :telemetry.execute(
      [:prismatic, :error],
      %{count: 1},
      %{
        error_type: error_type,
        timestamp: System.system_time(:second)
      } |> Map.merge(details)
    )
  end
  
  def user_action(action, user_id, details \\ %{}) do
    :telemetry.execute(
      [:prismatic, :user_action],
      %{count: 1},
      %{
        action: action,
        user_id: user_id,
        timestamp: System.system_time(:second)
      } |> Map.merge(details)
    )
  end
  
  def performance_metric(operation, duration, details \\ %{}) do
    :telemetry.execute(
      [:prismatic, :performance],
      %{duration: duration},
      %{
        operation: operation,
        timestamp: System.system_time(:second)
      } |> Map.merge(details)
    )
  end
end

# Usage in application code
defmodule Prismatic.Content do
  alias Prismatic.Telemetry
  
  def create_article(user, attrs) do
    start_time = System.monotonic_time()
    
    result = do_create_article(user, attrs)
    
    end_time = System.monotonic_time()
    duration = System.convert_time_unit(end_time - start_time, :native, :millisecond)
    
    case result do
      {:ok, article} ->
        Telemetry.user_action(:create_article, user.id, %{article_id: article.id})
        Telemetry.performance_metric(:create_article, duration, %{success: true})
        
      {:error, reason} ->
        Telemetry.error_occurred(:article_creation_failed, %{
          user_id: user.id,
          reason: reason
        })
        Telemetry.performance_metric(:create_article, duration, %{success: false})
    end
    
    result
  end
end
```

---

## Recovery Strategies

### Circuit Breaker Pattern

Implement circuit breakers for external service calls:

```elixir
defmodule Prismatic.CircuitBreaker do
  use GenServer
  require Logger
  
  defstruct [
    :name,
    :failure_threshold,
    :recovery_timeout,
    :failure_count,
    :state,
    :last_failure_time
  ]
  
  @states [:closed, :open, :half_open]
  
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(name))
  end
  
  def call(circuit_name, fun) when is_function(fun, 0) do
    GenServer.call(via_tuple(circuit_name), {:call, fun})
  end
  
  def init(opts) do
    state = %__MODULE__{
      name: Keyword.fetch!(opts, :name),
      failure_threshold: Keyword.get(opts, :failure_threshold, 5),
      recovery_timeout: Keyword.get(opts, :recovery_timeout, 30_000),
      failure_count: 0,
      state: :closed,
      last_failure_time: nil
    }
    
    {:ok, state}
  end
  
  def handle_call({:call, fun}, _from, %{state: :open} = state) do
    if should_attempt_reset?(state) do
      # Try half-open state
      new_state = %{state | state: :half_open}
      execute_call(fun, new_state)
    else
      {:reply, {:error, :circuit_open}, state}
    end
  end
  
  def handle_call({:call, fun}, _from, state) do
    execute_call(fun, state)
  end
  
  defp execute_call(fun, state) do
    try do
      result = fun.()
      handle_success(result, state)
    rescue
      error ->
        handle_failure(error, state)
    catch
      :exit, reason ->
        handle_failure(reason, state)
    end
  end
  
  defp handle_success(result, %{state: :half_open} = state) do
    Logger.info("Circuit breaker recovery successful", name: state.name)
    new_state = %{state | state: :closed, failure_count: 0}
    {:reply, {:ok, result}, new_state}
  end
  
  defp handle_success(result, state) do
    {:reply, {:ok, result}, state}
  end
  
  defp handle_failure(error, state) do
    new_failure_count = state.failure_count + 1
    
    Logger.warning("Circuit breaker failure", 
      name: state.name,
      failure_count: new_failure_count,
      error: inspect(error)
    )
    
    if new_failure_count >= state.failure_threshold do
      Logger.error("Circuit breaker opened", 
        name: state.name,
        failure_count: new_failure_count
      )
      
      new_state = %{state | 
        state: :open, 
        failure_count: new_failure_count,
        last_failure_time: System.monotonic_time(:millisecond)
      }
      
      {:reply, {:error, error}, new_state}
    else
      new_state = %{state | failure_count: new_failure_count}
      {:reply, {:error, error}, new_state}
    end
  end
  
  defp should_attempt_reset?(%{last_failure_time: last_failure, recovery_timeout: timeout}) do
    System.monotonic_time(:millisecond) - last_failure > timeout
  end
  
  defp via_tuple(name) do
    {:via, Registry, {Prismatic.CircuitBreakerRegistry, name}}
  end
end

# Usage example
defmodule Prismatic.ExternalApi do
  def fetch_data(id) do
    Prismatic.CircuitBreaker.call(:external_api, fn ->
      HTTPoison.get!("https://api.example.com/data/#{id}")
    end)
  end
end
```

### Retry Strategies

Implement exponential backoff for transient failures:

```elixir
defmodule Prismatic.Retry do
  require Logger
  
  @doc """
  Retries a function with exponential backoff.
  
  Options:
  - `:max_retries` - Maximum number of retry attempts (default: 3)
  - `:base_delay` - Base delay in milliseconds (default: 1000)
  - `:max_delay` - Maximum delay in milliseconds (default: 30000)
  - `:backoff_factor` - Multiplier for exponential backoff (default: 2)
  - `:jitter` - Add random jitter to prevent thundering herd (default: true)
  """
  def with_exponential_backoff(fun, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, 3)
    base_delay = Keyword.get(opts, :base_delay, 1000)
    max_delay = Keyword.get(opts, :max_delay, 30_000)
    backoff_factor = Keyword.get(opts, :backoff_factor, 2)
    jitter = Keyword.get(opts, :jitter, true)
    
    do_retry(fun, 0, max_retries, base_delay, max_delay, backoff_factor, jitter)
  end
  
  defp do_retry(fun, attempt, max_retries, base_delay, max_delay, backoff_factor, jitter) do
    try do
      result = fun.()
      {:ok, result}
    rescue
      error ->
        if attempt < max_retries and retryable_error?(error) do
          delay = calculate_delay(attempt, base_delay, max_delay, backoff_factor, jitter)
          
          Logger.warning("Retrying after error", 
            attempt: attempt + 1,
            max_retries: max_retries,
            delay_ms: delay,
            error: inspect(error)
          )
          
          Process.sleep(delay)
          do_retry(fun, attempt + 1, max_retries, base_delay, max_delay, backoff_factor, jitter)
        else
          Logger.error("Max retries exceeded", 
            attempts: attempt + 1,
            error: inspect(error)
          )
          {:error, error}
        end
    end
  end
  
  defp calculate_delay(attempt, base_delay, max_delay, backoff_factor, jitter) do
    delay = base_delay * :math.pow(backoff_factor, attempt)
    delay = min(delay, max_delay)
    
    if jitter do
      # Add up to 25% jitter
      jitter_amount = delay * 0.25 * :rand.uniform()
      round(delay + jitter_amount)
    else
      round(delay)
    end
  end
  
  defp retryable_error?(%HTTPoison.Error{reason: :timeout}), do: true
  defp retryable_error?(%HTTPoison.Error{reason: :connect_timeout}), do: true
  defp retryable_error?(%HTTPoison.Error{reason: :closed}), do: true
  defp retryable_error?(%HTTPoison.Error{reason: :econnrefused}), do: true
  defp retryable_error?(_), do: false
end

# Usage example
defmodule Prismatic.ExternalService do
  alias Prismatic.Retry
  
  def fetch_user_profile(user_id) do
    Retry.with_exponential_backoff(fn ->
      case HTTPoison.get("https://api.example.com/users/#{user_id}") do
        {:ok, %{status_code: 200, body: body}} ->
          Jason.decode!(body)
          
        {:ok, %{status_code: status}} when status >= 500 ->
          raise "Server error: #{status}"
          
        {:ok, %{status_code: 404}} ->
          {:error, :not_found}
          
        {:error, reason} ->
          raise "HTTP error: #{inspect(reason)}"
      end
    end, max_retries: 3, base_delay: 1000)
  end
end
```

---

## Testing Error Scenarios

### Unit Testing Error Paths

Test error handling thoroughly:

```elixir
defmodule Prismatic.ContentTest do
  use Prismatic.DataCase, async: true
  
  alias Prismatic.Content
  
  describe "create_article/2 error handling" do
    test "returns changeset error for invalid data" do
      user = user_fixture()
      invalid_attrs = %{title: "", content: ""}
      
      assert {:error, %Ecto.Changeset{} = changeset} = Content.create_article(user, invalid_attrs)
      assert %{title: ["can't be blank"], content: ["can't be blank"]} = errors_on(changeset)
    end
    
    test "handles database connection errors gracefully" do
      user = user_fixture()
      valid_attrs = %{title: "Test", content: "Content"}
      
      # Simulate database error
      expect(Prismatic.Repo.Mock, :insert, fn _ ->
        {:error, %Postgrex.Error{message: "connection lost"}}
      end)
      
      assert {:error, :database_error} = Content.create_article(user, valid_attrs)
    end
    
    test "enforces rate limiting" do
      user = user_fixture()
      valid_attrs = %{title: "Test", content: "Content"}
      
      # Simulate rate limit exceeded
      expect(Prismatic.RateLimit.Mock, :check_limit, fn _, _ ->
        :error
      end)
      
      assert {:error, :rate_limited} = Content.create_article(user, valid_attrs)
    end
  end
  
  describe "error logging" do
    test "logs validation errors with appropriate level" do
      user = user_fixture()
      invalid_attrs = %{title: "", content: ""}
      
      log = capture_log(fn ->
        Content.create_article(user, invalid_attrs)
      end)
      
      assert log =~ "Article validation failed"
      assert log =~ "user_id: #{user.id}"
    end
    
    test "logs unexpected errors with error level" do
      user = user_fixture()
      valid_attrs = %{title: "Test", content: "Content"}
      
      # Simulate unexpected error
      expect(Prismatic.Content.Mock, :do_create_article, fn _, _ ->
        raise "Unexpected error"
      end)
      
      log = capture_log([level: :error], fn ->
        Content.create_article(user, valid_attrs)
      end)
      
      assert log =~ "[error]"
      assert log =~ "Unexpected error"
    end
  end
end
```

### Integration Testing Error Scenarios

Test error handling across system boundaries:

```elixir
defmodule Prismatic.OrderProcessingTest do
  use Prismatic.DataCase
  
  import Mox
  alias Prismatic.Orders
  
  setup :verify_on_exit!
  
  describe "order processing error scenarios" do
    test "handles payment service unavailable" do
      user = user_fixture()
      order_params = valid_order_params()
      
      # Mock payment service failure
      expect(Prismatic.PaymentService.Mock, :charge_card, fn _, _ ->
        {:error, :service_unavailable}
      end)
      
      log = capture_log([level: :warning], fn ->
        assert {:error, :payment_service_unavailable} = Orders.process_order(user, order_params)
      end)
      
      assert log =~ "Payment service unavailable"
      assert log =~ "user_id: #{user.id}"
      
      # Verify no side effects occurred
      assert Orders.list_orders_for_user(user) == []
    end
    
    test "handles inventory service timeout with retry" do
      user = user_fixture()
      order_params = valid_order_params()
      
      # First two calls timeout, third succeeds
      expect(Prismatic.InventoryService.Mock, :reserve_items, 3, fn _ ->
        case call_count() do
          count when count < 3 -> {:error, :timeout}
          _ -> {:ok, %{reservation_id: "res_123"}}
        end
      end)
      
      expect(Prismatic.PaymentService.Mock, :charge_card, fn _, _ ->
        {:ok, %{transaction_id: "txn_123"}}
      end)
      
      log = capture_log(fn ->
        assert {:ok, order} = Orders.process_order(user, order_params)
        assert order.status == :confirmed
      end)
      
      assert log =~ "Retrying after error"
      assert log =~ "attempt: 1"
      assert log =~ "attempt: 2"
    end
  end
end
```

---

## Performance Impact

### Logging Performance Considerations

Optimize logging for production performance:

```elixir
defmodule Prismatic.PerformantLogging do
  require Logger
  
  @doc """
  Conditionally logs based on configured level to avoid expensive operations.
  """
  def debug_with_computation(message_fun) when is_function(message_fun, 0) do
    if Logger.compare_levels(:debug, Logger.level()) != :lt do
      Logger.debug(message_fun.())
    end
  end
  
  @doc """
  Logs with lazy evaluation of expensive metadata.
  """
  def log_with_lazy_metadata(level, message, lazy_metadata) when is_function(lazy_metadata, 0) do
    if Logger.compare_levels(level, Logger.level()) != :lt do
      Logger.log(level, message, lazy_metadata.())
    end
  end
  
  @doc """
  Samples logs to reduce volume in high-traffic scenarios.
  """
  def sampled_log(level, message, metadata, sample_rate \\ 0.1) do
    if :rand.uniform() <= sample_rate do
      Logger.log(level, message, metadata)
    end
  end
end

# Usage examples
defmodule Prismatic.Content do
  alias Prismatic.PerformantLogging
  
  def process_large_dataset(data) do
    # Only compute expensive debug info if debug logging is enabled
    PerformantLogging.debug_with_computation(fn ->
      "Processing dataset with #{length(data)} items: #{inspect(data, limit: 10)}"
    end)
    
    # Sample logs in high-volume operations
    PerformantLogging.sampled_log(:info, "Dataset processed", 
      [item_count: length(data)], 0.1)
    
    do_process(data)
  end
end
```

### Error Handling Performance

Optimize error handling paths:

```elixir
defmodule Prismatic.OptimizedErrorHandling do
  @doc """
  Use pattern matching instead of try/catch when possible for better performance.
  """
  def parse_json_optimized(json_string) do
    case Jason.decode(json_string) do
      {:ok, data} -> {:ok, data}
      {:error, %Jason.DecodeError{}} -> {:error, :invalid_json}
    end
  end
  
  # Avoid try/catch when not necessary
  def parse_json_slow(json_string) do
    try do
      {:ok, Jason.decode!(json_string)}
    rescue
      Jason.DecodeError -> {:error, :invalid_json}
    end
  end
  
  @doc """
  Use early returns to avoid deep nesting in error handling.
  """
  def process_request_optimized(params) do
    with {:ok, validated} <- validate_params(params),
         {:ok, processed} <- process_data(validated),
         {:ok, result} <- save_result(processed) do
      {:ok, result}
    else
      error -> error  # Early return, no additional processing
    end
  end
end
```

---

## Production Best Practices

### Log Rotation and Management

Configure log rotation for production:

```bash
# /etc/logrotate.d/prismatic
/var/log/prismatic/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 prismatic prismatic
    postrotate
        systemctl reload prismatic
    endscript
}
```

### Error Alerting Configuration

Set up intelligent alerting:

```elixir
defmodule Prismatic.AlertingRules do
  @moduledoc """
  Define alerting rules for different error scenarios.
  """
  
  @error_thresholds %{
    # Alert if error rate exceeds 5% over 5 minutes
    high_error_rate: %{threshold: 0.05, window: 300},
    
    # Alert if any critical errors occur
    critical_errors: %{threshold: 1, window: 60},
    
    # Alert if response time exceeds 2 seconds for 90th percentile
    slow_responses: %{threshold: 2000, window: 300}
  }
  
  def should_alert?(metric_type, current_value, window_duration) do
    case Map.get(@error_thresholds, metric_type) do
      %{threshold: threshold, window: required_window} when window_duration >= required_window ->
        current_value >= threshold
        
      _ ->
        false
    end
  end
end
```

### Health Checks

Implement comprehensive health checks:

```elixir
defmodule PrismaticWeb.HealthController do
  use PrismaticWeb, :controller
  
  def check(conn, _params) do
    checks = [
      database: check_database(),
      redis: check_redis(),
      external_services: check_external_services(),
      disk_space: check_disk_space(),
      memory: check_memory_usage()
    ]
    
    all_healthy = Enum.all?(checks, fn {_, status} -> status == :ok end)
    
    status_code = if all_healthy, do: 200, else: 503
    
    response = %{
      status: if(all_healthy, do: "healthy", else: "unhealthy"),
      timestamp: DateTime.utc_now(),
      checks: Enum.into(checks, %{})
    }
    
    conn
    |> put_status(status_code)
    |> json(response)
  end
  
  defp check_database do
    try do
      Ecto.Adapters.SQL.query!(Prismatic.Repo, "SELECT 1", [])
      :ok
    rescue
      _ -> :error
    end
  end
  
  defp check_redis do
    try do
      Redix.command!(Prismatic.Redis, ["PING"])
      :ok
    rescue
      _ -> :error
    end
  end
  
  defp check_external_services do
    # Check critical external services
    case HTTPoison.get("https://api.external.com/health", [], timeout: 2000) do
      {:ok, %{status_code: 200}} -> :ok
      _ -> :error
    end
  end
  
  defp check_disk_space do
    case System.cmd("df", ["-h", "/"]) do
      {output, 0} ->
        # Parse disk usage, alert if > 90%
        if disk_usage_percent(output) > 90, do: :error, else: :ok
      _ ->
        :error
    end
  end
  
  defp check_memory_usage do
    memory_info = :erlang.memory()
    total_memory = memory_info[:total]
    
    # Alert if using more than 80% of available memory
    if total_memory > get_memory_limit() * 0.8, do: :error, else: :ok
  end
end
```

---

## Common Anti-Patterns

### 1. Swallowing Errors

```elixir
# ❌ Avoid - Hiding errors without proper handling
def risky_operation(data) do
  try do
    dangerous_operation(data)
    :ok
  rescue
    _ -> :ok  # Silently ignores all errors
  end
end

# ✅ Better - Explicit error handling with logging
def risky_operation(data) do
  case safe_dangerous_operation(data) do
    :ok -> :ok
    {:error, reason} = error ->
      Logger.warning("Dangerous operation failed", 
        reason: reason, 
        data: sanitize_data(data)
      )
      error
  end
end
```

### 2. Generic Error Messages

```elixir
# ❌ Avoid - Vague error messages
def process_user_data(data) do
  case validate_data(data) do
    :ok -> :ok
    _ -> {:error, "Something went wrong"}
  end
end

# ✅ Better - Specific, actionable error messages
def process_user_data(data) do
  case validate_data(data) do
    :ok -> :ok
    {:error, :missing_email} -> {:error, "Email address is required"}
    {:error, :invalid_email} -> {:error, "Email address format is invalid"}
    {:error, :duplicate_email} -> {:error, "Email address is already registered"}
  end
end
```

### 3. Inconsistent Logging Levels

```elixir
# ❌ Avoid - Incorrect log levels
def important_business_operation(data) do
  Logger.debug("Critical business operation failed")  # Wrong level
  Logger.error("User logged in")  # Wrong level
end

# ✅ Better - Appropriate log levels
def important_business_operation(data) do
  Logger.error("Critical business operation failed")  # Error level for failures
  Logger.info("User logged in")  # Info level for normal events
end
```

---

## Troubleshooting

### Common Issues

#### Log Volume Too High

**Problem**: Excessive logging impacting performance

**Solutions**:
```elixir
# Use sampling for high-volume operations
def log_high_volume_event(data) do
  if rem(System.unique_integer([:positive]), 100) == 0 do  # 1% sampling
    Logger.info("High volume event", data: data)
  end
end

# Configure appropriate log levels
config :logger, level: :info  # Don't log debug in production

# Use structured logging with proper metadata
Logger.info("User action", user_id: user.id, action: :login)
```

#### Missing Error Context

**Problem**: Errors lack sufficient context for debugging

**Solutions**:
```elixir
# Add request ID to all logs
Logger.metadata(request_id: get_request_id())

# Include relevant business context
Logger.error("Order processing failed", 
  order_id: order.id,
  user_id: user.id,
  payment_method: order.payment_method,
  amount: order.total
)
```

#### Inconsistent Error Formats

**Problem**: Different error formats across the application

**Solutions**:
```elixir
# Use standardized error response module
defmodule Prismatic.ErrorResponse do
  def build_error(code, message, details \\ %{}) do
    %{
      error: %{
        code: code,
        message: message,
        details: details,
        timestamp: DateTime.utc_now()
      }
    }
  end
end
```

### Debugging Tools

#### Log Analysis

```bash
# Filter logs by error level
grep "ERROR" /var/log/prismatic/app.log

# Find specific request ID
grep "request_id=abc123" /var/log/prismatic/app.log

# Count error types
grep "ERROR" /var/log/prismatic/app.log | cut -d' ' -f5 | sort | uniq -c
```

#### Error Pattern Detection

```elixir
defmodule Prismatic.ErrorAnalysis do
  @doc """
  Analyzes error patterns from log files.
  """
  def analyze_error_patterns(log_file) do
    File.stream!(log_file)
    |> Stream.filter(&String.contains?(&1, "ERROR"))
    |> Stream.map(&extract_error_info/1)
    |> Enum.group_by(& &1.error_type)
    |> Enum.map(fn {type, errors} ->
      {type, %{count: length(errors), recent: List.first(errors)}}
    end)
    |> Enum.into(%{})
  end
  
  defp extract_error_info(log_line) do
    # Parse log line and extract error information
    %{
      error_type: "parsed_error_type",
      timestamp: "parsed_timestamp",
      details: "parsed_details"
    }
  end
end
```

---

## Related Documentation

- **[Testing Strategy](testing-strategy.md)** - Testing error scenarios and edge cases thoroughly
- **[API Design Guidelines](api-design-guidelines.md)** - API error handling patterns and status codes
- **[Coding Standards](coding-standards.md)** - Code quality standards that support error handling
- **[Performance Optimization](../performance/performance-optimization.md)** - Performance monitoring and error impact analysis
- **[Security Guidelines](../security/security-guidelines.md)** - Security-related error handling and logging
- **[Deployment Procedures](../deployment/deployment-procedures.md)** - Production error monitoring and incident response

---

**💡 Pro Tip**: Design your error handling strategy before you need it. Consistent error patterns, comprehensive logging, and proactive monitoring will save countless hours during debugging and incident response. Remember that good error handling is about more than just catching exceptions - it's about creating systems that fail gracefully and provide clear paths to resolution.