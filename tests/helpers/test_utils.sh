#!/bin/bash

# Test utilities for backup testing
# This script provides common functions for test cases

# Test configuration
TEST_TEMP_DIR="/tmp/backup_test"
TEST_COUNT=0
TEST_PASSED=0
TEST_FAILED=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Setup test environment
setup_test_env() {
    local test_dir="$1"
    local backup_dir="$2"
    local snapshot_dir="$3"
    
    # Create test directories
    mkdir -p "$test_dir"
    mkdir -p "$backup_dir"
    mkdir -p "$snapshot_dir"
    
    # Create BTRFS subvolumes if needed
    if ! is_btrfs_subvolume "$backup_dir"; then
        btrfs subvolume create "$backup_dir" >/dev/null 2>&1
    fi
    
    if ! is_btrfs_subvolume "$snapshot_dir"; then
        btrfs subvolume create "$snapshot_dir" >/dev/null 2>&1
    fi
}

# Cleanup test environment
cleanup_test_env() {
    local test_dir="$1"
    
    # Remove test directories
    rm -rf "$test_dir"
}

# Test case wrapper
test_case() {
    local name="$1"
    local code="$2"
    
    TEST_COUNT=$((TEST_COUNT + 1))
    echo -e "${YELLOW}Running test: $name${NC}"
    
    # Execute test code
    if eval "$code"; then
        TEST_PASSED=$((TEST_PASSED + 1))
        echo -e "${GREEN}✓ Test passed: $name${NC}"
    else
        TEST_FAILED=$((TEST_FAILED + 1))
        echo -e "${RED}✗ Test failed: $name${NC}"
    fi
}

# Fail test with message
fail() {
    local message="$1"
    echo -e "${RED}Test failed: $message${NC}"
    return 1
}

# Print test summary
print_test_summary() {
    echo -e "\n${YELLOW}Test Summary:${NC}"
    echo -e "Total tests: $TEST_COUNT"
    echo -e "${GREEN}Passed: $TEST_PASSED${NC}"
    echo -e "${RED}Failed: $TEST_FAILED${NC}"
    
    if [ $TEST_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Check if path is a BTRFS subvolume
is_btrfs_subvolume() {
    local path="$1"
    btrfs subvolume show "$path" >/dev/null 2>&1
    return $?
}

# Create test data
create_test_data() {
    local dir="$1"
    local count="${2:-10}"
    
    mkdir -p "$dir"
    for i in $(seq 1 $count); do
        echo "Test file $i" > "$dir/file$i.txt"
    done
}

# Verify test data
verify_test_data() {
    local source_dir="$1"
    local dest_dir="$2"
    local count="${3:-10}"
    
    for i in $(seq 1 $count); do
        if [ ! -f "$dest_dir/file$i.txt" ]; then
            fail "File file$i.txt not found in destination"
            return 1
        fi
        
        if [ "$(cat "$source_dir/file$i.txt")" != "$(cat "$dest_dir/file$i.txt")" ]; then
            fail "Content mismatch in file$i.txt"
            return 1
        fi
    done
    
    return 0
}

# Run cleanup on exit
trap 'cleanup_test_env "$TEST_TEMP_DIR"' EXIT 