# Developer Experience

Complete guide for developer onboarding, daily workflow, and productivity optimization.

## ⏱️ Time Estimates

📖 Reading time: 30 minutes | 🔧 Implementation time: 30 minutes | 📊 Skill level: Beginner

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../../README.md) > [Guides](../README.md) > [Getting Started](README.md) > Developer Experience

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to getting started guides
- **🏠 [Documentation Home](../../README.md)** - Main documentation index
- **🔍 [Search Documentation](../../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Coding Standards](../development/coding-standards.md) - Code style and conventions for consistent development
- [Feature Branch Workflow](../workflow/feature-branch-workflow.md) - Branching strategy and workflow
- [Architecture Overview](../../core/architecture-overview.md) - System design principles and structure
- [Performance Optimization](../performance/performance-optimization.md) - Development tools and practices that support performance
- [Security Guidelines](../security/security-guidelines.md) - Security considerations in development workflow
<!-- NAV_END -->

## Onboarding Process

### New Developer Setup
**Time to first contribution: ~30 minutes**

1. **Environment Prerequisites**
   - Install Elixir ~> 1.14 via [asdf](https://asdf-vm.com/)
   - Install PostgreSQL 12+ 
   - Install Node.js 16+ for asset compilation

2. **Project Setup**
   ```bash
   git clone https://github.com/org/prismatic.git
   cd prismatic
   mix setup    # Installs deps, creates DB, runs migrations
   mix phx.server
   ```

3. **Verification Steps**
   - Visit [`http://localhost:4000`](http://localhost:4000) - Application loads
   - Visit [`http://localhost:4000/dev/dashboard`](http://localhost:4000/dev/dashboard) - Monitoring dashboard
   - Run `mix test` - All tests pass

### First Day Checklist
- [ ] Complete environment setup
- [ ] Read [architecture overview](../../core/architecture-overview.md)
- [ ] Review [coding standards](../development/coding-standards.md) 
- [ ] Browse existing code in [`apps/`](../../../apps/)
- [ ] Make first small contribution (documentation fix, typo correction)

## Daily Development Workflow

### Starting Development
```bash
# Start all services
mix phx.server

# Alternative: Start with IEx console
iex -S mix phx.server
```

### Code Development Cycle
1. **Create Feature Branch**
   ```bash
   git checkout -b feature/user-authentication
   ```

2. **Implement Following Patterns**
   - Business logic in [`apps/prismatic/lib/prismatic/`](../../../apps/prismatic/lib/prismatic/)
   - Web interface in [`apps/prismatic_web/lib/prismatic_web/`](../../../apps/prismatic_web/lib/prismatic_web/)
   - Follow [coding standards](../development/coding-standards.md) for consistency

3. **Test Implementation**
   ```bash
   mix test                    # Run full test suite
   mix test --failed          # Re-run only failed tests
   mix test path/to/test.exs  # Run specific test file
   ```

4. **Validate Changes**
   ```bash
   mix format                 # Auto-format code
   mix credo                  # Static code analysis (if configured)
   mix dialyzer              # Type checking (if configured)
   ```

### Database Workflow
```bash
# Create new migration
mix ecto.gen.migration add_users_table

# Run migrations
mix ecto.migrate

# Reset database (development only)
mix ecto.reset

# Check migration status
mix ecto.migrations
```

## Development Tools

### IDE Setup
**Recommended: VS Code with extensions**
- ElixirLS for language support
- Phoenix Framework snippets
- Tailwind CSS IntelliSense
- GitLens for git integration

### Essential Commands
```bash
# Development
mix phx.server              # Start development server
mix phx.server --open       # Start server and open browser
iex -S mix phx.server      # Start with interactive console

# Code Quality
mix format                  # Format all code
mix format --check-formatted # Check formatting without changes
mix compile --warnings-as-errors # Strict compilation

# Testing
mix test                    # Run all tests
mix test --cover           # Run with coverage report
mix test --stale           # Run only stale tests
mix test.watch             # Continuous testing (with mix_test_watch)

# Database
mix ecto.create            # Create database
mix ecto.drop              # Drop database
mix ecto.migrate           # Run pending migrations
mix ecto.rollback          # Rollback last migration
mix ecto.seed              # Run seed data

# Assets
mix assets.build           # Build development assets
mix assets.deploy          # Build production assets
```

### Interactive Development
**IEx Console Usage**
```elixir
# Reload specific module
iex> r Prismatic.Accounts

# Test functions interactively
iex> Prismatic.Accounts.list_users()

# Inspect LiveView processes
iex> :observer.start()
```

### Debugging Tools
- **Phoenix LiveDashboard**: Real-time application metrics
- **IEx Debugging**: Interactive breakpoints with `IEx.pry()`
- **Logger Output**: Structured logging with different levels
- **Database Query Logging**: Ecto query inspection

## Productivity Optimizations

### Development Speed
- **Live Reload**: Automatic browser refresh on file changes
- **Code Hot Reloading**: Module reloading without server restart
- **Fast Compilation**: Incremental compilation with caching
- **Parallel Testing**: Tests run concurrently for faster feedback

### Code Navigation
- **Context-Based Organization**: Business logic grouped by domain
- **Consistent Naming**: Predictable file and function naming
- **Documentation Links**: Cross-references between code and docs
- **IDE Integration**: Jump-to-definition and find-references

### Quality Feedback
- **Immediate Formatting**: Format-on-save integration
- **Live Error Detection**: Real-time syntax and type checking
- **Test Feedback**: Rapid test execution and reporting
- **Performance Monitoring**: Built-in metrics and profiling

## Common Development Patterns

### Creating New Features
1. **Context First**: Define business logic in core app
2. **Web Interface**: Add controllers/LiveView in web app
3. **Testing**: Comprehensive test coverage for both layers
4. **Documentation**: Update relevant guides and references

### Working with LiveView
```elixir
# Standard LiveView pattern
defmodule PrismaticWeb.UserLive.Index do
  use PrismaticWeb, :live_view
  
  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :users, Prismatic.Accounts.list_users())}
  end
end
```

### Context Development
```elixir
# Context API pattern
defmodule Prismatic.Accounts do
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end
end
```

## Development Environment

### Local Services
- **Application**: [`http://localhost:4000`](http://localhost:4000)
- **LiveDashboard**: [`http://localhost:4000/dev/dashboard`](http://localhost:4000/dev/dashboard)
- **Email Preview**: [`http://localhost:4000/dev/mailbox`](http://localhost:4000/dev/mailbox)
- **Database**: PostgreSQL on localhost:5432

### Configuration Management
- **Development**: [`config/dev.exs`](../../../config/dev.exs)
- **Test**: [`config/test.exs`](../../../config/test.exs)
- **Runtime**: [`config/runtime.exs`](../../../config/runtime.exs)

### Environment Variables
```bash
# Database configuration
DATABASE_URL=postgresql://user:pass@localhost/prismatic_dev

# Application configuration  
SECRET_KEY_BASE=your-secret-key-here
PHX_HOST=localhost
```

## Troubleshooting Common Issues

### Quick Solutions
- **Port already in use**: Kill process on port 4000 or change port in config
- **Database connection failed**: Ensure PostgreSQL is running and configured
- **Asset compilation errors**: Delete `_build` and `deps`, run `mix deps.get`
- **Permission denied**: Check file permissions and ownership

**For detailed troubleshooting**: See [troubleshooting guide](../../operations/troubleshooting.md)

## Team Collaboration

### Code Review Process
1. Create pull request with clear description
2. Ensure all tests pass and code is formatted
3. Request review from relevant team members
4. Address feedback and update documentation if needed

### Communication Patterns
- **Architecture Questions**: Discuss in team channel, document decisions
- **Bug Reports**: Create issues with reproduction steps
- **Feature Ideas**: Propose in team meetings, create ADRs for decisions

## Related Documentation
- [Coding Standards](../development/coding-standards.md) - Code style and conventions
- [Architecture Overview](../../core/architecture-overview.md) - System design principles
- [Deployment Procedures](../../operations/deployment-procedures.md) - Production deployment
- [Troubleshooting](../../operations/troubleshooting.md) - Problem diagnosis and solutions