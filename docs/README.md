# Prismatic Documentation

Welcome to the Prismatic project documentation. This modular documentation system provides comprehensive guides, references, and procedures for development and operations.

## Quick Navigation

### 🚀 Getting Started
- **New Developer?** Start with [Developer Experience](guides/developer-experience.md)
- **Need to Deploy?** See [Deployment Procedures](operations/deployment-procedures.md)
- **Having Issues?** Check [Troubleshooting](operations/troubleshooting.md)
- **Understanding the System?** Read [Architecture Overview](core/architecture-overview.md)

### 📚 Documentation Sections

| Section | Purpose | Key Documents |
|---------|---------|---------------|
| **[Core](core/)** | Essential system knowledge | [Architecture](core/architecture-overview.md), [Tech Stack](core/tech-stack.md) |
| **[Guides](guides/)** | How-to and best practices | [Developer Experience](guides/developer-experience.md), [Coding Standards](guides/coding-standards.md) |
| **[Reference](reference/)** | Lookups and specifications | [Glossary](reference/glossary.md), [API Docs](reference/api-endpoints.md) |
| **[Architecture](architecture/)** | Design decisions | [ADRs](architecture/), [System Diagrams](architecture/system-diagrams.md) |
| **[Operations](operations/)** | Deployment and maintenance | [Deployment](operations/deployment-procedures.md), [Troubleshooting](operations/troubleshooting.md) |

## Documentation Principles

### Modular Design
Each document has a **single, focused purpose** and can be maintained independently:
- **Atomic Updates**: Change one thing without affecting others
- **Clear Ownership**: Each domain has designated maintainers
- **Cross-References**: Rich linking between related concepts

### AI-Assisted Maintenance
- **Human Oversight**: Architectural decisions and business logic
- **AI Contribution**: Code examples, API documentation, consistency checks
- **Collaborative Process**: AI generates, humans validate and approve

### Quality Standards
- **Consistent Formatting**: Standardized structure and style
- **Living Documentation**: Updated with code changes
- **Validated Links**: Cross-references checked and maintained

## Finding Information

### By Role
**Developer (New)**
1. [Developer Experience](guides/developer-experience.md) - Complete onboarding guide
2. [Architecture Overview](core/architecture-overview.md) - System understanding
3. [Coding Standards](guides/coding-standards.md) - Style and conventions

**Developer (Experienced)**
1. [Reference Materials](reference/) - Quick lookups and specifications
2. [Troubleshooting](operations/troubleshooting.md) - Problem solving
3. [Architecture Decisions](architecture/) - Design context and rationale

**Operations/DevOps**
1. [Deployment Procedures](operations/deployment-procedures.md) - Step-by-step deployment
2. [Monitoring Setup](operations/monitoring-setup.md) - Observability configuration
3. [Troubleshooting](operations/troubleshooting.md) - Production issue resolution

**Architect/Tech Lead**
1. [Architecture Overview](core/architecture-overview.md) - System design
2. [Architecture Decisions](architecture/) - ADRs and design rationale
3. [System Diagrams](architecture/system-diagrams.md) - Visual representations

### By Task
**Setting Up Development Environment**
→ [Developer Experience: Onboarding](guides/developer-experience.md#onboarding-process)

**Understanding Code Organization**
→ [Architecture Overview: Structure](core/architecture-overview.md#umbrella-application-structure)

**Deploying to Production**
→ [Deployment Procedures](operations/deployment-procedures.md#production-deployment)

**Debugging Issues**
→ [Troubleshooting Guide](operations/troubleshooting.md)

**Finding Definitions**
→ [Glossary](reference/glossary.md)

## Documentation Maintenance

### Update Triggers
- **Code Changes** → Update related guides and references
- **Architecture Decisions** → Create ADRs and update overviews  
- **New Features** → Update user guides and API documentation
- **Bug Fixes** → Update troubleshooting guides

### Quality Assurance
- **Weekly**: Link validation and cross-reference checks
- **Monthly**: Content review and accuracy validation
- **Quarterly**: Structure assessment and improvement planning

For detailed maintenance procedures, see [Documentation Maintenance](/_meta/maintenance-process.md).

## Contributing to Documentation

### Making Changes
1. **Small Fixes**: Direct edits with descriptive commit messages
2. **Major Updates**: Feature branch with review process
3. **Structural Changes**: Discuss with documentation owners first

### Standards
- Follow [Naming Conventions](_meta/naming-conventions.md)
- Use [Cross-Reference Guide](_meta/cross-reference-guide.md) for linking
- Maintain [single responsibility](_meta/naming-conventions.md#content-principles) per file

### AI Collaboration
- AI generates initial content following established patterns
- Humans review for accuracy and business logic
- Documentation updated systematically with code changes

## Quick Reference

### Essential Commands
```bash
# Start development
mix phx.server

# Run tests  
mix test

# Deploy to production
mix release

# Format code
mix format
```

### Key Directories
```
apps/prismatic/          # Core business logic
apps/prismatic_web/      # Web interface  
config/                  # Configuration
docs/                    # This documentation
```

### Important Links
- **Application**: [http://localhost:4000](http://localhost:4000)
- **Dashboard**: [http://localhost:4000/dev/dashboard](http://localhost:4000/dev/dashboard)
- **Code Repository**: [`apps/`](../apps/)
- **Configuration**: [`config/`](../config/)

## Meta Documentation
- [Naming Conventions](_meta/naming-conventions.md) - File and directory standards
- [Maintenance Process](_meta/maintenance-process.md) - Documentation upkeep procedures
- [Cross-Reference Guide](_meta/cross-reference-guide.md) - Linking standards and practices

---

**This documentation system is designed for both human developers and AI contributors. Keep it updated, interconnected, and focused on enabling productive development.**