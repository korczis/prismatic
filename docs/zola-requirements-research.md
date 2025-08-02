# Zola Blog Requirements & TOML Frontmatter Research

## 📋 Zola Static Site Generator Overview

Zola is a fast static site generator written in Rust that uses:
- **Markdown** for content with TOML frontmatter
- **Tera** templating engine (similar to Jinja2)
- **Built-in** taxonomies, search, and multilingual support
- **Zero-dependency** deployment (single binary)

## 🏗️ Zola Site Structure Requirements

### Essential Directory Structure
```
site/
├── config.toml              # Main configuration
├── content/                 # All markdown content
│   ├── _index.md           # Homepage
│   ├── section1/           # Content sections
│   │   ├── _index.md       # Section index
│   │   ├── page1.md        # Individual pages
│   │   └── subsection/     # Nested sections
│   └── section2/
├── templates/              # Tera templates
│   ├── base.html          # Base template
│   ├── index.html         # Homepage template
│   ├── section.html       # Section listing
│   └── page.html          # Individual page
├── static/                # Static assets
└── themes/                # Optional themes
```

### Content Organization Principles
1. **Sections** = directories with `_index.md`
2. **Pages** = individual `.md` files
3. **Nested sections** supported for hierarchical content
4. **Co-location** of assets with content

## 📝 TOML Frontmatter Specification

### Required Fields
```toml
+++
title = "Page Title"                    # Required for all pages
date = 2025-01-26                      # Required for blog posts
+++
```

### Common Optional Fields
```toml
+++
title = "Complete Page Title"
description = "SEO meta description"
date = 2025-01-26
updated = 2025-01-27                   # Last modification date
draft = false                          # Hide from production
weight = 10                            # Sort order (lower = first)
slug = "custom-url-slug"               # Override URL slug
path = "custom/path"                   # Override full path
aliases = ["old-url", "another-old-url"] # Redirect from old URLs
template = "custom-template.html"       # Override default template
paginate_by = 10                       # Enable pagination
sort_by = "date"                       # Sort method: date, weight, title
transparent = true                     # Don't generate section page
insert_anchor_links = "left"           # Auto-generate anchor links
render = true                          # Whether to render (default: true)
redirect_to = "https://example.com"    # External redirect
+++
```

### Taxonomy Fields
```toml
+++
[taxonomies]
tags = ["rust", "web", "static-site"]
categories = ["programming", "tutorial"]
authors = ["John Doe", "Jane Smith"]
series = ["Getting Started"]
+++
```

### Custom Extra Fields
```toml
+++
[extra]
author = "John Doe"
reading_time = 5
difficulty = "intermediate"
github_repo = "https://github.com/user/repo"
toc = true                             # Table of contents
math = true                            # Enable MathJax
mermaid = true                         # Enable Mermaid diagrams
+++
```

## 🌐 Multilingual Support

### Configuration (config.toml)
```toml
default_language = "en"

[languages.en]
title = "My Site"
description = "English description"

[languages.cs]
title = "Můj web"
description = "Český popis"
```

### Content Structure for Multilingual
```
content/
├── _index.md                 # English homepage
├── _index.cs.md             # Czech homepage
├── blog/
│   ├── _index.md            # English blog section
│   ├── _index.cs.md         # Czech blog section
│   ├── post1.md             # English post
│   └── post1.cs.md          # Czech post
```

### Multilingual Frontmatter
```toml
+++
title = "English Title"
[extra]
lang = "en"
translations = ["cs"]        # Available translations
+++
```

## 🏷️ Taxonomy System

### Built-in Taxonomies
- **Tags**: Cross-cutting topics
- **Categories**: Content classification

### Custom Taxonomies (config.toml)
```toml
[taxonomies]
tag = { paginate_by = 10, paginate_path = "page", feed = true }
category = { paginate_by = 5, feed = true }
author = { paginate_by = 10 }
series = { paginate_by = 5 }
difficulty = { paginate_by = 10 }
audience = { paginate_by = 10 }
language = { paginate_by = 20 }
```

### Using Taxonomies in Content
```toml
+++
title = "My Post"
[taxonomies]
tags = ["rust", "programming", "tutorial"]
categories = ["technical"]
authors = ["john-doe"]
series = ["rust-basics"]
difficulty = ["intermediate"]
audience = ["developers"]
language = ["english"]
+++
```

## 🔍 Search Configuration

### Built-in Search (config.toml)
```toml
build_search_index = true
search_index_format = "elasticlunr_json"  # or "fuse_js"

[search]
include_title = true
include_description = true
include_path = true
include_content = true
truncate_content_length = 100
```

### Search Index Customization
```toml
+++
[extra]
search_exclude = true          # Exclude from search
search_boost = 2.0            # Boost search ranking
+++
```

## 📄 Templates and Themes

### Template Hierarchy
1. Page-specific template (`template` field)
2. Section template (`section.html`)
3. Default page template (`page.html`)
4. Base template (`base.html`)

### Template Variables Available
```html
<!-- Page variables -->
{{ page.title }}
{{ page.description }}
{{ page.date }}
{{ page.content | safe }}
{{ page.toc }}
{{ page.extra }}

<!-- Section variables -->
{{ section.title }}
{{ section.pages }}
{{ section.subsections }}

<!-- Site variables -->
{{ config.title }}
{{ config.description }}
{{ config.base_url }}

<!-- Taxonomy variables -->
{{ page.taxonomies.tags }}
{{ get_taxonomy(kind="tags") }}
```

## 🚀 Performance and SEO

### SEO Optimization
```toml
+++
title = "SEO-Optimized Title"
description = "Meta description for search engines"
[extra]
og_title = "Open Graph Title"
og_description = "Open Graph Description"
og_image = "path/to/image.jpg"
twitter_card = "summary_large_image"
canonical_url = "https://example.com/canonical"
robots = "index, follow"
+++
```

### Performance Features
- **Fast builds**: Rust-based, parallel processing
- **Asset optimization**: Built-in Sass compilation
- **Image processing**: Resize and optimize images
- **Minification**: HTML, CSS, JS minification

## 🔧 Configuration for Our Use Case

### Recommended config.toml
```toml
base_url = "https://docs.prismatic.dev"
title = "Prismatic Documentation"
description = "Comprehensive documentation for the Prismatic AI agent framework"
default_language = "en"
compile_sass = true
minify_html = true
build_search_index = true
generate_feed = true
feed_filename = "atom.xml"

[markdown]
highlight_code = true
highlight_theme = "github"
render_emoji = true
external_links_target_blank = true
external_links_no_follow = true
external_links_no_referrer = true
smart_punctuation = true

[extra]
github_repo = "https://github.com/korczis/prismatic"
edit_page = true
show_reading_time = true
show_word_count = true

# Multilingual support
[languages.en]
title = "Prismatic Documentation"
description = "AI Agent Framework Documentation"
weight = 1

[languages.cs]
title = "Prismatic Dokumentace"
description = "Dokumentace AI Agent Framework"
weight = 2

# Custom taxonomies for our content
[taxonomies]
tag = { paginate_by = 20, feed = true }
category = { paginate_by = 15, feed = true }
audience = { paginate_by = 10 }
difficulty = { paginate_by = 10 }
content_type = { paginate_by = 15 }
language = { paginate_by = 20 }
status = { paginate_by = 10 }
```

## 📋 Frontmatter Templates for Our Content Types

### Technical Documentation Template
```toml
+++
title = "Technical Page Title"
description = "Brief description for SEO and navigation"
date = 2025-01-26
weight = 10
draft = false

[taxonomies]
tags = ["elixir", "agents", "architecture"]
categories = ["technical"]
audience = ["developers"]
difficulty = ["intermediate"]
content_type = ["documentation"]
language = ["english"]
status = ["complete"]

[extra]
toc = true
github_edit = true
related_sections = ["agents", "architecture"]
code_examples = true
mermaid_diagrams = true
reading_time = 15
+++
```

### Academic/Research Template
```toml
+++
title = "Research Paper Title"
description = "Academic paper description"
date = 2025-01-26
weight = 10

[taxonomies]
tags = ["nabla-infinity", "consciousness", "ai-research"]
categories = ["academic"]
audience = ["researchers", "academics"]
difficulty = ["advanced"]
content_type = ["research"]
language = ["english"]
status = ["complete"]

[extra]
authors = ["Tomas Korcak"]
institution = "Prismatic Research"
paper_type = "theoretical"
citations = true
math_notation = true
bibliography = true
peer_reviewed = false
+++
```

### Legal Documentation Template
```toml
+++
title = "Legal Document Title"
description = "Legal document description"
date = 2025-01-26
weight = 10

[taxonomies]
tags = ["license", "legal", "sovereignty"]
categories = ["legal"]
audience = ["legal", "developers"]
difficulty = ["advanced"]
content_type = ["legal"]
language = ["english"]
status = ["final"]

[extra]
legal_version = "1.0"
jurisdiction = "Czech Republic"
author = "Tomas Korcak"
legal_type = "license"
binding = true
canonical = true
+++
```

### Application/Use Case Template
```toml
+++
title = "Application Use Case Title"
description = "Real-world application description"
date = 2025-01-26
weight = 10

[taxonomies]
tags = ["crisis-intervention", "healthcare", "applications"]
categories = ["applications"]
audience = ["business", "developers"]
difficulty = ["intermediate"]
content_type = ["use-case"]
language = ["english"]
status = ["complete"]

[extra]
industry = "healthcare"
roi_analysis = true
case_studies = true
implementation_guide = true
success_metrics = true
+++
```

### Multilingual (Czech) Template
```toml
+++
title = "Český název"
description = "Český popis"
date = 2025-01-26
weight = 10

[taxonomies]
tags = ["epistemologie", "psychiatrie", "taxonomie"]
categories = ["academic"]
audience = ["medical", "researchers"]
difficulty = ["expert"]
content_type = ["kompendium"]
language = ["czech"]
status = ["complete"]

[extra]
lang = "cs"
translations = ["en"]
academic_level = "postgraduate"
field = "psychiatry"
classification_system = true
ethical_guidelines = true
+++
```

## 🔄 Migration Strategy

### Automated Frontmatter Generation
1. **Analyze existing content** to extract metadata
2. **Generate appropriate frontmatter** based on content type
3. **Preserve existing TOML** where it exists
4. **Add missing required fields** with sensible defaults
5. **Implement taxonomy mapping** from content analysis

### Content Type Detection Rules
```
Technical Documentation:
- Contains code examples (```elixir, ```mermaid)
- Has implementation details
- References APIs or system components

Academic Content:
- Contains citations and references
- Has theoretical frameworks
- Uses academic language patterns

Legal Content:
- Formal legal language
- Section numbering
- Rights and obligations

Applications:
- Business use cases
- ROI analysis
- Implementation examples
```

## ✅ Validation Checklist

### Zola Compatibility
- [ ] All pages have required `title` field
- [ ] Date format is correct (YYYY-MM-DD)
- [ ] TOML syntax is valid
- [ ] Taxonomy values are consistent
- [ ] Template references exist
- [ ] Asset paths are correct

### GitHub Compatibility
- [ ] Markdown renders correctly on GitHub
- [ ] Relative links work in both platforms
- [ ] Code blocks display properly
- [ ] Images and assets load correctly
- [ ] Directory structure remains navigable

---

*This research provides the technical foundation for implementing a robust Zola blog transformation while maintaining full GitHub compatibility.*