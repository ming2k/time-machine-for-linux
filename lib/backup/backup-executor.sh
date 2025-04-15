#!/bin/bash

source "${LIB_DIR}/core/logging.sh"
source "${LIB_DIR}/backup/backup-protection.sh"
source "${LIB_DIR}/fs/btrfs.sh"  # Added for BTRFS validation


# Execute backup with snapshot protection
execute_backup_with_snapshots() {
    local backup_dest_dir="$1"
    local backup_snapshot_dir="$2"
    local backup_function="$3"  # Function to perform the actual backup

    # Create safety snapshot before backup
    local backup_timestamp=""
    if [ -n "$backup_snapshot_dir" ]; then
        backup_timestamp=$(create_safety_snapshots "$backup_dest_dir" "$backup_snapshot_dir")
        if [ $? -ne 0 ] || [ -z "$backup_timestamp" ]; then
            log_msg "WARNING" "Failed to create safety snapshots, proceeding without protection"
            backup_snapshot_dir=""
        else
            log_msg "INFO" "Using timestamp: $backup_timestamp"
        fi
    fi
    
    # Execute the custom backup function
    if ! $backup_function; then
        log_msg "ERROR" "Backup function failed"
        return 1
    fi
    
    # Create post-backup snapshot if pre-backup snapshot was successful
    if [ -n "$backup_snapshot_dir" ] && [ -n "$backup_timestamp" ]; then
        log_msg "INFO" "Creating post-backup snapshot"
        if ! create_safety_snapshots "$backup_dest_dir" "$backup_snapshot_dir"; then
            log_msg "ERROR" "Failed to create post-backup snapshot"
            return 1
        fi
    fi
    
    log_msg "SUCCESS" "Backup completed successfully"
    return 0
}

# Execute system backup with single snapshot (post-backup only)
execute_system_backup_with_snapshot() {
    local backup_dest_dir="$1"
    local backup_snapshot_dir="$2"
    local backup_function="$3"  # Function to perform the actual backup

    # Execute the system backup function first
    if ! $backup_function; then
        log_msg "ERROR" "System backup function failed"
        return 1
    fi
    
    # Create single snapshot after successful backup
    local backup_timestamp=""
    if [ -n "$backup_snapshot_dir" ]; then
        log_msg "INFO" "Creating system backup snapshot"
        backup_timestamp=$(create_safety_snapshots "$backup_dest_dir" "$backup_snapshot_dir")
        if [ $? -ne 0 ] || [ -z "$backup_timestamp" ]; then
            log_msg "WARNING" "Failed to create system backup snapshot"
        else
            log_msg "SUCCESS" "System backup snapshot created: $backup_timestamp"
        fi
    fi
    
    # Export timestamp for use in results
    TIMESTAMP="$backup_timestamp"
    
    log_msg "SUCCESS" "System backup completed successfully"
    return 0
}

# Show final backup results with snapshots
show_backup_results() {
    local result_success="$1"
    local result_snapshot_dir="$2"
    local result_timestamp="$3"
    
    if [ "$result_success" = "true" ]; then
        if [ -n "$result_timestamp" ]; then
            echo -e "\n${YELLOW}Backup completed successfully with snapshot:${NC}"
            echo -e "${YELLOW}Snapshot: ${result_snapshot_dir}/${result_timestamp}${NC}"
        fi
        print_banner "BACKUP PROCESS COMPLETED" "$GREEN"
        return 0
    else
        if [ -n "$result_timestamp" ]; then
            echo -e "\n${YELLOW}Backup operation had errors.${NC}"
            echo -e "${YELLOW}Snapshot is available at: ${result_snapshot_dir}/${result_timestamp}${NC}"
        fi
        print_banner "BACKUP PROCESS FAILED" "$RED"
        return 1
    fi
}

# Create safety snapshot before backup
create_safety_snapshots() {
    local snapshot_dest_dir="$1"
    local snapshot_snapshot_dir="$2"
    
    # Check if destination is on BTRFS
    log_msg "INFO" "Checking if destination is on a BTRFS filesystem"
    if ! is_btrfs_subvolume "$snapshot_dest_dir"; then
        log_msg "ERROR" "Destination path '$snapshot_dest_dir' is not on a BTRFS filesystem"
        return 1
    fi
    
    # Check if snapshot directory is on BTRFS (if provided)
    if [ -n "$snapshot_snapshot_dir" ]; then
        log_msg "INFO" "Checking if snapshot directory is on a BTRFS filesystem"
        if ! is_btrfs_subvolume "$snapshot_snapshot_dir"; then
            log_msg "ERROR" "Snapshot directory '$snapshot_snapshot_dir' is not on a BTRFS filesystem"
            return 1
        fi
    fi

    local snapshot_timestamp=$(date +%Y%m%d%H%M%S)
    
    # Extract and clean the base name of the destination directory
    local snapshot_dest_name=$(basename "${snapshot_dest_dir%/}")
    
    # Remove leading slash and trailing slashes from snapshot directory
    local clean_snapshot_dir="${snapshot_snapshot_dir%/}"
    
    # Create a more descriptive snapshot name for system backups
    if [[ "$snapshot_dest_name" == "@" ]]; then
        local snapshot_name="system-backup-${snapshot_timestamp}"
    elif [[ "$snapshot_dest_name" == "@data" ]]; then
        local snapshot_name="data-backup-${snapshot_timestamp}"
    else
        local snapshot_name="${snapshot_dest_name}-backup-${snapshot_timestamp}"
    fi
    
    local snapshot_path="${clean_snapshot_dir}/${snapshot_name}"

    log_msg "INFO" "Creating backup snapshot at: $snapshot_path"

    # Attempt to create the snapshot
    if btrfs subvolume snapshot "$snapshot_dest_dir" "$snapshot_path"; then
        log_msg "SUCCESS" "Created backup snapshot at: $snapshot_path"
        echo "$snapshot_timestamp"
    else
        log_msg "ERROR" "Failed to create backup snapshot at: $snapshot_path"
        return 1
    fi
} 