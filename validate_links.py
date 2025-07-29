#!/usr/bin/env python3
"""
Documentation Links Validator

This script validates all internal links extracted from markdown files to ensure they point to 
existing files and sections. It generates a comprehensive validation report with details about
broken links, suspicious links, and suggested corrections.
"""

import json
import os
import re
from pathlib import Path
from typing import Dict, List, Set, Tuple, Optional
from datetime import datetime
import urllib.parse

class LinkValidator:
    def __init__(self, base_dir: str = "docs"):
        self.base_dir = Path(base_dir)
        self.project_root = Path(".")
        self.valid_links = []
        self.broken_links = []
        self.suspicious_links = []
        
        # Load existing files from inventory or scan filesystem
        self.existing_files = self._build_file_inventory()
        
    def _build_file_inventory(self) -> Set[str]:
        """Build inventory of all existing files in the project."""
        existing_files = set()
        
        # Scan the entire project for files
        for root, dirs, files in os.walk(self.project_root):
            # Skip hidden directories and common build/cache directories
            dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ['node_modules', '__pycache__', 'build', 'dist']]
            
            for file in files:
                file_path = Path(root) / file
                # Store relative path from project root
                rel_path = file_path.relative_to(self.project_root)
                existing_files.add(str(rel_path))
                
        return existing_files
    
    def _resolve_relative_path(self, source_file: str, target_path: str) -> str:
        """Resolve relative path from source file to target."""
        source_dir = Path(source_file).parent
        resolved_path = (source_dir / target_path).resolve()
        
        # Convert back to relative path from project root
        try:
            rel_path = resolved_path.relative_to(self.project_root.resolve())
            return str(rel_path)
        except ValueError:
            # Path is outside project root
            return str(resolved_path)
    
    def _extract_anchors_from_file(self, file_path: str) -> Set[str]:
        """Extract all possible anchor targets from a markdown file."""
        anchors = set()
        full_path = self.project_root / file_path
        
        if not full_path.exists() or not full_path.is_file():
            return anchors
            
        try:
            with open(full_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            # Find markdown headers (# ## ### etc.)
            header_pattern = re.compile(r'^#{1,6}\s+(.+)$', re.MULTILINE)
            headers = header_pattern.findall(content)
            
            for header in headers:
                # Convert header to anchor format (lowercase, spaces to hyphens, remove special chars)
                anchor = re.sub(r'[^\w\s-]', '', header.lower())
                anchor = re.sub(r'[\s_]+', '-', anchor)
                anchor = anchor.strip('-')
                anchors.add(anchor)
                
            # Also look for explicit anchor tags
            anchor_pattern = re.compile(r'<a\s+[^>]*name\s*=\s*["\']([^"\']+)["\'][^>]*>', re.IGNORECASE)
            explicit_anchors = anchor_pattern.findall(content)
            anchors.update(explicit_anchors)
            
            # Look for id attributes
            id_pattern = re.compile(r'id\s*=\s*["\']([^"\']+)["\']', re.IGNORECASE)
            id_anchors = id_pattern.findall(content)
            anchors.update(id_anchors)
            
        except Exception as e:
            print(f"Warning: Could not read {file_path}: {e}")
            
        return anchors
    
    def _find_case_variants(self, target_path: str) -> List[str]:
        """Find files that match the target path with different case."""
        variants = []
        target_lower = target_path.lower()
        
        for existing_file in self.existing_files:
            if existing_file.lower() == target_lower and existing_file != target_path:
                variants.append(existing_file)
                
        return variants
    
    def _suggest_corrections(self, target_path: str, source_file: str) -> List[str]:
        """Suggest possible corrections for broken links."""
        suggestions = []
        
        # Look for case variants
        case_variants = self._find_case_variants(target_path)
        suggestions.extend(case_variants)
        
        # Look for similar file names (simple fuzzy matching)
        target_name = Path(target_path).name.lower()
        target_stem = Path(target_path).stem.lower()
        
        for existing_file in self.existing_files:
            existing_name = Path(existing_file).name.lower()
            existing_stem = Path(existing_file).stem.lower()
            
            # Exact stem match (different extension)
            if target_stem == existing_stem and existing_file not in suggestions:
                suggestions.append(existing_file)
                
            # Similar name (simple substring check)
            elif (target_stem in existing_stem or existing_stem in target_stem) and len(suggestions) < 5:
                if existing_file not in suggestions:
                    suggestions.append(existing_file)
        
        return suggestions[:3]  # Limit to top 3 suggestions
    
    def validate_link(self, link_data: Dict) -> Dict:
        """Validate a single link and return validation result."""
        source_file = link_data['source_file']
        destination = link_data['destination']
        link_text = link_data['link_text']
        link_type = link_data['link_type']
        line_number = link_data['line_number']
        
        result = {
            'source_file': source_file,
            'line_number': line_number,
            'link_text': link_text,
            'destination': destination,
            'link_type': link_type,
            'raw_match': link_data['raw_match'],
            'status': 'valid',
            'issues': [],
            'suggestions': []
        }
        
        # Skip external links and reference links
        if link_type in ['external', 'reference']:
            return result
            
        # Handle anchor-only links (internal page anchors)
        if link_type == 'anchor':
            anchor = destination.lstrip('#')
            if anchor:
                # Check if anchor exists in source file
                source_anchors = self._extract_anchors_from_file(source_file)
                if anchor not in source_anchors:
                    result['status'] = 'broken'
                    result['issues'].append(f"Anchor '#{anchor}' not found in source file")
            return result
        
        # Parse destination for file path and anchor
        if '#' in destination:
            file_path, anchor = destination.split('#', 1)
            anchor = urllib.parse.unquote(anchor)  # URL decode anchor
        else:
            file_path = destination
            anchor = None
            
        # Resolve file path
        if link_type == 'internal-absolute':
            # Remove leading slash and resolve from project root
            target_path = file_path.lstrip('/')
        else:  # internal-relative
            target_path = self._resolve_relative_path(source_file, file_path)
            
        # Check if target file exists
        file_exists = target_path in self.existing_files
        
        if not file_exists:
            result['status'] = 'broken'
            result['issues'].append(f"Target file '{target_path}' does not exist")
            
            # Look for case variants
            case_variants = self._find_case_variants(target_path)
            if case_variants:
                result['status'] = 'suspicious'
                result['issues'][-1] = f"Target file '{target_path}' not found, but case variants exist"
                result['suggestions'] = case_variants
            else:
                # Look for other suggestions
                suggestions = self._suggest_corrections(target_path, source_file)
                if suggestions:
                    result['suggestions'] = suggestions
        else:
            # File exists, check anchor if present
            if anchor:
                target_anchors = self._extract_anchors_from_file(target_path)
                if anchor not in target_anchors:
                    result['status'] = 'broken'
                    result['issues'].append(f"Anchor '#{anchor}' not found in target file '{target_path}'")
                    
                    # Suggest similar anchors
                    similar_anchors = [a for a in target_anchors if anchor.lower() in a.lower() or a.lower() in anchor.lower()]
                    if similar_anchors:
                        result['suggestions'] = [f"#{a}" for a in similar_anchors[:3]]
        
        return result
    
    def validate_all_links(self, links_data: Dict) -> Dict:
        """Validate all internal links and generate comprehensive report."""
        print("Starting link validation...")
        
        links = links_data['links']
        internal_links = [link for link in links if link['link_type'] in ['internal-relative', 'internal-absolute', 'anchor']]
        
        print(f"Validating {len(internal_links)} internal links...")
        
        validation_results = []
        valid_count = 0
        broken_count = 0
        suspicious_count = 0
        
        for i, link in enumerate(internal_links):
            if i % 50 == 0:
                print(f"Processing link {i+1}/{len(internal_links)}...")
                
            result = self.validate_link(link)
            validation_results.append(result)
            
            if result['status'] == 'valid':
                valid_count += 1
                self.valid_links.append(result)
            elif result['status'] == 'broken':
                broken_count += 1
                self.broken_links.append(result)
            elif result['status'] == 'suspicious':
                suspicious_count += 1
                self.suspicious_links.append(result)
        
        # Generate summary statistics
        summary_stats = {
            'total_internal_links': len(internal_links),
            'valid_links': valid_count,
            'broken_links': broken_count,
            'suspicious_links': suspicious_count,
            'validation_success_rate': round((valid_count / len(internal_links)) * 100, 2) if internal_links else 0
        }
        
        # Analyze broken links by type
        broken_by_type = {}
        for link in self.broken_links:
            link_type = link['link_type']
            broken_by_type[link_type] = broken_by_type.get(link_type, 0) + 1
            
        # Find most common issues
        issue_counts = {}
        for link in self.broken_links + self.suspicious_links:
            for issue in link['issues']:
                issue_type = issue.split(':')[0] if ':' in issue else issue
                issue_counts[issue_type] = issue_counts.get(issue_type, 0) + 1
        
        common_issues = sorted(issue_counts.items(), key=lambda x: x[1], reverse=True)[:5]
        
        # Generate comprehensive report
        report = {
            'metadata': {
                'validation_date': datetime.utcnow().isoformat() + 'Z',
                'validator_version': '1.0.0',
                'base_directory': str(self.base_dir),
                'total_files_scanned': len(self.existing_files)
            },
            'summary_statistics': summary_stats,
            'validation_breakdown': {
                'by_link_type': {
                    'internal-relative': len([l for l in internal_links if l['link_type'] == 'internal-relative']),
                    'internal-absolute': len([l for l in internal_links if l['link_type'] == 'internal-absolute']),
                    'anchor': len([l for l in internal_links if l['link_type'] == 'anchor'])
                },
                'broken_by_type': broken_by_type,
                'common_issues': [{'issue': issue, 'count': count} for issue, count in common_issues]
            },
            'validation_results': {
                'valid_links': self.valid_links,
                'broken_links': self.broken_links,
                'suspicious_links': self.suspicious_links
            },
            'critical_issues': self._identify_critical_issues()
        }
        
        print(f"\nValidation completed!")
        print(f"✅ Valid links: {valid_count}")
        print(f"❌ Broken links: {broken_count}")
        print(f"⚠️  Suspicious links: {suspicious_count}")
        print(f"📊 Success rate: {summary_stats['validation_success_rate']}%")
        
        return report
    
    def _identify_critical_issues(self) -> List[Dict]:
        """Identify critical broken links that need immediate attention."""
        critical_issues = []
        
        # Links in main navigation files
        navigation_files = ['docs/README.md', 'docs/guides/README.md', 'docs/core/README.md', 
                          'docs/operations/README.md', 'docs/reference/README.md']
        
        for link in self.broken_links:
            if link['source_file'] in navigation_files:
                critical_issues.append({
                    'type': 'broken_navigation_link',
                    'source_file': link['source_file'],
                    'destination': link['destination'],
                    'line_number': link['line_number'],
                    'reason': 'Broken link in main navigation file'
                })
        
        # Frequently referenced broken links
        broken_destinations = {}
        for link in self.broken_links:
            dest = link['destination']
            if dest not in broken_destinations:
                broken_destinations[dest] = []
            broken_destinations[dest].append(link)
        
        for dest, links in broken_destinations.items():
            if len(links) > 2:  # Referenced from multiple files
                critical_issues.append({
                    'type': 'frequently_broken_link',
                    'destination': dest,
                    'reference_count': len(links),
                    'source_files': [link['source_file'] for link in links],
                    'reason': f'Broken link referenced from {len(links)} different files'
                })
        
        return critical_issues


def main():
    # Load extracted links data
    print("Loading extracted links data...")
    try:
        with open('docs-links-extracted.json', 'r', encoding='utf-8') as f:
            links_data = json.load(f)
    except FileNotFoundError:
        print("Error: docs-links-extracted.json not found. Please run the link extraction first.")
        return
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in docs-links-extracted.json: {e}")
        return
    
    # Initialize validator
    validator = LinkValidator()
    
    # Validate all links
    validation_report = validator.validate_all_links(links_data)
    
    # Save validation report
    output_file = 'docs-links-validation-report.json'
    print(f"\nSaving validation report to {output_file}...")
    
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(validation_report, f, indent=2, ensure_ascii=False)
        print(f"✅ Validation report saved successfully!")
    except Exception as e:
        print(f"❌ Error saving validation report: {e}")
        return
    
    # Print summary
    print("\n" + "="*60)
    print("VALIDATION SUMMARY")
    print("="*60)
    
    stats = validation_report['summary_statistics']
    print(f"Total internal links validated: {stats['total_internal_links']}")
    print(f"Valid links: {stats['valid_links']}")
    print(f"Broken links: {stats['broken_links']}")
    print(f"Suspicious links: {stats['suspicious_links']}")
    print(f"Validation success rate: {stats['validation_success_rate']}%")
    
    if validation_report['critical_issues']:
        print(f"\n⚠️  CRITICAL ISSUES FOUND: {len(validation_report['critical_issues'])}")
        for issue in validation_report['critical_issues'][:3]:  # Show top 3
            print(f"   • {issue['reason']}")
            if issue['type'] == 'broken_navigation_link':
                print(f"     File: {issue['source_file']} (line {issue['line_number']})")
            elif issue['type'] == 'frequently_broken_link':
                print(f"     Target: {issue['destination']} (referenced {issue['reference_count']} times)")
    
    if validation_report['validation_breakdown']['common_issues']:
        print(f"\nMOST COMMON ISSUES:")
        for issue in validation_report['validation_breakdown']['common_issues'][:3]:
            print(f"   • {issue['issue']}: {issue['count']} occurrences")
    
    print(f"\nDetailed validation report saved to: {output_file}")


if __name__ == "__main__":
    main()