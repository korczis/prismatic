# Taxonomy and Metadata Structure Design

## 📋 Executive Summary

This document defines a comprehensive taxonomy and metadata structure for the Prismatic documentation, designed to support both Zola blog functionality and GitHub browsability while providing rich categorization, search, and navigation capabilities.

## 🏷️ Taxonomy Architecture

### Primary Taxonomies

#### 1. **Categories** (Primary Content Classification)
```toml
[taxonomies]
category = { paginate_by = 15, feed = true }
```

**Values:**
- `technical` - Implementation guides, APIs, architecture documentation
- `academic` - Research papers, theoretical frameworks, mathematical models
- `legal` - License terms, legal frameworks, compliance documentation
- `applications` - Real-world use cases, industry implementations
- `reference` - API docs, glossaries, quick reference materials
- `tutorial` - Step-by-step guides, learning materials
- `specification` - Formal specifications, standards, protocols

#### 2. **Tags** (Cross-cutting Topics)
```toml
[taxonomies]
tag = { paginate_by = 20, feed = true }
```

**Technology Tags:**
- `elixir`, `phoenix`, `postgresql`, `timescaledb`, `meilisearch`
- `ai`, `llm`, `machine-learning`, `nlp`, `consciousness`
- `rust`, `javascript`, `html`, `css`, `markdown`

**Domain Tags:**
- `crisis-intervention`, `mental-health`, `suicide-prevention`
- `algorithmic-trading`, `financial-markets`, `risk-management`
- `content-moderation`, `social-media`, `misinformation`
- `healthcare`, `education`, `government`, `enterprise`

**Concept Tags:**
- `agents`, `societies`, `memory`, `blackboard`, `reasoning`
- `nabla-infinity`, `recursive-introspection`, `consciousness`
- `psychological-warfare`, `manipulation-detection`, `fallacies`
- `automation`, `workflows`, `monitoring`, `analytics`

**Framework Tags:**
- `solid-principles`, `fault-tolerance`, `distributed-systems`
- `event-sourcing`, `circuit-breakers`, `supervision-trees`
- `protocol-based`, `polymorphism`, `pattern-matching`

#### 3. **Audience** (Target Users)
```toml
[taxonomies]
audience = { paginate_by = 10 }
```

**Values:**
- `developers` - Software engineers, system architects
- `researchers` - AI researchers, academics, scientists
- `medical` - Healthcare professionals, psychiatrists, therapists
- `legal` - Legal professionals, compliance officers
- `business` - Business leaders, product managers, executives
- `students` - Computer science students, researchers in training
- `operators` - DevOps, system administrators, site reliability engineers

#### 4. **Difficulty** (Complexity Level)
```toml
[taxonomies]
difficulty = { paginate_by = 10 }
```

**Values:**
- `beginner` - Basic concepts, getting started materials
- `intermediate` - Standard implementation, common patterns
- `advanced` - Complex systems, optimization, edge cases
- `expert` - Cutting-edge research, highly specialized content

#### 5. **Content Type** (Document Format/Purpose)
```toml
[taxonomies]
content_type = { paginate_by = 15 }
```

**Values:**
- `documentation` - Standard technical documentation
- `api-reference` - API documentation and references
- `tutorial` - Step-by-step instructional content
- `research-paper` - Academic research and theoretical work
- `use-case` - Real-world application examples
- `specification` - Formal technical specifications
- `legal-document` - Legal frameworks and license terms
- `kompendium` - Specialized academic taxonomy (Czech content)
- `guide` - Implementation and setup guides
- `overview` - High-level conceptual overviews

#### 6. **Language** (Content Language)
```toml
[taxonomies]
language = { paginate_by = 20 }
```

**Values:**
- `english` - English content (primary)
- `czech` - Czech language content
- `slovak` - Slovak language content
- `multilingual` - Content available in multiple languages

#### 7. **Status** (Development/Review Status)
```toml
[taxonomies]
status = { paginate_by = 10 }
```

**Values:**
- `draft` - Work in progress, not ready for production
- `review` - Under review, pending approval
- `complete` - Finished and approved content
- `deprecated` - Outdated content, kept for reference
- `final` - Legally final documents (for legal content)
- `living` - Continuously updated documents

## 📊 Metadata Schema Design

### Universal Metadata Fields

#### Required Fields (All Content)
```toml
+++
title = "Document Title"                    # Human-readable title
description = "Brief description for SEO"  # Meta description
date = 2025-01-26                          # Creation/publication date
weight = 10                                # Sort order within section
+++
```

#### Common Optional Fields
```toml
+++
updated = 2025-01-27                       # Last modification date
draft = false                              # Visibility in production
slug = "custom-url-slug"                   # Override URL slug
template = "custom-template.html"          # Override template
aliases = ["old-url-1", "old-url-2"]      # Redirect from old URLs
+++
```

### Content-Type Specific Metadata

#### Technical Documentation
```toml
+++
title = "Agent System Architecture"
description = "Core agent infrastructure and protocol design"
date = 2025-01-26
weight = 10

[taxonomies]
tags = ["elixir", "agents", "architecture", "protocols"]
categories = ["technical"]
audience = ["developers", "operators"]
difficulty = ["intermediate"]
content_type = ["documentation"]
language = ["english"]
status = ["complete"]

[extra]
# Technical metadata
github_edit = true                         # Show "Edit on GitHub" link
toc = true                                # Generate table of contents
code_examples = true                      # Contains code examples
mermaid_diagrams = true                   # Contains Mermaid diagrams
api_reference = false                     # Is API reference
implementation_phase = 2                  # Development phase (1-8)
related_sections = ["societies", "memory", "blackboard"]
prerequisites = ["elixir-basics", "otp-fundamentals"]
estimated_reading_time = 15               # Minutes
complexity_score = 7                     # 1-10 complexity rating
+++
```

#### Academic/Research Content
```toml
+++
title = "Nabla-Infinity Recursive Introspection Framework"
description = "Mathematical framework for consciousness emergence"
date = 2025-01-26
weight = 10

[taxonomies]
tags = ["nabla-infinity", "consciousness", "recursion", "mathematics"]
categories = ["academic"]
audience = ["researchers", "academics"]
difficulty = ["expert"]
content_type = ["research-paper"]
language = ["english"]
status = ["complete"]

[extra]
# Academic metadata
authors = ["Tomas Korcak"]               # Author list
institution = "Prismatic Research"       # Affiliated institution
paper_type = "theoretical"               # theoretical, empirical, review
peer_reviewed = false                    # Peer review status
citations = true                         # Has citations/bibliography
math_notation = true                     # Contains mathematical notation
abstract = "Brief abstract text..."      # Paper abstract
keywords = ["consciousness", "AI", "recursion", "introspection"]
doi = ""                                # DOI if published
arxiv_id = ""                           # arXiv identifier
publication_venue = ""                   # Journal/conference
+++
```

#### Legal Documentation
```toml
+++
title = "General Honest License v1.0"
description = "Comprehensive software licensing framework"
date = 2025-01-05
weight = 10

[taxonomies]
tags = ["license", "legal", "sovereignty", "software"]
categories = ["legal"]
audience = ["legal", "developers"]
difficulty = ["advanced"]
content_type = ["legal-document"]
language = ["english"]
status = ["final"]

[extra]
# Legal metadata
legal_version = "1.0"                    # Legal document version
jurisdiction = "Czech Republic"          # Legal jurisdiction
author = "Tomas Korcak"                 # Legal author
legal_type = "license"                  # license, terms, policy
binding = true                          # Legally binding
canonical = true                        # Canonical version
effective_date = "2025-01-05"          # When it takes effect
last_modified = "2025-01-26"           # Last legal modification
supersedes = []                         # Previous versions
+++
```

#### Application/Use Case Content
```toml
+++
title = "Crisis Intervention System Implementation"
description = "Mental health crisis detection and intervention"
date = 2025-01-26
weight = 10

[taxonomies]
tags = ["crisis-intervention", "mental-health", "healthcare", "ai"]
categories = ["applications"]
audience = ["business", "medical", "developers"]
difficulty = ["intermediate"]
content_type = ["use-case"]
language = ["english"]
status = ["complete"]

[extra]
# Application metadata
industry = "healthcare"                  # Target industry
use_case_type = "crisis-intervention"   # Specific use case
roi_analysis = true                     # Includes ROI analysis
case_studies = true                     # Has real case studies
implementation_guide = true             # Step-by-step implementation
success_metrics = true                  # Defined success criteria
deployment_complexity = "medium"        # low, medium, high
estimated_cost = "medium"               # low, medium, high
time_to_deployment = "3-6 months"      # Implementation timeline
regulatory_considerations = true        # Has regulatory aspects
+++
```

#### Multilingual (Czech/Slovak) Content
```toml
+++
title = "Kompendium epistemické a kognitivní anihilace"
description = "Taxonomický systém pro psychiatrickou komunitu"
date = 2025-01-26
weight = 10

[taxonomies]
tags = ["epistemologie", "psychiatrie", "taxonomie", "anihilace"]
categories = ["academic"]
audience = ["medical", "researchers"]
difficulty = ["expert"]
content_type = ["kompendium"]
language = ["czech"]
status = ["complete"]

[extra]
# Multilingual metadata
lang = "cs"                             # ISO language code
translations = ["en"]                   # Available translations
original_language = "cs"                # Original language
translation_status = "complete"         # Translation completeness
translator = ""                         # Translator name
translation_date = ""                   # Translation date

# Academic metadata (Czech context)
academic_level = "postgraduate"         # Target academic level
field = "psychiatry"                    # Academic field
classification_system = true           # Is classification system
ethical_guidelines = true              # Has ethical considerations
professional_audience = "psychiatrists" # Specific professional group
access_level = 3                       # Access restriction level (1-4)
+++
```

## 🔍 Search and Discovery Schema

### Search Index Configuration
```toml
# config.toml
build_search_index = true
search_index_format = "elasticlunr_json"

[search]
include_title = true
include_description = true
include_path = true
include_content = true
include_taxonomies = ["tags", "categories"]
truncate_content_length = 200
```

### Enhanced Search Metadata
```toml
+++
[extra]
# Search optimization
search_keywords = ["additional", "search", "terms"]
search_boost = 1.5                      # Boost search ranking
search_exclude = false                  # Exclude from search
featured = true                         # Featured content
popular = true                          # Popular/important content
+++
```

## 🗂️ Section-Level Metadata

### Section Configuration (_index.md)
```toml
+++
title = "Section Title"
description = "Section description"
sort_by = "weight"                      # weight, date, title
paginate_by = 20                        # Items per page
template = "section.html"               # Section template
transparent = false                     # Generate section page
insert_anchor_links = "right"           # Anchor link position

[extra]
# Section metadata
section_icon = "🏗️"                    # Icon for navigation
show_subsections = true                 # Show subsection list
navigation_weight = 20                  # Navigation order
section_type = "documentation"          # Section type
landing_page = true                     # Is landing page
featured_pages = ["page1", "page2"]    # Highlight specific pages
+++
```

## 📋 Content Relationship Schema

### Cross-References and Relations
```toml
+++
[extra]
# Content relationships
related_pages = ["agents", "societies", "memory"]
prerequisites = ["elixir-basics", "otp-fundamentals"]
follows_from = ["architecture-overview"]
leads_to = ["implementation-guide"]
part_of_series = "getting-started"
series_order = 3

# See also links
see_also = [
  { title = "Agent System", url = "/agents/", description = "Core infrastructure" },
  { title = "Societies", url = "/societies/", description = "Group coordination" },
  { title = "Memory", url = "/memory/", description = "Multi-layer memory" }
]

# External references
external_links = [
  { title = "Elixir Documentation", url = "https://elixir-lang.org/docs.html" },
  { title = "Phoenix Framework", url = "https://phoenixframework.org/" }
]
+++
```

## 🎯 Validation Schema

### Metadata Validation Rules
```yaml
# metadata-validation.yml
required_fields:
  all_content: ["title", "description", "date"]
  technical: ["taxonomies.categories", "taxonomies.audience"]
  academic: ["extra.authors", "taxonomies.difficulty"]
  legal: ["extra.legal_version", "extra.jurisdiction"]

taxonomy_values:
  categories: ["technical", "academic", "legal", "applications", "reference", "tutorial", "specification"]
  difficulty: ["beginner", "intermediate", "advanced", "expert"]
  audience: ["developers", "researchers", "medical", "legal", "business", "students", "operators"]
  language: ["english", "czech", "slovak", "multilingual"]
  status: ["draft", "review", "complete", "deprecated", "final", "living"]

field_constraints:
  weight: { type: "integer", min: 1, max: 100 }
  complexity_score: { type: "integer", min: 1, max: 10 }
  access_level: { type: "integer", min: 1, max: 4 }
  estimated_reading_time: { type: "integer", min: 1 }
```

## 🚀 Implementation Strategy

### Automated Metadata Generation
```python
# generate-metadata.py
def generate_metadata(file_path, content_analysis):
    """Generate appropriate TOML frontmatter based on content analysis"""
    
    # Detect content type
    content_type = detect_content_type(file_path, content_analysis)
    
    # Generate base metadata
    metadata = {
        "title": extract_title(content_analysis),
        "description": generate_description(content_analysis),
        "date": get_file_date(file_path),
        "weight": calculate_weight(file_path)
    }
    
    # Add taxonomies
    metadata["taxonomies"] = {
        "tags": extract_tags(content_analysis),
        "categories": [content_type],
        "audience": detect_audience(content_analysis),
        "difficulty": assess_difficulty(content_analysis),
        "content_type": [content_type],
        "language": detect_language(content_analysis),
        "status": determine_status(file_path)
    }
    
    # Add content-specific metadata
    if content_type == "technical":
        metadata["extra"] = generate_technical_metadata(content_analysis)
    elif content_type == "academic":
        metadata["extra"] = generate_academic_metadata(content_analysis)
    # ... etc
    
    return metadata
```

### Migration Script
```bash
#!/bin/bash
# migrate-to-taxonomy.sh

echo "Migrating documentation to new taxonomy structure..."

# Process each markdown file
find docs -name "*.md" -not -path "*/templates/*" | while read file; do
    echo "Processing: $file"
    
    # Generate metadata
    python generate-metadata.py "$file" > temp_metadata.toml
    
    # Add frontmatter if not present
    if ! head -1 "$file" | grep -q "+++"; then
        # Prepend TOML frontmatter
        cat temp_metadata.toml "$file" > temp_file
        mv temp_file "$file"
    else
        # Update existing frontmatter
        python update-metadata.py "$file" temp_metadata.toml
    fi
    
    rm temp_metadata.toml
done

echo "Migration complete!"
```

## 📊 Analytics and Reporting

### Content Analytics Schema
```toml
+++
[extra]
# Analytics metadata
created_by = "author-name"              # Content creator
last_updated_by = "editor-name"         # Last editor
review_date = "2025-06-01"             # Next review date
maintenance_priority = "high"           # Maintenance priority
page_views = 0                         # View counter
feedback_score = 0.0                   # User feedback
outdated_links = []                    # Broken/outdated links
+++
```

### Quality Metrics
```toml
+++
[extra]
# Quality indicators
completeness_score = 85                # Content completeness (%)
accuracy_verified = true               # Accuracy verification
technical_review = true                # Technical review completed
editorial_review = false               # Editorial review status
accessibility_score = 90               # Accessibility rating
seo_score = 75                         # SEO optimization score
+++
```

---

*This comprehensive taxonomy and metadata structure provides the foundation for rich content organization, discovery, and management while maintaining compatibility with both Zola and GitHub platforms.*