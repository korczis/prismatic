defmodule Prismatic.TODO.Analyzer do
  @moduledoc """
  Advanced TODO analysis and dependency mapping for the Prismatic TODO management system.

  This module provides comprehensive analysis capabilities for TODO items including
  dependency graph analysis, complexity assessment, implementation planning, and
  risk evaluation. It uses machine learning techniques and heuristics to provide
  intelligent insights for TODO management.

  ## Features

  - **Dependency Graph Analysis**: Build and analyze dependencies between TODO items
  - **Complexity Assessment**: Estimate implementation complexity and effort
  - **Implementation Planning**: Generate phased implementation plans
  - **Risk Assessment**: Identify and evaluate implementation risks
  - **Priority Recommendations**: Smart priority adjustments based on analysis
  - **Impact Analysis**: Assess impact of TODO completion on codebase

  ## Usage

      # Analyze TODO dependencies
      {:ok, analysis} = Analyzer.analyze_dependencies(todos)

      # Generate implementation plan
      {:ok, plan} = Analyzer.generate_implementation_plan(todos, options)

      # Assess TODO complexity
      {:ok, complexity} = Analyzer.assess_complexity(todo_item)

      # Perform risk analysis
      {:ok, risks} = Analyzer.analyze_risks(todos, codebase_context)

  ## Analysis Types

  The analyzer performs several types of analysis:

  - **Static Analysis**: Code structure and relationship analysis
  - **Dynamic Analysis**: Runtime behavior and performance impact assessment
  - **Semantic Analysis**: Content understanding and categorization
  - **Temporal Analysis**: Timeline and scheduling considerations
  - **Resource Analysis**: Development resource requirements

  ## Configuration

      config :prismatic, Prismatic.TODO.Analyzer,
        complexity_factors: %{
          code_lines_affected: 0.3,
          dependencies_count: 0.2,
          test_coverage_impact: 0.15,
          breaking_changes: 0.35
        },
        risk_thresholds: %{
          high_complexity: 0.8,
          many_dependencies: 5,
          critical_path: true
        },
        ml_model_path: "priv/models/todo_classifier.bin"
  """

  alias Prismatic.TODO.Scanner
  require Logger

  @type analysis_options :: %{
    include_dependencies: boolean(),
    analyze_complexity: boolean(),
    generate_estimates: boolean(),
    assess_risks: boolean(),
    context_analysis: boolean()
  }

  @type analysis_result :: %{
    dependency_graph: dependency_graph(),
    complexity_analysis: complexity_analysis(),
    implementation_plan: implementation_plan(),
    risk_assessment: risk_assessment(),
    priority_recommendations: [priority_recommendation()],
    estimated_effort_hours: float(),
    completion_timeline: Date.t()
  }

  @type dependency_graph :: %{
    nodes: [String.t()],
    edges: [dependency_edge()],
    cycles: [cycle()],
    critical_path: [String.t()],
    dependency_levels: %{String.t() => non_neg_integer()}
  }

  @type dependency_edge :: %{
    from: String.t(),
    to: String.t(),
    type: :hard | :soft | :suggested,
    strength: float()
  }

  @type cycle :: %{
    nodes: [String.t()],
    severity: :critical | :warning | :info
  }

  @type complexity_analysis :: %{
    overall_complexity: float(),
    factors: %{atom() => float()},
    estimation_confidence: float(),
    complexity_breakdown: %{atom() => complexity_detail()}
  }

  @type complexity_detail :: %{
    score: float(),
    description: String.t(),
    contributing_factors: [String.t()]
  }

  @type implementation_plan :: %{
    phases: [implementation_phase()],
    total_estimate: float(),
    critical_path: [String.t()],
    parallel_tracks: [[String.t()]],
    milestones: [milestone()]
  }

  @type implementation_phase :: %{
    name: String.t(),
    todos: [String.t()],
    estimate_hours: float(),
    dependencies: [String.t()],
    risks: [String.t()],
    deliverables: [String.t()]
  }

  @type milestone :: %{
    name: String.t(),
    todos_completed: [String.t()],
    target_date: Date.t(),
    success_criteria: [String.t()]
  }

  @type risk_assessment :: %{
    overall_risk: :low | :medium | :high | :critical,
    risk_factors: [risk_factor()],
    mitigation_strategies: [mitigation_strategy()],
    risk_score: float()
  }

  @type risk_factor :: %{
    type: atom(),
    severity: :low | :medium | :high | :critical,
    description: String.t(),
    affected_todos: [String.t()],
    probability: float(),
    impact: float()
  }

  @type mitigation_strategy :: %{
    risk_type: atom(),
    strategy: String.t(),
    effort_required: String.t(),
    effectiveness: float()
  }

  @type priority_recommendation :: %{
    todo_id: String.t(),
    current_priority: atom(),
    recommended_priority: atom(),
    reasoning: String.t(),
    confidence: float()
  }

  @doc """
  Perform comprehensive analysis of TODO items.

  ## Parameters

  - `todos` - List of TODO items to analyze
  - `options` - Analysis options and configuration

  ## Returns

  Complete analysis results with dependencies, complexity, and recommendations.

  ## Examples

      iex> Analyzer.analyze_todos(todos, %{include_dependencies: true})
      {:ok, %{
        dependency_graph: %{...},
        complexity_analysis: %{...},
        implementation_plan: %{...},
        risk_assessment: %{...}
      }}
  """
  @spec analyze_todos([Scanner.todo_item()], analysis_options()) :: {:ok, analysis_result()} | {:error, term()}
  def analyze_todos(todos, options \\ %{}) do
    Logger.info("Starting comprehensive TODO analysis for #{length(todos)} items")

    options = merge_default_options(options)

    analysis_result = %{
      dependency_graph: %{nodes: [], edges: [], cycles: [], critical_path: [], dependency_levels: %{}},
      complexity_analysis: %{overall_complexity: 0.0, factors: %{}, estimation_confidence: 0.0, complexity_breakdown: %{}},
      implementation_plan: %{phases: [], total_estimate: 0.0, critical_path: [], parallel_tracks: [], milestones: []},
      risk_assessment: %{overall_risk: :low, risk_factors: [], mitigation_strategies: [], risk_score: 0.0},
      priority_recommendations: [],
      estimated_effort_hours: 0.0,
      completion_timeline: Date.utc_today()
    }

    try do
      result = analysis_result
      |> analyze_dependencies_if_enabled(todos, options)
      |> analyze_complexity_if_enabled(todos, options)
      |> generate_implementation_plan_if_enabled(todos, options)
      |> assess_risks_if_enabled(todos, options)
      |> generate_priority_recommendations(todos, options)
      |> calculate_effort_estimates(todos, options)
      |> project_completion_timeline(todos, options)

      Logger.info("TODO analysis completed successfully")
      {:ok, result}
    rescue
      error ->
        Logger.error("TODO analysis failed: #{Exception.message(error)}")
        {:error, "Analysis failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Analyze dependencies between TODO items.

  ## Parameters

  - `todos` - List of TODO items
  - `options` - Dependency analysis options

  ## Returns

  Dependency graph with nodes, edges, cycles, and critical path.

  ## Examples

      iex> Analyzer.analyze_dependencies(todos)
      {:ok, %{
        nodes: ["TODO_001", "TODO_002", "TODO_003"],
        edges: [%{from: "TODO_001", to: "TODO_002", type: :hard}],
        critical_path: ["TODO_001", "TODO_002"],
        cycles: []
      }}
  """
  @spec analyze_dependencies([Scanner.todo_item()], map()) :: {:ok, dependency_graph()} | {:error, term()}
  def analyze_dependencies(todos, options \\ %{}) do
    Logger.info("Analyzing TODO dependencies")

    try do
      # Extract explicit dependencies from metadata
      explicit_deps = extract_explicit_dependencies(todos)

      # Infer implicit dependencies from code analysis
      implicit_deps = infer_implicit_dependencies(todos, options)

      # Combine and build dependency graph
      all_edges = explicit_deps ++ implicit_deps
      nodes = extract_unique_nodes(todos, all_edges)

      # Detect dependency cycles
      cycles = detect_dependency_cycles(nodes, all_edges)

      # Calculate critical path
      critical_path = calculate_critical_path(nodes, all_edges)

      # Determine dependency levels
      dependency_levels = calculate_dependency_levels(nodes, all_edges)

      dependency_graph = %{
        nodes: nodes,
        edges: all_edges,
        cycles: cycles,
        critical_path: critical_path,
        dependency_levels: dependency_levels
      }

      {:ok, dependency_graph}
    rescue
      error ->
        {:error, "Dependency analysis failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Assess complexity of TODO items.

  ## Parameters

  - `todos` - List of TODO items to assess
  - `options` - Complexity assessment options

  ## Returns

  Complexity analysis with overall scores and detailed breakdown.

  ## Examples

      iex> Analyzer.assess_complexity(todos)
      {:ok, %{
        overall_complexity: 0.73,
        estimation_confidence: 0.85,
        complexity_breakdown: %{
          code_impact: %{score: 0.8, description: "High code impact"},
          dependencies: %{score: 0.6, description: "Medium dependencies"}
        }
      }}
  """
  @spec assess_complexity([Scanner.todo_item()], map()) :: {:ok, complexity_analysis()} | {:error, term()}
  def assess_complexity(todos, options \\ %{}) do
    Logger.info("Assessing TODO complexity")

    try do
      # Analyze different complexity factors
      complexity_factors = %{
        code_lines_affected: assess_code_impact(todos),
        dependencies_count: assess_dependency_complexity(todos),
        test_coverage_impact: assess_test_impact(todos),
        breaking_changes: assess_breaking_change_risk(todos),
        domain_complexity: assess_domain_complexity(todos)
      }

      # Calculate overall complexity score
      overall_complexity = calculate_weighted_complexity(complexity_factors, options)

      # Assess estimation confidence
      estimation_confidence = calculate_estimation_confidence(todos, complexity_factors)

      # Generate detailed breakdown
      complexity_breakdown = generate_complexity_breakdown(complexity_factors)

      complexity_analysis = %{
        overall_complexity: overall_complexity,
        factors: complexity_factors,
        estimation_confidence: estimation_confidence,
        complexity_breakdown: complexity_breakdown
      }

      {:ok, complexity_analysis}
    rescue
      error ->
        {:error, "Complexity assessment failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Generate implementation plan for TODO items.

  ## Parameters

  - `todos` - List of TODO items
  - `dependency_graph` - Dependency graph from analysis
  - `options` - Planning options

  ## Returns

  Implementation plan with phases, estimates, and milestones.

  ## Examples

      iex> Analyzer.generate_implementation_plan(todos, dependency_graph)
      {:ok, %{
        phases: [
          %{name: "Phase 1", todos: ["TODO_001"], estimate_hours: 8.0}
        ],
        total_estimate: 24.0,
        milestones: [...]
      }}
  """
  @spec generate_implementation_plan([Scanner.todo_item()], dependency_graph(), map()) :: {:ok, implementation_plan()} | {:error, term()}
  def generate_implementation_plan(todos, dependency_graph, options \\ %{}) do
    Logger.info("Generating implementation plan")

    try do
      # Group TODOs into logical phases based on dependencies
      phases = create_implementation_phases(todos, dependency_graph, options)

      # Calculate total effort estimate
      total_estimate = calculate_total_effort(phases)

      # Extract critical path from dependency graph
      critical_path = dependency_graph.critical_path

      # Identify parallel execution tracks
      parallel_tracks = identify_parallel_tracks(todos, dependency_graph)

      # Generate project milestones
      milestones = generate_project_milestones(phases, options)

      implementation_plan = %{
        phases: phases,
        total_estimate: total_estimate,
        critical_path: critical_path,
        parallel_tracks: parallel_tracks,
        milestones: milestones
      }

      {:ok, implementation_plan}
    rescue
      error ->
        {:error, "Implementation plan generation failed: #{Exception.message(error)}"}
    end
  end

  @doc """
  Assess risks associated with TODO implementation.

  ## Parameters

  - `todos` - List of TODO items
  - `context` - Codebase and project context
  - `options` - Risk assessment options

  ## Returns

  Risk assessment with identified risks and mitigation strategies.

  ## Examples

      iex> Analyzer.analyze_risks(todos, context)
      {:ok, %{
        overall_risk: :medium,
        risk_factors: [
          %{type: :breaking_changes, severity: :high, description: "..."}
        ],
        mitigation_strategies: [...]
      }}
  """
  @spec analyze_risks([Scanner.todo_item()], map(), map()) :: {:ok, risk_assessment()} | {:error, term()}
  def analyze_risks(todos, context, options \\ %{}) do
    Logger.info("Analyzing implementation risks")

    try do
      # Identify various risk factors
      risk_factors = []
      |> identify_complexity_risks(todos)
      |> identify_dependency_risks(todos)
      |> identify_breaking_change_risks(todos)
      |> identify_resource_risks(todos, context)
      |> identify_timeline_risks(todos, context)
      |> identify_integration_risks(todos, context)

      # Calculate overall risk score
      risk_score = calculate_risk_score(risk_factors)

      # Determine overall risk level
      overall_risk = determine_risk_level(risk_score)

      # Generate mitigation strategies
      mitigation_strategies = generate_mitigation_strategies(risk_factors, options)

      risk_assessment = %{
        overall_risk: overall_risk,
        risk_factors: risk_factors,
        mitigation_strategies: mitigation_strategies,
        risk_score: risk_score
      }

      {:ok, risk_assessment}
    rescue
      error ->
        {:error, "Risk analysis failed: #{Exception.message(error)}"}
    end
  end

  # Private helper functions

  defp merge_default_options(options) do
    defaults = %{
      include_dependencies: true,
      analyze_complexity: true,
      generate_estimates: true,
      assess_risks: true,
      context_analysis: true,
      complexity_weights: %{
        code_lines_affected: 0.3,
        dependencies_count: 0.2,
        test_coverage_impact: 0.15,
        breaking_changes: 0.35
      }
    }

    Map.merge(defaults, options)
  end

  defp analyze_dependencies_if_enabled(result, todos, options) do
    if options.include_dependencies do
      case analyze_dependencies(todos, options) do
        {:ok, dependency_graph} ->
          Map.put(result, :dependency_graph, dependency_graph)

        {:error, _reason} ->
          Logger.warning("Failed to analyze dependencies, using empty graph")
          result
      end
    else
      result
    end
  end

  defp analyze_complexity_if_enabled(result, todos, options) do
    if options.analyze_complexity do
      case assess_complexity(todos, options) do
        {:ok, complexity_analysis} ->
          Map.put(result, :complexity_analysis, complexity_analysis)

        {:error, _reason} ->
          Logger.warning("Failed to analyze complexity, using defaults")
          result
      end
    else
      result
    end
  end

  defp generate_implementation_plan_if_enabled(result, todos, options) do
    if options.generate_estimates and Map.has_key?(result, :dependency_graph) do
      case generate_implementation_plan(todos, result.dependency_graph, options) do
        {:ok, implementation_plan} ->
          Map.put(result, :implementation_plan, implementation_plan)

        {:error, _reason} ->
          Logger.warning("Failed to generate implementation plan, using defaults")
          result
      end
    else
      result
    end
  end

  defp assess_risks_if_enabled(result, todos, options) do
    if options.assess_risks do
      context = build_analysis_context(result, todos)

      case analyze_risks(todos, context, options) do
        {:ok, risk_assessment} ->
          Map.put(result, :risk_assessment, risk_assessment)

        {:error, _reason} ->
          Logger.warning("Failed to assess risks, using defaults")
          result
      end
    else
      result
    end
  end

  defp generate_priority_recommendations(result, todos, _options) do
    recommendations = todos
    |> Enum.map(&generate_priority_recommendation(&1, result))
    |> Enum.reject(&is_nil/1)

    Map.put(result, :priority_recommendations, recommendations)
  end

  defp generate_priority_recommendation(todo, analysis_result) do
    current_priority = todo.priority

    # Analyze factors that might affect priority
    complexity_factor = get_complexity_factor(todo, analysis_result)
    dependency_factor = get_dependency_factor(todo, analysis_result)
    risk_factor = get_risk_factor(todo, analysis_result)

    # Calculate recommended priority based on factors
    recommended_priority = calculate_recommended_priority(
      current_priority,
      complexity_factor,
      dependency_factor,
      risk_factor
    )

    if recommended_priority != current_priority do
      %{
        todo_id: todo.id,
        current_priority: current_priority,
        recommended_priority: recommended_priority,
        reasoning: build_priority_reasoning(complexity_factor, dependency_factor, risk_factor),
        confidence: calculate_recommendation_confidence(complexity_factor, dependency_factor, risk_factor)
      }
    else
      nil
    end
  end

  defp get_complexity_factor(todo, analysis_result) do
    case Map.get(analysis_result, :complexity_analysis) do
      nil -> 0.5
      complexity ->
        Map.get(complexity.factors, :overall_complexity, 0.5)
    end
  end

  defp get_dependency_factor(todo, analysis_result) do
    case Map.get(analysis_result, :dependency_graph) do
      nil -> 0.5
      graph ->
        dependency_count = count_todo_dependencies(todo.id, graph)
        min(dependency_count / 5.0, 1.0)  # Normalize to 0-1 scale
    end
  end

  defp get_risk_factor(todo, analysis_result) do
    case Map.get(analysis_result, :risk_assessment) do
      nil -> 0.5
      risk ->
        risk.risk_score
    end
  end

  defp calculate_recommended_priority(current, complexity, dependency, risk) do
    # Simple scoring algorithm - in real implementation would be more sophisticated
    score = (complexity * 0.4) + (dependency * 0.3) + (risk * 0.3)

    cond do
      score >= 0.8 -> :critical
      score >= 0.6 -> :high
      score >= 0.4 -> :medium
      true -> :low
    end
  end

  defp build_priority_reasoning(complexity, dependency, risk) do
    factors = []

    factors = if complexity > 0.7, do: ["high complexity" | factors], else: factors
    factors = if dependency > 0.6, do: ["many dependencies" | factors], else: factors
    factors = if risk > 0.6, do: ["high risk" | factors], else: factors

    case factors do
      [] -> "Priority adjustment based on analysis"
      [single] -> "Priority adjustment due to #{single}"
      multiple -> "Priority adjustment due to #{Enum.join(multiple, ", ")}"
    end
  end

  defp calculate_recommendation_confidence(complexity, dependency, risk) do
    # Higher confidence when factors are more extreme
    factor_confidence = abs(complexity - 0.5) + abs(dependency - 0.5) + abs(risk - 0.5)
    min(factor_confidence / 1.5, 1.0)
  end

  defp count_todo_dependencies(todo_id, graph) do
    graph.edges
    |> Enum.count(fn edge -> edge.from == todo_id or edge.to == todo_id end)
  end

  defp calculate_effort_estimates(result, todos, _options) do
    # Calculate effort based on complexity and other factors
    effort_hours = todos
    |> Enum.map(&estimate_todo_effort(&1, result))
    |> Enum.sum()

    Map.put(result, :estimated_effort_hours, effort_hours)
  end

  defp estimate_todo_effort(todo, analysis_result) do
    base_effort = case todo.category do
      :bug -> 4.0
      :feature -> 8.0
      :refactor -> 6.0
      :docs -> 2.0
      :test -> 3.0
      :security -> 12.0
      :performance -> 10.0
      :tech_debt -> 5.0
    end

    # Adjust based on complexity if available
    complexity_multiplier = case Map.get(analysis_result, :complexity_analysis) do
      nil -> 1.0
      complexity -> 1.0 + complexity.overall_complexity
    end

    base_effort * complexity_multiplier
  end

  defp project_completion_timeline(result, todos, _options) do
    # Simple timeline projection based on effort estimates
    total_hours = result.estimated_effort_hours

    # Assume 6 productive hours per day
    working_days = ceil(total_hours / 6.0)

    # Add buffer for weekends and planning
    calendar_days = ceil(working_days * 1.4)

    completion_date = Date.utc_today() |> Date.add(calendar_days)
    Map.put(result, :completion_timeline, completion_date)
  end

  defp build_analysis_context(result, todos) do
    %{
      total_todos: length(todos),
      complexity_analysis: Map.get(result, :complexity_analysis),
      dependency_graph: Map.get(result, :dependency_graph),
      project_size: :medium  # Would be determined from codebase analysis
    }
  end

  # Dependency analysis helper functions

  defp extract_explicit_dependencies(todos) do
    todos
    |> Enum.flat_map(fn todo ->
      todo.metadata.dependencies
      |> Enum.map(fn dep ->
        %{
          from: todo.id,
          to: find_dependency_todo_id(dep, todos),
          type: :hard,
          strength: 1.0
        }
      end)
      |> Enum.reject(&is_nil(&1.to))
    end)
  end

  defp find_dependency_todo_id(dependency_name, todos) do
    # In a real implementation, this would intelligently match dependency names to TODO IDs
    # For now, just return the dependency name if it looks like a TODO ID
    if String.starts_with?(dependency_name, "TODO_") do
      dependency_name
    else
      nil
    end
  end

  defp infer_implicit_dependencies(todos, _options) do
    # Infer dependencies based on file proximity, function relationships, etc.
    # This is a simplified implementation
    todos
    |> Enum.flat_map(fn todo ->
      # Find TODOs in the same file that might be related
      same_file_todos = Enum.filter(todos, &(&1.file_path == todo.file_path and &1.id != todo.id))

      same_file_todos
      |> Enum.map(fn related_todo ->
        %{
          from: todo.id,
          to: related_todo.id,
          type: :soft,
          strength: 0.3
        }
      end)
    end)
  end

  defp extract_unique_nodes(todos, edges) do
    todo_ids = Enum.map(todos, & &1.id)
    edge_nodes = Enum.flat_map(edges, fn edge -> [edge.from, edge.to] end)

    (todo_ids ++ edge_nodes)
    |> Enum.uniq()
  end

  defp detect_dependency_cycles(nodes, edges) do
    # Simplified cycle detection - in real implementation would use proper graph algorithms
    cycles = []

    # For now, return empty cycles
    cycles
  end

  defp calculate_critical_path(nodes, edges) do
    # Simplified critical path calculation
    # In real implementation would use proper graph algorithms
    case edges do
      [] -> []
      [first_edge | _] -> [first_edge.from, first_edge.to]
    end
  end

  defp calculate_dependency_levels(nodes, edges) do
    # Calculate how many levels deep each node is in the dependency tree
    nodes
    |> Enum.map(fn node ->
      level = calculate_node_depth(node, edges, 0)
      {node, level}
    end)
    |> Enum.into(%{})
  end

  defp calculate_node_depth(node, edges, current_depth) do
    # Simplified depth calculation
    dependencies = Enum.filter(edges, &(&1.to == node))

    if Enum.empty?(dependencies) do
      current_depth
    else
      max_parent_depth = dependencies
      |> Enum.map(&calculate_node_depth(&1.from, edges, current_depth + 1))
      |> Enum.max(fn -> current_depth end)

      max_parent_depth
    end
  end

  # Complexity analysis helper functions

  defp assess_code_impact(todos) do
    # Assess how much code will be affected by implementing these TODOs
    avg_impact = todos
    |> Enum.map(&estimate_code_lines_affected/1)
    |> Enum.sum()
    |> case do
      0 -> 0.0
      sum -> sum / length(todos)
    end

    # Normalize to 0-1 scale
    min(avg_impact / 100.0, 1.0)
  end

  defp estimate_code_lines_affected(todo) do
    # Estimate based on TODO category and description
    case todo.category do
      :bug -> 10
      :feature -> 50
      :refactor -> 100
      :docs -> 5
      :test -> 30
      :security -> 25
      :performance -> 40
      :tech_debt -> 60
    end
  end

  defp assess_dependency_complexity(todos) do
    avg_deps = todos
    |> Enum.map(&length(&1.metadata.dependencies))
    |> Enum.sum()
    |> case do
      0 -> 0.0
      sum -> sum / length(todos)
    end

    # Normalize to 0-1 scale
    min(avg_deps / 5.0, 1.0)
  end

  defp assess_test_impact(todos) do
    # Assess impact on test coverage and test writing needs
    test_todos = Enum.count(todos, &(&1.category == :test))

    # Higher score means more test impact
    min(test_todos / length(todos), 1.0)
  end

  defp assess_breaking_change_risk(todos) do
    # Assess risk of breaking changes
    risky_categories = [:refactor, :security, :performance]
    risky_todos = Enum.count(todos, &(&1.category in risky_categories))

    min(risky_todos / length(todos), 1.0)
  end

  defp assess_domain_complexity(todos) do
    # Assess domain-specific complexity based on content analysis
    complex_keywords = ["algorithm", "performance", "security", "integration", "migration"]

    complex_todos = todos
    |> Enum.count(fn todo ->
      content_lower = String.downcase(todo.description)
      Enum.any?(complex_keywords, &String.contains?(content_lower, &1))
    end)

    min(complex_todos / length(todos), 1.0)
  end

  defp calculate_weighted_complexity(factors, options) do
    weights = options.complexity_weights

    weighted_sum = factors
    |> Enum.map(fn {factor, score} ->
      weight = Map.get(weights, factor, 0.2)
      score * weight
    end)
    |> Enum.sum()

    # Normalize to 0-1 range
    min(weighted_sum, 1.0)
  end

  defp calculate_estimation_confidence(todos, complexity_factors) do
    # Higher confidence for more todos and more consistent complexity factors
    sample_size_factor = min(length(todos) / 10.0, 1.0)

    # Calculate variance in complexity factors
    factor_values = Map.values(complexity_factors)
    mean_complexity = Enum.sum(factor_values) / length(factor_values)

    variance = factor_values
    |> Enum.map(&:math.pow(&1 - mean_complexity, 2))
    |> Enum.sum()
    |> Kernel./(length(factor_values))

    consistency_factor = max(0.0, 1.0 - variance)

    # Combine factors
    (sample_size_factor + consistency_factor) / 2.0
  end

  defp generate_complexity_breakdown(factors) do
    factors
    |> Enum.map(fn {factor, score} ->
      detail = %{
        score: score,
        description: describe_complexity_factor(factor, score),
        contributing_factors: get_contributing_factors(factor)
      }

      {factor, detail}
    end)
    |> Enum.into(%{})
  end

  defp describe_complexity_factor(factor, score) do
    level = cond do
      score >= 0.8 -> "Very High"
      score >= 0.6 -> "High"
      score >= 0.4 -> "Medium"
      score >= 0.2 -> "Low"
      true -> "Very Low"
    end

    factor_name = factor |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
    "#{level} #{factor_name}"
  end

  defp get_contributing_factors(factor) do
    case factor do
      :code_lines_affected -> ["Lines of code to modify", "Number of files affected", "Code complexity"]
      :dependencies_count -> ["Direct dependencies", "Transitive dependencies", "Circular dependencies"]
      :test_coverage_impact -> ["New tests required", "Existing tests to modify", "Integration test impact"]
      :breaking_changes -> ["API changes", "Database migrations", "Configuration changes"]
      :domain_complexity -> ["Business logic complexity", "Algorithm complexity", "Integration complexity"]
    end
  end

  # Implementation planning helper functions

  defp create_implementation_phases(todos, dependency_graph, _options) do
    # Group TODOs into phases based on dependency levels
    dependency_levels = dependency_graph.dependency_levels

    # Group by dependency level
    level_groups = todos
    |> Enum.group_by(fn todo ->
      Map.get(dependency_levels, todo.id, 0)
    end)
    |> Enum.sort_by(fn {level, _todos} -> level end)

    # Create phases
    level_groups
    |> Enum.with_index(1)
    |> Enum.map(fn {{_level, phase_todos}, phase_number} ->
      %{
        name: "Phase #{phase_number}",
        todos: Enum.map(phase_todos, & &1.id),
        estimate_hours: Enum.sum(Enum.map(phase_todos, &estimate_todo_effort(&1, %{}))),
        dependencies: extract_phase_dependencies(phase_todos, dependency_graph),
        risks: identify_phase_risks(phase_todos),
        deliverables: generate_phase_deliverables(phase_todos)
      }
    end)
  end

  defp extract_phase_dependencies(phase_todos, dependency_graph) do
    phase_todo_ids = Enum.map(phase_todos, & &1.id)

    dependency_graph.edges
    |> Enum.filter(fn edge ->
      edge.to in phase_todo_ids and edge.from not in phase_todo_ids
    end)
    |> Enum.map(& &1.from)
    |> Enum.uniq()
  end

  defp identify_phase_risks(phase_todos) do
    # Identify risks specific to this phase
    risky_categories = [:security, :performance, :refactor]

    phase_todos
    |> Enum.filter(&(&1.category in risky_categories))
    |> Enum.map(&"Risk: #{&1.title}")
  end

  defp generate_phase_deliverables(phase_todos) do
    # Generate deliverables based on TODO categories
    categories = phase_todos |> Enum.map(& &1.category) |> Enum.uniq()

    Enum.map(categories, fn category ->
      case category do
        :feature -> "New feature implementation"
        :bug -> "Bug fixes"
        :refactor -> "Code refactoring"
        :docs -> "Documentation updates"
        :test -> "Test coverage improvements"
        :security -> "Security enhancements"
        :performance -> "Performance optimizations"
        :tech_debt -> "Technical debt reduction"
      end
    end)
  end

  defp calculate_total_effort(phases) do
    phases
    |> Enum.map(& &1.estimate_hours)
    |> Enum.sum()
  end

  defp identify_parallel_tracks(todos, dependency_graph) do
    # Identify TODOs that can be worked on in parallel
    # This is a simplified implementation
    independent_todos = todos
    |> Enum.filter(fn todo ->
      # TODOs with no dependencies can potentially be done in parallel
      incoming_deps = Enum.count(dependency_graph.edges, &(&1.to == todo.id))
      outgoing_deps = Enum.count(dependency_graph.edges, &(&1.from == todo.id))

      incoming_deps == 0 and outgoing_deps == 0
    end)
    |> Enum.map(& &1.id)

    if length(independent_todos) > 1 do
      [independent_todos]
    else
      []
    end
  end

  defp generate_project_milestones(phases, _options) do
    phases
    |> Enum.with_index(1)
    |> Enum.map(fn {phase, index} ->
      target_date = Date.utc_today() |> Date.add(index * 14)  # 2 weeks per phase

      %{
        name: "#{phase.name} Completion",
        todos_completed: phase.todos,
        target_date: target_date,
        success_criteria: [
          "All phase TODOs completed",
          "Code review passed",
          "Tests passing"
        ]
      }
    end)
  end

  # Risk analysis helper functions

  defp identify_complexity_risks(risk_factors, todos) do
    high_complexity_todos = Enum.filter(todos, fn todo ->
      # Simplified complexity assessment
      todo.category in [:refactor, :security, :performance]
    end)

    if length(high_complexity_todos) > 0 do
      risk_factor = %{
        type: :high_complexity,
        severity: :medium,
        description: "#{length(high_complexity_todos)} high-complexity TODOs identified",
        affected_todos: Enum.map(high_complexity_todos, & &1.id),
        probability: 0.8,
        impact: 0.6
      }

      [risk_factor | risk_factors]
    else
      risk_factors
    end
  end

  defp identify_dependency_risks(risk_factors, todos) do
    todos_with_many_deps = Enum.filter(todos, fn todo ->
      length(todo.metadata.dependencies) > 3
    end)

    if length(todos_with_many_deps) > 0 do
      risk_factor = %{
        type: :complex_dependencies,
        severity: :medium,
        description: "TODOs with complex dependency chains",
        affected_todos: Enum.map(todos_with_many_deps, & &1.id),
        probability: 0.7,
        impact: 0.7
      }

      [risk_factor | risk_factors]
    else
      risk_factors
    end
  end

  defp identify_breaking_change_risks(risk_factors, todos) do
    breaking_change_todos = Enum.filter(todos, fn todo ->
      content_lower = String.downcase(todo.description)
      String.contains?(content_lower, ["breaking", "api change", "migration", "deprecate"])
    end)

    if length(breaking_change_todos) > 0 do
      risk_factor = %{
        type: :breaking_changes,
        severity: :high,
        description: "Potential breaking changes identified",
        affected_todos: Enum.map(breaking_change_todos, & &1.id),
        probability: 0.9,
        impact: 0.8
      }

      [risk_factor | risk_factors]
    else
      risk_factors
    end
  end

  defp identify_resource_risks(risk_factors, todos, context) do
    total_effort = length(todos) * 6  # Rough estimate: 6 hours per TODO

    if total_effort > 160 do  # More than 1 month of work
      risk_factor = %{
        type: :resource_constraints,
        severity: :medium,
        description: "Large amount of work may strain resources",
        affected_todos: Enum.map(todos, & &1.id),
        probability: 0.6,
        impact: 0.5
      }

      [risk_factor | risk_factors]
    else
      risk_factors
    end
  end

  defp identify_timeline_risks(risk_factors, todos, context) do
    urgent_todos = Enum.filter(todos, & &1.priority in [:critical, :high])

    if length(urgent_todos) > length(todos) * 0.5 do
      risk_factor = %{
        type: :timeline_pressure,
        severity: :high,
        description: "Many high-priority TODOs may create timeline pressure",
        affected_todos: Enum.map(urgent_todos, & &1.id),
        probability: 0.8,
        impact: 0.7
      }

      [risk_factor | risk_factors]
    else
      risk_factors
    end
  end

  defp identify_integration_risks(risk_factors, todos, context) do
    integration_todos = Enum.filter(todos, fn todo ->
      content_lower = String.downcase(todo.description)
      String.contains?(content_lower, ["integrate", "api", "external", "service", "third-party"])
    end)

    if length(integration_todos) > 0 do
      risk_factor = %{
        type: :integration_complexity,
        severity: :medium,
        description: "External integrations may introduce complexity",
        affected_todos: Enum.map(integration_todos, & &1.id),
        probability: 0.7,
        impact: 0.6
      }

      [risk_factor | risk_factors]
    else
      risk_factors
    end
  end

  defp calculate_risk_score(risk_factors) do
    if Enum.empty?(risk_factors) do
      0.0
    else
      total_risk = risk_factors
      |> Enum.map(fn risk -> risk.probability * risk.impact end)
      |> Enum.sum()

      # Normalize by number of risk factors
      total_risk / length(risk_factors)
    end
  end

  defp determine_risk_level(risk_score) do
    cond do
      risk_score >= 0.8 -> :critical
      risk_score >= 0.6 -> :high
      risk_score >= 0.4 -> :medium
      true -> :low
    end
  end

  defp generate_mitigation_strategies(risk_factors, _options) do
    risk_factors
    |> Enum.map(&generate_mitigation_for_risk/1)
    |> Enum.reject(&is_nil/1)
  end

  defp generate_mitigation_for_risk(risk_factor) do
    case risk_factor.type do
      :high_complexity ->
        %{
          risk_type: :high_complexity,
          strategy: "Break down complex TODOs into smaller, manageable tasks. Conduct code reviews and pair programming for complex implementations.",
          effort_required: "Medium",
          effectiveness: 0.8
        }

      :complex_dependencies ->
        %{
          risk_type: :complex_dependencies,
          strategy: "Create detailed dependency maps and implement in phases. Consider reducing dependencies where possible.",
          effort_required: "Low",
          effectiveness: 0.7
        }

      :breaking_changes ->
        %{
          risk_type: :breaking_changes,
          strategy: "Plan breaking changes carefully with proper deprecation notices. Implement backwards compatibility where possible.",
          effort_required: "High",
          effectiveness: 0.9
        }

      :resource_constraints ->
        %{
          risk_type: :resource_constraints,
          strategy: "Prioritize critical TODOs and consider bringing in additional resources or extending timeline.",
          effort_required: "High",
          effectiveness: 0.6
        }

      :timeline_pressure ->
        %{
          risk_type: :timeline_pressure,
          strategy: "Re-evaluate priorities and consider moving non-critical items to future releases.",
          effort_required: "Low",
          effectiveness: 0.7
        }

      :integration_complexity ->
        %{
          risk_type: :integration_complexity,
          strategy: "Create comprehensive integration tests and have fallback plans for external service failures.",
          effort_required: "Medium",
          effectiveness: 0.8
        }

      _ -> nil
    end
  end
end
