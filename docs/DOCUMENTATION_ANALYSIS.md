# Prismatic Documentation Analysis & Standardization Plan

## Current State Analysis

### TOML Header Patterns Identified

#### 1. Full TOML Headers (Primary Documentation)
**Examples**: `docs/_index.md`, `docs/agents/_index.md`, `docs/applications/_index.md`

```toml
+++
title = "Title"
description = "Description"
date = 2025-01-26
sort_by = "weight"
template = "section.html"
weight = 30

[taxonomies]
tags = ["tag1", "tag2"]
categories = ["category1"]
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
featured_pages = []
toc = true
github_edit = true
+++
```

#### 2. Minimal TOML Headers (Application Pages)
**Examples**: `docs/applications/crisis-intervention.md`

```toml
+++
title = "Crisis Intervention Application"
description = "Description"
weight = 1

[taxonomies]
categories = ["applications", "crisis-management"]
tags = ["crisis", "negotiation", "emergency"]

[extra]
toc = true
+++
```

#### 3. GHL-Specific Headers (Legal Documentation)
**Examples**: `docs/ghl/01-foundations/01-preamble-and-purpose.md`

```toml
+++
title = "Preamble and Purpose"
description = "Section 1 of the General Honest License v1.0"
weight = 10
template = "ghl.html"
draft = false

[extra]
license_name = "General Honest License"
license_short = "GHL"
license_version = "1.0"
license_status = "final"
sovereign = true
author = "Tomas Korcak"
canonical = "@/ghl/01-foundations/01-preamble-and-purpose/"
date_created = "2025-01-05"
date_modified = "2025-01-05"
jurisdiction = "Czech Republic"
+++
```

#### 4. NLP-Specific Headers
**Examples**: `docs/nlp/clean-language.md`

```toml
+++
title = "Clean Language"
description = "Technika pro zkoumání osobních metafor a symbolického myšlení"
date = 2025-03-12
+++
```

#### 5. No Headers (Technical Documentation)
**Examples**: `docs/agents/README.md`, `docs/architecture/README.md`, `docs/psychological-warfare/README.md`

Just markdown content without TOML frontmatter.

### Content Structure Variations

#### Pattern A: Primary Documentation Pages
- TOML header with full metadata
- Main title with emoji (# 📚 Title)
- Overview section (## 🎯 Overview)
- Structured sections with emojis
- Quick start guide
- Feature lists
- Cross-references
- License footer

#### Pattern B: Technical Implementation Pages
- No TOML header OR minimal header
- Main title (# Title)
- Overview with architecture diagrams
- Code examples and implementation details
- Performance metrics
- Implementation status sections
- Related documentation links

#### Pattern C: Application Showcase Pages
- Minimal TOML header
- Title and description
- System architecture
- Key features
- Implementation details
- Performance metrics
- Future enhancements

#### Pattern D: Academic/Research Pages (NLP, Kompendium)
- Simple TOML headers
- Structured academic content
- Methodology sections
- Examples and case studies
- References and bibliography
- Glossary terms

#### Pattern E: Legal Documentation (GHL)
- Specialized TOML headers with legal metadata
- Formal legal language
- Structured sections
- Cross-references to other legal documents

### Major Inconsistencies Identified

#### 1. File Organization
- **_index.md vs README.md**: Mixed usage across directories
- **Directory structure**: Inconsistent organization patterns
- **File naming**: Mixed conventions (kebab-case, snake_case, etc.)

#### 2. TOML Headers
- **Date formats**: Mixed with/without quotes, different formats
- **Taxonomies**: Inconsistent structure and field usage
- **Extra sections**: Varying metadata fields
- **Required fields**: Missing standard metadata

#### 3. Content Structure
- **Header formatting**: Inconsistent emoji usage and hierarchy
- **Section organization**: Different patterns for similar content
- **Cross-references**: Mixed absolute/relative paths
- **Code blocks**: Inconsistent formatting and language tags

#### 4. Cross-References
- **Link formats**: Mixed markdown link styles
- **Path references**: Inconsistent relative/absolute paths
- **Link text**: Varying conventions for reference text

#### 5. Language and Terminology
- **Mixed languages**: English/Czech content without clear organization
- **Technical terms**: Inconsistent terminology usage
- **Writing style**: Varying levels of formality and structure

### Content Type Categories

Based on analysis, documentation falls into these categories:

1. **Root Documentation** (`docs/_index.md`)
2. **Section Indexes** (`docs/*/_index.md`)
3. **Technical Documentation** (`docs/*/README.md`)
4. **Application Showcases** (`docs/applications/*.md`)
5. **Academic Content** (`docs/nlp/*.md`, `docs/kompendium/**/*.md`)
6. **Legal Documentation** (`docs/ghl/**/*.md`)
7. **Planning Documents** (`docs/development-plan.md`, etc.)

### Cross-Reference Patterns

#### Current Inconsistent Patterns:
- `[Link Text](../section/README.md)`
- `[Link Text](../section/)`
- `[Link Text](section/README.md)`
- `**[Link Text](../section/)**`
- `[📚 Link Text](../section/README.md)`

## Standardization Requirements

### 1. Unified TOML Header Standard
Need consistent metadata across all content types while accommodating specialized requirements.

### 2. Content Structure Templates
Standard templates for each content type with consistent section organization.

### 3. File Organization Rules
Clear rules for _index.md vs README.md usage and directory structure.

### 4. Cross-Reference Standards
Consistent linking patterns and reference formatting.

### 5. Naming Conventions
Standardized file and directory naming across the entire documentation.

### 6. Language Organization
Clear separation and organization of multi-language content.

## Implementation Strategy

1. **Create Standards Documents**: Define unified standards for each aspect
2. **Implement Headers**: Apply standardized TOML headers across all files
3. **Standardize Structure**: Reorganize content according to templates
4. **Fix Cross-References**: Update all links to use consistent patterns
5. **Validate Changes**: Ensure all links work and structure is consistent
6. **Document Standards**: Create comprehensive standards documentation

## Next Steps

1. Design unified TOML header standard accommodating all content types
2. Create content structure templates for each category
3. Define consistent naming conventions and file organization rules
4. Implement standardization across all documentation files
5. Validate and test all changes
6. Document the applied standards for future maintenance