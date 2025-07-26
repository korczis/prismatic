#!/usr/bin/env python3
"""
Internal link validation script for Prismatic documentation.
Validates that all internal markdown links work correctly on both GitHub and Zola.
"""

import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple
from urllib.parse import urlparse, unquote

class LinkValidator:
    def __init__(self, docs_path: str = "docs"):
        self.docs_path = Path(docs_path)
        self.errors = []
        self.warnings = []
        self.all_files = set()
        self.all_sections = set()
        
        # Collect all files and sections
        self._collect_files()

    def _collect_files(self):
        """Collect all markdown files and sections."""
        for md_file in self.docs_path.rglob("*.md"):
            # Store relative path from docs root
            rel_path = md_file.relative_to(self.docs_path)
            self.all_files.add(str(rel_path))
            
            # If it's an index file, also add the directory as a section
            if md_file.name in ['_index.md', 'README.md']:
                section_path = str(rel_path.parent) if rel_path.parent != Path('.') else ""
                if section_path:
                    self.all_sections.add(section_path)

    def extract_links(self, content: str) -> List[Tuple[str, int]]:
        """Extract all markdown links from content."""
        links = []
        
        # Find all markdown links [text](url)
        link_pattern = r'\[([^\]]*)\]\(([^)]+)\)'
        for match in re.finditer(link_pattern, content):
            link_text = match.group(1)
            link_url = match.group(2)
            line_number = content[:match.start()].count('\n') + 1
            links.append((link_url, line_number))
        
        # Find all reference-style links [text][ref] and [ref]: url
        ref_links = {}
        ref_pattern = r'^\[([^\]]+)\]:\s*(.+)$'
        for match in re.finditer(ref_pattern, content, re.MULTILINE):
            ref_name = match.group(1)
            ref_url = match.group(2)
            ref_links[ref_name] = ref_url
        
        # Find usage of reference links
        ref_usage_pattern = r'\[([^\]]*)\]\[([^\]]+)\]'
        for match in re.finditer(ref_usage_pattern, content):
            ref_name = match.group(2)
            if ref_name in ref_links:
                line_number = content[:match.start()].count('\n') + 1
                links.append((ref_links[ref_name], line_number))
        
        return links

    def is_external_link(self, url: str) -> bool:
        """Check if a link is external (has scheme)."""
        parsed = urlparse(url)
        return bool(parsed.scheme)

    def normalize_path(self, path: str) -> str:
        """Normalize a file path for comparison."""
        # Remove URL fragments
        if '#' in path:
            path = path.split('#')[0]
        
        # URL decode
        path = unquote(path)
        
        # Normalize path separators
        path = path.replace('\\', '/')
        
        # Remove leading ./
        if path.startswith('./'):
            path = path[2:]
        
        return path

    def resolve_relative_link(self, current_file: Path, link_url: str) -> str:
        """Resolve a relative link from the current file."""
        if link_url.startswith('/'):
            # Absolute path from docs root
            return link_url[1:]
        
        # Relative path from current file
        current_dir = current_file.parent
        resolved = (current_dir / link_url).resolve()
        
        try:
            # Get path relative to docs root
            rel_path = resolved.relative_to(self.docs_path.resolve())
            return str(rel_path)
        except ValueError:
            # Path is outside docs directory
            return link_url

    def validate_internal_link(self, current_file: Path, link_url: str, line_number: int) -> bool:
        """Validate a single internal link."""
        original_url = link_url
        
        # Extract fragment (anchor)
        fragment = ""
        if '#' in link_url:
            link_url, fragment = link_url.split('#', 1)
        
        # Skip empty links (just fragments)
        if not link_url:
            return True
        
        # Normalize and resolve the path
        normalized_path = self.normalize_path(link_url)
        resolved_path = self.resolve_relative_link(current_file, normalized_path)
        
        # Check if target file exists
        target_exists = False
        
        # Direct file match
        if resolved_path in self.all_files:
            target_exists = True
        
        # Check for README.md in directory
        elif resolved_path in self.all_sections:
            readme_path = f"{resolved_path}/README.md"
            index_path = f"{resolved_path}/_index.md"
            if readme_path in self.all_files or index_path in self.all_files:
                target_exists = True
        
        # Check if it's a directory with index files
        elif not resolved_path.endswith('.md'):
            readme_path = f"{resolved_path}/README.md"
            index_path = f"{resolved_path}/_index.md"
            if readme_path in self.all_files or index_path in self.all_files:
                target_exists = True
        
        # Check for file without extension
        elif not resolved_path.endswith('.md'):
            md_path = f"{resolved_path}.md"
            if md_path in self.all_files:
                target_exists = True
        
        if not target_exists:
            rel_current = current_file.relative_to(self.docs_path)
            self.errors.append(f"{rel_current}:{line_number}: Broken link '{original_url}' -> '{resolved_path}'")
            return False
        
        # TODO: Validate fragments/anchors by parsing target file headers
        # This would require parsing the target file and extracting all headers
        
        return True

    def validate_zola_links(self, current_file: Path, link_url: str, line_number: int) -> bool:
        """Validate Zola-specific link syntax."""
        # Check for Zola internal links @/path/to/page.md
        if link_url.startswith('@/'):
            zola_path = link_url[2:]  # Remove @/
            
            # Normalize path
            normalized_path = self.normalize_path(zola_path)
            
            if normalized_path not in self.all_files:
                rel_current = current_file.relative_to(self.docs_path)
                self.errors.append(f"{rel_current}:{line_number}: Broken Zola link '{link_url}' -> '{normalized_path}'")
                return False
        
        return True

    def validate_file_links(self, file_path: Path) -> bool:
        """Validate all links in a single file."""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
        except UnicodeDecodeError:
            rel_path = file_path.relative_to(self.docs_path)
            self.errors.append(f"{rel_path}: Cannot read file as UTF-8")
            return False
        
        links = self.extract_links(content)
        all_valid = True
        
        for link_url, line_number in links:
            # Skip external links
            if self.is_external_link(link_url):
                continue
            
            # Skip mailto and other special schemes
            if link_url.startswith(('mailto:', 'tel:', 'javascript:')):
                continue
            
            # Validate Zola-specific links
            if not self.validate_zola_links(file_path, link_url, line_number):
                all_valid = False
                continue
            
            # Validate regular internal links
            if not self.validate_internal_link(file_path, link_url, line_number):
                all_valid = False
        
        return all_valid

    def check_orphaned_files(self):
        """Check for files that are not linked from anywhere."""
        linked_files = set()
        
        for md_file in self.docs_path.rglob("*.md"):
            if md_file.name.startswith('_'):
                continue
                
            try:
                with open(md_file, 'r', encoding='utf-8') as f:
                    content = f.read()
            except UnicodeDecodeError:
                continue
            
            links = self.extract_links(content)
            
            for link_url, _ in links:
                if self.is_external_link(link_url):
                    continue
                
                # Resolve and normalize the link
                normalized_path = self.normalize_path(link_url.split('#')[0])
                if normalized_path:
                    resolved_path = self.resolve_relative_link(md_file, normalized_path)
                    linked_files.add(resolved_path)
        
        # Find orphaned files (excluding special files)
        for file_path in self.all_files:
            if file_path.endswith(('README.md', '_index.md')):
                continue
            if file_path.startswith('_'):
                continue
            
            if file_path not in linked_files:
                self.warnings.append(f"Orphaned file (not linked from anywhere): {file_path}")

    def validate_all(self) -> Tuple[bool, int]:
        """Validate all links in all markdown files."""
        all_valid = True
        file_count = 0
        
        for md_file in self.docs_path.rglob("*.md"):
            file_count += 1
            if not self.validate_file_links(md_file):
                all_valid = False
        
        # Check for orphaned files
        self.check_orphaned_files()
        
        return all_valid, file_count

    def print_summary(self, file_count: int):
        """Print validation summary."""
        print(f"\n📊 Link Validation Summary:")
        print(f"   Files checked: {file_count}")
        print(f"   Total files found: {len(self.all_files)}")
        print(f"   Sections found: {len(self.all_sections)}")
        print(f"   Errors: {len(self.errors)}")
        print(f"   Warnings: {len(self.warnings)}")
        
        if self.errors:
            print(f"\n❌ Link Errors:")
            for error in self.errors:
                print(f"   {error}")
        
        if self.warnings:
            print(f"\n⚠️  Warnings:")
            for warning in self.warnings:
                print(f"   {warning}")
        
        if not self.errors and not self.warnings:
            print("✅ All links are valid!")
        elif not self.errors:
            print("✅ No broken links found (warnings can be ignored)")
        else:
            print("❌ Link validation failed - please fix broken links above")

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description="Validate internal links in Prismatic documentation")
    parser.add_argument("docs_path", nargs="?", default="docs", help="Path to documentation directory")
    parser.add_argument("--strict", action="store_true", help="Treat warnings as errors")
    
    args = parser.parse_args()
    
    validator = LinkValidator(args.docs_path)
    
    print(f"🔗 Validating internal links in {args.docs_path}")
    
    all_valid, file_count = validator.validate_all()
    validator.print_summary(file_count)
    
    # Exit with error code if validation failed
    if not all_valid or (args.strict and validator.warnings):
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()