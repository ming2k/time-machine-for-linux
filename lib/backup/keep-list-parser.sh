#!/bin/bash

# Logging will be available through loader.sh

# Parse keep list file and generate include patterns for rsync
parse_keep_list() {
    local keep_file="$1"
    local temp_include_file="$2"
    local source_path="$3"
    
    # Clear the output file
    > "$temp_include_file"
    
    # Return if keep file doesn't exist
    if [[ ! -f "$keep_file" ]]; then
        log_msg "WARN" "Keep list file not found: $keep_file"
        return 1
    fi
    
    log_msg "INFO" "Processing keep list: $keep_file"
    
    local line_number=0
    local has_includes=false
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_number++))
        
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Remove leading/trailing whitespace
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Skip if line becomes empty after trimming
        if [[ -z "$line" ]]; then
            continue
        fi
        
        # Convert keep pattern to rsync include pattern
        convert_keep_pattern_to_rsync "$line" "$temp_include_file" "$source_path"
        has_includes=true
        
    done < "$keep_file"
    
    if [[ "$has_includes" == true ]]; then
        # Add exclude all pattern at the end to exclude everything not explicitly included
        echo "- *" >> "$temp_include_file"
        log_msg "INFO" "Processed keep list with $(( $(wc -l < "$temp_include_file") - 1 )) include patterns"
    else
        log_msg "WARN" "No valid patterns found in keep list file"
        return 1
    fi
    
    return 0
}

# Convert keep list pattern to rsync include format
convert_keep_pattern_to_rsync() {
    local pattern="$1"
    local output_file="$2"
    local source_path="$3"
    
    # Handle negation (!) - these become excludes
    if [[ "$pattern" =~ ^! ]]; then
        pattern="${pattern#!}"
        pattern=$(echo "$pattern" | sed 's/^[[:space:]]*//')
        echo "- $pattern" >> "$output_file"
        return
    fi
    
    # For directories, we need to include the directory and its parents
    if [[ "$pattern" =~ /$ || -d "$source_path/$pattern" ]]; then
        # Include directory pattern
        local dir_pattern="${pattern%/}"
        
        # Include all parent directories
        local parent_path=""
        IFS='/' read -ra path_parts <<< "$dir_pattern"
        for part in "${path_parts[@]}"; do
            if [[ -n "$part" ]]; then
                if [[ -n "$parent_path" ]]; then
                    parent_path="$parent_path/$part"
                else
                    parent_path="$part"
                fi
                echo "+ $parent_path/" >> "$output_file"
            fi
        done
        
        # Include everything under the directory
        echo "+ $dir_pattern/**" >> "$output_file"
    else
        # For files, include the file and its parent directories
        local file_pattern="$pattern"
        local dir_path=$(dirname "$file_pattern")
        
        # Include parent directories if not root
        if [[ "$dir_path" != "." && "$dir_path" != "/" ]]; then
            local parent_path=""
            IFS='/' read -ra path_parts <<< "$dir_path"
            for part in "${path_parts[@]}"; do
                if [[ -n "$part" ]]; then
                    if [[ -n "$parent_path" ]]; then
                        parent_path="$parent_path/$part"
                    else
                        parent_path="$part"
                    fi
                    echo "+ $parent_path/" >> "$output_file"
                fi
            done
        fi
        
        # Include the file pattern
        echo "+ $file_pattern" >> "$output_file"
    fi
}

# Generate incremental backup includes based on modification time
generate_incremental_includes() {
    local source_path="$1"
    local temp_include_file="$2"
    local last_backup_timestamp="$3"
    local keep_file="${4:-}"
    
    # Clear the output file
    > "$temp_include_file"
    
    log_msg "INFO" "Generating incremental backup includes since: $last_backup_timestamp"
    
    # If keep file exists, filter by keep list first
    if [[ -n "$keep_file" && -f "$keep_file" ]]; then
        local temp_keep_includes=$(mktemp)
        
        if parse_keep_list "$keep_file" "$temp_keep_includes" "$source_path"; then
            # Find files newer than last backup that match keep list
            generate_incremental_with_keep_filter "$source_path" "$temp_include_file" "$last_backup_timestamp" "$temp_keep_includes"
        else
            log_msg "ERROR" "Failed to parse keep list, falling back to full incremental"
            generate_full_incremental "$source_path" "$temp_include_file" "$last_backup_timestamp"
        fi
        
        rm -f "$temp_keep_includes"
    else
        # Generate full incremental backup
        generate_full_incremental "$source_path" "$temp_include_file" "$last_backup_timestamp"
    fi
}

# Generate incremental backup with keep list filtering
generate_incremental_with_keep_filter() {
    local source_path="$1"
    local temp_include_file="$2"
    local last_backup_timestamp="$3"
    local keep_includes_file="$4"
    
    # Create temporary file for changed files
    local temp_changed_files=$(mktemp)
    
    # Find files modified since last backup
    find "$source_path" -type f -newer "$last_backup_timestamp" 2>/dev/null > "$temp_changed_files" || {
        log_msg "WARN" "Could not find files newer than timestamp, using timestamp comparison"
        find "$source_path" -type f -newermt "@$(stat -c %Y "$last_backup_timestamp")" 2>/dev/null > "$temp_changed_files" || {
            log_msg "ERROR" "Failed to find changed files"
            rm -f "$temp_changed_files"
            return 1
        }
    }
    
    # Process each changed file against keep list
    local included_count=0
    while IFS= read -r changed_file; do
        # Make path relative to source
        local rel_path="${changed_file#$source_path/}"
        
        # Check if this file matches any include pattern in keep list
        if check_file_against_keep_list "$rel_path" "$keep_includes_file"; then
            # Include parent directories
            include_parent_directories "$rel_path" "$temp_include_file"
            # Include the file
            echo "+ $rel_path" >> "$temp_include_file"
            ((included_count++))
        fi
    done < "$temp_changed_files"
    
    # Add exclude all pattern at the end
    echo "- *" >> "$temp_include_file"
    
    log_msg "INFO" "Incremental backup will include $included_count changed files"
    rm -f "$temp_changed_files"
}

# Generate full incremental backup (all changed files)
generate_full_incremental() {
    local source_path="$1"
    local temp_include_file="$2"
    local last_backup_timestamp="$3"
    
    # Find all files modified since last backup
    local temp_changed_files=$(mktemp)
    
    find "$source_path" -type f -newer "$last_backup_timestamp" 2>/dev/null > "$temp_changed_files" || {
        find "$source_path" -type f -newermt "@$(stat -c %Y "$last_backup_timestamp")" 2>/dev/null > "$temp_changed_files" || {
            log_msg "ERROR" "Failed to find changed files"
            rm -f "$temp_changed_files"
            return 1
        }
    }
    
    local included_count=0
    while IFS= read -r changed_file; do
        local rel_path="${changed_file#$source_path/}"
        
        # Include parent directories
        include_parent_directories "$rel_path" "$temp_include_file"
        # Include the file
        echo "+ $rel_path" >> "$temp_include_file"
        ((included_count++))
    done < "$temp_changed_files"
    
    # Add exclude all pattern at the end
    echo "- *" >> "$temp_include_file"
    
    log_msg "INFO" "Incremental backup will include $included_count changed files"
    rm -f "$temp_changed_files"
}

# Check if a file matches any pattern in the keep list
check_file_against_keep_list() {
    local file_path="$1"
    local keep_includes_file="$2"
    
    # Use rsync's --dry-run to test if file would be included
    local test_result
    test_result=$(rsync --dry-run --include-from="$keep_includes_file" --exclude="*" "$file_path" /tmp/ 2>/dev/null)
    
    # If rsync would transfer the file, it matches the include patterns
    [[ -n "$test_result" ]]
}

# Include parent directories in the include file
include_parent_directories() {
    local file_path="$1"
    local output_file="$2"
    
    local dir_path=$(dirname "$file_path")
    
    if [[ "$dir_path" != "." && "$dir_path" != "/" ]]; then
        local parent_path=""
        IFS='/' read -ra path_parts <<< "$dir_path"
        for part in "${path_parts[@]}"; do
            if [[ -n "$part" ]]; then
                if [[ -n "$parent_path" ]]; then
                    parent_path="$parent_path/$part"
                else
                    parent_path="$part"
                fi
                # Only add if not already in file
                if ! grep -q "^+ $parent_path/$" "$output_file" 2>/dev/null; then
                    echo "+ $parent_path/" >> "$output_file"
                fi
            fi
        done
    fi
}

# Get the timestamp of the last backup
get_last_backup_timestamp() {
    local backup_dest_path="$1"
    local source_name="$2"
    
    # Look for timestamp marker file
    local timestamp_file="$backup_dest_path/.backup_timestamps/$source_name"
    
    if [[ -f "$timestamp_file" ]]; then
        echo "$timestamp_file"
    else
        # If no timestamp file, create one with current time minus 1 day
        mkdir -p "$(dirname "$timestamp_file")"
        touch -d "1 day ago" "$timestamp_file"
        echo "$timestamp_file"
    fi
}

# Update the timestamp marker for successful backup
update_backup_timestamp() {
    local backup_dest_path="$1"
    local source_name="$2"
    
    local timestamp_file="$backup_dest_path/.backup_timestamps/$source_name"
    mkdir -p "$(dirname "$timestamp_file")"
    touch "$timestamp_file"
    
    log_msg "INFO" "Updated backup timestamp for $source_name"
}