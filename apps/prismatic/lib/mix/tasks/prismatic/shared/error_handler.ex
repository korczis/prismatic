defmodule Mix.Tasks.Prismatic.Shared.ErrorHandler do
  @moduledoc """
  Enhanced error handling with detailed diagnostics and recovery suggestions.

  Provides comprehensive error management including:
  - Detailed error categorization and diagnosis
  - Context-aware recovery suggestions
  - CI/CD friendly error reporting
  - Automated fix recommendations
  - Integration with telemetry and monitoring
  """

  alias Mix.Tasks.Prismatic.Shared.{Telemetry, ProgressMonitor}

  @doc """
  Handle task execution errors with comprehensive diagnostics.
  """
  @spec handle_task_error(Exception.t(), integer(), String.t(), list() | nil) :: no_return()
  def handle_task_error(error, execution_time, task_name, stacktrace \\ nil) do
    # Record error in telemetry
    Telemetry.record_task_error(task_name, error, execution_time)

    Mix.shell().error([
      :red, "❌ #{String.capitalize(task_name)} failed after #{execution_time}ms", :reset
    ])

    error_context = categorize_error(error, task_name)

    display_error_summary(error, error_context)
    display_error_details(error_context)

    if should_show_stacktrace?(error) and stacktrace do
      display_stacktrace(stacktrace)
    end

    display_recovery_suggestions(error_context)
    display_support_information(error_context)

    System.halt(1)
  end

  @doc """
  Handle validation errors with specific guidance.
  """
  @spec handle_validation_error(String.t(), String.t()) :: no_return()
  def handle_validation_error(reason, task_name) do
    Mix.shell().error([
      :red, "❌ Invalid configuration for ", :cyan, task_name, :reset, ": #{reason}"
    ])

    display_validation_help(task_name, reason)
    System.halt(1)
  end

  @doc """
  Handle dependency errors with installation guidance.
  """
  @spec handle_dependency_error([atom()], String.t()) :: no_return()
  def handle_dependency_error(missing_modules, task_name) do
    Mix.shell().error([
      :red, "❌ Missing dependencies for ", :cyan, task_name, :reset
    ])

    Mix.shell().error("Missing modules: #{inspect(missing_modules)}")

    display_dependency_resolution_steps(missing_modules)
    System.halt(1)
  end

  @doc """
  Validate file access with enhanced error messages.
  """
  @spec validate_file_access(String.t(), String.t()) :: :ok | no_return()
  def validate_file_access(path, description) do
    cond do
      not File.exists?(path) ->
        handle_file_not_found_error(path, description)

      File.dir?(path) and not File.dir?(path) ->
        handle_directory_access_error(path, description)

      File.regular?(path) and not File.regular?(path) ->
        handle_file_access_error(path, description)

      true ->
        :ok
    end
  end

  @doc """
  Validate output directory with auto-creation.
  """
  @spec validate_output_directory(String.t()) :: :ok | no_return()
  def validate_output_directory(file_path) do
    output_dir = Path.dirname(file_path)

    cond do
      output_dir == "." ->
        :ok

      File.dir?(output_dir) ->
        :ok

      true ->
        case File.mkdir_p(output_dir) do
          :ok ->
            ProgressMonitor.show_info("Created output directory: #{output_dir}")
            :ok
          {:error, reason} ->
            handle_directory_creation_error(output_dir, reason)
        end
    end
  end

  @doc """
  Safely execute with enhanced error context.
  """
  @spec safe_execute(String.t(), String.t(), (() -> any())) :: any() | no_return()
  def safe_execute(task_name, operation_name, fun) do
    start_time = System.monotonic_time(:millisecond)

    try do
      fun.()
    rescue
      error ->
        execution_time = System.monotonic_time(:millisecond) - start_time
        enhanced_task_name = "#{task_name}.#{operation_name}"
        handle_task_error(error, execution_time, enhanced_task_name, __STACKTRACE__)
    end
  end

  @doc """
  Generate automated fix suggestions for common errors.
  """
  @spec suggest_automated_fixes(Exception.t(), String.t()) :: [String.t()]
  def suggest_automated_fixes(error, task_name) do
    error_context = categorize_error(error, task_name)

    generate_fix_suggestions(error_context)
  end

  @doc """
  Display warning with context-appropriate styling.
  """
  @spec display_warning(String.t(), String.t()) :: :ok
  def display_warning(message, context \\ "general") do
    icon = case context do
      "performance" -> "⚡"
      "security" -> "🔒"
      "compatibility" -> "🔄"
      _ -> "⚠️"
    end

    Mix.shell().info([
      :yellow, "#{icon} Warning: ", :reset, message
    ])
    :ok
  end

  @doc """
  Display informational message with enhanced formatting.
  """
  @spec display_info(String.t(), String.t()) :: :ok
  def display_info(message, context \\ "general") do
    icon = case context do
      "progress" -> "📊"
      "config" -> "⚙️"
      "success" -> "✅"
      _ -> "ℹ️"
    end

    Mix.shell().info([
      :blue, "#{icon} ", :reset, message
    ])
    :ok
  end

  # Private functions

  defp categorize_error(error, task_name) do
    %{
      error: error,
      task_name: task_name,
      category: determine_error_category(error),
      severity: determine_error_severity(error),
      likely_cause: analyze_likely_cause(error, task_name),
      context: gather_error_context(error, task_name),
      fixable: is_automatically_fixable?(error),
      recovery_time: estimate_recovery_time(error)
    }
  end

  defp determine_error_category(error) do
    case error do
      %File.Error{} -> :filesystem
      %Jason.DecodeError{} -> :data_format
      %FunctionClauseError{} -> :invalid_data
      %UndefinedFunctionError{} -> :missing_dependency
      %ArgumentError{} -> :invalid_argument
      %RuntimeError{} -> :runtime
      %Mix.Error{} -> :mix_task
      _ -> :unknown
    end
  end

  defp determine_error_severity(error) do
    case error do
      %File.Error{reason: :enoent} -> :medium
      %File.Error{reason: :eacces} -> :high
      %Jason.DecodeError{} -> :medium
      %UndefinedFunctionError{} -> :high
      %RuntimeError{} -> :high
      _ -> :medium
    end
  end

  defp analyze_likely_cause(error, task_name) do
    base_cause = case error do
      %File.Error{reason: :enoent} -> "Required file or directory does not exist"
      %File.Error{reason: :eacces} -> "Insufficient permissions to access file or directory"
      %Jason.DecodeError{} -> "Malformed JSON data in configuration or cache files"
      %UndefinedFunctionError{module: module} -> "Missing or uncompiled module: #{inspect(module)}"
      %ArgumentError{message: message} -> "Invalid argument: #{message}"
      _ -> "Unexpected error condition"
    end

    # Add task-specific context
    task_context = case task_name do
      "docs." <> _ -> " in documentation analysis"
      "sync." <> _ -> " in synchronization operations"
      _ -> " in task execution"
    end

    base_cause <> task_context
  end

  defp gather_error_context(error, task_name) do
    %{
      environment: Mix.env(),
      task_category: extract_task_category(task_name),
      system_info: %{
        elixir_version: System.version(),
        os: :os.type(),
        available_memory: get_available_memory()
      }
    }
  end

  defp is_automatically_fixable?(error) do
    case error do
      %File.Error{reason: :enoent} -> true # Can create missing directories
      %Jason.DecodeError{} -> false # Requires manual data fix
      %UndefinedFunctionError{} -> true # Can suggest dependency fixes
      _ -> false
    end
  end

  defp estimate_recovery_time(error) do
    case error do
      %File.Error{} -> "< 1 minute"
      %UndefinedFunctionError{} -> "2-5 minutes"
      %Jason.DecodeError{} -> "5-15 minutes"
      _ -> "Unknown"
    end
  end

  defp display_error_summary(error, error_context) do
    severity_color = case error_context.severity do
      :high -> :red
      :medium -> :yellow
      :low -> :blue
    end

    Mix.shell().error([
      severity_color, "Error Category: #{error_context.category}", :reset
    ])
    Mix.shell().error("Likely Cause: #{error_context.likely_cause}")
    Mix.shell().error("Estimated Recovery Time: #{error_context.recovery_time}")

    if error_context.fixable do
      Mix.shell().info([
        :green, "✓ This error may have automated fixes available", :reset
      ])
    end
  end

  defp display_error_details(error_context) do
    case error_context.error do
      %File.Error{reason: reason, path: path} ->
        Mix.shell().error([
          :red, "File Error Details:", :reset,
          "\n  Reason: #{reason}",
          "\n  Path: #{path}",
          "\n  Directory exists: #{File.dir?(Path.dirname(path))}",
          "\n  Path readable: #{File.exists?(path)}"
        ])

      %Jason.DecodeError{data: data, position: position} ->
        data_preview = String.slice(data, 0, 100)
        Mix.shell().error([
          :red, "JSON Error Details:", :reset,
          "\n  Position: #{position}",
          "\n  Data preview: #{data_preview}...",
          "\n  Data length: #{String.length(data)} characters"
        ])

      %UndefinedFunctionError{module: module, function: function, arity: arity} ->
        Mix.shell().error([
          :red, "Missing Function Details:", :reset,
          "\n  Module: #{inspect(module)}",
          "\n  Function: #{function}/#{arity}",
          "\n  Module loaded: #{Code.ensure_loaded?(module)}"
        ])

      _ ->
        Mix.shell().error("Error: #{Exception.message(error_context.error)}")
    end
  end

  defp display_recovery_suggestions(error_context) do
    suggestions = generate_fix_suggestions(error_context)

    if not Enum.empty?(suggestions) do
      Mix.shell().error([
        :yellow, "\n💡 Recovery Suggestions:", :reset
      ])

      suggestions
      |> Enum.with_index(1)
      |> Enum.each(fn {suggestion, index} ->
        Mix.shell().error("  #{index}. #{suggestion}")
      end)
    end
  end

  defp generate_fix_suggestions(error_context) do
    base_suggestions = case error_context.error do
      %File.Error{reason: :enoent, path: path} ->
        [
          "Create the missing directory: mkdir -p #{Path.dirname(path)}",
          "Verify the path is correct: #{path}",
          "Check if the file was moved or renamed"
        ]

      %File.Error{reason: :eacces, path: path} ->
        [
          "Check file permissions: ls -la #{path}",
          "Fix permissions: chmod 644 #{path} (or appropriate permissions)",
          "Ensure you have access to the parent directory"
        ]

      %Jason.DecodeError{} ->
        [
          "Validate JSON syntax in configuration files",
          "Remove or regenerate corrupted cache files",
          "Check for trailing commas or unescaped characters"
        ]

      %UndefinedFunctionError{module: module} ->
        [
          "Ensure dependencies are compiled: mix deps.get && mix compile",
          "Check if #{inspect(module)} is properly defined",
          "Verify the module is included in the application dependencies"
        ]

      _ ->
        [
          "Review the error details above for specific guidance",
          "Try running the command with --verbose for more information",
          "Check system requirements and dependencies"
        ]
    end

    # Add task-specific suggestions
    task_suggestions = case error_context.task_name do
      "docs." <> _ ->
        ["Ensure documentation directory exists and is readable"]
      "sync." <> _ ->
        ["Verify both documentation and code directories are accessible"]
      _ ->
        []
    end

    base_suggestions ++ task_suggestions
  end

  defp display_support_information(error_context) do
    error_id = generate_error_id(error_context)

    Mix.shell().error([
      :yellow, "\n📞 Support Information:", :reset,
      "\n  Error ID: #{error_id}",
      "\n  Task: #{error_context.task_name}",
      "\n  Category: #{error_context.category}",
      "\n  Severity: #{error_context.severity}"
    ])

    Mix.shell().error([
      :blue, "\n📚 Additional Resources:", :reset,
      "\n  • Documentation: docs/guides/troubleshooting.md",
      "\n  • Task help: mix #{error_context.task_name} --help",
      "\n  • System diagnostics: mix prismatic status",
      "\n  • Debug mode: MIX_DEBUG=1 mix #{error_context.task_name}"
    ])
  end

  defp display_validation_help(task_name, reason) do
    Mix.shell().error([
      :blue, "\n🔧 Configuration Help:", :reset,
      "\n  • View task options: mix #{task_name} --help",
      "\n  • Check configuration: mix prismatic.docs.validate --dry-run",
      "\n  • Example usage: Available in task documentation"
    ])

    # Provide specific help based on validation error
    specific_help = case reason do
      "Invalid arguments: " <> _ ->
        "\n  • Check argument syntax and spelling"
      "Invalid output format" <> _ ->
        "\n  • Supported formats: json, yaml, html, report, markdown"
      "does not exist" ->
        "\n  • Ensure all specified paths exist"
      _ ->
        ""
    end

    if specific_help != "" do
      Mix.shell().error([
        :yellow, "\n💡 Specific Help:", :reset, specific_help
      ])
    end
  end

  defp display_dependency_resolution_steps(missing_modules) do
    Mix.shell().error([
      :yellow, "\n🔧 Dependency Resolution Steps:", :reset,
      "\n  1. Update dependencies: mix deps.get",
      "\n  2. Compile application: mix compile",
      "\n  3. Verify installation: mix app.start",
      "\n  4. Check for version conflicts: mix deps.tree"
    ])

    # Module-specific suggestions
    if Enum.any?(missing_modules, &String.contains?(Atom.to_string(&1), "Jason")) do
      Mix.shell().error("  • Add Jason to dependencies for JSON support")
    end

    if Enum.any?(missing_modules, &String.contains?(Atom.to_string(&1), "YamlElixir")) do
      Mix.shell().error("  • Add YamlElixir to dependencies for YAML support")
    end
  end

  defp should_show_stacktrace?(error) do
    System.get_env("MIX_DEBUG") == "1" or
    Mix.env() == :dev or
    match?(%RuntimeError{}, error) or
    match?(%FunctionClauseError{}, error)
  end

  defp display_stacktrace(stacktrace) do
    Mix.shell().error([
      :yellow, "\n🔍 Stack Trace (MIX_DEBUG=1):", :reset
    ])
    Mix.shell().error(Exception.format_stacktrace(stacktrace))
  end

  defp handle_file_not_found_error(path, description) do
    Mix.shell().error([
      :red, "❌ File not found: ", :reset, "#{description}"
    ])
    Mix.shell().error("Path: #{path}")

    # Suggest similar paths if available
    similar_paths = suggest_similar_paths(path)
    if not Enum.empty?(similar_paths) do
      Mix.shell().info([
        :yellow, "Did you mean:", :reset
      ])
      Enum.each(similar_paths, fn similar_path ->
        Mix.shell().info("  • #{similar_path}")
      end)
    end

    System.halt(1)
  end

  defp handle_directory_access_error(path, description) do
    Mix.shell().error([
      :red, "❌ Directory access error: ", :reset, "#{description}"
    ])
    Mix.shell().error("Path: #{path}")
    Mix.shell().error("Check directory permissions and try again")
    System.halt(1)
  end

  defp handle_file_access_error(path, description) do
    Mix.shell().error([
      :red, "❌ File access error: ", :reset, "#{description}"
    ])
    Mix.shell().error("Path: #{path}")
    Mix.shell().error("Check file permissions and try again")
    System.halt(1)
  end

  defp handle_directory_creation_error(output_dir, reason) do
    Mix.shell().error([
      :red, "❌ Cannot create output directory: ", :reset, "#{output_dir}"
    ])
    Mix.shell().error("Reason: #{reason}")
    Mix.shell().error("Ensure parent directory exists and is writable")
    System.halt(1)
  end

  defp generate_error_id(error_context) do
    # Generate unique error ID for tracking and support
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    category = error_context.category
    task = String.replace(error_context.task_name, ".", "-")

    "#{String.upcase(Atom.to_string(category))}-#{task}-#{timestamp}"
  end

  defp extract_task_category(task_name) do
    case task_name do
      "docs." <> _ -> :docs
      "sync." <> _ -> :sync
      "code." <> _ -> :code
      "system." <> _ -> :system
      _ -> :general
    end
  end

  defp get_available_memory do
    case :erlang.memory(:total) do
      memory when is_integer(memory) -> memory
      _ -> 0
    end
  end

  defp suggest_similar_paths(path) do
    # Simple path suggestion logic
    dir = Path.dirname(path)
    filename = Path.basename(path)

    if File.dir?(dir) do
      File.ls!(dir)
      |> Enum.filter(fn file ->
        String.jaro_distance(String.downcase(file), String.downcase(filename)) > 0.7
      end)
      |> Enum.take(3)
      |> Enum.map(fn file -> Path.join(dir, file) end)
    else
      []
    end
  rescue
    _ -> []
  end
end
