# GitHub Actions Implementation Guide

## Overview

This document provides comprehensive specifications for GitHub Actions workflows that enforce the feature branch workflow, provide automated testing, and handle semantic versioning with automatic tagging.

## Workflow Architecture

```mermaid
graph TB
    A[Push/PR Event] --> B{Branch Type?}
    
    B -->|main| C[Main Branch Workflow]
    B -->|feature/*| D[Feature Branch Workflow] 
    B -->|hotfix/*| E[Hotfix Workflow]
    B -->|release/*| F[Release Workflow]
    
    D --> G[Validation & Testing]
    E --> H[Critical Testing]
    F --> I[Release Testing]
    
    G --> J[PR Checks]
    H --> J
    I --> J
    
    J --> K{All Checks Pass?}
    K -->|No| L[Block Merge]
    K -->|Yes| M[Allow Merge]
    
    C --> N[Post-Merge Actions]
    M --> N
    
    N --> O[Automatic Tagging]
    O --> P[Documentation Update]
    P --> Q[Deployment Trigger]
```

## Workflow Files Structure

All workflow files should be created in `.github/workflows/` directory:

```
.github/
└── workflows/
    ├── branch-protection.yml        # Main branch protection
    ├── feature-validation.yml       # Feature branch testing
    ├── release-automation.yml       # Automatic tagging & releases
    ├── documentation-sync.yml       # Doc updates on merge
    ├── security-scan.yml           # Security and dependency checks
    └── deployment.yml              # Deployment automation
```

## Core Workflow Implementations

### 1. Branch Protection Workflow

**File**: `.github/workflows/branch-protection.yml`

```yaml
name: Branch Protection & Validation

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

env:
  MIX_ENV: test
  ELIXIR_VERSION: "1.15.7"
  OTP_VERSION: "26.1.2"

jobs:
  # Prevent direct pushes to main
  prevent-direct-push:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main' && !contains(github.event.head_commit.message, 'Merge pull request')
    runs-on: ubuntu-latest
    steps:
      - name: Block direct push to main
        run: |
          echo "❌ Direct pushes to main branch are not allowed!"
          echo "Use feature branch workflow:"
          echo "1. Create feature branch: git checkout -b feature/description"
          echo "2. Push branch: git push origin feature/description"  
          echo "3. Create pull request"
          echo "4. Merge via GitHub interface"
          exit 1

  # Validate branch naming for PRs
  validate-branch-name:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - name: Check branch naming convention
        run: |
          BRANCH_NAME="${{ github.head_ref }}"
          echo "🔍 Validating branch name: $BRANCH_NAME"
          
          # Branch naming pattern
          PATTERN="^(feature|bugfix|hotfix|release|chore|docs)/[a-z0-9-]+$"
          
          if [[ ! $BRANCH_NAME =~ $PATTERN ]]; then
            echo "❌ Invalid branch name: $BRANCH_NAME"
            echo "Must follow pattern: type/description"
            echo "Valid types: feature, bugfix, hotfix, release, chore, docs"
            echo "Example: feature/user-authentication"
            exit 1
          fi
          
          echo "✅ Branch name is valid"

  # Setup and dependency management
  setup:
    runs-on: ubuntu-latest
    outputs:
      cache-key: ${{ steps.cache-deps.outputs.cache-hit }}
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: ${{ env.ELIXIR_VERSION }}
          otp-version: ${{ env.OTP_VERSION }}
          
      - name: Cache dependencies
        id: cache-deps
        uses: actions/cache@v3
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
          restore-keys: |
            ${{ runner.os }}-mix-
            
      - name: Install dependencies
        if: steps.cache-deps.outputs.cache-hit != 'true'
        run: |
          mix deps.get
          mix deps.compile

  # Code quality checks
  code-quality:
    runs-on: ubuntu-latest
    needs: setup
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: ${{ env.ELIXIR_VERSION }}
          otp-version: ${{ env.OTP_VERSION }}
          
      - name: Restore dependencies
        uses: actions/cache@v3
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
          
      - name: Check formatting
        run: mix format --check-formatted
        
      - name: Check unused dependencies
        run: mix deps.unlock --check-unused
        
      - name: Compile with warnings as errors
        run: mix compile --warnings-as-errors
        
      - name: Run Credo static analysis
        run: mix credo --strict
        continue-on-error: true

  # Test execution
  test:
    runs-on: ubuntu-latest
    needs: setup
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: prismatic_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
          
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: ${{ env.ELIXIR_VERSION }}
          otp-version: ${{ env.OTP_VERSION }}
          
      - name: Restore dependencies
        uses: actions/cache@v3
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
          
      - name: Setup database
        run: |
          mix ecto.create
          mix ecto.migrate
          
      - name: Run tests
        run: mix test --cover --export-coverage default
        
      - name: Generate coverage report
        run: mix test.coverage
        continue-on-error: true
        
      - name: Upload coverage reports
        uses: codecov/codecov-action@v3
        with:
          file: ./cover/excoveralls.json
        continue-on-error: true

  # Security scanning
  security:
    runs-on: ubuntu-latest
    needs: setup
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: ${{ env.ELIXIR_VERSION }}
          otp-version: ${{ env.OTP_VERSION }}
          
      - name: Restore dependencies
        uses: actions/cache@v3
        with:
          path: |
            deps
            _build
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
          
      - name: Check for known security vulnerabilities
        run: mix deps.audit
        continue-on-error: true
        
      - name: Run Sobelow security scan
        run: mix sobelow --config
        continue-on-error: true

  # Documentation validation
  docs-validation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Python for doc validation
        uses: actions/setup-python@v4
        with:
          python-version: '3.x'
          
      - name: Install documentation tools
        run: |
          pip install markdown-link-check
          npm install -g markdown-link-check
          
      - name: Validate documentation links
        run: |
          find docs -name "*.md" -exec markdown-link-check {} \;
        continue-on-error: true
        
      - name: Check documentation completeness
        run: |
          echo "🔍 Checking documentation completeness..."
          # Add custom documentation validation here
          # Could integrate with existing docs/scripts/validate_completeness.sh
```

### 2. Release Automation Workflow

**File**: `.github/workflows/release-automation.yml`

```yaml
name: Release Automation & Tagging

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      version_type:
        description: 'Version bump type'
        required: true
        default: 'patch'
        type: choice
        options:
          - patch
          - minor  
          - major

concurrency:
  group: release-${{ github.ref }}
  cancel-in-progress: false

jobs:
  # Only run on actual merges to main
  detect-merge:
    runs-on: ubuntu-latest
    outputs:
      is-merge: ${{ steps.check.outputs.is-merge }}
      branch-type: ${{ steps.check.outputs.branch-type }}
      version-type: ${{ steps.check.outputs.version-type }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2
          
      - name: Check if this is a merge commit
        id: check
        run: |
          # Check if this is a merge commit
          if git log -1 --pretty=%P | grep -q ' '; then
            echo "is-merge=true" >> $GITHUB_OUTPUT
            
            # Extract branch name from merge commit message
            MERGE_MSG=$(git log -1 --pretty=%B)
            echo "Merge message: $MERGE_MSG"
            
            # Determine branch type and version bump
            if [[ $MERGE_MSG =~ feature/ ]]; then
              echo "branch-type=feature" >> $GITHUB_OUTPUT
              echo "version-type=minor" >> $GITHUB_OUTPUT
            elif [[ $MERGE_MSG =~ hotfix/ ]]; then
              echo "branch-type=hotfix" >> $GITHUB_OUTPUT  
              echo "version-type=patch" >> $GITHUB_OUTPUT
            elif [[ $MERGE_MSG =~ bugfix/ ]]; then
              echo "branch-type=bugfix" >> $GITHUB_OUTPUT
              echo "version-type=patch" >> $GITHUB_OUTPUT
            elif [[ $MERGE_MSG =~ release/ ]]; then
              echo "branch-type=release" >> $GITHUB_OUTPUT
              # Extract version from branch name if possible
              if [[ $MERGE_MSG =~ release/v([0-9]+\.[0-9]+\.[0-9]+) ]]; then
                echo "version-type=specific" >> $GITHUB_OUTPUT
                echo "specific-version=${BASH_REMATCH[1]}" >> $GITHUB_OUTPUT
              else
                echo "version-type=minor" >> $GITHUB_OUTPUT
              fi
            else
              echo "branch-type=other" >> $GITHUB_OUTPUT
              echo "version-type=patch" >> $GITHUB_OUTPUT
            fi
          else
            echo "is-merge=false" >> $GITHUB_OUTPUT
          fi

  # Generate next version
  generate-version:
    needs: detect-merge
    if: needs.detect-merge.outputs.is-merge == 'true' || github.event_name == 'workflow_dispatch'
    runs-on: ubuntu-latest
    outputs:
      current-version: ${{ steps.version.outputs.current }}
      next-version: ${{ steps.version.outputs.next }}
      changelog: ${{ steps.changelog.outputs.changes }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          
      - name: Get current version
        id: version
        run: |
          # Get latest tag
          CURRENT=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
          echo "current=$CURRENT" >> $GITHUB_OUTPUT
          
          # Calculate next version
          VERSION_TYPE="${{ needs.detect-merge.outputs.version-type }}"
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            VERSION_TYPE="${{ github.event.inputs.version_type }}"
          fi
          
          # Remove 'v' prefix for calculation
          CURRENT_NUM=${CURRENT#v}
          IFS='.' read -ra PARTS <<< "$CURRENT_NUM"
          MAJOR=${PARTS[0]:-0}
          MINOR=${PARTS[1]:-0}
          PATCH=${PARTS[2]:-0}
          
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
            specific)
              # Use specific version from release branch
              NEXT="v${{ needs.detect-merge.outputs.specific-version }}"
              echo "next=$NEXT" >> $GITHUB_OUTPUT
              exit 0
              ;;
          esac
          
          NEXT="v$MAJOR.$MINOR.$PATCH"
          echo "next=$NEXT" >> $GITHUB_OUTPUT
          
      - name: Generate changelog
        id: changelog
        run: |
          CURRENT="${{ steps.version.outputs.current }}"
          
          # Generate changelog since last tag
          CHANGES=$(git log ${CURRENT}..HEAD --oneline --pretty=format:"- %s" | head -20)
          
          # Handle multiline output for GitHub Actions
          {
            echo 'changes<<EOF'
            echo "$CHANGES"
            echo EOF
          } >> $GITHUB_OUTPUT

  # Create release
  create-release:
    needs: [detect-merge, generate-version]
    runs-on: ubuntu-latest
    outputs:
      tag-created: ${{ steps.tag.outputs.created }}
    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          fetch-depth: 0
          
      - name: Create and push tag
        id: tag
        run: |
          VERSION="${{ needs.generate-version.outputs.next-version }}"
          
          # Create annotated tag
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          
          TAG_MESSAGE="Release $VERSION

Automated release created by GitHub Actions
Commit: ${{ github.sha }}
Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Branch Type: ${{ needs.detect-merge.outputs.branch-type }}

Recent Changes:
${{ needs.generate-version.outputs.changelog }}
"
          
          git tag -a "$VERSION" -m "$TAG_MESSAGE"
          git push origin "$VERSION"
          
          echo "created=true" >> $GITHUB_OUTPUT
          echo "Created and pushed tag: $VERSION"
          
      - name: Update mix.exs version
        run: |
          VERSION="${{ needs.generate-version.outputs.next-version }}"
          VERSION_NUM=${VERSION#v}
          
          # Update version in mix.exs
          sed -i "s/version: \"[^\"]*\"/version: \"$VERSION_NUM\"/" mix.exs
          
          # Commit version update
          git config user.name "github-actions[bot]"  
          git config user.email "github-actions[bot]@users.noreply.github.com"
          
          if git diff --quiet mix.exs; then
            echo "No version update needed"
          else
            git add mix.exs
            git commit -m "chore: bump version to $VERSION_NUM [skip ci]"
            git push origin main
            echo "Version updated in mix.exs"
          fi
          
      - name: Create GitHub Release
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: ${{ needs.generate-version.outputs.next-version }}
          release_name: Release ${{ needs.generate-version.outputs.next-version }}
          body: |
            ## Changes in this Release
            
            **Version**: ${{ needs.generate-version.outputs.next-version }}
            **Previous Version**: ${{ needs.generate-version.outputs.current-version }}
            **Branch Type**: ${{ needs.detect-merge.outputs.branch-type }}
            
            ### Recent Changes
            ${{ needs.generate-version.outputs.changelog }}
            
            ### Installation
            ```bash
            # Update your dependency in mix.exs
            {:prismatic, "~> ${{ needs.generate-version.outputs.next-version }}"}
            ```
            
            ---
            *This release was automatically generated by GitHub Actions*
          draft: false
          prerelease: false

  # Notify team channels
  notify:
    needs: [create-release, generate-version]
    if: needs.create-release.outputs.tag-created == 'true'
    runs-on: ubuntu-latest
    steps:
      - name: Notify Slack
        if: env.SLACK_WEBHOOK_URL != ''
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
        run: |
          curl -X POST -H 'Content-type: application/json' \
            --data '{"text":"🚀 New release: ${{ needs.generate-version.outputs.next-version }} is now available!\n\nChanges:\n${{ needs.generate-version.outputs.changelog }}"}' \
            $SLACK_WEBHOOK_URL
            
      - name: Notify Teams  
        if: env.TEAMS_WEBHOOK_URL != ''
        env:
          TEAMS_WEBHOOK_URL: ${{ secrets.TEAMS_WEBHOOK_URL }}
        run: |
          curl -H "Content-Type: application/json" -d '{
            "@type": "MessageCard",
            "@context": "http://schema.org/extensions",
            "summary": "New Release Available",
            "themeColor": "0076D7",
            "sections": [{
              "activityTitle": "🚀 New Release: ${{ needs.generate-version.outputs.next-version }}",
              "activitySubtitle": "Prismatic",
              "facts": [{
                "name": "Version",
                "value": "${{ needs.generate-version.outputs.next-version }}"
              }, {
                "name": "Previous",
                "value": "${{ needs.generate-version.outputs.current-version }}"
              }],
              "text": "Recent changes:\n${{ needs.generate-version.outputs.changelog }}"
            }]
          }' $TEAMS_WEBHOOK_URL
```

### 3. Documentation Synchronization Workflow

**File**: `.github/workflows/documentation-sync.yml`

```yaml
name: Documentation Synchronization

on:
  push:
    branches: [main]
    paths: ['docs/**', 'lib/**', 'apps/**']
  pull_request:
    branches: [main]
    paths: ['docs/**', 'lib/**', 'apps/**']

jobs:
  validate-docs:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.x'
          
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          
      - name: Install documentation tools
        run: |
          pip install markdown-link-check
          npm install -g markdown-link-check
          npm install -g markdownlint-cli2
          
      - name: Validate markdown syntax
        run: markdownlint-cli2 "docs/**/*.md"
        continue-on-error: true
        
      - name: Check documentation links
        run: |
          find docs -name "*.md" -exec markdown-link-check {} \;
        continue-on-error: true
        
      - name: Validate cross-references
        run: |
          echo "🔍 Validating documentation cross-references..."
          # Custom script to validate internal links
          # Could integrate with existing validation scripts
          
      - name: Check glossary compliance
        if: contains(github.event.head_commit.modified, 'docs/reference/glossary.md')
        run: |
          echo "📚 Validating glossary formatting..."
          python -c "
import re
import sys

def validate_glossary():
    with open('docs/reference/glossary.md', 'r') as f:
        content = f.read()
    
    # Extract terms from ### headings
    terms = re.findall(r'^### (.+)$', content, re.MULTILINE)
    sorted_terms = sorted(terms, key=str.lower)
    
    if terms != sorted_terms:
        print('ERROR: Glossary terms not in alphabetical order')
        return False
        
    print('✅ Glossary validation passed')
    return True

if not validate_glossary():
    sys.exit(1)
"

  sync-documentation:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    needs: validate-docs
    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          
      - name: Setup Elixir for docs generation
        uses: erlef/setup-beam@v1
        with:
          elixir-version: "1.15.7"
          otp-version: "26.1.2"
          
      - name: Install dependencies
        run: |
          mix deps.get
          mix deps.compile
          
      - name: Generate API documentation
        run: |
          mix docs
          echo "📚 API documentation generated"
          
      - name: Update cross-references
        run: |
          echo "🔗 Updating documentation cross-references..."
          # Custom script to update internal references
          # Could integrate with existing cross-reference tools
          
      - name: Commit documentation updates
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          
          if git diff --quiet; then
            echo "No documentation updates needed"
          else
            git add .
            git commit -m "docs: automatic documentation sync [skip ci]"
            git push origin main
            echo "✅ Documentation updates committed"
          fi
```

## Branch Protection Configuration

### Repository Settings

Configure the following branch protection rules via GitHub repository settings:

```json
{
  "branch": "main",
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
      "require_code_owner_reviews": true
    },
    "restrictions": null,
    "allow_force_pushes": false,
    "allow_deletions": false
  }
}
```

### Required Secrets

Configure the following secrets in GitHub repository settings:

| Secret Name | Description | Required |
|-------------|-------------|----------|
| `GITHUB_TOKEN` | Auto-provided by GitHub | ✅ |
| `SLACK_WEBHOOK_URL` | Slack notifications (optional) | ⚪ |
| `TEAMS_WEBHOOK_URL` | Microsoft Teams notifications (optional) | ⚪ |
| `CODECOV_TOKEN` | Code coverage reporting (optional) | ⚪ |

## Environment Variables

Set these environment variables in workflow files or repository settings:

```yaml
env:
  MIX_ENV: test
  ELIXIR_VERSION: "1.15.7"
  OTP_VERSION: "26.1.2"
  DATABASE_URL: "postgresql://postgres:postgres@localhost/prismatic_test"
```

## Integration with Existing Systems

### Phoenix Umbrella Structure

Workflows are designed to work with the umbrella project structure:

```yaml
# Handle umbrella-specific testing
- name: Test all applications
  run: |
    cd apps/prismatic && mix test
    cd apps/prismatic_web && mix test
```

### Documentation System Integration

Workflows integrate with the existing documentation system:

- Validates against [`docs/_meta/feature-documentation-workflow.md`](../docs/_meta/feature-documentation-workflow.md)
- Syncs with documentation cross-references
- Maintains glossary formatting standards

### Mix Tasks Integration

GitHub Actions can trigger custom Mix tasks:

```yaml
- name: Run custom branch validation
  run: mix branch.validate

- name: Bump version  
  run: mix version.bump ${{ env.VERSION_TYPE }}
```

## Monitoring and Maintenance

### Workflow Monitoring

- Monitor workflow success rates in GitHub Actions tab
- Set up alerts for failing workflows
- Regular review of workflow performance metrics

### Regular Updates

- Update Elixir/OTP versions quarterly
- Review and update dependency versions
- Monitor for security vulnerabilities in actions

### Team Training

- Document workflow behavior for team onboarding
- Provide troubleshooting guides for common issues
- Regular training on new workflow features

## Troubleshooting

### Common Issues

1. **Workflow not triggering**
   - Check branch protection rules
   - Verify workflow file syntax
   - Check repository permissions

2. **Tests failing in CI but passing locally**
   - Verify environment variables
   - Check database setup
   - Review dependency versions

3. **Automatic tagging not working**
   - Check merge commit detection logic
   - Verify GitHub token permissions
   - Review tag creation process

### Debug Commands

```yaml
# Add to workflow for debugging
- name: Debug workflow
  run: |
    echo "Event: ${{ github.event_name }}"
    echo "Ref: ${{ github.ref }}"
    echo "Branch: ${{ github.head_ref }}"
    echo "Commit: ${{ github.sha }}"
    git log -1 --pretty=format:"%H %s"
```

## Performance Optimization

### Caching Strategy

- Cache Mix dependencies between runs
- Cache compiled code artifacts
- Use matrix builds for parallel testing

### Workflow Efficiency

- Use `concurrency` groups to prevent duplicate runs
- Skip unnecessary steps with conditionals
- Optimize Docker layer caching

This comprehensive GitHub Actions implementation provides robust branch protection, automated testing, semantic versioning, and seamless integration with the existing Phoenix umbrella project structure.