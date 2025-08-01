# Documentation Naming Conventions

This document establishes standardized naming patterns for the modular documentation system.

## File Naming Patterns

### Primary Files
Use kebab-case with descriptive, action-oriented names:
- `developer-experience.md` - Developer onboarding and workflow
- `coding-standards.md` - Code style and conventions  
- `style-guide.md` - Visual and UI style guidelines
- `deployment-procedures.md` - Step-by-step deployment process
- `troubleshooting.md` - Problem diagnosis and solutions
- `architecture-overview.md` - High-level system design

### Supporting Files
Use descriptive prefixes for specialized content:
- `api-[domain].md` - API documentation for specific domains
- `guide-[task].md` - Task-specific how-to guides
- `reference-[topic].md` - Reference materials and lookups
- `adr-[number]-[title].md` - Architecture Decision Records

## Directory Organization

```
docs/
├── _meta/                    # Documentation system metadata
│   ├── naming-conventions.md # This file
│   ├── maintenance-process.md # Documentation maintenance
│   └── cross-reference-guide.md # Linking standards
├── core/                     # Essential project knowledge
│   ├── architecture-overview.md
│   ├── tech-stack.md
│   └── project-structure.md
├── guides/                   # Task-oriented how-to guides
│   ├── developer-experience.md
│   ├── coding-standards.md
│   └── style-guide.md
├── reference/                # Reference materials and lookups
│   ├── api-endpoints.md
│   ├── glossary.md
│   └── command-reference.md
├── architecture/             # System design and decisions
│   ├── adr-[number]-[title].md
│   └── system-diagrams.md
├── operations/               # Deployment and maintenance
│   ├── deployment-procedures.md
│   ├── monitoring-setup.md
│   └── troubleshooting.md
└── shared/                   # Templates and common elements
    ├── templates/
    └── fragments/
```

## Linking Conventions

### Relative Links
Use relative paths with descriptive link text:
```markdown
See [coding standards](../guides/coding-standards.md) for detailed conventions.
```

### Cross-References
Include "Related" sections at the end of each file:
```markdown
## Related Documentation
- [Architecture Overview](../core/architecture-overview.md)
- [Deployment Procedures](../operations/deployment-procedures.md)
- [Troubleshooting Guide](../operations/troubleshooting.md)
```

### Fragment Links
Link to specific sections within documents:
```markdown
Review the [error handling patterns](../guides/coding-standards.md) section.
```

## Content Principles

### Single Responsibility
Each file should have one clear purpose:
- ✅ `troubleshooting.md` - Diagnostic procedures and solutions
- ❌ `development-guide.md` - Too broad, multiple concerns

### Atomic Updates
Files should be updatable independently:
- Changes to deployment procedures don't affect coding standards
- API documentation updates don't impact troubleshooting guides
- Architecture decisions are isolated from operational procedures

### Discoverable Content
Use descriptive titles and clear section headers:
```markdown
# Troubleshooting Common Development Issues

## Database Connection Problems
## Asset Compilation Failures  
## LiveView Mount Errors
```

## Version Control Strategy

### Granular Changes
- One logical change per file modification
- Separate commits for different documentation domains
- Clear commit messages referencing affected documentation areas

### Collaborative Editing
- Each file can be edited independently by different team members
- Merge conflicts minimized by atomic file structure
- Cross-references updated systematically after structural changes

## Maintenance Guidelines

### Regular Review
- Monthly review of cross-references for accuracy
- Quarterly assessment of content relevance
- Annual restructuring evaluation

### Update Triggers
- Code changes require related documentation updates
- New features trigger guide creation
- Architecture changes require ADR documentation
- Operational changes update procedures and troubleshooting

See also:
- [Maintenance Process](maintenance-process.md)
- [Cross-Reference Guide](cross-reference-guide.md)