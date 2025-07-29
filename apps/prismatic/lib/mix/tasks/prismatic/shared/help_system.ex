defmodule Mix.Tasks.Prismatic.Shared.HelpSystem do
  @moduledoc """
  Centralized help system with task discovery and documentation.

  Provides unified help interface, task discovery, search functionality,
  and cross-references for all Prismatic mix tasks.
  """

  @doc """
  Show comprehensive help with all available commands and categories.
  """
  @spec show_comprehensive_help() :: :ok
  def show_comprehensive_help do
    Mix.shell().info([
      :cyan, "\n🔧 Prismatic Unified Mix Tasks", :reset,
      "\n", String.duplicate("═", 50)
    ])

    show_command_categories()
    show_usage_examples()
    show_integration_examples()
    show_help_navigation()

    :ok
  end

  @doc """
  Show organized task list by category.
  """
  @spec show_task_list() :: :ok
  def show_task_list do
    Mix.shell().info([
      :cyan, "\n📋 Available Prismatic Tasks", :reset
    ])
    Mix.shell().info("═══════════════════════════════════════")

    task_categories()
    |> Enum.each(fn {category, tasks} ->
      Mix.shell().info([
        :green, "\n#{category}:", :reset
      ])

      Enum.each(tasks, fn {task, description} ->
        Mix.shell().info("  #{IO.ANSI.yellow()}mix #{task}#{IO.ANSI.reset()} - #{description}")
      end)
    end)

    Mix.shell().info([
      :blue, "\n💡 Use 'mix prismatic find <keyword>' to search for specific tasks", :reset
    ])

    :ok
  end

  @doc """
  Find tasks by keyword search.
  """
  @spec find_tasks(String.t()) :: :ok
  def find_tasks(keyword) do
    Mix.shell().info([
      :cyan, "\n🔍 Tasks matching '#{keyword}':", :reset
    ])

    matches = search_tasks(keyword)

    if Enum.empty?(matches) do
      Mix.shell().info("No tasks found matching '#{keyword}'")

      # Suggest similar keywords
      suggestions = suggest_keywords(keyword)
      if not Enum.empty?(suggestions) do
        Mix.shell().info([
          :yellow, "\nDid you mean:", :reset
        ])
        Enum.each(suggestions, fn suggestion ->
          Mix.shell().info("  • #{suggestion}")
        end)
      end
    else
      Enum.each(matches, fn {task, description, category} ->
        Mix.shell().info([
          "  ", :yellow, "mix #{task}", :reset, " - #{description} ",
          :light_black, "(#{category})", :reset
        ])
      end)

      Mix.shell().info([
        :blue, "\n💡 Use 'mix <task> --help' for detailed task documentation", :reset
      ])
    end

    :ok
  end

  @doc """
  Show related tasks for a given task.
  """
  @spec show_related_tasks(String.t()) :: :ok
  def show_related_tasks(task_name) do
    Mix.shell().info([
      :cyan, "\n🔗 Tasks related to '#{task_name}':", :reset
    ])

    related = find_related_tasks(task_name)

    if Enum.empty?(related) do
      Mix.shell().info("No related tasks found for '#{task_name}'")
    else
      Enum.each(related, fn {task, description, relationship} ->
        Mix.shell().info([
          "  ", :yellow, "mix #{task}", :reset, " - #{description} ",
          :light_black, "(#{relationship})", :reset
        ])
      end)
    end

    :ok
  end

  @doc """
  Show usage summary for invalid commands.
  """
  @spec show_usage_summary() :: :ok
  def show_usage_summary do
    Mix.shell().info("""
    Usage: mix prismatic [command] [options]

    Quick commands:
      mix prismatic --help        # Show comprehensive help
      mix prismatic list          # List all available tasks
      mix prismatic find <term>   # Search for tasks
      mix prismatic status        # Show system status

    Popular tasks:
      mix prismatic.docs.analyze  # Comprehensive documentation analysis
      mix prismatic.sync.monitor  # Monitor synchronization health
      mix prismatic.docs.validate # Validate documentation links

    Run 'mix prismatic --help' for full documentation.
    """)
    :ok
  end

  # Private functions

  defp show_command_categories do
    Mix.shell().info([
      :green, "\n📚 DOCUMENTATION ANALYSIS", :reset
    ])

    show_category_help([
      {"prismatic.docs.analyze", "Comprehensive multi-dimensional analysis"},
      {"prismatic.docs.validate", "Link validation and consistency checks"},
      {"prismatic.docs.report", "Health reporting and dashboards"},
      {"prismatic.docs.extract.adrs", "Architecture Decision Records extraction"},
      {"prismatic.docs.extract.examples", "Code examples extraction"},
      {"prismatic.docs.trace", "Traceability markers and matrices"},
      {"prismatic.docs.ai_data", "AI-optimized structured data generation"}
    ])

    Mix.shell().info([
      :green, "\n⚡ SYNCHRONIZATION OPERATIONS", :reset
    ])

    show_category_help([
      {"prismatic.sync.migrate", "Code migration framework"},
      {"prismatic.sync.references", "Reference replacement system"},
      {"prismatic.sync.bidirectional", "Real-time bidirectional sync"},
      {"prismatic.sync.hooks", "Version control integration"},
      {"prismatic.sync.monitor", "Drift detection and prevention"},
      {"prismatic.sync.health", "Synchronization health reporting"}
    ])

    Mix.shell().info([
      :green, "\n🔮 FUTURE EXTENSIONS", :reset
    ])

    show_category_help([
      {"prismatic.code.*", "Code Analysis & Transformation (planned)"},
      {"prismatic.system.*", "System Health & Monitoring (planned)"}
    ])
  end

  defp show_category_help(commands) do
    Enum.each(commands, fn {command, description} ->
      Mix.shell().info("  #{IO.ANSI.yellow()}mix #{command}#{IO.ANSI.reset()} - #{description}")
    end)
  end

  defp show_usage_examples do
    Mix.shell().info([
      :blue, "\n💡 COMMON USAGE PATTERNS", :reset
    ])

    examples = [
      {"Development Workflow", "mix prismatic.docs.analyze --verbose"},
      {"CI/CD Integration", "mix prismatic.docs.validate --ci --format json"},
      {"Content Maintenance", "mix prismatic.docs.extract.examples --language elixir"},
      {"Health Monitoring", "mix prismatic.sync.monitor --continuous"},
      {"System Diagnostics", "mix prismatic.sync.health --period 7d --format html"}
    ]

    Enum.each(examples, fn {title, command} ->
      Mix.shell().info([
        "  ", :cyan, title, :reset, ": ",
        :light_black, command, :reset
      ])
    end)
  end

  defp show_integration_examples do
    Mix.shell().info([
      :blue, "\n🔧 CI/CD INTEGRATION", :reset
    ])

    Mix.shell().info("""
      # GitHub Actions example
      - name: Validate Documentation
        run: |
          mix prismatic.docs.validate --ci --format json
          mix prismatic.sync.monitor --threshold 85

      # Quality gate example
      - name: Documentation Quality Gate
        run: mix prismatic.docs.report --format json | jq '.overall_score >= 85'
    """)
  end

  defp show_help_navigation do
    Mix.shell().info([
      :yellow, "\n📖 HELP NAVIGATION", :reset
    ])

    Mix.shell().info([
      "  • ", :cyan, "mix prismatic list", :reset, " - Browse all tasks by category",
      "\n  • ", :cyan, "mix prismatic find <term>", :reset, " - Search for specific functionality",
      "\n  • ", :cyan, "mix prismatic related <task>", :reset, " - Find related tasks",
      "\n  • ", :cyan, "mix <task> --help", :reset, " - Detailed help for any task",
      "\n  • ", :cyan, "mix prismatic status", :reset, " - Check system health"
    ])

    Mix.shell().info([
      :green, "\n✨ For detailed task help: mix <task-name> --help", :reset, "\n"
    ])
  end

  defp task_categories do
    [
      {"Documentation Analysis", [
        {"prismatic.docs.analyze", "Comprehensive multi-dimensional analysis"},
        {"prismatic.docs.validate", "Link validation and consistency checks"},
        {"prismatic.docs.report", "Health reporting and dashboards"},
        {"prismatic.docs.extract.adrs", "Architecture Decision Records extraction"},
        {"prismatic.docs.extract.examples", "Code examples extraction"},
        {"prismatic.docs.extract.links", "Link inventory and analysis"},
        {"prismatic.docs.trace", "Traceability markers and matrices"},
        {"prismatic.docs.ai_data", "AI-optimized structured data generation"}
      ]},
      {"Synchronization Operations", [
        {"prismatic.sync.migrate", "Code migration framework"},
        {"prismatic.sync.references", "Reference replacement system"},
        {"prismatic.sync.bidirectional", "Real-time bidirectional sync"},
        {"prismatic.sync.hooks", "Version control integration"},
        {"prismatic.sync.monitor", "Drift detection and prevention"},
        {"prismatic.sync.health", "Synchronization health reporting"}
      ]}
    ]
  end

  defp search_tasks(keyword) do
    all_tasks = task_categories()
    |> Enum.flat_map(fn {category, tasks} ->
      Enum.map(tasks, fn {task, description} ->
        {task, description, category}
      end)
    end)

    keyword_lower = String.downcase(keyword)

    all_tasks
    |> Enum.filter(fn {task, description, _category} ->
      String.contains?(String.downcase(task), keyword_lower) or
      String.contains?(String.downcase(description), keyword_lower)
    end)
  end

  defp suggest_keywords(keyword) do
    common_keywords = [
      "analyze", "validate", "extract", "sync", "monitor", "health",
      "trace", "migrate", "reference", "docs", "examples", "adrs"
    ]

    keyword_lower = String.downcase(keyword)

    common_keywords
    |> Enum.filter(fn suggested ->
      String.jaro_distance(keyword_lower, suggested) > 0.6
    end)
    |> Enum.take(3)
  end

  defp find_related_tasks(task_name) do
    # Simple relationship mapping - in a real implementation this could be more sophisticated
    relationships = %{
      "prismatic.docs.analyze" => [
        {"prismatic.docs.validate", "Validation follows analysis", "workflow"},
        {"prismatic.docs.report", "Reports use analysis results", "output"},
        {"prismatic.docs.trace", "Traceability complements analysis", "enhancement"}
      ],
      "prismatic.docs.validate" => [
        {"prismatic.docs.analyze", "Analysis provides validation context", "prerequisite"},
        {"prismatic.sync.monitor", "Monitors validation health", "monitoring"}
      ],
      "prismatic.sync.migrate" => [
        {"prismatic.sync.references", "References updated after migration", "workflow"},
        {"prismatic.sync.monitor", "Monitor migration health", "monitoring"}
      ],
      "prismatic.sync.monitor" => [
        {"prismatic.sync.health", "Health reporting for monitoring", "reporting"},
        {"prismatic.docs.validate", "Validates sync integrity", "validation"}
      ]
    }

    Map.get(relationships, task_name, [])
  end
end
