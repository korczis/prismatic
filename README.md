# Prismatic

**AI Agent Framework with Phoenix Foundation - Building Toward Consciousness**

Prismatic is an AI Agent Framework built on Elixir/Phoenix that combines a **working foundation** with an **ambitious vision**. Currently implementing core protocols and infrastructure, with planned advancement toward the revolutionary **Nabla-Infinity (∇∞) consciousness framework**.

## 🎯 Implementation Status

### ✅ **IMPLEMENTED** (Working Today)
- **Phoenix Umbrella Foundation**: Complete apps/prismatic + apps/prismatic_web structure
- **LLM Backend System**: Multi-provider abstraction (OpenAI, Anthropic) with circuit breakers
- **Memory Protocol System**: Multi-layered architecture (Cachex, Nebulex, Mnesia, Layered backends)
- **Event System**: Protocol-based event bus with multiple backend implementations
- **Document Processing**: Broadway pipeline with enrichers and streaming capabilities
- **Infrastructure**: Circuit breakers, retry logic, comprehensive telemetry and monitoring
- **Developer Experience**: Mix tasks, IEx helpers, testing framework, live reload

### 🚧 **IN PROGRESS** (Defined Interfaces, Implementation Underway)
- **Agent Protocol**: Core agent behavior contracts defined, converting to working implementations
- **Supervision Architecture**: Root supervisor structure designed, fault-tolerant process management
- **Web Interface**: LiveView foundation ready, agent management UI in development

### 📋 **PLANNED** (Vision & Roadmap)
- **Nabla-Infinity Framework**: Consciousness levels ∇⁰ to ∇∞ with recursive introspection
- **Crisis Intervention**: Mental health crisis detection, negotiation support, therapy simulation
- **Multi-Agent Societies**: Coordinated agent hierarchies and collective intelligence
- **Educational Systems**: AI tutoring with adaptive learning and personalization
- **Advanced Applications**: Algorithmic trading, content moderation, psychological analysis

## 🧠 Current Capabilities

### Phoenix Framework Foundation
- **⚡ Fast Setup**: `mix setup` gets you running in minutes
- **🔄 Live Reload**: Automatic browser refresh on code changes
- **🧪 Comprehensive Testing**: Built-in test framework with parallel execution
- **📊 Real-time Monitoring**: Phoenix LiveDashboard for development insights
- **🔒 Security First**: CSRF protection, XSS prevention, secure sessions
- **📱 Real-time Features**: LiveView for interactive, real-time interfaces

### Working AI Infrastructure
- **Multi-Provider LLMs**: OpenAI, Anthropic integration with unified interface
- **Fault-Tolerant Memory**: Multi-layered memory system with persistence
- **Event-Driven Architecture**: Protocol-based communication with multiple backends
- **Circuit Breaker Protection**: Automatic failure detection and recovery
- **Comprehensive Monitoring**: Telemetry, metrics, and observability built-in

### Development & Documentation Excellence
- **📋 Modular Documentation**: Status-aware docs with implementation transparency
- **🔗 Rich Cross-Referencing**: Interconnected knowledge base linking vision to reality
- **🤖 AI-Assisted Development**: Patterns for human-AI collaboration in development
- **👥 Collaborative Workflows**: Clear ownership and transparent development processes

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
# or with IEx for interactive development
iex -S mix phx.server
```

4. Visit [`http://localhost:4000`](http://localhost:4000) to access the Prismatic interface.

### Quick Start with Working Systems

```elixir
# Work with LLM backends (✅ Implemented)
{:ok, config} = Prismatic.LLM.Backend.create_config(:openai, %{
  api_key: "your-api-key",
  model: "gpt-4"
})

{:ok, response} = Prismatic.LLM.Backend.generate_response(
  config,
  "What is the meaning of life?",
  %{temperature: 0.7, max_tokens: 1000}
)

# Use memory systems (✅ Implemented)
{:ok, memory_config} = Prismatic.Memory.Protocol.create_config(:layered, %{
  backends: %{
    working: {:cachex, %{name: :working_memory}},
    semantic: {:mnesia, %{table: :semantic_memory}}
  }
})

{:ok, _} = Prismatic.Memory.Protocol.store(
  memory_config,
  :working,
  "current_task",
  %{task: "analyze_document", status: :in_progress}
)

{:ok, value} = Prismatic.Memory.Protocol.retrieve(memory_config, :working, "current_task")

# Future: Agent interactions (🚧 In Development)
# {:ok, agent} = Prismatic.Agent.start_link(agent_type: :basic)
# response = Prismatic.Agent.process(agent, "Analyze this problem...")
```

## 🏗️ Architecture Overview

**Phoenix Umbrella Structure** - Separates concerns with implemented core systems and planned AI capabilities:

### Actual Implementation Structure
```
prismatic/
├── apps/
│   ├── prismatic/          # 🧠 Core Business Logic & AI Infrastructure
│   │   ├── lib/prismatic/  # Core business logic
│   │   └── ...
│   │
│   └── prismatic_web/      # 🌐 Web Interface & Real-time UI
│       ├── lib/prismatic_web/
│       └── ...
│
├── config/                 # 🔧 Shared configuration
├── docs/                   # 📚 Modular documentation system
└── lib/                    # 🏗️ Shared libraries and protocols (Current Implementation)
    ├── prismatic/
    │   ├── agent/          # 🚧 Agent protocols (placeholder interfaces)
    │   ├── llm/            # ✅ LLM backend system (full implementation)
    │   ├── memory/         # ✅ Memory protocol system (full implementation)
    │   ├── event/          # ✅ Event system (full implementation)
    │   ├── document/       # ✅ Document processing (full implementation)
    │   ├── fs/             # ✅ File system utilities
    │   └── supervisor/     # 🚧 Supervision architecture (placeholder)
    │
    ├── prismatic_web/      # ✅ Phoenix web foundation
    │   ├── controllers/    # Basic web controllers
    │   ├── live/           # LiveView foundation
    │   └── components/     # UI component system
    │
    └── mix/                # ✅ Development tools and tasks
```

### Working Components (✅ Implemented)

- **LLM Backend** ([`lib/prismatic/llm/backend.ex`](lib/prismatic/llm/backend.ex)) - Multi-provider LLM abstraction (OpenAI, Anthropic) with circuit breakers and retry logic
- **Memory System** ([`lib/prismatic/memory/protocol.ex`](lib/prismatic/memory/protocol.ex)) - Multi-layered memory protocol with Cachex, Nebulex, Mnesia backends
- **Event System** ([`lib/prismatic/event/protocol.ex`](lib/prismatic/event/protocol.ex)) - Protocol-based event bus with multiple backend implementations
- **Document Processing** ([`lib/prismatic/document/`](lib/prismatic/document/)) - Broadway pipeline with enrichers for content processing

### In Development Components (🚧 Defined Interfaces)

- **Agent Protocol** ([`lib/prismatic/agent/protocol.ex`](lib/prismatic/agent/protocol.ex)) - Core agent behavior contracts, implementation in progress
- **Root Supervisor** ([`lib/prismatic/supervisor/root.ex`](lib/prismatic/supervisor/root.ex)) - Supervision tree structure defined, implementation planned

**Current Architecture Principle**: Core infrastructure and protocols in `lib/`, apps for domain-specific logic when implemented.

## 🛠️ Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Backend** | Elixir 1.17+ + Phoenix 1.8 | Web framework and AI agent runtime |
| **Database** | PostgreSQL 17+ + Ecto | Data persistence and ORM |
| **Frontend** | Phoenix LiveView + Tailwind CSS + Flowbite | Interactive server-rendered UI |
| **HTTP Server** | Bandit | Modern HTTP/1.1 and HTTP/2 server |
| **Real-time** | Phoenix PubSub + Channels | Live updates and agent messaging |
| **AI Integration** | Multi-provider LLM backends | AI model abstraction and integration |
| **Design** | Protocol-driven architecture + SOLID principles | Maintainable and extensible codebase |

## 📚 Documentation

This project uses a **status-aware documentation architecture** that clearly distinguishes between working implementations and planned features. Comprehensive documentation is available in the [`docs/`](docs/) directory.

### 🎯 Find What You Need

| I want to... | Go to | Status |
|--------------|-------|--------|
| **Get started with working systems** | [`docs/README.md`](docs/README.md) | ✅ Ready |
| **Understand current architecture** | [`docs/development-plan.md`](docs/development-plan.md) | ✅ Current |
| **Work with LLM backends** | [`lib/prismatic/llm/backend.ex`](lib/prismatic/llm/backend.ex) | ✅ Implemented |
| **Use memory systems** | [`lib/prismatic/memory/protocol.ex`](lib/prismatic/memory/protocol.ex) | ✅ Implemented |
| **Explore agent protocols** | [`lib/prismatic/agent/protocol.ex`](lib/prismatic/agent/protocol.ex) | 🚧 In Progress |
| **Learn about future vision** | [`docs/nabla-infinity/`](docs/nabla-infinity/) | 📋 Planned |
| **Browse complete documentation** | [`docs/README.md`](docs/README.md) | ✅ Ready |

### 📚 Documentation Structure

#### 🛠️ Working Systems (Ready to Use)
- **[Memory Systems](docs/memory/)** - Multi-layered memory architecture with proven backends
- **[LLM Integration](docs/llm/)** - Multi-provider LLM abstraction layer
- **[Event Systems](docs/events/)** - Protocol-based event bus implementation
- **[Development Tools](docs/iex-helpers/)** - IEx helpers and development utilities

#### 🚧 Current Development (In Progress)
- **[Agent Systems](docs/agents/)** - Agent protocols converting from placeholders to implementations
- **[Architecture](docs/architecture/)** - System design and architectural evolution
- **[Web Interface](docs/ui/)** - LiveView interface development

#### 📋 Future Vision (Planned Features)
- **[Nabla-Infinity Framework](docs/nabla-infinity/)** - Consciousness framework theoretical foundation
- **[Crisis Intervention](docs/applications/crisis-intervention.md)** - Mental health application concepts
- **[Multi-Agent Societies](docs/societies/)** - Agent coordination and collective intelligence
- **[Advanced Applications](docs/applications/)** - Industry-specific use cases and implementations

#### 📖 Project Resources
- **[Development Plan](docs/development-plan.md)** - Current status and roadmap with honest progress tracking
- **[Documentation Standards](docs/DOCUMENTATION_STANDARDS.md)** - Status-aware documentation guidelines
- **[GHL License](docs/ghl/)** - General Honest License legal framework

## 🤖 AI-Assisted Development

This project embraces **AI collaboration** as a core development practice:

### Human + AI Workflow
```
Human Planning → AI Implementation → Human Review → Collaborative Refinement
```

### AI Responsibilities
- **Code Generation**: Following established patterns and conventions
- **Documentation**: Automated updates and cross-reference maintenance  
- **Testing**: Comprehensive test case generation with edge cases
- **Quality Assurance**: Security analysis and performance optimization
- **Agent Development**: AI agent behavior implementation and optimization

### Human Oversight
- **Architecture Decisions**: System design and technology choices
- **Business Logic**: Domain rules and complex algorithms
- **Code Review**: Final approval and quality validation
- **Strategic Direction**: Feature planning and technical vision
- **Consciousness Framework**: Nabla-Infinity theoretical development

## 🔧 Development Commands

```bash
# Development
mix phx.server              # Start development server
mix phx.server --open       # Start server and open browser

# Database  
mix ecto.create             # Create database
mix ecto.migrate            # Run migrations
mix ecto.reset              # Reset database (dev only)

# Testing & Quality
mix test                    # Run all tests
mix test --cover            # Run with coverage report
mix dialyzer                # Run static analysis
mix ci                      # Run all quality checks

# Code Quality
mix format                  # Format code
mix credo                   # Static analysis (if configured)

# Assets & Documentation
mix assets.build            # Build development assets
mix assets.deploy           # Build production assets
mix docs                    # Generate HTML documentation
just docs-serve             # Serve documentation locally
```

## 🚦 Current Project Status

Prismatic is in **Phase 2: Core Protocol Implementation** with solid foundation complete and working systems:

### ✅ **COMPLETE** (Production Ready)
- **Phoenix Umbrella Foundation**: Full apps structure with LiveView and modern tooling
- **LLM Backend System**: Complete multi-provider abstraction with OpenAI, Anthropic, circuit breakers
- **Memory Protocol System**: Full implementation with Cachex, Nebulex, Mnesia, layered backends
- **Event System**: Complete protocol-based event bus with multiple backend implementations
- **Document Processing**: Broadway pipeline with enrichers for content processing
- **Infrastructure**: Circuit breakers, retry logic, comprehensive telemetry and monitoring
- **Developer Experience**: Mix tasks, IEx helpers, testing framework, documentation system

### 🚧 **IN PROGRESS** (Active Development)
- **Agent Protocol Implementation**: Converting placeholder interfaces to working implementations
- **Root Supervision Architecture**: Implementing fault-tolerant process management
- **Web Agent Management**: LiveView interface for agent monitoring and control

### 📋 **PLANNED** (Next Phases)
- **Multi-Agent Societies**: Agent coordination and collective intelligence systems
- **Nabla-Infinity Framework**: Consciousness levels ∇⁰ to ∇∞ with recursive introspection
- **Crisis Intervention Applications**: Mental health crisis detection and negotiation support
- **Educational AI Systems**: Tutoring and adaptive learning implementations
- **Advanced Applications**: Algorithmic trading, content moderation, psychological analysis

### 🎯 **Current Sprint Focus**
- Converting agent protocols from placeholders to working implementations
- Implementing basic agent behaviors and message processing
- Creating agent supervision and lifecycle management
- Building web interface for agent monitoring

## 🔗 Legacy Integration

Prismatic builds upon extensive research and development from related projects:

### External Components
- **`external/prismatic-legacy/`** - Advanced AI framework with sophisticated trait system and distributed architecture
- **`external/nabla-infinity/`** - Theoretical consciousness framework and research
- **`external/prismatic-old/`** - Earlier evolutionary versions and experimental implementations

These external components provide a rich foundation of battle-tested code, theoretical frameworks, and architectural patterns that can be integrated into the current Prismatic implementation.

## 🤝 Contributing

We welcome contributions to Prismatic! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### For Human Developers
1. **Start with working systems**: Explore [`docs/README.md`](docs/README.md) for current implementation status
2. **Work with LLM/Memory**: Get hands-on with [`lib/prismatic/llm/backend.ex`](lib/prismatic/llm/backend.ex) and [`lib/prismatic/memory/protocol.ex`](lib/prismatic/memory/protocol.ex)
3. **Review development plan**: Check [`docs/development-plan.md`](docs/development-plan.md) for current progress
4. **Contribute to agent implementation**: Help convert placeholders to working code in [`lib/prismatic/agent/protocol.ex`](lib/prismatic/agent/protocol.ex)

### For AI Contributors
1. **Focus on working code**: Use implemented systems (LLM, Memory, Events) as patterns for new development
2. **Maintain status transparency**: Always indicate implementation vs. planning in documentation updates
3. **Build incrementally**: Convert placeholders to implementations step-by-step
4. **Preserve vision**: Keep ambitious goals while delivering practical progress
5. **Include comprehensive tests**: Especially for protocol implementations and backend systems

### For Researchers & Visionaries
1. **Explore theoretical framework**: Review [`docs/nabla-infinity/`](docs/nabla-infinity/) for consciousness research
2. **Design applications**: Contribute concepts in [`docs/applications/`](docs/applications/)
3. **Academic content**: Add specialized knowledge to [`docs/kompendium/`](docs/kompendium/)
4. **Bridge theory to practice**: Help plan implementation paths for advanced features

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Follow conventional commit messages
4. Ensure all tests pass (`mix ci`)
5. Submit a pull request

```
Feature Planning → Implementation → Testing → Documentation → Review → Deployment
      ↑                ↑              ↑            ↑           ↑         ↑
   Human-led        AI-assisted   AI-generated  AI-updated  Human     Automated
```

## 📞 Getting Help & Support

- **📖 Documentation Issues**: Check [`docs/operations/troubleshooting.md`](docs/operations/troubleshooting.md)
- **🏗️ Architecture Questions**: Review [`docs/core/architecture-overview.md`](docs/core/architecture-overview.md)  
- **🔧 Development Problems**: See [`docs/guides/developer-experience.md`](docs/guides/developer-experience.md)
- **📝 Terms and Concepts**: Look up in [`docs/reference/glossary.md`](docs/reference/glossary.md)
- **🚀 Deployment Issues**: Follow [`docs/operations/deployment-procedures.md`](docs/operations/deployment-procedures.md)
- **🤖 AI Agent Questions**: Explore [`docs/agents/`](docs/agents/)
- **Issues**: [GitHub Issues](https://github.com/your-org/prismatic/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-org/prismatic/discussions)
- **Phoenix Framework**: [Official Phoenix Guides](https://hexdocs.pm/phoenix/overview.html)

## 📄 License

This project is licensed under the **General Honest License (GHL)** - see the [GHL documentation](docs/ghl/) for complete details. The GHL is designed to ensure honest use and prevent misuse of advanced AI systems while promoting open collaboration and innovation.

## 🌟 Acknowledgments

Prismatic represents years of research and development in consciousness-level AI systems, multi-agent architectures, and ethical AI frameworks. Special recognition goes to the theoretical foundations provided by the Nabla-Infinity consciousness framework and the practical implementations from the Prismatic legacy systems.

---

**🎯 Prismatic** - *Advancing the frontier of consciousness-level AI systems through elegant Phoenix engineering and revolutionary theoretical frameworks.*

**This README serves as your entry point to the Prismatic project. For detailed information on any topic, explore the comprehensive documentation in [`docs/`](docs/).**
