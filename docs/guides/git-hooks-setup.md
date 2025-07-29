# Git Hooks Setup Guide

Comprehensive guide for setting up and configuring Git hooks to enforce code quality, security, and development standards in the Prismatic project.

<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > [Guides](README.md) > Git Hooks Setup

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to guides index
- **🏠 [Documentation Home](../README.md)** - Main documentation index
- **🔍 [Search Documentation](../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Semantic Versioning](semantic-versioning.md) - Version management automation
- [Style Guide](style-guide.md) - Code and documentation standards
- [CI/CD Configuration](../operations/cicd-configuration.md) - Continuous integration workflows
- [Security Guidelines](security-guidelines.md) - Security validation in hooks
- [Performance Optimization](performance-optimization.md) - Performance checks automation
<!-- NAV_END -->

## Overview

Git hooks are scripts that run automatically at specific points in the Git workflow. This guide covers the setup and configuration of client-side and server-side hooks for the Prismatic project, ensuring code quality, security, and consistency across all commits and deployments.

## Hook Types and Purposes

### Client-Side Hooks

**Pre-Commit Hooks**
- Code formatting validation
- Linting and static analysis
- Security vulnerability scanning
- Test execution for changed files
- Documentation updates

**Commit-Message Hooks**
- Conventional commit format validation
- Issue reference requirements
- Message length and style checks

**Pre-Push Hooks**
- Full test suite execution
- Build verification
- Security audit checks
- Performance regression tests

### Server-Side Hooks

**Pre-Receive Hooks**
- Branch protection enforcement
- Commit signature verification
- Large file detection
- Security policy compliance

**Post-Receive Hooks**
- Deployment triggers
- Notification systems
- Documentation updates
- Metrics collection

## Installation and Setup

### Automated Installation

#### Setup Script
```bash
#!/bin/bash
# scripts/setup-git-hooks.sh

set -e

HOOKS_DIR=".githooks"
GIT_HOOKS_DIR=".git/hooks"

echo "Setting up Git hooks for Prismatic..."

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Configure Git to use our hooks directory
git config core.hooksPath "$HOOKS_DIR"

# Make all hook files executable
find "$HOOKS_DIR" -type f -exec chmod +x {} \;

echo "✅ Git hooks configured successfully!"
echo "📝 Hooks directory: $HOOKS_DIR"
echo "🔗 Git hooks path: $(git config core.hooksPath)"

# Install dependencies if needed
if command -v npm &> /dev/null; then
    echo "📦 Installing hook dependencies..."
    npm install --save-dev husky lint-staged
fi

if command -v mix &> /dev/null; then
    echo "🧪 Installing Elixir hook dependencies..."
    mix deps.get
fi

echo "🎉 Setup complete! Hooks are now active."
```

#### Makefile Integration
```makefile
# Makefile
.PHONY: setup-hooks install-hooks test-hooks

setup-hooks:
	@echo "Setting up Git hooks..."
	@./scripts/setup-git-hooks.sh

install-hooks: setup-hooks
	@echo "Installing hook dependencies..."
	@npm install --save-dev husky lint-staged
	@mix deps.get

test-hooks:
	@echo "Testing Git hooks..."
	@.githooks/pre-commit --test
	@.githooks/commit-msg --test "feat: test commit message"
	@echo "✅ All hooks tested successfully!"

dev-setup: install-hooks
	@echo "Development environment setup complete!"
```

### Manual Installation

#### Step-by-Step Setup
```bash
# 1. Clone repository and navigate to project
git clone https://github.com/example/prismatic.git
cd prismatic

# 2. Create hooks directory
mkdir -p .githooks

# 3. Configure Git to use custom hooks directory
git config core.hooksPath .githooks

# 4. Copy hook templates
cp scripts/hooks/* .githooks/

# 5. Make hooks executable
chmod +x .githooks/*

# 6. Install dependencies
npm install --save-dev husky lint-staged
mix deps.get
```

## Pre-Commit Hook Configuration

### Main Pre-Commit Hook

#### .githooks/pre-commit
```bash
#!/bin/bash
# Pre-commit hook for Prismatic project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get list of staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED_FILES" ]; then
    log_info "No staged files found. Skipping pre-commit hooks."
    exit 0
fi

log_info "Running pre-commit hooks..."

# Flag to track if any check fails
CHECKS_FAILED=0

# 1. Check for forbidden patterns
log_info "Checking for forbidden patterns..."
FORBIDDEN_PATTERNS=(
    "console\.log"
    "debugger"
    "TODO.*FIXME"
    "\.focus\(\)"
    "\.only\("
    "binding\.pry"
    "IO\.inspect"
    "IEx\.pry"
)

for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
    if echo "$STAGED_FILES" | xargs grep -l "$pattern" 2>/dev/null; then
        log_error "Found forbidden pattern: $pattern"
        echo "$STAGED_FILES" | xargs grep -n "$pattern" 2>/dev/null || true
        CHECKS_FAILED=1
    fi
done

# 2. Check for large files
log_info "Checking for large files..."
for file in $STAGED_FILES; do
    if [ -f "$file" ]; then
        size=$(wc -c < "$file")
        if [ $size -gt 1048576 ]; then # 1MB
            log_error "File $file is too large: ${size} bytes (max: 1MB)"
            CHECKS_FAILED=1
        fi
    fi
done

# 3. Check for secrets
log_info "Scanning for secrets..."
if command -v gitleaks &> /dev/null; then
    if ! gitleaks protect --staged; then
        log_error "Potential secrets detected"
        CHECKS_FAILED=1
    fi
else
    log_warn "gitleaks not found. Install with: brew install gitleaks"
fi

# 4. Elixir-specific checks
ELIXIR_FILES=$(echo "$STAGED_FILES" | grep -E '\.(ex|exs)$' || true)
if [ -n "$ELIXIR_FILES" ]; then
    log_info "Running Elixir checks..."
    
    # Format check
    if ! mix format --check-formatted $ELIXIR_FILES; then
        log_error "Elixir formatting issues found. Run: mix format"
        CHECKS_FAILED=1
    fi
    
    # Credo check
    if ! mix credo --strict $ELIXIR_FILES; then
        log_error "Credo issues found"
        CHECKS_FAILED=1
    fi
    
    # Compile check
    if ! mix compile --warnings-as-errors; then
        log_error "Compilation warnings/errors found"
        CHECKS_FAILED=1
    fi
    
    # Dialyzer for critical files
    CRITICAL_FILES=$(echo "$ELIXIR_FILES" | grep -E '(auth|payment|security)' || true)
    if [ -n "$CRITICAL_FILES" ]; then
        log_info "Running Dialyzer on critical files..."
        if ! mix dialyzer $CRITICAL_FILES; then
            log_warn "Dialyzer issues found in critical files"
        fi
    fi
fi

# 5. JavaScript/TypeScript checks
JS_FILES=$(echo "$STAGED_FILES" | grep -E '\.(js|ts|jsx|tsx)$' || true)
if [ -n "$JS_FILES" ]; then
    log_info "Running JavaScript/TypeScript checks..."
    
    cd assets || exit 1
    
    # ESLint check
    if ! npx eslint $JS_FILES; then
        log_error "ESLint issues found"
        CHECKS_FAILED=1
    fi
    
    # Prettier check
    if ! npx prettier --check $JS_FILES; then
        log_error "Prettier formatting issues found. Run: npm run format"
        CHECKS_FAILED=1
    fi
    
    # TypeScript check if applicable
    TS_FILES=$(echo "$JS_FILES" | grep -E '\.(ts|tsx)$' || true)
    if [ -n "$TS_FILES" ]; then
        if ! npx tsc --noEmit; then
            log_error "TypeScript compilation errors found"
            CHECKS_FAILED=1
        fi
    fi
    
    cd ..
fi

# 6. Test execution for modified files
log_info "Running tests for modified files..."

# Find test files related to modified files
TEST_FILES=""
for file in $ELIXIR_FILES; do
    # Convert lib/module/file.ex to test/module/file_test.exs
    test_file=$(echo "$file" | sed 's|^lib/|test/|' | sed 's|\.ex$|_test.exs|')
    if [ -f "$test_file" ]; then
        TEST_FILES="$TEST_FILES $test_file"
    fi
done

if [ -n "$TEST_FILES" ]; then
    if ! MIX_ENV=test mix test $TEST_FILES; then
        log_error "Tests failed for modified files"
        CHECKS_FAILED=1
    fi
else
    log_info "No specific tests found for modified files"
fi

# 7. Documentation checks
DOCS_FILES=$(echo "$STAGED_FILES" | grep -E '\.(md|ex|exs)$' || true)
if [ -n "$DOCS_FILES" ]; then
    log_info "Checking documentation..."
    
    # Check for broken links in markdown files
    MD_FILES=$(echo "$DOCS_FILES" | grep '\.md$' || true)
    if [ -n "$MD_FILES" ] && [ -f "scripts/check-docs-links.sh" ]; then
        if ! ./scripts/check-docs-links.sh $MD_FILES; then
            log_warn "Documentation link issues found"
        fi
    fi
    
    # Check for @doc tags in Elixir files
    for file in $(echo "$DOCS_FILES" | grep -E '\.(ex|exs)$' || true); do
        if grep -q "^  def " "$file" && ! grep -q "@doc" "$file"; then
            log_warn "File $file contains public functions without @doc tags"
        fi
    done
fi

# 8. Security checks
log_info "Running security checks..."

# Check for hardcoded secrets patterns
SECRET_PATTERNS=(
    "password\s*=\s*['\"][^'\"]{8,}"
    "api_key\s*=\s*['\"][^'\"]{16,}"
    "secret\s*=\s*['\"][^'\"]{16,}"
    "token\s*=\s*['\"][^'\"]{20,}"
    "-----BEGIN RSA PRIVATE KEY-----"
    "-----BEGIN PRIVATE KEY-----"
)

for pattern in "${SECRET_PATTERNS[@]}"; do
    if echo "$STAGED_FILES" | xargs grep -l -E "$pattern" 2>/dev/null; then
        log_error "Potential secret found: $pattern"
        CHECKS_FAILED=1
    fi
done

# 9. Dependencies check
if echo "$STAGED_FILES" | grep -q "mix.exs\|mix.lock"; then
    log_info "Checking Elixir dependencies for vulnerabilities..."
    if command -v mix &> /dev/null; then
        if ! mix deps.audit; then
            log_warn "Dependency vulnerabilities found"
        fi
    fi
fi

if echo "$STAGED_FILES" | grep -q "package.json\|package-lock.json"; then
    log_info "Checking npm dependencies for vulnerabilities..."
    cd assets || exit 1
    if ! npm audit --audit-level=moderate; then
        log_warn "npm audit found issues"
    fi
    cd ..
fi

# Summary
if [ $CHECKS_FAILED -eq 0 ]; then
    log_info "✅ All pre-commit checks passed!"
    exit 0
else
    log_error "❌ Pre-commit checks failed. Please fix the issues above."
    exit 1
fi
```

### Lint-Staged Configuration

#### package.json Configuration
```json
{
  "devDependencies": {
    "husky": "^8.0.3",
    "lint-staged": "^13.2.3"
  },
  "lint-staged": {
    "*.{js,jsx,ts,tsx}": [
      "eslint --fix",
      "prettier --write",
      "git add"
    ],
    "*.{css,scss,sass}": [
      "stylelint --fix",
      "prettier --write",
      "git add"
    ],
    "*.{md,json,yaml,yml}": [
      "prettier --write",
      "git add"
    ]
  },
  "scripts": {
    "prepare": "husky install",
    "lint-staged": "lint-staged"
  }
}
```

#### Husky Configuration
```bash
# .husky/pre-commit
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

# Run custom pre-commit hook
./.githooks/pre-commit

# Run lint-staged for additional formatting
npx lint-staged
```

## Commit Message Hook

### Conventional Commits Validation

#### .githooks/commit-msg
```bash
#!/bin/bash
# Commit message hook for Prismatic project

commit_regex='^(feat|fix|docs|style|refactor|perf|test|chore|build|ci)(\(.+\))?(!)?: .{1,50}'
merge_regex='^Merge (branch|tag)'
revert_regex='^Revert "'

commit_msg_file=$1
commit_msg=$(cat "$commit_msg_file")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Skip validation for merge commits and reverts
if [[ $commit_msg =~ $merge_regex ]] || [[ $commit_msg =~ $revert_regex ]]; then
    log_info "Skipping validation for merge/revert commit"
    exit 0
fi

# Validate commit message format
if [[ ! $commit_msg =~ $commit_regex ]]; then
    log_error "Invalid commit message format!"
    echo ""
    echo "Commit message must follow Conventional Commits specification:"
    echo ""
    echo "Format: <type>[optional scope]: <description>"
    echo ""
    echo "Examples:"
    echo "  feat: add user authentication"
    echo "  fix(auth): resolve login redirect issue"
    echo "  docs: update API documentation"
    echo "  feat!: redesign user interface (breaking change)"
    echo ""
    echo "Types: feat, fix, docs, style, refactor, perf, test, chore, build, ci"
    echo ""
    echo "Your commit message:"
    echo "  '$commit_msg'"
    echo ""
    exit 1
fi

# Additional validations
commit_length=${#commit_msg}
if [ $commit_length -gt 72 ]; then
    log_error "Commit message too long: $commit_length characters (max: 72)"
    exit 1
fi

# Check for issue references in feature commits
if [[ $commit_msg =~ ^feat ]] && [[ ! $commit_msg =~ \#[0-9]+ ]]; then
    echo -e "${YELLOW}[WARN]${NC} Feature commits should reference an issue (e.g., feat: add feature #123)"
fi

# Check for breaking change indicator consistency
if [[ $commit_msg =~ ^.*!: ]] && [[ ! $commit_msg =~ BREAKING\ CHANGE ]]; then
    echo -e "${YELLOW}[WARN]${NC} Breaking change indicator (!) found but no BREAKING CHANGE footer"
fi

log_info "✅ Commit message format valid"
exit 0
```

### Commit Message Templates

#### .gitmessage Template
```
# <type>[optional scope]: <description>
#
# [optional body]
#
# [optional footer(s)]

# Type must be one of:
# feat:     A new feature
# fix:      A bug fix
# docs:     Documentation only changes
# style:    Changes that do not affect the meaning of the code
# refactor: A code change that neither fixes a bug nor adds a feature
# perf:     A code change that improves performance
# test:     Adding missing tests or correcting existing tests
# chore:    Changes to the build process or auxiliary tools
# build:    Changes that affect the build system or external dependencies
# ci:       Changes to our CI configuration files and scripts

# Example:
# feat: add user authentication
# 
# Implement JWT-based authentication system with login,
# logout, and token refresh functionality.
# 
# Closes #123
```

#### Setup Commit Template
```bash
# Configure Git to use the commit message template
git config commit.template .gitmessage

# Make it global for all repositories (optional)
git config --global commit.template ~/.gitmessage
```

## Pre-Push Hook

### Comprehensive Pre-Push Validation

#### .githooks/pre-push
```bash
#!/bin/bash
# Pre-push hook for Prismatic project

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if pushing to protected branches
protected_branch='main'
current_branch=$(git symbolic-ref HEAD | sed -e 's,.*/\(.*\),\1,')

if [ "$current_branch" = "$protected_branch" ]; then
    log_error "Direct push to $protected_branch is not allowed!"
    log_info "Please create a pull request instead."
    exit 1
fi

log_info "Running pre-push validations..."

# Get the range of commits being pushed
remote=$1
url=$2

z40=0000000000000000000000000000000000000000

while read local_ref local_sha remote_ref remote_sha; do
    if [ "$local_sha" = $z40 ]; then
        # Handle delete - nothing to validate
        continue
    fi
    
    if [ "$remote_sha" = $z40 ]; then
        # New branch, examine all commits
        range="$local_sha"
    else
        # Update to existing branch, examine new commits
        range="$remote_sha..$local_sha"
    fi
    
    # 1. Full test suite
    log_info "Running full test suite..."
    if ! MIX_ENV=test mix test; then
        log_error "Test suite failed"
        exit 1
    fi
    
    # 2. Security audit
    log_info "Running security audit..."
    if command -v mix &> /dev/null; then
        if ! mix deps.audit; then
            log_warn "Dependency vulnerabilities found"
        fi
    fi
    
    # 3. Build verification
    log_info "Verifying build..."
    if ! MIX_ENV=prod mix compile --warnings-as-errors; then
        log_error "Production build failed"
        exit 1
    fi
    
    # 4. Asset compilation
    log_info "Compiling assets..."
    cd assets || exit 1
    if ! npm run build; then
        log_error "Asset compilation failed"
        exit 1
    fi
    cd ..
    
    # 5. Documentation checks
    log_info "Checking documentation..."
    if [ -f "scripts/validate-docs.sh" ]; then
        if ! ./scripts/validate-docs.sh; then
            log_warn "Documentation validation issues found"
        fi
    fi
    
    # 6. Performance regression check
    log_info "Checking for performance regressions..."
    if [ -f "scripts/performance-check.sh" ]; then
        if ! ./scripts/performance-check.sh; then
            log_warn "Performance regression detected"
        fi
    fi
    
    # 7. Check commit signatures (if required)
    if git config --get commit.gpgsign | grep -q true; then
        log_info "Verifying commit signatures..."
        for commit in $(git rev-list $range); do
            if ! git verify-commit $commit 2>/dev/null; then
                log_error "Unsigned commit found: $commit"
                exit 1
            fi
        done
    fi
    
    # 8. Branch naming convention
    if [[ ! $current_branch =~ ^(feature|bugfix|hotfix|release)/.+ ]]; then
        log_warn "Branch name '$current_branch' doesn't follow naming convention"
        log_info "Recommended: feature/description, bugfix/issue-123, hotfix/critical-fix"
    fi
    
done

log_info "✅ All pre-push checks passed!"
exit 0
```

## Server-Side Hooks

### Pre-Receive Hook

#### Server Setup
```bash
#!/bin/bash
# hooks/pre-receive (server-side)

# Read from stdin
while read oldrev newrev refname; do
    # Extract branch name
    branch=$(echo $refname | sed -e 's/.*\///')
    
    # Protect main branch
    if [ "$branch" = "main" ]; then
        # Only allow fast-forward merges
        if [ "$oldrev" != "0000000000000000000000000000000000000000" ]; then
            # Check if it's a fast-forward
            if ! git merge-base --is-ancestor $oldrev $newrev; then
                echo "Error: Non-fast-forward updates to main branch are not allowed"
                exit 1
            fi
        fi
        
        # Require signed commits
        for commit in $(git rev-list $oldrev..$newrev); do
            if ! git verify-commit $commit 2>/dev/null; then
                echo "Error: Unsigned commit $commit not allowed on main branch"
                exit 1
            fi
        done
    fi
    
    # Check for large files
    for commit in $(git rev-list $oldrev..$newrev); do
        git ls-tree -r -l $commit | while read mode type sha size path; do
            if [ "$size" -gt 10485760 ]; then # 10MB
                echo "Error: File $path is too large: $size bytes"
                exit 1
            fi
        done
    done
done

exit 0
```

### Post-Receive Hook

#### Deployment Trigger
```bash
#!/bin/bash
# hooks/post-receive (server-side)

# Configuration
DEPLOY_BRANCH="main"
DEPLOY_DIR="/var/www/prismatic"
LOG_FILE="/var/log/git-deploy.log"

# Read from stdin
while read oldrev newrev refname; do
    branch=$(echo $refname | sed -e 's/.*\///')
    
    # Log deployment
    echo "$(date): Received push to $branch ($oldrev..$newrev)" >> $LOG_FILE
    
    # Deploy on main branch push
    if [ "$branch" = "$DEPLOY_BRANCH" ]; then
        echo "Deploying to production..." >> $LOG_FILE
        
        # Change to deployment directory
        cd $DEPLOY_DIR || exit 1
        
        # Update code
        git fetch origin
        git reset --hard origin/$DEPLOY_BRANCH
        
        # Install dependencies
        mix deps.get --only prod
        cd assets && npm ci --only=production && cd ..
        
        # Compile application
        MIX_ENV=prod mix compile
        MIX_ENV=prod mix assets.deploy
        
        # Run migrations
        MIX_ENV=prod mix ecto.migrate
        
        # Restart services
        sudo systemctl restart prismatic
        
        # Health check
        sleep 10
        if curl -f http://localhost:4000/api/health; then
            echo "$(date): Deployment successful" >> $LOG_FILE
            
            # Send notification
            curl -X POST $SLACK_WEBHOOK_URL \
                -H 'Content-type: application/json' \
                --data "{\"text\":\"🚀 Prismatic deployed successfully to production\"}" \
                || true
        else
            echo "$(date): Deployment failed - health check failed" >> $LOG_FILE
            
            # Rollback
            git reset --hard HEAD~1
            sudo systemctl restart prismatic
            
            # Send alert
            curl -X POST $SLACK_WEBHOOK_URL \
                -H 'Content-type: application/json' \
                --data "{\"text\":\"❌ Prismatic deployment failed - rolled back\"}" \
                || true
        fi
    fi
done

exit 0
```

## Advanced Hook Features

### Performance Optimization

#### Selective Hook Execution
```bash
# .githooks/pre-commit-selective
#!/bin/bash

# Only run expensive checks on CI or when explicitly requested
if [ "$CI" = "true" ] || [ "$FORCE_FULL_CHECKS" = "true" ]; then
    # Run full suite
    ./scripts/full-validation.sh
else
    # Run only fast checks locally
    ./scripts/quick-validation.sh
fi
```

#### Parallel Execution
```bash
# .githooks/pre-commit-parallel
#!/bin/bash

# Run checks in parallel for better performance
{
    echo "Running format checks..." && mix format --check-formatted &
    echo "Running linting..." && mix credo --strict &
    echo "Running security scan..." && mix sobelow &
    wait
} || {
    echo "Some checks failed"
    exit 1
}
```

### Hook Testing

#### Test Framework
```bash
# scripts/test-hooks.sh
#!/bin/bash

# Test pre-commit hook
test_pre_commit() {
    echo "Testing pre-commit hook..."
    
    # Create test commit
    echo "test change" > test_file.txt
    git add test_file.txt
    
    # Run hook
    if .githooks/pre-commit; then
        echo "✅ Pre-commit hook passed"
    else
        echo "❌ Pre-commit hook failed"
        return 1
    fi
    
    # Cleanup
    git reset HEAD test_file.txt
    rm test_file.txt
}

# Test commit message hook
test_commit_msg() {
    echo "Testing commit-msg hook..."
    
    # Test valid message
    echo "feat: add new feature" > /tmp/test_msg
    if .githooks/commit-msg /tmp/test_msg; then
        echo "✅ Valid commit message accepted"
    else
        echo "❌ Valid commit message rejected"
        return 1
    fi
    
    # Test invalid message
    echo "invalid message" > /tmp/test_msg
    if ! .githooks/commit-msg /tmp/test_msg; then
        echo "✅ Invalid commit message rejected"
    else
        echo "❌ Invalid commit message accepted"
        return 1
    fi
    
    rm /tmp/test_msg
}

# Run all tests
test_pre_commit
test_commit_msg

echo "🎉 All hook tests passed!"
```

## IDE Integration

### VSCode Integration

#### .vscode/settings.json
```json
{
  "git.inputValidation": "always",
  "git.inputValidationLength": 72,
  "git.inputValidationSubjectLength": 50,
  "files.associations": {
    ".githooks/*": "shellscript"
  },
  "shellcheck.enable": true,
  "shellformat.enable": true
}
```

#### .vscode/tasks.json
```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Setup Git Hooks",
      "type": "shell",
      "command": "./scripts/setup-git-hooks.sh",
      "group": "build",
      "presentation": {
        "echo": true,
        "reveal": "always"
      }
    },
    {
      "label": "Test Git Hooks",
      "type": "shell",
      "command": "./scripts/test-hooks.sh",
      "group": "test",
      "presentation": {
        "echo": true,
        "reveal": "always"
      }
    }
  ]
}
```

### Git Configuration

#### Global Configuration
```bash
# Configure globally for consistent behavior
git config --global init.templatedir '~/.git-templates'
git config --global commit.template '~/.gitmessage'
git config --global core.hooksPath '~/.git-hooks'

# Enable GPG signing
git config --global commit.gpgsign true
git config --global user.signingkey YOUR_GPG_KEY_ID
```

#### Project-Specific Configuration
```bash
# .gitconfig (project-level)
[core]
    hooksPath = .githooks
[commit]
    template = .gitmessage
    gpgsign = true
[push]
    default = simple
    followTags = true
```

## Troubleshooting

### Common Issues

#### Hook Not Executing
```bash
# Check hook path configuration
git config core.hooksPath

# Verify hook permissions
ls -la .githooks/

# Make hooks executable
chmod +x .githooks/*
```

#### Performance Issues
```bash
# Skip hooks temporarily
git commit --no-verify

# Run specific hook manually
./.githooks/pre-commit

# Check hook execution time
time ./.githooks/pre-commit
```

#### Windows Compatibility
```bash
# Use bash explicitly
#!/usr/bin/env bash

# Handle line endings
git config core.autocrlf input

# Use cross-platform commands
command -v git >/dev/null 2>&1 || { echo "Git not found"; exit 1; }
```

### Debugging Hooks

#### Debug Mode
```bash
# Enable debug output
export GIT_HOOK_DEBUG=1

# Verbose hook execution
set -x  # Add to hook script for tracing
```

#### Logging
```bash
# Add logging to hooks
LOG_FILE="$HOME/.git-hooks.log"
echo "$(date): Hook executed: $0" >> "$LOG_FILE"
```

## Related Documentation

- [Semantic Versioning](semantic-versioning.md) - Automated version management and validation
- [Style Guide](style-guide.md) - Code and documentation standards enforced by hooks
- [CI/CD Configuration](../operations/cicd-configuration.md) - Integration with continuous integration workflows
- [Security Guidelines](security-guidelines.md) - Security checks and validations in hooks
- [Performance Optimization](performance-optimization.md) - Performance testing and regression detection

---

**Well-configured Git hooks ensure consistent code quality, security, and development standards across all team members and environments.**