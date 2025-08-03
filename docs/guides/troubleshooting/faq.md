# Frequently Asked Questions (FAQ)

**Common questions and solutions for the Prismatic AI Agent Framework**

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../../README.md) > [Guides](../README.md) > [Troubleshooting](README.md) > FAQ

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to troubleshooting guides
- **🏠 [Documentation Home](../../README.md)** - Main documentation index
- **🔧 [Comprehensive Troubleshooting](comprehensive-troubleshooting-guide.md)** - Detailed troubleshooting procedures
- **🔍 [Error Reference](error-reference-guide.md)** - Common error messages

### Related Documentation

- [Getting Started](../getting-started/README.md) - New user setup guides
- [Development Guidelines](../development/README.md) - Development best practices
- [Deployment Procedures](../deployment/README.md) - Production deployment
- [Performance Optimization](../performance/README.md) - Performance tuning
<!-- NAV_END -->

---

## Table of Contents

1. [General Questions](#general-questions)
2. [Getting Started](#getting-started)
3. [Development Environment](#development-environment)
4. [Technical Architecture](#technical-architecture)
5. [Build and Compilation](#build-and-compilation)
6. [Database and Migrations](#database-and-migrations)
7. [Testing](#testing)
8. [Asset Pipeline](#asset-pipeline)
9. [Phoenix and LiveView](#phoenix-and-liveview)
10. [BEAM VM and Performance](#beam-vm-and-performance)
11. [Deployment and Production](#deployment-and-production)
12. [Contributing](#contributing)
13. [Common Error Messages](#common-error-messages)

---

## General Questions

### What is Prismatic?

**Prismatic** is an advanced AI Agent Framework built with Elixir/Phoenix that provides enterprise-grade BEAM VM introspection, automated TODO management, consolidation tools, and sophisticated documentation systems. It's designed as a Phoenix umbrella application for scalability and modularity.

### What technology stack does Prismatic use?

- **Backend**: Elixir 1.17+, Erlang/OTP 26+
- **Web Framework**: Phoenix 1.7.21+ with LiveView
- **Database**: PostgreSQL 14+
- **Frontend**: Tailwind CSS, esbuild, JavaScript
- **Testing**: ExUnit, Mox, StreamData
- **Build Tools**: Mix, Hex
- **Development**: asdf for version management

### Is Prismatic suitable for production use?

Yes, Prismatic is designed for production use with:
- Comprehensive error handling and logging
- Performance monitoring and optimization
- Zero-downtime deployment strategies  
- Database migration safety
- Security best practices
- Scalable umbrella architecture

### What are the main features of Prismatic?

1. **BEAM VM Introspection** - Deep runtime analysis and monitoring
2. **TODO Management System** - Automated discovery and lifecycle management
3. **Documentation Generation** - Intelligent analysis and gap detection
4. **Consolidation Tools** - Dependency mapping and conflict resolution
5. **AI/LLM Integration** - Advanced AI capabilities and tooling

---

## Getting Started

### What are the system requirements?

**Minimum Requirements**:
- **OS**: macOS, Linux (Ubuntu 20.04+, CentOS 8+)
- **Elixir**: 1.17+ 
- **Erlang/OTP**: 26+
- **Node.js**: 18+
- **PostgreSQL**: 14+
- **Memory**: 4GB RAM (8GB+ recommended)
- **Disk**: 10GB free space

### How do I install Prismatic?

1. **Clone the repository**:
   ```bash
   git clone https://github.com/korczis/prismatic.git
   cd prismatic
   ```

2. **Install dependencies**:
   ```bash
   mix deps.get
   mix ecto.setup
   mix compile
   ```

3. **Start the server**:
   ```bash
   mix phx.server
   ```

4. **Visit**: `http://localhost:4000`

### I'm getting "command not found" errors. What should I do?

This usually means your development environment isn't set up correctly:

1. **Install asdf** for version management:
   ```bash
   git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
   echo '. ~/.asdf/asdf.sh' >> ~/.bashrc
   source ~/.bashrc
   ```

2. **Install required tools**:
   ```bash
   asdf plugin add erlang
   asdf plugin add elixir  
   asdf plugin add nodejs
   asdf install  # Uses .tool-versions file
   ```

3. **Verify installations**:
   ```bash
   elixir --version
   node --version
   psql --version
   ```

### How do I get help if I'm stuck?

1. **Check this FAQ** for common issues
2. **Review the [Comprehensive Troubleshooting Guide](comprehensive-troubleshooting-guide.md)**
3. **Search existing GitHub issues**
4. **Join the community discussions**
5. **Create a new issue** with detailed information

---

## Development Environment

### Should I use asdf or system packages?

**Use asdf** - it's the recommended approach because:
- Ensures consistent versions across team members
- Easy switching between projects with different requirements
- Avoids conflicts with system packages
- Supports the `.tool-versions` file in the project

### My database won't connect. What's wrong?

Common database connection issues:

1. **PostgreSQL not running**:
   ```bash
   # Linux
   sudo systemctl start postgresql
   
   # macOS
   brew services start postgresql@15
   
   # Docker
   docker run -d --name postgres -p 5432:5432 -e POSTGRES_PASSWORD=postgres postgres:15
   ```

2. **Database doesn't exist**:
   ```bash
   mix ecto.create
   mix ecto.migrate
   ```

3. **Wrong connection settings** - Check `config/dev.exs`:
   ```elixir
   config :prismatic, Prismatic.Repo,
     username: "postgres",
     password: "postgres",  # Update if different
     hostname: "localhost",
     database: "prismatic_dev"
   ```

### How do I clean up my development environment?

For a complete reset:
```bash
# Clean all compiled code and dependencies
mix deps.clean --all
mix clean
rm -rf _build deps

# Reset database
mix ecto.reset

# Clear asset cache
cd apps/prismatic_web/assets
rm -rf node_modules package-lock.json
npm cache clean --force
cd ../../..

# Fresh install
mix deps.get
mix compile
cd apps/prismatic_web/assets && npm install && cd ../../..
mix assets.build
```

### Can I use Docker for development?

Yes, but local development is recommended for the best experience. If using Docker:

1. **For database only** (recommended):
   ```bash
   docker run -d --name postgres -p 5432:5432 -e POSTGRES_PASSWORD=postgres postgres:15
   ```

2. **For full development** (optional):
   ```bash
   docker-compose -f docker-compose.dev.yml up
   ```

---

## Technical Architecture

### Why is Prismatic an umbrella application?

Umbrella applications provide:
- **Separation of concerns** - Different apps handle different responsibilities
- **Independent deployment** - Apps can be deployed separately
- **Scalability** - Each app can scale independently
- **Testability** - Easier to test individual components
- **Team collaboration** - Teams can work on different apps

### What's the difference between `prismatic` and `prismatic_web` apps?

- **`prismatic`**: Core business logic, BEAM introspection, TODO management, data models
- **`prismatic_web`**: Phoenix web interface, controllers, LiveView components, API endpoints

This separation follows Phoenix's recommended pattern for umbrella applications.

### How does the BEAM VM introspection work?

Prismatic uses Erlang's built-in introspection capabilities:
- **`:observer`** - For GUI-based system monitoring
- **`:erlang.system_info/1`** - For system information
- **`:erlang.memory/0`** - For memory usage stats
- **`Process.list/0`** - For process enumeration
- **Custom modules** - For application-specific metrics

### What databases are supported?

Currently **PostgreSQL 14+** is the only supported database. It's chosen for:
- **ACID compliance** - Reliable transactions
- **Advanced features** - JSON support, full-text search
- **Performance** - Excellent query optimization
- **Ecosystem** - Great Elixir/Ecto support

### Can I add new Mix tasks?

Yes! Prismatic has extensive Mix task support. Create new tasks in:
- `apps/prismatic/lib/mix/tasks/` for core functionality
- `lib/mix/tasks/` for umbrella-wide tasks

Example:
```elixir
defmodule Mix.Tasks.Prismatic.MyTask do
  use Mix.Task
  
  @shortdoc "Description of my task"
  
  def run(args) do
    # Task implementation
  end
end
```

---

## Build and Compilation

### `mix deps.get` is failing. What should I do?

1. **Update Hex and Rebar**:
   ```bash
   mix local.hex --force
   mix local.rebar --force
   ```

2. **Clear dependency cache**:
   ```bash
   mix deps.clean --all
   rm -rf _build deps
   mix deps.get
   ```

3. **Check for version conflicts**:
   ```bash
   mix deps.tree | grep -E "\*|>"
   ```

### Compilation is slow. How can I speed it up?

1. **Use parallel compilation**:
   ```bash
   export ELIXIR_MAKE_CACHE_DIR=~/.cache/elixir_make
   mix compile --parallel
   ```

2. **Avoid full recompilation**:
   ```bash
   # Instead of mix clean, try:
   mix compile --force
   ```

3. **Use umbrella compilation**:
   ```bash
   # Compile specific app
   cd apps/prismatic
   mix compile
   ```

### I'm getting circular dependency warnings. How do I fix them?

1. **Identify circular dependencies**:
   ```bash
   mix xref graph --format stats
   ```

2. **Refactor shared code** into separate modules:
   ```elixir
   # Move common functions to:
   # lib/prismatic/shared/helpers.ex
   defmodule Prismatic.Shared.Helpers do
     def common_function do
       # Implementation
     end
   end
   ```

3. **Use protocols** for polymorphic behavior instead of cross-dependencies

---

## Database and Migrations

### How do I reset my database?

```bash
# Development
mix ecto.reset

# Test
MIX_ENV=test mix ecto.reset

# Manual steps
mix ecto.drop
mix ecto.create  
mix ecto.migrate
mix run priv/repo/seeds.exs
```

### My migration failed. How do I fix it?

1. **Check migration status**:
   ```bash
   mix ecto.migrations
   ```

2. **Rollback failed migration**:
   ```bash
   mix ecto.rollback
   # Fix the migration file
   mix ecto.migrate
   ```

3. **For stuck migrations**:
   ```sql
   -- Connect to database and clear locks
   SELECT pg_terminate_backend(pid) FROM pg_stat_activity 
   WHERE state = 'idle in transaction' AND pid <> pg_backend_pid();
   ```

### How do I write safe migrations?

```elixir
defmodule MyApp.Repo.Migrations.SafeMigration do
  use Ecto.Migration
  
  def up do
    # Add columns without constraints first
    alter table(:users) do
      add :email, :string
    end
    
    # Populate data
    execute "UPDATE users SET email = 'unknown' WHERE email IS NULL"
    
    # Add constraints after data is populated
    execute "ALTER TABLE users ALTER COLUMN email SET NOT NULL"
  end
end
```

### Can I use database seeds?

Yes, create seeds in `priv/repo/seeds.exs`:

```elixir
# priv/repo/seeds.exs
alias Prismatic.{Accounts, Content}

# Create admin user
{:ok, admin} = Accounts.create_user(%{
  name: "Admin User",
  email: "admin@example.com",
  role: "admin"
})

# Run with: mix run priv/repo/seeds.exs
```

---

## Testing

### How do I run tests?

```bash
# All tests
mix test

# Specific file
mix test test/prismatic/accounts_test.exs

# Specific test
mix test test/prismatic/accounts_test.exs:42

# With coverage
mix test --cover

# Watch mode (if configured)
mix test.watch
```

### My tests are failing with database errors. What's wrong?

1. **Create test database**:
   ```bash
   MIX_ENV=test mix ecto.create
   MIX_ENV=test mix ecto.migrate
   ```

2. **Check test configuration** in `config/test.exs`:
   ```elixir
   config :prismatic, Prismatic.Repo,
     database: "prismatic_test",
     pool: Ecto.Adapters.SQL.Sandbox
   ```

3. **Use proper test setup**:
   ```elixir
   defmodule Prismatic.SomeTest do
     use Prismatic.DataCase, async: true
     
     # Tests here
   end
   ```

### How do I test external API calls?

Use **Mox** for mocking:

1. **Define behaviour**:
   ```elixir
   defmodule Prismatic.ExternalService.Behaviour do
     @callback call(term()) :: {:ok, term()} | {:error, term()}
   end
   ```

2. **Create mock**:
   ```elixir
   # test/support/mocks.ex
   Mox.defmock(Prismatic.ExternalService.Mock, for: Prismatic.ExternalService.Behaviour)
   ```

3. **Use in tests**:
   ```elixir
   import Mox
   setup :verify_on_exit!
   
   test "external service call" do
     expect(Prismatic.ExternalService.Mock, :call, fn _ -> {:ok, "result"} end)
     # Test code
   end
   ```

### Can I run tests in parallel?

Yes, but be careful:

```elixir
# Safe for parallel (no shared state)
defmodule Prismatic.UtilsTest do
  use ExUnit.Case, async: true
end

# Not safe for parallel (database interactions)
defmodule Prismatic.AccountsTest do
  use Prismatic.DataCase, async: false
end
```

---

## Asset Pipeline

### My CSS isn't loading. What's wrong?

1. **Check Tailwind is installed**:
   ```bash
   cd apps/prismatic_web/assets
   npx tailwindcss --version
   ```

2. **Build assets manually**:
   ```bash
   mix assets.build
   # Or
   cd apps/prismatic_web/assets
   npm run build
   ```

3. **Check generated files**:
   ```bash
   ls -la apps/prismatic_web/priv/static/assets/
   ```

### JavaScript isn't working. How do I debug it?

1. **Check browser console** for errors

2. **Verify esbuild configuration**:
   ```bash
   cd apps/prismatic_web/assets
   npx esbuild --version
   ```

3. **Test build process**:
   ```bash
   cd apps/prismatic_web/assets
   npx esbuild js/app.js --bundle --outdir=../priv/static/assets
   ```

4. **Check LiveView connection**:
   ```js
   // In browser console
   window.liveSocket.isConnected()
   ```

### How do I add new CSS/JS dependencies?

1. **Install via npm**:
   ```bash
   cd apps/prismatic_web/assets
   npm install package-name
   ```

2. **Import in your files**:
   ```js
   // apps/prismatic_web/assets/js/app.js
   import "package-name"
   ```

3. **Or add to Tailwind config**:
   ```js
   // tailwind.config.js
   module.exports = {
     plugins: [
       require('@tailwindcss/forms')
     ]
   }
   ```

---

## Phoenix and LiveView

### LiveView isn't updating. What could be wrong?

1. **Check WebSocket connection** in browser dev tools

2. **Verify CSRF token**:
   ```heex
   <!-- In your layout -->
   <meta name="csrf-token" content={get_csrf_token()} />
   ```

3. **Check LiveView JavaScript**:
   ```js
   // apps/prismatic_web/assets/js/app.js
   let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
   let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})
   ```

4. **Verify LiveView mount**:
   ```elixir
   def mount(_params, _session, socket) do
     {:ok, socket}
   end
   ```

### How do I handle forms in LiveView?

```elixir
def mount(_params, _session, socket) do
  changeset = MySchema.changeset(%MySchema{}, %{})
  {:ok, assign(socket, :changeset, changeset)}
end

def handle_event("validate", %{"my_schema" => params}, socket) do
  changeset = MySchema.changeset(%MySchema{}, params)
  {:noreply, assign(socket, :changeset, changeset)}
end

def handle_event("save", %{"my_schema" => params}, socket) do
  case MyContext.create_item(params) do
    {:ok, item} ->
      {:noreply, 
       socket
       |> put_flash(:info, "Item created successfully")
       |> push_redirect(to: Routes.item_path(socket, :show, item))}
    {:error, changeset} ->
      {:noreply, assign(socket, :changeset, changeset)}
  end
end
```

### Can I use regular Phoenix controllers with LiveView?

Yes! Mix and match based on your needs:
- **Controllers** for API endpoints, file downloads, redirects
- **LiveView** for interactive, real-time interfaces
- **Templates** for static pages

Example routing:
```elixir
scope "/", PrismaticWeb do
  pipe_through :browser
  
  get "/", PageController, :home
  live "/dashboard", DashboardLive
  resources "/api/users", UserController, only: [:index, :show]
end
```

---

## BEAM VM and Performance

### How do I monitor application performance?

1. **Use Observer**:
   ```elixir
   :observer.start()
   ```

2. **Check memory usage**:
   ```elixir
   :erlang.memory()
   ```

3. **Monitor processes**:
   ```elixir
   Process.list() |> length()
   :erlang.system_info(:process_count)
   ```

4. **Use telemetry** for custom metrics:
   ```elixir
   :telemetry.execute([:my_app, :action], %{count: 1}, %{user_id: user.id})
   ```

### My application is using too much memory. How do I debug it?

1. **Identify memory-hungry processes**:
   ```elixir
   Process.list()
   |> Enum.map(fn pid -> {pid, Process.info(pid, :memory)} end)
   |> Enum.sort_by(fn {_pid, {:memory, mem}} -> mem end, :desc)
   |> Enum.take(10)
   ```

2. **Check for memory leaks**:
   ```elixir
   # Monitor memory over time
   spawn(fn ->
     :timer.sleep(1000)
     IO.puts("Memory: #{:erlang.memory(:total)}")
   end)
   ```

3. **Use streams for large datasets**:
   ```elixir
   # Instead of loading all records
   MyRepo.all(MySchema)
   
   # Use streaming
   MyRepo.stream(MySchema)
   |> Stream.map(&process_record/1)
   |> Stream.run()
   ```

### How do I profile my application?

1. **Use :fprof**:
   ```elixir
   :fprof.apply(&MyModule.my_function/1, [arg])
   :fprof.profile()
   :fprof.analyse()
   ```

2. **Use :eprof**:
   ```elixir
   :eprof.start_profiling([self()])
   MyModule.my_function(arg)
   :eprof.stop_profiling()
   :eprof.analyze()
   ```

3. **Use benchee** for benchmarking:
   ```elixir
   Benchee.run(%{
     "function_a" => fn -> MyModule.function_a() end,
     "function_b" => fn -> MyModule.function_b() end
   })
   ```

---

## Deployment and Production

### How do I deploy Prismatic to production?

1. **Build release**:
   ```bash
   MIX_ENV=prod mix release
   ```

2. **Set environment variables**:
   ```bash
   export DATABASE_URL="postgresql://user:pass@host:5432/db"
   export SECRET_KEY_BASE="your-secret-key"
   export PHX_HOST="your-domain.com"
   ```

3. **Run migrations**:
   ```bash
   _build/prod/rel/prismatic/bin/prismatic eval "Prismatic.Release.migrate"
   ```

4. **Start application**:
   ```bash
   _build/prod/rel/prismatic/bin/prismatic start
   ```

### Can I use Docker for production?

Yes, use the provided Dockerfile:

```bash
# Build image
docker build -t prismatic .

# Run container
docker run -d \
  -p 4000:4000 \
  -e DATABASE_URL="postgresql://..." \
  -e SECRET_KEY_BASE="..." \
  prismatic
```

### How do I handle database migrations in production?

1. **Create release tasks**:
   ```elixir
   # lib/prismatic/release.ex
   defmodule Prismatic.Release do
     def migrate do
       {:ok, _} = Application.ensure_all_started(:prismatic)
       Ecto.Migrator.run(Prismatic.Repo, :up, all: true)
     end
   end
   ```

2. **Run before starting app**:
   ```bash
   _build/prod/rel/prismatic/bin/prismatic eval "Prismatic.Release.migrate"
   _build/prod/rel/prismatic/bin/prismatic start
   ```

### How do I monitor production applications?

1. **Health checks**:
   ```elixir
   # Add to router
   get "/health", HealthController, :check
   ```

2. **Logging**:
   ```elixir
   # config/prod.exs
   config :logger, level: :info
   ```

3. **Metrics**:
   - Use Telemetry for custom metrics
   - Integrate with Prometheus/Grafana
   - Use APM tools like New Relic

4. **Error tracking**:
   ```elixir
   # Add Sentry or similar
   config :sentry,
     dsn: System.get_env("SENTRY_DSN")
   ```

---

## Contributing

### How do I contribute to Prismatic?

1. **Fork the repository** on GitHub
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make your changes** and add tests
4. **Run the test suite**: `mix test`
5. **Submit a pull request** with a clear description

See the [Contributing Guide](../getting-started/contribution-workflow.md) for detailed instructions.

### What's the code review process?

All contributions go through code review:
1. **Automated checks** (tests, linting, formatting)
2. **Peer review** by maintainers
3. **Discussion** and iteration if needed
4. **Merge** once approved

### Are there coding standards?

Yes, we follow:
- **Elixir style guide** with `mix format`
- **Credo** for code analysis
- **Dialyzer** for type checking
- **ExDoc** for documentation
- **Test coverage** requirements

Run quality checks:
```bash
mix format
mix credo
mix dialyzer
mix test --cover
```

### Can I add new features?

Yes! For significant features:
1. **Open an issue** to discuss the feature
2. **Get feedback** from maintainers
3. **Create a design document** if needed
4. **Implement** with tests and documentation
5. **Submit a pull request**

---

## Common Error Messages

### `(Mix) Could not start application`

**Cause**: Application dependencies not started or configuration error.

**Solution**:
1. Check `application.ex` for missing dependencies
2. Verify database connection
3. Check environment variables

### `(Postgrex.Error) FATAL: database does not exist`

**Solution**:
```bash
mix ecto.create
mix ecto.migrate
```

### `(CompileError) module Foo is not loaded and could not be found`

**Cause**: Missing dependency or incorrect module name.

**Solution**:
1. Check module exists in correct path
2. Verify `mix.exs` dependencies
3. Run `mix deps.get && mix compile`

### `(Phoenix.Router.NoRouteError) no route found`

**Cause**: Route not defined or incorrect path.

**Solution**:
1. Check `router.ex` for missing routes
2. Verify controller action exists
3. Check route helper usage

### `(Ecto.NoResultsError) expected at least one result but got none`

**Cause**: Using `get!` or `one!` functions when record doesn't exist.

**Solution**:
```elixir
# Instead of
user = Repo.get!(User, id)

# Use
case Repo.get(User, id) do
  nil -> {:error, :not_found}
  user -> {:ok, user}
end
```

### `(ArgumentError) argument error`

**Cause**: Various issues - check the full stack trace.

**Solution**:
1. Read the complete error message
2. Check function arguments and types
3. Verify data structures

### `esbuild: command not found`

**Solution**:
```bash
mix esbuild.install
# Or
cd apps/prismatic_web/assets && npm install
```

### `tailwind: command not found`

**Solution**:
```bash
mix tailwind.install
# Or
cd apps/prismatic_web/assets && npm install -D tailwindcss
```

### LiveView `push_event` not working

**Cause**: JavaScript not properly configured.

**Solution**:
1. Check browser console for errors
2. Verify LiveView JavaScript setup
3. Check CSRF token configuration

---

## Still Need Help?

### Documentation Resources

- **[Comprehensive Troubleshooting Guide](comprehensive-troubleshooting-guide.md)** - Detailed procedures
- **[Error Reference Guide](error-reference-guide.md)** - Specific error solutions
- **[Debug Tools Guide](debug-diagnostic-tools.md)** - Advanced debugging
- **[Community Support](community-support-guide.md)** - Getting help

### Community Support

- **GitHub Issues** - Bug reports and feature requests
- **Discussions** - Questions and community help
- **Documentation** - Comprehensive guides and references

### Information to Provide When Asking for Help

1. **Complete error message** and stack trace
2. **Environment details**: OS, Elixir/Erlang versions
3. **Steps to reproduce** the issue
4. **Expected vs actual behavior**
5. **Recent changes** that might be related
6. **Configuration files** (sanitized)

### Debug Information Collection

Use this script to collect debug info:

```bash
#!/bin/bash
# collect-debug-info.sh

echo "=== Environment ==="
elixir --version
node --version
psql --version

echo "=== Dependencies ==="
mix deps

echo "=== Recent Logs ==="
tail -50 _build/dev/lib/*/ebin/*.log 2>/dev/null || echo "No logs found"

echo "=== System Info ==="
uname -a
free -h 2>/dev/null || vm_stat
df -h
```

---

**📚 Keep Learning**: This FAQ covers common questions, but Prismatic is a rich framework. Explore the [comprehensive documentation](../../README.md) to discover advanced features and capabilities.

**🤝 Contribute**: Found an issue not covered here? Help improve this FAQ by submitting a pull request or opening an issue!

**💡 Pro Tip**: Join the community, ask questions, and share your experiences. The best way to learn is by doing and helping others!