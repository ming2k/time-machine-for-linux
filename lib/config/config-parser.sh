#!/bin/bash

source "${LIB_DIR}/core/logging.sh"
source "${LIB_DIR}/fs/fs-utils.sh"

# Parse backup mapping configuration file (source|destination|excludes)
parse_backup_maps() {
    local config_file="$1"
    local -n sources_ref="$2"
    local -n destinations_ref="$3"
    local -n excludes_ref="$4"
    local validate_paths="${5:-true}"  # Optional: validate source paths
    
    if [ ! -f "$config_file" ]; then
        log_msg "ERROR" "Config file not found: $config_file"
        return 1
    fi
    
    # Check if config file is empty
    if [ ! -s "$config_file" ]; then
        log_msg "ERROR" "Config file is empty: $config_file"
        return 1
    fi
    
    log_msg "INFO" "Using config file: $config_file"
    
    # Parse config file and validate entries
    local line_num=0
    local valid_entries=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Split line into source and destination
        IFS='|' read -r src_path dst_path exclude_pattern <<< "$line"
        
        # Trim whitespace
        src_path=$(echo "$src_path" | xargs)
        dst_path=$(echo "$dst_path" | xargs)
        exclude_pattern=$(echo "$exclude_pattern" | xargs)
        
        # Validate source path
        if [ -z "$src_path" ]; then
            log_msg "WARNING" "Line $line_num: Missing source path, skipping"
            continue
        fi
        
        # Validate destination path
        if [ -z "$dst_path" ]; then
            log_msg "WARNING" "Line $line_num: Missing destination path, skipping"
            continue
        fi
        
        # Check if source exists (optional)
        if [ "$validate_paths" = "true" ] && ! check_directory "$src_path"; then
            log_msg "WARNING" "Line $line_num: Invalid source directory, skipping"
            continue
        fi
        
        # Add to valid entries
        sources_ref+=("$src_path")
        destinations_ref+=("$dst_path")
        excludes_ref+=("$exclude_pattern")
        ((valid_entries++))
    done < "$config_file"
    
    if [ $valid_entries -eq 0 ]; then
        log_msg "ERROR" "No valid entries found in config file"
        return 1
    fi
    
    log_msg "INFO" "Found $valid_entries valid backup entries"
    return 0
}

# Parse and validate backup mapping configuration file
parse_backup_mapping() {
    local config_file="$1"
    local -n sources_ref="$2"
    local -n destinations_ref="$3"
    local -n excludes_ref="$4"
    
    if [ ! -f "$config_file" ]; then
        log_msg "ERROR" "Config file not found: $config_file"
        return 1
    fi
    
    # Check if config file is empty
    if [ ! -s "$config_file" ]; then
        log_msg "ERROR" "Config file is empty: $config_file"
        return 1
    fi
    
    log_msg "INFO" "Using config file: $config_file"
    
    # Parse config file and validate entries
    local line_num=0
    local valid_entries=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Split line into source and destination
        IFS='|' read -r src_path dst_path exclude_pattern <<< "$line"
        
        # Trim whitespace
        src_path=$(echo "$src_path" | xargs)
        dst_path=$(echo "$dst_path" | xargs)
        exclude_pattern=$(echo "$exclude_pattern" | xargs)
        
        # Validate source path
        if [ -z "$src_path" ]; then
            log_msg "WARNING" "Line $line_num: Missing source path, skipping"
            continue
        fi
        
        # Validate destination path
        if [ -z "$dst_path" ]; then
            log_msg "WARNING" "Line $line_num: Missing destination path, skipping"
            continue
        fi
        
        # Check if source exists
        if ! check_directory "$src_path"; then
            log_msg "WARNING" "Line $line_num: Invalid source directory, skipping"
            continue
        fi
        
        # Add to valid entries
        sources_ref+=("$src_path")
        destinations_ref+=("$dst_path")
        excludes_ref+=("$exclude_pattern")
        ((valid_entries++))
    done < "$config_file"
    
    if [ $valid_entries -eq 0 ]; then
        log_msg "ERROR" "No valid entries found in config file"
        return 1
    fi
    
    log_msg "INFO" "Found $valid_entries valid backup entries"
    return 0
} 