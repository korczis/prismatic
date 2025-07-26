# IEx Helpers Documentation

The IEx helpers provide a powerful, developer-friendly interface for creating, testing, and debugging agents and societies directly from the Elixir interactive shell.

## 📋 Overview

The IEx helper system provides two levels of functionality:
- **Basic Helpers** (`Prismatic.IExHelpers`): Simple agent creation and interaction
- **Advanced Helpers** (`Prismatic.IExAdvanced`): Power user tools for complex scenarios and debugging

## 🚀 Basic IEx Helpers

### Agent Management

```elixir
# Simple agent creation
{:ok, agent} = Prismatic.IExHelpers.create_agent("Alice", :anthropic)

# Agent with custom configuration
{:ok, agent} = Prismatic.IExHelpers.create_agent("Bob", :openai, [
  context: "You are a helpful research assistant",
  temperature: 0.7,
  max_tokens: 1000
])

# Quick shortcuts
agent = Prismatic.IExHelpers.quick_agent("TestAgent")
agent = Prismatic.IExHelpers.test_agent()  # Pre-configured test agent
```

### Agent Interaction

```elixir
# Chat with an agent
response = Prismatic.IExHelpers.chat(agent.id, "Hello, how are you?")

# Set agent context
Prismatic.IExHelpers.set_context(agent.id, "You are now a crisis negotiator")

# Inspect agent memory
memory = Prismatic.IExHelpers.inspect_memory(agent.id)
```

## 🔧 Advanced IEx Helpers

### Batch Operations

```elixir
# Create multiple agents at once
agents = Prismatic.IExAdvanced.create_agent_batch(5, :negotiator)

# Stress test with concurrent agents
results = Prismatic.IExAdvanced.stress_test_agents(10)
```

### Crisis Scenario Setup

```elixir
# Quick crisis room setup
society = Prismatic.IExAdvanced.setup_crisis_room("Training Alpha", 1, 1)

# Create specific crisis scenario
scenario = Prismatic.IExAdvanced.crisis_scenario("Psychiatric Crisis", [
  %{role: :negotiator, name: "Officer Smith"},
  %{role: :subject, name: "Roman", context: "45, alcohol dependency, lost daughter contact"}
])
```

### Real-time Monitoring

```elixir
# Monitor society interactions
Prismatic.IExAdvanced.monitor_society(society.id, :timer.minutes(5))

# Full agent inspection
details = Prismatic.IExAdvanced.inspect_agent_full(agent.id)
# Returns: %{agent: ..., memory: ..., traits: ..., recent_changes: ...}

# Quick performance analysis
analysis = Prismatic.IExAdvanced.quick_analysis(agent.id, :last_hour)
```

### Export and Analysis

```elixir
# Export scenario session
Prismatic.IExAdvanced.export_session(society.id, :json)
Prismatic.IExAdvanced.export_session(society.id, :markdown)

# Generate training report
report = Prismatic.IExAdvanced.generate_training_report(scenario.id)
```

## 📚 Documentation Structure

- [`basic-helpers.md`](basic-helpers.md) - Core IEx helper functions
- [`advanced-helpers.md`](advanced-helpers.md) - Power user and developer tools
- [`crisis-training.md`](crisis-training.md) - Crisis scenario IEx workflows
- [`debugging.md`](debugging.md) - Debugging and inspection tools
- [`batch-operations.md`](batch-operations.md) - Bulk agent and society operations
- [`testing-patterns.md`](testing-patterns.md) - Common testing workflows
- [`api-reference.md`](api-reference.md) - Complete function reference

## 🎯 Common Workflows

### Quick Agent Testing

```elixir
# Create and test an agent quickly
agent = Prismatic.IExHelpers.test_agent()
response = Prismatic.IExHelpers.chat(agent.id, "What's 2+2?")
IO.puts(response)
```

### Crisis Training Session

```elixir
# Set up complete crisis training environment
society = Prismatic.IExAdvanced.setup_crisis_room("Crisis Room 1", 1, 1)

# Start monitoring
spawn(fn -> Prismatic.IExAdvanced.monitor_society(society.id, :timer.minutes(10)) end)

# Begin scenario
scenario = Prismatic.IExAdvanced.crisis_scenario("psychiatric_crisis", society.agents)

# Export results when done
Prismatic.IExAdvanced.export_session(society.id, :json)
```

### Development and Debugging

```elixir
# Create test agents
agents = Prismatic.IExAdvanced.create_agent_batch(3, :default)

# Inspect one thoroughly
details = Prismatic.IExAdvanced.inspect_agent_full(hd(agents).id)

# Run stress test
results = Prismatic.IExAdvanced.stress_test_agents(5)

# Analyze performance
analysis = Prismatic.IExAdvanced.quick_analysis(hd(agents).id)
```

## 🔍 Debugging Features

### Agent State Inspection

```elixir
# Get complete agent state
state = Prismatic.IExAdvanced.inspect_agent_full(agent.id)

# Check agent health
health = Prismatic.IExHelpers.agent_health(agent.id)

# View recent activity
activity = Prismatic.IExHelpers.recent_activity(agent.id, 10)
```

### Society Debugging

```elixir
# List all societies
societies = Prismatic.Society.list_all()

# Inspect society state
state = Prismatic.Society.inspect_state(society.id)

# Check member interactions
interactions = Prismatic.Society.get_recent_interactions(society.id, 20)
```

### System Monitoring

```elixir
# System health check
health = Prismatic.IExAdvanced.system_health()

# Performance metrics
metrics = Prismatic.IExAdvanced.performance_metrics()

# Active processes
processes = Prismatic.IExAdvanced.list_active_processes()
```

## 🎯 Implementation Status

- [ ] **Phase 1**: Basic IEx Helpers
  - [ ] Agent creation and management
  - [ ] Simple chat interface
  - [ ] Memory inspection
  - [ ] Context setting

- [ ] **Phase 4**: Advanced IEx Helpers
  - [ ] Crisis scenario setup
  - [ ] Batch operations
  - [ ] Real-time monitoring
  - [ ] Export capabilities

- [ ] **Phase 8**: Developer Tools
  - [ ] Advanced debugging features
  - [ ] Performance analysis
  - [ ] System monitoring
  - [ ] Testing utilities

## 🔗 Related Documentation

- [Agent System](../agents/README.md) - Core agent infrastructure
- [Society Management](../societies/README.md) - Agent group coordination
- [Scenarios](../scenarios/README.md) - Crisis training scenarios
- [Development Plan](../development-plan.md) - Overall project roadmap