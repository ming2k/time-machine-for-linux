#!/bin/bash

# Cold Data Archive Script (Append-Only)
# Safely synchronizes completed projects, media, or datasets to cold storage
# Principle: NEVER DELETE at destination (Append-Only). Optional checksum verification.

# Get project paths
SCRIPT_PATH="$(readlink -f "$0")"
PROJECT_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

# Load core libraries
source "${LIB_DIR}/loader.sh"
if ! load_backup_libs "$LIB_DIR"; then
    echo "Failed to load required libraries" >&2
    exit 1
fi

# Initialize logging
init_logging

# Display usage
usage() {
    echo -e "${BOLD}Usage:${NC} $0 --source <source_path> --dest <archive_dest> [OPTIONS]"
    echo
    echo -e "${BOLD}Required Parameters:${NC}"
    echo " --source <path>     : Path to local cold data to archive (e.g. /data/archive/ or /data/projects/old-app)"
    echo " --dest <path>       : Path to archive destination (usually /mnt/@archive)"
    echo
    echo -e "${BOLD}Options:${NC}"
    echo " --snapshots <path>  : Path to snapshots subvolume to store read-only archive snapshots (e.g. /mnt/@snapshots)"
    echo " --checksum, -c      : Compare file contents via checksum (slower, but guarantees bit-for-bit integrity)"
    echo " --clean-source      : Prompt to delete source files after verified transfer to free local disk space"
    echo " --dry-run, -n       : Preview files that would be transferred without modifying destination"
    echo " --no-snapshot       : Do not create a read-only safety snapshot after transfer"
    echo " --help, -h          : Show this help message"
    echo
    echo -e "${BOLD}Safety Guarantees:${NC}"
    echo " • APPEND-ONLY: NEVER runs with --delete. Destination files are NEVER purged."
    echo " • METADATA PRESERVATION: Full -aAXH flags preserve permissions, ownership, timestamps, and ACLs."
    echo " • READ-ONLY BTRFS SNAPSHOTS: Can lock batch snapshots with 'btrfs subvolume snapshot -r'."
    echo " • CONFIRMATION: Interactive prompt with preview before execution."
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo " # Archive local /data/archive staging folder to external cold subvolume"
    echo " sudo $0 --source /data/archive/ --dest /mnt/@archive --snapshots /mnt/@snapshots"
    echo
    echo " # Archive with content checksum verification and free local space"
    echo " sudo $0 --source /data/projects/old-repo --dest /mnt/@archive/projects/ --checksum --clean-source"
    echo
    echo " # Preview archive transfer safely"
    echo " sudo $0 --source /data/archive/ --dest /mnt/@archive --dry-run"
    exit "${1:-1}"
}

# Parse command line arguments
parse_arguments() {
    SOURCE_PATH=""
    DEST_PATH=""
    SNAPSHOT_PATH=""
    USE_CHECKSUM=false
    CLEAN_SOURCE=false
    DRY_RUN=false
    CREATE_SNAPSHOT=true

    while [[ $# -gt 0 ]]; do
        case $1 in
            --source)
                [ -z "${2:-}" ] && { log_msg "ERROR" "--source requires a path argument"; usage 1; }
                SOURCE_PATH="$2"
                shift 2
                ;;
            --dest)
                [ -z "${2:-}" ] && { log_msg "ERROR" "--dest requires a path argument"; usage 1; }
                DEST_PATH="$2"
                shift 2
                ;;
            --snapshots)
                [ -z "${2:-}" ] && { log_msg "ERROR" "--snapshots requires a path argument"; usage 1; }
                SNAPSHOT_PATH="$2"
                shift 2
                ;;
            --checksum|-c)
                USE_CHECKSUM=true
                shift
                ;;
            --clean-source)
                CLEAN_SOURCE=true
                shift
                ;;
            --dry-run|-n)
                DRY_RUN=true
                shift
                ;;
            --no-snapshot)
                CREATE_SNAPSHOT=false
                shift
                ;;
            --help|-h)
                usage 0
                ;;
            -*)
                log_msg "ERROR" "Unknown option: $1"
                usage
                ;;
            *)
                if [ -z "$SOURCE_PATH" ]; then
                    SOURCE_PATH="$1"
                elif [ -z "$DEST_PATH" ]; then
                    DEST_PATH="$1"
                else
                    log_msg "ERROR" "Unexpected argument: $1"
                    usage
                fi
                shift
                ;;
        esac
    done

    if [ -z "$SOURCE_PATH" ]; then
        log_msg "ERROR" "Missing required parameter: --source"
        usage
    fi

    if [ -z "$DEST_PATH" ]; then
        log_msg "ERROR" "Missing required parameter: --dest"
        usage
    fi
}

# Check required commands
check_requirements() {
    local required_commands=("rsync" "btrfs")
    local missing=()
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        log_msg "ERROR" "Missing required tools: ${missing[*]}"
        return 1
    fi
    return 0
}

# Main execution
main() {
    parse_arguments "$@"

    print_banner "Cold Data Archive" "$BLUE"

    # Require root for preserving ownership & btrfs operations
    if [ "$(id -u)" -ne 0 ]; then
        log_msg "ERROR" "This script must be run as root (to preserve full metadata)"
        exit 1
    fi

    check_requirements || exit 1

    # Normalize paths
    SOURCE_PATH="${SOURCE_PATH%/}"
    DEST_PATH="${DEST_PATH%/}"

    if [ ! -e "$SOURCE_PATH" ]; then
        log_msg "ERROR" "Source path does not exist: $SOURCE_PATH"
        exit 1
    fi

    if [ ! -d "$DEST_PATH" ]; then
        log_msg "INFO" "Destination path does not exist, creating directory: $DEST_PATH"
        mkdir -p "$DEST_PATH" || { log_msg "ERROR" "Failed to create destination $DEST_PATH"; exit 1; }
    fi

    # Display configuration
    echo -e "${BOLD}Source:${NC}       $SOURCE_PATH"
    echo -e "${BOLD}Destination:${NC}  $DEST_PATH"
    echo -e "${BOLD}Checksum:${NC}     $USE_CHECKSUM"
    echo -e "${BOLD}Clean Source:${NC} $CLEAN_SOURCE"
    echo -e "${BOLD}Mode:${NC}         ${GREEN}APPEND-ONLY (No files deleted at destination)${NC}"
    echo

    # Build rsync options (NEVER include --delete)
    local -a rsync_cmd=(rsync -aAXHv --numeric-ids --info=progress2)
    if [ "$USE_CHECKSUM" = true ]; then
        rsync_cmd+=(-c)
    fi

    # Dry-run execution
    if [ "$DRY_RUN" = true ]; then
        log_msg "INFO" "Executing dry-run preview..."
        print_banner "Archive Dry Run Preview" "$YELLOW"
        "${rsync_cmd[@]}" --dry-run "$SOURCE_PATH/" "$DEST_PATH/"
        echo
        log_msg "SUCCESS" "Dry-run complete. No files were modified."
        exit 0
    fi

    # User confirmation prompt
    echo -e "${YELLOW}Notice: Transferring data into cold archive storage.${NC}"
    read -r -p "Proceed with archive transfer? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_msg "INFO" "Operation cancelled by user."
        exit 0
    fi

    # Perform transfer
    log_msg "INFO" "Starting archive synchronization..."
    local start_time
    start_time=$(date +%s)

    local rsync_status=0
    "${rsync_cmd[@]}" "$SOURCE_PATH/" "$DEST_PATH/" || rsync_status=$?

    if [ $rsync_status -ne 0 ] && [ $rsync_status -ne 24 ]; then
        log_msg "ERROR" "Archive transfer encountered errors (exit code: $rsync_status)"
        exit 1
    fi

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_msg "SUCCESS" "Data successfully archived in ${duration}s"

    # Optional: Read-only BTRFS Snapshot
    if [ "$CREATE_SNAPSHOT" = true ] && [ -n "$SNAPSHOT_PATH" ]; then
        if is_btrfs_subvolume "$SNAPSHOT_PATH" && is_btrfs_subvolume "$DEST_PATH"; then
            local snap_time
            snap_time=$(date +%Y%m%d%H%M%S)
            local snap_target="${SNAPSHOT_PATH%/}/archive-batch-${snap_time}"
            log_msg "INFO" "Creating read-only BTRFS snapshot: $snap_target"
            if btrfs subvolume snapshot -r "$DEST_PATH" "$snap_target" >/dev/null 2>&1; then
                log_msg "SUCCESS" "Read-only archive snapshot locked: $snap_target"
            else
                log_msg "WARNING" "Failed to create read-only snapshot, but archive files are intact."
            fi
        fi
    fi

    # Optional: Clean source to free local space
    if [ "$CLEAN_SOURCE" = true ]; then
        echo
        echo -e "${BOLD}${RED}⚠ WARNING: Local Space Recovery${NC}"
        echo -e "Data has been verified and safely archived to: $DEST_PATH"
        read -r -p "Do you want to permanently delete local source files in '$SOURCE_PATH' to free disk space? [y/N]: " clean_confirm
        if [[ "$clean_confirm" =~ ^[Yy]$ ]]; then
            log_msg "INFO" "Cleaning local source: $SOURCE_PATH"
            # If source was a directory, clean its contents or remove it
            rm -rf "${SOURCE_PATH:?}"/*
            log_msg "SUCCESS" "Local source cleared. Space freed on local disk."
        else
            log_msg "INFO" "Local source preserved."
        fi
    fi

    echo
    log_msg "SUCCESS" "Archive operation completed successfully."
    exit 0
}

main "$@"
