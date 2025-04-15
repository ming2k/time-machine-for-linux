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

# Function to validate configuration files
validate_config_files() {
    local config_type="$1"
    local errors=0
    
    log_msg "INFO" "Validating $config_type configuration files..."
    
    case "$config_type" in
        "system")
            # Validate system backup configuration
            if [ ! -f "$CONFIG_DIR/backup/system-exclude.conf" ]; then
                log_msg "ERROR" "Missing system-exclude.conf"
                errors=$((errors + 1))
            fi
            ;;
        "data")
            # Validate data backup configuration
            if [ ! -f "$CONFIG_DIR/backup/data-maps.conf" ]; then
                log_msg "ERROR" "Missing data-maps.conf"
                errors=$((errors + 1))
            fi
            ;;
        "restore")
            # Validate restore configuration
            if [ ! -f "$CONFIG_DIR/restore/exclude.conf" ]; then
                log_msg "ERROR" "Missing restore/exclude.conf"
                errors=$((errors + 1))
            fi
            if [ ! -f "$CONFIG_DIR/restore/system-files.conf" ]; then
                log_msg "ERROR" "Missing restore/system-files.conf"
                errors=$((errors + 1))
            fi
            ;;
        "all")
            validate_config_files "system"
            validate_config_files "data"
            validate_config_files "restore"
            return $?
            ;;
        *)
            log_msg "ERROR" "Invalid configuration type: $config_type"
            return 1
            ;;
    esac
    
    return $errors
}

# Function to check system requirements
check_system_requirements() {
    local errors=0
    
    log_msg "INFO" "Checking system requirements..."
    
    # Check for required commands
    for cmd in rsync btrfs; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_msg "ERROR" "Required command '$cmd' not found"
            errors=$((errors + 1))
        fi
    done
    
    # Check for BTRFS support
    if ! modprobe -n btrfs >/dev/null 2>&1; then
        log_msg "ERROR" "BTRFS module not available"
        errors=$((errors + 1))
    fi
    
    return $errors
}

# Function to validate backup paths
validate_backup_paths() {
    local backup_path="$1"
    local snapshot_path="$2"
    local errors=0
    
    log_msg "INFO" "Validating backup paths..."
    
    # Check if paths exist
    if [ ! -d "$backup_path" ]; then
        log_msg "ERROR" "Backup path does not exist: $backup_path"
        errors=$((errors + 1))
    fi
    
    if [ ! -d "$snapshot_path" ]; then
        log_msg "ERROR" "Snapshot path does not exist: $snapshot_path"
        errors=$((errors + 1))
    fi
    
    # Check if paths are on BTRFS
    if ! is_btrfs_subvolume "$backup_path"; then
        log_msg "ERROR" "Backup path is not on BTRFS: $backup_path"
        errors=$((errors + 1))
    fi
    
    if ! is_btrfs_subvolume "$snapshot_path"; then
        log_msg "ERROR" "Snapshot path is not on BTRFS: $snapshot_path"
        errors=$((errors + 1))
    fi
    
    return $errors
}

# Main script starts here
# ---------------------------

# Print header
print_banner "CONFIGURATION VALIDATOR" "$BLUE"

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${BOLD}Usage:${NC} $0 <config_type> [backup_path] [snapshot_path]"
    echo -e "${BOLD}Config types:${NC} system, data, restore, all"
    exit 1
fi

CONFIG_TYPE="$1"
BACKUP_PATH="$2"
SNAPSHOT_PATH="$3"

# Validate configuration files
if ! validate_config_files "$CONFIG_TYPE"; then
    log_msg "ERROR" "Configuration validation failed"
    exit 1
fi

# Check system requirements
if ! check_system_requirements; then
    log_msg "ERROR" "System requirements check failed"
    exit 1
fi

# If backup paths are provided, validate them
if [ -n "$BACKUP_PATH" ] && [ -n "$SNAPSHOT_PATH" ]; then
    if ! validate_backup_paths "$BACKUP_PATH" "$SNAPSHOT_PATH"; then
        log_msg "ERROR" "Backup paths validation failed"
        exit 1
    fi
fi

log_msg "SUCCESS" "All validations passed successfully"
exit 0 