# Prismatic Documentation Standards

## Unified TOML Header Standard

### Core Required Fields (All Documents)

```toml
+++
title = "Document Title"
description = "Brief description of the document content (max 200 characters)"
date = 2025-01-27
weight = 10

[taxonomies]
tags = ["tag1", "tag2", "tag3"]
categories = ["category1", "category2"]
audience = ["developers", "researchers", "business", "medical"]
difficulty = ["beginner", "intermediate", "advanced", "expert"]
content_type = ["documentation", "reference", "tutorial", "overview", "use-case", "legal", "academic"]
language = ["english", "czech", "slovak"]
status = ["complete", "draft", "review", "deprecated"]

[extra]
toc = true
github_edit = true
+++
```

### Content-Type Specific Standards

#### 1. Root Documentation (`docs/_index.md`)

```toml
+++
title = "Prismatic Documentation"
description = "Comprehensive AI Agent Framework Documentation - Advanced multi-agent systems, crisis intervention, and consciousness research"
date = 2025-01-27
template = "index.html"

[taxonomies]
tags = ["prismatic", "ai", "agents", "documentation", "framework"]
categories = ["reference"]
audience = ["developers", "researchers", "business"]
difficulty = ["beginner"]
content_type = ["overview"]
language = ["english"]
status = ["complete"]

[extra]
featured = true
toc = false
github_edit = true
show_subsections = true
navigation_weight = 1
section_icon = "🏠"
+++
```

#### 2. Section Index Pages (`docs/*/_index.md`)

```toml
+++
title = "Section Title"
description = "Section description explaining the purpose and scope"
date = 2025-01-27
sort_by = "weight"
template = "section.html"
weight = 30

[taxonomies]
tags = ["relevant", "tags"]
categories = ["technical", "applications", "reference"]
audience = ["developers", "researchers"]
difficulty = ["intermediate"]
content_type = ["documentation"]
language = ["english"]
status = ["complete"]

[extra]
section_icon = "🤖"
show_subsections = true
navigation_weight = 30
section_type = "documentation"
landing_page = true
featured_pages = ["page1", "page2"]
toc = true
github_edit = true
+++
```

#### 3. Technical Documentation (`docs/*/README.md`)

```toml
+++
title = "Technical Component Title"
description = "Technical description of the component and its capabilities"
date = 2025-01-27
weight = 10

[taxonomies]
tags = ["technical", "implementation", "architecture"]
categories = ["technical"]
audience = ["developers"]
difficulty = ["intermediate", "advanced"]
content_type = ["documentation", "reference"]
language = ["english"]
status = ["complete"]

[extra]
toc = true
github_edit = true
show_code_examples = true
api_reference = true
+++
```

#### 4. Application Showcases (`docs/applications/*.md`)

```toml
+++
title = "Application Name"
description = "Description of the application and its use case"
date = 2025-01-27
weight = 10

[taxonomies]
tags = ["application", "use-case", "specific-domain"]
categories = ["applications"]
audience = ["business", "developers", "medical"]
difficulty = ["intermediate"]
content_type = ["use-case"]
language = ["english"]
status = ["complete"]

[extra]
toc = true
github_edit = true
featured_application = true
demo_available = false
+++
```

#### 5. Academic Content (`docs/nlp/*.md`, `docs/kompendium/**/*.md`)

```toml
+++
title = "Academic Topic Title"
description = "Academic description of the research topic or technique"
date = 2025-01-27
weight = 10

[taxonomies]
tags = ["academic", "research", "specific-technique"]
categories = ["academic", "research"]
audience = ["researchers", "academic"]
difficulty = ["advanced", "expert"]
content_type = ["academic", "research"]
language = ["english", "czech"]
status = ["complete"]

[extra]
toc = true
github_edit = true
academic_paper = true
citations_required = true
peer_reviewed = false
+++
```

#### 6. Legal Documentation (`docs/ghl/**/*.md`)

```toml
+++
title = "Legal Section Title"
description = "Description of the legal section content"
date = 2025-01-27
weight = 10
template = "ghl.html"
draft = false

[taxonomies]
tags = ["legal", "license", "sovereignty"]
categories = ["legal"]
audience = ["legal", "developers"]
difficulty = ["advanced"]
content_type = ["legal"]
language = ["english"]
status = ["final"]

[extra]
toc = true
github_edit = true
license_name = "General Honest License"
license_short = "GHL"
license_version = "1.0"
license_status = "final"
sovereign = true
author = "Tomas Korcak"
canonical = "@/ghl/section/page/"
date_created = "2025-01-05"
date_modified = "2025-01-27"
jurisdiction = "Czech Republic"
legal_binding = true
+++
```

#### 7. Planning Documents (`docs/development-plan.md`, etc.)

```toml
+++
title = "Planning Document Title"
description = "Description of the planning document purpose and scope"
date = 2025-01-27
weight = 10

[taxonomies]
tags = ["planning", "roadmap", "development"]
categories = ["planning"]
audience = ["developers", "business"]
difficulty = ["intermediate"]
content_type = ["planning", "reference"]
language = ["english"]
status = ["review"]

[extra]
toc = true
github_edit = true
living_document = true
update_frequency = "quarterly"
+++
```

## Content Structure Templates

### Standard Content Structure

All documents should follow this general structure:

```markdown
+++
[TOML Header as specified above]
+++

# Document Title

Brief introduction paragraph explaining the document's purpose and scope.

## 🎯 Overview

High-level overview of the content, key concepts, and what readers will learn.

### Key Features
- Feature 1: Description
- Feature 2: Description
- Feature 3: Description

## 🏗️ [Main Content Sections]

### Section 1
Content organized into logical sections with consistent emoji usage for visual hierarchy.

### Section 2
Each section should have a clear purpose and logical flow.

## 📊 [Data/Metrics/Examples Section]

Concrete examples, performance metrics, or implementation details.

## 🚀 Quick Start / Getting Started

Practical guidance for users to begin using or understanding the topic.

## 🎯 Implementation Status

Current status and future plans (for technical documentation).

## 📚 Related Documentation

Cross-references to related content with consistent linking format.

## 🔗 Related Documentation

### Core Systems
- [System Name](../system/README.md) - Brief description
- [Another System](../another/README.md) - Brief description

### Applications
- [Application Name](../applications/app-name.md) - Brief description

---

*Footer with brief description of the document's role in the broader Prismatic ecosystem.*
```

## File Organization Standards

### Directory Structure Rules

1. **Primary Documentation**: Use `_index.md` for section landing pages
2. **Technical Implementation**: Use `README.md` for technical documentation
3. **Specific Topics**: Use descriptive kebab-case filenames (e.g., `crisis-intervention.md`)

### File Naming Conventions

1. **Directories**: `kebab-case` (e.g., `psychological-warfare`, `nabla-infinity`)
2. **Files**: `kebab-case.md` (e.g., `crisis-intervention.md`, `clean-language.md`)
3. **Index Files**: 
   - `_index.md` for Zola section pages
   - `README.md` for technical documentation
4. **Multi-word Terms**: Use hyphens (e.g., `meta-model-questioning.md`)

### Language Organization

1. **Primary Language**: English (`language = ["english"]`)
2. **Multilingual Content**: 
   - Czech content: `language = ["czech"]` or `["english", "czech"]`
   - Slovak content: `language = ["slovak"]` or `["english", "slovak"]`
3. **Translation Files**: Use language suffixes when needed (e.g., `document.cs.md`, `document.sk.md`)

## Cross-Reference Standards

### Link Format Standard

```markdown
[Link Text](../section/file.md) - Brief description of linked content
```

### Examples:

#### Internal Documentation Links
```markdown
- [Agent System](../agents/README.md) - Core agent architecture and implementation
- [Crisis Intervention](../applications/crisis-intervention.md) - AI-powered crisis response system
- [Nabla-Infinity Framework](../nabla-infinity/README.md) - Recursive introspection capabilities
```

#### Section References
```markdown
- [Architecture Overview](../architecture/README.md) - System-wide architectural patterns
- [Development Plan](../development-plan.md) - Overall project roadmap and phases
```

#### External References
```markdown
- [Elixir Documentation](https://hexdocs.pm/elixir/) - Official Elixir language documentation
- [Phoenix Framework](https://phoenixframework.org/) - Web framework for Elixir
```

### Link Text Conventions

1. **Use descriptive titles**: Match the actual document title
2. **No emoji in links**: Keep link text clean and accessible
3. **Consistent descriptions**: Brief, informative descriptions after links
4. **Relative paths**: Always use relative paths for internal links

## Taxonomy Standards

### Tags Guidelines

1. **Keep specific**: Use specific, descriptive tags
2. **Avoid duplicates**: Don't duplicate category information in tags
3. **Use kebab-case**: Multi-word tags use hyphens
4. **Limit quantity**: Maximum 6 tags per document

### Categories

Use categories from the established taxonomy:
- `reference` - General reference material
- `technical` - Technical implementation details
- `applications` - Use cases and applications
- `academic` - Research and academic content
- `legal` - Legal documentation
- `planning` - Planning and roadmap documents

### Audience Classification

- `developers` - Software developers and engineers
- `researchers` - Academic researchers and scientists
- `business` - Business stakeholders and decision makers
- `medical` - Medical and healthcare professionals
- `legal` - Legal professionals and compliance

### Difficulty Levels

- `beginner` - No prior knowledge assumed
- `intermediate` - Basic understanding of domain assumed
- `advanced` - Significant expertise assumed
- `expert` - Deep domain expertise required

### Content Types

- `documentation` - Standard documentation
- `reference` - Reference material and API docs
- `tutorial` - Step-by-step tutorials
- `overview` - High-level overviews
- `use-case` - Specific use cases and applications
- `legal` - Legal documents and licenses
- `academic` - Academic and research content
- `planning` - Planning and roadmap documents

### Status Values

- `complete` - Content is complete and ready
- `draft` - Work in progress, not final
- `review` - Under review, may change
- `deprecated` - Outdated, kept for reference

## Implementation Checklist

- [ ] Apply unified TOML headers to all files
- [ ] Standardize content structure according to templates
- [ ] Update all cross-references to use consistent format
- [ ] Ensure proper file naming conventions
- [ ] Validate all internal links work correctly
- [ ] Check taxonomy consistency across all files
- [ ] Verify date formats are consistent
- [ ] Ensure language tagging is correct
- [ ] Update navigation weights logically
- [ ] Test Zola build with new standards