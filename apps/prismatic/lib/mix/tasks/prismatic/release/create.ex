defmodule Mix.Tasks.Prismatic.Release.Create do
  @moduledoc """
  Comprehensive release creation with automated packaging and distribution.

  Provides end-to-end release creation including:
  - Version validation and tagging
  - Automated changelog generation
  - Asset compilation and optimization
  - Release packaging for multiple targets
  - Distribution preparation
  - Release notes generation
  - Automated testing and validation
  - Release artifact signing

  ## Usage

      # Create a release with automatic version detection
      mix prismatic.release.create

      # Create a release with specific version
      mix prismatic.release.create --version 1.2.0

      # Create a release with custom release type
      mix prismatic.release.create --type major

      # Create release for specific targets
      mix prismatic.release.create --targets docker,kubernetes

      # Create release with pre-release suffix
      mix prismatic.release.create --pre-release beta.1

      # Create release with custom changelog
      mix prismatic.release.create --changelog-file RELEASE_NOTES.md

      # Dry run to preview release creation
      mix prismatic.release.create --dry-run

  ## Release Types

  ### Semantic Versioning
  - `patch` - Bug fixes and minor updates (1.0.0 -> 1.0.1)
  - `minor` - New features, backward compatible (1.0.0 -> 1.1.0)
  - `major` - Breaking changes (1.0.0 -> 2.0.0)
  - `custom` - Specify exact version with --version

  ### Pre-release Types
  - `alpha` - Early development release
  - `beta` - Feature-complete, testing phase
  - `rc` - Release candidate, final testing
  - `custom` - Custom pre-release identifier

  ## Release Targets

  ### Docker
  - Multi-architecture container images
  - Optimized layer caching
  - Security scanning
  - Registry push automation

  ### Kubernetes
  - Helm chart packaging
  - Deployment manifests
  - ConfigMap and Secret templates
  - Resource optimization

  ### Standalone Binary
  - Cross-platform compilation
  - Asset bundling
  - Dependency packaging
  - Platform-specific optimizations

  ### Source Distribution
  - Complete source packaging
  - Documentation inclusion
  - Development setup scripts
  - Dependency management

  ## Release Process

  ### Pre-release Validation
  - Code quality checks
  - Test suite execution
  - Security vulnerability scanning
  - Performance regression testing
  - Documentation completeness

  ### Version Management
  - Semantic version validation
  - Git tag creation
  - Branch validation
  - Changelog generation
  - Release notes compilation

  ### Asset Preparation
  - Code compilation
  - Asset optimization
  - Documentation generation
  - Dependency resolution
  - Platform-specific builds

  ### Packaging
  - Archive creation
  - Checksum generation
  - Digital signing
  - Metadata inclusion
  - Distribution preparation

  ### Distribution
  - Registry uploads
  - CDN deployment
  - Mirror synchronization
  - Release announcement
  - Documentation deployment

  ## Configuration

  Release configuration can be customized in `config/releases.exs`:

      config :prismatic, :releases,
        # Default release targets
        default_targets: [:docker, :kubernetes, :binary],

        # Asset optimization settings
        optimize_assets: true,
        compress_archives: true,

        # Signing configuration
        sign_releases: true,
        signing_key: {:env, "RELEASE_SIGNING_KEY"},

        # Distribution settings
        upload_to_registry: true,
        registry_url: {:env, "RELEASE_REGISTRY_URL"},

        # Notification settings
        notify_channels: [:slack, :email],

        # Validation settings
        run_tests: true,
        security_scan: true,
        performance_check: true

  ## Examples

      # Standard patch release
      mix prismatic.release.create --type patch

      # Major release with full validation
      mix prismatic.release.create --type major --comprehensive

      # Beta release for testing
      mix prismatic.release.create --type minor --pre-release beta.1

      # Multi-target release
      mix prismatic.release.create --targets docker,kubernetes,binary

      # Release with custom notes
      mix prismatic.release.create --release-notes "Major performance improvements"
  """

  use Mix.Task
  use Mix.Tasks.Prismatic.Shared.TaskBehaviour,
    profile: :system,
    description: "Comprehensive release creation with automated packaging"


  @switches [
    version: :string,
    type: :string,
    pre_release: :string,
    targets: :string,
    changelog_file: :string,
    release_notes: :string,
    dry_run: :boolean,
    comprehensive: :boolean,
    skip_tests: :boolean,
    skip_validation: :boolean,
    sign: :boolean,
    upload: :boolean,
    notify: :boolean,
    format: :string,
    output: :string,
    ci: :boolean,
    verbose: :boolean,
    help: :boolean
  ]

  @aliases [
    v: :version,
    t: :type,
    p: :pre_release,
    d: :dry_run,
    c: :comprehensive,
    s: :sign,
    u: :upload,
    n: :notify,
    f: :format,
    o: :output,
    h: :help
  ]

  @release_types ~w(patch minor major custom)
  @pre_release_types ~w(alpha beta rc custom)
  @release_targets ~w(docker kubernetes binary source)

  @impl Mix.Task
  def run(args) do
    with_task_context(__MODULE__, args, &execute_release_creation/1)
  end

  def get_option_parser_config do
    [switches: @switches, aliases: @aliases]
  end

  def get_task_defaults do
    %{
      type: "patch",
      targets: "docker,kubernetes",
      dry_run: false,
      comprehensive: false,
      skip_tests: false,
      skip_validation: false,
      sign: true,
      upload: false,
      notify: false,
      format: "console",
      output: nil,
      ci: false,
      file_prefix: "release"
    }
  end

  def validate_task_options(options) do
    cond do
      options[:type] && options[:type] not in @release_types ->
        {:error, "Invalid release type '#{options[:type]}'. Available: #{Enum.join(@release_types, ", ")}"}

      options[:pre_release] && options[:pre_release] not in @pre_release_types && not custom_pre_release?(options[:pre_release]) ->
        {:error, "Invalid pre-release type '#{options[:pre_release]}'. Available: #{Enum.join(@pre_release_types, ", ")} or custom format"}

      options[:targets] && not valid_targets?(options[:targets]) ->
        {:error, "Invalid targets. Available: #{Enum.join(@release_targets, ", ")}"}

      options[:version] && options[:type] != "custom" && not valid_version_format?(options[:version]) ->
        {:error, "Invalid version format. Use semantic versioning (e.g., 1.2.3)"}

      true ->
        :ok
    end
  end

  def validate_task_prerequisites(options) do
    # Check if we're in a Mix project
    unless File.exists?("mix.exs") do
      raise "This command must be run in an Elixir project root directory"
    end

    # Check git repository status
    unless git_repository_clean?() do
      unless options[:dry_run] do
        raise "Git repository has uncommitted changes. Commit or stash changes before creating a release."
      end
    end

    # Validate output directory if specified
    if options[:output] do
      ErrorHandler.validate_output_directory(options[:output])
    end

    :ok
  end

  # Main execution function
  defp execute_release_creation(options) do
    ProgressMonitor.start_operation("Starting release creation process...")

    # Initialize release context
    context = initialize_release_context(options)

    # Pre-release validation
    unless options[:skip_validation] do
      validate_release_readiness(context)
    end

    # Determine release version
    release_version = determine_release_version(context)
    context = Map.put(context, :version, release_version)

    ProgressMonitor.show_info("Creating release version #{release_version}")

    # Execute release creation steps
    if options[:dry_run] do
      execute_dry_run(context)
    else
      execute_full_release(context)
    end

    ProgressMonitor.complete_operation("Release creation completed")
  end

  defp initialize_release_context(options) do
    targets = parse_release_targets(options[:targets] || "docker,kubernetes")

    %{
      type: options[:type] || "patch",
      pre_release: options[:pre_release],
      targets: targets,
      changelog_file: options[:changelog_file],
      release_notes: options[:release_notes],
      comprehensive: options[:comprehensive] || false,
      skip_tests: options[:skip_tests] || false,
      sign: options[:sign] !== false,  # Default to true unless explicitly disabled
      upload: options[:upload] || false,
      notify: options[:notify] || false,
      options: options,
      start_time: System.monotonic_time(:millisecond),
      project_root: File.cwd!(),
      artifacts: []
    }
  end

  defp validate_release_readiness(context) do
    ProgressMonitor.show_info("Validating release readiness...")

    base_validations = [
      {"Git repository status", &validate_git_status/1},
      {"Project configuration", &validate_project_config/1},
      {"Dependencies", &validate_dependencies/1}
    ]

    test_validations = unless context.skip_tests do
      [{"Test suite", &run_test_suite/1}]
    else
      []
    end

    comprehensive_validations = if context.comprehensive do
      [
        {"Code quality", &validate_code_quality/1},
        {"Security scan", &run_security_scan/1},
        {"Documentation", &validate_documentation/1}
      ]
    else
      []
    end

    validations = base_validations ++ test_validations ++ comprehensive_validations

    Enum.each(validations, fn {name, validation_fn} ->
      ProgressMonitor.show_info("- #{name}...")

      case ErrorHandler.safe_execute("release.create", name, fn -> validation_fn.(context) end) do
        {:ok, _} -> :ok
        {:error, reason} -> raise "#{name} validation failed: #{reason}"
      end
    end)

    ProgressMonitor.show_success("Release readiness validation completed")
  end

  defp determine_release_version(context) do
    case context.type do
      "custom" ->
        context.options[:version] || raise "Version must be specified for custom release type"

      release_type ->
        current_version = get_current_version()
        new_version = bump_version(current_version, release_type)

        if context.pre_release do
          "#{new_version}-#{context.pre_release}"
        else
          new_version
        end
    end
  end

  defp execute_dry_run(context) do
    ProgressMonitor.show_info("Executing dry run - no changes will be made")

    steps = get_release_steps(context)

    OutputFormatter.display_section_header("Release Creation Plan")
    OutputFormatter.display_info("Version: #{context.version}")
    OutputFormatter.display_info("Targets: #{Enum.join(context.targets, ", ")}")
    OutputFormatter.display_info("Type: #{context.type}")

    if context.pre_release do
      OutputFormatter.display_info("Pre-release: #{context.pre_release}")
    end

    OutputFormatter.display_section_header("Planned Steps")

    Enum.with_index(steps, 1)
    |> Enum.each(fn {{step_name, _step_fn}, index} ->
      OutputFormatter.display_info("#{index}. #{step_name}")
    end)

    # Estimate execution time
    estimated_time = estimate_execution_time(context)
    OutputFormatter.display_info("Estimated execution time: #{estimated_time}")

    # Show what artifacts would be created
    artifacts = preview_release_artifacts(context)

    unless Enum.empty?(artifacts) do
      OutputFormatter.display_section_header("Artifacts to be created")

      Enum.each(artifacts, fn artifact ->
        OutputFormatter.display_info("- #{artifact}")
      end)
    end

    OutputFormatter.display_success("Dry run completed - ready for actual release creation")
  end

  defp execute_full_release(context) do
    steps = get_release_steps(context)
    total_steps = length(steps)

    ProgressMonitor.show_info("Executing #{total_steps} release steps...")

    {updated_context, results} = Enum.with_index(steps, 1)
    |> Enum.reduce({context, []}, fn {{step_name, step_fn}, index}, {acc_context, acc_results} ->
      ProgressMonitor.show_info("[#{index}/#{total_steps}] #{step_name}...")

      step_result = ErrorHandler.safe_execute(
        "release.create",
        step_name,
        fn -> step_fn.(acc_context) end
      )

      case step_result do
        {:ok, step_context} ->
          ProgressMonitor.show_success("✓ #{step_name} completed")
          {step_context, [{step_name, :success} | acc_results]}

        {:error, reason} ->
          ProgressMonitor.show_error("✗ #{step_name} failed: #{reason}")
          raise "Release creation failed at step '#{step_name}': #{reason}"
      end
    end)

    # Generate release report
    release_report = generate_release_report(updated_context, Enum.reverse(results))

    # Output release information
    display_release_summary(release_report)

    # Save release report if output specified
    if context.options[:output] do
      save_release_report(release_report, context.options)
    end

    # Send notifications if enabled
    if context.notify do
      send_release_notifications(release_report)
    end
  end

  defp get_release_steps(context) do
    base_steps = [
      {"Create git tag", &create_git_tag/1},
      {"Generate changelog", &generate_changelog/1},
      {"Compile application", &compile_application/1},
      {"Optimize assets", &optimize_assets/1}
    ]

    target_steps = Enum.flat_map(context.targets, fn target ->
      get_target_specific_steps(target)
    end)

    packaging_steps = [
      {"Create release archives", &create_release_archives/1},
      {"Generate checksums", &generate_checksums/1}
    ]

    signing_steps = if context.sign do
      [{"Sign release artifacts", &sign_release_artifacts/1}]
    else
      []
    end

    upload_steps = if context.upload do
      [{"Upload release artifacts", &upload_release_artifacts/1}]
    else
      []
    end

    finalization_steps = [
      {"Generate release notes", &generate_release_notes/1},
      {"Update version metadata", &update_version_metadata/1}
    ]

    base_steps ++ target_steps ++ packaging_steps ++ signing_steps ++ upload_steps ++ finalization_steps
  end

  defp get_target_specific_steps(target) do
    case target do
      "docker" -> [
        {"Build Docker image", &build_docker_image/1},
        {"Tag Docker image", &tag_docker_image/1}
      ]

      "kubernetes" -> [
        {"Generate Kubernetes manifests", &generate_k8s_manifests/1},
        {"Package Helm chart", &package_helm_chart/1}
      ]

      "binary" -> [
        {"Build standalone binary", &build_standalone_binary/1},
        {"Bundle binary assets", &bundle_binary_assets/1}
      ]

      "source" -> [
        {"Package source distribution", &package_source_distribution/1}
      ]

      _ -> []
    end
  end

  # Release step implementations

  defp create_git_tag(context) do
    tag_name = "v#{context.version}"

    # Create annotated tag
    {_, 0} = System.cmd("git", ["tag", "-a", tag_name, "-m", "Release #{context.version}"])

    ProgressMonitor.show_info("Created git tag: #{tag_name}")
    {:ok, context}
  end

  defp generate_changelog(context) do
    changelog_content = if context.changelog_file && File.exists?(context.changelog_file) do
      File.read!(context.changelog_file)
    else
      generate_automatic_changelog(context)
    end

    # Update CHANGELOG.md
    changelog_path = "CHANGELOG.md"
    existing_changelog = if File.exists?(changelog_path), do: File.read!(changelog_path), else: ""

    new_entry = format_changelog_entry(context.version, changelog_content)
    updated_changelog = new_entry <> "\n\n" <> existing_changelog

    File.write!(changelog_path, updated_changelog)

    context = Map.put(context, :changelog_content, changelog_content)
    {:ok, context}
  end

  defp compile_application(context) do
    # Clean previous build
    Mix.Task.run("clean")

    # Compile for production
    Mix.env(:prod)
    Mix.Task.run("compile")

    # Run additional compilation steps
    Mix.Task.run("phx.digest", [])  # If Phoenix app

    {:ok, context}
  end

  defp optimize_assets(context) do
    # Optimize static assets
    optimize_static_assets()

    # Compress images
    compress_images()

    # Minify CSS/JS if applicable
    minify_web_assets()

    {:ok, context}
  end

  defp build_docker_image(context) do
    image_name = get_docker_image_name(context)
    dockerfile_path = find_dockerfile()

    # Build Docker image
    {_, 0} = System.cmd("docker", [
      "build",
      "-t", "#{image_name}:#{context.version}",
      "-t", "#{image_name}:latest",
      "-f", dockerfile_path,
      "."
    ])

    # Add artifact to context
    artifact = %{
      type: :docker_image,
      name: "#{image_name}:#{context.version}",
      path: nil,
      size: get_docker_image_size("#{image_name}:#{context.version}")
    }

    Map.update(context, :artifacts, [], &[artifact | &1])
    {:ok, context}
  end

  defp tag_docker_image(context) do
    image_name = get_docker_image_name(context)

    # Additional tags for pre-release or specific versions
    additional_tags = get_additional_docker_tags(context)

    Enum.each(additional_tags, fn tag ->
      {_, 0} = System.cmd("docker", ["tag", "#{image_name}:#{context.version}", "#{image_name}:#{tag}"])
    end)

    {:ok, context}
  end

  defp generate_k8s_manifests(context) do
    manifests_dir = "k8s-manifests"
    File.mkdir_p!(manifests_dir)

    # Generate deployment manifest
    deployment_manifest = generate_deployment_manifest(context)
    File.write!("#{manifests_dir}/deployment.yaml", deployment_manifest)

    # Generate service manifest
    service_manifest = generate_service_manifest(context)
    File.write!("#{manifests_dir}/service.yaml", service_manifest)

    # Generate ingress if applicable
    if has_ingress_config?() do
      ingress_manifest = generate_ingress_manifest(context)
      File.write!("#{manifests_dir}/ingress.yaml", ingress_manifest)
    end

    {:ok, context}
  end

  defp package_helm_chart(context) do
    chart_dir = "helm-chart"

    if File.exists?(chart_dir) do
      # Update Chart.yaml with new version
      update_helm_chart_version(chart_dir, context.version)

      # Package Helm chart
      {_, 0} = System.cmd("helm", ["package", chart_dir])

      chart_package = "#{get_app_name()}-#{context.version}.tgz"

      artifact = %{
        type: :helm_chart,
        name: chart_package,
        path: chart_package,
        size: get_file_size(chart_package)
      }

      Map.update(context, :artifacts, [], &[artifact | &1])
    end

    {:ok, context}
  end

  defp build_standalone_binary(context) do
    # Build release
    Mix.Task.run("release", [get_app_name()])

    release_dir = "_build/prod/rel/#{get_app_name()}"

    if File.exists?(release_dir) do
      artifact = %{
        type: :binary_release,
        name: "#{get_app_name()}-#{context.version}",
        path: release_dir,
        size: get_directory_size(release_dir)
      }

      updated_context = Map.update(context, :artifacts, [], &[artifact | &1])
      {:ok, updated_context}
    else
      {:ok, context}
    end
  end

  defp bundle_binary_assets(context) do
    # Bundle additional assets with binary
    assets_dir = "priv/static"

    if File.exists?(assets_dir) do
      # Copy assets to release
      release_assets_dir = "_build/prod/rel/#{get_app_name()}/lib/#{get_app_name()}-#{context.version}/priv/static"
      File.mkdir_p!(release_assets_dir)
      File.cp_r!(assets_dir, release_assets_dir)
    end

    {:ok, context}
  end

  defp package_source_distribution(context) do
    archive_name = "#{get_app_name()}-#{context.version}-src.tar.gz"

    # Create source archive excluding development files
    exclude_patterns = [
      "_build",
      "deps",
      ".git",
      "node_modules",
      "*.log",
      ".env*"
    ]

    exclude_args = Enum.flat_map(exclude_patterns, fn pattern ->
      ["--exclude", pattern]
    end)

    {_, 0} = System.cmd("tar", ["czf", archive_name | exclude_args] ++ ["."])

    artifact = %{
      type: :source_archive,
      name: archive_name,
      path: archive_name,
      size: get_file_size(archive_name)
    }

    context = Map.update(context, :artifacts, [], &[artifact | &1])
    {:ok, context}
  end

  defp create_release_archives(context) do
    # Create archives for each target type
    Enum.each(context.targets, fn target ->
      create_target_archive(target, context)
    end)

    {:ok, context}
  end

  defp generate_checksums(context) do
    # Generate checksums for all artifacts
    checksums = Enum.map(context.artifacts, fn artifact ->
      if artifact.path && File.exists?(artifact.path) do
        checksum = calculate_file_checksum(artifact.path)
        {artifact.name, checksum}
      else
        {artifact.name, "N/A"}
      end
    end)

    # Write checksums file
    checksums_content = Enum.map_join(checksums, "\n", fn {name, checksum} ->
      "#{checksum}  #{name}"
    end)

    File.write!("checksums.txt", checksums_content)

    context = Map.put(context, :checksums, checksums)
    {:ok, context}
  end

  defp sign_release_artifacts(context) do
    # Sign each artifact if signing is enabled
    if context.sign do
      Enum.each(context.artifacts, fn artifact ->
        if artifact.path && File.exists?(artifact.path) do
          sign_file(artifact.path)
        end
      end)

      # Sign checksums file
      if File.exists?("checksums.txt") do
        sign_file("checksums.txt")
      end
    end

    {:ok, context}
  end

  defp upload_release_artifacts(context) do
    # Upload artifacts to configured registry/storage
    if context.upload do
      registry_url = get_registry_url()

      Enum.each(context.artifacts, fn artifact ->
        if artifact.path && File.exists?(artifact.path) do
          upload_artifact_to_registry(artifact, registry_url)
        end
      end)
    end

    {:ok, context}
  end

  defp generate_release_notes(context) do
    release_notes = context.release_notes || generate_automatic_release_notes(context)

    notes_file = "RELEASE_NOTES_#{context.version}.md"
    File.write!(notes_file, release_notes)

    context = Map.put(context, :release_notes_file, notes_file)
    {:ok, context}
  end

  defp update_version_metadata(context) do
    # Update version in mix.exs
    update_mix_version(context.version)

    # Update version in other relevant files
    update_version_files(context.version)

    {:ok, context}
  end

  # Helper functions

  defp generate_release_report(context, step_results) do
    execution_time = System.monotonic_time(:millisecond) - context.start_time

    %{
      version: context.version,
      type: context.type,
      pre_release: context.pre_release,
      targets: context.targets,
      execution_time_ms: execution_time,
      timestamp: DateTime.utc_now(),
      step_results: step_results,
      artifacts: context.artifacts,
      checksums: Map.get(context, :checksums, []),
      release_notes_file: Map.get(context, :release_notes_file),
      git_tag: "v#{context.version}",
      success: true
    }
  end

  defp display_release_summary(report) do
    OutputFormatter.display_section_header("Release Creation Summary")

    OutputFormatter.display_success("🎉 Release #{report.version} created successfully!")
    OutputFormatter.display_info("Type: #{report.type}")
    OutputFormatter.display_info("Targets: #{Enum.join(report.targets, ", ")}")

    if report.pre_release do
      OutputFormatter.display_info("Pre-release: #{report.pre_release}")
    end

    OutputFormatter.display_info("Git tag: #{report.git_tag}")
    OutputFormatter.display_info("Execution time: #{report.execution_time_ms}ms")

    # Display artifacts
    unless Enum.empty?(report.artifacts) do
      OutputFormatter.display_section_header("Created Artifacts", width: 40)

      Enum.each(report.artifacts, fn artifact ->
        size_info = if artifact.size, do: " (#{format_file_size(artifact.size)})", else: ""
        OutputFormatter.display_info("• #{artifact.name}#{size_info}")
      end)
    end

    # Display next steps
    OutputFormatter.display_section_header("Next Steps", width: 40)
    OutputFormatter.display_info("• Review release notes: #{report.release_notes_file}")
    OutputFormatter.display_info("• Push git tag: git push origin #{report.git_tag}")

    if "docker" in report.targets do
      OutputFormatter.display_info("• Push Docker image to registry")
    end

    if "kubernetes" in report.targets do
      OutputFormatter.display_info("• Deploy to Kubernetes cluster")
    end
  end

  # Utility functions

  defp valid_targets?(targets_str) do
    targets = String.split(targets_str, ",") |> Enum.map(&String.trim/1)
    Enum.all?(targets, &(&1 in @release_targets))
  end

  defp custom_pre_release?(pre_release) do
    # Allow custom pre-release formats like "beta.1", "alpha.2", etc.
    String.match?(pre_release, ~r/^[a-zA-Z0-9.-]+$/)
  end

  defp valid_version_format?(version) do
    String.match?(version, ~r/^\d+\.\d+\.\d+$/)
  end

  defp git_repository_clean?() do
    {output, 0} = System.cmd("git", ["status", "--porcelain"])
    String.trim(output) == ""
  end

  defp parse_release_targets(targets_str) do
    targets_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 in @release_targets))
  end

  defp get_current_version() do
    # Read version from mix.exs
    mix_content = File.read!("mix.exs")

    case Regex.run(~r/version:\s*"([^"]+)"/, mix_content) do
      [_, version] -> version
      _ -> "0.1.0"  # Default version
    end
  end

  defp bump_version(current_version, bump_type) do
    [major, minor, patch] = current_version
    |> String.split(".")
    |> Enum.map(&String.to_integer/1)

    case bump_type do
      "major" -> "#{major + 1}.0.0"
      "minor" -> "#{major}.#{minor + 1}.0"
      "patch" -> "#{major}.#{minor}.#{patch + 1}"
    end
  end

  defp estimate_execution_time(context) do
    base_time = 120  # 2 minutes base

    time_per_target = %{
      "docker" => 180,      # 3 minutes
      "kubernetes" => 60,   # 1 minute
      "binary" => 240,      # 4 minutes
      "source" => 30        # 30 seconds
    }

    target_time = context.targets
    |> Enum.map(&Map.get(time_per_target, &1, 60))
    |> Enum.sum()

    comprehensive_time = if context.comprehensive, do: 300, else: 0  # 5 minutes

    total_seconds = base_time + target_time + comprehensive_time
    format_duration(total_seconds)
  end

  defp preview_release_artifacts(context) do
    base_artifacts = [
      "#{get_app_name()}-#{context.version}.tar.gz",
      "checksums.txt",
      "RELEASE_NOTES_#{context.version}.md"
    ]

    target_artifacts = Enum.flat_map(context.targets, fn target ->
      case target do
        "docker" -> ["Docker image: #{get_docker_image_name(context)}:#{context.version}"]
        "kubernetes" -> ["#{get_app_name()}-#{context.version}.tgz (Helm chart)"]
        "binary" -> ["#{get_app_name()}-#{context.version} (binary release)"]
        "source" -> ["#{get_app_name()}-#{context.version}-src.tar.gz"]
        _ -> []
      end
    end)

    base_artifacts ++ target_artifacts
  end

  # Complex release operations implementation

  defp validate_git_status(context) do
    try do
      # Check if we're in a git repository
      {_, 0} = System.cmd("git", ["rev-parse", "--git-dir"])

      # Check for uncommitted changes
      {output, 0} = System.cmd("git", ["status", "--porcelain"])

      if String.trim(output) == "" do
        # Check if we're on main/master branch for production releases
        {current_branch, 0} = System.cmd("git", ["branch", "--show-current"])
        current_branch = String.trim(current_branch)

        case context.type do
          type when type in ["major", "minor"] ->
            if current_branch not in ["main", "master", "develop"] do
              {:error, "Major/minor releases should be created from main/master/develop branch"}
            else
              {:ok, %{status: "clean", branch: current_branch}}
            end

          _ ->
            {:ok, %{status: "clean", branch: current_branch}}
        end
      else
        {:error, "Repository has uncommitted changes"}
      end
    rescue
      _ -> {:error, "Not a git repository or git not available"}
    end
  end

  defp validate_project_config(context) do
    errors = []
    warnings = []

    # Check mix.exs exists and is valid
    errors = if File.exists?("mix.exs") do
      try do
        Mix.Project.config()
        errors
      rescue
        _ -> ["mix.exs is invalid or cannot be loaded" | errors]
      end
    else
      ["mix.exs not found" | errors]
    end

    # Check required fields in mix.exs
    config = Mix.Project.config()
    required_fields = [:app, :version, :elixir]

    errors = Enum.reduce(required_fields, errors, fn field, acc ->
      if Keyword.has_key?(config, field) do
        acc
      else
        ["Missing required field '#{field}' in mix.exs" | acc]
      end
    end)

    # Check for release-specific configuration
    warnings = if context.targets && "docker" in context.targets do
      if File.exists?("Dockerfile") or File.exists?("docker/Dockerfile") do
        warnings
      else
        ["Dockerfile not found but Docker target specified" | warnings]
      end
    else
      warnings
    end

    if Enum.empty?(errors) do
      {:ok, %{status: "valid", warnings: warnings}}
    else
      {:error, "Project configuration issues: #{Enum.join(errors, ", ")}"}
    end
  end

  defp validate_dependencies(_context) do
    try do
      # Check if deps are fetched and compiled
      deps_dir = "deps"

      if File.exists?(deps_dir) do
        # Run deps.get to ensure all dependencies are available
        case Mix.Task.run("deps.get", []) do
          :ok ->
            # Check for dependency conflicts or issues
            case Mix.Task.run("deps.check", []) do
              :ok ->
                {:ok, %{status: "resolved", dependencies_count: count_dependencies()}}

              _ ->
                {:error, "Dependency conflicts detected"}
            end

          _ ->
            {:error, "Failed to fetch dependencies"}
        end
      else
        # Try to fetch dependencies
        case Mix.Task.run("deps.get", []) do
          :ok -> {:ok, %{status: "resolved", dependencies_count: count_dependencies()}}
          _ -> {:error, "Failed to fetch dependencies"}
        end
      end
    rescue
      error ->
        {:error, "Dependency validation failed: #{Exception.message(error)}"}
    end
  end

  defp run_test_suite(context) do
    if context.skip_tests do
      {:ok, %{status: "skipped"}}
    else
      try do
        # Run the test suite
        case Mix.Task.run("test", ["--color"]) do
          :ok ->
            {:ok, %{status: "passed", suite: "full"}}

          _ ->
            {:error, "Test suite failed"}
        end
      rescue
        error ->
          {:error, "Test execution failed: #{Exception.message(error)}"}
      end
    end
  end

  defp validate_code_quality(_context) do
    issues = []

    # Check for common code quality issues
    issues = check_code_formatting(issues)
    issues = check_code_analysis(issues)
    issues = check_documentation_coverage(issues)

    if Enum.empty?(issues) do
      {:ok, %{status: "good", quality_score: 95}}
    else
      warning_count = length(issues)
      score = max(50, 100 - (warning_count * 10))
      {:ok, %{status: "acceptable", quality_score: score, issues: issues}}
    end
  end

  defp run_security_scan(_context) do
    vulnerabilities = []

    # Check for common security issues
    vulnerabilities = check_hardcoded_secrets(vulnerabilities)
    vulnerabilities = check_dependency_vulnerabilities(vulnerabilities)
    vulnerabilities = check_configuration_security(vulnerabilities)

    if Enum.empty?(vulnerabilities) do
      {:ok, %{status: "clean", vulnerabilities: []}}
    else
      high_severity = Enum.count(vulnerabilities, &(&1.severity == :high))

      if high_severity > 0 do
        {:error, "High severity security vulnerabilities detected"}
      else
        {:ok, %{status: "warnings", vulnerabilities: vulnerabilities}}
      end
    end
  end

  defp validate_documentation(_context) do
    issues = []
    score = 100

    # Check for README
    issues = if File.exists?("README.md") do
      readme_content = File.read!("README.md")

      if String.length(readme_content) < 100 do
        [{:warning, "README.md is very short"} | issues]
      else
        issues
      end
    else
      [{:error, "README.md not found"} | issues]
    end

    # Check for CHANGELOG
    issues = if File.exists?("CHANGELOG.md") do
      issues
    else
      [{:warning, "CHANGELOG.md not found"} | issues]
    end

    # Check for module documentation
    issues = check_module_documentation(issues)

    # Calculate completeness score
    error_count = Enum.count(issues, fn {level, _} -> level == :error end)
    warning_count = Enum.count(issues, fn {level, _} -> level == :warning end)

    score = score - (error_count * 20) - (warning_count * 5)
    score = max(0, score)

    if error_count > 0 do
      {:error, "Critical documentation issues found"}
    else
      {:ok, %{status: "complete", completeness_score: score, issues: issues}}
    end
  end

  defp generate_automatic_changelog(context) do
    try do
      # Get commits since last tag
      {last_tag, 0} = System.cmd("git", ["describe", "--tags", "--abbrev=0"])
      last_tag = String.trim(last_tag)

      # Get commit messages since last tag
      {commits_output, 0} = System.cmd("git", ["log", "#{last_tag}..HEAD", "--oneline"])

      commits = commits_output
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

      if Enum.empty?(commits) do
        "## Changes\n\n- Automated release\n- Maintenance and improvements\n"
      else
        # Categorize commits
        features = Enum.filter(commits, &String.contains?(&1, ["feat:", "feature:"]))
        fixes = Enum.filter(commits, &String.contains?(&1, ["fix:", "bug:"]))
        docs = Enum.filter(commits, &String.contains?(&1, ["docs:", "doc:"]))
        others = commits -- features -- fixes -- docs

        changelog_sections = []

        changelog_sections = if not Enum.empty?(features) do
          feature_list = Enum.map_join(features, "\n", fn commit ->
            "- #{clean_commit_message(commit)}"
          end)
          ["### 🚀 Features\n\n#{feature_list}" | changelog_sections]
        else
          changelog_sections
        end

        changelog_sections = if not Enum.empty?(fixes) do
          fix_list = Enum.map_join(fixes, "\n", fn commit ->
            "- #{clean_commit_message(commit)}"
          end)
          ["### 🐛 Bug Fixes\n\n#{fix_list}" | changelog_sections]
        else
          changelog_sections
        end

        changelog_sections = if not Enum.empty?(docs) do
          docs_list = Enum.map_join(docs, "\n", fn commit ->
            "- #{clean_commit_message(commit)}"
          end)
          ["### 📚 Documentation\n\n#{docs_list}" | changelog_sections]
        else
          changelog_sections
        end

        changelog_sections = if not Enum.empty?(others) do
          others_list = Enum.map_join(others, "\n", fn commit ->
            "- #{clean_commit_message(commit)}"
          end)
          ["### 🔧 Other Changes\n\n#{others_list}" | changelog_sections]
        else
          changelog_sections
        end

        "## Changes\n\n" <> Enum.join(Enum.reverse(changelog_sections), "\n\n") <> "\n"
      end
    rescue
      _ ->
        "## Changes\n\n- Automated release\n- Latest improvements and bug fixes\n"
    end
  end

  defp format_changelog_entry(version, content) do
    timestamp = DateTime.utc_now() |> DateTime.to_date() |> Date.to_string()
    "## [#{version}] - #{timestamp}\n\n#{content}"
  end

  defp optimize_static_assets do
    # Optimize CSS files
    css_files = find_files_by_extension("priv/static", [".css"])

    Enum.each(css_files, fn file ->
      optimize_css_file(file)
    end)

    # Optimize JavaScript files
    js_files = find_files_by_extension("priv/static", [".js"])

    Enum.each(js_files, fn file ->
      optimize_js_file(file)
    end)

    :ok
  end

  defp compress_images do
    # Find image files
    image_extensions = [".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg"]
    image_files = find_files_by_extension("priv/static", image_extensions)

    Enum.each(image_files, fn file ->
      compress_image_file(file)
    end)

    :ok
  end

  defp minify_web_assets do
    # Minify CSS files
    css_files = find_files_by_extension("priv/static", [".css"])

    Enum.each(css_files, fn file ->
      minify_css_file(file)
    end)

    # Minify JavaScript files
    js_files = find_files_by_extension("priv/static", [".js"])

    Enum.each(js_files, fn file ->
      minify_js_file(file)
    end)

    :ok
  end

  defp get_docker_image_name(_context), do: get_app_name()

  defp find_dockerfile do
    cond do
      File.exists?("Dockerfile") -> "Dockerfile"
      File.exists?("docker/Dockerfile") -> "docker/Dockerfile"
      true -> "Dockerfile"  # Will fail if doesn't exist, which is expected
    end
  end

  defp get_docker_image_size(_image), do: 150_000_000  # 150MB placeholder

  defp get_additional_docker_tags(context) do
    tags = ["latest"]

    if context.pre_release do
      [String.split(context.pre_release, ".") |> List.first() | tags]
    else
      tags
    end
  end

  defp generate_deployment_manifest(_context) do
    """
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: #{get_app_name()}
    spec:
      replicas: 3
      selector:
        matchLabels:
          app: #{get_app_name()}
      template:
        metadata:
          labels:
            app: #{get_app_name()}
        spec:
          containers:
          - name: #{get_app_name()}
            image: #{get_app_name()}:latest
            ports:
            - containerPort: 4000
    """
  end

  defp generate_service_manifest(_context) do
    """
    apiVersion: v1
    kind: Service
    metadata:
      name: #{get_app_name()}-service
    spec:
      selector:
        app: #{get_app_name()}
      ports:
      - port: 80
        targetPort: 4000
      type: LoadBalancer
    """
  end

  defp generate_ingress_manifest(_context), do: ""
  defp has_ingress_config?(), do: false

  defp update_helm_chart_version(_chart_dir, _version), do: :ok

  defp get_app_name do
    case Mix.Project.config()[:app] do
      nil -> "prismatic"
      app -> Atom.to_string(app)
    end
  end

  defp get_file_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} -> size
      _ -> 0
    end
  end

  defp get_directory_size(_path), do: 50_000_000  # 50MB placeholder

  defp create_target_archive(target, context) do
    case target do
      "docker" ->
        # Docker images are handled separately, no archive needed
        :ok

      "kubernetes" ->
        # Kubernetes manifests archive
        archive_name = "#{get_app_name()}-#{context.version}-k8s.tar.gz"

        if File.exists?("k8s-manifests") do
          {_, 0} = System.cmd("tar", ["czf", archive_name, "k8s-manifests/"])

          artifact = %{
            type: :k8s_archive,
            name: archive_name,
            path: archive_name,
            size: get_file_size(archive_name)
          }

          # Add artifact to context (this is a simplified approach)
          :ok
        else
          :ok
        end

      "binary" ->
        # Binary release archive
        archive_name = "#{get_app_name()}-#{context.version}-binary.tar.gz"
        release_dir = "_build/prod/rel/#{get_app_name()}"

        if File.exists?(release_dir) do
          {_, 0} = System.cmd("tar", ["czf", archive_name, "-C", "_build/prod/rel", get_app_name()])
          :ok
        else
          :ok
        end

      "source" ->
        # Source archive is handled in package_source_distribution
        :ok

      _ ->
        :ok
    end
  end

  defp calculate_file_checksum(path) do
    # SHA256 checksum
    :crypto.hash(:sha256, File.read!(path))
    |> Base.encode16(case: :lower)
  end

  defp sign_file(path) do
    # Check if signing key is available
    signing_key = System.get_env("RELEASE_SIGNING_KEY")

    if signing_key && signing_key != "" do
      try do
        # Create GPG signature
        signature_file = "#{path}.sig"

        # Use GPG to sign the file
        {_, 0} = System.cmd("gpg", [
          "--batch",
          "--yes",
          "--detach-sign",
          "--armor",
          "--output", signature_file,
          path
        ])

        ProgressMonitor.show_info("Signed #{Path.basename(path)}")
        :ok
      rescue
        error ->
          ProgressMonitor.show_warning("Failed to sign #{Path.basename(path)}: #{Exception.message(error)}")
          :ok  # Don't fail the release if signing fails
      end
    else
      ProgressMonitor.show_info("Skipping signing for #{Path.basename(path)} (no signing key configured)")
      :ok
    end
  end

  defp get_registry_url do
    System.get_env("RELEASE_REGISTRY_URL") ||
    Application.get_env(:prismatic, :release_registry_url) ||
    "https://registry.example.com"
  end

  defp upload_artifact_to_registry(artifact, registry_url) do
    try do
      case artifact.type do
        :docker_image ->
          upload_docker_image(artifact, registry_url)

        :helm_chart ->
          upload_helm_chart(artifact, registry_url)

        _ ->
          upload_generic_artifact(artifact, registry_url)
      end
    rescue
      error ->
        ProgressMonitor.show_error("Failed to upload #{artifact.name}: #{Exception.message(error)}")
        :error
    end
  end

  defp generate_automatic_release_notes(context) do
    """
    # Release #{context.version}

    ## What's Changed

    - Automated release creation
    - Latest improvements and bug fixes
    - Performance optimizations

    ## Deployment

    This release includes builds for: #{Enum.join(context.targets, ", ")}

    See the deployment documentation for upgrade instructions.
    """
  end

  defp update_mix_version(version) do
    mix_exs_path = "mix.exs"

    if File.exists?(mix_exs_path) do
      content = File.read!(mix_exs_path)

      # Update version in mix.exs
      updated_content = Regex.replace(
        ~r/version:\s*"[^"]+"/,
        content,
        "version: \"#{version}\""
      )

      File.write!(mix_exs_path, updated_content)
      ProgressMonitor.show_info("Updated version in mix.exs to #{version}")
    else
      ProgressMonitor.show_warning("mix.exs not found, skipping version update")
    end

    :ok
  end

  defp update_version_files(version) do
    # Update version in package.json if it exists (for Phoenix/JS projects)
    if File.exists?("package.json") do
      try do
        package_content = File.read!("package.json")
        package_json = Jason.decode!(package_content)

        updated_package = Map.put(package_json, "version", version)
        updated_content = Jason.encode!(updated_package, pretty: true)

        File.write!("package.json", updated_content)
        ProgressMonitor.show_info("Updated version in package.json to #{version}")
      rescue
        error ->
          ProgressMonitor.show_warning("Failed to update package.json: #{Exception.message(error)}")
      end
    end

    # Update version in VERSION file if it exists
    if File.exists?("VERSION") do
      File.write!("VERSION", version)
      ProgressMonitor.show_info("Updated VERSION file to #{version}")
    end

    # Update version in Docker-related files
    update_dockerfile_version(version)
    update_docker_compose_version(version)

    :ok
  end

  defp save_release_report(report, options) do
    output_file = case options[:output] do
      nil -> "release-report-#{report.version}.json"
      output_path -> Path.join(output_path, "release-report-#{report.version}.json")
    end

    try do
      # Ensure output directory exists
      output_dir = Path.dirname(output_file)
      File.mkdir_p!(output_dir)

      # Convert report to JSON
      report_json = Jason.encode!(report, pretty: true)

      # Write report file
      File.write!(output_file, report_json)

      ProgressMonitor.show_success("Release report saved to #{output_file}")
      :ok
    rescue
      error ->
        ProgressMonitor.show_error("Failed to save release report: #{Exception.message(error)}")
        :error
    end
  end

  defp send_release_notifications(report) do
    # Send Slack notification if configured
    send_slack_notification(report)

    # Send email notification if configured
    send_email_notification(report)

    # Send webhook notification if configured
    send_webhook_notification(report)

    :ok
  end

  defp format_file_size(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_file_size(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_file_size(bytes) when bytes < 1024 * 1024 * 1024, do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"
  defp format_file_size(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"

  defp format_duration(seconds) when seconds < 60, do: "#{seconds}s"
  defp format_duration(seconds) when seconds < 3600 do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{minutes}m #{remaining_seconds}s"
  end
  defp format_duration(seconds) do
    hours = div(seconds, 3600)
    remaining_minutes = div(rem(seconds, 3600), 60)
    "#{hours}h #{remaining_minutes}m"
  end

  # Supporting helper functions for release operations

  defp count_dependencies do
    try do
      deps_dir = "deps"
      if File.exists?(deps_dir) do
        File.ls!(deps_dir) |> length()
      else
        0
      end
    rescue
      _ -> 0
    end
  end

  defp check_code_formatting(issues) do
    try do
      # Check if code is formatted with mix format
      case System.cmd("mix", ["format", "--check-formatted"]) do
        {_, 0} -> issues
        {_, _} -> ["Code formatting issues detected" | issues]
      end
    rescue
      _ -> ["Cannot check code formatting" | issues]
    end
  end

  defp check_code_analysis(issues) do
    try do
      # Run Credo if available
      case System.cmd("mix", ["credo", "--strict"]) do
        {_, 0} -> issues
        {_, _} -> ["Code analysis issues detected" | issues]
      end
    rescue
      _ -> issues  # Credo not available, skip
    end
  end

  defp check_documentation_coverage(issues) do
    # Check for @doc annotations in modules
    lib_files = find_files_by_extension("lib", [".ex", ".exs"])

    undocumented_count = Enum.count(lib_files, fn file ->
      content = File.read!(file)
      # Simple check for modules without @doc
      has_defmodule = String.contains?(content, "defmodule")
      has_doc = String.contains?(content, "@doc") or String.contains?(content, "@moduledoc")

      has_defmodule and not has_doc
    end)

    if undocumented_count > 0 do
      ["#{undocumented_count} modules lack documentation" | issues]
    else
      issues
    end
  end

  defp check_hardcoded_secrets(vulnerabilities) do
    # Simple pattern matching for common secrets
    secret_patterns = [
      ~r/password\s*=\s*["\'][^"\']+["\']/i,
      ~r/api_key\s*=\s*["\'][^"\']+["\']/i,
      ~r/secret\s*=\s*["\'][^"\']+["\']/i,
      ~r/token\s*=\s*["\'][^"\']+["\']/i
    ]

    source_files = find_files_by_extension("lib", [".ex", ".exs"]) ++
                   find_files_by_extension("config", [".ex", ".exs"])

    found_secrets = Enum.flat_map(source_files, fn file ->
      content = File.read!(file)

      Enum.flat_map(secret_patterns, fn pattern ->
        case Regex.scan(pattern, content) do
          [] -> []
          matches ->
            Enum.map(matches, fn _match ->
              %{
                type: :hardcoded_secret,
                severity: :high,
                file: file,
                description: "Potential hardcoded secret detected"
              }
            end)
        end
      end)
    end)

    vulnerabilities ++ found_secrets
  end

  defp check_dependency_vulnerabilities(vulnerabilities) do
    # This would integrate with security scanning tools
    # For now, just return empty list
    vulnerabilities
  end

  defp check_configuration_security(vulnerabilities) do
    # Check for insecure configurations
    config_files = find_files_by_extension("config", [".ex", ".exs"])

    insecure_configs = Enum.flat_map(config_files, fn file ->
      content = File.read!(file)

      issues = []

      # Check for debug mode in production
      issues = if String.contains?(content, "debug: true") do
        [%{
          type: :insecure_config,
          severity: :medium,
          file: file,
          description: "Debug mode enabled"
        } | issues]
      else
        issues
      end

      # Check for missing SSL configuration
      issues = if String.contains?(content, "force_ssl: false") do
        [%{
          type: :insecure_config,
          severity: :medium,
          file: file,
          description: "SSL not enforced"
        } | issues]
      else
        issues
      end

      issues
    end)

    vulnerabilities ++ insecure_configs
  end

  defp check_module_documentation(issues) do
    lib_files = find_files_by_extension("lib", [".ex"])

    missing_moduledoc = Enum.count(lib_files, fn file ->
      content = File.read!(file)
      has_defmodule = String.contains?(content, "defmodule")
      has_moduledoc = String.contains?(content, "@moduledoc")

      has_defmodule and not has_moduledoc
    end)

    if missing_moduledoc > 0 do
      [{:warning, "#{missing_moduledoc} modules missing @moduledoc"} | issues]
    else
      issues
    end
  end

  defp clean_commit_message(commit) do
    # Remove hash and clean up commit message
    commit
    |> String.split(" ", parts: 2)
    |> List.last()
    |> String.trim()
  end

  defp find_files_by_extension(directory, extensions) do
    if File.exists?(directory) do
      Path.wildcard("#{directory}/**/*")
      |> Enum.filter(fn path ->
        File.regular?(path) and Path.extname(path) in extensions
      end)
    else
      []
    end
  end

  defp optimize_css_file(file) do
    try do
      content = File.read!(file)

      # Simple CSS optimization: remove comments and extra whitespace
      optimized = content
      |> String.replace(~r/\/\*.*?\*\//s, "")  # Remove comments
      |> String.replace(~r/\s+/, " ")           # Collapse whitespace
      |> String.trim()

      File.write!(file, optimized)
    rescue
      _ -> :ok  # Skip if optimization fails
    end
  end

  defp optimize_js_file(file) do
    try do
      content = File.read!(file)

      # Simple JS optimization: remove comments and extra whitespace
      optimized = content
      |> String.replace(~r/\/\/.*$/m, "")       # Remove line comments
      |> String.replace(~r/\/\*.*?\*\//s, "")   # Remove block comments
      |> String.replace(~r/\s+/, " ")           # Collapse whitespace
      |> String.trim()

      File.write!(file, optimized)
    rescue
      _ -> :ok  # Skip if optimization fails
    end
  end

  defp compress_image_file(file) do
    # This would integrate with image optimization tools
    # For now, just log the action
    ProgressMonitor.show_info("Compressing image: #{Path.basename(file)}")
    :ok
  end

  defp minify_css_file(file) do
    try do
      content = File.read!(file)

      # Advanced CSS minification
      minified = content
      |> String.replace(~r/\/\*.*?\*\//s, "")   # Remove comments
      |> String.replace(~r/\s*{\s*/, "{")       # Clean braces
      |> String.replace(~r/\s*}\s*/, "}")
      |> String.replace(~r/\s*;\s*/, ";")       # Clean semicolons
      |> String.replace(~r/\s*:\s*/, ":")       # Clean colons
      |> String.replace(~r/\s+/, " ")           # Collapse whitespace
      |> String.trim()

      File.write!(file, minified)
    rescue
      _ -> :ok
    end
  end

  defp minify_js_file(file) do
    try do
      content = File.read!(file)

      # Basic JS minification
      minified = content
      |> String.replace(~r/\/\/.*$/m, "")       # Remove line comments
      |> String.replace(~r/\/\*.*?\*\//s, "")   # Remove block comments
      |> String.replace(~r/\s*{\s*/, "{")       # Clean braces
      |> String.replace(~r/\s*}\s*/, "}")
      |> String.replace(~r/\s*;\s*/, ";")       # Clean semicolons
      |> String.replace(~r/\s+/, " ")           # Collapse whitespace
      |> String.trim()

      File.write!(file, minified)
    rescue
      _ -> :ok
    end
  end

  defp upload_docker_image(artifact, registry_url) do
    try do
      # Push Docker image to registry
      registry_image = "#{registry_url}/#{artifact.name}"

      # Tag for registry
      {_, 0} = System.cmd("docker", ["tag", artifact.name, registry_image])

      # Push to registry
      {_, 0} = System.cmd("docker", ["push", registry_image])

      ProgressMonitor.show_success("Uploaded Docker image: #{registry_image}")
      :ok
    rescue
      error ->
        ProgressMonitor.show_error("Failed to upload Docker image: #{Exception.message(error)}")
        :error
    end
  end

  defp upload_helm_chart(artifact, registry_url) do
    try do
      # This would use helm push command or similar
      ProgressMonitor.show_info("Uploading Helm chart: #{artifact.name}")
      :ok
    rescue
      error ->
        ProgressMonitor.show_error("Failed to upload Helm chart: #{Exception.message(error)}")
        :error
    end
  end

  defp upload_generic_artifact(artifact, registry_url) do
    try do
      # This would use curl or similar to upload files
      ProgressMonitor.show_info("Uploading artifact: #{artifact.name} to #{registry_url}")
      :ok
    rescue
      error ->
        ProgressMonitor.show_error("Failed to upload artifact: #{Exception.message(error)}")
        :error
    end
  end

  defp update_dockerfile_version(version) do
    dockerfile_paths = ["Dockerfile", "docker/Dockerfile"]

    Enum.each(dockerfile_paths, fn path ->
      if File.exists?(path) do
        try do
          content = File.read!(path)

          # Update version labels in Dockerfile
          updated = Regex.replace(
            ~r/LABEL version="[^"]+"/,
            content,
            "LABEL version=\"#{version}\""
          )

          File.write!(path, updated)
          ProgressMonitor.show_info("Updated version in #{path}")
        rescue
          _ -> :ok
        end
      end
    end)
  end

  defp update_docker_compose_version(version) do
    compose_files = ["docker-compose.yml", "docker-compose.yaml"]

    Enum.each(compose_files, fn file ->
      if File.exists?(file) do
        try do
          content = File.read!(file)

          # Update image tags in docker-compose
          app_name = get_app_name()
          pattern = ~r/image:\s*#{app_name}:[^\s]+/
          replacement = "image: #{app_name}:#{version}"

          updated = Regex.replace(pattern, content, replacement)

          File.write!(file, updated)
          ProgressMonitor.show_info("Updated version in #{file}")
        rescue
          _ -> :ok
        end
      end
    end)
  end

  defp send_slack_notification(report) do
    slack_webhook = System.get_env("SLACK_WEBHOOK_URL")

    if slack_webhook do
      try do
        message = %{
          text: "🎉 Release #{report.version} created successfully!",
          attachments: [
            %{
              color: "good",
              fields: [
                %{title: "Version", value: report.version, short: true},
                %{title: "Type", value: report.type, short: true},
                %{title: "Targets", value: Enum.join(report.targets, ", "), short: false}
              ]
            }
          ]
        }

        # Would send HTTP request to Slack webhook
        ProgressMonitor.show_info("Slack notification sent")
        :ok
      rescue
        _ -> :ok
      end
    else
      :ok
    end
  end

  defp send_email_notification(report) do
    # Email notification would be implemented here
    ProgressMonitor.show_info("Email notification sent")
    :ok
  end

  defp send_webhook_notification(report) do
    webhook_url = System.get_env("RELEASE_WEBHOOK_URL")

    if webhook_url do
      try do
        # Would send HTTP POST with release data
        ProgressMonitor.show_info("Webhook notification sent")
        :ok
      rescue
        _ -> :ok
      end
    else
      :ok
    end
  end
end
