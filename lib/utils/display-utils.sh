#!/bin/bash

source "${LIB_DIR}/core/colors.sh"

# Print banner with title
print_banner() {
    local title="$1"
    local color="${2:-$BLUE}"  # Default to BLUE if no color specified
    
    echo -e "\n${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${color} $title${NC}"
    echo -e "${BOLD}${BLUE}═══════════════════════════════════════════════════${NC}\n"
}

# Display rule details with customizable header and options
display_rule_details() {
    local title="$1"
    local show_warning="${2:-false}"  # Default: don't show warning
    local warning_msg="${3:-}"        # Optional custom warning message
    local rules_file="$4"            # File containing the rules/patterns
    local source_prefix="${5:-}"      # Optional prefix to strip from display

    print_banner "$title"
    
    # Display patterns from rules file
    if [ -f "$rules_file" ]; then
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            if [[ "$line" =~ ^[[:space:]]*# ]]; then
                echo -e "\n${BOLD}${line#\#}${NC}"
            else
                # If source_prefix is provided, strip it from the display
                if [ -n "$source_prefix" ]; then
                    echo -e " • ${line#$source_prefix/}"
                else
                    echo -e " • ${line}"
                fi
            fi
        done < "$rules_file"
    fi

    # Display warning if enabled
    if [ "$show_warning" = true ] && [ -n "$warning_msg" ]; then
        echo -e "\n${YELLOW}Warning: ${warning_msg}${NC}\n"
    fi
} 