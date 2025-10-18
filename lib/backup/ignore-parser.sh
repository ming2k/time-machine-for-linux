#!/bin/bash

source "${LIB_DIR}/core/logging.sh"

# Parse gitignore-style file and convert to rsync exclude patterns
parse_gitignore_file() {
    local ignore_file="$1"
    local temp_exclude_file="$2"
    local base_path="${3:-}"
    
    # Clear the output file
    > "$temp_exclude_file"
    
    # Return if ignore file doesn't exist
    if [[ ! -f "$ignore_file" ]]; then
        return 0
    fi
    
    local line_number=0
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
        
        # Convert gitignore pattern to rsync exclude pattern
        convert_gitignore_pattern_to_rsync "$line" "$temp_exclude_file" "$base_path"
        
    done < "$ignore_file"
}

# Convert a single gitignore pattern to rsync exclude format
convert_gitignore_pattern_to_rsync() {
    local pattern="$1"
    local output_file="$2"
    local base_path="${3:-}"
    
    local rsync_pattern=""
    local negation=false
    
    # Handle negation (!)
    if [[ "$pattern" =~ ^! ]]; then
        negation=true
        pattern="${pattern#!}"
        # Remove leading whitespace after !
        pattern=$(echo "$pattern" | sed 's/^[[:space:]]*//')
    fi
    
    # Handle patterns starting with /
    if [[ "$pattern" =~ ^/ ]]; then
        # Absolute pattern (relative to repository root)
        pattern="${pattern#/}"
        if [[ -n "$base_path" ]]; then
            # Remove trailing slash from base path to avoid double slashes
            local clean_base_path="${base_path%/}"
            rsync_pattern="$clean_base_path/$pattern"
        else
            rsync_pattern="$pattern"
        fi
    else
        # Relative pattern - matches anywhere in the tree
        rsync_pattern="$pattern"
    fi
    
    # Handle directory patterns (ending with /)
    if [[ "$pattern" =~ /$ ]]; then
        # It's a directory pattern - rsync uses trailing slash differently
        rsync_pattern="${rsync_pattern%/}"
        rsync_pattern="$rsync_pattern/"
    fi
    
    # Handle special gitignore patterns
    case "$pattern" in
        "**/"*)
            # Recursive directory pattern
            rsync_pattern="${pattern#**/}"
            ;;
        *"/**")
            # Everything under directory
            rsync_pattern="${pattern%/**}/**"
            ;;
        *"/**/"*)
            # Complex recursive pattern
            rsync_pattern="$pattern"
            ;;
    esac
    
    # Add negation prefix for rsync if needed
    if [[ "$negation" == true ]]; then
        echo "+ $rsync_pattern" >> "$output_file"
    else
        echo "$rsync_pattern" >> "$output_file"
    fi
}

# Merge multiple ignore sources into a single rsync exclude file
merge_ignore_sources() {
    local temp_exclude_file="$1"
    local base_path="${2:-}"
    shift 2
    local ignore_files=("$@")
    
    # Clear the output file
    > "$temp_exclude_file"
    
    # Process each ignore file
    for ignore_file in "${ignore_files[@]}"; do
        if [[ -f "$ignore_file" ]]; then
            local temp_single=$(mktemp)
            parse_gitignore_file "$ignore_file" "$temp_single" "$base_path"
            
            # Append to main exclude file
            if [[ -s "$temp_single" ]]; then
                cat "$temp_single" >> "$temp_exclude_file"
            fi
            
            rm -f "$temp_single"
        fi
    done
    
    # Add common system excludes
    add_common_excludes "$temp_exclude_file"
}

# Add common system files/directories that should typically be excluded
add_common_excludes() {
    local exclude_file="$1"
    
    cat >> "$exclude_file" << 'EOF'
.git/
.svn/
.hg/
.bzr/
CVS/
.DS_Store
Thumbs.db
desktop.ini
*.tmp
*.temp
*~
.#*
#*#
*.swp
*.swo
*.bak
core
core.*
*.core
EOF
}

# Parse gitignore patterns from backup config inline excludes
parse_inline_excludes() {
    local exclude_patterns="$1"
    local temp_exclude_file="$2"
    local base_path="${3:-}"
    
    # Clear the output file
    > "$temp_exclude_file"
    
    # If no exclude pattern, return empty file
    if [[ -z "$exclude_patterns" ]]; then
        return 0
    fi
    
    # Split patterns by comma and process each
    IFS=',' read -ra patterns <<< "$exclude_patterns"
    for pattern in "${patterns[@]}"; do
        # Trim whitespace
        pattern=$(echo "$pattern" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "$pattern" ]]; then
            convert_gitignore_pattern_to_rsync "$pattern" "$temp_exclude_file" "$base_path"
        fi
    done
}