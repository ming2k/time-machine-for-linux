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
    local config_dir="$CONFIG_DIR"
    local exclude_config="${config_dir}/backup/system-exclude.conf"
    
    # Check if exclude config exists
    if [ ! -f "$exclude_config" ]; then
        log_msg "ERROR" "Exclude list file not found: $exclude_config"
        exit 1
    fi
    
    # Remove trailing slash from source path if present
    source_path="${source_path%/}"
    
    # Create temporary exclude file with prefixed paths
    while IFS= read -r line; do
        # Preserve comments and empty lines
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            echo "$line" >> "$TEMP_EXCLUDE_FILE"
            continue
        fi
        
        # Remove leading slash if present
        line="${line#/}"
        # Add source path prefix
        echo "${source_path}/${line}" >> "$TEMP_EXCLUDE_FILE"
    done < "$exclude_config"
}

# Display backup operation details and ask for confirmation
confirm_execution() {
    local source=$1
    local dest=$2
    local snapshot=$3
    
    echo -e "\n${BOLD}${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${YELLOW} SYSTEM BACKUP CONFIRMATION${NC}"
    echo -e "${BOLD}${YELLOW}═══════════════════════════════════════════════════${NC}\n"
    
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
    done < "$TEMP_EXCLUDE_FILE"
    
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
    echo -e "${BOLD}Usage:${NC} $0 <source_dir> <backup_dir> <snapshot_dir>"
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

# Check arguments
if [ $# -ne 3 ]; then
    log_msg "ERROR" "Usage: $0 <source_path> <backup_path> <snapshot_path>"
    log_msg "INFO" "Both backup_path and snapshot_path must be on BTRFS filesystem"
    exit 1
fi

SOURCE_DIR="$1"
BACKUP_DIR="$2"
SNAPSHOT_DIR="$3"

# Verify BTRFS requirements
if ! is_btrfs_filesystem "$BACKUP_DIR"; then
    log_msg "ERROR" "Backup destination must be on a BTRFS filesystem"
    exit 1
fi

if ! is_btrfs_filesystem "$SNAPSHOT_DIR"; then
    log_msg "ERROR" "Snapshot path must be on a BTRFS filesystem"
    exit 1
fi

DATE=$(date +%Y-%m-%d_%H-%M-%S)

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_msg "ERROR" "Please run as root"
    exit 1
fi

# Verify BTRFS tools are available
if ! command -v btrfs >/dev/null 2>&1; then
    log_msg "ERROR" "BTRFS tools not found. Please install btrfs-progs"
    exit 1
fi

# Print header
echo -e "\n${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE} SYSTEM BACKUP UTILITY${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}\n"

# Verify source directory is a valid system root
log_msg "STEP" "Verifying system root directory"
if ! is_valid_system_root "$SOURCE_DIR"; then
    log_msg "ERROR" "Source directory does not appear to be a valid system root"
    log_msg "ERROR" "Please ensure you're pointing to the correct system root directory"
    exit 1
fi

# Create temporary exclude file and ensure cleanup
TEMP_EXCLUDE_FILE=$(mktemp)
trap 'rm -f "$TEMP_EXCLUDE_FILE"' EXIT
# Generate exclude list log_msg "STEP" "Generating exclude list from configuration"
generate_exclude_list "$SOURCE_DIR"

# Ask for confirmation before proceeding
confirm_execution "$SOURCE_DIR" "$BACKUP_DIR" "$SNAPSHOT_DIR"

log_msg "INFO" "Backup process initiated"
log_msg "INFO" "System root: ${BOLD}$SOURCE_DIR${NC}"
log_msg "INFO" "Backup destination: ${BOLD}$BACKUP_DIR${NC}"

# Check if source and backup directories exist and are accessible
if [ ! -d "$SOURCE_DIR" ]; then
    log_msg "ERROR" "Source directory $SOURCE_DIR does not exist!"
    exit 1
fi

if [ ! -d "$BACKUP_DIR" ]; then
    log_msg "ERROR" "Backup directory $BACKUP_DIR does not exist!"
    exit 1
fi

if [ ! -w "$BACKUP_DIR" ]; then
    log_msg "ERROR" "Backup directory $BACKUP_DIR is not writable!"
    exit 1
fi

# Verify backup directory is on BTRFS if snapshots are requested
if [ -n "$SNAPSHOT_DIR" ]; then
    if ! is_btrfs_filesystem "$BACKUP_DIR"; then
        log_msg "ERROR" "Backup directory must be on a BTRFS filesystem for snapshots!"
        exit 1
    fi
    
    if ! is_btrfs_subvolume "$BACKUP_DIR"; then
        log_msg "ERROR" "Backup directory must be a BTRFS subvolume for snapshots!"
        exit 1
    fi
    
    # Check snapshot directory
    if ! check_directory "$SNAPSHOT_DIR"; then
        log_msg "ERROR" "Invalid snapshot directory: $SNAPSHOT_DIR"
        exit 1
    fi
fi

# Check available disk space
REQUIRED_SPACE=$(df -k "$SOURCE_DIR" | awk 'NR==2 {print $3}')
AVAILABLE_SPACE=$(df -k "$BACKUP_DIR" | awk 'NR==2 {print $4}')

log_msg "STEP" "Checking disk space"
echo -e "Required space : ${BOLD}$(numfmt --to=iec-i --suffix=B $((REQUIRED_SPACE * 1024)))${NC}"
echo -e "Available space: ${BOLD}$(numfmt --to=iec-i --suffix=B $((AVAILABLE_SPACE * 1024)))${NC}"

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    log_msg "ERROR" "Not enough space in backup directory!"
    exit 1
fi

# Before starting backup
if [ -n "$SNAPSHOT_DIR" ]; then
    log_msg "STEP" "Creating safety snapshots"
    TIMESTAMP=$(create_safety_snapshots "$BACKUP_DIR" "$SNAPSHOT_DIR" "system")
    if [ $? -ne 0 ]; then
        log_msg "WARNING" "Failed to create safety snapshots, proceeding without protection"
        TIMESTAMP=""
    fi
fi

# Perform the backup using exclude-from
log_msg "STEP" "Starting backup process to ${BOLD}$BACKUP_DIR${NC}"
echo -e "${CYAN}Progress:${NC}"

rsync -aAXHv --delete --exclude-from="$TEMP_EXCLUDE_FILE" --info=progress2 "$SOURCE_DIR/" "$BACKUP_DIR/"

BACKUP_EXIT_CODE=$?

# Create snapshot of the backup if successful
if [ $BACKUP_EXIT_CODE -eq 0 ]; then
    log_msg "SUCCESS" "Backup completed successfully"
    
    if [ -n "$SNAPSHOT_DIR" ]; then
        SNAPSHOT_PATH="${SNAPSHOT_DIR}backup_${DATE}"
        log_msg "STEP" "Creating backup snapshot at ${BOLD}$SNAPSHOT_PATH${NC}"
        
        if btrfs subvolume snapshot -r "$BACKUP_DIR" "$SNAPSHOT_PATH"; then
            log_msg "SUCCESS" "Backup snapshot created successfully"
        else
            log_msg "ERROR" "Failed to create backup snapshot"
        fi
    fi
else
    log_msg "ERROR" "Backup failed with exit code $BACKUP_EXIT_CODE"
fi

# After successful backup
if [ $BACKUP_EXIT_CODE -eq 0 ] && [ -n "$TIMESTAMP" ]; then
    create_post_snapshot "$BACKUP_DIR" "$SNAPSHOT_DIR" "system" "$TIMESTAMP"
    
    # Cleanup old snapshots (keep last 5)
    cleanup_old_snapshots "$SNAPSHOT_DIR" "system" 5
fi

# Print footer
echo -e "\n${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN} BACKUP PROCESS COMPLETED${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}\n"

exit $BACKUP_EXIT_CODE
