# Workflow Configuration Files Guide

## Overview

This document provides comprehensive configuration files and settings required to implement the feature branch workflow with automated tagging across different platforms and environments.

## Repository Configuration Files

### 1. Git Attributes Configuration

**File**: `.gitattributes`

```gitattributes
# Git Attributes for Prismatic Feature Branch Workflow

# =============================================================================
# AUTO-DETECTION OVERRIDES
# =============================================================================

# Force Git to treat specific files as text/binary
*.md            text eol=lf
*.ex            text eol=lf
*.exs           text eol=lf
*.yml           text eol=lf
*.yaml          text eol=lf
*.json          text eol=lf
*.js            text eol=lf
*.css           text eol=lf
*.html          text eol=lf
*.heex          text eol=lf

# Binary files
*.png           binary
*.jpg           binary
*.jpeg          binary
*.gif           binary
*.ico           binary
*.svg           binary
*.woff          binary
*.woff2         binary
*.ttf           binary
*.eot           binary

# =============================================================================
# MERGE STRATEGIES
# =============================================================================

# Use union merge for changelog to avoid conflicts
CHANGELOG.md    merge=union

# Custom merge strategy for version files
mix.exs         merge=ours
package.json    merge=ours

# =============================================================================
# DIFF AND MERGE SETTINGS
# =============================================================================

# Better diff output for Elixir files
*.ex            diff=elixir
*.exs           diff=elixir

# Better diff for documentation
*.md            diff=markdown

# =============================================================================
# EXPORT-IGNORE (for git archive)
# =============================================================================

# Development and testing files
.gitignore          export-ignore
.gitattributes      export-ignore
.tool-versions      export-ignore
.formatter.exs      export-ignore

# CI/CD files
.github/            export-ignore
.gitlab-ci.yml      export-ignore

# Documentation source
docs/_meta/         export-ignore
docs/guides/        export-ignore

# Testing and development
test/               export-ignore
scripts/            export-ignore

# =============================================================================
# LINGUIST SETTINGS (GitHub language detection)
# =============================================================================

# Mark files as documentation
docs/**             linguist-documentation
*.md                linguist-documentation

# Mark files as generated
_build/**           linguist-generated
deps/**             linguist-generated
doc/**              linguist-generated
cover/**            linguist-generated

# Mark vendor files
assets/vendor/**    linguist-vendored
priv/static/**      linguist-vendored

# =============================================================================
# SECURITY AND SECRETS
# =============================================================================

# Prevent secrets from being stored in Git history
*.secret            text eol=lf
*.key               text eol=lf
.env*               text eol=lf

# Filter driver for cleaning secrets (if configured)
config/*.secret.exs filter=clean-secrets
```

### 2. Git Ignore Configuration

**File**: Enhanced `.gitignore` (extends existing)

```gitignore
# =============================================================================
# WORKFLOW-SPECIFIC PATTERNS  
# =============================================================================

# Branch workflow temporary files
.branch-info
.feature-docs.md
.bugfix-docs.md
.hotfix-docs.md
.release-docs.md

# Mix task temporary files
.mix-task-*
.workflow-status.*

# Version management temporary files
version.env
release.env
tag.env

# =============================================================================
# DOCUMENTATION GENERATION
# =============================================================================

# Generated documentation reports
docs-report.md
docs-report.html
docs-report.json

# Documentation validation cache
.docs-validation-cache/
.cross-reference-cache/
.glossary-validation-cache/

# =============================================================================
# CI/CD ARTIFACTS
# =============================================================================

# GitHub Actions artifacts
.github-actions-cache/
workflow-status.json

# GitLab CI artifacts
.gitlab-ci-cache/
pipeline-status.json

# Branch protection validation
.branch-protection-status

# =============================================================================
# DEVELOPMENT WORKFLOW
# =============================================================================

# Pre-commit hook outputs
.pre-commit-output
.validation-results

# Git hook temporary files
.git-hook-*

# Version bump working files
.version-*
.changelog-*

# =============================================================================
# EDITOR AND IDE WORKFLOW
# =============================================================================

# VS Code workflow settings (project-specific)
.vscode/launch.json
.vscode/tasks.json
.vscode/c_cpp_properties.json

# Vim workflow files
.workflow.vim
Session.vim

# =============================================================================
# TESTING AND VALIDATION
# =============================================================================

# Workflow testing artifacts
test/workflow/
test/fixtures/git-repos/

# Integration test temporary repos
/tmp-test-repos/

# Coverage for workflow tests
/workflow-cover/
```

### 3. Editor Configuration

**File**: `.editorconfig`

```ini
# EditorConfig for Prismatic Feature Branch Workflow
# https://editorconfig.org

root = true

# =============================================================================
# DEFAULT SETTINGS
# =============================================================================

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2

# =============================================================================
# LANGUAGE-SPECIFIC SETTINGS
# =============================================================================

# Elixir files
[*.{ex,exs}]
indent_size = 2

# JavaScript/TypeScript
[*.{js,ts,jsx,tsx}]
indent_size = 2

# CSS/SCSS
[*.{css,scss,sass}]
indent_size = 2

# HTML/HEEX templates
[*.{html,heex}]
indent_size = 2

# Configuration files
[*.{yml,yaml}]
indent_size = 2

[*.json]
indent_size = 2

# Documentation
[*.md]
indent_size = 2
trim_trailing_whitespace = false  # Preserve markdown formatting

# Shell scripts
[*.{sh,bash}]
indent_size = 2

# Python (for documentation scripts)
[*.py]
indent_size = 4

# =============================================================================
# PROJECT-SPECIFIC FILES
# =============================================================================

# Mix configuration
[mix.exs]
indent_size = 2

# Phoenix configuration
[config/*.exs]
indent_size = 2

# Git workflow scripts
[scripts/**]
indent_size = 2

# Documentation configuration
[docs/**/*.md]
indent_size = 2
max_line_length = 80

# =============================================================================
# CI/CD CONFIGURATION
# =============================================================================

# GitHub Actions
[.github/workflows/*.yml]
indent_size = 2

# GitLab CI
[.gitlab-ci.yml]
indent_size = 2

[.gitlab/ci/*.yml]
indent_size = 2
```

## Platform-Specific Configuration

### 4. GitHub Repository Configuration

**File**: `docs/config/github-repository-settings.md`

```markdown
# GitHub Repository Configuration

## Branch Protection Rules

### Main Branch Protection

Configure the following settings for the `main` branch:

```json
{
  "protection": {
    "required_status_checks": {
      "strict": true,
      "contexts": [
        "validate-branch-name",
        "code-quality",
        "test",
        "security",
        "docs-validation"
      ]
    },
    "enforce_admins": true,
    "required_pull_request_reviews": {
      "required_approving_review_count": 1,
      "dismiss_stale_reviews": true,
      "require_code_owner_reviews": true,
      "restrict_dismissals": false
    },
    "restrictions": null,
    "allow_force_pushes": false,
    "allow_deletions": false
  }
}
```

### Repository Settings

**General Settings:**
- Default branch: `main`
- Allow merge commits: ✅
- Allow squash merging: ✅ (default)
- Allow rebase merging: ✅
- Automatically delete head branches: ✅

**Pull Request Settings:**
- Allow auto-merge: ✅
- Require branches to be up to date: ✅
- Suggest updating pull request branches: ✅

### Actions & Secrets

**Repository Secrets:**
```yaml
SLACK_WEBHOOK_URL: <webhook-url>         # Optional
TEAMS_WEBHOOK_URL: <webhook-url>         # Optional
CODECOV_TOKEN: <token>                   # Optional
```

**Environment Variables:**
```yaml
MIX_ENV: test
ELIXIR_VERSION: "1.15.7"
OTP_VERSION: "26.1.2"
```

### Code Owners

**File**: `.github/CODEOWNERS`

```gitignore
# Code Owners for Prismatic Feature Branch Workflow

# =============================================================================
# GLOBAL OWNERSHIP
# =============================================================================

# Default owners for all files
* @team-leads @senior-developers

# =============================================================================
# CRITICAL WORKFLOW FILES
# =============================================================================

# Git hooks and workflow scripts
.git/hooks/* @team-leads @devops
scripts/ @team-leads @devops

# CI/CD configuration
.github/ @team-leads @devops
.gitlab-ci.yml @team-leads @devops

# Branch workflow configuration
docs/guides/branch-workflow-*.md @team-leads @technical-writers
docs/guides/git-hooks-*.md @team-leads @devops

# =============================================================================
# CORE APPLICATION
# =============================================================================

# Phoenix application core
apps/prismatic/lib/ @senior-developers @elixir-experts
apps/prismatic_web/lib/ @senior-developers @phoenix-experts

# Database migrations
apps/*/priv/repo/migrations/ @senior-developers @database-admins

# Configuration files
config/ @team-leads @senior-developers

# =============================================================================
# DOCUMENTATION
# =============================================================================

# Core documentation
docs/core/ @team-leads @technical-writers
docs/architecture/ @team-leads @architects

# API documentation
docs/api/ @senior-developers @technical-writers

# User guides
docs/guides/ @technical-writers @user-experience

# Glossary and references
docs/reference/ @technical-writers
docs/_meta/ @team-leads @technical-writers

# =============================================================================
# RELEASE AND DEPLOYMENT
# =============================================================================

# Version and release files
mix.exs @team-leads
CHANGELOG.md @team-leads @technical-writers

# Deployment configuration
deployment/ @team-leads @devops @sre

# Docker files
Dockerfile* @devops @sre
docker-compose*.yml @devops @sre

# =============================================================================
# SECURITY AND COMPLIANCE
# =============================================================================

# Security configuration
.github/workflows/security-*.yml @security @devops
docs/security/ @security @compliance

# Dependency files
mix.lock @senior-developers @security
package-lock.json @senior-developers @security
```

### Issue and PR Templates

**File**: `.github/ISSUE_TEMPLATE/feature-request.yml`

```yaml
name: Feature Request
description: Request a new feature following the branch workflow
title: "[FEATURE] "
labels: ["enhancement", "needs-planning"]
assignees: []

body:
  - type: markdown
    attributes:
      value: |
        ## Feature Request Template
        
        This template ensures proper planning and documentation for new features in the branch workflow.

  - type: input
    id: feature-name
    attributes:
      label: Feature Name
      description: What should the feature branch be named?
      placeholder: "feature/user-authentication"
    validations:
      required: true

  - type: textarea
    id: description
    attributes:
      label: Feature Description
      description: Describe the feature in detail
      placeholder: "A comprehensive description of what this feature should do..."
    validations:
      required: true

  - type: checkboxes
    id: documentation-requirements
    attributes:
      label: Documentation Requirements
      description: What documentation will need to be updated?
      options:
        - label: API documentation
        - label: User guides
        - label: Technical specifications
        - label: Glossary updates
        - label: Cross-reference updates

  - type: checkboxes
    id: workflow-checklist
    attributes:
      label: Branch Workflow Checklist
      description: Confirm workflow requirements
      options:
        - label: I will create the feature branch using `mix branch.create feature/name`
          required: true
        - label: I will follow conventional commit message format
          required: true
        - label: I will update all required documentation
          required: true
        - label: I will run `mix branch.validate` before creating PR
          required: true
```

**File**: `.github/pull_request_template.md`

```markdown
## Pull Request Checklist

<!-- This template ensures compliance with the feature branch workflow -->

### Branch Information
- **Branch Name**: `<!-- branch name here -->`
- **Branch Type**: <!-- feature/bugfix/hotfix/docs/chore -->
- **Related Issue**: #<!-- issue number -->

### Workflow Compliance
- [ ] Branch follows naming convention: `type/description`
- [ ] Branch created using `mix branch.create` or follows proper process
- [ ] All commits follow conventional commit format
- [ ] `mix branch.validate` passes without errors
- [ ] Branch is up to date with `main`

### Code Quality
- [ ] All tests pass locally
- [ ] Code follows project style guidelines (`mix format` applied)
- [ ] No compiler warnings
- [ ] New code has appropriate test coverage

### Documentation Updates
- [ ] Code documentation updated (inline docs, `@moduledoc`, `@doc`)
- [ ] API documentation updated (if applicable)
- [ ] User guides updated (if applicable)
- [ ] Glossary updated with new terms (if applicable)
- [ ] Cross-references validated and updated

### Security & Performance
- [ ] Security implications considered and documented
- [ ] Performance impact evaluated
- [ ] No sensitive information exposed

### Review Requirements
- [ ] Ready for review
- [ ] Breaking changes documented (if any)
- [ ] Migration guide provided (if applicable)

## Description
<!-- Provide a detailed description of the changes -->

## Testing
<!-- Describe how the changes have been tested -->

## Screenshots (if applicable)
<!-- Add screenshots to help explain your changes -->

## Additional Notes
<!-- Any additional information reviewers should know -->

---

**Reviewer Checklist:**
- [ ] Code follows project conventions
- [ ] Documentation is complete and accurate
- [ ] Tests are comprehensive
- [ ] Security review completed (if needed)
- [ ] Performance impact acceptable
```

### 5. GitLab Repository Configuration

**File**: `docs/config/gitlab-repository-settings.md`

```markdown
# GitLab Repository Configuration

## Push Rules

Configure the following push rules in **Settings > Repository > Push Rules**:

- ✅ **Deny deleting a tag**
- ✅ **Check whether the commit author is a GitLab user**
- ✅ **Restrict commits by author (email)**
- ✅ **GitLab will reject unsigned commits**
- ✅ **Restrict pushes to Git tag**
- **Prohibited file names**: `*.secret,*.key,.env*`
- **Required branch name**: `^(main|feature\/.*|bugfix\/.*|hotfix\/.*|release\/.*|chore\/.*|docs\/.*)$`
- **Commit message pattern**: `^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?: .+|^Merge`

## Protected Branches

### Main Branch Protection

Configure `main` branch with these settings:

- **Allowed to merge**: Maintainers
- **Allowed to push**: No one
- **Allowed to force push**: No one
- **Code owner approval required**: ✅
- **Inherited**: No

## Merge Request Settings

- **Merge method**: Merge commit
- **Squash commits**: Allow
- **Fast-forward merge**: Require
- **Remove source branch**: ✅
- **Pipelines must succeed**: ✅
- **All threads must be resolved**: ✅

## CI/CD Variables

Configure these variables in **Settings > CI/CD > Variables**:

```yaml
DATABASE_URL: "postgresql://postgres:postgres@postgres/prismatic_test"
MIX_ENV: "test"
ELIXIR_VERSION: "1.15.7"
OTP_VERSION: "26.1.2"
SLACK_WEBHOOK_URL: "<webhook-url>"    # Optional, Masked
TEAMS_WEBHOOK_URL: "<webhook-url>"    # Optional, Masked
```

## Merge Request Templates

**File**: `.gitlab/merge_request_templates/feature.md`

```markdown
## Feature Merge Request

### Branch Information
- **Source Branch**: `<!-- branch name -->`
- **Target Branch**: `main`
- **Feature Type**: <!-- New Feature/Enhancement/API Change -->

### Workflow Compliance
- [ ] Branch name follows convention: `feature/description`
- [ ] Created using proper branch workflow
- [ ] All commits use conventional format
- [ ] Pipeline validation passes
- [ ] Branch synchronized with main

### Implementation Details
<!-- Describe what was implemented -->

### Documentation Updates
- [ ] Code documentation complete
- [ ] API changes documented
- [ ] User guides updated
- [ ] Glossary entries added/updated

### Testing Coverage
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Performance testing (if applicable)

### Review Checklist
- [ ] Code follows Elixir/Phoenix best practices
- [ ] Security considerations addressed
- [ ] Error handling appropriate
- [ ] Logging and monitoring included

/label ~feature ~workflow-compliant
/assign @reviewer
```
```

### 6. Team Configuration Templates

**File**: `docs/config/team-setup-template.md`

```markdown
# Team Setup Configuration Template

## Git Configuration

Each team member should configure their local Git environment:

```bash
# Basic Git configuration
git config --global user.name "Your Name"
git config --global user.email "your.email@company.com"

# Signing commits (recommended)
git config --global commit.gpgsign true
git config --global user.signingkey YOUR_GPG_KEY_ID

# Branch workflow settings
git config --global pull.rebase true
git config --global branch.autosetupmerge always
git config --global branch.autosetuprebase always

# Better diff and merge tools
git config --global diff.tool vscode
git config --global merge.tool vscode
git config --global difftool.vscode.cmd 'code --wait --diff $LOCAL $REMOTE'
git config --global mergetool.vscode.cmd 'code --wait $MERGED'

# Workflow-specific aliases
git config --global alias.feature '!f() { mix branch.create feature/$1; }; f'
git config --global alias.bugfix '!f() { mix branch.create bugfix/$1; }; f'
git config --global alias.hotfix '!f() { mix branch.create hotfix/$1; }; f'
git config --global alias.sync '!git fetch origin main && git rebase origin/main'
git config --global alias.validate '!mix branch.validate'
git config --global alias.status-workflow '!mix workflow.status'
```

## IDE Configuration

### VS Code Settings

**File**: `.vscode/settings.json`

```json
{
  "elixir.projectPath": ".",
  "elixir.suggestSpecs": true,
  "elixir.dialyzerEnabled": true,
  
  "files.associations": {
    "*.heex": "html-eex",
    "*.leex": "html-eex"
  },
  
  "emmet.includeLanguages": {
    "html-eex": "html"
  },
  
  "git.enableSmartCommit": true,
  "git.confirmSync": false,
  "git.autofetch": true,
  "git.pullTags": true,
  
  "conventionalCommits.autoCommit": false,
  "conventionalCommits.showEditor": true,
  "conventionalCommits.emojiFormat": "emoji",
  
  "files.watcherExclude": {
    "**/_build/**": true,
    "**/deps/**": true,
    "**/node_modules/**": true
  },
  
  "search.exclude": {
    "_build": true,
    "deps": true,
    "doc": true,
    "cover": true
  },
  
  "terminal.integrated.env.osx": {
    "MIX_ENV": "dev"
  },
  
  "terminal.integrated.env.linux": {
    "MIX_ENV": "dev"
  },
  
  "tasks.version": "2.0.0",
  "launch.version": "0.2.0"
}
```

**File**: `.vscode/tasks.json`

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Branch: Create Feature",
      "type": "shell",
      "command": "mix",
      "args": ["branch.create", "feature/${input:featureName}"],
      "group": "build",
      "presentation": {
        "echo": true,
        "reveal": "always",
        "panel": "new"
      }
    },
    {
      "label": "Branch: Validate",
      "type": "shell",
      "command": "mix",
      "args": ["branch.validate"],
      "group": "test",
      "presentation": {
        "echo": true,
        "reveal": "always"
      }
    },
    {
      "label": "Workflow: Status",
      "type": "shell",
      "command": "mix",
      "args": ["workflow.status", "--verbose"],
      "group": "test"
    },
    {
      "label": "Version: Bump Patch",
      "type": "shell",
      "command": "mix",
      "args": ["version.bump", "patch", "--tag"],
      "group": "build"
    },
    {
      "label": "Format Code",
      "type": "shell",
      "command": "mix",
      "args": ["format"],
      "group": "build"
    },
    {
      "label": "Run Tests",
      "type": "shell",
      "command": "mix",
      "args": ["test"],
      "group": "test"
    }
  ],
  "inputs": [
    {
      "id": "featureName",
      "description": "Feature name (will be prefixed with 'feature/')",
      "default": "new-feature",
      "type": "promptString"
    }
  ]
}
```

### VS Code Extensions

**File**: `.vscode/extensions.json`

```json
{
  "recommendations": [
    "jakebecker.elixir-ls",
    "bradlc.vscode-tailwindcss",
    "ms-vscode.vscode-json",
    "redhat.vscode-yaml",
    "davidanson.vscode-markdownlint",
    "yzhang.markdown-all-in-one",
    "github.vscode-pull-request-github",
    "gitlab.gitlab-workflow",
    "vivaxy.vscode-conventional-commits",
    "ms-vscode.vscode-todo-highlight",
    "gruntfuggly.todo-tree",
    "streetsidesoftware.code-spell-checker"
  ]
}
```

## Environment Setup

### Development Environment

**File**: `.env.example`

```bash
# Development Environment Configuration
MIX_ENV=dev

# Database Configuration
DATABASE_URL=postgresql://postgres:postgres@localhost/prismatic_dev
TEST_DATABASE_URL=postgresql://postgres:postgres@localhost/prismatic_test

# Phoenix Configuration
SECRET_KEY_BASE=your-secret-key-base-here
LIVE_VIEW_SIGNING_SALT=your-signing-salt-here

# External Services (Development)
EXTERNAL_API_URL=https://api.development.example.com
EXTERNAL_API_KEY=dev-api-key

# Workflow Configuration
ENABLE_GIT_HOOKS=true
WORKFLOW_VALIDATION_LEVEL=standard
AUTO_DOCUMENTATION_SYNC=true

# CI/CD Integration
GITHUB_TOKEN=your-github-token
GITLAB_TOKEN=your-gitlab-token

# Notification Settings (Optional)
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
TEAMS_WEBHOOK_URL=https://outlook.office.com/webhook/...

# Feature Flags
ENABLE_FEATURE_BRANCH_TEMPLATES=true
ENABLE_AUTOMATIC_TAGGING=true
ENABLE_DOCUMENTATION_VALIDATION=true
```

### Tool Versions

**File**: `.tool-versions`

```bash
# Tool versions for Prismatic Feature Branch Workflow
elixir 1.15.7-otp-26
erlang 26.1.2
nodejs 18.18.0
python 3.11.5
```

## Workflow Scripts

### Setup Script

**File**: `scripts/setup-workflow.sh`

```bash
#!/bin/bash
# Workflow setup script for new team members

set -e

echo "🚀 Setting up Prismatic Feature Branch Workflow..."

# Check dependencies
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        echo "❌ $1 is required but not installed"
        exit 1
    fi
}

echo "📋 Checking dependencies..."
check_dependency "git"
check_dependency "elixir"
check_dependency "mix"
check_dependency "node"
check_dependency "python3"

# Install git hooks
echo "🔧 Installing git hooks..."
if [ -f "scripts/install-git-hooks.sh" ]; then
    bash scripts/install-git-hooks.sh
else
    echo "⚠️  Git hooks script not found, skipping..."
fi

# Install Elixir dependencies
echo "📦 Installing Elixir dependencies..."
mix deps.get
mix deps.compile

# Install Node dependencies (if package.json exists)
if [ -f "package.json" ]; then
    echo "📦 Installing Node dependencies..."
    npm install
fi

# Install Python dependencies for documentation tools
if [ -f "docs/requirements.txt" ]; then
    echo "📦 Installing Python documentation tools..."
    pip3 install -r docs/requirements.txt
fi

# Setup database
echo "🗄️  Setting up database..."
mix ecto.create
mix ecto.migrate

# Run initial validation
echo "✅ Running initial workflow validation..."
mix branch.validate || echo "⚠️  Some validations failed - this is normal for initial setup"

# Generate workflow status
echo "📊 Generating workflow status..."
mix workflow.status

echo ""
echo "🎉 Workflow setup complete!"
echo ""
echo "📚 Next steps:"
echo "  1. Review the workflow documentation: docs/guides/branch-workflow-*.md"
echo "  2. Configure your IDE settings (see docs/config/team-setup-template.md)"
echo "  3. Create your first feature branch: mix branch.create feature/my-first-feature"
echo "  4. Run workflow status anytime: mix workflow.status"
echo ""
echo "💡 Need help? Check docs/guides/ or ask in team chat!"
```

### Validation Script

**File**: `scripts/validate-workflow-setup.sh`

```bash
#!/bin/bash
# Validate workflow setup for team members

set -e

echo "🔍 Validating Prismatic Feature Branch Workflow Setup..."

ERRORS=0
WARNINGS=0

validate_git_config() {
    echo "📋 Validating Git configuration..."
    
    if [ -z "$(git config user.name)" ]; then
        echo "❌ Git user.name not configured"
        ERRORS=$((ERRORS + 1))
    fi
    
    if [ -z "$(git config user.email)" ]; then
        echo "❌ Git user.email not configured"
        ERRORS=$((ERRORS + 1))
    fi
    
    if [ -z "$(git config --get alias.feature)" ]; then
        echo "⚠️  Git workflow aliases not configured"
        WARNINGS=$((WARNINGS + 1))
    fi
}

validate_git_hooks() {
    echo "🔧 Validating Git hooks..."
    
    HOOKS=("pre-commit" "pre-push" "post-merge" "commit-msg")
    
    for hook in "${HOOKS[@]}"; do
        if [ ! -f ".git/hooks/$hook" ]; then
            echo "⚠️  Git hook $hook not installed"
            WARNINGS=$((WARNINGS + 1))
        elif [ ! -x ".git/hooks/$hook" ]; then
            echo "❌ Git hook $hook not executable"
            ERRORS=$((ERRORS + 1))
        fi
    done
}

validate_mix_tasks() {
    echo "🧪 Validating Mix tasks..."
    
    TASKS=("branch.create" "branch.validate" "workflow.status" "version.bump")
    
    for task in "${TASKS[@]}"; do
        if ! mix help "$task" &> /dev/null; then
            echo "❌ Mix task $task not available"
            ERRORS=$((ERRORS + 1))
        fi
    done
}

validate_documentation_tools() {
    echo "📚 Validating documentation tools..."
    
    if ! command -v python3 &> /dev/null; then
        echo "❌ Python 3 not available (needed for documentation validation)"
        ERRORS=$((ERRORS + 1))
    fi
    
    if ! command -v node &> /dev/null; then
        echo "❌ Node.js not available (needed for markdown validation)"
        ERRORS=$((ERRORS + 1))
    fi
}

validate_environment() {
    echo "🌍 Validating environment..."
    
    if [ ! -f ".env" ] && [ ! -f ".env.local" ]; then
        echo "⚠️  No environment file found (.env or .env.local)"
        WARNINGS=$((WARNINGS + 1))
    fi
    
    if [ -z "$MIX_ENV" ]; then
        echo "⚠️  MIX_ENV not set (defaults to dev)"
        WARNINGS=$((WARNINGS + 1))
    fi
}

validate_dependencies() {
    echo "📦 Validating dependencies..."
    
    if [ ! -d "deps" ]; then
        echo "❌ Elixir dependencies not installed (run: mix deps.get)"
        ERRORS=$((ERRORS + 1))
    fi
    
    if [ ! -d "_build" ]; then
        echo "⚠️  Project not compiled (run: mix compile)"
        WARNINGS=$((WARNINGS + 1))
    fi
}

# Run all validations
validate_git_config
validate_git_hooks
validate_mix_tasks
validate_documentation_tools
validate_environment
validate_dependencies

# Report results
echo ""
echo "📊 Validation Results:"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ All validations passed! Workflow setup is complete."
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  Setup complete with $WARNINGS warnings."
    echo "💡 Check warnings above for optional improvements."
    exit 0
else
    echo "❌ Setup incomplete with $ERRORS errors and $WARNINGS warnings."
    echo "🔧 Please fix the errors above before using the workflow."
    exit 1
fi
```

## Configuration Summary

### Essential Files Checklist

- [ ] `.gitattributes` - Git file handling configuration
- [ ] `.gitignore` - Enhanced with workflow-specific patterns  
- [ ] `.editorconfig` - Consistent editor settings
- [ ] `.github/CODEOWNERS` - Code ownership definitions
- [ ] `.github/workflows/` - CI/CD pipeline configurations
- [ ] `.vscode/settings.json` - IDE configuration
- [ ] `.tool-versions` - Development tool versions
- [ ] `scripts/setup-workflow.sh` - Team setup automation
- [ ] `scripts/validate-workflow-setup.sh` - Setup validation

### Platform Configuration

- [ ] GitHub branch protection rules
- [ ] GitHub repository settings
- [ ] GitLab push rules and protected branches  
- [ ] GitLab CI/CD variables
- [ ] Team git configuration
- [ ] IDE extensions and settings

### Integration Points

- [ ] Git hooks installation
- [ ] Mix tasks availability
- [ ] Documentation tools setup
- [ ] CI/CD pipeline activation
- [ ] Team onboarding automation

This comprehensive configuration ensures consistent implementation of the feature branch workflow across all team members and environments.