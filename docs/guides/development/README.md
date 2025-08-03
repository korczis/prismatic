# Development Guide

**Comprehensive development guide for contributing to Prismatic**

This guide provides detailed information for developers who want to contribute to the Prismatic project, including setup procedures, development workflows, coding standards, and best practices.

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Development Environment](#development-environment)
- [Project Structure](#project-structure)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)
- [Debugging](#debugging)
- [Performance](#performance)
- [Contributing](#contributing)

## 🚀 Quick Start

### Prerequisites

Ensure you have the following installed:

- **Elixir 1.17+** with OTP 26+
- **Phoenix Framework 1.7.21+**
- **PostgreSQL 14+**
- **Node.js 18+** with npm
- **Git 2.30+**
- **Docker & Docker Compose** (optional, for containerized development)

### 1-Minute Setup

```bash
# Clone and enter directory
git clone https://github.com/korczis/prismatic.git
cd prismatic

# Run the setup script
./scripts/dev-setup.sh

# Start development server
mix phx.server
```

Visit [`http://localhost:4000`](http://localhost:4000) to verify the setup.

## 🛠️ Development Environment

### Manual Setup

#### 1. Install Dependencies

```bash
# Install Elixir dependencies
mix deps.get

# Install Node.js dependencies
cd apps/prismatic_web/assets
npm install
cd ../../../
```

#### 2. Database Setup

```bash
# Create and migrate database
mix ecto.setup

# Or step by step:
mix ecto.create
mix ecto.migrate
mix run apps/prismatic/priv/repo/seeds.exs
```

#### 3. Compile and Verify

```bash
# Compile the project
mix compile

# Run tests to verify setup
mix test

# Check code quality
mix credo
mix dialyzer
```

### Docker Development

```bash
# Start development environment
docker-compose -f docker-compose.dev.yml up

# Run commands in container
docker-compose exec app mix test
docker-compose exec app mix credo
```

### IDE Configuration

#### Visual Studio Code

Install recommended extensions:

```json
{
  "recommendations": [
    "jakebecker.elixir-ls",
    "phoenixframework.phoenix",
    "bradlc.vscode-tailwindcss",
    "esbenp.prettier-vscode",
    "ms-vscode.vscode-json"
  ]
}
```

#### IntelliJ IDEA / WebStorm

Install the Elixir plugin and configure:

1. Install **Elixir Plugin**
2. Configure **Mix** as build tool
3. Set up **PostgreSQL** data source
4. Configure **Tailwind CSS** support

### Environment Variables

Create `.env` file for development:

```bash
# Database
DATABASE_URL=postgres://postgres:postgres@localhost/prismatic_dev

# Phoenix
SECRET_KEY_BASE=your_secret_key_base_here
PHX_HOST=localhost
PHX_PORT=4000

# External Services (optional)
GITHUB_TOKEN=your_github_token
JIRA_URL=https://your-domain.atlassian.net
JIRA_TOKEN=your_jira_token
SLACK_WEBHOOK_URL=your_slack_webhook
```

## 🏗️ Project Structure

### Umbrella Application Layout

```
prismatic/
├── apps/
│   ├── prismatic/              # Core business logic
│   │   ├── lib/
│   │   │   ├── prismatic/      # Main application modules
│   │   │   │   ├── beam/       # BEAM VM introspection
│   │   │   │   ├── todo/       # TODO management system
│   │   │   │   ├── docs/       # Documentation system
│   │   │   │   ├── llm/        # LLM integration
│   │   │   │   └── shared/     # Shared utilities
│   │   │   └── mix/tasks/      # Mix tasks
│   │   ├── test/               # Tests
│   │   └── priv/               # Private resources
│   └── prismatic_web/          # Web interface
│       ├── lib/
│       │   └── prismatic_web/  # Phoenix modules
│       │       ├── controllers/ # API controllers
│       │       ├── components/  # LiveView components
│       │       └── live/        # LiveView modules
│       ├── assets/             # Frontend resources
│       └── test/               # Web-specific tests
├── config/                     # Configuration files
├── docs/                       # Documentation
├── scripts/                    # Development scripts
└── docker/                     # Docker configurations
```

### Key Modules and Responsibilities

#### Core Application (`apps/prismatic`)

- **[`Prismatic.BEAM`](../../api/beam.md)** - BEAM VM introspection toolkit
- **[`Prismatic.TODO`](../../api/todo.md)** - TODO management system
- **[`Prismatic.Docs`](../../api/docs.md)** - Documentation generation and analysis
- **[`Prismatic.Shared`](../../api/shared.md)** - Shared utilities and protocols

#### Web Application (`apps/prismatic_web`)

- **[`PrismaticWeb.Endpoint`](../../api/web/endpoint.md)** - Phoenix endpoint configuration
- **[`PrismaticWeb.Router`](../../api/web/router.md)** - Routing configuration
- **[`PrismaticWeb.Controllers`](../../api/web/controllers.md)** - REST API controllers
- **[`PrismaticWeb.Live`](../../api/web/live.md)** - LiveView interfaces

## 🔄 Development Workflow

### Git Workflow

We follow **GitHub Flow** with additional quality gates:

#### 1. Create Feature Branch

```bash
# Update main branch
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/your-feature-name
```

#### 2. Development Cycle

```bash
# Make changes
# ... edit files ...

# Run local checks
mix test                    # Run tests
mix credo                   # Code analysis
mix dialyzer                # Type checking
mix docs                    # Generate docs

# Commit changes
git add .
git commit -m "feat: add amazing feature

- Implement feature X
- Add tests for feature X
- Update documentation"
```

#### 3. Pre-Push Checklist

Before pushing, ensure:

- [ ] All tests pass: `mix test`
- [ ] Code quality passes: `mix credo --strict`
- [ ] Type checking passes: `mix dialyzer`
- [ ] Documentation generates: `mix docs`
- [ ] No compilation warnings: `mix compile --warnings-as-errors`

#### 4. Pull Request Process

```bash
# Push feature branch
git push origin feature/your-feature-name

# Create pull request on GitHub
# - Use descriptive title
# - Fill out PR template
# - Request review from maintainers
# - Link related issues
```

### Commit Message Convention

We follow **Conventional Commits**:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples:**
```bash
feat(beam): add process memory analysis
fix(todo): resolve scanner pattern matching issue
docs(api): update BEAM introspection examples
refactor(shared): extract common utilities
test(todo): add integration tests for scanner
```

### Development Scripts

Use provided scripts for common tasks:

```bash
# Setup development environment
./scripts/dev-setup.sh

# Run full test suite
./scripts/test-full.sh

# Quality checks
./scripts/quality-check.sh

# Reset development environment
./scripts/dev-reset.sh

# Generate release
./scripts/build-release.sh
```

## 📏 Coding Standards

### Elixir Style Guide

We follow the [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide) with these additions:

#### Module Organization

```elixir
defmodule Prismatic.MyModule do
  @moduledoc """
  Brief description of module purpose.

  Detailed explanation with examples and usage patterns.

  ## Examples

      iex> MyModule.function(:param)
      {:ok, :result}

  ## See Also

  - `RelatedModule`
  - `AnotherModule`
  """

  # Module attributes
  @default_timeout 5000
  @required_keys [:name, :type]

  # Type definitions
  @type config :: %{
    name: String.t(),
    type: atom(),
    options: keyword()
  }

  # Module imports and aliases
  alias Prismatic.Shared.Utils
  require Logger

  # Public API
  @doc """
  Public function documentation.
  """
  @spec public_function(config()) :: {:ok, term()} | {:error, term()}
  def public_function(config) do
    # Implementation
  end

  # Private implementation
  defp private_helper(arg) do
    # Implementation
  end
end
```

#### Documentation Standards

- **All public functions** must have `@doc` with examples
- **All modules** must have `@moduledoc` with overview
- **Complex functions** should include `@spec` type annotations
- **Examples** should be runnable with `doctest`

#### Error Handling

Use consistent error handling patterns:

```elixir
# Return tuples for expected errors
def process_data(data) do
  case validate_data(data) do
    :ok -> {:ok, transform_data(data)}
    {:error, reason} -> {:error, reason}
  end
end

# Use exceptions for unexpected errors
def process_data!(data) do
  case process_data(data) do
    {:ok, result} -> result
    {:error, reason} -> raise ArgumentError, "Invalid data: #{reason}"
  end
end

# Use with statements for multiple operations
def complex_operation(params) do
  with {:ok, validated} <- validate_params(params),
       {:ok, processed} <- process_validated(validated),
       {:ok, result} <- finalize_result(processed) do
    {:ok, result}
  else
    {:error, reason} -> {:error, reason}
  end
end
```

### Phoenix/Web Standards

#### Controllers

```elixir
defmodule PrismaticWeb.TodoController do
  use PrismaticWeb, :controller

  action_fallback PrismaticWeb.FallbackController

  def index(conn, params) do
    with {:ok, todos} <- Prismatic.TODO.list_todos(params) do
      render(conn, :index, todos: todos)
    end
  end

  def create(conn, %{"todo" => todo_params}) do
    with {:ok, todo} <- Prismatic.TODO.create_todo(todo_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/v1/todos/#{todo.id}")
      |> render(:show, todo: todo)
    end
  end
end
```

#### LiveView Components

```elixir
defmodule PrismaticWeb.TodoLive.Component do
  use PrismaticWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="todo-item">
      <span class={["status", @todo.status]}><%= @todo.status %></span>
      <span class="title"><%= @todo.title %></span>
    </div>
    """
  end
end
```

## 🧪 Testing

### Test Structure

```
test/
├── integration/          # End-to-end integration tests
├── prismatic/           # Core application tests
│   ├── beam/           # BEAM introspection tests
│   ├── todo/           # TODO management tests
│   └── docs/           # Documentation system tests
└── support/            # Test support modules
```

### Testing Patterns

#### Unit Tests

```elixir
defmodule Prismatic.TODO.ScannerTest do
  use ExUnit.Case, async: true
  doctest Prismatic.TODO.Scanner

  alias Prismatic.TODO.Scanner

  describe "scan_todos/2" do
    test "identifies TODO comments in source files" do
      # Given
      source_dirs = ["test/fixtures/sample_code"]
      options = %{include_metadata: true}

      # When
      {:ok, result} = Scanner.scan_todos(source_dirs, options)

      # Then
      assert result.total_todos > 0
      assert is_list(result.todos)
      
      todo = List.first(result.todos)
      assert todo.type in [:todo, :fixme, :hack, :bug]
      assert is_binary(todo.title)
      assert is_integer(todo.line_number)
    end
  end
end
```

#### Integration Tests

```elixir
defmodule Prismatic.IntegrationTest do
  use ExUnit.Case
  use Plug.Test

  alias Prismatic.TODO

  @moduletag :integration

  describe "TODO workflow integration" do
    test "complete TODO lifecycle" do
      # Scan for TODOs
      {:ok, scan_result} = TODO.scan_todos(paths: ["test/fixtures"])
      
      # Analyze results
      {:ok, analysis} = TODO.analyze_todos()
      
      # Generate report
      {:ok, report} = TODO.generate_report([:json])
      
      # Verify workflow
      assert scan_result.total_todos > 0
      assert analysis.categories != %{}
      assert byte_size(report) > 0
    end
  end
end
```

#### Property-Based Tests

```elixir
defmodule Prismatic.TODO.PropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  alias Prismatic.TODO.Scanner

  property "scanner handles all valid TODO formats" do
    check all todo_type <- member_of([:todo, :fixme, :hack, :bug]),
              content <- string(:printable),
              content != "" do
      comment = "#{String.upcase(to_string(todo_type))}: #{content}"
      
      {:ok, parsed} = Scanner.parse_todo_comment(comment, %{})
      
      assert parsed.type == todo_type
      assert String.contains?(parsed.description, content)
    end
  end
end
```

### Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/prismatic/todo/scanner_test.exs

# Run tests with coverage
mix test --cover

# Run only integration tests
mix test --only integration

# Run tests in watch mode
mix test.watch

# Run property-based tests
mix test --only property
```

### Mocking and Test Doubles

```elixir
# test/support/mocks.ex
Mox.defmock(Prismatic.TODO.ScannerMock, for: Prismatic.TODO.Scanner.Behaviour)

# In test
defmodule Prismatic.TODO.IntegratorTest do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  test "handles scanner errors gracefully" do
    Prismatic.TODO.ScannerMock
    |> expect(:scan_todos, fn _paths, _opts ->
      {:error, :file_not_found}
    end)

    assert {:error, :scan_failed} = 
      Prismatic.TODO.Integrator.sync_todos(scanner: Prismatic.TODO.ScannerMock)
  end
end
```

## 📚 Documentation

### Writing Documentation

#### Module Documentation

```elixir
defmodule Prismatic.MyModule do
  @moduledoc """
  Brief description of the module's purpose.

  Longer description explaining:
  - What the module does
  - When to use it
  - How it fits into the larger system

  ## Examples

      # Basic usage
      iex> MyModule.basic_function()
      {:ok, :result}

      # Advanced usage
      iex> MyModule.advanced_function(%{option: :value})
      {:ok, %{processed: :result}}

  ## Configuration

      config :prismatic, MyModule,
        default_option: :value,
        timeout: 5000

  ## See Also

  - `RelatedModule` - for related functionality
  - `AnotherModule` - for alternative approaches
  """
end
```

#### Function Documentation

```elixir
@doc """
Brief description of what the function does.

Longer description explaining the function's behavior, side effects,
and any important considerations.

## Parameters

- `param1` - Description of first parameter
- `param2` - Description of second parameter with constraints
- `options` - Keyword list of options:
  - `:timeout` - Request timeout in milliseconds (default: 5000)
  - `:retry` - Number of retry attempts (default: 3)

## Returns

- `{:ok, result}` - Success case with result description
- `{:error, reason}` - Error cases:
  - `:invalid_params` - When parameters are invalid
  - `:timeout` - When operation times out
  - `:not_found` - When resource doesn't exist

## Examples

    # Basic usage
    iex> MyModule.my_function("input", %{option: :value})
    {:ok, "processed input"}

    # Error handling
    iex> MyModule.my_function("", %{})
    {:error, :invalid_params}

    # With options
    iex> MyModule.my_function("input", %{}, timeout: 10_000)
    {:ok, "processed with custom timeout"}

## See Also

- `related_function/2` - for related operations
- `alternative_function/1` - for alternative approach
"""
@spec my_function(String.t(), map(), keyword()) :: 
  {:ok, String.t()} | {:error, atom()}
def my_function(input, params, options \\ [])
```

### Generating Documentation

```bash
# Generate HTML documentation
mix docs

# Generate documentation with private functions
mix docs --priv

# Serve documentation locally
mix docs && open doc/index.html
```

## 🐛 Debugging

### Debugging Tools

#### IEx (Interactive Elixir)

```bash
# Start IEx with project loaded
iex -S mix

# Start IEx with Phoenix server
iex -S mix phx.server
```

Useful IEx commands:
```elixir
# Inspect process state
pid |> :sys.get_state() |> IO.inspect()

# List all processes
Process.list() |> length()

# Memory usage
:erlang.memory() |> IO.inspect()

# Hot code reloading
recompile()

# Process information
Process.info(pid)
```

#### Debugging in Code

```elixir
# Add debugging breakpoints
require IEx; IEx.pry()

# Debug pipe operations
result = 
  input
  |> transform()
  |> IO.inspect(label: "after transform")
  |> validate()
  |> IO.inspect(label: "after validate")
  |> process()
```

#### Logger Usage

```elixir
require Logger

# Different log levels
Logger.debug("Debug information", data: debug_data)
Logger.info("Operation completed", duration: duration)
Logger.warning("Deprecated function used", function: :old_function)
Logger.error("Operation failed", error: error, context: context)

# Structured logging
Logger.info("TODO scanned", 
  total_todos: count,
  scan_duration: duration,
  source_dirs: dirs
)
```

### Performance Profiling

#### :fprof (Function Profiler)

```elixir
# Profile function execution
:fprof.apply(&Prismatic.TODO.scan_todos/2, [["lib"], %{}])
:fprof.profile()
:fprof.analyse()
```

#### :observer

```elixir
# Start observer GUI
:observer.start()
```

#### Benchmarking

```elixir
# Using Benchee
Benchee.run(%{
  "scan_todos" => fn -> Prismatic.TODO.scan_todos(["lib"], %{}) end,
  "scan_todos_fast" => fn -> Prismatic.TODO.scan_todos_fast(["lib"], %{}) end
})
```

## ⚡ Performance

### Performance Guidelines

#### Memory Management

```elixir
# Use stream processing for large datasets
def process_large_file(file_path) do
  file_path
  |> File.stream!()
  |> Stream.map(&String.trim/1)
  |> Stream.filter(&(&1 != ""))
  |> Stream.map(&process_line/1)
  |> Enum.to_list()
end

# Limit process message queue sizes
def handle_info(msg, %{queue_size: size} = state) when size > 1000 do
  Logger.warning("Message queue size exceeded", size: size)
  {:noreply, %{state | queue_size: 0}}
end
```

#### Database Optimization

```elixir
# Use efficient queries
def get_todos_with_metadata(user_id) do
  from(t in Todo,
    join: m in assoc(t, :metadata),
    where: t.user_id == ^user_id,
    preload: [metadata: m],
    order_by: [desc: t.updated_at]
  )
  |> Repo.all()
end

# Use database indexes
defmodule Prismatic.Repo.Migrations.AddTodoIndexes do
  def change do
    create index(:todos, [:user_id, :status])
    create index(:todos, [:created_at])
    create index(:todos, [:priority, :status])
  end
end
```

#### Concurrent Processing

```elixir
# Use Task.async_stream for parallel processing
def process_files_concurrently(file_paths) do
  file_paths
  |> Task.async_stream(&process_single_file/1, 
                       max_concurrency: System.schedulers_online())
  |> Stream.map(fn {:ok, result} -> result end)
  |> Enum.to_list()
end
```

### Monitoring and Metrics

```elixir
# Add telemetry events
defmodule Prismatic.TODO.Scanner do
  def scan_todos(paths, options) do
    start_time = System.monotonic_time()
    
    result = perform_scan(paths, options)
    
    duration = System.monotonic_time() - start_time
    
    :telemetry.execute(
      [:prismatic, :todo, :scan, :complete],
      %{duration: duration, todo_count: length(result.todos)},
      %{paths: paths, options: options}
    )
    
    result
  end
end
```

## 🤝 Contributing

### Code Review Process

#### Review Checklist

**Functionality:**
- [ ] Code solves the intended problem
- [ ] Edge cases are handled appropriately
- [ ] Error conditions are managed gracefully

**Code Quality:**
- [ ] Code follows project style guidelines
- [ ] Functions are appropriately sized and focused
- [ ] Variable and function names are descriptive
- [ ] Complex logic is commented

**Testing:**
- [ ] Appropriate tests are included
- [ ] Tests cover happy path and error cases
- [ ] Integration tests are included where appropriate

**Documentation:**
- [ ] Public functions have appropriate `@doc`
- [ ] Module has appropriate `@moduledoc`
- [ ] Examples are included and tested

**Performance:**
- [ ] No obvious performance bottlenecks
- [ ] Memory usage is reasonable
- [ ] Database queries are efficient

### Getting Help

- **Discord**: Join our [development Discord](https://discord.gg/prismatic-dev)
- **GitHub Discussions**: [Project discussions](https://github.com/korczis/prismatic/discussions)
- **Issues**: [Bug reports and feature requests](https://github.com/korczis/prismatic/issues)
- **Documentation**: [Complete documentation](../README.md)

### Recognition

We recognize contributors through:

- **Contributor Guide**: Listed in project documentation
- **Release Notes**: Recognition in release announcements
- **Hall of Fame**: Featured contributors on project website

---

This development guide is a living document. Please suggest improvements and additions as the project evolves.