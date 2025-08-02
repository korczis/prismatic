# Benchmarking suite for Prismatic core protocols
# Run with: mix bench

alias Prismatic.Agent.Protocol, as: AgentProtocol
alias Prismatic.Memory.Protocol, as: MemoryProtocol
alias Prismatic.LLM.Backend

# Set up test data
agent_config = %{
  id: "benchmark_agent",
  name: "BenchmarkAgent",
  llm_backend: :test,
  config: %{temperature: 0.0, max_tokens: 1000}
}

memory_config = %{
  working_memory_size: 1000,
  episodic_memory_ttl: :timer.hours(1)
}

# Sample messages for benchmarking
messages = [
  "Hello, how are you?",
  "What is the meaning of life?",
  "Explain quantum computing in simple terms.",
  "Write a short story about a robot.",
  "Solve this math problem: 2 + 2 = ?"
]

# Memory operations for benchmarking
memory_operations = [
  {:store, :working, "key1", "value1"},
  {:store, :episodic, "key2", %{event: "test", timestamp: DateTime.utc_now()}},
  {:retrieve, :working, "key1"},
  {:query, :episodic, %{pattern: "test"}},
  {:consolidate}
]

Benchee.run(
  %{
    # Agent Protocol Benchmarks
    "Agent.process_message/3" => fn ->
      {:ok, agent} = Prismatic.Agent.TestImpl.new(agent_config)
      message = Enum.random(messages)
      AgentProtocol.process_message(agent, message, %{})
    end,

    "Agent.get_state/1" => fn ->
      {:ok, agent} = Prismatic.Agent.TestImpl.new(agent_config)
      AgentProtocol.get_state(agent)
    end,

    "Agent.serialize/1" => fn ->
      {:ok, agent} = Prismatic.Agent.TestImpl.new(agent_config)
      AgentProtocol.serialize(agent)
    end,

    # Memory Protocol Benchmarks
    "Memory.store/4" => fn ->
      {:ok, memory} = Prismatic.Memory.TestImpl.new(memory_config)
      key = "bench_key_#{:rand.uniform(1000)}"
      value = "bench_value_#{:rand.uniform(1000)}"
      MemoryProtocol.store(memory, :working, key, value)
    end,

    "Memory.retrieve/3" => fn ->
      {:ok, memory} = Prismatic.Memory.TestImpl.new(memory_config)
      # Pre-populate with some data
      MemoryProtocol.store(memory, :working, "test_key", "test_value")
      MemoryProtocol.retrieve(memory, :working, "test_key")
    end,

    "Memory.query/3" => fn ->
      {:ok, memory} = Prismatic.Memory.TestImpl.new(memory_config)
      # Pre-populate with some data
      Enum.each(1..10, fn i ->
        MemoryProtocol.store(memory, :episodic, "key_#{i}", "value_#{i}")
      end)
      MemoryProtocol.query(memory, :episodic, %{pattern: "key_*"})
    end,

    "Memory.consolidate/1" => fn ->
      {:ok, memory} = Prismatic.Memory.TestImpl.new(memory_config)
      # Pre-populate working memory
      Enum.each(1..50, fn i ->
        MemoryProtocol.store(memory, :working, "temp_#{i}", "data_#{i}")
      end)
      MemoryProtocol.consolidate(memory)
    end,

    # LLM Backend Benchmarks
    "LLM.generate_response/3" => fn ->
      {:ok, config} = Backend.create_config(:test, %{})
      prompt = Enum.random(messages)
      Backend.generate_response(config, prompt, %{})
    end,

    "LLM.validate_config/1" => fn ->
      {:ok, config} = Backend.create_config(:test, %{})
      Backend.validate_config(config)
    end,

    # Concurrent Operations Benchmarks
    "Concurrent.agent_processing" => fn ->
      tasks = Enum.map(1..10, fn _i ->
        Task.async(fn ->
          {:ok, agent} = Prismatic.Agent.TestImpl.new(agent_config)
          message = Enum.random(messages)
          AgentProtocol.process_message(agent, message, %{})
        end)
      end)
      Task.await_many(tasks)
    end,

    "Concurrent.memory_operations" => fn ->
      {:ok, memory} = Prismatic.Memory.TestImpl.new(memory_config)
      tasks = Enum.map(1..10, fn i ->
        Task.async(fn ->
          key = "concurrent_#{i}"
          value = "value_#{i}"
          MemoryProtocol.store(memory, :working, key, value)
          MemoryProtocol.retrieve(memory, :working, key)
        end)
      end)
      Task.await_many(tasks)
    end
  },
  time: 10,
  memory_time: 2,
  reduction_time: 2,
  formatters: [
    Benchee.Formatters.HTML,
    Benchee.Formatters.Console
  ],
  html: %{
    file: "benchmarks/results/benchmark_results.html",
    title: "Prismatic Core Protocols Benchmark"
  },
  print: %{
    benchmarking: true,
    configuration: true,
    fast_warning: true
  }
)

# Memory usage benchmarks
IO.puts("\n=== Memory Usage Analysis ===")

memory_before = :erlang.memory()

# Create multiple agents and measure memory usage
agents = Enum.map(1..100, fn i ->
  config = Map.put(agent_config, :id, "agent_#{i}")
  {:ok, agent} = Prismatic.Agent.TestImpl.new(config)
  agent
end)

memory_after = :erlang.memory()

memory_diff = memory_after[:total] - memory_before[:total]
memory_per_agent = div(memory_diff, 100)

IO.puts("Memory usage for 100 agents:")
IO.puts("  Total memory increase: #{memory_diff} bytes")
IO.puts("  Memory per agent: #{memory_per_agent} bytes")
IO.puts("  Memory per agent: #{Float.round(memory_per_agent / 1024, 2)} KB")

# Clean up
agents = nil
:erlang.garbage_collect()

IO.puts("\nBenchmark completed. Results saved to benchmarks/results/")
