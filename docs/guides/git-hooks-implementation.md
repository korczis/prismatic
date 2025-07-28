# Git Hooks Implementation Guide

## Overview

This document provides the complete implementation specifications for git hooks enforcing the feature branch workflow with automatic tagging upon merge to main.

## Hook Installation

### Automatic Installation Script

Create `scripts/install-git-hooks.sh`:

```bash
#!/bin/bash
# Git Hooks Installation Script for Prismatic Feature Branch Workflow

set -e

HOOKS_DIR=".git/hooks"
SCRIPTS_DIR="scripts/git-hooks"

echo "🔧 Installing Prismatic git hooks..."

# Ensure hooks directory exists
mkdir -p "$HOOKS_DIR"

# Copy and make executable
for hook in pre-commit pre-push post-merge commit-msg; do
    if [ -f "$SCRIPTS_DIR/$hook" ]; then
        cp "$SCRIPTS_DIR/$hook" "$HOOKS_DIR/$hook"
        chmod +x "$HOOKS_DIR/$hook"
        echo "✅ Installed $hook hook"
    fi
done

echo "🎉 Git hooks installation complete!"
echo "💡 Run 'mix branch.validate' to test your current branch"
```

### Team Distribution

Add to [`mix.exs`](../../mix.exs) aliases:

```elixir
defp aliases do
  [
    setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build", "hooks.install"],
    "hooks.install": ["cmd ./scripts/install-git-hooks.sh"]
  ]
end
```

## Hook Implementations

### 1. Pre-Commit Hook

**Purpose**: Validate branch naming and run quick checks before commit

**File**: `scripts/git-hooks/pre-commit`

```bash
#!/bin/bash
# Pre-commit hook for Prismatic feature branch workflow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get current branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo "🔍 Pre-commit validation for branch: $BRANCH"

# Skip validation for main branch (shouldn't happen, but just in case)
if [ "$BRANCH" = "main" ]; then
    echo -e "${YELLOW}⚠️  Warning: You're committing directly to main branch${NC}"
    echo -e "${YELLOW}   This should only happen during initial setup${NC}"
    exit 0
fi

# Skip validation for master branch during migration period
if [ "$BRANCH" = "master" ]; then
    echo -e "${YELLOW}⚠️  Warning: You're on legacy master branch${NC}"
    echo -e "${YELLOW}   Please migrate to feature branch workflow${NC}"
    exit 0
fi

# Branch naming validation
BRANCH_PATTERN="^(feature|bugfix|hotfix|release|chore|docs)/[a-z0-9-]+$"

if [[ ! $BRANCH =~ $BRANCH_PATTERN ]]; then
    echo -e "${RED}❌ Invalid branch name: $BRANCH${NC}"
    echo -e "${RED}   Branch must follow pattern: type/description${NC}"
    echo -e "${RED}   Valid types: feature, bugfix, hotfix, release, chore, docs${NC}"
    echo -e "${RED}   Example: feature/user-authentication${NC}"
    echo ""
    echo -e "${YELLOW}💡 Create a valid branch with: mix branch.create <type>/<description>${NC}"
    exit 1
fi

# Run quick linting and formatting checks
echo "📝 Running code formatting check..."
if ! mix format --check-formatted; then
    echo -e "${RED}❌ Code formatting issues found${NC}"
    echo -e "${YELLOW}💡 Run 'mix format' to fix formatting${NC}"
    exit 1
fi

# Run quick tests (only if test files exist and not too many changes)
CHANGED_FILES=$(git diff --cached --name-only | wc -l)
if [ "$CHANGED_FILES" -lt 10 ] && [ -d "test" ]; then
    echo "🧪 Running quick test validation..."
    if ! mix test --max-failures=1 --timeout=30000; then
        echo -e "${RED}❌ Tests failed${NC}"
        echo -e "${YELLOW}💡 Fix failing tests before committing${NC}"
        exit 1
    fi
fi

# Check for common issues
echo "🔍 Checking for common issues..."

# Check for debugging statements
if git diff --cached | grep -E "(IO\.puts|IO\.inspect|dbg\(|binding\.pry)" > /dev/null; then
    echo -e "${YELLOW}⚠️  Warning: Debugging statements found in staged changes${NC}"
    echo -e "${YELLOW}   Consider removing before committing${NC}"
fi

# Check for TODO comments
if git diff --cached | grep -E "(TODO|FIXME|HACK)" > /dev/null; then
    echo -e "${YELLOW}⚠️  Warning: TODO/FIXME comments found${NC}"
    echo -e "${YELLOW}   Consider addressing or creating issue tracker items${NC}"
fi

echo -e "${GREEN}✅ Pre-commit validation passed${NC}"
exit 0
```

### 2. Pre-Push Hook

**Purpose**: Prevent direct pushes to main branch and enforce feature branch workflow

**File**: `scripts/git-hooks/pre-push`

```bash
#!/bin/bash
# Pre-push hook for Prismatic feature branch workflow

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Read push details from stdin
while read local_ref local_sha remote_ref remote_sha; do
    # Extract branch name from ref
    if [[ $remote_ref =~ refs/heads/(.+) ]]; then
        BRANCH="${BASH_REMATCH[1]}"
        
        echo "🚀 Pre-push validation for branch: $BRANCH"
        
        # Prevent direct pushes to main
        if [ "$BRANCH" = "main" ]; then
            echo -e "${RED}❌ Direct pushes to main branch are forbidden${NC}"
            echo -e "${RED}   Use feature branch workflow:${NC}"
            echo -e "${RED}   1. Create feature branch: mix branch.create <type>/<description>${NC}"
            echo -e "${RED}   2. Push feature branch: git push origin <branch-name>${NC}"
            echo -e "${RED}   3. Create pull/merge request${NC}"
            echo -e "${RED}   4. Merge via GitHub/GitLab interface${NC}"
            exit 1
        fi
        
        # Warn about pushes to master during migration
        if [ "$BRANCH" = "master" ]; then
            echo -e "${YELLOW}⚠️  Warning: Pushing to legacy master branch${NC}"
            echo -e "${YELLOW}   Please migrate to main branch workflow${NC}"
            echo -e "${YELLOW}   Contact team lead for migration assistance${NC}"
        fi
        
        # Validate feature branch naming
        BRANCH_PATTERN="^(feature|bugfix|hotfix|release|chore|docs)/[a-z0-9-]+$"
        
        if [[ ! $BRANCH =~ $BRANCH_PATTERN ]] && [ "$BRANCH" != "master" ]; then
            echo -e "${RED}❌ Invalid branch name: $BRANCH${NC}"
            echo -e "${RED}   Branch must follow pattern: type/description${NC}"
            echo -e "${RED}   Valid types: feature, bugfix, hotfix, release, chore, docs${NC}"
            exit 1
        fi
        
        # Check if branch has diverged from main
        if [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ]; then
            echo "🔄 Checking if branch is up to date with main..."
            
            # Fetch latest main
            git fetch origin main --quiet
            
            # Check if branch needs rebasing
            MERGE_BASE=$(git merge-base HEAD origin/main)
            MAIN_HEAD=$(git rev-parse origin/main)
            
            if [ "$MERGE_BASE" != "$MAIN_HEAD" ]; then
                echo -e "${YELLOW}⚠️  Warning: Your branch may be behind main${NC}"
                echo -e "${YELLOW}   Consider rebasing: git rebase origin/main${NC}"
            fi
        fi
        
        echo -e "${GREEN}✅ Pre-push validation passed for $BRANCH${NC}"
    fi
done

exit 0
```

### 3. Post-Merge Hook

**Purpose**: Automatic tagging when merging to main branch

**File**: `scripts/git-hooks/post-merge`

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
    if mix help version.bump >/dev/null 2>&1; then
        NEXT_VERSION=$(mix version.bump $VERSION_TYPE --dry-run)
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

**File**: `scripts/git-hooks/commit-msg`

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
PATTERN="^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?: .{1,72}"

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

echo -e "${GREEN}✅ Commit message format is valid${NC}"
exit 0
```

## Hook Testing

### Test Scripts

Create `scripts/test-git-hooks.sh`:

```bash
#!/bin/bash
# Test script for git hooks

set -e

echo "🧪 Testing Git Hooks..."

# Test branch naming validation
echo "📝 Testing branch naming..."
mix branch.create feature/test-branch
git checkout feature/test-branch

# Test commit message validation
echo "📝 Testing commit message validation..."
echo "test file" > test.txt
git add test.txt

# This should pass
git commit -m "feat(test): add test file for hook validation"

# Test pre-push validation
echo "📝 Testing pre-push validation..."
# git push origin feature/test-branch --dry-run

# Cleanup
git checkout main
git branch -D feature/test-branch
git rm test.txt
git commit -m "chore: cleanup test files"

echo "✅ Git hooks testing complete"
```

## Hook Configuration

### Global Git Configuration

Add to team setup documentation:

```bash
# Configure git for better hook experience
git config --global core.hooksPath .git/hooks
git config --global commit.template .gitmessage

# Optional: Configure git aliases for common tasks
git config --global alias.feature '!f() { git checkout -b feature/$1; }; f'
git config --global alias.bugfix '!f() { git checkout -b bugfix/$1; }; f'
git config --global alias.hotfix '!f() { git checkout -b hotfix/$1; }; f'
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

## Troubleshooting

### Common Issues

1. **Hook not executing**
   ```bash
   # Check if hook is executable
   ls -la .git/hooks/
   
   # Make executable if needed
   chmod +x .git/hooks/pre-commit
   ```

2. **Branch validation failing**
   ```bash
   # Check current branch name
   git branch --show-current
   
   # Create properly named branch
   mix branch.create feature/proper-name
   ```

3. **Tag conflicts during auto-tagging**
   ```bash
   # Check existing tags
   git tag -l
   
   # Force update tag if needed (be careful!)
   git tag -d v1.0.0
   git push origin :refs/tags/v1.0.0
   ```

### Bypass Options (Emergency Use Only)

```bash
# Skip pre-commit hook (not recommended)
git commit --no-verify

# Skip pre-push hook (not recommended)
git push --no-verify
```

## Integration Points

### Mix Tasks Integration

Hooks should work seamlessly with custom Mix tasks:
- [`mix branch.create`](mix-tasks-implementation.md#branch-create)
- [`mix branch.validate`](mix-tasks-implementation.md#branch-validate)
- [`mix version.bump`](mix-tasks-implementation.md#version-bump)

### CI/CD Integration

Hooks complement but don't replace CI/CD validation:
- Local hooks provide immediate feedback
- CI/CD provides comprehensive testing
- Both use same validation rules for consistency

### Documentation Integration

Hooks trigger documentation updates:
- Auto-update cross-references on merge
- Validate documentation completeness
- Sync with existing [`docs/_meta/feature-documentation-workflow.md`](../docs/_meta/feature-documentation-workflow.md)

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