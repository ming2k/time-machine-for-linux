#!/bin/bash

source "${LIB_DIR}/core/logging.sh"

# Check if path is a valid system root by verifying essential directories and files
# FHS: https://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html
is_valid_system_root() {
    local path="$1"
    local required_dirs=("bin" "etc" "lib" "usr")
    local required_files=("etc/fstab" "etc/passwd" "etc/group")
    
    # Check for essential directories
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "${path}/${dir}" ]; then
            log_msg "ERROR" "Essential directory not found: ${path}/${dir}"
            return 1
        fi
    done
    
    # Check for essential files
    for file in "${required_files[@]}"; do
        if [ ! -f "${path}/${file}" ]; then
            log_msg "ERROR" "Essential file not found: ${path}/${file}"
            return 1
        fi
    done
    
    return 0
} 