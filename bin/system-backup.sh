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

# Validate configs
if ! validate_backup_config "$CONFIG_DIR" "system"; then
    log_msg "ERROR" "Invalid configuration"
    exit 1
fi

# Check for required commands
check_required_commands() {
    local required_commands=("rsync" "btrfs")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_msg "ERROR" "Missing required commands: ${missing_commands[*]}"
        return 1
    fi
    return 0
}

# Check available disk space
check_disk_space() {
    local source_dir="$1"
    local dest_dir="$2"
    local required_space
    
    # Get source directory size
    required_space=$(du -sb "$source_dir" | cut -f1)
    
    # Get available space in destination
    local available_space=$(df -B1 "$dest_dir" | awk 'NR==2 {print $4}')
    
    # Add 10% buffer
    required_space=$((required_space * 11 / 10))
    
    if [ "$required_space" -gt "$available_space" ]; then
        log_msg "ERROR" "Insufficient disk space in destination"
        log_msg "ERROR" "Required: $(numfmt --to=iec-i --suffix=B "$required_space")"
        log_msg "ERROR" "Available: $(numfmt --to=iec-i --suffix=B "$available_space")"
        return 1
    fi
    
    return 0
}

# Display usage information
usage() {
    echo -e "${BOLD}Usage:${NC} $0 [--validate-snapshots] <source_dir> <backup_dir> <snapshot_dir>"
    echo -e "${BOLD}Example:${NC} $0 /mnt /mnt/@backup /mnt/@backup_snapshots"
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

# Function to perform system backup
system_backup_function() {
    local rsync_cmd="rsync -aAXHv --info=progress2"
    [ "$delete_flag" = "true" ] && rsync_cmd+=" --delete"
    [ -s "$TEMP_EXCLUDE_FILE" ] && rsync_cmd+=" --exclude-from='$TEMP_EXCLUDE_FILE'"
    
    # Execute rsync with progress visible and error capture
    local rsync_status
    eval "$rsync_cmd '$SOURCE_DIR/' '$BACKUP_DIR/'" 2> >(tee -a >(grep -v '^[[:space:]]*$' >&2) > /dev/null) | tee /dev/tty
    rsync_status=${PIPESTATUS[0]}
    
    # Handle specific rsync error codes
    case $rsync_status in
        0)  # Success
            log_msg "SUCCESS" "rsync completed successfully"
            ;;
        23) # Partial transfer due to error
            log_msg "WARNING" "rsync completed with partial transfer"
            log_msg "WARNING" "Some files could not be transferred"
            # Continue with backup as partial transfer might be acceptable
            ;;
        24) # Partial transfer due to vanished source files
            log_msg "WARNING" "rsync completed with partial transfer"
            log_msg "WARNING" "Some source files vanished during transfer"
            # Continue with backup as this is often acceptable
            ;;
        *)  # Other errors
            log_msg "ERROR" "rsync operation failed with status $rsync_status"
            return 1
            ;;
    esac
    
    # Verify backup integrity
    if ! verify_backup_integrity "$SOURCE_DIR" "$BACKUP_DIR"; then
        log_msg "ERROR" "Backup integrity verification failed"
        return 1
    fi
    
    return 0
}

# Verify backup integrity
verify_backup_integrity() {
    local source="$1"
    local dest="$2"
    
    # Check if essential directories exist
    local essential_dirs=("bin" "etc" "usr" "var")
    for dir in "${essential_dirs[@]}"; do
        if [ ! -d "$dest/$dir" ]; then
            log_msg "ERROR" "Essential directory '$dir' missing in backup"
            return 1
        fi
    done
    
    return 0
}

# Main script starts here
# ---------------------------

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
print_banner "SYSTEM BACKUP UTILITY" "$BLUE"

# Check required commands
if ! check_required_commands; then
    exit 1
fi

# Verify source directory is a valid system root
log_msg "INFO" "Verifying system root directory"
if ! is_valid_system_root "$SOURCE_DIR"; then
    log_msg "ERROR" "Source directory does not appear to be a valid system root"
    exit 1
fi

# Create temporary exclude file and ensure cleanup
TEMP_EXCLUDE_FILE=$(mktemp)
trap 'rm -f "$TEMP_EXCLUDE_FILE"' EXIT

# Generate exclude list
log_msg "INFO" "Generating exclude list from configuration"
generate_prefixed_exclude_list "$SOURCE_DIR" "$TEMP_EXCLUDE_FILE" "$CONFIG_DIR/backup/system-exclude.conf"

# Display backup details
display_backup_details "system" "$SOURCE_DIR" "$BACKUP_DIR" "$SNAPSHOT_DIR" "$TEMP_EXCLUDE_FILE"

# Ask for confirmation before proceeding
if confirm_execution "system backup" "n"; then
    # Proceed with backup operations
    # Verify BTRFS requirements
    if ! is_btrfs_filesystem "$BACKUP_DIR" || ! is_btrfs_filesystem "$SNAPSHOT_DIR"; then
        log_msg "ERROR" "Backup and snapshot paths must be on BTRFS filesystems"
        exit 1
    fi

    # Check available disk space
    # Rsync is incremental, so we don't need to check disk space
    # if ! check_disk_space "$SOURCE_DIR" "$BACKUP_DIR"; then
    #     exit 1
    # fi
else
    log_msg "INFO" "Backup operation cancelled by user"
    exit 1
fi

# Main script execution
if execute_backup_with_snapshots "$BACKUP_DIR" "$SNAPSHOT_DIR" system_backup_function; then
    show_backup_results "true" "$SNAPSHOT_DIR" "$TIMESTAMP"
    exit 0
else
    show_backup_results "false" "$SNAPSHOT_DIR" "$TIMESTAMP"
    exit 1
fi
