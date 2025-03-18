#!/bin/bash

source "${LIB_DIR}/core/colors.sh"
source "${LIB_DIR}/utils/display-utils.sh"

# Display backup operation details and ask for confirmation
display_backup_details() {
    local backup_type="$1"      # "system" or "data"
    local source_dir="$2"       # Source directory/directories
    local backup_dir="$3"       # Backup destination path
    local snapshot_dir="$4"     # Snapshot directory
    local temp_exclude_file="$5" # Exclude patterns file
    local sources_ref="$6"      # Optional: Array of sources (for data backup)
    local dests_ref="$7"        # Optional: Array of destinations (for data backup)
    local excludes_ref="$8"     # Optional: Array of excludes (for data backup)

    print_banner "BACKUP CONFIRMATION" "$BLUE"
    
    echo -e "${BOLD}The following backup operation will be performed:${NC}\n"

    if [ "$backup_type" = "system" ]; then
        # System backup display
        echo -e "${CYAN}System Root Directory:${NC} ${BOLD}$source_dir${NC}"
        echo -e "${CYAN}Backup Directory:${NC} ${BOLD}$backup_dir${NC}"
    else
        # Data backup display
        echo -e "${CYAN}Backup Destination Path:${NC} ${BOLD}$backup_dir${NC}"
    fi

    if [ -n "$snapshot_dir" ]; then
        echo -e "${CYAN}Safety Snapshot Base:${NC} ${BOLD}$snapshot_dir${NC}"
    fi

    # Display data backup operations if arrays are provided
    if [ "$backup_type" = "data" ] && [ -n "$sources_ref" ]; then
        local -n srcs=$sources_ref
        local -n dsts=$dests_ref
        local -n excls=$excludes_ref

        echo -e "\n${CYAN}Backup Operations:${NC}"
        for i in "${!srcs[@]}"; do
            local src="${srcs[$i]}"
            local dst="${dsts[$i]}"
            local excludes="${excls[$i]}"
            
            echo -e "\n${BOLD}Backup #$((i+1)):${NC}"
            echo -e "  ${CYAN}Source:${NC} ${BOLD}$src${NC}"
            echo -e "  ${CYAN}Destination:${NC} ${BOLD}$dst${NC}"
            
            if [ -n "$excludes" ]; then
                echo -e "  ${CYAN}Exclude Patterns:${NC} ${BOLD}$excludes${NC}"
            fi
        done
    fi

    # Display exclude patterns and sync warning based on backup type
    if [ "$backup_type" = "system" ]; then
        display_rule_details "EXCLUDED PATTERNS" false "" "$temp_exclude_file" "$source_dir"
        display_rule_details "BACKUP WARNING" true \
            "This operation will synchronize the destination with the source.\nFiles that exist only in the destination will be deleted." ""
    else
        display_rule_details "BACKUP RULES" true \
            "Files will only be added or updated.\nExisting files in the destination will not be deleted." \
            "$temp_exclude_file"
    fi
} 