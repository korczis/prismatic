#!/usr/bin/env python3
"""
External Documentation Links Validator

This script validates all external links extracted from markdown files to ensure they are 
accessible and functioning. It performs comprehensive checks including URL accessibility,
redirect handling, response time measurement, SSL/TLS validation, and content type detection.
"""

import json
import time
import ssl
import urllib.parse
import urllib.request
import urllib.error
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from datetime import datetime
import socket
import certifi
import re

class ExternalLinkValidator:
    def __init__(self, timeout: int = 10, max_redirects: int = 5, user_agent: str = None):
        self.timeout = timeout
        self.max_redirects = max_redirects
        self.user_agent = user_agent or "Prismatic-Docs-Validator/1.0 (External Link Checker)"
        
        # Statistics tracking
        self.total_links = 0
        self.accessible_links = []
        self.broken_links = []
        self.redirected_links = []
        self.slow_links = []
        self.ssl_issues = []
        
        # Rate limiting
        self.request_interval = 0.5  # 500ms between requests
        self.last_request_time = 0
        
        # SSL context for certificate validation
        self.ssl_context = ssl.create_default_context(cafile=certifi.where())
        self.ssl_context.check_hostname = True
        self.ssl_context.verify_mode = ssl.CERT_REQUIRED

    def _rate_limit(self):
        """Implement rate limiting between requests."""
        current_time = time.time()
        time_since_last = current_time - self.last_request_time
        if time_since_last < self.request_interval:
            time.sleep(self.request_interval - time_since_last)
        self.last_request_time = time.time()

    def _create_request(self, url: str) -> urllib.request.Request:
        """Create HTTP request with proper headers."""
        headers = {
            'User-Agent': self.user_agent,
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Accept-Encoding': 'gzip, deflate',
            'DNT': '1',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        }
        
        req = urllib.request.Request(url, headers=headers)
        return req

    def _follow_redirects(self, url: str) -> Tuple[str, List[str], int]:
        """Follow redirects manually to track the redirect chain."""
        redirect_chain = [url]
        current_url = url
        redirect_count = 0
        final_status = None
        
        while redirect_count < self.max_redirects:
            try:
                req = self._create_request(current_url)
                
                # Create custom opener with no redirect handler
                opener = urllib.request.build_opener()
                
                # Configure SSL context for HTTPS requests
                if current_url.startswith('https://'):
                    https_handler = urllib.request.HTTPSHandler(context=self.ssl_context)
                    opener.add_handler(https_handler)
                
                response = opener.open(req, timeout=self.timeout)
                final_status = response.getcode()
                
                # If we get here, no redirect occurred
                break
                
            except urllib.error.HTTPError as e:
                # Check for redirect status codes
                if e.code in [301, 302, 303, 307, 308]:
                    redirect_count += 1
                    location = e.headers.get('Location')
                    if not location:
                        break
                    
                    # Handle relative redirects
                    if location.startswith('/'):
                        parsed_url = urllib.parse.urlparse(current_url)
                        location = f"{parsed_url.scheme}://{parsed_url.netloc}{location}"
                    elif not location.startswith(('http://', 'https://')):
                        # Relative to current directory
                        parsed_url = urllib.parse.urlparse(current_url)
                        base_url = f"{parsed_url.scheme}://{parsed_url.netloc}{parsed_url.path}"
                        if not base_url.endswith('/'):
                            base_url = '/'.join(base_url.split('/')[:-1]) + '/'
                        location = base_url + location
                    
                    current_url = location
                    redirect_chain.append(current_url)
                    continue
                else:
                    final_status = e.code
                    break
            except Exception:
                break
        
        return current_url, redirect_chain, final_status

    def _detect_content_type(self, response) -> str:
        """Detect content type from response headers."""
        content_type = response.headers.get('Content-Type', '').lower()
        
        # Extract main content type
        if ';' in content_type:
            content_type = content_type.split(';')[0].strip()
        
        # Map to readable categories
        if content_type.startswith('text/html'):
            return 'HTML Document'
        elif content_type.startswith('text/'):
            return 'Text Document'
        elif content_type.startswith('application/pdf'):
            return 'PDF Document'
        elif content_type.startswith('application/json'):
            return 'JSON Data'
        elif content_type.startswith('application/xml') or content_type.startswith('text/xml'):
            return 'XML Document'
        elif content_type.startswith('image/'):
            return 'Image'
        elif content_type.startswith('video/'):
            return 'Video'
        elif content_type.startswith('audio/'):
            return 'Audio'
        elif content_type.startswith('application/'):
            return 'Application Data'
        else:
            return content_type or 'Unknown'

    def validate_external_link(self, link_data: Dict) -> Dict:
        """Validate a single external link and return comprehensive result."""
        url = link_data['destination']
        source_file = link_data['source_file']
        line_number = link_data['line_number']
        link_text = link_data['link_text']
        
        result = {
            'source_file': source_file,
            'line_number': line_number,
            'link_text': link_text,
            'url': url,
            'status': 'unknown',
            'http_status_code': None,
            'response_time_ms': None,
            'final_url': url,
            'redirect_chain': [],
            'content_type': None,
            'ssl_valid': None,
            'error_details': None,
            'issues': [],
            'raw_match': link_data['raw_match']
        }
        
        # Rate limiting
        self._rate_limit()
        
        start_time = time.time()
        
        try:
            # Follow redirects manually to get full chain
            final_url, redirect_chain, status_code = self._follow_redirects(url)
            
            # Make final request to get response details
            req = self._create_request(final_url)
            
            # Configure opener with SSL context
            opener = urllib.request.build_opener()
            if final_url.startswith('https://'):
                https_handler = urllib.request.HTTPSHandler(context=self.ssl_context)
                opener.add_handler(https_handler)
            
            response = opener.open(req, timeout=self.timeout)
            
            # Calculate response time
            response_time = (time.time() - start_time) * 1000
            
            # Collect response information
            result.update({
                'status': 'accessible',
                'http_status_code': response.getcode(),
                'response_time_ms': round(response_time, 2),
                'final_url': final_url,
                'redirect_chain': redirect_chain if len(redirect_chain) > 1 else [],
                'content_type': self._detect_content_type(response),
                'ssl_valid': True if final_url.startswith('https://') else None
            })
            
            # Check for slow response
            if response_time > 5000:  # 5 seconds
                result['issues'].append(f"Slow response time: {response_time:.0f}ms")
                
            # Check for redirects
            if len(redirect_chain) > 1:
                result['issues'].append(f"Redirected {len(redirect_chain)-1} times")
                
        except urllib.error.HTTPError as e:
            response_time = (time.time() - start_time) * 1000
            result.update({
                'status': 'broken',
                'http_status_code': e.code,
                'response_time_ms': round(response_time, 2),
                'error_details': f"HTTP {e.code}: {e.reason}",
                'issues': [f"HTTP error {e.code}: {e.reason}"]
            })
            
        except urllib.error.URLError as e:
            response_time = (time.time() - start_time) * 1000
            result.update({
                'status': 'broken',
                'response_time_ms': round(response_time, 2)
            })
            
            if isinstance(e.reason, ssl.SSLError):
                result.update({
                    'ssl_valid': False,
                    'error_details': f"SSL Error: {str(e.reason)}",
                    'issues': [f"SSL certificate error: {str(e.reason)}"]
                })
            elif isinstance(e.reason, socket.gaierror):
                result.update({
                    'error_details': f"DNS resolution failed: {str(e.reason)}",
                    'issues': [f"DNS resolution failed: {str(e.reason)}"]
                })
            else:
                result.update({
                    'error_details': f"Connection error: {str(e.reason)}",
                    'issues': [f"Connection error: {str(e.reason)}"]
                })
                
        except socket.timeout:
            response_time = (time.time() - start_time) * 1000
            result.update({
                'status': 'timeout',
                'response_time_ms': round(response_time, 2),
                'error_details': f"Request timeout after {self.timeout} seconds",
                'issues': [f"Request timeout after {self.timeout} seconds"]
            })
            
        except Exception as e:
            response_time = (time.time() - start_time) * 1000
            result.update({
                'status': 'error',
                'response_time_ms': round(response_time, 2),
                'error_details': f"Unexpected error: {str(e)}",
                'issues': [f"Unexpected error: {str(e)}"]
            })
        
        return result

    def validate_all_external_links(self, links_data: Dict) -> Dict:
        """Validate all external links and generate comprehensive report."""
        print("Starting external link validation...")
        
        # Filter external links
        all_links = links_data['links']
        external_links = [link for link in all_links if link['link_type'] == 'external']
        
        self.total_links = len(external_links)
        print(f"Found {self.total_links} external links to validate...")
        
        if self.total_links == 0:
            print("No external links found.")
            return self._generate_empty_report()
        
        validation_results = []
        
        for i, link in enumerate(external_links, 1):
            print(f"Validating link {i}/{self.total_links}: {link['destination'][:60]}...")
            
            result = self.validate_external_link(link)
            validation_results.append(result)
            
            # Categorize results
            if result['status'] == 'accessible':
                self.accessible_links.append(result)
                if result['redirect_chain']:
                    self.redirected_links.append(result)
                if result['response_time_ms'] and result['response_time_ms'] > 5000:
                    self.slow_links.append(result)
            else:
                self.broken_links.append(result)
                if result.get('ssl_valid') is False:
                    self.ssl_issues.append(result)
        
        return self._generate_report(validation_results)

    def _generate_empty_report(self) -> Dict:
        """Generate empty report when no external links found."""
        return {
            'metadata': {
                'validation_date': datetime.utcnow().isoformat() + 'Z',
                'validator_version': '1.0.0',
                'total_external_links': 0,
                'timeout_seconds': self.timeout,
                'max_redirects': self.max_redirects
            },
            'summary_statistics': {
                'total_external_links': 0,
                'accessible_links': 0,
                'broken_links': 0,
                'redirected_links': 0,
                'slow_links': 0,
                'ssl_issues': 0,
                'success_rate_percentage': 0,
                'average_response_time_ms': 0
            },
            'categorized_results': {
                'accessible_links': [],
                'broken_links': [],
                'redirected_links': [],
                'slow_links': [],
                'ssl_issues': []
            },
            'detailed_results': []
        }

    def _generate_report(self, validation_results: List[Dict]) -> Dict:
        """Generate comprehensive validation report."""
        # Calculate statistics
        accessible_count = len(self.accessible_links)
        broken_count = len(self.broken_links)
        redirected_count = len(self.redirected_links)
        slow_count = len(self.slow_links)
        ssl_issues_count = len(self.ssl_issues)
        
        success_rate = (accessible_count / self.total_links * 100) if self.total_links > 0 else 0
        
        # Calculate average response time for successful requests
        successful_times = [r['response_time_ms'] for r in self.accessible_links if r['response_time_ms']]
        avg_response_time = sum(successful_times) / len(successful_times) if successful_times else 0
        
        # Analyze most common issues
        issue_types = {}
        for result in self.broken_links:
            for issue in result['issues']:
                issue_type = issue.split(':')[0].strip()
                issue_types[issue_type] = issue_types.get(issue_type, 0) + 1
        
        common_issues = sorted(issue_types.items(), key=lambda x: x[1], reverse=True)
        
        # Find links that need immediate attention
        critical_links = []
        for result in self.broken_links:
            if any(keyword in result['error_details'].lower() if result['error_details'] else '' 
                   for keyword in ['404', 'not found', 'dns', 'ssl']):
                critical_links.append(result)
        
        # Generate comprehensive report
        report = {
            'metadata': {
                'validation_date': datetime.utcnow().isoformat() + 'Z',
                'validator_version': '1.0.0',
                'total_external_links': self.total_links,
                'timeout_seconds': self.timeout,
                'max_redirects': self.max_redirects,
                'user_agent': self.user_agent
            },
            'summary_statistics': {
                'total_external_links': self.total_links,
                'accessible_links': accessible_count,
                'broken_links': broken_count,
                'redirected_links': redirected_count,
                'slow_links': slow_count,
                'ssl_issues': ssl_issues_count,
                'success_rate_percentage': round(success_rate, 2),
                'average_response_time_ms': round(avg_response_time, 2)
            },
            'issue_analysis': {
                'most_common_issues': [
                    {'issue_type': issue, 'count': count} 
                    for issue, count in common_issues[:5]
                ],
                'critical_links_count': len(critical_links),
                'response_time_analysis': {
                    'fastest_response_ms': min(successful_times) if successful_times else 0,
                    'slowest_response_ms': max(successful_times) if successful_times else 0,
                    'median_response_ms': sorted(successful_times)[len(successful_times)//2] if successful_times else 0
                }
            },
            'categorized_results': {
                'accessible_links': self.accessible_links,
                'broken_links': self.broken_links,
                'redirected_links': self.redirected_links,
                'slow_links': self.slow_links,
                'ssl_issues': self.ssl_issues
            },
            'links_needing_attention': critical_links[:10],  # Top 10 critical issues
            'detailed_results': validation_results
        }
        
        return report


def main():
    print("External Links Validator")
    print("=" * 50)
    
    # Load extracted links data
    print("Loading extracted links data...")
    try:
        with open('docs-links-extracted.json', 'r', encoding='utf-8') as f:
            links_data = json.load(f)
    except FileNotFoundError:
        print("❌ Error: docs-links-extracted.json not found.")
        print("Please run the link extraction script first.")
        return
    except json.JSONDecodeError as e:
        print(f"❌ Error: Invalid JSON in docs-links-extracted.json: {e}")
        return
    
    # Initialize validator
    print("Initializing external link validator...")
    validator = ExternalLinkValidator(
        timeout=15,  # 15 second timeout
        max_redirects=5,
        user_agent="Prismatic-Documentation-Validator/1.0 (+https://github.com/prismatic/docs)"
    )
    
    # Validate all external links
    validation_report = validator.validate_all_external_links(links_data)
    
    # Save validation report
    output_file = 'docs-external-links-validation-report.json'
    print(f"\nSaving validation report to {output_file}...")
    
    try:
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(validation_report, f, indent=2, ensure_ascii=False)
        print(f"✅ External links validation report saved successfully!")
    except Exception as e:
        print(f"❌ Error saving validation report: {e}")
        return
    
    # Print comprehensive summary
    print("\n" + "="*70)
    print("EXTERNAL LINKS VALIDATION SUMMARY")
    print("="*70)
    
    stats = validation_report['summary_statistics']
    print(f"📊 Total external links validated: {stats['total_external_links']}")
    print(f"✅ Accessible links: {stats['accessible_links']}")
    print(f"❌ Broken/inaccessible links: {stats['broken_links']}")
    print(f"🔄 Redirected links: {stats['redirected_links']}")
    print(f"🐌 Slow links (>5s): {stats['slow_links']}")
    print(f"🔒 SSL issues: {stats['ssl_issues']}")
    print(f"📈 Success rate: {stats['success_rate_percentage']}%")
    
    if stats['accessible_links'] > 0:
        print(f"⚡ Average response time: {stats['average_response_time_ms']:.0f}ms")
    
    # Show most common issues
    if validation_report['issue_analysis']['most_common_issues']:
        print(f"\n🔍 MOST COMMON ISSUES:")
        for issue in validation_report['issue_analysis']['most_common_issues'][:3]:
            print(f"   • {issue['issue_type']}: {issue['count']} occurrences")
    
    # Show critical links that need attention
    critical_count = validation_report['issue_analysis']['critical_links_count']
    if critical_count > 0:
        print(f"\n⚠️  LINKS NEEDING IMMEDIATE ATTENTION: {critical_count}")
        for link in validation_report['links_needing_attention'][:3]:
            print(f"   • {link['url'][:50]}...")
            print(f"     Source: {link['source_file']} (line {link['line_number']})")
            print(f"     Issue: {link['error_details']}")
    
    print(f"\n📁 Detailed validation report saved to: {output_file}")
    
    # Final recommendations
    if stats['broken_links'] > 0:
        print(f"\n💡 RECOMMENDATIONS:")
        print(f"   • Review and fix {stats['broken_links']} broken external links")
        if stats['ssl_issues'] > 0:
            print(f"   • Address {stats['ssl_issues']} SSL certificate issues")
        if stats['slow_links'] > 0:
            print(f"   • Consider alternatives for {stats['slow_links']} slow-loading links")
    else:
        print(f"\n🎉 All external links are accessible! Great job maintaining the documentation.")


if __name__ == "__main__":
    main()