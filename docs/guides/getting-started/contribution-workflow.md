<!-- NAV_START -->
<div align="center">
  <strong>🔄 Contribution Workflow Guide</strong><br>
  <em>Complete workflow from finding issues to successful merge</em><br><br>
  
  <a href="../../README.md">🏠 Home</a> | 
  <a href="../README.md">📖 All Guides</a> | 
  <a href="README.md">🚀 Getting Started</a><br>
  
  <strong>Quick Links:</strong>
  <a href="new-contributor-quickstart.md">Quick Start</a> |
  <a href="first-time-setup.md">First-Time Setup</a> |
  <a href="project-orientation.md">Project Orientation</a>
</div>

### Related Documentation
- [New Contributor Quick-Start](new-contributor-quickstart.md) - 5-minute setup for immediate productivity
- [First-Time Setup Guide](first-time-setup.md) - Comprehensive environment setup
- [Project Orientation Guide](project-orientation.md) - Understanding the codebase
- [Feature Branch Workflow](../workflow/feature-branch-workflow.md) - Advanced workflow details
<!-- NAV_END -->

# Contribution Workflow Guide

> **📋 From Issue to Merge**  
> This guide walks you through the complete contribution process, from finding your first issue to getting your code merged into the main branch.

## Table of Contents

- [Finding Good Issues](#finding-good-issues)
- [Branch Naming & Git Workflow](#branch-naming--git-workflow)
- [Development Process](#development-process)
- [Code Review Process](#code-review-process)
- [Testing Requirements](#testing-requirements)
- [Merge and Deployment](#merge-and-deployment)
- [Common Scenarios](#common-scenarios)
- [Quality Checklist](#quality-checklist)

## Finding Good Issues

### For New Contributors

**🎯 Start Here:**
```bash
# Find beginner-friendly issues
gh issue list --label "good first issue" --state open

# Or browse on GitHub
# https://github.com/korczis/prismatic/labels/good%20first%20issue
```

**Issue Types for Beginners:**

| Label | Difficulty | Time | Examples |
|-------|------------|------|----------|
| `good first issue` | ⭐ Easy | 1-4 hours | Documentation fixes, simple bug fixes |
| `documentation` | ⭐ Easy | 1-2 hours | Typo fixes, example updates |
| `enhancement` | ⭐⭐ Medium | 4-8 hours | Small feature additions |
| `bug` | ⭐⭐ Medium | 2-6 hours | Bug fixes with clear reproduction |
| `refactor` | ⭐⭐⭐ Hard | 1-3 days | Code structure improvements |

### Understanding Issue Context

**Before Starting Work:**

1. **Read the Issue Thoroughly**
   - Understand the problem or feature request
   - Check if there are acceptance criteria
   - Look for linked PRs or related issues

2. **Check Current Status**
   ```bash
   # See if anyone is already working on it
   gh issue view 123  # Replace with issue number
   
   # Check for existing branches
   git branch -r | grep -i "issue-123\|feature-name"
   ```

3. **Ask Questions Early**
   - Comment on the issue if anything is unclear
   - Tag maintainers with `@username` for clarification
   - Better to ask now than to rework later

### Claiming an Issue

```bash
# Comment on the issue to claim it
gh issue comment 123 --body "I'd like to work on this issue. ETA: 2-3 days."

# Or assign yourself (if you have permissions)
gh issue edit 123 --add-assignee @me
```

**💡 Etiquette:**
- Only claim issues you can realistically complete
- Give an estimated timeline
- Update if your timeline changes
- Let others know if you need to step away

## Branch Naming & Git Workflow

### Branch Naming Conventions

**Format:** `<type>/<short-description>`

```bash
# Bug fixes
fix/database-connection-timeout
fix/todo-scanner-null-pointer

# New features  
feat/user-authentication
feat/export-todo-csv

# Documentation
docs/api-examples-update
docs/contributing-guide-typos

# Refactoring
refactor/extract-todo-parser
refactor/simplify-beam-introspection

# Performance improvements
perf/optimize-database-queries
perf/reduce-memory-usage-scanner

# Tests
test/add-integration-tests-todo
test/improve-coverage-beam-module

# Build/CI improvements
chore/update-dependencies
chore/improve-ci-performance
```

### Git Workflow Step-by-Step

#### 1. Setup and Branch Creation

```bash
# 1. Start from clean main branch
git checkout main
git pull origin main

# 2. Create and switch to feature branch
git checkout -b feat/your-feature-name

# 3. Verify you're on the right branch
git branch  # Should show * feat/your-feature-name
```

#### 2. Development Cycle

```bash
# Make your changes...
# Then stage and commit

# Stage specific files (recommended)
git add path/to/changed/file.ex
git add test/path/to/test_file.exs

# Or stage all changes (be careful)
git add .

# Commit with conventional format
git commit -m "feat: add user authentication system

- Implement login/logout functionality
- Add password hashing with Argon2
- Create user session management
- Add comprehensive tests

Resolves #123"
```

#### 3. Keeping Your Branch Updated

```bash
# Regularly sync with main (daily for long-running branches)
git checkout main
git pull origin main
git checkout feat/your-feature-name
git rebase main  # Or git merge main if you prefer

# Resolve any conflicts that arise
# Test thoroughly after rebasing
mix test
```

#### 4. Push and Create Pull Request

```bash
# Push your branch
git push origin feat/your-feature-name

# Create pull request via GitHub CLI
gh pr create --title "feat: add user authentication system" \
             --body "Resolves #123\n\nThis PR implements..."

# Or create via GitHub web interface
```

### Commit Message Guidelines

**Format:** 
```
<type>(<scope>): <description>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style (formatting, semicolons, etc.)
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Build process or auxiliary tool changes

**Examples:**
```bash
# Simple fix
git commit -m "fix: resolve database connection timeout issue"

# Feature with details
git commit -m "feat(todo): add CSV export functionality

Implement CSV export for TODO items with:
- Filter by status, priority, and date range
- Configurable column selection
- Progress indicator for large exports
- Input validation and error handling

Closes #456"

# Documentation update
git commit -m "docs: update API examples in README

Fix outdated function calls and add missing parameters.
Improve code formatting for better readability."
```

## Development Process

### 1. Planning Phase (5-10 minutes)

**Before Writing Code:**
- [ ] Understand the requirements completely
- [ ] Identify the files you'll need to modify
- [ ] Plan your approach and architecture
- [ ] Consider edge cases and error handling
- [ ] Think about testing strategy

**Quick Planning Example:**
```bash
# For issue: "Add TODO priority sorting"

# Files to modify:
# - lib/prismatic/todo/scanner.ex (add priority field)
# - lib/prismatic/todo/sorter.ex (new sorting logic)
# - test/prismatic/todo/sorter_test.exs (comprehensive tests)
# - docs/api/todo.md (update documentation)

# Architecture decisions:
# - Use atoms for priority levels: :low, :medium, :high, :urgent
# - Default sorting: urgent > high > medium > low
# - Maintain backward compatibility
```

### 2. Implementation Phase

#### Code Quality Standards

```elixir
# ✅ Good: Clear, documented, tested
defmodule Prismatic.TODO.Sorter do
  @moduledoc """
  Provides sorting functionality for TODO items.
  
  Supports sorting by priority, date, status, and custom criteria.
  """
  
  @doc """
  Sorts TODOs by priority level.
  
  ## Examples
  
      iex> todos = [%{priority: :low}, %{priority: :high}]
      iex> Sorter.sort_by_priority(todos)
      [%{priority: :high}, %{priority: :low}]
  """
  @spec sort_by_priority([map()]) :: [map()]
  def sort_by_priority(todos) when is_list(todos) do
    Enum.sort_by(todos, &priority_weight/1, :desc)
  end
  
  defp priority_weight(%{priority: :urgent}), do: 4
  defp priority_weight(%{priority: :high}), do: 3
  defp priority_weight(%{priority: :medium}), do: 2
  defp priority_weight(%{priority: :low}), do: 1
  defp priority_weight(_), do: 0
end
```

#### Testing as You Go

```bash
# Run tests frequently during development
mix test test/prismatic/todo/sorter_test.exs

# Run related tests
mix test --stale  # Only tests affected by changes

# Watch mode for continuous testing
mix test.watch test/prismatic/todo/
```

### 3. Pre-Commit Quality Checks

**Always Run Before Committing:**

```bash
# 1. Format code
mix format

# 2. Run tests
mix test

# 3. Code quality analysis
mix credo --strict

# 4. Type checking (if you have time)
mix dialyzer

# 5. Compile with warnings as errors
mix compile --warnings-as-errors
```

**Automated Pre-commit Hooks:**
```bash
# Install pre-commit hooks (one-time setup)
cp .git-hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

# Now these checks run automatically on commit
```

## Code Review Process

### Creating a Good Pull Request

**PR Title Format:**
```
<type>(<scope>): <clear description>

# Examples:
feat(todo): add priority-based sorting
fix(beam): resolve memory leak in process introspection
docs(api): update TODO scanning examples
```

**PR Description Template:**
```markdown
## Summary
Brief description of what this PR does.

## Changes
- List of specific changes made
- New features or bug fixes
- Any breaking changes

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests passing
- [ ] Manual testing completed

## Documentation
- [ ] Code comments added where needed
- [ ] API documentation updated
- [ ] README updated if necessary

## Related Issues
Resolves #123
Related to #456

## Screenshots (if applicable)
<!-- Include before/after screenshots for UI changes -->

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Tests pass locally
- [ ] Documentation updated
```

### Review Process Timeline

**Expected Timeline:**
- **Initial Review:** 1-2 business days
- **Follow-up Reviews:** 12-24 hours
- **Emergency Fixes:** Same day

**Review Stages:**

1. **Automated Checks** (Immediate)
   - CI/CD pipeline runs
   - Automated tests
   - Code quality checks
   - Security scans

2. **Maintainer Review** (1-2 days)
   - Code quality and architecture
   - Test coverage and quality
   - Documentation completeness
   - Performance considerations

3. **Final Approval** (Same day after changes)
   - Final review of requested changes
   - Merge approval
   - Automatic deployment (if applicable)

### Responding to Review Feedback

**Good Response Pattern:**

```markdown
# Reviewer Comment:
> "Consider extracting this logic into a separate function for better testability."

# Your Response:
Good point! I've extracted the priority calculation logic into `calculate_priority_score/1` and added dedicated tests for it. 

Commit: abc123f - refactor: extract priority calculation logic

# Code changes made...
```

**When You Disagree:**
```markdown
# Respectful Discussion:
> "This approach might be slower for large datasets."

I understand the concern about performance. I ran benchmarks with 10k+ TODOs and the current approach actually performs better because:

1. It leverages Enum.sort_by/3 which is optimized in the BEAM
2. Single-pass sorting vs multiple comparisons
3. Benchmark results: [attach results]

However, I'm open to alternative approaches if you have suggestions!
```

### Making Review Changes

```bash
# Make requested changes
# ... edit files ...

# Commit changes clearly
git add .
git commit -m "refactor: extract priority calculation as requested

Address review feedback:
- Extract priority_weight logic into separate function
- Add dedicated tests for priority calculation
- Improve function documentation"

# Push updates
git push origin feat/your-feature-name

# Comment on PR about changes
gh pr comment --body "Changes made to address review feedback. PTAL! 🙏"
```

## Testing Requirements

### Test Coverage Standards

**Minimum Requirements:**
- **Unit Tests:** All public functions
- **Integration Tests:** Key workflows
- **Documentation Tests:** All `@doc` examples
- **Coverage:** 80%+ for new code

### Testing Pyramid

```
         /\        
        /  \       
       / UI \      <- Few integration tests
      /______\     
     /        \    
    / Service  \   <- Some service/API tests
   /___________\   
  /             \  
 / Unit Tests    \ <- Many unit tests
/_________________\
```

### Writing Good Tests

**Test Structure:**
```elixir
defmodule Prismatic.TODO.SorterTest do
  use ExUnit.Case, async: true
  doctest Prismatic.TODO.Sorter
  
  alias Prismatic.TODO.Sorter
  
  describe "sort_by_priority/1" do
    test "sorts todos by priority correctly" do
      # Given
      todos = [
        %{title: "Low priority task", priority: :low},
        %{title: "Urgent task", priority: :urgent},
        %{title: "Medium task", priority: :medium}
      ]
      
      # When
      result = Sorter.sort_by_priority(todos)
      
      # Then
      priorities = Enum.map(result, & &1.priority)
      assert priorities == [:urgent, :medium, :low]
    end
    
    test "handles empty list" do
      assert Sorter.sort_by_priority([]) == []
    end
    
    test "handles todos without priority" do
      todos = [%{title: "No priority"}, %{title: "With priority", priority: :high}]
      result = Sorter.sort_by_priority(todos)
      
      # Items with priority should come first
      assert length(result) == 2
      assert List.first(result).priority == :high
    end
  end
end
```

**Property-Based Testing Example:**
```elixir
use ExUnitProperties

property "sorting maintains all elements" do
  check all todos <- list_of(todo_generator()) do
    sorted = Sorter.sort_by_priority(todos)
    assert length(sorted) == length(todos)
    assert Enum.sort(sorted) == Enum.sort(todos)
  end
end
```

### Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/prismatic/todo/sorter_test.exs

# Run specific test
mix test test/prismatic/todo/sorter_test.exs:42

# Run with coverage
mix test --cover

# Run only failed tests
mix test --failed

# Watch mode
mix test.watch
```

## Merge and Deployment

### Pre-Merge Requirements

**All Must Pass:**
- [ ] ✅ All CI checks passing
- [ ] ✅ Code review approved
- [ ] ✅ No merge conflicts
- [ ] ✅ Branch up-to-date with main
- [ ] ✅ Documentation updated
- [ ] ✅ Tests passing with coverage

### Merge Process

**Merge Options:**

1. **Squash and Merge** (Recommended for most PRs)
   - Combines all commits into one
   - Clean main branch history
   - Good for feature branches

2. **Rebase and Merge** (For clean commit history)
   - Preserves individual commits
   - Use when commits are already well-structured
   - Requires clean, atomic commits

3. **Merge Commit** (For release branches)
   - Creates a merge commit
   - Preserves branch context
   - Good for major features

### Post-Merge Actions

```bash
# After your PR is merged:

# 1. Update your local main
git checkout main
git pull origin main

# 2. Delete feature branch
git branch -d feat/your-feature-name
git push origin --delete feat/your-feature-name

# 3. Verify deployment (if applicable)
# Check staging environment
# Monitor for any issues
```

## Common Scenarios

### Scenario 1: Simple Bug Fix

```bash
# 1. Find and claim issue
gh issue view 123
gh issue comment 123 --body "Working on this, ETA: 2 hours"

# 2. Create branch
git checkout -b fix/database-timeout

# 3. Make minimal fix
# Edit only necessary files
# Add test to prevent regression

# 4. Test thoroughly
mix test
mix test --stale

# 5. Commit and push
git commit -m "fix: resolve database connection timeout

Increase connection timeout from 5s to 15s and add retry logic.
Add test to verify timeout handling.

Fixes #123"
git push origin fix/database-timeout

# 6. Create focused PR
gh pr create --title "fix: resolve database connection timeout" \
             --body "Small fix for issue #123. Increases timeout and adds retry logic."
```

### Scenario 2: New Feature Development

```bash
# 1. Plan the feature
# Break down into smaller tasks
# Design API and data structures

# 2. Create branch
git checkout -b feat/csv-export

# 3. Implement incrementally
# Commit small, working pieces
# Push regularly for backup

# 4. Comprehensive testing
# Unit tests for all functions
# Integration tests for workflow
# Performance tests if needed

# 5. Documentation
# Update API docs
# Add usage examples
# Update changelog

# 6. Thorough PR
# Detailed description
# Screenshots if applicable
# Migration notes if needed
```

### Scenario 3: Documentation Improvement

```bash
# 1. Quick fix branch
git checkout -b docs/fix-api-examples

# 2. Make improvements
# Fix typos and outdated examples
# Add missing documentation
# Improve clarity

# 3. Verify examples work
# Test all code examples
# Check all links

# 4. Simple commit
git commit -m "docs: fix API examples and improve clarity

- Update outdated function calls
- Fix broken links
- Add missing parameter descriptions
- Improve code formatting"

# 5. Quick PR
gh pr create --title "docs: fix API examples and improve clarity"
```

## Quality Checklist

### Before Committing

- [ ] **Code Quality**
  - [ ] Code follows project style guidelines
  - [ ] Functions are well-named and focused
  - [ ] Complex logic is commented
  - [ ] No debugging code left behind
  - [ ] No compilation warnings

- [ ] **Testing**
  - [ ] All new functions have tests
  - [ ] Tests cover happy path and edge cases
  - [ ] All tests pass locally
  - [ ] Test coverage meets requirements
  - [ ] Integration tests updated if needed

- [ ] **Documentation**
  - [ ] Public functions have `@doc` with examples
  - [ ] Module has appropriate `@moduledoc`
  - [ ] Examples are tested with `doctest`
  - [ ] API documentation updated
  - [ ] README updated if necessary

### Before Creating PR

- [ ] **Branch Management**
  - [ ] Branch name follows conventions
  - [ ] Branch is up-to-date with main
  - [ ] No merge conflicts
  - [ ] Clean commit history

- [ ] **PR Description**
  - [ ] Clear title following conventions
  - [ ] Detailed description of changes
  - [ ] Links to related issues
  - [ ] Screenshots for UI changes
  - [ ] Breaking changes noted

### Before Requesting Review

- [ ] **Final Checks**
  - [ ] Self-review completed
  - [ ] All CI checks passing
  - [ ] No obvious improvements needed
  - [ ] Ready for production deployment

---

**🎉 Congratulations!** You now understand the complete contribution workflow. Each contribution you make will help you learn more about the codebase and improve your skills.

**📈 Continuous Improvement:**
- Learn from code review feedback
- Study merged PRs from other contributors
- Participate in project discussions
- Help review others' contributions

**🤝 Community:**
- Be patient with the review process
- Help other new contributors
- Suggest process improvements
- Celebrate successful merges!

**Next Steps:**
- Make your first contribution using this workflow
- Read [Project Orientation Guide](project-orientation.md) to understand the codebase better
- Study [Development Guide](../development/README.md) for deeper technical practices