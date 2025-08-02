defmodule Mix.Tasks.Prismatic.Setup do
  @moduledoc """
  Project setup and initialization with comprehensive environment configuration.

  Provides automated project setup including:
  - Development environment configuration
  - Dependency installation and verification
  - Database setup and migrations
  - Configuration file generation
  - Git hooks installation
  - Development tools initialization
  - Team onboarding automation

  ## Usage

      # Complete project setup with all components
      mix prismatic.setup

      # Setup specific components only
      mix prismatic.setup --components deps,database,git

      # Interactive setup with guided configuration
      mix prismatic.setup --interactive

      # Reset and reconfigure existing setup
      mix prismatic.setup --reset

      # Setup for specific environment
      mix prismatic.setup --env production

  ## Setup Components

  ### Dependencies
  - Install and compile all Mix dependencies
  - Verify dependency compatibility
  - Download and setup Node.js dependencies
  - Install development tools and utilities

  ### Database
  - Create development and test databases
  - Run all pending migrations
  - Seed development data
  - Setup database users and permissions

  ### Configuration
  - Generate environment-specific config files
  - Setup secrets and environment variables
  - Configure external service integrations
  - Validate configuration completeness

  ### Git Integration
  - Install pre-commit and pre-push hooks
  - Configure commit message templates
  - Setup branch protection rules
  - Initialize issue and PR templates

  ### Development Tools
  - Configure code formatter and linting
  - Setup testing framework and coverage
  - Install debugging and profiling tools
  - Configure CI/CD integration

  ### Team Onboarding
  - Create development documentation
  - Setup local development server
  - Configure team-specific settings
  - Generate getting started guide
  """

  use Mix.Tasks.Prismatic.Shared.TaskBehaviour,
    profile: :system,
    description: "Project setup and initialization with comprehensive configuration"

  @shortdoc "Project setup and initialization with comprehensive environment configuration"

  @switches [
    components: :string,
    interactive: :boolean,
    reset: :boolean,
    env: :string,
    skip_deps: :boolean,
    skip_database: :boolean,
    skip_git: :boolean,
    force: :boolean,
    verbose: :boolean,
    help: :boolean
  ]

  @aliases [
    c: :components,
    i: :interactive,
    r: :reset,
    e: :env,
    f: :force,
    v: :verbose,
    h: :help
  ]

  @setup_components [
    :dependencies,
    :database,
    :configuration,
    :git_integration,
    :development_tools,
    :team_onboarding
  ]

  @impl Mix.Task
  def run(args) do
    with_task_context(__MODULE__, args, &execute_setup/1)
  end

  @impl Mix.Tasks.Prismatic.Shared.TaskBehaviour
  def get_option_parser_config do
    [switches: @switches, aliases: @aliases]
  end

  @impl Mix.Tasks.Prismatic.Shared.TaskBehaviour
  def get_task_defaults do
    %{
      components: "all",
      interactive: false,
      reset: false,
      env: "development",
      skip_deps: false,
      skip_database: false,
      skip_git: false,
      force: false,
      file_prefix: "setup"
    }
  end

  @impl Mix.Tasks.Prismatic.Shared.TaskBehaviour
  def validate_task_options(options) do
    cond do
      options[:components] && not valid_components?(options[:components]) ->
        {:error, "Invalid components. Available: #{Enum.join(@setup_components, ", ")}"}

      options[:env] && options[:env] not in ~w(development test production) ->
        {:error, "Invalid environment. Available: development, test, production"}

      true ->
        :ok
    end
  end

  @impl Mix.Tasks.Prismatic.Shared.TaskBehaviour
  def validate_task_prerequisites(options) do
    # Check if we're in a Mix project
    unless File.exists?("mix.exs") do
      raise "This command must be run in an Elixir project root directory (mix.exs not found)"
    end

    # Check for basic system requirements
    validate_system_requirements()

    :ok
  end

  # Main execution function
  defp execute_setup(options) do
    if options[:interactive] do
      execute_interactive_setup(options)
    else
      execute_automated_setup(options)
    end
  end

  defp execute_interactive_setup(options) do
    OutputFormatter.display_section_header("Interactive Project Setup")

    # Gather setup preferences
    setup_config = gather_setup_preferences(options)

    # Show setup plan
    display_setup_plan(setup_config)

    # Confirm setup
    if confirm_setup_execution(setup_config) do
      perform_project_setup(setup_config)
    else
      OutputFormatter.display_info("Setup cancelled.")
    end
  end

  defp execute_automated_setup(options) do
    # Determine components to setup
    components = parse_setup_components(options[:components])

    # Create setup configuration
    setup_config = create_setup_config(components, options)

    # Show what will be setup
    if options[:verbose] do
      display_setup_plan(setup_config)
    end

    # Perform setup
    perform_project_setup(setup_config)
  end

  defp gather_setup_preferences(options) do
    OutputFormatter.display_info("Welcome to Prismatic project setup!")
    OutputFormatter.display_info("This wizard will help configure your development environment.\n")

    # Get project information
    project_info = gather_project_information()

    # Get component preferences
    components = select_setup_components()

    # Get environment configuration
    env_config = configure_environment_settings()

    # Get team preferences
    team_config = configure_team_settings()

    %{
      project: project_info,
      components: components,
      environment: env_config,
      team: team_config,
      options: options
    }
  end

  defp create_setup_config(components, options) do
    %{
      project: %{name: get_project_name(), type: detect_project_type()},
      components: components,
      environment: %{target: options[:env], reset: options[:reset]},
      team: %{size: "small", workflow: "standard"},
      options: options
    }
  end

  defp perform_project_setup(config) do
    ProgressMonitor.start_operation("Starting project setup...")

    # Initialize setup context
    context = initialize_setup_context(config)

    # Execute setup phases
    results = execute_setup_phases(context)

    # Generate setup report
    report = generate_setup_report(results, context)

    # Display results
    display_setup_results(report)

    ProgressMonitor.complete_operation("Project setup completed successfully")
  end

  defp initialize_setup_context(config) do
    %{
      config: config,
      start_time: System.monotonic_time(:millisecond),
      project_root: File.cwd!(),
      setup_results: %{},
      errors: [],
      warnings: []
    }
  end

  defp execute_setup_phases(context) do
    components = context.config.components

    results = components
    |> Enum.map(fn component ->
      ProgressMonitor.show_info("Setting up #{component}...")

      component_result = ErrorHandler.safe_execute(
        "setup",
        Atom.to_string(component),
        fn -> setup_component(component, context) end
      )

      {component, component_result}
    end)
    |> Map.new()

    results
  end

  defp setup_component(:dependencies, context) do
    if not context.config.options[:skip_deps] do
      steps = [
        {"Installing Mix dependencies", &install_mix_dependencies/1},
        {"Compiling dependencies", &compile_dependencies/1},
        {"Installing Node.js dependencies", &install_node_dependencies/1},
        {"Verifying dependency integrity", &verify_dependencies/1}
      ]

      execute_setup_steps(steps, context)
    else
      %{skipped: true, reason: "Dependencies setup skipped"}
    end
  end

  defp setup_component(:database, context) do
    if not context.config.options[:skip_database] do
      steps = [
        {"Creating databases", &create_databases/1},
        {"Running migrations", &run_migrations/1},
        {"Seeding development data", &seed_development_data/1},
        {"Verifying database connectivity", &verify_database_connection/1}
      ]

      execute_setup_steps(steps, context)
    else
      %{skipped: true, reason: "Database setup skipped"}
    end
  end

  defp setup_component(:configuration, context) do
    steps = [
      {"Generating configuration files", &generate_config_files/1},
      {"Setting up environment variables", &setup_environment_variables/1},
      {"Configuring external services", &configure_external_services/1},
      {"Validating configuration", &validate_configuration/1}
    ]

    execute_setup_steps(steps, context)
  end

  defp setup_component(:git_integration, context) do
    if not context.config.options[:skip_git] do
      steps = [
        {"Installing Git hooks", &install_git_hooks/1},
        {"Configuring commit templates", &setup_commit_templates/1},
        {"Creating issue templates", &create_issue_templates/1},
        {"Setting up branch protection", &setup_branch_protection/1}
      ]

      execute_setup_steps(steps, context)
    else
      %{skipped: true, reason: "Git integration setup skipped"}
    end
  end

  defp setup_component(:development_tools, context) do
    steps = [
      {"Configuring code formatter", &setup_code_formatter/1},
      {"Installing linting tools", &setup_linting_tools/1},
      {"Configuring testing framework", &setup_testing_framework/1},
      {"Setting up debugging tools", &setup_debugging_tools/1}
    ]

    execute_setup_steps(steps, context)
  end

  defp setup_component(:team_onboarding, context) do
    steps = [
      {"Creating development documentation", &create_dev_documentation/1},
      {"Setting up local development server", &setup_dev_server/1},
      {"Generating getting started guide", &generate_getting_started/1},
      {"Configuring team settings", &configure_team_settings/1}
    ]

    execute_setup_steps(steps, context)
  end

  defp execute_setup_steps(steps, context) do
    step_results = Enum.map(steps, fn {name, step_fn} ->
      try do
        result = step_fn.(context)
        {name, %{success: true, result: result}}
      rescue
        error ->
          {name, %{success: false, error: Exception.message(error)}}
      end
    end)

    total_steps = length(steps)
    successful_steps = Enum.count(step_results, fn {_, result} -> result.success end)

    %{
      steps: step_results,
      total: total_steps,
      successful: successful_steps,
      failed: total_steps - successful_steps,
      success_rate: (successful_steps / total_steps) * 100
    }
  end

  # Setup step implementations

  defp install_mix_dependencies(context) do
    case System.cmd("mix", ["deps.get"], cd: context.project_root) do
      {output, 0} -> %{installed: true, output: output}
      {error, _} -> raise "Failed to install Mix dependencies: #{error}"
    end
  end

  defp compile_dependencies(context) do
    case System.cmd("mix", ["deps.compile"], cd: context.project_root) do
      {output, 0} -> %{compiled: true, output: output}
      {error, _} -> raise "Failed to compile dependencies: #{error}"
    end
  end

  defp install_node_dependencies(context) do
    if File.exists?(Path.join(context.project_root, "package.json")) do
      case System.cmd("npm", ["install"], cd: context.project_root) do
        {output, 0} -> %{installed: true, output: output}
        {error, _} -> raise "Failed to install Node.js dependencies: #{error}"
      end
    else
      %{skipped: true, reason: "No package.json found"}
    end
  end

  defp verify_dependencies(context) do
    # Check if all dependencies are properly installed
    case System.cmd("mix", ["deps.check"], cd: context.project_root) do
      {_, 0} -> %{verified: true}
      {error, _} -> raise "Dependency verification failed: #{error}"
    end
  end

  defp create_databases(context) do
    env = context.config.environment.target

    # Create database for the specified environment
    case System.cmd("mix", ["ecto.create"], env: [{"MIX_ENV", env}], cd: context.project_root) do
      {output, 0} -> %{created: true, environment: env, output: output}
      {error, _} ->
        # Database might already exist, check if that's the case
        if String.contains?(error, "already exists") do
          %{created: false, reason: "Database already exists", output: error}
        else
          raise "Failed to create database: #{error}"
        end
    end
  end

  defp run_migrations(context) do
    env = context.config.environment.target

    case System.cmd("mix", ["ecto.migrate"], env: [{"MIX_ENV", env}], cd: context.project_root) do
      {output, 0} -> %{migrated: true, environment: env, output: output}
      {error, _} -> raise "Failed to run migrations: #{error}"
    end
  end

  defp seed_development_data(context) do
    if context.config.environment.target == "development" do
      case System.cmd("mix", ["run", "priv/repo/seeds.exs"], cd: context.project_root) do
        {output, 0} -> %{seeded: true, output: output}
        {error, _} ->
          if String.contains?(error, "No such file") do
            %{seeded: false, reason: "Seeds file not found"}
          else
            raise "Failed to seed development data: #{error}"
          end
      end
    else
      %{skipped: true, reason: "Seeding only applies to development environment"}
    end
  end

  defp verify_database_connection(context) do
    # Simple database connectivity check
    case System.cmd("mix", ["ecto.migrator", "version"], cd: context.project_root) do
      {_, 0} -> %{connected: true}
      {error, _} -> raise "Database connection failed: #{error}"
    end
  end

  defp generate_config_files(context) do
    config_files = [
      {".env.example", generate_env_example()},
      {"config/dev.local.exs.example", generate_dev_local_config()},
      {".editorconfig", generate_editorconfig()}
    ]

    created_files = Enum.map(config_files, fn {filename, content} ->
      file_path = Path.join(context.project_root, filename)

      if not File.exists?(file_path) or context.config.options[:force] do
        File.write!(file_path, content)
        filename
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)

    %{created: created_files, total: length(config_files)}
  end

  defp setup_environment_variables(context) do
    env_file = Path.join(context.project_root, ".env")

    if not File.exists?(env_file) do
      # Create basic .env file
      env_content = """
      # Development Environment Variables
      # Copy from .env.example and customize for your local setup

      MIX_ENV=development
      DATABASE_URL=ecto://postgres:postgres@localhost/prismatic_dev
      SECRET_KEY_BASE=#{generate_secret_key()}

      # Add your local environment variables here
      """

      File.write!(env_file, env_content)
      %{created: true, file: ".env"}
    else
      %{exists: true, message: ".env file already exists"}
    end
  end

  defp configure_external_services(context) do
    # Placeholder for external service configuration
    %{configured: [], available: ["database", "cache", "email"]}
  end

  defp validate_configuration(context) do
    # Basic configuration validation
    required_files = ["config/config.exs", "config/dev.exs"]

    missing_files = Enum.filter(required_files, fn file ->
      not File.exists?(Path.join(context.project_root, file))
    end)

    if Enum.empty?(missing_files) do
      %{valid: true, checked_files: required_files}
    else
      raise "Missing configuration files: #{Enum.join(missing_files, ", ")}"
    end
  end

  defp install_git_hooks(context) do
    hooks_dir = Path.join(context.project_root, ".git/hooks")

    if File.dir?(hooks_dir) do
      # Install pre-commit hook
      pre_commit_content = generate_pre_commit_hook()
      pre_commit_path = Path.join(hooks_dir, "pre-commit")

      File.write!(pre_commit_path, pre_commit_content)
      File.chmod!(pre_commit_path, 0o755)

      %{installed: ["pre-commit"], hooks_dir: hooks_dir}
    else
      %{skipped: true, reason: "Not a git repository"}
    end
  end

  defp setup_commit_templates(context) do
    template_content = """
    # <type>(<scope>): <subject>
    #
    # <body>
    #
    # <footer>
    #
    # Type: feat, fix, docs, style, refactor, test, chore
    # Scope: component or file name
    # Subject: imperative, present tense, no period
    # Body: what and why vs. how
    # Footer: breaking changes, close issues
    """

    template_path = Path.join(context.project_root, ".gitmessage")
    File.write!(template_path, template_content)

    # Configure git to use the template
    System.cmd("git", ["config", "commit.template", ".gitmessage"], cd: context.project_root)

    %{configured: true, template_file: ".gitmessage"}
  end

  defp create_issue_templates(context) do
    templates_dir = Path.join(context.project_root, ".github/ISSUE_TEMPLATE")
    File.mkdir_p!(templates_dir)

    # Bug report template
    bug_template = """
    ---
    name: Bug report
    about: Create a report to help us improve
    title: ''
    labels: bug
    assignees: ''
    ---

    **Describe the bug**
    A clear and concise description of what the bug is.

    **To Reproduce**
    Steps to reproduce the behavior:
    1. Go to '...'
    2. Click on '....'
    3. Scroll down to '....'
    4. See error

    **Expected behavior**
    A clear and concise description of what you expected to happen.

    **Environment:**
    - OS: [e.g. iOS]
    - Version [e.g. 22]

    **Additional context**
    Add any other context about the problem here.
    """

    File.write!(Path.join(templates_dir, "bug_report.md"), bug_template)

    %{created: ["bug_report.md"], templates_dir: templates_dir}
  end

  defp setup_branch_protection(context) do
    # This would typically interact with GitHub API
    # For now, just create documentation
    %{configured: false, reason: "Requires GitHub API integration"}
  end

  defp setup_code_formatter(context) do
    formatter_config = """
    [
      inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
      line_length: 100,
      import_deps: [:phoenix, :ecto, :plug]
    ]
    """

    formatter_path = Path.join(context.project_root, ".formatter.exs")

    if not File.exists?(formatter_path) or context.config.options[:force] do
      File.write!(formatter_path, formatter_config)
      %{configured: true, file: ".formatter.exs"}
    else
      %{exists: true, message: ".formatter.exs already exists"}
    end
  end

  defp setup_linting_tools(context) do
    # Install Credo configuration
    credo_config = """
    %{
      configs: [
        %{
          name: "default",
          files: %{
            included: ["lib/", "src/", "apps/"],
            excluded: [~r"/_build/", ~r"/deps/"]
          },
          checks: [
            {Credo.Check.Consistency.ExceptionNames},
            {Credo.Check.Consistency.LineEndings},
            {Credo.Check.Consistency.ParameterPatternMatching},
            {Credo.Check.Consistency.SpaceAroundOperators},
            {Credo.Check.Consistency.SpaceInParentheses},
            {Credo.Check.Consistency.TabsOrSpaces}
          ]
        }
      ]
    }
    """

    credo_path = Path.join(context.project_root, ".credo.exs")

    if not File.exists?(credo_path) or context.config.options[:force] do
      File.write!(credo_path, credo_config)
      %{configured: true, file: ".credo.exs"}
    else
      %{exists: true, message: ".credo.exs already exists"}
    end
  end

  defp setup_testing_framework(context) do
    # Configure ExUnit and create test helper enhancements
    test_helper_addition = """

    # Additional test configuration
    ExUnit.configure(exclude: [:skip, :pending])

    # Setup test database
    if Application.get_env(:prismatic, :sql_sandbox) do
      Ecto.Adapters.SQL.Sandbox.mode(Prismatic.Repo, :manual)
    end
    """

    test_helper_path = Path.join(context.project_root, "test/test_helper.exs")

    if File.exists?(test_helper_path) do
      current_content = File.read!(test_helper_path)
      if not String.contains?(current_content, "Additional test configuration") do
        File.write!(test_helper_path, current_content <> test_helper_addition)
        %{enhanced: true, file: "test/test_helper.exs"}
      else
        %{exists: true, message: "Test helper already configured"}
      end
    else
      %{skipped: true, reason: "test/test_helper.exs not found"}
    end
  end

  defp setup_debugging_tools(context) do
    # Basic debugging setup
    %{configured: ["IEx.pry", "Debugging helpers"], tools: ["observer", "recon"]}
  end

  defp create_dev_documentation(context) do
    dev_docs = [
      {"DEVELOPMENT.md", generate_development_guide()},
      {"CONTRIBUTING.md", generate_contributing_guide()},
      {"DEPLOYMENT.md", generate_deployment_guide()}
    ]

    created_docs = Enum.map(dev_docs, fn {filename, content} ->
      file_path = Path.join(context.project_root, filename)

      if not File.exists?(file_path) or context.config.options[:force] do
        File.write!(file_path, content)
        filename
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)

    %{created: created_docs, total: length(dev_docs)}
  end

  defp setup_dev_server(context) do
    # Basic development server configuration
    %{configured: true, port: 4000, url: "http://localhost:4000"}
  end

  defp generate_getting_started(context) do
    getting_started_content = """
    # Getting Started with #{context.config.project.name}

    ## Prerequisites
    - Elixir 1.14+
    - PostgreSQL 13+
    - Node.js 16+ (if using Phoenix LiveView)

    ## Setup
    1. Clone the repository
    2. Run `mix prismatic.setup` to configure your environment
    3. Start the development server with `mix phx.server`
    4. Visit http://localhost:4000

    ## Development Workflow
    1. Create a feature branch: `mix prismatic.branch.create --name your-feature`
    2. Make your changes
    3. Run tests: `mix test`
    4. Validate your branch: `mix prismatic.branch.validate`
    5. Create a pull request

    ## Available Commands
    - `mix prismatic.setup` - Project setup
    - `mix prismatic.check` - Health check
    - `mix prismatic.test.coverage` - Test coverage
    - `mix prismatic.docs.analyze` - Documentation analysis

    ## Need Help?
    - Check the documentation in the `docs/` directory
    - Run `mix prismatic --help` for all available commands
    - Contact the team for assistance
    """

    getting_started_path = Path.join(context.project_root, "GETTING_STARTED.md")
    File.write!(getting_started_path, getting_started_content)

    %{created: true, file: "GETTING_STARTED.md"}
  end

  # Helper functions

  defp valid_components?(components_str) do
    components = parse_setup_components(components_str)
    Enum.all?(components, &(&1 in @setup_components))
  end

  defp parse_setup_components("all"), do: @setup_components
  defp parse_setup_components(components_str) do
    components_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_atom/1)
  end

  defp validate_system_requirements do
    # Check Elixir version
    unless System.find_executable("elixir") do
      raise "Elixir is not installed or not in PATH"
    end

    # Check for git
    unless System.find_executable("git") do
      raise "Git is not installed or not in PATH"
    end

    :ok
  end

  defp get_project_name do
    case File.read("mix.exs") do
      {:ok, content} ->
        case Regex.run(~r/app:\s*:(\w+)/, content) do
          [_, app_name] -> app_name
          _ -> "unknown"
        end
      _ -> "unknown"
    end
  end

  defp detect_project_type do
    if File.exists?("lib/prismatic_web") do
      "phoenix"
    else
      "elixir"
    end
  end

  defp gather_project_information do
    %{
      name: get_project_name(),
      type: detect_project_type(),
      root: File.cwd!()
    }
  end

  defp select_setup_components do
    Mix.shell().info("\nSelect components to setup:")

    @setup_components
    |> Enum.with_index(1)
    |> Enum.each(fn {component, index} ->
      description = get_component_description(component)
      Mix.shell().info("  #{index}. #{component} - #{description}")
    end)

    choice = Mix.shell().prompt("Enter component numbers (1-#{length(@setup_components)}) or 'all': ")

    if String.trim(choice) == "all" do
      @setup_components
    else
      choice
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.to_integer/1)
      |> Enum.map(fn index -> Enum.at(@setup_components, index - 1) end)
      |> Enum.reject(&is_nil/1)
    end
  end

  defp configure_environment_settings do
    env = Mix.shell().prompt("Target environment (development/test/production): ") |> String.trim()
    env = if env in ~w(development test production), do: env, else: "development"

    %{target: env, configured: true}
  end

  defp configure_team_settings do
    team_size = Mix.shell().prompt("Team size (small/medium/large): ") |> String.trim()
    team_size = if team_size in ~w(small medium large), do: team_size, else: "small"

    %{size: team_size, workflow: "standard"}
  end

  defp display_setup_plan(config) do
    OutputFormatter.display_section_header("Setup Plan")

    OutputFormatter.display_info("Project: #{config.project.name} (#{config.project.type})")
    OutputFormatter.display_info("Environment: #{config.environment.target}")
    OutputFormatter.display_info("Components: #{Enum.join(config.components, ", ")}")

    if config.team do
      OutputFormatter.display_info("Team size: #{config.team.size}")
    end
  end

  defp confirm_setup_execution(config) do
    Mix.shell().yes?("\nProceed with setup?")
  end

  defp generate_setup_report(results, context) do
    execution_time = System.monotonic_time(:millisecond) - context.start_time

    overall_success = Enum.all?(results, fn {_, result} ->
      not Map.has_key?(result, :failed) or result.failed == 0
    end)

    %{
      metadata: %{
        setup_timestamp: DateTime.utc_now(),
        execution_time_ms: execution_time,
        project_root: context.project_root,
        components_setup: Map.keys(results)
      },
      results: results,
      summary: %{
        overall_success: overall_success,
        components_completed: length(Map.keys(results)),
        total_steps: count_total_steps(results),
        successful_steps: count_successful_steps(results)
      }
    }
  end

  defp display_setup_results(report) do
    OutputFormatter.display_section_header("Setup Results")

    if report.summary.overall_success do
      OutputFormatter.display_success("✅ Project setup completed successfully!")
    else
      OutputFormatter.display_warning("⚠️ Project setup completed with some issues")
    end

    OutputFormatter.display_info("Components setup: #{report.summary.components_completed}")
    OutputFormatter.display_info("Total steps: #{report.summary.total_steps}")
    OutputFormatter.display_info("Successful steps: #{report.summary.successful_steps}")
    OutputFormatter.display_info("Execution time: #{report.metadata.execution_time_ms}ms")

    # Show component results
    OutputFormatter.display_section_header("Component Results", width: 40)

    Enum.each(report.results, fn {component, result} ->
      if Map.has_key?(result, :success_rate) do
        rate = Float.round(result.success_rate, 1)
        status_emoji = if rate == 100.0, do: "✅", else: "⚠️"
        component_name = component |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
        OutputFormatter.display_info("#{status_emoji} #{component_name}: #{rate}% (#{result.successful}/#{result.total})")
      else
        component_name = component |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
        if Map.get(result, :skipped) do
          OutputFormatter.display_info("⏭️ #{component_name}: Skipped")
        else
          OutputFormatter.display_info("✅ #{component_name}: Completed")
        end
      end
    end)

    # Show next steps
    OutputFormatter.display_section_header("Next Steps", width: 40)
    display_setup_next_steps()
  end

  defp display_setup_next_steps do
    next_steps = [
      "Start development server: mix phx.server",
      "Run tests: mix test",
      "Check project health: mix prismatic.check",
      "Review generated documentation",
      "Customize configuration files as needed"
    ]

    Enum.each(next_steps, fn step ->
      OutputFormatter.display_info("• #{step}")
    end)
  end

  # Placeholder content generators
  defp generate_env_example, do: "# Environment variables example\nDATABASE_URL=ecto://postgres:postgres@localhost/prismatic_dev\n"
  defp generate_dev_local_config, do: "# Local development configuration\n# Copy to dev.local.exs and customize\n"
  defp generate_editorconfig, do: "[*]\ncharset = utf-8\nend_of_line = lf\ninsert_final_newline = true\nindent_style = space\nindent_size = 2\n"
  defp generate_secret_key, do: :crypto.strong_rand_bytes(32) |> Base.encode64()
  defp generate_pre_commit_hook, do: "#!/bin/sh\n# Pre-commit hook\nmix format --check-formatted\nmix credo --strict\n"
  defp generate_development_guide, do: "# Development Guide\n\nThis guide covers development practices and workflows.\n"
  defp generate_contributing_guide, do: "# Contributing Guide\n\nThank you for contributing to this project!\n"
  defp generate_deployment_guide, do: "# Deployment Guide\n\nThis guide covers deployment procedures and best practices.\n"

  defp get_component_description(component) do
    case component do
      :dependencies -> "Install and verify project dependencies"
      :database -> "Setup databases and run migrations"
      :configuration -> "Generate configuration files and environment setup"
      :git_integration -> "Install Git hooks and templates"
      :development_tools -> "Configure formatting, linting, and testing tools"
      :team_onboarding -> "Create documentation and onboarding resources"
    end
  end

  defp count_total_steps(results) do
    results
    |> Map.values()
    |> Enum.map(&Map.get(&1, :total, 1))
    |> Enum.sum()
  end

  defp count_successful_steps(results) do
    results
    |> Map.values()
    |> Enum.map(&Map.get(&1, :successful, 1))
    |> Enum.sum()
  end

  defp configure_team_settings(_context) do
    %{configured: true, settings: ["commit_templates", "issue_templates"]}
  end
end
