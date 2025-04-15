#!/bin/bash

source "${LIB_DIR}/core/logging.sh"
source "${LIB_DIR}/backup/ignore-parser.sh"

# Convert comma-separated exclude patterns into rsync exclude file (legacy support)
convert_patterns_to_rsync_excludes() {
    local exclude_pattern="$1"
    local temp_file="$2"
    local source_path="${3:-}"
    
    # Use the new gitignore-style parser for inline patterns
    parse_inline_excludes "$exclude_pattern" "$temp_file" "$source_path"
}

# Enhanced function to handle both inline patterns and ignore files
process_backup_excludes() {
    local source_path="$1"
    local inline_excludes="$2"
    local temp_exclude_file="$3"
    local custom_ignore_file="${4:-}"
    
    # Array to store all ignore file sources
    local ignore_files=()
    
    # Look for .backupignore file in source directory
    local source_ignore_file="$source_path/.backupignore"
    if [[ -f "$source_ignore_file" ]]; then
        ignore_files+=("$source_ignore_file")
        log_msg "INFO" "Found .backupignore in $source_path"
    fi
    
    # Add custom ignore file if specified
    if [[ -n "$custom_ignore_file" && -f "$custom_ignore_file" ]]; then
        ignore_files+=("$custom_ignore_file")
        log_msg "INFO" "Using custom ignore file: $custom_ignore_file"
    fi
    
    # Check for global backup ignore file
    local global_ignore_file="${PROJECT_ROOT}/config/backup/.backupignore"
    if [[ -f "$global_ignore_file" ]]; then
        ignore_files+=("$global_ignore_file")
        log_msg "INFO" "Using global backup ignore file"
    fi
    
    # If we have ignore files, use the gitignore parser
    if [[ ${#ignore_files[@]} -gt 0 ]]; then
        merge_ignore_sources "$temp_exclude_file" "" "${ignore_files[@]}"
        
        # Also process inline excludes if provided
        if [[ -n "$inline_excludes" ]]; then
            local temp_inline=$(mktemp)
            parse_inline_excludes "$inline_excludes" "$temp_inline" ""
            
            # Append inline excludes to the main file
            if [[ -s "$temp_inline" ]]; then
                cat "$temp_inline" >> "$temp_exclude_file"
            fi
            rm -f "$temp_inline"
        fi
    else
        # Fall back to legacy inline pattern processing
        convert_patterns_to_rsync_excludes "$inline_excludes" "$temp_exclude_file" "$source_path"
    fi
} 