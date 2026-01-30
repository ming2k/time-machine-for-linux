#!/bin/bash

source "${LIB_DIR}/core/colors.sh"
source "${LIB_DIR}/utils/display-utils.sh"

# Display backup operation details
display_backup_details() {
    local backup_type="$1"      # "system" or "data"
    local source_dir="$2"       # Source directory/directories
    local backup_dir="$3"       # Backup destination path
    local snapshot_dir="$4"     # Snapshot directory
    local temp_exclude_file="$5" # Exclude patterns file (optional)

    print_banner "System Backup"

    echo -e "Source:       ${BOLD}$source_dir${NC}"
    echo -e "Destination:  ${BOLD}$backup_dir${NC}"
    echo -e "Snapshots:    ${BOLD}$snapshot_dir${NC}"

    # Show pattern count if exclude file exists
    if [ -f "$temp_exclude_file" ] && [ -s "$temp_exclude_file" ]; then
        local pattern_count=$(wc -l < "$temp_exclude_file")
        echo -e "Excludes:     ${BOLD}$pattern_count patterns${NC}"
    fi

    # Show warning for system backup (uses --delete)
    if [ "$backup_type" = "system" ]; then
        echo -e "\n${YELLOW}[WARN]${NC}  Mirror mode: files not in source will be deleted"
    fi
    echo ""
} 