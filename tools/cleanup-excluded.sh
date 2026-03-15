#!/bin/bash

# cleanup-excluded.sh - Remove excluded files from backup destination
#
# When exclude patterns are added to config after files were already backed up,
# those files remain in the backup destination (rsync --delete won't touch them
# because excluded files are invisible to rsync). This tool finds and removes them.

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Respect NO_COLOR
if [[ -n "${NO_COLOR:-}" ]] || [[ "${TERM:-}" == "dumb" ]]; then
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' DIM='' NC=''
fi

log_msg() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        "ERROR")   echo -e "${RED}[ERROR]${NC} $timestamp - $message" >&2 ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $timestamp - $message" ;;
        "WARNING") echo -e "${YELLOW}[WARNING]${NC} $timestamp - $message" ;;
        "INFO")    echo -e "${BLUE}[INFO]${NC} $timestamp - $message" ;;
    esac
}

show_usage() {
    echo -e "${BOLD}Usage:${NC} $0 --dest <backup_dir> --config <exclude_config> [--execute]"
    echo
    echo -e "${BOLD}Description:${NC}"
    echo "  Find and remove files from backup destination that match exclude patterns."
    echo "  When patterns are added to the exclude config after files have been backed up,"
    echo "  those files remain in the destination. This tool cleans them up."
    echo
    echo -e "${BOLD}Required Parameters:${NC}"
    echo "  --dest <path>       Backup destination directory to clean"
    echo "  --config <path>     Exclude configuration file"
    echo
    echo -e "${BOLD}Options:${NC}"
    echo "  --execute           Actually delete files (default: preview only)"
    echo "  --help, -h          Show this help message"
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo "  # Preview what would be cleaned from home backup"
    echo "  $0 --dest /mnt/@home --config config/home-backup-ignore"
    echo
    echo "  # Actually clean excluded files from system backup"
    echo "  $0 --dest /mnt/@system --config config/system-backup-ignore --execute"
}

# Parse a pattern into its type flags (modifies caller variables)
# Sets: clean, is_dir_only
parse_pattern_flags() {
    local pattern="$1"
    is_dir_only=false
    clean="$pattern"

    if [[ "$clean" == */\* ]]; then
        is_dir_only=true
        clean="${clean%/\*}"
    elif [[ "$clean" == */.\* ]]; then
        is_dir_only=true
        clean="${clean%/.\*}"
    elif [[ "$clean" == */ ]]; then
        is_dir_only=true
        clean="${clean%/}"
    fi
}

# Find all matches in one pass:
# 1. Absolute patterns without wildcards → direct stat (instant)
# 2. Everything else → single find command with -o (one traversal)
find_all_matches() {
    local dest="$1"
    shift
    local -a patterns=("$@")

    local -a find_exprs=()
    local has_find_patterns=false
    local clean is_dir_only

    for pattern in "${patterns[@]}"; do
        # Skip negation patterns
        [[ "$pattern" == !* ]] && continue

        parse_pattern_flags "$pattern"

        if [[ "$clean" == /* ]]; then
            # --- Absolute pattern ---
            if [[ "$clean" == *'*'* ]]; then
                # Wildcards in path → needs find
                if $has_find_patterns; then
                    find_exprs+=(-o)
                fi
                has_find_patterns=true
                if $is_dir_only; then
                    find_exprs+=(\( -path "${dest}${clean}" -type d \))
                else
                    find_exprs+=(\( -path "${dest}${clean}" \))
                fi
            else
                # Direct path → instant stat check
                local target="${dest}${clean}"
                if [[ -e "$target" ]]; then
                    echo "$target"
                fi
            fi
        else
            # --- Relative pattern ---
            if $has_find_patterns; then
                find_exprs+=(-o)
            fi
            has_find_patterns=true

            if [[ "$clean" == *'/'* ]]; then
                # Multi-component path (e.g. .npm/_cacache, .local/share/Trash)
                if $is_dir_only; then
                    find_exprs+=(\( -path "*/${clean}" -type d \))
                else
                    find_exprs+=(\( -path "*/${clean}" \))
                fi
            elif [[ "$clean" == *'*'* ]]; then
                # Glob pattern (e.g. *.swap)
                find_exprs+=(\( -name "$clean" \))
            else
                # Simple name (e.g. .cache, node_modules, lost+found)
                if $is_dir_only; then
                    find_exprs+=(\( -name "$clean" -type d \))
                else
                    find_exprs+=(\( -name "$clean" \))
                fi
            fi
        fi
    done

    # Run single find for all non-direct patterns
    if $has_find_patterns; then
        find "$dest" -mindepth 1 \( "${find_exprs[@]}" \) 2>/dev/null || true
    fi
}

# Remove child paths when a parent is already in the list
# e.g. if /mnt/@home/.cache is listed, skip /mnt/@home/.cache/chromium
prune_nested_paths() {
    local -a sorted_paths=()
    while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        sorted_paths+=("$p")
    done

    local count=${#sorted_paths[@]}
    for ((i = 0; i < count; i++)); do
        local current="${sorted_paths[$i]}"
        local is_child=false

        for ((j = 0; j < count; j++)); do
            [[ $i -eq $j ]] && continue
            local other="${sorted_paths[$j]}"
            # Check if current is a child of other (other is shorter prefix)
            if [[ "${#other}" -lt "${#current}" && "$current" == "$other"/* ]]; then
                is_child=true
                break
            fi
        done

        $is_child || echo "$current"
    done
}

main() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi

    # Handle help before root check
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" || "$arg" == "help" ]]; then
            show_usage
            exit 0
        fi
    done

    # Check root
    if [[ "$EUID" -ne 0 ]]; then
        log_msg "ERROR" "This tool requires root privileges. Please run with sudo."
        exit 1
    fi

    # Parse arguments
    local dest="" config="" execute=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dest)
                [[ $# -lt 2 ]] && { log_msg "ERROR" "--dest requires a path argument"; exit 1; }
                dest="$2"
                shift 2
                ;;
            --config)
                [[ $# -lt 2 ]] && { log_msg "ERROR" "--config requires a path argument"; exit 1; }
                config="$2"
                shift 2
                ;;
            --execute)
                execute=true
                shift
                ;;
            -h|--help|help)
                show_usage
                exit 0
                ;;
            *)
                log_msg "ERROR" "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Validate required parameters
    if [[ -z "$dest" ]]; then
        log_msg "ERROR" "Missing required parameter: --dest"
        show_usage
        exit 1
    fi

    if [[ -z "$config" ]]; then
        log_msg "ERROR" "Missing required parameter: --config"
        show_usage
        exit 1
    fi

    # Validate paths
    if [[ ! -d "$dest" ]]; then
        log_msg "ERROR" "Destination directory does not exist: $dest"
        exit 1
    fi

    if [[ ! -f "$config" ]]; then
        log_msg "ERROR" "Config file does not exist: $config"
        exit 1
    fi

    if [[ ! -r "$config" ]]; then
        log_msg "ERROR" "Config file is not readable: $config"
        exit 1
    fi

    # Remove trailing slash from dest for consistent path joining
    dest="${dest%/}"

    # Parse patterns from config
    local -a patterns=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "${line// }" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        patterns+=("$line")
    done < "$config"

    if [[ ${#patterns[@]} -eq 0 ]]; then
        log_msg "WARNING" "No patterns found in config file"
        exit 0
    fi

    log_msg "INFO" "Scanning destination for excluded files..."
    log_msg "INFO" "Destination: $dest"
    log_msg "INFO" "Config: $config"
    log_msg "INFO" "Patterns: ${#patterns[@]}"
    echo

    # Find all matches (global for trap access)
    matches_file=$(mktemp)
    trap 'rm -f "$matches_file"' EXIT

    find_all_matches "$dest" "${patterns[@]}" > "$matches_file"

    # Deduplicate and prune nested paths
    local -a final_paths=()
    while IFS= read -r path; do
        [[ -z "$path" ]] && continue
        final_paths+=("$path")
    done < <(sort -u "$matches_file" | prune_nested_paths)

    if [[ ${#final_paths[@]} -eq 0 ]]; then
        log_msg "SUCCESS" "No excluded files found in destination. Already clean!"
        exit 0
    fi

    # Display matches with sizes
    echo -e "${BOLD}Files matching exclude patterns:${NC}"
    echo

    local total_size=0
    for path in "${final_paths[@]}"; do
        local size human_size
        size=$(du -sb "$path" 2>/dev/null | cut -f1) || size=0
        human_size=$(du -sh "$path" 2>/dev/null | cut -f1) || human_size="?"
        total_size=$((total_size + size))

        if [[ -d "$path" ]]; then
            echo -e "  ${YELLOW}${human_size}${NC}\t${DIM}[dir]${NC}  ${path}/"
        else
            echo -e "  ${YELLOW}${human_size}${NC}\t${DIM}[file]${NC} ${path}"
        fi
    done

    echo
    local human_total
    human_total=$(numfmt --to=iec "$total_size" 2>/dev/null) || human_total="${total_size} bytes"
    echo -e "${BOLD}Total: ${YELLOW}${human_total}${NC} in ${BOLD}${#final_paths[@]}${NC} items"
    echo

    if $execute; then
        echo -e "${RED}${BOLD}This will permanently delete the above files from the backup destination.${NC}"
        read -r -p "Continue? [y/N] " confirm
        if [[ "$confirm" == [yY] ]]; then
            echo
            local deleted=0 failed=0
            for path in "${final_paths[@]}"; do
                if rm -rf "$path" 2>/dev/null; then
                    log_msg "INFO" "Deleted: $path"
                    ((++deleted))
                else
                    log_msg "ERROR" "Failed to delete: $path"
                    ((++failed))
                fi
            done
            echo
            log_msg "SUCCESS" "Cleanup complete: $deleted deleted, $failed failed"
        else
            echo "Cancelled."
        fi
    else
        log_msg "INFO" "Preview mode. Use ${BOLD}--execute${NC} to actually delete."
    fi
}

main "$@"
