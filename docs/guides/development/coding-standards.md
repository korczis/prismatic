# Coding Standards

Code style conventions and quality standards for consistent development across the Prismatic project.

## ⏱️ Time Estimates

📖 Reading time: 15 minutes | 🔧 Reference time: Ongoing | 📊 Skill level: Beginner

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../../README.md) > [Guides](../README.md) > [Development](README.md) > Coding Standards

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to development guides
- **🏠 [Documentation Home](../../README.md)** - Main documentation index
- **🔍 [Search Documentation](../../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Developer Experience](../getting-started/developer-experience.md) - Development workflow and tools that support these standards
- [Architecture Overview](../../core/architecture-overview.md) - System design principles that inform coding practices
- [Security Guidelines](../security/security-guidelines.md) - Security implementation standards and patterns
- [Performance Optimization](../performance/performance-optimization.md) - Performance considerations in code development
- [Feature Branch Workflow](../workflow/feature-branch-workflow.md) - Code quality enforcement in branch workflow
<!-- NAV_END -->

## Elixir Code Style

### Module Organization
```elixir
defmodule Prismatic.Accounts.User do
  @moduledoc """
  User schema and changeset functions.
  
  Handles user data validation, password hashing, and account management.
  
  Related: [Security Guidelines](../security/security-guidelines.md#password-hashing)
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  # Schema definition first
  schema "users" do
    field :email, :string
    field :password_hash, :string
    timestamps()
  end
  
  # Public API functions
  def changeset(user, attrs) do
    # Implementation
  end
  
  # Private helper functions last
  defp hash_password(changeset) do
    # Implementation  
  end
end
```

### Function Documentation
**All public functions must include `@doc` with examples:**
```elixir
@doc """
Creates a new user account with the given attributes.

Returns `{:ok, user}` on success or `{:error, changeset}` on validation failure.

## Examples

    iex> create_user(%{email: "user@example.com", password: "secure123"})
    {:ok, %User{email: "user@example.com"}}
    
    iex> create_user(%{email: "invalid"})
    {:error, %Ecto.Changeset{}}

## Security
Passwords are automatically hashed using Argon2.
See [Security Guidelines](../security/security-guidelines.md#password-policies) for requirements.
"""
@spec create_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
def create_user(attrs \\ %{}) do
  # Implementation
end
```

### Naming Conventions

**Modules**: PascalCase with descriptive, hierarchical names
```elixir
# ✅ Good
Prismatic.Accounts.User
Prismatic.Content.Article  
PrismaticWeb.UserController

# ❌ Avoid
Prismatic.User  # Too generic
Prismatic.Stuff # Vague naming
```

**Functions**: snake_case with clear, action-oriented names
```elixir
# ✅ Good  
def create_user_account(attrs)
def authenticate_with_password(email, password)
def list_published_articles()

# ❌ Avoid
def make_user(attrs)  # Vague action
def auth(e, p)        # Abbreviated parameters
def get_stuff()       # Generic naming
```

**Variables**: snake_case with descriptive names
```elixir
# ✅ Good
user_params = %{email: email, password: password}
validation_result = User.changeset(user, attrs)

# ❌ Avoid  
up = %{e: email, p: password}  # Abbreviated
result = User.changeset(user, attrs)  # Generic
```

## Phoenix Conventions

### Controller Design
**Keep controllers thin - delegate to contexts:**
```elixir
defmodule PrismaticWeb.UserController do
  use PrismaticWeb, :controller
  
  alias Prismatic.Accounts
  
  def create(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> redirect(to: ~p"/users/#{user}")
      
      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :new, changeset: changeset)
    end
  end
end
```

### LiveView Patterns
**Standard LiveView structure:**
```elixir
defmodule PrismaticWeb.UserLive.Index do
  use PrismaticWeb, :live_view
  
  alias Prismatic.Accounts
  
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: subscribe_to_users()
    {:ok, stream(socket, :users, Accounts.list_users())}
  end
  
  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    {:ok, _} = Accounts.delete_user(user)
    
    {:noreply, stream_delete(socket, :users, user)}
  end
  
  # Private functions for organization
  defp subscribe_to_users do
    Phoenix.PubSub.subscribe(Prismatic.PubSub, "users")
  end
end
```

## Error Handling Standards

### Tagged Tuples
**Consistent error return patterns:**
```elixir
# ✅ Standard patterns
{:ok, result}           # Success with data
{:error, :not_found}    # Resource doesn't exist  
{:error, :unauthorized} # Permission denied
{:error, changeset}     # Validation errors
{:error, :timeout}      # Operation timeout

# Function implementation example
def authenticate_user(email, password) do
  case get_user_by_email(email) do
    nil -> {:error, :not_found}
    user -> verify_password(user, password)
  end
end
```

### Error Context
**Provide meaningful error context:**
```elixir
# ✅ Good - Specific error information
{:error, :invalid_credentials}
{:error, :account_suspended}  
{:error, :payment_required}

# ❌ Avoid - Generic errors
{:error, :error}
{:error, "Something went wrong"}
```

## Database Standards

### Query Optimization
**Prevent N+1 queries with explicit preloading:**
```elixir
# ✅ Good - Explicit preloading
def list_articles_with_authors do
  Article
  |> preload(:author)
  |> order_by([a], desc: a.published_at)
  |> Repo.all()
end

# ❌ Avoid - N+1 query potential
def list_articles do
  Repo.all(Article)
  # Accessing article.author in templates causes N+1
end
```

### Schema Design
**Clear, validated schemas:**
```elixir
schema "users" do
  field :email, :string
  field :password_hash, :string
  field :confirmed_at, :utc_datetime
  
  has_many :articles, Article
  timestamps()
end

def changeset(user, attrs) do
  user
  |> cast(attrs, [:email, :password])
  |> validate_required([:email, :password])
  |> validate_format(:email, ~r/@/)
  |> validate_length(:password, min: 8)
  |> unique_constraint(:email)
  |> hash_password()
end
```

## Testing Standards

### Test Structure
**Use Arrange-Act-Assert pattern:**
```elixir
defmodule Prismatic.AccountsTest do
  use Prismatic.DataCase, async: true
  
  alias Prismatic.Accounts
  
  describe "create_user/1" do
    test "creates user with valid attributes" do
      # Arrange
      valid_attrs = %{
        email: "test@example.com",
        password: "securepassword123"
      }
      
      # Act
      result = Accounts.create_user(valid_attrs)
      
      # Assert
      assert {:ok, user} = result
      assert user.email == "test@example.com"
      refute user.password_hash == "securepassword123"  # Should be hashed
    end
    
    test "returns error with invalid email format" do
      invalid_attrs = %{email: "invalid-email", password: "secure123"}
      
      assert {:error, changeset} = Accounts.create_user(invalid_attrs)
      assert %{email: ["has invalid format"]} = errors_on(changeset)
    end
  end
end
```

### Test Coverage
**Comprehensive test scenarios:**
- **Happy Path**: Normal successful operations
- **Edge Cases**: Boundary conditions and unusual inputs
- **Error Cases**: Various failure scenarios
- **Security**: Authentication and authorization checks

## Code Quality Tools

### Automated Formatting
```bash
# Format all code (required before commits)
mix format

# Check formatting without changes
mix format --check-formatted
```

### Static Analysis
```bash
# Code quality analysis (if configured)
mix credo

# Type checking (if configured)  
mix dialyzer
```

### Documentation Generation
```bash
# Generate API documentation
mix docs
```

## Performance Guidelines

### Database Efficiency
- Use indexes for frequently queried columns
- Limit query results with pagination
- Preload associations to avoid N+1 queries
- Use `select` to fetch only needed columns

### LiveView Optimization  
- Use `temporary_assigns` for large datasets
- Implement efficient `handle_info` for real-time updates
- Optimize DOM updates with targeted changes
- Monitor memory usage with telemetry

### Memory Management
- Avoid large data structures in process state
- Use streams for processing large datasets
- Implement proper cleanup in GenServer processes

## Security Standards

### Input Validation
**Validate all user inputs at context boundaries:**
```elixir
def create_user(attrs) do
  %User{}
  |> User.changeset(attrs)  # Validation happens here
  |> Repo.insert()
end
```

### Data Exposure
**Explicit field selection for external data:**
```elixir
# ✅ Good - Controlled data exposure
def user_public_data(user) do
  Map.take(user, [:id, :email, :name, :inserted_at])
end

# ❌ Avoid - Exposing internal structures
def get_user_data(id), do: Repo.get(User, id)
```

## AI Development Guidelines

### When AI Generates Code
- **Follow established patterns** from existing codebase
- **Include comprehensive documentation** with examples
- **Add cross-references** to related documentation
- **Generate corresponding tests** with edge cases
- **Consider security implications** in all implementations

### Code Review for AI
- Verify business logic correctness
- Check architectural compliance  
- Validate security considerations
- Ensure documentation accuracy
- Test generated code thoroughly

## Related Documentation
- [Architecture Overview](../../core/architecture-overview.md) - System design principles
- [Developer Experience](../getting-started/developer-experience.md) - Development workflow and tools
- [Security Guidelines](../security/security-guidelines.md) - Security implementation details
- [Performance Optimization](../performance/performance-optimization.md) - Performance best practices