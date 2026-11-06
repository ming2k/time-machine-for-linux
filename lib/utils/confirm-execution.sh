#!/bin/bash

# Confirm execution with automatic preflight checks
# Usage: confirm_execution "operation_name" "default_response" ["backup_type" "dest_path" "snapshot_path"]
confirm_execution() {
    local operation_name="$1"
    local default_response="${2:-n}"  # Default to 'n' if not specified
    local backup_type="$3"            # Optional: for preflight checks
    local dest_path="$4"              # Optional: for preflight checks
    local snapshot_path="$5"          # Optional: for preflight checks

    # Convert default response to lowercase
    default_response=$(echo "$default_response" | tr '[:upper:]' '[:lower:]')

    # Run preflight checks and auto-show if there are warnings/critical issues
    if [ -n "$backup_type" ] && [ -n "$dest_path" ] && [ -n "$snapshot_path" ]; then
        run_preflight_checks "$backup_type" "$dest_path" "$snapshot_path"

        # Check if there are any WARNING or CRITICAL notices
        local has_issues=false
        for severity in "${PREFLIGHT_SEVERITIES[@]}"; do
            if [ "$severity" = "WARNING" ] || [ "$severity" = "CRITICAL" ]; then
                has_issues=true
                break
            fi
        done

        # Auto-show preflight info if there are issues
        if [ "$has_issues" = true ]; then
            show_preflight_info
        fi
    fi

    # Set prompt
    local prompt
    if [ "$default_response" = "y" ]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi

    while true; do
        read -p "Proceed with ${operation_name}? ${prompt} " response

        # If empty response, use default
        if [ -z "$response" ]; then
            response=$default_response
        fi

        # Convert response to lowercase
        response=$(echo "$response" | tr '[:upper:]' '[:lower:]')

        case $response in
            y|yes)
                return 0
                ;;
            n|no)
                echo "Operation cancelled by user."
                return 1
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

# Explicit confirmation for disaster-level restore operations [INV-RESTORE-02]
# Strictly requires exact case-sensitive uppercase 'YES'. Rejects default Enter, 'y', 'yes', or any other input.
# Usage: confirm_restore_execution "tier_name" "source_path" "dest_path" ["snapshot_path"]
confirm_restore_execution() {
    local tier_name="$1"
    local source_path="$2"
    local dest_path="$3"
    local snapshot_path="${4:-}"

    echo
    echo -e "${RED}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}${BOLD} ⚠  RESTORE CONFIRMATION REQUIRED  ⚠${NC}"
    echo -e "${RED}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}${BOLD}CAUTION: Restore will overwrite existing files on destination!${NC}"
    echo -e "${BOLD}Tier:${NC}                ${tier_name}"
    echo -e "${BOLD}Source Mirror:${NC}       ${source_path}"
    echo -e "${BOLD}Destination Target:${NC}  ${RED}${BOLD}${dest_path}${NC}"
    if [ -n "$snapshot_path" ]; then
        echo -e "${BOLD}Pre-Restore Snapshot:${NC} ${GREEN}${snapshot_path}${NC}"
    else
        echo -e "${BOLD}Pre-Restore Snapshot:${NC} ${RED}${BOLD}NONE (Running without safety rollback snapshot)${NC}"
    fi
    echo
    echo -e "${YELLOW}To authorize this operation, type uppercase ${RED}'YES'${NC}${YELLOW} (Enter or 'y' aborts):${NC}"

    read -r -p "Confirm restore? " response

    if [ "$response" = "YES" ]; then
        return 0
    else
        echo -e "${YELLOW}Restore operation cancelled by operator (input was not 'YES').${NC}"
        return 1
    fi
}
