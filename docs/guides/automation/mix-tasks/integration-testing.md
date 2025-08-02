<!-- NAV_START -->
<div align="center">
  <strong>🧪 Integration Testing & CI/CD</strong><br>
  <em>Testing Mix tasks, CI/CD integration, and error recovery</em><br><br>
  
  <a href="../../../README.md">🏠 Home</a> | 
  <a href="../../README.md">📖 All Guides</a> | 
  <a href="../README.md">🤖 Automation</a> | 
  <a href="README.md">⚙️ Mix Tasks</a><br>
  
  <strong>📖 Reading time:</strong> 8 min | 
  <strong>🔧 Implementation time:</strong> 15 min | 
  <strong>📊 Skill level:</strong> Advanced<br><br>
  
  <strong>Quick Links:</strong>
  <a href="#testing-mix-tasks">Testing</a> |
  <a href="#ci-cd-integration">CI/CD</a> |
  <a href="#error-handling">Error Handling</a> |
  <a href="#performance-optimization">Performance</a>
</div>
<!-- NAV_END -->

# Integration Testing & CI/CD

## Overview

This guide covers comprehensive testing strategies for Mix tasks, CI/CD pipeline integration, error handling and recovery procedures, and performance optimization techniques for the Prismatic project's automation tooling.

## Table of Contents

- [Testing Mix Tasks](#testing-mix-tasks)
  - [Unit Tests](#unit-tests)
  - [Integration Tests](#integration-tests)
  - [Test Environment Setup](#test-environment-setup)
- [CI/CD Integration](#ci-cd-integration)
  - [GitHub Actions](#github-actions)
  - [Pipeline Configuration](#pipeline-configuration)
  - [Automated Testing](#automated-testing)
- [Error Handling & Recovery](#error-handling--recovery)
  - [Common Scenarios](#common-scenarios)
  - [Recovery Procedures](#recovery-procedures)
  - [Automated Recovery](#automated-recovery)
- [Performance Optimization](#performance-optimization)
- [Best Practices](#best-practices)

## Testing Mix Tasks

### Unit Tests

Create comprehensive unit tests for all Mix task functionality:

**File Structure:**
```
test/mix/tasks/
├── branch/
│   ├── create_test.exs
│   └── validate_test.exs
├── version/
│   └── bump_test.exs
└── workflow/
    └── status_test.exs
```

**Branch Creation Tests:**

```elixir
defmodule Mix.Tasks.Branch.CreateTest do
  use ExUnit.Case
  import Mix.Tasks.Branch.Create
  
  test "validates branch names correctly" do
    assert validate_branch_name("feature/user-auth") == :ok
    assert validate_branch_name("bugfix/login-fix") == :ok
    assert validate_branch_name("hotfix/security-patch") == :ok
    
    assert {:error, _} = validate_branch_name("invalid-name")
    assert {:error, _} = validate_branch_name("feature/")
    assert {:error, _} = validate_branch_name("ab")
  end
  
  test "extracts branch type correctly" do
    assert extract_branch_type("feature/user-auth") == "feature"
    assert extract_branch_type("bugfix/login-issue") == "bugfix"
    assert extract_branch_type("invalid-name") == nil
  end
  
  test "validates branch name length" do
    long_name = "feature/" <> String.duplicate("a", 50)
    assert {:error, _} = validate_branch_name(long_name)
    
    short_name = "ab"
    assert {:error, _} = validate_branch_name(short_name)
  end
  
  test "rejects invalid characters" do
    assert {:error, _} = validate_branch_name("feature/user_auth")
    assert {:error, _} = validate_branch_name("feature/user auth")
    assert {:error, _} = validate_branch_name("feature/user.auth")
  end
end
```

**Version Bump Tests:**

```elixir
defmodule Mix.Tasks.Version.BumpTest do
  use ExUnit.Case
  import Mix.Tasks.Version.Bump
  
  test "calculates next version correctly" do
    assert calculate_next_version("1.0.0", "patch") == "1.0.1"
    assert calculate_next_version("1.0.0", "minor") == "1.1.0"
    assert calculate_next_version("1.0.0", "major") == "2.0.0"
  end
  
  test "validates version format" do
    assert validate_version_format("1.2.3") == "1.2.3"
    assert validate_version_format("1.2.3-alpha.1") == "1.2.3-alpha.1"
    assert validate_version_format("1.2.3+build.1") == "1.2.3+build.1"
    
    assert_raise RuntimeError, fn ->
      validate_version_format("invalid-version")
    end
  end
  
  test "handles prerelease versions" do
    assert calculate_next_version("1.0.0-beta.1", "patch") == "1.0.1-beta.1"
    assert calculate_next_version("1.0.0-beta.1", "major") == "2.0.0"
  end
end
```

**Workflow Status Tests:**

```elixir
defmodule Mix.Tasks.Workflow.StatusTest do
  use ExUnit.Case
  import Mix.Tasks.Workflow.Status
  
  test "extracts branch type correctly" do
    assert extract_branch_type("feature/user-auth") == "feature"
    assert extract_branch_type("bugfix/login-issue") == "bugfix"
    assert extract_branch_type("main") == "unknown"
  end
  
  test "validates branch names" do
    assert validate_branch_name("feature/user-auth") == true
    assert validate_branch_name("main") == true
    assert validate_branch_name("invalid-name") == false
  end
  
  test "validates commit messages" do
    assert validate_commit_message("feat: add user authentication") == true
    assert validate_commit_message("fix: resolve login issue") == true
    assert validate_commit_message("Merge pull request #123") == true
    assert validate_commit_message("update readme") == false
  end
end
```

### Integration Tests

Test tasks with real git repositories and system interactions:

```elixir
defmodule Mix.Tasks.IntegrationTest do
  use ExUnit.Case
  
  @tmp_dir System.tmp_dir!()
  
  setup do
    # Create temporary git repository for testing
    git_dir = Path.join(@tmp_dir, "test-repo-#{:rand.uniform(10000)}")
    
    File.mkdir_p!(git_dir)
    File.cd!(git_dir)
    
    # Initialize git repository
    System.cmd("git", ["init"])
    System.cmd("git", ["config", "user.name", "Test User"])
    System.cmd("git", ["config", "user.email", "test@example.com"])
    
    # Create initial commit
    File.write!("README.md", "# Test Project")
    System.cmd("git", ["add", "README.md"])
    System.cmd("git", ["commit", "-m", "Initial commit"])
    
    # Create main branch
    System.cmd("git", ["checkout", "-b", "main"])
    
    on_exit(fn ->
      File.rm_rf!(git_dir)
    end)
    
    {:ok, git_dir: git_dir}
  end
  
  test "creates branch successfully", %{git_dir: _git_dir} do
    # Test branch creation
    Mix.Task.run("branch.create", ["feature/test-feature"])
    
    {branch, 0} = System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"])
    assert String.trim(branch) == "feature/test-feature"
    
    # Verify branch info file was created
    assert File.exists?(".branch-info")
  end
  
  test "validates branch correctly", %{git_dir: _git_dir} do
    # Create a feature branch
    Mix.Task.run("branch.create", ["feature/validation-test"])
    
    # Run validation
    Mix.Task.run("branch.validate", [])
    
    # Should pass validation
    assert true  # Test passes if no errors
  end
  
  test "workflow status reports correctly", %{git_dir: _git_dir} do
    # Create a feature branch
    Mix.Task.run("branch.create", ["feature/status-test"])
    
    # Make some changes
    File.write!("test.txt", "test content")
    System.cmd("git", ["add", "test.txt"])
    System.cmd("git", ["commit", "-m", "feat: add test file"])
    
    # Run status check
    Mix.Task.run("workflow.status", [])
    
    # Should complete without errors
    assert true
  end
  
  test "version bump works correctly", %{git_dir: _git_dir} do
    # Create mix.exs file
    mix_content = """
    defmodule TestProject.MixProject do
      use Mix.Project
      
      def project do
        [
          app: :test_project,
          version: "0.1.0",
          elixir: "~> 1.15"
        ]
      end
    end
    """
    
    File.write!("mix.exs", mix_content)
    System.cmd("git", ["add", "mix.exs"])
    System.cmd("git", ["commit", "-m", "Add mix.exs"])
    
    # Test version bump
    Mix.Task.run("version.bump", ["patch"])
    
    # Verify version was updated
    updated_content = File.read!("mix.exs")
    assert String.contains?(updated_content, ~s(version: "0.1.1"))
  end
end
```

### Test Environment Setup

**Test Helper Configuration:**

```elixir
# test/test_helper.exs
ExUnit.start()

defmodule TestHelpers do
  def with_temp_git_repo(fun) do
    tmp_dir = System.tmp_dir!()
    git_dir = Path.join(tmp_dir, "test-repo-#{:rand.uniform(10000)}")
    
    File.mkdir_p!(git_dir)
    original_dir = File.cwd!()
    File.cd!(git_dir)
    
    try do
      # Setup git repository
      System.cmd("git", ["init"])
      System.cmd("git", ["config", "user.name", "Test User"])
      System.cmd("git", ["config", "user.email", "test@example.com"])
      
      fun.()
    after
      File.cd!(original_dir)
      File.rm_rf!(git_dir)
    end
  end
  
  def create_test_commit(message \\ "test commit") do
    File.write!("test-#{:rand.uniform(1000)}.txt", "test content")
    System.cmd("git", ["add", "."])
    System.cmd("git", ["commit", "-m", message])
  end
end
```

**Data Case for Database Tests:**

```elixir
defmodule Mix.Tasks.DataCase do
  use ExUnit.CaseTemplate
  
  using do
    quote do
      import Mix.Tasks.DataCase
      import TestHelpers
    end
  end
  
  def setup_git_repo do
    TestHelpers.with_temp_git_repo(fn ->
      # Setup basic repository structure
      TestHelpers.create_test_commit("Initial commit")
      System.cmd("git", ["checkout", "-b", "main"])
    end)
  end
end
```

## CI/CD Integration

### GitHub Actions

**Complete Workflow Configuration:**

```yaml
# .github/workflows/mix-tasks.yml
name: Mix Tasks Integration
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test-mix-tasks:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        elixir: ['1.15']
        otp: ['26']
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0  # Fetch full history for git operations
      
      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: ${{ matrix.elixir }}
          otp-version: ${{ matrix.otp }}
      
      - name: Cache dependencies
        uses: actions/cache@v3
        with:
          path: deps
          key: ${{ runner.os }}-mix-${{ hashFiles('**/mix.lock') }}
          restore-keys: ${{ runner.os }}-mix-
      
      - name: Install dependencies
        run: mix deps.get
      
      - name: Run tests
        run: mix test
      
      - name: Test branch validation
        run: mix branch.validate --ci --strict
      
      - name: Test workflow status
        run: mix workflow.status --json > workflow-status.json
      
      - name: Upload workflow status
        uses: actions/upload-artifact@v3
        with:
          name: workflow-status
          path: workflow-status.json

  integration-tests:
    runs-on: ubuntu-latest
    needs: test-mix-tasks
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0
      
      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.15'
          otp-version: '26'
      
      - name: Install dependencies
        run: mix deps.get
      
      - name: Test branch creation
        run: |
          mix branch.create feature/ci-test-$(date +%s) --no-switch
          git branch | grep "feature/ci-test"
      
      - name: Test version bump dry run
        run: mix version.bump patch --dry-run
      
      - name: Test workflow status in CI
        run: mix workflow.status --verbose

  security-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Run security scan
        run: |
          # Scan for secrets in Mix task files
          grep -r "password\|secret\|token" lib/mix/tasks/ || true
          
          # Check for hardcoded credentials
          grep -r "hardcoded" lib/mix/tasks/ || true
```

### Pipeline Configuration

**Multi-Environment Testing:**

```yaml
# .github/workflows/multi-env-test.yml
name: Multi-Environment Testing
on: [push, pull_request]

jobs:
  test-matrix:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest]
        elixir: ['1.14', '1.15']
        otp: ['25', '26']
        exclude:
          - elixir: '1.14'
            otp: '26'
    
    steps:
      - uses: actions/checkout@v3
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: ${{ matrix.elixir }}
          otp-version: ${{ matrix.otp }}
      
      - name: Run Mix Tasks Tests
        run: |
          mix deps.get
          mix test test/mix/tasks/
      
      - name: Test Platform-Specific Features
        run: |
          # Test git operations on different platforms
          mix branch.create feature/platform-test-${{ matrix.os }} --no-switch
          mix workflow.status
```

### Automated Testing

**Scheduled Integration Tests:**

```yaml
# .github/workflows/scheduled-tests.yml
name: Scheduled Integration Tests
on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  workflow_dispatch:

jobs:
  comprehensive-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.15'
          otp-version: '26'
      
      - name: Full Integration Test Suite
        run: |
          mix deps.get
          
          # Test complete workflow
          mix branch.create feature/scheduled-test --push
          echo "test content" > test.txt
          git add test.txt
          git commit -m "feat: add test content"
          mix branch.validate --verbose
          mix workflow.status --verbose
          mix version.bump patch --dry-run
          
          # Cleanup
          git checkout main
          git branch -D feature/scheduled-test
```

## Error Handling & Recovery

### Common Scenarios

**Git Repository Issues:**

```elixir
defmodule Mix.Tasks.Branch.Recover do
  @shortdoc "Recover from common branch workflow issues"
  
  @moduledoc """
  Provides recovery procedures for common Mix task failures.
  
  ## Usage
  
      mix branch.recover merge-conflict
      mix branch.recover invalid-branch
      mix branch.recover sync-issues
  """
  
  use Mix.Task
  
  def run(args) do
    case args do
      ["merge-conflict"] -> resolve_merge_conflict()
      ["invalid-branch"] -> fix_invalid_branch()
      ["sync-issues"] -> fix_sync_issues()
      ["reset-branch"] -> reset_branch_state()
      _ -> show_recovery_options()
    end
  end
  
  defp resolve_merge_conflict do
    Mix.shell().info("🔧 Resolving merge conflicts...")
    
    # Check for merge conflicts
    case System.cmd("git", ["status", "--porcelain"]) do
      {output, 0} ->
        conflicts = output
        |> String.split("\n", trim: true)
        |> Enum.filter(&String.starts_with?(&1, "UU"))
        
        if Enum.empty?(conflicts) do
          Mix.shell().info("✅ No merge conflicts found")
        else
          Mix.shell().info("📝 Conflicted files:")
          Enum.each(conflicts, fn conflict ->
            file = String.slice(conflict, 3..-1)
            Mix.shell().info("  - #{file}")
          end)
          
          Mix.shell().info("""
          
          🔧 Resolution steps:
          1. Edit conflicted files to resolve conflicts
          2. Remove conflict markers (<<<<<<<, =======, >>>>>>>)
          3. Run: git add <resolved-files>
          4. Run: git commit
          5. Run: mix branch.validate
          """)
        end
        
      {_, _} ->
        Mix.shell().error("❌ Not in a git repository")
    end
  end
  
  defp fix_invalid_branch do
    Mix.shell().info("🔧 Fixing invalid branch name...")
    
    case System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"]) do
      {branch_name, 0} ->
        branch_name = String.trim(branch_name)
        
        # Suggest valid branch name
        suggested = suggest_valid_branch_name(branch_name)
        
        Mix.shell().info("Current branch: #{branch_name}")
        Mix.shell().info("Suggested name: #{suggested}")
        
        if Mix.shell().yes?("Rename branch to #{suggested}?") do
          case System.cmd("git", ["branch", "-m", suggested]) do
            {_, 0} ->
              Mix.shell().info("✅ Branch renamed successfully")
              
            {error, _} ->
              Mix.shell().error("❌ Failed to rename branch: #{error}")
          end
        end
        
      {_, _} ->
        Mix.shell().error("❌ Cannot determine current branch")
    end
  end
  
  defp fix_sync_issues do
    Mix.shell().info("🔧 Fixing branch synchronization issues...")
    
    # Fetch latest changes
    Mix.shell().info("📥 Fetching latest changes...")
    System.cmd("git", ["fetch", "origin"])
    
    # Check sync status
    case System.cmd("git", ["rev-list", "--count", "HEAD..origin/main"]) do
      {behind_str, 0} ->
        behind = String.trim(behind_str) |> String.to_integer()
        
        if behind > 0 do
          Mix.shell().info("⚠️  Branch is #{behind} commits behind main")
          
          if Mix.shell().yes?("Rebase onto origin/main?") do
            case System.cmd("git", ["rebase", "origin/main"]) do
              {_, 0} ->
                Mix.shell().info("✅ Rebase completed successfully")
                
              {error, _} ->
                Mix.shell().error("❌ Rebase failed: #{error}")
                Mix.shell().info("💡 Run 'mix branch.recover merge-conflict' to resolve conflicts")
            end
          end
        else
          Mix.shell().info("✅ Branch is up to date with main")
        end
        
      {_, _} ->
        Mix.shell().error("❌ Cannot determine sync status")
    end
  end
  
  defp reset_branch_state do
    Mix.shell().info("🔧 Resetting branch state...")
    
    Mix.shell().info("""
    ⚠️  This will reset your branch to match origin. 
    Any local changes will be lost!
    """)
    
    if Mix.shell().yes?("Continue with reset?") do
      case System.cmd("git", ["reset", "--hard", "origin/HEAD"]) do
        {_, 0} ->
          Mix.shell().info("✅ Branch state reset successfully")
          
        {error, _} ->
          Mix.shell().error("❌ Reset failed: #{error}")
      end
    end
  end
  
  defp suggest_valid_branch_name(current_name) do
    # Clean up the branch name
    cleaned = current_name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9-]/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
    
    # Add feature prefix if not present
    if String.contains?(cleaned, "/") do
      cleaned
    else
      "feature/#{cleaned}"
    end
  end
  
  defp show_recovery_options do
    Mix.shell().info("""
    🔧 Branch Recovery Options:
    
    mix branch.recover merge-conflict   # Resolve merge conflicts
    mix branch.recover invalid-branch   # Fix invalid branch names
    mix branch.recover sync-issues      # Fix synchronization problems
    mix branch.recover reset-branch     # Reset branch to origin state
    
    For more help, see the Mix Tasks documentation.
    """)
  end
end
```

### Recovery Procedures

**Automated Recovery Scripts:**

```bash
#!/bin/bash
# scripts/recover-workflow.sh

set -e

echo "🔧 Workflow Recovery Script"
echo "=========================="

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not in a git repository"
    exit 1
fi

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "📋 Current branch: $CURRENT_BRANCH"

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "⚠️  Uncommitted changes detected"
    echo "💾 Stashing changes..."
    git stash push -m "Auto-stash before recovery"
fi

# Fetch latest changes
echo "📥 Fetching latest changes..."
git fetch origin

# Check branch validity
if mix branch.validate --ci; then
    echo "✅ Branch validation passed"
else
    echo "⚠️  Branch validation failed"
    echo "🔧 Attempting automatic fixes..."
    mix branch.validate --fix
fi

# Check sync status
echo "🔄 Checking sync status..."
if mix workflow.status --json | jq -e '.sync.status == "synced"' > /dev/null; then
    echo "✅ Branch is synced"
else
    echo "⚠️  Branch sync issues detected"
    read -p "Rebase onto origin/main? (y/N): " -n 1 -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git rebase origin/main
    fi
fi

# Restore stashed changes if any
if git stash list | grep -q "Auto-stash before recovery"; then
    echo "💾 Restoring stashed changes..."
    git stash pop
fi

echo "✅ Recovery complete"
```

### Automated Recovery

**Self-Healing Workflows:**

```elixir
defmodule Mix.Tasks.Auto.Heal do
  @shortdoc "Automatically detect and fix common workflow issues"
  
  use Mix.Task
  
  def run(_args) do
    Mix.shell().info("🔧 Auto-healing workflow issues...")
    
    issues = detect_issues()
    
    if Enum.empty?(issues) do
      Mix.shell().info("✅ No issues detected")
    else
      Mix.shell().info("⚠️  Found #{length(issues)} issues:")
      
      Enum.each(issues, fn issue ->
        Mix.shell().info("  • #{issue.description}")
        
        if issue.auto_fixable do
          Mix.shell().info("    🔧 Auto-fixing...")
          apply_fix(issue)
        else
          Mix.shell().info("    💡 Manual action required: #{issue.remedy}")
        end
      end)
    end
  end
  
  defp detect_issues do
    [
      check_git_status(),
      check_branch_name(),
      check_sync_status(),
      check_uncommitted_changes()
    ]
    |> Enum.filter(& &1)
  end
  
  defp check_git_status do
    case System.cmd("git", ["status", "--porcelain"]) do
      {"", 0} -> nil
      {_, 0} -> 
        %{
          type: :uncommitted_changes,
          description: "Uncommitted changes present",
          auto_fixable: false,
          remedy: "Commit or stash changes"
        }
      {_, _} -> 
        %{
          type: :not_git_repo,
          description: "Not in git repository",
          auto_fixable: false,
          remedy: "Run in git repository"
        }
    end
  end
  
  defp apply_fix(issue) do
    case issue.type do
      :format_issues ->
        System.cmd("mix", ["format"])
        Mix.shell().info("    ✅ Code formatted")
        
      :outdated_deps ->
        System.cmd("mix", ["deps.update", "--all"])
        Mix.shell().info("    ✅ Dependencies updated")
        
      _ ->
        Mix.shell().info("    ⚠️  Cannot auto-fix this issue")
    end
  end
end
```

## Performance Optimization

### Caching Strategies

```elixir
defmodule Mix.Tasks.Cache do
  @cache_dir ".mix_tasks_cache"
  @cache_ttl 300  # 5 minutes
  
  def get_cached(key) do
    cache_file = Path.join(@cache_dir, "#{key}.cache")
    
    if File.exists?(cache_file) do
      case File.read(cache_file) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, %{"timestamp" => timestamp, "data" => data}} ->
              if current_timestamp() - timestamp < @cache_ttl do
                {:ok, data}
              else
                :expired
              end
            _ -> :invalid
          end
        _ -> :error
      end
    else
      :not_found
    end
  end
  
  def cache_put(key, data) do
    File.mkdir_p!(@cache_dir)
    cache_file = Path.join(@cache_dir, "#{key}.cache")
    
    cache_data = %{
      timestamp: current_timestamp(),
      data: data
    }
    
    File.write!(cache_file, Jason.encode!(cache_data))
  end
  
  defp current_timestamp do
    System.system_time(:second)
  end
end
```

### Efficient Git Operations

```elixir
defmodule GitUtils do
  def batch_git_info do
    # Get multiple pieces of information in one command
    case System.cmd("git", [
      "log", "--oneline", "-n", "1", 
      "--pretty=format:%H|%s|%an|%ar|%d"
    ]) do
      {output, 0} ->
        case String.split(output, "|", parts: 5) do
          [hash, message, author, date, refs] ->
            %{
              hash: hash,
              message: message,
              author: author,
              date: date,
              refs: String.trim(refs)
            }
          _ -> nil
        end
      _ -> nil
    end
  end
  
  def efficient_status_check do
    # Use git commands that minimize I/O
    case System.cmd("git", [
      "status", "--porcelain", "--untracked-files=no", "--ignored=no"
    ]) do
      {"", 0} -> {:ok, :clean}
      {output, 0} -> {:ok, {:dirty, String.split(output, "\n", trim: true)}}
      {_, _} -> {:error, :not_git_repo}
    end
  end
end
```

## Best Practices

### Test Organization

1. **Separate Unit and Integration Tests**: Keep fast unit tests separate from slower integration tests
2. **Use Test Helpers**: Create reusable test utilities for common operations
3. **Mock External Dependencies**: Mock git operations and file system access in unit tests
4. **Test Error Conditions**: Ensure error paths are tested thoroughly

### CI/CD Best Practices

1. **Fail Fast**: Run quick tests first, expensive tests later
2. **Parallel Execution**: Use matrix builds for different environments
3. **Cache Dependencies**: Cache Mix dependencies and compiled code
4. **Artifact Preservation**: Save test results and status reports

### Error Recovery

1. **Graceful Degradation**: Continue operation when possible, fail safely when not
2. **Clear Error Messages**: Provide actionable error messages with recovery suggestions
3. **Automated Recovery**: Implement self-healing for common issues
4. **Rollback Capabilities**: Provide ways to undo changes when things go wrong

## Next Steps

- **[Branch Management](branch-management.md)**: Learn about branch creation and validation
- **[Version Management](version-management.md)**: Automate semantic versioning
- **[Workflow Status](workflow-status.md)**: Monitor and report workflow status
- **[Mix Tasks Overview](README.md)**: Return to main Mix tasks guide

---

*This guide is part of the [Prismatic Mix Tasks Implementation](README.md). For questions or improvements, please refer to the [contribution guidelines](../../../README.md).*