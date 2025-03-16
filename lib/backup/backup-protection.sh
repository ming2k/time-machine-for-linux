#!/bin/bash

source "${LIB_DIR}/core/logging.sh"
source "${LIB_DIR}/fs/btrfs-utils.sh"

# Create safety snapshot before and after backup operations
create_safety_snapshots() {
    local backup_dir="$1"
    local snapshot_dir="$2"
    local backup_type="$3"  # "system" or "data"
    local timestamp="$(date +%Y-%m-%d-%H-%M-%S)"
    
    # Remove trailing slashes from paths
    backup_dir="${backup_dir%/}"
    snapshot_dir="${snapshot_dir%/}"
    
    # Verify directories are writable first
    if ! touch "$backup_dir/test_write_$$" 2>/dev/null; then
        log_msg "ERROR" "Backup directory is not writable: $backup_dir" >&2
        return 1
    fi
    rm -f "$backup_dir/test_write_$$"
    
    if ! touch "$snapshot_dir/test_write_$$" 2>/dev/null; then
        log_msg "ERROR" "Snapshot directory is not writable: $snapshot_dir" >&2
        return 1
    fi
    rm -f "$snapshot_dir/test_write_$$"
    
    # Check if backup directory is on BTRFS
    if ! is_btrfs_filesystem "$backup_dir"; then
        log_msg "ERROR" "Backup directory is not on BTRFS filesystem" >&2
        return 1
    fi
    
    # Check if backup directory is a BTRFS subvolume
    if ! is_btrfs_subvolume "$backup_dir"; then
        log_msg "ERROR" "Backup directory is not a BTRFS subvolume" >&2
        return 1
    fi
    
    # Check if snapshot directory exists and is on BTRFS
    if [ ! -d "$snapshot_dir" ]; then
        log_msg "STEP" "Creating snapshot directory: $snapshot_dir" >&2
        if ! mkdir -p "$snapshot_dir"; then
            log_msg "ERROR" "Failed to create snapshot directory" >&2
            return 1
        fi
    fi

    if ! is_btrfs_filesystem "$snapshot_dir"; then
        log_msg "ERROR" "Snapshot directory must be on a BTRFS filesystem" >&2
        return 1
    fi
    
    # Create pre-backup snapshot with pre- prefix
    local pre_snapshot="${snapshot_dir}/${backup_type}-pre-${timestamp}"
    log_msg "STEP" "Creating pre-backup snapshot at: ${pre_snapshot}" >&2
    
    if ! btrfs subvolume snapshot -r "$backup_dir" "$pre_snapshot" >/dev/null 2>&1; then
        log_msg "ERROR" "Failed to create pre-backup snapshot" >&2
        return 1
    fi
    
    log_msg "SUCCESS" "Created pre-backup snapshot at: $pre_snapshot" >&2
    
    # Return only the timestamp on stdout
    echo "$timestamp"
    return 0
}

# Create post-backup snapshot
create_post_snapshot() {
    local backup_dir="$1"
    local snapshot_dir="$2"
    local backup_type="$3"
    local timestamp="$4"
    
    # Remove trailing slashes from paths
    backup_dir="${backup_dir%/}"
    snapshot_dir="${snapshot_dir%/}"
    
    # Validate timestamp format
    if [[ ! "$timestamp" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]; then
        log_msg "ERROR" "Invalid timestamp format: '$timestamp'"
        return 1
    fi
    
    # Debug info
    log_msg "INFO" "Post-snapshot parameters:"
    log_msg "INFO" "  Backup dir: $backup_dir"
    log_msg "INFO" "  Snapshot dir: $snapshot_dir"
    log_msg "INFO" "  Backup type: $backup_type"
    log_msg "INFO" "  Timestamp: $timestamp"
    
    # Create post-backup snapshot with post- prefix
    local post_snapshot="${snapshot_dir}/${backup_type}-post-${timestamp}"
    log_msg "INFO" "Creating post-backup snapshot at: ${post_snapshot}"
    
    # Verify source exists
    if [ ! -d "$backup_dir" ]; then
        log_msg "ERROR" "Source directory does not exist: $backup_dir"
        return 1
    fi
    
    # Capture and format btrfs output
    if ! output=$(btrfs subvolume snapshot -r "$backup_dir" "$post_snapshot" 2>&1); then
        local error_output="$output"
        log_msg "ERROR" "Failed to create post-backup snapshot"
        log_msg "ERROR" "Command output: $error_output"
        return 1
    fi
    
    # Format the btrfs output using log_msg
    log_msg "INFO" "BTRFS: Create readonly snapshot of '$backup_dir' in '$post_snapshot'"
    
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
    
    # Remove trailing slash from snapshot directory
    snapshot_dir="${snapshot_dir%/}"
    
    log_msg "INFO" "Cleaning up old snapshots"
    
    # List snapshots sorted by date (newest first)
    find "$snapshot_dir" -maxdepth 1 -type d -name "${backup_type}-*" | \
        sort -r | tail -n +$((keep_count + 1)) | \
        while read snapshot; do
            log_msg "INFO" "Removing old snapshot: $(basename "$snapshot")"
            btrfs subvolume delete "$snapshot" >/dev/null 2>&1
        done
} 