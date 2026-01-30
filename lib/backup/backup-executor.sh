#!/bin/bash

source "${LIB_DIR}/core/logging.sh"
source "${LIB_DIR}/backup/backup-protection.sh"
source "${LIB_DIR}/fs/btrfs.sh"  # Added for BTRFS validation


# Execute backup with snapshot protection
execute_backup_with_snapshots() {
    local backup_dest_dir="$1"
    local backup_snapshot_dir="$2"
    local backup_function="$3"

    # Create safety snapshot before backup
    local backup_timestamp=""
    if [ -n "$backup_snapshot_dir" ]; then
        backup_timestamp=$(create_safety_snapshots "$backup_dest_dir" "$backup_snapshot_dir")
        if [ $? -ne 0 ] || [ -z "$backup_timestamp" ]; then
            log_msg "WARNING" "Failed to create safety snapshot"
            backup_snapshot_dir=""
        fi
    fi

    # Execute the backup function
    if ! $backup_function; then
        return 1
    fi

    # Create post-backup snapshot
    if [ -n "$backup_snapshot_dir" ] && [ -n "$backup_timestamp" ]; then
        create_safety_snapshots "$backup_dest_dir" "$backup_snapshot_dir" >/dev/null
    fi

    return 0
}

# Execute system backup with single snapshot (post-backup only)
execute_system_backup_with_snapshot() {
    local backup_dest_dir="$1"
    local backup_snapshot_dir="$2"
    local backup_function="$3"

    # Execute the backup function
    if ! $backup_function; then
        return 1
    fi

    # Create snapshot after successful backup
    local backup_timestamp=""
    if [ -n "$backup_snapshot_dir" ]; then
        backup_timestamp=$(create_safety_snapshots "$backup_dest_dir" "$backup_snapshot_dir")
        [ $? -ne 0 ] && log_msg "WARNING" "Failed to create snapshot"
    fi

    TIMESTAMP="$backup_timestamp"
    return 0
}

# Show final backup results
show_backup_results() {
    local result_success="$1"
    local result_snapshot_dir="$2"
    local result_timestamp="$3"

    echo ""
    if [ "$result_success" = "true" ]; then
        log_msg "SUCCESS" "Backup completed"
        [ -n "$result_timestamp" ] && echo -e "   Snapshot: ${result_snapshot_dir}/${result_timestamp}"
        return 0
    else
        log_msg "ERROR" "Backup failed"
        [ -n "$result_timestamp" ] && echo -e "   Snapshot: ${result_snapshot_dir}/${result_timestamp}"
        return 1
    fi
}

# Create safety snapshot
create_safety_snapshots() {
    local snapshot_dest_dir="$1"
    local snapshot_snapshot_dir="$2"

    # Validate BTRFS
    if ! is_btrfs_subvolume "$snapshot_dest_dir"; then
        log_msg "ERROR" "Destination is not a BTRFS subvolume"
        return 1
    fi

    if [ -n "$snapshot_snapshot_dir" ] && ! is_btrfs_subvolume "$snapshot_snapshot_dir"; then
        log_msg "ERROR" "Snapshot dir is not a BTRFS subvolume"
        return 1
    fi

    local snapshot_timestamp=$(date +%Y%m%d%H%M%S)
    local snapshot_dest_name=$(basename "${snapshot_dest_dir%/}")
    local clean_snapshot_dir="${snapshot_snapshot_dir%/}"

    # Create snapshot name
    local snapshot_name
    case "$snapshot_dest_name" in
        "@") snapshot_name="system-backup-${snapshot_timestamp}" ;;
        "@data") snapshot_name="data-backup-${snapshot_timestamp}" ;;
        *) snapshot_name="${snapshot_dest_name}-backup-${snapshot_timestamp}" ;;
    esac

    local snapshot_path="${clean_snapshot_dir}/${snapshot_name}"

    if btrfs subvolume snapshot "$snapshot_dest_dir" "$snapshot_path" >/dev/null 2>&1; then
        echo "$snapshot_timestamp"
    else
        log_msg "ERROR" "Failed to create snapshot"
        return 1
    fi
} 