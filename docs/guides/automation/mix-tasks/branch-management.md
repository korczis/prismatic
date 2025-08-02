<!-- NAV_START -->
<div align="center">
  <strong>🌿 Branch Management Mix Tasks</strong><br>
  <em>Automated branch creation, validation, and management</em><br><br>
  
  <a href="../../../README.md">🏠 Home</a> | 
  <a href="../../README.md">📖 All Guides</a> | 
  <a href="../README.md">🤖 Automation</a> | 
  <a href="README.md">⚙️ Mix Tasks</a><br>
  
  <strong>📖 Reading time:</strong> 15 min | 
  <strong>🔧 Implementation time:</strong> 30 min | 
  <strong>📊 Skill level:</strong> Intermediate<br><br>
  
  <strong>Quick Links:</strong>
  <a href="#branch-creation-task">Create</a> |
  <a href="#branch-validation-task">Validate</a> |
  <a href="#usage-examples">Examples</a> |
  <a href="#testing">Testing</a>
</div>
<!-- NAV_END -->

# Branch Management Mix Tasks

## Overview

This guide covers the implementation and usage of Mix tasks for automated branch management in the Prismatic project. These tasks enforce branch naming conventions, validate workflow compliance, and streamline the feature branch workflow.

## Table of Contents

- [Branch Creation Task](#branch-creation-task)
  - [Implementation](#branch-creation-implementation)
  - [Features](#branch-creation-features)
  - [Usage](#branch-creation-usage)
- [Branch Validation Task](#branch-validation-task)
  - [Implementation](#branch-validation-implementation)
  - [Validation Checks](#validation-checks)
  - [Usage](#branch-validation-usage)
- [Usage Examples](#usage-examples)
- [Testing](#testing)
- [Integration](#integration)

## Branch Creation Task

### Branch Creation Implementation

**File**: `lib/mix/tasks/branch/create.ex`

```elixir
defmodule Mix.Tasks.Branch.Create do
  @shortdoc "Create a new feature branch following naming conventions"
  
  @moduledoc """
  Creates a new feature branch with proper naming validation and setup.
  
  ## Usage
  
      mix branch.create feature/user-authentication
      mix branch.create bugfix/login-validation  
      mix branch.create hotfix/security-patch
      mix branch.create docs/api-documentation
  
  ## Branch Types
  
  - `feature/` - New features and enhancements
  - `bugfix/` - Non-critical bug fixes
  - `hotfix/` - Critical production fixes
  - `release/` - Release preparation
  - `chore/` - Maintenance tasks
  - `docs/` - Documentation updates
  
  ## Options
  
      --from BRANCH    Create branch from specific branch (default: main)
      --push           Automatically push new branch to origin
      --no-switch      Don't switch to new branch after creation
      --template TYPE  Use branch template (feature, bugfix, etc.)
  
  ## Examples
  
      # Create and switch to feature branch
      mix branch.create feature/user-dashboard
      
      # Create from specific branch
      mix branch.create --from=release/v2.0.0 hotfix/critical-fix
      
      # Create and push immediately
      mix branch.create --push feature/new-component
      
      # Create but don't switch
      mix branch.create --no-switch docs/readme-update
  """
  
  use Mix.Task
  
  @branch_types ~w(feature bugfix hotfix release chore docs)
  @branch_pattern ~r/^(feature|bugfix|hotfix|release|chore|docs)\/[a-z0-9-]+$/
  
  @switches [
    from: :string,
    push: :boolean,
    no_switch: :boolean,
    template: :string,
    help: :boolean
  ]
  
  def run(args) do
    case OptionParser.parse(args, switches: @switches, aliases: [h: :help]) do
      {opts, [branch_name], _} ->
        create_branch(branch_name, opts)
        
      {opts, [], _} ->
        if opts[:help] do
          show_help()
        else
          Mix.shell().error("Branch name is required")
          show_usage()
        end
        
      {_, _, _} ->
        Mix.shell().error("Invalid arguments")
        show_usage()
    end
  end
  
  defp create_branch(branch_name, opts) do
    with :ok <- validate_branch_name(branch_name),
         :ok <- check_git_status(),
         :ok <- ensure_base_branch(opts[:from] || "main"),
         :ok <- create_git_branch(branch_name, opts),
         :ok <- setup_branch_template(branch_name, opts[:template]),
         :ok <- maybe_push_branch(branch_name, opts[:push]),
         :ok <- maybe_switch_branch(branch_name, !opts[:no_switch]) do
      
      Mix.shell().info([
        :green, "✅ Successfully created branch: ", :reset, branch_name
      ])
      
      show_next_steps(branch_name)
    else
      {:error, reason} ->
        Mix.shell().error("❌ Failed to create branch: #{reason}")
        System.halt(1)
    end
  end
  
  defp validate_branch_name(branch_name) do
    cond do
      String.length(branch_name) < 3 ->
        {:error, "Branch name too short (minimum 3 characters)"}
        
      String.length(branch_name) > 50 ->
        {:error, "Branch name too long (maximum 50 characters)"}
        
      not Regex.match?(@branch_pattern, branch_name) ->
        {:error, "Invalid branch name format. Use: type/description"}
        
      String.contains?(branch_name, ["_", " ", ".", ".."]) ->
        {:error, "Branch name contains invalid characters"}
        
      true ->
        :ok
    end
  end
  
  defp check_git_status do
    case System.cmd("git", ["status", "--porcelain"]) do
      {"", 0} ->
        :ok
        
      {output, 0} when output != "" ->
        Mix.shell().info("⚠️  You have uncommitted changes:")
        Mix.shell().info(output)
        
        if Mix.shell().yes?("Continue anyway?") do
          :ok
        else
          {:error, "Uncommitted changes present"}
        end
        
      {_, _} ->
        {:error, "Not in a git repository"}
    end
  end
  
  defp ensure_base_branch(base_branch) do
    # Fetch latest changes
    case System.cmd("git", ["fetch", "origin", base_branch]) do
      {_, 0} ->
        # Switch to base branch
        case System.cmd("git", ["checkout", base_branch]) do
          {_, 0} ->
            # Pull latest changes
            case System.cmd("git", ["pull", "origin", base_branch]) do
              {_, 0} -> :ok
              {error, _} -> {:error, "Failed to pull #{base_branch}: #{error}"}
            end
            
          {error, _} ->
            {:error, "Failed to checkout #{base_branch}: #{error}"}
        end
        
      {error, _} ->
        {:error, "Failed to fetch #{base_branch}: #{error}"}
    end
  end
  
  defp create_git_branch(branch_name, _opts) do
    case System.cmd("git", ["checkout", "-b", branch_name]) do
      {_, 0} ->
        :ok
        
      {error, _} ->
        {:error, "Failed to create branch: #{error}"}
    end
  end
  
  defp setup_branch_template(branch_name, template_type) do
    template_type = template_type || extract_branch_type(branch_name)
    
    case template_type do
      "feature" -> setup_feature_template()
      "bugfix" -> setup_bugfix_template()
      "hotfix" -> setup_hotfix_template()
      "docs" -> setup_docs_template()
      _ -> :ok
    end
  end
  
  defp setup_feature_template do
    create_branch_file(".branch-info", """
    # Feature Branch Information
    
    ## Description
    Brief description of the feature being implemented.
    
    ## Requirements
    - [ ] Requirement 1
    - [ ] Requirement 2
    
    ## Testing Checklist
    - [ ] Unit tests added
    - [ ] Integration tests updated
    - [ ] Manual testing completed
    
    ## Documentation
    - [ ] Code documentation updated
    - [ ] User documentation updated
    - [ ] API documentation updated (if applicable)
    """)
  end
  
  defp setup_bugfix_template do
    create_branch_file(".branch-info", """
    # Bugfix Branch Information
    
    ## Bug Description
    Description of the bug being fixed.
    
    ## Root Cause
    Analysis of what caused the bug.
    
    ## Solution
    Description of the implemented fix.
    
    ## Testing
    - [ ] Bug reproduction test added
    - [ ] Fix verification completed
    - [ ] Regression testing performed
    """)
  end
  
  defp setup_hotfix_template do
    create_branch_file(".branch-info", """
    # Hotfix Branch Information
    
    ## Critical Issue
    Description of the critical issue being addressed.
    
    ## Impact
    What systems/users are affected.
    
    ## Solution
    Quick fix implementation details.
    
    ## Verification
    - [ ] Fix tested in production-like environment
    - [ ] Rollback plan prepared
    - [ ] Stakeholders notified
    """)
  end
  
  defp setup_docs_template do
    create_branch_file(".branch-info", """
    # Documentation Branch Information
    
    ## Documentation Updates
    Description of documentation changes.
    
    ## Files Updated
    - [ ] README.md
    - [ ] API documentation
    - [ ] User guides
    - [ ] Code comments
    
    ## Validation
    - [ ] Links verified
    - [ ] Content reviewed for accuracy
    - [ ] Formatting checked
    """)
  end
  
  defp create_branch_file(filename, content) do
    File.write!(filename, content)
    :ok
  rescue
    _ -> :ok  # Don't fail if template creation fails
  end
  
  defp maybe_push_branch(branch_name, should_push) do
    if should_push do
      case System.cmd("git", ["push", "-u", "origin", branch_name]) do
        {_, 0} ->
          Mix.shell().info("📤 Branch pushed to origin")
          :ok
          
        {error, _} ->
          Mix.shell().info("⚠️  Failed to push branch: #{error}")
          :ok  # Don't fail the entire operation
      end
    else
      :ok
    end
  end
  
  defp maybe_switch_branch(branch_name, should_switch) do
    if should_switch do
      case System.cmd("git", ["checkout", branch_name]) do
        {_, 0} -> :ok
        {_, _} -> :ok  # Already on the branch
      end
    else
      :ok
    end
  end
  
  defp extract_branch_type(branch_name) do
    case String.split(branch_name, "/", parts: 2) do
      [type, _] -> type
      _ -> nil
    end
  end
  
  defp show_next_steps(branch_name) do
    Mix.shell().info([
      :yellow, "\n💡 Next Steps:\n",
      :reset, "1. Start working on your changes\n",
      "2. Run ", :cyan, "mix branch.validate", :reset, " to check branch status\n",
      "3. Commit your changes with conventional commit messages\n",
      "4. Push branch: ", :cyan, "git push origin #{branch_name}", :reset, "\n",
      "5. Create pull/merge request when ready\n"
    ])
  end
  
  defp show_help do
    Mix.shell().info(@moduledoc)
  end
  
  defp show_usage do
    Mix.shell().info("""
    Usage: mix branch.create <branch-name> [options]
    
    Examples:
      mix branch.create feature/user-authentication
      mix branch.create --push bugfix/login-validation
      mix branch.create --from=develop hotfix/security-patch
    
    Run 'mix help branch.create' for detailed documentation.
    """)
  end
end
```

### Branch Creation Features

- **Naming Convention Enforcement**: Validates branch names follow `type/description` pattern
- **Template Generation**: Creates branch-specific `.branch-info` files with checklists
- **Git Integration**: Handles fetching, switching, and pushing automatically
- **Base Branch Support**: Can create branches from any base (default: main)
- **Interactive Prompts**: Handles uncommitted changes gracefully

### Branch Creation Usage

```bash
# Basic usage
mix branch.create feature/user-authentication

# Advanced options
mix branch.create --from=develop --push feature/new-dashboard

# With template
mix branch.create --template=feature docs/api-update
```

## Branch Validation Task

### Branch Validation Implementation

**File**: `lib/mix/tasks/branch/validate.ex`

```elixir
defmodule Mix.Tasks.Branch.Validate do
  @shortdoc "Validate current branch against workflow requirements"
  
  @moduledoc """
  Validates the current branch against feature branch workflow requirements.
  
  ## Usage
  
      mix branch.validate
      mix branch.validate --fix        # Attempt to fix issues
      mix branch.validate --verbose    # Show detailed information
  
  ## Validation Checks
  
  - Branch naming convention compliance
  - Branch synchronization with main
  - Commit message format validation
  - Code quality checks
  - Documentation requirements
  - Test coverage requirements
  
  ## Options
  
      --fix        Attempt to automatically fix issues
      --verbose    Show detailed validation information
      --strict     Use strict validation rules
      --ci         Run in CI mode (exit codes for automation)
  """
  
  use Mix.Task
  
  @switches [
    fix: :boolean,
    verbose: :boolean,
    strict: :boolean,
    ci: :boolean,
    help: :boolean
  ]
  
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches, aliases: [h: :help])
    
    if opts[:help] do
      show_help()
    else
      validate_branch(opts)
    end
  end
  
  defp validate_branch(opts) do
    Mix.shell().info("🔍 Validating current branch...")
    
    validations = [
      &validate_git_status/1,
      &validate_branch_name/1,
      &validate_branch_sync/1,
      &validate_commit_messages/1,
      &validate_code_quality/1,
      &validate_tests/1,
      &validate_documentation/1
    ]
    
    results = Enum.map(validations, fn validation ->
      validation.(opts)
    end)
    
    show_validation_summary(results, opts)
    
    if opts[:ci] do
      exit_code = if Enum.all?(results, &(&1.status == :ok)), do: 0, else: 1
      System.halt(exit_code)
    end
  end
  
  defp validate_git_status(opts) do
    case System.cmd("git", ["status", "--porcelain"]) do
      {"", 0} ->
        %{check: "Git Status", status: :ok, message: "Working directory clean"}
        
      {output, 0} ->
        status = if opts[:strict], do: :error, else: :warning
        message = "Uncommitted changes present"
        
        if opts[:verbose] do
          %{check: "Git Status", status: status, message: message, details: output}
        else
          %{check: "Git Status", status: status, message: message}
        end
        
      {_, _} ->
        %{check: "Git Status", status: :error, message: "Not in git repository"}
    end
  end
  
  defp validate_branch_name(opts) do
    case System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"]) do
      {branch_name, 0} ->
        branch_name = String.trim(branch_name)
        pattern = ~r/^(feature|bugfix|hotfix|release|chore|docs)\/[a-z0-9-]+$/
        
        if branch_name == "main" do
          %{check: "Branch Name", status: :warning, message: "On main branch"}
        else
          if Regex.match?(pattern, branch_name) do
            %{check: "Branch Name", status: :ok, message: "Valid: #{branch_name}"}
          else
            message = "Invalid format: #{branch_name}"
            fix_message = if opts[:fix], do: suggest_branch_fix(branch_name), else: nil
            
            %{check: "Branch Name", status: :error, message: message, fix: fix_message}
          end
        end
        
      {_, _} ->
        %{check: "Branch Name", status: :error, message: "Cannot determine branch"}
    end
  end
  
  defp validate_branch_sync(opts) do
    case System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"]) do
      {branch_name, 0} ->
        branch_name = String.trim(branch_name)
        
        if branch_name == "main" do
          %{check: "Branch Sync", status: :ok, message: "On main branch"}
        else
          # Fetch latest main
          System.cmd("git", ["fetch", "origin", "main"])
          
          case System.cmd("git", ["merge-base", "HEAD", "origin/main"]) do
            {merge_base, 0} ->
              merge_base = String.trim(merge_base)
              
              case System.cmd("git", ["rev-parse", "origin/main"]) do
                {main_head, 0} ->
                  main_head = String.trim(main_head)
                  
                  if merge_base == main_head do
                    %{check: "Branch Sync", status: :ok, message: "Up to date with main"}
                  else
                    status = if opts[:strict], do: :error, else: :warning
                    message = "Behind main branch"
                    fix = if opts[:fix], do: "git rebase origin/main", else: nil
                    
                    %{check: "Branch Sync", status: status, message: message, fix: fix}
                  end
                  
                {_, _} ->
                  %{check: "Branch Sync", status: :error, message: "Cannot access origin/main"}
              end
              
            {_, _} ->
              %{check: "Branch Sync", status: :error, message: "Cannot determine merge base"}
          end
        end
        
      {_, _} ->
        %{check: "Branch Sync", status: :error, message: "Cannot determine current branch"}
    end
  end
  
  defp validate_commit_messages(_opts) do
    case System.cmd("git", ["log", "--oneline", "-n", "5", "--pretty=format:%s"]) do
      {output, 0} ->
        messages = String.split(output, "\n", trim: true)
        pattern = ~r/^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?: .+/
        
        invalid_messages = Enum.reject(messages, fn msg ->
          String.starts_with?(msg, "Merge") or Regex.match?(pattern, msg)
        end)
        
        if Enum.empty?(invalid_messages) do
          %{check: "Commit Messages", status: :ok, message: "All recent commits follow convention"}
        else
          %{
            check: "Commit Messages", 
            status: :warning, 
            message: "#{length(invalid_messages)} commits don't follow convention",
            details: invalid_messages
          }
        end
        
      {_, _} ->
        %{check: "Commit Messages", status: :error, message: "Cannot access commit history"}
    end
  end
  
  defp validate_code_quality(opts) do
    # Run mix format check
    case System.cmd("mix", ["format", "--check-formatted"]) do
      {_, 0} ->
        # Run compile check
        case System.cmd("mix", ["compile", "--warnings-as-errors"]) do
          {_, 0} ->
            %{check: "Code Quality", status: :ok, message: "Formatting and compilation clean"}
            
          {output, _} ->
            fix = if opts[:fix], do: "mix format", else: nil
            %{check: "Code Quality", status: :error, message: "Compilation warnings", fix: fix, details: output}
        end
        
      {output, _} ->
        fix = if opts[:fix], do: "mix format", else: nil
        %{check: "Code Quality", status: :error, message: "Formatting issues", fix: fix, details: output}
    end
  end
  
  defp validate_tests(_opts) do
    case System.cmd("mix", ["test", "--formatter", "Mix.Tasks.Test.Coverage"]) do
      {output, 0} ->
        # Extract coverage percentage if available
        coverage_regex = ~r/\[TOTAL\]\s+(\d+\.\d+)%/
        
        case Regex.run(coverage_regex, output) do
          [_, coverage_str] ->
            coverage = String.to_float(coverage_str)
            
            cond do
              coverage >= 80.0 ->
                %{check: "Test Coverage", status: :ok, message: "Coverage: #{coverage}%"}
                
              coverage >= 60.0 ->
                %{check: "Test Coverage", status: :warning, message: "Coverage: #{coverage}% (low)"}
                
              true ->
                %{check: "Test Coverage", status: :error, message: "Coverage: #{coverage}% (too low)"}
            end
            
          nil ->
            %{check: "Test Coverage", status: :ok, message: "Tests pass (coverage unknown)"}
        end
        
      {output, _} ->
        %{check: "Test Coverage", status: :error, message: "Tests failing", details: output}
    end
  end
  
  defp validate_documentation(_opts) do
    # Check if documentation files are present and up to date
    doc_files = [
      "README.md",
      "docs/",
      ".branch-info"
    ]
    
    missing_docs = Enum.reject(doc_files, fn file ->
      File.exists?(file)
    end)
    
    if Enum.empty?(missing_docs) do
      %{check: "Documentation", status: :ok, message: "Required documentation present"}
    else
      %{
        check: "Documentation", 
        status: :warning, 
        message: "Missing: #{Enum.join(missing_docs, ", ")}"
      }
    end
  end
  
  defp suggest_branch_fix(branch_name) do
    # Attempt to suggest a valid branch name
    cleaned = branch_name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9-]/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
    
    "Suggested: feature/#{cleaned}"
  end
  
  defp show_validation_summary(results, opts) do
    Mix.shell().info("\n📊 Validation Summary:")
    
    Enum.each(results, fn result ->
      status_icon = case result.status do
        :ok -> "✅"
        :warning -> "⚠️ "
        :error -> "❌"
      end
      
      Mix.shell().info("  #{status_icon} #{result.check}: #{result.message}")
      
      if opts[:verbose] and Map.has_key?(result, :details) do
        Mix.shell().info("     Details: #{result.details}")
      end
      
      if opts[:fix] and Map.has_key?(result, :fix) and result.fix do
        Mix.shell().info("     Fix: #{result.fix}")
      end
    end)
    
    # Show overall status
    error_count = Enum.count(results, &(&1.status == :error))
    warning_count = Enum.count(results, &(&1.status == :warning))
    
    cond do
      error_count > 0 ->
        Mix.shell().info([
          :red, "\n❌ Validation failed with #{error_count} errors and #{warning_count} warnings"
        ])
        
      warning_count > 0 ->
        Mix.shell().info([
          :yellow, "\n⚠️  Validation passed with #{warning_count} warnings"
        ])
        
      true ->
        Mix.shell().info([
          :green, "\n✅ All validations passed!"
        ])
    end
  end
  
  defp show_help do
    Mix.shell().info(@moduledoc)
  end
end
```

### Validation Checks

The validation task performs comprehensive checks:

1. **Git Status**: Ensures working directory is clean
2. **Branch Name**: Validates naming convention compliance
3. **Branch Sync**: Checks synchronization with main branch
4. **Commit Messages**: Validates conventional commit format
5. **Code Quality**: Runs formatting and compilation checks
6. **Test Coverage**: Verifies test execution and coverage levels
7. **Documentation**: Ensures required documentation is present

## Usage Examples

### Daily Development Workflow

```bash
# Start new feature
mix branch.create feature/user-dashboard --push

# Validate during development
mix branch.validate --verbose

# Quick validation check
mix branch.validate

# Fix issues automatically
mix branch.validate --fix

# Strict validation for CI
mix branch.validate --ci --strict
```

### Branch Templates

```bash
# Create feature with template
mix branch.create feature/api-integration --template=feature

# Create bugfix with template
mix branch.create bugfix/authentication-issue --template=bugfix

# Create hotfix from release branch
mix branch.create --from=release/v1.2.0 hotfix/critical-security-fix
```

## Testing

### Unit Tests

Create tests in `test/mix/tasks/branch/` directory:

```elixir
defmodule Mix.Tasks.Branch.CreateTest do
  use ExUnit.Case
  import Mix.Tasks.Branch.Create
  
  test "validates branch names correctly" do
    assert validate_branch_name("feature/user-auth") == :ok
    assert validate_branch_name("invalid-name") == {:error, _}
  end
  
  test "extracts branch type correctly" do
    assert extract_branch_type("feature/user-auth") == "feature"
    assert extract_branch_type("bugfix/login-issue") == "bugfix"
  end
end
```

### Integration Tests

```elixir
defmodule Mix.Tasks.Branch.IntegrationTest do
  use ExUnit.Case
  
  setup do
    # Create temporary git repository for testing
    tmp_dir = System.tmp_dir!()
    git_dir = Path.join(tmp_dir, "test-repo")
    
    File.mkdir_p!(git_dir)
    File.cd!(git_dir)
    
    System.cmd("git", ["init"])
    System.cmd("git", ["config", "user.name", "Test User"])
    System.cmd("git", ["config", "user.email", "test@example.com"])
    
    on_exit(fn ->
      File.rm_rf!(git_dir)
    end)
    
    {:ok, git_dir: git_dir}
  end
  
  test "creates branch successfully", %{git_dir: _git_dir} do
    Mix.Task.run("branch.create", ["feature/test-feature"])
    
    {branch, 0} = System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"])
    assert String.trim(branch) == "feature/test-feature"
  end
end
```

## Integration

### Add to Mix Aliases

Add to your `mix.exs` aliases:

```elixir
defp aliases do
  [
    # Branch management aliases
    "branch.create": ["branch.create"],
    "branch.validate": ["branch.validate"],
    
    # Convenience aliases
    "feature": ["branch.create feature/"],
    "bugfix": ["branch.create bugfix/"],
    "hotfix": ["branch.create hotfix/"],
    
    # Development workflow
    "dev.check": ["branch.validate", "test", "format --check-formatted"],
    "dev.fix": ["format", "branch.validate --fix"]
  ]
end
```

### CI/CD Integration

```yaml
# .github/workflows/branch-validation.yml
name: Branch Validation
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.15'
          otp-version: '26'
      - name: Validate Branch
        run: mix branch.validate --ci --strict
```

## Next Steps

- **[Version Management](version-management.md)**: Learn about semantic versioning automation
- **[Workflow Status](workflow-status.md)**: Monitor and report workflow status
- **[Integration Testing](integration-testing.md)**: Test Mix tasks and CI/CD integration
- **[Automation Overview](../README.md)**: Return to main automation guide

---

*This guide is part of the [Prismatic Mix Tasks Implementation](README.md). For questions or improvements, please refer to the [contribution guidelines](../../../README.md).*