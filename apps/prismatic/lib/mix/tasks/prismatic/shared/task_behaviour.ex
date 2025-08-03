defmodule Mix.Tasks.Prismatic.Shared.TaskBehaviour do
  @moduledoc """
  Common behaviour and utilities for all Prismatic tasks.

  Defines the standard interface and provides shared functionality including:
  - Option parsing and validation with common switches
  - Error handling with diagnostics
  - Progress monitoring and telemetry
  - CI/CD integration patterns
  - Consistent output formatting
  - Common validation helpers
  - Standardized prerequisite checks

  ## Usage

  To use TaskBehaviour in your Mix task:

      defmodule Mix.Tasks.MyApp.MyTask do
        use Mix.Tasks.Prismatic.Shared.TaskBehaviour,
          profile: :code,
          description: "My custom task"

        @impl Mix.Task
        def run(args) do
          with_task_context(__MODULE__, args, &execute_my_task/1)
        end

        # Override get_option_parser_config to add task-specific switches
        def get_option_parser_config do
          base_config = super()

          # Add your custom switches
          custom_switches = [my_option: :string]
          custom_aliases = [m: :my_option]

          [
            switches: base_config[:switches] ++ custom_switches,
            aliases: base_config[:aliases] ++ custom_aliases
          ]
        end

        defp execute_my_task(options) do
          # Your task implementation
          :ok
        end
      end

  ## Common Switches Provided

  TaskBehaviour automatically provides these common switches:

  - `--verbose, -v`: Enable verbose output
  - `--help, -h`: Show help information
  - `--output, -o`: Specify output file path
  - `--format, -f`: Set output format (console, json, html, yaml)
  - `--threshold, -t`: Set quality/coverage threshold (0-100)
  - `--dry-run, -d`: Preview changes without executing
  - `--ci`: Enable CI/CD mode with non-interactive output

  ## Validation Helpers

  TaskBehaviour provides common validation functions:

  - `validate_threshold/1`: Validates threshold values (0-100)
  - `validate_output_format/1`: Validates output format options
  - `validate_file_path/2`: Validates file paths with descriptive names
  - `validate_directory_path/2`: Validates directory paths
  - `validate_mix_project/0`: Ensures running in a Mix project

  ## Best Practices

  1. **Always use `with_task_context/3`** for task execution
  2. **Override validation functions** for custom requirements
  3. **Use common switches** instead of defining your own variants
  4. **Provide descriptive `@shortdoc`** for Mix task help
  5. **Document your options** in the module's `@moduledoc`
  """

  @callback run([String.t()]) :: :ok | no_return()

  # Common validation helper functions available to all tasks
  @doc """
  Validates a threshold value is between 0 and 100.
  """
  def validate_threshold(threshold) when is_integer(threshold) do
    if threshold >= 0 and threshold <= 100 do
      :ok
    else
      {:error, "Threshold must be between 0 and 100, got: #{threshold}"}
    end
  end

  def validate_threshold(threshold) do
    {:error, "Threshold must be an integer, got: #{inspect(threshold)}"}
  end

  @doc """
  Validates output format is one of the supported formats.
  """
  def validate_output_format(format) when is_binary(format) do
    supported_formats = ["console", "json", "html", "yaml", "xml", "text"]
    if format in supported_formats do
      :ok
    else
      {:error, "Invalid format '#{format}'. Supported: #{Enum.join(supported_formats, ", ")}"}
    end
  end

  def validate_output_format(format) do
    {:error, "Format must be a string, got: #{inspect(format)}"}
  end

  @doc """
  Validates a file path exists and is accessible.
  """
  def validate_file_path(path, description \\ "file")
  def validate_file_path(path, description) when is_binary(path) do
    cond do
      File.exists?(path) and File.regular?(path) ->
        :ok
      File.exists?(path) ->
        {:error, "#{String.capitalize(description)} path '#{path}' is not a regular file"}
      true ->
        {:error, "#{String.capitalize(description)} path '#{path}' does not exist"}
    end
  end

  def validate_file_path(path, description) do
    {:error, "#{String.capitalize(description)} path must be a string, got: #{inspect(path)}"}
  end

  @doc """
  Validates a directory path exists and is accessible.
  """
  def validate_directory_path(path, description \\ "directory")
  def validate_directory_path(path, description) when is_binary(path) do
    cond do
      File.exists?(path) and File.dir?(path) ->
        :ok
      File.exists?(path) ->
        {:error, "#{String.capitalize(description)} path '#{path}' is not a directory"}
      true ->
        {:error, "#{String.capitalize(description)} path '#{path}' does not exist"}
    end
  end

  def validate_directory_path(path, description) do
    {:error, "#{String.capitalize(description)} path must be a string, got: #{inspect(path)}"}
  end

  @doc """
  Validates we are running in a Mix project directory.
  """
  def validate_mix_project do
    if File.exists?("mix.exs") do
      :ok
    else
      {:error, "This command must be run in an Elixir project root directory (mix.exs not found)"}
    end
  end

  @doc """
  Validates that required tools/dependencies are available.
  """
  def validate_required_tools(tools) when is_list(tools) do
    missing_tools = Enum.filter(tools, fn tool ->
      case System.find_executable(tool) do
        nil -> true
        _ -> false
      end
    end)

    if Enum.empty?(missing_tools) do
      :ok
    else
      {:error, "Missing required tools: #{Enum.join(missing_tools, ", ")}"}
    end
  end

  @doc """
  Parse and validate comma-separated categories/aspects lists.
  Common pattern used across many tasks.
  """
  def parse_and_validate_categories(categories_str, valid_categories, category_type \\ "category")
  def parse_and_validate_categories("all", valid_categories, _), do: {:ok, valid_categories}
  def parse_and_validate_categories(nil, valid_categories, _), do: {:ok, valid_categories}
  def parse_and_validate_categories(categories_str, valid_categories, category_type) when is_binary(categories_str) do
    requested_categories = categories_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_atom/1)

    invalid_categories = requested_categories -- valid_categories

    if Enum.empty?(invalid_categories) do
      {:ok, requested_categories}
    else
      {:error, "Invalid #{category_type}(s): #{inspect(invalid_categories)}. Available: #{inspect(valid_categories)}"}
    end
  end
  def parse_and_validate_categories(categories, _valid_categories, category_type) do
    {:error, "#{String.capitalize(category_type)} list must be a string, got: #{inspect(categories)}"}
  end

  @doc """
  Validate that a value is one of the allowed values.
  Common pattern for level, environment, target validation.
  """
  def validate_enum_option(value, allowed_values, option_name)
  def validate_enum_option(nil, _allowed_values, _option_name), do: :ok
  def validate_enum_option(value, allowed_values, option_name) when is_binary(value) do
    if value in allowed_values do
      :ok
    else
      {:error, "Invalid #{option_name} '#{value}'. Available: #{Enum.join(allowed_values, ", ")}"}
    end
  end
  def validate_enum_option(value, _allowed_values, option_name) do
    {:error, "#{String.capitalize(option_name)} must be a string, got: #{inspect(value)}"}
  end

  @doc """
  Validate boolean dry-run option.
  """
  def validate_dry_run_option(nil), do: :ok
  def validate_dry_run_option(value) when is_boolean(value), do: :ok
  def validate_dry_run_option(value) do
    {:error, "Dry run option must be boolean, got: #{inspect(value)}"}
  end

  defmacro __using__(opts) do
    quote do
      @behaviour Mix.Tasks.Prismatic.Shared.TaskBehaviour

      # Import validation helper functions
      import Mix.Tasks.Prismatic.Shared.TaskBehaviour, only: [
        validate_threshold: 1,
        validate_output_format: 1,
        validate_file_path: 1,
        validate_file_path: 2,
        validate_directory_path: 1,
        validate_directory_path: 2,
        validate_mix_project: 0,
        validate_required_tools: 1,
        parse_and_validate_categories: 2,
        parse_and_validate_categories: 3,
        validate_enum_option: 3,
        validate_dry_run_option: 1
      ]

      alias Mix.Tasks.Prismatic.Shared.{Config, ErrorHandler, OutputFormatter, ProgressMonitor, Telemetry}

      require Logger

      # Task metadata
      @task_category unquote(opts[:category] || :general)
      @task_profile unquote(opts[:profile] || :default)

      @doc """
      Execute task with comprehensive error handling, progress monitoring, and telemetry.
      """
      def with_task_context(module, args, fun) do
        task_name = extract_task_name(module)
        start_time = System.monotonic_time(:millisecond)

        try do
          # Ensure application is started
          Mix.Task.run("app.start")

          # Parse and validate options
          case parse_and_validate_task_options(args) do
            {:ok, options} ->
              if options[:help] do
                show_task_help(module)
                :ok
              else
                # Validate task prerequisites
                validate_task_prerequisites(options)

                # Display configuration if verbose
                if options[:verbose] do
                  Config.display_config(options, task_name)
                end

                # Execute the task with monitoring
                result = execute_with_monitoring(fun, options, task_name)

                result
              end

            {:error, reason} ->
              ErrorHandler.handle_validation_error(reason, task_name)
          end

        rescue
          error ->
            execution_time = System.monotonic_time(:millisecond) - start_time
            ErrorHandler.handle_task_error(error, execution_time, task_name, __STACKTRACE__)
        end
      end

      @doc """
      Parse task-specific options with common validation.
      """
      def parse_and_validate_task_options(args) do
        {options, _, invalid} = OptionParser.parse(args, get_option_parser_config())

        cond do
          length(invalid) > 0 ->
            {:error, "Invalid arguments: #{inspect(invalid)}"}

          options[:help] ->
            {:ok, %{help: true}}

          true ->
            case validate_task_options(options) do
              :ok ->
                normalized_options = Config.normalize_config(options, get_task_defaults())
                {:ok, normalized_options}
              {:error, reason} ->
                {:error, reason}
            end
        end
      end

      @doc """
      Get option parser configuration for this task.
      Override in implementing modules for task-specific options.

      ## Common Switches Provided

      - `verbose`: Enable verbose output
      - `help`: Show help information
      - `output`: Specify output file path
      - `format`: Set output format (console, json, html, yaml)
      - `threshold`: Set quality/coverage threshold (0-100)
      - `dry_run`: Preview changes without executing
      - `ci`: Enable CI/CD mode with non-interactive output

      ## Legacy Switches (for backwards compatibility)

      - `docs`: Documentation directory path
      - `code`: Code directory path
      - `file`: Generic file path
      """
      def get_option_parser_config() do
        [
          switches: [
            # Common switches (new)
            verbose: :boolean,
            help: :boolean,
            output: :string,
            format: :string,
            threshold: :integer,
            dry_run: :boolean,
            ci: :boolean,
            # Legacy switches (backwards compatibility)
            docs: :string,
            code: :string,
            file: :string
          ],
          aliases: [
            # Common aliases
            v: :verbose,
            h: :help,
            o: :output,
            f: :format,
            t: :threshold,
            d: :dry_run,
            # Legacy aliases (backwards compatibility)
            docs_alias: :docs,
            c: :code,
            file_alias: :file
          ]
        ]
      end

      @doc """
      Get task-specific default configuration.
      Override in implementing modules for custom defaults.
      """
      def get_task_defaults() do
        %{
          # Common defaults
          verbose: false,
          format: "console",
          threshold: 80,
          dry_run: false,
          ci: false,
          # Task-specific defaults
          file_prefix: extract_task_name(__MODULE__)
        }
      end

      @doc """
      Validate task-specific options with common validation patterns.
      Override in implementing modules for additional custom validation.
      """
      def validate_task_options(options) do
        # Common validations using helper functions
        with :ok <- validate_common_option(:threshold, options[:threshold]),
             :ok <- validate_common_option(:format, options[:format]),
             :ok <- validate_common_option(:output, options[:output]) do
          :ok
        else
          {:error, reason} -> {:error, reason}
        end
      end

      @doc """
      Validate task prerequisites with enhanced common checks.
      Override in implementing modules for additional custom prerequisites.
      """
      def validate_task_prerequisites(options) do
        # Enhanced prerequisite validation
        with :ok <- validate_mix_project_if_needed(options),
             :ok <- validate_paths_if_provided(options),
             :ok <- validate_output_destination(options) do
          :ok
        else
          {:error, reason} -> raise reason
        end
      end

      # Common option validation helpers
      defp validate_common_option(:threshold, nil), do: :ok
      defp validate_common_option(:threshold, threshold), do: validate_threshold(threshold)

      defp validate_common_option(:format, nil), do: :ok
      defp validate_common_option(:format, format), do: validate_output_format(format)

      defp validate_common_option(:output, nil), do: :ok
      defp validate_common_option(:output, output) when is_binary(output) do
        # Validate output directory exists or can be created
        output_dir = Path.dirname(output)
        if output_dir != "." and not File.dir?(output_dir) do
          case File.mkdir_p(output_dir) do
            :ok -> :ok
            {:error, reason} -> {:error, "Cannot create output directory '#{output_dir}': #{reason}"}
          end
        else
          :ok
        end
      end
      defp validate_common_option(:output, output) do
        {:error, "Output path must be a string, got: #{inspect(output)}"}
      end

      # Enhanced prerequisite validation helpers
      defp validate_mix_project_if_needed(options) do
        # Only validate Mix project for tasks that need it (most do)
        # Tasks can override validate_task_prerequisites to skip this
        validate_mix_project()
      end

      defp validate_paths_if_provided(options) do
        # Validate legacy path options if provided
        with :ok <- validate_path_option(options, :docs, "Documentation directory"),
             :ok <- validate_path_option(options, :code, "Code directory"),
             :ok <- validate_path_option(options, :file, "File") do
          :ok
        end
      end

      defp validate_path_option(options, key, description) do
        case Map.get(options, key) do
          nil -> :ok
          path -> validate_directory_path(path, description)
        end
      end

      defp validate_output_destination(options) do
        case options[:output] do
          nil -> :ok
          output_file ->
            # Validate we can write to the output location
            output_dir = Path.dirname(output_file)
            if File.dir?(output_dir) do
              :ok
            else
              {:error, "Output directory '#{output_dir}' does not exist"}
            end
        end
      end

      @doc """
      Show comprehensive help for this task.
      Override in implementing modules for custom help.
      """
      def show_task_help(module) do
        case Code.fetch_docs(module) do
          {:docs_v1, _, :elixir, _, %{"en" => moduledoc}, _, _} ->
            Mix.shell().info(moduledoc)
          _ ->
            Mix.shell().info("No documentation available for #{inspect(module)}")
        end
      end

      defp execute_with_monitoring(fun, options, task_name) do
        # Start progress monitoring if enabled
        progress_monitor = if options[:show_progress] != false do
          ProgressMonitor.start_task_monitoring(task_name)
        else
          nil
        end

        try do
          # Execute the main task function
          result = fun.(options)

          # Show completion message
          if not options[:ci_mode] do
            ProgressMonitor.show_task_completion(task_name)
          end

          result

        after
          if progress_monitor do
            ProgressMonitor.stop_task_monitoring(progress_monitor)
          end
        end
      end

      defp extract_task_name(module) do
        module
        |> Module.split()
        |> List.last()
        |> String.downcase()
      end

      # Allow implementing modules to override these functions
      defoverridable [
        get_option_parser_config: 0,
        get_task_defaults: 0,
        validate_task_options: 1,
        validate_task_prerequisites: 1,
        show_task_help: 1
      ]
    end
  end
end
