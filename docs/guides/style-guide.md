# Style Guide

Comprehensive coding standards and style guidelines for the Prismatic project, covering Elixir, JavaScript/TypeScript, documentation, and general development practices.

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > [Guides](README.md) > Style Guide

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to guides index
- **🏠 [Documentation Home](../README.md)** - Main documentation index
- **🔍 [Search Documentation](../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Git Hooks Setup](git-hooks-setup.md) - Automated style enforcement
- [Semantic Versioning](semantic-versioning.md) - Version and release standards
- [CI/CD Configuration](../operations/cicd-configuration.md) - Automated style checking
- [Security Guidelines](security-guidelines.md) - Security-related coding practices
- [Performance Optimization](performance-optimization.md) - Performance-conscious coding
<!-- NAV_END -->

## Overview

This style guide establishes consistent coding standards across the Prismatic project to ensure maintainability, readability, and team collaboration. It covers language-specific conventions, documentation standards, naming conventions, and architectural patterns.

## General Principles

### Code Quality Standards

1. **Readability First** - Code should be self-documenting and easily understood
2. **Consistency** - Follow established patterns throughout the codebase
3. **Simplicity** - Prefer simple, straightforward solutions over complex ones
4. **Performance Awareness** - Consider performance implications of coding choices
5. **Security Mindset** - Always consider security implications
6. **Testability** - Write code that is easy to test and debug

### File Organization

```
lib/
├── prismatic/              # Main application namespace
│   ├── accounts/           # Domain-specific modules
│   │   ├── user.ex
│   │   ├── user_token.ex
│   │   └── accounts.ex     # Context module
│   ├── core/               # Core business logic
│   └── utils/              # Utility modules
├── prismatic_web/          # Web interface
│   ├── controllers/
│   ├── views/
│   ├── templates/
│   └── channels/
└── prismatic.ex            # Application module
```

## Elixir Style Guide

### Module Organization

#### Module Structure
```elixir
defmodule Prismatic.Accounts.User do
  @moduledoc """
  User schema and associated functions.
  
  This module represents a user in the system and provides
  functions for user management and validation.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  alias Prismatic.Accounts.{User, UserToken}
  alias Prismatic.Core.Encryption
  
  # Schema definition
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :email, :string
    field :name, :string
    field :password, :string, virtual: true, redact: true
    field :hashed_password, :string, redact: true
    field :role, Ecto.Enum, values: [:admin, :user, :viewer]
    field :confirmed_at, :naive_datetime
    
    has_many :tokens, UserToken
    
    timestamps()
  end
  
  # Public API functions
  
  # Private helper functions
end
```

#### Documentation Standards
```elixir
@doc """
Creates a user registration changeset.

## Examples

    iex> changeset = User.registration_changeset(%User{}, %{email: "test@example.com"})
    iex> changeset.valid?
    true

## Parameters

- `user` - The user struct (usually %User{})
- `attrs` - Map of user attributes

## Returns

- `%Ecto.Changeset{}` - The changeset for validation
"""
@spec registration_changeset(t(), map()) :: Ecto.Changeset.t()
def registration_changeset(user, attrs) do
  # Implementation
end
```

### Naming Conventions

#### Modules and Functions
```elixir
# ✅ Good - Clear, descriptive names
defmodule Prismatic.Accounts.UserRegistration do
  def create_user_with_confirmation(attrs) do
    # Implementation
  end
  
  def send_confirmation_email(user) do
    # Implementation
  end
end

# ❌ Bad - Unclear, abbreviated names
defmodule Prismatic.Acc.UsrReg do
  def create_usr(attrs), do: nil
  def send_email(usr), do: nil
end
```

#### Variables and Atoms
```elixir
# ✅ Good - Descriptive variable names
def process_user_registration(user_params) do
  registration_changeset = User.registration_changeset(%User{}, user_params)
  confirmation_token = generate_confirmation_token()
  
  with {:ok, user} <- Repo.insert(registration_changeset),
       {:ok, _token} <- create_confirmation_token(user, confirmation_token) do
    {:ok, user}
  end
end

# ❌ Bad - Unclear abbreviations
def process_reg(params) do
  cs = User.reg_cs(%User{}, params)
  tok = gen_tok()
  # ...
end
```

### Pattern Matching and Guards

#### Effective Pattern Matching
```elixir
# ✅ Good - Clear pattern matching
def handle_user_creation(result) do
  case result do
    {:ok, %User{confirmed_at: nil} = user} ->
      send_confirmation_email(user)
      {:ok, user}
    
    {:ok, %User{} = user} ->
      {:ok, user}
    
    {:error, %Ecto.Changeset{} = changeset} ->
      {:error, changeset}
    
    {:error, reason} ->
      {:error, reason}
  end
end

# ✅ Good - Guard clauses for validation
def calculate_user_score(user) when is_struct(user, User) do
  case user.role do
    :admin -> 100
    :user -> 50
    :viewer -> 10
  end
end

def calculate_user_score(_), do: {:error, :invalid_user}
```

#### Function Heads and Guards
```elixir
# ✅ Good - Multiple function heads with guards
def format_timestamp(timestamp) when is_nil(timestamp), do: "Never"

def format_timestamp(%NaiveDateTime{} = timestamp) do
  Calendar.strftime(timestamp, "%Y-%m-%d %H:%M")
end

def format_timestamp(%DateTime{} = timestamp) do
  timestamp
  |> DateTime.to_naive()
  |> format_timestamp()
end

def format_timestamp(_), do: {:error, :invalid_timestamp}
```

### Error Handling

#### Consistent Error Patterns
```elixir
# ✅ Good - Consistent error handling
defmodule Prismatic.Accounts do
  def create_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, user} -> {:ok, user}
      {:error, changeset} -> {:error, changeset}
    end
  end
  
  def get_user(id) when is_binary(id) do
    case Repo.get(User, id) do
      %User{} = user -> {:ok, user}
      nil -> {:error, :not_found}
    end
  end
  
  def get_user(_), do: {:error, :invalid_id}
end

# ✅ Good - With clause for complex operations
def register_user_with_profile(user_attrs, profile_attrs) do
  Multi.new()
  |> Multi.insert(:user, User.registration_changeset(%User{}, user_attrs))
  |> Multi.insert(:profile, fn %{user: user} ->
    Profile.changeset(%Profile{user_id: user.id}, profile_attrs)
  end)
  |> Repo.transaction()
  |> case do
    {:ok, %{user: user, profile: profile}} ->
      {:ok, %{user: user, profile: profile}}
    
    {:error, :user, changeset, _changes} ->
      {:error, :user_creation_failed, changeset}
    
    {:error, :profile, changeset, _changes} ->
      {:error, :profile_creation_failed, changeset}
  end
end
```

### GenServer and OTP Patterns

#### GenServer Structure
```elixir
defmodule Prismatic.Cache.UserCache do
  @moduledoc """
  GenServer for caching user data with TTL support.
  """
  
  use GenServer
  
  alias Prismatic.Accounts.User
  
  # Client API
  
  @doc "Starts the user cache GenServer"
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc "Gets a user from cache or database"
  @spec get_user(binary()) :: {:ok, User.t()} | {:error, term()}
  def get_user(user_id) when is_binary(user_id) do
    GenServer.call(__MODULE__, {:get_user, user_id})
  end
  
  @doc "Invalidates a user from cache"
  def invalidate_user(user_id) when is_binary(user_id) do
    GenServer.cast(__MODULE__, {:invalidate, user_id})
  end
  
  # Server Callbacks
  
  @impl GenServer
  def init(opts) do
    ttl = Keyword.get(opts, :ttl, :timer.minutes(15))
    schedule_cleanup()
    
    {:ok, %{cache: %{}, ttl: ttl}}
  end
  
  @impl GenServer
  def handle_call({:get_user, user_id}, _from, %{cache: cache, ttl: ttl} = state) do
    case Map.get(cache, user_id) do
      {user, expires_at} when expires_at > System.system_time(:millisecond) ->
        {:reply, {:ok, user}, state}
      
      _ ->
        case fetch_user_from_db(user_id) do
          {:ok, user} ->
            expires_at = System.system_time(:millisecond) + ttl
            new_cache = Map.put(cache, user_id, {user, expires_at})
            {:reply, {:ok, user}, %{state | cache: new_cache}}
          
          error ->
            {:reply, error, state}
        end
    end
  end
  
  @impl GenServer
  def handle_cast({:invalidate, user_id}, %{cache: cache} = state) do
    new_cache = Map.delete(cache, user_id)
    {:noreply, %{state | cache: new_cache}}
  end
  
  @impl GenServer
  def handle_info(:cleanup, %{cache: cache} = state) do
    now = System.system_time(:millisecond)
    new_cache = 
      cache
      |> Enum.reject(fn {_key, {_user, expires_at}} -> expires_at <= now end)
      |> Map.new()
    
    schedule_cleanup()
    {:noreply, %{state | cache: new_cache}}
  end
  
  # Private functions
  
  defp fetch_user_from_db(user_id) do
    # Implementation
  end
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, :timer.minutes(5))
  end
end
```

## Phoenix/Web Layer Style

### Controller Patterns

#### Controller Structure
```elixir
defmodule PrismaticWeb.UserController do
  use PrismaticWeb, :controller
  
  alias Prismatic.Accounts
  alias Prismatic.Accounts.User
  
  action_fallback PrismaticWeb.FallbackController
  
  # Standard RESTful actions
  
  def index(conn, params) do
    with {:ok, users} <- Accounts.list_users(params) do
      render(conn, "index.json", users: users)
    end
  end
  
  def show(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.get_user(id) do
      render(conn, "show.json", user: user)
    end
  end
  
  def create(conn, %{"user" => user_params}) do
    with {:ok, user} <- Accounts.create_user(user_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", Routes.user_path(conn, :show, user))
      |> render("show.json", user: user)
    end
  end
  
  def update(conn, %{"id" => id, "user" => user_params}) do
    with {:ok, user} <- Accounts.get_user(id),
         {:ok, updated_user} <- Accounts.update_user(user, user_params) do
      render(conn, "show.json", user: updated_user)
    end
  end
  
  def delete(conn, %{"id" => id}) do
    with {:ok, user} <- Accounts.get_user(id),
         {:ok, _user} <- Accounts.delete_user(user) do
      send_resp(conn, :no_content, "")
    end
  end
end
```

#### View and Template Patterns
```elixir
defmodule PrismaticWeb.UserView do
  use PrismaticWeb, :view
  
  alias PrismaticWeb.UserView
  
  def render("index.json", %{users: users}) do
    %{
      data: render_many(users, UserView, "user.json"),
      meta: %{
        total: length(users),
        page: 1  # Add pagination metadata as needed
      }
    }
  end
  
  def render("show.json", %{user: user}) do
    %{data: render_one(user, UserView, "user.json")}
  end
  
  def render("user.json", %{user: user}) do
    %{
      id: user.id,
      email: user.email,
      name: user.name,
      role: user.role,
      confirmed_at: user.confirmed_at,
      inserted_at: user.inserted_at,
      updated_at: user.updated_at
    }
  end
end
```

### LiveView Patterns

#### LiveView Structure
```elixir
defmodule PrismaticWeb.UserLive.Index do
  use PrismaticWeb, :live_view
  
  alias Prismatic.Accounts
  alias Prismatic.Accounts.User
  
  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket), do: Accounts.subscribe()
    
    socket =
      socket
      |> assign(:users, list_users())
      |> assign(:page_title, "Users")
    
    {:ok, socket}
  end
  
  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end
  
  @impl Phoenix.LiveView
  def handle_event("delete", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    {:ok, _} = Accounts.delete_user(user)
    
    {:noreply, assign(socket, :users, list_users())}
  end
  
  @impl Phoenix.LiveView
  def handle_info({:user_created, user}, socket) do
    {:noreply, update(socket, :users, fn users -> [user | users] end)}
  end
  
  def handle_info({:user_updated, user}, socket) do
    {:noreply, update(socket, :users, fn users ->
      Enum.map(users, fn u -> if u.id == user.id, do: user, else: u end)
    end)}
  end
  
  def handle_info({:user_deleted, user}, socket) do
    {:noreply, update(socket, :users, fn users ->
      Enum.reject(users, fn u -> u.id == user.id end)
    end)}
  end
  
  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit User")
    |> assign(:user, Accounts.get_user!(id))
  end
  
  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New User")
    |> assign(:user, %User{})
  end
  
  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Users")
    |> assign(:user, nil)
  end
  
  defp list_users do
    Accounts.list_users()
  end
end
```

## JavaScript/TypeScript Style

### General JavaScript Conventions

#### Naming and Structure
```javascript
// ✅ Good - Clear naming and organization
class UserRegistrationForm {
  constructor(formElement) {
    this.form = formElement;
    this.emailField = this.form.querySelector('#email');
    this.passwordField = this.form.querySelector('#password');
    this.submitButton = this.form.querySelector('[type="submit"]');
    
    this.bindEvents();
  }
  
  bindEvents() {
    this.form.addEventListener('submit', this.handleSubmit.bind(this));
    this.emailField.addEventListener('blur', this.validateEmail.bind(this));
    this.passwordField.addEventListener('input', this.validatePassword.bind(this));
  }
  
  async handleSubmit(event) {
    event.preventDefault();
    
    if (!this.isFormValid()) {
      return;
    }
    
    try {
      this.setSubmitState(true);
      const response = await this.submitRegistration();
      this.handleSuccess(response);
    } catch (error) {
      this.handleError(error);
    } finally {
      this.setSubmitState(false);
    }
  }
  
  validateEmail() {
    const email = this.emailField.value;
    const isValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
    
    this.setFieldValidation(this.emailField, isValid, 'Please enter a valid email address');
    return isValid;
  }
  
  validatePassword() {
    const password = this.passwordField.value;
    const minLength = 8;
    const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(password);
    const hasNumber = /\d/.test(password);
    
    const isValid = password.length >= minLength && hasSpecialChar && hasNumber;
    const message = isValid ? '' : 'Password must be at least 8 characters with a number and special character';
    
    this.setFieldValidation(this.passwordField, isValid, message);
    return isValid;
  }
  
  setFieldValidation(field, isValid, message) {
    const errorElement = field.parentElement.querySelector('.error-message');
    
    field.classList.toggle('invalid', !isValid);
    field.classList.toggle('valid', isValid);
    
    if (errorElement) {
      errorElement.textContent = isValid ? '' : message;
    }
  }
  
  isFormValid() {
    return this.validateEmail() && this.validatePassword();
  }
  
  setSubmitState(isSubmitting) {
    this.submitButton.disabled = isSubmitting;
    this.submitButton.textContent = isSubmitting ? 'Creating Account...' : 'Create Account';
  }
  
  async submitRegistration() {
    const formData = new FormData(this.form);
    const response = await fetch('/api/users', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify(Object.fromEntries(formData))
    });
    
    if (!response.ok) {
      throw new Error(`Registration failed: ${response.statusText}`);
    }
    
    return response.json();
  }
  
  handleSuccess(response) {
    // Redirect or show success message
    window.location.href = '/users/dashboard';
  }
  
  handleError(error) {
    console.error('Registration error:', error);
    this.showGlobalError('Registration failed. Please try again.');
  }
  
  showGlobalError(message) {
    const errorContainer = document.querySelector('.global-error');
    if (errorContainer) {
      errorContainer.textContent = message;
      errorContainer.style.display = 'block';
    }
  }
}

// Initialize when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  const registrationForm = document.querySelector('#user-registration-form');
  if (registrationForm) {
    new UserRegistrationForm(registrationForm);
  }
});
```

### TypeScript Conventions

#### Type Definitions and Interfaces
```typescript
// ✅ Good - Clear type definitions
interface User {
  id: string;
  email: string;
  name: string;
  role: 'admin' | 'user' | 'viewer';
  confirmedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

interface UserCreateRequest {
  email: string;
  name: string;
  password: string;
  role?: 'user' | 'viewer'; // admin requires special permissions
}

interface ApiResponse<T> {
  data: T;
  meta?: {
    total?: number;
    page?: number;
    perPage?: number;
  };
}

interface ApiError {
  error: string;
  details?: Record<string, string[]>;
}

// ✅ Good - Generic API client
class ApiClient {
  private baseUrl: string;
  private headers: Record<string, string>;
  
  constructor(baseUrl: string = '/api') {
    this.baseUrl = baseUrl;
    this.headers = {
      'Content-Type': 'application/json',
      'X-CSRF-Token': this.getCsrfToken()
    };
  }
  
  async get<T>(endpoint: string): Promise<T> {
    return this.request<T>('GET', endpoint);
  }
  
  async post<T>(endpoint: string, data: unknown): Promise<T> {
    return this.request<T>('POST', endpoint, data);
  }
  
  async put<T>(endpoint: string, data: unknown): Promise<T> {
    return this.request<T>('PUT', endpoint, data);
  }
  
  async delete<T>(endpoint: string): Promise<T> {
    return this.request<T>('DELETE', endpoint);
  }
  
  private async request<T>(
    method: string, 
    endpoint: string, 
    data?: unknown
  ): Promise<T> {
    const url = `${this.baseUrl}${endpoint}`;
    const config: RequestInit = {
      method,
      headers: this.headers,
    };
    
    if (data) {
      config.body = JSON.stringify(data);
    }
    
    const response = await fetch(url, config);
    
    if (!response.ok) {
      const error: ApiError = await response.json();
      throw new Error(error.error || `HTTP ${response.status}: ${response.statusText}`);
    }
    
    return response.json();
  }
  
  private getCsrfToken(): string {
    const metaTag = document.querySelector('meta[name="csrf-token"]') as HTMLMetaElement;
    return metaTag?.content || '';
  }
}

// ✅ Good - Service classes with proper typing
class UserService {
  private api: ApiClient;
  
  constructor(api: ApiClient) {
    this.api = api;
  }
  
  async listUsers(): Promise<User[]> {
    const response = await this.api.get<ApiResponse<User[]>>('/users');
    return response.data;
  }
  
  async getUser(id: string): Promise<User> {
    const response = await this.api.get<ApiResponse<User>>(`/users/${id}`);
    return response.data;
  }
  
  async createUser(userData: UserCreateRequest): Promise<User> {
    const response = await this.api.post<ApiResponse<User>>('/users', userData);
    return response.data;
  }
  
  async updateUser(id: string, userData: Partial<UserCreateRequest>): Promise<User> {
    const response = await this.api.put<ApiResponse<User>>(`/users/${id}`, userData);
    return response.data;
  }
  
  async deleteUser(id: string): Promise<void> {
    await this.api.delete<void>(`/users/${id}`);
  }
}
```

## CSS/Styling Guidelines

### CSS Architecture

#### BEM Methodology
```css
/* ✅ Good - BEM structure */
.user-card {
  display: flex;
  flex-direction: column;
  padding: 1rem;
  border: 1px solid var(--color-border);
  border-radius: var(--border-radius);
  background: var(--color-surface);
}

.user-card__header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.75rem;
}

.user-card__title {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-text-primary);
  margin: 0;
}

.user-card__subtitle {
  font-size: 0.875rem;
  color: var(--color-text-secondary);
  margin: 0.25rem 0 0 0;
}

.user-card__actions {
  display: flex;
  gap: 0.5rem;
  margin-top: auto;
}

.user-card__button {
  padding: 0.5rem 1rem;
  border: 1px solid var(--color-primary);
  border-radius: var(--border-radius-sm);
  background: transparent;
  color: var(--color-primary);
  cursor: pointer;
  transition: all 0.2s ease;
}

.user-card__button--primary {
  background: var(--color-primary);
  color: var(--color-white);
}

.user-card__button:hover {
  background: var(--color-primary);
  color: var(--color-white);
}

.user-card__button--primary:hover {
  background: var(--color-primary-dark);
}

.user-card__button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
```

#### CSS Custom Properties
```css
/* ✅ Good - Organized CSS variables */
:root {
  /* Colors */
  --color-primary: #3b82f6;
  --color-primary-dark: #2563eb;
  --color-primary-light: #93c5fd;
  
  --color-secondary: #64748b;
  --color-secondary-dark: #475569;
  --color-secondary-light: #cbd5e1;
  
  --color-success: #10b981;
  --color-warning: #f59e0b;
  --color-error: #ef4444;
  
  --color-text-primary: #1f2937;
  --color-text-secondary: #6b7280;
  --color-text-muted: #9ca3af;
  
  --color-background: #ffffff;
  --color-surface: #f9fafb;
  --color-border: #e5e7eb;
  
  /* Spacing */
  --spacing-xs: 0.25rem;
  --spacing-sm: 0.5rem;
  --spacing-md: 1rem;
  --spacing-lg: 1.5rem;
  --spacing-xl: 2rem;
  --spacing-2xl: 3rem;
  
  /* Typography */
  --font-family-sans: system-ui, -apple-system, sans-serif;
  --font-family-mono: 'Fira Code', 'Monaco', monospace;
  
  --font-size-xs: 0.75rem;
  --font-size-sm: 0.875rem;
  --font-size-base: 1rem;
  --font-size-lg: 1.125rem;
  --font-size-xl: 1.25rem;
  --font-size-2xl: 1.5rem;
  --font-size-3xl: 1.875rem;
  
  /* Layout */
  --border-radius: 0.375rem;
  --border-radius-sm: 0.25rem;
  --border-radius-lg: 0.5rem;
  
  --shadow-sm: 0 1px 2px 0 rgb(0 0 0 / 0.05);
  --shadow-md: 0 4px 6px -1px rgb(0 0 0 / 0.1);
  --shadow-lg: 0 10px 15px -3px rgb(0 0 0 / 0.1);
  
  /* Transitions */
  --transition-fast: 0.15s ease;
  --transition-base: 0.2s ease;
  --transition-slow: 0.3s ease;
}

/* Dark mode support */
@media (prefers-color-scheme: dark) {
  :root {
    --color-text-primary: #f9fafb;
    --color-text-secondary: #d1d5db;
    --color-text-muted: #9ca3af;
    
    --color-background: #111827;
    --color-surface: #1f2937;
    --color-border: #374151;
  }
}
```

## Documentation Standards

### Module Documentation

#### Comprehensive Module Docs
```elixir
defmodule Prismatic.Accounts do
  @moduledoc """
  The Accounts context.
  
  This module provides the public API for user account management,
  including registration, authentication, profile management, and
  user preferences.
  
  ## Core Concepts
  
  - **User**: The main account entity representing a person
  - **UserToken**: Session and authentication tokens
  - **UserProfile**: Extended user information and preferences
  
  ## Usage Examples
  
      # Create a new user
      {:ok, user} = Accounts.create_user(%{
        email: "user@example.com",
        name: "John Doe",
        password: "secure_password123"
      })
      
      # Authenticate user
      case Accounts.authenticate_user("user@example.com", "secure_password123") do
        {:ok, user} -> # Login successful
        {:error, :invalid_credentials} -> # Login failed
      end
      
      # Update user profile
      {:ok, updated_user} = Accounts.update_user_profile(user, %{
        bio: "Software developer",
        timezone: "America/New_York"
      })
  
  ## Security Considerations
  
  All password operations use secure hashing with bcrypt.
  User tokens are generated using cryptographically secure random bytes.
  Email confirmation is required before account activation.
  
  ## Related Documentation
  
  - `Prismatic.Accounts.User` - User schema and validations
  - `Prismatic.Accounts.UserToken` - Token management
  - `PrismaticWeb.Auth` - Web authentication helpers
  """
  
  import Ecto.Query, warn: false
  
  alias Prismatic.Repo
  alias Prismatic.Accounts.{User, UserToken, UserProfile}
  # ... rest of implementation
end
```

### README Standards

#### Project README Template
```markdown
# Prismatic

A comprehensive web application built with Phoenix and Elixir.

## Features

- 🔐 **Authentication** - Secure user registration and login
- 👥 **User Management** - Role-based access control
- 📊 **Analytics** - Real-time metrics and reporting
- 🔒 **Security** - Multi-factor authentication and encryption
- 📱 **Responsive** - Mobile-first design
- 🚀 **Performance** - Optimized for speed and scalability

## Quick Start

### Prerequisites

- Elixir 1.16+ and Erlang 26+
- Node.js 18+ and npm
- PostgreSQL 14+
- Redis 7+ (for caching)

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/example/prismatic.git
   cd prismatic
   ```

2. Install dependencies:
   ```bash
   mix deps.get
   cd assets && npm install && cd ..
   ```

3. Set up the database:
   ```bash
   mix ecto.setup
   ```

4. Start the development server:
   ```bash
   mix phx.server
   ```

5. Visit [`localhost:4000`](http://localhost:4000) in your browser.

## Development

### Running Tests
```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover

# Run specific test file
mix test test/prismatic/accounts_test.exs
```

### Code Quality
```bash
# Format code
mix format

# Run static analysis
mix credo --strict

# Run security checks
mix sobelow
```

### Database Operations
```bash
# Create and run migration
mix ecto.gen.migration create_users
mix ecto.migrate

# Reset database
mix ecto.reset

# Generate seed data
mix run priv/repo/seeds.exs
```

## Deployment

See [Deployment Guide](docs/operations/deployment-procedures.md) for detailed instructions.

## Documentation

- [API Documentation](docs/reference/api-endpoints.md)
- [Security Guidelines](docs/guides/security-guidelines.md)
- [Performance Guide](docs/guides/performance-optimization.md)
- [Style Guide](docs/guides/style-guide.md)

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please read our [Style Guide](docs/guides/style-guide.md) and ensure all tests pass.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
```

## Testing Standards

### Test Organization

#### Test File Structure
```elixir
defmodule Prismatic.AccountsTest do
  use Prismatic.DataCase, async: true
  
  alias Prismatic.Accounts
  alias Prismatic.Accounts.User
  
  describe "create_user/1" do
    test "creates user with valid attributes" do
      attrs = %{
        email: "test@example.com",
        name: "Test User",
        password: "secure_password123"
      }
      
      assert {:ok, %User{} = user} = Accounts.create_user(attrs)
      assert user.email == "test@example.com"
      assert user.name == "Test User"
      assert user.hashed_password != "secure_password123"
      assert is_nil(user.confirmed_at)
    end
    
    test "returns error with invalid email" do
      attrs = %{
        email: "invalid-email",
        name: "Test User", 
        password: "secure_password123"
      }
      
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.create_user(attrs)
      assert %{email: ["has invalid format"]} = errors_on(changeset)
    end
    
    test "returns error with short password" do
      attrs = %{
        email: "test@example.com",
        name: "Test User",
        password: "short"
      }
      
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.create_user(attrs)
      assert %{password: ["should be at least 8 character(s)"]} = errors_on(changeset)
    end
    
    test "returns error with duplicate email" do
      attrs = %{
        email: "test@example.com",
        name: "Test User",
        password: "secure_password123"
      }
      
      assert {:ok, _user} = Accounts.create_user(attrs)
      assert {:error, %Ecto.Changeset{} = changeset} = Accounts.create_user(attrs)
      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end
  end
  
  describe "authenticate_user/2" do
    setup do
      {:ok, user} = Accounts.create_user(%{
        email: "test@example.com",
        name: "Test User",
        password: "secure_password123"
      })
      
      %{user: user}
    end
    
    test "returns user with valid credentials", %{user: user} do
      assert {:ok, authenticated_user} = 
        Accounts.authenticate_user("test@example.com", "secure_password123")
      assert authenticated_user.id == user.id
    end
    
    test "returns error with invalid email" do
      assert {:error, :invalid_credentials} = 
        Accounts.authenticate_user("wrong@example.com", "secure_password123")
    end
    
    test "returns error with invalid password", %{user: _user} do
      assert {:error, :invalid_credentials} = 
        Accounts.authenticate_user("test@example.com", "wrong_password")
    end
  end
end
```

### Factory Patterns

#### Using ExMachina
```elixir
defmodule Prismatic.Factory do
  use ExMachina.Ecto, repo: Prismatic.Repo
  
  def user_factory do
    %Prismatic.Accounts.User{
      email: sequence(:email, &"user#{&1}@example.com"),
      name: fake_name(),
      hashed_password: Bcrypt.hash_pwd_salt("password123"),
      role: :user,
      confirmed_at: ~N[2024-01-01 12:00:00]
    }
  end
  
  def admin_user_factory do
    build(:user, role: :admin)
  end
  
  def unconfirmed_user_factory do
    build(:user, confirmed_at: nil)
  end
  
  def user_token_factory do
    %Prismatic.Accounts.UserToken{
      user: build(:user),
      token: :crypto.strong_rand_bytes(32),
      context: "session",
      sent_to: "user@example.com"
    }
  end
  
  defp fake_name do
    ["Alice", "Bob", "Charlie", "Diana", "Eve", "Frank"]
    |> Enum.random()
  end
end

# Usage in tests
defmodule Prismatic.SomeTest do
  use Prismatic.DataCase
  
  import Prismatic.Factory
  
  test "some functionality" do
    user = insert(:user)
    admin = insert(:admin_user)
    tokens = insert_list(3, :user_token, user: user)
    
    # Test implementation
  end
end
```

## Configuration Management

### Environment Configuration

#### Structured Config Pattern
```elixir
# config/config.exs
import Config

# Application configuration
config :prismatic,
  ecto_repos: [Prismatic.Repo],
  generators: [binary_id: true]

# Web configuration  
config :prismatic, PrismaticWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Phoenix.Endpoint.Cowboy2Adapter,
  render_errors: [view: PrismaticWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Prismatic.PubSub,
  live_view: [signing_salt: "SECRET_SALT"]

# Database configuration
config :prismatic, Prismatic.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "prismatic_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Import environment specific config
import_config "#{config_env()}.exs"
```

```elixir
# config/runtime.exs
import Config

# Production runtime configuration
if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
    raise """
    environment variable DATABASE_URL is missing.
    For example: ecto://USER:PASS@HOST/DATABASE
    """

  maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

  config :prismatic, Prismatic.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
    raise """
    environment variable SECRET_KEY_BASE is missing.
    You can generate one by calling: mix phx.gen.secret
    """

  config :prismatic, PrismaticWeb.Endpoint,
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    secret_key_base: secret_key_base

  # Additional production configuration...
end
```

## Related Documentation

- [Git Hooks Setup](git-hooks-setup.md) - Automated enforcement of style guidelines
- [Semantic Versioning](semantic-versioning.md) - Version management and release standards
- [CI/CD Configuration](../operations/cicd-configuration.md) - Automated code quality checks and deployments
- [Security Guidelines](security-guidelines.md) - Security-focused coding practices and standards
- [Performance Optimization](performance-optimization.md) - Performance-conscious development practices

---

**Consistent style and coding standards improve code maintainability, team productivity, and reduce bugs. Regular review and updates ensure these standards evolve with the project.**