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
    log_msg "INFO" "Found system backup config: $CONFIG_FILE"
    
    # Quick config file validation
    if [ ! -r "$CONFIG_FILE" ]; then
        log_msg "ERROR" "Config file exists but is not readable: $CONFIG_FILE"
        exit 1
    fi
    
    # Check file size
    config_size=$(stat -f%z "$CONFIG_FILE" 2>/dev/null || stat -c%s "$CONFIG_FILE" 2>/dev/null || echo 0)
    if [ "$config_size" -eq 0 ]; then
        log_msg "WARNING" "Config file is empty: $CONFIG_FILE"
    else
        log_msg "INFO" "Config file size: $(numfmt --to=iec-i --suffix=B "$config_size")"
    fi
else
    log_msg "WARNING" "No system-backup-ignore config found at: $CONFIG_FILE"
    log_msg "INFO" "Will proceed with backup of all system files"
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

# Check available disk space
check_disk_space() {
    local source_dir="$1"
    local dest_dir="$2"
    local required_space
    
    # Get source directory size
    required_space=$(du -sb "$source_dir" | cut -f1)
    
    # Get available space in destination
    local available_space=$(df -B1 "$dest_dir" | awk 'NR==2 {print $4}')
    
    # Add 10% buffer
    required_space=$((required_space * 11 / 10))
    
    if [ "$required_space" -gt "$available_space" ]; then
        log_msg "ERROR" "Insufficient disk space in destination"
        log_msg "ERROR" "Required: $(numfmt --to=iec-i --suffix=B "$required_space")"
        log_msg "ERROR" "Available: $(numfmt --to=iec-i --suffix=B "$available_space")"
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

# Validate and optimize exclude patterns
validate_exclude_patterns() {
    local exclude_file="$1"
    local validated_file="$2"
    
    if [ ! -f "$exclude_file" ] || [ ! -s "$exclude_file" ]; then
        log_msg "INFO" "No exclude patterns to validate"
        touch "$validated_file"
        return 0
    fi
    
    log_msg "INFO" "Validating and optimizing exclude patterns"
    
    local invalid_patterns=0
    local duplicates_removed=0
    local patterns_processed=0
    
    # Use associative array to track duplicates (requires bash 4+)
    declare -A seen_patterns
    
    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "${line// }" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        
        patterns_processed=$((patterns_processed + 1))
        
        # Basic pattern validation
        if [[ ${#line} -gt 1000 ]]; then
            log_msg "WARNING" "Skipping overly long pattern (${#line} chars): ${line:0:50}..."
            invalid_patterns=$((invalid_patterns + 1))
            continue
        fi
        
        # Check for duplicate patterns
        local normalized_pattern="${line// }"
        if [[ -n "${seen_patterns[$normalized_pattern]:-}" ]]; then
            duplicates_removed=$((duplicates_removed + 1))
            continue
        fi
        seen_patterns["$normalized_pattern"]=1
        
        # Add validated pattern
        echo "$line" >> "$validated_file"
        
    done < "$exclude_file"
    
    local final_patterns=$(grep -v '^[[:space:]]*$' "$validated_file" 2>/dev/null | wc -l)
    
    log_msg "INFO" "Pattern validation complete:"
    log_msg "INFO" "  Patterns processed: $patterns_processed"
    log_msg "INFO" "  Final patterns: $final_patterns"
    [ "$duplicates_removed" -gt 0 ] && log_msg "INFO" "  Duplicates removed: $duplicates_removed"
    [ "$invalid_patterns" -gt 0 ] && log_msg "WARNING" "  Invalid patterns skipped: $invalid_patterns"
    
    return 0
}

# Function to perform system backup
system_backup_function() {
    local rsync_cmd="rsync -aAXHv --info=progress2"
    [ "$delete_flag" = "true" ] && rsync_cmd+=" --delete"
    [ -s "$VALIDATED_EXCLUDE_FILE" ] && rsync_cmd+=" --exclude-from='$VALIDATED_EXCLUDE_FILE'"
    
    # Execute rsync with progress visible and error capture
    local rsync_status
    eval "$rsync_cmd '$SOURCE_DIR/' '$BACKUP_DIR/'" 2> >(tee -a >(grep -v '^[[:space:]]*$' >&2) > /dev/null) | tee /dev/tty
    rsync_status=${PIPESTATUS[0]}
    
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

# Print header
print_banner "SYSTEM BACKUP UTILITY" "$BLUE"

# Check required commands
if ! check_required_commands; then
    exit 1
fi

# Verify source directory is a valid system root
log_msg "INFO" "Verifying system root directory"
if ! is_valid_system_root "$SOURCE_DIR"; then
    log_msg "ERROR" "Source directory does not appear to be a valid system root"
    exit 1
fi

# Create temporary files and ensure cleanup
TEMP_EXCLUDE_FILE=$(mktemp)
VALIDATED_EXCLUDE_FILE=$(mktemp)
trap 'rm -f "$TEMP_EXCLUDE_FILE" "$VALIDATED_EXCLUDE_FILE"' EXIT

# Parse and validate exclude configuration
parse_exclude_config() {
    local config_file="${CONFIG_DIR}/system-backup-ignore"
    local temp_file="$1"
    
    if [ ! -f "$config_file" ]; then
        log_msg "WARNING" "No system-backup-ignore config found at: $config_file"
        log_msg "INFO" "Creating empty exclude list - will backup everything"
        touch "$temp_file"
        return 0
    fi
    
    log_msg "INFO" "Parsing exclude configuration: $config_file"
    
    # Validate config file is readable
    if [ ! -r "$config_file" ]; then
        log_msg "ERROR" "Cannot read config file: $config_file"
        return 1
    fi
    
    # Process config file and count patterns
    local total_lines=0
    local comment_lines=0
    local empty_lines=0
    local pattern_lines=0
    local negation_patterns=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        total_lines=$((total_lines + 1))
        
        # Skip empty lines
        if [[ -z "${line// }" ]]; then
            empty_lines=$((empty_lines + 1))
            continue
        fi
        
        # Skip comments
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            comment_lines=$((comment_lines + 1))
            continue
        fi
        
        # Count negation patterns
        if [[ "$line" =~ ^[[:space:]]*! ]]; then
            negation_patterns=$((negation_patterns + 1))
        fi
        
        # Add valid patterns to temp file
        echo "$line" >> "$temp_file"
        pattern_lines=$((pattern_lines + 1))
        
    done < "$config_file"
    
    # Display parsing statistics
    log_msg "INFO" "Config parsing complete:"
    log_msg "INFO" "  Total lines: $total_lines"
    log_msg "INFO" "  Active patterns: $pattern_lines"
    log_msg "INFO" "  Negation patterns: $negation_patterns"
    log_msg "INFO" "  Comments: $comment_lines"
    log_msg "INFO" "  Empty lines: $empty_lines"
    
    # Show preview of active patterns (first 5)
    if [ "$pattern_lines" -gt 0 ]; then
        log_msg "INFO" "Preview of exclude patterns:"
        grep -v '^[[:space:]]*$' "$temp_file" | grep -v '^[[:space:]]*#' | head -5 | while read -r pattern; do
            log_msg "INFO" "  → $pattern"
        done
        
        if [ "$pattern_lines" -gt 5 ]; then
            log_msg "INFO" "  ... and $((pattern_lines - 5)) more patterns"
        fi
    else
        log_msg "WARNING" "No active exclude patterns found - will backup everything"
    fi
    
    return 0
}

# Generate and validate exclude list
log_msg "INFO" "Processing system backup exclude configuration"
if ! parse_exclude_config "$TEMP_EXCLUDE_FILE"; then
    log_msg "ERROR" "Failed to parse exclude configuration"
    exit 1
fi

# Validate and optimize exclude patterns
if ! validate_exclude_patterns "$TEMP_EXCLUDE_FILE" "$VALIDATED_EXCLUDE_FILE"; then
    log_msg "ERROR" "Failed to validate exclude patterns"
    exit 1
fi

# Log the resolved source directory
log_msg "INFO" "Source directory: $SOURCE_DIR"
if [ "$SOURCE_DIR" = "/" ]; then
    log_msg "INFO" "Using default root filesystem as source"
fi

# Display backup details
display_backup_details "system" "$SOURCE_DIR" "$BACKUP_DIR" "$SNAPSHOT_DIR" "$VALIDATED_EXCLUDE_FILE"

# Ask for confirmation before proceeding
if confirm_execution "system backup" "n"; then
    # Proceed with backup operations
    # Verify BTRFS requirements
    if ! is_btrfs_filesystem "$BACKUP_DIR" || ! is_btrfs_filesystem "$SNAPSHOT_DIR"; then
        log_msg "ERROR" "Backup and snapshot paths must be on BTRFS filesystems"
        exit 1
    fi

    # Check available disk space
    # Rsync is incremental, so we don't need to check disk space
    # if ! check_disk_space "$SOURCE_DIR" "$BACKUP_DIR"; then
    #     exit 1
    # fi
else
    log_msg "INFO" "Backup operation cancelled by user"
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
