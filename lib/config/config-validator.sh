#!/bin/bash

source "$(dirname "$0")/../core/logging.sh"

# Validate config file existence and permissions
validate_config_file() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        log_msg "ERROR" "Config file not found: $config_file"
        return 1
    fi
    
    if [[ ! -r "$config_file" ]]; then
        log_msg "ERROR" "Config file not readable: $config_file"
        return 1
    fi
    
    return 0
}

# Validate backup configuration
validate_backup_config() {
    local config_dir="$1"
    local backup_type="$2"  # "system" or "data"
    local -a required_configs=(
        $(case "$backup_type" in
            "system") echo "backup/system-exclude.conf";;
            "data") echo "backup/data-maps.conf";;
            "restore") echo "restore/exclude.conf restore/system-files.conf";;
        esac)
    )
    
    local failed=0
    for config in "${required_configs[@]}"; do
        if ! validate_config_file "${config_dir}/${config}"; then
            ((failed++))
        fi
    done
    
    return $failed
} 