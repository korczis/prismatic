defmodule Mix.Tasks.Docs.Shared.Config do
  @moduledoc """
  Centralized configuration management for documentation analysis tasks.

  Provides consistent configuration handling, default values, and validation
  across all documentation analysis tasks.
  """

  @typedoc "Common configuration options"
  @type config :: %{
    docs_path: String.t(),
    code_path: String.t(),
    output_format: String.t(),
    output_file: String.t(),
    ci_mode: boolean(),
    verbose: boolean()
  }

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
      verbose: false
    }
  end

  @doc """
  Supported output formats across all tasks.
  """
  @spec output_formats() :: [String.t()]
  def output_formats, do: ~w(json yaml html report)

  @doc """
  Merge user options with defaults and normalize values.
  """
  @spec normalize_config(keyword(), map()) :: config()
  def normalize_config(options, task_defaults \\ %{}) do
    base_config = Map.merge(defaults(), task_defaults)

    %{
      docs_path: options[:docs] || base_config.docs_path,
      code_path: options[:code] || base_config.code_path,
      output_format: options[:output] || base_config.output_format,
      output_file: options[:file] || generate_output_filename(
        options[:output] || base_config.output_format,
        task_defaults[:file_prefix] || "docs-analysis"
      ),
      ci_mode: options[:ci] || base_config.ci_mode,
      verbose: options[:verbose] || base_config.verbose
    }
    |> Map.merge(extract_task_specific_options(options, task_defaults))
  end

  @doc """
  Validate configuration options.
  """
  @spec validate_config(config()) :: :ok | {:error, String.t()}
  def validate_config(config) do
    with :ok <- validate_paths(config),
         :ok <- validate_output_format(config),
         :ok <- validate_output_directory(config) do
      :ok
    end
  end

  @doc """
  Generate output filename with timestamp.
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
      _ -> "txt"
    end
  end

  @doc """
  Display configuration summary.
  """
  @spec display_config(config(), String.t()) :: :ok
  def display_config(config, task_name) do
    Mix.shell().info([
      :blue, "\n📋 #{String.capitalize(task_name)} Configuration", :reset
    ])

    config_items = [
      {"Documentation Path", config.docs_path},
      {"Code Path", config.code_path},
      {"Output Format", config.output_format},
      {"Output File", config.output_file},
      {"CI Mode", if(config.ci_mode, do: "Enabled", else: "Disabled")},
      {"Verbose Mode", if(config.verbose, do: "Enabled", else: "Disabled")}
    ]

    Enum.each(config_items, fn {label, value} ->
      Mix.shell().info("  #{label}: #{value}")
    end)

    Mix.shell().info("")
    :ok
  end

  # Private functions

  defp validate_paths(config) do
    cond do
      not File.dir?(config.docs_path) ->
        {:error, "Documentation directory '#{config.docs_path}' does not exist"}

      config[:code_path] && not File.dir?(config.code_path) ->
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
      {:error, "Output directory '#{output_dir}' is not writable"}
    end
  end

  defp extract_task_specific_options(options, task_defaults) do
    task_specific_keys = Map.keys(task_defaults) -- Map.keys(defaults())

    Enum.reduce(task_specific_keys, %{}, fn key, acc ->
      if Keyword.has_key?(options, key) do
        Map.put(acc, key, options[key])
      else
        Map.put(acc, key, task_defaults[key])
      end
    end)
  end
end
