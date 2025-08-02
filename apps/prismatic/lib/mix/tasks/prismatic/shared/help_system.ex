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
  Show categorized help for all available tasks.
  """
  @spec show_categorized_help() :: :ok
  def show_categorized_help do
    show_command_categories()
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

    matches = search_tasks_internal(keyword)

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

  @doc """
  Search for tasks by keyword with scoring.
  """
  @spec search_tasks(String.t()) :: {:ok, list(), list()} | {:error, String.t()}
  def search_tasks(keyword) do
    # Validate input
    if String.trim(keyword) == "" do
      {:error, "Search keyword cannot be empty"}
    else
      try do
        matches = search_tasks_internal(keyword)
        suggestions = if Enum.empty?(matches) do
          suggest_keywords(keyword)
        else
          []
        end

        scored_matches = Enum.map(matches, fn {task, description, category} ->
          score = calculate_match_score(task, description, keyword)
          %{task: task, description: description, category: category, score: score}
        end)
        |> Enum.sort_by(& &1.score, :desc)

        {:ok, scored_matches, suggestions}
      rescue
        error ->
          {:error, "Search failed: #{Exception.message(error)}"}
      end
    end
 end

 # Helper functions for the new API
 defp calculate_match_score(task, description, keyword) do
   keyword_lower = String.downcase(keyword)
   task_lower = String.downcase(task)
   desc_lower = String.downcase(description)

   score = 0

   # Exact match in task name gets highest score
   score = if String.contains?(task_lower, keyword_lower) do
     score + 100
   else
     score
   end

   # Match in description gets medium score
   score = if String.contains?(desc_lower, keyword_lower) do
     score + 50
   else
     score
   end

   # Jaro distance for fuzzy matching
   task_similarity = String.jaro_distance(task_lower, keyword_lower)
   desc_similarity = String.jaro_distance(desc_lower, keyword_lower)

   score + (task_similarity * 30) + (desc_similarity * 20)
 end

 defp find_related_tasks_by_keyword(keyword) do
   # Find tasks related to a keyword by category or common functionality
   keyword_lower = String.downcase(keyword)

   all_tasks = task_categories()
   |> Enum.flat_map(fn {category, tasks} ->
     Enum.map(tasks, fn {task, description} ->
       {task, description, category}
     end)
   end)

   # Filter tasks that share similar functionality or category
   all_tasks
   |> Enum.filter(fn {task, description, _category} ->
     task_words = String.split(String.downcase(task), ".")
     desc_words = String.split(String.downcase(description), [" ", "-", "_"])

     Enum.any?(task_words ++ desc_words, fn word ->
       String.jaro_distance(word, keyword_lower) > 0.7
     end)
   end)
   |> Enum.map(fn {task, _description, _category} -> task end)
   |> Enum.take(5)
  end

  @doc """
  Get related tasks for a given keyword.
  """
  @spec get_related_tasks(String.t()) :: {:ok, list()} | {:error, String.t()}
  def get_related_tasks(keyword) do
    if String.trim(keyword) == "" do
      {:error, "Keyword cannot be empty"}
    else
      try do
        related = find_related_tasks_by_keyword(keyword)
        {:ok, related}
      rescue
        error ->
          {:error, "Failed to find related tasks: #{Exception.message(error)}"}
      end
    end
  end

  # Private functions

  defp show_command_categories do
    Mix.shell().info([
      :green, "\n📚 DOCUMENTATION TASKS", :reset
    ])

    show_category_help([
      {"prismatic.docs.sync", "Bidirectional documentation synchronization"}
    ])

    Mix.shell().info([
      :green, "\n🌿 BRANCH & WORKFLOW MANAGEMENT", :reset
    ])

    show_category_help([
      {"prismatic.branch.create", "Automated branch creation with templates"},
      {"prismatic.branch.validate", "Branch compliance validation"},
      {"prismatic.workflow.status", "Comprehensive workflow monitoring"},
      {"prismatic.version.bump", "Semantic versioning with changelog generation"}
    ])

    Mix.shell().info([
      :green, "\n🛠️ DEVELOPMENT TASKS", :reset
    ])

    show_category_help([
      {"prismatic.setup", "Project setup and initialization"},
      {"prismatic.check", "Comprehensive health checking"},
      {"prismatic.test.coverage", "Advanced test coverage analysis"},
      {"prismatic.quality.check", "Code quality validation and metrics"}
    ])

    Mix.shell().info([
      :green, "\n🚀 DEPLOYMENT & RELEASE TASKS", :reset
    ])

    show_category_help([
      {"prismatic.deploy.prepare", "Deployment preparation and configuration"},
      {"prismatic.deploy.validate", "Deployment readiness validation"},
      {"prismatic.release.create", "Comprehensive release creation and packaging"}
    ])

    Mix.shell().info([
      :green, "\n📦 LEGACY TASKS", :reset
    ])

    show_category_help([
      {"prismatic.sync.migrate", "Content synchronization between sources"},
      {"prismatic.docs.analyze", "Documentation analysis and validation"},
      {"prismatic.docs.validate", "Link validation and consistency checks"}
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
      {"Documentation Tasks", [
        {"prismatic.docs.sync", "Bidirectional documentation synchronization"}
      ]},
      {"Branch & Workflow Management", [
        {"prismatic.branch.create", "Automated branch creation with templates"},
        {"prismatic.branch.validate", "Branch compliance validation"},
        {"prismatic.workflow.status", "Comprehensive workflow monitoring"},
        {"prismatic.version.bump", "Semantic versioning with changelog generation"}
      ]},
      {"Development Tasks", [
        {"prismatic.setup", "Project setup and initialization"},
        {"prismatic.check", "Comprehensive health checking"},
        {"prismatic.test.coverage", "Advanced test coverage analysis"},
        {"prismatic.quality.check", "Code quality validation and metrics"}
      ]},
      {"Deployment & Release Tasks", [
        {"prismatic.deploy.prepare", "Deployment preparation and configuration"},
        {"prismatic.deploy.validate", "Deployment readiness validation"},
        {"prismatic.release.create", "Comprehensive release creation and packaging"}
      ]},
      {"Legacy Tasks", [
        {"prismatic.sync.migrate", "Content synchronization between sources"},
        {"prismatic.docs.analyze", "Documentation analysis and validation"},
        {"prismatic.docs.validate", "Link validation and consistency checks"}
      ]}
    ]
  end

  defp search_tasks_internal(keyword) do
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
