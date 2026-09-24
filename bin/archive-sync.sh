#!/bin/bash

# Cold Data Archive Script (Append-Only & Defensive Dual-Staging)
# Safely synchronizes completed projects, media, or datasets to cold storage.
# Principle: NEVER DELETE at destination (Append-Only). Optional checksum verification.
# Defensive Feature: Autodiscovers both /data/archive and /home/*/archive staging exits.

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
    echo -e "${BOLD}Usage:${NC} $0 [--source <path>] [--dest <path>] [OPTIONS]"
    echo
    echo -e "${BOLD}Description:${NC}"
    echo " Synchronizes cold data to long-term storage under an APPEND-ONLY policy."
    echo " By default, autodiscovers active staging exits (/data/archive and /home/*/archive)."
    echo
    echo -e "${BOLD}Parameters:${NC}"
    echo " --source <path>     : Explicit path to archive (default: autodiscovers /data/archive & /home/*/archive)"
    echo " --dest <path>       : Archive destination (default: /mnt/@archive)"
    echo " --snapshots <path>  : Path to snapshots subvolume (default: /mnt/@snapshots)"
    echo
    echo -e "${BOLD}Options:${NC}"
    echo " --checksum, -c      : Compare file contents via checksum (guarantees bit-for-bit integrity)"
    echo " --clean-source      : Prompt to delete source files after verified transfer to free local disk space"
    echo " --dry-run, -n       : Preview files that would be transferred without modifying destination"
    echo " --no-snapshot       : Do not create a read-only safety snapshot after transfer"
    echo " --help, -h          : Show this help message"
    echo
    echo -e "${BOLD}Safety Guarantees:${NC}"
    echo " • APPEND-ONLY: NEVER runs with --delete. Destination files are NEVER purged."
    echo " • METADATA PRESERVATION: Full -aAXH flags preserve permissions, ownership, timestamps, and ACLs."
    echo " • READ-ONLY BTRFS SNAPSHOTS: Locks batch snapshots with 'btrfs subvolume snapshot -r'."
    echo " • DUAL-STAGING DEFENSE: Protects against missed archives across /data and /home."
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo " # Autodiscover and archive all staging exits (/data/archive + /home/*/archive)"
    echo " sudo $0"
    echo
    echo " # Archive with checksum verification and reclaim local NVMe disk space"
    echo " sudo $0 --checksum --clean-source"
    echo
    echo " # Archive a specific directory only"
    echo " sudo $0 --source /home/ming/archive/projects/ --dest /mnt/@archive/projects/"
    exit "${1:-1}"
}

# Parse command line arguments
parse_arguments() {
    EXPLICIT_SOURCE=""
    DEST_PATH="/mnt/@archive"
    SNAPSHOT_PATH="/mnt/@snapshots"
    USE_CHECKSUM=false
    CLEAN_SOURCE=false
    DRY_RUN=false
    CREATE_SNAPSHOT=true

    while [[ $# -gt 0 ]]; do
        case $1 in
            --source)
                [ -z "${2:-}" ] && { log_msg "ERROR" "--source requires a path argument"; usage 1; }
                EXPLICIT_SOURCE="$2"
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
                usage 1
                ;;
            *)
                if [ -z "$EXPLICIT_SOURCE" ]; then
                    EXPLICIT_SOURCE="$1"
                elif [ -z "$DEST_PATH" ]; then
                    DEST_PATH="$1"
                else
                    log_msg "ERROR" "Unexpected argument: $1"
                    usage 1
                fi
                shift
                ;;
        esac
    done
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

# Discover all non-empty candidate staging exits
discover_staging_exits() {
    local -n out_exits="$1"
    out_exits=()

    # Candidate 1: Canonical data staging exit
    if [ -d "/data/archive" ] && [ -n "$(ls -A /data/archive 2>/dev/null)" ]; then
        out_exits+=("/data/archive")
    fi

    # Candidate 2: Defensive home staging exits
    for user_home in /home/*; do
        local candidate="${user_home}/archive"
        if [ -d "$candidate" ] && [ -n "$(ls -A "$candidate" 2>/dev/null)" ]; then
            # Avoid duplicate if symlinked
            local resolved_candidate
            resolved_candidate=$(readlink -f "$candidate" || true)
            local already_included=false
            for existing in "${out_exits[@]}"; do
                if [ "$(readlink -f "$existing" 2>/dev/null)" = "$resolved_candidate" ]; then
                    already_included=true
                    break
                fi
            done
            if [ "$already_included" = false ]; then
                out_exits+=("$candidate")
            fi
        fi
    done
}

# Execute archive for a single source path
sync_archive_source() {
    local src_path="${1%/}"
    local target_dest="${DEST_PATH%/}"

    echo
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}▶ Archiving:${NC} $src_path -> $target_dest"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local -a rsync_cmd=(rsync -aAXHv --numeric-ids --info=progress2)
    [ "$USE_CHECKSUM" = true ] && rsync_cmd+=(-c)

    if [ "$DRY_RUN" = true ]; then
        log_msg "INFO" "Dry-run preview for $src_path:"
        "${rsync_cmd[@]}" --dry-run "$src_path/" "$target_dest/"
        return 0
    fi

    local start_time
    start_time=$(date +%s)
    local rsync_status=0
    "${rsync_cmd[@]}" "$src_path/" "$target_dest/" || rsync_status=$?

    if [ $rsync_status -ne 0 ] && [ $rsync_status -ne 24 ]; then
        log_msg "ERROR" "Archive transfer for $src_path encountered errors (exit: $rsync_status)"
        return 1
    fi

    local duration=$(( $(date +%s) - start_time ))
    log_msg "SUCCESS" "Archived $src_path in ${duration}s"

    # Optional: Clean source to free local space
    if [ "$CLEAN_SOURCE" = true ]; then
        echo
        echo -e "${BOLD}${RED}⚠ Local Space Recovery Confirmation${NC}"
        echo -e "Files in '$src_path' have been safely archived to '$target_dest'."
        read -r -p "Permanently delete contents of '$src_path' to free local disk space? [y/N]: " clean_confirm
        if [[ "$clean_confirm" =~ ^[Yy]$ ]]; then
            log_msg "INFO" "Cleaning local source: $src_path"
            rm -rf "${src_path:?}"/*
            log_msg "SUCCESS" "Cleared $src_path. Local space successfully recovered."
        else
            log_msg "INFO" "Source files preserved at $src_path."
        fi
    fi

    return 0
}

# Main execution
main() {
    parse_arguments "$@"

    print_banner "Cold Data Archive" "$BLUE"

    if [ "$(id -u)" -ne 0 ]; then
        log_msg "ERROR" "This script must be run as root (sudo) to preserve metadata."
        exit 1
    fi

    check_requirements || exit 1

    DEST_PATH="${DEST_PATH%/}"
    if [ ! -d "$DEST_PATH" ]; then
        log_msg "INFO" "Destination path does not exist, creating directory: $DEST_PATH"
        mkdir -p "$DEST_PATH" || { log_msg "ERROR" "Failed to create destination $DEST_PATH"; exit 1; }
    fi

    # Determine sources to archive
    declare -a SOURCES_TO_ARCHIVE=()
    if [ -n "$EXPLICIT_SOURCE" ]; then
        if [ ! -e "$EXPLICIT_SOURCE" ]; then
            log_msg "ERROR" "Specified source path does not exist: $EXPLICIT_SOURCE"
            exit 1
        fi
        SOURCES_TO_ARCHIVE+=("$EXPLICIT_SOURCE")
    else
        discover_staging_exits SOURCES_TO_ARCHIVE
        if [ ${#SOURCES_TO_ARCHIVE[@]} -eq 0 ]; then
            log_msg "INFO" "Both /data/archive and /home/*/archive are empty or missing."
            log_msg "INFO" "No pending cold data to archive."
            exit 0
        fi
    fi

    # Display execution plan
    echo -e "${BOLD}${BLUE}=== Archive Execution Plan ===${NC}"
    echo -e "${BOLD}Destination:${NC}  $DEST_PATH"
    echo -e "${BOLD}Checksum:${NC}     $USE_CHECKSUM"
    echo -e "${BOLD}Clean Source:${NC} $CLEAN_SOURCE"
    echo -e "${BOLD}Policy:${NC}       ${GREEN}APPEND-ONLY (No files deleted at destination)${NC}"
    echo
    echo -e "${BOLD}Detected Staging Exits (${#SOURCES_TO_ARCHIVE[@]}):${NC}"
    for src in "${SOURCES_TO_ARCHIVE[@]}"; do
        local size_str
        size_str=$(du -sh "$src" 2>/dev/null | awk '{print $1}')
        echo -e "  • ${CYAN}$src${NC} (${BOLD}$size_str${NC})"
    done
    echo

    if [ "$DRY_RUN" = true ]; then
        log_msg "INFO" "Executing dry-run preview across all detected exits..."
        for src in "${SOURCES_TO_ARCHIVE[@]}"; do
            sync_archive_source "$src"
        done
        echo
        log_msg "SUCCESS" "Dry-run complete across all exits. No files were modified."
        exit 0
    fi

    # User confirmation prompt
    read -r -p "Proceed with archive transfer for all detected exits? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_msg "INFO" "Archive operation cancelled by user."
        exit 0
    fi

    # Execute synchronization for all sources
    local any_failed=false
    for src in "${SOURCES_TO_ARCHIVE[@]}"; do
        if ! sync_archive_source "$src"; then
            any_failed=true
        fi
    done

    # Create immutable read-only BTRFS snapshot of @archive
    if [ "$CREATE_SNAPSHOT" = true ] && [ -n "$SNAPSHOT_PATH" ] && [ "$any_failed" = false ]; then
        if is_btrfs_subvolume "$SNAPSHOT_PATH" && is_btrfs_subvolume "$DEST_PATH"; then
            local snap_time
            snap_time=$(date +%Y%m%d%H%M%S)
            local snap_target="${SNAPSHOT_PATH%/}/archive-batch-${snap_time}"
            echo
            log_msg "INFO" "Creating immutable read-only BTRFS snapshot: $snap_target"
            if btrfs subvolume snapshot -r "$DEST_PATH" "$snap_target" >/dev/null 2>&1; then
                log_msg "SUCCESS" "Read-only archive snapshot locked: $snap_target"
            else
                log_msg "WARNING" "Could not create read-only snapshot, but archive transfer succeeded."
            fi
        fi
    fi

    echo
    if [ "$any_failed" = true ]; then
        log_msg "WARNING" "Archive finished with warnings or errors. Check logs above."
        exit 1
    else
        log_msg "SUCCESS" "All cold data successfully archived."
        exit 0
    fi
}

main "$@"
