# Contributing to Prismatic

**Thank you for your interest in contributing to Prismatic!**

This document provides comprehensive guidelines for contributing to the Prismatic project. Whether you're fixing bugs, adding features, improving documentation, or helping with testing, your contributions are welcome and appreciated.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Process](#development-process)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)
- [Community](#community)

## 🤝 Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to [maintainers@prismatic.dev](mailto:maintainers@prismatic.dev).

### Our Pledge

We pledge to make participation in our project a harassment-free experience for everyone, regardless of:

- Age, body size, disability, ethnicity, gender identity and expression
- Level of experience, education, socio-economic status
- Nationality, personal appearance, race, religion
- Sexual identity and orientation

## 🚀 Getting Started

### Prerequisites

Before contributing, ensure you have:

- **[Elixir 1.17+](https://elixir-lang.org/install.html)** with OTP 26+
- **[Phoenix Framework 1.7.21+](https://phoenixframework.org/)**
- **[PostgreSQL 14+](https://www.postgresql.org/download/)**
- **[Node.js 18+](https://nodejs.org/)** with npm
- **[Git 2.30+](https://git-scm.com/downloads)**

### First-Time Setup

1. **Fork the Repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/your-username/prismatic.git
   cd prismatic
   ```

2. **Set Up Development Environment**
   ```bash
   # Run the setup script
   ./scripts/dev-setup.sh
   
   # Or manually:
   mix deps.get
   mix ecto.setup
   mix compile
   ```

3. **Verify Setup**
   ```bash
   # Run tests
   mix test
   
   # Start server
   mix phx.server
   ```

4. **Configure Git**
   ```bash
   # Add upstream remote
   git remote add upstream https://github.com/korczis/prismatic.git
   
   # Configure Git hooks (optional)
   ./scripts/setup-git-hooks.sh
   ```

### Finding Issues to Work On

Great ways to start contributing:

- **Good First Issues**: Look for [`good first issue`](https://github.com/korczis/prismatic/labels/good%20first%20issue) label
- **Help Wanted**: Check [`help wanted`](https://github.com/korczis/prismatic/labels/help%20wanted) issues
- **Documentation**: Improve docs, add examples, fix typos
- **Testing**: Add test coverage, improve test quality
- **Bug Reports**: Fix reported bugs and issues

## 🔄 Development Process

### Workflow Overview

We follow **GitHub Flow** with additional quality gates:

```
main branch → feature branch → pull request → code review → merge → deploy
```

### Creating a Feature Branch

```bash
# Update main branch
git checkout main
git pull upstream main

# Create and switch to feature branch
git checkout -b feature/descriptive-name

# For bug fixes
git checkout -b fix/issue-description

# For documentation
git checkout -b docs/section-update
```

### Making Changes

#### 1. Write Code

Follow our [coding standards](#coding-standards) and:

- Write clear, self-documenting code
- Add appropriate comments for complex logic
- Follow existing patterns and conventions
- Keep functions small and focused

#### 2. Add Tests

- **Unit tests** for individual functions
- **Integration tests** for component interactions
- **Property-based tests** for complex logic
- **Documentation tests** (doctests) for examples

```bash
# Run tests as you develop
mix test

# Run specific test file
mix test test/prismatic/todo/scanner_test.exs

# Run tests with coverage
mix test --cover
```

#### 3. Update Documentation

- Add `@doc` to all public functions
- Update `@moduledoc` for new modules
- Add usage examples to documentation
- Update relevant guides and README

#### 4. Commit Changes

Use [conventional commits](https://www.conventionalcommits.org/):

```bash
# Stage changes
git add .

# Commit with descriptive message
git commit -m "feat(todo): add priority-based sorting

- Implement priority sorting algorithm
- Add tests for sorting edge cases
- Update documentation with examples
- Closes #123"
```

**Commit Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

### Pre-Push Quality Gates

Before pushing, ensure all quality gates pass:

```bash
# Run full test suite
mix test

# Check code quality
mix credo --strict

# Run type checking
mix dialyzer

# Check formatting
mix format --check-formatted

# Generate documentation
mix docs

# Run all checks
./scripts/quality-check.sh
```

## 📥 Pull Request Process

### Creating a Pull Request

1. **Push Your Branch**
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create Pull Request**
   - Go to GitHub and create a pull request
   - Use the pull request template
   - Write a clear title and description
   - Link related issues with `Closes #123`

3. **Pull Request Template**

   Fill out all sections of the PR template:

   ```markdown
   ## Description
   Brief description of changes made.

   ## Type of Change
   - [ ] Bug fix (non-breaking change)
   - [ ] New feature (non-breaking change)
   - [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
   - [ ] Documentation update

   ## Testing
   - [ ] Tests pass locally
   - [ ] Added tests for new functionality
   - [ ] Updated documentation

   ## Screenshots (if applicable)
   Include screenshots of UI changes.

   ## Checklist
   - [ ] Code follows project style guidelines
   - [ ] Self-review of code completed
   - [ ] Code is commented where necessary
   - [ ] Documentation updated
   - [ ] Tests added/updated
   - [ ] All tests pass
   ```

### Review Process

#### What to Expect

1. **Automated Checks**: CI will run tests, linting, and type checking
2. **Maintainer Review**: A maintainer will review your code
3. **Community Review**: Other contributors may provide feedback
4. **Revision Cycle**: You may need to make changes based on feedback

#### Review Criteria

Reviewers will check:

- **Functionality**: Does the code work as intended?
- **Code Quality**: Is the code well-written and maintainable?
- **Testing**: Are there appropriate tests?
- **Documentation**: Is the code properly documented?
- **Performance**: Are there any performance concerns?
- **Security**: Are there any security implications?

#### Responding to Feedback

- **Be Responsive**: Reply to comments promptly
- **Be Open**: Consider all feedback objectively
- **Ask Questions**: If unclear, ask for clarification
- **Make Changes**: Address feedback through code updates

```bash
# Make requested changes
git add .
git commit -m "refactor: address review feedback

- Extract helper function as suggested
- Add error handling for edge case
- Update tests based on review comments"

git push origin feature/your-feature-name
```

### Merge Process

Once approved:

1. **Squash and Merge**: Most PRs are squashed into a single commit
2. **Merge Commit**: Large features may use merge commits
3. **Rebase and Merge**: Clean commits may be rebased

After merge:

```bash
# Clean up local branches
git checkout main
git pull upstream main
git branch -d feature/your-feature-name
git push origin --delete feature/your-feature-name
```

## 📏 Coding Standards

### Elixir Style Guide

We follow the [Elixir Style Guide](https://github.com/christopheradams/elixir_style_guide) with these additions:

#### File Organization

```elixir
defmodule Prismatic.MyModule do
  @moduledoc """
  Module documentation with examples.
  """

  # 1. Module attributes
  @default_timeout 5000

  # 2. Type definitions
  @type config :: %{name: String.t(), timeout: pos_integer()}

  # 3. Module imports and aliases
  alias Prismatic.Shared.Utils
  require Logger

  # 4. Public API functions
  def public_function(config) do
    # Implementation
  end

  # 5. Private helper functions
  defp private_helper do
    # Implementation
  end
end
```

#### Naming Conventions

- **Modules**: `PascalCase` (e.g., `Prismatic.TODO.Scanner`)
- **Functions**: `snake_case` (e.g., `scan_todos/2`)
- **Variables**: `snake_case` (e.g., `scan_result`)
- **Constants**: `@upper_snake_case` (e.g., `@default_timeout`)
- **Atoms**: `snake_case` (e.g., `:scan_complete`)

#### Documentation Standards

```elixir
@doc """
Brief one-line description.

Longer description explaining the function's purpose, behavior,
and any important considerations.

## Parameters

- `param1` - Description of first parameter
- `options` - Keyword list of options:
  - `:timeout` - Request timeout (default: 5000)
  - `:retry` - Retry attempts (default: 3)

## Returns

- `{:ok, result}` - Success with result
- `{:error, reason}` - Error cases:
  - `:invalid_input` - Invalid parameters
  - `:timeout` - Operation timeout

## Examples

    iex> MyModule.function("input", timeout: 1000)
    {:ok, "processed"}

    iex> MyModule.function("", [])
    {:error, :invalid_input}

## See Also

- `related_function/1`
- `Prismatic.RelatedModule`
"""
@spec function(String.t(), keyword()) :: {:ok, String.t()} | {:error, atom()}
def function(input, options \\ [])
```

#### Error Handling

```elixir
# Use tagged tuples for expected errors
def process_data(data) do
  case validate_data(data) do
    :ok -> {:ok, transform_data(data)}
    {:error, reason} -> {:error, reason}
  end
end

# Use with statements for multiple operations
def complex_operation(params) do
  with {:ok, validated} <- validate_params(params),
       {:ok, processed} <- process_data(validated),
       {:ok, result} <- finalize_result(processed) do
    {:ok, result}
  else
    {:error, reason} -> {:error, reason}
  end
end

# Use exceptions for programming errors
def process_data!(data) do
  case process_data(data) do
    {:ok, result} -> result
    {:error, reason} -> raise ArgumentError, message: "Invalid data: #{reason}"
  end
end
```

### Phoenix/Web Standards

#### Controllers

```elixir
defmodule PrismaticWeb.MyController do
  use PrismaticWeb, :controller

  action_fallback PrismaticWeb.FallbackController

  def index(conn, params) do
    with {:ok, items} <- MyContext.list_items(params) do
      render(conn, :index, items: items)
    end
  end

  def create(conn, %{"item" => item_params}) do
    with {:ok, item} <- MyContext.create_item(item_params) do
      conn
      |> put_status(:created)
      |> put_resp_header("location", ~p"/api/v1/items/#{item.id}")
      |> render(:show, item: item)
    end
  end
end
```

#### LiveView

```elixir
defmodule PrismaticWeb.MyLive do
  use PrismaticWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, items: [])}
  end

  @impl true
  def handle_event("add_item", %{"item" => item_params}, socket) do
    case MyContext.create_item(item_params) do
      {:ok, item} ->
        items = [item | socket.assigns.items]
        {:noreply, assign(socket, items: items)}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
```

## 🧪 Testing Guidelines

### Test Structure

```
test/
├── integration/          # End-to-end tests
├── prismatic/           # Unit tests for core app
│   ├── beam/           # BEAM introspection tests
│   ├── todo/           # TODO management tests
│   └── docs/           # Documentation tests
├── prismatic_web/      # Web layer tests
│   ├── controllers/    # Controller tests
│   └── live/          # LiveView tests
└── support/            # Test support modules
```

### Test Types

#### Unit Tests

```elixir
defmodule Prismatic.TODO.ScannerTest do
  use ExUnit.Case, async: true
  doctest Prismatic.TODO.Scanner

  alias Prismatic.TODO.Scanner

  describe "scan_todos/2" do
    test "identifies TODO comments correctly" do
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

    test "handles empty directories" do
      {:ok, result} = Scanner.scan_todos([], %{})
      assert result.total_todos == 0
      assert result.todos == []
    end

    test "returns error for non-existent directories" do
      assert {:error, :directory_not_found} = 
        Scanner.scan_todos(["/non/existent/path"], %{})
    end
  end
end
```

#### Integration Tests

```elixir
defmodule Prismatic.IntegrationTest do
  use ExUnit.Case
  use Plug.Test

  @moduletag :integration

  describe "TODO management workflow" do
    test "complete TODO lifecycle" do
      # Scan
      {:ok, scan_result} = Prismatic.TODO.scan_todos(paths: ["test/fixtures"])
      assert scan_result.total_todos > 0

      # Analyze
      {:ok, analysis} = Prismatic.TODO.analyze_todos()
      assert analysis.categories != %{}

      # Generate report
      {:ok, report} = Prismatic.TODO.generate_report([:json])
      assert byte_size(report) > 0

      # Update status
      todo_id = List.first(scan_result.todos).id
      {:ok, updated} = Prismatic.TODO.update_todo_status(todo_id, :in_progress)
      assert updated.status == :in_progress
    end
  end
end
```

#### Property-Based Tests

```elixir
defmodule Prismatic.TODO.PropertyTest do
  use ExUnit.Case
  use ExUnitProperties

  property "scanner handles all valid TODO formats" do
    check all todo_type <- member_of([:todo, :fixme, :hack, :bug]),
              content <- string(:printable, min_length: 1) do
      
      comment = "#{String.upcase(to_string(todo_type))}: #{content}"
      
      {:ok, parsed} = Prismatic.TODO.Scanner.parse_todo_comment(comment, %{})
      
      assert parsed.type == todo_type
      assert String.contains?(parsed.description, content)
    end
  end
end
```

### Test Best Practices

- **Use descriptive test names** that explain what is being tested
- **Follow Given-When-Then** structure for clarity
- **Test edge cases** and error conditions
- **Use async: true** for tests that don't share state
- **Mock external dependencies** to ensure test reliability
- **Keep tests focused** on single behaviors

### Running Tests

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific tests
mix test test/prismatic/todo/scanner_test.exs
mix test --only integration
mix test --only property

# Run in watch mode
mix test.watch

# Run with specific tags
mix test --exclude slow
mix test --only unit
```

## 📚 Documentation

### Documentation Types

#### Code Documentation

All public functions must have `@doc` with:

- Brief description
- Parameter descriptions
- Return value descriptions
- Usage examples
- Related functions

#### Module Documentation

All modules must have `@moduledoc` with:

- Purpose and scope
- Usage examples
- Configuration options
- See also references

#### Guide Documentation

- **Installation guides** for setup instructions
- **Usage guides** for feature explanation
- **API guides** for integration help
- **Troubleshooting guides** for common issues

### Writing Good Documentation

#### Be Clear and Concise

```elixir
# Good
@doc """
Scans directories for TODO comments and returns structured results.
"""

# Avoid
@doc """
This function does scanning of directories to find TODO comments
and then it processes them and returns some results.
"""
```

#### Include Examples

```elixir
@doc """
Parses a TODO comment and extracts metadata.

## Examples

    iex> parse_todo_comment("TODO: Fix the bug")
    {:ok, %{type: :todo, title: "Fix the bug"}}

    iex> parse_todo_comment("FIXME: [HIGH] Critical issue")
    {:ok, %{type: :fixme, title: "Critical issue", priority: :high}}
"""
```

#### Link Related Content

```elixir
@doc """
Scans for TODO comments in source files.

See also:
- `parse_todo_comment/2` for parsing individual comments
- `Prismatic.TODO.Analyzer` for analyzing scan results
"""
```

### Documentation Tools

```bash
# Generate documentation
mix docs

# Serve documentation locally
mix docs && open doc/index.html

# Check documentation coverage
mix docs --formatter html --priv
```

## 🌐 Community

### Getting Help

- **[GitHub Discussions](https://github.com/korczis/prismatic/discussions)** - Ask questions and share ideas
- **[Discord](https://discord.gg/prismatic)** - Real-time chat with maintainers and contributors
- **[Issues](https://github.com/korczis/prismatic/issues)** - Report bugs and request features
- **[Stack Overflow](https://stackoverflow.com/questions/tagged/prismatic)** - Technical questions with `prismatic` tag

### Contributing Areas

#### Code Contributions

- **Bug fixes** - Fix reported issues
- **Feature development** - Implement new features
- **Performance improvements** - Optimize existing code
- **Refactoring** - Improve code quality and maintainability

#### Non-Code Contributions

- **Documentation** - Improve guides, API docs, and examples
- **Testing** - Add test coverage and improve test quality
- **Design** - UI/UX improvements and design consistency
- **Translation** - Localization and internationalization
- **Community** - Help others, answer questions, write blog posts

### Maintainer Responsibilities

#### Core Maintainers

- **Review pull requests** and provide constructive feedback
- **Merge approved changes** and manage releases
- **Set project direction** and maintain roadmap
- **Support contributors** and maintain community

#### Community Maintainers

- **Help with support** in discussions and issues
- **Review documentation** and suggest improvements
- **Test new features** and report issues
- **Mentor new contributors** and help with onboarding

### Recognition

We recognize all contributors:

- **Contributors list** in README and documentation
- **Release acknowledgments** in changelog and release notes
- **Annual contributor awards** for outstanding contributions
- **Speaking opportunities** at conferences and meetups

---

## 🎉 Thank You!

Thank you for contributing to Prismatic! Your contributions help make this project better for everyone. Whether you're fixing a typo, adding a feature, or helping others in the community, every contribution matters.

**Happy coding!** 🚀

---

For questions about this contributing guide, please [open an issue](https://github.com/korczis/prismatic/issues/new?template=question.md) or reach out in our [Discord community](https://discord.gg/prismatic).