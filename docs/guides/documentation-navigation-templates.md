# Documentation Navigation Templates and Positioning Rules

## Overview

This document provides the complete templates and positioning rules for implementing standardized navigation sections across all README.md files in the `/docs/` directory. These templates ensure consistency and provide clear guidelines for both automated tools and manual documentation updates.

## Standard Navigation Template

### Complete Template Structure

```markdown
<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > [Current Section](../current-section/README.md) > Current Document

### Subdirectories

| Directory | Description | Key Documents |
|-----------|-------------|---------------|
| [`subdirectory1/`](subdirectory1/) | Brief description of subdirectory1 purpose | [Key Doc 1](subdirectory1/key-doc.md), [Key Doc 2](subdirectory1/other-doc.md) |
| [`subdirectory2/`](subdirectory2/) | Brief description of subdirectory2 purpose | [Important Guide](subdirectory2/guide.md) |

### Quick Links

- **📚 [Parent Directory](../README.md)** - Return to parent level
- **🏠 [Documentation Home](../../README.md)** - Main documentation index
- **🔍 [Search Documentation](../../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Cross-Reference Guide](../../_meta/cross-reference-guide.md) - Documentation linking standards
- [Maintenance Process](../../_meta/maintenance-process.md) - How to update documentation
<!-- NAV_END -->
```

## Template Components Specification

### 1. HTML Comment Markers

**Purpose**: Define navigation section boundaries for automated processing

**Format**:
```html
<!-- NAV_START -->
[Navigation content]
<!-- NAV_END -->
```

**Rules**:
- Must be exact text: `NAV_START` and `NAV_END`
- Must be on separate lines
- No additional text on marker lines
- Case sensitive
- Only one navigation section per file

### 2. Navigation Header

**Format**: `## Navigation`

**Rules**:
- Always use level 2 heading (`##`)
- Exact text: "Navigation" (not "Contents", "Index", etc.)
- No additional styling or emojis in header
- Must be first element after `NAV_START` marker

### 3. Current Location (Breadcrumb)

**Format**: `**Current Location**: [Link1](path) > [Link2](path) > Current Document`

**Rules**:
- Use bold formatting for "Current Location" label
- Separate links with ` > ` (space-greater-than-space)
- Last item should be plain text (current document title)
- Links use relative paths from current document
- Maximum breadcrumb depth: 5 levels

**Examples**:
```markdown
<!-- Root level -->
**Current Location**: Documentation Home

<!-- Second level -->
**Current Location**: [Home](../README.md) > Guides

<!-- Third level -->
**Current Location**: [Home](../../README.md) > [Guides](../README.md) > Feature Branch Workflow

<!-- Deep nesting -->
**Current Location**: [Home](../../../README.md) > [Guides](../../README.md) > [Workflows](../README.md) > Advanced Features
```

### 4. Subdirectories Table

**Format**:
```markdown
### Subdirectories

| Directory | Description | Key Documents |
|-----------|-------------|---------------|
| [`dirname/`](dirname/) | Description text | [Doc1](dirname/doc1.md), [Doc2](dirname/doc2.md) |
```

**Rules**:
- Always use level 3 heading (`###`)
- Use table format with exactly 3 columns
- Directory column: Use backticks around directory name with trailing slash
- Directory column: Link to directory (not README.md specifically)
- Description column: Single sentence, no period at end
- Key Documents column: Maximum 3 documents, comma-separated
- Sort directories alphabetically
- If no subdirectories exist, show: `*No subdirectories in this section.*`

**Key Documents Selection Priority**:
1. README.md files (implied, don't list explicitly)
2. Most frequently accessed documents
3. Entry-point documents for newcomers
4. Recently updated important content

### 5. Quick Links Section

**Format**:
```markdown
### Quick Links

- **📚 [Parent Directory](../README.md)** - Return to parent level
- **🏠 [Documentation Home](path-to-root/README.md)** - Main documentation index
- **🔍 [Search Documentation](path-to-search)** - Find terms and concepts
```

**Rules**:
- Always use level 3 heading (`###`)
- Use unordered list with consistent emoji icons
- Use bold formatting for link text
- Include brief description after dash
- Adjust paths based on current document depth
- Standard emojis: 📚 (parent), 🏠 (home), 🔍 (search)

**Path Calculation**:
- Parent Directory: Always `../README.md`
- Documentation Home: `../` repeated for each level above root
- Search Documentation: Typically points to `reference/glossary.md`

### 6. Related Documentation Section

**Format**:
```markdown
### Related Documentation

- [Cross-Reference Guide](path-to-meta/cross-reference-guide.md) - Documentation linking standards
- [Maintenance Process](path-to-meta/maintenance-process.md) - How to update documentation
- [Custom Link 1](path) - Custom description
- [Custom Link 2](path) - Custom description
```

**Rules**:
- Always use level 3 heading (`###`)
- Use unordered list format
- Include brief description after dash
- Always include standard cross-reference and maintenance links
- Add custom links relevant to current section
- Maximum 5 links total
- Sort with standard links first, then custom links

## Positioning Rules

### Document Structure Requirements

Every README.md file should follow this structure:

```markdown
# Document Title

Brief description of the document's purpose (1-3 paragraphs maximum).

<!-- NAV_START -->
## Navigation
[Navigation content as specified above]
<!-- NAV_END -->

## First Content Section

[Main document content begins here]
```

### Positioning Guidelines

#### 1. After Title and Description
- Navigation must come after the main title (`# Title`)
- Navigation must come after the brief description
- Brief description should be 1-3 paragraphs maximum
- Leave one blank line before `<!-- NAV_START -->`

#### 2. Before Main Content
- Navigation must come before all other content sections
- Navigation should be within the first 20% of document
- Leave one blank line after `<!-- NAV_END -->`

#### 3. Visual Separation
- Clear visual separation from title/description above
- Clear visual separation from main content below
- Consistent whitespace around navigation section

### Position Examples

#### Correct Positioning
```markdown
# Deployment Procedures

Step-by-step procedures for deploying Prismatic to different environments.

<!-- NAV_START -->
## Navigation
[Navigation content]
<!-- NAV_END -->

## Pre-Deployment Checklist

[Main content begins here]
```

#### Incorrect Positioning
```markdown
# Deployment Procedures

## Pre-Deployment Checklist

Before deploying, ensure all requirements are met.

<!-- NAV_START -->
## Navigation
[Navigation content]
<!-- NAV_END -->

[Rest of content]
```

## Template Variations by Document Type

### 1. Root Directory Template (docs/README.md)

```markdown
<!-- NAV_START -->
## Navigation

**Current Location**: Documentation Home

### Documentation Sections

| Section | Description | Key Documents |
|---------|-------------|---------------|
| [`core/`](core/) | Essential system architecture and design | [Architecture Overview](core/architecture-overview.md), [Tech Stack](core/tech-stack.md) |
| [`guides/`](guides/) | Step-by-step implementation guides | [Developer Experience](guides/developer-experience.md), [Coding Standards](guides/coding-standards.md) |
| [`operations/`](operations/) | Deployment and maintenance procedures | [Deployment Procedures](operations/deployment-procedures.md), [Troubleshooting](operations/troubleshooting.md) |
| [`reference/`](reference/) | Quick reference materials | [Glossary](reference/glossary.md), [API Reference](reference/api-endpoints.md) |
| [`architecture/`](architecture/) | Architectural decisions and design | [System Diagrams](architecture/system-diagrams.md) |

### Quick Links

- **🚀 [Getting Started](guides/developer-experience.md)** - New developer onboarding
- **📖 [API Documentation](reference/api-endpoints.md)** - Complete API reference
- **🔧 [Troubleshooting](operations/troubleshooting.md)** - Common issues and solutions

### Related Documentation

- [Cross-Reference Guide](_meta/cross-reference-guide.md) - Documentation linking standards
- [Maintenance Process](_meta/maintenance-process.md) - How to update documentation
- [Documentation Navigation Standards](guides/documentation-navigation-standards.md) - Navigation system standards
<!-- NAV_END -->
```

### 2. Section Directory Template (e.g., docs/guides/README.md)

```markdown
<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > Guides

### Available Guides

| Guide | Description | Key Topics |
|-------|-------------|------------|
| [`developer-experience.md`](developer-experience.md) | Complete onboarding guide for new developers | Setup, Tools, Workflow |
| [`coding-standards.md`](coding-standards.md) | Code quality and style guidelines | Formatting, Best Practices, Review |
| [`feature-branch-workflow.md`](comprehensive-feature-branch-workflow.md) | Complete feature branch workflow system | Branching, CI/CD, Automation |

### Quick Links

- **📚 [Parent Directory](../README.md)** - Return to documentation home
- **🏠 [Documentation Home](../README.md)** - Main documentation index
- **🔍 [Search Documentation](../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Cross-Reference Guide](../_meta/cross-reference-guide.md) - Documentation linking standards
- [Maintenance Process](../_meta/maintenance-process.md) - How to update documentation
- [Operations Guides](../operations/README.md) - Deployment and maintenance procedures
<!-- NAV_END -->
```

### 3. Deep Directory Template (e.g., docs/guides/workflows/README.md)

```markdown
<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../../README.md) > [Guides](../README.md) > Workflows

### Workflow Documentation

| Workflow | Description | Key Documents |
|----------|-------------|---------------|
| [`feature-development/`](feature-development/) | Feature branch development process | [Branch Creation](feature-development/branch-creation.md), [Code Review](feature-development/code-review.md) |
| [`release-management/`](release-management/) | Release and deployment workflows | [Release Process](release-management/release-process.md), [Hotfix Procedure](release-management/hotfix-procedure.md) |

### Quick Links

- **📚 [Parent Directory](../README.md)** - Return to guides section
- **🏠 [Documentation Home](../../README.md)** - Main documentation index
- **🔍 [Search Documentation](../../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Cross-Reference Guide](../../_meta/cross-reference-guide.md) - Documentation linking standards
- [Maintenance Process](../../_meta/maintenance-process.md) - How to update documentation
- [Operations Procedures](../../operations/README.md) - Deployment workflows
<!-- NAV_END -->
```

### 4. Individual Document Template (e.g., docs/guides/feature-workflow.md)

```markdown
<!-- NAV_START -->
## Navigation

**Current Location**: [Home](../README.md) > [Guides](README.md) > Feature Branch Workflow

### Quick Links

- **📚 [Parent Directory](README.md)** - Return to guides section
- **🏠 [Documentation Home](../README.md)** - Main documentation index
- **🔍 [Search Documentation](../reference/glossary.md)** - Find terms and concepts

### Related Documentation

- [Cross-Reference Guide](../_meta/cross-reference-guide.md) - Documentation linking standards
- [Maintenance Process](../_meta/maintenance-process.md) - How to update documentation
- [Git Hooks Implementation](git-hooks-implementation.md) - Related workflow automation
- [GitHub Actions Implementation](github-actions-implementation.md) - CI/CD integration
<!-- NAV_END -->
```

## Conditional Content Rules

### When No Subdirectories Exist

Replace the subdirectories table with:

```markdown
### Subdirectories

*No subdirectories in this section.*
```

### When No Key Documents Exist

In the key documents column, use:

```markdown
*No key documents*
```

### When Path Depth Varies

Adjust relative paths based on current document location:

**One level deep (docs/section/README.md)**:
- Parent: `../README.md`
- Home: `../README.md`
- Search: `../reference/glossary.md`

**Two levels deep (docs/section/subsection/README.md)**:
- Parent: `../README.md`
- Home: `../../README.md`
- Search: `../../reference/glossary.md`

**Three levels deep (docs/section/subsection/document.md)**:
- Parent: `../README.md`
- Home: `../../../README.md`
- Search: `../../../reference/glossary.md`

## Automation Integration Points

### Template Variables for Automation

When implementing automated navigation generation, use these template variables:

```markdown
<!-- NAV_START -->
## Navigation

**Current Location**: {{BREADCRUMB_PATH}}

{{#if SUBDIRECTORIES}}
### Subdirectories

| Directory | Description | Key Documents |
|-----------|-------------|---------------|
{{#each SUBDIRECTORIES}}
| [`{{name}}/`]({{name}}/) | {{description}} | {{key_documents}} |
{{/each}}
{{else}}
### Subdirectories

*No subdirectories in this section.*
{{/if}}

### Quick Links

- **📚 [Parent Directory]({{PARENT_PATH}})** - Return to parent level
- **🏠 [Documentation Home]({{HOME_PATH}})** - Main documentation index
- **🔍 [Search Documentation]({{SEARCH_PATH}})** - Find terms and concepts

### Related Documentation

{{#each RELATED_LINKS}}
- [{{title}}]({{path}}) - {{description}}
{{/each}}
<!-- NAV_END -->
```

### Template Data Structure

```elixir
%{
  breadcrumb_path: "Generated breadcrumb string",
  subdirectories: [
    %{
      name: "subdirectory_name",
      description: "Brief description",
      key_documents: "Link1, Link2, Link3"
    }
  ],
  parent_path: "../README.md",
  home_path: "../../README.md", 
  search_path: "../../reference/glossary.md",
  related_links: [
    %{
      title: "Cross-Reference Guide",
      path: "../_meta/cross-reference-guide.md",
      description: "Documentation linking standards"
    }
  ]
}
```

## Quality Assurance Checklist

### Template Compliance Validation

- [ ] Navigation section wrapped in HTML comment markers
- [ ] Correct heading levels used (## for Navigation, ### for subsections)
- [ ] Breadcrumb shows accurate path
- [ ] Subdirectories table has correct format and columns
- [ ] Quick links use standard emojis and descriptions
- [ ] Related documentation includes standard links
- [ ] All links use relative paths
- [ ] No broken links or missing files
- [ ] Consistent formatting and spacing

### Content Quality Validation

- [ ] Directory descriptions are concise and informative
- [ ] Key documents represent most important/useful files
- [ ] Breadcrumb accurately reflects directory hierarchy
- [ ] Related links are relevant to current section
- [ ] No duplicate links within navigation section
- [ ] All descriptions follow consistent style and tone

## Common Mistakes and Corrections

### Incorrect HTML Markers

❌ **Wrong**:
```html
<!-- NAVIGATION_START -->
<!-- NAV_BEGIN -->
<!-- START_NAV -->
```

✅ **Correct**:
```html
<!-- NAV_START -->
<!-- NAV_END -->
```

### Incorrect Heading Levels

❌ **Wrong**:
```markdown
# Navigation
### Navigation
#### Subdirectories
```

✅ **Correct**:
```markdown
## Navigation
### Subdirectories
```

### Incorrect Link Formats

❌ **Wrong**:
```markdown
| [subdirectory](subdirectory/README.md) | Description | Links |
| subdirectory/ | Description | Links |
```

✅ **Correct**:
```markdown
| [`subdirectory/`](subdirectory/) | Description | Links |
```

### Incorrect Path Calculations

❌ **Wrong**:
```markdown
**Current Location**: [Home](/README.md) > [Guides](/guides/README.md)
```

✅ **Correct**:
```markdown
**Current Location**: [Home](../README.md) > [Guides](README.md)
```

## Related Documentation

- [Documentation Navigation Standards](documentation-navigation-standards.md) - Complete system standards
- [Documentation Navigation Mix Tasks](documentation-navigation-mix-tasks.md) - Automation implementation
- [Cross-Reference Guide](../_meta/cross-reference-guide.md) - General linking standards
- [Maintenance Process](../_meta/maintenance-process.md) - Documentation maintenance procedures

---

**These templates and positioning rules ensure consistent, professional navigation across all documentation while supporting both manual editing and automated maintenance.**