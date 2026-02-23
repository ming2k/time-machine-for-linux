#!/bin/bash

source "${LIB_DIR}/core/logging.sh"
source "${LIB_DIR}/fs/utils.sh"

# Parse system backup exclude configuration
# Usage: parse_system_exclude_config "config_file" "output_file"
parse_system_exclude_config() {
    local config_file="$1"
    local output_file="$2"

    if [ ! -f "$config_file" ]; then
        touch "$output_file"
        return 0
    fi

    if [ ! -r "$config_file" ]; then
        log_msg "ERROR" "Cannot read config file: $config_file"
        return 1
    fi

    # Extract patterns (skip empty lines and comments)
    while IFS= read -r line || [ -n "$line" ]; do
        [[ -z "${line// }" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        echo "$line" >> "$output_file"
    done < "$config_file"

    return 0
}
