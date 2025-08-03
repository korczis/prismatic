<!-- NAV_START -->
<div align="center">
  <strong>🛠️ First-Time Setup Guide</strong><br>
  <em>Comprehensive development environment setup with verification steps</em><br><br>
  
  <a href="../../README.md">🏠 Home</a> | 
  <a href="../README.md">📖 All Guides</a> | 
  <a href="README.md">🚀 Getting Started</a><br>
  
  <strong>Quick Links:</strong>
  <a href="new-contributor-quickstart.md">Quick Start</a> |
  <a href="contribution-workflow.md">Contribution Workflow</a> |
  <a href="project-orientation.md">Project Orientation</a>
</div>

### Related Documentation
- [New Contributor Quick-Start](new-contributor-quickstart.md) - 5-minute setup for immediate productivity
- [Contribution Workflow Guide](contribution-workflow.md) - Complete contribution process
- [Development Guide](../development/README.md) - Comprehensive development practices
<!-- NAV_END -->

# First-Time Setup Guide

> **📋 Complete Setup & Verification**  
> This guide provides detailed setup instructions with verification steps for a robust development environment. For a quick 5-minute setup, see the [Quick-Start Guide](new-contributor-quickstart.md).

## Table of Contents

- [Prerequisites & System Requirements](#prerequisites--system-requirements)
- [Tool Installation](#tool-installation)
- [Project Setup](#project-setup)
- [Database Configuration](#database-configuration)
- [Development Tools](#development-tools)
- [Verification & Testing](#verification--testing)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)

## Prerequisites & System Requirements

### Operating System Support

| OS | Version | Status | Notes |
|----|---------|--------|---------|
| **macOS** | 12.0+ (Monterey) | ✅ Fully Supported | Recommended for development |
| **Ubuntu** | 20.04+ LTS | ✅ Fully Supported | Excellent Docker support |
| **Windows** | 10/11 + WSL2 | ⚠️ Supported | Use WSL2 for best experience |
| **Debian** | 11+ | ✅ Supported | Great for production-like dev |
| **CentOS/RHEL** | 8+ | ⚠️ Limited | Manual package management |

### Hardware Requirements

**Minimum:**
- 8GB RAM (4GB available for development)
- 2 CPU cores
- 10GB free disk space
- Stable internet connection

**Recommended:**
- 16GB+ RAM (better for large project compilation)
- 4+ CPU cores (faster test runs and compilation)
- 25GB+ free disk space (includes Docker images)
- SSD storage (significantly faster compilation)

## Tool Installation

### 1. Elixir & Erlang Setup

#### Option A: Using ASDF (Recommended)

```bash
# Install asdf
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1

# Add to shell profile (choose your shell)
echo '. ~/.asdf/asdf.sh' >> ~/.bashrc        # Bash
echo '. ~/.asdf/asdf.sh' >> ~/.zshrc         # Zsh

# Restart terminal or source profile
source ~/.bashrc  # or ~/.zshrc

# Install Erlang plugin and dependencies
asdf plugin add erlang

# Install Erlang build dependencies
# Ubuntu/Debian:
sudo apt-get update
sudo apt-get install build-essential autoconf m4 libncurses5-dev libwxgtk3.0-gtk3-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils libncurses-dev openjdk-11-jdk

# macOS:
brew install autoconf wxwidgets libxslt fop

# Install Erlang (this takes 10-15 minutes)
asdf install erlang 26.2.5
asdf global erlang 26.2.5

# Install Elixir plugin and version
asdf plugin add elixir
asdf install elixir 1.17.2-otp-26
asdf global elixir 1.17.2-otp-26
```

**Verification:**
```bash
elixir --version
# Should show:
# Erlang/OTP 26 [erts-14.2.5] [source] [64-bit] [smp:8:8] [ds:8:8:10] [async-threads:1] [jit:ns]
# Elixir 1.17.2 (compiled with Erlang/OTP 26)
```

### 2. Node.js & NPM Setup

```bash
# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc

# Install and use Node.js 20 LTS
nvm install 20
nvm use 20
nvm alias default 20

# Verify installation
node --version  # Should show v20.x.x
npm --version   # Should show 10.x.x
```

### 3. PostgreSQL Database

#### macOS (Homebrew)
```bash
brew install postgresql@14
brew services start postgresql@14

# Create user and database
createuser -s postgres
createdb prismatic_dev
```

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Setup user
sudo -u postgres createuser --superuser $USER
sudo -u postgres createdb prismatic_dev
```

#### Docker Alternative
```bash
# Run PostgreSQL in Docker
docker run --name prismatic-postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=prismatic_dev \
  -p 5432:5432 \
  -d postgres:14
```

**Verification:**
```bash
psql --version  # Should show PostgreSQL 14.x
psql -d prismatic_dev -c "SELECT version();"
```

### 4. Git Configuration

```bash
# Configure Git (replace with your details)
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Optional: Setup GPG signing
git config --global commit.gpgsign true
git config --global user.signingkey YOUR_GPG_KEY_ID

# Verify configuration
git config --list | grep user
```

## Project Setup

### 1. Clone Repository

```bash
# Clone the repository
git clone https://github.com/korczis/prismatic.git
cd prismatic

# Verify you're on main branch
git branch
# * main
```

### 2. Install Dependencies

```bash
# Install Elixir dependencies
mix deps.get

# Install Hex package manager (if prompted)
mix local.hex --force

# Install Rebar3 build tool (if prompted)
mix local.rebar --force

# Install Node.js dependencies for web assets
cd apps/prismatic_web/assets
npm install
cd ../../../
```

**Verification:**
```bash
# Check mix dependencies
mix deps
# Should show all dependencies as "ok"

# Check npm dependencies
ls apps/prismatic_web/assets/node_modules | wc -l
# Should show a number > 100
```

### 3. Environment Configuration

```bash
# Copy example environment file
cp .env.example .env

# Edit environment variables
vim .env  # or your preferred editor
```

**Example `.env` file:**
```bash
# Database Configuration
DATABASE_URL=postgres://postgres:postgres@localhost/prismatic_dev
DATABASE_TEST_URL=postgres://postgres:postgres@localhost/prismatic_test

# Phoenix Configuration
SECRET_KEY_BASE=your_very_long_secret_key_base_here_64_chars_minimum
PHX_HOST=localhost
PHX_PORT=4000

# External Services (Optional)
GITHUB_TOKEN=your_github_token_for_api_access
JIRA_URL=https://your-domain.atlassian.net
JIRA_TOKEN=your_jira_api_token
SLACK_WEBHOOK_URL=your_slack_webhook_url
```

## Database Configuration

### 1. Create and Setup Database

```bash
# Create development and test databases
mix ecto.create

# Run migrations
mix ecto.migrate

# Seed with sample data (optional)
mix run apps/prismatic/priv/repo/seeds.exs
```

### 2. Verify Database Setup

```bash
# Check database connection
mix ecto.migrate --dry-run
# Should show "Already up" or list of pending migrations

# Test database query
mix run -e "IO.inspect(Prismatic.Repo.query!(\"SELECT version();\"))"
```

## Development Tools

### 1. Code Quality Tools

```bash
# Install development tools
mix deps.get

# Setup Dialyzer PLT files (takes 5-10 minutes first time)
mix dialyzer --plt

# Run code formatting
mix format

# Run code analysis
mix credo

# Run type checking
mix dialyzer
```

### 2. Editor Configuration

#### Visual Studio Code

**Install Extensions:**
```bash
# Install VS Code extensions via command line
code --install-extension jakebecker.elixir-ls
code --install-extension phoenixframework.phoenix
code --install-extension bradlc.vscode-tailwindcss
code --install-extension esbenp.prettier-vscode
```

**Configure Settings (`.vscode/settings.json`):**
```json
{
  "elixirLS.dialyzerEnabled": true,
  "elixirLS.fetchDeps": false,
  "elixirLS.mixEnv": "dev",
  "editor.formatOnSave": true,
  "[elixir]": {
    "editor.defaultFormatter": "JakeBecker.elixir-ls"
  },
  "files.associations": {
    "*.heex": "phoenix-heex"
  }
}
```

#### Vim/Neovim Configuration

```lua
-- Using vim-plug or your preferred plugin manager
Plug 'elixir-editors/vim-elixir'
Plug 'mhinz/vim-mix-format'
Plug 'neoclide/coc.nvim', {'branch': 'release'}

-- Auto-format on save
autocmd BufWritePost *.ex,*.exs silent :!mix format %
```

## Verification & Testing

### 1. Compile Project

```bash
# Clean compile
mix compile

# Compile with warnings as errors (stricter)
mix compile --warnings-as-errors
```

### 2. Run Test Suite

```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover

# Run specific test file
mix test test/prismatic/todo/scanner_test.exs

# Run integration tests
mix test --only integration
```

### 3. Quality Checks

```bash
# Run all quality checks
mix credo --strict
mix dialyzer
mix format --check-formatted

# Generate documentation
mix docs
```

### 4. Start Development Server

```bash
# Start Phoenix server with live reload
mix phx.server

# Or start in IEx for debugging
iex -S mix phx.server
```

**Verification Steps:**
1. Visit [`http://localhost:4000`](http://localhost:4000)
2. Verify the Prismatic interface loads
3. Check for any JavaScript console errors
4. Test basic navigation

### 5. Prismatic-Specific Features

```bash
# Test TODO scanning
mix prismatic.todo.scan --paths="lib,apps" --format=json

# Test documentation generation
mix prismatic.docs.generate --format=html

# Test BEAM introspection
mix prismatic.beam.inspect --target=system

# Test consolidation analysis
mix prismatic.consolidation.analyze --dry-run
```

## Troubleshooting

### Common Installation Issues

#### Erlang/Elixir Build Failures

```bash
# Missing build dependencies
# Ubuntu/Debian:
sudo apt-get install build-essential autoconf m4 libncurses5-dev libssl-dev

# macOS:
brew install autoconf openssl

# Clear and rebuild
rm -rf ~/.asdf/installs/erlang
rm -rf ~/.asdf/installs/elixir
asdf install erlang 26.2.5
asdf install elixir 1.17.2-otp-26
```

#### Database Connection Issues

```bash
# Check PostgreSQL is running
sudo systemctl status postgresql  # Linux
brew services list | grep postgresql  # macOS

# Reset database
mix ecto.drop && mix ecto.create && mix ecto.migrate

# Check connection manually
psql -d prismatic_dev -c "\\l"
```

#### Node.js/NPM Issues

```bash
# Clear npm cache
npm cache clean --force

# Remove and reinstall node_modules
cd apps/prismatic_web/assets
rm -rf node_modules package-lock.json
npm install
```

#### Permission Issues

```bash
# Fix npm permissions (avoid sudo npm)
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

### Performance Issues

#### Slow Compilation

```bash
# Use parallel compilation
export ELIXIR_MAKE_JOBS=$(nproc)  # Linux
export ELIXIR_MAKE_JOBS=$(sysctl -n hw.ncpu)  # macOS

# Enable incremental compilation
echo 'export MIX_ENV=dev' >> ~/.bashrc
```

#### Memory Issues

```bash
# Increase Erlang VM memory
export ERL_MAX_PORTS=65536
export ERL_MAX_ETS_TABLES=10000

# Monitor memory usage
iex -S mix
:erlang.memory() |> IO.inspect()
```

### IDE Issues

#### VS Code ElixirLS Problems

```bash
# Restart ElixirLS
Cmd/Ctrl + Shift + P -> "ElixirLS: Restart"

# Clear ElixirLS cache
rm -rf .elixir_ls

# Rebuild project
mix clean && mix compile
```

## Next Steps

After completing this setup:

### ✅ Immediate Actions

1. **Verify Everything Works:**
   ```bash
   # Run the full verification suite
   mix test && mix credo && mix dialyzer
   mix phx.server  # Visit http://localhost:4000
   ```

2. **Make Your First Contribution:**
   - See [Contribution Workflow Guide](contribution-workflow.md)
   - Look for [`good first issue`](https://github.com/korczis/prismatic/labels/good%20first%20issue) labels

3. **Understand the Codebase:**
   - Read [Project Orientation Guide](project-orientation.md)
   - Explore [Architecture Documentation](../../architecture/README.md)

### 🚀 Advanced Setup (Optional)

4. **Docker Development:**
   ```bash
   docker-compose -f docker-compose.dev.yml up
   ```

5. **Performance Monitoring:**
   ```bash
   # Install additional monitoring tools
   mix deps.get
   mix compile
   ```

6. **IDE Integration:**
   - Set up debugger configuration
   - Configure advanced linting rules
   - Install project-specific snippets

### 📚 Learning Resources

7. **Study the Documentation:**
   - [Development Guide](../development/README.md) - Comprehensive development practices
   - [API Documentation](../../api/README.md) - Generated API docs
   - [Mix Tasks Guide](../mix-tasks/README.md) - Prismatic-specific commands

8. **Join the Community:**
   - Watch the GitHub repository for updates
   - Participate in code reviews
   - Contribute to documentation improvements

---

**🎉 Success!** You now have a complete Prismatic development environment. Your setup should be fast, reliable, and ready for productive contribution to the project.

**📊 Verification Checklist:**
- ✅ All tests pass: `mix test`
- ✅ Code quality passes: `mix credo`
- ✅ Type checking passes: `mix dialyzer`
- ✅ Server starts: `mix phx.server`
- ✅ Database works: Can create/migrate
- ✅ Frontend builds: NPM install succeeds
- ✅ Prismatic tools work: TODO scan, docs generation

**⭐ Pro Tips:**
- Bookmark this page for troubleshooting reference
- Join code reviews to learn faster
- Set up git hooks for automatic quality checks
- Use `iex -S mix` for interactive development