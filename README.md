# Prismatic

A Phoenix umbrella application built with Elixir, featuring AI-assisted development workflows and modular documentation architecture.

## 🚀 Quick Start

```bash
# Clone and setup
git clone https://github.com/org/prismatic.git
cd prismatic
mix setup

# Start development server
mix phx.server
```

Visit [`http://localhost:4000`](http://localhost:4000) to see the application.

## 📖 Documentation

This project uses a **modular documentation architecture** designed for both human developers and AI contributors. All comprehensive documentation is located in the [`docs/`](docs/) directory.

### 🎯 Find What You Need

| I want to... | Go to |
|--------------|-------|
| **Get started as a new developer** | [`docs/guides/developer-experience.md`](docs/guides/developer-experience.md) |
| **Understand the system architecture** | [`docs/core/architecture-overview.md`](docs/core/architecture-overview.md) |
| **Learn coding standards** | [`docs/guides/coding-standards.md`](docs/guides/coding-standards.md) |
| **Deploy to production** | [`docs/operations/deployment-procedures.md`](docs/operations/deployment-procedures.md) |
| **Troubleshoot issues** | [`docs/operations/troubleshooting.md`](docs/operations/troubleshooting.md) |
| **Look up terms and concepts** | [`docs/reference/glossary.md`](docs/reference/glossary.md) |
| **Browse all documentation** | [`docs/README.md`](docs/README.md) |

### 📚 Documentation Structure

```
docs/
├── 📋 README.md                    # Documentation navigation hub
├── 🏗️  core/                       # Essential system knowledge
│   ├── architecture-overview.md   # System design and principles
│   └── tech-stack.md              # Technology details and rationale
├── 📖 guides/                      # How-to and best practices  
│   ├── developer-experience.md    # Complete developer onboarding
│   └── coding-standards.md        # Code style and conventions
├── 📚 reference/                   # Lookups and specifications
│   └── glossary.md                # Terms, concepts, and definitions
├── 🏛️  architecture/               # Design decisions and ADRs
│   └── adr-0001-umbrella-structure.md
├── ⚙️  operations/                 # Deployment and maintenance
│   ├── deployment-procedures.md   # Step-by-step deployment guide
│   └── troubleshooting.md         # Problem diagnosis and solutions  
└── 🔧 _meta/                      # Documentation system metadata
    ├── naming-conventions.md      # File and directory standards
    ├── maintenance-process.md     # Documentation upkeep procedures
    └── cross-reference-guide.md   # Linking standards and practices
```

## 🏗️ Architecture Overview

**Umbrella Application Structure** - Separates concerns into distinct applications:

```
prismatic/
├── apps/
│   ├── prismatic/          # 🧠 Core Business Logic
│   │   ├── contexts/       # Domain logic (Accounts, Content, etc.)
│   │   ├── schemas/        # Database models and changesets
│   │   └── repo.ex         # Database access layer
│   │
│   └── prismatic_web/      # 🌐 Web Interface  
│       ├── controllers/    # HTTP request handling
│       ├── live/           # LiveView interactive components
│       └── components/     # Reusable UI elements
│
├── config/                 # 🔧 Shared configuration
└── docs/                   # 📚 Modular documentation system
```

**Key Principle**: Business logic stays in `prismatic`, web concerns in `prismatic_web`.

For complete architectural details: [`docs/core/architecture-overview.md`](docs/core/architecture-overview.md)

## 🛠️ Technology Stack

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Backend** | Elixir + Phoenix 1.7.21 | Web framework and business logic |
| **Database** | PostgreSQL + Ecto | Data persistence and ORM |
| **Frontend** | Phoenix LiveView + Tailwind CSS | Interactive server-rendered UI |
| **HTTP Server** | Bandit | Modern HTTP/1.1 and HTTP/2 server |
| **Real-time** | Phoenix PubSub + Channels | Live updates and messaging |

Complete technology details: [`docs/core/tech-stack.md`](docs/core/tech-stack.md)

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

### Human Oversight
- **Architecture Decisions**: System design and technology choices
- **Business Logic**: Domain rules and complex algorithms
- **Code Review**: Final approval and quality validation
- **Strategic Direction**: Feature planning and technical vision

**Learn more**: [`docs/guides/developer-experience.md#ai-assisted-development`](docs/guides/developer-experience.md#ai-assisted-development)

## 🔧 Development Commands

```bash
# Development
mix phx.server              # Start development server
mix phx.server --open       # Start server and open browser

# Database  
mix ecto.create             # Create database
mix ecto.migrate            # Run migrations
mix ecto.reset              # Reset database (dev only)

# Testing
mix test                    # Run all tests
mix test --cover            # Run with coverage report

# Code Quality
mix format                  # Format code
mix credo                   # Static analysis (if configured)

# Assets
mix assets.build            # Build development assets
mix assets.deploy           # Build production assets
```

## 🌟 Key Features

### Developer Experience
- **⚡ Fast Setup**: `mix setup` gets you running in minutes
- **🔄 Live Reload**: Automatic browser refresh on code changes
- **🧪 Comprehensive Testing**: Built-in test framework with parallel execution
- **📊 Real-time Monitoring**: Phoenix LiveDashboard for development insights

### Production Ready
- **🚀 Zero-Downtime Deployments**: Blue-green deployment strategies
- **📈 Horizontal Scaling**: Stateless design with clustering support
- **🔒 Security First**: CSRF protection, XSS prevention, secure sessions
- **📱 Real-time Features**: LiveView for interactive, real-time interfaces

### Documentation Excellence
- **📋 Modular Design**: Atomic, single-purpose documentation files
- **🔗 Rich Cross-Referencing**: Interconnected knowledge base
- **🤖 AI-Maintained**: Automated consistency and accuracy checks
- **👥 Collaborative**: Clear ownership and maintenance processes

## 🚦 Project Status

- ✅ **Foundation**: Phoenix umbrella app with core structure
- ✅ **Documentation**: Comprehensive modular documentation system  
- ✅ **Development Tools**: Live reloading, testing, monitoring setup
- ✅ **AI Workflow**: Established patterns for AI-assisted development
- ⏳ **Business Logic**: Domain contexts to be implemented
- ⏳ **Authentication**: User management system to be built
- ⏳ **Core Features**: Application-specific functionality pending

## 🤝 Contributing

### For Human Developers
1. **Read the docs**: Start with [`docs/guides/developer-experience.md`](docs/guides/developer-experience.md)
2. **Follow standards**: Review [`docs/guides/coding-standards.md`](docs/guides/coding-standards.md)
3. **Understand architecture**: Study [`docs/core/architecture-overview.md`](docs/core/architecture-overview.md)
4. **Maintain documentation**: Update relevant docs with code changes

### For AI Contributors
1. **Reference documentation**: Use [`docs/`](docs/) directory for context and patterns
2. **Follow conventions**: Adhere to established coding and documentation standards
3. **Maintain cross-references**: Update related documentation with changes
4. **Generate comprehensive tests**: Include edge cases and error scenarios
5. **Include human review**: Always require human approval for architectural decisions

### Development Process
```
Feature Planning → Implementation → Testing → Documentation → Review → Deployment
      ↑                ↑              ↑            ↑           ↑         ↑
   Human-led        AI-assisted   AI-generated  AI-updated  Human     Automated
```

## 📞 Getting Help

- **📖 Documentation Issues**: Check [`docs/operations/troubleshooting.md`](docs/operations/troubleshooting.md)
- **🏗️ Architecture Questions**: Review [`docs/core/architecture-overview.md`](docs/core/architecture-overview.md)  
- **🔧 Development Problems**: See [`docs/guides/developer-experience.md`](docs/guides/developer-experience.md)
- **📝 Terms and Concepts**: Look up in [`docs/reference/glossary.md`](docs/reference/glossary.md)
- **🚀 Deployment Issues**: Follow [`docs/operations/deployment-procedures.md`](docs/operations/deployment-procedures.md)

## 📄 License

[Your License Here]

---

**🎯 This README serves as your entry point to the Prismatic project. For detailed information on any topic, explore the comprehensive documentation in [`docs/`](docs/).**
