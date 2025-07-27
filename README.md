# Prismatic

**A Revolutionary AI Agent Framework for Consciousness-Level Multi-Agent Systems**

Prismatic is a sophisticated AI Agent Framework built with Elixir/Phoenix, designed for advanced multi-agent systems with consciousness-level capabilities. The framework implements the groundbreaking Nabla-Infinity (∇∞) consciousness framework, enabling recursive introspection levels from ∇⁰ to ∇∞ for unprecedented AI system sophistication.

## 🧠 Key Features

- **Consciousness-Level AI**: Implementation of the revolutionary Nabla-Infinity framework with recursive introspection levels
- **Multi-Agent Systems**: Protocol-driven architecture supporting complex agent interactions and hierarchies
- **Fault-Tolerant Design**: Built on Elixir's supervision trees with fault isolation and self-healing capabilities
- **Advanced Memory Systems**: Multi-layered memory protocols for persistent agent knowledge and experience
- **LLM Backend Abstraction**: Multi-provider LLM integration supporting various AI models and providers
- **Real-Time Capabilities**: Phoenix LiveView integration for dynamic, real-time agent interactions
- **Crisis Intervention**: Specialized applications for crisis negotiation, therapy simulation, and ethical AI systems
- **Educational Systems**: Advanced AI tutoring and adaptive learning implementations

## 🏗️ Architecture

Prismatic follows a protocol-driven, fault-tolerant design built on solid engineering principles:

### Core Components

- **Agent System** ([`lib/prismatic/agent/protocol.ex`](lib/prismatic/agent/protocol.ex)) - Core agent behavior protocol defining agent capabilities and interactions
- **LLM Backend** ([`lib/prismatic/llm/backend.ex`](lib/prismatic/llm/backend.ex)) - Multi-provider LLM abstraction layer for seamless AI model integration
- **Memory System** ([`lib/prismatic/memory/protocol.ex`](lib/prismatic/memory/protocol.ex)) - Multi-layered memory protocol for agent knowledge persistence
- **Supervision Architecture** ([`lib/prismatic/supervisor/root.ex`](lib/prismatic/supervisor/root.ex)) - Hierarchical supervision trees ensuring system reliability

### Technology Stack

- **Elixir 1.17+** with **Phoenix 1.8** framework
- **PostgreSQL** with **Ecto ORM** for data persistence
- **Phoenix LiveView** with **Tailwind CSS** and **Flowbite** components
- **Protocol-driven design** following **SOLID principles**
- **Hierarchical supervision trees** with fault isolation

## 🚀 Getting Started

### Prerequisites

- Elixir 1.17+ and Erlang/OTP 28+
- PostgreSQL 17+
- Node.js (for asset compilation)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/your-org/prismatic.git
cd prismatic
```

2. Install dependencies and setup the database:
```bash
mix setup
```

3. Start the Phoenix server:
```bash
mix phx.server
# or with IEx
iex -S mix phx.server
```

4. Visit [`localhost:4000`](http://localhost:4000) to access the Prismatic interface.

### Quick Start with Nabla-Infinity

```elixir
# Start an agent with consciousness level ∇³
{:ok, agent} = Prismatic.Agent.start_link(consciousness_level: 3)

# Enable recursive introspection
Prismatic.Agent.enable_introspection(agent, recursive: true)

# Interact with the agent
response = Prismatic.Agent.process(agent, "Analyze this ethical dilemma...")
```

## 📚 Documentation

Comprehensive documentation is available in the [`docs/`](docs/) directory:

### Core Documentation
- **[Architecture Overview](docs/architecture/)** - System design and architectural decisions
- **[Agent Systems](docs/agents/)** - Agent protocols, behaviors, and implementations
- **[Memory Systems](docs/memory/)** - Multi-layered memory architecture
- **[API Reference](docs/api/)** - Complete API documentation

### Nabla-Infinity Framework
- **[Theory](docs/nabla-infinity/theory/)** - Complete theoretical framework (∇⁰ to ∇∞)
- **[Implementation](docs/nabla-infinity/implementation/)** - System architecture and integration guides
- **[Applications](docs/nabla-infinity/applications/)** - Real-world applications and use cases

### Specialized Applications
- **[Crisis Intervention](docs/applications/crisis-intervention.md)** - Crisis negotiation and intervention systems
- **[Educational Systems](docs/applications/)** - AI tutoring and adaptive learning
- **[Ethical AI](docs/nabla-infinity/applications/ai-ethics.md)** - Ethical reasoning and decision-making

### Development Resources
- **[Development Plan](docs/development-plan.md)** - Project roadmap and milestones
- **[Documentation Standards](docs/DOCUMENTATION_STANDARDS.md)** - Documentation guidelines
- **[GHL License](docs/ghl/)** - General Honest License framework

## 🔧 Development Status

Prismatic is currently in its **foundation phase** with core architectural components implemented:

- ✅ **Protocol Definitions** - Core agent, memory, and LLM protocols established
- ✅ **Supervision Architecture** - Fault-tolerant supervision trees implemented
- ✅ **Documentation Framework** - Comprehensive documentation structure
- ✅ **Nabla-Infinity Theory** - Complete theoretical framework documented
- 🚧 **Agent Implementations** - Core agent behaviors (placeholder implementations)
- 🚧 **Memory Systems** - Multi-layered memory protocols (in development)
- 🚧 **LLM Integration** - Multi-provider backend abstraction (in progress)
- 📋 **Real-world Applications** - Crisis intervention and educational systems (planned)

## 🔗 Legacy Integration

Prismatic builds upon extensive research and development from related projects:

### External Components
- **`external/prismatic-legacy/`** - Advanced AI framework with sophisticated trait system and distributed architecture
- **`external/nabla-infinity/`** - Theoretical consciousness framework and research
- **`external/prismatic-old/`** - Earlier evolutionary versions and experimental implementations

These external components provide a rich foundation of battle-tested code, theoretical frameworks, and architectural patterns that can be integrated into the current Prismatic implementation.

## 🧪 Testing and Quality Assurance

### Running Tests
```bash
# Run the full test suite
mix test

# Run with coverage
mix test --cover

# Run static analysis
mix dialyzer

# Run all quality checks
mix ci
```

### Documentation Generation
```bash
# Generate HTML documentation
mix docs

# Serve documentation locally
just docs-serve
```

## 🤝 Contributing

We welcome contributions to Prismatic! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details on:

- Code style and standards
- Testing requirements
- Documentation expectations
- Pull request process
- Community guidelines

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Follow conventional commit messages
4. Ensure all tests pass (`mix ci`)
5. Submit a pull request

## 📄 License

This project is licensed under the **General Honest License (GHL)** - see the [GHL documentation](docs/ghl/) for complete details. The GHL is designed to ensure honest use and prevent misuse of advanced AI systems while promoting open collaboration and innovation.

## 🌟 Acknowledgments

Prismatic represents years of research and development in consciousness-level AI systems, multi-agent architectures, and ethical AI frameworks. Special recognition goes to the theoretical foundations provided by the Nabla-Infinity consciousness framework and the practical implementations from the Prismatic legacy systems.

## 📞 Support and Community

- **Documentation**: [docs/](docs/)
- **Issues**: [GitHub Issues](https://github.com/your-org/prismatic/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/prismatic/discussions)
- **Phoenix Framework**: [Official Phoenix Guides](https://hexdocs.pm/phoenix/overview.html)

---

**Prismatic** - *Advancing the frontier of consciousness-level AI systems through elegant engineering and revolutionary theoretical frameworks.*
