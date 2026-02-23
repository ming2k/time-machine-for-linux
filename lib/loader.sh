#!/bin/bash

# Library Loader for Time Machine for Linux
# Automatically discovers and loads modules across different directories

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

# Library loading functions

load_backup_libs() {
    local lib_dir="$1"
    if [ -z "$lib_dir" ]; then
        lib_dir="$LIB_DIR"
    fi
    
    # Core libraries (always needed)
    local core_libs=(
        "core/colors.sh"
        "core/logging.sh"
    )
    
    # Backup-specific libraries
    local backup_libs=(
        "fs/btrfs.sh"
        "fs/utils.sh"
        "config/parser.sh"
        "config/validator.sh"
        "backup/backup-executor.sh"
        "backup/backup-protection.sh"
        "backup/backup-display.sh"
        "utils/validation.sh"
        "utils/preflight-checks.sh"
        "utils/confirm-execution.sh"
        "utils/display-utils.sh"
        "utils/rsync-utils.sh"
    )
    
    # Load core libraries first
    for lib in "${core_libs[@]}"; do
        local lib_path="$lib_dir/$lib"
        if [ -f "$lib_path" ]; then
            # shellcheck source=/dev/null
            source "$lib_path" || {
                echo "ERROR: Failed to load core library: $lib" >&2
                return 1
            }
        else
            echo "ERROR: Core library not found: $lib_path" >&2
            return 1
        fi
    done
    
    # Load backup libraries
    for lib in "${backup_libs[@]}"; do
        local lib_path="$lib_dir/$lib"
        if [ -f "$lib_path" ]; then
            # shellcheck source=/dev/null
            source "$lib_path" || {
                echo "ERROR: Failed to load backup library: $lib" >&2
                return 1
            }
        else
            echo "WARNING: Optional library not found: $lib_path" >&2
        fi
    done
    
    return 0
}

load_restore_libs() {
    local lib_dir="$1"
    if [ -z "$lib_dir" ]; then
        lib_dir="$LIB_DIR"
    fi
    
    # Core libraries (always needed)
    local core_libs=(
        "core/colors.sh"
        "core/logging.sh"
    )
    
    # Restore-specific libraries
    local restore_libs=(
        "fs/btrfs.sh"
        "fs/utils.sh"
        "config/parser.sh"
        "config/validator.sh"
        "utils/validation.sh"
        "utils/preflight-checks.sh"
        "utils/confirm-execution.sh"
        "utils/display-utils.sh"
    )
    
    # Load core libraries first
    for lib in "${core_libs[@]}"; do
        local lib_path="$lib_dir/$lib"
        if [ -f "$lib_path" ]; then
            # shellcheck source=/dev/null
            source "$lib_path" || {
                echo "ERROR: Failed to load core library: $lib" >&2
                return 1
            }
        else
            echo "ERROR: Core library not found: $lib_path" >&2
            return 1
        fi
    done
    
    # Load restore libraries
    for lib in "${restore_libs[@]}"; do
        local lib_path="$lib_dir/$lib"
        if [ -f "$lib_path" ]; then
            # shellcheck source=/dev/null
            source "$lib_path" || {
                echo "ERROR: Failed to load restore library: $lib" >&2
                return 1
            }
        else
            echo "WARNING: Optional library not found: $lib_path" >&2
        fi
    done
    
    return 0
}

# Auto-discovery function for all modules
discover_modules() {
    local lib_dir="$1"
    if [ -z "$lib_dir" ]; then
        lib_dir="$LIB_DIR"
    fi
    
    local modules=()
    
    # Discover modules in standard directories
    local search_dirs=("core" "fs" "config" "backup" "ui" "utils")
    
    for dir in "${search_dirs[@]}"; do
        if [ -d "$lib_dir/$dir" ]; then
            while IFS= read -r -d '' file; do
                if [[ "$file" == *.sh ]]; then
                    modules+=("${file#$lib_dir/}")
                fi
            done < <(find "$lib_dir/$dir" -name "*.sh" -type f -print0)
        fi
    done
    
    printf '%s\n' "${modules[@]}"
}