#!/bin/bash

source "$(dirname "$0")/colors.sh"

# Log message with timestamp and appropriate emoji
log_msg() {
    local level=$1
    local msg=$2
    local color=$NC
    local prefix=""
    case $level in
        "INFO") color=$GREEN; prefix="ℹ️ ";;
        "WARNING") color=$YELLOW; prefix="⚠️ ";;
        "ERROR") color=$RED; prefix="❌ ";;
        "SUCCESS") color=$GREEN; prefix="✅ ";;
        "STEP") color=$CYAN; prefix="🔄 ";;
    esac
    echo -e "\n${color}${prefix}[$(date '+%Y-%m-%d %H:%M:%S')] ${msg}${NC}"
} 