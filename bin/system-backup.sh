#!/bin/bash

# Get project paths
SCRIPT_PATH="$(readlink -f "$0")"
PROJECT_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"
CONFIG_DIR="${PROJECT_ROOT}/config"

# Load libraries
source "${LIB_DIR}/loader.sh"
if ! load_backup_libs "$LIB_DIR"; then
    echo "Failed to load required libraries" >&2
    exit 1
fi

# Validate system-backup-ignore config exists
CONFIG_FILE="${CONFIG_DIR}/system-backup-ignore"
if [ -f "$CONFIG_FILE" ]; then
    if [ ! -r "$CONFIG_FILE" ]; then
        log_msg "ERROR" "Config file exists but is not readable: $CONFIG_FILE"
        exit 1
    fi
fi

# Check for required commands
check_required_commands() {
    local required_commands=("rsync" "btrfs")
    local missing_commands=()

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done

    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_msg "ERROR" "Missing required commands: ${missing_commands[*]}"
        return 1
    fi
    return 0
}

# Display usage information
usage() {
    echo -e "${BOLD}Usage:${NC} $0 --dest <backup_dir> --snapshots <snapshot_dir> [--source <source_dir>] [OPTIONS]"
    echo
    echo -e "${BOLD}Required Parameters:${NC}"
    echo " --dest <path>       : Destination directory for backup (must be on BTRFS)"
    echo " --snapshots <path>  : Directory for storing snapshots (must be on BTRFS)"
    echo
    echo -e "${BOLD}Optional Parameters:${NC}"
    echo " --source <path>     : Source directory to backup (default: /)"
    echo
    echo -e "${BOLD}Options:${NC}"
    echo " --help, -h          : Show this help message"
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo " $0 --dest /mnt/@backup --snapshots /mnt/@backup_snapshots"
    echo " $0 --dest /mnt/@backup --snapshots /mnt/@backup_snapshots --source /mnt"
    echo " $0 --snapshots /mnt/@backup_snapshots --dest /mnt/@backup --source /"
    echo
    echo -e "${BOLD}Note:${NC} The source directory must be a valid system root containing"
    echo "      essential system directories and files (etc, usr, bin, etc.)"
    exit 1
}

# Validate and optimize exclude patterns (remove duplicates)
validate_exclude_patterns() {
    local exclude_file="$1"
    local validated_file="$2"

    if [ ! -f "$exclude_file" ] || [ ! -s "$exclude_file" ]; then
        touch "$validated_file"
        return 0
    fi

    # Use associative array to track duplicates (requires bash 4+)
    declare -A seen_patterns

    while IFS= read -r line; do
        [[ -z "${line// }" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Skip overly long patterns
        [[ ${#line} -gt 1000 ]] && continue

        # Skip duplicates
        local normalized_pattern="${line// }"
        [[ -n "${seen_patterns[$normalized_pattern]:-}" ]] && continue
        seen_patterns["$normalized_pattern"]=1

        echo "$line" >> "$validated_file"
    done < "$exclude_file"

    return 0
}

# Function to perform system backup
system_backup_function() {
    # Build rsync command as array (safer than eval)
    local -a rsync_cmd=(rsync -aAXHv --numeric-ids --info=progress2 --delete)
    [ -s "$VALIDATED_EXCLUDE_FILE" ] && rsync_cmd+=(--exclude-from="$VALIDATED_EXCLUDE_FILE")

    # Execute rsync
    local rsync_status
    "${rsync_cmd[@]}" "$SOURCE_DIR/" "$BACKUP_DIR/"
    rsync_status=$?

    # Handle specific rsync error codes
    case $rsync_status in
        0)  # Success
            log_msg "SUCCESS" "rsync completed successfully"
            ;;
        23) # Partial transfer due to error
            log_msg "WARNING" "rsync completed with partial transfer"
            log_msg "WARNING" "Some files could not be transferred"
            # Continue with backup as partial transfer might be acceptable
            ;;
        24) # Partial transfer due to vanished source files
            log_msg "WARNING" "rsync completed with partial transfer"
            log_msg "WARNING" "Some source files vanished during transfer"
            # Continue with backup as this is often acceptable
            ;;
        *)  # Other errors
            log_msg "ERROR" "rsync operation failed with status $rsync_status"
            return 1
            ;;
    esac

    # Verify backup integrity
    if ! verify_backup_integrity "$SOURCE_DIR" "$BACKUP_DIR"; then
        log_msg "ERROR" "Backup integrity verification failed"
        return 1
    fi

    return 0
}

# Verify backup integrity
verify_backup_integrity() {
    local source="$1"
    local dest="$2"

    # Check if essential directories exist
    local essential_dirs=("bin" "etc" "usr" "var")
    for dir in "${essential_dirs[@]}"; do
        if [ ! -d "$dest/$dir" ]; then
            log_msg "ERROR" "Essential directory '$dir' missing in backup"
            return 1
        fi
    done

    return 0
}

# Parse command line arguments
parse_arguments() {
    BACKUP_DIR=""
    SNAPSHOT_DIR=""
    SOURCE_DIR="/"  # Default to root filesystem

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
            --source)
                if [ -z "$2" ]; then
                    log_msg "ERROR" "--source requires a path argument"
                    usage
                fi
                SOURCE_DIR="$2"
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
    if [ -z "$BACKUP_DIR" ]; then
        log_msg "ERROR" "Missing required parameter: --dest"
        usage
    fi

    if [ -z "$SNAPSHOT_DIR" ]; then
        log_msg "ERROR" "Missing required parameter: --snapshots"
        usage
    fi
}

# Main script starts here
# ---------------------------

# Parse arguments first to handle --help
parse_arguments "$@"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    log_msg "ERROR" "This script must be run as root"
    exit 1
fi

# Check required commands
if ! check_required_commands; then
    exit 1
fi

# Verify source directory is a valid system root
if ! is_valid_system_root "$SOURCE_DIR"; then
    log_msg "ERROR" "Source directory does not appear to be a valid system root"
    exit 1
fi

# Create temporary files and ensure cleanup
TEMP_EXCLUDE_FILE=$(mktemp)
VALIDATED_EXCLUDE_FILE=$(mktemp)
trap 'rm -f "$TEMP_EXCLUDE_FILE" "$VALIDATED_EXCLUDE_FILE"' EXIT

# Parse exclude configuration
if ! parse_system_exclude_config "${CONFIG_DIR}/system-backup-ignore" "$TEMP_EXCLUDE_FILE"; then
    log_msg "ERROR" "Failed to parse exclude configuration"
    exit 1
fi

if ! validate_exclude_patterns "$TEMP_EXCLUDE_FILE" "$VALIDATED_EXCLUDE_FILE"; then
    log_msg "ERROR" "Failed to validate exclude patterns"
    exit 1
fi

# Display backup details
display_backup_details "system" "$SOURCE_DIR" "$BACKUP_DIR" "$SNAPSHOT_DIR" "$VALIDATED_EXCLUDE_FILE"

# Ask for confirmation before proceeding (with preflight check option)
if confirm_execution "system backup" "n" "system" "$BACKUP_DIR" "$SNAPSHOT_DIR"; then
    # Proceed with backup operations
    # Verify BTRFS requirements
    if ! is_btrfs_filesystem "$BACKUP_DIR" || ! is_btrfs_filesystem "$SNAPSHOT_DIR"; then
        log_msg "ERROR" "Backup and snapshot paths must be on BTRFS filesystems"
        exit 1
    fi
else
    echo "Cancelled"
    exit 1
fi

# Main script execution
if execute_system_backup_with_snapshot "$BACKUP_DIR" "$SNAPSHOT_DIR" system_backup_function; then
    show_backup_results "true" "$SNAPSHOT_DIR" "$TIMESTAMP"
    exit 0
else
    show_backup_results "false" "$SNAPSHOT_DIR" "$TIMESTAMP"
    exit 1
fi
