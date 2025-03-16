#!/bin/bash

# Use absolute path from LIB_DIR
source "${LIB_DIR}/core/colors.sh"

# Log message with timestamp and level
log_msg() {
    local level=$1
    local msg=$2
    local color=$NC
    
    case $level in
        "INFO") color=$NC;;
        "WARNING") color=$YELLOW;;
        "ERROR") color=$RED;;
        "SUCCESS") color=$GREEN;;
    esac
    
    # Format: [date] [level] message
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${msg}${NC}"
}

# Print raw message without timestamp and level (for special formatting)
print_raw() {
    local msg="$1"
    echo -e "$msg"
}

# Print indented message with consistent formatting
print_info() {
    local msg="$1"
    log_msg "INFO" "  ${msg}"
} 