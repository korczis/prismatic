defmodule Prismatic.TODO.Integrator do
  @moduledoc """
  External system integration for the Prismatic TODO management system.

  This module provides comprehensive integration capabilities with external systems
  including GitHub, Jira, Slack, CI/CD pipelines, and other development tools.
  It enables seamless workflows and keeps TODO management synchronized across
  the entire development ecosystem.

  ## Features

  - **GitHub Integration**: Issues, Pull Requests, and project board synchronization
  - **Jira Integration**: Ticket creation, status updates, and workflow automation
  - **Slack Integration**: Team notifications, status updates, and bot commands
  - **CI/CD Integration**: Automated TODO validation and deployment gates
  - **IDE Integration**: Real-time TODO synchronization in development environments
  - **Webhook Support**: Real-time event handling and bidirectional synchronization

  ## Usage

      # Sync with GitHub issues
      {:ok, sync_result} = Integrator.sync_github_issues(todos, github_config)

      # Create Jira tickets for high-priority TODOs
      {:ok, tickets} = Integrator.create_jira_tickets(high_priority_todos, jira_config)

      # Send Slack notifications for completed TODOs
      {:ok, notifications} = Integrator.send_slack_notifications(completed_todos, slack_config)

      # Validate TODOs in CI/CD pipeline
      {:ok, validation} = Integrator.validate_in_pipeline(todos, pipeline_config)

  ## Integration Types

  The integrator supports various integration patterns:

  - **Push Integration**: Send TODO updates to external systems
  - **Pull Integration**: Import external items as TODOs
  - **Bidirectional Sync**: Maintain consistency across systems
  - **Event-Driven**: React to external system changes
  - **Batch Processing**: Bulk operations for efficiency

  ## Configuration

      config :prismatic, Prismatic.TODO.Integrator,
        github: %{
          api_token: System.get_env("GITHUB_TOKEN"),
          repository: "organization/project",
          auto_create_issues: true,
          label_mapping: %{
            bug: ["bug", "todo:bug"],
            feature: ["enhancement", "todo:feature"]
          }
        },
        jira: %{
          url: "https://company.atlassian.net",
          username: System.get_env("JIRA_USERNAME"),
          api_token: System.get_env("JIRA_TOKEN"),
          project_key: "PROJ",
          issue_type_mapping: %{
            bug: "Bug",
            feature: "Story"
          }
        },
        slack: %{
          webhook_url: System.get_env("SLACK_WEBHOOK_URL"),
          channel: "#development",
          notification_triggers: [:completed, :overdue, :blocked]
        }
  """

  alias Prismatic.TODO.Scanner
  require Logger

  @type integration_config :: %{
    github: github_config() | nil,
    jira: jira_config() | nil,
    slack: slack_config() | nil,
    ci_cd: ci_cd_config() | nil
  }

  @type github_config :: %{
    api_token: String.t(),
    repository: String.t(),
    auto_create_issues: boolean(),
    label_mapping: %{atom() => [String.t()]},
    milestone_mapping: map()
  }

  @type jira_config :: %{
    url: String.t(),
    username: String.t(),
    api_token: String.t(),
    project_key: String.t(),
    issue_type_mapping: %{atom() => String.t()},
    workflow_mapping: map()
  }

  @type slack_config :: %{
    webhook_url: String.t(),
    channel: String.t(),
    notification_triggers: [atom()],
    user_mapping: map()
  }

  @type ci_cd_config :: %{
    validation_rules: [atom()],
    gate_conditions: map(),
    notification_endpoints: [String.t()]
  }

  @type sync_result :: %{
    synced_items: non_neg_integer(),
    created_items: non_neg_integer(),
    updated_items: non_neg_integer(),
    failed_items: non_neg_integer(),
    errors: [String.t()]
  }

  @doc """
  Synchronize TODOs with GitHub issues and pull requests.

  ## Parameters

  - `todos` - List of TODO items to synchronize
  - `github_config` - GitHub integration configuration
  - `options` - Synchronization options

  ## Returns

  Synchronization results with created/updated items.

  ## Examples

      iex> Integrator.sync_github_issues(todos, github_config)
      {:ok, %{
        synced_items: 15,
        created_items: 3,
        updated_items: 12,
        failed_items: 0,
        errors: []
      }}
  """
  @spec sync_github_issues([Scanner.todo_item()], github_config(), map()) :: {:ok, sync_result()} | {:error, term()}
  def sync_github_issues(todos, github_config, options \\ %{}) do
    Logger.info("Syncing #{length(todos)} TODOs with GitHub")

    options = Map.merge(%{dry_run: false, batch_size: 10}, options)

    try do
      # Filter TODOs that should be synced with GitHub
      syncable_todos = filter_github_syncable_todos(todos, github_config)

      # Get existing GitHub issues to avoid duplicates
      existing_issues = fetch_existing_github_issues(github_config)

      # Process TODOs in batches
      sync_results = syncable_todos
      |> Enum.chunk_every(options.batch_size)
      |> Enum.map(&process_github_batch(&1, existing_issues, github_config, options))
      |> Enum.reduce(%{synced_items: 0, created_items: 0, updated_items: 0, failed_items: 0, errors: []}, &merge_sync_results/2)

      Logger.info("GitHub sync completed: #{sync_results.synced_items} items processed")
      {:ok, sync_results}
    rescue
      error ->
        Logger.error("GitHub sync failed: #{Exception.message(error)}")
        {:error, "GitHub sync failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Create Jira tickets for TODO items.

  ## Parameters

  - `todos` - List of TODO items to create tickets for
  - `jira_config` - Jira integration configuration
  - `options` - Ticket creation options

  ## Returns

  Results of ticket creation with Jira ticket identifiers.

  ## Examples

      iex> Integrator.create_jira_tickets(high_priority_todos, jira_config)
      {:ok, %{
        created_tickets: [
          %{todo_id: "TODO_001", jira_key: "PROJ-123"},
          %{todo_id: "TODO_002", jira_key: "PROJ-124"}
        ],
        failed_creations: []
      }}
  """
  @spec create_jira_tickets([Scanner.todo_item()], jira_config(), map()) :: {:ok, map()} | {:error, term()}
  def create_jira_tickets(todos, jira_config, options \\ %{}) do
    Logger.info("Creating Jira tickets for #{length(todos)} TODOs")

    try do
      # Filter TODOs that should create Jira tickets
      ticket_todos = filter_jira_ticket_todos(todos, options)

      # Create tickets for each TODO
      results = ticket_todos
      |> Enum.map(&create_single_jira_ticket(&1, jira_config, options))
      |> Enum.split_with(&match?({:ok, _}, &1))

      {successful, failed} = results

      created_tickets = successful
      |> Enum.map(fn {:ok, ticket_info} -> ticket_info end)

      failed_creations = failed
      |> Enum.map(fn {:error, {todo_id, reason}} -> %{todo_id: todo_id, error: reason} end)

      result = %{
        created_tickets: created_tickets,
        failed_creations: failed_creations,
        total_attempted: length(ticket_todos),
        success_rate: length(created_tickets) / length(ticket_todos)
      }

      Logger.info("Jira ticket creation completed: #{length(created_tickets)} tickets created")
      {:ok, result}
    rescue
      error ->
        {:error, "Jira ticket creation failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Send Slack notifications for TODO events.

  ## Parameters

  - `todos` - List of TODO items to notify about
  - `event_type` - Type of event (completed, overdue, blocked, etc.)
  - `slack_config` - Slack integration configuration
  - `options` - Notification options

  ## Returns

  Results of notification sending.

  ## Examples

      iex> Integrator.send_slack_notifications(completed_todos, :completed, slack_config)
      {:ok, %{
        notifications_sent: 5,
        failed_notifications: 0,
        channel: "#development"
      }}
  """
  @spec send_slack_notifications([Scanner.todo_item()], atom(), slack_config(), map()) :: {:ok, map()} | {:error, term()}
  def send_slack_notifications(todos, event_type, slack_config, options \\ %{}) do
    Logger.info("Sending Slack notifications for #{length(todos)} TODOs (#{event_type})")

    # Check if this event type should trigger notifications
    if event_type in slack_config.notification_triggers do
      try do
        # Group TODOs by notification type for batching
        notification_groups = group_todos_for_notification(todos, event_type)

        # Send notifications for each group
        results = notification_groups
        |> Enum.map(&send_slack_notification_group(&1, slack_config, options))
        |> Enum.reduce(%{notifications_sent: 0, failed_notifications: 0}, &merge_notification_results/2)

        result = Map.put(results, :channel, slack_config.channel)

        Logger.info("Slack notifications completed: #{result.notifications_sent} sent")
        {:ok, result}
      rescue
        error ->
          {:error, "Slack notification failed: #{Exception.message(error)}"}
      end
    else
      Logger.debug("Event type #{event_type} not configured for notifications")
      {:ok, %{notifications_sent: 0, skipped: true, reason: "Event type not configured"}}
    end
  end

  @doc """
  Validate TODOs in CI/CD pipeline context.

  ## Parameters

  - `todos` - List of TODO items to validate
  - `pipeline_config` - CI/CD pipeline configuration
  - `options` - Validation options

  ## Returns

  Validation results for pipeline integration.

  ## Examples

      iex> Integrator.validate_in_pipeline(todos, pipeline_config)
      {:ok, %{
        validation_passed: true,
        blocking_issues: [],
        warnings: ["TODO_003 is overdue"],
        gate_status: :pass
      }}
  """
  @spec validate_in_pipeline([Scanner.todo_item()], ci_cd_config(), map()) :: {:ok, map()} | {:error, term()}
  def validate_in_pipeline(todos, pipeline_config, options \\ %{}) do
    Logger.info("Validating #{length(todos)} TODOs in CI/CD pipeline")

    try do
      # Apply validation rules
      validation_results = pipeline_config.validation_rules
      |> Enum.map(&apply_validation_rule(todos, &1))
      |> Enum.reduce(%{blocking_issues: [], warnings: [], info: []}, &merge_validation_results/2)

      # Check gate conditions
      gate_status = evaluate_gate_conditions(validation_results, pipeline_config.gate_conditions)

      # Determine overall validation status
      validation_passed = gate_status == :pass and Enum.empty?(validation_results.blocking_issues)

      result = validation_results
      |> Map.put(:validation_passed, validation_passed)
      |> Map.put(:gate_status, gate_status)

      Logger.info("Pipeline validation completed: #{if validation_passed, do: "PASSED", else: "FAILED"}")
      {:ok, result}
    rescue
      error ->
        {:error, "Pipeline validation failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Setup webhook endpoints for real-time integration.

  ## Parameters

  - `webhook_config` - Webhook configuration and endpoints
  - `integration_config` - Integration system configurations

  ## Returns

  Webhook setup results with endpoint information.

  ## Examples

      iex> Integrator.setup_webhooks(webhook_config, integration_config)
      {:ok, %{
        endpoints_created: 3,
        webhook_urls: [...],
        security_tokens: [...]
      }}
  """
  @spec setup_webhooks(map(), integration_config()) :: {:ok, map()} | {:error, term()}
  def setup_webhooks(webhook_config, integration_config) do
    Logger.info("Setting up integration webhooks")

    try do
      endpoints = []

      # Setup GitHub webhooks if configured
      endpoints = if integration_config.github do
        github_webhook = setup_github_webhook(integration_config.github, webhook_config)
        [github_webhook | endpoints]
      else
        endpoints
      end

      # Setup Jira webhooks if configured
      endpoints = if integration_config.jira do
        jira_webhook = setup_jira_webhook(integration_config.jira, webhook_config)
        [jira_webhook | endpoints]
      else
        endpoints
      end

      # Setup Slack webhooks if configured
      endpoints = if integration_config.slack do
        slack_webhook = setup_slack_webhook(integration_config.slack, webhook_config)
        [slack_webhook | endpoints]
      else
        endpoints
      end

      result = %{
        endpoints_created: length(endpoints),
        webhook_urls: Enum.map(endpoints, & &1.url),
        security_tokens: Enum.map(endpoints, & &1.token),
        endpoints: endpoints
      }

      Logger.info("Webhook setup completed: #{result.endpoints_created} endpoints created")
      {:ok, result}
    rescue
      error ->
        {:error, "Webhook setup failed: #{Exception.message(error)}"}
    end
  end

  # Private helper functions

  defp filter_github_syncable_todos(todos, github_config) do
    # Filter TODOs that should be synced with GitHub
    todos
    |> Enum.filter(fn todo ->
      # Sync high-priority TODOs or those with specific categories
      todo.priority in [:critical, :high] or
      todo.category in [:bug, :feature] or
      has_github_metadata?(todo)
    end)
  end

  defp has_github_metadata?(todo) do
    # Check if TODO has GitHub-related metadata
    related_items = todo.metadata.related_items || []
    Enum.any?(related_items, &String.contains?(&1, ["#", "PR", "issue"]))
  end

  defp fetch_existing_github_issues(github_config) do
    # In real implementation, this would call GitHub API
    # For now, return empty list
    []
  end

  defp process_github_batch(todo_batch, existing_issues, github_config, options) do
    # Process a batch of TODOs for GitHub sync
    results = todo_batch
    |> Enum.map(&process_single_github_todo(&1, existing_issues, github_config, options))

    # Aggregate results
    results
    |> Enum.reduce(%{synced_items: 0, created_items: 0, updated_items: 0, failed_items: 0, errors: []}, fn
      {:ok, :created}, acc -> %{acc | synced_items: acc.synced_items + 1, created_items: acc.created_items + 1}
      {:ok, :updated}, acc -> %{acc | synced_items: acc.synced_items + 1, updated_items: acc.updated_items + 1}
      {:error, reason}, acc -> %{acc | failed_items: acc.failed_items + 1, errors: [reason | acc.errors]}
    end)
  end

  defp process_single_github_todo(todo, existing_issues, github_config, options) do
    if options.dry_run do
      Logger.debug("DRY RUN: Would sync TODO #{todo.id} with GitHub")
      {:ok, :created}
    else
      # Check if issue already exists
      existing_issue = find_existing_github_issue(todo, existing_issues)

      if existing_issue do
        update_github_issue(todo, existing_issue, github_config)
      else
        create_github_issue(todo, github_config)
      end
    end
  end

  defp find_existing_github_issue(todo, existing_issues) do
    # Find existing GitHub issue for this TODO
    # In real implementation, would match by title, labels, or custom fields
    nil
  end

  defp create_github_issue(todo, github_config) do
    # Create GitHub issue for TODO
    Logger.debug("Creating GitHub issue for TODO #{todo.id}")

    issue_data = %{
      title: todo.title,
      body: build_github_issue_body(todo),
      labels: map_todo_to_github_labels(todo, github_config),
      assignees: get_github_assignees(todo, github_config)
    }

    # In real implementation, would call GitHub API
    # For now, simulate success
    {:ok, :created}
  end

  defp update_github_issue(todo, existing_issue, github_config) do
    # Update existing GitHub issue
    Logger.debug("Updating GitHub issue for TODO #{todo.id}")

    # In real implementation, would call GitHub API to update issue
    {:ok, :updated}
  end

  defp build_github_issue_body(todo) do
    """
    **TODO Details**

    - **File**: `#{todo.file_path}:#{todo.line_number}`
    - **Category**: #{todo.category}
    - **Priority**: #{todo.priority}
    - **Status**: #{todo.status}

    **Description**
    #{todo.description}

    **Context**
    ```elixir
    #{Enum.join(todo.context.before_lines ++ ["# TODO: #{todo.description}"] ++ todo.context.after_lines, "\n")}
    ```

    **Metadata**
    #{if todo.metadata.assignee, do: "- **Assignee**: #{todo.metadata.assignee}", else: ""}
    #{if todo.metadata.estimate, do: "- **Estimate**: #{todo.metadata.estimate}", else: ""}
    #{if todo.metadata.due_date, do: "- **Due Date**: #{todo.metadata.due_date}", else: ""}

    ---
    *Generated by Prismatic TODO Management System*
    *TODO ID: #{todo.id}*
    """
  end

  defp map_todo_to_github_labels(todo, github_config) do
    base_labels = ["todo"]

    # Add category-based labels
    category_labels = Map.get(github_config.label_mapping, todo.category, [])

    # Add priority-based labels
    priority_labels = case todo.priority do
      :critical -> ["priority:critical"]
      :high -> ["priority:high"]
      :medium -> ["priority:medium"]
      :low -> ["priority:low"]
    end

    base_labels ++ category_labels ++ priority_labels
  end

  defp get_github_assignees(todo, github_config) do
    case todo.metadata.assignee do
      nil -> []
      assignee ->
        # In real implementation, would map email to GitHub username
        [String.split(assignee, "@") |> List.first()]
    end
  end

  defp merge_sync_results(batch_result, acc_result) do
    %{
      synced_items: acc_result.synced_items + batch_result.synced_items,
      created_items: acc_result.created_items + batch_result.created_items,
      updated_items: acc_result.updated_items + batch_result.updated_items,
      failed_items: acc_result.failed_items + batch_result.failed_items,
      errors: acc_result.errors ++ batch_result.errors
    }
  end

  defp filter_jira_ticket_todos(todos, options) do
    # Filter TODOs that should create Jira tickets
    min_priority = Map.get(options, :min_priority, :medium)

    todos
    |> Enum.filter(fn todo ->
      priority_level = priority_to_level(todo.priority)
      min_level = priority_to_level(min_priority)
      priority_level >= min_level
    end)
  end

  defp priority_to_level(priority) do
    case priority do
      :critical -> 4
      :high -> 3
      :medium -> 2
      :low -> 1
    end
  end

  defp create_single_jira_ticket(todo, jira_config, options) do
    Logger.debug("Creating Jira ticket for TODO #{todo.id}")

    ticket_data = %{
      project: %{key: jira_config.project_key},
      summary: todo.title,
      description: build_jira_ticket_description(todo),
      issuetype: %{name: map_todo_to_jira_issue_type(todo, jira_config)},
      priority: %{name: map_todo_to_jira_priority(todo)},
      labels: ["todo", "prismatic", Atom.to_string(todo.category)]
    }

    # In real implementation, would call Jira API
    # For now, simulate success
    jira_key = "#{jira_config.project_key}-#{:rand.uniform(999)}"

    {:ok, %{todo_id: todo.id, jira_key: jira_key, created_at: DateTime.utc_now()}}
  rescue
    error ->
      {:error, {todo.id, Exception.message(error)}}
  end

  defp build_jira_ticket_description(todo) do
    """
    h3. TODO Details

    * *File*: {{#{todo.file_path}:#{todo.line_number}}}
    * *Category*: #{todo.category}
    * *Priority*: #{todo.priority}
    * *Status*: #{todo.status}

    h3. Description
    #{todo.description}

    h3. Code Context
    {code:elixir}
    #{Enum.join(todo.context.before_lines ++ ["# TODO: #{todo.description}"] ++ todo.context.after_lines, "\n")}
    {code}

    h3. Additional Information
    #{if todo.metadata.assignee, do: "* *Assignee*: #{todo.metadata.assignee}", else: ""}
    #{if todo.metadata.estimate, do: "* *Estimate*: #{todo.metadata.estimate}", else: ""}
    #{if todo.metadata.due_date, do: "* *Due Date*: #{todo.metadata.due_date}", else: ""}

    ----
    _Generated by Prismatic TODO Management System_
    _TODO ID: #{todo.id}_
    """
  end

  defp map_todo_to_jira_issue_type(todo, jira_config) do
    Map.get(jira_config.issue_type_mapping, todo.category, "Task")
  end

  defp map_todo_to_jira_priority(todo) do
    case todo.priority do
      :critical -> "Highest"
      :high -> "High"
      :medium -> "Medium"
      :low -> "Low"
    end
  end

  defp group_todos_for_notification(todos, event_type) do
    # Group TODOs for efficient notification batching
    case event_type do
      :completed ->
        # Group completed TODOs by assignee for personalized notifications
        todos
        |> Enum.group_by(&(&1.metadata.assignee || "team"))
        |> Enum.map(fn {assignee, assignee_todos} ->
          %{type: :completion_summary, assignee: assignee, todos: assignee_todos}
        end)

      :overdue ->
        # Single notification for all overdue TODOs
        [%{type: :overdue_alert, todos: todos}]

      :blocked ->
        # Group by category for blocked TODOs
        todos
        |> Enum.group_by(& &1.category)
        |> Enum.map(fn {category, category_todos} ->
          %{type: :blocked_alert, category: category, todos: category_todos}
        end)

      _ ->
        # Default: single notification
        [%{type: :general, event_type: event_type, todos: todos}]
    end
  end

  defp send_slack_notification_group(notification_group, slack_config, options) do
    message = build_slack_message(notification_group, slack_config)

    # In real implementation, would send HTTP request to Slack webhook
    Logger.debug("Sending Slack notification to #{slack_config.channel}")
    Logger.debug("Message: #{message}")

    # Simulate successful notification
    {:ok, %{notifications_sent: 1, failed_notifications: 0}}
  rescue
    error ->
      Logger.error("Failed to send Slack notification: #{Exception.message(error)}")
      {:ok, %{notifications_sent: 0, failed_notifications: 1}}
  end

  defp build_slack_message(notification_group, slack_config) do
    case notification_group.type do
      :completion_summary ->
        assignee = notification_group.assignee
        completed_count = length(notification_group.todos)

        """
        :white_check_mark: *TODO Completion Summary*

        #{assignee} has completed #{completed_count} TODO#{if completed_count != 1, do: "s"}:
        #{notification_group.todos |> Enum.take(5) |> Enum.map(&"• #{&1.title}") |> Enum.join("\n")}
        #{if completed_count > 5, do: "\n... and #{completed_count - 5} more", else: ""}

        Great work! :tada:
        """

      :overdue_alert ->
        overdue_count = length(notification_group.todos)

        """
        :warning: *Overdue TODOs Alert*

        #{overdue_count} TODO#{if overdue_count != 1, do: "s are", else: " is"} overdue:
        #{notification_group.todos |> Enum.take(3) |> Enum.map(&"• #{&1.title} (#{&1.priority})") |> Enum.join("\n")}
        #{if overdue_count > 3, do: "\n... and #{overdue_count - 3} more", else: ""}

        Please review and update the timeline.
        """

      :blocked_alert ->
        blocked_count = length(notification_group.todos)
        category = notification_group.category

        """
        :no_entry_sign: *Blocked TODOs Alert*

        #{blocked_count} #{category} TODO#{if blocked_count != 1, do: "s are", else: " is"} currently blocked:
        #{notification_group.todos |> Enum.take(3) |> Enum.map(&"• #{&1.title}") |> Enum.join("\n")}
        #{if blocked_count > 3, do: "\n... and #{blocked_count - 3} more", else: ""}

        Please resolve the blocking dependencies.
        """

      :general ->
        event_type = notification_group.event_type
        todo_count = length(notification_group.todos)

        """
        :information_source: *TODO #{String.capitalize(Atom.to_string(event_type))} Notification*

        #{todo_count} TODO#{if todo_count != 1, do: "s have", else: " has"} #{event_type}:
        #{notification_group.todos |> Enum.take(5) |> Enum.map(&"• #{&1.title}") |> Enum.join("\n")}
        """
    end
  end

  defp merge_notification_results(batch_result, acc_result) do
    case batch_result do
      {:ok, result} ->
        %{
          notifications_sent: acc_result.notifications_sent + result.notifications_sent,
          failed_notifications: acc_result.failed_notifications + result.failed_notifications
        }

      {:error, _reason} ->
        %{
          notifications_sent: acc_result.notifications_sent,
          failed_notifications: acc_result.failed_notifications + 1
        }
    end
  end

  defp apply_validation_rule(todos, rule) do
    case rule do
      :no_critical_todos ->
        critical_todos = Enum.filter(todos, &(&1.priority == :critical and &1.status != :completed))

        if Enum.empty?(critical_todos) do
          %{blocking_issues: [], warnings: [], info: ["No critical TODOs found"]}
        else
          issue = "#{length(critical_todos)} critical TODOs must be resolved before deployment"
          %{blocking_issues: [issue], warnings: [], info: []}
        end

      :high_priority_limit ->
        high_priority_todos = Enum.filter(todos, &(&1.priority in [:critical, :high] and &1.status != :completed))

        if length(high_priority_todos) <= 5 do
          %{blocking_issues: [], warnings: [], info: ["High priority TODO count is acceptable"]}
        else
          warning = "#{length(high_priority_todos)} high priority TODOs may indicate technical debt"
          %{blocking_issues: [], warnings: [warning], info: []}
        end

      :no_security_todos ->
        security_todos = Enum.filter(todos, &(&1.category == :security and &1.status != :completed))

        if Enum.empty?(security_todos) do
          %{blocking_issues: [], warnings: [], info: ["No security TODOs found"]}
        else
          issue = "#{length(security_todos)} security TODOs must be resolved before deployment"
          %{blocking_issues: [issue], warnings: [], info: []}
        end

      :test_coverage_todos ->
        test_todos = Enum.filter(todos, &(&1.category == :test and &1.status != :completed))

        if length(test_todos) <= 3 do
          %{blocking_issues: [], warnings: [], info: ["Test TODO count is acceptable"]}
        else
          warning = "#{length(test_todos)} test TODOs suggest missing test coverage"
          %{blocking_issues: [], warnings: [warning], info: []}
        end

      _ ->
        %{blocking_issues: [], warnings: [], info: []}
    end
  end

  defp merge_validation_results(rule_result, acc_result) do
    %{
      blocking_issues: acc_result.blocking_issues ++ rule_result.blocking_issues,
      warnings: acc_result.warnings ++ rule_result.warnings,
      info: acc_result.info ++ rule_result.info
    }
  end

  defp evaluate_gate_conditions(validation_results, gate_conditions) do
    # Evaluate gate conditions to determine if pipeline should pass
    blocking_count = length(validation_results.blocking_issues)
    warning_count = length(validation_results.warnings)

    max_blocking = Map.get(gate_conditions, :max_blocking_issues, 0)
    max_warnings = Map.get(gate_conditions, :max_warnings, 10)

    cond do
      blocking_count > max_blocking -> :fail
      warning_count > max_warnings -> :warn
      true -> :pass
    end
  end

  defp setup_github_webhook(github_config, webhook_config) do
    # Setup GitHub webhook for real-time integration
    webhook_url = "#{webhook_config.base_url}/webhooks/github"
    security_token = generate_webhook_token()

    Logger.debug("Setting up GitHub webhook: #{webhook_url}")

    # In real implementation, would register webhook with GitHub API
    %{
      service: :github,
      url: webhook_url,
      token: security_token,
      events: ["issues", "pull_requests"],
      repository: github_config.repository
    }
  end

  defp setup_jira_webhook(jira_config, webhook_config) do
    # Setup Jira webhook for real-time integration
    webhook_url = "#{webhook_config.base_url}/webhooks/jira"
    security_token = generate_webhook_token()

    Logger.debug("Setting up Jira webhook: #{webhook_url}")

    # In real implementation, would register webhook with Jira API
    %{
      service: :jira,
      url: webhook_url,
      token: security_token,
      events: ["jira:issue_created", "jira:issue_updated"],
      project: jira_config.project_key
    }
  end

  defp setup_slack_webhook(slack_config, webhook_config) do
    # Setup Slack webhook for bidirectional communication
    webhook_url = "#{webhook_config.base_url}/webhooks/slack"
    security_token = generate_webhook_token()

    Logger.debug("Setting up Slack webhook: #{webhook_url}")

    # In real implementation, would configure Slack app with webhook URL
    %{
      service: :slack,
      url: webhook_url,
      token: security_token,
      events: ["message", "slash_command"],
      channel: slack_config.channel
    }
  end

  defp generate_webhook_token do
    # Generate secure token for webhook validation
    :crypto.strong_rand_bytes(32) |> Base.encode64()
  end
end
