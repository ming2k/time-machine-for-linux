#!/bin/bash

source "$(dirname "$0")/../../lib/backup-protection.sh"
source "$(dirname "$0")/../../lib/logging.sh"

test_create_safety_snapshots() {
    # Skip if not root
    if [ "$(id -u)" -ne 0 ]; then
        echo "SKIP: test_create_safety_snapshots (requires root)"
        return 0
    fi
    
    # Setup test BTRFS
    local TEST_DIR=$(mktemp -d)
    trap 'rm -rf "$TEST_DIR"' EXIT
    
    # Create test BTRFS volume
    dd if=/dev/zero of="$TEST_DIR/btrfs.img" bs=100M count=10
    local test_dev=$(losetup -f)
    losetup "$test_dev" "$TEST_DIR/btrfs.img"
    mkfs.btrfs "$test_dev"
    
    # Mount and create subvolumes
    mkdir -p "$TEST_DIR/mnt"
    mount "$test_dev" "$TEST_DIR/mnt"
    
    btrfs subvolume create "$TEST_DIR/mnt/@backup"
    btrfs subvolume create "$TEST_DIR/mnt/@snapshots"
    
    # Test snapshot creation
    if ! create_safety_snapshots "$TEST_DIR/mnt/@backup" "$TEST_DIR/mnt/@snapshots" "test"; then
        echo "FAIL: Safety snapshot creation failed"
        return 1
    fi
    
    # Verify snapshot exists
    if [ ! -d "$TEST_DIR/mnt/@snapshots/test-pre-"* ]; then
        echo "FAIL: Pre-backup snapshot not found"
        return 1
    fi
    
    # Cleanup
    umount "$TEST_DIR/mnt"
    losetup -d "$test_dev"
    
    echo "PASS: create_safety_snapshots"
    return 0
}

# Run tests
test_create_safety_snapshots 