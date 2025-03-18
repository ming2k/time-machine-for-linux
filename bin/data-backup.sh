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
if ! validate_backup_config "$CONFIG_DIR" "data"; then
    log_msg "ERROR" "Invalid configuration"
    exit 1
fi

# Get script directory for config path
CONFIG_FILE="${CONFIG_DIR}/backup/data-maps.conf"

# Function to display script usage
usage() {
    echo -e "${BOLD}Usage:${NC} $0 <backup_path> <snapshot_path>"
    echo
    echo -e "${BOLD}Arguments:${NC}"
    echo " backup_path   : Backup destination mount point"
    echo " snapshot_path : Base path for creating a timestamped safety snapshot"
    echo
    echo -e "${BOLD}Features:${NC}"
    echo " • If snapshot_path is provided, a timestamped safety snapshot is created"
    echo " • Each snapshot is stored in: <snapshot_path>/date-YYYY-MM-DD_HH-MM-SS"
    echo " • Regular backup will add or update files but never delete existing files"
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo " $0 /mnt/backup_drive                 # Regular backup without snapshot"
    echo " $0 /mnt/backup_drive /mnt/snapshots  # Create timestamped snapshot before backup"
    exit 1
}

# Get backup destination with mount point
get_backup_dest() {
    local dst_path="$1"
    local mount_point="$2"
    
    # If destination starts with / and isn't just /, it's an absolute path
    if [[ "$dst_path" =~ ^/.+ ]]; then
        echo "${mount_point}${dst_path}"
    else
        echo "${mount_point}/${dst_path}"
    fi
}

# Function to perform data backup
data_backup_function() {
    for i in "${!SOURCES[@]}"; do
        src="${SOURCES[$i]}"
        dest_dir=$(get_backup_dest "${DESTINATIONS[$i]}" "$BACKUP_DEST_PATH")
        excludes="${EXCLUDES[$i]}"
        
        convert_patterns_to_rsync_excludes "$excludes" "$TEMP_EXCLUDE_FILE"
        
        log_msg "INFO" "Backing up: $src -> $dest_dir"
        
        # Create destination directory if it doesn't exist
        mkdir -p "$dest_dir"
        
        local rsync_cmd="rsync -aHv --info=progress2"
        [ -s "$TEMP_EXCLUDE_FILE" ] && rsync_cmd+=" --exclude-from='$TEMP_EXCLUDE_FILE'"
        
        # Run rsync in a subshell and capture its PID
        eval "$rsync_cmd '$src/' '$dest_dir/'" &
        RSYNC_PID=$!
        
        # Wait for rsync to finish
        wait $RSYNC_PID
        if [ $? -ne 0 ]; then
            log_msg "ERROR" "Backup of $src failed"
            return 1
        fi
    done
    return 0
}

# Handle Ctrl+C interruption
handle_interrupt() {
    echo -e "\n${YELLOW}Backup interrupted by user${NC}"
    if [ -n "$RSYNC_PID" ]; then
        kill -SIGINT "$RSYNC_PID" 2>/dev/null
        wait "$RSYNC_PID" 2>/dev/null
    fi
    BACKUP_INTERRUPTED=true
    echo -e "\n${YELLOW}Exiting backup process...${NC}"
    exit 1
}

# Set up interrupt handler
trap 'handle_interrupt' SIGINT

# Main script starts here

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_msg "ERROR" "This script must be run as root"
    exit 1
fi

# Check arguments
if [ $# -ne 2 ]; then
    usage
fi

BACKUP_DEST_PATH="$1"
SNAPSHOT_PATH="$2"

# Verify that the snapshot path is a BTRFS subvolume
if ! is_btrfs_subvolume "$SNAPSHOT_PATH"; then
    log_msg "ERROR" "Snapshot path '$SNAPSHOT_PATH' is not a BTRFS subvolume"
    exit 1
fi

# Print header
print_banner "DATA BACKUP UTILITY" "$BLUE"

# Initialize arrays for sources and destinations
declare -a SOURCES=()
declare -a DESTINATIONS=()
declare -a EXCLUDES=()

# Flag to track if backup was interrupted
BACKUP_INTERRUPTED=false

# Parse config file
log_msg "INFO" "Parsing configuration file"
if ! parse_backup_maps "$CONFIG_FILE" SOURCES DESTINATIONS EXCLUDES true; then
    log_msg "ERROR" "Failed to parse backup mapping configuration"
    exit 1
fi

# Display backup details and ask for confirmation
TEMP_EXCLUDE_FILE=$(mktemp)
trap 'rm -f "$TEMP_EXCLUDE_FILE"' EXIT
display_backup_details "data" "" "$BACKUP_DEST_PATH" "$SNAPSHOT_PATH" "$TEMP_EXCLUDE_FILE" \
    SOURCES DESTINATIONS EXCLUDES

# Ask for confirmation before proceeding
if ! confirm_execution "data backup" "n"; then
    log_msg "INFO" "Backup operation cancelled by user"
    exit 1
fi

# Create safety snapshot if path provided
if [ -n "$SNAPSHOT_PATH" ]; then
    log_msg "INFO" "Creating safety snapshots"
    TIMESTAMP=$(create_safety_snapshots "$BACKUP_DEST_PATH" "$SNAPSHOT_PATH")
    if [ $? -ne 0 ] || [ -z "$TIMESTAMP" ]; then
        log_msg "WARNING" "Failed to create safety snapshots, proceeding without protection"
        TIMESTAMP=""
    fi
fi

# Perform all backups in one call
if execute_backup_with_snapshots "$BACKUP_DEST_PATH" "$SNAPSHOT_PATH" data_backup_function; then
    show_backup_results "true" "$SNAPSHOT_PATH" "data" "$TIMESTAMP"
    exit 0
else
    show_backup_results "false" "$SNAPSHOT_PATH" "data" "$TIMESTAMP"
    exit 1
fi
