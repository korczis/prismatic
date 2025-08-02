<!-- NAV_START -->
<div align="center">
  <strong>🔖 Version Management Mix Tasks</strong><br>
  <em>Automated semantic versioning and release management</em><br><br>
  
  <a href="../../../README.md">🏠 Home</a> | 
  <a href="../../README.md">📖 All Guides</a> | 
  <a href="../README.md">🤖 Automation</a> | 
  <a href="README.md">⚙️ Mix Tasks</a><br>
  
  <strong>📖 Reading time:</strong> 12 min | 
  <strong>🔧 Implementation time:</strong> 25 min | 
  <strong>📊 Skill level:</strong> Intermediate<br><br>
  
  <strong>Quick Links:</strong>
  <a href="#version-bump-task">Version Bump</a> |
  <a href="#semantic-versioning">Semantic Versioning</a> |
  <a href="#release-automation">Release Automation</a> |
  <a href="#usage-examples">Examples</a>
</div>
<!-- NAV_END -->

# Version Management Mix Tasks

## Overview

This guide covers the implementation and usage of Mix tasks for automated semantic versioning and release management in the Prismatic project. These tasks handle version bumping, changelog generation, and release automation following semantic versioning principles.

## Table of Contents

- [Version Bump Task](#version-bump-task)
  - [Implementation](#version-bump-implementation)
  - [Features](#version-bump-features)
  - [Usage](#version-bump-usage)
- [Semantic Versioning](#semantic-versioning)
- [Release Automation](#release-automation)
- [Changelog Management](#changelog-management)
- [Usage Examples](#usage-examples)
- [Integration](#integration)

## Version Bump Task

### Version Bump Implementation

**File**: `lib/mix/tasks/version/bump.ex`

```elixir
defmodule Mix.Tasks.Version.Bump do
  @shortdoc "Bump project version following semantic versioning"
  
  @moduledoc """
  Bumps the project version in mix.exs following semantic versioning principles.
  
  ## Usage
  
      mix version.bump patch
      mix version.bump minor
      mix version.bump major
      mix version.bump --to=1.2.3
  
  ## Version Types
  
  - `patch` - Bug fixes and small changes (1.0.0 -> 1.0.1)
  - `minor` - New features, backward compatible (1.0.0 -> 1.1.0)
  - `major` - Breaking changes (1.0.0 -> 2.0.0)
  
  ## Options
  
      --to VERSION     Set specific version
      --dry-run        Show what would be changed without making changes
      --tag            Create git tag after version bump
      --push           Push changes and tags to origin
      --changelog      Update CHANGELOG.md file
  
  ## Examples
  
      # Bump patch version
      mix version.bump patch
      
      # Bump minor version and create tag
      mix version.bump minor --tag
      
      # Set specific version
      mix version.bump --to=2.0.0-rc.1
      
      # Dry run to see changes
      mix version.bump major --dry-run
  """
  
  use Mix.Task
  
  @switches [
    to: :string,
    dry_run: :boolean,
    tag: :boolean,
    push: :boolean,
    changelog: :boolean,
    help: :boolean
  ]
  
  def run(args) do
    {opts, args, _} = OptionParser.parse(args, switches: @switches, aliases: [h: :help])
    
    if opts[:help] do
      show_help()
    else
      bump_version(args, opts)
    end
  end
  
  defp bump_version(args, opts) do
    current_version = get_current_version()
    
    new_version = cond do
      opts[:to] ->
        validate_version_format(opts[:to])
        
      length(args) == 1 ->
        [bump_type] = args
        calculate_next_version(current_version, bump_type)
        
      true ->
        Mix.shell().error("Version bump type or --to option required")
        show_usage()
        System.halt(1)
    end
    
    if opts[:dry_run] do
      show_dry_run(current_version, new_version, opts)
    else
      perform_version_bump(current_version, new_version, opts)
    end
  end
  
  defp get_current_version do
    case File.read("mix.exs") do
      {:ok, content} ->
        case Regex.run(~r/version: "([^"]+)"/, content) do
          [_, version] -> version
          nil -> raise "Could not find version in mix.exs"
        end
        
      {:error, _} ->
        raise "Could not read mix.exs file"
    end
  end
  
  defp validate_version_format(version) do
    version_regex = ~r/^\d+\.\d+\.\d+(-[a-zA-Z0-9\.-]+)?(\+[a-zA-Z0-9\.-]+)?$/
    
    if Regex.match?(version_regex, version) do
      version
    else
      raise "Invalid version format: #{version}. Use semantic versioning (e.g., 1.2.3)"
    end
  end
  
  defp calculate_next_version(current_version, bump_type) do
    # Parse current version
    [version_part, prerelease] = case String.split(current_version, "-", parts: 2) do
      [version] -> [version, nil]
      [version, pre] -> [version, pre]
    end
    
    [major, minor, patch] = version_part
    |> String.split(".")
    |> Enum.map(&String.to_integer/1)
    
    {new_major, new_minor, new_patch} = case bump_type do
      "major" -> {major + 1, 0, 0}
      "minor" -> {major, minor + 1, 0}
      "patch" -> {major, minor, patch + 1}
      _ -> raise "Invalid bump type: #{bump_type}. Use major, minor, or patch"
    end
    
    new_version = "#{new_major}.#{new_minor}.#{new_patch}"
    
    # Add prerelease suffix if present and not a major bump
    if prerelease && bump_type != "major" do
      "#{new_version}-#{prerelease}"
    else
      new_version
    end
  end
  
  defp show_dry_run(current_version, new_version, opts) do
    Mix.shell().info("🔍 Dry Run - Version Bump Preview:")
    Mix.shell().info("  Current version: #{current_version}")
    Mix.shell().info("  New version:     #{new_version}")
    
    if opts[:tag] do
      Mix.shell().info("  Would create git tag: v#{new_version}")
    end
    
    if opts[:push] do
      Mix.shell().info("  Would push changes to origin")
    end
    
    if opts[:changelog] do
      Mix.shell().info("  Would update CHANGELOG.md")
    end
  end
  
  defp perform_version_bump(current_version, new_version, opts) do
    Mix.shell().info("📝 Bumping version: #{current_version} -> #{new_version}")
    
    # Update mix.exs
    update_mix_exs(current_version, new_version)
    
    # Update README if version is mentioned
    update_readme(current_version, new_version)
    
    # Update changelog if requested
    if opts[:changelog] do
      update_changelog(new_version)
    end
    
    # Commit changes
    commit_version_changes(new_version)
    
    # Create tag if requested
    if opts[:tag] do
      create_version_tag(new_version)
    end
    
    # Push if requested
    if opts[:push] do
      push_changes(opts[:tag])
    end
    
    Mix.shell().info([
      :green, "✅ Version successfully bumped to #{new_version}"
    ])
  end
  
  defp update_mix_exs(current_version, new_version) do
    content = File.read!("mix.exs")
    
    new_content = String.replace(
      content, 
      ~s(version: "#{current_version}"),
      ~s(version: "#{new_version}")
    )
    
    if content == new_content do
      raise "Failed to update version in mix.exs"
    end
    
    File.write!("mix.exs", new_content)
    Mix.shell().info("  ✅ Updated mix.exs")
  end
  
  defp update_readme(current_version, new_version) do
    if File.exists?("README.md") do
      content = File.read!("README.md")
      
      # Update version references in dependency examples
      new_content = String.replace(
        content,
        ~s("~> #{current_version}"),
        ~s("~> #{new_version}")
      )
      
      # Update any other version references
      new_content = String.replace(
        new_content,
        "v#{current_version}",
        "v#{new_version}"
      )
      
      if content != new_content do
        File.write!("README.md", new_content)
        Mix.shell().info("  ✅ Updated README.md")
      end
    end
  end
  
  defp update_changelog(new_version) do
    changelog_path = "CHANGELOG.md"
    
    if File.exists?(changelog_path) do
      content = File.read!(changelog_path)
      
      # Get recent commits for changelog entry
      {output, 0} = System.cmd("git", [
        "log", 
        "--oneline", 
        "--pretty=format:- %s", 
        "--since=1 week ago"
      ])
      
      changes = String.trim(output)
      
      new_entry = """
      ## [#{new_version}] - #{Date.utc_today()}
      
      #{changes}
      
      """
      
      # Insert new entry after the title
      new_content = String.replace(
        content,
        ~r/^(# Changelog\s*\n)/m,
        "\\1\n#{new_entry}"
      )
      
      File.write!(changelog_path, new_content)
      Mix.shell().info("  ✅ Updated CHANGELOG.md")
    else
      create_changelog(new_version)
    end
  end
  
  defp create_changelog(new_version) do
    changelog_content = """
    # Changelog
    
    All notable changes to this project will be documented in this file.
    
    The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
    and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
    
    ## [#{new_version}] - #{Date.utc_today()}
    
    - Initial version
    """
    
    File.write!("CHANGELOG.md", changelog_content)
    Mix.shell().info("  ✅ Created CHANGELOG.md")
  end
  
  defp commit_version_changes(new_version) do
    # Stage changes
    System.cmd("git", ["add", "mix.exs", "README.md", "CHANGELOG.md"])
    
    # Commit with conventional commit message
    commit_message = "chore: bump version to #{new_version}"
    
    case System.cmd("git", ["commit", "-m", commit_message]) do
      {_, 0} ->
        Mix.shell().info("  ✅ Committed version changes")
        
      {error, _} ->
        Mix.shell().info("  ⚠️  Failed to commit changes: #{error}")
    end
  end
  
  defp create_version_tag(new_version) do
    tag_name = "v#{new_version}"
    tag_message = "Release version #{new_version}"
    
    case System.cmd("git", ["tag", "-a", tag_name, "-m", tag_message]) do
      {_, 0} ->
        Mix.shell().info("  ✅ Created git tag: #{tag_name}")
        
      {error, _} ->
        Mix.shell().info("  ⚠️  Failed to create tag: #{error}")
    end
  end
  
  defp push_changes(include_tags) do
    # Push commits  
    case System.cmd("git", ["push", "origin", "HEAD"]) do
      {_, 0} ->
        Mix.shell().info("  ✅ Pushed changes to origin")
        
        # Push tags if requested
        if include_tags do
          case System.cmd("git", ["push", "origin", "--tags"]) do
            {_, 0} ->
              Mix.shell().info("  ✅ Pushed tags to origin")
              
            {error, _} ->
              Mix.shell().info("  ⚠️  Failed to push tags: #{error}")
          end
        end
        
      {error, _} ->
        Mix.shell().info("  ⚠️  Failed to push changes: #{error}")
    end
  end
  
  defp show_help do
    Mix.shell().info(@moduledoc)
  end
  
  defp show_usage do
    Mix.shell().info("""
    Usage: mix version.bump <type> [options]
           mix version.bump --to=<version> [options]
    
    Types: major, minor, patch
    
    Examples:
      mix version.bump patch
      mix version.bump minor --tag --push
      mix version.bump --to=2.0.0-rc.1
    
    Run 'mix help version.bump' for detailed documentation.
    """)
  end
end
```

### Version Bump Features

- **Semantic Versioning**: Automatic calculation of next version based on bump type
- **Format Validation**: Ensures version strings follow semantic versioning format
- **Multi-file Updates**: Updates `mix.exs`, `README.md`, and `CHANGELOG.md`
- **Git Integration**: Commits changes, creates tags, and pushes to remote
- **Dry Run Mode**: Preview changes before applying them
- **Prerelease Support**: Handles prerelease versions and build metadata

### Version Bump Usage

```bash
# Basic version bumps
mix version.bump patch    # 1.0.0 -> 1.0.1
mix version.bump minor    # 1.0.0 -> 1.1.0
mix version.bump major    # 1.0.0 -> 2.0.0

# Set specific version
mix version.bump --to=2.1.0-rc.1

# Create release with tag and push
mix version.bump minor --tag --push --changelog

# Preview changes
mix version.bump major --dry-run
```

## Semantic Versioning

### Version Format

The task follows [Semantic Versioning](https://semver.org/) principles:

```
MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]
```

- **MAJOR**: Incompatible API changes
- **MINOR**: Backward-compatible functionality additions
- **PATCH**: Backward-compatible bug fixes
- **PRERELEASE**: Pre-release versions (alpha, beta, rc)
- **BUILD**: Build metadata

### Version Calculation Rules

```elixir
# Current: 1.2.3
"patch" -> "1.2.4"    # Bug fixes
"minor" -> "1.3.0"    # New features
"major" -> "2.0.0"    # Breaking changes

# Current: 1.2.3-beta.1
"patch" -> "1.2.4-beta.1"  # Prerelease preserved
"minor" -> "1.3.0-beta.1"  # Prerelease preserved
"major" -> "2.0.0"         # Prerelease removed
```

### Prerelease Handling

```bash
# Set prerelease version
mix version.bump --to=2.0.0-alpha.1

# Bump prerelease
mix version.bump --to=2.0.0-alpha.2

# Release candidate
mix version.bump --to=2.0.0-rc.1

# Final release
mix version.bump --to=2.0.0
```

## Release Automation

### Automated Release Workflow

The version bump task can be integrated into a complete release workflow:

```bash
# 1. Prepare release branch
git checkout -b release/v1.2.0

# 2. Update version and changelog
mix version.bump minor --changelog

# 3. Review changes
git diff HEAD~1

# 4. Create release with tag
mix version.bump --to=1.2.0 --tag --push

# 5. Merge to main
git checkout main
git merge release/v1.2.0
git push origin main
```

### Release Aliases

Add convenient aliases to `mix.exs`:

```elixir
defp aliases do
  [
    # Release aliases
    "release.patch": ["version.bump patch --tag --push --changelog"],
    "release.minor": ["version.bump minor --tag --push --changelog"],
    "release.major": ["version.bump major --tag --push --changelog"],
    
    # Prerelease aliases
    "release.alpha": ["version.bump --to=${VERSION}-alpha.1 --tag --push"],
    "release.beta": ["version.bump --to=${VERSION}-beta.1 --tag --push"],
    "release.rc": ["version.bump --to=${VERSION}-rc.1 --tag --push"]
  ]
end
```

## Changelog Management

### Automatic Changelog Generation

The task can automatically update `CHANGELOG.md` with recent commits:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - 2024-01-15

- feat: add user authentication system
- fix: resolve login validation issue
- docs: update API documentation
- chore: update dependencies

## [1.1.0] - 2024-01-08

- feat: implement dashboard analytics
- fix: improve error handling
```

### Manual Changelog Management

For more control, update the changelog manually before version bumping:

```bash
# 1. Edit CHANGELOG.md manually
vim CHANGELOG.md

# 2. Bump version without automatic changelog
mix version.bump minor --tag --push

# 3. Or include your manual changes
mix version.bump minor --tag --push --changelog
```

## Usage Examples

### Development Workflow

```bash
# During development - patch releases
mix version.bump patch --changelog
mix version.bump patch --tag --push

# Feature releases
mix version.bump minor --tag --push --changelog

# Breaking changes
mix version.bump major --tag --push --changelog
```

### CI/CD Integration

```bash
# Automated releases in CI
if [[ $BRANCH == "main" ]]; then
  mix version.bump patch --tag --push --changelog
fi

# Manual releases with specific versions
mix version.bump --to=$RELEASE_VERSION --tag --push --changelog
```

### Prerelease Management

```bash
# Start alpha release cycle
mix version.bump --to=2.0.0-alpha.1 --tag --push

# Continue alpha releases
mix version.bump --to=2.0.0-alpha.2 --tag --push

# Move to beta
mix version.bump --to=2.0.0-beta.1 --tag --push

# Release candidate
mix version.bump --to=2.0.0-rc.1 --tag --push

# Final release
mix version.bump --to=2.0.0 --tag --push --changelog
```

### Dry Run Testing

```bash
# Preview patch release
mix version.bump patch --dry-run --changelog

# Preview major release with all options
mix version.bump major --dry-run --tag --push --changelog
```

## Integration

### Mix Aliases Integration

```elixir
defp aliases do
  [
    # Version management
    "version.bump": ["version.bump"],
    
    # Release workflow
    "release.patch": ["version.bump patch --tag --push --changelog"],
    "release.minor": ["version.bump minor --tag --push --changelog"],
    "release.major": ["version.bump major --tag --push --changelog"],
    
    # Development aliases
    "dev.release": ["version.bump patch --changelog"],
    "dev.tag": ["version.bump patch --tag"]
  ]
end
```

### Dependencies

Add required dependencies to `mix.exs`:

```elixir
defp deps do
  [
    # For date handling in changelog
    {:jason, "~> 1.4", only: [:dev, :test]}
  ]
end
```

### Git Hooks Integration

Create a pre-push hook to validate version bumps:

```bash
#!/bin/sh
# .git/hooks/pre-push

# Check if version was bumped properly
if git diff --name-only HEAD~1 | grep -q "mix.exs"; then
  echo "Version bump detected, validating..."
  mix version.bump --dry-run patch
fi
```

### GitHub Actions Integration

```yaml
name: Release
on:
  push:
    branches: [main]
  
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
      
      - name: Setup Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: '1.15'
          otp-version: '26'
      
      - name: Install dependencies
        run: mix deps.get
      
      - name: Create release
        run: mix release.patch
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Error Handling

### Common Issues and Solutions

1. **Version format errors**: Ensure versions follow semantic versioning
2. **Git repository issues**: Ensure working in a git repository with origin remote
3. **Permission errors**: Ensure proper git credentials for pushing
4. **File conflicts**: Resolve any merge conflicts before version bumping

### Recovery Procedures

```bash
# Undo last version bump (before push)
git reset --hard HEAD~1
git tag -d v1.2.3  # if tag was created

# Fix incorrect version
mix version.bump --to=correct.version.number

# Manual version fix
vim mix.exs  # Edit version manually
git add mix.exs
git commit -m "fix: correct version number"
```

## Next Steps

- **[Workflow Status](workflow-status.md)**: Monitor and report workflow status
- **[Branch Management](branch-management.md)**: Learn about branch creation and validation
- **[Integration Testing](integration-testing.md)**: Test Mix tasks and CI/CD integration
- **[Automation Overview](../README.md)**: Return to main automation guide

---

*This guide is part of the [Prismatic Mix Tasks Implementation](README.md). For questions or improvements, please refer to the [contribution guidelines](../../../README.md).*