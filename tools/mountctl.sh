#!/bin/bash

# mountctl.sh - Simple LUKS mount control tool
# Provides direct LUKS open/mount and unmount/close functionality

set -euo pipefail

# Default configuration
DEFAULT_ZSTD_LEVEL=3
DEFAULT_MOUNT_OPTIONS="compress=zstd:$DEFAULT_ZSTD_LEVEL,noatime"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_msg() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $timestamp - $message" >&2
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $timestamp - $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $timestamp - $message"
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $timestamp - $message"
            ;;
    esac
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_msg "ERROR" "This tool requires root privileges. Please run with sudo."
        exit 1
    fi
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for required commands
    for cmd in btrfs cryptsetup findmnt; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_msg "ERROR" "Missing dependencies: ${missing_deps[*]}"
        log_msg "INFO" "Please install the required packages and try again"
        exit 1
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 -b <device> -p <mountpoint> [options]
       $0 -u <mountpoint>

Description:
  Simple LUKS mount control tool for encrypted BTRFS filesystems
  
Operations:
  -b <device>                    Block device (LUKS encrypted)
  -p <mountpoint>                Mount point path
  -u <mountpoint>                Unmount and close LUKS

Options:
  --level <1-22>                 Zstd compression level (default: $DEFAULT_ZSTD_LEVEL)
  --luks-name <name>             LUKS mapping name (default: auto-generated)

Examples:
  $0 -b /dev/sdb1 -p /mnt/backup
  $0 -b /dev/sdb1 -p /mnt/backup --level 5 --luks-name my-backup
  $0 -u /mnt/backup

EOF
}

# Function to check if device is LUKS encrypted
is_luks_device() {
    local device="$1"
    cryptsetup isLuks "$device" 2>/dev/null
}

# Function to generate LUKS mapping name
generate_luks_name() {
    local device="$1"
    local base_name
    base_name=$(basename "$device")
    echo "luks-${base_name}-$(date +%s)"
}

# Function to open LUKS encrypted device
luks_open() {
    local device="$1"
    local luks_name="$2"
    
    if [ ! -b "$device" ]; then
        log_msg "ERROR" "Device $device does not exist or is not a block device"
        return 1
    fi
    
    if ! is_luks_device "$device"; then
        log_msg "ERROR" "$device is not a LUKS encrypted device"
        return 1
    fi
    
    # Check if already opened
    if [ -b "/dev/mapper/$luks_name" ]; then
        log_msg "WARNING" "LUKS device $luks_name is already open"
        return 0
    fi
    
    log_msg "INFO" "Opening LUKS device $device as $luks_name"
    
    if cryptsetup open "$device" "$luks_name"; then
        log_msg "SUCCESS" "LUKS device opened as /dev/mapper/$luks_name"
        return 0
    else
        log_msg "ERROR" "Failed to open LUKS device $device"
        return 1
    fi
}

# Function to close LUKS encrypted device
luks_close() {
    local luks_name="$1"
    
    if [ ! -b "/dev/mapper/$luks_name" ]; then
        log_msg "WARNING" "LUKS device $luks_name is not open"
        return 0
    fi
    
    # Check if device is mounted
    if findmnt "/dev/mapper/$luks_name" >/dev/null 2>&1; then
        log_msg "ERROR" "LUKS device /dev/mapper/$luks_name is currently mounted. Please unmount it first."
        findmnt "/dev/mapper/$luks_name"
        return 1
    fi
    
    log_msg "INFO" "Closing LUKS device $luks_name"
    
    if cryptsetup close "$luks_name"; then
        log_msg "SUCCESS" "LUKS device $luks_name closed successfully"
        return 0
    else
        log_msg "ERROR" "Failed to close LUKS device $luks_name"
        return 1
    fi
}

# Function to mount filesystem with zstd compression
mount_filesystem() {
    local device="$1"
    local mountpoint="$2"
    local zstd_level="$3"
    
    if [ ! -b "$device" ]; then
        log_msg "ERROR" "Device $device does not exist or is not a block device"
        return 1
    fi
    
    if [ ! -d "$mountpoint" ]; then
        log_msg "INFO" "Creating mountpoint $mountpoint"
        mkdir -p "$mountpoint"
    fi
    
    # Check if already mounted
    if findmnt "$mountpoint" >/dev/null 2>&1; then
        log_msg "WARNING" "Something is already mounted at $mountpoint"
        findmnt "$mountpoint"
        return 1
    fi
    
    # Build mount options
    local mount_options="compress=zstd:$zstd_level,noatime"
    
    log_msg "INFO" "Mounting $device at $mountpoint with options: $mount_options"
    
    if mount -t btrfs -o "$mount_options" "$device" "$mountpoint"; then
        log_msg "SUCCESS" "Filesystem mounted successfully"
        log_msg "INFO" "Mount details:"
        findmnt "$mountpoint"
    else
        log_msg "ERROR" "Failed to mount filesystem"
        return 1
    fi
}

# Function to unmount filesystem
unmount_filesystem() {
    local mountpoint="$1"
    
    if ! findmnt "$mountpoint" >/dev/null 2>&1; then
        log_msg "WARNING" "Nothing mounted at $mountpoint"
        return 0
    fi
    
    log_msg "INFO" "Unmounting $mountpoint"
    
    if umount "$mountpoint"; then
        log_msg "SUCCESS" "Filesystem unmounted successfully"
    else
        log_msg "ERROR" "Failed to unmount filesystem. Checking for active processes..."
        lsof +f -- "$mountpoint" 2>/dev/null || true
        return 1
    fi
}

# Function to handle LUKS + mount workflow
luks_mount() {
    local device="$1"
    local mountpoint="$2"
    local zstd_level="$3"
    local luks_name="$4"
    
    if [ ! -b "$device" ]; then
        log_msg "ERROR" "Device $device does not exist or is not a block device"
        return 1
    fi
    
    # Generate LUKS name if not provided
    if [ -z "$luks_name" ]; then
        luks_name=$(generate_luks_name "$device")
    fi
    
    # Check if device is LUKS encrypted
    if ! is_luks_device "$device"; then
        log_msg "ERROR" "$device is not a LUKS encrypted device"
        return 1
    fi
    
    log_msg "INFO" "Starting LUKS + mount workflow"
    log_msg "INFO" "Device: $device -> LUKS: $luks_name -> Mount: $mountpoint"
    
    # Step 1: Open LUKS device
    if ! luks_open "$device" "$luks_name"; then
        return 1
    fi
    
    # Step 2: Mount the opened LUKS device
    local mapper_device="/dev/mapper/$luks_name"
    if mount_filesystem "$mapper_device" "$mountpoint" "$zstd_level"; then
        log_msg "SUCCESS" "LUKS + mount completed successfully"
        log_msg "INFO" "To unmount and close: $0 -u $mountpoint"
        return 0
    else
        log_msg "ERROR" "Mount failed, closing LUKS device"
        luks_close "$luks_name"
        return 1
    fi
}

# Function to handle unmount + LUKS close workflow  
luks_unmount() {
    local mountpoint="$1"
    
    if ! findmnt "$mountpoint" >/dev/null 2>&1; then
        log_msg "WARNING" "Nothing mounted at $mountpoint"
        return 0
    fi
    
    # Get the device that's mounted
    local mounted_device
    mounted_device=$(findmnt -n -o SOURCE "$mountpoint")
    
    log_msg "INFO" "Starting unmount + LUKS close workflow"
    log_msg "INFO" "Mountpoint: $mountpoint -> Device: $mounted_device"
    
    # Step 1: Unmount
    if ! unmount_filesystem "$mountpoint"; then
        return 1
    fi
    
    # Step 2: Check if it's a LUKS mapper device and close it
    if [[ "$mounted_device" =~ ^/dev/mapper/ ]]; then
        local luks_name
        luks_name=$(basename "$mounted_device")
        
        log_msg "INFO" "Detected LUKS mapper device: $luks_name"
        if luks_close "$luks_name"; then
            log_msg "SUCCESS" "Unmount + LUKS close completed successfully"
        else
            log_msg "WARNING" "Unmount succeeded but LUKS close failed"
            return 1
        fi
    else
        log_msg "INFO" "Not a LUKS mapper device, unmount only"
    fi
    
    return 0
}

# Main function
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    # Check for help first before requiring root
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]] || [[ "$1" == "help" ]]; then
        show_usage
        exit 0
    fi
    
    check_root
    check_dependencies
    
    # Parse options
    local zstd_level="$DEFAULT_ZSTD_LEVEL"
    local luks_name=""
    local block_device=""
    local mount_point=""
    local operation=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b)
                if [ $# -lt 2 ]; then
                    log_msg "ERROR" "-b option requires device argument"
                    show_usage
                    exit 1
                fi
                block_device="$2"
                operation="mount"
                shift 2
                ;;
            -p)
                if [ $# -lt 2 ]; then
                    log_msg "ERROR" "-p option requires mountpoint argument"
                    show_usage
                    exit 1
                fi
                mount_point="$2"
                shift 2
                ;;
            -u)
                if [ $# -lt 2 ]; then
                    log_msg "ERROR" "-u option requires mountpoint argument"
                    show_usage
                    exit 1
                fi
                mount_point="$2"
                operation="unmount"
                shift 2
                ;;
            --level)
                if [ $# -lt 2 ]; then
                    log_msg "ERROR" "--level option requires value"
                    show_usage
                    exit 1
                fi
                zstd_level="$2"
                shift 2
                ;;
            --luks-name)
                if [ $# -lt 2 ]; then
                    log_msg "ERROR" "--luks-name option requires value"
                    show_usage
                    exit 1
                fi
                luks_name="$2"
                shift 2
                ;;
            -h|--help|help)
                show_usage
                exit 0
                ;;
            *)
                log_msg "ERROR" "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Validate zstd level
    if ! [[ "$zstd_level" =~ ^[1-9]$|^1[0-9]$|^2[0-2]$ ]]; then
        log_msg "ERROR" "Invalid zstd compression level: $zstd_level (must be 1-22)"
        exit 1
    fi
    
    # Validate operation
    case "$operation" in
        "mount")
            if [ -z "$block_device" ] || [ -z "$mount_point" ]; then
                log_msg "ERROR" "Mount operation requires both -b <device> and -p <mountpoint>"
                show_usage
                exit 1
            fi
            luks_mount "$block_device" "$mount_point" "$zstd_level" "$luks_name"
            ;;
        "unmount")
            if [ -z "$mount_point" ]; then
                log_msg "ERROR" "Unmount operation requires -u <mountpoint>"
                show_usage
                exit 1
            fi
            luks_unmount "$mount_point"
            ;;
        *)
            log_msg "ERROR" "No valid operation specified. Use -b/-p for mount or -u for unmount"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"