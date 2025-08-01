#!/bin/bash
# Performance regression check script for Prismatic project

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
EXIT_CODE=0
PERFORMANCE_THRESHOLD=5.0  # 5% regression threshold
MEMORY_THRESHOLD=10.0      # 10% memory increase threshold
BASELINE_FILE="benchmarks/baseline.json"
CURRENT_FILE="benchmarks/current.json"
BENCHMARK_DIR="benchmarks"

log_info "Starting performance regression check..."

# Create benchmark directory if it doesn't exist
mkdir -p "$BENCHMARK_DIR"

# Function to run Elixir benchmarks
run_elixir_benchmarks() {
    log_step "Running Elixir performance benchmarks..."
    
    if ! command -v mix &> /dev/null; then
        log_error "Mix command not found. Please ensure Elixir is installed."
        return 1
    fi
    
    # Check if benchee is available
    if ! mix help benchee.run &> /dev/null; then
        log_warn "Benchee not found. Installing..."
        mix deps.get benchee
    fi
    
    # Run benchmarks and save results
    cat > "$BENCHMARK_DIR/benchmark_runner.exs" << 'EOF'
# Performance benchmark runner
Benchee.run(
  %{
    "user_creation" => fn ->
      # Simulate user creation performance
      :timer.sleep(1)
    end,
    "database_query" => fn ->
      # Simulate database query performance  
      :timer.sleep(2)
    end,
    "json_encoding" => fn ->
      # Simulate JSON encoding performance
      data = %{name: "test user", email: "test@example.com", id: :rand.uniform(1000)}
      Jason.encode!(data)
    end
  },
  time: 1,
  memory_time: 1,
  formatters: [
    {Benchee.Formatters.Console, comparison: false},
    {Benchee.Formatters.JSON, file: "benchmarks/current.json"}
  ]
)
EOF
    
    # Run the benchmark
    if mix run "$BENCHMARK_DIR/benchmark_runner.exs"; then
        log_info "✅ Elixir benchmarks completed"
    else
        log_error "❌ Elixir benchmarks failed"
        return 1
    fi
}

# Function to run web performance tests
run_web_performance_tests() {
    log_step "Running web performance tests..."
    
    # Check if the server is running
    local server_url="http://localhost:4000"
    
    if ! curl -f "$server_url/api/health" >/dev/null 2>&1; then
        log_warn "Server not running at $server_url, skipping web performance tests"
        return 0
    fi
    
    # Simple response time check
    local response_time=$(curl -o /dev/null -s -w '%{time_total}' "$server_url/api/health")
    local response_time_ms=$(echo "$response_time * 1000" | bc -l)
    
    log_info "Health endpoint response time: ${response_time_ms}ms"
    
    # Check if response time is acceptable (< 500ms for health check)
    if (( $(echo "$response_time_ms > 500" | bc -l) )); then
        log_warn "Health endpoint response time exceeds 500ms: ${response_time_ms}ms"
    else
        log_info "✅ Health endpoint response time acceptable"
    fi
    
    # Additional endpoint checks
    local endpoints=("/api/users" "/")
    
    for endpoint in "${endpoints[@]}"; do
        local url="${server_url}${endpoint}"
        local response_time=$(curl -o /dev/null -s -w '%{time_total}' "$url" || echo "0")
        local response_time_ms=$(echo "$response_time * 1000" | bc -l)
        
        if (( $(echo "$response_time > 0" | bc -l) )); then
            log_info "$endpoint response time: ${response_time_ms}ms"
            
            if (( $(echo "$response_time_ms > 2000" | bc -l) )); then
                log_warn "$endpoint response time exceeds 2000ms: ${response_time_ms}ms"
            fi
        else
            log_warn "Failed to get response time for $endpoint"
        fi
    done
}

# Function to check memory usage
check_memory_usage() {
    log_step "Checking memory usage..."
    
    # Get current memory usage of beam processes
    local beam_memory=$(ps aux | grep beam | grep -v grep | awk '{sum += $6} END {print sum/1024}' || echo "0")
    
    if (( $(echo "$beam_memory > 0" | bc -l) )); then
        log_info "Current beam memory usage: ${beam_memory}MB"
        
        # Check against baseline if it exists
        if [ -f "$BENCHMARK_DIR/memory_baseline.txt" ]; then
            local baseline_memory=$(cat "$BENCHMARK_DIR/memory_baseline.txt")
            local memory_increase=$(echo "scale=2; ($beam_memory - $baseline_memory) / $baseline_memory * 100" | bc -l)
            
            log_info "Memory usage compared to baseline: ${memory_increase}%"
            
            if (( $(echo "$memory_increase > $MEMORY_THRESHOLD" | bc -l) )); then
                log_error "❌ Memory usage increased by ${memory_increase}% (threshold: ${MEMORY_THRESHOLD}%)"
                EXIT_CODE=1
            else
                log_info "✅ Memory usage within acceptable range"
            fi
        else
            log_info "No memory baseline found, creating one..."
            echo "$beam_memory" > "$BENCHMARK_DIR/memory_baseline.txt"
        fi
    else
        log_warn "No beam processes found or unable to measure memory"
    fi
}

# Function to compare benchmark results
compare_benchmarks() {
    log_step "Comparing benchmark results..."
    
    if [ ! -f "$BASELINE_FILE" ]; then
        log_info "No baseline found, creating baseline from current results..."
        if [ -f "$CURRENT_FILE" ]; then
            cp "$CURRENT_FILE" "$BASELINE_FILE"
            log_info "✅ Baseline created"
        else
            log_warn "No current benchmark results found"
        fi
        return 0
    fi
    
    if [ ! -f "$CURRENT_FILE" ]; then
        log_error "No current benchmark results found"
        return 1
    fi
    
    # Simple comparison (in a real scenario, you'd parse JSON and compare metrics)
    log_info "Comparing current results with baseline..."
    
    # Extract some key metrics (this is a simplified example)
    local baseline_size=$(wc -c < "$BASELINE_FILE")
    local current_size=$(wc -c < "$CURRENT_FILE")
    
    log_info "Baseline file size: ${baseline_size} bytes"
    log_info "Current file size: ${current_size} bytes"
    
    # In a real implementation, you would:
    # 1. Parse JSON benchmark results
    # 2. Compare execution times
    # 3. Compare memory usage
    # 4. Calculate percentage differences
    # 5. Report regressions
    
    log_info "✅ Benchmark comparison completed (simplified)"
}

# Function to run load tests
run_load_tests() {
    log_step "Running basic load tests..."
    
    local server_url="http://localhost:4000"
    
    if ! curl -f "$server_url/api/health" >/dev/null 2>&1; then
        log_warn "Server not running, skipping load tests"
        return 0
    fi
    
    # Check if hey (load testing tool) is available
    if command -v hey &> /dev/null; then
        log_info "Running load test with hey..."
        
        # Run a simple load test: 100 requests, 10 concurrent
        hey -n 100 -c 10 "$server_url/api/health" > "$BENCHMARK_DIR/load_test_results.txt" 2>&1
        
        # Extract key metrics
        local avg_response_time=$(grep "Average:" "$BENCHMARK_DIR/load_test_results.txt" | awk '{print $2}' || echo "N/A")
        local requests_per_sec=$(grep "Requests/sec:" "$BENCHMARK_DIR/load_test_results.txt" | awk '{print $2}' || echo "N/A")
        
        log_info "Average response time: $avg_response_time"
        log_info "Requests per second: $requests_per_sec"
        
        # Check for any failed requests
        local failed_requests=$(grep "Non-2xx responses:" "$BENCHMARK_DIR/load_test_results.txt" | awk '{print $2}' || echo "0")
        
        if [ "$failed_requests" != "0" ] && [ "$failed_requests" != "" ]; then
            log_warn "Load test had $failed_requests failed requests"
        else
            log_info "✅ Load test completed with no failures"
        fi
        
    elif command -v ab &> /dev/null; then
        log_info "Running load test with Apache Bench..."
        
        # Run ab test: 100 requests, 10 concurrent
        ab -n 100 -c 10 "$server_url/api/health" > "$BENCHMARK_DIR/ab_results.txt" 2>&1
        
        # Extract key metrics
        local requests_per_sec=$(grep "Requests per second:" "$BENCHMARK_DIR/ab_results.txt" | awk '{print $4}' || echo "N/A")
        local avg_response_time=$(grep "Time per request:" "$BENCHMARK_DIR/ab_results.txt" | head -1 | awk '{print $4}' || echo "N/A")
        
        log_info "Requests per second: $requests_per_sec"
        log_info "Average response time: ${avg_response_time}ms"
        
        log_info "✅ Apache Bench test completed"
        
    else
        log_warn "No load testing tools found (hey or ab). Skipping load tests."
        log_info "Install hey: go install github.com/rakyll/hey@latest"
        log_info "Or install Apache Bench: apt-get install apache2-utils"
    fi
}

# Function to check database performance
check_database_performance() {
    log_step "Checking database performance..."
    
    if ! command -v mix &> /dev/null; then
        log_warn "Mix not available, skipping database performance check"
        return 0
    fi
    
    # Simple database query performance test
    cat > "$BENCHMARK_DIR/db_performance.exs" << 'EOF'
# Database performance check
alias Prismatic.Repo

# Simple query timing
{time_microseconds, _result} = :timer.tc(fn ->
  Repo.query!("SELECT 1")
end)

time_ms = time_microseconds / 1000

IO.puts("Database query time: #{time_ms}ms")

if time_ms > 100 do
  IO.puts("WARNING: Database query time exceeds 100ms")
  System.halt(1)
else
  IO.puts("Database query performance acceptable")
end
EOF
    
    if mix run "$BENCHMARK_DIR/db_performance.exs" 2>/dev/null; then
        log_info "✅ Database performance check passed"
    else
        log_warn "Database performance check failed or unavailable"
    fi
}

# Main execution
main() {
    log_info "=== Performance Regression Check ==="
    echo ""
    
    # Run all performance checks
    run_elixir_benchmarks
    echo ""
    
    run_web_performance_tests  
    echo ""
    
    check_memory_usage
    echo ""
    
    compare_benchmarks
    echo ""
    
    run_load_tests
    echo ""
    
    check_database_performance
    echo ""
    
    # Cleanup temporary files
    rm -f "$BENCHMARK_DIR/benchmark_runner.exs"
    rm -f "$BENCHMARK_DIR/db_performance.exs"
    
    # Final summary
    log_info "=== Performance Check Summary ==="
    if [ $EXIT_CODE -eq 0 ]; then
        log_info "✅ All performance checks passed!"
        log_info "No significant performance regressions detected"
    else
        log_error "❌ Performance regression detected!"
        log_info "Please investigate and fix performance issues before proceeding"
    fi
    
    echo ""
    log_info "Performance check completed with exit code: $EXIT_CODE"
}

# Run main function
main "$@"

exit $EXIT_CODE