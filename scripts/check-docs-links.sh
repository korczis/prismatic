#!/bin/bash
# Documentation link checker script for Prismatic project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Configuration
DOCS_DIR="docs"
LINK_CHECK_TIMEOUT=30
EXIT_CODE=0

log_info "Starting documentation link validation..."

# Check if docs directory exists
if [ ! -d "$DOCS_DIR" ]; then
    log_error "Documentation directory '$DOCS_DIR' not found"
    exit 1
fi

# Function to check if a file exists relative to docs directory
check_file_exists() {
    local file_path="$1"
    local base_dir="$2"
    
    # Handle different path formats
    if [[ "$file_path" == /* ]]; then
        # Absolute path - check from root
        if [ -f "$file_path" ]; then
            return 0
        fi
    elif [[ "$file_path" == ../* ]]; then
        # Relative path going up - resolve from base_dir
        local resolved_path="${base_dir}/${file_path}"
        if [ -f "$resolved_path" ]; then
            return 0
        fi
    else
        # Relative path - check from base_dir
        local resolved_path="${base_dir}/${file_path}"
        if [ -f "$resolved_path" ]; then
            return 0
        fi
    fi
    
    return 1
}

# Function to validate internal links in a markdown file
validate_internal_links() {
    local file="$1"
    local file_dir=$(dirname "$file")
    local broken_links=0
    
    log_info "Checking links in: $file"
    
    # Extract markdown links [text](path) but exclude external URLs
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Extract the link path (everything between parentheses)
            link_path=$(echo "$line" | sed 's/.*(\([^)]*\)).*/\1/')
            
            # Skip empty links, external URLs, and anchors-only
            if [[ -z "$link_path" ]] || [[ "$link_path" == http* ]] || [[ "$link_path" == \#* ]]; then
                continue
            fi
            
            # Remove anchor fragments for file existence check
            file_path=$(echo "$link_path" | sed 's/#.*//')
            
            # Skip if it's just an anchor
            if [[ -z "$file_path" ]]; then
                continue
            fi
            
            # Check if the linked file exists
            if ! check_file_exists "$file_path" "$file_dir"; then
                log_error "Broken link in $file: $link_path"
                echo "  -> Resolved to: ${file_dir}/${file_path}"
                broken_links=$((broken_links + 1))
                EXIT_CODE=1
            fi
        fi
    done < <(grep -o '\[^[]*\]([^)]*)' "$file" 2>/dev/null || true)
    
    if [ $broken_links -eq 0 ]; then
        log_info "✅ All links valid in $file"
    else
        log_error "❌ Found $broken_links broken link(s) in $file"
    fi
    
    return $broken_links
}

# Function to check for orphaned files
check_orphaned_files() {
    log_info "Checking for orphaned documentation files..."
    
    local orphaned_count=0
    
    # Find all markdown files
    while IFS= read -r -d '' file; do
        local relative_path="${file#./}"
        
        # Skip certain files that don't need to be referenced
        if [[ "$file" =~ (README\.md|CHANGELOG\.md|LICENSE\.md)$ ]]; then
            continue
        fi
        
        # Search for references to this file in other markdown files
        local references=$(find "$DOCS_DIR" -name "*.md" -not -path "$file" -exec grep -l "${relative_path#$DOCS_DIR/}" {} \; 2>/dev/null | wc -l)
        
        if [ "$references" -eq 0 ]; then
            log_warn "Potentially orphaned file: $relative_path"
            orphaned_count=$((orphaned_count + 1))
        fi
    done < <(find "$DOCS_DIR" -name "*.md" -type f -print0)
    
    if [ $orphaned_count -eq 0 ]; then
        log_info "✅ No orphaned files found"
    else
        log_warn "⚠️  Found $orphaned_count potentially orphaned file(s)"
    fi
}

# Function to validate anchor links
validate_anchor_links() {
    local file="$1"
    local broken_anchors=0
    
    # Extract links with anchors [text](file.md#anchor)
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            # Extract full link path
            link_path=$(echo "$line" | sed 's/.*(\([^)]*\)).*/\1/')
            
            # Skip if no anchor
            if [[ "$link_path" != *"#"* ]]; then
                continue
            fi
            
            # Extract file path and anchor
            file_path=$(echo "$link_path" | sed 's/#.*//')
            anchor=$(echo "$link_path" | sed 's/.*#//')
            
            # If file_path is empty, it's a same-file anchor
            if [[ -z "$file_path" ]]; then
                target_file="$file"
            else
                local file_dir=$(dirname "$file")
                target_file="${file_dir}/${file_path}"
            fi
            
            # Check if target file exists
            if [ ! -f "$target_file" ]; then
                continue  # File check will catch this
            fi
            
            # Check if anchor exists in target file
            if ! grep -q "^#.*${anchor}" "$target_file" 2>/dev/null; then
                log_error "Broken anchor in $file: $link_path"
                echo "  -> Target file: $target_file"
                echo "  -> Missing anchor: #$anchor"
                broken_anchors=$((broken_anchors + 1))
                EXIT_CODE=1
            fi
        fi
    done < <(grep -o '\[[^[]*\]([^)]*#[^)]*)' "$file" 2>/dev/null || true)
    
    return $broken_anchors
}

# Main validation loop
total_files=0
total_broken=0

log_info "Scanning for markdown files in $DOCS_DIR..."

# Process all markdown files
while IFS= read -r -d '' file; do
    total_files=$((total_files + 1))
    
    # Validate internal links
    if ! validate_internal_links "$file"; then
        total_broken=$((total_broken + 1))
    fi
    
    # Validate anchor links
    validate_anchor_links "$file"
    
done < <(find "$DOCS_DIR" -name "*.md" -type f -print0)

# Check for orphaned files
check_orphaned_files

# Summary
echo ""
log_info "=== Link Validation Summary ==="
log_info "Files processed: $total_files"

if [ $EXIT_CODE -eq 0 ]; then
    log_info "✅ All documentation links are valid!"
else
    log_error "❌ Found broken links in documentation"
    log_info "Please fix the broken links before proceeding"
fi

echo ""
log_info "Link validation completed with exit code: $EXIT_CODE"

exit $EXIT_CODE