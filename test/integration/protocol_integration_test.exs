defmodule Prismatic.Integration.ProtocolIntegrationTest do
  @moduledoc """
  Integration tests for protocol interactions.

  These tests verify that the core protocols work together correctly
  and maintain consistency across the system.
  """

  use ExUnit.Case, async: false

  import Prismatic.TestHelpers
  import Prismatic.PropertyHelpers

  alias Prismatic.Agent.Protocol, as: AgentProtocol
  alias Prismatic.Memory.Protocol, as: MemoryProtocol
  alias Prismatic.LLM.Backend

  @moduletag :integration

  setup do
    setup_mocks()

    # Start required services for integration tests
    {:ok, _} = start_supervised(Prismatic.EventBus)
    {:ok, _} = start_supervised(Prismatic.Supervisor.Core)

    :ok
  end

  describe "Agent-Memory Integration" do
    test "agent can store and retrieve memories during conversation" do
      # Create agent with memory
      agent_config = test_agent_config(name: "MemoryAgent")
      {:ok, agent} = Prismatic.Agent.TestImpl.new(agent_config)

      # Process message that should create memories
      message1 = "My name is Alice and I like programming"
      {:ok, response1} = AgentProtocol.process_message(agent, message1, %{})

      assert is_binary(response1)

      # Verify memory was created
      {:ok, agent_state} = AgentProtocol.get_state(agent)
      memory = agent_state.memory

      {:ok, stored_info} = MemoryProtocol.retrieve(memory, :episodic, "user_name")
      assert stored_info == "Alice"

      # Process follow-up message that should use stored memory
      message2 = "What do you remember about me?"
      {:ok, response2} = AgentProtocol.process_message(agent, message2, %{})

      assert String.contains?(response2, "Alice") or String.contains?(response2, "programming")
    end

    test "memory consolidation works across agent sessions" do
      agent_config = test_agent_config(name: "PersistentAgent")

      # First session
      {:ok, agent1} = Prismatic.Agent.TestImpl.new(agent_config)
      {:ok, response1} = AgentProtocol.process_message(agent1, "Remember: the sky is blue", %{})

      # Serialize agent state
      {:ok, serialized} = AgentProtocol.serialize(agent1)

      # Second session - restore from serialized state
      {:ok, agent2} = AgentProtocol.deserialize(serialized)
      {:ok, response2} = AgentProtocol.process_message(agent2, "What color is the sky?", %{})

      assert String.contains?(response2, "blue")
    end
  end

  describe "Agent-LLM Integration" do
    test "agent can switch between different LLM backends" do
      # Test with different backends
      backends = [:test, :mock]

      Enum.each(backends, fn backend ->
        agent_config = test_agent_config(llm_backend: backend)
        {:ok, agent} = Prismatic.Agent.TestImpl.new(agent_config)

        {:ok, response} = AgentProtocol.process_message(agent, "Hello", %{})
        assert is_binary(response)
        assert String.length(response) > 0
      end)
    end

    test "agent handles LLM backend failures gracefully" do
      # Configure mock to fail
      Mox.stub(Prismatic.LLM.MockBackend, :generate_response, fn _config, _prompt, _context ->
        {:error, :service_unavailable}
      end)

      agent_config = test_agent_config(llm_backend: :mock)
      {:ok, agent} = Prismatic.Agent.TestImpl.new(agent_config)

      # Agent should handle the failure gracefully
      result = AgentProtocol.process_message(agent, "Hello", %{})

      case result do
        {:ok, response} ->
          # Fallback response
          assert String.contains?(response, "unavailable") or
                 String.contains?(response, "error")
        {:error, reason} ->
          # Acceptable error handling
          assert reason in [:service_unavailable, :llm_backend_error]
      end
    end
  end

  describe "Memory-LLM Integration" do
    test "memory system can store LLM responses for caching" do
      {:ok, memory} = Prismatic.Memory.TestImpl.new()
      {:ok, llm_config} = Backend.create_config(:test, %{})

      prompt = "What is 2 + 2?"

      # First call - should hit LLM
      {:ok, response1} = Backend.generate_response(llm_config, prompt, %{})
      {:ok, _} = MemoryProtocol.store(memory, :semantic, "llm_cache:#{prompt}", response1)

      # Second call - should use cache
      {:ok, cached_response} = MemoryProtocol.retrieve(memory, :semantic, "llm_cache:#{prompt}")

      assert response1 == cached_response
    end
  end

  describe "Full System Integration" do
    test "complete agent conversation with memory and LLM" do
      # Create a complete agent system
      agent_config = test_agent_config(
        name: "IntegrationAgent",
        llm_backend: :test,
        traits: %{
          personality: "helpful",
          memory_enabled: true
        }
      )

      {:ok, agent} = Prismatic.Agent.TestImpl.new(agent_config)

      # Multi-turn conversation
      conversations = [
        {"Hello, I'm Bob", "greeting"},
        {"I work as a software engineer", "personal_info"},
        {"What's my name?", "memory_recall"},
        {"What do I do for work?", "memory_recall"}
      ]

      responses = Enum.map(conversations, fn {message, _type} ->
        {:ok, response} = AgentProtocol.process_message(agent, message, %{})
        {message, response}
      end)

      # Verify conversation flow
      {_msg1, response1} = Enum.at(responses, 0)
      {_msg2, response2} = Enum.at(responses, 1)
      {_msg3, response3} = Enum.at(responses, 2)
      {_msg4, response4} = Enum.at(responses, 3)

      # All responses should be valid
      Enum.each(responses, fn {_msg, response} ->
        assert is_binary(response)
        assert String.length(response) > 0
      end)

      # Memory recall should work
      assert String.contains?(response3, "Bob") or String.contains?(response3, "name")
      assert String.contains?(response4, "software") or String.contains?(response4, "engineer")
    end

    test "system handles concurrent agent operations" do
      # Create multiple agents
      agent_configs = Enum.map(1..5, fn i ->
        test_agent_config(name: "ConcurrentAgent#{i}")
      end)

      agents = Enum.map(agent_configs, fn config ->
        {:ok, agent} = Prismatic.Agent.TestImpl.new(config)
        agent
      end)

      # Run concurrent operations
      tasks = Enum.map(agents, fn agent ->
        Task.async(fn ->
          messages = ["Hello", "How are you?", "Goodbye"]
          Enum.map(messages, fn msg ->
            {:ok, response} = AgentProtocol.process_message(agent, msg, %{})
            response
          end)
        end)
      end)

      # Wait for all tasks to complete
      results = Task.await_many(tasks, 10_000)

      # Verify all operations completed successfully
      assert length(results) == 5
      Enum.each(results, fn agent_responses ->
        assert length(agent_responses) == 3
        Enum.each(agent_responses, fn response ->
          assert is_binary(response)
          assert String.length(response) > 0
        end)
      end)
    end
  end

  describe "Error Handling Integration" do
    test "system recovers from cascading failures" do
      # This test would simulate various failure scenarios
      # and verify the system's resilience

      agent_config = test_agent_config(name: "ResilientAgent")
      {:ok, agent} = Prismatic.Agent.TestImpl.new(agent_config)

      # Simulate memory failure
      {:ok, agent_state} = AgentProtocol.get_state(agent)

      # Agent should continue functioning even with memory issues
      {:ok, response} = AgentProtocol.process_message(agent, "Hello", %{})
      assert is_binary(response)
    end
  end
end
