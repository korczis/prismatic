defmodule Mix.Tasks.Prismatic.Version do
  @moduledoc """
  Bumps the version according to semantic versioning rules.

  ## Examples

      mix prismatic.version --major
      mix prismatic.version --minor
      mix prismatic.version --patch

  """
  use Mix.Task

  @shortdoc "Bumps the version according to semantic versioning rules"
  def run(args) do
    # Ensure git_ops is initialized
    Mix.Task.run("git_ops.init")

    # Parse arguments
    {opts, _, _} = OptionParser.parse(args, strict: [
      major: :boolean,
      minor: :boolean,
      patch: :boolean
    ])

    # Get the current version from mix.exs
    {version_output, _} = System.cmd("mix", ["run", "-e", "IO.puts Mix.Project.config()[:version]"], stderr_to_stdout: true)
    current_version = String.trim(version_output)
    Mix.shell().info("Current version: #{current_version}")

    # Parse the current version
    [major, minor, patch] = current_version |> String.split(".") |> Enum.map(&String.to_integer/1)

    # Calculate the new version
    {new_major, new_minor, new_patch} = cond do
      opts[:major] -> {major + 1, 0, 0}
      opts[:minor] -> {major, minor + 1, 0}
      opts[:patch] -> {major, minor, patch + 1}
      true -> {major, minor, patch + 1} # Default to patch
    end

    new_version = "#{new_major}.#{new_minor}.#{new_patch}"
    Mix.shell().info("New version: #{new_version}")

    # Update the version in mix.exs
    mix_content = File.read!("mix.exs")
    updated_mix_content = String.replace(mix_content, ~r/version: "#{Regex.escape(current_version)}"/, ~s|version: "#{new_version}"|)
    File.write!("mix.exs", updated_mix_content)

    # Update the CHANGELOG.md
    Mix.Task.run("git_ops.changelog")

    # Add a new version section to the CHANGELOG.md
    changelog_content = File.read!("CHANGELOG.md")
    date = Date.utc_today() |> Date.to_string()

    # Replace the Unreleased section with the new version
    updated_changelog = String.replace(
      changelog_content,
      "## [Unreleased]",
      "## [Unreleased]\n\n## [#{new_version}] - #{date}"
    )

    File.write!("CHANGELOG.md", updated_changelog)

    Mix.shell().info("Version bumped to #{new_version}")
    Mix.shell().info("Don't forget to commit the changes!")
  end
end
