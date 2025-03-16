#!/bin/bash

# Load a library file with error handling
load_lib() {
    local lib_path="$1"
    local lib_dir="$2"
    
    # Handle both module/file.sh and just file.sh formats
    local full_path
    if [[ "$lib_path" == */* ]]; then
        full_path="${lib_dir}/${lib_path}"
    else
        # Check in each module directory
        for module in core fs config backup ui; do
            if [[ -f "${lib_dir}/${module}/${lib_path}" ]]; then
                full_path="${lib_dir}/${module}/${lib_path}"
                break
            fi
        done
    fi
    
    if [[ ! -f "$full_path" ]]; then
        echo "ERROR: Library not found: $lib_path" >&2
        return 1
    fi
    
    source "$full_path"
    return 0
}

# Load all required libraries for backup scripts
load_backup_libs() {
    local lib_dir="$1"
    local -a required_libs=(
        "core/colors.sh"
        "core/logging.sh"
        "fs/fs-utils.sh"
        "fs/btrfs-utils.sh"
        "config/config-parser.sh"
        "config/config-validator.sh"
        "ui/ui.sh"
        "backup/backup-protection.sh"
    )

    for lib in "${required_libs[@]}"; do
        if ! load_lib "$lib" "$lib_dir"; then
            echo "Failed to load required library: $lib" >&2
            return 1
        fi
    done
    return 0
} 