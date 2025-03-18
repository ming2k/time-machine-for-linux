generate_prefixed_exclude_list() {
    local source_path="$1"
    local temp_exclude_file="$2"
    local exclude_config="$3"
    
    # Check if exclude config exists
    if [ ! -f "$exclude_config" ]; then
        log_msg "ERROR" "Exclude list file not found: $exclude_config"
        exit 1
    fi
    
    # Remove trailing slash from source path if present
    source_path="${source_path%/}"
    
    # Create temporary exclude file with prefixed paths
    > "$temp_exclude_file"  # Clear the file first
    
    while IFS= read -r line; do
        # Preserve comments and empty lines
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            echo "$line" >> "$temp_exclude_file"
            continue
        fi
        
        # Remove leading slash if present
        line="${line#/}"
        # Add source path prefix
        echo "${source_path}/${line}" >> "$temp_exclude_file"
    done < "$exclude_config"
}
