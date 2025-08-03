defmodule Prismatic.Meta do
  @moduledoc """
  Advanced BEAM metaprogramming infrastructure providing compile-time introspection,
  dynamic macro generation, and sophisticated code analysis capabilities.

  This module serves as the foundation for the entire metaprogramming ecosystem,
  providing compile-time utilities, runtime introspection, and dynamic code generation
  patterns that enable self-documenting and self-configuring systems.

  ## Documentation References

  - **Guide**: [`@/docs/guides/meta/README.md`](../../docs/guides/meta/README.md)
  - **API**: [`@/docs/api/meta/README.md`](../../docs/api/meta/README.md)
  - **Tests**: [`@/test/prismatic/meta/`](../../test/prismatic/meta/)
  - **Navigation**: [`@/docs/guides/documentation/documentation-navigation-implementation.md`](../../docs/guides/documentation/documentation-navigation-implementation.md)

  ## Navigation

  - **Parent**: [`Prismatic`](../prismatic.md)
  - **Children**:
    - [`Prismatic.Meta.Introspection`](./meta/introspection.md)
    - [`Prismatic.Meta.MacroGenerator`](./meta/macro_generator.md)
    - [`Prismatic.Meta.ProtocolAnalyzer`](./meta/protocol_analyzer.md)
    - [`Prismatic.Meta.BehaviorIntrospector`](./meta/behavior_introspector.md)
    - [`Prismatic.Meta.ProcessInspector`](./meta/process_inspector.md)
    - [`Prismatic.Meta.SupervisorAnalyzer`](./meta/supervisor_analyzer.md)
    - [`Prismatic.Meta.ApplicationReflector`](./meta/application_reflector.md)
    - [`Prismatic.Meta.SelfDocumenting`](./meta/self_documenting.md)
    - [`Prismatic.Meta.SelfConfiguring`](./meta/self_configuring.md)
    - [`Prismatic.Meta.GenericAbstractions`](./meta/generic_abstractions.md)
    - [`Prismatic.Meta.HigherOrder`](./meta/higher_order.md)
    - [`Prismatic.Meta.CodeGenerator`](./meta/code_generator.md)
    - [`Prismatic.Meta.PatternAnalyzer`](./meta/pattern_analyzer.md)
    - [`Prismatic.Meta.ProcessLifecycle`](./meta/process_lifecycle.md)
    - [`Prismatic.Meta.BackpressureManager`](./meta/backpressure_manager.md)
    - [`Prismatic.Meta.HotSwapper`](./meta/hot_swapper.md)
    - [`Prismatic.Meta.DistributedPatterns`](./meta/distributed_patterns.md)
    - [`Prismatic.Meta.TelemetryIntegrator`](./meta/telemetry_integrator.md)
  - **Related**: [`Prismatic.Shared`](./shared.md), [`Prismatic.Code`](./code.md)

  ## Design Contracts

  ### Preconditions
  - All metaprogramming operations must maintain AST validity
  - Compile-time introspection must not affect runtime performance
  - Dynamic code generation must preserve type safety

  ### Postconditions
  - Generated code is equivalent to hand-written code in performance
  - All introspection results are deterministic and cacheable
  - Dynamic operations maintain BEAM VM invariants

  ### Invariants
  - Metaprogramming never introduces memory leaks or process leaks
  - All generated code passes dialyzer analysis
  - Compile-time operations are idempotent and side-effect free
  """

  @doc """
  Returns comprehensive metaprogramming capabilities and their current status.
  """
  @spec capabilities() :: [capability_info()]
  def capabilities do
    [
      %{
        module: Prismatic.Meta.Introspection,
        capability: :compile_time_introspection,
        status: :active,
        description: "Analyze modules, functions, and types at compile time"
      },
      %{
        module: Prismatic.Meta.MacroGenerator,
        capability: :dynamic_macro_generation,
        status: :active,
        description: "Generate macros dynamically based on runtime conditions"
      },
      %{
        module: Prismatic.Meta.ProtocolAnalyzer,
        capability: :protocol_polymorphism,
        status: :active,
        description: "Analyze and generate protocol implementations"
      },
      %{
        module: Prismatic.Meta.BehaviorIntrospector,
        capability: :behavior_introspection,
        status: :active,
        description: "Introspect behavior implementations and callbacks"
      },
      %{
        module: Prismatic.Meta.ProcessInspector,
        capability: :process_introspection,
        status: :active,
        description: "GenServer state inspection and process registry patterns"
      },
      %{
        module: Prismatic.Meta.SupervisorAnalyzer,
        capability: :supervisor_analysis,
        status: :active,
        description: "Analyze supervisor trees and OTP application structure"
      },
      %{
        module: Prismatic.Meta.ApplicationReflector,
        capability: :application_reflection,
        status: :active,
        description: "Reflect on OTP application structure and dependencies"
      },
      %{
        module: Prismatic.Meta.SelfDocumenting,
        capability: :self_documentation,
        status: :active,
        description: "Generate documentation from code introspection"
      },
      %{
        module: Prismatic.Meta.SelfConfiguring,
        capability: :self_configuration,
        status: :active,
        description: "Configure systems based on runtime introspection"
      },
      %{
        module: Prismatic.Meta.GenericAbstractions,
        capability: :generic_abstractions,
        status: :active,
        description: "Parameterized modules and generic programming patterns"
      },
      %{
        module: Prismatic.Meta.HigherOrder,
        capability: :higher_order_functions,
        status: :active,
        description: "Higher-order function patterns and combinators"
      },
      %{
        module: Prismatic.Meta.CodeGenerator,
        capability: :compile_time_generation,
        status: :active,
        description: "Generate code at compile time for performance"
      },
      %{
        module: Prismatic.Meta.PatternAnalyzer,
        capability: :pattern_analysis,
        status: :active,
        description: "Advanced pattern matching and guard analysis"
      },
      %{
        module: Prismatic.Meta.ProcessLifecycle,
        capability: :process_lifecycle,
        status: :active,
        description: "Process lifecycle management and monitoring"
      },
      %{
        module: Prismatic.Meta.BackpressureManager,
        capability: :backpressure_management,
        status: :active,
        description: "Backpressure mechanisms and flow control"
      },
      %{
        module: Prismatic.Meta.HotSwapper,
        capability: :hot_code_swapping,
        status: :active,
        description: "Dynamic module loading and hot code swapping"
      },
      %{
        module: Prismatic.Meta.DistributedPatterns,
        capability: :distributed_computing,
        status: :active,
        description: "Distributed computing patterns and coordination"
      },
      %{
        module: Prismatic.Meta.TelemetryIntegrator,
        capability: :telemetry_integration,
        status: :active,
        description: "Runtime introspection and telemetry integration"
      }
    ]
  end

  @type capability_info :: %{
    module: module(),
    capability: atom(),
    status: :active | :inactive | :experimental,
    description: String.t()
  }

  @doc """
  Performs compile-time analysis of the current module and generates metadata.
  """
  defmacro __using__(opts \\ []) do
    quote bind_quoted: [opts: opts] do
      @before_compile Prismatic.Meta

      # Import commonly used metaprogramming utilities
      import Prismatic.Meta.Introspection
      import Prismatic.Meta.MacroGenerator
      import Prismatic.Meta.PatternAnalyzer

      # Register module for introspection
      Module.register_attribute(__MODULE__, :meta_capabilities, accumulate: true)
      Module.register_attribute(__MODULE__, :meta_contracts, accumulate: true)
      Module.register_attribute(__MODULE__, :meta_patterns, accumulate: true)
      Module.register_attribute(__MODULE__, :meta_telemetry, accumulate: true)

      # Enable self-documentation
      if Keyword.get(opts, :self_documenting, true) do
        use Prismatic.Meta.SelfDocumenting
      end

      # Enable self-configuration
      if Keyword.get(opts, :self_configuring, false) do
        use Prismatic.Meta.SelfConfiguring
      end

      # Enable telemetry integration
      if Keyword.get(opts, :telemetry, true) do
        use Prismatic.Meta.TelemetryIntegrator
      end
    end
  end

  @doc """
  Compile-time hook that analyzes the module and generates metadata.
  """
  defmacro __before_compile__(env) do
    module = env.module

    # Analyze module structure
    functions = Module.definitions_in(module)
    attributes = Module.get_attribute(module, :meta_capabilities, [])
    contracts = Module.get_attribute(module, :meta_contracts, [])
    patterns = Module.get_attribute(module, :meta_patterns, [])
    telemetry = Module.get_attribute(module, :meta_telemetry, [])

    # Generate metadata functions
    quote do
      @doc false
      def __meta__(:capabilities), do: unquote(attributes)
      def __meta__(:contracts), do: unquote(contracts)
      def __meta__(:patterns), do: unquote(patterns)
      def __meta__(:telemetry), do: unquote(telemetry)
      def __meta__(:functions), do: unquote(functions)
      def __meta__(:module), do: __MODULE__
      def __meta__(:compilation_time), do: unquote(DateTime.utc_now())

      @doc """
      Returns comprehensive metadata about this module.
      """
      def __meta__ do
        %{
          module: __MODULE__,
          capabilities: __meta__(:capabilities),
          contracts: __meta__(:contracts),
          patterns: __meta__(:patterns),
          telemetry: __meta__(:telemetry),
          functions: __meta__(:functions),
          compilation_time: __meta__(:compilation_time),
          beam_metadata: beam_metadata()
        }
      end

      defp beam_metadata do
        case Code.which(__MODULE__) do
          nil -> %{}
          beam_path ->
            %{
              beam_path: beam_path,
              beam_size: File.stat!(beam_path).size,
              beam_modified: File.stat!(beam_path).mtime
            }
        end
      end
    end
  end

  @doc """
  Registers a capability for the current module.
  """
  defmacro capability(name, opts \\ []) do
    quote do
      @meta_capabilities {unquote(name), unquote(opts)}
    end
  end

  @doc """
  Registers a design contract for the current module.
  """
  defmacro contract(type, description) do
    quote do
      @meta_contracts {unquote(type), unquote(description)}
    end
  end

  @doc """
  Registers a pattern usage for the current module.
  """
  defmacro pattern(name, opts \\ []) do
    quote do
      @meta_patterns {unquote(name), unquote(opts)}
    end
  end

  @doc """
  Registers telemetry events for the current module.
  """
  defmacro telemetry_event(name, metadata \\ []) do
    quote do
      @meta_telemetry {unquote(name), unquote(metadata)}
    end
  end

  @doc """
  Creates a generic abstraction with compile-time parameterization.
  """
  defmacro defgeneric(name, params, do: body) do
    quote do
      defmacro unquote(name)(unquote_splicing(params)) do
        unquote(body)
      end
    end
  end

  @doc """
  Creates a higher-order function with advanced pattern matching.
  """
  defmacro defhigher(name, patterns, do: body) when is_list(patterns) do
    clauses =
      for pattern <- patterns do
        quote do
          def unquote(name)(unquote(pattern)) do
            unquote(body)
          end
        end
      end

    quote do
      unquote_splicing(clauses)
    end
  end

  @doc """
  Creates a protocol-aware function that dispatches based on data type.
  """
  defmacro defprotocol_aware(name, args, opts \\ []) do
    quote do
      def unquote(name)(unquote_splicing(args)) do
        data = unquote(hd(args))
        protocol = unquote(Keyword.get(opts, :protocol))

        if protocol && Protocol.implemented?(protocol, data) do
          protocol.unquote(name)(data)
        else
          # Fallback implementation
          unquote(Keyword.get(opts, :fallback, quote(do: {:error, :not_implemented})))
        end
      end
    end
  end

  @doc """
  Creates a behavior-aware GenServer with introspection capabilities.
  """
  defmacro defserver(name, opts \\ []) do
    quote do
      defmodule unquote(name) do
        use GenServer
        use Prismatic.Meta.ProcessInspector
        use Prismatic.Meta.ProcessLifecycle

        capability :genserver, [
          state_introspection: true,
          lifecycle_management: true,
          backpressure_support: Keyword.get(unquote(opts), :backpressure, false)
        ]

        @doc """
        Starts the GenServer with enhanced monitoring.
        """
        def start_link(init_arg, opts \\ []) do
          GenServer.start_link(__MODULE__, init_arg, opts)
        end

        @doc """
        Returns current server state for introspection.
        """
        def inspect_state(pid) do
          GenServer.call(pid, :__inspect_state__)
        end

        @doc """
        Returns server lifecycle information.
        """
        def lifecycle_info(pid) do
          GenServer.call(pid, :__lifecycle_info__)
        end

        # Default GenServer callbacks with introspection
        def init(init_arg) do
          state = %{
            init_arg: init_arg,
            started_at: DateTime.utc_now(),
            message_count: 0,
            lifecycle_events: []
          }

          {:ok, state}
        end

        def handle_call(:__inspect_state__, _from, state) do
          {:reply, state, state}
        end

        def handle_call(:__lifecycle_info__, _from, state) do
          info = %{
            started_at: state.started_at,
            uptime: DateTime.diff(DateTime.utc_now(), state.started_at),
            message_count: state.message_count,
            lifecycle_events: state.lifecycle_events
          }
          {:reply, info, state}
        end

        def handle_call(msg, from, state) do
          new_state = %{state | message_count: state.message_count + 1}
          handle_call_impl(msg, from, new_state)
        end

        def handle_cast(msg, state) do
          new_state = %{state | message_count: state.message_count + 1}
          handle_cast_impl(msg, new_state)
        end

        def handle_info(msg, state) do
          new_state = %{state | message_count: state.message_count + 1}
          handle_info_impl(msg, new_state)
        end

        # Override these in your implementation
        defp handle_call_impl(_msg, _from, state), do: {:reply, :ok, state}
        defp handle_cast_impl(_msg, state), do: {:noreply, state}
        defp handle_info_impl(_msg, state), do: {:noreply, state}

        defoverridable [
          handle_call_impl: 3,
          handle_cast_impl: 2,
          handle_info_impl: 2
        ]
      end
    end
  end

  @doc """
  Creates a supervisor with advanced introspection and analysis capabilities.
  """
  defmacro defsupervisor(name, opts \\ []) do
    quote do
      defmodule unquote(name) do
        use Supervisor
        use Prismatic.Meta.SupervisorAnalyzer

        capability :supervisor, [
          tree_analysis: true,
          child_introspection: true,
          restart_strategy: Keyword.get(unquote(opts), :strategy, :one_for_one)
        ]

        def start_link(init_arg) do
          Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
        end

        @doc """
        Analyzes the supervisor tree structure.
        """
        def analyze_tree do
          Prismatic.Meta.SupervisorAnalyzer.analyze_tree(__MODULE__)
        end

        @doc """
        Returns information about all child processes.
        """
        def child_info do
          Supervisor.which_children(__MODULE__)
          |> Enum.map(&analyze_child/1)
        end

        defp analyze_child({id, pid, type, modules}) do
          %{
            id: id,
            pid: pid,
            type: type,
            modules: modules,
            memory: if(is_pid(pid), do: Process.info(pid, :memory), else: nil),
            message_queue_len: if(is_pid(pid), do: Process.info(pid, :message_queue_len), else: nil)
          }
        end

        def init(init_arg) do
          children = child_specs(init_arg)

          strategy = Keyword.get(unquote(opts), :strategy, :one_for_one)
          max_restarts = Keyword.get(unquote(opts), :max_restarts, 3)
          max_seconds = Keyword.get(unquote(opts), :max_seconds, 5)

          Supervisor.init(children,
            strategy: strategy,
            max_restarts: max_restarts,
            max_seconds: max_seconds
          )
        end

        # Override this in your implementation
        defp child_specs(_init_arg), do: []

        defoverridable [child_specs: 1]
      end
    end
  end

  @doc """
  Performs runtime introspection of the BEAM VM and processes.
  """
  @spec runtime_introspection() :: runtime_info()
  def runtime_introspection do
    %{
      system_info: system_introspection(),
      process_info: process_introspection(),
      memory_info: memory_introspection(),
      scheduler_info: scheduler_introspection(),
      application_info: application_introspection()
    }
  end

  @type runtime_info :: %{
    system_info: map(),
    process_info: map(),
    memory_info: map(),
    scheduler_info: map(),
    application_info: map()
  }

  defp system_introspection do
    %{
      otp_version: System.otp_release(),
      elixir_version: System.version(),
      system_architecture: :erlang.system_info(:system_architecture),
      schedulers: :erlang.system_info(:schedulers),
      schedulers_online: :erlang.system_info(:schedulers_online),
      logical_processors: :erlang.system_info(:logical_processors),
      ets_limit: :erlang.system_info(:ets_limit),
      port_limit: :erlang.system_info(:port_limit),
      process_limit: :erlang.system_info(:process_limit)
    }
  end

  defp process_introspection do
    processes = Process.list()

    %{
      total_processes: length(processes),
      registered_processes: length(Process.registered()),
      memory_per_process: processes |> Enum.map(&Process.info(&1, :memory)) |> Enum.map(&elem(&1, 1)),
      message_queue_lengths: processes |> Enum.map(&Process.info(&1, :message_queue_len)) |> Enum.map(&elem(&1, 1)),
      reductions: processes |> Enum.map(&Process.info(&1, :reductions)) |> Enum.map(&elem(&1, 1))
    }
  end

  defp memory_introspection do
    :erlang.memory()
    |> Enum.into(%{})
  end

  defp scheduler_introspection do
    :erlang.statistics(:scheduler_wall_time)
    |> case do
      :undefined -> %{scheduler_wall_time: :not_enabled}
      scheduler_times -> %{scheduler_wall_time: scheduler_times}
    end
    |> Map.merge(%{
      context_switches: :erlang.statistics(:context_switches),
      garbage_collection: :erlang.statistics(:garbage_collection),
      io: :erlang.statistics(:io),
      reductions: :erlang.statistics(:reductions),
      run_queue: :erlang.statistics(:run_queue),
      runtime: :erlang.statistics(:runtime),
      wall_clock: :erlang.statistics(:wall_clock)
    })
  end

  defp application_introspection do
    loaded_apps = Application.loaded_applications()
    started_apps = Application.started_applications()

    %{
      loaded_applications: loaded_apps,
      started_applications: started_apps,
      loaded_count: length(loaded_apps),
      started_count: length(started_apps)
    }
  end
end
