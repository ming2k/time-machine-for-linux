#!/bin/bash

source "${LIB_DIR}/core/logging.sh"

# Parse backup maps configuration
parse_backup_maps() {
    local config_file="$1"
    local -n sources=$2
    local -n destinations=$3
    local -n excludes=$4
    
    if [ ! -f "$config_file" ]; then
        log_msg "ERROR" "Config file not found: $config_file"
        return 1
    fi
    
    local line_num=0
    local valid_entries=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Split line into components
        IFS='|' read -r src_path dst_path exclude_pattern <<< "$line"
        
        # Validate entries
        if [ -z "$src_path" ] || [ -z "$dst_path" ]; then
            log_msg "WARNING" "Line $line_num: Invalid entry, skipping"
            continue
        fi
        
        # Add to arrays
        sources+=("$src_path")
        destinations+=("$dst_path")
        excludes+=("$exclude_pattern")
        ((valid_entries++))
    done < "$config_file"
    
    return $valid_entries
} 