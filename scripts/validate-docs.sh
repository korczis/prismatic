#!/bin/bash
# Documentation validation script for Prismatic project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Configuration
DOCS_DIR="docs"
EXIT_CODE=0
VALIDATION_ERRORS=0

log_info "Starting comprehensive documentation validation..."

# Check if docs directory exists
if [ ! -d "$DOCS_DIR" ]; then
    log_error "Documentation directory '$DOCS_DIR' not found"
    exit 1
fi

# Function to validate markdown syntax
validate_markdown_syntax() {
    log_step "Validating Markdown syntax..."
    
    local syntax_errors=0
    
    while IFS= read -r -d '' file; do
        # Check for common markdown syntax issues
        
        # Check for malformed links
        if grep -n "]\(" "$file" | grep -v "]\([^)]*\)" >/dev/null 2>&1; then
            log_error "Malformed links found in $file"
            grep -n "]\(" "$file" | grep -v "]\([^)]*\)"
            syntax_errors=$((syntax_errors + 1))
        fi
        
        # Check for unmatched brackets
        local open_brackets=$(grep -o "\[" "$file" | wc -l)
        local close_brackets=$(grep -o "\]" "$file" | wc -l)
        if [ "$open_brackets" -ne "$close_brackets" ]; then
            log_error "Unmatched brackets in $file (open: $open_brackets, close: $close_brackets)"
            syntax_errors=$((syntax_errors + 1))
        fi
        
        # Check for unmatched parentheses in links
        local open_parens=$(grep -o "(\[" "$file" | wc -l)
        local close_parens=$(grep -o "\])" "$file" | wc -l)
        if [ "$open_parens" -ne "$close_parens" ]; then
            log_warn "Potential unmatched parentheses in links in $file"
        fi
        
    done < <(find "$DOCS_DIR" -name "*.md" -type f -print0)
    
    if [ $syntax_errors -eq 0 ]; then
        log_info "✅ Markdown syntax validation passed"
    else
        log_error "❌ Found $syntax_errors markdown syntax error(s)"
        EXIT_CODE=1
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + syntax_errors))
    fi
}

# Function to validate navigation sections
validate_navigation_sections() {
    log_step "Validating navigation sections..."
    
    local nav_errors=0
    
    while IFS= read -r -d '' file; do
        # Check for NAV_START and NAV_END markers
        if grep -q "<!-- NAV_START -->" "$file"; then
            if ! grep -q "<!-- NAV_END -->" "$file"; then
                log_error "Missing NAV_END marker in $file"
                nav_errors=$((nav_errors + 1))
            fi
        elif grep -q "<!-- NAV_END -->" "$file"; then
            log_error "NAV_END marker without NAV_START in $file"
            nav_errors=$((nav_errors + 1))
        fi
        
        # Check for proper navigation structure
        if grep -q "## Navigation" "$file"; then
            if ! grep -q "**Current Location**:" "$file"; then
                log_warn "Navigation section missing 'Current Location' in $file"
            fi
            
            if ! grep -q "### Quick Links" "$file"; then
                log_warn "Navigation section missing 'Quick Links' in $file"
            fi
        fi
        
    done < <(find "$DOCS_DIR" -name "*.md" -type f -print0)
    
    if [ $nav_errors -eq 0 ]; then
        log_info "✅ Navigation section validation passed"
    else
        log_error "❌ Found $nav_errors navigation error(s)"
        EXIT_CODE=1
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + nav_errors))
    fi
}

# Function to validate heading structure
validate_heading_structure() {
    log_step "Validating heading structure..."
    
    local heading_errors=0
    
    while IFS= read -r -d '' file; do
        local filename=$(basename "$file")
        
        # Check for H1 heading (should be exactly one)
        local h1_count=$(grep -c "^# " "$file" 2>/dev/null || echo 0)
        if [ "$h1_count" -ne 1 ]; then
            if [ "$h1_count" -eq 0 ]; then
                log_error "Missing H1 heading in $file"
            else
                log_error "Multiple H1 headings in $file ($h1_count found)"
            fi
            heading_errors=$((heading_errors + 1))
        fi
        
        # Check heading hierarchy (no skipping levels)
        local prev_level=0
        while IFS= read -r line; do
            if [[ "$line" =~ ^#{1,6}[[:space:]] ]]; then
                local level=$(echo "$line" | grep -o "^#*" | wc -c)
                level=$((level - 1))  # Adjust for character count
                
                if [ $level -gt $((prev_level + 1)) ] && [ $prev_level -gt 0 ]; then
                    log_warn "Heading level skip in $file: jumped from H$prev_level to H$level"
                    log_warn "  Line: $line"
                fi
                prev_level=$level
            fi
        done < "$file"
        
    done < <(find "$DOCS_DIR" -name "*.md" -type f -print0)
    
    if [ $heading_errors -eq 0 ]; then
        log_info "✅ Heading structure validation passed"
    else
        log_error "❌ Found $heading_errors heading structure error(s)"
        EXIT_CODE=1
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + heading_errors))
    fi
}

# Function to validate required sections
validate_required_sections() {
    log_step "Validating required sections..."
    
    local section_errors=0
    
    while IFS= read -r -d '' file; do
        local filename=$(basename "$file")
        
        # Skip certain files that don't need standard sections
        if [[ "$filename" =~ ^(README\.md|CHANGELOG\.md|LICENSE\.md)$ ]]; then
            continue
        fi
        
        # Check for Overview section (recommended for most docs)
        if ! grep -q "## Overview" "$file"; then
            log_warn "Missing '## Overview' section in $file"
        fi
        
        # Check for Related Documentation section
        if ! grep -q "## Related Documentation" "$file"; then
            log_warn "Missing '## Related Documentation' section in $file"
        fi
        
    done < <(find "$DOCS_DIR" -name "*.md" -type f -print0)
    
    if [ $section_errors -eq 0 ]; then
        log_info "✅ Required sections validation passed"
    else
        log_error "❌ Found $section_errors missing required section(s)"
        EXIT_CODE=1
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + section_errors))
    fi
}

# Function to validate glossary format
validate_glossary_format() {
    log_step "Validating glossary format..."
    
    local glossary_file="$DOCS_DIR/reference/glossary.md"
    
    if [ ! -f "$glossary_file" ]; then
        log_warn "Glossary file not found: $glossary_file"
        return
    fi
    
    local glossary_errors=0
    
    # Check that terms use ### headings
    local incorrect_headings=0
    while IFS= read -r line; do
        # Look for term definitions that don't use ### format
        if [[ "$line" =~ ^##[[:space:]] ]] && [[ ! "$line" =~ ^###[[:space:]] ]]; then
            # Skip main sections like "## Navigation", "## Overview"
            if [[ ! "$line" =~ (Navigation|Overview|Related) ]]; then
                log_error "Glossary term should use ### heading: $line"
                incorrect_headings=$((incorrect_headings + 1))
            fi
        fi
    done < "$glossary_file"
    
    # Check alphabetical order of terms
    local terms_file=$(mktemp)
    grep "^### " "$glossary_file" | sed 's/^### //' > "$terms_file"
    local sorted_terms_file=$(mktemp)
    sort -f "$terms_file" > "$sorted_terms_file"
    
    if ! diff -q "$terms_file" "$sorted_terms_file" >/dev/null; then
        log_error "Glossary terms are not in alphabetical order"
        log_info "Expected order:"
        cat "$sorted_terms_file"
        glossary_errors=$((glossary_errors + 1))
    fi
    
    rm -f "$terms_file" "$sorted_terms_file"
    
    glossary_errors=$((glossary_errors + incorrect_headings))
    
    if [ $glossary_errors -eq 0 ]; then
        log_info "✅ Glossary format validation passed"
    else
        log_error "❌ Found $glossary_errors glossary format error(s)"
        EXIT_CODE=1
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + glossary_errors))
    fi
}

# Function to check for TODO and FIXME comments
check_todo_comments() {
    log_step "Checking for TODO and FIXME comments..."
    
    local todo_count=0
    
    while IFS= read -r -d '' file; do
        local todos=$(grep -n -i "TODO\|FIXME\|XXX" "$file" 2>/dev/null || true)
        if [ -n "$todos" ]; then
            log_warn "Found TODO/FIXME comments in $file:"
            echo "$todos" | while IFS= read -r line; do
                echo "  $line"
            done
            todo_count=$((todo_count + 1))
        fi
    done < <(find "$DOCS_DIR" -name "*.md" -type f -print0)
    
    if [ $todo_count -eq 0 ]; then
        log_info "✅ No TODO/FIXME comments found"
    else
        log_warn "⚠️  Found TODO/FIXME comments in $todo_count file(s)"
    fi
}

# Function to validate code blocks
validate_code_blocks() {
    log_step "Validating code blocks..."
    
    local code_errors=0
    
    while IFS= read -r -d '' file; do
        # Check for unmatched code fences
        local triple_backticks=$(grep -c "^```" "$file" 2>/dev/null || echo 0)
        if [ $((triple_backticks % 2)) -ne 0 ]; then
            log_error "Unmatched code fences (```) in $file"
            code_errors=$((code_errors + 1))
        fi
        
        # Check for common code block issues
        if grep -q "^```$" "$file"; then
            # Look for empty language specifiers
            local empty_code_blocks=$(grep -A1 "^```$" "$file" | grep -c "^```$" 2>/dev/null || echo 0)
            if [ $empty_code_blocks -gt 0 ]; then
                log_warn "Code blocks without language specification in $file"
            fi
        fi
        
    done < <(find "$DOCS_DIR" -name "*.md" -type f -print0)
    
    if [ $code_errors -eq 0 ]; then
        log_info "✅ Code block validation passed"
    else
        log_error "❌ Found $code_errors code block error(s)"
        EXIT_CODE=1
        VALIDATION_ERRORS=$((VALIDATION_ERRORS + code_errors))
    fi
}

# Function to run link validation
run_link_validation() {
    log_step "Running link validation..."
    
    if [ -f "scripts/check-docs-links.sh" ]; then
        if ! bash scripts/check-docs-links.sh; then
            log_error "Link validation failed"
            EXIT_CODE=1
            VALIDATION_ERRORS=$((VALIDATION_ERRORS + 1))
        fi
    else
        log_warn "Link validation script not found: scripts/check-docs-links.sh"
    fi
}

# Main validation sequence
log_info "=== Starting Documentation Validation ==="
echo ""

validate_markdown_syntax
echo ""

validate_navigation_sections  
echo ""

validate_heading_structure
echo ""

validate_required_sections
echo ""

validate_glossary_format
echo ""

validate_code_blocks
echo ""

check_todo_comments
echo ""

run_link_validation
echo ""

# Final summary
log_info "=== Documentation Validation Summary ==="
if [ $EXIT_CODE -eq 0 ]; then
    log_info "✅ All documentation validation checks passed!"
else
    log_error "❌ Documentation validation failed with $VALIDATION_ERRORS error(s)"
    log_info "Please fix the issues above before proceeding"
fi

echo ""
log_info "Validation completed with exit code: $EXIT_CODE"

exit $EXIT_CODE