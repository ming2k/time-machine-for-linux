#!/bin/bash

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Get the script's directory path
SCRIPT_DIR="$( cd "$(dirname "$(readlink -f "$0")")" && pwd )"

# Default location for exclude file relative to script
EXCLUDE_FILE="${SCRIPT_DIR}/config/backup_exclude.txt"

# BTRFS utility functions
is_btrfs_filesystem() {
    local path="$1"
    if [ -d "$path" ]; then
        local fstype=$(stat -f -c %T "$path")
        [ "$fstype" = "btrfs" ]
        return $?
    fi
    return 1
}

is_btrfs_subvolume() {
    local path="$1"
    btrfs subvolume show "$path" >/dev/null 2>&1
    return $?
}

get_mount_point() {
    local path="$1"
    df --output=target "$path" | tail -n 1
}

is_btrfs_mounted() {
    local path="$1"
    local fstype=$(df --output=fstype "$path" | tail -n 1)
    [ "$fstype" = "btrfs" ]
    return $?
}

# Log message with timestamp
log_msg() {
    local level=$1
    local msg=$2
    local color=$NC
    local prefix=""
    case $level in
        "INFO") color=$GREEN; prefix="ℹ️ ";;
        "WARNING") color=$YELLOW; prefix="⚠️ ";;
        "ERROR") color=$RED; prefix="❌ ";;
        "SUCCESS") color=$GREEN; prefix="✅ ";;
        "STEP") color=$CYAN; prefix="🔄 ";;
    esac
    echo -e "${color}${prefix}[$(date '+%Y-%m-%d %H:%M:%S')] ${msg}${NC}"
}

# Function to check and read exclude file
check_exclude_file() {
    if [ ! -f "$EXCLUDE_FILE" ]; then
        log_msg "ERROR" "Exclude file not found at $EXCLUDE_FILE"
        echo -e "${YELLOW}Please ensure the exclude patterns file exists at:${NC}"
        echo -e "${YELLOW}$EXCLUDE_FILE${NC}"
        exit 1
    fi
    
    # Check if file is readable
    if [ ! -r "$EXCLUDE_FILE" ]; then
        log_msg "ERROR" "Cannot read exclude file: $EXCLUDE_FILE"
        exit 1
    fi
}

# Confirm execution
confirm_execution() {
    local source=$1
    local dest=$2
    local snapshot=$3
    
    echo -e "\n${BOLD}${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${YELLOW} BACKUP CONFIRMATION${NC}"
    echo -e "${BOLD}${YELLOW}═══════════════════════════════════════════════════${NC}\n"
    
    echo -e "${BOLD}The following backup operation will be performed:${NC}\n"
    echo -e "${CYAN}Source Directory:${NC} ${BOLD}$source${NC}"
    echo -e "${CYAN}Backup Directory:${NC} ${BOLD}$dest${NC}"
    if [ -n "$snapshot" ]; then
        echo -e "${CYAN}Backup Snapshots:${NC} ${BOLD}$snapshot${NC}"
    fi
    echo -e "${CYAN}Exclude File:${NC} ${BOLD}$EXCLUDE_FILE${NC}"
    
    if ! is_btrfs_filesystem "$dest"; then
        echo -e "\n${YELLOW}⚠️  Warning: Backup directory is not on a BTRFS filesystem.${NC}"
        echo -e "${YELLOW}   Snapshots will be skipped.${NC}"
    fi
    
    echo -e "\n${CYAN}Excluded Paths:${NC}"
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        if [ -n "$line" ] && [ "${line:0:1}" != "#" ]; then
            echo -e " • $line"
        fi
    done < "$EXCLUDE_FILE"
    
    echo -e "\n${BOLD}The following rsync command will be executed:${NC}"
    echo -e "${MAGENTA}rsync -aAXHv --delete --exclude-from=\"$EXCLUDE_FILE\" --info=progress2 \"$source\" \"$dest\"${NC}"
    
    echo -e "\n${YELLOW}⚠️ Warning: This operation will synchronize the destination with the source.${NC}"
    echo -e "${YELLOW} Files that exist only in the destination will be deleted.${NC}\n"
    
    read -p "Do you want to proceed with the backup? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_msg "INFO" "Backup operation cancelled by user"
        exit 1
    fi
}

# Function to display usage
usage() {
    echo -e "${BOLD}Usage:${NC} $0 <source_dir> <backup_dir> [snapshot_dir] [exclude_file]"
    echo -e "${BOLD}Example:${NC} $0 /mnt/@root /mnt/@backup /mnt/@backup_snapshots [./config/custom-exclude.txt]"
    echo
    echo -e "${BOLD}Arguments:${NC}"
    echo " source_dir   : Source directory to backup"
    echo " backup_dir   : Destination directory for backup"
    echo " snapshot_dir : (Optional) Directory to store backup snapshots"
    echo " exclude_file : (Optional) Path to exclude patterns file (default: ./config/backup_exclude.txt)"
    exit 1
}

# Parse command line arguments
if [ $# -lt 2 ] || [ $# -gt 4 ]; then
    usage
fi

SOURCE_DIR="$1"
BACKUP_DIR="$2"
SNAPSHOT_DIR="$3"
[ -n "$4" ] && EXCLUDE_FILE="$4"

LOG_FILE="/var/log/backup.log"
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

# Check exclude file
check_exclude_file

# Print header
echo -e "\n${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE} SYSTEM BACKUP UTILITY${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}\n"

# Ask for confirmation before proceeding
confirm_execution "$SOURCE_DIR" "$BACKUP_DIR" "$SNAPSHOT_DIR"

# Start logging
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

log_msg "INFO" "Backup process initiated"
log_msg "INFO" "Source: ${BOLD}$SOURCE_DIR${NC}"
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
    
    if [ ! -d "$SNAPSHOT_DIR" ]; then
        log_msg "STEP" "Creating snapshot directory"
        mkdir -p "$SNAPSHOT_DIR"
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

# Perform the backup
log_msg "STEP" "Starting backup process to ${BOLD}$BACKUP_DIR${NC}"
echo -e "${CYAN}Progress:${NC}"

rsync -aAXHv --delete \
    --exclude-from="$EXCLUDE_FILE" \
    --info=progress2 \
    "$SOURCE_DIR/" \
    "$BACKUP_DIR/"

BACKUP_EXIT_CODE=$?

# Create snapshot of the backup if successful
if [ $BACKUP_EXIT_CODE -eq 0 ]; then
    log_msg "SUCCESS" "Backup completed successfully"
    
    if [ -n "$SNAPSHOT_DIR" ]; then
        SNAPSHOT_PATH="${SNAPSHOT_DIR}/backup_${DATE}"
        log_msg "STEP" "Creating backup snapshot at ${BOLD}$SNAPSHOT_PATH${NC}"
        
        if btrfs subvolume snapshot -r "$BACKUP_DIR" "$SNAPSHOT_PATH"; then
            log_msg "SUCCESS" "Backup snapshot created successfully"
            
            # Clean up old snapshots (keep last 5)
            log_msg "STEP" "Cleaning up old snapshots"
            ls -dt "${SNAPSHOT_DIR}"/backup_* | tail -n +6 | xargs -r btrfs subvolume delete
        else
            log_msg "ERROR" "Failed to create backup snapshot"
        fi
    fi
else
    log_msg "ERROR" "Backup failed with exit code $BACKUP_EXIT_CODE"
fi

# Calculate and display backup size
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
log_msg "INFO" "Final backup size: ${BOLD}${BACKUP_SIZE}${NC}"

# Print footer
echo -e "\n${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN} BACKUP PROCESS COMPLETED${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}\n"

exit $BACKUP_EXIT_CODE