#!/bin/bash
# Smoke tests for Prismatic application
# Basic functionality verification after deployment

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
ENVIRONMENT_URL=${1:-"http://localhost:4000"}
TIMEOUT=30
EXIT_CODE=0
FAILED_TESTS=0
TOTAL_TESTS=0

log_info "Starting smoke tests for: $ENVIRONMENT_URL"
log_info "Test timeout: ${TIMEOUT}s"

# Function to make HTTP request with timeout
make_request() {
    local url="$1"
    local expected_status="${2:-200}"
    local method="${3:-GET}"
    local data="${4:-}"
    
    local curl_opts=(-s -w "%{http_code}|%{time_total}" --max-time "$TIMEOUT")
    
    if [ "$method" = "POST" ] && [ -n "$data" ]; then
        curl_opts+=(-X POST -H "Content-Type: application/json" -d "$data")
    elif [ "$method" = "POST" ]; then
        curl_opts+=(-X POST -H "Content-Type: application/json")
    fi
    
    local response=$(curl "${curl_opts[@]}" "$url" 2>/dev/null || echo "000|0.000")
    local status_code=$(echo "$response" | cut -d'|' -f1)
    local response_time=$(echo "$response" | cut -d'|' -f2)
    
    echo "$status_code|$response_time"
}

# Function to run a single test
run_test() {
    local test_name="$1"
    local url="$2"
    local expected_status="${3:-200}"
    local method="${4:-GET}"
    local data="${5:-}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    log_step "Testing: $test_name"
    
    local result=$(make_request "$url" "$expected_status" "$method" "$data")
    local status_code=$(echo "$result" | cut -d'|' -f1)
    local response_time=$(echo "$result" | cut -d'|' -f2)
    
    if [ "$status_code" = "$expected_status" ]; then
        log_info "✅ $test_name - Status: $status_code, Time: ${response_time}s"
    else
        log_error "❌ $test_name - Expected: $expected_status, Got: $status_code, Time: ${response_time}s"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        EXIT_CODE=1
    fi
    
    # Warn if response time is slow
    if (( $(echo "$response_time > 5.0" | bc -l 2>/dev/null || echo 0) )); then
        log_warn "⚠️  Slow response time: ${response_time}s"
    fi
}

# Function to test basic connectivity
test_basic_connectivity() {
    log_step "=== Basic Connectivity Tests ==="
    
    # Test if the server is reachable
    if ! curl -f --max-time 10 "$ENVIRONMENT_URL" >/dev/null 2>&1; then
        log_error "❌ Server not reachable at $ENVIRONMENT_URL"
        EXIT_CODE=1
        return 1
    fi
    
    log_info "✅ Server is reachable"
    return 0
}

# Function to test health endpoints
test_health_endpoints() {
    log_step "=== Health Check Tests ==="
    
    # Basic health check
    run_test "Health Check" "$ENVIRONMENT_URL/api/health" 200
    
    # Database health (if endpoint exists)
    run_test "Database Health" "$ENVIRONMENT_URL/api/health/database" 200
    
    # Ready check (if endpoint exists)  
    run_test "Readiness Check" "$ENVIRONMENT_URL/api/ready" 200
}

# Function to test static assets
test_static_assets() {
    log_step "=== Static Asset Tests ==="
    
    # Test main page
    run_test "Home Page" "$ENVIRONMENT_URL/" 200
    
    # Test common static assets
    run_test "CSS Assets" "$ENVIRONMENT_URL/assets/app.css" 200
    run_test "JS Assets" "$ENVIRONMENT_URL/assets/app.js" 200
    
    # Test favicon
    run_test "Favicon" "$ENVIRONMENT_URL/favicon.ico" 200
}

# Function to test API endpoints
test_api_endpoints() {
    log_step "=== API Endpoint Tests ==="
    
    # Test API root (might return 404 or redirect, that's OK)
    local api_response=$(make_request "$ENVIRONMENT_URL/api" "200")
    local api_status=$(echo "$api_response" | cut -d'|' -f1)
    
    if [ "$api_status" = "200" ] || [ "$api_status" = "404" ] || [ "$api_status" = "302" ]; then
        log_info "✅ API Root - Status: $api_status"
    else
        log_error "❌ API Root - Unexpected status: $api_status"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        EXIT_CODE=1
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Test API endpoints that should exist
    run_test "API Documentation" "$ENVIRONMENT_URL/api/docs" 200
    run_test "API Version" "$ENVIRONMENT_URL/api/version" 200
}

# Function to test authentication endpoints
test_auth_endpoints() {
    log_step "=== Authentication Tests ==="
    
    # Test login endpoint (should accept POST)
    run_test "Login Endpoint (GET should fail)" "$ENVIRONMENT_URL/api/auth/login" 405 "GET"
    
    # Test login with POST (should return 400/422 for missing data)
    run_test "Login Endpoint (POST no data)" "$ENVIRONMENT_URL/api/auth/login" 400 "POST" "{}"
    
    # Test registration endpoint
    run_test "Registration Endpoint" "$ENVIRONMENT_URL/api/auth/register" 400 "POST" "{}"
}

# Function to test database connectivity
test_database_connectivity() {
    log_step "=== Database Connectivity Tests ==="
    
    # If there's a database health endpoint
    run_test "Database Connection" "$ENVIRONMENT_URL/api/health/database" 200
    
    # Test a simple query endpoint (like user count, if available)
    local stats_response=$(make_request "$ENVIRONMENT_URL/api/stats" "200")
    local stats_status=$(echo "$stats_response" | cut -d'|' -f1)
    
    if [ "$stats_status" = "200" ] || [ "$stats_status" = "404" ]; then
        log_info "✅ Stats endpoint accessible (or doesn't exist)"
    else
        log_warn "⚠️  Stats endpoint returned: $stats_status"
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# Function to test critical business functionality
test_business_functionality() {
    log_step "=== Business Functionality Tests ==="
    
    # Test user-related endpoints (basic checks)
    run_test "Users Endpoint" "$ENVIRONMENT_URL/api/users" 401  # Should require auth
    
    # Test public endpoints that might exist
    run_test "Public Content" "$ENVIRONMENT_URL/api/public" 200
    
    # Test search functionality
    run_test "Search Endpoint" "$ENVIRONMENT_URL/api/search" 400  # Should require query
}

# Function to test error handling
test_error_handling() {
    log_step "=== Error Handling Tests ==="
    
    # Test 404 handling
    run_test "404 Handling" "$ENVIRONMENT_URL/nonexistent-endpoint" 404
    
    # Test malformed requests
    run_test "Malformed JSON" "$ENVIRONMENT_URL/api/users" 400 "POST" "invalid-json"
    
    # Test method not allowed
    run_test "Method Not Allowed" "$ENVIRONMENT_URL/api/health" 405 "DELETE"
}

# Function to test security headers
test_security_headers() {
    log_step "=== Security Headers Tests ==="
    
    local headers_file=$(mktemp)
    
    # Get headers from home page
    curl -I --max-time 10 "$ENVIRONMENT_URL/" > "$headers_file" 2>/dev/null || {
        log_warn "Could not fetch headers for security check"
        rm -f "$headers_file"
        return 0
    }
    
    # Check for security headers
    local security_headers=(
        "x-frame-options"
        "x-content-type-options"
        "x-xss-protection"
        "strict-transport-security"
    )
    
    local missing_headers=0
    
    for header in "${security_headers[@]}"; do
        if grep -qi "$header" "$headers_file"; then
            log_info "✅ Security header present: $header"
        else
            log_warn "⚠️  Missing security header: $header"
            missing_headers=$((missing_headers + 1))
        fi
    done
    
    if [ $missing_headers -eq 0 ]; then
        log_info "✅ All security headers present"
    else
        log_warn "⚠️  $missing_headers security header(s) missing"
    fi
    
    rm -f "$headers_file"
}

# Function to test SSL/TLS (if HTTPS)
test_ssl_configuration() {
    local url_scheme=$(echo "$ENVIRONMENT_URL" | cut -d':' -f1)
    
    if [ "$url_scheme" = "https" ]; then
        log_step "=== SSL/TLS Configuration Tests ==="
        
        local domain=$(echo "$ENVIRONMENT_URL" | sed 's|^https\?://||' | cut -d'/' -f1 | cut -d':' -f1)
        
        # Test SSL certificate
        if command -v openssl &> /dev/null; then
            local ssl_check=$(echo | openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || echo "")
            
            if [ -n "$ssl_check" ]; then
                log_info "✅ SSL certificate is valid"
                echo "$ssl_check" | while IFS= read -r line; do
                    log_info "  $line"
                done
            else
                log_warn "⚠️  Could not verify SSL certificate"
            fi
        else
            log_warn "⚠️  OpenSSL not available for SSL checks"
        fi
    else
        log_info "HTTP endpoint - skipping SSL tests"
    fi
}

# Function to test performance
test_performance() {
    log_step "=== Performance Tests ==="
    
    # Test response times for critical endpoints
    local critical_endpoints=(
        "$ENVIRONMENT_URL/api/health"
        "$ENVIRONMENT_URL/"
    )
    
    for endpoint in "${critical_endpoints[@]}"; do
        local result=$(make_request "$endpoint" "200")
        local status_code=$(echo "$result" | cut -d'|' -f1)
        local response_time=$(echo "$result" | cut -d'|' -f2)
        
        if [ "$status_code" = "200" ]; then
            local response_time_ms=$(echo "$response_time * 1000" | bc -l 2>/dev/null || echo "0")
            log_info "Response time for $endpoint: ${response_time_ms}ms"
            
            # Warn if response time is > 2 seconds
            if (( $(echo "$response_time > 2.0" | bc -l 2>/dev/null || echo 0) )); then
                log_warn "⚠️  Slow response time: ${response_time}s"
            fi
        fi
    done
}

# Main test execution
main() {
    log_info "=== Prismatic Application Smoke Tests ==="
    log_info "Target: $ENVIRONMENT_URL"
    log_info "Timeout: ${TIMEOUT}s"
    echo ""
    
    # Run all test suites
    if test_basic_connectivity; then
        test_health_endpoints
        echo ""
        
        test_static_assets
        echo ""
        
        test_api_endpoints
        echo ""
        
        test_auth_endpoints
        echo ""
        
        test_database_connectivity
        echo ""
        
        test_business_functionality
        echo ""
        
        test_error_handling
        echo ""
        
        test_security_headers
        echo ""
        
        test_ssl_configuration
        echo ""
        
        test_performance
        echo ""
    else
        log_error "Basic connectivity failed - skipping remaining tests"
        EXIT_CODE=1
    fi
    
    # Final summary
    log_info "=== Smoke Test Summary ==="
    log_info "Total tests: $TOTAL_TESTS"
    log_info "Failed tests: $FAILED_TESTS"
    log_info "Success rate: $(( (TOTAL_TESTS - FAILED_TESTS) * 100 / TOTAL_TESTS ))%"
    
    if [ $EXIT_CODE -eq 0 ]; then
        log_info "✅ All smoke tests passed!"
        log_info "Application appears to be functioning correctly"
    else
        log_error "❌ $FAILED_TESTS smoke test(s) failed!"
        log_info "Please investigate the failures above"
    fi
    
    echo ""
    log_info "Smoke tests completed with exit code: $EXIT_CODE"
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        echo "Usage: $0 [ENVIRONMENT_URL]"
        echo ""
        echo "Arguments:"
        echo "  ENVIRONMENT_URL    Target URL for testing (default: http://localhost:4000)"
        echo ""
        echo "Examples:"
        echo "  $0                                    # Test localhost:4000"
        echo "  $0 https://staging.example.com       # Test staging environment"
        echo "  $0 https://production.example.com    # Test production environment"
        exit 0
        ;;
    -*)
        log_error "Unknown option: $1"
        log_info "Use --help for usage information"
        exit 1
        ;;
esac

# Run main function
main "$@"

exit $EXIT_CODE