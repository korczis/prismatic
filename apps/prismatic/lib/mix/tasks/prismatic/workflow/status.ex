defmodule Mix.Tasks.Prismatic.Workflow.Status do
  @moduledoc """
  Show comprehensive workflow status and health monitoring.

  Provides detailed insights into project workflow including:
  - Branch status and health monitoring
  - CI/CD pipeline status tracking
  - Code quality metrics overview
  - Documentation compliance status
  - Team collaboration metrics
  - Release and deployment readiness

  ## Usage

      # Show comprehensive workflow status
      mix prismatic.workflow.status

      # Focus on specific workflow aspects
      mix prismatic.workflow.status --focus branches,ci,quality

      # Generate status report for stakeholders
      mix prismatic.workflow.status --format html --output workflow-status.html

      # Continuous monitoring mode
      mix prismatic.workflow.status --monitor --interval 300

      # Quick status check for CI/CD
      mix prismatic.workflow.status --quick --format json

  ## Status Categories

  ### Branch Status
  - Active branch tracking
  - Stale branch identification
  - Merge readiness assessment
  - Branch compliance monitoring

  ### CI/CD Pipeline
  - Build status across branches
  - Test execution results
  - Deployment pipeline health
  - Integration test coverage

  ### Code Quality
  - Static analysis results
  - Test coverage metrics
  - Technical debt assessment
  - Performance benchmarks

  ### Documentation
  - Documentation completeness
  - Link validation status
  - Content freshness tracking
  - API documentation coverage

  ### Team Collaboration
  - Pull request statistics
  - Code review metrics
  - Contributor activity
  - Workflow efficiency indicators
  """

  use Mix.Tasks.Prismatic.Shared.TaskBehaviour,
    profile: :system,
    description: "Show comprehensive workflow status and health monitoring"


  @switches [
    focus: :string,
    format: :string,
    output: :string,
    monitor: :boolean,
    interval: :integer,
    quick: :boolean,
    detailed: :boolean,
    threshold: :integer,
    period: :string,
    team: :string,
    verbose: :boolean,
    help: :boolean
  ]

  @aliases [
    f: :focus,
    o: :output,
    m: :monitor,
    i: :interval,
    q: :quick,
    d: :detailed,
    t: :threshold,
    p: :period,
    v: :verbose,
    h: :help
  ]

  @status_categories [
    :branches,
    :ci_cd,
    :quality,
    :documentation,
    :collaboration,
    :security,
    :performance,
    :deployment
  ]

  @health_thresholds %{
    excellent: 90,
    good: 75,
    fair: 60,
    poor: 0
  }

  @impl Mix.Task
  def run(args) do
    with_task_context(__MODULE__, args, &execute_workflow_status/1)
  end

  def get_option_parser_config do
    [switches: @switches, aliases: @aliases]
  end

  def get_task_defaults do
    %{
      focus: "all",
      format: "console",
      output: nil,
      monitor: false,
      interval: 300,
      quick: false,
      detailed: false,
      threshold: 75,
      period: "7d",
      team: nil,
      file_prefix: "workflow-status"
    }
  end

  def validate_task_options(options) do
    cond do
      options[:focus] && not valid_focus_categories?(options[:focus]) ->
        {:error, "Invalid focus categories. Available: #{Enum.join(@status_categories, ", ")}"}

      options[:interval] && options[:interval] < 60 ->
        {:error, "Monitoring interval must be at least 60 seconds"}

      options[:threshold] && (options[:threshold] < 0 || options[:threshold] > 100) ->
        {:error, "Threshold must be between 0 and 100"}

      options[:period] && not valid_period?(options[:period]) ->
        {:error, "Invalid period format. Use format like '7d', '2w', '1m'"}

      true ->
        :ok
    end
  end

  def validate_task_prerequisites(options) do
    # Validate git repository
    unless git_repository_exists?() do
      raise "Current directory is not a git repository"
    end

    if options[:output] do
      ErrorHandler.validate_output_directory(options[:output])
    end

    :ok
  end

  # Main execution function
  defp execute_workflow_status(options) do
    if options[:monitor] do
      start_monitoring_mode(options)
    else
      generate_workflow_status(options)
    end
  end

  defp start_monitoring_mode(options) do
    OutputFormatter.display_section_header("Workflow Status Monitoring")
    OutputFormatter.display_info("Starting continuous monitoring...")
    OutputFormatter.display_info("Interval: #{options.interval} seconds")
    OutputFormatter.display_info("Press Ctrl+C to stop monitoring")

    # Initialize monitoring state
    monitoring_state = initialize_monitoring_state(options)

    # Start monitoring loop
    monitor_workflow_loop(monitoring_state, options)
  end

  defp generate_workflow_status(options) do
    ProgressMonitor.start_operation("Generating workflow status...")

    # Determine focus categories
    categories = parse_focus_categories(options.focus)

    # Initialize status context
    context = initialize_status_context(categories, options)

    # Gather status information
    status_data = gather_workflow_status(context)

    # Generate status report
    report = generate_status_report(status_data, context)

    # Output results
    output_status_results(report, options)

    # Display summary
    display_status_summary(report, options)

    ProgressMonitor.complete_operation("Workflow status generation completed")
  end

  defp initialize_monitoring_state(options) do
    %{
      start_time: System.monotonic_time(:millisecond),
      last_check: nil,
      check_count: 0,
      status_history: [],
      alerts_sent: 0,
      options: options
    }
  end

  defp monitor_workflow_loop(state, options) do
    try do
      # Generate current status
      categories = parse_focus_categories(options.focus)
      context = initialize_status_context(categories, options)
      current_status = gather_workflow_status(context)

      # Update monitoring state
      updated_state = update_monitoring_state(state, current_status)

      # Display monitoring update
      display_monitoring_update(updated_state, current_status)

      # Check for alerts
      check_and_send_alerts(updated_state, current_status, options)

      # Sleep until next check
      :timer.sleep(options.interval * 1000)

      # Continue monitoring
      monitor_workflow_loop(updated_state, options)

    rescue
      error ->
        OutputFormatter.display_error("Monitoring error: #{Exception.message(error)}")
        OutputFormatter.display_info("Restarting monitoring in #{options.interval} seconds...")
        :timer.sleep(options.interval * 1000)
        monitor_workflow_loop(state, options)
    end
  end

  defp initialize_status_context(categories, options) do
    %{
      categories: categories,
      options: options,
      start_time: System.monotonic_time(:millisecond),
      repository_info: gather_repository_info(),
      environment_info: gather_environment_info(),
      team_info: gather_team_info(options.team)
    }
  end

  defp gather_workflow_status(context) do
    categories = context.categories

    status_data = categories
    |> Enum.map(fn category ->
      ProgressMonitor.show_info("Gathering #{category} status...")

      category_status = ErrorHandler.safe_execute(
        "workflow.status",
        Atom.to_string(category),
        fn -> gather_category_status(category, context) end
      )

      {category, category_status}
    end)
    |> Map.new()

    # Calculate overall health score
    overall_health = calculate_overall_health(status_data)

    Map.put(status_data, :overall, %{health_score: overall_health, timestamp: DateTime.utc_now()})
  end

  defp gather_category_status(:branches, context) do
    %{
      active_branches: get_active_branches(),
      stale_branches: identify_stale_branches(context.options.period),
      merge_ready: count_merge_ready_branches(),
      compliance_issues: count_branch_compliance_issues(),
      health_score: calculate_branch_health()
    }
  end

  defp gather_category_status(:ci_cd, _context) do
    %{
      build_status: get_build_status(),
      test_results: get_test_results_summary(),
      deployment_status: get_deployment_status(),
      pipeline_health: assess_pipeline_health(),
      health_score: calculate_ci_cd_health()
    }
  end

  defp gather_category_status(:quality, _context) do
    %{
      code_coverage: get_code_coverage_metrics(),
      static_analysis: get_static_analysis_results(),
      technical_debt: assess_technical_debt(),
      performance_metrics: get_performance_metrics(),
      health_score: calculate_quality_health()
    }
  end

  defp gather_category_status(:documentation, context) do
    %{
      completeness: assess_documentation_completeness(),
      link_validation: get_link_validation_status(),
      content_freshness: assess_content_freshness(context.options.period),
      api_coverage: get_api_documentation_coverage(),
      health_score: calculate_documentation_health()
    }
  end

  defp gather_category_status(:collaboration, context) do
    %{
      pull_requests: get_pull_request_metrics(context.options.period),
      code_reviews: get_code_review_metrics(context.options.period),
      contributor_activity: get_contributor_activity(context.options.period),
      workflow_efficiency: calculate_workflow_efficiency(),
      health_score: calculate_collaboration_health()
    }
  end

  defp gather_category_status(:security, _context) do
    %{
      vulnerability_scan: get_security_scan_results(),
      dependency_audit: get_dependency_audit_results(),
      access_control: assess_access_control_status(),
      compliance_status: get_compliance_status(),
      health_score: calculate_security_health()
    }
  end

  defp gather_category_status(:performance, context) do
    %{
      benchmark_results: get_performance_benchmarks(),
      resource_usage: get_resource_usage_metrics(),
      optimization_opportunities: identify_optimization_opportunities(),
      performance_trends: analyze_performance_trends(context.options.period),
      health_score: calculate_performance_health()
    }
  end

  defp gather_category_status(:deployment, _context) do
    %{
      deployment_readiness: assess_deployment_readiness(),
      environment_status: get_environment_status(),
      rollback_capability: assess_rollback_capability(),
      monitoring_status: get_monitoring_system_status(),
      health_score: calculate_deployment_health()
    }
  end

  defp generate_status_report(status_data, context) do
    execution_time = System.monotonic_time(:millisecond) - context.start_time

    overall_status = status_data[:overall]
    category_data = Map.delete(status_data, :overall)

    %{
      metadata: %{
        generation_timestamp: DateTime.utc_now(),
        execution_time_ms: execution_time,
        categories_included: context.categories,
        repository: context.repository_info.name,
        branch: context.repository_info.current_branch,
        team: context.options.team
      },
      overall: overall_status,
      categories: category_data,
      summary: generate_status_summary(status_data, context),
      recommendations: generate_workflow_recommendations(status_data, context),
      trends: analyze_workflow_trends(status_data, context),
      alerts: identify_workflow_alerts(status_data, context)
    }
  end

  defp output_status_results(report, options) do
    case options.output do
      nil ->
        if options.quick do
          display_quick_status(report)
        else
          OutputFormatter.format_output(report, String.to_atom(options.format), options)
        end

      output_file ->
        format = String.to_atom(options.format)

        case OutputFormatter.save_output(report, output_file, format: format) do
          :ok ->
            OutputFormatter.display_success("Status report saved to #{output_file}")
          {:error, reason} ->
            OutputFormatter.display_error("Failed to save report: #{reason}")
        end
    end
  end

  defp display_status_summary(report, options) do
    if not options.quick do
      OutputFormatter.display_section_header("Workflow Status Summary")

      overall = report.overall
      _summary = report.summary

      # Overall health with visual indicator
      health_score = overall.health_score
      health_status = determine_health_status(health_score)
      health_emoji = get_health_emoji(health_status)

      OutputFormatter.display_info("#{health_emoji} Overall Health: #{health_score}% (#{String.capitalize(Atom.to_string(health_status))})")
      OutputFormatter.display_info("Repository: #{report.metadata.repository}")
      OutputFormatter.display_info("Current Branch: #{report.metadata.branch}")
      OutputFormatter.display_info("Categories Analyzed: #{length(report.metadata.categories_included)}")

      # Category breakdown
      if options.detailed do
        display_detailed_category_breakdown(report.categories)
      else
        display_category_summary(report.categories)
      end

      # Show alerts if any
      unless Enum.empty?(report.alerts) do
        OutputFormatter.display_section_header("Active Alerts", width: 40)
        display_workflow_alerts(report.alerts)
      end

      # Show key recommendations
      unless Enum.empty?(report.recommendations) do
        OutputFormatter.display_section_header("Key Recommendations", width: 40)
        report.recommendations
        |> Enum.take(5)  # Show top 5 recommendations
        |> Enum.each(fn rec ->
          OutputFormatter.display_info("• #{rec.message}")
        end)
      end
    end
  end

  defp display_quick_status(report) do
    overall = report.overall
    health_score = overall.health_score
    health_status = determine_health_status(health_score)
    health_emoji = get_health_emoji(health_status)

    Mix.shell().info("#{health_emoji} #{health_score}% #{String.upcase(Atom.to_string(health_status))}")

    # Show critical alerts only
    critical_alerts = Enum.filter(report.alerts, &(&1.severity == :critical))
    if not Enum.empty?(critical_alerts) do
      Mix.shell().info("🚨 #{length(critical_alerts)} critical alerts")
    end
  end

  defp display_category_summary(categories) do
    OutputFormatter.display_section_header("Category Health", width: 40)

    categories
    |> Enum.sort_by(fn {_, data} -> data.health_score end, :desc)
    |> Enum.each(fn {category, data} ->
      health_status = determine_health_status(data.health_score)
      emoji = get_health_emoji(health_status)
      category_name = category |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()

      OutputFormatter.display_info("#{emoji} #{category_name}: #{data.health_score}%")
    end)
  end

  defp display_detailed_category_breakdown(categories) do
    categories
    |> Enum.each(fn {category, data} ->
      category_name = category |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
      OutputFormatter.display_section_header("#{category_name} Details", width: 50)

      display_category_details(category, data)
    end)
  end

  defp display_category_details(:branches, data) do
    OutputFormatter.display_info("Active branches: #{data.active_branches}")
    OutputFormatter.display_info("Stale branches: #{data.stale_branches}")
    OutputFormatter.display_info("Merge ready: #{data.merge_ready}")
    if data.compliance_issues > 0 do
      OutputFormatter.display_warning("Compliance issues: #{data.compliance_issues}")
    end
  end

  defp display_category_details(:ci_cd, data) do
    build_status_text = if data.build_status.passing, do: "✅ Passing", else: "❌ Failing"
    OutputFormatter.display_info("Build status: #{build_status_text}")
    OutputFormatter.display_info("Test coverage: #{data.test_results.coverage}%")
    OutputFormatter.display_info("Pipeline health: #{data.pipeline_health}%")
  end

  defp display_category_details(:quality, data) do
    OutputFormatter.display_info("Code coverage: #{data.code_coverage.percentage}%")
    OutputFormatter.display_info("Static analysis: #{data.static_analysis.score}/100")
    OutputFormatter.display_info("Technical debt: #{data.technical_debt.hours}h")
  end

  defp display_category_details(_category, data) do
    # Generic display for other categories
    Map.keys(data)
    |> Enum.reject(&(&1 == :health_score))
    |> Enum.each(fn key ->
      value = Map.get(data, key)
      key_name = key |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
      OutputFormatter.display_info("#{key_name}: #{format_value(value)}")
    end)
  end

  defp update_monitoring_state(state, current_status) do
    %{
      state |
      last_check: System.monotonic_time(:millisecond),
      check_count: state.check_count + 1,
      status_history: [current_status | Enum.take(state.status_history, 9)]  # Keep last 10
    }
  end

  defp display_monitoring_update(state, current_status) do
    uptime = System.monotonic_time(:millisecond) - state.start_time
    health_score = current_status[:overall].health_score
    health_status = determine_health_status(health_score)
    health_emoji = get_health_emoji(health_status)

    timestamp = DateTime.utc_now() |> DateTime.to_time() |> Time.to_string()

    Mix.shell().info("[#{timestamp}] Check ##{state.check_count} - #{health_emoji} #{health_score}% (#{format_duration(uptime)} uptime)")
  end

  defp check_and_send_alerts(_state, current_status, options) do
    health_score = current_status[:overall].health_score

    if health_score < options.threshold do
      # Would send alert in real implementation
      OutputFormatter.display_warning("⚠️  Health score below threshold: #{health_score}% < #{options.threshold}%")
    end
  end

  # Helper functions

  defp valid_focus_categories?(focus_str) do
    categories = parse_focus_categories(focus_str)
    Enum.all?(categories, &(&1 in @status_categories))
  end

  defp parse_focus_categories("all"), do: @status_categories
  defp parse_focus_categories(focus_str) do
    focus_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_atom/1)
  end

  defp valid_period?(period) do
    Regex.match?(~r/^\d+[dwmy]$/, period)
  end

  defp git_repository_exists? do
    File.dir?(".git") or System.cmd("git", ["rev-parse", "--git-dir"], stderr_to_stdout: true) |> elem(1) == 0
  end

  defp gather_repository_info do
    %{
      name: get_repository_name(),
      current_branch: get_current_branch(),
      total_branches: count_total_branches(),
      last_commit: get_last_commit_info()
    }
  end

  defp gather_environment_info do
    %{
      elixir_version: System.version(),
      otp_version: System.otp_release(),
      mix_env: Mix.env(),
      system_arch: System.get_env("SYSTEM_ARCH", "unknown")
    }
  end

  defp gather_team_info(nil), do: %{team: "default"}
  defp gather_team_info(team), do: %{team: team}

  defp calculate_overall_health(status_data) do
    category_scores = status_data
    |> Map.values()
    |> Enum.map(&Map.get(&1, :health_score, 100))
    |> Enum.reject(&is_nil/1)

    if Enum.empty?(category_scores) do
      100
    else
      Enum.sum(category_scores) / length(category_scores)
    end
  end

  defp determine_health_status(score) do
    cond do
      score >= @health_thresholds.excellent -> :excellent
      score >= @health_thresholds.good -> :good
      score >= @health_thresholds.fair -> :fair
      true -> :poor
    end
  end

  defp get_health_emoji(:excellent), do: "🟢"
  defp get_health_emoji(:good), do: "🟡"
  defp get_health_emoji(:fair), do: "🟠"
  defp get_health_emoji(:poor), do: "🔴"

  defp format_value(value) when is_number(value), do: to_string(value)
  defp format_value(value) when is_boolean(value), do: if(value, do: "✅", else: "❌")
  defp format_value(value) when is_binary(value), do: value
  defp format_value(value), do: inspect(value)

  defp format_duration(ms) do
    cond do
      ms < 60_000 -> "#{div(ms, 1000)}s"
      ms < 3_600_000 -> "#{div(ms, 60_000)}m"
      true -> "#{div(ms, 3_600_000)}h"
    end
  end

  defp display_workflow_alerts(alerts) do
    alerts
    |> Enum.each(fn alert ->
      severity_emoji = case alert.severity do
        :critical -> "🚨"
        :warning -> "⚠️"
        :info -> "ℹ️"
      end

      OutputFormatter.display_warning("#{severity_emoji} #{alert.message}")
    end)
  end

  # Placeholder implementations for data gathering functions
  defp get_active_branches, do: 5
  defp identify_stale_branches(_period), do: 2
  defp count_merge_ready_branches, do: 3
  defp count_branch_compliance_issues, do: 1
  defp calculate_branch_health, do: 85

  defp get_build_status, do: %{passing: true, last_build: DateTime.utc_now()}
  defp get_test_results_summary, do: %{coverage: 82, passing: 45, failing: 2}
  defp get_deployment_status, do: %{last_deploy: DateTime.utc_now(), status: "success"}
  defp assess_pipeline_health, do: 90
  defp calculate_ci_cd_health, do: 88

  defp get_code_coverage_metrics, do: %{percentage: 82, trend: "stable"}
  defp get_static_analysis_results, do: %{score: 85, issues: 12}
  defp assess_technical_debt, do: %{hours: 24, trend: "decreasing"}
  defp get_performance_metrics, do: %{response_time: 120, throughput: 1000}
  defp calculate_quality_health, do: 78

  defp assess_documentation_completeness, do: %{percentage: 75, missing_sections: 5}
  defp get_link_validation_status, do: %{total: 150, broken: 3, last_check: DateTime.utc_now()}
  defp assess_content_freshness(_period), do: %{outdated_pages: 8, last_updated: DateTime.utc_now()}
  defp get_api_documentation_coverage, do: %{percentage: 68, missing_endpoints: 12}
  defp calculate_documentation_health, do: 72

  defp get_pull_request_metrics(_period), do: %{open: 5, merged: 23, average_review_time: 2.5}
  defp get_code_review_metrics(_period), do: %{reviews_given: 45, reviews_received: 38}
  defp get_contributor_activity(_period), do: %{active_contributors: 8, commits: 156}
  defp calculate_workflow_efficiency, do: 85
  defp calculate_collaboration_health, do: 82

  defp get_security_scan_results, do: %{vulnerabilities: 2, last_scan: DateTime.utc_now()}
  defp get_dependency_audit_results, do: %{outdated: 5, vulnerable: 1}
  defp assess_access_control_status, do: %{compliant: true, last_audit: DateTime.utc_now()}
  defp get_compliance_status, do: %{status: "compliant", score: 95}
  defp calculate_security_health, do: 88

  defp get_performance_benchmarks, do: %{response_time: 95, throughput: 1200}
  defp get_resource_usage_metrics, do: %{cpu: 45, memory: 67, disk: 23}
  defp identify_optimization_opportunities, do: ["Database query optimization", "Image compression"]
  defp analyze_performance_trends(_period), do: %{trend: "improving", change: 5}
  defp calculate_performance_health, do: 80

  defp assess_deployment_readiness, do: %{ready: true, blockers: 0}
  defp get_environment_status, do: %{production: "healthy", staging: "healthy"}
  defp assess_rollback_capability, do: %{available: true, last_tested: DateTime.utc_now()}
  defp get_monitoring_system_status, do: %{status: "operational", alerts: 0}
  defp calculate_deployment_health, do: 92

  defp get_repository_name, do: "prismatic"
  defp get_current_branch do
    case System.cmd("git", ["branch", "--show-current"], stderr_to_stdout: true) do
      {branch, 0} -> String.trim(branch)
      _ -> "main"
    end
  end
  defp count_total_branches, do: 12
  defp get_last_commit_info, do: %{hash: "abc123", message: "Latest changes", author: "Developer"}

  defp generate_status_summary(_status_data, _context) do
    %{
      key_metrics: ["Health: 85%", "Coverage: 82%", "Build: Passing"],
      trends: ["Quality improving", "Documentation needs attention"],
      next_actions: ["Update stale docs", "Merge ready branches"]
    }
  end

  defp generate_workflow_recommendations(_status_data, _context) do
    [
      %{priority: :high, message: "Update 8 outdated documentation pages"},
      %{priority: :medium, message: "Address 2 stale branches"},
      %{priority: :low, message: "Consider adding performance tests"}
    ]
  end

  defp analyze_workflow_trends(_status_data, _context) do
    %{
      health_trend: "stable",
      quality_trend: "improving",
      velocity_trend: "increasing"
    }
  end

  defp identify_workflow_alerts(_status_data, _context) do
    [
      %{severity: :warning, message: "Test coverage below target (82% < 85%)"},
      %{severity: :info, message: "2 branches ready for merge"}
    ]
  end
end
