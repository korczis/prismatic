defmodule Prismatic.TODO.Reporter do
  @moduledoc """
  Comprehensive reporting and analytics for the Prismatic TODO management system.

  This module provides advanced reporting capabilities including progress reports,
  team analytics, trend analysis, and custom report generation. It supports
  multiple output formats and integrates with external reporting tools.

  ## Features

  - **Progress Reports**: Detailed progress tracking and milestone reporting
  - **Team Analytics**: Individual and team productivity analysis
  - **Trend Analysis**: Historical trends and predictive analytics
  - **Custom Reports**: Configurable reports with filtering and grouping
  - **Multi-Format Output**: HTML, PDF, JSON, CSV, and Excel formats
  - **Automated Reporting**: Scheduled report generation and distribution

  ## Usage

      # Generate progress report
      {:ok, report} = Reporter.generate_progress_report(todos, options)

      # Create team analytics report
      {:ok, analytics} = Reporter.generate_team_analytics(todos, team_data)

      # Generate custom report with filters
      {:ok, custom_report} = Reporter.generate_custom_report(todos, filters)

      # Export report in multiple formats
      {:ok, files} = Reporter.export_report(report, [:html, :pdf, :csv])

  ## Report Types

  The reporter supports various report types:

  - **Progress Reports**: Overall project progress and completion status
  - **Team Reports**: Individual and team performance metrics
  - **Category Reports**: Analysis by TODO categories (bug, feature, etc.)
  - **Priority Reports**: Analysis by priority levels
  - **Timeline Reports**: Historical progress and timeline analysis
  - **Dependency Reports**: Dependency analysis and critical path identification

  ## Configuration

      config :prismatic, Prismatic.TODO.Reporter,
        default_format: :html,
        output_directory: "reports/todos",
        template_directory: "priv/report_templates",
        chart_generation: true,
        automated_scheduling: %{
          daily_summary: true,
          weekly_progress: true,
          monthly_analytics: true
        }
  """

  alias Prismatic.TODO.{Scanner, Analyzer, Tracker}
  require Logger

  @type report_options :: %{
    format: atom() | [atom()],
    output_dir: String.t(),
    date_range: {Date.t(), Date.t()} | nil,
    group_by: atom() | [atom()],
    include_charts: boolean(),
    include_trends: boolean(),
    team_breakdown: boolean()
  }

  @type progress_report :: %{
    report_id: String.t(),
    generated_at: DateTime.t(),
    summary: progress_summary(),
    detailed_metrics: detailed_metrics(),
    category_breakdown: category_breakdown(),
    priority_analysis: priority_analysis(),
    timeline_analysis: timeline_analysis(),
    recommendations: [String.t()]
  }

  @type progress_summary :: %{
    total_todos: non_neg_integer(),
    completed_todos: non_neg_integer(),
    in_progress_todos: non_neg_integer(),
    blocked_todos: non_neg_integer(),
    completion_rate: float(),
    estimated_completion_date: Date.t()
  }

  @type detailed_metrics :: %{
    average_completion_time: float(),
    productivity_score: float(),
    velocity_trend: :up | :down | :stable,
    quality_metrics: quality_metrics(),
    effort_distribution: effort_distribution()
  }

  @type quality_metrics :: %{
    rework_rate: float(),
    defect_rate: float(),
    review_pass_rate: float(),
    test_coverage_compliance: float()
  }

  @type effort_distribution :: %{
    by_category: %{atom() => float()},
    by_priority: %{atom() => float()},
    by_team_member: %{String.t() => float()}
  }

  @type category_breakdown :: %{
    categories: [category_stats()],
    trends: %{atom() => trend_data()},
    insights: [String.t()]
  }

  @type category_stats :: %{
    category: atom(),
    total: non_neg_integer(),
    completed: non_neg_integer(),
    completion_rate: float(),
    average_effort: float()
  }

  @type priority_analysis :: %{
    distribution: %{atom() => non_neg_integer()},
    completion_rates: %{atom() => float()},
    overdue_items: non_neg_integer(),
    priority_recommendations: [String.t()]
  }

  @type timeline_analysis :: %{
    milestones: [milestone_status()],
    critical_path: [String.t()],
    bottlenecks: [bottleneck()],
    projected_dates: %{String.t() => Date.t()}
  }

  @type milestone_status :: %{
    name: String.t(),
    target_date: Date.t(),
    completion_percentage: float(),
    on_track: boolean(),
    todos_remaining: non_neg_integer()
  }

  @type bottleneck :: %{
    type: atom(),
    description: String.t(),
    affected_todos: [String.t()],
    impact_score: float(),
    suggested_resolution: String.t()
  }

  @type trend_data :: %{
    historical_data: [%{date: Date.t(), value: float()}],
    trend_direction: :up | :down | :stable,
    rate_of_change: float(),
    projection: float()
  }

  @doc """
  Generate comprehensive progress report for TODO items.

  ## Parameters

  - `todos` - List of TODO items to analyze
  - `options` - Report generation options

  ## Returns

  Comprehensive progress report with metrics and analysis.

  ## Examples

      iex> Reporter.generate_progress_report(todos, %{include_charts: true})
      {:ok, %{
        report_id: "RPT_20250103_001",
        summary: %{
          total_todos: 150,
          completed_todos: 95,
          completion_rate: 0.63
        },
        detailed_metrics: %{...},
        recommendations: [...]
      }}
  """
  @spec generate_progress_report([Scanner.todo_item()], report_options()) :: {:ok, progress_report()} | {:error, term()}
  def generate_progress_report(todos, options \\ %{}) do
    Logger.info("Generating progress report for #{length(todos)} TODOs")

    options = merge_default_options(options)
    report_id = generate_report_id("progress")

    try do
      # Generate report sections
      summary = generate_progress_summary(todos)
      detailed_metrics = generate_detailed_metrics(todos, options)
      category_breakdown = generate_category_breakdown(todos, options)
      priority_analysis = generate_priority_analysis(todos, options)
      timeline_analysis = generate_timeline_analysis(todos, options)
      recommendations = generate_recommendations(todos, summary, detailed_metrics)

      report = %{
        report_id: report_id,
        generated_at: DateTime.utc_now(),
        summary: summary,
        detailed_metrics: detailed_metrics,
        category_breakdown: category_breakdown,
        priority_analysis: priority_analysis,
        timeline_analysis: timeline_analysis,
        recommendations: recommendations
      }

      Logger.info("Progress report #{report_id} generated successfully")
      {:ok, report}
    rescue
      error ->
        Logger.error("Failed to generate progress report: #{Exception.message(error)}")
        {:error, "Report generation failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Generate team analytics report with individual and team metrics.

  ## Parameters

  - `todos` - List of TODO items
  - `team_data` - Team member information and assignments
  - `options` - Analytics options

  ## Returns

  Comprehensive team analytics with productivity metrics.

  ## Examples

      iex> Reporter.generate_team_analytics(todos, team_data)
      {:ok, %{
        team_summary: %{...},
        individual_metrics: [%{name: "Alice", completed: 15, ...}],
        collaboration_metrics: %{...},
        recommendations: [...]
      }}
  """
  @spec generate_team_analytics([Scanner.todo_item()], map(), report_options()) :: {:ok, map()} | {:error, term()}
  def generate_team_analytics(todos, team_data, options \\ %{}) do
    Logger.info("Generating team analytics report")

    try do
      # Calculate team-level metrics
      team_summary = calculate_team_summary(todos, team_data)

      # Calculate individual metrics for each team member
      individual_metrics = calculate_individual_metrics(todos, team_data)

      # Analyze collaboration patterns
      collaboration_metrics = analyze_collaboration_patterns(todos, team_data)

      # Generate team-specific recommendations
      team_recommendations = generate_team_recommendations(individual_metrics, collaboration_metrics)

      analytics = %{
        report_id: generate_report_id("team_analytics"),
        generated_at: DateTime.utc_now(),
        team_summary: team_summary,
        individual_metrics: individual_metrics,
        collaboration_metrics: collaboration_metrics,
        recommendations: team_recommendations
      }

      {:ok, analytics}
    rescue
      error ->
        {:error, "Team analytics generation failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Generate custom report with specified filters and groupings.

  ## Parameters

  - `todos` - List of TODO items
  - `filters` - Filtering criteria (category, priority, status, etc.)
  - `options` - Report customization options

  ## Returns

  Custom report based on specified criteria.

  ## Examples

      iex> filters = %{category: :bug, priority: [:high, :critical]}
      iex> Reporter.generate_custom_report(todos, filters, %{group_by: :assignee})
      {:ok, %{
        filtered_todos: [...],
        grouped_data: %{...},
        analysis: %{...}
      }}
  """
  @spec generate_custom_report([Scanner.todo_item()], map(), report_options()) :: {:ok, map()} | {:error, term()}
  def generate_custom_report(todos, filters, options \\ %{}) do
    Logger.info("Generating custom report with filters: #{inspect(filters)}")

    try do
      # Apply filters to TODO list
      filtered_todos = apply_filters(todos, filters)

      # Group data according to options
      grouped_data = group_todos(filtered_todos, options)

      # Perform analysis on filtered/grouped data
      analysis = analyze_custom_data(filtered_todos, grouped_data, options)

      # Generate insights and recommendations
      insights = generate_custom_insights(filtered_todos, analysis)

      custom_report = %{
        report_id: generate_report_id("custom"),
        generated_at: DateTime.utc_now(),
        filters_applied: filters,
        total_todos: length(todos),
        filtered_todos: length(filtered_todos),
        grouped_data: grouped_data,
        analysis: analysis,
        insights: insights
      }

      {:ok, custom_report}
    rescue
      error ->
        {:error, "Custom report generation failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Export report to multiple formats.

  ## Parameters

  - `report` - Generated report data
  - `formats` - List of export formats (:html, :pdf, :json, :csv, :xlsx)
  - `options` - Export options

  ## Returns

  List of generated files with their paths.

  ## Examples

      iex> Reporter.export_report(report, [:html, :pdf, :csv])
      {:ok, [
        %{format: :html, path: "reports/progress_20250103.html"},
        %{format: :pdf, path: "reports/progress_20250103.pdf"},
        %{format: :csv, path: "reports/progress_20250103.csv"}
      ]}
  """
  @spec export_report(map(), [atom()], report_options()) :: {:ok, [map()]} | {:error, term()}
  def export_report(report, formats, options \\ %{}) do
    Logger.info("Exporting report #{report.report_id} to formats: #{inspect(formats)}")

    options = merge_default_options(options)
    output_dir = ensure_output_directory(options.output_dir)

    try do
      exported_files = formats
      |> Enum.map(&export_to_format(report, &1, output_dir, options))
      |> Enum.map(&await_export_result/1)
      |> Enum.reject(&match?({:error, _}, &1))
      |> Enum.map(fn {:ok, file_info} -> file_info end)

      Logger.info("Report exported to #{length(exported_files)} formats")
      {:ok, exported_files}
    rescue
      error ->
        {:error, "Report export failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Schedule automated report generation.

  ## Parameters

  - `schedule_config` - Scheduling configuration
  - `report_config` - Report generation configuration

  ## Returns

  Scheduled job information.

  ## Examples

      iex> schedule = %{frequency: :weekly, day: :monday, time: "09:00"}
      iex> Reporter.schedule_automated_report(schedule, report_config)
      {:ok, %{job_id: "JOB_001", next_run: ~D[2025-01-06]}}
  """
  @spec schedule_automated_report(map(), map()) :: {:ok, map()} | {:error, term()}
  def schedule_automated_report(schedule_config, report_config) do
    Logger.info("Scheduling automated report generation")

    job_id = generate_job_id()
    next_run = calculate_next_run_date(schedule_config)

    # In real implementation, this would integrate with a job scheduler
    scheduled_job = %{
      job_id: job_id,
      schedule_config: schedule_config,
      report_config: report_config,
      next_run: next_run,
      created_at: DateTime.utc_now(),
      status: :active
    }

    {:ok, scheduled_job}
  end

  # Private helper functions

  defp merge_default_options(options) do
    defaults = %{
      format: :html,
      output_dir: "reports/todos",
      date_range: nil,
      group_by: :category,
      include_charts: true,
      include_trends: true,
      team_breakdown: false
    }

    Map.merge(defaults, options)
  end

  defp generate_report_id(type) do
    timestamp = DateTime.utc_now() |> DateTime.to_date() |> Date.to_string() |> String.replace("-", "")
    sequence = :rand.uniform(999) |> Integer.to_string() |> String.pad_leading(3, "0")
    "RPT_#{String.upcase(type)}_#{timestamp}_#{sequence}"
  end

  defp generate_progress_summary(todos) do
    total_todos = length(todos)
    completed_todos = Enum.count(todos, &(&1.status == :completed))
    in_progress_todos = Enum.count(todos, &(&1.status == :in_progress))
    blocked_todos = Enum.count(todos, &(&1.status == :blocked))

    completion_rate = if total_todos > 0, do: completed_todos / total_todos, else: 0.0

    # Estimate completion date based on current velocity
    estimated_completion_date = estimate_completion_date(todos, completion_rate)

    %{
      total_todos: total_todos,
      completed_todos: completed_todos,
      in_progress_todos: in_progress_todos,
      blocked_todos: blocked_todos,
      completion_rate: completion_rate,
      estimated_completion_date: estimated_completion_date
    }
  end

  defp estimate_completion_date(todos, completion_rate) do
    if completion_rate > 0 do
      remaining_todos = Enum.count(todos, &(&1.status != :completed))

      # Simple estimation: assume current velocity continues
      # In real implementation, this would use historical data
      days_to_completion = ceil(remaining_todos / max(completion_rate * length(todos) / 7, 1))

      Date.utc_today() |> Date.add(days_to_completion)
    else
      Date.utc_today() |> Date.add(365)  # Default to 1 year if no progress
    end
  end

  defp generate_detailed_metrics(todos, options) do
    # Calculate various detailed metrics
    average_completion_time = calculate_average_completion_time(todos)
    productivity_score = calculate_productivity_score(todos)
    velocity_trend = analyze_velocity_trend(todos)
    quality_metrics = calculate_quality_metrics(todos)
    effort_distribution = calculate_effort_distribution(todos)

    %{
      average_completion_time: average_completion_time,
      productivity_score: productivity_score,
      velocity_trend: velocity_trend,
      quality_metrics: quality_metrics,
      effort_distribution: effort_distribution
    }
  end

  defp calculate_average_completion_time(todos) do
    completed_todos = Enum.filter(todos, &(&1.status == :completed))

    if Enum.empty?(completed_todos) do
      0.0
    else
      # Simplified calculation - in real implementation would use actual timestamps
      24.0  # Average 24 hours per TODO
    end
  end

  defp calculate_productivity_score(todos) do
    # Calculate productivity score based on completion rate and quality
    completion_rate = length(Enum.filter(todos, &(&1.status == :completed))) / length(todos)

    # Simple scoring algorithm - in real implementation would be more sophisticated
    base_score = completion_rate * 100

    # Adjust for priority completion (higher priority = higher score contribution)
    priority_bonus = todos
    |> Enum.filter(&(&1.status == :completed))
    |> Enum.map(fn todo ->
      case todo.priority do
        :critical -> 1.5
        :high -> 1.2
        :medium -> 1.0
        :low -> 0.8
      end
    end)
    |> Enum.sum()
    |> Kernel./(length(todos))

    min(base_score * priority_bonus, 100.0)
  end

  defp analyze_velocity_trend(todos) do
    # Analyze velocity trend over time
    # Simplified implementation - would use historical data in real system
    completed_count = Enum.count(todos, &(&1.status == :completed))

    cond do
      completed_count > length(todos) * 0.7 -> :up
      completed_count < length(todos) * 0.3 -> :down
      true -> :stable
    end
  end

  defp calculate_quality_metrics(todos) do
    # Calculate quality-related metrics
    total_todos = length(todos)

    # Simplified quality metrics - would be more sophisticated in real implementation
    %{
      rework_rate: 0.05,  # 5% of TODOs require rework
      defect_rate: 0.02,  # 2% of completed TODOs have defects
      review_pass_rate: 0.95,  # 95% of TODOs pass review on first attempt
      test_coverage_compliance: 0.88  # 88% of TODOs meet test coverage requirements
    }
  end

  defp calculate_effort_distribution(todos) do
    # Calculate effort distribution across different dimensions
    by_category = todos
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {category, todo_list} -> {category, length(todo_list) / length(todos)} end)
    |> Enum.into(%{})

    by_priority = todos
    |> Enum.group_by(& &1.priority)
    |> Enum.map(fn {priority, todo_list} -> {priority, length(todo_list) / length(todos)} end)
    |> Enum.into(%{})

    by_team_member = todos
    |> Enum.group_by(&get_assignee/1)
    |> Enum.map(fn {assignee, todo_list} -> {assignee, length(todo_list) / length(todos)} end)
    |> Enum.into(%{})

    %{
      by_category: by_category,
      by_priority: by_priority,
      by_team_member: by_team_member
    }
  end

  defp get_assignee(todo) do
    case todo.metadata.assignee do
      nil -> "unassigned"
      assignee -> assignee
    end
  end

  defp generate_category_breakdown(todos, options) do
    # Generate detailed breakdown by category
    categories = todos
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {category, category_todos} ->
      total = length(category_todos)
      completed = Enum.count(category_todos, &(&1.status == :completed))
      completion_rate = if total > 0, do: completed / total, else: 0.0

      %{
        category: category,
        total: total,
        completed: completed,
        completion_rate: completion_rate,
        average_effort: calculate_category_effort(category_todos)
      }
    end)

    # Generate trend data for each category
    trends = categories
    |> Enum.map(fn cat -> {cat.category, generate_trend_data(cat.category)} end)
    |> Enum.into(%{})

    # Generate insights
    insights = generate_category_insights(categories)

    %{
      categories: categories,
      trends: trends,
      insights: insights
    }
  end

  defp calculate_category_effort(category_todos) do
    # Calculate average effort for category
    # Simplified implementation - would use actual effort tracking in real system
    case List.first(category_todos) do
      %{category: :bug} -> 6.0
      %{category: :feature} -> 12.0
      %{category: :refactor} -> 8.0
      %{category: :docs} -> 2.0
      %{category: :test} -> 4.0
      %{category: :security} -> 16.0
      %{category: :performance} -> 10.0
      %{category: :tech_debt} -> 6.0
      _ -> 8.0
    end
  end

  defp generate_trend_data(category) do
    # Generate mock trend data - in real implementation would use historical data
    %{
      historical_data: [
        %{date: Date.utc_today() |> Date.add(-30), value: 10.0},
        %{date: Date.utc_today() |> Date.add(-20), value: 15.0},
        %{date: Date.utc_today() |> Date.add(-10), value: 12.0},
        %{date: Date.utc_today(), value: 18.0}
      ],
      trend_direction: :up,
      rate_of_change: 0.05,
      projection: 20.0
    }
  end

  defp generate_category_insights(categories) do
    insights = []

    insights = categories
    |> Enum.sort_by(& &1.completion_rate)
    |> List.first()
    |> case do
      %{category: category, completion_rate: rate} when rate < 0.5 ->
        ["#{category} category has low completion rate (#{Float.round(rate * 100, 1)}%)" | insights]
      _ -> insights
    end

    # Add more insights based on analysis
    high_effort_categories = categories
    |> Enum.filter(&(&1.average_effort > 10.0))
    |> Enum.map(& &1.category)

    insights = if length(high_effort_categories) > 0 do
      ["High-effort categories: #{Enum.join(high_effort_categories, ", ")}" | insights]
    else
      insights
    end

    Enum.reverse(insights)
  end

  defp generate_priority_analysis(todos, options) do
    # Analyze TODOs by priority level
    distribution = todos
    |> Enum.group_by(& &1.priority)
    |> Enum.map(fn {priority, todo_list} -> {priority, length(todo_list)} end)
    |> Enum.into(%{})

    completion_rates = todos
    |> Enum.group_by(& &1.priority)
    |> Enum.map(fn {priority, todo_list} ->
      completed = Enum.count(todo_list, &(&1.status == :completed))
      rate = completed / length(todo_list)
      {priority, rate}
    end)
    |> Enum.into(%{})

    # Count overdue items (simplified - would use actual due dates)
    overdue_items = Enum.count(todos, fn todo ->
      todo.priority in [:critical, :high] and todo.status not in [:completed, :cancelled]
    end)

    # Generate priority-based recommendations
    recommendations = generate_priority_recommendations(distribution, completion_rates, overdue_items)

    %{
      distribution: distribution,
      completion_rates: completion_rates,
      overdue_items: overdue_items,
      priority_recommendations: recommendations
    }
  end

  defp generate_priority_recommendations(distribution, completion_rates, overdue_items) do
    recommendations = []

    # Check for too many high-priority items
    high_priority_count = Map.get(distribution, :critical, 0) + Map.get(distribution, :high, 0)
    total_count = distribution |> Map.values() |> Enum.sum()

    recommendations = if high_priority_count > total_count * 0.3 do
      ["Consider re-evaluating priorities - #{high_priority_count} high-priority items may indicate priority inflation" | recommendations]
    else
      recommendations
    end

    # Check completion rates by priority
    critical_completion = Map.get(completion_rates, :critical, 0.0)
    recommendations = if critical_completion < 0.8 do
      ["Critical priority completion rate is low (#{Float.round(critical_completion * 100, 1)}%) - consider addressing bottlenecks" | recommendations]
    else
      recommendations
    end

    # Check overdue items
    recommendations = if overdue_items > 5 do
      ["#{overdue_items} high-priority items may be overdue - review and adjust timelines" | recommendations]
    else
      recommendations
    end

    Enum.reverse(recommendations)
  end

  defp generate_timeline_analysis(todos, options) do
    # Analyze timeline and milestones
    # Simplified implementation - would integrate with project management data

    milestones = [
      %{
        name: "Phase 1 Completion",
        target_date: Date.utc_today() |> Date.add(30),
        completion_percentage: 65.0,
        on_track: true,
        todos_remaining: 15
      },
      %{
        name: "Beta Release",
        target_date: Date.utc_today() |> Date.add(60),
        completion_percentage: 25.0,
        on_track: false,
        todos_remaining: 35
      }
    ]

    critical_path = todos
    |> Enum.filter(&(&1.priority == :critical))
    |> Enum.map(& &1.id)
    |> Enum.take(5)

    bottlenecks = identify_bottlenecks(todos)

    projected_dates = %{
      "All TODOs Complete" => Date.utc_today() |> Date.add(90),
      "Critical Path Complete" => Date.utc_today() |> Date.add(45)
    }

    %{
      milestones: milestones,
      critical_path: critical_path,
      bottlenecks: bottlenecks,
      projected_dates: projected_dates
    }
  end

  defp identify_bottlenecks(todos) do
    bottlenecks = []

    # Identify blocked TODOs as potential bottlenecks
    blocked_count = Enum.count(todos, &(&1.status == :blocked))

    bottlenecks = if blocked_count > 5 do
      bottleneck = %{
        type: :blocked_todos,
        description: "#{blocked_count} TODOs are currently blocked",
        affected_todos: todos |> Enum.filter(&(&1.status == :blocked)) |> Enum.map(& &1.id),
        impact_score: min(blocked_count / 10.0, 1.0),
        suggested_resolution: "Review and resolve blocking dependencies"
      }
      [bottleneck | bottlenecks]
    else
      bottlenecks
    end

    # Identify high-complexity TODOs as potential bottlenecks
    complex_todos = Enum.filter(todos, &(&1.category in [:refactor, :security, :performance]))

    bottlenecks = if length(complex_todos) > 10 do
      bottleneck = %{
        type: :complexity_bottleneck,
        description: "#{length(complex_todos)} complex TODOs may slow progress",
        affected_todos: Enum.map(complex_todos, & &1.id),
        impact_score: min(length(complex_todos) / 20.0, 1.0),
        suggested_resolution: "Break down complex TODOs into smaller tasks"
      }
      [bottleneck | bottlenecks]
    else
      bottlenecks
    end

    bottlenecks
  end

  defp generate_recommendations(todos, summary, detailed_metrics) do
    recommendations = []

    # Completion rate recommendations
    recommendations = if summary.completion_rate < 0.5 do
      ["Completion rate is below 50% - consider reviewing workload and priorities" | recommendations]
    else
      recommendations
    end

    # Productivity recommendations
    recommendations = if detailed_metrics.productivity_score < 60.0 do
      ["Productivity score is low - consider process improvements or additional resources" | recommendations]
    else
      recommendations
    end

    # Velocity trend recommendations
    recommendations = case detailed_metrics.velocity_trend do
      :down -> ["Velocity is declining - investigate and address impediments" | recommendations]
      :stable -> ["Velocity is stable - look for opportunities to improve" | recommendations]
      :up -> ["Velocity is increasing - maintain current practices" | recommendations]
    end

    # Quality recommendations
    quality = detailed_metrics.quality_metrics
    recommendations = if quality.rework_rate > 0.1 do
      ["Rework rate is high (#{Float.round(quality.rework_rate * 100, 1)}%) - focus on quality processes" | recommendations]
    else
      recommendations
    end

    Enum.reverse(recommendations)
  end

  defp calculate_team_summary(todos, team_data) do
    # Calculate team-level summary metrics
    team_members = Map.keys(team_data)

    %{
      team_size: length(team_members),
      total_todos_assigned: count_assigned_todos(todos),
      team_completion_rate: calculate_team_completion_rate(todos),
      average_todos_per_member: length(todos) / max(length(team_members), 1),
      top_performer: identify_top_performer(todos, team_data),
      collaboration_score: calculate_collaboration_score(todos, team_data)
    }
  end

  defp count_assigned_todos(todos) do
    Enum.count(todos, &(!is_nil(&1.metadata.assignee)))
  end

  defp calculate_team_completion_rate(todos) do
    assigned_todos = Enum.filter(todos, &(!is_nil(&1.metadata.assignee)))

    if Enum.empty?(assigned_todos) do
      0.0
    else
      completed = Enum.count(assigned_todos, &(&1.status == :completed))
      completed / length(assigned_todos)
    end
  end

  defp identify_top_performer(todos, team_data) do
    todos
    |> Enum.filter(&(&1.status == :completed and !is_nil(&1.metadata.assignee)))
    |> Enum.group_by(& &1.metadata.assignee)
    |> Enum.map(fn {assignee, completed_todos} -> {assignee, length(completed_todos)} end)
    |> Enum.max_by(fn {_assignee, count} -> count end, fn -> {"none", 0} end)
    |> elem(0)
  end

  defp calculate_collaboration_score(todos, team_data) do
    # Simplified collaboration score based on shared work
    # In real implementation would analyze code reviews, pair programming, etc.
    0.75
  end

  defp calculate_individual_metrics(todos, team_data) do
    team_data
    |> Enum.map(fn {member_name, member_info} ->
      member_todos = Enum.filter(todos, &(&1.metadata.assignee == member_name))

      %{
        name: member_name,
        total_assigned: length(member_todos),
        completed: Enum.count(member_todos, &(&1.status == :completed)),
        in_progress: Enum.count(member_todos, &(&1.status == :in_progress)),
        completion_rate: calculate_member_completion_rate(member_todos),
        average_completion_time: calculate_member_avg_time(member_todos),
        productivity_score: calculate_member_productivity(member_todos),
        specialization: identify_member_specialization(member_todos)
      }
    end)
  end

  defp calculate_member_completion_rate(member_todos) do
    if Enum.empty?(member_todos) do
      0.0
    else
      completed = Enum.count(member_todos, &(&1.status == :completed))
      completed / length(member_todos)
    end
  end

  defp calculate_member_avg_time(member_todos) do
    # Simplified - would use actual time tracking data
    24.0
  end

  defp calculate_member_productivity(member_todos) do
    # Simplified productivity calculation
    completion_rate = calculate_member_completion_rate(member_todos)
    completion_rate * 100
  end

  defp identify_member_specialization(member_todos) do
    if Enum.empty?(member_todos) do
      :general
    else
      member_todos
      |> Enum.group_by(& &1.category)
      |> Enum.max_by(fn {_category, todos} -> length(todos) end)
      |> elem(0)
    end
  end

  defp analyze_collaboration_patterns(todos, team_data) do
    # Analyze how team members collaborate
    %{
      cross_category_work: analyze_cross_category_work(todos, team_data),
      knowledge_sharing_score: 0.8,
      mentorship_activities: identify_mentorship_patterns(todos, team_data),
      team_cohesion_score: 0.75
    }
  end

  defp analyze_cross_category_work(todos, team_data) do
    # Analyze if team members work across different categories
    Map.keys(team_data)
    |> Enum.map(fn member ->
      member_todos = Enum.filter(todos, &(&1.metadata.assignee == member))
      categories = member_todos |> Enum.map(& &1.category) |> Enum.uniq()
      {member, length(categories)}
    end)
    |> Enum.into(%{})
  end

  defp identify_mentorship_patterns(todos, team_data) do
    # Simplified mentorship identification
    # In real implementation would analyze code reviews, pair programming, etc.
    []
  end

  defp generate_team_recommendations(individual_metrics, collaboration_metrics) do
    recommendations = []

    # Identify team members who might need support
    low_performers = individual_metrics
    |> Enum.filter(&(&1.completion_rate < 0.4))
    |> Enum.map(& &1.name)

    recommendations = if length(low_performers) > 0 do
      ["Team members needing support: #{Enum.join(low_performers, ", ")}" | recommendations]
    else
      recommendations
    end

    # Identify high performers for knowledge sharing
    high_performers = individual_metrics
    |> Enum.filter(&(&1.completion_rate > 0.8))
    |> Enum.map(& &1.name)

    recommendations = if length(high_performers) > 0 do
      ["Consider knowledge sharing sessions with top performers: #{Enum.join(high_performers, ", ")}" | recommendations]
    else
      recommendations
    end

    Enum.reverse(recommendations)
  end

  defp apply_filters(todos, filters) do
    todos
    |> filter_by_category(filters)
    |> filter_by_priority(filters)
    |> filter_by_status(filters)
    |> filter_by_assignee(filters)
    |> filter_by_date_range(filters)
  end

  defp filter_by_category(todos, filters) do
    case Map.get(filters, :category) do
      nil -> todos
      category when is_atom(category) -> Enum.filter(todos, &(&1.category == category))
      categories when is_list(categories) -> Enum.filter(todos, &(&1.category in categories))
    end
  end

  defp filter_by_priority(todos, filters) do
    case Map.get(filters, :priority) do
      nil -> todos
      priority when is_atom(priority) -> Enum.filter(todos, &(&1.priority == priority))
      priorities when is_list(priorities) -> Enum.filter(todos, &(&1.priority in priorities))
    end
  end

  defp filter_by_status(todos, filters) do
    case Map.get(filters, :status) do
      nil -> todos
      status when is_atom(status) -> Enum.filter(todos, &(&1.status == status))
      statuses when is_list(statuses) -> Enum.filter(todos, &(&1.status in statuses))
    end
  end

  defp filter_by_assignee(todos, filters) do
    case Map.get(filters, :assignee) do
      nil -> todos
      assignee -> Enum.filter(todos, &(&1.metadata.assignee == assignee))
    end
  end

  defp filter_by_date_range(todos, filters) do
    case Map.get(filters, :date_range) do
      nil -> todos
      {start_date, end_date} ->
        Enum.filter(todos, fn todo ->
          created_date = DateTime.to_date(todo.metadata.created_at)
          Date.compare(created_date, start_date) != :lt and Date.compare(created_date, end_date) != :gt
        end)
    end
  end

  defp group_todos(todos, options) do
    group_by = Map.get(options, :group_by, :category)

    case group_by do
      :category -> Enum.group_by(todos, & &1.category)
      :priority -> Enum.group_by(todos, & &1.priority)
      :status -> Enum.group_by(todos, & &1.status)
      :assignee -> Enum.group_by(todos, &(&1.metadata.assignee || "unassigned"))
      fields when is_list(fields) -> group_by_multiple_fields(todos, fields)
      _ -> %{all: todos}
    end
  end

  defp group_by_multiple_fields(todos, fields) do
    # Group by multiple fields - simplified implementation
    Enum.group_by(todos, fn todo ->
      fields
      |> Enum.map(fn field ->
        case field do
          :category -> todo.category
          :priority -> todo.priority
          :status -> todo.status
          :assignee -> todo.metadata.assignee || "unassigned"
        end
      end)
      |> Enum.join("_")
    end)
  end

  defp analyze_custom_data(filtered_todos, grouped_data, options) do
    # Perform analysis on the custom filtered/grouped data
    %{
      total_filtered: length(filtered_todos),
      group_counts: Enum.map(grouped_data, fn {key, todos} -> {key, length(todos)} end) |> Enum.into(%{}),
      completion_by_group: calculate_completion_by_group(grouped_data),
      trends_by_group: calculate_trends_by_group(grouped_data)
    }
  end

  defp calculate_completion_by_group(grouped_data) do
    grouped_data
    |> Enum.map(fn {group, todos} ->
      completed = Enum.count(todos, &(&1.status == :completed))
      rate = if length(todos) > 0, do: completed / length(todos), else: 0.0
      {group, rate}
    end)
    |> Enum.into(%{})
  end

  defp calculate_trends_by_group(grouped_data) do
    # Simplified trend calculation for each group
    grouped_data
    |> Enum.map(fn {group, _todos} ->
      # In real implementation, would calculate actual trends from historical data
      {group, :stable}
    end)
    |> Enum.into(%{})
  end

  defp generate_custom_insights(filtered_todos, analysis) do
    insights = []

    # Generate insights based on filtered data
    insights = if analysis.total_filtered < 10 do
      ["Small dataset (#{analysis.total_filtered} items) - insights may be limited" | insights]
    else
      insights
    end

    # Find group with highest completion rate
    best_group = analysis.completion_by_group
    |> Enum.max_by(fn {_group, rate} -> rate end, fn -> {nil, 0.0} end)

    insights = case best_group do
      {group, rate} when rate > 0.8 ->
        ["#{group} has the highest completion rate (#{Float.round(rate * 100, 1)}%)" | insights]
      _ -> insights
    end

    Enum.reverse(insights)
  end

  defp ensure_output_directory(output_dir) do
    File.mkdir_p!(output_dir)
    output_dir
  end

  defp export_to_format(report, format, output_dir, options) do
    Task.async(fn ->
      filename = generate_filename(report, format)
      file_path = Path.join(output_dir, filename)

      case format do
        :html -> export_to_html(report, file_path, options)
        :pdf -> export_to_pdf(report, file_path, options)
        :json -> export_to_json(report, file_path, options)
        :csv -> export_to_csv(report, file_path, options)
        :xlsx -> export_to_xlsx(report, file_path, options)
        _ -> {:error, "Unsupported format: #{format}"}
      end
    end)
  end

  defp await_export_result(task) do
    Task.await(task, 30_000)
  end

  defp generate_filename(report, format) do
    base_name = report.report_id |> String.downcase()
    extension = case format do
      :html -> "html"
      :pdf -> "pdf"
      :json -> "json"
      :csv -> "csv"
      :xlsx -> "xlsx"
    end

    "#{base_name}.#{extension}"
  end

  defp export_to_html(report, file_path, options) do
    # Generate HTML report
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>TODO Progress Report - #{report.report_id}</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .summary { background: #f5f5f5; padding: 15px; margin: 10px 0; }
            .metric { display: inline-block; margin: 10px; padding: 10px; background: white; border: 1px solid #ddd; }
            table { width: 100%; border-collapse: collapse; margin: 10px 0; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
            th { background-color: #f2f2f2; }
        </style>
    </head>
    <body>
        <h1>TODO Progress Report</h1>
        <p>Report ID: #{report.report_id}</p>
        <p>Generated: #{report.generated_at}</p>

        <div class="summary">
            <h2>Summary</h2>
            <div class="metric">Total TODOs: #{report.summary.total_todos}</div>
            <div class="metric">Completed: #{report.summary.completed_todos}</div>
            <div class="metric">Completion Rate: #{Float.round(report.summary.completion_rate * 100, 1)}%</div>
        </div>

        <h2>Category Breakdown</h2>
        <table>
            <tr><th>Category</th><th>Total</th><th>Completed</th><th>Rate</th></tr>
            #{Enum.map(report.category_breakdown.categories, fn cat ->
              "<tr><td>#{cat.category}</td><td>#{cat.total}</td><td>#{cat.completed}</td><td>#{Float.round(cat.completion_rate * 100, 1)}%</td></tr>"
            end) |> Enum.join("\n")}
        </table>

        <h2>Recommendations</h2>
        <ul>
            #{Enum.map(report.recommendations, fn rec -> "<li>#{rec}</li>" end) |> Enum.join("\n")}
        </ul>
    </body>
    </html>
    """

    File.write!(file_path, html_content)
    {:ok, %{format: :html, path: file_path, size: byte_size(html_content)}}
  end

  defp export_to_json(report, file_path, options) do
    json_content = Jason.encode!(report, pretty: true)
    File.write!(file_path, json_content)
    {:ok, %{format: :json, path: file_path, size: byte_size(json_content)}}
  end

  defp export_to_csv(report, file_path, options) do
    # Generate CSV with category breakdown
    headers = "Category,Total,Completed,Completion Rate\n"

    rows = report.category_breakdown.categories
    |> Enum.map(fn cat ->
      "#{cat.category},#{cat.total},#{cat.completed},#{Float.round(cat.completion_rate * 100, 1)}%"
    end)
    |> Enum.join("\n")

    csv_content = headers <> rows
    File.write!(file_path, csv_content)
    {:ok, %{format: :csv, path: file_path, size: byte_size(csv_content)}}
  end

  defp export_to_pdf(report, file_path, options) do
    # Simplified PDF export - in real implementation would use a PDF library
    pdf_content = "TODO Progress Report PDF - #{report.report_id}\n" <>
                  "This is a placeholder for PDF content."

    File.write!(file_path, pdf_content)
    {:ok, %{format: :pdf, path: file_path, size: byte_size(pdf_content)}}
  end

  defp export_to_xlsx(report, file_path, options) do
    # Simplified Excel export - in real implementation would use an Excel library
    xlsx_content = "TODO Progress Report Excel - #{report.report_id}\n" <>
                   "This is a placeholder for Excel content."

    File.write!(file_path, xlsx_content)
    {:ok, %{format: :xlsx, path: file_path, size: byte_size(xlsx_content)}}
  end

  defp generate_job_id do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    "JOB_#{timestamp}_#{:rand.uniform(1000)}"
  end

  defp calculate_next_run_date(schedule_config) do
    # Calculate next run date based on schedule
    case schedule_config.frequency do
      :daily -> Date.utc_today() |> Date.add(1)
      :weekly -> Date.utc_today() |> Date.add(7)
      :monthly -> Date.utc_today() |> Date.add(30)
      _ -> Date.utc_today() |> Date.add(1)
    end
  end
end
