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
    
    eval "$rsync_cmd '$SOURCE_DIR/' '$BACKUP_DIR/'"
    return $?
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
