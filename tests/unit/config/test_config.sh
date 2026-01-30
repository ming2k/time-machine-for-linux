#!/bin/bash

source "$(dirname "$0")/../../lib/config-validator.sh"
source "$(dirname "$0")/../../lib/logging.sh"

test_validate_config_file() {
    # Setup
    local TEST_DIR=$(mktemp -d)
    trap 'rm -rf "$TEST_DIR"' EXIT
    
    # Test missing file
    if validate_config_file "$TEST_DIR/nonexistent.txt"; then
        echo "FAIL: Missing file validation should fail"
        return 1
    fi
    
    # Test unreadable file
    touch "$TEST_DIR/unreadable.txt"
    chmod 000 "$TEST_DIR/unreadable.txt"
    if validate_config_file "$TEST_DIR/unreadable.txt"; then
        echo "FAIL: Unreadable file validation should fail"
        return 1
    fi
    
    # Test valid file
    echo "test content" > "$TEST_DIR/valid.txt"
    if ! validate_config_file "$TEST_DIR/valid.txt"; then
        echo "FAIL: Valid file validation should pass"
        return 1
    fi
    
    echo "PASS: validate_config_file"
    return 0
}

test_validate_backup_config() {
    # Setup
    local TEST_DIR=$(mktemp -d)
    trap 'rm -rf "$TEST_DIR"' EXIT
    
    # Create test configs
    mkdir -p "$TEST_DIR/config"
    echo "test" > "$TEST_DIR/config/data-backup-maps.txt"
    echo "test" > "$TEST_DIR/config/system-backup-exclude-list.txt"
    
    # Test data backup config
    if ! validate_backup_config "$TEST_DIR/config" "data"; then
        echo "FAIL: Valid data backup config should pass"
        return 1
    fi
    
    # Test system backup config
    if ! validate_backup_config "$TEST_DIR/config" "system"; then
        echo "FAIL: Valid system backup config should pass"
        return 1
    fi
    
    echo "PASS: validate_backup_config"
    return 0
}

# Run tests
test_validate_config_file
test_validate_backup_config 