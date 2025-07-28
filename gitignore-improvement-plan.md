# Phoenix 1.7 Umbrella Project .gitignore Improvement Plan

## Current Issues Analysis

After analyzing your current .gitignore setup, I've identified several issues:

1. **Duplication**: Same patterns repeated across root, `apps/prismatic/`, and `apps/prismatic_web/` .gitignore files
2. **Incomplete Coverage**: Missing many file types that should be ignored
3. **Poor Organization**: No clear structure or documentation
4. **Missing Categories**: No coverage for IDEs, databases, security files, logs, etc.

## Project Structure Analysis

Your project is:
- **Elixir Phoenix 1.7** umbrella application
- **PostgreSQL** database (from config files)
- **TailwindCSS** for styling
- **Phoenix LiveView** for interactivity
- **Standard Mix** build system

## Specific Tools Detected in Your Project

After analyzing your codebase, I've identified these specific tools that need additional .gitignore patterns:

1. **ASDF Version Manager** - `.tool-versions` file present
2. **ESBuild** - JavaScript/CSS bundling tool (in deps)
3. **TailwindCSS** - CSS framework with config file
4. **NPM** - JavaScript package manager (referenced throughout)
5. **Docker** - Container support (Phoenix release generation)
6. **Direnv** - Environment management (`.envrc` already ignored)
7. **PostgreSQL** - Database (from config files)

## Comprehensive .gitignore Structure

The new root `.gitignore` should be structured with clear sections, including tool-specific patterns:

### 1. Elixir/Mix Build Artifacts
```gitignore
# =============================================================================
# ELIXIR & MIX BUILD ARTIFACTS
# =============================================================================

# The directory Mix will write compiled artifacts to
/_build/

# Where Mix downloads your dependencies sources to
/deps/

# Where 3rd-party dependencies like ExDoc output generated docs
/doc/

# If you run "mix test --cover", coverage assets end up here
/cover/

# Ignore .fetch files in case you like to edit your project deps locally
/.fetch

# If the VM crashes, it generates a dump, let's ignore it too
erl_crash.dump

# Also ignore archive artifacts (built via "mix archive.build")
*.ez

# Ignore package tarballs (built via "mix hex.build")
*.tar

# Temporary files, for example, from tests
/tmp/
```

### 2. Phoenix Web Assets
```gitignore
# =============================================================================
# PHOENIX WEB ASSETS
# =============================================================================

# Ignore assets that are produced by build tools (esbuild, webpack, etc.)
/apps/*/priv/static/assets/
/priv/static/assets/

# Ignore digested assets cache
/apps/*/priv/static/cache_manifest.json
/priv/static/cache_manifest.json

# Generated CSS and JS files
/apps/*/priv/static/css/
/apps/*/priv/static/js/

# Asset build artifacts
/apps/*/assets/dist/
/apps/*/assets/build/
/assets/dist/
/assets/build/

# TailwindCSS generated files
/apps/*/priv/static/css/app.css.map
/priv/static/css/app.css.map

# ESBuild artifacts
/apps/*/assets/esbuild/
/assets/esbuild/
```

### 3. Node.js & JavaScript
```gitignore
# =============================================================================
# NODE.JS & JAVASCRIPT
# =============================================================================

# Node modules
/apps/*/assets/node_modules/
/assets/node_modules/
node_modules/

# npm debug logs
npm-debug.log*
npm-error.log*

# Yarn error logs
yarn-debug.log*
yarn-error.log*

# Package lock files (choose one approach)
# package-lock.json
# yarn.lock

# Node.js crash logs
*.log

# Coverage directory used by tools like istanbul
coverage/
```

### 4. Database Files
```gitignore
# =============================================================================
# DATABASE FILES
# =============================================================================

# SQLite databases
*.sqlite
*.sqlite3
*.db

# PostgreSQL dumps
*.sql
*.dump

# Database migration backups
*.backup
```

### 5. Environment & Configuration
```gitignore
# =============================================================================
# ENVIRONMENT & CONFIGURATION
# =============================================================================

# Environment variables
.env
.env.local
.env.*.local
.envrc

# Runtime configuration
config/*.secret.exs
config/prod.secret.exs

# SSL certificates
*.pem
*.key
*.crt
*.cert
```

### 6. Editor & IDE Files
```gitignore
# =============================================================================
# EDITOR & IDE FILES
# =============================================================================

# VS Code
.vscode/
*.code-workspace

# Vim
*.swp
*.swo
*~

# Emacs
*~
\#*\#
/.emacs.desktop
/.emacs.desktop.lock
*.elc
auto-save-list
tramp
.\#*

# Sublime Text
*.sublime-project
*.sublime-workspace

# JetBrains IDEs (IntelliJ, PhpStorm, etc.)
.idea/
*.iml
*.iws

# Atom
.atom/
```

### 7. Operating System Files
```gitignore
# =============================================================================
# OPERATING SYSTEM FILES
# =============================================================================

# macOS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Icon?

# Windows
Thumbs.db
Thumbs.db:encryptable
ehthumbs.db
ehthumbs_vista.db
*.stackdump
[Dd]esktop.ini
$RECYCLE.BIN/

# Linux
*~
.fuse_hidden*
.directory
.Trash-*
.nfs*
```

### 8. Development & Testing
```gitignore
# =============================================================================
# DEVELOPMENT & TESTING
# =============================================================================

# Test artifacts
test/tmp/
test/fixtures/uploads/
test/support/fixtures/

# ExUnit coverage
/cover/
coveralls.json
excoveralls.json

# Dialyzer PLT files
*.plt
*.plt.hash
priv/plts/
/apps/*/priv/plts/

# Benchmarking
benchmarks/results/
benchmark/results/

# Property-based testing (StreamData)
.shrinking/

# Phoenix LiveView testing artifacts
test/support/file_helpers/
```

### 9. Deployment & Production
```gitignore
# =============================================================================
# DEPLOYMENT & PRODUCTION
# =============================================================================

# Release artifacts
/_build/prod/
/rel/

# Docker
.dockerignore
Dockerfile.prod

# Terraform
*.tfstate
*.tfstate.*
.terraform/

# Logs
*.log
logs/
log/
```

### 10. Tool-Specific Patterns
```gitignore
# =============================================================================
# TOOL-SPECIFIC PATTERNS
# =============================================================================

# ASDF Version Manager
.tool-versions.local

# ESBuild specific
.esbuild/
esbuild.json

# TailwindCSS specific
/apps/*/assets/tailwind.config.js.backup
*.tailwind.bak

# Docker & Container Files
Dockerfile.dev
Dockerfile.local
docker-compose.override.yml
docker-compose.local.yml
.dockerignore.local

# Phoenix Release & Deployment
/rel/overlays/
/rel/vm.args
/rel/remote.args
*.tar.gz
*.zip

# Livebook (if used)
*.livemd.backup
.livebook/
```

### 11. Security & Secrets
```gitignore
# =============================================================================
# SECURITY & SECRETS
# =============================================================================

# Private keys and certificates
*.pem
*.key
*.p12
*.p8
*.crt
*.cer
*.cert

# Secret configuration files
*secret*
*SECRET*
*.secrets

# Auth tokens and API keys
.token
.api_key
credentials.json
service-account.json
```

## App-Specific .gitignore Simplification

After creating the comprehensive root `.gitignore`, the app-specific files should be simplified:

### `apps/prismatic/.gitignore`
Should only contain:
```gitignore
# App-specific package tarball
prismatic-*.tar
```

### `apps/prismatic_web/.gitignore`  
Should only contain:
```gitignore
# App-specific package tarball
prismatic_web-*.tar
```

## Implementation Steps

1. **Replace root `.gitignore`** with the comprehensive version
2. **Simplify app-specific .gitignore files** to remove duplicates
3. **Test the new setup** by checking git status
4. **Validate coverage** by ensuring unwanted files are ignored

## Benefits of This Structure

1. **Centralized Management**: All ignore patterns in one place
2. **Well Documented**: Clear sections with explanations
3. **Comprehensive Coverage**: Covers all common file types
4. **Future-Proof**: Includes patterns for tools you might add later
5. **No Duplication**: Eliminates redundant patterns across files
6. **Professional**: Follows industry best practices

## Validation Checklist

After implementation, verify:
- [ ] Build artifacts are ignored (`_build/`, `deps/`, etc.)
- [ ] Asset files are ignored (`priv/static/assets/`)
- [ ] Environment files are ignored (`.env*`)
- [ ] Editor files are ignored (`.vscode/`, `.idea/`, etc.)
- [ ] OS files are ignored (`.DS_Store`, `Thumbs.db`)
- [ ] Important files are still tracked (`mix.exs`, `lib/`, `config/`, etc.)
- [ ] App-specific .gitignore files are simplified