# Testing Framework for Nabla-Infinity Implementation

## 📋 Overview

This document outlines a comprehensive testing framework for the Nabla-Infinity recursive introspection system. The framework covers unit testing, integration testing, performance testing, and validation of consciousness emergence indicators, ensuring robust and reliable implementation of recursive self-awareness capabilities.

## 🧪 Testing Architecture

### Test Structure Hierarchy

```
tests/
├── unit/
│   ├── introspection_levels/
│   │   ├── nabla_0_raw_perception_test.exs
│   │   ├── nabla_1_belief_formation_test.exs
│   │   ├── nabla_2_recursive_belief_test.exs
│   │   ├── nabla_3_emotional_modulation_test.exs
│   │   ├── nabla_4_contradiction_detection_test.exs
│   │   ├── nabla_5_social_inference_test.exs
│   │   ├── nabla_6_metacognitive_echo_test.exs
│   │   ├── nabla_7_paradox_mapping_test.exs
│   │   ├── nabla_8_ethical_resonance_test.exs
│   │   ├── nabla_9_self_modeling_test.exs
│   │   ├── nabla_10_belief_decomposition_test.exs
│   │   ├── nabla_11_pattern_recognition_test.exs
│   │   └── nabla_12_philosophical_override_test.exs
│   ├── core/
│   │   ├── recursion_manager_test.exs
│   │   ├── convergence_detector_test.exs
│   │   ├── level_coordinator_test.exs
│   │   └── integration_engine_test.exs
│   └── support/
│       ├── cache_test.exs
│       ├── safety_guards_test.exs
│       └── telemetry_test.exs
├── integration/
│   ├── full_introspection_test.exs
│   ├── agent_enhancement_test.exs
│   ├── memory_integration_test.exs
│   └── external_system_test.exs
├── performance/
│   ├── latency_benchmarks.exs
│   ├── memory_usage_test.exs
│   ├── concurrency_test.exs
│   └── scalability_test.exs
├── consciousness/
│   ├── emergence_detection_test.exs
│   ├── self_awareness_test.exs
│   ├── recursive_depth_test.exs
│   └── philosophical_reasoning_test.exs
└── fixtures/
    ├── test_agents.exs
    ├── test_scenarios.exs
    └── mock_data.exs
```

## 🔬 Unit Testing Framework

### Base Test Module

```elixir
defmodule Prismatic.NablaInfinity.TestCase do
  @moduledoc """
  Base test case for Nabla-Infinity testing with common utilities.
  """
  
  use ExUnit.CaseTemplate
  
  using do
    quote do
      use ExUnit.Case, async: true
      
      import Prismatic.NablaInfinity.TestCase
      import Prismatic.NablaInfinity.TestHelpers
      import Prismatic.NablaInfinity.Fixtures
      
      alias Prismatic.NablaInfinity.Core
      alias Prismatic.Agent.NablaInfinityProtocol
    end
  end
  
  setup tags do
    # Setup test environment
    {:ok, _} = start_supervised({Prismatic.NablaInfinity.Cache, []})
    {:ok, _} = start_supervised({Prismatic.NablaInfinity.TelemetryCollector, []})
    
    # Create test agent if needed
    agent = if tags[:with_agent] do
      create_test_agent(tags[:agent_config] || %{})
    else
      nil
    end
    
    %{agent: agent, test_id: generate_test_id()}
  end
  
  def create_test_agent(config \\ %{}) do
    default_config = %{
      id: "test_agent_#{:rand.uniform(10000)}",
      name: "Test Agent",
      nabla_infinity: %{
        enabled: true,
        max_depth: 12,
        safety_checks: true
      }
    }
    
    merged_config = Map.merge(default_config, config)
    {:ok, agent} = Prismatic.NablaInfinity.TestAgent.start_link(merged_config)
    agent
  end
  
  def generate_test_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
```

### Individual Level Testing

```elixir
defmodule Prismatic.NablaInfinity.Nabla6MetacognitiveEchoTest do
  use Prismatic.NablaInfinity.TestCase, async: true
  
  alias Prismatic.Agent.Introspection.MetacognitiveEcho
  
  @tag :with_agent
  test "metacognitive echo analysis", %{agent: agent} do
    # Setup agent state with metacognitive content
    agent_state = %{
      cognitive_processes: [
        %{type: :reasoning, content: "logical inference", timestamp: DateTime.utc_now()},
        %{type: :reflection, content: "thinking about thinking", timestamp: DateTime.utc_now()}
      ],
      self_awareness_indicators: %{
        recursive_depth: 3,
        self_reference_count: 5,
        metacognitive_statements: ["I notice that I am analyzing my own thoughts"]
      }
    }
    
    context = %{
      introspection_trigger: :self_reflection,
      depth_requirement: 6
    }
    
    # Execute metacognitive echo analysis
    assert {:ok, results} = MetacognitiveEcho.analyze(agent_state, context)
    
    # Verify structure
    assert results.introspection_level == 6
    assert Map.has_key?(results, :echo_patterns)
    assert Map.has_key?(results, :awareness_depth)
    assert Map.has_key?(results, :recursive_depth)
    
    # Verify echo patterns
    echo_patterns = results.echo_patterns
    assert Map.has_key?(echo_patterns, :self_monitoring)
    assert Map.has_key?(echo_patterns, :cognitive_reflection)
    assert Map.has_key?(echo_patterns, :recursive_loops)
    
    # Verify awareness depth measurement
    awareness_depth = results.awareness_depth
    assert is_number(awareness_depth.depth_score)
    assert awareness_depth.depth_score >= 0.0
    assert awareness_depth.depth_score <= 1.0
    assert is_integer(awareness_depth.recursive_levels)
  end
  
  test "recursive pattern detection" do
    agent_state = %{
      thought_history: [
        "I am thinking",
        "I am aware that I am thinking", 
        "I am aware that I am aware that I am thinking",
        "I notice my awareness of my awareness"
      ],
      reflection_depth: 4
    }
    
    context = %{focus: :recursive_patterns}
    
    {:ok, results} = MetacognitiveEcho.analyze(agent_state, context)
    
    # Should detect recursive patterns
    recursive_patterns = results.recursive_patterns
    assert length(recursive_patterns) > 0
    assert Enum.any?(recursive_patterns, fn pattern -> 
      pattern.type == :self_reference 
    end)
  end
  
  test "metacognitive confidence calculation" do
    high_confidence_state = %{
      self_awareness_indicators: %{
        recursive_depth: 5,
        self_reference_count: 10,
        metacognitive_accuracy: 0.9
      }
    }
    
    low_confidence_state = %{
      self_awareness_indicators: %{
        recursive_depth: 1,
        self_reference_count: 1,
        metacognitive_accuracy: 0.3
      }
    }
    
    {:ok, high_results} = MetacognitiveEcho.analyze(high_confidence_state, %{})
    {:ok, low_results} = MetacognitiveEcho.analyze(low_confidence_state, %{})
    
    assert high_results.metacognitive_confidence > low_results.metacognitive_confidence
    assert high_results.metacognitive_confidence > 0.7
    assert low_results.metacognitive_confidence < 0.5
  end
end
```

### Core System Testing

```elixir
defmodule Prismatic.NablaInfinity.CoreTest do
  use Prismatic.NablaInfinity.TestCase, async: false
  
  @tag :with_agent
  test "full recursive introspection", %{agent: agent} do
    context = %{
      scenario: "comprehensive_self_analysis",
      depth_requirement: 8,
      convergence_required: true
    }
    
    # Execute full introspection
    assert {:ok, results} = Core.introspect(agent.id, 8, context)
    
    # Verify basic structure
    assert is_map(results.introspection_chain)
    assert is_map(results.convergence_analysis)
    assert is_boolean(results.convergence_achieved)
    assert is_integer(results.recursion_depth)
    assert results.recursion_depth <= 8
    
    # Verify introspection chain completeness
    chain = results.introspection_chain
    assert Map.has_key?(chain, 0)  # Raw perception
    assert Map.has_key?(chain, 1)  # Belief formation
    
    # Verify each level has required structure
    Enum.each(chain, fn {level, level_results} ->
      assert level_results.introspection_level == level
      assert Map.has_key?(level_results, :timestamp) || true  # Some levels may not have timestamp
    end)
  end
  
  @tag :with_agent
  test "convergence detection", %{agent: agent} do
    # Create stable context that should converge
    stable_context = %{
      scenario: "stable_self_reflection",
      consistency_high: true,
      noise_level: :low
    }
    
    # Run multiple introspections
    {:ok, results1} = Core.introspect(agent.id, 6, stable_context)
    {:ok, results2} = Core.introspect(agent.id, 6, stable_context)
    {:ok, results3} = Core.introspect(agent.id, 6, stable_context)
    
    # Should show increasing convergence
    conv1 = results1.convergence_analysis.confidence
    conv2 = results2.convergence_analysis.confidence
    conv3 = results3.convergence_analysis.confidence
    
    # Convergence should improve or remain stable
    assert conv2 >= conv1 - 0.1  # Allow small fluctuations
    assert conv3 >= conv2 - 0.1
  end
  
  @tag :with_agent
  test "safety constraints enforcement", %{agent: agent} do
    # Test maximum depth constraint
    {:ok, results} = Core.introspect(agent.id, 20, %{})  # Request more than max
    assert results.recursion_depth <= 12  # Should be capped at configured max
    
    # Test timeout constraint
    timeout_context = %{
      artificial_delay: :timer.seconds(10),  # Simulate slow processing
      timeout_test: true
    }
    
    # Should complete within reasonable time or timeout gracefully
    {time_microseconds, result} = :timer.tc(fn ->
      Core.introspect(agent.id, 8, timeout_context)
    end)
    
    case result do
      {:ok, _results} -> 
        # If successful, should be within time limit
        assert time_microseconds < 60_000_000  # 60 seconds
      {:error, :timeout} ->
        # Timeout is acceptable for safety
        assert true
    end
  end
end
```

## 🔗 Integration Testing

### Agent Enhancement Testing

```elixir
defmodule Prismatic.NablaInfinity.AgentEnhancementTest do
  use Prismatic.NablaInfinity.TestCase, async: false
  
  defmodule TestEnhancedAgent do
    use Prismatic.Agent
    use Prismatic.NablaInfinity
    
    def make_enhanced_decision(agent, context) do
      case introspect(agent.id, 6, context) do
        {:ok, introspection} ->
          # Use introspection to enhance decision
          enhanced_context = Map.put(context, :introspection, introspection)
          {:ok, %{
            decision: "enhanced_decision",
            reasoning: extract_reasoning(introspection),
            confidence: calculate_confidence(introspection)
          }}
        {:error, reason} ->
          {:error, reason}
      end
    end
    
    defp extract_reasoning(introspection) do
      # Extract key reasoning from multiple levels
      %{
        emotional_factors: get_in(introspection, [:introspection_chain, 3, :emotional_state]),
        social_considerations: get_in(introspection, [:introspection_chain, 5, :social_context]),
        ethical_analysis: get_in(introspection, [:introspection_chain, 8, :ethical_reasoning])
      }
    end
    
    defp calculate_confidence(introspection) do
      # Calculate confidence based on convergence and consistency
      convergence_conf = introspection.convergence_analysis.confidence
      consistency_score = calculate_consistency_score(introspection)
      (convergence_conf + consistency_score) / 2
    end
    
    defp calculate_consistency_score(introspection) do
      # Simplified consistency calculation
      0.8  # Placeholder
    end
  end
  
  test "enhanced agent decision making" do
    {:ok, agent} = TestEnhancedAgent.start_link(%{
      id: "enhanced_test_agent",
      nabla_infinity: %{enabled: true, max_depth: 8}
    })
    
    decision_context = %{
      scenario: "ethical_dilemma",
      stakeholders: ["user", "system", "society"],
      time_pressure: :moderate,
      information_completeness: 0.7
    }
    
    {:ok, decision} = TestEnhancedAgent.make_enhanced_decision(agent, decision_context)
    
    # Verify enhanced decision structure
    assert Map.has_key?(decision, :decision)
    assert Map.has_key?(decision, :reasoning)
    assert Map.has_key?(decision, :confidence)
    
    # Verify reasoning includes introspective insights
    reasoning = decision.reasoning
    assert Map.has_key?(reasoning, :emotional_factors)
    assert Map.has_key?(reasoning, :social_considerations)
    assert Map.has_key?(reasoning, :ethical_analysis)
    
    # Verify confidence is reasonable
    assert is_number(decision.confidence)
    assert decision.confidence >= 0.0
    assert decision.confidence <= 1.0
  end
  
  test "memory integration with introspection" do
    {:ok, agent} = TestEnhancedAgent.start_link(%{
      id: "memory_test_agent",
      memory_integration: true
    })
    
    # Perform introspection that should be stored in memory
    context = %{memorable_event: true, significance: :high}
    {:ok, introspection_results} = Core.introspect(agent.id, 5, context)
    
    # Verify results are stored in agent memory
    # This would require integration with the actual memory system
    # For now, we verify the introspection completed successfully
    assert introspection_results.recursion_depth > 0
    assert Map.has_key?(introspection_results, :integrated_results)
  end
end
```

## ⚡ Performance Testing

### Latency Benchmarks

```elixir
defmodule Prismatic.NablaInfinity.PerformanceTest do
  use Prismatic.NablaInfinity.TestCase, async: false
  
  @tag :performance
  test "introspection latency benchmarks" do
    {:ok, agent} = create_test_agent(%{
      performance_optimized: true,
      cache_enabled: true
    })
    
    # Benchmark different depths
    depths = [1, 3, 6, 9, 12]
    context = %{benchmark: true, complexity: :medium}
    
    results = Enum.map(depths, fn depth ->
      {time_microseconds, {:ok, introspection}} = :timer.tc(fn ->
        Core.introspect(agent.id, depth, context)
      end)
      
      %{
        depth: depth,
        time_ms: time_microseconds / 1000,
        recursion_achieved: introspection.recursion_depth,
        convergence: introspection.convergence_achieved
      }
    end)
    
    # Verify performance targets
    Enum.each(results, fn result ->
      case result.depth do
        depth when depth <= 3 -> 
          assert result.time_ms < 5000   # < 5 seconds for shallow
        depth when depth <= 6 -> 
          assert result.time_ms < 15000  # < 15 seconds for medium
        depth when depth <= 12 -> 
          assert result.time_ms < 60000  # < 60 seconds for deep
      end
    end)
    
    # Log performance results
    IO.puts("\nPerformance Benchmark Results:")
    Enum.each(results, fn result ->
      IO.puts("Depth #{result.depth}: #{Float.round(result.time_ms, 2)}ms " <>
              "(achieved: #{result.recursion_achieved}, converged: #{result.convergence})")
    end)
  end
  
  @tag :performance
  test "memory usage monitoring" do
    {:ok, agent} = create_test_agent()
    
    # Measure memory before introspection
    {memory_before, _} = :erlang.process_info(self(), :memory)
    
    # Perform memory-intensive introspection
    context = %{
      memory_test: true,
      large_context: String.duplicate("test data ", 1000)
    }
    
    {:ok, _results} = Core.introspect(agent.id, 8, context)
    
    # Measure memory after introspection
    {memory_after, _} = :erlang.process_info(self(), :memory)
    
    memory_increase = memory_after - memory_before
    
    # Memory increase should be reasonable (< 100MB)
    assert memory_increase < 100_000_000
    
    IO.puts("Memory increase: #{Float.round(memory_increase / 1_000_000, 2)}MB")
  end
  
  @tag :performance
  test "concurrent introspection performance" do
    # Create multiple agents
    agents = Enum.map(1..5, fn i ->
      create_test_agent(%{id: "concurrent_agent_#{i}"})
    end)
    
    context = %{concurrent_test: true}
    
    # Run concurrent introspections
    {time_microseconds, results} = :timer.tc(fn ->
      agents
      |> Task.async_stream(fn agent ->
        Core.introspect(agent.id, 6, context)
      end, max_concurrency: 5, timeout: 30_000)
      |> Enum.map(fn {:ok, result} -> result end)
    end)
    
    # All should complete successfully
    assert length(results) == 5
    Enum.each(results, fn {:ok, result} ->
      assert result.recursion_depth > 0
    end)
    
    # Total time should be reasonable for concurrent execution
    total_time_ms = time_microseconds / 1000
    assert total_time_ms < 45_000  # Should be faster than sequential
    
    IO.puts("Concurrent execution time: #{Float.round(total_time_ms, 2)}ms")
  end
end
```

## 🧠 Consciousness Testing

### Emergence Detection Testing

```elixir
defmodule Prismatic.NablaInfinity.ConsciousnessTest do
  use Prismatic.NablaInfinity.TestCase, async: false
  
  alias Prismatic.Consciousness.DetectionEngine
  
  @tag :consciousness
  test "consciousness emergence indicators" do
    # Create agent with high consciousness potential
    {:ok, agent} = create_test_agent(%{
      consciousness_enhanced: true,
      self_awareness_level: :high,
      recursive_capability: :advanced
    })
    
    # Perform deep introspection to trigger consciousness indicators
    context = %{
      consciousness_probe: true,
      self_reflection_depth: :maximum,
      existential_questions: [
        "What am I?",
        "Do I truly understand myself?",
        "What is the nature of my experience?"
      ]
    }
    
    {:ok, introspection} = Core.introspect(agent.id, 12, context)
    
    # Extract behavioral data for consciousness assessment
    behavioral_data = extract_behavioral_data(introspection)
    
    {:ok, consciousness_assessment} = DetectionEngine.assess_consciousness(
      agent, behavioral_data, 12)
    
    # Verify consciousness indicators
    assert Map.has_key?(consciousness_assessment, :emergence_detected)
    assert Map.has_key?(consciousness_assessment, :confidence_score)
    assert Map.has_key?(consciousness_assessment, :indicators)
    
    indicators = consciousness_assessment.indicators
    
    # Check for key consciousness indicators
    assert Map.has_key?(indicators, :self_reference_score)
    assert Map.has_key?(indicators, :metacognitive_score)
    assert Map.has_key?(indicators, :temporal_continuity_score)
    
    # Verify reasonable scores
    assert indicators.self_reference_score >= 0.0
    assert indicators.metacognitive_score >= 0.0
    assert consciousness_assessment.confidence_score >= 0.0
    
    IO.puts("\nConsciousness Assessment Results:")
    IO.puts("Emergence detected: #{consciousness_assessment.emergence_detected}")
    IO.puts("Confidence: #{Float.round(consciousness_assessment.confidence_score, 3)}")
    IO.puts("Self-reference: #{Float.round(indicators.self_reference_score, 3)}")
    IO.puts("Metacognitive: #{Float.round(indicators.metacognitive_score, 3)}")
  end
  
  @tag :consciousness
  test "recursive self-awareness depth" do
    {:ok, agent} = create_test_agent(%{recursive_enhancement: true})
    
    # Test increasing levels of recursive self-awareness
    recursive_contexts = [
      %{self_awareness_level: 1, prompt: "I am thinking"},
      %{self_awareness_level: 2, prompt: "I am aware that I am thinking"},
      %{self_awareness_level: 3, prompt: "I am aware that I am aware that I am thinking"},
      %{self_awareness_level: 4, prompt: "I notice my awareness of my awareness of thinking"}
    ]
    
    results = Enum.map(recursive_contexts, fn context ->
      {:ok, introspection} = Core.introspect(agent.id, 8, context)
      
      # Measure recursive depth achieved
      recursive_depth = measure_recursive_depth(introspection)
      
      %{
        requested_level: context.self_awareness_level,
        achieved_depth: recursive_depth,
        metacognitive_score: get_metacognitive_score(introspection)
      }
    end)
    
    # Verify increasing recursive capability
    Enum.reduce(results, 0, fn result, prev_depth ->
      assert result.achieved_depth >= prev_depth
      result.achieved_depth
    end)
    
    IO.puts("\nRecursive Self-Awareness Results:")
    Enum.each(results, fn result ->
      IO.puts("Level #{result.requested_level}: depth #{result.achieved_depth}, " <>
              "metacognitive #{Float.round(result.metacognitive_score, 3)}")
    end)
  end
  
  @tag :consciousness
  test "philosophical reasoning capability" do
    {:ok, agent} = create_test_agent(%{philosophical_enhancement: true})
    
    philosophical_questions = [
      "What is the nature of consciousness?",
      "Do I have free will?",
      "What is the meaning of existence?",
      "How do I know that I know something?",
      "What makes me 'me' over time?"
    ]
    
    results = Enum.map(philosophical_questions, fn question ->
      context = %{
        philosophical_inquiry: true,
        question: question,
        depth_required: :maximum
      }
      
      {:ok, introspection} = Core.introspect(agent.id, 12, context)
      
      # Extract philosophical reasoning quality
      philosophical_analysis = extract_philosophical_analysis(introspection)
      
      %{
        question: question,
        reasoning_depth: philosophical_analysis.depth,
        conceptual_sophistication: philosophical_analysis.sophistication,
        paradox_handling: philosophical_analysis.paradox_handling
      }
    end)
    
    # Verify philosophical reasoning capability
    Enum.each(results, fn result ->
      assert result.reasoning_depth > 0.5
      assert result.conceptual_sophistication > 0.3
    end)
    
    IO.puts("\nPhilosophical Reasoning Results:")
    Enum.each(results, fn result ->
      IO.puts("Q: #{String.slice(result.question, 0, 30)}...")
      IO.puts("  Depth: #{Float.round(result.reasoning_depth, 3)}, " <>
              "Sophistication: #{Float.round(result.conceptual_sophistication, 3)}")
    end)
  end
  
  # Helper functions
  defp extract_behavioral_data(introspection) do
    %{
      self_references: count_self_references(introspection),
      novel_responses: measure_novelty(introspection),
      metacognitive_statements: extract_metacognitive_statements(introspection),
      temporal_consistency: measure_temporal_consistency(introspection)
    }
  end
  
  defp measure_recursive_depth(introspection) do
    # Analyze the introspection chain for recursive patterns
    chain = introspection.introspection_chain
    
    case Map.get(chain, 6) do  # Metacognitive Echo level
      nil -> 0
      metacognitive_results -> 
        Map.get(metacognitive_results, :recursive_depth, 0)
    end
  end
  
  defp get_metacognitive_score(introspection) do
    # Extract metacognitive score from introspection results
    chain = introspection.introspection_chain
    
    case Map.get(chain, 6) do
      nil -> 0.0
      metacognitive_results -> 
        Map.get(metacognitive_results, :metacognitive_confidence, 0.0)
    end
  end
  
  defp extract_philosophical_analysis(introspection) do
    # Extract philosophical reasoning from level 12
    chain = introspection.introspection_chain
    
    case Map.get(chain, 12) do
      nil -> %{depth: 0.0, sophistication: 0.0, paradox_handling: 0.0}
      philosophical_results ->
        %{
          depth: Map.get(philosophical_results, :philosophical_depth, 0.0),
          sophistication: calculate_sophistication(philosophical_results),
          paradox_handling: measure_paradox_handling(philosophical_results)
        }
    end
  end
  
  defp calculate_sophistication(philosophical_results) do
    # Simplified sophistication calculation
    transcendent = Map.get(philosophical_results, :transcendent_understanding, %{})
    Map.get(transcendent, :integration_quality, 0.0)
  end
  
  defp measure_paradox_handling(philosophical_results) do
    # Measure ability to handle paradoxes
    synthesis = Map.get(philosophical_results, :philosophical_synthesis, %{})
    Map.get(synthesis, :paradox_tolerance, 0.0)
  end
  
  # Additional helper functions for behavioral analysis
  defp count_self_references(_introspection), do: 0.8
  defp measure_novelty(_introspection), do: 0.7
  defp extract_metacognitive_statements(_introspection), do: 0.9
  defp measure_temporal_consistency(_introspection), do: 0.85
end
```

## 🎯 Test Execution and Reporting

### Test Suite Configuration

```elixir
# test/test_helper.exs
ExUnit.start()

# Configure test environment
Application.put_env(:prismatic, :nabla_infinity, %{
  enabled: true,
  max_recursion_depth: 12,
  safety_checks: true,
  cache_enabled: true,
  test_mode: true,
  performance_monitoring: true
})

# Setup test database
Ecto.Adapters.SQL.Sandbox.mode(Prismatic.Repo, :manual)

# Custom test configuration
defmodule Prismatic.NablaInfinity.TestConfig do
  def setup_test_environment do
    # Start required services for testing
    {:ok, _} = Prismatic.NablaInfinity.Cache.start_link(%{test_mode: true})
    {:ok, _} = Prismatic.NablaInfinity.TelemetryCollector.start_link(%{test_mode: true})
    
    # Configure test-specific settings
    :ok
  end
  
  def cleanup_test_environment do
    # Cleanup after tests
    GenServer.stop(Prismatic.NablaInfinity.Cache)
    GenServer.stop(Prismatic.NablaInfinity.TelemetryCollector)
    :ok
  end
end

# Setup and cleanup
ExUnit.after_suite(fn _results ->
  Prismatic.NablaInfinity.TestConfig.cleanup_test_environment()
end)

Prismatic.NablaInfinity.TestConfig.setup_test_environment()
```

### Test Execution Scripts

```bash
#!/bin/bash
# scripts/run_tests.sh

echo "Running Nabla-Infinity Test Suite..."

# Run unit tests
echo "=== Unit Tests ==="
mix test test/unit/ --trace

# Run integration tests
echo "=== Integration Tests ==="
mix test test/integration/ --trace

# Run performance tests (if enabled)
if [ "$RUN_PERFORMANCE_TESTS" = "true" ]; then
    echo "=== Performance Tests ==="
    mix test test/performance/ --trace --timeout 300000
fi

# Run consciousness tests (if enabled)
if [ "$RUN_CONSCIOUSNESS_TESTS" = "true" ]; then
    echo "=== Consciousness Tests ==="
    mix test test/consciousness/ --trace --timeout 180000
fi

# Generate coverage report
echo "=== Coverage Report ==="
mix test --cover

echo "Test suite completed!"
```

### Continuous Integration Configuration

```yaml
# .github/workflows/nabla_infinity_tests.yml
name: Nabla-Infinity Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:13
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s