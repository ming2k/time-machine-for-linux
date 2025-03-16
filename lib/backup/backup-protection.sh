#!/bin/bash

source "$(dirname "$0")/../core/logging.sh"
source "$(dirname "$0")/../fs/btrfs-utils.sh"

# Create safety snapshot before and after backup operations
create_safety_snapshots() {
    local backup_dir="$1"
    local snapshot_dir="$2"
    local backup_type="$3"  # "system" or "data"
    local timestamp="$(date +%Y-%m-%d-%H-%M-%S)"
    
    # Check if backup directory is on BTRFS
    if ! is_btrfs_filesystem "$backup_dir"; then
        log_msg "ERROR" "Backup directory is not on BTRFS filesystem"
        return 1
    fi
    
    # Check if backup directory is a BTRFS subvolume
    if ! is_btrfs_subvolume "$backup_dir"; then
        log_msg "ERROR" "Backup directory is not a BTRFS subvolume"
        return 1
    fi
    
    # Check if snapshot directory exists and is on BTRFS
    if [ ! -d "$snapshot_dir" ]; then
        log_msg "STEP" "Creating snapshot directory: $snapshot_dir"
        if ! mkdir -p "$snapshot_dir"; then
            log_msg "ERROR" "Failed to create snapshot directory"
            return 1
        fi
    fi

    if ! is_btrfs_filesystem "$snapshot_dir"; then
        log_msg "ERROR" "Snapshot directory must be on a BTRFS filesystem"
        return 1
    fi
    
    # Create pre-backup snapshot with pre- prefix
    local pre_snapshot="${snapshot_dir}/${backup_type}-pre-${timestamp}"
    log_msg "STEP" "Creating pre-backup snapshot at: ${pre_snapshot}"
    
    if ! btrfs subvolume snapshot -r "$backup_dir" "$pre_snapshot"; then
        log_msg "ERROR" "Failed to create pre-backup snapshot"
        log_msg "ERROR" "Command output: $(btrfs subvolume snapshot -r "$backup_dir" "$pre_snapshot" 2>&1)"
        return 1
    fi
    
    log_msg "SUCCESS" "Created pre-backup snapshot at: $pre_snapshot"
    echo "$timestamp"
    return 0
}

# Create post-backup snapshot
create_post_snapshot() {
    local backup_dir="$1"
    local snapshot_dir="$2"
    local backup_type="$3"
    local timestamp="$4"
    
    # Debug info
    log_msg "INFO" "Post-snapshot parameters:"
    log_msg "INFO" "  Backup dir: $backup_dir"
    log_msg "INFO" "  Snapshot dir: $snapshot_dir"
    log_msg "INFO" "  Backup type: $backup_type"
    log_msg "INFO" "  Timestamp: $timestamp"
    
    # Verify parameters
    if [ -z "$backup_dir" ] || [ -z "$snapshot_dir" ] || [ -z "$backup_type" ] || [ -z "$timestamp" ]; then
        log_msg "ERROR" "Missing required parameters for post-backup snapshot"
        return 1
    fi
    
    # Check if backup directory exists
    if [ ! -d "$backup_dir" ]; then
        log_msg "ERROR" "Backup directory does not exist: $backup_dir"
        return 1
    fi
    
    # Check if backup directory still exists and is valid
    if ! is_btrfs_subvolume "$backup_dir"; then
        log_msg "ERROR" "Backup directory is not a valid BTRFS subvolume: $backup_dir"
        return 1
    fi
    
    # Check if snapshot directory exists and is valid
    if [ ! -d "$snapshot_dir" ]; then
        log_msg "ERROR" "Snapshot directory does not exist: $snapshot_dir"
        return 1
    fi
    
    if ! is_btrfs_filesystem "$snapshot_dir"; then
        log_msg "ERROR" "Snapshot directory is not on BTRFS filesystem: $snapshot_dir"
        return 1
    fi
    
    # Create post-backup snapshot with post- prefix
    local post_snapshot="${snapshot_dir}/${backup_type}-post-${timestamp}"
    log_msg "STEP" "Creating post-backup snapshot at: ${post_snapshot}"
    
    # Debug the btrfs command
    local cmd="btrfs subvolume snapshot -r '$backup_dir' '$post_snapshot'"
    log_msg "INFO" "Executing: $cmd"
    
    if ! btrfs subvolume snapshot -r "$backup_dir" "$post_snapshot"; then
        local error_output=$(btrfs subvolume snapshot -r "$backup_dir" "$post_snapshot" 2>&1)
        log_msg "ERROR" "Failed to create post-backup snapshot"
        log_msg "ERROR" "Command output: $error_output"
        return 1
    fi
    
    # Verify the snapshot was created
    if [ ! -d "$post_snapshot" ]; then
        log_msg "ERROR" "Post-backup snapshot directory was not created: $post_snapshot"
        return 1
    fi
    
    log_msg "SUCCESS" "Created post-backup snapshot at: $post_snapshot"
    return 0
}

# Cleanup old snapshots keeping only the latest N
cleanup_old_snapshots() {
    local snapshot_dir="$1"
    local backup_type="$2"
    local keep_count="$3"
    
    log_msg "STEP" "Cleaning up old snapshots"
    find "$snapshot_dir" -maxdepth 1 -type d -name "${backup_type}-*" | \
        sort -r | tail -n +$((keep_count + 1)) | \
        while read snapshot; do
            log_msg "INFO" "Removing old snapshot: $(basename "$snapshot")"
            btrfs subvolume delete "$snapshot" >/dev/null 2>&1
        done
} 