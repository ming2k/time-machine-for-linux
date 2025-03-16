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
if ! validate_backup_config "$CONFIG_DIR" "data"; then
    log_msg "ERROR" "Invalid configuration"
    exit 1
fi

# Get script directory for config path
CONFIG_FILE="${CONFIG_DIR}/backup/data-maps.conf"

# Parse and validate config file
parse_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_msg "ERROR" "Config file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Check if config file is empty
    if [ ! -s "$CONFIG_FILE" ]; then
        log_msg "ERROR" "Config file is empty: $CONFIG_FILE"
        exit 1
    fi
    
    log_msg "INFO" "Using config file: $CONFIG_FILE"
    
    # Parse config file and validate entries
    local line_num=0
    local valid_entries=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Split line into source and destination
        IFS='|' read -r src_path dst_path exclude_pattern <<< "$line"
        
        # Trim whitespace
        src_path=$(echo "$src_path" | xargs)
        dst_path=$(echo "$dst_path" | xargs)
        exclude_pattern=$(echo "$exclude_pattern" | xargs)
        
        # Validate source path
        if [ -z "$src_path" ]; then
            log_msg "WARNING" "Line $line_num: Missing source path, skipping"
            continue
        fi
        
        # Validate destination path
        if [ -z "$dst_path" ]; then
            log_msg "WARNING" "Line $line_num: Missing destination path, skipping"
            continue
        fi
        
        # Check if source exists
        if ! check_directory "$src_path"; then
            log_msg "WARNING" "Line $line_num: Invalid source directory, skipping"
            continue
        fi
        
        # Add to valid entries
        SOURCES+=("$src_path")
        DESTINATIONS+=("$dst_path")
        EXCLUDES+=("$exclude_pattern")
        ((valid_entries++))
    done < "$CONFIG_FILE"
    
    if [ $valid_entries -eq 0 ]; then
        log_msg "ERROR" "No valid entries found in config file"
        exit 1
    fi
    
    log_msg "INFO" "Found $valid_entries valid backup entries"
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

# Create a temporary exclude file for rsync
create_exclude_file() {
    local exclude_pattern="$1"
    local temp_file="$2"
    
    # Clear the file
    > "$temp_file"
    
    # If no exclude pattern, return empty file
    if [ -z "$exclude_pattern" ]; then
        return 0
    fi
    
    # Split patterns by comma and write to file
    IFS=',' read -ra patterns <<< "$exclude_pattern"
    for pattern in "${patterns[@]}"; do
        # Trim whitespace
        pattern=$(echo "$pattern" | xargs)
        if [ -n "$pattern" ]; then
            echo "$pattern" >> "$temp_file"
        fi
    done
}

# Display backup operation details and ask for confirmation
confirm_execution() {
    local backup_dest_path="$1"
    
    print_header "DATA BACKUP CONFIRMATION"
    
    echo -e "${BOLD}The following backup operations will be performed:${NC}\n"
    
    echo -e "${CYAN}Backup Destination Path:${NC} ${BOLD}$backup_dest_path${NC}"
    
    if [ -n "$SNAPSHOT_PATH" ]; then
        echo -e "${CYAN}Safety Snapshot Base:${NC} ${BOLD}$SNAPSHOT_PATH${NC}"
    else
        echo -e "${CYAN}Safety Snapshot:${NC} ${BOLD}None${NC}"
    fi
    
    # Display backup operations
    echo -e "\n${CYAN}Backup Operations:${NC}"
    for i in "${!SOURCES[@]}"; do
        local src="${SOURCES[$i]}"
        local dst=$(get_backup_dest "${DESTINATIONS[$i]}" "$backup_dest_path")
        local excludes="${EXCLUDES[$i]}"
        
        echo -e "\n${BOLD}Backup #$((i+1)):${NC}"
        echo -e "  ${CYAN}Source:${NC} ${BOLD}$src${NC}"
        echo -e "  ${CYAN}Destination:${NC} ${BOLD}$dst${NC}"
        
        if [ -n "$excludes" ]; then
            echo -e "  ${CYAN}Exclude Patterns:${NC} ${BOLD}$excludes${NC}"
        fi
    done
    
    echo -e "\n${YELLOW}ℹ️  Note: Files will only be added or updated.${NC}"
    echo -e "${YELLOW}   Existing files in the destination will not be deleted.${NC}\n"
    
    read -p "Do you want to proceed with the backup? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_msg "INFO" "Backup operation cancelled by user"
        exit 1
    fi
}

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

# Perform backup for a single source-destination pair
perform_backup() {
    local src="$1"
    local dst="$2"
    local exclude_file="$3"
    local backup_number="$4"
    local total_backups="$5"
    
    log_msg "STEP" "[$backup_number/$total_backups] Backing up: $src -> $dst"
    
    # Create destination directory if it doesn't exist
    mkdir -p "$dst"
    
    # Perform rsync backup with --update flag
    if [ -s "$exclude_file" ]; then
        log_msg "INFO" "Using exclude patterns from config"
        rsync -aAXhv --update --info=progress2 --exclude-from="$exclude_file" "$src/" "$dst/"
    else
        rsync -aAXhv --update --info=progress2 "$src/" "$dst/"
    fi
    
    local rsync_status=$?
    
    if [ $rsync_status -eq 0 ]; then
        log_msg "SUCCESS" "Backup completed successfully: $src -> $dst"
    else
        log_msg "ERROR" "Failed to backup: $src -> $dst (rsync exit code: $rsync_status)"
    fi
    
    return $rsync_status
}

# Main script starts here

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_msg "WARNING" "Not running as root, some files may not be backed up properly"
fi

# Check arguments
if [ $# -ne 2 ]; then
    usage
fi

BACKUP_DEST_PATH="$1"
SNAPSHOT_PATH="$2"

# Verify BTRFS requirements
if ! is_btrfs_filesystem "$BACKUP_DEST_PATH" || ! is_btrfs_filesystem "$SNAPSHOT_PATH"; then
    log_msg "ERROR" "Backup and snapshot paths must be on BTRFS filesystems"
    exit 1
fi

# Print header
print_header "DATA BACKUP UTILITY"

# Initialize arrays for sources and destinations
declare -a SOURCES=()
declare -a DESTINATIONS=()
declare -a EXCLUDES=()

# Parse config file
log_msg "STEP" "Parsing configuration file"
parse_config

# Ask for confirmation before proceeding
confirm_execution "$BACKUP_DEST_PATH"

# Create temporary exclude file
TEMP_EXCLUDE_FILE=$(mktemp)
trap 'rm -f "$TEMP_EXCLUDE_FILE"' EXIT

# Perform backups
TOTAL_BACKUPS=${#SOURCES[@]}
SUCCESS_COUNT=0
FAILURE_COUNT=0

# Create safety snapshot if path provided
if [ -n "$SNAPSHOT_PATH" ]; then
    log_msg "STEP" "Creating safety snapshots"
    TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
    if ! create_safety_snapshots "$BACKUP_DEST_PATH" "$SNAPSHOT_PATH" "data"; then
        log_msg "WARNING" "Failed to create safety snapshots, proceeding without protection"
        TIMESTAMP=""
    fi
fi

# Process each backup operation
for i in "${!SOURCES[@]}"; do
    src="${SOURCES[$i]}"
    dst=$(get_backup_dest "${DESTINATIONS[$i]}" "$BACKUP_DEST_PATH")
    excludes="${EXCLUDES[$i]}"
    
    create_exclude_file "$excludes" "$TEMP_EXCLUDE_FILE"
    
    if perform_backup "$src" "$dst" "$TEMP_EXCLUDE_FILE" "$((i+1))" "$TOTAL_BACKUPS"; then
        ((SUCCESS_COUNT++))
    else
        ((FAILURE_COUNT++))
    fi
done

# Create final snapshot and show results
if [ $FAILURE_COUNT -eq 0 ]; then
    if [ -n "$TIMESTAMP" ]; then
        if create_post_snapshot "$BACKUP_DEST_PATH" "$SNAPSHOT_PATH" "data" "$TIMESTAMP"; then
            echo -e "\n${YELLOW}Backup completed successfully with snapshots:${NC}"
            echo -e "${YELLOW}Pre-backup snapshot : ${SNAPSHOT_PATH}/data-pre-${TIMESTAMP}${NC}"
            echo -e "${YELLOW}Post-backup snapshot: ${SNAPSHOT_PATH}/data-post-${TIMESTAMP}${NC}"
        fi
    fi
    print_footer "BACKUP PROCESS COMPLETED"
    exit 0
else
    if [ -n "$TIMESTAMP" ]; then
        echo -e "\n${YELLOW}Backup operation had errors.${NC}"
        echo -e "${YELLOW}Pre-backup snapshot is available at: ${SNAPSHOT_PATH}/data-pre-${TIMESTAMP}${NC}"
    fi
    print_footer "BACKUP PROCESS FAILED"
    exit 1
fi
