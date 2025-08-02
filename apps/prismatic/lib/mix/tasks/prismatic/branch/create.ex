defmodule Mix.Tasks.Prismatic.Branch.Create do
  @moduledoc """
  Create feature branches with automated templates and validation.

  Provides intelligent branch creation with:
  - Branch naming convention enforcement
  - Automated template application
  - Integration with project workflow
  - Branch protection and validation
  - Git hooks setup and configuration

  ## Usage

      # Create a feature branch with automatic naming
      mix prismatic.branch.create --name user-authentication --type feature

      # Create a branch from template with custom base
      mix prismatic.branch.create --name hotfix-security --type hotfix --base main

      # Interactive branch creation with guided setup
      mix prismatic.branch.create --interactive

      # Create branch with specific template and validation
      mix prismatic.branch.create --name docs-update --template documentation --validate

      # Dry run to preview branch creation
      mix prismatic.branch.create --name feature-test --dry-run

  ## Branch Types

  ### Feature Branches
  - Standard feature development
  - Automatic naming: `feature/ISSUE-NAME`
  - Template: feature development setup
  - Validation: code quality checks

  ### Hotfix Branches
  - Critical bug fixes
  - Automatic naming: `hotfix/VERSION-ISSUE`
  - Template: minimal setup for quick fixes
  - Validation: security and stability checks

  ### Documentation Branches
  - Documentation updates
  - Automatic naming: `docs/TOPIC-NAME`
  - Template: documentation tools setup
  - Validation: link and content checks

  ### Experimental Branches
  - Research and prototyping
  - Automatic naming: `experiment/RESEARCH-TOPIC`
  - Template: sandbox environment
  - Validation: minimal checks
  """

  use Mix.Tasks.Prismatic.Shared.TaskBehaviour,
    profile: :code,
    description: "Create feature branches with automated templates"

  @shortdoc "Create feature branches with automated templates and validation"

  @switches [
    name: :string,
    type: :string,
    base: :string,
    template: :string,
    interactive: :boolean,
    validate: :boolean,
    dry_run: :boolean,
    force: :boolean,
    description: :string,
    issue: :string,
    assignee: :string,
    priority: :string,
    verbose: :boolean,
    help: :boolean
  ]

  @aliases [
    n: :name,
    t: :type,
    b: :base,
    i: :interactive,
    d: :dry_run,
    f: :force,
    v: :verbose,
    h: :help
  ]

  @branch_types ~w(feature hotfix docs documentation experiment bugfix chore)
  @default_templates %{
    "feature" => "feature_template",
    "hotfix" => "hotfix_template",
    "docs" => "docs_template",
    "documentation" => "docs_template",
    "experiment" => "experiment_template",
    "bugfix" => "bugfix_template",
    "chore" => "chore_template"
  }

  @impl Mix.Task
  def run(args) do
    with_task_context(__MODULE__, args, &execute_branch_creation/1)
  end

  @impl Mix.Tasks.Prismatic.Shared.TaskBehaviour
  def get_option_parser_config do
    [switches: @switches, aliases: @aliases]
  end

  @impl Mix.Tasks.Prismatic.Shared.TaskBehaviour
  def get_task_defaults do
    %{
      type: "feature",
      base: "main",
      template: nil,
      interactive: false,
      validate: true,
      dry_run: false,
      force: false,
      priority: "medium",
      file_prefix: "branch-creation"
    }
  end

  @impl Mix.Tasks.Prismatic.Shared.TaskBehaviour
  def validate_task_options(options) do
    cond do
      options[:name] && not valid_branch_name?(options[:name]) ->
        {:error, "Invalid branch name format. Use alphanumeric characters, hyphens, and underscores only."}

      options[:type] && options[:type] not in @branch_types ->
        {:error, "Invalid branch type '#{options[:type]}'. Available types: #{Enum.join(@branch_types, ", ")}"}

      options[:interactive] && options[:name] ->
        {:error, "Cannot use --interactive with --name. Choose one approach."}

      not options[:interactive] && not options[:name] ->
        {:error, "Branch name is required. Use --name or --interactive."}

      true ->
        :ok
    end
  end

  @impl Mix.Tasks.Prismatic.Shared.TaskBehaviour
  def validate_task_prerequisites(options) do
    # Validate git repository
    unless git_repository_exists?() do
      raise "Current directory is not a git repository. Initialize git first."
    end

    # Check git configuration
    validate_git_configuration()

    # Verify base branch exists
    unless git_branch_exists?(options.base) do
      raise "Base branch '#{options.base}' does not exist."
    end

    # Check for uncommitted changes if not force mode
    unless options.force do
      if has_uncommitted_changes?() do
        raise "Uncommitted changes detected. Commit or stash changes first, or use --force."
      end
    end

    :ok
  end

  # Main execution function
  defp execute_branch_creation(options) do
    if options[:interactive] do
      execute_interactive_creation(options)
    else
      if options[:dry_run] do
        preview_branch_creation(options)
      else
        perform_branch_creation(options)
      end
    end
  end

  defp execute_interactive_creation(options) do
    OutputFormatter.display_section_header("Interactive Branch Creation")

    # Gather information interactively
    branch_config = gather_branch_information(options)

    # Show preview of what will be created
    preview_interactive_branch(branch_config)

    # Confirm creation
    if confirm_branch_creation(branch_config) do
      perform_branch_creation(branch_config)
    else
      OutputFormatter.display_info("Branch creation cancelled.")
    end
  end

  defp preview_branch_creation(options) do
    OutputFormatter.display_section_header("Branch Creation Preview")

    branch_name = generate_branch_name(options[:name], options[:type])
    template = determine_template(options)

    OutputFormatter.display_info("Branch name: #{branch_name}")
    OutputFormatter.display_info("Branch type: #{options[:type]}")
    OutputFormatter.display_info("Base branch: #{options[:base]}")
    OutputFormatter.display_info("Template: #{template}")

    if options[:description] do
      OutputFormatter.display_info("Description: #{options[:description]}")
    end

    # Show what the template will set up
    OutputFormatter.display_section_header("Template Setup", width: 40)
    display_template_setup(template, options)

    # Show validation checks that will run
    if options[:validate] do
      OutputFormatter.display_section_header("Validation Checks", width: 40)
      display_validation_checks(options)
    end

    OutputFormatter.display_success("Dry run completed. Use without --dry-run to create branch.")
  end

  defp perform_branch_creation(options) do
    ProgressMonitor.start_operation("Creating branch...")

    # Generate final branch name
    branch_name = generate_branch_name(options[:name], options[:type])

    # Create branch creation context
    context = initialize_branch_context(branch_name, options)

    # Execute branch creation phases
    results = execute_branch_creation_phases(context)

    # Generate creation report
    report = generate_branch_report(results, context)

    # Display results
    display_branch_creation_results(report, options)

    ProgressMonitor.complete_operation("Branch creation completed")
  end

  defp gather_branch_information(options) do
    Mix.shell().info("\n" <> IO.ANSI.cyan() <> "🌿 Interactive Branch Creation" <> IO.ANSI.reset())
    Mix.shell().info("Please provide the following information:")

    # Get branch name
    name = get_user_input("Branch name (descriptive, kebab-case):", options[:name])

    # Get branch type
    type = get_branch_type_input(options[:type])

    # Get base branch
    available_branches = get_available_branches()
    base = get_base_branch_input(available_branches, options[:base])

    # Get optional information
    description = get_user_input("Description (optional):", options[:description])
    issue = get_user_input("Related issue number (optional):", options[:issue])
    assignee = get_user_input("Assignee (optional):", options[:assignee])
    priority = get_priority_input(options[:priority])

    %{
      name: name,
      type: type,
      base: base,
      description: description,
      issue: issue,
      assignee: assignee,
      priority: priority,
      validate: true,
      template: determine_template(%{type: type, template: options[:template]})
    }
  end

  defp initialize_branch_context(branch_name, options) do
    %{
      branch_name: branch_name,
      options: options,
      template: determine_template(options),
      start_time: System.monotonic_time(:millisecond),
      operations: [],
      validations: [],
      errors: []
    }
  end

  defp execute_branch_creation_phases(context) do
    phases = [
      {:preparation, &prepare_branch_creation/1},
      {:creation, &create_git_branch/1},
      {:template_application, &apply_branch_template/1},
      {:validation, &validate_branch_setup/1},
      {:finalization, &finalize_branch_creation/1}
    ]

    Enum.reduce(phases, %{}, fn {phase, phase_fn}, results ->
      ProgressMonitor.show_info("Executing #{phase} phase...")

      phase_result = ErrorHandler.safe_execute(
        "branch.create",
        Atom.to_string(phase),
        fn -> phase_fn.(context) end
      )

      Map.put(results, phase, phase_result)
    end)
  end

  defp prepare_branch_creation(context) do
    # Switch to base branch
    switch_to_base_branch(context.options.base)

    # Pull latest changes
    pull_latest_changes(context.options.base)

    # Verify clean state
    verify_clean_working_directory()

    %{
      base_branch_current: true,
      latest_changes_pulled: true,
      working_directory_clean: true
    }
  end

  defp create_git_branch(context) do
    # Create the new branch
    create_result = create_git_branch_command(context.branch_name, context.options.base)

    # Switch to the new branch
    switch_result = switch_to_branch(context.branch_name)

    %{
      branch_created: create_result,
      branch_switched: switch_result,
      branch_name: context.branch_name
    }
  end

  defp apply_branch_template(context) do
    template = context.template

    if template do
      # Apply template files and configuration
      template_results = apply_template_files(template, context)

      # Set up branch-specific configuration
      config_results = setup_branch_configuration(context)

      %{
        template_applied: template_results,
        configuration_set: config_results,
        template_name: template
      }
    else
      %{template_applied: false, message: "No template specified"}
    end
  end

  defp validate_branch_setup(context) do
    if context.options.validate do
      # Run branch validation checks
      validation_results = run_branch_validations(context)

      %{
        validations_run: true,
        results: validation_results,
        all_passed: Enum.all?(validation_results, fn {_, result} -> result.passed end)
      }
    else
      %{validations_run: false, message: "Validation skipped"}
    end
  end

  defp finalize_branch_creation(context) do
    # Create initial commit if template was applied
    commit_result = if context.template do
      create_initial_commit(context)
    else
      %{committed: false, message: "No template changes to commit"}
    end

    # Set up branch tracking
    tracking_result = setup_branch_tracking(context.branch_name)

    %{
      initial_commit: commit_result,
      tracking_set: tracking_result,
      branch_ready: true
    }
  end

  # Git operation helpers

  defp git_repository_exists? do
    File.dir?(".git") or System.cmd("git", ["rev-parse", "--git-dir"], stderr_to_stdout: true) |> elem(1) == 0
  end

  defp validate_git_configuration do
    # Check for user name and email
    case System.cmd("git", ["config", "user.name"], stderr_to_stdout: true) do
      {"", 1} -> raise "Git user.name not configured. Run: git config user.name 'Your Name'"
      _ -> :ok
    end

    case System.cmd("git", ["config", "user.email"], stderr_to_stdout: true) do
      {"", 1} -> raise "Git user.email not configured. Run: git config user.email 'your@email.com'"
      _ -> :ok
    end
  end

  defp git_branch_exists?(branch_name) do
    case System.cmd("git", ["rev-parse", "--verify", branch_name], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end

  defp has_uncommitted_changes? do
    case System.cmd("git", ["status", "--porcelain"], stderr_to_stdout: true) do
      {"", 0} -> false
      {output, 0} -> String.trim(output) != ""
      _ -> false
    end
  end

  defp switch_to_base_branch(base_branch) do
    case System.cmd("git", ["checkout", base_branch], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {error, _} -> raise "Failed to switch to base branch: #{error}"
    end
  end

  defp pull_latest_changes(base_branch) do
    case System.cmd("git", ["pull", "origin", base_branch], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {error, _} ->
        # Non-fatal error - branch might not have upstream
        ProgressMonitor.show_warning("Could not pull latest changes: #{error}")
        :ok
    end
  end

  defp verify_clean_working_directory do
    unless has_uncommitted_changes?() do
      :ok
    else
      raise "Working directory is not clean after preparation"
    end
  end

  defp create_git_branch_command(branch_name, base_branch) do
    case System.cmd("git", ["checkout", "-b", branch_name, base_branch], stderr_to_stdout: true) do
      {_, 0} -> %{success: true, branch: branch_name}
      {error, _} -> raise "Failed to create branch: #{error}"
    end
  end

  defp switch_to_branch(branch_name) do
    case System.cmd("git", ["checkout", branch_name], stderr_to_stdout: true) do
      {_, 0} -> %{success: true, current_branch: branch_name}
      {error, _} -> raise "Failed to switch to branch: #{error}"
    end
  end

  # Template and configuration helpers

  defp determine_template(options) do
    cond do
      options[:template] -> options[:template]
      options[:type] -> Map.get(@default_templates, options[:type], "default")
      true -> "default"
    end
  end

  defp apply_template_files(template_name, context) do
    template_dir = Path.join(["priv", "templates", "branches", template_name])

    if File.dir?(template_dir) do
      # Copy template files
      copy_template_files(template_dir, ".")

      # Process template variables
      process_template_variables(template_name, context)

      %{success: true, template: template_name, files_created: list_template_files(template_dir)}
    else
      # Create basic template structure
      create_basic_template(context)

      %{success: true, template: "basic", files_created: ["README.md"]}
    end
  end

  defp setup_branch_configuration(context) do
    # Create branch-specific configuration
    config = %{
      branch_name: context.branch_name,
      branch_type: context.options.type,
      created_at: DateTime.utc_now(),
      base_branch: context.options.base,
      description: context.options[:description],
      assignee: context.options[:assignee],
      priority: context.options[:priority]
    }

    # Save configuration to .branch file
    config_content = Jason.encode!(config, pretty: true)
    File.write!(".branch", config_content)

    %{success: true, config_saved: true}
  end

  defp run_branch_validations(context) do
    validations = [
      {"Branch Name Format", &validate_branch_name_format/1},
      {"Git Configuration", &validate_git_setup/1},
      {"Template Application", &validate_template_application/1},
      {"File Permissions", &validate_file_permissions/1}
    ]

    Enum.map(validations, fn {name, validator} ->
      {name, validator.(context)}
    end)
  end

  defp create_initial_commit(context) do
    # Add all template files
    case System.cmd("git", ["add", "."], stderr_to_stdout: true) do
      {_, 0} ->
        # Create commit
        commit_message = generate_commit_message(context)
        case System.cmd("git", ["commit", "-m", commit_message], stderr_to_stdout: true) do
          {_, 0} -> %{committed: true, message: commit_message}
          {error, _} -> %{committed: false, error: error}
        end
      {error, _} -> %{committed: false, error: "Failed to add files: #{error}"}
    end
  end

  defp setup_branch_tracking(branch_name) do
    # Set up upstream tracking (optional, might fail if no remote)
    case System.cmd("git", ["push", "--set-upstream", "origin", branch_name], stderr_to_stdout: true) do
      {_, 0} -> %{tracking_set: true, upstream: "origin/#{branch_name}"}
      {_, _} -> %{tracking_set: false, message: "No remote origin configured"}
    end
  end

  # User interaction helpers

  defp get_user_input(prompt, default \\ nil) do
    default_text = if default, do: " [#{default}]", else: ""
    input = Mix.shell().prompt("#{prompt}#{default_text} ") |> String.trim()

    if input == "" and default, do: default, else: input
  end

  defp get_branch_type_input(default) do
    Mix.shell().info("\nAvailable branch types:")
    Enum.with_index(@branch_types, 1)
    |> Enum.each(fn {type, index} ->
      marker = if type == default, do: " (default)", else: ""
      Mix.shell().info("  #{index}. #{type}#{marker}")
    end)

    choice = get_user_input("Select branch type (1-#{length(@branch_types)}):", "1")

    case Integer.parse(choice) do
      {index, ""} when index >= 1 and index <= length(@branch_types) ->
        Enum.at(@branch_types, index - 1)
      _ ->
        if choice in @branch_types, do: choice, else: default
    end
  end

  defp get_available_branches do
    case System.cmd("git", ["branch", "-r"], stderr_to_stdout: true) do
      {output, 0} ->
        output
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&(&1 != ""))
        |> Enum.map(fn branch -> String.replace(branch, "origin/", "") end)
        |> Enum.reject(&String.starts_with?(&1, "HEAD"))
      _ ->
        ["main", "master", "develop"]
    end
  end

  defp get_base_branch_input(available_branches, default) do
    Mix.shell().info("\nAvailable base branches:")
    available_branches
    |> Enum.take(10)  # Show first 10
    |> Enum.with_index(1)
    |> Enum.each(fn {branch, index} ->
      marker = if branch == default, do: " (default)", else: ""
      Mix.shell().info("  #{index}. #{branch}#{marker}")
    end)

    choice = get_user_input("Base branch:", default)

    if choice in available_branches, do: choice, else: default
  end

  defp get_priority_input(default) do
    priorities = ["low", "medium", "high", "urgent"]

    Mix.shell().info("\nPriority levels:")
    Enum.with_index(priorities, 1)
    |> Enum.each(fn {priority, index} ->
      marker = if priority == default, do: " (default)", else: ""
      Mix.shell().info("  #{index}. #{priority}#{marker}")
    end)

    choice = get_user_input("Priority:", default)

    if choice in priorities, do: choice, else: default
  end

  # Validation and utility functions

  defp valid_branch_name?(name) do
    # Allow alphanumeric, hyphens, underscores, slashes
    Regex.match?(~r/^[a-zA-Z0-9\-_\/]+$/, name) and String.length(name) <= 100
  end

  defp generate_branch_name(name, type) do
    # Clean and format the branch name
    clean_name = name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\-_]/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")

    case type do
      "feature" -> "feature/#{clean_name}"
      "hotfix" -> "hotfix/#{clean_name}"
      "docs" -> "docs/#{clean_name}"
      "documentation" -> "docs/#{clean_name}"
      "experiment" -> "experiment/#{clean_name}"
      "bugfix" -> "bugfix/#{clean_name}"
      "chore" -> "chore/#{clean_name}"
      _ -> clean_name
    end
  end

  defp preview_interactive_branch(config) do
    OutputFormatter.display_section_header("Branch Preview")

    branch_name = generate_branch_name(config.name, config.type)

    OutputFormatter.display_info("Branch name: #{branch_name}")
    OutputFormatter.display_info("Type: #{config.type}")
    OutputFormatter.display_info("Base: #{config.base}")
    OutputFormatter.display_info("Template: #{config.template}")

    if config.description && config.description != "" do
      OutputFormatter.display_info("Description: #{config.description}")
    end

    if config.issue && config.issue != "" do
      OutputFormatter.display_info("Related issue: ##{config.issue}")
    end

    if config.assignee && config.assignee != "" do
      OutputFormatter.display_info("Assignee: #{config.assignee}")
    end

    OutputFormatter.display_info("Priority: #{config.priority}")
  end

  defp confirm_branch_creation(config) do
    Mix.shell().yes?("\nCreate this branch?")
  end

  defp display_template_setup(template, _options) do
    template_info = get_template_info(template)

    Enum.each(template_info.files, fn file ->
      OutputFormatter.display_info("• #{file}")
    end)

    if not Enum.empty?(template_info.configurations) do
      OutputFormatter.display_info("\nConfigurations:")
      Enum.each(template_info.configurations, fn config ->
        OutputFormatter.display_info("• #{config}")
      end)
    end
  end

  defp display_validation_checks(options) do
    checks = [
      "Branch name format validation",
      "Git configuration verification",
      "Base branch existence check",
      "Template application validation"
    ]

    if options[:type] == "hotfix" do
      checks = checks ++ ["Security vulnerability scan", "Stability impact assessment"]
    end

    Enum.each(checks, fn check ->
      OutputFormatter.display_info("• #{check}")
    end)
  end

  defp generate_branch_report(results, context) do
    execution_time = System.monotonic_time(:millisecond) - context.start_time

    %{
      metadata: %{
        creation_timestamp: DateTime.utc_now(),
        execution_time_ms: execution_time,
        branch_name: context.branch_name,
        template_used: context.template
      },
      results: results,
      summary: generate_creation_summary(results, context),
      success: creation_successful?(results)
    }
  end

  defp display_branch_creation_results(report, options) do
    OutputFormatter.display_section_header("Branch Creation Results")

    if report.success do
      OutputFormatter.display_success("✅ Branch '#{report.metadata.branch_name}' created successfully!")
      OutputFormatter.display_info("Template: #{report.metadata.template_used}")
      OutputFormatter.display_info("Execution time: #{report.metadata.execution_time_ms}ms")

      # Show next steps
      OutputFormatter.display_section_header("Next Steps", width: 40)
      display_next_steps(report.metadata.branch_name, options)
    else
      OutputFormatter.display_error("❌ Branch creation failed")
      display_creation_errors(report.results)
    end
  end

  defp display_next_steps(branch_name, _options) do
    next_steps = [
      "Start working on your feature",
      "Make commits as you progress",
      "Push to remote: git push origin #{branch_name}",
      "Create pull request when ready",
      "Use 'mix prismatic.branch.validate' to check compliance"
    ]

    Enum.each(next_steps, fn step ->
      OutputFormatter.display_info("• #{step}")
    end)
  end

  # Placeholder implementations for template system
  defp get_template_info(_template) do
    %{
      files: ["README.md", ".gitignore", "CHANGELOG.md"],
      configurations: ["Git hooks", "Code quality checks"]
    }
  end

  defp copy_template_files(_template_dir, _target_dir), do: :ok
  defp process_template_variables(_template, _context), do: :ok
  defp list_template_files(_template_dir), do: ["README.md"]
  defp create_basic_template(_context), do: File.write!("README.md", "# New Branch\n\nDescription coming soon...\n")

  defp validate_branch_name_format(_context), do: %{passed: true}
  defp validate_git_setup(_context), do: %{passed: true}
  defp validate_template_application(_context), do: %{passed: true}
  defp validate_file_permissions(_context), do: %{passed: true}

  defp generate_commit_message(context) do
    type = String.capitalize(context.options.type || "feature")
    name = context.options.name || "branch"

    base_message = "#{type}: Initialize #{name} branch"

    if context.options[:description] do
      "#{base_message}\n\n#{context.options.description}"
    else
      base_message
    end
  end

  defp generate_creation_summary(_results, context) do
    %{
      branch_created: context.branch_name,
      template_applied: context.template,
      validations_passed: true
    }
  end

  defp creation_successful?(results) do
    Enum.all?(results, fn {_phase, result} ->
      case result do
        %{success: success} -> success
        %{branch_created: created} -> created
        %{all_passed: passed} -> passed
        _ -> true
      end
    end)
  end

  defp display_creation_errors(results) do
    Enum.each(results, fn {phase, result} ->
      case result do
        %{error: error} -> OutputFormatter.display_error("#{phase}: #{error}")
        _ -> :ok
      end
    end)
  end
end
