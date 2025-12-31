#!/bin/bash

# Restore protection utilities
# This script provides safety checks and protection mechanisms for restore operations

# Create a pre-restore snapshot of the destination
create_pre_restore_snapshot() {
    local dest_path="$1"
    local snapshot_dir="$2"
    local restore_type="$3"  # "system" or "data"

    if [ -z "$dest_path" ] || [ -z "$restore_type" ]; then
        log_msg "ERROR" "Missing required parameters for pre-restore snapshot"
        return 1
    fi

    # If no snapshot directory provided, skip snapshot creation
    if [ -z "$snapshot_dir" ]; then
        log_msg "INFO" "No snapshot directory provided, skipping pre-restore snapshot"
        return 0
    fi

    # Validate snapshot directory is BTRFS subvolume
    if ! is_btrfs_subvolume "$snapshot_dir"; then
        log_msg "WARNING" "Snapshot directory is not a BTRFS subvolume: $snapshot_dir"
        log_msg "WARNING" "Skipping pre-restore snapshot creation"
        return 0
    fi

    # Create snapshot name with timestamp
    local timestamp=$(date +%Y%m%d%H%M%S)
    local snapshot_name="pre-restore-${restore_type}-${timestamp}"

    # Remove trailing slash from snapshot dir to avoid double slashes
    local clean_snapshot_dir="${snapshot_dir%/}"
    local snapshot_path="${clean_snapshot_dir}/${snapshot_name}"

    if [ -e "$snapshot_path" ]; then
        log_msg "ERROR" "Snapshot already exists: $snapshot_path"
        return 1
    fi

    # For system restore, snapshot the entire system
    # For data restore, snapshot the specific destination directory
    local source_for_snapshot="$dest_path"

    # Validate source is on BTRFS (for snapshot capability)
    if ! is_btrfs_filesystem "$source_for_snapshot"; then
        log_msg "WARNING" "Destination is not on BTRFS filesystem, skipping snapshot"
        log_msg "WARNING" "Restore will proceed without rollback capability"
        return 0
    fi

    # Create the snapshot
    log_msg "INFO" "Creating pre-restore snapshot: $snapshot_name"
    if ! btrfs subvolume snapshot "$source_for_snapshot" "$snapshot_path" >/dev/null 2>&1; then
        log_msg "ERROR" "Failed to create pre-restore snapshot: $snapshot_path"
        return 1
    fi

    log_msg "SUCCESS" "Pre-restore snapshot created: $snapshot_path"

    # Store snapshot path for later reference
    PRE_RESTORE_SNAPSHOT="$snapshot_path"
    export PRE_RESTORE_SNAPSHOT

    return 0
}

# Validate that restore is safe to proceed
validate_restore_safety() {
    local source_path="$1"
    local dest_path="$2"

    if [ -z "$source_path" ] || [ -z "$dest_path" ]; then
        log_msg "ERROR" "Missing required parameters for safety validation"
        return 1
    fi

    # Check if source exists and is readable
    if [ ! -d "$source_path" ]; then
        log_msg "ERROR" "Source path does not exist: $source_path"
        return 1
    fi

    if [ ! -r "$source_path" ]; then
        log_msg "ERROR" "Source path is not readable: $source_path"
        return 1
    fi

    # Check if destination is writable (use is_safe_restore_path if available)
    if ! is_safe_restore_path "$dest_path"; then
        return 1
    fi

    # Check if source contains any files
    if ! find "$source_path" -type f -print -quit | grep -q .; then
        log_msg "ERROR" "Source appears to be empty: $source_path"
        return 1
    fi

    return 0
}

# Calculate restore impact (estimate what will be changed)
calculate_restore_impact() {
    local source_path="$1"
    local dest_path="$2"

    if [ -z "$source_path" ] || [ -z "$dest_path" ]; then
        log_msg "ERROR" "Missing required parameters for impact calculation"
        return 1
    fi

    # Count total files in source
    local total_files
    total_files=$(find "$source_path" -type f 2>/dev/null | wc -l)

    # Calculate total size
    local total_size
    total_size=$(du -sb "$source_path" 2>/dev/null | cut -f1)

    # Convert size to human-readable format
    local size_human
    if [ -n "$total_size" ]; then
        size_human=$(numfmt --to=iec-i --suffix=B "$total_size" 2>/dev/null || echo "${total_size} bytes")
    else
        size_human="unknown"
    fi

    # Export for display
    RESTORE_FILE_COUNT="$total_files"
    RESTORE_SIZE="$size_human"
    export RESTORE_FILE_COUNT
    export RESTORE_SIZE

    log_msg "INFO" "Restore impact: $total_files files, $size_human"

    return 0
}

# Validate system restore source contains critical files
validate_system_restore_source() {
    local source_path="$1"

    if [ -z "$source_path" ]; then
        log_msg "ERROR" "Missing source path for system validation"
        return 1
    fi

    # Check for critical system directories
    local critical_dirs=("bin" "etc" "lib" "usr")
    local missing_dirs=()

    for dir in "${critical_dirs[@]}"; do
        if [ ! -d "${source_path}/${dir}" ]; then
            missing_dirs+=("$dir")
        fi
    done

    if [ ${#missing_dirs[@]} -gt 0 ]; then
        log_msg "ERROR" "Source is missing critical system directories: ${missing_dirs[*]}"
        return 1
    fi

    # Check for critical system files
    local critical_files=(
        "etc/passwd"
        "etc/group"
        "etc/fstab"
    )
    local missing_files=()

    for file in "${critical_files[@]}"; do
        if [ ! -f "${source_path}/${file}" ]; then
            missing_files+=("$file")
        fi
    done

    if [ ${#missing_files[@]} -gt 0 ]; then
        log_msg "WARNING" "Source is missing some system files: ${missing_files[*]}"
    fi

    log_msg "SUCCESS" "System restore source validation passed"
    return 0
}

# Check available disk space for restore
check_restore_disk_space() {
    local source_path="$1"
    local dest_path="$2"

    if [ -z "$source_path" ] || [ -z "$dest_path" ]; then
        log_msg "ERROR" "Missing required parameters for disk space check"
        return 1
    fi

    # Calculate source size
    local required_space
    required_space=$(du -sb "$source_path" 2>/dev/null | cut -f1)

    if [ -z "$required_space" ] || [ "$required_space" -eq 0 ]; then
        log_msg "WARNING" "Could not determine source size, skipping disk space check"
        return 0
    fi

    # Get available space on destination
    local available_space
    available_space=$(df -B1 "$dest_path" | awk 'NR==2 {print $4}')

    if [ -z "$available_space" ]; then
        log_msg "WARNING" "Could not determine available space, skipping disk space check"
        return 0
    fi

    # Add 10% buffer
    required_space=$((required_space * 11 / 10))

    if [ "$available_space" -lt "$required_space" ]; then
        local req_human=$(numfmt --to=iec-i --suffix=B "$required_space" 2>/dev/null || echo "$required_space")
        local avail_human=$(numfmt --to=iec-i --suffix=B "$available_space" 2>/dev/null || echo "$available_space")
        log_msg "ERROR" "Insufficient disk space. Required: $req_human, Available: $avail_human"
        return 1
    fi

    log_msg "INFO" "Disk space check passed"
    return 0
}
