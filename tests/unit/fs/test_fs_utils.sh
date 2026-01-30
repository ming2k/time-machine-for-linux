#!/bin/bash

source "$(dirname "$0")/../../../lib/fs/fs-utils.sh"

test_check_directory() {
    # Setup
    local TEST_DIR=$(mktemp -d)
    trap 'rm -rf "$TEST_DIR"' EXIT
    
    # Test existing directory
    if ! check_directory "$TEST_DIR"; then
        echo "FAIL: Valid directory check should pass"
        return 1
    fi
    
    # Test non-existent directory
    if check_directory "$TEST_DIR/nonexistent"; then
        echo "FAIL: Non-existent directory check should fail"
        return 1
    fi
    
    # Test unreadable directory
    mkdir "$TEST_DIR/unreadable"
    chmod 000 "$TEST_DIR/unreadable"
    if check_directory "$TEST_DIR/unreadable"; then
        echo "FAIL: Unreadable directory check should fail"
        return 1
    fi
    
    echo "PASS: check_directory"
    return 0
}

# Run tests
test_check_directory 