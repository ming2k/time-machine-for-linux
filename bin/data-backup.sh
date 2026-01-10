#!/bin/bash

# Get project paths
SCRIPT_PATH="$(readlink -f "$0")"
PROJECT_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"
CONFIG_DIR="${PROJECT_ROOT}/config"
DEFAULT_BACKUP_MAP_FILE="${CONFIG_DIR}/data-map.conf"
BACKUP_MAP_FILE="$DEFAULT_BACKUP_MAP_FILE"
CUSTOM_CONFIG_SPECIFIED=false
CONFIG_FILE_PRESENT=true
CONFIG_DIR_MISSING=false

# Load libraries
source "${PROJECT_ROOT}/lib/loader.sh"
if ! load_backup_libs "$LIB_DIR"; then
    echo "Failed to load required libraries" >&2
    exit 1
fi

if [ ! -d "$CONFIG_DIR" ]; then
    CONFIG_DIR_MISSING=true
fi

# Function to display script usage
usage() {
    echo -e "${BOLD}Usage:${NC} $0 --dest <backup_path> --snapshots <snapshot_path> [OPTIONS]"
    echo
    echo -e "${BOLD}Required Parameters:${NC}"
    echo " --dest <path>       : Main backup destination path"
    echo " --snapshots <path>  : Path for creating safety snapshots"
    echo
    echo -e "${BOLD}Options:${NC}"
    echo " --help, -h          : Show this help message"
    echo " --config <file>     : Use custom config file (default: data-map.conf)"
    echo
    echo -e "${BOLD}Features:${NC}"
    echo " • Uses data-map.conf for multiple source-destination mappings"
    echo " • Each source can have custom ignore patterns and backup modes"
    echo " • Creates timestamped safety snapshots before backup"
    echo " • Supports incremental and mirror backup modes"
    echo " • Preserves file attributes and permissions"
    echo
    echo -e "${BOLD}Configuration:${NC}"
    echo " Edit ${BACKUP_MAP_FILE} to configure:"
    echo " • Source directories to backup"
    echo " • Destination subdirectories (under main backup path)"
    echo " • Ignore patterns for each source"
    echo " • Backup modes (incremental or mirror)"
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo " $0 --dest /mnt/backup --snapshots /mnt/snapshots"
    echo " $0 --dest /mnt/backup --snapshots /mnt/snapshots --config custom-map.conf"
    echo " $0 --help"
    exit 1
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

# Emit deferred configuration warnings near script exit
emit_config_warnings() {
    if [ "$CONFIG_DIR_MISSING" = "true" ]; then
        log_msg "WARNING" "Config directory not found: $CONFIG_DIR"
    fi
    if [ "$CONFIG_FILE_PRESENT" != "true" ]; then
        log_msg "WARNING" "Data backup map config not found: $BACKUP_MAP_FILE"
    fi
}

# Parse command line arguments
parse_arguments() {
    BACKUP_DEST_PATH=""
    SNAPSHOT_PATH=""
    CONFIG_FILE="$BACKUP_MAP_FILE"

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dest)
                if [ -z "$2" ]; then
                    log_msg "ERROR" "--dest requires a path argument"
                    usage
                fi
                BACKUP_DEST_PATH="$2"
                shift 2
                ;;
            --snapshots)
                if [ -z "$2" ]; then
                    log_msg "ERROR" "--snapshots requires a path argument"
                    usage
                fi
                SNAPSHOT_PATH="$2"
                shift 2
                ;;
            --config)
                if [ -z "$2" ]; then
                    log_msg "ERROR" "--config requires a file path argument"
                    usage
                fi
                CONFIG_FILE="$2"
                CUSTOM_CONFIG_SPECIFIED=true
                shift 2
                ;;
            --help|-h)
                usage
                ;;
            -*)
                log_msg "ERROR" "Unknown option: $1"
                usage
                ;;
            *)
                log_msg "ERROR" "Unexpected argument: $1"
                usage
                ;;
        esac
    done

    # Validate required parameters
    if [ -z "$BACKUP_DEST_PATH" ]; then
        log_msg "ERROR" "Missing required parameter: --dest"
        usage
    fi

    if [ -z "$SNAPSHOT_PATH" ]; then
        log_msg "ERROR" "Missing required parameter: --snapshots"
        usage
    fi

    # Update backup map file if custom config specified
    BACKUP_MAP_FILE="$CONFIG_FILE"
    if [ ! -f "$BACKUP_MAP_FILE" ]; then
        if [ "$CUSTOM_CONFIG_SPECIFIED" = "true" ]; then
            log_msg "ERROR" "Config file not found: $BACKUP_MAP_FILE"
            exit 1
        fi
        CONFIG_FILE_PRESENT=false
    fi
}

# Main script starts here

# Parse command line arguments first to handle --help
parse_arguments "$@"

if [ "$CONFIG_FILE_PRESENT" != "true" ]; then
    print_banner "DATA BACKUP UTILITY" "$BLUE"
    log_msg "INFO" "Skipping data backup because no configuration file was found"
    emit_config_warnings
    exit 0
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_msg "ERROR" "This script must be run as root"
    exit 1
fi

# Verify that the snapshot path is a BTRFS subvolume
if ! is_btrfs_subvolume "$SNAPSHOT_PATH"; then
    log_msg "ERROR" "Snapshot path '$SNAPSHOT_PATH' is not a BTRFS subvolume"
    exit 1
fi

# Print header
print_banner "DATA BACKUP UTILITY" "$BLUE"

# Initialize variables for temporary files
TEMP_EXCLUDE_FILE=""

# Flag to track if backup was interrupted
BACKUP_INTERRUPTED=false

# Map-based backup function
map_based_backup_function() {
    # Parse the backup map configuration
    local -a sources=()
    local -a destinations=()
    local -a ignore_patterns=()
    local -a backup_modes=()

    if ! parse_pipe_delimited_backup_map "$BACKUP_MAP_FILE" sources destinations ignore_patterns backup_modes "false"; then
        log_msg "ERROR" "Failed to parse backup map configuration"
        return 1
    fi

    local total_entries=${#sources[@]}
    local successful_backups=0
    local failed_backups=0

    log_msg "INFO" "Starting backup of $total_entries configured sources"

    # Process each backup entry
    for ((i=0; i<total_entries; i++)); do
        local source_path="${sources[i]}"
        local dest_subdir="${destinations[i]}"
        local ignore_pattern="${ignore_patterns[i]}"
        local backup_mode="${backup_modes[i]}"
        # Remove trailing slash from base path to avoid double slashes
        local clean_dest_path="${BACKUP_DEST_PATH%/}"
        local full_dest_path="$clean_dest_path/$dest_subdir"

        log_msg "INFO" "Processing entry $((i+1))/$total_entries"
        log_msg "INFO" "Source: $source_path"
        log_msg "INFO" "Destination: $full_dest_path"
        log_msg "INFO" "Mode: $backup_mode"

        # Check if source exists
        if [ ! -d "$source_path" ]; then
            log_msg "WARNING" "Source directory does not exist: $source_path, skipping"
            ((failed_backups++))
            continue
        fi

        # Create destination directory if it doesn't exist
        if ! mkdir -p "$full_dest_path"; then
            log_msg "ERROR" "Failed to create destination directory: $full_dest_path"
            ((failed_backups++))
            continue
        fi

        # Execute backup for this entry
        if backup_single_source "$source_path" "$full_dest_path" "$ignore_pattern" "$backup_mode"; then
            log_msg "SUCCESS" "Backup completed for: $source_path"
            ((successful_backups++))
        else
            log_msg "ERROR" "Backup failed for: $source_path"
            ((failed_backups++))
        fi

        echo # Add spacing between entries
    done

    # Summary
    log_msg "INFO" "Backup summary: $successful_backups successful, $failed_backups failed"

    if [ $failed_backups -eq 0 ]; then
        log_msg "SUCCESS" "All backup operations completed successfully"
        return 0
    elif [ $successful_backups -gt 0 ]; then
        log_msg "WARNING" "Some backup operations failed"
        return 1
    else
        log_msg "ERROR" "All backup operations failed"
        return 1
    fi
}

# Backup a single source directory
backup_single_source() {
    local source_path="$1"
    local dest_path="$2"
    local ignore_pattern="$3"
    local backup_mode="$4"

    # local rsync_cmd="rsync -aAXHv --info=progress2 --bwlimit=50000"
    local rsync_cmd="rsync -aAXHv --info=progress2"
    local temp_exclude_file=""

    # Process ignore patterns if provided
    if [ -n "$ignore_pattern" ]; then
        temp_exclude_file=$(mktemp)
        trap 'rm -f "$temp_exclude_file"' RETURN

        # Convert comma-separated patterns to exclude file format
        echo "$ignore_pattern" | tr ',' '\n' | while IFS= read -r pattern; do
            [ -n "$pattern" ] && echo "$pattern" >> "$temp_exclude_file"
        done

        if [ -s "$temp_exclude_file" ]; then
            rsync_cmd+=" --exclude-from=\"$temp_exclude_file\""
            log_msg "INFO" "Applied ignore patterns: $ignore_pattern"
        fi
    fi

    # Handle different backup modes
    case "$backup_mode" in
        "incremental")
            # For incremental, we could add timestamp-based logic here
            # For now, we'll use rsync's built-in incremental capabilities
            log_msg "INFO" "Using incremental mode (rsync will only copy changed files)"
            ;;
        "mirror")
            # Mirror mode creates an exact copy and removes files not in source
            rsync_cmd+=" --delete --delete-excluded"
            log_msg "INFO" "Using mirror mode (will delete files not in source)"
            log_msg "WARNING" "Mirror mode will remove files from destination not present in source"
            ;;
        *)
            log_msg "WARNING" "Unknown backup mode '$backup_mode', using incremental"
            ;;
    esac

    # Execute rsync
    log_msg "INFO" "Executing: rsync from '$source_path' to '$dest_path'"
    eval "$rsync_cmd '$source_path/' '$dest_path/'"
    local rsync_status=$?

    # Clean up temp file
    [ -n "$temp_exclude_file" ] && rm -f "$temp_exclude_file"

    return $rsync_status
}

# Display backup details
log_msg "INFO" "Main backup destination: $BACKUP_DEST_PATH"
log_msg "INFO" "Snapshots path: $SNAPSHOT_PATH"
log_msg "INFO" "Configuration file: $BACKUP_MAP_FILE"

# Parse and display backup map summary
declare -a sources=()
declare -a destinations=()
declare -a ignore_patterns=()
declare -a backup_modes=()

if parse_pipe_delimited_backup_map "$BACKUP_MAP_FILE" sources destinations ignore_patterns backup_modes "false"; then
    log_msg "INFO" "Backup plan:"
    for ((i=0; i<${#sources[@]}; i++)); do
        local source_exists=""
        [ -d "${sources[i]}" ] && source_exists="✓" || source_exists="✗"
        log_msg "INFO" "  [$((i+1))] $source_exists ${sources[i]} → ${destinations[i]}/ (${backup_modes[i]})"
        [ -n "${ignore_patterns[i]}" ] && log_msg "INFO" "      Ignoring: ${ignore_patterns[i]}"
    done
else
    log_msg "ERROR" "Failed to parse backup configuration"
    exit 1
fi

# Ask for confirmation before proceeding (with preflight check option)
if ! confirm_execution "map-based data backup" "n" "data" "$BACKUP_DEST_PATH" "$SNAPSHOT_PATH" "sources"; then
    log_msg "INFO" "Backup operation cancelled by user"
    exit 1
fi

# Perform backup with single snapshot (post-backup only)
if execute_system_backup_with_snapshot "$BACKUP_DEST_PATH" "$SNAPSHOT_PATH" map_based_backup_function; then
    show_backup_results "true" "$SNAPSHOT_PATH" "$TIMESTAMP"
    emit_config_warnings
    exit 0
else
    show_backup_results "false" "$SNAPSHOT_PATH" "$TIMESTAMP"
    emit_config_warnings
    exit 1
fi
