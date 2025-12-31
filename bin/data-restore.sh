#!/bin/bash

# Data Restore Script
# Restores data files from backup created by data-backup.sh
# Supports both full restoration (using map config) and selective restoration

# Get project paths
SCRIPT_PATH="$(readlink -f "$0")"
PROJECT_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"
CONFIG_DIR="${PROJECT_ROOT}/config"
DEFAULT_BACKUP_MAP_FILE="${CONFIG_DIR}/data-map.conf"

# Load restore libraries
source "${LIB_DIR}/loader.sh"
if ! load_restore_libs "$LIB_DIR"; then
    echo "Failed to load required libraries" >&2
    exit 1
fi

# Initialize logging
init_logging

# Global variables
RESTORE_MODE=""  # "full" or "selective" or "list"
INCLUDE_PATTERNS=()
EXCLUDE_PATTERNS=()

# Function to display script usage
usage() {
    echo -e "${BOLD}Usage:${NC} $0 <mode> [OPTIONS]"
    echo
    echo -e "${BOLD}Modes:${NC}"
    echo " Full Restore (using backup map):"
    echo "   $0 --source <backup_path> [--config <file>] [--snapshots <path>] [--dry-run]"
    echo
    echo " Selective Restore:"
    echo "   $0 --source <backup_path> --dest <restore_path>"
    echo "      --include <pattern> [--exclude <pattern>] [--snapshots <path>] [--dry-run]"
    echo
    echo " List Available Backups:"
    echo "   $0 --source <backup_path> --list"
    echo
    echo -e "${BOLD}Common Parameters:${NC}"
    echo " --source <path>      : Path to the backup location"
    echo " --dry-run            : Preview what would be restored without making changes"
    echo
    echo -e "${BOLD}Metadata Preservation:${NC}"
    echo " All restore operations preserve complete file metadata including:"
    echo " • Permissions, owner, group (requires root/sudo)"
    echo " • Timestamps, ACLs, extended attributes"
    echo " • Hard links, symlinks, executable bits"
    echo
    echo -e "${BOLD}Full Restore Parameters:${NC}"
    echo " --config <file>      : Use custom backup map config (default: data-map.conf)"
    echo
    echo -e "${BOLD}Selective Restore Parameters:${NC}"
    echo " --dest <path>        : Destination path for selective restore"
    echo " --include <pattern>  : Include pattern (can be specified multiple times)"
    echo " --exclude <pattern>  : Exclude pattern (can be specified multiple times)"
    echo
    echo -e "${BOLD}Other Options:${NC}"
    echo " --snapshots <path>   : Path for creating pre-restore safety snapshots (optional)"
    echo " --no-snapshot        : Skip pre-restore snapshot creation"
    echo " --list               : List available backup subdirectories and exit"
    echo " --help, -h           : Show this help message"
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo " # List available backups"
    echo " $0 --source /mnt/@data --list"
    echo
    echo " # Full restore using backup map"
    echo " sudo $0 --source /mnt/@data"
    echo
    echo " # Full restore with snapshot"
    echo " sudo $0 --source /mnt/@data --snapshots /mnt/@snapshots"
    echo
    echo " # Selective restore of specific project"
    echo " sudo $0 --source /mnt/@data --dest /home/ming \\"
    echo "    --include 'projects/myproject/**'"
    echo
    echo " # Dry-run selective restore"
    echo " sudo $0 --source /mnt/@data --dest /home/ming \\"
    echo "    --include 'documents/*.pdf' --dry-run"
    echo
    exit 1
}

# Parse command line arguments
parse_arguments() {
    RESTORE_SOURCE=""
    RESTORE_DEST=""
    SNAPSHOT_PATH=""
    CONFIG_FILE="$DEFAULT_BACKUP_MAP_FILE"
    DRY_RUN=false
    LIST_MODE=false
    NO_SNAPSHOT=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --source)
                if [ -z "$2" ]; then
                    log_msg "ERROR" "--source requires a path argument"
                    usage
                fi
                RESTORE_SOURCE="$2"
                shift 2
                ;;
            --dest)
                if [ -z "$2" ]; then
                    log_msg "ERROR" "--dest requires a path argument"
                    usage
                fi
                RESTORE_DEST="$2"
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
                shift 2
                ;;
            --include)
                if [ -z "$2" ]; then
                    log_msg "ERROR" "--include requires a pattern argument"
                    usage
                fi
                INCLUDE_PATTERNS+=("$2")
                shift 2
                ;;
            --exclude)
                if [ -z "$2" ]; then
                    log_msg "ERROR" "--exclude requires a pattern argument"
                    usage
                fi
                EXCLUDE_PATTERNS+=("$2")
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-snapshot)
                NO_SNAPSHOT=true
                shift
                ;;
            --list)
                LIST_MODE=true
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

    # Validate required parameters based on mode
    if [ -z "$RESTORE_SOURCE" ]; then
        log_msg "ERROR" "Missing required parameter: --source"
        usage
    fi

    # Determine restore mode
    if [ "$LIST_MODE" = true ]; then
        RESTORE_MODE="list"
    elif [ ${#INCLUDE_PATTERNS[@]} -gt 0 ] || [ ${#EXCLUDE_PATTERNS[@]} -gt 0 ] || [ -n "$RESTORE_DEST" ]; then
        RESTORE_MODE="selective"

        if [ -z "$RESTORE_DEST" ]; then
            log_msg "ERROR" "Selective restore requires --dest parameter"
            usage
        fi
    else
        RESTORE_MODE="full"
    fi
}

# List available backups
list_backups() {
    if ! display_available_backups "$RESTORE_SOURCE"; then
        exit 1
    fi
    exit 0
}

# Execute full restore using backup map
execute_full_restore() {
    print_banner "Data Restore (Full Mode)" "$BLUE"

    # Check root privileges
    if [ "$EUID" -ne 0 ] && [ "$DRY_RUN" != true ]; then
        log_msg "ERROR" "This script must be run as root"
        exit 1
    fi

    # Validate BTRFS for snapshots (if provided)
    if [ "$DRY_RUN" != true ]; then
        if [ -n "$SNAPSHOT_PATH" ] && [ "$NO_SNAPSHOT" != true ]; then
            if ! is_btrfs_subvolume "$SNAPSHOT_PATH"; then
                log_msg "ERROR" "Snapshot path must be a BTRFS subvolume: $SNAPSHOT_PATH"
                log_msg "INFO" "Create BTRFS subvolume: sudo btrfs subvolume create $SNAPSHOT_PATH"
                exit 1
            fi
        elif [ -z "$SNAPSHOT_PATH" ] && [ "$NO_SNAPSHOT" != true ]; then
            log_msg "WARNING" "No snapshot path provided, restore will proceed without pre-restore snapshots"
            log_msg "WARNING" "Use --snapshots <path> to enable rollback capability"
            SNAPSHOT_PATH=""
        fi
    fi

    # Check if config file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        log_msg "ERROR" "Backup map config file not found: $CONFIG_FILE"
        exit 1
    fi

    # Parse backup map in reverse (for restore)
    local sources=()
    local destinations=()
    local ignore_patterns_list=()
    local backup_modes=()

    if ! parse_pipe_delimited_backup_map "$CONFIG_FILE" sources destinations ignore_patterns_list backup_modes "false"; then
        log_msg "ERROR" "Failed to parse backup map configuration"
        exit 1
    fi

    local total_entries=${#sources[@]}
    if [ "$total_entries" -eq 0 ]; then
        log_msg "ERROR" "No restore mappings found in config file"
        exit 1
    fi

    # Display restore mappings
    display_data_restore_mappings sources destinations "$RESTORE_SOURCE"

    # Get user confirmation
    if [ "$DRY_RUN" != true ]; then
        if ! confirm_execution "data restore" "n"; then
            log_msg "INFO" "Data restore cancelled by user"
            exit 0
        fi
    else
        log_msg "INFO" "Running in dry-run mode - no changes will be made"
    fi

    # Execute restore for each mapping
    local successful=0
    local failed=0
    local skipped=0

    for ((i=0; i<total_entries; i++)); do
        local original_source="${sources[i]}"
        local backup_subdir="${destinations[i]}"
        local ignore_patterns="${ignore_patterns_list[i]}"

        local backup_path="${RESTORE_SOURCE}/${backup_subdir}"

        # Check if backup exists
        if [ ! -d "$backup_path" ]; then
            log_msg "WARNING" "Backup not found, skipping: $backup_path"
            ((skipped++))
            continue
        fi

        # Restore this mapping
        if restore_single_source "$backup_path" "$original_source" "$SNAPSHOT_PATH" "$ignore_patterns" "$DRY_RUN"; then
            ((successful++))
        else
            ((failed++))
        fi
    done

    # Display summary
    echo
    print_banner "Restore Summary" "$BLUE"
    echo -e "${BOLD}Total mappings:${NC} $total_entries"
    echo -e "${GREEN}Successful:${NC} $successful"
    if [ "$failed" -gt 0 ]; then
        echo -e "${RED}Failed:${NC} $failed"
    fi
    if [ "$skipped" -gt 0 ]; then
        echo -e "${YELLOW}Skipped:${NC} $skipped"
    fi
    echo

    if [ "$failed" -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Handle selective restore mode
handle_selective_restore() {
    print_banner "Data Restore (Selective Mode)" "$BLUE"

    # Check root privileges
    if [ "$EUID" -ne 0 ] && [ "$DRY_RUN" != true ]; then
        log_msg "ERROR" "This script must be run as root"
        exit 1
    fi

    # Validate BTRFS for snapshots (if provided)
    if [ "$DRY_RUN" != true ]; then
        if [ -n "$SNAPSHOT_PATH" ] && [ "$NO_SNAPSHOT" != true ]; then
            if ! is_btrfs_subvolume "$SNAPSHOT_PATH"; then
                log_msg "ERROR" "Snapshot path must be a BTRFS subvolume: $SNAPSHOT_PATH"
                log_msg "INFO" "Create BTRFS subvolume: sudo btrfs subvolume create $SNAPSHOT_PATH"
                exit 1
            fi
        elif [ -z "$SNAPSHOT_PATH" ] && [ "$NO_SNAPSHOT" != true ]; then
            log_msg "WARNING" "No snapshot path provided, restore will proceed without pre-restore snapshots"
            log_msg "WARNING" "Use --snapshots <path> to enable rollback capability"
            SNAPSHOT_PATH=""
        fi
    fi

    # Display selective patterns
    if [ ${#INCLUDE_PATTERNS[@]} -gt 0 ] || [ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]; then
        display_selective_patterns INCLUDE_PATTERNS EXCLUDE_PATTERNS
    fi

    # Display restore details
    local additional_info=""
    if [ ${#INCLUDE_PATTERNS[@]} -gt 0 ]; then
        additional_info+="Include patterns: ${INCLUDE_PATTERNS[*]}\n"
    fi
    if [ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]; then
        additional_info+="Exclude patterns: ${EXCLUDE_PATTERNS[*]}"
    fi

    calculate_restore_impact "$RESTORE_SOURCE" "$RESTORE_DEST"
    display_restore_details "data" "$RESTORE_SOURCE" "$RESTORE_DEST" "$SNAPSHOT_PATH" "$additional_info"

    # Get user confirmation (if not dry-run)
    if [ "$DRY_RUN" != true ]; then
        if ! confirm_execution "selective restore" "n"; then
            log_msg "INFO" "Selective restore cancelled by user"
            exit 0
        fi
    else
        log_msg "INFO" "Running in dry-run mode - no changes will be made"
    fi

    # Execute selective restore
    if execute_selective_restore "$RESTORE_SOURCE" "$RESTORE_DEST" "$SNAPSHOT_PATH" INCLUDE_PATTERNS EXCLUDE_PATTERNS "$DRY_RUN"; then
        if [ "$DRY_RUN" != true ]; then
            log_msg "SUCCESS" "Selective restore completed successfully"
        fi
        exit 0
    else
        log_msg "ERROR" "Selective restore failed"
        exit 1
    fi
}

# Main execution
main() {
    # Parse arguments
    parse_arguments "$@"

    # Execute based on mode
    case "$RESTORE_MODE" in
        list)
            list_backups
            ;;
        full)
            execute_full_restore
            ;;
        selective)
            handle_selective_restore
            ;;
        *)
            log_msg "ERROR" "Unknown restore mode: $RESTORE_MODE"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
