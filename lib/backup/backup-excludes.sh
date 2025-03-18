#!/bin/bash

source "${LIB_DIR}/core/logging.sh"

# Convert comma-separated exclude patterns into rsync exclude file
convert_patterns_to_rsync_excludes() {
    local exclude_pattern="$1"
    local temp_file="$2"
    
    # Clear the file
    > "$temp_file"
    
    # If no exclude pattern, return empty file
    if [ -z "$exclude_pattern" ]; then
        return 0
    fi
    
    # Split patterns by comma and write to file
    IFS=',' read -ra patterns <<< "$exclude_pattern"
    for pattern in "${patterns[@]}"; do
        # Trim whitespace
        pattern=$(echo "$pattern" | xargs)
        if [ -n "$pattern" ]; then
            echo "$pattern" >> "$temp_file"
        fi
    done
} 