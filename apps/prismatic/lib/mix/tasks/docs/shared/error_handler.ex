defmodule Mix.Tasks.Docs.Shared.ErrorHandler do
  @moduledoc """
  Centralized error handling for documentation analysis tasks.

  Provides consistent error reporting, troubleshooting guidance, and graceful
  failure handling across all documentation analysis tasks.
  """

  @doc """
  Handle task execution errors with proper diagnostics and troubleshooting tips.
  """
  @spec handle_task_error(Exception.t(), integer(), String.t(), list() | nil) :: no_return()
  def handle_task_error(error, execution_time, task_name, stacktrace \\ nil) do
    Mix.shell().error([
      :red, "❌ #{String.capitalize(task_name)} failed after #{execution_time}ms", :reset
    ])

    display_error_details(error)

    if System.get_env("MIX_DEBUG") == "1" and stacktrace do
      display_stacktrace(stacktrace)
    end

    display_troubleshooting_tips(error, task_name)

    System.halt(1)
  end

  @doc """
  Handle validation errors with specific guidance.
  """
  @spec handle_validation_error(String.t(), String.t()) :: no_return()
  def handle_validation_error(reason, task_name) do
    Mix.shell().error("❌ Invalid options for #{task_name}: #{reason}")
    display_usage_help(task_name)
    System.halt(1)
  end

  @doc """
  Handle file system errors with specific guidance.
  """
  @spec handle_file_error(File.posix() | String.t(), String.t()) :: no_return()
  def handle_file_error(reason, file_path) do
    Mix.shell().error([
      :red, "❌ File system error: ", :reset, "#{reason} - #{file_path}"
    ])

    Mix.shell().error([
      :yellow, "\n💡 File System Troubleshooting:", :reset,
      "\n  • Verify the file or directory exists and is accessible",
      "\n  • Check file permissions (read/write access)",
      "\n  • Ensure sufficient disk space is available",
      "\n  • Verify the path is correct and properly formatted"
    ])

    System.halt(1)
  end

  @doc """
  Handle dependency missing errors.
  """
  @spec handle_dependency_error([atom()]) :: no_return()
  def handle_dependency_error(missing_modules) do
    Mix.shell().error([
      :red, "❌ Missing required dependencies: ", :reset, inspect(missing_modules)
    ])

    Mix.shell().error([
      :yellow, "\n💡 Dependency Troubleshooting:", :reset,
      "\n  • Ensure the Prismatic application is properly started",
      "\n  • Verify all required dependencies are compiled",
      "\n  • Try running 'mix deps.get && mix compile'",
      "\n  • Check if any dependencies failed to load"
    ])

    System.halt(1)
  end

  @doc """
  Validate file access and provide helpful error messages.
  """
  @spec validate_file_access(String.t(), String.t()) :: :ok | no_return()
  def validate_file_access(path, description) do
    cond do
      not File.exists?(path) ->
        handle_file_error("does not exist", "#{description}: #{path}")

      not File.dir?(path) and not File.regular?(path) ->
        handle_file_error("is not a valid file or directory", "#{description}: #{path}")

      File.dir?(path) and not File.dir?(path) ->
        handle_file_error("directory not accessible", "#{description}: #{path}")

      File.regular?(path) and not File.regular?(path) ->
        handle_file_error("file not readable", "#{description}: #{path}")

      true ->
        :ok
    end
  end

  @doc """
  Validate output directory and provide helpful error messages.
  """
  @spec validate_output_directory(String.t()) :: :ok | no_return()
  def validate_output_directory(file_path) do
    output_dir = Path.dirname(file_path)

    cond do
      output_dir != "." and not File.dir?(output_dir) ->
        case File.mkdir_p(output_dir) do
          :ok -> :ok
          {:error, reason} ->
            handle_file_error(reason, "output directory: #{output_dir}")
        end

      not File.dir?(output_dir) ->
        handle_file_error("output directory not accessible", output_dir)

      true ->
        :ok
    end
  end

  @doc """
  Safely execute a function with error handling.
  """
  @spec safe_execute(String.t(), String.t(), (() -> any())) :: any() | no_return()
  def safe_execute(task_name, operation_name, fun) do
    start_time = System.monotonic_time(:millisecond)

    try do
      fun.()
    rescue
      error ->
        execution_time = System.monotonic_time(:millisecond) - start_time
        handle_task_error(error, execution_time, "#{task_name} #{operation_name}", __STACKTRACE__)
    end
  end

  @doc """
  Display warning messages consistently.
  """
  @spec display_warning(String.t()) :: :ok
  def display_warning(message) do
    Mix.shell().info([
      :yellow, "⚠️  Warning: ", :reset, message
    ])
    :ok
  end

  @doc """
  Display informational messages consistently.
  """
  @spec display_info(String.t()) :: :ok
  def display_info(message) do
    Mix.shell().info([
      :blue, "ℹ️  Info: ", :reset, message
    ])
    :ok
  end

  # Private functions

  defp display_error_details(error) do
    case error do
      %File.Error{reason: reason, path: path} ->
        Mix.shell().error("File system error: #{reason} - #{path}")

      %Jason.DecodeError{data: data} ->
        Mix.shell().error("JSON parsing error in data: #{String.slice(data, 0, 100)}...")

      %FunctionClauseError{} ->
        Mix.shell().error("Invalid data format encountered during analysis")

      %UndefinedFunctionError{module: module, function: function, arity: arity} ->
        Mix.shell().error("Function #{module}.#{function}/#{arity} is not available")

      %ArgumentError{message: message} ->
        Mix.shell().error("Invalid argument: #{message}")

      _ ->
        Mix.shell().error("Unexpected error: #{Exception.message(error)}")
    end
  end

  defp display_stacktrace(stacktrace) do
    Mix.shell().error("Stack trace:")
    Mix.shell().error(Exception.format_stacktrace(stacktrace))
  end

  defp display_troubleshooting_tips(error, task_name) do
    general_tips = [
      "Verify all file paths exist and are accessible",
      "Check for sufficient disk space for output files",
      "Ensure all required dependencies are available",
      "Try running with --verbose for more detailed information"
    ]

    specific_tips = case error do
      %File.Error{} ->
        [
          "Check file permissions for reading and writing",
          "Verify the file or directory path is correct",
          "Ensure the parent directory exists"
        ]

      %Jason.DecodeError{} ->
        [
          "Verify JSON files are properly formatted",
          "Check for any corrupted data files",
          "Try regenerating any cached analysis files"
        ]

      %UndefinedFunctionError{} ->
        [
          "Ensure the application is properly compiled",
          "Try running 'mix deps.get && mix compile'",
          "Verify all dependencies are up to date"
        ]

      _ ->
        []
    end

    all_tips = specific_tips ++ general_tips

    Mix.shell().error([
      :yellow, "\n💡 Troubleshooting Tips for #{task_name}:", :reset
    ])

    Enum.each(all_tips, fn tip ->
      Mix.shell().error("  • #{tip}")
    end)

    Mix.shell().error([
      :yellow, "\nFor more help:", :reset,
      "\n  • Run 'mix docs.#{task_name} --help' for detailed documentation",
      "\n  • Enable debug mode with MIX_DEBUG=1",
      "\n  • Check the documentation at docs/guides/"
    ])
  end

  defp display_usage_help(task_name) do
    Mix.shell().info([
      :blue, "\nUsage Help:", :reset,
      "\n  Run 'mix docs.#{task_name} --help' for detailed options and examples",
      "\n  Run 'mix docs --help' for overview of all available commands"
    ])
  end
end
