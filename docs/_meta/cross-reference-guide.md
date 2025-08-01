# Cross-Reference Guide

This document establishes standards for linking between documentation files in the modular system.

## Linking Principles

### Semantic Linking
Links should provide context about the relationship:
```markdown
<!-- ✅ Good: Descriptive link text -->
For database setup details, see [deployment procedures](../operations/deployment-procedures.md).

<!-- ❌ Poor: Generic link text -->
See [here](../operations/deployment-procedures.md) for more info.
```

### Bidirectional References
When one document references another, consider adding a backlink:
```markdown
<!-- In coding-standards.md -->
Database queries must follow the [performance guidelines](../operations/performance-optimization.md#query-patterns).

<!-- In performance-optimization.md -->
These patterns are enforced by our [coding standards](../guides/coding-standards.md).
```

## Link Types and Formats

### Document Links
```markdown
<!-- Link to entire document -->
[Developer Experience Guide](../guides/developer-experience.md)

<!-- Link to specific section -->
[Error Handling Patterns](../guides/coding-standards.md)

<!-- Link with context -->
Review the [troubleshooting procedures](../operations/troubleshooting.md) before deploying.
```

### Fragment Identifiers
Use consistent heading anchor patterns:
```markdown
## Database Connection Issues
<!-- Anchor: #database-connection-issues -->

### PostgreSQL Setup Problems  
<!-- Anchor: #postgresql-setup-problems -->
```

### External References
```markdown
<!-- Code references -->
See implementation in [`apps/prismatic/lib/prismatic/accounts.ex`](../../apps/prismatic/lib/prismatic/accounts.ex)

<!-- Issue references -->
Related to issue [#123](https://github.com/org/prismatic/issues/123)

<!-- External documentation -->
Follows [Phoenix conventions](https://hexdocs.pm/phoenix/overview.html)
```

## Standard Cross-Reference Patterns

### "Related Documentation" Sections
Every document should end with relevant cross-references:
```markdown
## Related Documentation
- [Architecture Overview](../core/architecture-overview.md) - System design context
- [Deployment Procedures](../operations/deployment-procedures.md) - Implementation steps  
- [Troubleshooting](../operations/troubleshooting.md) - Common issues and solutions
```

### Inline References
Use inline references for immediate context:
```markdown
When implementing authentication (see [security guidelines](../guides/security-guidelines.md)), ensure proper session management.
```

### Breadcrumb Navigation
Include navigation context in complex documents:
```markdown
# API Endpoint Reference

**Navigation**: [Home](../README.md) > [Reference](../reference/README.md) > API Endpoints

**Related**: [Authentication](../guides/security-guidelines.md) | [Error Handling](../guides/coding-standards.md)
```

## Cross-Reference Maintenance

### Automated Validation
Implement checks for:
- **Link integrity**: All relative links resolve to existing files
- **Anchor validation**: Section references point to existing headings
- **Orphaned content**: Files not referenced from navigation or other documents
- **Circular references**: Avoid infinite reference loops

### Update Procedures
When modifying document structure:
1. **Before changes**: Document all incoming references to the file
2. **During changes**: Update section headings and anchors carefully
3. **After changes**: Update all cross-references to reflect new structure
4. **Validation**: Run link checker to verify all references work

### Reference Templates
Use consistent patterns for common reference types:

#### Architecture Decision References
```markdown
This implements [ADR-0001: Umbrella Structure](../architecture/adr-0001-umbrella-structure.md), which established our application architecture.
```

#### Procedure References
```markdown
Follow the [standard deployment process](../operations/deployment-procedures.md) for production releases.
```

#### Troubleshooting References
```markdown
If you encounter issues, check the [troubleshooting guide](../operations/troubleshooting.md#[specific-section]) for solutions.
```

## Navigation Patterns

### Hub Documents
Each directory should have a README.md that serves as a navigation hub:
```markdown
# Reference Documentation

## Available References
- [API Endpoints](api-endpoints.md) - REST and GraphQL API documentation
- [Command Reference](command-reference.md) - CLI commands and options
- [Glossary](glossary.md) - Terms and definitions

## Quick Links
- **For Developers**: [Coding Standards](../guides/coding-standards.md)
- **For Operations**: [Deployment Procedures](../operations/deployment-procedures.md)  
- **For Architecture**: [System Overview](../core/architecture-overview.md)
```

### Topic Clustering
Group related references together:
```markdown
## Authentication & Security
- [Security Guidelines](../guides/security-guidelines.md)
- [Authentication API](../reference/api-authentication.md)
- [Security Architecture](../architecture/adr-0003-security-model.md)

## Database & Performance  
- [Database Setup](../operations/database-setup.md)
- [Query Optimization](../guides/performance-optimization.md)
- [Schema Reference](../reference/database-schema.md)
```

## Link Validation Strategy

### Automated Checks
```bash
# Example validation commands
find docs -name "*.md" -exec grep -l "\[.*\](.*\.md" {} \; | xargs link-checker
markdown-link-check docs/**/*.md
```

### Manual Review Process
- **Weekly**: Review recently modified files for broken references
- **Monthly**: Comprehensive validation of all cross-references
- **Quarterly**: Assessment of reference patterns and navigation effectiveness

### Error Handling
When links break:
1. **Immediate**: Add TODO comment near broken link
2. **Short-term**: Create issue with priority label
3. **Resolution**: Fix link and validate related references
4. **Prevention**: Add to automated validation patterns

## Best Practices

### Link Density
- **Moderate linking**: Too many links create cognitive overload
- **Strategic placement**: Link at decision points where readers need context
- **Context-appropriate**: Links should enhance understanding, not distract

### Link Maintenance
- **Prefer relative paths**: Absolute paths break when repositories move
- **Use descriptive anchors**: Avoid generic section names like "overview"
- **Version considerations**: Links to external resources may need version specificity

### Reader Experience
- **Clear expectations**: Link text should indicate what readers will find
- **Avoid deep nesting**: Long chains of references can confuse navigation
- **Provide context**: Include brief explanations of why links are relevant

## Related Documentation
- [Naming Conventions](naming-conventions.md) - File and directory naming standards
- [Maintenance Process](maintenance-process.md) - Documentation maintenance procedures
- [Developer Experience](../guides/developer-experience.md) - How developers interact with documentation