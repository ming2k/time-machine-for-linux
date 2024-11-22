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

# Progress bar function
progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    printf "\r["
    printf "%${completed}s" | tr ' ' '='
    printf ">"
    printf "%${remaining}s" | tr ' ' ' '
    printf "] %3d%%" $percentage
}

# Log message with timestamp
log_msg() {
    local level=$1
    local msg=$2
    local color=$NC
    local prefix=""
    
    case $level in
        "INFO")    color=$GREEN;    prefix="ℹ️ ";;
        "WARNING") color=$YELLOW;   prefix="⚠️ ";;
        "ERROR")   color=$RED;      prefix="❌ ";;
        "SUCCESS") color=$GREEN;    prefix="✅ ";;
        "STEP")    color=$CYAN;     prefix="🔄 ";;
    esac
    
    echo -e "${color}${prefix}[$(date '+%Y-%m-%d %H:%M:%S')] ${msg}${NC}"
}

# Confirm execution
confirm_execution() {
    local source=$1
    local dest=$2
    local snapshot=$3
    
    echo -e "\n${BOLD}${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${YELLOW}           BACKUP CONFIRMATION${NC}"
    echo -e "${BOLD}${YELLOW}═══════════════════════════════════════════════════${NC}\n"
    
    echo -e "${BOLD}The following backup operation will be performed:${NC}\n"
    echo -e "${CYAN}Source Directory:${NC}      ${BOLD}$source${NC}"
    echo -e "${CYAN}Backup Destination:${NC}    ${BOLD}$dest${NC}"
    
    if [ -n "$snapshot" ]; then
        echo -e "${CYAN}Snapshot Location:${NC}     ${BOLD}$snapshot${NC}"
        echo -e "\n${YELLOW}Note: BTRFS snapshot will be created if filesystem supports it${NC}"
    fi
    
    echo -e "\n${CYAN}Excluded Paths:${NC}"
    echo -e "  • /proc/*"
    echo -e "  • /sys/*"
    echo -e "  • /tmp/*"
    echo -e "  • /run/*"
    echo -e "  • /mnt/*"
    echo -e "  • /media/*"
    echo -e "  • /dev/*"
    echo -e "  • /lost+found"
    echo -e "  • /backup/*"
    echo -e "  • /var/log/*"
    echo -e "  • /var/cache/*"
    echo -e "  • /var/tmp/*"
    echo -e "  • /home/*/.cache/*"
    echo -e "  • /root/.cache/*"
    
    echo -e "\n${BOLD}The following rsync command will be executed:${NC}"
    echo -e "${MAGENTA}rsync -aAXv --delete [exclude-patterns] --info=progress2 \"$source\" \"$dest\"${NC}"
    
    echo -e "\n${YELLOW}⚠️  Warning: This operation will synchronize the destination with the source.${NC}"
    echo -e "${YELLOW}   Files that exist only in the destination will be deleted.${NC}\n"
    
    read -p "Do you want to proceed with the backup? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_msg "INFO" "Backup operation cancelled by user"
        exit 1
    fi
}

# Function to display usage
usage() {
    echo -e "${BOLD}Usage:${NC} $0 <source_dir> <backup_dir> [snapshot_dir]"
    echo -e "${BOLD}Example:${NC} $0 /home/user /mnt/backup [/mnt/btrfs/@snapshots]"
    echo
    echo -e "${BOLD}Arguments:${NC}"
    echo "  source_dir   : Source directory to backup"
    echo "  backup_dir   : Destination directory for backups"
    echo "  snapshot_dir : (Optional) BTRFS snapshot location"
    exit 1
}

# Check if we have the minimum required arguments
if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    usage
fi

# Configuration from arguments
SOURCE_DIR="$1"
BACKUP_DIR="$2"
SNAPSHOT_DIR="$3"
LOG_FILE="/var/log/backup.log"
DATE=$(date +%Y-%m-%d_%H-%M-%S)

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_msg "ERROR" "Please run as root"
    exit 1
fi

# Print header
echo -e "\n${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${BLUE}           SYSTEM BACKUP UTILITY${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}\n"

# Ask for confirmation before proceeding
confirm_execution "$SOURCE_DIR" "$BACKUP_DIR" "$SNAPSHOT_DIR"

# Start logging
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

log_msg "INFO" "Backup process initiated"
log_msg "INFO" "Source: ${BOLD}$SOURCE_DIR${NC}"
log_msg "INFO" "Backup destination: ${BOLD}$BACKUP_DIR${NC}"

# Initialize snapshot variables
USE_SNAPSHOT=0
BACKUP_SOURCE="$SOURCE_DIR"

# Handle snapshot if directory is provided
if [ -n "$SNAPSHOT_DIR" ]; then
    log_msg "INFO" "Snapshot location: ${BOLD}$SNAPSHOT_DIR${NC}"
    SNAPSHOT_PATH="${SNAPSHOT_DIR}/system_backup_${DATE}"
    
    # Create snapshot directory if it doesn't exist
    if [ ! -d "$SNAPSHOT_DIR" ]; then
        log_msg "STEP" "Creating snapshot directory"
        mkdir -p "$SNAPSHOT_DIR"
    fi

    # Check if the source is on a BTRFS filesystem
    if btrfs filesystem show "$SOURCE_DIR" >/dev/null 2>&1; then
        USE_SNAPSHOT=1
        log_msg "STEP" "Creating BTRFS snapshot at ${BOLD}$SNAPSHOT_PATH${NC}"
        if btrfs subvolume snapshot -r "$SOURCE_DIR" "$SNAPSHOT_PATH"; then
            BACKUP_SOURCE="$SNAPSHOT_PATH"
            log_msg "SUCCESS" "Snapshot created successfully"
        else
            log_msg "WARNING" "Failed to create BTRFS snapshot, falling back to direct backup"
            USE_SNAPSHOT=0
        fi
    else
        log_msg "WARNING" "Source directory is not on a BTRFS filesystem. Skipping snapshot creation."
    fi
fi

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    log_msg "ERROR" "Source directory $SOURCE_DIR does not exist!"
    exit 1
fi

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    log_msg "ERROR" "Backup directory $BACKUP_DIR does not exist!"
    exit 1
fi

# Check if backup directory is writable
if [ ! -w "$BACKUP_DIR" ]; then
    log_msg "ERROR" "Backup directory $BACKUP_DIR is not writable!"
    exit 1
fi

# Check available disk space
REQUIRED_SPACE=$(df -k "$SOURCE_DIR" | awk 'NR==2 {print $3}')
AVAILABLE_SPACE=$(df -k "$BACKUP_DIR" | awk 'NR==2 {print $4}')

log_msg "STEP" "Checking disk space"
echo -e "Required space : ${BOLD}$(numfmt --to=iec-i --suffix=B $((REQUIRED_SPACE * 1024)))${NC}"
echo -e "Available space: ${BOLD}$(numfmt --to=iec-i --suffix=B $((AVAILABLE_SPACE * 1024)))${NC}"

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    log_msg "ERROR" "Not enough space in backup directory!"
    [ $USE_SNAPSHOT -eq 1 ] && btrfs subvolume delete "$SNAPSHOT_PATH"
    exit 1
fi

# Perform the backup
log_msg "STEP" "Starting backup process to ${BOLD}$BACKUP_DIR${NC}"
echo -e "${CYAN}Progress:${NC}"

rsync -aAXv --delete \
    --exclude='/proc/*' \
    --exclude='/sys/*' \
    --exclude='/tmp/*' \
    --exclude='/run/*' \
    --exclude='/mnt/*' \
    --exclude='/media/*' \
    --exclude='/dev/*' \
    --exclude='/lost+found' \
    --exclude='/backup/*' \
    --exclude='/var/log/*' \
    --exclude='/var/cache/*' \
    --exclude='/var/tmp/*' \
    --exclude='/home/*/.cache/*' \
    --exclude='/root/.cache/*' \
    --info=progress2 \
    "$BACKUP_SOURCE/" \
    "$BACKUP_DIR"

BACKUP_EXIT_CODE=$?

# Check if backup was successful
if [ $BACKUP_EXIT_CODE -eq 0 ]; then
    log_msg "SUCCESS" "Backup completed successfully"
    
    # Clean up old snapshots (keep last 5) if using snapshots
    if [ $USE_SNAPSHOT -eq 1 ]; then
        log_msg "STEP" "Cleaning up old snapshots"
        ls -dt "${SNAPSHOT_DIR}"/system_backup_* | tail -n +6 | xargs -r btrfs subvolume delete
    fi
else
    log_msg "ERROR" "Backup failed with exit code $BACKUP_EXIT_CODE"
fi

# Clean up current snapshot if it exists
if [ $USE_SNAPSHOT -eq 1 ]; then
    log_msg "STEP" "Cleaning up BTRFS snapshot"
    btrfs subvolume delete "$SNAPSHOT_PATH"
fi

# Calculate and display backup size
BACKUP_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
log_msg "INFO" "Final backup size: ${BOLD}${BACKUP_SIZE}${NC}"

# Print footer
echo -e "\n${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}           BACKUP PROCESS COMPLETED${NC}"
echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}\n"

exit $BACKUP_EXIT_CODE