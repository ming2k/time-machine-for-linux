#!/bin/bash

# Backup protection utilities
# This script provides safety checks and protection mechanisms for backup operations

# Check if a path is safe for backup operations
is_safe_backup_path() {
    local path="$1"
    
    # Check if path exists
    if [ ! -e "$path" ]; then
        log_msg "ERROR" "Path does not exist: $path"
        return 1
    fi
    
    # Check if path is a mount point
    if mountpoint -q "$path"; then
        log_msg "ERROR" "Path is a mount point: $path"
        return 1
    fi
    
    # Check if path is writable
    if [ ! -w "$path" ]; then
        log_msg "ERROR" "Path is not writable: $path"
        return 1
    fi
    
    return 0
}

# Check if a path is safe for restore operations
is_safe_restore_path() {
    local path="$1"
    
    # Check if path exists
    if [ ! -e "$path" ]; then
        log_msg "ERROR" "Path does not exist: $path"
        return 1
    fi
    
    # Check if path is writable
    if [ ! -w "$path" ]; then
        log_msg "ERROR" "Path is not writable: $path"
        return 1
    fi
    
    return 0
}

# Check if we have enough free space for backup
check_free_space() {
    local source_path="$1"
    local dest_path="$2"
    local required_space="$3"  # in bytes
    
    # Get available space on destination
    local available_space
    available_space=$(df -B1 "$dest_path" | awk 'NR==2 {print $4}')
    
    if [ "$available_space" -lt "$required_space" ]; then
        log_msg "ERROR" "Not enough free space on destination. Required: $required_space, Available: $available_space"
        return 1
    fi
    
    return 0
}

# Create a safety snapshot before backup
create_safety_snapshot() {
    local snapshot_path="$1"
    local snapshot_name="$2"
    
    if ! is_btrfs_subvolume "$snapshot_path"; then
        log_msg "ERROR" "Snapshot path is not a BTRFS subvolume: $snapshot_path"
        return 1
    fi
    
    local full_path="${snapshot_path}/${snapshot_name}"
    
    if [ -e "$full_path" ]; then
        log_msg "ERROR" "Snapshot already exists: $full_path"
        return 1
    fi
    
    if ! btrfs subvolume snapshot "$snapshot_path" "$full_path" >/dev/null 2>&1; then
        log_msg "ERROR" "Failed to create safety snapshot: $full_path"
        return 1
    fi
    
    log_msg "INFO" "Created safety snapshot: $full_path"
    return 0
}

# Verify backup integrity
verify_backup_integrity() {
    local backup_path="$1"
    local source_path="$2"
    
    if [ ! -d "$backup_path" ] || [ ! -d "$source_path" ]; then
        log_msg "ERROR" "Invalid paths for integrity check"
        return 1
    fi
    
    # Basic integrity check - verify that backup contains expected files
    if ! find "$backup_path" -type f | grep -q .; then
        log_msg "ERROR" "Backup appears to be empty"
        return 1
    fi
    
    # Check for critical system files if this is a system backup
    if [ "$source_path" = "/" ]; then
        local critical_files=(
            "/etc/passwd"
            "/etc/group"
            "/etc/shadow"
            "/etc/fstab"
        )
        
        for file in "${critical_files[@]}"; do
            local backup_file="${backup_path}${file}"
            if [ ! -f "$backup_file" ]; then
                log_msg "ERROR" "Critical system file missing in backup: $file"
                return 1
            fi
        done
    fi
    
    return 0
} 