defmodule Mix.Tasks.Prismatic.Shared.Config do
  @moduledoc """
  Enhanced centralized configuration with task-specific profiles.

  Provides comprehensive configuration management for all Prismatic tasks including:
  - Task-specific configuration profiles
  - Environment-based defaults
  - Validation and normalization
  - CI/CD integration settings
  """

  @type task_profile :: :docs | :sync | :code | :system
  @type config :: %{
    docs_path: String.t(),
    code_path: String.t(),
    output_format: String.t(),
    output_file: String.t(),
    ci_mode: boolean(),
    verbose: boolean(),
    profile: task_profile()
  }

  @doc """
  Get profile-specific default configuration.
  """
  @spec profile_defaults(task_profile()) :: map()
  def profile_defaults(:docs) do
    %{
      docs_path: "docs",
      code_path: "apps",
      output_format: "json",
      ci_mode: false,
      verbose: false,
      file_prefix: "docs-analysis",
      show_progress: true,
      sections: ["all"],
      include_examples: true,
      include_traceability: true
    }
  end

  def profile_defaults(:sync) do
    %{
      docs_path: "docs",
      code_path: "apps",
      output_format: "json",
      ci_mode: false,
      verbose: false,
      file_prefix: "sync-analysis",
      show_progress: true,
      auto_fix: false,
      threshold: 85,
      monitoring_interval: 3600
    }
  end

  def profile_defaults(:code) do
    %{
      code_path: "apps",
      output_format: "json",
      ci_mode: false,
      verbose: false,
      file_prefix: "code-analysis",
      show_progress: true,
      include_dependencies: true,
      quality_threshold: 80
    }
  end

  def profile_defaults(:system) do
    %{
      output_format: "json",
      ci_mode: false,
      verbose: false,
      file_prefix: "system-health",
      show_progress: true,
      monitoring_interval: 300,
      alert_threshold: 70
    }
  end

  @doc """
  Default configuration values used across all tasks.
  """
  @spec defaults() :: config()
  def defaults do
    %{
      docs_path: "docs",
      code_path: "apps",
      output_format: "json",
      output_file: nil,
      ci_mode: false,
      verbose: false,
      profile: :docs
    }
  end

  @doc """
  Supported output formats across all tasks.
  """
  @spec output_formats() :: [String.t()]
  def output_formats, do: ~w(json yaml html report markdown)

  @doc """
  Merge user options with profile defaults and normalize values.
  """
  @spec normalize_config(keyword(), map()) :: config()
  def normalize_config(options, task_defaults \\ %{}) do
    # Determine profile from task defaults or options
    profile = task_defaults[:profile] || options[:profile] || :docs
    profile_config = profile_defaults(profile)

    # Merge configurations with precedence: options > task_defaults > profile_defaults > defaults
    base_config = defaults()
    |> Map.merge(profile_config)
    |> Map.merge(task_defaults)

    normalized = %{
      docs_path: options[:docs] || base_config[:docs_path],
      code_path: options[:code] || base_config[:code_path],
      output_format: options[:output] || base_config[:output_format],
      output_file: options[:file] || generate_output_filename(
        options[:output] || base_config[:output_format],
        base_config[:file_prefix] || "prismatic-analysis"
      ),
      ci_mode: options[:ci] || base_config[:ci_mode],
      verbose: options[:verbose] || base_config[:verbose],
      profile: profile,
      show_progress: Keyword.get(options, :show_progress, base_config[:show_progress])
    }

    # Add profile-specific and task-specific options
    profile_specific = extract_profile_specific_options(options, profile_config)
    task_specific = extract_task_specific_options(options, task_defaults)

    normalized
    |> Map.merge(profile_specific)
    |> Map.merge(task_specific)
  end

  @doc """
  Validate configuration options comprehensively.
  """
  @spec validate_config(config()) :: :ok | {:error, String.t()}
  def validate_config(config) do
    with :ok <- validate_paths(config),
         :ok <- validate_output_format(config),
         :ok <- validate_output_directory(config),
         :ok <- validate_profile_specific(config) do
      :ok
    end
  end

  @doc """
  Generate output filename with timestamp and profile.
  """
  @spec generate_output_filename(String.t(), String.t()) :: String.t()
  def generate_output_filename(format, prefix) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601(:basic)
    extension = format_to_extension(format)
    "#{prefix}-#{timestamp}.#{extension}"
  end

  @doc """
  Get file extension for output format.
  """
  @spec format_to_extension(String.t()) :: String.t()
  def format_to_extension(format) do
    case format do
      "json" -> "json"
      "yaml" -> "yaml"
      "html" -> "html"
      "report" -> "txt"
      "markdown" -> "md"
      _ -> "txt"
    end
  end

  @doc """
  Display configuration summary with profile information.
  """
  @spec display_config(config(), String.t()) :: :ok
  def display_config(config, task_name) do
    Mix.shell().info([
      :blue, "\n📋 #{String.capitalize(task_name)} Configuration", :reset
    ])

    # Basic configuration
    config_items = [
      {"Profile", config[:profile] || "default"},
      {"Documentation Path", config[:docs_path] || "N/A"},
      {"Code Path", config[:code_path] || "N/A"},
      {"Output Format", config[:output_format]},
      {"Output File", config[:output_file]},
      {"CI Mode", if(config[:ci_mode], do: "Enabled", else: "Disabled")},
      {"Verbose Mode", if(config[:verbose], do: "Enabled", else: "Disabled")},
      {"Progress Monitoring", if(config[:show_progress], do: "Enabled", else: "Disabled")}
    ]

    Enum.each(config_items, fn {label, value} ->
      Mix.shell().info("  #{label}: #{value}")
    end)

    # Profile-specific configuration
    display_profile_specific_config(config)

    Mix.shell().info("")
    :ok
  end

  @doc """
  Get environment-specific configuration overrides.
  """
  @spec environment_overrides() :: map()
  def environment_overrides do
    %{
      ci_mode: System.get_env("CI") == "true",
      verbose: System.get_env("VERBOSE") == "true" or System.get_env("MIX_DEBUG") == "1",
      docs_path: System.get_env("DOCS_PATH") || "docs",
      code_path: System.get_env("CODE_PATH") || "apps"
    }
  end

  @doc """
  Apply environment overrides to configuration.
  """
  @spec apply_environment_overrides(config()) :: config()
  def apply_environment_overrides(config) do
    env_overrides = environment_overrides()

    Enum.reduce(env_overrides, config, fn {key, value}, acc ->
      if value != nil and value != false do
        Map.put(acc, key, value)
      else
        acc
      end
    end)
  end

  # Private functions

  defp validate_paths(config) do
    cond do
      Map.has_key?(config, :docs_path) and not File.dir?(config.docs_path) ->
        {:error, "Documentation directory '#{config.docs_path}' does not exist"}

      Map.has_key?(config, :code_path) and not File.dir?(config.code_path) ->
        {:error, "Code directory '#{config.code_path}' does not exist"}

      true ->
        :ok
    end
  end

  defp validate_output_format(config) do
    if config.output_format in output_formats() do
      :ok
    else
      {:error, "Invalid output format '#{config.output_format}'. Available: #{Enum.join(output_formats(), ", ")}"}
    end
  end

  defp validate_output_directory(config) do
    output_dir = Path.dirname(config.output_file)

    if File.dir?(output_dir) or output_dir == "." do
      :ok
    else
      case File.mkdir_p(output_dir) do
        :ok -> :ok
        {:error, reason} ->
          {:error, "Cannot create output directory '#{output_dir}': #{reason}"}
      end
    end
  end

  defp validate_profile_specific(config) do
    case config[:profile] do
      :docs -> validate_docs_profile(config)
      :sync -> validate_sync_profile(config)
      :code -> validate_code_profile(config)
      :system -> validate_system_profile(config)
      _ -> :ok
    end
  end

  defp validate_docs_profile(config) do
    # Validate docs-specific configuration
    cond do
      Map.has_key?(config, :sections) and not valid_sections?(config[:sections]) ->
        {:error, "Invalid sections for docs profile"}
      true -> :ok
    end
  end

  defp validate_sync_profile(config) do
    # Validate sync-specific configuration
    cond do
      Map.has_key?(config, :threshold) and (config[:threshold] < 0 or config[:threshold] > 100) ->
        {:error, "Threshold must be between 0 and 100"}
      true -> :ok
    end
  end

  defp validate_code_profile(config) do
    # Validate code-specific configuration
    cond do
      Map.has_key?(config, :quality_threshold) and (config[:quality_threshold] < 0 or config[:quality_threshold] > 100) ->
        {:error, "Quality threshold must be between 0 and 100"}
      true -> :ok
    end
  end

  defp validate_system_profile(config) do
    # Validate system-specific configuration
    cond do
      Map.has_key?(config, :alert_threshold) and (config[:alert_threshold] < 0 or config[:alert_threshold] > 100) ->
        {:error, "Alert threshold must be between 0 and 100"}
      true -> :ok
    end
  end

  defp valid_sections?(sections) when is_list(sections) do
    valid_section_names = ~w(all adrs examples trace ai validation)
    Enum.all?(sections, &(&1 in valid_section_names))
  end
  defp valid_sections?(_), do: false

  defp extract_profile_specific_options(options, profile_config) do
    profile_keys = Map.keys(profile_config) -- Map.keys(defaults())

    Enum.reduce(profile_keys, %{}, fn key, acc ->
      if Keyword.has_key?(options, key) do
        Map.put(acc, key, options[key])
      else
        Map.put(acc, key, profile_config[key])
      end
    end)
  end

  defp extract_task_specific_options(options, task_defaults) do
    task_specific_keys = Map.keys(task_defaults) -- (Map.keys(defaults()) ++ Map.keys(profile_defaults(:docs)))

    Enum.reduce(task_specific_keys, %{}, fn key, acc ->
      if Keyword.has_key?(options, key) do
        Map.put(acc, key, options[key])
      else
        Map.put(acc, key, task_defaults[key])
      end
    end)
  end

  defp display_profile_specific_config(config) do
    case config[:profile] do
      :docs -> display_docs_profile_config(config)
      :sync -> display_sync_profile_config(config)
      :code -> display_code_profile_config(config)
      :system -> display_system_profile_config(config)
      _ -> :ok
    end
  end

  defp display_docs_profile_config(config) do
    if Map.has_key?(config, :sections) do
      Mix.shell().info("  Analysis Sections: #{Enum.join(config[:sections], ", ")}")
    end
    if Map.has_key?(config, :include_examples) do
      Mix.shell().info("  Include Examples: #{config[:include_examples]}")
    end
  end

  defp display_sync_profile_config(config) do
    if Map.has_key?(config, :threshold) do
      Mix.shell().info("  Health Threshold: #{config[:threshold]}%")
    end
    if Map.has_key?(config, :auto_fix) do
      Mix.shell().info("  Auto Fix: #{config[:auto_fix]}")
    end
  end

  defp display_code_profile_config(config) do
    if Map.has_key?(config, :quality_threshold) do
      Mix.shell().info("  Quality Threshold: #{config[:quality_threshold]}%")
    end
  end

  defp display_system_profile_config(config) do
    if Map.has_key?(config, :alert_threshold) do
      Mix.shell().info("  Alert Threshold: #{config[:alert_threshold]}%")
    end
  end

  @doc """
  Get configuration for a specific profile with fallback defaults.
  """
  @spec get_config(task_profile(), map()) :: map()
  def get_config(profile, fallback_defaults \\ %{}) do
    profile_config = profile_defaults(profile)
    env_overrides = environment_overrides()

    profile_config
    |> Map.merge(fallback_defaults)
    |> Map.merge(env_overrides)
  end

  @doc """
  Validate base configuration for system health checks.
  """
  @spec validate_base_config() :: :ok
  def validate_base_config do
    # Basic configuration validation
    profiles = [:docs, :sync, :code, :system]

    Enum.each(profiles, fn profile ->
      config = get_config(profile, %{})
      case validate_config(config) do
        :ok -> :ok
        {:error, reason} -> raise "Configuration validation failed for #{profile}: #{reason}"
      end
    end)

    :ok
  end
end
