defmodule Prismatic.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Core Infrastructure
      Prismatic.Repo,
      {DNSCluster, query: Application.get_env(:prismatic, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Prismatic.PubSub},

      # HTTP Clients
      {Finch, name: Prismatic.Finch},

      # Registries for Backend Services
      {Registry, keys: :unique, name: Prismatic.LLM.CircuitBreakerRegistry},
      {Registry, keys: :unique, name: Prismatic.Memory.CircuitBreakerRegistry},
      {Registry, keys: :unique, name: Prismatic.Blackboard.CircuitBreakerRegistry},

      # Event System Components
      {Prismatic.Event.CircuitBreakerRegistry, name: Prismatic.Event.CircuitBreakerRegistry},
      {Prismatic.Event.Registry, name: Prismatic.Event.Registry},
      {Prismatic.Event.Bus, name: Prismatic.Event.Bus},
      {Prismatic.Event.Sourcing,
       config: %{
        backend_type: :in_memory,
        name: :default_sourcing,
        enable_sourcing: true
        },
       name: Prismatic.Event.Sourcing
      },

      # Memory System Components
      {Prismatic.Memory.Manager, name: Prismatic.Memory.Manager},
      {Prismatic.Memory.Metrics, name: Prismatic.Memory.Metrics},

      # Blackboard System Components
      {Prismatic.Blackboard.Manager,
       config: %{
         name: :blackboard_manager,
         memory_backend: :layered,
         enable_events: true,
         enable_rules: true,
         enable_access_control: true,
         max_knowledge_objects: 100_000,
         rule_engine_config: %{
           max_rules: 10_000,
           execution_timeout: 5_000,
           enable_parallel_execution: true,
           max_concurrent_executions: 100,
           enable_events: true,
           rule_cache_ttl: 300_000
         }
       },
       name: Prismatic.Blackboard.Manager
      },

      # Additional workers can be added here
      # {Prismatic.Worker, arg}
    ]

    # Configure supervision strategy
    opts = [strategy: :one_for_one, name: Prismatic.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
