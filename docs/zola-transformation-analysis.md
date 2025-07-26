# Zola Blog Transformation Analysis

## 📋 Executive Summary

This document provides a comprehensive analysis of the `/docs/` directory structure and content types, preparing for transformation into a Zola blog that maintains GitHub browsable markdown compatibility (polyglot approach).

## 🗂️ Current Documentation Structure Analysis

### Major Content Categories Identified

#### 1. **Technical Documentation** (English)
- **Architecture & Planning**: Core system design and development roadmaps
- **Core Systems**: Agent infrastructure, memory, blackboard, societies
- **Advanced Features**: Nabla-Infinity, reasoning engines, automation
- **Applications**: Real-world use cases across industries
- **Infrastructure**: Distributed operations, monitoring, persistence

#### 2. **Legal Documentation** (English)
- **GHL (General Honest License)**: Comprehensive legal framework
- **Structured hierarchically** with 6 main sections and subsections
- **Already has Zola-compatible TOML frontmatter**

#### 3. **Academic/Research Content** (Mixed Languages)
- **Kompendium**: Czech/Slovak academic content on epistemological topics
- **Nabla-Infinity**: Mathematical framework documentation
- **NLP Patterns**: Multilingual content with academic references

#### 4. **Specialized Knowledge Bases**
- **Psychological Warfare**: Detection and countermeasure systems
- **NLP Techniques**: Advanced linguistic and cognitive patterns
- **Crisis Intervention**: Professional training materials

## 📊 Content Type Classification

### By Format and Structure

#### Type A: **Index/Overview Files** (README.md, _index.md)
- **Count**: ~25 files
- **Current State**: Mixed - some have TOML frontmatter, others don't
- **Characteristics**: 
  - Hierarchical navigation
  - Cross-references to other sections
  - Overview and quick-start information

#### Type B: **Technical Specifications** (.md files)
- **Count**: ~150+ files
- **Current State**: Pure markdown without frontmatter
- **Characteristics**:
  - Code examples (Elixir, configuration)
  - Architecture diagrams (Mermaid)
  - Implementation details
  - API references

#### Type C: **Academic Papers/Research** (.md files)
- **Count**: ~30 files
- **Current State**: Some have TOML frontmatter (NLP section)
- **Characteristics**:
  - Academic citations and references
  - Theoretical frameworks
  - Mathematical notation
  - Multilingual content

#### Type D: **Legal/Formal Documents** (.md files)
- **Count**: ~40 files (GHL section)
- **Current State**: Complete TOML frontmatter
- **Characteristics**:
  - Formal legal language
  - Hierarchical section numbering
  - Cross-references within legal framework

### By Language and Audience

#### English Technical Content (70%)
- Primary audience: Developers, system architects, researchers
- Content: Technical specifications, APIs, implementation guides
- Style: Technical, code-heavy, practical

#### English Academic Content (15%)
- Primary audience: Researchers, academics, AI specialists
- Content: Theoretical frameworks, mathematical models
- Style: Academic, citation-heavy, theoretical

#### Czech/Slovak Academic Content (10%)
- Primary audience: Czech/Slovak psychiatric professionals
- Content: Specialized psychiatric taxonomy
- Style: Highly academic, professional terminology

#### Legal Content (5%)
- Primary audience: Legal professionals, developers
- Content: License terms, legal frameworks
- Style: Formal legal language

## 🏗️ Current TOML Frontmatter Analysis

### Files WITH Existing TOML Frontmatter

#### 1. **GHL Section** (Complete)
```toml
+++
title = "General Honest License (GHL)"
description = "Full text of the General Honest License v1.0"
sort_by = "weight"
template = "ghl.html"
draft = false

[extra]
license_name = "General Honest License"
license_version = "1.0"
author = "Tomas Korcak"
canonical = "@/ghl/"
date_created = "2025-01-05"
jurisdiction = "Czech Republic"
tags = ["sovereignty", "invocation", "license"]
categories = ["license", "philosophy"]
+++
```

#### 2. **Kompendium Section** (Complete)
```toml
+++
title = "Kompendium epistemické a kognitivní anihilace"
description = "První ucelený taxonomický systém..."
sort_by = "weight"
weight = 1
insert_anchor_links = "right"
+++
```

#### 3. **NLP Section** (Partial)
```toml
+++
title = "Clean Language"
description = "Technika pro zkoumání osobních metafor"
date = 2025-03-12
+++
```

### Files WITHOUT TOML Frontmatter
- Most technical documentation (architecture/, applications/, agents/, etc.)
- Development plans and roadmaps
- API references and implementation guides

## 🎯 Zola Blog Requirements Research

### Essential Zola Features Needed

#### 1. **Section Organization**
- Zola uses sections (directories) for content organization
- Each section can have its own `_index.md` with section-wide configuration
- Supports nested sections for hierarchical content

#### 2. **Taxonomies**
- **Tags**: For cross-cutting topics (e.g., "AI", "crisis-intervention", "elixir")
- **Categories**: For major content types (e.g., "technical", "academic", "legal")
- **Custom Taxonomies**: Could add "audience", "difficulty", "language"

#### 3. **Templates**
- Different content types need different templates
- Technical docs vs academic papers vs legal documents
- Multilingual support considerations

#### 4. **Search and Navigation**
- Full-text search across all content
- Hierarchical navigation
- Cross-references and related content

## 🌐 Polyglot Approach Strategy

### GitHub Compatibility Requirements
1. **Preserve existing README.md structure** for GitHub navigation
2. **Maintain relative links** that work in both GitHub and Zola
3. **Keep code examples** properly formatted for both platforms
4. **Preserve directory structure** for logical organization

### Zola Enhancement Strategy
1. **Add TOML frontmatter** to all markdown files
2. **Implement consistent taxonomy** across all content
3. **Create section indexes** for better navigation
4. **Add search and filtering** capabilities
5. **Implement multilingual support** for Czech/Slovak content

## 📋 Proposed Taxonomy Structure

### Primary Categories
- `technical` - Implementation guides, APIs, architecture
- `academic` - Research papers, theoretical frameworks
- `legal` - License terms, legal frameworks
- `applications` - Real-world use cases and examples
- `reference` - API docs, glossaries, quick references

### Tags (Cross-cutting Topics)
- **Technology**: `elixir`, `ai`, `llm`, `phoenix`, `postgresql`
- **Domains**: `crisis-intervention`, `trading`, `content-moderation`
- **Concepts**: `agents`, `societies`, `memory`, `reasoning`
- **Frameworks**: `nabla-infinity`, `psychological-warfare`, `nlp`

### Custom Taxonomies
- **Audience**: `developers`, `researchers`, `legal`, `medical`, `business`
- **Difficulty**: `beginner`, `intermediate`, `advanced`, `expert`
- **Language**: `english`, `czech`, `slovak`
- **Status**: `draft`, `review`, `complete`, `deprecated`

### Content Types
- **Architecture**: System design and technical specifications
- **Tutorial**: Step-by-step implementation guides
- **Reference**: API documentation and quick references
- **Research**: Academic papers and theoretical content
- **Legal**: License and legal framework documentation
- **Application**: Real-world use cases and examples

## 🔄 Transformation Strategy

### Phase 1: Foundation Setup
1. **Configure Zola site structure** with proper sections
2. **Design base templates** for different content types
3. **Set up taxonomy system** with categories and tags
4. **Create navigation structure** that works for both platforms

### Phase 2: Content Enhancement
1. **Add TOML frontmatter** to all markdown files
2. **Standardize metadata** across similar content types
3. **Implement cross-references** using Zola's link system
4. **Add search functionality** and content filtering

### Phase 3: Multilingual Support
1. **Configure Zola multilingual** setup for Czech/Slovak content
2. **Create language-specific** navigation and templates
3. **Implement language switching** functionality
4. **Ensure proper SEO** for multilingual content

### Phase 4: Advanced Features
1. **Add interactive elements** (code highlighting, diagrams)
2. **Implement content relationships** (related articles, series)
3. **Create specialized templates** for academic citations
4. **Add export functionality** (PDF, EPUB for academic content)

## 📈 Success Metrics

### GitHub Compatibility
- [ ] All existing README.md files work as before
- [ ] Relative links function correctly in GitHub
- [ ] Code examples display properly in both platforms
- [ ] Directory structure remains logical and navigable

### Zola Enhancement
- [ ] Full-text search across all content
- [ ] Consistent navigation and taxonomy
- [ ] Responsive design for all device types
- [ ] Fast build times despite large content volume
- [ ] SEO optimization for discoverability

### Content Quality
- [ ] Consistent metadata across all files
- [ ] Proper categorization and tagging
- [ ] Cross-references work correctly
- [ ] Multilingual content properly supported

## 🚀 Next Steps

1. **Research Zola configuration** for complex multilingual sites
2. **Design metadata schema** for consistent frontmatter
3. **Create transformation scripts** for bulk frontmatter addition
4. **Develop templates** for different content types
5. **Test polyglot compatibility** with sample transformations

---

*This analysis provides the foundation for transforming the comprehensive Prismatic documentation into a modern, searchable, and navigable Zola blog while maintaining full GitHub compatibility.*