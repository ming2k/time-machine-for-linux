#!/bin/bash

# Get project paths
SCRIPT_PATH="$(readlink -f "$0")"
PROJECT_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"
CONFIG_DIR="${PROJECT_ROOT}/config"

# Load libraries
source "${LIB_DIR}/loader.sh"
if ! load_backup_libs "$LIB_DIR"; then
    echo "Failed to load required libraries" >&2
    exit 1
fi

# Check for data-backup-keep config file
KEEPLIST_FILE="${CONFIG_DIR}/data-backup-keep"
if [ ! -f "$KEEPLIST_FILE" ]; then
    log_msg "INFO" "No data-backup-keep config found - will backup from current directory"
fi

# Function to display script usage
usage() {
    echo -e "${BOLD}Usage:${NC} $0 <source_dir> <backup_path> <snapshot_path>"
    echo
    echo -e "${BOLD}Arguments:${NC}"
    echo " source_dir    : Source directory to backup"
    echo " backup_path   : Backup destination path"
    echo " snapshot_path : Path for creating safety snapshots"
    echo
    echo -e "${BOLD}Features:${NC}"
    echo " • Uses data-backup-keep config (gitignore syntax) for selective backup"
    echo " • Creates timestamped safety snapshots"
    echo " • Preserves file attributes and permissions"
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo " $0 /home/user /mnt/backup /mnt/snapshots"
    echo " $0 . /mnt/backup /mnt/snapshots"
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

# Function to perform data backup with keep list and incremental support
data_backup_function() {
    for i in "${!SOURCES[@]}"; do
        src="${SOURCES[$i]}"
        dest_dir=$(get_backup_dest "${DESTINATIONS[$i]}" "$BACKUP_DEST_PATH")
        excludes="${EXCLUDES[$i]}"
        keep_list_file="${KEEP_LISTS[$i]:-}"
        backup_mode="${BACKUP_MODES[$i]:-full}"
        
        log_msg "INFO" "Backing up: $src -> $dest_dir (mode: $backup_mode)"
        
        # Create destination directory if it doesn't exist
        mkdir -p "$dest_dir"
        
        local rsync_cmd="rsync -aHv --info=progress2"
        local temp_include_file=""
        
        # Handle backup mode
        if [[ "$backup_mode" == "incremental" ]]; then
            # Get source name for timestamp tracking
            local source_name=$(basename "$src")
            local last_backup_timestamp=$(get_last_backup_timestamp "$BACKUP_DEST_PATH" "$source_name")
            
            if [[ -n "$keep_list_file" && -f "$keep_list_file" ]]; then
                # Incremental backup with keep list
                log_msg "INFO" "Using keep list config: $keep_list_file"
                temp_include_file=$(mktemp)
                
                if generate_incremental_includes "$src" "$temp_include_file" "$last_backup_timestamp" "$keep_list_file"; then
                    rsync_cmd+=" --include-from='$temp_include_file'"
                    log_msg "INFO" "Generated incremental include list"
                else
                    log_msg "WARN" "Failed to generate incremental includes, falling back to full backup"
                    rm -f "$temp_include_file"
                    temp_include_file=""
                fi
            else
                # Incremental backup without keep list (all changed files)
                temp_include_file=$(mktemp)
                
                if generate_full_incremental "$src" "$temp_include_file" "$last_backup_timestamp"; then
                    rsync_cmd+=" --include-from='$temp_include_file'"
                    log_msg "INFO" "Generated incremental backup list"
                else
                    log_msg "WARN" "Failed to generate incremental backup, falling back to full backup"
                    rm -f "$temp_include_file"
                    temp_include_file=""
                fi
            fi
        elif [[ -n "$keep_list_file" && -f "$keep_list_file" ]]; then
            # Full backup with keep list
            log_msg "INFO" "Using keep list config: $keep_list_file"
            temp_include_file=$(mktemp)
            
            if parse_keep_list "$keep_list_file" "$temp_include_file" "$src"; then
                rsync_cmd+=" --include-from='$temp_include_file'"
                log_msg "INFO" "Applied keep list filter"
            else
                log_msg "WARN" "Failed to parse keep list, backing up everything"
                rm -f "$temp_include_file"
                temp_include_file=""
            fi
        fi
        
        # Add exclude processing for traditional excludes and .backupignore files
        if [[ -z "$temp_include_file" ]]; then
            # Only use excludes if not using include filters
            process_backup_excludes "$src" "$excludes" "$TEMP_EXCLUDE_FILE"
            [ -s "$TEMP_EXCLUDE_FILE" ] && rsync_cmd+=" --exclude-from='$TEMP_EXCLUDE_FILE'"
        fi
        
        # Run rsync in a subshell and capture its PID
        eval "$rsync_cmd '$src/' '$dest_dir/'" &
        RSYNC_PID=$!
        
        # Wait for rsync to finish
        wait $RSYNC_PID
        local rsync_exit_code=$?
        
        # Clean up temporary include file
        [[ -n "$temp_include_file" ]] && rm -f "$temp_include_file"
        
        if [ $rsync_exit_code -ne 0 ]; then
            log_msg "ERROR" "Backup of $src failed"
            return 1
        fi
        
        # Update timestamp for incremental backups
        if [[ "$backup_mode" == "incremental" ]]; then
            local source_name=$(basename "$src")
            update_backup_timestamp "$BACKUP_DEST_PATH" "$source_name"
        fi
        
        log_msg "INFO" "Successfully backed up: $src"
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
if [ $# -ne 3 ]; then
    usage
fi

SOURCE_DIR="$1"
BACKUP_DEST_PATH="$2"
SNAPSHOT_PATH="$3"

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
declare -a KEEP_LISTS=()
declare -a BACKUP_MODES=()

# Flag to track if backup was interrupted
BACKUP_INTERRUPTED=false

# Simple backup function using keep list
simple_backup_function() {
    local rsync_cmd="rsync -aAXHv --info=progress2"
    
    # Apply keep list if it exists
    if [ -f "$KEEPLIST_FILE" ]; then
        log_msg "INFO" "Using keep list config: $KEEPLIST_FILE"
        local temp_include_file=$(mktemp)
        trap 'rm -f "$temp_include_file"' EXIT
        
        if parse_keep_list "$KEEPLIST_FILE" "$temp_include_file" "$SOURCE_DIR"; then
            rsync_cmd+=" --include-from='$temp_include_file'"
            log_msg "INFO" "Applied keep list filter"
        else
            log_msg "WARNING" "Failed to parse keep list, backing up everything"
            rm -f "$temp_include_file"
        fi
    else
        log_msg "INFO" "No keep list found, backing up everything"
    fi
    
    # Execute rsync
    log_msg "INFO" "Starting backup: $SOURCE_DIR -> $BACKUP_DEST_PATH"
    eval "$rsync_cmd '$SOURCE_DIR/' '$BACKUP_DEST_PATH/'"
    local rsync_status=$?
    
    if [ $rsync_status -eq 0 ]; then
        log_msg "SUCCESS" "Backup completed successfully"
        return 0
    else
        log_msg "ERROR" "Backup failed with status $rsync_status"
        return 1
    fi
}

# Display backup details
log_msg "INFO" "Source: $SOURCE_DIR"
log_msg "INFO" "Destination: $BACKUP_DEST_PATH"
log_msg "INFO" "Snapshots: $SNAPSHOT_PATH"
if [ -f "$KEEPLIST_FILE" ]; then
    log_msg "INFO" "Keep list config: $KEEPLIST_FILE"
else
    log_msg "INFO" "Keep list config: none (backup everything)"
fi

# Ask for confirmation before proceeding
if ! confirm_execution "data backup" "n"; then
    log_msg "INFO" "Backup operation cancelled by user"
    exit 1
fi

# Perform backup with snapshots
if execute_backup_with_snapshots "$BACKUP_DEST_PATH" "$SNAPSHOT_PATH" simple_backup_function; then
    show_backup_results "true" "$SNAPSHOT_PATH" "$TIMESTAMP"
    exit 0
else
    show_backup_results "false" "$SNAPSHOT_PATH" "$TIMESTAMP"
    exit 1
fi
