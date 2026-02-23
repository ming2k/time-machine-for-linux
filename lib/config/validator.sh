#!/bin/bash

source "${LIB_DIR}/core/logging.sh"

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
