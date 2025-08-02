defmodule Prismatic.Event.CircuitBreakerRegistry do
  @moduledoc """
  Registry for Event System circuit breakers.

  This module provides a centralized registry for managing circuit breaker
  processes across different event system backends. It ensures that each backend
  has a unique circuit breaker instance and provides lookup functionality.

  ## Usage

  The registry is typically started as part of the application supervision
  tree and used internally by the CircuitBreaker module.

  ## Examples

      # Start the registry
      {:ok, _pid} = Prismatic.Event.CircuitBreakerRegistry.start_link()

      # Register a circuit breaker (done automatically by CircuitBreaker)
      Registry.register(Prismatic.Event.CircuitBreakerRegistry, :in_memory, nil)

      # Lookup circuit breaker processes
      [{pid, _}] = Registry.lookup(Prismatic.Event.CircuitBreakerRegistry, :in_memory)
  """

  @doc """
  Starts the circuit breaker registry.

  ## Options

  - `:name` - Registry name (default: `__MODULE__`)

  ## Examples

      iex> {:ok, pid} = Prismatic.Event.CircuitBreakerRegistry.start_link()
      iex> is_pid(pid)
      true
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    Registry.start_link(keys: :unique, name: name)
  end

  @doc """
  Returns the child specification for use in supervision trees.

  ## Examples

      # In your application supervisor
      children = [
        Prismatic.Event.CircuitBreakerRegistry.child_spec([])
      ]
  """
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end
end
