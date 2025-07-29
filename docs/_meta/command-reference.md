# Command Reference

Comprehensive reference of all commands used in the Prismatic project, including Mix tasks, database operations, testing commands, deployment procedures, and development workflows.

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > [Meta](README.md) > Command Reference

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to meta documentation index
- **🏠 [Documentation Home](../README.md)** - Main documentation index
- **🔍 [Search Documentation](../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Git Hooks Setup](../guides/git-hooks-setup.md) - Git command workflows
- [CI/CD Configuration](../operations/cicd-configuration.md) - Automated command execution
- [Database Setup](../operations/database-setup.md) - Database commands
- [Style Guide](../guides/style-guide.md) - Code formatting commands
- [Semantic Versioning](../guides/semantic-versioning.md) - Version management commands
<!-- NAV_END -->

## Overview

This reference provides a comprehensive list of commands used throughout the Prismatic project development lifecycle. Commands are organized by category and include usage examples, common options, and troubleshooting tips.

## Project Setup

### Initial Setup Commands

```bash
# Clone the repository
git clone https://github.com/example/prismatic.git
cd prismatic

# Install Elixir dependencies
mix deps.get

# Install JavaScript dependencies
cd assets && npm install && cd ..

# Set up the database
mix ecto.setup

# Compile the application
mix compile

# Start the development server
mix phx.server

# Start with IEx (Interactive Elixir)
iex -S mix phx.server
```

### Environment Setup

```bash
# Copy environment configuration
cp config/dev.exs.example config/dev.exs
cp config/test.exs.example config/test.exs

# Generate secret key base
mix phx.gen.secret

# Set up Git hooks
./scripts/setup-git-hooks.sh

# Install development tools
mix archive.install hex phx_new
mix escript.install hex livebook
```

## Mix Commands

### Core Application Commands

#### Server Management
```bash
# Start Phoenix server
mix phx.server

# Start with interactive shell
iex -S mix phx.server

# Start with specific environment
MIX_ENV=prod mix phx.server

# Start with custom port
PORT=4001 mix phx.server

# Start in detached mode (daemon)
mix phx.server --detached
```

#### Compilation
```bash
# Compile application
mix compile

# Force recompilation
mix compile --force

# Compile with warnings as errors
mix compile --warnings-as-errors

# Clean build artifacts
mix clean

# Clean and recompile dependencies
mix deps.clean --all && mix deps.get && mix compile
```

#### Dependencies
```bash
# Get dependencies
mix deps.get

# Get only production dependencies
mix deps.get --only prod

# Update dependencies
mix deps.update --all

# Update specific dependency
mix deps.update phoenix

# Check for outdated dependencies
mix hex.outdated

# Show dependency tree
mix deps.tree

# Audit dependencies for security issues
mix deps.audit
```

### Database Commands

#### Basic Operations
```bash
# Create database
mix ecto.create

# Drop database
mix ecto.drop

# Run migrations
mix ecto.migrate

# Rollback migrations
mix ecto.rollback

# Reset database (drop, create, migrate)
mix ecto.reset

# Setup database (create, migrate, seed)
mix ecto.setup

# Show migration status
mix ecto.migrations
```

#### Migration Management
```bash
# Generate new migration
mix ecto.gen.migration create_users_table

# Generate migration with specific timestamp
mix ecto.gen.migration add_email_to_users --timestamp-format="%Y%m%d%H%M%S"

# Rollback to specific version
mix ecto.rollback --to=20240101120000

# Rollback specific number of migrations
mix ecto.rollback --step=2

# Show SQL for migration
mix ecto.gen.migration create_posts --dry-run
```

#### Schema and Context Generation
```bash
# Generate context with schema
mix phx.gen.context Accounts User users name:string email:string:unique

# Generate schema only
mix phx.gen.schema Accounts.User users name:string email:string

# Generate JSON API
mix phx.gen.json Accounts User users name:string email:string

# Generate HTML resources
mix phx.gen.html Accounts User users name:string email:string

# Generate LiveView resources
mix phx.gen.live Accounts User users name:string email:string
```

#### Seeds and Sample Data
```bash
# Run seeds
mix run priv/repo/seeds.exs

# Run specific seed file
mix run priv/repo/seeds/users.exs

# Run seeds with environment
MIX_ENV=prod mix run priv/repo/seeds.exs
```

### Testing Commands

#### Basic Testing
```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover

# Run specific test file
mix test test/prismatic/accounts_test.exs

# Run specific test by line number
mix test test/prismatic/accounts_test.exs:42

# Run tests matching pattern
mix test --grep "user creation"

# Run tests excluding pattern
mix test --exclude integration
```

#### Test Environment Management
```bash
# Set up test database
MIX_ENV=test mix ecto.setup

# Reset test database
MIX_ENV=test mix ecto.reset

# Run tests in parallel
mix test --max-cases 4

# Run tests with specific partition
MIX_TEST_PARTITION=1 mix test --partitions 4
```

#### Coverage and Reporting
```bash
# Generate coverage report
mix test --cover

# Export coverage data
mix test --export-coverage default

# Generate detailed coverage report
mix test.coverage

# Open coverage report in browser
open cover/excoveralls.html
```

### Code Quality Commands

#### Formatting and Linting
```bash
# Format code
mix format

# Check if code is formatted
mix format --check-formatted

# Format specific files
mix format lib/prismatic/accounts.ex

# Run Credo (static analysis)
mix credo

# Run Credo with strict mode
mix credo --strict

# Run Credo on specific files
mix credo lib/prismatic/accounts.ex
```

#### Type Checking and Security
```bash
# Run Dialyzer (type analysis)
mix dialyzer

# Build Dialyzer PLT files
mix dialyzer --plt

# Run security analysis
mix sobelow

# Run security analysis with config
mix sobelow --config .sobelow-conf

# Check for unused dependencies
mix deps.unlock --check-unused
```

### Asset Commands

#### Asset Compilation
```bash
# Install node dependencies
cd assets && npm install && cd ..

# Build assets for development
mix assets.setup
mix assets.build

# Build assets for production
mix assets.deploy

# Watch assets for changes
cd assets && npm run watch && cd ..
```

#### Asset Development
```bash
# Start asset development server
cd assets && npm run dev && cd ..

# Run asset tests
cd assets && npm test && cd ..

# Lint JavaScript/TypeScript
cd assets && npm run lint && cd ..

# Format assets
cd assets && npm run format && cd ..
```

### Release Commands

#### Production Releases
```bash
# Build release
MIX_ENV=prod mix release

# Build release with specific name
MIX_ENV=prod mix release prismatic

# Start release
_build/prod/rel/prismatic/bin/prismatic start

# Run release in daemon mode
_build/prod/rel/prismatic/bin/prismatic daemon

# Stop release
_build/prod/rel/prismatic/bin/prismatic stop

# Restart release
_build/prod/rel/prismatic/bin/prismatic restart
```

#### Release Management
```bash
# Run remote console
_build/prod/rel/prismatic/bin/prismatic remote

# Execute code in release
_build/prod/rel/prismatic/bin/prismatic eval "Prismatic.Application.version()"

# Run migrations on release
_build/prod/rel/prismatic/bin/prismatic eval "Prismatic.Release.migrate()"

# Check release version
_build/prod/rel/prismatic/bin/prismatic version
```

## Git Commands

### Basic Git Operations

```bash
# Clone repository
git clone https://github.com/example/prismatic.git

# Check status
git status

# Add files to staging
git add .
git add specific-file.ex

# Commit changes
git commit -m "feat: add user authentication"

# Push changes
git push origin main

# Pull latest changes
git pull origin main
```

### Branch Management

```bash
# Create new branch
git checkout -b feature/user-profiles

# Switch branches
git checkout main
git switch develop

# List branches
git branch
git branch -r  # remote branches
git branch -a  # all branches

# Delete branch
git branch -d feature/completed-feature
git push origin --delete feature/completed-feature

# Merge branch
git checkout main
git merge feature/user-profiles
```

### Advanced Git Operations

```bash
# Interactive rebase
git rebase -i HEAD~3

# Squash commits
git rebase -i HEAD~2

# Cherry pick commit
git cherry-pick abc123

# Stash changes
git stash
git stash pop
git stash list

# Reset changes
git reset --hard HEAD
git reset --soft HEAD~1

# Tag release
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

## Docker Commands

### Development with Docker

```bash
# Build development image
docker build -t prismatic:dev .

# Run development container
docker run -p 4000:4000 prismatic:dev

# Build with docker-compose
docker-compose build

# Start services with docker-compose
docker-compose up
docker-compose up -d  # detached mode

# Stop services
docker-compose down

# View logs
docker-compose logs app
docker-compose logs -f app  # follow logs
```

### Production Docker

```bash
# Build production image
docker build -t prismatic:prod --target prod .

# Run production container
docker run -p 4000:4000 \
  -e DATABASE_URL="$DATABASE_URL" \
  -e SECRET_KEY_BASE="$SECRET_KEY_BASE" \
  prismatic:prod

# Tag and push to registry
docker tag prismatic:prod registry.example.com/prismatic:latest
docker push registry.example.com/prismatic:latest

# Clean up images
docker system prune
docker image prune
```

## Database Commands

### PostgreSQL Commands

```bash
# Connect to database
psql -h localhost -U postgres -d prismatic_dev

# Create database user
createuser -P prismatic_user

# Create database
createdb -O prismatic_user prismatic_dev

# Dump database
pg_dump prismatic_dev > backup.sql

# Restore database
psql prismatic_dev < backup.sql

# Show database size
psql -c "SELECT pg_size_pretty(pg_database_size('prismatic_dev'));"
```

### Database Maintenance

```bash
# Vacuum database
psql -c "VACUUM ANALYZE;" prismatic_dev

# Reindex database
psql -c "REINDEX DATABASE prismatic_dev;"

# Show active connections
psql -c "SELECT * FROM pg_stat_activity WHERE datname = 'prismatic_dev';"

# Kill hanging queries
psql -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'prismatic_dev' AND state = 'idle in transaction';"
```

## System Administration

### Process Management

```bash
# Check running processes
ps aux | grep beam
ps aux | grep phoenix

# Kill processes
pkill -f "mix phx.server"
killall beam.smp

# Monitor system resources
top
htop
iostat 1
vmstat 1
```

### Log Management

```bash
# View application logs
tail -f log/dev.log
tail -f log/prod.log

# View system logs (macOS)
log stream --predicate 'process == "beam.smp"'

# View system logs (Linux)
journalctl -u prismatic -f

# Rotate logs
logrotate /etc/logrotate.d/prismatic
```

### Performance Monitoring

```bash
# Monitor database connections
psql -c "SELECT count(*) FROM pg_stat_activity;"

# Check memory usage
free -h
cat /proc/meminfo

# Check disk space
df -h
du -sh /var/log/*

# Network connections
netstat -tulpn | grep :4000
lsof -i :4000
```

## Development Workflow Commands

### Daily Development

```bash
# Start development session
git pull origin main
mix deps.get
mix ecto.migrate
mix phx.server

# Before committing
mix format
mix credo --strict
mix test
git add .
git commit -m "feat: implement user profiles"

# Feature branch workflow
git checkout main
git pull origin main
git checkout -b feature/new-feature
# ... development work ...
git push origin feature/new-feature
# ... create pull request ...
```

### Code Review Preparation

```bash
# Run full quality checks
mix format --check-formatted
mix credo --strict
mix dialyzer
mix sobelow
mix test --cover
mix deps.audit

# Check for security issues
git secrets --scan
gitleaks detect --source .

# Performance testing
mix run --no-halt scripts/performance_test.exs
```

### Release Preparation

```bash
# Version bump
./scripts/bump-version.sh 1.2.0

# Build and test release
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix release

# Test release
_build/prod/rel/prismatic/bin/prismatic eval "Prismatic.Application.version()"

# Create release
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0
```

## CI/CD Commands

### GitHub Actions

```bash
# Test CI locally with act
act -j test

# Validate workflow syntax
actionlint .github/workflows/ci.yml

# Manual workflow trigger
gh workflow run ci.yml

# View workflow runs
gh run list

# View specific run details
gh run view 123456789
```

### Deployment Commands

```bash
# Deploy to staging
./scripts/deploy.sh staging

# Deploy to production
./scripts/deploy.sh production

# Rollback deployment
./scripts/rollback.sh v1.1.0

# Check deployment status
curl -f https://api.prismatic.example.com/health

# View deployment logs
ssh deploy@server 'tail -f /var/log/prismatic/current'
```

## Troubleshooting Commands

### Common Issues

#### Port Already in Use
```bash
# Find process using port 4000
lsof -i :4000
netstat -tulpn | grep :4000

# Kill process using port
kill -9 $(lsof -ti:4000)
```

#### Database Connection Issues
```bash
# Test database connection
psql -h localhost -U postgres -d prismatic_dev -c "SELECT 1;"

# Check PostgreSQL status
pg_ctl status
systemctl status postgresql

# Restart PostgreSQL
brew services restart postgresql  # macOS
systemctl restart postgresql     # Linux
```

#### Memory Issues
```bash
# Check Erlang VM memory usage
mix run -e "IO.inspect(:erlang.memory())"

# Check system memory
free -h
vm_stat  # macOS

# Clear Phoenix compilation cache
mix clean
rm -rf _build/
```

#### Asset Compilation Issues
```bash
# Clear node modules and reinstall
cd assets
rm -rf node_modules package-lock.json
npm install

# Clear webpack cache
rm -rf assets/.cache/

# Check Node.js version
node --version
npm --version
```

### Debug Commands

```bash
# Start with debugger
iex -S mix phx.server

# Enable debug logging
LOG_LEVEL=debug mix phx.server

# Run with profiling
mix profile.fprof -e "YourModule.your_function()"

# Memory profiling
mix profile.eprof -e "YourModule.your_function()"

# Benchmark code
mix run scripts/benchmark.exs

# Generate dependency graph
mix deps.tree --format dot
```

### Performance Analysis

```bash
# Profile application startup
time mix compile
time mix phx.server --no-start

# Database query analysis
QUERY_DEBUG=true mix phx.server

# Check for N+1 queries
mix test --trace

# Asset build time analysis
cd assets
npm run build -- --analyze

# Bundle size analysis
cd assets
npx webpack-bundle-analyzer dist/
```

## Custom Mix Tasks

### Application-Specific Tasks

```bash
# Custom tasks (examples - replace with actual tasks)
mix prismatic.setup              # Complete application setup
mix prismatic.seed.demo          # Generate demo data
mix prismatic.cleanup.logs       # Clean old log files
mix prismatic.backup.create      # Create database backup
mix prismatic.deploy.check       # Pre-deployment health check
mix prismatic.cache.clear        # Clear application cache
mix prismatic.users.export       # Export user data
mix prismatic.metrics.report     # Generate metrics report
```

### Task Development

```bash
# Generate new mix task
mix phx.gen.task MyTask

# Run custom task with arguments
mix my_task --env=prod --verbose

# List all available tasks
mix help | grep prismatic

# Get help for specific task
mix help prismatic.setup
```

## Environment Variables

### Development Environment

```bash
# Common environment variables
export MIX_ENV=dev
export DATABASE_URL="ecto://postgres:postgres@localhost/prismatic_dev"
export SECRET_KEY_BASE=$(mix phx.gen.secret)
export PHX_HOST="localhost"
export PORT=4000

# Debug settings
export LOG_LEVEL=debug
export QUERY_DEBUG=true
export DEBUG=true

# Asset development
export NODE_ENV=development
export WEBPACK_MODE=development
```

### Production Environment

```bash
# Production configuration
export MIX_ENV=prod
export DATABASE_URL="ecto://user:pass@host/database"
export SECRET_KEY_BASE="your-secret-key-base"
export PHX_HOST="prismatic.example.com"
export PORT=4000

# SSL and security
export FORCE_SSL=true
export SECURE_COOKIES=true

# Performance settings
export POOL_SIZE=20
export MAX_CONNECTIONS=1000
```

## Quick Reference

### Most Used Commands

```bash
# Daily development
mix phx.server                   # Start development server
mix test                         # Run tests
mix format                       # Format code
git status                       # Check git status

# Database operations
mix ecto.migrate                 # Run migrations
mix ecto.reset                   # Reset database
mix ecto.gen.migration name      # Generate migration

# Code quality
mix credo --strict               # Static analysis
mix dialyzer                     # Type checking
mix sobelow                      # Security analysis

# Deployment
mix deps.get --only prod         # Get production deps
MIX_ENV=prod mix compile         # Compile for production
MIX_ENV=prod mix release         # Build release
```

### Emergency Commands

```bash
# Application not responding
pkill -f "mix phx.server"        # Kill development server
kill -9 $(lsof -ti:4000)        # Kill process on port 4000

# Database issues
mix ecto.drop && mix ecto.setup  # Reset database completely
psql -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity;" # Kill DB connections

# Asset issues
cd assets && rm -rf node_modules && npm install # Reinstall node modules
mix clean && mix compile         # Clean and recompile

# Git issues
git stash && git pull            # Stash changes and pull
git reset --hard HEAD            # Discard all local changes
```

## Related Documentation

- [Git Hooks Setup](../guides/git-hooks-setup.md) - Automated command execution and validation
- [CI/CD Configuration](../operations/cicd-configuration.md) - Automated deployment commands
- [Database Setup](../operations/database-setup.md) - Database administration commands
- [Style Guide](../guides/style-guide.md) - Code quality and formatting commands
- [Semantic Versioning](../guides/semantic-versioning.md) - Version management commands

---

**This command reference serves as a comprehensive guide for all development, deployment, and maintenance operations in the Prismatic project. Keep it updated as new commands and workflows are introduced.**