#!/bin/bash

# Get project paths
SCRIPT_PATH="$(readlink -f "$0")"
PROJECT_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"
CONFIG_DIR="${PROJECT_ROOT}/config"

# Update config file paths - move these near the top with other configs
EXCLUDE_CONFIG="${CONFIG_DIR}/restore/exclude.conf"
SYSFILES_CONFIG="${CONFIG_DIR}/restore/system-files.conf"

# Load libraries
source "${LIB_DIR}/lib-loader.sh"
if ! load_restore_libs "$LIB_DIR"; then
    echo "Failed to load required libraries" >&2
    exit 1
fi

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Check if user exists in the system
is_valid_user() {
    local username="$1"
    if id "$username" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Generate exclude list from config file
generate_exclude_list() {
    local backup_dir="$1"
    local username="$2"
    local exclude_config="$CONFIG_DIR/user-restore-exclude-list.txt"
    
    # Check if exclude config exists
    if [ ! -f "$exclude_config" ]; then
        log_msg "ERROR" "Exclude list file not found: $exclude_config"
        exit 1
    fi
    
    # Create temporary exclude file with prefixed paths
    while IFS= read -r line; do
        # Preserve comments and empty lines
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            echo "$line" >> "$TEMP_EXCLUDE_FILE"
            continue
        fi
        
        # Remove leading slash if present and add backup_dir prefix
        echo "$backup_dir/${line#/}" >> "$TEMP_EXCLUDE_FILE"
    done < "$exclude_config"
}

# Load system files list from config
load_system_files() {
    local system_files_config="$CONFIG_DIR/user-restore-system-files-list.txt"
    
    # Check if system files config exists
    if [ ! -f "$system_files_config" ]; then
        log_msg "ERROR" "System files list not found: $system_files_config"
        exit 1
    fi
    
    # Create temporary array to store system files
    declare -a SYSTEM_FILES
    local current_section=""
    
    # Read system files list
    while IFS= read -r line; do
        # Skip empty lines
        [[ -z "$line" ]] && continue
        
        # Process section headers (comments)
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            current_section="${line#\# }"
            echo -e "\n${BOLD}${current_section}${NC}" >> "$TEMP_SYSFILES_FILE"
            continue
        fi
        
        # Add file path to both the array and the temp file
        SYSTEM_FILES+=("$line")
        echo "$line" >> "$TEMP_SYSFILES_FILE"
    done < "$system_files_config"
    
    # Return the array
    echo "${SYSTEM_FILES[@]}"
}

# Display restore operation details and ask for confirmation
confirm_execution() {
    local backup_dir="$1"
    local username="$2"
    
    print_banner "USER DATA RESTORE CONFIRMATION"
    
    echo -e "${BOLD}The following restore operation will be performed:${NC}\n"
    echo -e "${CYAN}Backup Source:${NC} ${BOLD}$backup_dir${NC}"
    echo -e "${CYAN}Target User:${NC} ${BOLD}$username${NC}"
    echo -e "${CYAN}Target Home:${NC} ${BOLD}/home/$username${NC}"
    
    # Display excluded patterns using the new utility
    display_rule_details "EXCLUDED PATTERNS" false "" "$TEMP_EXCLUDE_FILE" "$backup_dir"
    
    # Display system files using the new utility
    display_rule_details "SYSTEM FILES TO RESTORE" false "" "$TEMP_SYSFILES_FILE"
    
    # Display warning about data overwrite
    display_rule_details "RESTORE WARNING" true \
        "This operation will overwrite existing user data.\nExisting files in the target directory may be modified or deleted." \
        ""
    
    if ! confirm_execution "the restore operation" "n"; then
        log_msg "INFO" "Restore operation cancelled by user"
        exit 1
    fi
}

# Function to restore user data
restore_user_data() {
    local backup_dir="$1"
    local username="$2"
    
    log_msg "INFO" "Starting user data restore"
    log_msg "INFO" "Source: ${BOLD}$backup_dir/home/$username${NC}"
    log_msg "INFO" "Target: ${BOLD}/home/$username${NC}"
    
    # Perform rsync with exclude list
    rsync -aAXHv --delete --exclude-from="$TEMP_EXCLUDE_FILE" --info=progress2 \
        "$backup_dir/home/$username/" "/home/$username/"
    
    local rsync_status=$?
    
    if [ $rsync_status -eq 0 ]; then
        log_msg "SUCCESS" "User data restore completed successfully"
        # Fix ownership
        chown -R "$username:$username" "/home/$username"
    else
        log_msg "ERROR" "Failed to restore user data (rsync exit code: $rsync_status)"
    fi
    
    return $rsync_status
}

# Function to restore system configuration files
restore_system_files() {
    local backup_dir="$1"
    local system_files=($2)
    
    log_msg "INFO" "Starting system configuration restore"
    
    # Create a temporary file to store rsync include patterns
    local TEMP_INCLUDE_FILE=$(mktemp)
    trap 'rm -f "$TEMP_INCLUDE_FILE"' RETURN
    
    # Generate include patterns for rsync
    for file in "${system_files[@]}"; do
        echo "+ $file" >> "$TEMP_INCLUDE_FILE"
        # Include parent directories
        local dir="$file"
        while [ "$dir" != "/" ]; do
            dir=$(dirname "$dir")
            echo "+ $dir/" >> "$TEMP_INCLUDE_FILE"
        done
    done
    # Exclude everything else
    echo "- *" >> "$TEMP_INCLUDE_FILE"
    
    log_msg "INFO" "Starting rsync for system files"
    # Use rsync with include-from to copy only specified files
    if rsync -aAXHv --delete --info=progress2 --include-from="$TEMP_INCLUDE_FILE" "$backup_dir/" /; then
        log_msg "SUCCESS" "System configuration restore completed"
    else
        log_msg "ERROR" "Failed to restore system configuration"
        return 1
    fi
    
    return 0
}

# Function to display script usage
usage() {
    echo -e "${BOLD}Usage:${NC} $0 <backup_dir> <username>"
    echo
    echo -e "${BOLD}Arguments:${NC}"
    echo " backup_dir : Source backup directory"
    echo " username   : Username to restore"
    echo
    echo -e "${BOLD}Example:${NC}"
    echo " $0 /mnt/backup john"
    exit 1
}

# Main script starts here

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_msg "ERROR" "Please run as root"
    exit 1
fi

# Check arguments
if [ $# -ne 2 ]; then
    usage
fi

BACKUP_DIR="$1"
USERNAME="$2"

# Create temporary files and ensure cleanup
TEMP_EXCLUDE_FILE=$(mktemp)
TEMP_SYSFILES_FILE=$(mktemp)
trap 'rm -f "$TEMP_EXCLUDE_FILE" "$TEMP_SYSFILES_FILE"' EXIT

# Print header
print_banner "USER DATA AND SYSTEM RESTORE UTILITY" "$BLUE"

# Validate inputs
log_msg "INFO" "Validating inputs"

if [ ! -d "$BACKUP_DIR" ]; then
    log_msg "ERROR" "Backup directory does not exist: $BACKUP_DIR"
    exit 1
fi

if ! is_valid_user "$USERNAME"; then
    log_msg "ERROR" "User does not exist: $USERNAME"
    exit 1
fi

# Check if the user's home directory exists
USER_HOME="/home/$USERNAME"
if [ ! -d "$USER_HOME" ]; then
    log_msg "ERROR" "User home directory does not exist: $USER_HOME"
    exit 1
fi

# Load system files list
log_msg "INFO" "Loading system files list"
SYSTEM_FILES=$(load_system_files)

# Generate exclude list
log_msg "INFO" "Generating exclude list from configuration"
generate_exclude_list "$BACKUP_DIR" "$USERNAME"

# Ask for confirmation before proceeding
confirm_execution "$BACKUP_DIR" "$USERNAME"

log_msg "INFO" "Starting restore process"

# Perform restore operations
if restore_user_data "$BACKUP_DIR" "$USERNAME"; then
    restore_system_files "$BACKUP_DIR" "$SYSTEM_FILES"
    print_banner "RESTORE PROCESS COMPLETED" "$GREEN"
    log_msg "SUCCESS" "Restore completed successfully"
    exit 0
else
    print_banner "RESTORE PROCESS FAILED" "$RED"
    log_msg "ERROR" "Restore process failed"
    exit 1
fi
