defmodule Mix.Tasks.Docs.Dispatcher do
  @moduledoc """
  Main dispatcher for documentation analysis tasks.

  Handles command parsing, validation, and routing to appropriate task modules.
  Provides consistent command-line interface and help system across all tasks.
  """

  alias Mix.Tasks.Docs.Shared.{ErrorHandler, ProgressMonitor}

  @available_commands ~w(analyze extract_adrs extract_examples trace ai_data validate report)

  @doc """
  Parse and execute documentation analysis commands.
  """
  @spec run([String.t()]) :: :ok | no_return()
  def run(args) do
    start_time = System.monotonic_time(:millisecond)

    ErrorHandler.safe_execute("docs", "command execution", fn ->
      case parse_args(args) do
        {:help} ->
          show_comprehensive_help()

        {:command, command, command_args} ->
          execute_command_with_monitoring(command, command_args, start_time)

        {:error, reason} ->
          ErrorHandler.handle_validation_error(reason, "docs")
      end
    end)
  end

  @doc """
  Parse command line arguments.
  """
  @spec parse_args([String.t()]) :: {:help} | {:command, String.t(), [String.t()]} | {:error, String.t()}
  def parse_args(args) do
    case args do
      [] -> {:help}
      ["--help"] -> {:help}
      ["-h"] -> {:help}
      ["help"] -> {:help}

      [command | rest] when command in @available_commands ->
        {:command, command, rest}

      [unknown_command | _] ->
        {:error, "Unknown command '#{unknown_command}'. Available commands: #{Enum.join(@available_commands, ", ")}"}

      _ ->
        {:error, "Invalid argument format"}
    end
  end

  @doc """
  Display comprehensive help information.
  """
  @spec show_comprehensive_help() :: :ok
  def show_comprehensive_help do
    Mix.shell().info([
      :cyan, "\n🔍 Prismatic Documentation Analysis Toolkit", :reset, "\n",
      String.duplicate("═", 55), "\n"
    ])

    show_command_categories()
    show_usage_examples()
    show_ci_integration_examples()

    :ok
  end

  @doc """
  Show usage summary for invalid commands.
  """
  @spec show_usage_summary() :: :ok
  def show_usage_summary do
    Mix.shell().info("""
    Usage: mix docs <command> [options]

    Available commands: #{Enum.join(@available_commands, ", ")}

    Run 'mix docs --help' for detailed information and examples.
    """)
    :ok
  end

  # Private functions

  defp execute_command_with_monitoring(command, args, start_time) do
    Mix.shell().info([
      :blue, "🚀 Starting ", :cyan, "docs.#{command}", :reset,
      (if length(args) > 0, do: " with args: #{inspect(args)}", else: "")
    ])

    result = dispatch_to_task_module(command, args)

    execution_time = System.monotonic_time(:millisecond) - start_time
    ProgressMonitor.show_completion("docs.#{command}", execution_time)

    result
  end

  defp dispatch_to_task_module(command, args) do
    case command do
      "analyze" -> Mix.Tasks.Docs.Tasks.Analyze.run(args)
      "extract_adrs" -> Mix.Tasks.Docs.Tasks.ExtractAdrs.run(args)
      "extract_examples" -> Mix.Tasks.Docs.Tasks.ExtractExamples.run(args)
      "trace" -> Mix.Tasks.Docs.Tasks.Trace.run(args)
      "ai_data" -> Mix.Tasks.Docs.Tasks.AiData.run(args)
      "validate" -> Mix.Tasks.Docs.Tasks.Validate.run(args)
      "report" -> Mix.Tasks.Docs.Tasks.Report.run(args)
    end
  end

  defp show_command_categories do
    Mix.shell().info([
      :green, "CORE ANALYSIS COMMANDS", :reset
    ])

    show_command_help([
      {"docs.analyze", "Comprehensive multi-dimensional documentation analysis"},
      {"docs.validate", "Validate links, references, and structural consistency"},
      {"docs.report", "Generate detailed health and analysis reports"}
    ])

    Mix.shell().info([
      :green, "\nCONTENT EXTRACTION COMMANDS", :reset
    ])

    show_command_help([
      {"docs.extract_adrs", "Extract and analyze Architecture Decision Records"},
      {"docs.extract_examples", "Extract and categorize code examples from docs"},
      {"docs.trace", "Generate bidirectional traceability markers"}
    ])

    Mix.shell().info([
      :green, "\nAI INTEGRATION COMMANDS", :reset
    ])

    show_command_help([
      {"docs.ai_data", "Generate AI-optimized structured documentation data"}
    ])
  end

  defp show_command_help(commands) do
    Enum.each(commands, fn {command, description} ->
      Mix.shell().info("  #{IO.ANSI.yellow()}mix #{command}#{IO.ANSI.reset()} - #{description}")
    end)
  end

  defp show_usage_examples do
    Mix.shell().info([
      :blue, "\n💡 COMMON USAGE PATTERNS", :reset
    ])

    examples = [
      {"Development Workflow", "mix docs.analyze --verbose --output dev-analysis.json"},
      {"CI/CD Integration", "mix docs.validate --ci --format json --output validation.json"},
      {"Content Audit", "mix docs.extract_examples --language elixir --executable"},
      {"Health Reporting", "mix docs.report --format html --sections all"},
      {"Traceability Matrix", "mix docs.trace --docs docs --code apps --matrix"}
    ]

    Enum.each(examples, fn {title, command} ->
      Mix.shell().info([
        "  ", :cyan, title, :reset, ": ",
        :light_black, command, :reset
      ])
    end)
  end

  defp show_ci_integration_examples do
    Mix.shell().info([
      :blue, "\n🔧 CI/CD INTEGRATION", :reset
    ])

    Mix.shell().info("""
      # GitHub Actions example
      - name: Validate Documentation
        run: |
          mix docs.validate --ci --format json --output docs-validation.json
          mix docs.analyze --output docs-analysis.json

      # Quality gate example
      - name: Documentation Quality Gate
        run: mix docs.report --format json --sections summary | jq '.overall_score >= 85'
    """)

    Mix.shell().info([
      :yellow, "\n📚 For detailed help on any command:", :reset, " mix docs.[command] --help\n"
    ])
  end
end
