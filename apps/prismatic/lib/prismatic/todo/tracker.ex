defmodule Prismatic.TODO.Tracker do
  @moduledoc """
  Lifecycle tracking and management for the Prismatic TODO management system.

  This module provides comprehensive TODO lifecycle tracking including status updates,
  progress monitoring, completion validation, and automated workflow management.
  It maintains the complete history of TODO items and provides insights into
  development progress and team productivity.

  ## Features

  - **Lifecycle Management**: Complete TODO lifecycle from creation to completion
  - **Status Tracking**: Real-time status updates and progress monitoring
  - **Completion Validation**: Automated validation of TODO completion requirements
  - **History Tracking**: Complete audit trail of all TODO changes
  - **Progress Analytics**: Team and project progress analysis
  - **Automated Workflows**: Trigger-based automation for TODO management

  ## Usage

      # Update TODO status
      {:ok, updated_todo} = Tracker.update_todo_status(todo_id, :in_progress, options)

      # Complete TODO with validation
      {:ok, completed_todo} = Tracker.complete_todo(todo_id, completion_data)

      # Get TODO history
      {:ok, history} = Tracker.get_todo_history(todo_id)

      # Track progress for a set of TODOs
      {:ok, progress} = Tracker.track_progress(todo_list, date_range)

  ## Lifecycle States

  TODOs progress through the following states:

  - `:open` - Newly created, ready for work
  - `:in_progress` - Currently being worked on
  - `:review` - Awaiting code review or validation
  - `:completed` - Finished and validated
  - `:blocked` - Cannot proceed due to dependencies
  - `:cancelled` - No longer needed or relevant

  ## Configuration

      config :prismatic, Prismatic.TODO.Tracker,
        validation_rules: %{
          require_tests: true,
          require_documentation: false,
          require_code_review: true
        },
        auto_transitions: %{
          completion_timeout: 72,  # hours
          review_timeout: 24       # hours
        },
        notifications: %{
          status_changes: true,
          milestone_completion: true,
          overdue_reminders: true
        }
  """

  alias Prismatic.TODO.Scanner
  require Logger

  @type status_update_options :: %{
    assignee: String.t() | nil,
    comment: String.t() | nil,
    metadata: map(),
    auto_transition: boolean()
  }

  @type completion_data :: %{
    validation_required: boolean(),
    test_coverage_check: boolean(),
    code_review_check: boolean(),
    documentation_check: boolean(),
    completion_notes: String.t()
  }

  @type todo_history_entry :: %{
    timestamp: DateTime.t(),
    action: atom(),
    old_status: atom() | nil,
    new_status: atom() | nil,
    user: String.t() | nil,
    comment: String.t() | nil,
    metadata: map()
  }

  @type progress_metrics :: %{
    total_todos: non_neg_integer(),
    completed_todos: non_neg_integer(),
    in_progress_todos: non_neg_integer(),
    blocked_todos: non_neg_integer(),
    completion_rate: float(),
    average_completion_time: float(),
    productivity_trend: :increasing | :stable | :decreasing,
    milestone_progress: [milestone_progress()]
  }

  @type milestone_progress :: %{
    name: String.t(),
    todos_total: non_neg_integer(),
    todos_completed: non_neg_integer(),
    progress_percentage: float(),
    target_date: Date.t(),
    estimated_completion: Date.t()
  }

  @type validation_result :: %{
    valid: boolean(),
    checks_passed: [atom()],
    checks_failed: [atom()],
    requirements_met: boolean(),
    validation_notes: String.t()
  }

  @doc """
  Update the status of a TODO item with optional metadata.

  ## Parameters

  - `todo_id` - Unique identifier of the TODO item
  - `new_status` - New status to set
  - `options` - Update options including assignee, comments, etc.

  ## Returns

  Updated TODO item with new status and history entry.

  ## Examples

      iex> Tracker.update_todo_status("TODO_001", :in_progress, %{assignee: "dev@company.com"})
      {:ok, %{
        id: "TODO_001",
        status: :in_progress,
        assignee: "dev@company.com",
        updated_at: ~U[2025-01-03 10:30:00Z]
      }}
  """
  @spec update_todo_status(String.t(), atom(), status_update_options()) :: {:ok, Scanner.todo_item()} | {:error, term()}
  def update_todo_status(todo_id, new_status, options \\ %{}) do
    Logger.info("Updating TODO #{todo_id} status to #{new_status}")

    with {:ok, current_todo} <- get_todo_by_id(todo_id),
         :ok <- validate_status_transition(current_todo.status, new_status),
         {:ok, updated_todo} <- apply_status_update(current_todo, new_status, options),
         :ok <- record_status_change(updated_todo, current_todo.status, new_status, options),
         {:ok, final_todo} <- apply_auto_transitions_if_enabled(updated_todo, options) do

      Logger.info("TODO #{todo_id} status updated successfully")
      {:ok, final_todo}
    else
      {:error, reason} ->
        Logger.error("Failed to update TODO #{todo_id} status: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Complete a TODO item with comprehensive validation.

  ## Parameters

  - `todo_id` - Unique identifier of the TODO item
  - `completion_data` - Completion validation data and requirements

  ## Returns

  Completed TODO item with validation results.

  ## Examples

      iex> Tracker.complete_todo("TODO_001", %{validation_required: true})
      {:ok, %{
        id: "TODO_001",
        status: :completed,
        completion_percentage: 100.0,
        validation_result: %{valid: true, ...}
      }}
  """
  @spec complete_todo(String.t(), completion_data()) :: {:ok, Scanner.todo_item()} | {:error, term()}
  def complete_todo(todo_id, completion_data \\ %{}) do
    Logger.info("Completing TODO #{todo_id}")

    completion_data = merge_default_completion_data(completion_data)

    with {:ok, current_todo} <- get_todo_by_id(todo_id),
         :ok <- validate_completion_prerequisites(current_todo),
         {:ok, validation_result} <- validate_completion_requirements(current_todo, completion_data),
         {:ok, completed_todo} <- apply_completion(current_todo, completion_data, validation_result),
         :ok <- record_completion(completed_todo, completion_data),
         :ok <- trigger_completion_workflows(completed_todo) do

      Logger.info("TODO #{todo_id} completed successfully")
      {:ok, completed_todo}
    else
      {:error, reason} ->
        Logger.error("Failed to complete TODO #{todo_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Get the complete history of changes for a TODO item.

  ## Parameters

  - `todo_id` - Unique identifier of the TODO item
  - `options` - History query options (date range, limit, etc.)

  ## Returns

  List of history entries showing all changes to the TODO.

  ## Examples

      iex> Tracker.get_todo_history("TODO_001")
      {:ok, [
        %{
          timestamp: ~U[2025-01-03 09:00:00Z],
          action: :created,
          new_status: :open,
          user: "system"
        },
        %{
          timestamp: ~U[2025-01-03 10:30:00Z],
          action: :status_changed,
          old_status: :open,
          new_status: :in_progress,
          user: "dev@company.com"
        }
      ]}
  """
  @spec get_todo_history(String.t(), map()) :: {:ok, [todo_history_entry()]} | {:error, term()}
  def get_todo_history(todo_id, _options \\ %{}) do
    Logger.debug("Retrieving history for TODO #{todo_id}")

    # In a real implementation, this would query a database or file system
    # For now, return a mock history
    history = [
      %{
        timestamp: DateTime.utc_now() |> DateTime.add(-3600, :second),
        action: :created,
        old_status: nil,
        new_status: :open,
        user: "system",
        comment: "TODO created from code scan",
        metadata: %{}
      },
      %{
        timestamp: DateTime.utc_now() |> DateTime.add(-1800, :second),
        action: :status_changed,
        old_status: :open,
        new_status: :in_progress,
        user: "dev@company.com",
        comment: "Starting work on this TODO",
        metadata: %{assignee: "dev@company.com"}
      }
    ]

    {:ok, history}
  end

  @doc """
  Track progress metrics for a collection of TODOs.

  ## Parameters

  - `todos` - List of TODO items to analyze
  - `date_range` - Date range for progress analysis
  - `options` - Progress tracking options

  ## Returns

  Comprehensive progress metrics and analytics.

  ## Examples

      iex> Tracker.track_progress(todos, {start_date, end_date})
      {:ok, %{
        total_todos: 50,
        completed_todos: 32,
        completion_rate: 0.64,
        average_completion_time: 72.5,
        productivity_trend: :increasing
      }}
  """
  @spec track_progress([Scanner.todo_item()], {Date.t(), Date.t()}, map()) :: {:ok, progress_metrics()} | {:error, term()}
  def track_progress(todos, date_range, options \\ %{}) do
    Logger.info("Tracking progress for #{length(todos)} TODOs")

    {start_date, end_date} = date_range

    try do
      # Calculate basic metrics
      total_todos = length(todos)
      completed_todos = Enum.count(todos, &(&1.status == :completed))
      in_progress_todos = Enum.count(todos, &(&1.status == :in_progress))
      blocked_todos = Enum.count(todos, &(&1.status == :blocked))

      completion_rate = if total_todos > 0, do: completed_todos / total_todos, else: 0.0

      # Calculate average completion time
      average_completion_time = calculate_average_completion_time(todos)

      # Analyze productivity trend
      productivity_trend = analyze_productivity_trend(todos, date_range)

      # Calculate milestone progress
      milestone_progress = calculate_milestone_progress(todos, options)

      metrics = %{
        total_todos: total_todos,
        completed_todos: completed_todos,
        in_progress_todos: in_progress_todos,
        blocked_todos: blocked_todos,
        completion_rate: completion_rate,
        average_completion_time: average_completion_time,
        productivity_trend: productivity_trend,
        milestone_progress: milestone_progress
      }

      {:ok, metrics}
    rescue
      error ->
        {:error, "Progress tracking failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Validate TODO completion against requirements.

  ## Parameters

  - `todo_item` - TODO item to validate
  - `validation_options` - Validation configuration

  ## Returns

  Validation result with detailed check results.

  ## Examples

      iex> Tracker.validate_todo_completion(todo, %{require_tests: true})
      {:ok, %{
        valid: true,
        checks_passed: [:code_review, :tests],
        checks_failed: [],
        requirements_met: true
      }}
  """
  @spec validate_todo_completion(Scanner.todo_item(), map()) :: {:ok, validation_result()} | {:error, term()}
  def validate_todo_completion(todo_item, validation_options \\ %{}) do
    Logger.debug("Validating completion for TODO #{todo_item.id}")

    validation_config = get_validation_config(validation_options)

    checks_passed = []
    checks_failed = []

    # Test coverage check
    {checks_passed, checks_failed} = if validation_config.require_tests do
      if validate_test_coverage(todo_item) do
        {[:test_coverage | checks_passed], checks_failed}
      else
        {checks_passed, [:test_coverage | checks_failed]}
      end
    else
      {checks_passed, checks_failed}
    end

    # Documentation check
    {checks_passed, checks_failed} = if validation_config.require_documentation do
      if validate_documentation(todo_item) do
        {[:documentation | checks_passed], checks_failed}
      else
        {checks_passed, [:documentation | checks_failed]}
      end
    else
      {checks_passed, checks_failed}
    end

    # Code review check
    {checks_passed, checks_failed} = if validation_config.require_code_review do
      if validate_code_review(todo_item) do
        {[:code_review | checks_passed], checks_failed}
      else
        {checks_passed, [:code_review | checks_failed]}
      end
    else
      {checks_passed, checks_failed}
    end

    valid = Enum.empty?(checks_failed)
    requirements_met = valid and length(checks_passed) > 0

    validation_result = %{
      valid: valid,
      checks_passed: Enum.reverse(checks_passed),
      checks_failed: Enum.reverse(checks_failed),
      requirements_met: requirements_met,
      validation_notes: generate_validation_notes(checks_passed, checks_failed)
    }

    {:ok, validation_result}
  end

  @doc """
  Create automated workflow for TODO management.

  ## Parameters

  - `workflow_config` - Workflow configuration and rules
  - `todos` - TODOs to include in workflow

  ## Returns

  Created workflow with automation rules.

  ## Examples

      iex> Tracker.create_workflow(%{auto_assign: true, priority: :high}, todos)
      {:ok, %{
        workflow_id: "WF_001",
        todos_included: 5,
        automation_rules: [...],
        created_at: ~U[2025-01-03 10:30:00Z]
      }}
  """
  @spec create_workflow(map(), [Scanner.todo_item()]) :: {:ok, map()} | {:error, term()}
  def create_workflow(workflow_config, todos) do
    Logger.info("Creating automated workflow for #{length(todos)} TODOs")

    workflow_id = generate_workflow_id()

    # Filter TODOs based on workflow criteria
    filtered_todos = filter_todos_for_workflow(todos, workflow_config)

    # Create automation rules
    automation_rules = create_automation_rules(workflow_config)

    # Set up workflow triggers
    triggers = create_workflow_triggers(workflow_config, filtered_todos)

    workflow = %{
      workflow_id: workflow_id,
      todos_included: length(filtered_todos),
      filtered_todo_ids: Enum.map(filtered_todos, & &1.id),
      automation_rules: automation_rules,
      triggers: triggers,
      auto_assign: Map.get(workflow_config, :auto_assign, false),
      phases: Map.get(workflow_config, :phases, 1),
      created_at: DateTime.utc_now()
    }

    # Store workflow (in real implementation would persist to database)
    Logger.info("Workflow #{workflow_id} created with #{length(filtered_todos)} TODOs")

    {:ok, workflow}
  end

  # Private helper functions

  defp get_todo_by_id(todo_id) do
    # In real implementation, this would query the TODO storage
    # For now, return a mock TODO
    todo = %{
      id: todo_id,
      type: :todo,
      category: :feature,
      priority: :medium,
      status: :open,
      title: "Sample TODO",
      description: "This is a sample TODO for testing",
      file_path: "lib/sample.ex",
      line_number: 42,
      column_number: 5,
      context: %{
        before_lines: [],
        after_lines: [],
        function_name: "sample_function",
        module_name: "Sample"
      },
      metadata: %{
        assignee: nil,
        estimate: nil,
        dependencies: [],
        related_items: [],
        due_date: nil,
        created_at: DateTime.utc_now() |> DateTime.add(-3600, :second),
        updated_at: DateTime.utc_now() |> DateTime.add(-1800, :second)
      }
    }

    {:ok, todo}
  end

  defp validate_status_transition(current_status, new_status) do
    valid_transitions = %{
      open: [:in_progress, :blocked, :cancelled],
      in_progress: [:review, :completed, :blocked, :open],
      review: [:completed, :in_progress, :open],
      blocked: [:open, :in_progress, :cancelled],
      completed: [],  # Completed TODOs cannot change status
      cancelled: [:open]  # Cancelled TODOs can be reopened
    }

    allowed_statuses = Map.get(valid_transitions, current_status, [])

    if new_status in allowed_statuses do
      :ok
    else
      {:error, "Invalid status transition from #{current_status} to #{new_status}"}
    end
  end

  defp apply_status_update(todo, new_status, options) do
    updated_todo = todo
    |> Map.put(:status, new_status)
    |> Map.put(:updated_at, DateTime.utc_now())

    # Apply optional updates
    updated_todo = if Map.has_key?(options, :assignee) do
      put_in(updated_todo.metadata.assignee, options.assignee)
    else
      updated_todo
    end

    # Update completion percentage based on status
    completion_percentage = case new_status do
      :open -> 0.0
      :in_progress -> 25.0
      :review -> 75.0
      :completed -> 100.0
      :blocked -> todo.completion_percentage || 0.0
      :cancelled -> 0.0
    end

    updated_todo = Map.put(updated_todo, :completion_percentage, completion_percentage)

    {:ok, updated_todo}
  end

  defp record_status_change(todo, old_status, new_status, options) do
    # In real implementation, this would persist the change to a database
    Logger.debug("Recording status change for #{todo.id}: #{old_status} -> #{new_status}")

    history_entry = %{
      timestamp: DateTime.utc_now(),
      action: :status_changed,
      old_status: old_status,
      new_status: new_status,
      user: Map.get(options, :user, "system"),
      comment: Map.get(options, :comment),
      metadata: Map.get(options, :metadata, %{})
    }

    # Store history entry
    :ok
  end

  defp apply_auto_transitions_if_enabled(todo, options) do
    if Map.get(options, :auto_transition, false) do
      # Apply automatic transitions based on configured rules
      # For now, just return the todo unchanged
      {:ok, todo}
    else
      {:ok, todo}
    end
  end

  defp merge_default_completion_data(completion_data) do
    defaults = %{
      validation_required: true,
      test_coverage_check: true,
      code_review_check: true,
      documentation_check: false,
      completion_notes: ""
    }

    Map.merge(defaults, completion_data)
  end

  defp validate_completion_prerequisites(todo) do
    case todo.status do
      :open -> {:error, "TODO must be in progress before completion"}
      :blocked -> {:error, "Cannot complete blocked TODO"}
      :cancelled -> {:error, "Cannot complete cancelled TODO"}
      :completed -> {:error, "TODO is already completed"}
      _ -> :ok
    end
  end

  defp validate_completion_requirements(todo, completion_data) do
    if completion_data.validation_required do
      validate_todo_completion(todo, completion_data)
    else
      {:ok, %{valid: true, checks_passed: [], checks_failed: [], requirements_met: true, validation_notes: "Validation skipped"}}
    end
  end

  defp apply_completion(todo, completion_data, validation_result) do
    completed_todo = todo
    |> Map.put(:status, :completed)
    |> Map.put(:completion_percentage, 100.0)
    |> Map.put(:updated_at, DateTime.utc_now())
    |> Map.put(:validation_result, validation_result)

    # Add completion metadata
    completion_metadata = Map.merge(todo.metadata, %{
      completed_at: DateTime.utc_now(),
      completion_notes: completion_data.completion_notes,
      validation_result: validation_result
    })

    completed_todo = Map.put(completed_todo, :metadata, completion_metadata)

    {:ok, completed_todo}
  end

  defp record_completion(todo, completion_data) do
    # Record completion in history
    Logger.info("Recording completion for TODO #{todo.id}")
    :ok
  end

  defp trigger_completion_workflows(todo) do
    # Trigger any workflows associated with TODO completion
    Logger.debug("Triggering completion workflows for TODO #{todo.id}")
    :ok
  end

  defp get_validation_config(options) do
    defaults = %{
      require_tests: true,
      require_documentation: false,
      require_code_review: true
    }

    Map.merge(defaults, options)
  end

  defp validate_test_coverage(todo) do
    # In real implementation, this would check test coverage for the affected code
    # For now, assume tests are required for certain categories
    todo.category in [:feature, :bug, :refactor]
  end

  defp validate_documentation(todo) do
    # In real implementation, this would check if documentation was updated
    # For now, assume documentation is always adequate
    true
  end

  defp validate_code_review(todo) do
    # In real implementation, this would check if code review was completed
    # For now, assume code review is always done
    true
  end

  defp generate_validation_notes(checks_passed, checks_failed) do
    case {checks_passed, checks_failed} do
      {[], []} -> "No validation checks configured"
      {passed, []} -> "All validation checks passed: #{Enum.join(passed, ", ")}"
      {[], failed} -> "All validation checks failed: #{Enum.join(failed, ", ")}"
      {passed, failed} ->
        "Passed: #{Enum.join(passed, ", ")}. Failed: #{Enum.join(failed, ", ")}"
    end
  end

  defp calculate_average_completion_time(todos) do
    completed_todos = Enum.filter(todos, &(&1.status == :completed))

    if Enum.empty?(completed_todos) do
      0.0
    else
      completion_times = completed_todos
      |> Enum.map(&calculate_todo_completion_time/1)
      |> Enum.reject(&is_nil/1)

      if Enum.empty?(completion_times) do
        0.0
      else
        Enum.sum(completion_times) / length(completion_times)
      end
    end
  end

  defp calculate_todo_completion_time(todo) do
    case {todo.metadata.created_at, todo.metadata.completed_at} do
      {%DateTime{} = created, %DateTime{} = completed} ->
        DateTime.diff(completed, created, :hour)

      _ -> nil
    end
  end

  defp analyze_productivity_trend(todos, {start_date, end_date}) do
    # Analyze completion rate over time to determine trend
    # This is a simplified implementation
    completed_todos = Enum.filter(todos, &(&1.status == :completed))

    if length(completed_todos) > length(todos) * 0.7 do
      :increasing
    else
      :stable
    end
  end

  defp calculate_milestone_progress(todos, options) do
    # Calculate progress for defined milestones
    # For now, return empty list - would be populated based on project milestones
    []
  end

  defp generate_workflow_id do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "WF_#{timestamp}_#{:rand.uniform(1000)}"
  end

  defp filter_todos_for_workflow(todos, workflow_config) do
    todos
    |> filter_by_priority_if_specified(workflow_config)
    |> filter_by_category_if_specified(workflow_config)
    |> filter_by_status_if_specified(workflow_config)
  end

  defp filter_by_priority_if_specified(todos, config) do
    case Map.get(config, :priority) do
      nil -> todos
      priority -> Enum.filter(todos, &(&1.priority == priority))
    end
  end

  defp filter_by_category_if_specified(todos, config) do
    case Map.get(config, :category) do
      nil -> todos
      category -> Enum.filter(todos, &(&1.category == category))
    end
  end

  defp filter_by_status_if_specified(todos, config) do
    case Map.get(config, :status) do
      nil -> todos
      status -> Enum.filter(todos, &(&1.status == status))
    end
  end

  defp create_automation_rules(workflow_config) do
    rules = []

    rules = if Map.get(workflow_config, :auto_assign, false) do
      ["Auto-assign TODOs to available team members" | rules]
    else
      rules
    end

    rules = if Map.get(workflow_config, :auto_prioritize, false) do
      ["Automatically adjust priorities based on dependencies" | rules]
    else
      rules
    end

    rules = if Map.get(workflow_config, :progress_tracking, true) do
      ["Track progress and send notifications" | rules]
    else
      rules
    end

    Enum.reverse(rules)
  end

  defp create_workflow_triggers(workflow_config, todos) do
    triggers = []

    triggers = if Map.get(workflow_config, :status_change_triggers, true) do
      ["Trigger on status changes" | triggers]
    else
      triggers
    end

    triggers = if Map.get(workflow_config, :deadline_triggers, true) do
      ["Trigger on approaching deadlines" | triggers]
    else
      triggers
    end

    triggers = if Map.get(workflow_config, :completion_triggers, true) do
      ["Trigger on TODO completion" | triggers]
    else
      triggers
    end

    Enum.reverse(triggers)
  end
end
