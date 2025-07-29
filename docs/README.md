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
| **[Core](core/README.md)** | Essential system knowledge | [Architecture](core/architecture-overview.md), [Tech Stack](core/tech-stack.md) |
| **[Guides](guides/README.md)** | How-to and best practices | [Developer Experience](guides/developer-experience.md), [Coding Standards](guides/coding-standards.md) |
| **[Reference](reference/README.md)** | Lookups and specifications | [Glossary](reference/glossary.md), [API Endpoints](reference/api-endpoints.md) |
| **[Architecture](architecture/README.md)** | Design decisions | [ADRs](architecture/README.md), [Umbrella Structure](architecture/adr-0001-umbrella-structure.md) |
| **[Operations](operations/README.md)** | Deployment and maintenance | [Deployment](operations/deployment-procedures.md), [Troubleshooting](operations/troubleshooting.md) |

> **📍 Navigation Note**: Each section directory contains a standardized navigation section in its README.md file, providing consistent signpost navigation throughout the documentation system.

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

## Navigation System

### Standardized Navigation Structure

Every README.md file in the `/docs/` directory includes a **standardized navigation section** that serves as a directory signpost. This system ensures consistent, automated navigation that stays synchronized with the actual directory structure.

#### Navigation System Features

- **🧭 Consistent Format**: Every directory has identical navigation structure
- **🔄 Automated Synchronization**: Navigation updates automatically when directories change
- **🔗 Validated Links**: All navigation links are verified and maintained
- **📍 Breadcrumb Navigation**: Clear hierarchical context in every document
- **⚡ Mix Task Integration**: Automated tools for navigation management

#### Navigation Section Components

Each navigation section includes:

1. **Current Location Breadcrumb**: Shows hierarchical position
2. **Subdirectories Table**: Links to immediate subdirectories with descriptions
3. **Quick Links**: Parent directory, documentation home, and search
4. **Related Documentation**: Cross-references to relevant sections

#### Example Navigation Section

```markdown
<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > [Guides](README.md) > Feature Workflow

### Subdirectories

| Directory | Description | Key Documents |
|-----------|-------------|---------------|
| [`guides/`](guides/README.md) | Development workflow procedures | [Feature Branch Workflow](guides/comprehensive-feature-branch-workflow.md), [Developer Experience](guides/developer-experience.md) |
| [`_meta/`](_meta/README.md) | Documentation system metadata | [Naming Conventions](_meta/naming-conventions.md), [Cross-Reference Guide](_meta/cross-reference-guide.md) |

### Quick Links

- **📚 [Parent Directory](../README.md)** - Return to documentation home
- **🏠 [Documentation Home](../README.md)** - Main documentation index
- **🔍 [Search Documentation](reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Cross-Reference Guide](_meta/cross-reference-guide.md) - Documentation linking standards
- [Maintenance Process](_meta/maintenance-process.md) - How to update documentation
<!-- NAV_END -->
```

#### Automation Tools

The navigation system includes automated maintenance tools:

```bash
# Update all navigation sections
mix docs.nav.update

# Validate navigation integrity
mix docs.nav.validate

# Migrate existing files to new format
mix docs.nav.migrate --backup

# Show navigation system status
mix docs.nav.validate --verbose
```

#### Implementation Standards

- **HTML Comment Markers**: Navigation sections are wrapped in `<!-- NAV_START -->` and `<!-- NAV_END -->` markers
- **Consistent Positioning**: Navigation appears after document title and description, before main content
- **Automated Updates**: CI/CD pipelines automatically maintain navigation synchronization
- **Quality Validation**: Regular checks ensure all navigation links are valid and current

For complete implementation details, see:
- [Documentation Navigation Standards](guides/documentation-navigation-standards.md) - Complete system specifications
- [Navigation Templates](guides/documentation-navigation-templates.md) - Template formats and positioning rules
- [Mix Tasks Implementation](guides/documentation-navigation-mix-tasks.md) - Automation tools and usage

## Finding Information

### By Role
**Developer (New)**
1. [Developer Experience](guides/developer-experience.md) - Complete onboarding guide
2. [Architecture Overview](core/architecture-overview.md) - System understanding
3. [Coding Standards](guides/coding-standards.md) - Style and conventions

**Developer (Experienced)**
1. [Reference Materials](reference/README.md) - Quick lookups and specifications
2. [Troubleshooting](operations/troubleshooting.md) - Problem solving
3. [Architecture Decisions](architecture/README.md) - Design context and rationale

**Operations/DevOps**
1. [Deployment Procedures](operations/deployment-procedures.md) - Step-by-step deployment
2. [Monitoring Setup](operations/monitoring-setup.md) - Observability configuration
3. [Troubleshooting](operations/troubleshooting.md) - Production issue resolution

**Architect/Tech Lead**
1. [Architecture Overview](core/architecture-overview.md) - System design
2. [Architecture Decisions](architecture/README.md) - ADRs and design rationale
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
- **Directory Changes** → Automatic navigation section updates

### Quality Assurance
- **Weekly**: Link validation and cross-reference checks
- **Monthly**: Content review and accuracy validation
- **Quarterly**: Structure assessment and improvement planning

### Navigation System Maintenance
- **Automatic Updates**: Navigation sections update automatically when directory structure changes
- **Validation**: `mix docs.nav.validate` checks navigation integrity
- **CI/CD Integration**: Pipeline automation ensures navigation stays synchronized
- **Manual Override**: Use `mix docs.nav.update --force` for manual navigation updates

For detailed maintenance procedures, see [Documentation Maintenance](_meta/maintenance-process.md).

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

# Documentation navigation management
mix docs.nav.update        # Update all navigation sections
mix docs.nav.validate      # Validate navigation integrity
mix docs.nav.migrate       # Migrate existing files to navigation system
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
- **Architecture Overview**: [System Design](core/architecture-overview.md)
- **API Documentation**: [Endpoints Reference](reference/api-endpoints.md)

## Meta Documentation

### Documentation System
- [Naming Conventions](_meta/naming-conventions.md) - File and directory standards
- [Maintenance Process](_meta/maintenance-process.md) - Documentation upkeep procedures
- [Cross-Reference Guide](_meta/cross-reference-guide.md) - Linking standards and practices

### Navigation System
- [Documentation Navigation Standards](guides/documentation-navigation-standards.md) - Complete navigation system specifications
- [Navigation Templates](guides/documentation-navigation-templates.md) - Template formats and positioning rules
- [Navigation Mix Tasks](guides/documentation-navigation-mix-tasks.md) - Automation tools and implementation

---

**This documentation system is designed for both human developers and AI contributors. Keep it updated, interconnected, and focused on enabling productive development.**