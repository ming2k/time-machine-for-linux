#!/bin/bash

# Test suite for backup functionality
# This script should be run from the project root directory

# Load test utilities
source "${BASH_SOURCE%/*}/../test_utils.sh"

# Test backup executor
test_backup_executor() {
    local test_name="Backup Executor"
    local test_dir="${TEST_TEMP_DIR}/backup_test"
    local backup_dir="${test_dir}/backup"
    local snapshot_dir="${test_dir}/snapshots"
    
    # Setup test environment
    setup_test_env "$test_dir" "$backup_dir" "$snapshot_dir"
    
    # Test cases
    test_case "Create backup with snapshots" {
        # Create test data
        mkdir -p "${test_dir}/source"
        echo "test data" > "${test_dir}/source/test.txt"
        
        # Execute backup
        if execute_backup_with_snapshots "$backup_dir" "$snapshot_dir" "test_backup_function"; then
            # Verify backup
            [ -f "${backup_dir}/test.txt" ] || fail "Backup file not found"
            [ "$(cat "${backup_dir}/test.txt")" = "test data" ] || fail "Backup content mismatch"
            
            # Verify snapshot
            local snapshots=($(ls "$snapshot_dir"))
            [ ${#snapshots[@]} -eq 1 ] || fail "Expected 1 snapshot, found ${#snapshots[@]}"
        else
            fail "Backup execution failed"
        fi
    }
    
    test_case "Handle backup failure" {
        # Create test data
        mkdir -p "${test_dir}/source"
        chmod 000 "${test_dir}/source"  # Make directory unreadable
        
        # Execute backup (should fail)
        if execute_backup_with_snapshots "$backup_dir" "$snapshot_dir" "test_backup_function"; then
            fail "Backup should have failed"
        else
            # Verify no backup was created
            [ ! -f "${backup_dir}/test.txt" ] || fail "Backup should not exist"
        fi
    }
    
    # Cleanup
    cleanup_test_env "$test_dir"
}

# Test backup protection
test_backup_protection() {
    local test_name="Backup Protection"
    local test_dir="${TEST_TEMP_DIR}/protection_test"
    local backup_dir="${test_dir}/backup"
    local snapshot_dir="${test_dir}/snapshots"
    
    # Setup test environment
    setup_test_env "$test_dir" "$backup_dir" "$snapshot_dir"
    
    # Test cases
    test_case "Create safety snapshots" {
        # Create test data
        mkdir -p "${backup_dir}/test"
        echo "test data" > "${backup_dir}/test/file.txt"
        
        # Create snapshot
        local timestamp=$(create_safety_snapshots "$backup_dir" "$snapshot_dir")
        [ -n "$timestamp" ] || fail "Failed to create snapshot"
        
        # Verify snapshot
        [ -d "${snapshot_dir}/test-${timestamp}" ] || fail "Snapshot directory not found"
        [ -f "${snapshot_dir}/test-${timestamp}/file.txt" ] || fail "Snapshot file not found"
        [ "$(cat "${snapshot_dir}/test-${timestamp}/file.txt")" = "test data" ] || fail "Snapshot content mismatch"
    }
    
    test_case "Handle invalid paths" {
        # Test with non-existent path
        if create_safety_snapshots "/nonexistent" "$snapshot_dir"; then
            fail "Should fail with non-existent path"
        fi
        
        # Test with non-BTRFS path
        if create_safety_snapshots "/tmp" "$snapshot_dir"; then
            fail "Should fail with non-BTRFS path"
        fi
    }
    
    # Cleanup
    cleanup_test_env "$test_dir"
}

# Test backup results display
test_backup_results() {
    local test_name="Backup Results"
    local test_dir="${TEST_TEMP_DIR}/results_test"
    local backup_dir="${test_dir}/backup"
    local snapshot_dir="${test_dir}/snapshots"
    
    # Setup test environment
    setup_test_env "$test_dir" "$backup_dir" "$snapshot_dir"
    
    # Test cases
    test_case "Display successful backup" {
        # Create test snapshot
        mkdir -p "${snapshot_dir}/test-20240318"
        local output=$(show_backup_results "true" "$snapshot_dir" "20240318")
        
        # Verify output contains success message
        [[ "$output" == *"Backup completed successfully"* ]] || fail "Missing success message"
        [[ "$output" == *"20240318"* ]] || fail "Missing timestamp"
    }
    
    test_case "Display failed backup" {
        # Create test snapshot
        mkdir -p "${snapshot_dir}/test-20240318"
        local output=$(show_backup_results "false" "$snapshot_dir" "20240318")
        
        # Verify output contains error message
        [[ "$output" == *"Backup operation had errors"* ]] || fail "Missing error message"
        [[ "$output" == *"20240318"* ]] || fail "Missing timestamp"
    }
    
    # Cleanup
    cleanup_test_env "$test_dir"
}

# Helper function for test backup
test_backup_function() {
    # Simple backup function for testing
    cp -r "${test_dir}/source/"* "$backup_dir/"
    return $?
}

# Run all tests
run_tests() {
    test_backup_executor
    test_backup_protection
    test_backup_results
}

# Main execution
if [ "$(basename "$0")" = "backup_test.sh" ]; then
    run_tests
fi 