#!/bin/bash

# Backup state management for data backups
# Tracks backup mappings to detect orphaned destinations

source "${LIB_DIR}/core/logging.sh"

STATE_FILE_NAME=".backup-state.json"
STATE_VERSION=1

# Check if jq is available
check_jq_available() {
    if ! command -v jq &>/dev/null; then
        log_msg "ERROR" "jq is required for state management but not installed"
        log_msg "INFO" "Install with: sudo apt install jq (Debian/Ubuntu) or sudo dnf install jq (Fedora)"
        return 1
    fi
    return 0
}

# Get the state file path for a backup destination
get_state_file_path() {
    local dest_path="$1"
    echo "${dest_path%/}/${STATE_FILE_NAME}"
}

# Read existing backup state
# Returns: JSON content on stdout, or empty if no state exists
read_backup_state() {
    local dest_path="$1"
    local state_file
    state_file=$(get_state_file_path "$dest_path")

    if [[ ! -f "$state_file" ]]; then
        return 1
    fi

    if ! check_jq_available; then
        return 1
    fi

    # Validate JSON
    if ! jq empty "$state_file" 2>/dev/null; then
        log_msg "WARNING" "State file is malformed, treating as first run"
        return 1
    fi

    cat "$state_file"
    return 0
}

# Update backup state after successful backup
# Usage: update_backup_state dest_path sources_array destinations_array
update_backup_state() {
    local dest_path="$1"
    shift
    local -n _sources=$1
    shift
    local -n _destinations=$1

    if ! check_jq_available; then
        log_msg "WARNING" "Cannot update backup state: jq not available"
        return 1
    fi

    local state_file
    state_file=$(get_state_file_path "$dest_path")
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Build mappings array
    local mappings_json="["
    local first=true
    for ((i=0; i<${#_sources[@]}; i++)); do
        if [[ "$first" != "true" ]]; then
            mappings_json+=","
        fi
        first=false
        # Escape strings for JSON
        local src_escaped
        local dst_escaped
        src_escaped=$(printf '%s' "${_sources[i]}" | jq -Rs '.')
        dst_escaped=$(printf '%s' "${_destinations[i]}" | jq -Rs '.')
        mappings_json+="{\"source\":${src_escaped},\"dest\":${dst_escaped}}"
    done
    mappings_json+="]"

    # Create state JSON
    local state_json
    state_json=$(jq -n \
        --argjson version "$STATE_VERSION" \
        --arg last_backup "$timestamp" \
        --argjson mappings "$mappings_json" \
        '{version: $version, last_backup: $last_backup, mappings: $mappings}')

    # Write state file
    if ! echo "$state_json" > "$state_file" 2>/dev/null; then
        log_msg "WARNING" "Failed to write backup state file: $state_file"
        return 1
    fi

    log_msg "INFO" "Updated backup state file"
    return 0
}

# Detect orphaned backup destinations
# Returns: 0 if orphans found, 1 if no orphans or error
# Outputs orphan names to stdout (one per line)
detect_orphans() {
    local dest_path="$1"
    shift
    local -n _current_destinations=$1

    local state_json
    if ! state_json=$(read_backup_state "$dest_path"); then
        # No state file means first run, no orphans
        return 1
    fi

    if ! check_jq_available; then
        return 1
    fi

    # Get destinations from state file
    local -a state_destinations
    while IFS= read -r dest; do
        [[ -n "$dest" ]] && state_destinations+=("$dest")
    done < <(echo "$state_json" | jq -r '.mappings[].dest // empty')

    # Find orphans: destinations in state but not in current config
    local -a orphans=()
    for state_dest in "${state_destinations[@]}"; do
        local found=false
        for current_dest in "${_current_destinations[@]}"; do
            if [[ "$state_dest" == "$current_dest" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            # Verify the directory actually exists
            local full_path="${dest_path%/}/${state_dest}"
            if [[ -d "$full_path" ]]; then
                orphans+=("$state_dest")
            fi
        fi
    done

    if [[ ${#orphans[@]} -eq 0 ]]; then
        return 1
    fi

    # Output orphan names
    printf '%s\n' "${orphans[@]}"
    return 0
}

# List orphaned destinations with sizes
list_orphans() {
    local dest_path="$1"
    shift
    local -n _current_dests=$1

    local -a orphans=()
    while IFS= read -r orphan; do
        [[ -n "$orphan" ]] && orphans+=("$orphan")
    done < <(detect_orphans "$dest_path" _current_dests)

    if [[ ${#orphans[@]} -eq 0 ]]; then
        echo -e "${GREEN}No orphaned backup destinations found.${NC}"
        return 0
    fi

    echo -e "\n${BOLD}${YELLOW}Orphaned backup destinations found:${NC}\n"

    for orphan in "${orphans[@]}"; do
        local full_path="${dest_path%/}/${orphan}"
        local size
        size=$(du -sh "$full_path" 2>/dev/null | cut -f1)
        [[ -z "$size" ]] && size="unknown"
        echo -e "  ${RED}•${NC} ${orphan}/     ${DIM}(${size})${NC}"
    done

    echo -e "\n${DIM}These directories exist in the backup destination but are no longer"
    echo -e "in your configuration. Use --cleanup-orphans to remove them.${NC}\n"

    return 0
}

# Interactive cleanup of orphaned destinations
cleanup_orphans() {
    local dest_path="$1"
    shift
    local -n _current_dests_cleanup=$1

    local -a orphans=()
    while IFS= read -r orphan; do
        [[ -n "$orphan" ]] && orphans+=("$orphan")
    done < <(detect_orphans "$dest_path" _current_dests_cleanup)

    if [[ ${#orphans[@]} -eq 0 ]]; then
        echo -e "${GREEN}No orphaned backup destinations found.${NC}"
        return 0
    fi

    echo -e "\n${BOLD}${YELLOW}The following orphaned backup destinations will be removed:${NC}\n"

    local total_size=0
    for orphan in "${orphans[@]}"; do
        local full_path="${dest_path%/}/${orphan}"
        local size
        size=$(du -sh "$full_path" 2>/dev/null | cut -f1)
        [[ -z "$size" ]] && size="unknown"
        echo -e "  ${RED}•${NC} ${orphan}/     ${DIM}(${size})${NC}"
    done

    echo -e "\n${BOLD}${RED}WARNING: This action cannot be undone!${NC}"
    echo -en "\nAre you sure you want to delete these directories? [y/N] "
    read -r response

    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Cleanup cancelled.${NC}"
        return 1
    fi

    echo ""
    local deleted_count=0
    local failed_count=0

    for orphan in "${orphans[@]}"; do
        local full_path="${dest_path%/}/${orphan}"
        echo -n "Removing ${orphan}... "
        if rm -rf "$full_path" 2>/dev/null; then
            echo -e "${GREEN}done${NC}"
            ((deleted_count++))
        else
            echo -e "${RED}failed${NC}"
            ((failed_count++))
        fi
    done

    echo ""
    if [[ $failed_count -eq 0 ]]; then
        log_msg "SUCCESS" "Removed $deleted_count orphaned destination(s)"
    else
        log_msg "WARNING" "Removed $deleted_count destination(s), $failed_count failed"
    fi

    # Update state file to remove deleted orphans
    if [[ $deleted_count -gt 0 ]]; then
        # Re-read current state and filter out deleted orphans
        local state_json
        if state_json=$(read_backup_state "$dest_path"); then
            local state_file
            state_file=$(get_state_file_path "$dest_path")

            # Build list of remaining destinations
            local remaining_json="["
            local first=true
            while IFS= read -r line; do
                local src dest
                src=$(echo "$line" | jq -r '.source')
                dest=$(echo "$line" | jq -r '.dest')

                # Check if this dest was deleted
                local was_deleted=false
                for orphan in "${orphans[@]}"; do
                    if [[ "$dest" == "$orphan" ]]; then
                        was_deleted=true
                        break
                    fi
                done

                if [[ "$was_deleted" == "false" ]] || [[ -d "${dest_path%/}/${dest}" ]]; then
                    if [[ "$first" != "true" ]]; then
                        remaining_json+=","
                    fi
                    first=false
                    remaining_json+="{\"source\":$(printf '%s' "$src" | jq -Rs '.'),\"dest\":$(printf '%s' "$dest" | jq -Rs '.')}"
                fi
            done < <(echo "$state_json" | jq -c '.mappings[]')
            remaining_json+="]"

            # Update state file
            local timestamp
            timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
            jq -n \
                --argjson version "$STATE_VERSION" \
                --arg last_backup "$timestamp" \
                --argjson mappings "$remaining_json" \
                '{version: $version, last_backup: $last_backup, mappings: $mappings}' > "$state_file"
        fi
    fi

    return 0
}
