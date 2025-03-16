#!/bin/bash

source "$(dirname "$0")/../core/logging.sh"

# Check if directory exists and is accessible
check_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        log_msg "ERROR" "Directory does not exist: $dir"
        return 1
    fi
    
    if [ ! -r "$dir" ]; then
        log_msg "ERROR" "Directory is not readable: $dir"
        return 1
    fi
    
    return 0
}

# Check available disk space
check_disk_space() {
    local source_dir="$1"
    local dest_dir="$2"
    
    local required_space=$(df -k "$source_dir" | awk 'NR==2 {print $3}')
    local available_space=$(df -k "$dest_dir" | awk 'NR==2 {print $4}')
    
    log_msg "STEP" "Checking disk space"
    echo -e "Required space : ${BOLD}$(numfmt --to=iec-i --suffix=B $((required_space * 1024)))${NC}"
    echo -e "Available space: ${BOLD}$(numfmt --to=iec-i --suffix=B $((available_space * 1024)))${NC}"
    
    if [ "$available_space" -lt "$required_space" ]; then
        log_msg "ERROR" "Not enough space in destination directory!"
        return 1
    fi
    
    return 0
} 