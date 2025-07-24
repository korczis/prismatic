defmodule Mix.Tasks.GitOps.Changelog do
  @moduledoc """
  Generates a changelog based on git commit history.

  ## Examples

      mix git_ops.changelog

  """
  use Mix.Task

  @shortdoc "Generates a changelog based on git commit history"
  def run(_) do
    Mix.shell().info("Generating changelog...")

    # Ensure git_ops is initialized
    Mix.Task.run("git_ops.init")

    # Get the current version from mix.exs
    {version, _} = System.cmd("mix", ["run", "-e", "IO.puts Mix.Project.config()[:version]"], stderr_to_stdout: true)
    version = String.trim(version)
    Mix.shell().info("Current version: #{version}")

    # Get the git commit history
    {commits, _} = System.cmd("git", ["log", "--pretty=format:%h %s", "-n", "20"], stderr_to_stdout: true)

    # Parse commits and update CHANGELOG.md
    changelog_content = File.read!("CHANGELOG.md")

    # Add commits to the Unreleased section
    new_content = if String.contains?(changelog_content, "## [Unreleased]") do
      # Extract commit types and messages
      commit_entries = commits
                      |> String.split("\n")
                      |> Enum.map(fn commit ->
                        [_hash, message] = String.split(commit, " ", parts: 2)
                        message
                      end)
                      |> Enum.filter(fn message ->
                        Regex.match?(~r/^(feat|fix|docs|style|refactor|perf|test|build|ci):/, message)
                      end)
                      |> Enum.map(fn message ->
                        type = message |> String.split(":", parts: 2) |> List.first()
                        desc = message |> String.split(":", parts: 2) |> List.last() |> String.trim()
                        {type, desc}
                      end)

      # Group commits by type
      grouped_commits = Enum.reduce(commit_entries, %{}, fn {type, desc}, acc ->
        Map.update(acc, type, [desc], fn descs -> [desc | descs] end)
      end)

      # Generate changelog sections
      sections = %{
        "feat" => "New Features",
        "fix" => "Bug Fixes",
        "perf" => "Performance Improvements",
        "refactor" => "Code Refactoring",
        "docs" => "Documentation Updates",
        "build" => "Build System",
        "test" => "Tests",
        "style" => "Styling"
      }

      # Replace the Unreleased section
      unreleased_section = "## [Unreleased]\n\n" <>
        (Enum.map(sections, fn {type, title} ->
          entries = Map.get(grouped_commits, type, [])
          if Enum.empty?(entries) do
            ""
          else
            section_content = "### #{title}\n\n"
            entries_content = Enum.map(entries, fn desc -> "- #{desc}\n" end) |> Enum.join("")
            section_content <> entries_content <> "\n"
          end
        end)
        |> Enum.join(""))

      # Replace the Unreleased section in the changelog
      String.replace(changelog_content, ~r/## \[Unreleased\].*?(?=##|\z)/s, unreleased_section)
    else
      changelog_content
    end

    # Write the updated changelog
    File.write!("CHANGELOG.md", new_content)

    Mix.shell().info("Changelog generated successfully!")
  end
end
