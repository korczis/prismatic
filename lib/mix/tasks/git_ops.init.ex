defmodule Mix.Tasks.GitOps.Init do
  @moduledoc """
  Initializes git_ops for the project.

  ## Examples

      mix git_ops.init

  """
  use Mix.Task

  @shortdoc "Initializes git_ops for the project"
  def run(_) do
    Mix.shell().info("Initializing git_ops...")

    # Create initial changelog if it doesn't exist
    unless File.exists?("CHANGELOG.md") do
      Mix.shell().info("Creating initial CHANGELOG.md...")
      File.write!("CHANGELOG.md", """
      # Changelog

      All notable changes to this project will be documented in this file.

      The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
      and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

      ## [Unreleased]

      ### New Features

      - Initial project setup
      - Phoenix 1.8 integration
      - ExDoc integration for documentation
      - git_ops integration for changelog and version management
      """)
    end

    # Initialize git if not already initialized
    _git_init_result = unless File.exists?(".git") do
      Mix.shell().info("Initializing git repository...")
      {_, _} = System.cmd("git", ["init"], stderr_to_stdout: true)
    end

    # Create initial commit if no commits exist
    {result, _} = System.cmd("git", ["log", "-1"], stderr_to_stdout: true)
    _git_commit_result = if String.contains?(result, "fatal: your current branch") do
      Mix.shell().info("Creating initial commit...")
      {_, _} = System.cmd("git", ["add", "."], stderr_to_stdout: true)
      {_, _} = System.cmd("git", ["commit", "-m", "feat: Initial commit"], stderr_to_stdout: true)
    end

    Mix.shell().info("git_ops initialized successfully!")
  end
end
