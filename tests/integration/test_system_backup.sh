#!/bin/bash

source "$(dirname "$0")/../../lib/logging.sh"

setup_system_test() {
    TEST_ROOT=$(mktemp -d)
    mkdir -p "$TEST_ROOT"/{source,backup,snapshots}
    
    # Create minimal system structure
    mkdir -p "$TEST_ROOT/source"/{bin,etc,lib,usr}
    touch "$TEST_ROOT/source/etc/"{fstab,passwd,group}
    
    # Create test config
    mkdir -p "$TEST_ROOT/config"
    echo "/proc/*" > "$TEST_ROOT/config/system-backup-exclude-list.txt"
    echo "/sys/*" >> "$TEST_ROOT/config/system-backup-exclude-list.txt"
}

cleanup_system_test() {
    rm -rf "$TEST_ROOT"
}

test_system_backup() {
    # Setup
    setup_system_test
    trap cleanup_system_test EXIT
    
    # Run backup
    ../../bin/system-backup.sh "$TEST_ROOT/source" "$TEST_ROOT/backup" "$TEST_ROOT/snapshots"
    
    # Verify essential directories
    for dir in bin etc lib usr; do
        if [ ! -d "$TEST_ROOT/backup/$dir" ]; then
            echo "FAIL: Essential directory missing: $dir"
            return 1
        fi
    done
    
    # Verify essential files
    for file in etc/fstab etc/passwd etc/group; do
        if [ ! -f "$TEST_ROOT/backup/$file" ]; then
            echo "FAIL: Essential file missing: $file"
            return 1
        fi
    done
    
    echo "PASS: system_backup"
    return 0
}

# Run test
test_system_backup 