#!/usr/bin/env python3
"""
Automated TOML frontmatter generation and migration script for Prismatic documentation.
This script analyzes markdown content and generates appropriate frontmatter based on content type.
"""

import os
import re
import sys
import toml
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import argparse

class DocumentationMigrator:
    def __init__(self, docs_path: str = "docs"):
        self.docs_path = Path(docs_path)
        self.content_types = {
            "technical": ["architecture", "agents", "societies", "memory", "automation", "iex-helpers"],
            "academic": ["nabla-infinity", "kompendium", "nlp", "psychological-warfare"],
            "legal": ["ghl"],
            "applications": ["applications"],
            "reference": ["scenarios", "societies"]
        }
        
        # Language detection patterns
        self.czech_patterns = [
            r'\b(a|je|se|na|do|od|za|po|při|před|mezi|nad|pod|podle|během|kolem)\b',
            r'\b(který|která|které|kteří|kterou|kterým|kterých)\b',
            r'\b(tento|tato|toto|tyto|těchto|těmto)\b',
            r'[áčďéěíňóřšťúůýž]'
        ]
        
        # Difficulty indicators
        self.difficulty_indicators = {
            "beginner": ["getting started", "introduction", "basic", "simple", "overview"],
            "intermediate": ["implementation", "guide", "tutorial", "example"],
            "advanced": ["architecture", "optimization", "complex", "advanced"],
            "expert": ["research", "theory", "mathematical", "academic", "formal"]
        }
        
        # Audience indicators
        self.audience_indicators = {
            "developers": ["code", "implementation", "api", "elixir", "programming"],
            "researchers": ["research", "theory", "academic", "paper", "study"],
            "medical": ["crisis", "intervention", "mental health", "psychiatric", "therapy"],
            "legal": ["license", "legal", "terms", "compliance", "jurisdiction"],
            "business": ["roi", "business", "case study", "application", "industry"]
        }

    def analyze_content(self, file_path: Path) -> Dict:
        """Analyze markdown content to determine metadata."""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
        except UnicodeDecodeError:
            print(f"Warning: Could not read {file_path} as UTF-8")
            return self._default_metadata(file_path)
        
        # Skip files that already have frontmatter
        if content.startswith('+++'):
            return None
        
        # Extract title
        title = self._extract_title(content, file_path)
        
        # Detect content type
        content_type = self._detect_content_type(file_path, content)
        
        # Extract tags
        tags = self._extract_tags(content, file_path)
        
        # Assess difficulty
        difficulty = self._assess_difficulty(content, file_path)
        
        # Detect language
        language = self._detect_language(content, file_path)
        
        # Determine audience
        audience = self._determine_audience(content, file_path, content_type)
        
        # Generate description
        description = self._generate_description(content, title)
        
        return {
            "title": title,
            "description": description,
            "content_type": content_type,
            "tags": tags,
            "difficulty": difficulty,
            "language": language,
            "audience": audience,
            "file_path": file_path
        }

    def _extract_title(self, content: str, file_path: Path) -> str:
        """Extract title from markdown content."""
        # Look for first H1 heading
        title_match = re.search(r'^#\s+(.+)$', content, re.MULTILINE)
        if title_match:
            return title_match.group(1).strip()
        
        # Fallback to filename
        return file_path.stem.replace('-', ' ').replace('_', ' ').title()

    def _detect_content_type(self, file_path: Path, content: str) -> str:
        """Detect content type based on file path and content."""
        path_str = str(file_path).lower()
        content_lower = content.lower()
        
        # Check path-based classification
        for content_type, paths in self.content_types.items():
            if any(path in path_str for path in paths):
                return content_type
        
        # Content-based detection
        if any(word in content_lower for word in ["license", "legal", "terms", "jurisdiction"]):
            return "legal"
        elif any(word in content_lower for word in ["research", "paper", "theory", "academic"]):
            return "academic"
        elif any(word in content_lower for word in ["application", "use case", "implementation", "example"]):
            return "applications"
        elif any(word in content_lower for word in ["api", "reference", "glossary", "quick"]):
            return "reference"
        else:
            return "technical"

    def _extract_tags(self, content: str, file_path: Path) -> List[str]:
        """Extract relevant tags from content and file path."""
        tags = []
        content_lower = content.lower()
        path_str = str(file_path).lower()
        
        # Technology tags
        tech_tags = {
            "elixir": ["elixir", "phoenix", "otp"],
            "ai": ["ai", "artificial intelligence", "machine learning", "llm"],
            "agents": ["agent", "agents", "multi-agent"],
            "crisis-intervention": ["crisis", "intervention", "mental health", "suicide"],
            "trading": ["trading", "algorithmic", "financial", "market"],
            "consciousness": ["consciousness", "nabla-infinity", "recursive"],
            "nlp": ["nlp", "natural language", "linguistic"],
            "architecture": ["architecture", "design", "pattern", "system"],
            "memory": ["memory", "persistence", "storage"],
            "societies": ["society", "societies", "group", "collective"]
        }
        
        for tag, keywords in tech_tags.items():
            if any(keyword in content_lower or keyword in path_str for keyword in keywords):
                tags.append(tag)
        
        # Path-based tags
        path_parts = file_path.parts
        for part in path_parts:
            if part in ["architecture", "agents", "applications", "nabla-infinity", "ghl", "kompendium", "nlp"]:
                tags.append(part)
        
        return list(set(tags))  # Remove duplicates

    def _assess_difficulty(self, content: str, file_path: Path) -> str:
        """Assess content difficulty level."""
        content_lower = content.lower()
        path_str = str(file_path).lower()
        
        # Count indicators for each difficulty level
        difficulty_scores = {}
        for level, indicators in self.difficulty_indicators.items():
            score = sum(1 for indicator in indicators 
                       if indicator in content_lower or indicator in path_str)
            difficulty_scores[level] = score
        
        # Special cases
        if "kompendium" in path_str or "research" in path_str:
            return "expert"
        elif "readme" in path_str or "introduction" in content_lower:
            return "beginner"
        elif "architecture" in path_str or "advanced" in content_lower:
            return "advanced"
        
        # Return highest scoring difficulty, default to intermediate
        if difficulty_scores:
            return max(difficulty_scores.items(), key=lambda x: x[1])[0]
        return "intermediate"

    def _detect_language(self, content: str, file_path: Path) -> str:
        """Detect content language."""
        path_str = str(file_path).lower()
        
        # Path-based detection
        if "kompendium" in path_str:
            return "czech"
        
        # Content-based detection for Czech
        czech_score = 0
        for pattern in self.czech_patterns:
            czech_score += len(re.findall(pattern, content, re.IGNORECASE))
        
        # If significant Czech content detected
        if czech_score > 10:
            return "czech"
        
        return "english"

    def _determine_audience(self, content: str, file_path: Path, content_type: str) -> List[str]:
        """Determine target audience."""
        content_lower = content.lower()
        path_str = str(file_path).lower()
        audiences = []
        
        # Content-based audience detection
        for audience, indicators in self.audience_indicators.items():
            if any(indicator in content_lower or indicator in path_str for indicator in indicators):
                audiences.append(audience)
        
        # Default audiences based on content type
        if not audiences:
            if content_type == "technical":
                audiences = ["developers"]
            elif content_type == "academic":
                audiences = ["researchers"]
            elif content_type == "legal":
                audiences = ["legal", "developers"]
            elif content_type == "applications":
                audiences = ["business", "developers"]
            else:
                audiences = ["developers"]
        
        return audiences

    def _generate_description(self, content: str, title: str) -> str:
        """Generate SEO-friendly description."""
        # Try to extract first paragraph
        paragraphs = re.findall(r'^(?!#)(.+)$', content, re.MULTILINE)
        if paragraphs:
            first_para = paragraphs[0].strip()
            if len(first_para) > 20 and not first_para.startswith('```'):
                # Truncate to reasonable length
                if len(first_para) > 150:
                    first_para = first_para[:147] + "..."
                return first_para
        
        # Fallback to generic description
        return f"Documentation for {title}"

    def _default_metadata(self, file_path: Path) -> Dict:
        """Generate default metadata for files that can't be analyzed."""
        return {
            "title": file_path.stem.replace('-', ' ').replace('_', ' ').title(),
            "description": f"Documentation for {file_path.stem}",
            "content_type": "technical",
            "tags": [],
            "difficulty": "intermediate",
            "language": "english",
            "audience": ["developers"],
            "file_path": file_path
        }

    def generate_frontmatter(self, analysis: Dict) -> str:
        """Generate TOML frontmatter from analysis."""
        if not analysis:
            return ""
        
        # Base metadata
        frontmatter = {
            "title": analysis["title"],
            "description": analysis["description"],
            "date": datetime.now().strftime("%Y-%m-%d"),
            "weight": 10
        }
        
        # Taxonomies
        frontmatter["taxonomies"] = {
            "tags": analysis["tags"],
            "categories": [analysis["content_type"]],
            "audience": analysis["audience"],
            "difficulty": [analysis["difficulty"]],
            "content_type": [analysis["content_type"]],
            "language": [analysis["language"]],
            "status": ["complete"]
        }
        
        # Extra metadata based on content type
        extra = {
            "toc": True,
            "github_edit": True
        }
        
        if analysis["content_type"] == "technical":
            extra.update({
                "code_examples": True,
                "mermaid_diagrams": False,
                "related_sections": [],
                "estimated_reading_time": 10
            })
        elif analysis["content_type"] == "academic":
            extra.update({
                "authors": ["Tomas Korcak"],
                "math_notation": False,
                "citations": False,
                "bibliography": False
            })
        elif analysis["content_type"] == "legal":
            extra.update({
                "legal_version": "1.0",
                "jurisdiction": "Czech Republic",
                "author": "Tomas Korcak"
            })
        
        frontmatter["extra"] = extra
        
        return toml.dumps(frontmatter)

    def migrate_file(self, file_path: Path, dry_run: bool = False) -> bool:
        """Add frontmatter to a single file."""
        if not file_path.exists() or file_path.suffix != '.md':
            return False
        
        # Skip special files
        if file_path.name.startswith('_') or file_path.name in ['README.md']:
            print(f"Skipping special file: {file_path}")
            return False
        
        analysis = self.analyze_content(file_path)
        if not analysis:
            print(f"Skipping {file_path} - already has frontmatter or couldn't analyze")
            return False
        
        try:
            # Read existing content
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Generate TOML frontmatter
            toml_frontmatter = self.generate_frontmatter(analysis)
            
            if dry_run:
                print(f"Would add frontmatter to: {file_path}")
                print("Frontmatter:")
                print("+++")
                print(toml_frontmatter)
                print("+++")
                print()
                return True
            
            # Write updated file
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write("+++\n")
                f.write(toml_frontmatter)
                f.write("+++\n\n")
                f.write(content)
            
            print(f"✅ Migrated: {file_path}")
            return True
            
        except Exception as e:
            print(f"❌ Error migrating {file_path}: {e}")
            return False

    def migrate_all(self, dry_run: bool = False) -> Tuple[int, int]:
        """Migrate all markdown files."""
        success_count = 0
        total_count = 0
        
        for md_file in self.docs_path.rglob("*.md"):
            total_count += 1
            if self.migrate_file(md_file, dry_run):
                success_count += 1
        
        return success_count, total_count

def main():
    parser = argparse.ArgumentParser(description="Generate TOML frontmatter for Prismatic documentation")
    parser.add_argument("--docs-path", default="docs", help="Path to documentation directory")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done without making changes")
    parser.add_argument("--file", help="Process single file instead of all files")
    
    args = parser.parse_args()
    
    migrator = DocumentationMigrator(args.docs_path)
    
    if args.file:
        file_path = Path(args.file)
        success = migrator.migrate_file(file_path, args.dry_run)
        if success:
            print(f"✅ Successfully processed {file_path}")
        else:
            print(f"❌ Failed to process {file_path}")
            sys.exit(1)
    else:
        print(f"🚀 Starting migration of documentation in {args.docs_path}")
        if args.dry_run:
            print("🔍 DRY RUN MODE - No files will be modified")
        
        success_count, total_count = migrator.migrate_all(args.dry_run)
        
        print(f"\n📊 Migration Summary:")
        print(f"   Total files processed: {total_count}")
        print(f"   Successfully migrated: {success_count}")
        print(f"   Failed: {total_count - success_count}")
        
        if success_count == total_count:
            print("🎉 All files migrated successfully!")
        elif success_count > 0:
            print("⚠️  Some files migrated successfully, check errors above")
        else:
            print("❌ Migration failed")
            sys.exit(1)

if __name__ == "__main__":
    main()