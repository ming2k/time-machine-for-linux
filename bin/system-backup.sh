#!/bin/bash

# Get project paths
SCRIPT_PATH="$(readlink -f "$0")"
PROJECT_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"
CONFIG_DIR="${PROJECT_ROOT}/config"

# Load libraries
source "${LIB_DIR}/lib-loader.sh"
if ! load_backup_libs "$LIB_DIR"; then
    echo "Failed to load required libraries" >&2
    exit 1
fi

# Import colors directly to ensure they're available
source "${LIB_DIR}/core/colors.sh"

# Validate configs
if ! validate_backup_config "$CONFIG_DIR" "system"; then
    log_msg "ERROR" "Invalid configuration"
    exit 1
fi

# Check if path is a valid system root by verifying essential directories and files
is_valid_system_root() {
    local path="$1"
    local required_dirs=("bin" "etc" "lib" "usr")
    local required_files=("etc/fstab" "etc/passwd" "etc/group")
    
    # Check for essential directories
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "${path}/${dir}" ]; then
            log_msg "ERROR" "Essential directory not found: ${path}/${dir}"
            return 1
        fi
    done
    
    # Check for essential files
    for file in "${required_files[@]}"; do
        if [ ! -f "${path}/${file}" ]; then
            log_msg "ERROR" "Essential file not found: ${path}/${file}"
            return 1
        fi
    done
    
    return 0
}

# Generate exclude list from config file
generate_exclude_list() {
    local source_path="$1"
    local temp_exclude_file="$2"
    local exclude_config="${CONFIG_DIR}/backup/system-exclude.conf"
    
    # Check if exclude config exists
    if [ ! -f "$exclude_config" ]; then
        log_msg "ERROR" "Exclude list file not found: $exclude_config"
        exit 1
    fi
    
    # Remove trailing slash from source path if present
    source_path="${source_path%/}"
    
    # Create temporary exclude file with prefixed paths
    > "$temp_exclude_file"  # Clear the file first
    
    while IFS= read -r line; do
        # Preserve comments and empty lines
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            echo "$line" >> "$temp_exclude_file"
            continue
        fi
        
        # Remove leading slash if present
        line="${line#/}"
        # Add source path prefix
        echo "${source_path}/${line}" >> "$temp_exclude_file"
    done < "$exclude_config"
}

# Display backup operation details and ask for confirmation
confirm_execution() {
    local source="$1"
    local dest="$2"
    local snapshot="$3"
    local temp_exclude_file="$4"
    
    print_header "SYSTEM BACKUP CONFIRMATION"
    
    echo -e "${BOLD}The following backup operation will be performed:${NC}\n"
    echo -e "${CYAN}System Root Directory:${NC} ${BOLD}$source${NC}"
    echo -e "${CYAN}Backup Directory:${NC} ${BOLD}$dest${NC}"
    if [ -n "$snapshot" ]; then
        echo -e "${CYAN}Backup Snapshots:${NC} ${BOLD}$snapshot${NC}"
    fi
    
    if ! is_btrfs_filesystem "$dest"; then
        echo -e "\n${YELLOW}⚠️  Warning: Backup directory is not on a BTRFS filesystem.${NC}"
        echo -e "${YELLOW}   Snapshots will be skipped.${NC}"
    fi
    
    echo -e "\n${CYAN}Excluded Patterns:${NC}"
    while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue
        # Print comments as section headers
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            echo -e "\n${BOLD}${line#\#}${NC}"
        else
            # Strip source path prefix for display
            echo -e " • ${line#$source/}"
        fi
    done < "$temp_exclude_file"
    
    echo -e "\n${YELLOW}⚠️  Warning: This operation will synchronize the destination with the source.${NC}"
    echo -e "${YELLOW}   Files that exist only in the destination will be deleted.${NC}\n"
    
    read -p "Do you want to proceed with the backup? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_msg "INFO" "Backup operation cancelled by user"
        exit 1
    fi
}

# Display usage information
usage() {
    echo -e "${BOLD}Usage:${NC} $0 [--validate-snapshots] <source_dir> <backup_dir> <snapshot_dir>"
    echo -e "${BOLD}Example:${NC} $0 /mnt /mnt/@backup /mnt/@backup_snapshots"
    echo
    echo -e "${BOLD}Options:${NC}"
    echo "  --validate-snapshots : Test snapshot functionality without performing backup"
    echo
    echo -e "${BOLD}Arguments:${NC}"
    echo " source_dir   : Source directory to backup (root filesystem)"
    echo " backup_dir   : Destination directory for backup (must be on BTRFS)"
    echo " snapshot_dir : Directory for storing snapshots (must be on BTRFS)"
    echo
    echo -e "${BOLD}Note:${NC} The source directory must be a valid system root containing"
    echo "      essential system directories and files (etc, usr, bin, etc.)"
    exit 1
}

# Perform system backup
perform_backup() {
    local source_dir="$1"
    local backup_dir="$2"
    local snapshot_dir="$3"
    local temp_exclude_file="$4"
    
    # Create safety snapshot before backup
    local timestamp=""
    if [ -n "$snapshot_dir" ]; then
        log_msg "STEP" "Creating safety snapshots"
        timestamp=$(create_safety_snapshots "$backup_dir" "$snapshot_dir" "system")
        if [ $? -ne 0 ] || [ -z "$timestamp" ]; then
            log_msg "WARNING" "Failed to create safety snapshots, proceeding without protection"
            timestamp=""
        else
            log_msg "INFO" "Using timestamp: $timestamp"
        fi
    fi
    
    # Perform the backup using exclude-from
    log_msg "INFO" "Starting backup process to ${BOLD}$backup_dir${NC}"
    echo -e "${CYAN}Progress:${NC}"
    
    rsync -aAXHv --delete --exclude-from="$temp_exclude_file" --info=progress2 "$source_dir/" "$backup_dir/"
    local backup_status=$?
    
    if [ $backup_status -eq 0 ]; then
        log_msg "SUCCESS" "Backup completed successfully"
        
        # Create post-backup snapshot if pre-backup snapshot was successful
        if [ -n "$snapshot_dir" ] && [ -n "$timestamp" ]; then
            log_msg "INFO" "Creating post-backup snapshot"
            if ! create_post_snapshot "$backup_dir" "$snapshot_dir" "system" "$timestamp"; then
                log_msg "ERROR" "Failed to create post-backup snapshot"
                return 1
            fi
        fi
        
        return 0
    else
        log_msg "ERROR" "Backup failed with exit code $backup_status"
        return $backup_status
    fi
}

# Validate snapshot functionality
validate_snapshot_only() {
    local backup_dir="$1"
    local snapshot_dir="$2"
    
    log_msg "INFO" "Running in snapshot validation mode"
    
    # Create test file and snapshots
    local test_file="${backup_dir}/snapshot_test_$(date +%s).txt"
    echo "Snapshot test file created at $(date)" > "$test_file"
    
    local timestamp=$(create_safety_snapshots "$backup_dir" "$snapshot_dir" "system-test")
    if [ $? -ne 0 ] || [ -z "$timestamp" ]; then
        log_msg "ERROR" "Pre-backup snapshot creation failed"
        rm -f "$test_file"
        return 1
    fi
    
    # Modify test file
    echo "Modified at $(date)" >> "$test_file"
    
    # Create post-backup snapshot
    if ! create_post_snapshot "$backup_dir" "$snapshot_dir" "system-test" "$timestamp"; then
        log_msg "ERROR" "Post-backup snapshot creation failed"
        rm -f "$test_file"
        return 1
    fi
    
    # Cleanup test file only, not snapshots
    rm -f "$test_file"
    
    log_msg "SUCCESS" "Snapshot validation completed successfully"
    return 0
}

# Main script starts here

# Check arguments
VALIDATE_ONLY=0
if [ "$1" = "--validate-snapshots" ]; then
    VALIDATE_ONLY=1
    shift
fi

if [ $# -ne 3 ]; then
    usage
fi

SOURCE_DIR="$1"
BACKUP_DIR="$2"
SNAPSHOT_DIR="$3"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    log_msg "ERROR" "This script must be run as root"
    exit 1
fi

# Print header
print_header "SYSTEM BACKUP UTILITY"

# Verify source directory is a valid system root
log_msg "STEP" "Verifying system root directory"
if ! is_valid_system_root "$SOURCE_DIR"; then
    log_msg "ERROR" "Source directory does not appear to be a valid system root"
    exit 1
fi

# Create temporary exclude file and ensure cleanup
TEMP_EXCLUDE_FILE=$(mktemp)
trap 'rm -f "$TEMP_EXCLUDE_FILE"' EXIT

# Generate exclude list
log_msg "STEP" "Generating exclude list from configuration"
generate_exclude_list "$SOURCE_DIR" "$TEMP_EXCLUDE_FILE"

# Ask for confirmation before proceeding
confirm_execution "$SOURCE_DIR" "$BACKUP_DIR" "$SNAPSHOT_DIR" "$TEMP_EXCLUDE_FILE"

# Verify BTRFS requirements
if ! is_btrfs_filesystem "$BACKUP_DIR" || ! is_btrfs_filesystem "$SNAPSHOT_DIR"; then
    log_msg "ERROR" "Backup and snapshot paths must be on BTRFS filesystems"
    exit 1
fi

# Check available disk space
if ! check_disk_space "$SOURCE_DIR" "$BACKUP_DIR"; then
    exit 1
fi

# Run in validation mode or perform backup
if [ $VALIDATE_ONLY -eq 1 ]; then
    if validate_snapshot_only "$BACKUP_DIR" "$SNAPSHOT_DIR"; then
        print_footer "VALIDATION COMPLETED"
        exit 0
    else
        print_footer "VALIDATION FAILED"
        exit 1
    fi
else
    if perform_backup "$SOURCE_DIR" "$BACKUP_DIR" "$SNAPSHOT_DIR" "$TEMP_EXCLUDE_FILE"; then
        print_footer "BACKUP PROCESS COMPLETED"
        exit 0
    else
        print_footer "BACKUP PROCESS FAILED"
        exit 1
    fi
fi
