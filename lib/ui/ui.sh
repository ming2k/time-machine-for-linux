#!/bin/bash

source "${LIB_DIR}/core/colors.sh"

# Print header banner
print_header() {
    local title="$1"
    echo -e "\n${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${BLUE} $title${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}\n"
}

# Print footer banner
print_footer() {
    local status="$1"
    echo -e "\n${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${GREEN} $status${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}\n"
}

# Display backup operation details and ask for confirmation
confirm_backup() {
    local backup_type="$1"
    local source="$2"
    local dest="$3"
    local snapshot_dir="$4"
    
    print_header "${backup_type} BACKUP CONFIRMATION"
    
    echo -e "${BOLD}The following backup operation will be performed:${NC}\n"
    echo -e "${CYAN}Source:${NC} ${BOLD}$source${NC}"
    echo -e "${CYAN}Destination:${NC} ${BOLD}$dest${NC}"
    
    if [ -n "$snapshot_dir" ]; then
        echo -e "${CYAN}Snapshots:${NC} ${BOLD}$snapshot_dir${NC}"
    fi
    
    echo -e "\n${YELLOW}⚠️  Warning: This operation will synchronize the destination with the source.${NC}"
    echo -e "${YELLOW}   Files that exist only in the destination will be deleted.${NC}\n"
    
    read -p "Do you want to proceed? (y/N) " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
    return $?
} 