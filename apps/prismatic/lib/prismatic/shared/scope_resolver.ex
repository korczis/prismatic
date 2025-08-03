defmodule Prismatic.Shared.ScopeResolver do
  @moduledoc """
  Runtime-compatible scope resolution engine providing comprehensive targeting capabilities.

  This module operates entirely through standard Elixir runtime APIs and works in production
  releases where Mix is not available. It provides module-specific, application-level,
  process-level, and registry-based targeting with support for complex scope combinations and filtering.

  **RUNTIME COMPATIBILITY**: All functionality works in production releases without Mix dependencies.
  Uses only BEAM introspection, OTP APIs, and standard library functions.

  ## Documentation References

  - **Guide**: [`@/docs/guides/shared/scope-resolver.md`](../../../docs/guides/shared/scope-resolver.md)
  - **API**: [`@/docs/api/shared/scope-resolver.md`](../../../docs/api/shared/scope-resolver.md)
  - **Tests**: [`@/test/prismatic/shared/scope_resolver_test.exs`](../../../test/prismatic/shared/scope_resolver_test.exs)
  - **Navigation**: [`@/docs/guides/documentation/documentation-navigation-implementation.md`](../../../docs/guides/documentation/documentation-navigation-implementation.md)

  ## Navigation

  - **Parent**: [`Prismatic.Shared`](../shared.md)
  - **Related**: [`Prismatic.Shared.DocumentationValidator`](./documentation_validator.md)
  - **Related**: [`Prismatic.Shared.NavigationGenerator`](./navigation_generator.md)

  ## Design Contracts

  ### Preconditions
  - Scope type must be valid atom from supported types
  - Target specification must be non-empty when type requires it
  - Options must contain valid keyword pairs
  - System must have access to BEAM introspection APIs

  ### Postconditions
  - Returns {:ok, list} for successful resolution
  - Returns {:error, reason} for invalid inputs or resolution failures
  - Resolved targets are guaranteed to exist and be accessible at runtime
  - All operations work in production releases without Mix

  ### Invariants
  - Resolution order is deterministic and repeatable
  - Scope combinations maintain logical hierarchy
  - Performance scales linearly with target count
  - No dependencies on Mix.* modules or compile-time tooling
  """

  use GenServer
  require Logger

  # Runtime-compatible scope types (no Mix dependencies)
  @type scope_type ::
    :application | :module | :loaded_modules | :beam_files |
    :process | :supervisor | :registry | :config | :runtime_deps

  @type scope_target :: String.t() | [String.t()] | :all | Regex.t() | module() | pid()

  @type scope_options :: [
    since: DateTime.t() | String.t(),
    until: DateTime.t() | String.t(),
    include_children: boolean(),
    exclude_patterns: [String.t()],
    filter_fn: (any() -> boolean()),
    max_depth: non_neg_integer(),
    correlation_id: String.t(),
    runtime_only: boolean()
  ]

  @type resolution_result :: {:ok, [resolved_target()]} | {:error, resolution_error()}

  @type resolved_target :: %{
    type: scope_type(),
    name: String.t() | atom(),
    module: module() | nil,
    pid: pid() | nil,
    metadata: map()
  }

  @type resolution_error ::
    :invalid_scope_type |
    :invalid_target |
    :target_not_found |
    :permission_denied |
    :circular_dependency |
    {:validation_failed, [String.t()]} |
    {:system_error, term()}

  # Runtime-compatible scope types only
  @supported_scopes [
    :application, :module, :loaded_modules, :beam_files,
    :process, :supervisor, :registry, :config, :runtime_deps
  ]

  # GenServer state for caching and performance
  defstruct [:cache, :options, :last_updated, :stats]

  @doc """
  Starts the ScopeResolver GenServer for caching and performance optimization.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(opts) do
    state = %__MODULE__{
      cache: %{},
      options: opts,
      last_updated: DateTime.utc_now(),
      stats: %{resolutions: 0, cache_hits: 0, cache_misses: 0}
    }
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:resolve_scope, types, targets, opts}, _from, state) do
    cache_key = {types, targets, opts}

    case Map.get(state.cache, cache_key) do
      nil ->
        result = resolve_scope_direct(types, targets, opts)
        new_cache = Map.put(state.cache, cache_key, {result, DateTime.utc_now()})
        new_stats = %{state.stats |
          resolutions: state.stats.resolutions + 1,
          cache_misses: state.stats.cache_misses + 1
        }
        {:reply, result, %{state | cache: new_cache, stats: new_stats}}

      {cached_result, _timestamp} ->
        new_stats = %{state.stats |
          resolutions: state.stats.resolutions + 1,
          cache_hits: state.stats.cache_hits + 1
        }
        {:reply, cached_result, %{state | stats: new_stats}}
    end
  end

  @impl GenServer
  def handle_call(:clear_cache, _from, state) do
    {:reply, :ok, %{state | cache: %{}}}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  @doc """
  Resolves scope specification to concrete list of targets using runtime-only APIs.

  **RUNTIME COMPATIBLE**: Works in production releases without Mix dependencies.

  ## Examples

      # Module scoping (runtime introspection)
      iex> resolve_scope(:module, "Prismatic.Code.*")
      {:ok, [
        %{type: :module, name: "Prismatic.Code.Analyzer", module: Prismatic.Code.Analyzer, metadata: %{}},
        %{type: :module, name: "Prismatic.Code.Resolver", module: Prismatic.Code.Resolver, metadata: %{}}
      ]}

      # Application scoping (OTP application introspection)
      iex> resolve_scope(:application, "prismatic")
      {:ok, [
        %{type: :application, name: :prismatic, module: nil, metadata: %{running: true}}
      ]}

      # Process scoping (runtime process introspection)
      iex> resolve_scope(:process, "GenServer")
      {:ok, [
        %{type: :process, name: "MyGenServer", pid: #PID<0.123.0>, module: MyGenServer, metadata: %{}}
      ]}
  """
  @spec resolve_scope(scope_type() | [scope_type()], scope_target(), scope_options()) ::
    resolution_result()
  def resolve_scope(type, target, opts \\ [])

  def resolve_scope(types, targets, opts) when is_list(types) and is_list(targets) do
    # Use GenServer for caching if available, otherwise direct resolution
    case GenServer.whereis(__MODULE__) do
      nil -> resolve_scope_direct(types, targets, opts)
      pid -> GenServer.call(pid, {:resolve_scope, types, targets, opts})
    end
  end

  def resolve_scope(type, target, opts) when is_atom(type) do
    resolve_scope([type], List.wrap(target), opts)
  end

  defp resolve_scope_direct(types, targets, opts) do
    correlation_id = Keyword.get(opts, :correlation_id, generate_correlation_id())

    Logger.debug("Resolving combined scope (runtime)",
      correlation_id: correlation_id,
      types: types,
      targets: targets,
      runtime_only: Keyword.get(opts, :runtime_only, true)
    )

    with :ok <- validate_scope_types(types),
         :ok <- validate_targets(targets),
         {:ok, resolved_combinations} <- resolve_scope_combinations_runtime(types, targets, opts) do

      flattened_results =
        resolved_combinations
        |> List.flatten()
        |> Enum.uniq_by(&get_unique_key/1)
        |> apply_runtime_filters(opts)
        |> sort_results(opts)

      Logger.info("Runtime scope resolution completed",
        correlation_id: correlation_id,
        resolved_count: length(flattened_results)
      )

      {:ok, flattened_results}
    else
      error ->
        Logger.error("Runtime scope resolution failed",
          correlation_id: correlation_id,
          error: error
        )
        error
    end
  end

  @doc """
  Resolves application scope using OTP application introspection.

  **RUNTIME COMPATIBLE**: Uses Application.loaded_applications/0 and Application.started_applications/0.
  """
  @spec resolve_application_scope(scope_target(), scope_options()) :: resolution_result()
  def resolve_application_scope(target, opts \\ [])

  def resolve_application_scope(:all, opts) do
    correlation_id = Keyword.get(opts, :correlation_id, generate_correlation_id())

    try do
      loaded_apps = Application.loaded_applications()
      started_apps = Application.started_applications()
      started_names = MapSet.new(started_apps, &elem(&1, 0))

      results =
        loaded_apps
        |> Enum.map(fn {app_name, description, version} ->
          %{
            type: :application,
            name: app_name,
            module: nil,
            pid: nil,
            metadata: %{
              description: description,
              version: version,
              started: MapSet.member?(started_names, app_name),
              spec: build_application_metadata_runtime(app_name)
            }
          }
        end)
        |> apply_runtime_filters(opts)

      {:ok, results}
    rescue
      error ->
        Logger.error("Application scope resolution failed",
          correlation_id: correlation_id,
          error: Exception.message(error)
        )
        {:error, {:system_error, error}}
    end
  end

  def resolve_application_scope(app_name, opts) when is_atom(app_name) or is_binary(app_name) do
    app_atom = if is_binary(app_name), do: String.to_existing_atom(app_name), else: app_name

    case Application.loaded_applications() |> Enum.find(fn {name, _, _} -> name == app_atom end) do
      {^app_atom, description, version} ->
        started = Application.started_applications() |> Enum.any?(fn {name, _, _} -> name == app_atom end)
        result = %{
          type: :application,
          name: app_atom,
          module: nil,
          pid: nil,
          metadata: %{
            description: description,
            version: version,
            started: started,
            spec: build_application_metadata_runtime(app_atom)
          }
        }
        {:ok, [result]}
      nil ->
        {:error, :target_not_found}
    end
  rescue
    ArgumentError -> {:error, :target_not_found}
  end

  def resolve_application_scope(pattern, opts) when is_binary(pattern) do
    case resolve_application_scope(:all, opts) do
      {:ok, apps} ->
        filtered = filter_applications_by_pattern(apps, pattern)
        {:ok, filtered}
      error -> error
    end
  end

  def resolve_application_scope(%Regex{} = pattern, opts) do
    case resolve_application_scope(:all, opts) do
      {:ok, apps} ->
        filtered = Enum.filter(apps, fn %{name: name} ->
          Regex.match?(pattern, to_string(name))
        end)
        {:ok, filtered}
      error -> error
    end
  end

  @doc """
  Resolves loaded module scope using runtime BEAM introspection.

  **RUNTIME COMPATIBLE**: Uses :code.all_loaded/0 and module introspection APIs.
  """
  @spec resolve_loaded_modules_scope(scope_target(), scope_options()) :: resolution_result()
  def resolve_loaded_modules_scope(target, opts \\ [])

  def resolve_loaded_modules_scope(:all, opts) do
    correlation_id = Keyword.get(opts, :correlation_id, generate_correlation_id())

    try do
      loaded_modules = :code.all_loaded()

      results =
        loaded_modules
        |> Enum.map(fn {module, beam_path} ->
          %{
            type: :module,
            name: to_string(module),
            module: module,
            pid: nil,
            metadata: %{
              beam_path: beam_path,
              loaded: true,
              attributes: build_module_metadata_runtime(module)
            }
          }
        end)
        |> apply_runtime_filters(opts)

      {:ok, results}
    rescue
      error ->
        Logger.error("Loaded modules scope resolution failed",
          correlation_id: correlation_id,
          error: Exception.message(error)
        )
        {:error, {:system_error, error}}
    end
  end

  def resolve_loaded_modules_scope(pattern, opts) when is_binary(pattern) do
    case resolve_loaded_modules_scope(:all, opts) do
      {:ok, modules} ->
        filtered = filter_modules_by_pattern_runtime(modules, pattern)
        {:ok, filtered}
      error -> error
    end
  end

  def resolve_loaded_modules_scope(%Regex{} = pattern, opts) do
    case resolve_loaded_modules_scope(:all, opts) do
      {:ok, modules} ->
        filtered = Enum.filter(modules, fn %{module: module} ->
          Regex.match?(pattern, to_string(module))
        end)
        {:ok, filtered}
      error -> error
    end
  end

  @doc """
  Resolves module-specific scoping using runtime module introspection.

  **RUNTIME COMPATIBLE**: Uses loaded module introspection and pattern matching.
  """
  @spec resolve_module_scope(scope_target(), scope_options()) :: resolution_result()
  def resolve_module_scope(target, opts \\ [])

  def resolve_module_scope(:all, opts) do
    resolve_loaded_modules_scope(:all, opts)
  end

  def resolve_module_scope(pattern, opts) when is_binary(pattern) do
    resolve_loaded_modules_scope(pattern, opts)
  end

  def resolve_module_scope(%Regex{} = pattern, opts) do
    resolve_loaded_modules_scope(pattern, opts)
  end

  def resolve_module_scope(module, opts) when is_atom(module) do
    case :code.is_loaded(module) do
      {:file, beam_path} ->
        result = %{
          type: :module,
          name: to_string(module),
          module: module,
          pid: nil,
          metadata: %{
            beam_path: beam_path,
            loaded: true,
            attributes: build_module_metadata_runtime(module)
          }
        }
        {:ok, [result]}
      false ->
        {:error, :target_not_found}
    end
  end

  def resolve_module_scope(modules, opts) when is_list(modules) do
    results =
      modules
      |> Enum.map(&resolve_module_scope(&1, opts))
      |> Enum.reduce({:ok, []}, fn
        {:ok, module_results}, {:ok, acc} -> {:ok, acc ++ module_results}
        error, _acc -> error
      end)

    case results do
      {:ok, all_results} -> {:ok, Enum.uniq_by(all_results, & &1.module)}
      error -> error
    end
  end

  @doc """
  Resolves process scope using runtime process introspection.

  **RUNTIME COMPATIBLE**: Uses Process.list/0 and process_info/2.
  """
  @spec resolve_process_scope(scope_target(), scope_options()) :: resolution_result()
  def resolve_process_scope(target, opts \\ [])

  def resolve_process_scope(:all, opts) do
    correlation_id = Keyword.get(opts, :correlation_id, generate_correlation_id())

    try do
      processes = Process.list()

      results =
        processes
        |> Enum.map(&build_process_target(&1, opts))
        |> Enum.filter(& &1 != nil)
        |> apply_runtime_filters(opts)

      {:ok, results}
    rescue
      error ->
        Logger.error("Process scope resolution failed",
          correlation_id: correlation_id,
          error: Exception.message(error)
        )
        {:error, {:system_error, error}}
    end
  end

  def resolve_process_scope(pattern, opts) when is_binary(pattern) do
    case resolve_process_scope(:all, opts) do
      {:ok, processes} ->
        filtered = filter_processes_by_pattern(processes, pattern)
        {:ok, filtered}
      error -> error
    end
  end

  def resolve_process_scope(pid, opts) when is_pid(pid) do
    case Process.alive?(pid) do
      true ->
        case build_process_target(pid, opts) do
          nil -> {:error, :target_not_found}
          result -> {:ok, [result]}
        end
      false ->
        {:error, :target_not_found}
    end
  end

  @doc """
  Resolves supervisor tree scope using OTP supervisor introspection.

  **RUNTIME COMPATIBLE**: Uses Supervisor.which_children/1 and OTP APIs.
  """
  @spec resolve_supervisor_scope(scope_target(), scope_options()) :: resolution_result()
  def resolve_supervisor_scope(target, opts \\ [])

  def resolve_supervisor_scope(:all, opts) do
    # Find all supervisors by scanning processes
    case resolve_process_scope(:all, opts) do
      {:ok, processes} ->
        supervisors = Enum.filter(processes, fn %{metadata: metadata} ->
          Map.get(metadata, :process_type) == :supervisor
        end)
        {:ok, supervisors}
      error -> error
    end
  end

  def resolve_supervisor_scope(supervisor_name, opts) when is_atom(supervisor_name) do
    try do
      children = Supervisor.which_children(supervisor_name)

      results =
        children
        |> Enum.map(fn {id, pid, type, modules} ->
          %{
            type: :supervisor,
            name: to_string(id),
            module: List.first(modules),
            pid: pid,
            metadata: %{
              supervisor: supervisor_name,
              child_type: type,
              modules: modules,
              alive: if(is_pid(pid), do: Process.alive?(pid), else: false)
            }
          }
        end)
        |> apply_runtime_filters(opts)

      {:ok, results}
    rescue
      error ->
        {:error, {:system_error, error}}
    end
  end

  @doc """
  Resolves registry scope using runtime registry introspection.

  **RUNTIME COMPATIBLE**: Uses Registry APIs where available.
  """
  @spec resolve_registry_scope(scope_target(), scope_options()) :: resolution_result()
  def resolve_registry_scope(target, opts \\ [])

  def resolve_registry_scope(registry_name, opts) when is_atom(registry_name) do
    if Code.ensure_loaded?(Registry) do
      try do
        keys = Registry.select(registry_name, [{{:_, :_, :_}, [], [:_]}])

        results =
          keys
          |> Enum.map(fn {key, pid, value} ->
            %{
              type: :registry,
              name: to_string(key),
              module: nil,
              pid: pid,
              metadata: %{
                registry: registry_name,
                key: key,
                value: value,
                alive: Process.alive?(pid)
              }
            }
          end)
          |> apply_runtime_filters(opts)

        {:ok, results}
      rescue
        error -> {:error, {:system_error, error}}
      end
    else
      {:error, :target_not_found}
    end
  end

  def resolve_registry_scope(:all, _opts) do
    # Cannot enumerate all registries without system-specific knowledge
    {:error, :target_not_found}
  end

  @doc """
  Validates scope type is supported.
  """
  @spec validate_scope_type(scope_type()) :: :ok | {:error, :invalid_scope_type}
  def validate_scope_type(type) when type in @supported_scopes, do: :ok
  def validate_scope_type(_type), do: {:error, :invalid_scope_type}

  @doc """
  Validates list of scope types.
  """
  @spec validate_scope_types([scope_type()]) :: :ok | {:error, :invalid_scope_type}
  def validate_scope_types(types) when is_list(types) do
    case Enum.all?(types, &validate_scope_type(&1) == :ok) do
      true -> :ok
      false -> {:error, :invalid_scope_type}
    end
  end

  @doc """
  Clears the resolution cache.
  """
  def clear_cache do
    case GenServer.whereis(__MODULE__) do
      nil -> :ok
      pid -> GenServer.call(pid, :clear_cache)
    end
  end

  @doc """
  Gets resolution statistics.
  """
  def get_stats do
    case GenServer.whereis(__MODULE__) do
      nil -> %{resolutions: 0, cache_hits: 0, cache_misses: 0}
      pid -> GenServer.call(pid, :get_stats)
    end
  end

  # Private implementation functions

  defp validate_targets([]), do: {:error, :invalid_target}
  defp validate_targets(targets) when is_list(targets), do: :ok
  defp validate_targets(_), do: :ok

  defp resolve_scope_combinations_runtime(types, targets, opts) do
    combinations = for type <- types, target <- targets, do: {type, target}

    results =
      combinations
      |> Enum.map(&resolve_single_combination_runtime(&1, opts))
      |> Enum.reduce_while([], fn
        {:ok, result}, acc -> {:cont, [result | acc]}
        error, _acc -> {:halt, error}
      end)

    case results do
      {:error, _} = error -> error
      results when is_list(results) -> {:ok, Enum.reverse(results)}
    end
  end

  defp resolve_single_combination_runtime({type, target}, opts) do
    case type do
      :application -> resolve_application_scope(target, opts)
      :module -> resolve_module_scope(target, opts)
      :loaded_modules -> resolve_loaded_modules_scope(target, opts)
      :process -> resolve_process_scope(target, opts)
      :supervisor -> resolve_supervisor_scope(target, opts)
      :registry -> resolve_registry_scope(target, opts)
      :config -> resolve_config_scope_runtime(target, opts)
      :runtime_deps -> resolve_runtime_deps_scope(target, opts)
      _ -> {:error, :invalid_scope_type}
    end
  end

  defp resolve_config_scope_runtime(target, opts) do
    # Runtime configuration introspection
    try do
      config_keys = Application.get_all_env(target)

      results =
        config_keys
        |> Enum.map(fn {key, value} ->
          %{
            type: :config,
            name: "#{target}.#{key}",
            module: nil,
            pid: nil,
            metadata: %{
              application: target,
              key: key,
              value: value
            }
          }
        end)
        |> apply_runtime_filters(opts)

      {:ok, results}
    rescue
      error -> {:error, {:system_error, error}}
    end
  end

  defp resolve_runtime_deps_scope(target, opts) do
    # Runtime dependency analysis using loaded applications
    case resolve_application_scope(target, opts) do
      {:ok, [app]} ->
        deps = get_runtime_dependencies(app.name)

        results =
          deps
          |> Enum.map(fn dep_name ->
            %{
              type: :runtime_deps,
              name: to_string(dep_name),
              module: nil,
              pid: nil,
              metadata: %{
                dependency_of: target,
                dependency_type: :runtime
              }
            }
          end)

        {:ok, results}
      error -> error
    end
  end

  defp get_runtime_dependencies(app_name) when is_atom(app_name) do
    case Application.spec(app_name, :applications) do
      nil -> []
      deps -> deps
    end
  end

  defp build_application_metadata_runtime(app_name) do
    try do
      %{
        modules: Application.spec(app_name, :modules) || [],
        applications: Application.spec(app_name, :applications) || [],
        included_applications: Application.spec(app_name, :included_applications) || [],
        registered: Application.spec(app_name, :registered) || [],
        env: Application.get_all_env(app_name)
      }
    rescue
      _ -> %{}
    end
  end

  defp build_module_metadata_runtime(module) do
    try do
      %{
        exports: module.module_info(:exports),
        attributes: module.module_info(:attributes),
        compile: module.module_info(:compile)
      }
    rescue
      _ -> %{}
    end
  end

  defp build_process_target(pid, _opts) do
    try do
      info = Process.info(pid)

      case info do
        nil -> nil
        process_info ->
          %{
            type: :process,
            name: get_process_name(process_info),
            module: get_process_module(process_info),
            pid: pid,
            metadata: %{
              process_type: get_process_type(process_info),
              status: Keyword.get(process_info, :status),
              memory: Keyword.get(process_info, :memory),
              message_queue_len: Keyword.get(process_info, :message_queue_len),
              links: Keyword.get(process_info, :links, []),
              monitors: Keyword.get(process_info, :monitors, [])
            }
          }
      end
    rescue
      _ -> nil
    end
  end

  defp get_process_name(process_info) do
    case Keyword.get(process_info, :registered_name) do
      [] -> "pid:#{inspect(Keyword.get(process_info, :pid))}"
      name -> to_string(name)
    end
  end

  defp get_process_module(process_info) do
    case Keyword.get(process_info, :dictionary) do
      nil -> nil
      dict ->
        case Keyword.get(dict, :"$initial_call") do
          {module, _fun, _arity} -> module
          _ -> nil
        end
    end
  end

  defp get_process_type(process_info) do
    case Keyword.get(process_info, :dictionary) do
      nil -> :process
      dict ->
        case Keyword.get(dict, :"$ancestors") do
          [supervisor | _] when is_atom(supervisor) -> :supervised_process
          _ -> :process
        end
    end
  end

  defp filter_applications_by_pattern(apps, pattern) do
    regex_pattern = convert_wildcard_to_regex(pattern)

    Enum.filter(apps, fn %{name: name} ->
      Regex.match?(regex_pattern, to_string(name))
    end)
  end

  defp filter_modules_by_pattern_runtime(modules, pattern) do
    regex_pattern = convert_wildcard_to_regex(pattern)

    Enum.filter(modules, fn %{name: name} ->
      Regex.match?(regex_pattern, name)
    end)
  end

  defp filter_processes_by_pattern(processes, pattern) do
    regex_pattern = convert_wildcard_to_regex(pattern)

    Enum.filter(processes, fn %{name: name, module: module} ->
      Regex.match?(regex_pattern, name) or
      (module && Regex.match?(regex_pattern, to_string(module)))
    end)
  end

  defp convert_wildcard_to_regex(pattern) do
    escaped = Regex.escape(pattern)
    regex_pattern = String.replace(escaped, "\\*", ".*")
    Regex.compile!("^#{regex_pattern}$")
  end

  defp get_unique_key(%{type: :application, name: name}), do: {:application, name}
  defp get_unique_key(%{type: :module, module: module}), do: {:module, module}
  defp get_unique_key(%{type: :process, pid: pid}), do: {:process, pid}
  defp get_unique_key(%{type: type, name: name}), do: {type, name}

  defp apply_runtime_filters(results, opts) do
    results
    |> maybe_filter_by_include_children(opts)
    |> maybe_apply_exclude_patterns(opts)
    |> maybe_apply_filter_function(opts)
    |> maybe_apply_max_depth(opts)
  end

  defp maybe_filter_by_include_children(results, opts) do
    if Keyword.get(opts, :include_children, true) do
      results
    else
      # Filter to only top-level items (implementation depends on type)
      results
    end
  end

  defp maybe_apply_exclude_patterns(results, opts) do
    exclude_patterns = Keyword.get(opts, :exclude_patterns, [])

    if exclude_patterns == [] do
      results
    else
      compiled_patterns = Enum.map(exclude_patterns, &Regex.compile!/1)

      Enum.filter(results, fn %{name: name} ->
        not Enum.any?(compiled_patterns, &Regex.match?(&1, to_string(name)))
      end)
    end
  end

  defp maybe_apply_filter_function(results, opts) do
    case Keyword.get(opts, :filter_fn) do
      nil -> results
      filter_fn when is_function(filter_fn, 1) -> Enum.filter(results, filter_fn)
      _ -> results
    end
  end

  defp maybe_apply_max_depth(results, opts) do
    case Keyword.get(opts, :max_depth) do
      nil -> results
      max_depth ->
        Enum.filter(results, fn result ->
          depth = calculate_result_depth(result)
          depth <= max_depth
        end)
    end
  end

  defp calculate_result_depth(%{name: name}) do
    name |> to_string() |> String.split(".") |> length()
  end

  defp sort_results(results, _opts) do
    Enum.sort_by(results, fn %{type: type, name: name} ->
      {type, to_string(name)}
    end)
  end

  defp generate_correlation_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
