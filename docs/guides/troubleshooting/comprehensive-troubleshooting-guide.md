# Comprehensive Troubleshooting Guide

**Systematic troubleshooting resource for the Prismatic AI Agent Framework**

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../../README.md) > [Guides](../README.md) > [Troubleshooting](README.md) > Comprehensive Troubleshooting Guide

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to troubleshooting guides
- **🏠 [Documentation Home](../../README.md)** - Main documentation index
- **🔍 [FAQ](faq.md)** - Frequently asked questions
- **🔧 [Error Reference](error-reference-guide.md)** - Common error messages and solutions

### Related Documentation

- [Environment Setup](../getting-started/environment-setup.md) - Development environment configuration
- [Error Handling & Logging](../development/error-handling-logging.md) - Application error patterns
- [Deployment Procedures](../deployment/deployment-procedures.md) - Production deployment troubleshooting
- [Performance Optimization](../performance/performance-optimization.md) - Performance issue diagnosis
- [LLM Troubleshooting](../ai-llm/troubleshooting.md) - AI/LLM specific issues
<!-- NAV_END -->

---

## Table of Contents

1. [Overview](#overview)
2. [Development Environment Issues](#development-environment-issues)
3. [Build System Problems](#build-system-problems)
4. [Database Issues](#database-issues)
5. [Asset Compilation Problems](#asset-compilation-problems)
6. [Testing Framework Issues](#testing-framework-issues)
7. [CI/CD Pipeline Problems](#cicd-pipeline-problems)
8. [Performance Issues](#performance-issues)
9. [Phoenix/LiveView Issues](#phoenixliveview-issues)
10. [BEAM VM Introspection Issues](#beam-vm-introspection-issues)
11. [Emergency Procedures](#emergency-procedures)
12. [Diagnostic Commands Reference](#diagnostic-commands-reference)

---

## Overview

This guide provides systematic troubleshooting strategies for common issues encountered in the Prismatic project. It follows a structured approach:

1. **Identify** - Gather symptoms and error information
2. **Isolate** - Narrow down the problem scope
3. **Investigate** - Use diagnostic tools and techniques
4. **Implement** - Apply targeted solutions
5. **Validate** - Verify the fix works correctly
6. **Document** - Record the solution for future reference

### Emergency Contact Information

```
🚨 CRITICAL ISSUES
- Production Outage: Follow emergency procedures below
- Security Incident: Contact security team immediately
- Data Loss: Stop all operations, contact database team
```

### Quick Diagnostic Commands

```bash
# Environment check
elixir --version && erl -eval 'erlang:system_info(otp_release), halt().'
node --version && npm --version
psql --version

# Application health
mix test --only smoke
curl -f http://localhost:4000/health

# Clean rebuild
mix deps.clean --all && mix clean && mix deps.get && mix compile
```

---

## Development Environment Issues

### Elixir/Erlang Version Conflicts

**Symptoms**:
- `elixir: command not found`
- Version mismatch warnings during compilation
- Compilation failures with cryptic OTP errors
- Mix commands failing with undefined function errors

**Diagnosis**:
```bash
# Check current versions
elixir --version
erl -eval 'erlang:system_info(otp_release), halt().'

# Check if using version manager
asdf current 2>/dev/null || echo "asdf not installed"
kiex list 2>/dev/null || echo "kiex not installed"

# Check PATH for conflicts
echo $PATH | tr ':' '\n' | grep -E '(elixir|erlang)'
which elixir erl
```

**Solutions**:

1. **Install asdf (Recommended)**:
   ```bash
   # Install asdf
   git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1
   echo '. ~/.asdf/asdf.sh' >> ~/.bashrc
   source ~/.bashrc
   
   # Install plugins
   asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git
   asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git
   
   # Install versions from .tool-versions
   asdf install
   ```

2. **Manual Version Installation**:
   ```bash
   # Install specific versions
   asdf install erlang 26.2.1
   asdf install elixir 1.17.2-otp-26
   asdf global erlang 26.2.1
   asdf global elixir 1.17.2-otp-26
   
   # Verify installation
   elixir --version
   ```

3. **Clean Conflicting Installations**:
   ```bash
   # Remove system installations (macOS)
   brew uninstall elixir erlang
   
   # Remove system installations (Ubuntu)
   sudo apt remove elixir erlang-base erlang-dev
   
   # Clean PATH conflicts
   export PATH="$HOME/.asdf/shims:$PATH"
   ```

### Node.js and Asset Pipeline Issues

**Symptoms**:
- `npm: command not found`
- Asset compilation failures
- Tailwind CSS not working
- JavaScript build errors
- `mix assets.build` failing

**Diagnosis**:
```bash
# Check Node.js installation
node --version
npm --version

# Check asset directories
ls -la apps/prismatic_web/assets/
ls -la apps/prismatic_web/priv/static/assets/

# Check package.json
cat apps/prismatic_web/assets/package.json

# Check Mix asset configuration
grep -r "esbuild\|tailwind" config/
```

**Solutions**:

1. **Install Node.js with asdf**:
   ```bash
   asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
   asdf install nodejs 18.19.0
   asdf global nodejs 18.19.0
   node --version
   ```

2. **Fix Asset Dependencies**:
   ```bash
   cd apps/prismatic_web/assets
   
   # Clean install
   rm -rf node_modules package-lock.json
   npm cache clean --force
   npm install
   
   # Test compilation
   npm run build
   ```

3. **Configure Mix Assets**:
   ```bash
   # Install Mix asset tools
   mix tailwind.install
   mix esbuild.install
   
   # Build assets
   mix assets.setup
   mix assets.build
   ```

### Database Connection Issues

**Symptoms**:
- `connection refused` errors
- `database "prismatic_dev" does not exist`
- Application won't start due to database errors
- Mix tasks hanging on database operations

**Diagnosis**:
```bash
# Check PostgreSQL status
pg_isready -h localhost -p 5432
sudo systemctl status postgresql  # Linux
brew services list | grep postgres  # macOS

# Test connection manually
psql postgresql://postgres:postgres@localhost:5432/postgres

# Check configuration
grep -r "database\|username\|password" config/dev.exs
echo $DATABASE_URL
```

**Solutions**:

1. **Start PostgreSQL Service**:
   ```bash
   # Linux (systemd)
   sudo systemctl start postgresql
   sudo systemctl enable postgresql
   
   # macOS (Homebrew)
   brew services start postgresql@15
   
   # Docker
   docker run -d --name postgres \
     -p 5432:5432 \
     -e POSTGRES_PASSWORD=postgres \
     postgres:15
   ```

2. **Create and Setup Database**:
   ```bash
   # Create databases
   mix ecto.create
   
   # Run migrations
   mix ecto.migrate
   
   # Seed data (if available)
   mix run priv/repo/seeds.exs
   ```

3. **Fix Configuration Issues**:
   ```elixir
   # config/dev.exs - Ensure correct database config
   config :prismatic, Prismatic.Repo,
     username: "postgres",
     password: "postgres",
     hostname: "localhost",
     database: "prismatic_dev",
     stacktrace: true,
     show_sensitive_data_on_connection_error: true,
     pool_size: 10
   ```

---

## Build System Problems

### Mix Dependency Issues

**Symptoms**:
- `mix deps.get` fails with resolution errors
- Compilation errors mentioning missing modules
- Hex package download failures
- Version conflict warnings

**Diagnosis**:
```bash
# Check dependency status
mix deps
mix deps.tree

# Look for conflicts
mix deps.tree | grep -E "\*|>"

# Check for outdated dependencies
mix hex.outdated

# Verify mix.lock integrity
head -20 mix.lock
```

**Solutions**:

1. **Clean Dependency Resolution**:
   ```bash
   # Complete clean
   mix deps.clean --all
   mix clean
   rm -rf _build deps
   
   # Fresh install
   mix deps.get
   mix deps.compile
   ```

2. **Resolve Version Conflicts**:
   ```bash
   # Update all dependencies
   mix deps.update --all
   
   # Update specific problematic deps
   mix deps.update phoenix ecto
   
   # Check for required overrides
   mix deps.tree | grep ">"
   ```

3. **Hex Registry Issues**:
   ```bash
   # Update Hex itself
   mix local.hex --force
   mix local.rebar --force
   
   # Clear Hex cache
   rm -rf ~/.hex
   mix local.hex
   ```

### Compilation Errors

**Symptoms**:
- `mix compile` fails with module not found
- Macro expansion errors
- Circular dependency warnings
- Protocol consolidation failures

**Diagnosis**:
```bash
# Compile with verbose output
mix compile --verbose --warnings-as-errors

# Force recompilation
mix compile --force

# Check for circular dependencies
mix xref graph --format stats

# Protocol consolidation issues
mix compile.protocols
```

**Solutions**:

1. **Fix Module Dependencies**:
   ```elixir
   # Ensure proper module definition
   defmodule Prismatic.SomeModule do
     # Module should be in lib/prismatic/some_module.ex
   end
   
   # Check aliases and imports
   alias Prismatic.{Accounts, Content}
   import Ecto.Query
   ```

2. **Resolve Circular Dependencies**:
   ```bash
   # Identify circular deps
   mix xref graph --format dot > deps.dot
   
   # Refactor shared code into separate modules
   # Move common functions to Prismatic.Shared
   ```

3. **Protocol Issues**:
   ```bash
   # Clean protocols
   mix clean
   mix compile.protocols
   mix compile
   ```

---

## Database Issues

### Migration Failures

**Symptoms**:
- `mix ecto.migrate` hangs or times out
- `column "xyz" already exists` errors
- Foreign key constraint violations during migration
- Lock timeout errors

**Diagnosis**:
```bash
# Check migration status
mix ecto.migrations

# Check database locks
psql prismatic_dev -c "SELECT * FROM pg_locks WHERE locktype = 'advisory';"

# Check running queries
psql prismatic_dev -c "SELECT pid, query FROM pg_stat_activity WHERE state = 'active';"

# Examine specific migration
cat priv/repo/migrations/$(ls priv/repo/migrations/ | tail -1)
```

**Solutions**:

1. **Handle Failed Migrations**:
   ```bash
   # Rollback last migration
   mix ecto.rollback
   
   # Rollback to specific version
   mix ecto.rollback --to 20240101000000
   
   # Check and fix migration
   # Then run again
   mix ecto.migrate
   ```

2. **Clear Database Locks**:
   ```sql
   -- Connect to database
   psql prismatic_dev
   
   -- Kill blocking queries
   SELECT pg_terminate_backend(pid) 
   FROM pg_stat_activity 
   WHERE state = 'idle in transaction' AND pid <> pg_backend_pid();
   ```

3. **Safe Migration Patterns**:
   ```elixir
   # Add existence checks
   def up do
     execute "ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(255)"
   end
   
   # Or use Ecto helpers with error handling
   def up do
     try do
       alter table(:users) do
         add :email, :string
       end
     rescue
       Postgrex.Error -> :ok
     end
   end
   ```

### Data Integrity Issues

**Symptoms**:
- Foreign key constraint errors
- Unique constraint violations
- Data corruption warnings
- Inconsistent application state

**Diagnosis**:
```sql
-- Check constraints
\d+ table_name

-- Find orphaned records
SELECT * FROM child_table c
LEFT JOIN parent_table p ON c.parent_id = p.id
WHERE p.id IS NULL;

-- Check data consistency
SELECT COUNT(*) FROM users WHERE email IS NULL;
```

**Solutions**:

1. **Clean Orphaned Data**:
   ```sql
   -- Backup first!
   CREATE TABLE backup_table AS SELECT * FROM problematic_table;
   
   -- Remove orphaned records
   DELETE FROM child_table 
   WHERE parent_id NOT IN (SELECT id FROM parent_table);
   ```

2. **Add Missing Constraints**:
   ```elixir
   # Create repair migration
   defmodule Prismatic.Repo.Migrations.AddMissingConstraints do
     use Ecto.Migration
     
     def up do
       create constraint(:posts, :valid_status, check: "status IN ('draft', 'published', 'archived')")
     end
   end
   ```

---

## Asset Compilation Problems

### Tailwind CSS Issues

**Symptoms**:
- Styles not loading in browser
- `tailwind: command not found`
- CSS classes not working
- Build process hanging on CSS compilation

**Diagnosis**:
```bash
# Check Tailwind installation
cd apps/prismatic_web/assets
npx tailwindcss --version

# Check configuration
cat tailwind.config.js
ls -la css/

# Check generated CSS
ls -la ../priv/static/assets/app.css
head -20 ../priv/static/assets/app.css
```

**Solutions**:

1. **Install and Configure Tailwind**:
   ```bash
   cd apps/prismatic_web/assets
   npm install -D tailwindcss @tailwindcss/forms
   npx tailwindcss init
   ```

2. **Fix Configuration**:
   ```js
   // tailwind.config.js
   module.exports = {
     content: [
       "../lib/**/*.{ex,heex}",
       "../lib/**/*_html.ex",
       "./js/**/*.js"
     ],
     theme: {
       extend: {},
     },
     plugins: [
       require("@tailwindcss/forms")
     ],
   }
   ```

3. **Manual Build Test**:
   ```bash
   cd apps/prismatic_web/assets
   npx tailwindcss -i css/app.css -o ../priv/static/assets/app.css --watch
   ```

### esbuild Problems

**Symptoms**:
- JavaScript not compiling
- Module resolution errors
- `esbuild: command not found`
- Phoenix LiveView not working

**Diagnosis**:
```bash
# Check esbuild
cd apps/prismatic_web/assets
npx esbuild --version

# Check JS files
ls -la js/
cat js/app.js

# Check build output
ls -la ../priv/static/assets/app.js
```

**Solutions**:

1. **Install esbuild**:
   ```bash
   # Via Mix
   mix esbuild.install
   
   # Or via npm
   cd apps/prismatic_web/assets
   npm install -D esbuild
   ```

2. **Fix JavaScript Issues**:
   ```js
   // apps/prismatic_web/assets/js/app.js
   import "../css/app.css"
   import "./phoenix"
   import "./live_view"
   
   // Import LiveView
   import {Socket} from "phoenix"
   import {LiveSocket} from "phoenix_live_view"
   
   let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
   let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}})
   
   liveSocket.connect()
   window.liveSocket = liveSocket
   ```

3. **Test Build Process**:
   ```bash
   # Test esbuild directly
   cd apps/prismatic_web/assets
   npx esbuild js/app.js --bundle --outdir=../priv/static/assets
   
   # Or use Mix
   mix esbuild prismatic_web
   ```

---

## Testing Framework Issues

### ExUnit Test Failures

**Symptoms**:
- Tests fail with database connection errors
- Intermittent test failures (flaky tests)
- Test suite hanging or timing out
- `mix test` command not found

**Diagnosis**:
```bash
# Run tests with verbose output
mix test --verbose

# Check test database
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate

# Run specific test
mix test test/prismatic/accounts_test.exs:42

# Check test configuration
cat config/test.exs
```

**Solutions**:

1. **Fix Test Database Setup**:
   ```bash
   # Reset test database
   MIX_ENV=test mix ecto.reset
   
   # Ensure proper test config
   # config/test.exs should have:
   # config :prismatic, Prismatic.Repo,
   #   pool: Ecto.Adapters.SQL.Sandbox
   ```

2. **Fix Async Test Issues**:
   ```elixir
   defmodule Prismatic.AccountsTest do
     use Prismatic.DataCase, async: true  # Only if tests are independent
     
     setup do
       # Clean setup for each test
       user = user_fixture()
       {:ok, user: user}
     end
   end
   ```

3. **Handle Flaky Tests**:
   ```elixir
   # Use proper cleanup
   setup do
     on_exit(fn ->
       # Clean up any state
     end)
   end
   
   # Use Mox for external services
   setup :verify_on_exit!
   ```

### Mocking and External Services

**Symptoms**:
- Tests making real HTTP requests
- External API failures breaking tests
- Mock expectations not working

**Solutions**:

1. **Setup Mox Properly**:
   ```elixir
   # test/support/mocks.ex
   Mox.defmock(Prismatic.ExternalService.Mock, for: Prismatic.ExternalService.Behaviour)
   
   # In test
   import Mox
   setup :verify_on_exit!
   
   test "service call" do
     expect(Prismatic.ExternalService.Mock, :call, fn _ -> {:ok, "result"} end)
     # Test code here
   end
   ```

2. **Use Bypass for HTTP**:
   ```elixir
   # Add to deps: {:bypass, "~> 2.1", only: :test}
   
   defmodule Prismatic.HttpTest do
     use ExUnit.Case
     
     setup do
       bypass = Bypass.open()
       {:ok, bypass: bypass}
     end
     
     test "http request", %{bypass: bypass} do
       Bypass.expect_once(bypass, "GET", "/api/data", fn conn ->
         Plug.Conn.resp(conn, 200, ~s<{"status": "ok"}>)
       end)
       
       # Test HTTP client code
     end
   end
   ```

---

## Emergency Procedures

### Production Outage Response

**Immediate Actions** (First 5 minutes):
1. Acknowledge the incident
2. Check monitoring dashboards
3. Determine scope (partial/complete outage)
4. Enable maintenance mode if needed
5. Notify stakeholders

**Emergency Response Script**:
```bash
#!/bin/bash
# emergency-response.sh

echo "🚨 PRODUCTION OUTAGE RESPONSE - $(date)"

# Quick health check
echo "=== Health Check ==="
curl -f http://localhost:4000/health || echo "❌ Health check failed"

# System resources
echo "=== System Resources ==="
free -h
df -h /
ps aux | grep beam | head -5

# Application logs
echo "=== Recent Errors ==="
tail -50 /var/log/prismatic/error.log

# Database status
echo "=== Database Status ==="
psql $DATABASE_URL -c "SELECT 1;" || echo "❌ Database connection failed"

# Recovery options
echo "=== Recovery Options ==="
echo "1. Restart application: systemctl restart prismatic"
echo "2. Rollback deployment: ./scripts/rollback.sh"
echo "3. Scale up: docker-compose up -d --scale app=4"

read -p "Choose action (1-3) or Enter to skip: " action
case $action in
  1) systemctl restart prismatic ;;
  2) ./scripts/rollback.sh ;;
  3) docker-compose up -d --scale app=4 ;;
esac
```

### Database Emergency Procedures

**Data Corruption Response**:
```bash
# STOP APPLICATION IMMEDIATELY
systemctl stop prismatic

# Create emergency backup
pg_dump $DATABASE_URL > emergency_backup_$(date +%Y%m%d_%H%M%S).sql

# Check database integrity
psql $DATABASE_URL -c "REINDEX DATABASE prismatic_prod;"
psql $DATABASE_URL -c "VACUUM ANALYZE;"

# If corruption confirmed, restore from backup
# psql $DATABASE_URL < latest_backup.sql
```

### Rollback Procedures

**Quick Application Rollback**:
```bash
#!/bin/bash
# rollback.sh
PREVIOUS_VERSION=${1:-"previous"}

echo "🔄 Rolling back to: $PREVIOUS_VERSION"

# Stop current version
docker-compose down

# Deploy previous version
export APP_VERSION=$PREVIOUS_VERSION
docker-compose up -d

# Verify rollback
for i in {1..30}; do
  if curl -f http://localhost:4000/health; then
    echo "✅ Rollback successful"
    exit 0
  fi
  sleep 10
done

echo "❌ Rollback verification failed"
exit 1
```

---

## Diagnostic Commands Reference

### System Diagnostics

```bash
# System information
uname -a
uptime
free -h
df -h

# Process monitoring
ps aux | grep beam
top -p $(pgrep beam.smp)

# Network status
netstat -tulpn | grep :4000
ss -tulpn | grep :5432

# Disk I/O
iostat -x 1 3
```

### Application Diagnostics

```elixir
# In IEx session (iex -S mix)

# Memory usage
:erlang.memory()

# Process information
length(Process.list())
:erlang.system_info(:process_count)

# Application status
Application.started_applications()

# Database connection pool
Ecto.Adapters.SQL.Sandbox.checkin(Prismatic.Repo)

# Phoenix endpoint info
Phoenix.Endpoint.server_info(PrismaticWeb.Endpoint)
```

### Database Diagnostics

```sql
-- Active connections
SELECT * FROM pg_stat_activity WHERE datname = 'prismatic_prod';

-- Long running queries
SELECT pid, now() - pg_stat_activity.query_start AS duration, query 
FROM pg_stat_activity 
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';

-- Database size
SELECT pg_size_pretty(pg_database_size('prismatic_prod'));

-- Table sizes
SELECT schemaname,tablename,pg_size_pretty(size) as size
FROM (
  SELECT schemaname,tablename,pg_total_relation_size(schemaname||'.'||tablename) as size
  FROM pg_tables
) AS TABLES
ORDER BY size DESC;
```

### Performance Diagnostics

```bash
# CPU and memory usage
top -bn1 | head -20
ps aux --sort=-%mem | head -10

# Load testing
ab -n 1000 -c 10 http://localhost:4000/

# Response time measurement
curl -w "@curl-format.txt" -o /dev/null -s http://localhost:4000/

# Create curl-format.txt:
echo 'time_namelookup:  %{time_namelookup}\ntime_connect:     %{time_connect}\ntime_appconnect:  %{time_appconnect}\ntime_pretransfer: %{time_pretransfer}\ntime_redirect:    %{time_redirect}\ntime_starttransfer: %{time_starttransfer}\n                 ----------\ntime_total:       %{time_total}\n' > curl-format.txt
```

---

## Getting Help

### Information to Gather Before Asking

1. **Complete error messages** and stack traces
2. **Environment details**: OS, Elixir/Erlang versions
3. **Steps to reproduce** the issue
4. **Expected vs actual behavior**
5. **Recent changes** that might be related

### Debug Information Collection Script

```bash
#!/bin/bash
# collect-debug-info.sh

DEBUG_DIR="debug-$(date +%Y%m%d_%H%M%S)"
mkdir -p $DEBUG_DIR

echo "📊 Collecting debug information in $DEBUG_DIR/"

# System information
uname -a > $DEBUG_DIR/system.txt
free -h > $DEBUG_DIR/memory.txt
df -h > $DEBUG_DIR/disk.txt
ps aux | grep beam > $DEBUG_DIR/processes.txt

# Elixir/Erlang versions
elixir --version > $DEBUG_DIR/elixir-version.txt 2>&1
erl -eval 'erlang:system_info(otp_release), halt().' > $DEBUG_DIR/otp-version.txt 2>&1

# Mix information
mix --version > $DEBUG_DIR/mix-version.txt 2>&1
mix deps > $DEBUG_DIR/deps.txt 2>&1

# Application logs (if available)
cp /var/log/prismatic/*.log $DEBUG_DIR/ 2>/dev/null || echo "No logs found"

# Configuration (sanitized)
cp config/*.exs $DEBUG_DIR/ 2>/dev/null
# Remove sensitive information
sed -i 's/password: "[^"]*"/password: "[REDACTED]"/g' $DEBUG_DIR/*.exs 2>/dev/null
sed -i 's/secret_key_base: "[^"]*"/secret_key_base: "[REDACTED]"/g' $DEBUG_DIR/*.exs 2>/dev/null

echo "✅ Debug information collected in $DEBUG_DIR/"
tar -czf $DEBUG_DIR.tar.gz $DEBUG_DIR/
echo "📦 Archive created: $DEBUG_DIR.tar.gz"
echo "📤 Please attach this file when asking for help"
```

### Escalation Process

1. **Self-help**: Try troubleshooting guides and FAQ
2. **Community**: Ask in community forums with debug info
3. **Issues**: Create GitHub issue for confirmed bugs
4. **Emergency**: Use emergency contacts for critical production issues

---

**🔧 Pro Tips**:
- Always check the logs first
- Verify your environment matches requirements
- Try a clean rebuild before deep debugging
- Document solutions you find for others

**🚨 Remember**: For production issues, prioritize service restoration over root cause analysis. Fix first, investigate later.

**📖 Next Steps**: 
- Check the [FAQ](faq.md) for common questions
- Review [Error Reference Guide](error-reference-guide.md) for specific errors
- Use [Debug Tools Guide](debug-diagnostic-tools.md) for advanced techniques