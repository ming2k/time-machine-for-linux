#!/bin/bash

source "${LIB_DIR}/core/logging.sh"
source "${LIB_DIR}/backup/backup-protection.sh"
source "${LIB_DIR}/fs/btrfs-utils.sh"  # Added for BTRFS validation

# Validate that paths are on BTRFS filesystem
validate_btrfs_paths() {
    local dest_dir="$1"
    local snapshot_dir="$2"
    
    # Check if destination is on BTRFS
    if ! is_btrfs_subvolume "$dest_dir"; then
        log_msg "ERROR" "Destination path '$dest_dir' is not on a BTRFS filesystem"
        return 1
    fi
    
    # Check if snapshot directory is on BTRFS (if provided)
    if [ -n "$snapshot_dir" ] && ! is_btrfs_subvolume "$snapshot_dir"; then
        log_msg "ERROR" "Snapshot directory '$snapshot_dir' is not on a BTRFS filesystem"
        return 1
    fi
    
    return 0
}

# Execute backup with snapshot protection
execute_backup_with_snapshots() {
    local dest_dir="$1"
    local snapshot_dir="$2"
    local backup_function="$3"  # Function to perform the actual backup

    # Validate BTRFS paths if snapshots are requested
    if [ -n "$snapshot_dir" ]; then
        log_msg "INFO" "Validating BTRFS filesystems"
        if ! validate_btrfs_paths "$dest_dir" "$snapshot_dir"; then
            log_msg "WARNING" "BTRFS validation failed, proceeding without snapshot protection"
            snapshot_dir=""
        fi
    fi
    
    # Create safety snapshot before backup
    local timestamp=""
    if [ -n "$snapshot_dir" ]; then
        log_msg "INFO" "Creating safety snapshots"
        timestamp=$(create_safety_snapshots "$dest_dir" "$snapshot_dir")
        if [ $? -ne 0 ] || [ -z "$timestamp" ]; then
            log_msg "WARNING" "Failed to create safety snapshots, proceeding without protection"
            timestamp=""
        else
            log_msg "INFO" "Using timestamp: $timestamp"
        fi
    fi
    
    # Execute the custom backup function
    if ! $backup_function; then
        log_msg "ERROR" "Backup function failed"
        return 1
    fi
    
    # Create post-backup snapshot if pre-backup snapshot was successful
    if [ -n "$snapshot_dir" ] && [ -n "$timestamp" ]; then
        log_msg "INFO" "Creating post-backup snapshot"
        if ! create_post_snapshot "$dest_dir" "$snapshot_dir" "$timestamp"; then
            log_msg "ERROR" "Failed to create post-backup snapshot"
            return 1
        fi
    fi
    
    log_msg "SUCCESS" "Backup completed successfully"
    return 0
}

# Show final backup results with snapshots
show_backup_results() {
    local success="$1"
    local snapshot_dir="$2"
    local backup_type="$3"
    local timestamp="$4"
    
    if [ "$success" = "true" ]; then
        if [ -n "$timestamp" ]; then
            echo -e "\n${YELLOW}Backup completed successfully with snapshots:${NC}"
            echo -e "${YELLOW}Pre-backup snapshot : ${snapshot_dir}/${backup_type}-pre-${timestamp}${NC}"
            echo -e "${YELLOW}Post-backup snapshot: ${snapshot_dir}/${backup_type}-post-${timestamp}${NC}"
        fi
        print_banner "BACKUP PROCESS COMPLETED" "$GREEN"
        return 0
    else
        if [ -n "$timestamp" ]; then
            echo -e "\n${YELLOW}Backup operation had errors.${NC}"
            echo -e "${YELLOW}Pre-backup snapshot is available at: ${snapshot_dir}/${backup_type}-pre-${timestamp}${NC}"
        fi
        print_banner "BACKUP PROCESS FAILED" "$RED"
        return 1
    fi
}

# Create safety snapshot before backup
create_safety_snapshots() {
    local dest_dir="$1"
    local snapshot_dir="$2"
    local timestamp=$(date +%Y-%m-%d-%H-%M-%S)
    
    # Extract the base name of the destination directory
    local dest_name=$(basename "$dest_dir")
    local snapshot_path="${snapshot_dir}/${dest_name}-${timestamp}"

    log_msg "INFO" "Creating pre-backup snapshot at: $snapshot_path"

    # Attempt to create the snapshot
    if btrfs subvolume snapshot "$dest_dir" "$snapshot_path"; then
        log_msg "SUCCESS" "Created pre-backup snapshot at: $snapshot_path"
        echo "$timestamp"
    else
        log_msg "ERROR" "Failed to create pre-backup snapshot at: $snapshot_path"
        return 1
    fi
} 