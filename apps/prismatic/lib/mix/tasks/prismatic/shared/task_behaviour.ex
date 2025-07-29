defmodule Mix.Tasks.Prismatic.Shared.TaskBehaviour do
  @moduledoc """
  Common behaviour and utilities for all Prismatic tasks.

  Defines the standard interface and provides shared functionality including:
  - Option parsing and validation
  - Error handling with diagnostics
  - Progress monitoring and telemetry
  - CI/CD integration patterns
  - Consistent output formatting
  """

  @callback run([String.t()]) :: :ok | no_return()

  defmacro __using__(opts) do
    quote do
      @behaviour Mix.Tasks.Prismatic.Shared.TaskBehaviour

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
      """
      def get_option_parser_config() do
        [
          switches: [
            docs: :string,
            code: :string,
            output: :string,
            file: :string,
            ci: :boolean,
            verbose: :boolean,
            help: :boolean
          ],
          aliases: [
            d: :docs,
            c: :code,
            o: :output,
            f: :file,
            v: :verbose,
            h: :help
          ]
        ]
      end

      @doc """
      Get task-specific default configuration.
      Override in implementing modules for custom defaults.
      """
      def get_task_defaults() do
        %{
          file_prefix: extract_task_name(__MODULE__)
        }
      end

      @doc """
      Validate task-specific options.
      Override in implementing modules for custom validation.
      """
      def validate_task_options(_options) do
        :ok
      end

      @doc """
      Validate task prerequisites (directories, dependencies, etc.).
      Override in implementing modules for custom prerequisites.
      """
      def validate_task_prerequisites(options) do
        # Common validations
        ErrorHandler.validate_file_access(options.docs_path, "Documentation directory")

        if Map.has_key?(options, :code_path) do
          ErrorHandler.validate_file_access(options.code_path, "Code directory")
        end

        ErrorHandler.validate_output_directory(options.output_file)

        :ok
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
