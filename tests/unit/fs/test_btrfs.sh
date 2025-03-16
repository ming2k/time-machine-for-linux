#!/bin/bash

source "$(dirname "$0")/../../lib/btrfs-utils.sh"
source "$(dirname "$0")/../../lib/logging.sh"

test_is_btrfs_filesystem() {
    # Setup
    local test_dir=$(mktemp -d)
    trap 'rm -rf "$test_dir"' EXIT
    
    # Test non-btrfs filesystem
    if is_btrfs_filesystem "$test_dir"; then
        echo "FAIL: Regular directory detected as BTRFS"
        return 1
    fi
    
    # Test non-existent path
    if is_btrfs_filesystem "/nonexistent/path"; then
        echo "FAIL: Non-existent path detected as BTRFS"
        return 1
    fi
    
    echo "PASS: is_btrfs_filesystem"
    return 0
}

test_is_btrfs_subvolume() {
    # This test requires root privileges and actual BTRFS volume
    if [ "$(id -u)" -ne 0 ]; then
        echo "SKIP: test_is_btrfs_subvolume (requires root)"
        return 0
    fi
    
    # Setup test BTRFS volume
    local test_dev=$(losetup -f)
    dd if=/dev/zero of=test.img bs=100M count=10
    losetup "$test_dev" test.img
    mkfs.btrfs "$test_dev"
    
    local mount_point=$(mktemp -d)
    mount "$test_dev" "$mount_point"
    
    # Create test subvolume
    btrfs subvolume create "$mount_point/test_subvol"
    
    # Test subvolume detection
    if ! is_btrfs_subvolume "$mount_point/test_subvol"; then
        echo "FAIL: Subvolume not detected"
        return 1
    fi
    
    # Cleanup
    umount "$mount_point"
    losetup -d "$test_dev"
    rm -f test.img
    rm -rf "$mount_point"
    
    echo "PASS: is_btrfs_subvolume"
    return 0
} 