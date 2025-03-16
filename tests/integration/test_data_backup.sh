#!/bin/bash

source "$(dirname "$0")/../../lib/logging.sh"

# Setup test environment
setup() {
    TEST_ROOT=$(mktemp -d)
    mkdir -p "$TEST_ROOT"/{source,backup,snapshots}
    
    # Create test files
    echo "test file 1" > "$TEST_ROOT/source/file1.txt"
    echo "test file 2" > "$TEST_ROOT/source/file2.txt"
    mkdir -p "$TEST_ROOT/source/subdir"
    echo "test file 3" > "$TEST_ROOT/source/subdir/file3.txt"
    
    # Create test config
    cat > "$TEST_ROOT/data-backup-maps.txt" << EOF
$TEST_ROOT/source | $TEST_ROOT/backup | *.tmp
EOF
}

# Cleanup test environment
cleanup() {
    rm -rf "$TEST_ROOT"
}

test_data_backup() {
    # Setup
    setup
    trap cleanup EXIT
    
    # Run backup
    ../../bin/data-backup.sh "$TEST_ROOT/backup" "$TEST_ROOT/snapshots"
    
    # Verify backup
    for file in file1.txt file2.txt subdir/file3.txt; do
        if ! cmp "$TEST_ROOT/source/$file" "$TEST_ROOT/backup/$file"; then
            echo "FAIL: Backup file mismatch: $file"
            return 1
        fi
    done
    
    # Verify snapshot
    if [ ! -d "$TEST_ROOT/snapshots" ]; then
        echo "FAIL: Snapshot directory not created"
        return 1
    fi
    
    echo "PASS: data_backup"
    return 0
} 