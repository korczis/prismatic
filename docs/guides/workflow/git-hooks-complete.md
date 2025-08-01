<!-- NAV_START -->
<div align="center">
  <strong>🪝 Complete Git Hooks Guide</strong><br>
  <em>Comprehensive implementation and setup for Git hooks in the Prismatic workflow</em><br><br>
  
  <a href="../../README.md">🏠 Home</a> | 
  <a href="../README.md">📖 All Guides</a> | 
  <a href="README.md">⚡ Workflow</a><br>
  
  <strong>Quick Links:</strong>
  <a href="#overview">Overview</a> |
  <a href="#installation-and-setup">Setup</a> |
  <a href="#hook-implementations">Implementations</a> |
  <a href="#advanced-features">Advanced</a> |
  <a href="#troubleshooting">Troubleshooting</a>
</div>

### Related Documentation
- [Feature Branch Workflow](feature-branch-workflow.md) - Core workflow enforced by hooks
- [CI/CD Implementation](ci-cd-implementation.md) - Integration with continuous integration
- [Development Standards](../development/coding-standards.md) - Code quality standards enforced
- [Security Guidelines](../security/security-guidelines.md) - Security validation in hooks
- [Mix Tasks Implementation](../automation/mix-tasks-implementation.md) - Developer automation tools
<!-- NAV_END -->

# Complete Git Hooks Guide

## Overview

Git hooks are scripts that run automatically at specific points in the Git workflow. This comprehensive guide covers both the setup and complete implementation of client-side and server-side hooks for the Prismatic project, ensuring code quality, security, and consistency across all commits and deployments while enforcing the feature branch workflow with automatic tagging.

### Hook Types and Purposes

#### Client-Side Hooks

**Pre-Commit Hooks**
- Branch naming validation
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
- Prevent direct pushes to main branch
- Full test suite execution
- Build verification
- Security audit checks
- Performance regression tests

**Post-Merge Hooks**
- Automatic tagging when merging to main
- Version management automation
- Deployment triggers

#### Server-Side Hooks

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
Create `scripts/setup-git-hooks.sh`:

```bash
#!/bin/bash
# Git Hooks Installation Script for Prismatic Feature Branch Workflow

set -e

HOOKS_DIR=".githooks"
GIT_HOOKS_DIR=".git/hooks"

echo "🔧 Setting up Git hooks for Prismatic..."

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
echo "💡 Run 'mix branch.validate' to test your current branch"
```

#### Mix.exs Integration
Add to [`mix.exs`](../../mix.exs) aliases:

```elixir
defp aliases do
  [
    setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build", "hooks.install"],
    "hooks.install": ["cmd ./scripts/setup-git-hooks.sh"]
  ]
end
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

## Hook Implementations

### 1. Pre-Commit Hook

**Purpose**: Validate branch naming, run quick checks, and enforce code quality before commit

**File**: `.githooks/pre-commit`

```bash
#!/bin/bash
# Pre-commit hook for Prismatic feature branch workflow

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

# Get current branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD)
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED_FILES" ]; then
    log_info "No staged files found. Skipping pre-commit hooks."
    exit 0
fi

echo "🔍 Pre-commit validation for branch: $BRANCH"

# Skip validation for main branch (shouldn't happen, but just in case)
if [ "$BRANCH" = "main" ]; then
    log_warn "Warning: You're committing directly to main branch"
    log_warn "This should only happen during initial setup"
    exit 0
fi

# Skip validation for master branch during migration period
if [ "$BRANCH" = "master" ]; then
    log_warn "Warning: You're on legacy master branch"
    log_warn "Please migrate to feature branch workflow"
    exit 0
fi

# Branch naming validation
BRANCH_PATTERN="^(feature|bugfix|hotfix|release|chore|docs)/[a-z0-9-]+$"

if [[ ! $BRANCH =~ $BRANCH_PATTERN ]]; then
    log_error "Invalid branch name: $BRANCH"
    log_error "Branch must follow pattern: type/description"
    log_error "Valid types: feature, bugfix, hotfix, release, chore, docs"
    log_error "Example: feature/user-authentication"
    echo ""
    log_warn "💡 Create a valid branch with: mix branch.create <type>/<description>"
    exit 1
fi

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
    if command -v mix credo &> /dev/null; then
        if ! mix credo --strict $ELIXIR_FILES; then
            log_error "Credo issues found"
            CHECKS_FAILED=1
        fi
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

# 6. Run quick tests (only if test files exist and not too many changes)
CHANGED_FILES_COUNT=$(echo "$STAGED_FILES" | wc -l)
if [ "$CHANGED_FILES_COUNT" -lt 10 ] && [ -d "test" ]; then
    log_info "Running quick test validation..."
    
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
        if ! MIX_ENV=test mix test $TEST_FILES --max-failures=1; then
            log_error "Tests failed for modified files"
            CHECKS_FAILED=1
        fi
    else
        log_info "No specific tests found for modified files"
    fi
fi

# 7. Check for common issues
log_info "Checking for common issues..."

# Check for debugging statements
if git diff --cached | grep -E "(IO\.puts|IO\.inspect|dbg\(|binding\.pry)" > /dev/null; then
    log_warn "Warning: Debugging statements found in staged changes"
    log_warn "Consider removing before committing"
fi

# Check for TODO comments
if git diff --cached | grep -E "(TODO|FIXME|HACK)" > /dev/null; then
    log_warn "Warning: TODO/FIXME comments found"
    log_warn "Consider addressing or creating issue tracker items"
fi

# 8. Documentation checks
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

# Summary
if [ $CHECKS_FAILED -eq 0 ]; then
    log_info "✅ All pre-commit checks passed!"
    exit 0
else
    log_error "❌ Pre-commit checks failed. Please fix the issues above."
    exit 1
fi
```

### 2. Pre-Push Hook

**Purpose**: Prevent direct pushes to main branch and enforce comprehensive validation

**File**: `.githooks/pre-push`

```bash
#!/bin/bash
# Pre-push hook for Prismatic feature branch workflow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Read push details from stdin
while read local_ref local_sha remote_ref remote_sha; do
    # Extract branch name from ref
    if [[ $remote_ref =~ refs/heads/(.+) ]]; then
        BRANCH="${BASH_REMATCH[1]}"
        
        echo "🚀 Pre-push validation for branch: $BRANCH"
        
        # Prevent direct pushes to main
        if [ "$BRANCH" = "main" ]; then
            log_error "Direct pushes to main branch are forbidden"
            log_error "Use feature branch workflow:"
            log_error "1. Create feature branch: mix branch.create <type>/<description>"
            log_error "2. Push feature branch: git push origin <branch-name>"
            log_error "3. Create pull/merge request"
            log_error "4. Merge via GitHub/GitLab interface"
            exit 1
        fi
        
        # Warn about pushes to master during migration
        if [ "$BRANCH" = "master" ]; then
            log_warn "Warning: Pushing to legacy master branch"
            log_warn "Please migrate to main branch workflow"
            log_warn "Contact team lead for migration assistance"
        fi
        
        # Validate feature branch naming
        BRANCH_PATTERN="^(feature|bugfix|hotfix|release|chore|docs)/[a-z0-9-]+$"
        
        if [[ ! $BRANCH =~ $BRANCH_PATTERN ]] && [ "$BRANCH" != "master" ]; then
            log_error "Invalid branch name: $BRANCH"
            log_error "Branch must follow pattern: type/description"
            log_error "Valid types: feature, bugfix, hotfix, release, chore, docs"
            exit 1
        fi
        
        # Check if branch has diverged from main
        if [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ]; then
            log_info "Checking if branch is up to date with main..."
            
            # Fetch latest main
            git fetch origin main --quiet
            
            # Check if branch needs rebasing
            MERGE_BASE=$(git merge-base HEAD origin/main)
            MAIN_HEAD=$(git rev-parse origin/main)
            
            if [ "$MERGE_BASE" != "$MAIN_HEAD" ]; then
                log_warn "Warning: Your branch may be behind main"
                log_warn "Consider rebasing: git rebase origin/main"
            fi
        fi
        
        # Get the range of commits being pushed
        z40=0000000000000000000000000000000000000000
        
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
        if [ -d "assets" ]; then
            log_info "Compiling assets..."
            cd assets || exit 1
            if ! npm run build; then
                log_error "Asset compilation failed"
                exit 1
            fi
            cd ..
        fi
        
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
        
        log_info "✅ Pre-push validation passed for $BRANCH"
    fi
done

exit 0
```

### 3. Post-Merge Hook

**Purpose**: Automatic tagging when merging to main branch

**File**: `.githooks/post-merge`

```bash
#!/bin/bash
# Post-merge hook for automatic tagging on main branch

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Only run on main branch
if [ "$CURRENT_BRANCH" != "main" ]; then
    exit 0
fi

echo -e "${BLUE}🏷️  Post-merge: Checking for automatic tagging...${NC}"

# Get the merge commit message to determine source branch
MERGE_MSG=$(git log -1 --pretty=%B)

# Extract branch name from merge message
# Supports both GitHub and GitLab merge message formats
BRANCH_NAME=""
if [[ $MERGE_MSG =~ Merge\ pull\ request.*from.*/(.*) ]]; then
    # GitHub format: "Merge pull request #123 from user/branch-name"
    BRANCH_NAME="${BASH_REMATCH[1]}"
elif [[ $MERGE_MSG =~ Merge\ branch\ \'(.*)\' ]]; then
    # GitLab format: "Merge branch 'branch-name' into 'main'"
    BRANCH_NAME="${BASH_REMATCH[1]}"
elif [[ $MERGE_MSG =~ ^(feature|bugfix|hotfix|release|chore|docs)/.* ]]; then
    # Direct merge with branch name as subject
    BRANCH_NAME=$(echo "$MERGE_MSG" | head -n1)
fi

if [ -z "$BRANCH_NAME" ]; then
    echo -e "${YELLOW}⚠️  Could not determine source branch from merge message${NC}"
    echo -e "${YELLOW}   Manual tagging may be required${NC}"
    exit 0
fi

echo -e "${BLUE}📝 Detected merge from branch: $BRANCH_NAME${NC}"

# Determine version bump type based on branch type
VERSION_TYPE=""
case $BRANCH_NAME in
    feature/*)
        VERSION_TYPE="minor"
        ;;
    bugfix/*)
        VERSION_TYPE="patch"
        ;;
    hotfix/*)
        VERSION_TYPE="patch"
        ;;
    release/*)
        # Extract version from release branch name
        if [[ $BRANCH_NAME =~ release/v([0-9]+\.[0-9]+\.[0-9]+) ]]; then
            SPECIFIC_VERSION="${BASH_REMATCH[1]}"
            VERSION_TYPE="specific"
        else
            VERSION_TYPE="minor"
        fi
        ;;
    chore/*)
        VERSION_TYPE="patch"
        ;;
    docs/*)
        VERSION_TYPE="patch"
        ;;
    *)
        echo -e "${YELLOW}⚠️  Unknown branch type, defaulting to patch version${NC}"
        VERSION_TYPE="patch"
        ;;
esac

# Get current version from git tags
CURRENT_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")

# Remove 'v' prefix for calculation
CURRENT_VERSION_NUM=${CURRENT_VERSION#v}

# Calculate next version
if [ "$VERSION_TYPE" = "specific" ]; then
    NEXT_VERSION="v$SPECIFIC_VERSION"
else
    # Use mix task for version calculation (if available)
    if command -v mix &> /dev/null && mix help version.bump >/dev/null 2>&1; then
        NEXT_VERSION_NUM=$(mix version.bump $VERSION_TYPE --dry-run | grep "New version:" | awk '{print $3}')
        NEXT_VERSION="v$NEXT_VERSION_NUM"
    else
        # Fallback to manual calculation
        IFS='.' read -ra VERSION_PARTS <<< "$CURRENT_VERSION_NUM"
        MAJOR=${VERSION_PARTS[0]:-0}
        MINOR=${VERSION_PARTS[1]:-0}
        PATCH=${VERSION_PARTS[2]:-0}
        
        case $VERSION_TYPE in
            major)
                MAJOR=$((MAJOR + 1))
                MINOR=0
                PATCH=0
                ;;
            minor)
                MINOR=$((MINOR + 1))
                PATCH=0
                ;;
            patch)
                PATCH=$((PATCH + 1))
                ;;
        esac
        
        NEXT_VERSION="v$MAJOR.$MINOR.$PATCH"
    fi
fi

echo -e "${BLUE}🏷️  Creating tag: $NEXT_VERSION${NC}"

# Create annotated tag
TAG_MESSAGE="Release $NEXT_VERSION

Merged from: $BRANCH_NAME
Commit: $(git rev-parse HEAD)
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

Changelog:
$(git log --oneline ${CURRENT_VERSION}..HEAD --pretty=format:"- %s" | head -20)
"

git tag -a "$NEXT_VERSION" -m "$TAG_MESSAGE"

# Push tag to all configured remotes
echo -e "${BLUE}📤 Pushing tag to remotes...${NC}"

for remote in $(git remote); do
    if git push "$remote" "$NEXT_VERSION" 2>/dev/null; then
        echo -e "${GREEN}✅ Pushed $NEXT_VERSION to $remote${NC}"
    else
        echo -e "${YELLOW}⚠️  Failed to push $NEXT_VERSION to $remote${NC}"
    fi
done

echo -e "${GREEN}✅ Automatic tagging complete: $NEXT_VERSION${NC}"

# Update version in mix.exs if possible
if [ -f "mix.exs" ] && command -v sed >/dev/null; then
    echo -e "${BLUE}📝 Updating version in mix.exs...${NC}"
    VERSION_NUM=${NEXT_VERSION#v}
    
    # Backup original file
    cp mix.exs mix.exs.backup
    
    # Update version in mix.exs
    sed -i.tmp "s/version: \"[^\"]*\"/version: \"$VERSION_NUM\"/" mix.exs && rm mix.exs.tmp
    
    # Commit version update
    if git diff --quiet mix.exs; then
        echo -e "${YELLOW}⚠️  No version update needed in mix.exs${NC}"
        rm mix.exs.backup
    else
        git add mix.exs
        git commit -m "chore: bump version to $VERSION_NUM

[skip ci]"
        
        # Push version update
        for remote in $(git remote); do
            git push "$remote" main 2>/dev/null || true
        done
        
        echo -e "${GREEN}✅ Version updated in mix.exs and committed${NC}"
        rm mix.exs.backup
    fi
fi

exit 0
```

### 4. Commit Message Hook

**Purpose**: Enforce conventional commit message format

**File**: `.githooks/commit-msg`

```bash
#!/bin/bash
# Commit message hook for conventional commit format

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Read commit message from file
COMMIT_MSG_FILE=$1
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

echo "📝 Validating commit message format..."

# Skip validation for merge commits
if [[ $COMMIT_MSG =~ ^Merge ]]; then
    echo -e "${GREEN}✅ Merge commit - skipping validation${NC}"
    exit 0
fi

# Skip validation for revert commits
if [[ $COMMIT_MSG =~ ^Revert ]]; then
    echo -e "${GREEN}✅ Revert commit - skipping validation${NC}"
    exit 0
fi

# Conventional commit pattern
# Format: type(scope): description
PATTERN="^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?(!)?: .{1,72}"

if [[ ! $COMMIT_MSG =~ $PATTERN ]]; then
    echo -e "${RED}❌ Invalid commit message format${NC}"
    echo -e "${RED}   Current message:${NC}"
    echo -e "${RED}   $COMMIT_MSG${NC}"
    echo ""
    echo -e "${YELLOW}✅ Valid format: type(scope): description${NC}"
    echo -e "${YELLOW}   Types: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert${NC}"
    echo -e "${YELLOW}   Examples:${NC}"
    echo -e "${YELLOW}   - feat(auth): add user login functionality${NC}"
    echo -e "${YELLOW}   - fix(api): resolve memory leak in user service${NC}"
    echo -e "${YELLOW}   - docs: update installation instructions${NC}"
    echo -e "${YELLOW}   - chore(deps): update elixir dependencies${NC}"
    exit 1
fi

# Check message length
FIRST_LINE=$(echo "$COMMIT_MSG" | head -n1)
if [ ${#FIRST_LINE} -gt 72 ]; then
    echo -e "${YELLOW}⚠️  Warning: Commit message is longer than 72 characters${NC}"
    echo -e "${YELLOW}   Consider shortening for better readability${NC}"
fi

# Check for issue references in feature commits
if [[ $COMMIT_MSG =~ ^feat ]] && [[ ! $COMMIT_MSG =~ \#[0-9]+ ]]; then
    echo -e "${YELLOW}⚠️  Warning: Feature commits should reference an issue (e.g., feat: add feature #123)${NC}"
fi

# Check for breaking change indicator consistency
if [[ $COMMIT_MSG =~ ^.*!: ]] && [[ ! $COMMIT_MSG =~ BREAKING\ CHANGE ]]; then
    echo -e "${YELLOW}⚠️  Warning: Breaking change indicator (!) found but no BREAKING CHANGE footer${NC}"
fi

echo -e "${GREEN}✅ Commit message format is valid${NC}"
exit 0
```

## Lint-Staged Configuration

### package.json Configuration
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

### Husky Configuration
```bash
# .husky/pre-commit
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

# Run custom pre-commit hook
./.githooks/pre-commit

# Run lint-staged for additional formatting
npx lint-staged
```

## Advanced Features

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

## Hook Testing

### Test Framework
```bash
# scripts/test-hooks.sh
#!/bin/bash

set -e

echo "🧪 Testing Git Hooks..."

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

# Test branch naming validation
test_branch_naming() {
    echo "Testing branch naming..."
    
    # Test with mix task if available
    if command -v mix &> /dev/null; then
        mix branch.create feature/test-branch
        git checkout feature/test-branch
        
        # Test pre-commit on feature branch
        echo "test file" > test.txt
        git add test.txt
        
        # This should pass
        if git commit -m "feat(test): add test file for hook validation"; then
            echo "✅ Feature branch commit passed"
        else
            echo "❌ Feature branch commit failed"
            return 1
        fi
        
        # Cleanup
        git checkout main
        git branch -D feature/test-branch
        git reset --hard HEAD~1
    fi
}

# Run all tests
test_pre_commit
test_commit_msg
test_branch_naming

echo "🎉 All hook tests passed!"
```

### Commit Message Template

Create `.gitmessage`:

```
# <type>(<scope>): <subject>
#
# <body>
#
# <footer>

# Types:
# feat: A new feature
# fix: A bug fix
# docs: Documentation only changes
# style: Changes that do not affect the meaning of the code
# refactor: A code change that neither fixes a bug nor adds a feature
# test: Adding missing tests or correcting existing tests
# chore: Changes to the build process or auxiliary tools
# perf: A code change that improves performance
# ci: Changes to our CI configuration files and scripts
# build: Changes that affect the build system or external dependencies
# revert: Reverts a previous commit
```

### Setup Commit Template
```bash
# Configure Git to use the commit message template
git config commit.template .gitmessage

# Make it global for all repositories (optional)
git config --global commit.template ~/.gitmessage
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

### Bypass Options (Emergency Use Only)

```bash
# Skip pre-commit hook (not recommended)
git commit --no-verify

# Skip pre-push hook (not recommended)
git push --no-verify
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

## Integration Points

### Mix Tasks Integration

Hooks should work seamlessly with custom Mix tasks:
- [`mix branch.create`](../automation/mix-tasks-implementation.md#branch-creation-task)
- [`mix branch.validate`](../automation/mix-tasks-implementation.md#branch-validation-task)
- [`mix version.bump`](../automation/mix-tasks-implementation.md#version-management-task)

### CI/CD Integration

Hooks complement but don't replace CI/CD validation:
- Local hooks provide immediate feedback
- CI/CD provides comprehensive testing
- Both use same validation rules for consistency
- See [CI/CD Implementation](ci-cd-implementation.md) for integration details

### Documentation Integration

Hooks trigger documentation updates:
- Auto-update cross-references on merge
- Validate documentation completeness
- Sync with existing documentation workflow

## Maintenance

### Regular Updates

- Review hook performance monthly
- Update validation rules based on team feedback
- Sync with CI/CD pipeline changes
- Test hooks with new Git versions

### Team Training

- Document hook behavior in onboarding
- Provide troubleshooting guide
- Regular workshops on workflow best practices
- Collect feedback for continuous improvement

---

**Well-configured Git hooks ensure consistent code quality, security, and development standards across all team members and environments while enforcing the feature branch workflow with automatic semantic versioning.**