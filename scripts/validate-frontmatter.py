#!/usr/bin/env python3
"""
TOML frontmatter validation script for Prismatic documentation.
Validates that all markdown files have proper TOML frontmatter with required fields.
"""

import os
import sys
import toml
import re
from pathlib import Path
from typing import Dict, List, Set, Tuple

class FrontmatterValidator:
    def __init__(self, docs_path: str = "docs"):
        self.docs_path = Path(docs_path)
        self.errors = []
        self.warnings = []
        
        # Required fields for all content
        self.required_fields = {
            "title": str,
            "description": str,
            "date": str,
            "weight": int
        }
        
        # Valid taxonomy values
        self.valid_taxonomies = {
            "categories": {"technical", "academic", "legal", "applications", "reference", "tutorial", "specification"},
            "difficulty": {"beginner", "intermediate", "advanced", "expert"},
            "audience": {"developers", "researchers", "medical", "legal", "business", "students", "operators"},
            "language": {"english", "czech", "slovak", "multilingual"},
            "status": {"draft", "review", "complete", "deprecated", "final", "living"},
            "content_type": {"documentation", "api-reference", "tutorial", "research-paper", "use-case", 
                           "specification", "legal-document", "kompendium", "guide", "overview"}
        }
        
        # Content-type specific requirements
        self.content_requirements = {
            "academic": {
                "required_extra": ["authors"],
                "recommended_extra": ["institution", "math_notation", "citations"]
            },
            "legal": {
                "required_extra": ["legal_version", "jurisdiction", "author"],
                "recommended_extra": ["effective_date", "binding"]
            },
            "applications": {
                "recommended_extra": ["industry", "use_case_type", "implementation_guide"]
            }
        }

    def extract_frontmatter(self, file_path: Path) -> Tuple[Dict, str]:
        """Extract TOML frontmatter from markdown file."""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
        except UnicodeDecodeError:
            self.errors.append(f"{file_path}: Cannot read file as UTF-8")
            return {}, ""
        
        # Check if file has frontmatter
        if not content.startswith('+++'):
            return {}, content
        
        # Find end of frontmatter
        end_match = re.search(r'\n\+\+\+\n', content)
        if not end_match:
            self.errors.append(f"{file_path}: Frontmatter not properly closed with +++")
            return {}, content
        
        frontmatter_text = content[3:end_match.start()]
        remaining_content = content[end_match.end():]
        
        try:
            frontmatter = toml.loads(frontmatter_text)
            return frontmatter, remaining_content
        except toml.TomlDecodeError as e:
            self.errors.append(f"{file_path}: Invalid TOML syntax - {e}")
            return {}, remaining_content

    def validate_required_fields(self, file_path: Path, frontmatter: Dict) -> bool:
        """Validate that all required fields are present and correct type."""
        valid = True
        
        for field, expected_type in self.required_fields.items():
            if field not in frontmatter:
                self.errors.append(f"{file_path}: Missing required field '{field}'")
                valid = False
            elif not isinstance(frontmatter[field], expected_type):
                self.errors.append(f"{file_path}: Field '{field}' should be {expected_type.__name__}, got {type(frontmatter[field]).__name__}")
                valid = False
        
        return valid

    def validate_date_format(self, file_path: Path, frontmatter: Dict) -> bool:
        """Validate date format (YYYY-MM-DD)."""
        if "date" not in frontmatter:
            return True  # Already caught by required fields check
        
        date_str = frontmatter["date"]
        if isinstance(date_str, str):
            if not re.match(r'^\d{4}-\d{2}-\d{2}$', date_str):
                self.errors.append(f"{file_path}: Date must be in YYYY-MM-DD format, got '{date_str}'")
                return False
        
        return True

    def validate_taxonomies(self, file_path: Path, frontmatter: Dict) -> bool:
        """Validate taxonomy values."""
        valid = True
        
        if "taxonomies" not in frontmatter:
            self.warnings.append(f"{file_path}: No taxonomies defined")
            return True
        
        taxonomies = frontmatter["taxonomies"]
        if not isinstance(taxonomies, dict):
            self.errors.append(f"{file_path}: Taxonomies must be a dictionary")
            return False
        
        for taxonomy_name, values in taxonomies.items():
            if taxonomy_name in self.valid_taxonomies:
                valid_values = self.valid_taxonomies[taxonomy_name]
                
                # Ensure values is a list
                if not isinstance(values, list):
                    self.errors.append(f"{file_path}: Taxonomy '{taxonomy_name}' must be a list")
                    valid = False
                    continue
                
                # Check each value
                for value in values:
                    if value not in valid_values:
                        self.errors.append(f"{file_path}: Invalid {taxonomy_name} value '{value}'. Valid values: {sorted(valid_values)}")
                        valid = False
            else:
                self.warnings.append(f"{file_path}: Unknown taxonomy '{taxonomy_name}'")
        
        return valid

    def validate_content_specific(self, file_path: Path, frontmatter: Dict) -> bool:
        """Validate content-type specific requirements."""
        valid = True
        
        taxonomies = frontmatter.get("taxonomies", {})
        categories = taxonomies.get("categories", [])
        
        if not categories:
            return True
        
        category = categories[0]  # Use first category
        if category in self.content_requirements:
            requirements = self.content_requirements[category]
            extra = frontmatter.get("extra", {})
            
            # Check required extra fields
            for required_field in requirements.get("required_extra", []):
                if required_field not in extra:
                    self.errors.append(f"{file_path}: Content type '{category}' requires extra field '{required_field}'")
                    valid = False
            
            # Check recommended extra fields
            for recommended_field in requirements.get("recommended_extra", []):
                if recommended_field not in extra:
                    self.warnings.append(f"{file_path}: Content type '{category}' recommends extra field '{recommended_field}'")
        
        return valid

    def validate_weight_range(self, file_path: Path, frontmatter: Dict) -> bool:
        """Validate weight is in reasonable range."""
        if "weight" not in frontmatter:
            return True
        
        weight = frontmatter["weight"]
        if not isinstance(weight, int) or weight < 1 or weight > 100:
            self.errors.append(f"{file_path}: Weight should be between 1 and 100, got {weight}")
            return False
        
        return True

    def validate_extra_fields(self, file_path: Path, frontmatter: Dict) -> bool:
        """Validate extra fields have reasonable values."""
        valid = True
        extra = frontmatter.get("extra", {})
        
        if not isinstance(extra, dict):
            self.errors.append(f"{file_path}: Extra section must be a dictionary")
            return False
        
        # Validate boolean fields
        boolean_fields = ["toc", "github_edit", "code_examples", "mermaid_diagrams", 
                         "math_notation", "citations", "bibliography", "binding"]
        for field in boolean_fields:
            if field in extra and not isinstance(extra[field], bool):
                self.errors.append(f"{file_path}: Extra field '{field}' must be boolean")
                valid = False
        
        # Validate integer fields
        integer_fields = ["estimated_reading_time", "complexity_score", "access_level"]
        for field in integer_fields:
            if field in extra and not isinstance(extra[field], int):
                self.errors.append(f"{file_path}: Extra field '{field}' must be integer")
                valid = False
        
        # Validate list fields
        list_fields = ["related_sections", "prerequisites", "leads_to", "authors"]
        for field in list_fields:
            if field in extra and not isinstance(extra[field], list):
                self.errors.append(f"{file_path}: Extra field '{field}' must be a list")
                valid = False
        
        return valid

    def validate_file(self, file_path: Path) -> bool:
        """Validate a single markdown file."""
        # Skip special files
        if file_path.name.startswith('_') or file_path.name == 'README.md':
            return True
        
        frontmatter, content = self.extract_frontmatter(file_path)
        
        if not frontmatter:
            if file_path.suffix == '.md':
                self.warnings.append(f"{file_path}: No TOML frontmatter found")
            return True
        
        valid = True
        valid &= self.validate_required_fields(file_path, frontmatter)
        valid &= self.validate_date_format(file_path, frontmatter)
        valid &= self.validate_taxonomies(file_path, frontmatter)
        valid &= self.validate_content_specific(file_path, frontmatter)
        valid &= self.validate_weight_range(file_path, frontmatter)
        valid &= self.validate_extra_fields(file_path, frontmatter)
        
        return valid

    def validate_all(self) -> bool:
        """Validate all markdown files in the documentation."""
        all_valid = True
        file_count = 0
        
        for md_file in self.docs_path.rglob("*.md"):
            file_count += 1
            if not self.validate_file(md_file):
                all_valid = False
        
        return all_valid, file_count

    def print_summary(self, file_count: int):
        """Print validation summary."""
        print(f"\n📊 Validation Summary:")
        print(f"   Files checked: {file_count}")
        print(f"   Errors: {len(self.errors)}")
        print(f"   Warnings: {len(self.warnings)}")
        
        if self.errors:
            print(f"\n❌ Errors:")
            for error in self.errors:
                print(f"   {error}")
        
        if self.warnings:
            print(f"\n⚠️  Warnings:")
            for warning in self.warnings:
                print(f"   {warning}")
        
        if not self.errors and not self.warnings:
            print("✅ All files passed validation!")
        elif not self.errors:
            print("✅ No errors found (warnings can be ignored)")
        else:
            print("❌ Validation failed - please fix errors above")

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="Validate TOML frontmatter in Prismatic documentation")
    parser.add_argument("docs_path", nargs="?", default="docs", help="Path to documentation directory")
    parser.add_argument("--strict", action="store_true", help="Treat warnings as errors")
    
    args = parser.parse_args()
    
    validator = FrontmatterValidator(args.docs_path)
    
    print(f"🔍 Validating TOML frontmatter in {args.docs_path}")
    
    all_valid, file_count = validator.validate_all()
    validator.print_summary(file_count)
    
    # Exit with error code if validation failed
    if not all_valid or (args.strict and validator.warnings):
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()