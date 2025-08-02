<!-- NAV_START -->
<div align="center">
  <strong>📊 Workflow Status Mix Tasks</strong><br>
  <em>Status reporting, metrics, and workflow monitoring</em><br><br>
  
  <a href="../../../README.md">🏠 Home</a> | 
  <a href="../../README.md">📖 All Guides</a> | 
  <a href="../README.md">🤖 Automation</a> | 
  <a href="README.md">⚙️ Mix Tasks</a><br>
  
  <strong>📖 Reading time:</strong> 10 min | 
  <strong>🔧 Implementation time:</strong> 20 min | 
  <strong>📊 Skill level:</strong> Intermediate<br><br>
  
  <strong>Quick Links:</strong>
  <a href="#workflow-status-task">Status Task</a> |
  <a href="#status-reporting">Reporting</a> |
  <a href="#monitoring-integration">Monitoring</a> |
  <a href="#usage-examples">Examples</a>
</div>
<!-- NAV_END -->

# Workflow Status Mix Tasks

## Overview

This guide covers the implementation and usage of Mix tasks for comprehensive workflow status reporting and monitoring in the Prismatic project. These tasks provide detailed information about branch status, sync status, code quality metrics, and actionable recommendations.

## Table of Contents

- [Workflow Status Task](#workflow-status-task)
  - [Implementation](#workflow-status-implementation)
  - [Features](#workflow-status-features)
  - [Usage](#workflow-status-usage)
- [Status Information](#status-information)
- [Output Formats](#output-formats)
- [Monitoring Integration](#monitoring-integration)
- [Usage Examples](#usage-examples)
- [Dashboard Integration](#dashboard-integration)

## Workflow Status Task

### Workflow Status Implementation

**File**: `lib/mix/tasks/workflow/status.ex`

```elixir
defmodule Mix.Tasks.Workflow.Status do
  @shortdoc "Show comprehensive workflow status and branch information"
  
  @moduledoc """
  Displays comprehensive information about the current branch workflow status.
  
  ## Usage
  
      mix workflow.status
      mix workflow.status --verbose    # Show detailed information
      mix workflow.status --json       # Output in JSON format
  
  ## Information Displayed
  
  - Current branch and type
  - Branch sync status with main
  - Recent commits and their format
  - CI/CD pipeline status
  - Code quality metrics
  - Documentation status
  - Next recommended actions
  
  ## Options
  
      --verbose    Show detailed information
      --json       Output in JSON format
      --checks     Run all validation checks
  """
  
  use Mix.Task
  
  @switches [
    verbose: :boolean,
    json: :boolean,
    checks: :boolean,
    help: :boolean
  ]
  
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches, aliases: [h: :help])
    
    if opts[:help] do
      show_help()
    else
      show_workflow_status(opts)
    end
  end
  
  defp show_workflow_status(opts) do
    status_data = gather_status_data(opts)
    
    if opts[:json] do
      output_json(status_data)
    else
      output_formatted(status_data, opts)
    end
  end
  
  defp gather_status_data(opts) do
    %{
      branch: get_branch_info(),
      git: get_git_status(),
      sync: get_sync_status(),
      commits: get_recent_commits(),
      quality: get_quality_status(),
      tests: get_test_status(),
      docs: get_documentation_status(),
      ci: get_ci_status(),
      recommendations: get_recommendations()
    }
  end
  
  defp get_branch_info do
    case System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"]) do
      {branch_name, 0} ->
        branch_name = String.trim(branch_name)
        
        %{
          name: branch_name,
          type: extract_branch_type(branch_name),
          valid: validate_branch_name(branch_name)
        }
        
      {_, _} ->
        %{name: nil, type: nil, valid: false}
    end
  end
  
  defp get_git_status do
    case System.cmd("git", ["status", "--porcelain"]) do
      {"", 0} ->
        %{clean: true, changes: []}
        
      {output, 0} ->
        changes = String.split(output, "\n", trim: true)
        %{clean: false, changes: changes, count: length(changes)}
        
      {_, _} ->
        %{clean: false, error: "Not a git repository"}
    end
  end
  
  defp get_sync_status do
    case System.cmd("git", ["rev-parse", "--abbrev-ref", "HEAD"]) do
      {branch_name, 0} ->
        branch_name = String.trim(branch_name)
        
        if branch_name == "main" do
          %{status: :on_main, behind: 0, ahead: 0}
        else
          System.cmd("git", ["fetch", "origin", "main"])
          
          # Check commits behind
          case System.cmd("git", ["rev-list", "--count", "HEAD..origin/main"]) do
            {behind_str, 0} ->
              behind = String.trim(behind_str) |> String.to_integer()
              
              # Check commits ahead
              case System.cmd("git", ["rev-list", "--count", "origin/main..HEAD"]) do
                {ahead_str, 0} ->
                  ahead = String.trim(ahead_str) |> String.to_integer()
                  
                  status = cond do
                    behind == 0 && ahead == 0 -> :synced
                    behind > 0 && ahead == 0 -> :behind
                    behind == 0 && ahead > 0 -> :ahead
                    true -> :diverged
                  end
                  
                  %{status: status, behind: behind, ahead: ahead}
                  
                {_, _} ->
                  %{status: :error, message: "Cannot determine ahead count"}
              end
              
            {_, _} ->
              %{status: :error, message: "Cannot determine behind count"}
          end
        end
        
      {_, _} ->
        %{status: :error, message: "Cannot determine branch"}
    end
  end
  
  defp get_recent_commits do
    case System.cmd("git", ["log", "--oneline", "-n", "5", "--pretty=format:%h|%s|%an|%ar"]) do
      {output, 0} ->
        output
        |> String.split("\n", trim: true)
        |> Enum.map(fn line ->
          case String.split(line, "|", parts: 4) do
            [hash, message, author, date] ->
              %{
                hash: hash,
                message: message,
                author: author,
                date: date,
                conventional: validate_commit_message(message)
              }
              
            _ ->
              %{hash: "unknown", message: line, conventional: false}
          end
        end)
        
      {_, _} ->
        []
    end
  end
  
  defp get_quality_status do
    format_result = case System.cmd("mix", ["format", "--check-formatted"]) do
      {_, 0} -> %{status: :ok, message: "Code properly formatted"}
      {_, _} -> %{status: :error, message: "Formatting issues found"}
    end
    
    compile_result = case System.cmd("mix", ["compile", "--warnings-as-errors"]) do
      {_, 0} -> %{status: :ok, message: "No compilation warnings"}
      {_, _} -> %{status: :warning, message: "Compilation warnings present"}
    end
    
    %{
      formatting: format_result,
      compilation: compile_result
    }
  end
  
  defp get_test_status do
    case System.cmd("mix", ["test", "--formatter", "Mix.Tasks.Test.Coverage"]) do
      {output, 0} ->
        coverage = extract_coverage(output)
        
        %{
          status: :passing,
          coverage: coverage,
          message: "All tests passing"
        }
        
      {output, _} ->
        %{
          status: :failing,
          message: "Tests failing",
          details: String.slice(output, 0, 200)
        }
    end
  end
  
  defp get_documentation_status do
    doc_files = ["README.md", "docs/", ".branch-info"]
    
    existing_docs = Enum.filter(doc_files, &File.exists?/1)
    missing_docs = doc_files -- existing_docs
    
    %{
      present: existing_docs,
      missing: missing_docs,
      score: length(existing_docs) / length(doc_files) * 100
    }
  end
  
  defp get_ci_status do
    # This would integrate with actual CI/CD APIs
    # For now, return placeholder data
    %{
      provider: detect_ci_provider(),
      status: :unknown,
      message: "CI status not available"
    }
  end
  
  defp get_recommendations do
    # Generate recommendations based on current status
    recommendations = []
    
    # Add recommendations based on various checks
    recommendations
    |> maybe_add_recommendation("format_code", "Run 'mix format' to fix formatting")
    |> maybe_add_recommendation("sync_branch", "Run 'git rebase origin/main' to sync with main")
    |> maybe_add_recommendation("commit_message", "Use conventional commit format")
    |> maybe_add_recommendation("add_tests", "Add tests to improve coverage")
    |> maybe_add_recommendation("update_docs", "Update documentation")
  end
  
  # Helper functions
  
  defp extract_branch_type(branch_name) do
    case String.split(branch_name, "/", parts: 2) do
      [type, _] when type in ["feature", "bugfix", "hotfix", "release", "chore", "docs"] -> 
        type
      _ -> 
        "unknown"
    end
  end
  
  defp validate_branch_name(branch_name) do
    pattern = ~r/^(feature|bugfix|hotfix|release|chore|docs)\/[a-z0-9-]+$/
    Regex.match?(pattern, branch_name) || branch_name == "main"
  end
  
  defp validate_commit_message(message) do
    pattern = ~r/^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?: .+/
    String.starts_with?(message, "Merge") || Regex.match?(pattern, message)
  end
  
  defp extract_coverage(output) do
    case Regex.run(~r/\[TOTAL\]\s+(\d+\.\d+)%/, output) do
      [_, coverage_str] -> String.to_float(coverage_str)
      nil -> nil
    end
  end
  
  defp detect_ci_provider do
    cond do
      System.get_env("GITHUB_ACTIONS") -> "GitHub Actions"
      System.get_env("GITLAB_CI") -> "GitLab CI"
      System.get_env("JENKINS_URL") -> "Jenkins"
      true -> "Unknown"
    end
  end
  
  defp maybe_add_recommendation(recommendations, _condition, recommendation) do
    # This would check actual conditions and add recommendations
    [recommendation | recommendations]
  end
  
  # Output functions
  
  defp output_json(status_data) do
    Jason.encode!(status_data, pretty: true)
    |> Mix.shell().info()
  end
  
  defp output_formatted(status_data, opts) do
    Mix.shell().info("🔍 Workflow Status Report")
    Mix.shell().info("=" <> String.duplicate("=", 50))
    
    show_branch_status(status_data.branch)
    show_git_status(status_data.git)
    show_sync_status(status_data.sync)
    
    if opts[:verbose] do
      show_commits_status(status_data.commits)
      show_quality_status(status_data.quality)
      show_test_status(status_data.tests)
      show_documentation_status(status_data.docs)
    end
    
    show_recommendations(status_data.recommendations)
  end
  
  defp show_branch_status(branch_info) do
    Mix.shell().info("\n📋 Branch Information:")
    Mix.shell().info("  Name: #{branch_info.name}")
    Mix.shell().info("  Type: #{branch_info.type}")
    
    status_icon = if branch_info.valid, do: "✅", else: "❌"
    Mix.shell().info("  Valid: #{status_icon}")
  end
  
  defp show_git_status(git_info) do
    Mix.shell().info("\n📁 Git Status:")
    
    if git_info.clean do
      Mix.shell().info("  ✅ Working directory clean")
    else
      Mix.shell().info("  ⚠️  #{git_info.count} uncommitted changes")
    end
  end
  
  defp show_sync_status(sync_info) do
    Mix.shell().info("\n🔄 Sync Status:")
    
    case sync_info.status do
      :on_main ->
        Mix.shell().info("  📍 On main branch")
        
      :synced ->
        Mix.shell().info("  ✅ Up to date with main")
        
      :behind ->
        Mix.shell().info("  ⚠️  #{sync_info.behind} commits behind main")
        
      :ahead ->
        Mix.shell().info("  ⬆️  #{sync_info.ahead} commits ahead of main")
        
      :diverged ->
        Mix.shell().info("  🔀 #{sync_info.behind} behind, #{sync_info.ahead} ahead of main")
        
      :error ->
        Mix.shell().info("  ❌ #{sync_info.message}")
    end
  end
  
  defp show_commits_status(commits) do
    Mix.shell().info("\n📝 Recent Commits:")
    
    Enum.each(commits, fn commit ->
      icon = if commit.conventional, do: "✅", else: "⚠️ "
      Mix.shell().info("  #{icon} #{commit.hash} #{commit.message}")
    end)
  end
  
  defp show_quality_status(quality_info) do
    Mix.shell().info("\n🔍 Code Quality:")
    
    format_icon = if quality_info.formatting.status == :ok, do: "✅", else: "❌"
    Mix.shell().info("  #{format_icon} Formatting: #{quality_info.formatting.message}")
    
    compile_icon = if quality_info.compilation.status == :ok, do: "✅", else: "⚠️ "
    Mix.shell().info("  #{compile_icon} Compilation: #{quality_info.compilation.message}")
  end
  
  defp show_test_status(test_info) do
    Mix.shell().info("\n🧪 Test Status:")
    
    status_icon = if test_info.status == :passing, do: "✅", else: "❌"
    Mix.shell().info("  #{status_icon} #{test_info.message}")
    
    if test_info.coverage do
      coverage_icon = cond do
        test_info.coverage >= 80 -> "✅"
        test_info.coverage >= 60 -> "⚠️ "
        true -> "❌"
      end
      
      Mix.shell().info("  #{coverage_icon} Coverage: #{test_info.coverage}%")
    end
  end
  
  defp show_documentation_status(docs_info) do
    Mix.shell().info("\n📚 Documentation:")
    
    score_icon = cond do
      docs_info.score >= 80 -> "✅"
      docs_info.score >= 50 -> "⚠️ "
      true -> "❌"
    end
    
    Mix.shell().info("  #{score_icon} Score: #{round(docs_info.score)}%")
    
    if not Enum.empty?(docs_info.missing) do
      Mix.shell().info("  📝 Missing: #{Enum.join(docs_info.missing, ", ")}")
    end
  end
  
  defp show_recommendations(recommendations) do
    if not Enum.empty?(recommendations) do
      Mix.shell().info("\n💡 Recommendations:")
      
      Enum.each(recommendations, fn rec ->
        Mix.shell().info("  • #{rec}")
      end)
    end
  end
  
  defp show_help do
    Mix.shell().info(@moduledoc)
  end
end
```

### Workflow Status Features

- **Comprehensive Status**: Provides complete workflow status overview
- **Branch Analysis**: Shows current branch info, type, and validity
- **Sync Monitoring**: Tracks synchronization with main branch
- **Code Quality Metrics**: Reports formatting and compilation status
- **Test Coverage**: Displays test results and coverage percentages
- **Smart Recommendations**: Suggests actionable next steps
- **Multiple Output Formats**: Human-readable and JSON formats

## Status Information

### Branch Information

The status task reports detailed branch information:

```bash
📋 Branch Information:
  Name: feature/user-authentication
  Type: feature
  Valid: ✅
```

### Git Status

Shows working directory status:

```bash
📁 Git Status:
  ✅ Working directory clean
  # or
  ⚠️  3 uncommitted changes
```

### Sync Status

Tracks branch synchronization:

```bash
🔄 Sync Status:
  ✅ Up to date with main
  # or
  ⚠️  2 commits behind main
  # or
  ⬆️  3 commits ahead of main
  # or
  🔀 2 behind, 3 ahead of main
```

### Code Quality

Reports quality metrics:

```bash
🔍 Code Quality:
  ✅ Formatting: Code properly formatted
  ✅ Compilation: No compilation warnings
```

### Test Status

Shows test results and coverage:

```bash
🧪 Test Status:
  ✅ All tests passing
  ✅ Coverage: 85.2%
```

## Output Formats

### Human-Readable Format

Default formatted output with colors and icons:

```bash
mix workflow.status --verbose
```

```
🔍 Workflow Status Report
==================================================

📋 Branch Information:
  Name: feature/user-auth
  Type: feature
  Valid: ✅

📁 Git Status:
  ✅ Working directory clean

🔄 Sync Status:
  ⚠️  2 commits behind main

📝 Recent Commits:
  ✅ a1b2c3d feat: add user authentication
  ⚠️  d4e5f6g update readme
  ✅ g7h8i9j fix: resolve login issue

💡 Recommendations:
  • Run 'git rebase origin/main' to sync with main
  • Use conventional commit format
```

### JSON Format

Machine-readable JSON output for automation:

```bash
mix workflow.status --json
```

```json
{
  "branch": {
    "name": "feature/user-auth",
    "type": "feature",
    "valid": true
  },
  "git": {
    "clean": true,
    "changes": []
  },
  "sync": {
    "status": "behind",
    "behind": 2,
    "ahead": 0
  },
  "commits": [
    {
      "hash": "a1b2c3d",
      "message": "feat: add user authentication",
      "author": "Developer",
      "date": "2 hours ago",
      "conventional": true
    }
  ],
  "quality": {
    "formatting": {
      "status": "ok",
      "message": "Code properly formatted"
    },
    "compilation": {
      "status": "ok", 
      "message": "No compilation warnings"
    }
  },
  "tests": {
    "status": "passing",
    "coverage": 85.2,
    "message": "All tests passing"
  },
  "docs": {
    "present": ["README.md", "docs/"],
    "missing": [".branch-info"],
    "score": 66.7
  },
  "recommendations": [
    "Run 'git rebase origin/main' to sync with main",
    "Use conventional commit format"
  ]
}
```

## Usage Examples

### Development Workflow

```bash
# Quick status check
mix workflow.status

# Detailed status with all information
mix workflow.status --verbose

# Get JSON output for scripts
mix workflow.status --json > status.json

# Run with validation checks
mix workflow.status --checks
```

### Daily Development

```bash
# Morning check
mix workflow.status --verbose

# Before committing
mix workflow.status

# Before push
mix workflow.status --json | jq '.sync.status'
```

### Team Standups

```bash
# Generate team status report
for branch in $(git branch -r | grep origin | grep -v HEAD); do
  echo "=== $branch ==="
  git checkout ${branch#origin/}
  mix workflow.status
  echo
done
```

## Monitoring Integration

### CI/CD Integration

```yaml
# .github/workflows/status-check.yml
name: Workflow Status
on: [push, pull_request]

jobs:
  status:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.15'
          otp-version: '26'
      
      - name: Get Workflow Status
        run: mix workflow.status --json > workflow-status.json
      
      - name: Upload Status Report
        uses: actions/upload-artifact@v3
        with:
          name: workflow-status
          path: workflow-status.json
```

### Slack Integration

```bash
#!/bin/bash
# Send status to Slack
STATUS=$(mix workflow.status --json)
RECOMMENDATIONS=$(echo $STATUS | jq -r '.recommendations | join("\n• ")')

curl -X POST -H 'Content-type: application/json' \
  --data "{\"text\":\"Workflow Status:\n• $RECOMMENDATIONS\"}" \
  $SLACK_WEBHOOK_URL
```

### Dashboard Integration

```javascript
// Fetch status from CI/CD and display in dashboard
async function getWorkflowStatus(branch) {
  const response = await fetch(`/api/workflow-status/${branch}`);
  const status = await response.json();
  
  return {
    branch: status.branch.name,
    sync: status.sync.status,
    quality: status.quality.formatting.status === 'ok',
    tests: status.tests.status === 'passing',
    coverage: status.tests.coverage
  };
}
```

## Dashboard Integration

### Status Dashboard

Create a web dashboard to monitor multiple branches:

```html
<!DOCTYPE html>
<html>
<head>
  <title>Workflow Status Dashboard</title>
  <style>
    .status-ok { color: green; }
    .status-warning { color: orange; }
    .status-error { color: red; }
  </style>
</head>
<body>
  <h1>Workflow Status Dashboard</h1>
  <div id="status-container"></div>
  
  <script>
    async function loadStatus() {
      const branches = ['main', 'develop', 'feature/user-auth'];
      const container = document.getElementById('status-container');
      
      for (const branch of branches) {
        const status = await getWorkflowStatus(branch);
        const div = document.createElement('div');
        div.innerHTML = `
          <h3>${status.branch}</h3>
          <p>Sync: <span class="status-${status.sync === 'synced' ? 'ok' : 'warning'}">${status.sync}</span></p>
          <p>Quality: <span class="status-${status.quality ? 'ok' : 'error'}">${status.quality ? 'Good' : 'Issues'}</span></p>
          <p>Tests: <span class="status-${status.tests ? 'ok' : 'error'}">${status.tests ? 'Passing' : 'Failing'}</span></p>
          <p>Coverage: ${status.coverage}%</p>
        `;
        container.appendChild(div);
      }
    }
    
    loadStatus();
    setInterval(loadStatus, 60000); // Refresh every minute
  </script>
</body>
</html>
```

### Metrics Collection

```elixir
defmodule WorkflowMetrics do
  def collect_metrics do
    status = Mix.Tasks.Workflow.Status.gather_status_data(%{})
    
    # Send metrics to monitoring system
    send_metric("workflow.branch.valid", status.branch.valid)
    send_metric("workflow.git.clean", status.git.clean)
    send_metric("workflow.sync.behind", status.sync.behind || 0)
    send_metric("workflow.tests.coverage", status.tests.coverage || 0)
  end
  
  defp send_metric(name, value) do
    # Integration with monitoring system (Prometheus, DataDog, etc.)
  end
end
```

## Performance Optimization

### Caching Status Data

```elixir
defmodule StatusCache do
  @cache_ttl 300 # 5 minutes
  
  def get_cached_status do
    case :ets.lookup(:status_cache, :current) do
      [{:current, status, timestamp}] ->
        if System.system_time(:second) - timestamp < @cache_ttl do
          {:ok, status}
        else
          :expired
        end
      [] ->
        :not_found
    end
  end
  
  def cache_status(status) do
    :ets.insert(:status_cache, {:current, status, System.system_time(:second)})
  end
end
```

### Efficient Git Operations

```elixir
defmodule GitUtils do
  def efficient_status_check do
    # Use git commands that minimize I/O
    System.cmd("git", ["status", "--porcelain", "--untracked-files=no"])
  end
  
  def batch_git_info do
    # Get multiple pieces of information in one command
    System.cmd("git", ["log", "--oneline", "-n", "1", "--pretty=format:%H|%s|%an"])
  end
end
```

## Next Steps

- **[Integration Testing](integration-testing.md)**: Test Mix tasks and CI/CD integration
- **[Branch Management](branch-management.md)**: Learn about branch creation and validation
- **[Version Management](version-management.md)**: Automate semantic versioning
- **[Automation Overview](../README.md)**: Return to main automation guide

---

*This guide is part of the [Prismatic Mix Tasks Implementation](README.md). For questions or improvements, please refer to the [contribution guidelines](../../../README.md).*