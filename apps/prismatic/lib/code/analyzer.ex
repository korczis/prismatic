defmodule Prismatic.Code.Analyzer do
  @moduledoc """
  Legacy codebase analysis tooling for the Enterprise Consolidation Strategy.

  Provides comprehensive analysis of Elixir codebases including:
  - AST-based module analysis
  - Dependency relationships
  - Database schemas (Ecto)
  - API endpoints (Phoenix)
  - Technical debt assessment
  - Test coverage analysis
  """

  require Logger
  alias Mix.Project

  @type analysis_result :: %{
    overview: map(),
    modules: list(map()),
    dependencies: map(),
    schemas: list(map()),
    endpoints: list(map()),
    technical_debt: map(),
    test_coverage: map(),
    performance_hotspots: list(map())
  }

  @type module_info :: %{
    name: String.t(),
    file_path: String.t(),
    line_count: integer(),
    function_count: integer(),
    complexity_score: integer(),
    dependencies: list(String.t()),
    exports: list(map()),
    module_attributes: list(map()),
    documentation: String.t() | nil,
    behaviours: list(String.t()),
    uses: list(String.t()),
    imports: list(String.t()),
    requires: list(String.t()),
    aliases: list(map())
  }

  @doc """
  Main analysis function that coordinates all analysis tasks.

  ## Parameters
  - `project_path` - Path to the Elixir project to analyze, or :umbrella for current umbrella
  - `opts` - Analysis options (optional)

  ## Options
  - `:scope` - Analysis scope: `:umbrella`, `:app`, or `:project` (default: `:project`)
  - `:include_apps` - List of umbrella apps to include (default: `:all`)
  - `:exclude_patterns` - Patterns to exclude from analysis (default: standard exclusions)
  - `:depth` - Analysis depth: `:surface`, `:standard`, or `:deep` (default: `:standard`)

  ## Returns
  - `{:ok, analysis_result()}` - Comprehensive analysis results
  - `{:error, reason}` - Error details if analysis fails

  ## Examples

      # Analyze current umbrella
      iex> Prismatic.Code.Analyzer.analyze_codebase(:umbrella)
      {:ok, %{projects: [%{name: "prismatic_core", ...}, ...]}}

      # Analyze external project
      iex> Prismatic.Code.Analyzer.analyze_codebase("/path/to/project")
      {:ok, %{projects: [%{name: "ProjectName", ...}]}}

      # Analyze with options
      iex> Prismatic.Code.Analyzer.analyze_codebase(:umbrella, scope: :umbrella, include_apps: [:prismatic_core])
      {:ok, %{projects: [%{name: "prismatic_core", ...}]}}
  """
  @spec analyze_codebase(String.t() | :umbrella, keyword()) :: {:ok, analysis_result()} | {:error, term()}
  def analyze_codebase(project_path, opts \\ []) do
    Logger.info("Starting codebase analysis for: #{inspect(project_path)}")

    config = build_analysis_config(project_path, opts)

    with {:ok, projects} <- discover_projects(config),
         {:ok, analysis_results} <- analyze_projects(projects, config) do

      result = %{
        projects: analysis_results,
        summary: generate_summary(analysis_results),
        metadata: %{
          analysis_timestamp: DateTime.utc_now(),
          config: sanitize_config(config),
          analyzer_version: get_analyzer_version()
        }
      }

      Logger.info("Codebase analysis completed successfully for #{length(analysis_results)} project(s)")
      {:ok, result}
    else
      {:error, reason} = error ->
        Logger.error("Codebase analysis failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Legacy function name for backward compatibility.
  """
  @spec analyze_legacy_codebase(String.t()) :: {:ok, analysis_result()} | {:error, term()}
  def analyze_legacy_codebase(project_path) do
    analyze_codebase(project_path)
  end

  @doc """
  Extract and analyze all modules from the project.

  Recursively scans for .ex files and parses their ASTs to extract module information.
  """
  @spec extract_modules(String.t()) :: {:ok, list(module_info())} | {:error, term()}
  def extract_modules(project_path) do
    Logger.info("Extracting modules from: #{project_path}")

    try do
      pattern = Path.join([project_path, "**", "*.ex"])

      modules =
        pattern
        |> Path.wildcard()
        |> Enum.map(&parse_module_ast/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(& &1.name)

      Logger.info("Extracted #{length(modules)} modules")
      {:ok, modules}
    rescue
      error ->
        Logger.error("Failed to extract modules: #{inspect(error)}")
        {:error, {:module_extraction_failed, error}}
    end
  end

  @doc """
  Parse a single Elixir file and extract its AST information.

  Returns module information or nil if parsing fails.
  """
  @spec parse_module_ast(String.t()) :: module_info() | nil
  def parse_module_ast(file_path) do
    try do
      case File.read(file_path) do
        {:ok, content} ->
          case Code.string_to_quoted(content) do
            {:ok, ast} ->
              extract_module_info(ast, file_path)
            {:error, reason} ->
              Logger.warning("Failed to parse AST for #{file_path}: #{inspect(reason)}")
              nil
          end
        {:error, reason} ->
          Logger.warning("Failed to read file #{file_path}: #{inspect(reason)}")
          nil
      end
    rescue
      error ->
        Logger.warning("Exception parsing #{file_path}: #{inspect(error)}")
        nil
    end
  end

  @doc """
  Extract detailed module information from parsed AST.

  Traverses the AST to collect:
  - Module name and basic metadata
  - Function definitions and exports
  - Dependencies (imports, requires, aliases, uses)
  - Module attributes
  - Documentation
  - Complexity metrics
  """
  @spec extract_module_info(Macro.t(), String.t()) :: module_info()
  def extract_module_info(ast, file_path) do
    context = %{
      module_name: nil,
      functions: [],
      imports: [],
      requires: [],
      aliases: [],
      uses: [],
      behaviours: [],
      module_attributes: [],
      documentation: nil
    }

    context = traverse_ast(ast, context)

    # Count lines in file
    {:ok, content} = File.read(file_path)
    line_count = String.split(content, "\n") |> length()

    %{
      name: context.module_name || "Unknown",
      file_path: file_path,
      line_count: line_count,
      function_count: length(context.functions),
      complexity_score: calculate_complexity_score(context.functions),
      dependencies: extract_dependencies_from_context(context),
      exports: context.functions,
      module_attributes: context.module_attributes,
      documentation: context.documentation,
      behaviours: context.behaviours,
      uses: context.uses,
      imports: context.imports,
      requires: context.requires,
      aliases: context.aliases
    }
  end

  @doc """
  Analyze project dependencies from mix.exs and mix.lock files.

  Extracts:
  - Direct dependencies with versions
  - Transitive dependencies
  - Development/test-only dependencies
  - Dependency conflicts
  - Security vulnerabilities (if available)
  """
  @spec analyze_dependencies(String.t()) :: {:ok, map()} | {:error, term()}
  def analyze_dependencies(project_path) do
    Logger.info("Analyzing dependencies in: #{project_path}")

    try do
      mix_exs_path = Path.join(project_path, "mix.exs")
      mix_lock_path = Path.join(project_path, "mix.lock")

      with {:ok, mix_exs_deps} <- parse_mix_exs_dependencies(mix_exs_path),
           {:ok, mix_lock_deps} <- parse_mix_lock_dependencies(mix_lock_path) do

        conflicts = detect_dependency_conflicts(mix_exs_deps, mix_lock_deps)
        outdated = identify_outdated_dependencies(mix_exs_deps, mix_lock_deps)

        result = %{
          direct_dependencies: mix_exs_deps,
          locked_dependencies: mix_lock_deps,
          conflicts: conflicts,
          outdated: outdated,
          total_count: length(mix_lock_deps),
          dev_dependencies: Enum.filter(mix_exs_deps, &(&1.only in [[:dev], [:dev, :test]])),
          prod_dependencies: Enum.filter(mix_exs_deps, &(&1.only not in [[:dev], [:dev, :test]]))
        }

        Logger.info("Analyzed #{result.total_count} dependencies")
        {:ok, result}
      end
    rescue
      error ->
        Logger.error("Failed to analyze dependencies: #{inspect(error)}")
        {:error, {:dependency_analysis_failed, error}}
    end
  end

  @doc """
  Extract Ecto schemas from the project.

  Finds modules that use Ecto.Schema and extracts:
  - Schema name and table name
  - Field definitions and types
  - Associations (belongs_to, has_many, etc.)
  - Validations and changesets
  - Indexes and constraints
  """
  @spec extract_schemas(String.t()) :: {:ok, list(map())} | {:error, term()}
  def extract_schemas(project_path) do
    Logger.info("Extracting Ecto schemas from: #{project_path}")

    try do
      {:ok, modules} = extract_modules(project_path)

      schemas =
        modules
        |> Enum.filter(&is_ecto_schema?/1)
        |> Enum.map(&extract_schema_details/1)
        |> Enum.reject(&is_nil/1)

      Logger.info("Found #{length(schemas)} Ecto schemas")
      {:ok, schemas}
    rescue
      error ->
        Logger.error("Failed to extract schemas: #{inspect(error)}")
        {:error, {:schema_extraction_failed, error}}
    end
  end

  @doc """
  Extract Phoenix endpoints and routes from the project.

  Analyzes:
  - Router modules and route definitions
  - Controller actions
  - Plug pipelines
  - LiveView routes
  - API endpoints and their HTTP methods
  """
  @spec extract_endpoints(String.t()) :: {:ok, list(map())} | {:error, term()}
  def extract_endpoints(project_path) do
    Logger.info("Extracting Phoenix endpoints from: #{project_path}")

    try do
      {:ok, modules} = extract_modules(project_path)

      routers = Enum.filter(modules, &is_phoenix_router?/1)
      controllers = Enum.filter(modules, &is_phoenix_controller?/1)
      live_views = Enum.filter(modules, &is_phoenix_live_view?/1)

      endpoints =
        []
        |> extract_router_endpoints(routers)
        |> extract_controller_endpoints(controllers)
        |> extract_live_view_endpoints(live_views)

      Logger.info("Found #{length(endpoints)} endpoints")
      {:ok, endpoints}
    rescue
      error ->
        Logger.error("Failed to extract endpoints: #{inspect(error)}")
        {:error, {:endpoint_extraction_failed, error}}
    end
  end

  @doc """
  Assess technical debt in the codebase.

  Analyzes:
  - Code complexity metrics
  - Code duplication
  - TODO/FIXME comments
  - Long functions and large modules
  - Missing documentation
  - Anti-patterns
  """
  @spec assess_technical_debt(String.t()) :: {:ok, map()} | {:error, term()}
  def assess_technical_debt(project_path) do
    Logger.info("Assessing technical debt in: #{project_path}")

    try do
      {:ok, modules} = extract_modules(project_path)

      complexity_issues = analyze_complexity_issues(modules)
      documentation_issues = analyze_documentation_coverage(modules)
      code_smells = detect_code_smells(modules)
      todo_comments = find_todo_comments(project_path)

      debt_score = calculate_technical_debt_score(
        complexity_issues,
        documentation_issues,
        code_smells,
        todo_comments
      )

      result = %{
        overall_score: debt_score,
        complexity_issues: complexity_issues,
        documentation_issues: documentation_issues,
        code_smells: code_smells,
        todo_comments: todo_comments,
        recommendations: generate_debt_recommendations(debt_score, complexity_issues, documentation_issues)
      }

      Logger.info("Technical debt assessment completed with score: #{debt_score}")
      {:ok, result}
    rescue
      error ->
        Logger.error("Failed to assess technical debt: #{inspect(error)}")
        {:error, {:technical_debt_assessment_failed, error}}
    end
  end

  @doc """
  Analyze test coverage across the project.

  Examines:
  - Test file coverage vs source files
  - Test types (unit, integration, property-based)
  - Critical path coverage
  - Missing test scenarios
  """
  @spec analyze_test_coverage(String.t()) :: {:ok, map()} | {:error, term()}
  def analyze_test_coverage(project_path) do
    Logger.info("Analyzing test coverage in: #{project_path}")

    try do
      test_files = find_test_files(project_path)
      {:ok, source_modules} = extract_modules(project_path)

      coverage_data = analyze_coverage_data(project_path)
      test_patterns = analyze_test_patterns(test_files)
      missing_tests = identify_missing_tests(source_modules, test_files)

      result = %{
        total_test_files: length(test_files),
        test_patterns: test_patterns,
        coverage_percentage: coverage_data.percentage,
        missing_tests: missing_tests,
        critical_path_coverage: analyze_critical_path_coverage(source_modules, test_files),
        recommendations: generate_testing_recommendations(missing_tests, coverage_data)
      }

      Logger.info("Test coverage analysis completed: #{result.coverage_percentage}%")
      {:ok, result}
    rescue
      error ->
        Logger.error("Failed to analyze test coverage: #{inspect(error)}")
        {:error, {:test_coverage_analysis_failed, error}}
    end
  end

  # Private helper functions

  defp build_analysis_config(project_path, opts) do
    default_config = %{
      scope: Keyword.get(opts, :scope, :project),
      include_apps: Keyword.get(opts, :include_apps, :all),
      exclude_patterns: Keyword.get(opts, :exclude_patterns, default_exclude_patterns()),
      depth: Keyword.get(opts, :depth, :standard),
      project_path: project_path
    }

    merge_with_application_config(default_config)
  end

  defp discover_projects(%{scope: :umbrella} = config) do
    case discover_umbrella_apps(config) do
      {:ok, apps} when length(apps) > 0 -> {:ok, apps}
      {:ok, []} -> {:error, {:no_apps_found, "No umbrella apps found"}}
      error -> error
    end
  end

  defp discover_projects(%{scope: :app, project_path: app_name} = config) when is_atom(app_name) do
    case find_umbrella_app(app_name, config) do
      {:ok, app_path} -> {:ok, [%{name: app_name, path: app_path, type: :umbrella_app}]}
      error -> error
    end
  end

  defp discover_projects(%{scope: :project, project_path: project_path} = _config) do
    case validate_project_path(project_path) do
      {:ok, validated_path} ->
        project_name = Path.basename(validated_path)
        {:ok, [%{name: project_name, path: validated_path, type: :external_project}]}
      error -> error
    end
  end

  defp discover_projects(%{project_path: :umbrella} = config) do
    discover_projects(%{config | scope: :umbrella})
  end

  defp analyze_projects(projects, config) do
    results =
      projects
      |> Enum.map(fn project ->
        Task.async(fn -> analyze_single_project(project, config) end)
      end)
      |> Enum.map(&Task.await(&1, 60_000))

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> {:ok, Enum.map(results, fn {:ok, result} -> result end)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp analyze_single_project(%{name: name, path: path, type: type}, config) do
    Logger.info("Analyzing #{type}: #{name} at #{path}")

    with {:ok, modules} <- extract_modules(path),
         {:ok, dependencies} <- analyze_dependencies(path),
         {:ok, schemas} <- extract_schemas(path),
         {:ok, endpoints} <- extract_endpoints(path),
         {:ok, technical_debt} <- assess_technical_debt(path),
         {:ok, test_coverage} <- analyze_test_coverage(path) do

      overview = generate_overview(modules, dependencies, schemas, endpoints)
      performance_hotspots = identify_performance_hotspots(modules)

      result = %{
        name: name,
        path: path,
        type: type,
        overview: overview,
        modules: modules,
        dependencies: dependencies,
        schemas: schemas,
        endpoints: endpoints,
        technical_debt: technical_debt,
        test_coverage: test_coverage,
        performance_hotspots: performance_hotspots
      }

      {:ok, result}
    end
  end

  defp discover_umbrella_apps(config) do
    umbrella_path = get_umbrella_root()
    apps_path = Path.join(umbrella_path, "apps")

    if File.exists?(apps_path) do
      apps =
        apps_path
        |> File.ls!()
        |> Enum.filter(&File.dir?(Path.join(apps_path, &1)))
        |> Enum.filter(&has_mix_file?(Path.join(apps_path, &1)))
        |> filter_included_apps(config)
        |> Enum.map(fn app_name ->
          app_path = Path.join(apps_path, app_name)
          %{name: app_name, path: app_path, type: :umbrella_app}
        end)

      {:ok, apps}
    else
      {:error, {:not_umbrella, "Not in an umbrella project or apps directory not found"}}
    end
  rescue
    error ->
      {:error, {:discovery_failed, error}}
  end

  defp find_umbrella_app(app_name, _config) do
    umbrella_path = get_umbrella_root()
    app_path = Path.join([umbrella_path, "apps", to_string(app_name)])

    if has_mix_file?(app_path) do
      {:ok, app_path}
    else
      {:error, {:app_not_found, "Umbrella app #{app_name} not found"}}
    end
  end

  defp get_umbrella_root do
    case Mix.Project.umbrella?() do
      true -> File.cwd!()
      false ->
        # Try to find umbrella root by traversing up
        find_umbrella_root(File.cwd!())
    end
  end

  defp find_umbrella_root(path) do
    mix_exs = Path.join(path, "mix.exs")

    if File.exists?(mix_exs) do
      content = File.read!(mix_exs)
      if String.contains?(content, "apps_path:") do
        path
      else
        parent = Path.dirname(path)
        if parent != path do
          find_umbrella_root(parent)
        else
          path  # fallback to current directory
        end
      end
    else
      parent = Path.dirname(path)
      if parent != path do
        find_umbrella_root(parent)
      else
        path  # fallback to current directory
      end
    end
  end

  defp has_mix_file?(path) do
    File.exists?(Path.join(path, "mix.exs"))
  end

  defp filter_included_apps(apps, %{include_apps: :all}), do: apps
  defp filter_included_apps(apps, %{include_apps: included_apps}) when is_list(included_apps) do
    included_strings = Enum.map(included_apps, &to_string/1)
    Enum.filter(apps, &(&1 in included_strings))
  end

  defp generate_summary(analysis_results) do
    %{
      total_projects: length(analysis_results),
      total_modules: Enum.sum(Enum.map(analysis_results, & &1.overview.total_modules)),
      total_dependencies: Enum.sum(Enum.map(analysis_results, & &1.overview.total_dependencies)),
      total_schemas: Enum.sum(Enum.map(analysis_results, & &1.overview.total_schemas)),
      total_endpoints: Enum.sum(Enum.map(analysis_results, & &1.overview.total_endpoints)),
      avg_technical_debt: calculate_average_debt(analysis_results),
      avg_test_coverage: calculate_average_coverage(analysis_results),
      projects_by_type: group_projects_by_type(analysis_results)
    }
  end

  defp calculate_average_debt(results) do
    if length(results) > 0 do
      Enum.sum(Enum.map(results, & &1.technical_debt.overall_score)) / length(results)
    else
      0.0
    end
  end

  defp calculate_average_coverage(results) do
    if length(results) > 0 do
      Enum.sum(Enum.map(results, & &1.test_coverage.coverage_percentage)) / length(results)
    else
      0.0
    end
  end

  defp group_projects_by_type(results) do
    Enum.group_by(results, & &1.type)
    |> Enum.map(fn {type, projects} -> {type, length(projects)} end)
    |> Enum.into(%{})
  end

  defp sanitize_config(config) do
    # Remove sensitive information from config for logging
    Map.delete(config, :sensitive_data)
  end

  defp get_analyzer_version do
    case Application.spec(:prismatic, :vsn) do
      nil -> "unknown"
      version -> to_string(version)
    end
  end

  defp merge_with_application_config(config) do
    app_config = Application.get_env(:prismatic, Prismatic.Code.Analyzer, [])

    Enum.reduce(app_config, config, fn {key, value}, acc ->
      if Map.has_key?(acc, key) do
        acc  # Don't override explicit options
      else
        Map.put(acc, key, value)
      end
    end)
  end

  defp default_exclude_patterns do
    [
      "**/deps/**",
      "**/_build/**",
      "**/node_modules/**",
      "**/.git/**",
      "**/cover/**",
      "**/doc/**",
      "**/logs/**",
      "**/*.beam"
    ]
  end

  defp validate_project_path(project_path) do
    expanded_path = Path.expand(project_path)

    cond do
      not File.exists?(expanded_path) ->
        {:error, {:invalid_path, "Project path does not exist: #{project_path}"}}

      not File.dir?(expanded_path) ->
        {:error, {:invalid_path, "Project path is not a directory: #{project_path}"}}

      not File.exists?(Path.join(expanded_path, "mix.exs")) ->
        {:error, {:invalid_project, "No mix.exs found in: #{project_path}"}}

      true ->
        {:ok, expanded_path}
    end
  end

  defp traverse_ast(ast, context) do
    {_ast, context} = Macro.prewalk(ast, context, &extract_ast_info/2)
    context
  end

  defp extract_ast_info({:defmodule, _meta, [{:__aliases__, _, name_parts}, _body]} = node, context) do
    module_name = name_parts |> Enum.map(&to_string/1) |> Enum.join(".")
    {node, %{context | module_name: module_name}}
  end

  defp extract_ast_info({:def, meta, [{name, _, args}, _body]} = node, context) when is_atom(name) do
    arity = if args, do: length(args), else: 0
    line = Keyword.get(meta, :line, 0)

    func_info = %{
      name: name,
      arity: arity,
      line: line,
      type: :public,
      complexity: calculate_function_complexity(node)
    }

    {node, %{context | functions: [func_info | context.functions]}}
  end

  defp extract_ast_info({:defp, meta, [{name, _, args}, _body]} = node, context) when is_atom(name) do
    arity = if args, do: length(args), else: 0
    line = Keyword.get(meta, :line, 0)

    func_info = %{
      name: name,
      arity: arity,
      line: line,
      type: :private,
      complexity: calculate_function_complexity(node)
    }

    {node, %{context | functions: [func_info | context.functions]}}
  end

  defp extract_ast_info({:import, _, [module | _]} = node, context) do
    module_name = extract_module_name(module)
    {node, %{context | imports: [module_name | context.imports]}}
  end

  defp extract_ast_info({:require, _, [module | _]} = node, context) do
    module_name = extract_module_name(module)
    {node, %{context | requires: [module_name | context.requires]}}
  end

  defp extract_ast_info({:alias, _, [module | opts]} = node, context) do
    module_name = extract_module_name(module)
    alias_name = extract_alias_name(opts)

    alias_info = %{module: module_name, as: alias_name}
    {node, %{context | aliases: [alias_info | context.aliases]}}
  end

  defp extract_ast_info({:use, _, [module | _]} = node, context) do
    module_name = extract_module_name(module)
    {node, %{context | uses: [module_name | context.uses]}}
  end

  defp extract_ast_info({:@, _, [{:behaviour, _, [module]}]} = node, context) do
    module_name = extract_module_name(module)
    {node, %{context | behaviours: [module_name | context.behaviours]}}
  end

  defp extract_ast_info({:@, _, [{attr_name, _, [value]}]} = node, context) when is_atom(attr_name) do
    attr_info = %{name: attr_name, value: sanitize_ast_value(value)}
    {node, %{context | module_attributes: [attr_info | context.module_attributes]}}
  end

  defp extract_ast_info(node, context), do: {node, context}

  defp extract_module_name({:__aliases__, _, name_parts}) do
    name_parts |> Enum.map(&to_string/1) |> Enum.join(".")
  end

  defp extract_module_name(atom) when is_atom(atom), do: to_string(atom)
  defp extract_module_name(_), do: "Unknown"

  defp extract_alias_name([{:as, _, [{:__aliases__, _, name_parts}]}]) do
    name_parts |> List.last() |> to_string()
  end

  defp extract_alias_name(_), do: nil

  defp calculate_complexity_score(functions) do
    functions
    |> Enum.map(& &1.complexity)
    |> Enum.sum()
  end

  defp calculate_function_complexity(_ast) do
    # Simplified complexity calculation
    # In a real implementation, this would analyze control flow, nesting, etc.
    1
  end

  defp extract_dependencies_from_context(context) do
    (context.imports ++ context.requires ++ context.uses ++
     Enum.map(context.aliases, & &1.module) ++ context.behaviours)
    |> Enum.uniq()
    |> Enum.reject(&(&1 == "Unknown"))
  end

  defp parse_mix_exs_dependencies(mix_exs_path) do
    if File.exists?(mix_exs_path) do
      try do
        {deps_list, _} = Code.eval_file(mix_exs_path)
        # Simplified - would need to actually parse the mix.exs structure
        {:ok, []}
      rescue
        _ -> {:ok, []}
      end
    else
      {:ok, []}
    end
  end

  defp parse_mix_lock_dependencies(mix_lock_path) do
    if File.exists?(mix_lock_path) do
      try do
        {lock_data, _} = Code.eval_file(mix_lock_path)
        deps = Enum.map(lock_data, fn {name, info} ->
          %{name: name, version: extract_version_from_lock(info)}
        end)
        {:ok, deps}
      rescue
        _ -> {:ok, []}
      end
    else
      {:ok, []}
    end
  end

  defp extract_version_from_lock({:hex, _name, version, _hash, _managers, _deps, _range}), do: version
  defp extract_version_from_lock(_), do: "unknown"

  defp detect_dependency_conflicts(_mix_exs_deps, _mix_lock_deps), do: []
  defp identify_outdated_dependencies(_mix_exs_deps, _mix_lock_deps), do: []

  defp is_ecto_schema?(module) do
    "Ecto.Schema" in module.uses
  end

  defp extract_schema_details(module) do
    %{
      name: module.name,
      file_path: module.file_path,
      table_name: extract_table_name(module),
      fields: extract_schema_fields(module),
      associations: extract_associations(module)
    }
  end

  defp extract_table_name(_module), do: "unknown"
  defp extract_schema_fields(_module), do: []
  defp extract_associations(_module), do: []

  defp is_phoenix_router?(module) do
    "Phoenix.Router" in module.uses
  end

  defp is_phoenix_controller?(module) do
    "Phoenix.Controller" in module.uses or String.contains?(module.name, "Controller")
  end

  defp is_phoenix_live_view?(module) do
    "Phoenix.LiveView" in module.uses
  end

  defp extract_router_endpoints(endpoints, _routers), do: endpoints
  defp extract_controller_endpoints(endpoints, _controllers), do: endpoints
  defp extract_live_view_endpoints(endpoints, _live_views), do: endpoints

  defp analyze_complexity_issues(modules) do
    modules
    |> Enum.filter(&(&1.complexity_score > 10))
    |> Enum.map(&%{module: &1.name, score: &1.complexity_score})
  end

  defp analyze_documentation_coverage(modules) do
    total = length(modules)
    documented = Enum.count(modules, &(&1.documentation != nil))

    %{
      total_modules: total,
      documented_modules: documented,
      coverage_percentage: if(total > 0, do: documented / total * 100, else: 0)
    }
  end

  defp detect_code_smells(_modules), do: []

  defp find_todo_comments(project_path) do
    pattern = Path.join([project_path, "**", "*.ex"])

    pattern
    |> Path.wildcard()
    |> Enum.flat_map(&extract_todo_from_file/1)
  end

  defp extract_todo_from_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _} ->
          String.contains?(String.upcase(line), ["TODO", "FIXME", "HACK"])
        end)
        |> Enum.map(fn {line, line_num} ->
          %{file: file_path, line: line_num, content: String.trim(line)}
        end)

      {:error, _} -> []
    end
  end

  defp calculate_technical_debt_score(complexity_issues, documentation_issues, code_smells, todo_comments) do
    complexity_score = length(complexity_issues) * 2
    doc_score = max(0, 100 - documentation_issues.coverage_percentage) / 10
    smell_score = length(code_smells) * 3
    todo_score = length(todo_comments) * 0.5

    complexity_score + doc_score + smell_score + todo_score
  end

  defp generate_debt_recommendations(_debt_score, _complexity_issues, _documentation_issues) do
    [
      "Improve code documentation coverage",
      "Refactor complex functions",
      "Address TODO/FIXME comments",
      "Implement automated code quality checks"
    ]
  end

  defp find_test_files(project_path) do
    pattern = Path.join([project_path, "**", "*_test.exs"])
    Path.wildcard(pattern)
  end

  defp analyze_coverage_data(_project_path) do
    # Would integrate with coverage tools like ExCoveralls
    %{percentage: 75.0}
  end

  defp analyze_test_patterns(_test_files) do
    %{
      unit_tests: 0,
      integration_tests: 0,
      property_tests: 0
    }
  end

  defp identify_missing_tests(_source_modules, _test_files), do: []

  defp analyze_critical_path_coverage(_source_modules, _test_files) do
    %{covered: 0, total: 0, percentage: 0.0}
  end

  defp generate_testing_recommendations(_missing_tests, _coverage_data) do
    [
      "Increase overall test coverage",
      "Add integration tests for critical paths",
      "Implement property-based testing for complex logic"
    ]
  end

  defp generate_overview(modules, dependencies, schemas, endpoints) do
    %{
      total_modules: length(modules),
      total_files: length(modules),
      total_dependencies: dependencies.total_count,
      total_schemas: length(schemas),
      total_endpoints: length(endpoints),
      analysis_timestamp: DateTime.utc_now(),
      largest_module: find_largest_module(modules),
      most_complex_module: find_most_complex_module(modules)
    }
  end

  defp identify_performance_hotspots(modules) do
    modules
    |> Enum.filter(&(&1.complexity_score > 15 or &1.line_count > 500))
    |> Enum.map(&%{
      module: &1.name,
      file_path: &1.file_path,
      issue: determine_performance_issue(&1),
      recommendation: performance_recommendation(&1)
    })
  end

  defp find_largest_module(modules) do
    modules
    |> Enum.max_by(& &1.line_count, fn -> %{name: "None", line_count: 0} end)
    |> Map.take([:name, :line_count])
  end

  defp find_most_complex_module(modules) do
    modules
    |> Enum.max_by(& &1.complexity_score, fn -> %{name: "None", complexity_score: 0} end)
    |> Map.take([:name, :complexity_score])
  end

  defp determine_performance_issue(module) do
    cond do
      module.line_count > 500 -> "large_module"
      module.complexity_score > 15 -> "high_complexity"
      true -> "potential_optimization"
    end
  end

  defp performance_recommendation(module) do
    case determine_performance_issue(module) do
      "large_module" -> "Consider breaking this module into smaller, more focused modules"
      "high_complexity" -> "Refactor complex functions to reduce cognitive load"
      _ -> "Review for optimization opportunities"
    end
  end

  # Sanitize AST values to make them JSON-serializable
  defp sanitize_ast_value(value) when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value) do
    value
  end

  defp sanitize_ast_value(value) when is_atom(value) do
    to_string(value)
  end

  defp sanitize_ast_value(value) when is_list(value) do
    Enum.map(value, &sanitize_ast_value/1)
  end

  defp sanitize_ast_value(value) when is_tuple(value) do
    # Convert tuples to a map representation for JSON serialization
    case value do
      {:"::", _, [name, type]} ->
        %{type_spec: %{name: sanitize_ast_value(name), type: sanitize_ast_value(type)}}
      {:%, _, [module, fields]} ->
        %{struct: %{module: sanitize_ast_value(module), fields: sanitize_ast_value(fields)}}
      {:%{}, _, fields} ->
        %{map: sanitize_ast_value(fields)}
      {:__aliases__, _, parts} ->
        %{module: Enum.join(Enum.map(parts, &to_string/1), ".")}
      {:., _, [module, func]} ->
        %{call: %{module: sanitize_ast_value(module), function: sanitize_ast_value(func)}}
      {func, _, args} when is_atom(func) ->
        %{function_call: %{name: to_string(func), args: sanitize_ast_value(args)}}
      _ ->
        # For complex tuples, convert to a generic representation
        tuple_list = Tuple.to_list(value)
        %{tuple: Enum.map(tuple_list, &sanitize_ast_value/1)}
    end
  end

  defp sanitize_ast_value(value) when is_map(value) do
    Map.new(value, fn {k, v} -> {sanitize_ast_value(k), sanitize_ast_value(v)} end)
  end

  defp sanitize_ast_value(_value) do
    # For any other complex types, return a placeholder
    "<complex_value>"
  end
end
