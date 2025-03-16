#!/bin/bash

source "$(dirname "$0")/../core/logging.sh"

# Check if the given path is on a BTRFS filesystem
is_btrfs_filesystem() {
    local path="$1"
    if [ -d "$path" ]; then
        local fstype=$(stat -f -c %T "$path")
        [ "$fstype" = "btrfs" ]
        return $?
    fi
    return 1
}

# Check if the given path is a BTRFS subvolume
is_btrfs_subvolume() {
    local path="$1"
    # First check if it's on BTRFS
    if ! is_btrfs_filesystem "$path"; then
        return 1
    fi
    btrfs subvolume show "$path" >/dev/null 2>&1
    return $?
}

# Create a BTRFS snapshot
create_snapshot() {
    local source="$1"
    local snapshot_path="$2"
    local readonly="$3"
    
    local snapshot_opts=""
    [ "$readonly" = "true" ] && snapshot_opts="-r"
    
    if btrfs subvolume snapshot $snapshot_opts "$source" "$snapshot_path"; then
        log_msg "SUCCESS" "Created snapshot at: $snapshot_path"
        return 0
    else
        log_msg "ERROR" "Failed to create snapshot: $snapshot_path"
        return 1
    fi
} 