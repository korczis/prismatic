# Semantic Versioning Guide

Complete guide to semantic versioning practices and release management for the Prismatic application, including version numbering, release planning, and automated versioning workflows.

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > [Guides](README.md) > Semantic Versioning

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to guides index
- **🏠 [Documentation Home](../README.md)** - Main documentation index
- **🔍 [Search Documentation](../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Git Hooks Setup](git-hooks-setup.md) - Automated version enforcement
- [CI/CD Configuration](../operations/cicd-configuration.md) - Automated release workflows
- [Style Guide](style-guide.md) - Code and documentation standards
- [API Endpoints](../reference/api-endpoints.md) - API versioning considerations
- [Database Schema](../reference/database-schema.md) - Schema migration versioning
<!-- NAV_END -->

## Overview

This guide establishes semantic versioning (SemVer) standards for the Prismatic application, covering version numbering, release types, branching strategies, and automated workflows. Following these practices ensures predictable releases and clear communication of changes to users and developers.

## Semantic Versioning Specification

### Version Format

Prismatic follows [Semantic Versioning 2.0.0](https://semver.org/) specification:

```
MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]
```

#### Components Explained

- **MAJOR** (`X.0.0`) - Incompatible API changes, breaking changes
- **MINOR** (`0.X.0`) - New functionality, backward compatible
- **PATCH** (`0.0.X`) - Bug fixes, backward compatible
- **PRERELEASE** (`-alpha.1`, `-beta.2`, `-rc.1`) - Pre-release versions
- **BUILD** (`+20240101.abc123`) - Build metadata (optional)

### Version Examples

```
1.0.0         # Initial stable release
1.1.0         # New features added
1.1.1         # Bug fixes
2.0.0         # Breaking changes
2.0.0-alpha.1 # Pre-release alpha
2.0.0-beta.1  # Pre-release beta
2.0.0-rc.1    # Release candidate
```

## Release Types and Criteria

### Major Releases (X.0.0)

**When to increment:**
- Breaking API changes
- Removal of deprecated features
- Major architecture changes
- Database schema breaking changes
- Configuration format changes

**Examples:**
```elixir
# Breaking API change
# Before (v1.x.x)
def create_user(name, email) do
  # Implementation
end

# After (v2.0.0)
def create_user(%{name: name, email: email, role: role}) do
  # New required parameter breaks compatibility
end
```

**Planning Requirements:**
- Migration guide must be provided
- Deprecation warnings in previous minor versions
- Extended support period for previous major version
- Comprehensive testing and QA

### Minor Releases (0.X.0)

**When to increment:**
- New features and functionality
- New API endpoints
- Database schema additions (non-breaking)
- Performance improvements
- New configuration options (with defaults)

**Examples:**
```elixir
# New feature addition
defmodule Prismatic.Analytics do
  @doc "New analytics functionality in v1.2.0"
  def track_event(event_name, properties \\ %{}) do
    # New feature implementation
  end
end
```

**Planning Requirements:**
- Feature documentation updates
- Integration tests for new functionality
- Performance impact assessment
- Security review for new features

### Patch Releases (0.0.X)

**When to increment:**
- Bug fixes
- Security patches
- Documentation corrections
- Performance optimizations (non-breaking)
- Dependency updates (compatible)

**Examples:**
```elixir
# Bug fix
def calculate_total(items) do
  # Fixed: Handle empty list case
  if Enum.empty?(items) do
    0
  else
    Enum.sum(items)
  end
end
```

**Planning Requirements:**
- Regression testing
- Security assessment for patches
- Minimal risk validation
- Quick deployment capability

### Pre-release Versions

#### Alpha Releases (-alpha.N)
- **Purpose**: Early development versions
- **Audience**: Internal development team
- **Stability**: Unstable, breaking changes expected
- **Testing**: Basic functionality testing

```
2.0.0-alpha.1  # First alpha
2.0.0-alpha.2  # Second alpha with fixes
```

#### Beta Releases (-beta.N)
- **Purpose**: Feature-complete but potentially buggy
- **Audience**: Early adopters, beta testers
- **Stability**: Feature-frozen, bug fixes only
- **Testing**: Comprehensive testing required

```
2.0.0-beta.1   # First beta
2.0.0-beta.2   # Beta with bug fixes
```

#### Release Candidates (-rc.N)
- **Purpose**: Final testing before stable release
- **Audience**: Production-like environments
- **Stability**: Production-ready unless critical issues found
- **Testing**: Full production simulation

```
2.0.0-rc.1     # First release candidate
2.0.0-rc.2     # RC with critical fixes
2.0.0          # Final stable release
```

## Branching Strategy

### Git Flow with SemVer

```
main (production)
├── release/2.1.0
│   ├── hotfix/2.0.1
│   └── feature/new-analytics
├── develop
│   ├── feature/user-profiles
│   └── feature/api-v2
└── hotfix/2.0.1
```

#### Branch Types and Versioning

**Main Branch (`main`)**
- Contains production-ready code
- Tags mark official releases
- Only accepts merges from release and hotfix branches

**Develop Branch (`develop`)**
- Integration branch for features
- Represents next minor/major release
- Pre-release versions built from here

**Feature Branches (`feature/*`)**
- Individual feature development
- Merged into develop
- No direct versioning impact

**Release Branches (`release/X.Y.0`)**
- Preparation for new minor/major release
- Bug fixes and documentation updates only
- Source for release candidates

**Hotfix Branches (`hotfix/X.Y.Z`)**
- Critical fixes for production
- Merged into both main and develop
- Results in immediate patch release

### Version Tagging Strategy

```bash
# Stable releases
git tag -a v1.0.0 -m "Release v1.0.0: Initial stable release"
git tag -a v1.1.0 -m "Release v1.1.0: User analytics feature"
git tag -a v1.1.1 -m "Release v1.1.1: Critical security fix"

# Pre-releases
git tag -a v2.0.0-alpha.1 -m "Release v2.0.0-alpha.1: API v2 preview"
git tag -a v2.0.0-beta.1 -m "Release v2.0.0-beta.1: API v2 beta"
git tag -a v2.0.0-rc.1 -m "Release v2.0.0-rc.1: API v2 release candidate"
```

## Automated Versioning

### Mix Version Management

#### mix.exs Configuration
```elixir
defmodule Prismatic.MixProject do
  use Mix.Project

  @version "1.2.0"

  def project do
    [
      app: :prismatic,
      version: @version,
      elixir: "~> 1.16",
      # ... other configuration
    ]
  end

  def version, do: @version
end
```

#### Dynamic Version from Git
```elixir
defmodule Prismatic.MixProject do
  use Mix.Project

  def project do
    [
      app: :prismatic,
      version: version(),
      elixir: "~> 1.16",
      # ... other configuration
    ]
  end

  defp version do
    case System.cmd("git", ["describe", "--tags", "--exact-match", "HEAD"], stderr_to_stdout: true) do
      {tag, 0} ->
        String.trim(tag) |> String.trim_leading("v")
      _ ->
        # Fallback to development version
        {commit, 0} = System.cmd("git", ["rev-parse", "--short", "HEAD"])
        "0.0.0-dev+" <> String.trim(commit)
    end
  end
end
```

### Package.json Synchronization

#### Automatic Version Sync
```json
{
  "name": "prismatic-assets",
  "version": "1.2.0",
  "scripts": {
    "version:sync": "node scripts/sync-version.js",
    "preversion": "npm run version:sync"
  }
}
```

#### Version Sync Script
```javascript
// scripts/sync-version.js
const fs = require('fs');
const path = require('path');

// Read version from mix.exs
const mixContent = fs.readFileSync('../mix.exs', 'utf8');
const versionMatch = mixContent.match(/@version\s+"([^"]+)"/);

if (!versionMatch) {
  console.error('Could not extract version from mix.exs');
  process.exit(1);
}

const version = versionMatch[1];

// Update package.json
const packagePath = path.join(__dirname, '../assets/package.json');
const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
packageJson.version = version;

fs.writeFileSync(packagePath, JSON.stringify(packageJson, null, 2) + '\n');
console.log(`Synchronized version to ${version}`);
```

## CI/CD Integration

### Automated Version Bumping

#### GitHub Actions Workflow
```yaml
name: Release Management

on:
  push:
    branches: [main]
  pull_request:
    types: [closed]

jobs:
  version-bump:
    if: github.event.pull_request.merged == true
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      with:
        fetch-depth: 0
        token: ${{ secrets.GITHUB_TOKEN }}

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'

    - name: Install semantic-release
      run: npm install -g semantic-release @semantic-release/changelog @semantic-release/git

    - name: Determine version bump
      id: version
      run: |
        # Check commit messages for version bump type
        if git log --format=%s HEAD~1..HEAD | grep -q "BREAKING CHANGE\|feat!"; then
          echo "bump=major" >> $GITHUB_OUTPUT
        elif git log --format=%s HEAD~1..HEAD | grep -q "feat"; then
          echo "bump=minor" >> $GITHUB_OUTPUT
        elif git log --format=%s HEAD~1..HEAD | grep -q "fix\|perf"; then
          echo "bump=patch" >> $GITHUB_OUTPUT
        else
          echo "bump=none" >> $GITHUB_OUTPUT
        fi

    - name: Bump version
      if: steps.version.outputs.bump != 'none'
      run: |
        # Update version in mix.exs
        current_version=$(grep '@version' mix.exs | cut -d'"' -f2)
        new_version=$(npx semver $current_version -i ${{ steps.version.outputs.bump }})
        
        sed -i "s/@version \"$current_version\"/@version \"$new_version\"/" mix.exs
        
        # Update assets/package.json
        cd assets
        npm version $new_version --no-git-tag-version
        cd ..
        
        # Commit changes
        git config user.name "release-bot"
        git config user.email "release-bot@prismatic.example.com"
        git add mix.exs assets/package.json
        git commit -m "chore: bump version to $new_version"
        git tag -a "v$new_version" -m "Release v$new_version"
        git push origin main --tags

    - name: Create GitHub Release
      if: steps.version.outputs.bump != 'none'
      uses: actions/create-release@v1
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      with:
        tag_name: v${{ env.NEW_VERSION }}
        release_name: Release v${{ env.NEW_VERSION }}
        body: |
          Changes in this release:
          ${{ github.event.pull_request.body }}
        draft: false
        prerelease: false
```

### Conventional Commits

#### Commit Message Format
```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

#### Examples
```bash
# Patch release
git commit -m "fix: resolve memory leak in user session handling"
git commit -m "fix(auth): correct JWT token expiration validation"

# Minor release
git commit -m "feat: add user profile analytics dashboard"
git commit -m "feat(api): implement user preference endpoints"

# Major release
git commit -m "feat!: redesign authentication system with breaking changes"
git commit -m "feat(api)!: remove deprecated v1 endpoints

BREAKING CHANGE: The v1 API endpoints have been removed. 
Please migrate to v2 endpoints as documented in the migration guide."
```

#### Commit Types
- `feat`: New feature (minor version)
- `fix`: Bug fix (patch version)
- `docs`: Documentation changes (patch version)
- `style`: Code style changes (patch version)
- `refactor`: Code refactoring (patch version)
- `perf`: Performance improvements (patch version)
- `test`: Test changes (patch version)
- `chore`: Build/maintenance tasks (no version change)
- `!` suffix: Breaking change (major version)

## Release Planning

### Release Calendar

#### Scheduled Releases
```
├── Major Releases (Quarterly)
│   ├── Q1: March 1st
│   ├── Q2: June 1st  
│   ├── Q3: September 1st
│   └── Q4: December 1st
│
├── Minor Releases (Monthly)
│   ├── First Tuesday of each month
│   └── Emergency releases as needed
│
└── Patch Releases (As needed)
    ├── Security fixes: Within 24-48 hours
    ├── Critical bugs: Within 1 week
    └── Regular fixes: Bi-weekly
```

#### Release Roadmap Template
```markdown
# Release v2.1.0 Roadmap

## Target Date: 2024-04-01

### Features Planned
- [ ] User analytics dashboard
- [ ] API rate limiting
- [ ] Enhanced search functionality

### Technical Debt
- [ ] Refactor authentication module
- [ ] Update deprecated dependencies
- [ ] Improve test coverage to 90%

### Breaking Changes
- None planned

### Migration Requirements
- None required

### Success Criteria
- [ ] All features implemented and tested
- [ ] Performance benchmarks met
- [ ] Security audit completed
- [ ] Documentation updated
```

### Pre-release Testing

#### Alpha Testing Checklist
```markdown
- [ ] Feature functionality verification
- [ ] Basic integration testing
- [ ] Development environment stability
- [ ] API contract validation
- [ ] Database migration testing
```

#### Beta Testing Checklist
```markdown
- [ ] Complete feature testing
- [ ] Performance benchmarking
- [ ] Security vulnerability scan
- [ ] Cross-browser compatibility
- [ ] Mobile responsiveness
- [ ] Load testing
- [ ] Documentation review
```

#### Release Candidate Checklist
```markdown
- [ ] Full regression testing
- [ ] Production environment simulation
- [ ] Disaster recovery testing
- [ ] Monitoring and alerting validation
- [ ] Rollback procedure verification
- [ ] Final security review
- [ ] Legal/compliance review
- [ ] Stakeholder sign-off
```

## Version Documentation

### Changelog Management

#### CHANGELOG.md Format
```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- New feature descriptions

### Changed
- Changes in existing functionality

### Deprecated
- Soon-to-be removed features

### Removed
- Now removed features

### Fixed
- Any bug fixes

### Security
- In case of vulnerabilities

## [2.1.0] - 2024-04-01

### Added
- User analytics dashboard with real-time metrics
- API rate limiting with configurable thresholds
- Enhanced search with faceted filtering

### Changed
- Improved authentication flow performance by 40%
- Updated user interface with modern design system

### Fixed
- Memory leak in session management
- Race condition in database migrations

### Security
- Upgraded JWT library to address CVE-2024-1234

## [2.0.0] - 2024-01-01

### Added
- Complete API v2 with GraphQL support
- Multi-tenant architecture support
- Advanced user role management

### Changed
- **BREAKING**: Authentication system completely redesigned
- **BREAKING**: Database schema restructured for performance

### Removed
- **BREAKING**: Deprecated API v1 endpoints
- Legacy user management interface

### Migration
- See [v2.0.0 Migration Guide](migrations/v2.0.0.md) for upgrade instructions
```

#### Automated Changelog Generation
```yaml
# .github/workflows/changelog.yml
name: Update Changelog

on:
  release:
    types: [created]

jobs:
  changelog:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Generate changelog
      uses: heinrichreimer/github-changelog-generator-action@v2.3
      with:
        token: ${{ secrets.GITHUB_TOKEN }}
        output: CHANGELOG.md
        stripHeaders: true
        stripGeneratorNotice: true

    - name: Commit changelog
      run: |
        git config user.name "changelog-bot"
        git config user.email "changelog-bot@prismatic.example.com"
        git add CHANGELOG.md
        git commit -m "docs: update changelog for ${{ github.event.release.tag_name }}"
        git push
```

### Migration Guides

#### Migration Guide Template
```markdown
# Migration Guide: v1.x to v2.0.0

## Overview
This guide helps you migrate from Prismatic v1.x to v2.0.0.

## Breaking Changes

### API Changes
#### Authentication
**Before (v1.x):**
```http
POST /api/auth/login
Content-Type: application/x-www-form-urlencoded

username=user@example.com&password=secret
```

**After (v2.0.0):**
```http
POST /api/v2/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "secret"
}
```

### Configuration Changes
**Before (v1.x):**
```elixir
config :prismatic, auth_provider: :simple
```

**After (v2.0.0):**
```elixir
config :prismatic, Prismatic.Auth,
  provider: :oauth2,
  strategy: :google
```

## Migration Steps

### 1. Update Dependencies
```bash
# Update mix.exs
mix deps.update prismatic

# Update package.json
npm update @prismatic/client
```

### 2. Database Migration
```bash
# Run migration script
mix ecto.migrate

# Or use guided migration
mix prismatic.migrate --from=v1 --to=v2
```

### 3. Update Configuration
```bash
# Generate new configuration template
mix prismatic.config.update --version=v2

# Review and update config files
# - config/config.exs
# - config/prod.exs
# - config/runtime.exs
```

### 4. Update Code
See the [API Changes](#api-changes) section for required code updates.

## Support
- Migration support available until 2024-12-31
- Join #migration-support channel in Slack
- Email support: migration@prismatic.example.com
```

## Version Monitoring

### Runtime Version Exposure

#### Application Module
```elixir
defmodule Prismatic.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # ... other children
      {Prismatic.VersionReporter, []}
    ]

    opts = [strategy: :one_for_one, name: Prismatic.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def version do
    Application.spec(:prismatic, :vsn)
    |> to_string()
  end
end
```

#### Health Check Integration
```elixir
defmodule PrismaticWeb.HealthController do
  use PrismaticWeb, :controller

  def check(conn, _params) do
    json(conn, %{
      status: "healthy",
      version: Prismatic.Application.version(),
      timestamp: DateTime.utc_now(),
      uptime: System.system_time(:second) - Application.get_env(:prismatic, :start_time, 0)
    })
  end
end
```

### Metrics and Monitoring

#### Version Metrics
```elixir
defmodule Prismatic.Metrics.Version do
  use Prometheus.Metric

  @version_info Counter.new(
    name: :prismatic_version_info,
    help: "Application version information",
    labels: [:version, :commit, :build_date]
  )

  def setup do
    version = Prismatic.Application.version()
    commit = System.get_env("GIT_COMMIT", "unknown")
    build_date = System.get_env("BUILD_DATE", "unknown")

    Counter.inc(@version_info, [version, commit, build_date])
  end
end
```

## Related Documentation

- [Git Hooks Setup](git-hooks-setup.md) - Automated version validation and enforcement
- [CI/CD Configuration](../operations/cicd-configuration.md) - Automated release workflows and deployment
- [Style Guide](style-guide.md) - Code and documentation standards that support versioning
- [API Endpoints](../reference/api-endpoints.md) - API versioning strategies and backward compatibility
- [Database Schema](../reference/database-schema.md) - Database versioning and migration strategies

---

**Consistent semantic versioning practices ensure predictable releases, clear communication of changes, and smooth upgrade experiences for users and developers.**