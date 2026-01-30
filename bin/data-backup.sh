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
    echo " --list-orphans      : List orphaned backup destinations with sizes"
    echo " --cleanup-orphans   : Interactive removal of orphaned destinations"
    echo
    echo -e "${BOLD}Features:${NC}"
    echo " • Uses data-map.conf for multiple source-destination mappings"
    echo " • Each source can have custom ignore patterns and backup modes"
    echo " • Creates timestamped safety snapshots before backup"
    echo " • Supports incremental and mirror backup modes"
    echo " • Preserves file attributes and permissions"
    echo " • Supports .backupignore files in source directories"
    echo " • Detects orphaned backup destinations when config changes"
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
    echo " $0 --dest /mnt/backup --snapshots /mnt/snapshots --list-orphans"
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
    BACKUP_DIR=""
    SNAPSHOT_DIR=""
    CONFIG_FILE="$BACKUP_MAP_FILE"
    LIST_ORPHANS=false
    CLEANUP_ORPHANS=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dest)
                if [ -z "$2" ]; then
                    log_msg "ERROR" "--dest requires a path argument"
                    usage
                fi
                BACKUP_DIR="$2"
                shift 2
                ;;
            --snapshots)
                if [ -z "$2" ]; then
                    log_msg "ERROR" "--snapshots requires a path argument"
                    usage
                fi
                SNAPSHOT_DIR="$2"
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
            --list-orphans)
                LIST_ORPHANS=true
                shift
                ;;
            --cleanup-orphans)
                CLEANUP_ORPHANS=true
                shift
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
    if [ -z "$BACKUP_DIR" ]; then
        log_msg "ERROR" "Missing required parameter: --dest"
        usage
    fi

    if [ -z "$SNAPSHOT_DIR" ]; then
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
    print_banner "Data Backup"
    echo "No configuration file found, skipping"
    emit_config_warnings
    exit 0
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_msg "ERROR" "This script must be run as root"
    exit 1
fi

# Verify that the snapshot path is a BTRFS subvolume
if ! is_btrfs_subvolume "$SNAPSHOT_DIR"; then
    log_msg "ERROR" "Snapshot path '$SNAPSHOT_DIR' is not a BTRFS subvolume"
    exit 1
fi


# Initialize variables for temporary files
TEMP_EXCLUDE_FILE=""

# Flag to track if backup was interrupted
BACKUP_INTERRUPTED=false

# Map-based backup function (uses global arrays: sources, destinations, ignore_patterns, backup_modes)
map_based_backup_function() {
    local total_entries=${#sources[@]}
    local successful_backups=0
    local failed_backups=0

    # Process each backup entry
    for ((i=0; i<total_entries; i++)); do
        local source_path="${sources[i]}"
        local dest_subdir="${destinations[i]}"
        local ignore_pattern="${ignore_patterns[i]}"
        local backup_mode="${backup_modes[i]}"
        # Remove trailing slash from base path to avoid double slashes
        local clean_dest_path="${BACKUP_DIR%/}"
        local full_dest_path="$clean_dest_path/$dest_subdir"

        echo -e "[$((i+1))/$total_entries] ${BOLD}$source_path${NC} → $dest_subdir ($backup_mode)"

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
    echo ""
    if [ $failed_backups -eq 0 ]; then
        log_msg "SUCCESS" "All $successful_backups backups completed"
        return 0
    elif [ $successful_backups -gt 0 ]; then
        log_msg "WARNING" "$successful_backups succeeded, $failed_backups failed"
        return 1
    else
        log_msg "ERROR" "All $failed_backups backups failed"
        return 1
    fi
}

# Backup a single source directory
backup_single_source() {
    local source_path="$1"
    local dest_path="$2"
    local ignore_pattern="$3"
    local backup_mode="$4"

    # Build rsync command as array (safer than eval)
    local -a rsync_cmd=(rsync -aAXHv --info=progress2)
    local temp_exclude_file=""

    # Process ignore patterns
    temp_exclude_file=$(mktemp)

    process_backup_excludes "$source_path" "$ignore_pattern" "$temp_exclude_file"

    if [ -s "$temp_exclude_file" ]; then
        rsync_cmd+=(--exclude-from="$temp_exclude_file")
    fi

    # Handle different backup modes
    if [ "$backup_mode" = "mirror" ]; then
        rsync_cmd+=(--delete --delete-excluded)
    fi

    # Execute rsync
    "${rsync_cmd[@]}" "$source_path/" "$dest_path/"
    local rsync_status=$?

    # Clean up temp file
    rm -f "$temp_exclude_file"

    return $rsync_status
}

# Parse backup map configuration first (needed for orphan handling)
declare -a sources=()
declare -a destinations=()
declare -a ignore_patterns=()
declare -a backup_modes=()

if ! parse_pipe_delimited_backup_map "$BACKUP_MAP_FILE" sources destinations ignore_patterns backup_modes "false"; then
    log_msg "ERROR" "Failed to parse backup configuration"
    exit 1
fi

# Handle --list-orphans flag
if [ "$LIST_ORPHANS" = "true" ]; then
    print_banner "Data Backup"
    list_orphans "$BACKUP_DIR" destinations
    exit 0
fi

# Handle --cleanup-orphans flag
if [ "$CLEANUP_ORPHANS" = "true" ]; then
    print_banner "Data Backup"
    cleanup_orphans "$BACKUP_DIR" destinations
    exit $?
fi

# Check for orphaned backup destinations and exit if any found
if detect_orphans "$BACKUP_DIR" destinations >/dev/null 2>&1; then
    print_banner "Data Backup"
    log_msg "WARNING" "Orphaned backup destinations detected"
    list_orphans "$BACKUP_DIR" destinations
    log_msg "ERROR" "Run --cleanup-orphans to remove or update config"
    exit 1
fi

# Display backup details
print_banner "Data Backup"
echo -e "Destination:  ${BOLD}$BACKUP_DIR${NC}"
echo -e "Snapshots:    ${BOLD}$SNAPSHOT_DIR${NC}"
echo -e "Sources:      ${BOLD}${#sources[@]}${NC}"
echo ""

# Ask for confirmation
if ! confirm_execution "data backup" "n" "data" "$BACKUP_DIR" "$SNAPSHOT_DIR" "sources" "destinations"; then
    echo "Cancelled"
    exit 1
fi

# Perform backup with single snapshot (post-backup only)
if execute_system_backup_with_snapshot "$BACKUP_DIR" "$SNAPSHOT_DIR" map_based_backup_function; then
    # Update backup state file for orphan detection
    update_backup_state "$BACKUP_DIR" sources destinations
    show_backup_results "true" "$SNAPSHOT_DIR" "$TIMESTAMP"
    emit_config_warnings
    exit 0
else
    show_backup_results "false" "$SNAPSHOT_DIR" "$TIMESTAMP"
    emit_config_warnings
    exit 1
fi
