#!/bin/bash

# Time Machine for Linux - Test Runner

set -euo pipefail

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test result tracking
declare -a FAILED_TESTS=()

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_banner() {
    local title="$1"
    local color="${2:-$BLUE}"
    echo
    echo -e "${color}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${color}${BOLD} $title${NC}"
    echo -e "${color}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo
}

# Run a single test file
run_test_file() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .sh)
    
    log_info "Running test: $test_name"
    
    if [[ ! -f "$test_file" ]]; then
        log_warn "Test file not found: $test_file"
        ((TESTS_SKIPPED++))
        return 0
    fi
    
    if [[ ! -x "$test_file" ]]; then
        log_warn "Test file not executable: $test_file"
        ((TESTS_SKIPPED++))
        return 0
    fi
    
    ((TESTS_TOTAL++))
    
    # Create temporary log file for test output
    local test_log=$(mktemp)
    
    # Run the test and capture output
    if "$test_file" > "$test_log" 2>&1; then
        log_success "Test passed: $test_name"
        ((TESTS_PASSED++))
    else
        log_error "Test failed: $test_name"
        echo "Test output:"
        cat "$test_log"
        echo
        FAILED_TESTS+=("$test_name")
        ((TESTS_FAILED++))
    fi
    
    rm -f "$test_log"
}

# Run unit tests
run_unit_tests() {
    print_banner "UNIT TESTS" "$BLUE"
    
    local unit_test_dir="tests/unit"
    
    if [[ ! -d "$unit_test_dir" ]]; then
        log_warn "Unit test directory not found: $unit_test_dir"
        return 0
    fi
    
    # Find and run all unit test files
    find "$unit_test_dir" -name "test_*.sh" -type f | sort | while read -r test_file; do
        run_test_file "$test_file"
    done
    
    # Also run any direct test files in unit directory
    for test_file in "$unit_test_dir"/*.sh; do
        if [[ -f "$test_file" && "$(basename "$test_file")" =~ ^test_.*\.sh$ ]]; then
            run_test_file "$test_file"
        fi
    done
}

# Run integration tests
run_integration_tests() {
    print_banner "INTEGRATION TESTS" "$YELLOW"
    
    local integration_test_dir="tests/integration"
    
    if [[ ! -d "$integration_test_dir" ]]; then
        log_warn "Integration test directory not found: $integration_test_dir"
        return 0
    fi
    
    # Find and run all integration test files
    find "$integration_test_dir" -name "test_*.sh" -type f | sort | while read -r test_file; do
        run_test_file "$test_file"
    done
}

# Print test summary
print_summary() {
    print_banner "TEST SUMMARY" "$BOLD"
    
    echo -e "Total tests run: ${BOLD}$TESTS_TOTAL${NC}"
    echo -e "Tests passed:    ${GREEN}${BOLD}$TESTS_PASSED${NC}"
    echo -e "Tests failed:    ${RED}${BOLD}$TESTS_FAILED${NC}"
    echo -e "Tests skipped:   ${YELLOW}${BOLD}$TESTS_SKIPPED${NC}"
    echo
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}${BOLD}Failed tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  ${RED}✗${NC} $test"
        done
        echo
        return 1
    else
        echo -e "${GREEN}${BOLD}All tests passed!${NC}"
        echo
        return 0
    fi
}

# Display usage information
usage() {
    echo "Usage: $0 [OPTIONS] [TEST_TYPE]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --verbose  Enable verbose output"
    echo
    echo "Test Types:"
    echo "  unit           Run only unit tests"
    echo "  integration    Run only integration tests"
    echo "  all            Run all tests (default)"
    echo
    echo "Examples:"
    echo "  $0                   # Run all tests"
    echo "  $0 unit             # Run only unit tests"
    echo "  $0 integration      # Run only integration tests"
    echo "  $0 --verbose unit   # Run unit tests with verbose output"
}

# Main function
main() {
    local test_type="all"
    local verbose=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            unit|integration|all)
                test_type="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Get script directory and change to project root
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    cd "$PROJECT_ROOT"
    
    print_banner "TIME MACHINE FOR LINUX - TEST SUITE" "$BOLD"
    
    # Check if we're in the right directory
    if [[ ! -f "lib/loader.sh" ]]; then
        log_error "Not in project root directory"
        log_info "Please run this script from the project root"
        exit 1
    fi
    
    # Set up test environment
    export PROJECT_ROOT
    export VERBOSE=$verbose
    
    # Run tests based on type
    case $test_type in
        unit)
            run_unit_tests
            ;;
        integration)
            # Check if running as root for integration tests
            if [[ $EUID -ne 0 ]]; then
                log_warn "Integration tests may require root privileges"
                log_info "Consider running with sudo for full test coverage"
            fi
            run_integration_tests
            ;;
        all)
            run_unit_tests
            if [[ $EUID -ne 0 ]]; then
                log_warn "Integration tests may require root privileges"
                log_info "Consider running with sudo for full test coverage"
            fi
            run_integration_tests
            ;;
    esac
    
    # Print summary and exit
    if print_summary; then
        exit 0
    else
        exit 1
    fi
}

main "$@"