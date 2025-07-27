defmodule Prismatic.TestHelpers do
  @moduledoc """
  Common test helpers and utilities for the Prismatic test suite.

  This module provides shared functionality for testing protocols,
  mocking external services, and generating test data.
  """

  import ExUnit.Assertions
  import Mox

  alias Prismatic.Agent.Protocol, as: AgentProtocol
  alias Prismatic.Memory.Protocol, as: MemoryProtocol
  alias Prismatic.LLM.Backend

  @doc """
  Sets up mocks for all external dependencies.

  This should be called in test setup to ensure clean mock state.
  """
  def setup_mocks do
    # Verify mocks are called as expected
    verify_on_exit!()

    # Set up default mock behaviors
    setup_llm_mocks()
    setup_external_service_mocks()

    :ok
  end

  @doc """
  Creates a test agent configuration with sensible defaults.

  ## Options

  - `:name` - Agent name (default: random UUID)
  - `:llm_backend` - LLM backend type (default: :test)
  - `:memory_config` - Memory configuration (default: test config)
  - `:traits` - Agent traits (default: empty map)

  ## Examples

      iex> config = test_agent_config(name: "TestAgent")
      iex> config.name
      "TestAgent"
  """
  def test_agent_config(opts \\ []) do
    %{
      id: Keyword.get(opts, :id, UUID.uuid4()),
      name: Keyword.get(opts, :name, "TestAgent_#{:rand.uniform(1000)}"),
      llm_backend: Keyword.get(opts, :llm_backend, :test),
      memory_config: Keyword.get(opts, :memory_config, test_memory_config()),
      traits: Keyword.get(opts, :traits, %{}),
      config: %{
        temperature: 0.7,
        max_tokens: 1000,
        timeout: 30_000
      }
    }
  end

  @doc """
  Creates a test memory configuration.
  """
  def test_memory_config do
    %{
      working_memory_size: 100,
      episodic_memory_ttl: :timer.hours(24),
      semantic_memory_persistence: :memory,
      procedural_memory_cache_size: 50
    }
  end

  @doc """
  Creates a test LLM backend configuration.
  """
  def test_llm_config(backend_type \\ :test) do
    Backend.create_config(backend_type, %{
      api_key: "test_key",
      model: "test-model",
      timeout: 10_000,
      max_retries: 2
    })
  end

  @doc """
  Asserts that a protocol implementation behaves correctly.

  This is a meta-test that validates protocol implementations
  follow the expected contracts.
  """
  def assert_protocol_implementation(module, protocol) do
    # Check that the module implements the protocol
    assert protocol.impl_for(struct(module)) != nil,
           "#{module} does not implement #{protocol}"

    # Check that all required callbacks are implemented
    protocol_callbacks = protocol.__protocol__(:functions)

    Enum.each(protocol_callbacks, fn {function, arity} ->
      assert function_exported?(module, function, arity),
             "#{module} does not implement #{function}/#{arity}"
    end)
  end

  @doc """
  Waits for a process to receive a message matching the given pattern.

  Useful for testing asynchronous operations.
  """
  def wait_for_message(pattern, timeout \\ 1000) do
    receive do
      message when message == pattern -> {:ok, message}
      other -> {:error, {:unexpected_message, other}}
    after
      timeout -> {:error, :timeout}
    end
  end

  @doc """
  Captures log messages during test execution.

  Returns a list of captured log entries.
  """
  def capture_logs(fun) when is_function(fun, 0) do
    ExUnit.CaptureLog.capture_log(fun)
  end

  @doc """
  Generates test data for property-based testing.
  """
  def generators do
    %{
      agent_id: StreamData.string(:alphanumeric, min_length: 1, max_length: 50),
      message: StreamData.string(:printable, min_length: 1, max_length: 1000),
      memory_key: StreamData.string(:alphanumeric, min_length: 1, max_length: 100),
      memory_value: StreamData.term(),
      llm_response: StreamData.string(:printable, min_length: 10, max_length: 2000),
      timestamp: StreamData.map(StreamData.positive_integer(), &DateTime.from_unix!/1),
      config_map: StreamData.map_of(
        StreamData.atom(:alphanumeric),
        StreamData.one_of([
          StreamData.string(:alphanumeric),
          StreamData.integer(),
          StreamData.float(),
          StreamData.boolean()
        ])
      )
    }
  end

  @doc """
  Creates a temporary test database for isolated testing.
  """
  def with_test_database(test_fun) when is_function(test_fun, 0) do
    # This would set up an isolated test database
    # For now, we'll use the existing test database
    test_fun.()
  end

  @doc """
  Benchmarks a function and returns timing information.
  """
  def benchmark(name, fun) when is_function(fun, 0) do
    {time_microseconds, result} = :timer.tc(fun)

    IO.puts("Benchmark #{name}: #{time_microseconds / 1000} ms")

    result
  end

  # Private helper functions

  defp setup_llm_mocks do
    # Set up default LLM mock responses
    Mox.stub(Prismatic.LLM.MockBackend, :generate_response, fn _config, prompt, _context ->
      {:ok, "Mock response for: #{String.slice(prompt, 0, 50)}..."}
    end)

    Mox.stub(Prismatic.LLM.MockBackend, :validate_config, fn _config ->
      :ok
    end)

    Mox.stub(Prismatic.LLM.MockBackend, :health_check, fn _config ->
      :ok
    end)

    Mox.stub(Prismatic.LLM.MockBackend, :get_model_info, fn _config ->
      {:ok, %{
        name: "test-model",
        max_tokens: 4096,
        supports_streaming: false,
        cost_per_token: 0.0
      }}
    end)
  end

  defp setup_external_service_mocks do
    # Set up mocks for external services like databases, APIs, etc.
    :ok
  end
end
