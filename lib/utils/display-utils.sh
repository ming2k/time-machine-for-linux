#!/bin/bash

source "${LIB_DIR}/core/colors.sh"

# Print simple section header
print_banner() {
    local title="$1"
    echo -e "\n${BOLD}${title}${NC}"
    echo -e "${DIM}─────────────────────────────────${NC}"
} 