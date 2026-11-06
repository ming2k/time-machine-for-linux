#!/bin/bash

# Home Restore Script
# Restores home directory from backup created by home-backup.sh

# Get project paths
SCRIPT_PATH="$(readlink -f "$0")"
PROJECT_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

# Load restore libraries
source "${LIB_DIR}/loader.sh"
if ! load_restore_libs "$LIB_DIR"; then
    echo "Failed to load required libraries" >&2
    exit 1
fi

# Initialize logging
init_logging

# Function to display script usage
usage() {
    echo -e "${BOLD}Usage:${NC} $0 --source <backup_path> --dest <restore_path> [OPTIONS]"
    echo
    echo -e "${BOLD}Required Parameters:${NC}"
    echo " --source <path>     : Path to the home backup to restore from"
    echo " --dest <path>       : Destination path for restore (usually /home)"
    echo
    echo -e "${BOLD}Options:${NC}"
    echo " --snapshots <path>  : Path for creating pre-restore safety snapshots (must be on destination filesystem)"
    echo " --no-snapshot       : Bypass safety snapshot creation (required if --snapshots is omitted)"
    echo " --dry-run           : Preview what would be restored without making changes"
    echo " --help, -h          : Show this help message"
    echo
    echo -e "${BOLD}Features:${NC}"
    echo " • Full home directory restoration from backup"
    echo " • Automatic pre-restore snapshot (if BTRFS and --snapshots provided)"
    echo " • Preserves ALL file metadata:"
    echo "   - Permissions (including executable bits)"
    echo "   - Owner and group"
    echo "   - Timestamps"
    echo "   - ACLs and extended attributes"
    echo "   - Hard links and symlinks"
    echo " • Requires root privileges (for ownership preservation)"
    echo
    echo -e "${BOLD}Safety:${NC}"
    echo " • Fail-Closed snapshot abort on failure [INV-RESTORE-01]"
    echo " • Case-sensitive uppercase 'YES' confirmation [INV-RESTORE-02]"
    echo " • Path identity and protected tier boundary enforcement [INV-RESTORE-03]"
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo " # Preview home restore"
    echo " sudo $0 --source /mnt/@home --dest /home --dry-run"
    echo
    echo " # Perform home restore with local snapshot"
    echo " sudo $0 --source /mnt/@home --dest /home --snapshots /home/.snapshots"
    echo
    echo " # Perform home restore without snapshot (e.g. fresh distro install)"
    echo " sudo $0 --source /mnt/@home --dest /home --no-snapshot"
    echo
    echo " # Show help"
    echo " $0 --help"
    exit 1
}

# Parse command line arguments
parse_arguments() {
    RESTORE_SOURCE=""
    RESTORE_DEST=""
    SNAPSHOT_PATH=""
    DRY_RUN=false
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
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-snapshot)
                NO_SNAPSHOT=true
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
    if [ -z "$RESTORE_SOURCE" ]; then
        log_msg "ERROR" "Missing required parameter: --source"
        usage
    fi

    if [ -z "$RESTORE_DEST" ]; then
        log_msg "ERROR" "Missing required parameter: --dest"
        usage
    fi
}

# Main execution
main() {
    # Parse arguments
    parse_arguments "$@"

    # Print banner
    print_banner "Home Restore" "$BLUE"

    # Check root privileges
    if [ "$EUID" -ne 0 ]; then
        log_msg "ERROR" "This script must be run as root"
        exit 1
    fi

    # Validate restore source: must exist and be non-empty
    if [ ! -d "$RESTORE_SOURCE" ]; then
        log_msg "ERROR" "Restore source does not exist: $RESTORE_SOURCE"
        exit 1
    fi

    if [ ! -r "$RESTORE_SOURCE" ]; then
        log_msg "ERROR" "Restore source is not readable: $RESTORE_SOURCE"
        exit 1
    fi

    if [ -z "$(ls -A "$RESTORE_SOURCE" 2>/dev/null)" ]; then
        log_msg "ERROR" "Restore source is empty: $RESTORE_SOURCE"
        exit 1
    fi

    # Validate restore destination and safety boundaries [INV-RESTORE-03]
    if ! validate_restore_safety "$RESTORE_SOURCE" "$RESTORE_DEST"; then
        log_msg "ERROR" "Destination validation failed"
        exit 1
    fi

    # Snapshot safety policy [INV-RESTORE-01]
    if [ -n "$SNAPSHOT_PATH" ] && [ "$NO_SNAPSHOT" != true ]; then
        if ! is_btrfs_subvolume "$SNAPSHOT_PATH"; then
            log_msg "ERROR" "Snapshot path must be a BTRFS subvolume: $SNAPSHOT_PATH"
            log_msg "INFO" "Create BTRFS subvolume: sudo btrfs subvolume create $SNAPSHOT_PATH"
            exit 1
        fi
    elif [ -z "$SNAPSHOT_PATH" ] && [ "$NO_SNAPSHOT" != true ]; then
        log_msg "ERROR" "No snapshot path provided [INV-RESTORE-01]"
        log_msg "INFO" "Restore requires rollback safety. Provide --snapshots <path> or explicitly pass --no-snapshot."
        exit 1
    fi

    # Check disk space
    if ! check_restore_disk_space "$RESTORE_SOURCE" "$RESTORE_DEST"; then
        log_msg "ERROR" "Insufficient disk space"
        exit 1
    fi

    # Calculate restore impact
    calculate_restore_impact "$RESTORE_SOURCE" "$RESTORE_DEST"

    # Display restore details
    local snapshot_info="${SNAPSHOT_PATH:-none (no rollback capability)}"
    display_restore_details "home" "$RESTORE_SOURCE" "$RESTORE_DEST" "$snapshot_info"

    # Dry-run mode
    if [ "$DRY_RUN" = true ]; then
        log_msg "INFO" "Running in dry-run mode - no changes will be made"
        print_banner "Dry Run Preview" "$YELLOW"

        # Execute dry-run
        rsync -aAXHv --numeric-ids --info=progress2 --dry-run "${RESTORE_SOURCE}/" "${RESTORE_DEST}/" | tee /tmp/home-restore-dry-run.txt

        echo
        log_msg "INFO" "Dry-run completed. Review the output above to see what would be restored."
        log_msg "INFO" "To perform the actual restore, run without --dry-run flag"
        exit 0
    fi

    # Explicit uppercase affirmation required [INV-RESTORE-02]
    if ! confirm_restore_execution "home" "$RESTORE_SOURCE" "$RESTORE_DEST" "${SNAPSHOT_PATH:-}"; then
        log_msg "INFO" "Home restore cancelled by user"
        exit 0
    fi

    # Execute restore with snapshot
    log_msg "INFO" "Starting home restore..."

    if execute_restore_with_snapshot "$RESTORE_SOURCE" "$RESTORE_DEST" "$SNAPSHOT_PATH" "home" "false"; then
        log_msg "SUCCESS" "Home restore completed successfully"

        if [ -n "${PRE_RESTORE_SNAPSHOT:-}" ]; then
            echo
            log_msg "INFO" "Pre-restore snapshot: ${PRE_RESTORE_SNAPSHOT}"
            log_msg "INFO" "To rollback: sudo btrfs subvolume snapshot ${PRE_RESTORE_SNAPSHOT} ${RESTORE_DEST}"
        fi

        exit 0
    else
        log_msg "ERROR" "Home restore failed"
        exit 1
    fi
}

# Run main function
main "$@"
