# Command Reference

Comprehensive reference for all CLI commands, Mix tasks, and scripts available in the Prismatic project.

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > [Reference](README.md) > Command Reference

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to reference index
- **🏠 [Documentation Home](../README.md)** - Main documentation index
- **🔍 [Search Documentation](glossary.md)** - Find terms and concepts

### Related Documentation

- [Developer Experience](../guides/developer-experience.md) - Development workflow and setup
- [Deployment Procedures](../operations/deployment-procedures.md) - Deployment commands and procedures
- [Database Setup](../operations/database-setup.md) - Database management commands
- [CI/CD Configuration](../operations/cicd-configuration.md) - Automated command execution
- [Git Hooks Setup](../guides/git-hooks-setup.md) - Git automation commands
<!-- NAV_END -->

## Overview

This reference provides comprehensive documentation for all command-line interfaces, Mix tasks, npm scripts, and utility scripts used in the Prismatic project. Commands are organized by category with detailed usage examples and options.

## Mix Commands

### Development Commands

#### Project Setup
```bash
# Install dependencies
mix deps.get

# Compile the project
mix compile

# Compile with warnings as errors
mix compile --warnings-as-errors

# Clean compiled files
mix clean

# Get dependency updates
mix deps.update --all
```

#### Database Commands
```bash
# Create database
mix ecto.create

# Run migrations
mix ecto.migrate

# Rollback migration
mix ecto.rollback

# Reset database (drop, create, migrate, seed)
mix ecto.reset

# Generate migration
mix ecto.gen.migration create_users

# Check migration status
mix ecto.migrations

# Seed database
mix run priv/repo/seeds.exs
```

#### Development Server
```bash
# Start Phoenix server
mix phx.server

# Start server with IEx console
iex -S mix phx.server

# Start server on specific port
PORT=4001 mix phx.server
```

### Testing Commands

#### Test Execution
```bash
# Run all tests
mix test

# Run specific test file
mix test test/prismatic/accounts_test.exs

# Run tests with specific tag
mix test --only integration

# Run tests excluding specific tag
mix test --exclude slow

# Run tests with coverage
mix test --cover

# Run tests in parallel
mix test --max-cases 4

# Run tests with detailed output
mix test --trace
```

#### Test Generation
```bash
# Generate ExUnit test file
mix test.gen

# Generate test with specific template
mix test.gen --template=context
```

### Code Quality Commands

#### Formatting and Linting
```bash
# Format code
mix format

# Check if code is formatted
mix format --check-formatted

# Format specific files
mix format lib/**/*.ex

# Run Credo analysis
mix credo

# Run Credo with strict checks
mix credo --strict

# Run Credo on specific files
mix credo lib/prismatic/accounts.ex
```

#### Type Checking
```bash
# Run Dialyzer
mix dialyzer

# Build PLT (first run)
mix dialyzer --plt

# Run Dialyzer with warnings
mix dialyzer --format github
```

#### Security Analysis
```bash
# Run Sobelow security scan
mix sobelow

# Run with configuration file
mix sobelow --config .sobelow-conf

# Scan specific paths
mix sobelow --router lib/prismatic_web/router.ex
```

### Documentation Commands

#### Generate Documentation
```bash
# Generate HTML documentation
mix docs

# Generate documentation and open
mix docs --open

# Generate documentation with specific format
mix docs --formatter html
```

### Release Commands

#### Production Release
```bash
# Build production release
MIX_ENV=prod mix release

# Build release with specific name
MIX_ENV=prod mix release prismatic

# Run release
_build/prod/rel/prismatic/bin/prismatic start

# Run release daemon
_build/prod/rel/prismatic/bin/prismatic daemon

# Stop release
_build/prod/rel/prismatic/bin/prismatic stop

# Get release status
_build/prod/rel/prismatic/bin/prismatic ping
```

### Custom Mix Tasks

#### Project-Specific Tasks
```bash
# Generate API documentation
mix api.generate_docs

# Validate configuration
mix config.validate

# Setup development environment
mix dev.setup

# Reset development environment
mix dev.reset

# Generate sample data
mix dev.seed_sample_data

# Check system health
mix health.check

# Backup database
mix backup.create

# Restore database from backup
mix backup.restore <backup_file>
```

## npm Commands

### Asset Management

#### Development
```bash
# Install dependencies
npm install

# Install for production only
npm install --only=production

# Install specific package
npm install package-name

# Install development dependency
npm install --save-dev package-name

# Update dependencies
npm update

# Audit for vulnerabilities
npm audit

# Fix vulnerabilities
npm audit fix
```

#### Build Commands
```bash
# Build assets for development
npm run build

# Build assets for production
npm run build:prod

# Build with watch mode
npm run build:watch

# Start development server
npm run dev

# Clean build artifacts
npm run clean
```

#### Testing and Quality
```bash
# Run JavaScript tests
npm test

# Run tests in watch mode
npm run test:watch

# Run tests with coverage
npm run test:coverage

# Run ESLint
npm run lint

# Fix ESLint issues
npm run lint:fix

# Run Prettier
npm run format

# Check Prettier formatting
npm run format:check
```

### Asset Pipeline Commands
```bash
# Deploy assets (Phoenix)
mix assets.deploy

# Install asset dependencies
mix assets.setup

# Clean asset cache
mix assets.clean
```

## Git Commands

### Repository Management
```bash
# Initialize Git hooks
git config core.hooksPath .githooks

# Set commit template
git config commit.template .gitmessage

# Enable GPG signing
git config commit.gpgsign true

# Configure user information
git config user.name "Your Name"
git config user.email "your.email@example.com"
```

### Branch Management
```bash
# Create feature branch
git checkout -b feature/new-feature

# Create bugfix branch
git checkout -b bugfix/issue-123

# Create hotfix branch
git checkout -b hotfix/critical-fix

# Merge with no fast-forward
git merge --no-ff feature/new-feature

# Interactive rebase
git rebase -i HEAD~3
```

### Release Management
```bash
# Create release tag
git tag -a v1.0.0 -m "Release v1.0.0"

# Push tags
git push origin --tags

# Create signed tag
git tag -s v1.0.0 -m "Release v1.0.0"

# List tags
git tag -l

# Delete tag
git tag -d v1.0.0
```

## Docker Commands

### Development
```bash
# Build development image
docker build -t prismatic:dev .

# Run container
docker run -p 4000:4000 prismatic:dev

# Run with environment variables
docker run -e DATABASE_URL=... -p 4000:4000 prismatic:dev

# Run in background
docker run -d --name prismatic-app prismatic:dev

# View logs
docker logs prismatic-app

# Execute command in container
docker exec -it prismatic-app /bin/bash
```

### Docker Compose
```bash
# Start all services
docker-compose up

# Start in background
docker-compose up -d

# Stop services
docker-compose down

# Rebuild services
docker-compose build

# View logs
docker-compose logs

# Execute command in service
docker-compose exec app mix test
```

### Production
```bash
# Build production image
docker build -t prismatic:prod --target=production .

# Push to registry
docker push registry.example.com/prismatic:prod

# Pull and run
docker run -d --name prismatic-prod prismatic:prod
```

## System Commands

### Environment Setup
```bash
# Install Elixir via asdf
asdf install elixir 1.16.0

# Set global Elixir version
asdf global elixir 1.16.0

# Install Node.js
asdf install nodejs 20.10.0

# Set global Node.js version
asdf global nodejs 20.10.0

# Install PostgreSQL
asdf install postgres 16.1

# Start PostgreSQL
pg_ctl start -D ~/.asdf/installs/postgres/16.1/data
```

### Database Management
```bash
# Create database user
createuser -P prismatic

# Create database
createdb -O prismatic prismatic_dev

# Connect to database
psql -d prismatic_dev -U prismatic

# Dump database
pg_dump prismatic_dev > backup.sql

# Restore database
psql prismatic_dev < backup.sql

# Check database size
psql -c "SELECT pg_size_pretty(pg_database_size('prismatic_dev'));"
```

### System Monitoring
```bash
# Check running processes
ps aux | grep beam

# Check ports in use
lsof -i :4000

# Check system resources
top -p $(pgrep beam)

# Check disk usage
df -h

# Check memory usage
free -h

# Check system logs
journalctl -f -u prismatic
```

## Deployment Commands

### Staging Deployment
```bash
# Deploy to staging
mix deploy.staging

# Check staging status
mix deploy.status staging

# Rollback staging
mix deploy.rollback staging

# View staging logs
mix deploy.logs staging
```

### Production Deployment
```bash
# Deploy to production
mix deploy.production

# Hot upgrade production
mix deploy.upgrade production

# Check production status
mix deploy.status production

# Rollback production
mix deploy.rollback production

# View production logs
mix deploy.logs production --tail
```

### Health Checks
```bash
# Check application health
curl https://prismatic.example.com/api/health

# Check database connectivity
mix health.database

# Check external services
mix health.external

# Generate health report
mix health.report
```

## Monitoring Commands

### Log Management
```bash
# View application logs
tail -f log/dev.log

# View error logs
tail -f log/error.log

# Search logs for patterns
grep -i "error" log/*.log

# Analyze log patterns
awk '/ERROR/ {print $0}' log/prod.log
```

### Performance Monitoring
```bash
# Memory usage report
mix profile.memory

# CPU profiling
mix profile.cprof

# Request profiling
mix profile.fprof

# Performance benchmarks
mix benchmark
```

### System Health
```bash
# Check system uptime
uptime

# Check system load
w

# Check disk I/O
iostat

# Check network connections
netstat -an | grep :4000

# Check SSL certificate
openssl s_client -connect prismatic.example.com:443
```

## Backup and Recovery

### Database Backup
```bash
# Create database backup
mix backup.database

# Create full system backup
mix backup.full

# Schedule automated backups
mix backup.schedule --frequency=daily

# List available backups
mix backup.list

# Verify backup integrity
mix backup.verify <backup_id>
```

### Data Recovery
```bash
# Restore from backup
mix restore.database <backup_file>

# Point-in-time recovery
mix restore.point_in_time "2024-01-01 12:00:00"

# Partial data recovery
mix restore.partial --table=users

# Dry run recovery
mix restore.dry_run <backup_file>
```

## Troubleshooting Commands

### Common Issues
```bash
# Clear compilation cache
mix clean

# Reset dependencies
rm -rf deps _build && mix deps.get

# Fix dependency conflicts
mix deps.unlock --all && mix deps.get

# Check for unused dependencies
mix deps.unlock --unused

# Verify system requirements
mix deps.check
```

### Debug Commands
```bash
# Start with debugging
iex --dbg pry -S mix phx.server

# Enable verbose logging
ELIXIR_LOG_LEVEL=debug mix phx.server

# Profile memory usage
mix profile.memory --callers

# Generate crash dump
kill -QUIT $(pgrep beam)
```

### Network Debugging
```bash
# Test connectivity
telnet localhost 4000

# Check DNS resolution
nslookup prismatic.example.com

# Test SSL connection
openssl s_client -connect prismatic.example.com:443

# Check firewall rules
iptables -L
```

## Configuration Commands

### Environment Configuration
```bash
# Generate secret key
mix phx.gen.secret

# Validate configuration
mix config.validate

# Show current configuration
mix config.show

# Export environment variables
export $(cat .env | xargs)

# Load environment from file
set -a; source .env; set +a
```

### SSL Certificate Management
```bash
# Generate self-signed certificate
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365

# Check certificate expiration
openssl x509 -in cert.pem -text -noout | grep "Not After"

# Verify certificate
openssl verify cert.pem

# Convert certificate format
openssl x509 -in cert.pem -out cert.crt
```

## Related Documentation

- [Developer Experience](../guides/developer-experience.md) - Development workflow utilizing these commands
- [Deployment Procedures](../operations/deployment-procedures.md) - Step-by-step deployment using these commands
- [Database Setup](../operations/database-setup.md) - Database management with detailed command usage
- [CI/CD Configuration](../operations/cicd-configuration.md) - Automated execution of these commands
- [Git Hooks Setup](../guides/git-hooks-setup.md) - Automated command execution in Git workflows

---

**This command reference is regularly updated as new tools and procedures are added to the Prismatic project. For the most current command options, use the `--help` flag with any command.**