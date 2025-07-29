#!/usr/bin/env python3
"""
Comprehensive Markdown Link Extractor
Extracts all types of links from markdown files and creates a database.
"""

import re
import json
import os
from pathlib import Path
from typing import Dict, List, Tuple, Any
from dataclasses import dataclass, asdict
from urllib.parse import urlparse

@dataclass
class LinkData:
    """Data structure for extracted link information"""
    source_file: str
    line_number: int
    link_text: str
    destination: str
    link_type: str
    raw_match: str

class MarkdownLinkExtractor:
    """Extracts and categorizes all types of markdown links"""
    
    def __init__(self):
        # Regex patterns for different link types
        self.patterns = {
            # Standard markdown links [text](url)
            'inline': re.compile(r'\[([^\]]*)\]\(([^)]+)\)', re.MULTILINE),
            
            # Reference-style links [text][ref]
            'reference': re.compile(r'\[([^\]]*)\]\[([^\]]*)\]', re.MULTILINE),
            
            # Reference definitions [ref]: url
            'reference_def': re.compile(r'^\s*\[([^\]]+)\]:\s*(.+)$', re.MULTILINE),
            
            # Auto-links <url>
            'autolink': re.compile(r'<((?:https?|ftp)://[^>]+)>', re.MULTILINE),
            
            # Image links ![alt](url)
            'image': re.compile(r'!\[([^\]]*)\]\(([^)]+)\)', re.MULTILINE)
        }
        
        self.extracted_links = []
        self.reference_definitions = {}
        
    def classify_link_type(self, destination: str, source_file: str) -> str:
        """Classify the type of link based on its destination"""
        # Clean up destination (remove quotes, spaces)
        dest = destination.strip().strip('"\'')
        
        # External links (http/https/ftp)
        if dest.startswith(('http://', 'https://', 'ftp://')):
            return 'external'
            
        # Email links
        if dest.startswith('mailto:'):
            return 'external'
            
        # Anchor links (same document)
        if dest.startswith('#'):
            return 'anchor'
            
        # Absolute internal links (starting with /)
        if dest.startswith('/'):
            return 'internal-absolute'
            
        # Relative links with explicit relative indicators
        if dest.startswith('./') or dest.startswith('../'):
            return 'internal-relative'
            
        # Check if it looks like a file path
        if '.' in dest or '/' in dest:
            return 'internal-relative'
            
        # Default to internal-relative for other cases
        return 'internal-relative'
    
    def extract_links_from_content(self, content: str, file_path: str) -> List[LinkData]:
        """Extract all links from markdown content"""
        links = []
        lines = content.split('\n')
        
        # First pass: collect reference definitions
        file_references = {}
        for line_num, line in enumerate(lines, 1):
            ref_matches = self.patterns['reference_def'].finditer(line)
            for match in ref_matches:
                ref_key = match.group(1).lower()
                ref_url = match.group(2).strip()
                file_references[ref_key] = ref_url
                
                # Add reference definition as a link entry
                links.append(LinkData(
                    source_file=file_path,
                    line_number=line_num,
                    link_text=f"[{match.group(1)}]",
                    destination=ref_url,
                    link_type=self.classify_link_type(ref_url, file_path),
                    raw_match=match.group(0)
                ))
        
        # Second pass: extract all other links
        for line_num, line in enumerate(lines, 1):
            # Inline links [text](url)
            inline_matches = self.patterns['inline'].finditer(line)
            for match in inline_matches:
                links.append(LinkData(
                    source_file=file_path,
                    line_number=line_num,
                    link_text=match.group(1),
                    destination=match.group(2),
                    link_type=self.classify_link_type(match.group(2), file_path),
                    raw_match=match.group(0)
                ))
            
            # Reference-style links [text][ref]
            ref_matches = self.patterns['reference'].finditer(line)
            for match in ref_matches:
                ref_key = match.group(2).lower() if match.group(2) else match.group(1).lower()
                ref_url = file_references.get(ref_key, f"UNRESOLVED:{ref_key}")
                
                links.append(LinkData(
                    source_file=file_path,
                    line_number=line_num,
                    link_text=match.group(1),
                    destination=ref_url,
                    link_type='reference' if ref_url.startswith('UNRESOLVED:') else self.classify_link_type(ref_url, file_path),
                    raw_match=match.group(0)
                ))
            
            # Auto-links <url>
            auto_matches = self.patterns['autolink'].finditer(line)
            for match in auto_matches:
                links.append(LinkData(
                    source_file=file_path,
                    line_number=line_num,
                    link_text=match.group(1),
                    destination=match.group(1),
                    link_type='external',
                    raw_match=match.group(0)
                ))
            
            # Image links ![alt](url)
            img_matches = self.patterns['image'].finditer(line)
            for match in img_matches:
                links.append(LinkData(
                    source_file=file_path,
                    line_number=line_num,
                    link_text=f"[IMAGE: {match.group(1)}]",
                    destination=match.group(2),
                    link_type=f"image-{self.classify_link_type(match.group(2), file_path)}",
                    raw_match=match.group(0)
                ))
        
        return links
    
    def process_file(self, file_path: str) -> List[LinkData]:
        """Process a single markdown file and extract all links"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            return self.extract_links_from_content(content, file_path)
            
        except Exception as e:
            print(f"Error processing {file_path}: {e}")
            return []
    
    def process_files(self, file_paths: List[str]) -> Dict[str, Any]:
        """Process multiple markdown files and create comprehensive database"""
        all_links = []
        stats = {
            'total_files_processed': 0,
            'total_links_found': 0,
            'links_by_type': {},
            'links_by_file': {},
            'files_with_errors': []
        }
        
        for file_path in file_paths:
            print(f"Processing: {file_path}")
            try:
                links = self.process_file(file_path)
                all_links.extend(links)
                
                stats['total_files_processed'] += 1
                stats['links_by_file'][file_path] = len(links)
                
                # Count by type
                for link in links:
                    link_type = link.link_type
                    stats['links_by_type'][link_type] = stats['links_by_type'].get(link_type, 0) + 1
                    
            except Exception as e:
                print(f"Error processing {file_path}: {e}")
                stats['files_with_errors'].append({'file': file_path, 'error': str(e)})
        
        stats['total_links_found'] = len(all_links)
        
        # Create comprehensive database
        database = {
            'metadata': {
                'extraction_date': '2025-07-29T04:43:00Z',
                'total_files_processed': stats['total_files_processed'],
                'total_links_extracted': stats['total_links_found'],
                'extractor_version': '1.0.0'
            },
            'statistics': stats,
            'links': [asdict(link) for link in all_links]
        }
        
        return database

def main():
    """Main function to extract links from all markdown files"""
    
    # List of all markdown files from the inventory
    markdown_files = [
        'docs/README.md',
        'docs/architecture/README.md',
        'docs/core/README.md',
        'docs/core/architecture-overview.md',
        'docs/core/tech-stack.md',
        'docs/_meta/README.md',
        'docs/_meta/cross-reference-guide.md',
        'docs/_meta/feature-documentation-workflow.md',
        'docs/_meta/maintenance-process.md',
        'docs/_meta/naming-conventions.md',
        'docs/guides/README.md',
        'docs/guides/branch-workflow-migration-plan.md',
        'docs/guides/coding-standards.md',
        'docs/guides/comprehensive-feature-branch-workflow.md',
        'docs/guides/deployment-team-adoption-strategy.md',
        'docs/guides/developer-experience.md',
        'docs/guides/documentation-integration.md',
        'docs/guides/documentation-navigation-cicd.md',
        'docs/guides/documentation-navigation-implementation.md',
        'docs/guides/documentation-navigation-migration.md',
        'docs/guides/documentation-navigation-mix-tasks.md',
        'docs/guides/documentation-navigation-standards.md',
        'docs/guides/documentation-navigation-templates.md',
        'docs/guides/documentation-navigation-validation.md',
        'docs/guides/git-hooks-implementation.md',
        'docs/guides/github-actions-implementation.md',
        'docs/guides/gitlab-ci-implementation.md',
        'docs/guides/mix-tasks-implementation.md',
        'docs/guides/workflow-configuration-files.md',
        'docs/guides/workflow-testing-validation.md',
        'docs/operations/README.md',
        'docs/operations/deployment-procedures.md',
        'docs/operations/troubleshooting.md',
        'docs/reference/README.md',
        'docs/reference/glossary.md',
        'docs/shared/README.md'
    ]
    
    print(f"Starting link extraction from {len(markdown_files)} markdown files...")
    
    extractor = MarkdownLinkExtractor()
    database = extractor.process_files(markdown_files)
    
    # Save the comprehensive database
    output_file = 'docs-links-extracted.json'
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(database, f, indent=2, ensure_ascii=False)
    
    print(f"\n=== EXTRACTION COMPLETE ===")
    print(f"Database saved to: {output_file}")
    print(f"Total files processed: {database['metadata']['total_files_processed']}")
    print(f"Total links extracted: {database['metadata']['total_links_extracted']}")
    
    print(f"\n=== LINK TYPE BREAKDOWN ===")
    for link_type, count in sorted(database['statistics']['links_by_type'].items()):
        print(f"  {link_type}: {count}")
    
    print(f"\n=== TOP FILES BY LINK COUNT ===")
    files_by_links = sorted(database['statistics']['links_by_file'].items(), 
                           key=lambda x: x[1], reverse=True)
    for file_path, count in files_by_links[:10]:
        print(f"  {file_path}: {count} links")
    
    if database['statistics']['files_with_errors']:
        print(f"\n=== FILES WITH ERRORS ===")
        for error_info in database['statistics']['files_with_errors']:
            print(f"  {error_info['file']}: {error_info['error']}")

if __name__ == '__main__':
    main()