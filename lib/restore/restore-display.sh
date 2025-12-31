#!/bin/bash

# Restore display utilities
# This script provides display functions for restore operations

# Display restore details to the user before execution
display_restore_details() {
    local restore_type="$1"    # "system" or "data"
    local source_path="$2"
    local dest_path="$3"
    local snapshot_dir="$4"
    local additional_info="${5:-}"

    print_banner "Restore Operation Details" "$BLUE"

    echo -e "${BOLD}Type:${NC} ${restore_type^} Restore"
    echo -e "${BOLD}Source:${NC} $source_path"
    echo -e "${BOLD}Destination:${NC} $dest_path"
    echo -e "${BOLD}Snapshots:${NC} $snapshot_dir"

    # Display estimated size and file count if available
    if [ -n "${RESTORE_FILE_COUNT:-}" ]; then
        echo -e "${BOLD}Estimated Files:${NC} $RESTORE_FILE_COUNT"
    fi

    if [ -n "${RESTORE_SIZE:-}" ]; then
        echo -e "${BOLD}Estimated Size:${NC} $RESTORE_SIZE"
    fi

    # Display additional information if provided
    if [ -n "$additional_info" ]; then
        echo -e "\n${BOLD}Additional Information:${NC}"
        echo -e "$additional_info"
    fi

    # Display warning for system restore
    if [ "$restore_type" = "system" ]; then
        echo -e "\n${BOLD}${RED}⚠ WARNING ⚠${NC}"
        echo -e "${YELLOW}This will restore system files and may overwrite current configuration.${NC}"
        if [ -n "$snapshot_dir" ] && [ "$snapshot_dir" != "none (no rollback capability)" ]; then
            echo -e "${YELLOW}A pre-restore snapshot will be created for rollback capability.${NC}"
        fi
    else
        if [ -n "$snapshot_dir" ] && [ "$snapshot_dir" != "none (no rollback capability)" ]; then
            echo -e "\n${BOLD}${YELLOW}Note:${NC} A pre-restore snapshot will be created before restoration."
        fi
    fi

    echo ""
}

# Display available backups in a directory
display_available_backups() {
    local backup_source="$1"

    if [ ! -d "$backup_source" ]; then
        log_msg "ERROR" "Backup source directory does not exist: $backup_source"
        return 1
    fi

    print_banner "Available Backups" "$BLUE"

    echo -e "${BOLD}Backup Location:${NC} $backup_source\n"

    # List subdirectories
    local found_backups=false
    while IFS= read -r dir; do
        if [ -d "$dir" ]; then
            local dir_name=$(basename "$dir")
            local dir_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            local file_count=$(find "$dir" -type f 2>/dev/null | wc -l)
            echo -e "  ${BOLD}$dir_name${NC}"
            echo -e "    Size: $dir_size"
            echo -e "    Files: $file_count"
            echo ""
            found_backups=true
        fi
    done < <(find "$backup_source" -maxdepth 1 -mindepth 1 -type d | sort)

    if [ "$found_backups" = false ]; then
        echo -e "${YELLOW}No backup subdirectories found.${NC}\n"
        return 1
    fi

    return 0
}

# Preview restore changes (dry-run results)
preview_restore_changes() {
    local dry_run_output="$1"

    print_banner "Restore Preview (Dry Run)" "$YELLOW"

    echo -e "${BOLD}The following changes would be made:${NC}\n"

    # Parse and display dry-run output
    if [ -n "$dry_run_output" ]; then
        echo "$dry_run_output" | grep -v "^sending\|^total\|^sent\|^$" | head -50

        # Count changes
        local change_count=$(echo "$dry_run_output" | grep -v "^sending\|^total\|^sent\|^$" | wc -l)

        if [ "$change_count" -gt 50 ]; then
            echo -e "\n${YELLOW}... and $((change_count - 50)) more files${NC}"
        fi

        echo -e "\n${BOLD}Total files to restore:${NC} $change_count"
    else
        echo -e "${YELLOW}No changes detected.${NC}"
    fi

    echo ""
}

# Display restore results after execution
show_restore_results() {
    local success="$1"
    local snapshot_path="$2"
    local restore_type="$3"

    if [ "$success" = "true" ]; then
        print_banner "Restore Completed Successfully" "$GREEN"

        echo -e "${GREEN}✓${NC} ${restore_type^} restore completed successfully"

        if [ -n "$snapshot_path" ] && [ -d "$snapshot_path" ]; then
            echo -e "\n${BOLD}Pre-restore snapshot:${NC} $snapshot_path"
            echo -e "${YELLOW}You can use this snapshot for rollback if needed.${NC}"
        fi

        echo -e "\n${BOLD}Next steps:${NC}"
        if [ "$restore_type" = "system" ]; then
            echo -e "  • Review restored system files"
            echo -e "  • Reboot if necessary"
            echo -e "  • Verify system functionality"
        else
            echo -e "  • Verify restored files"
            echo -e "  • Check file permissions and ownership"
        fi
    else
        print_banner "Restore Failed" "$RED"

        echo -e "${RED}✗${NC} Restore operation failed"

        if [ -n "$snapshot_path" ] && [ -d "$snapshot_path" ]; then
            echo -e "\n${BOLD}Pre-restore snapshot:${NC} $snapshot_path"
            echo -e "${YELLOW}Your data before the restore attempt is preserved.${NC}"
        fi

        echo -e "\n${BOLD}Troubleshooting:${NC}"
        echo -e "  • Check log files for detailed error messages"
        echo -e "  • Verify source and destination paths"
        echo -e "  • Ensure sufficient disk space"
        echo -e "  • Check file permissions"
    fi

    echo ""
}

# Display data restore mapping details
display_data_restore_mappings() {
    local -n sources=$1
    local -n destinations=$2
    local backup_base="$3"

    print_banner "Data Restore Mappings" "$BLUE"

    echo -e "${BOLD}The following mappings will be restored:${NC}\n"

    local total_entries=${#sources[@]}

    for ((i=0; i<total_entries; i++)); do
        local source="${sources[i]}"
        local dest="${destinations[i]}"
        local backup_path="${backup_base}/${dest}"

        echo -e "  ${BOLD}Mapping $((i+1)):${NC}"
        echo -e "    From: ${backup_path}/"
        echo -e "    To:   ${source}/"

        # Check if backup exists
        if [ -d "$backup_path" ]; then
            local size=$(du -sh "$backup_path" 2>/dev/null | cut -f1)
            echo -e "    Size: $size"
        else
            echo -e "    ${YELLOW}Warning: Backup not found${NC}"
        fi

        echo ""
    done

    echo -e "${BOLD}Total mappings:${NC} $total_entries\n"
}

# Display selective restore patterns
display_selective_patterns() {
    local -n include_patterns=$1
    local -n exclude_patterns=$2

    echo -e "\n${BOLD}Selective Restore Patterns:${NC}\n"

    if [ ${#include_patterns[@]} -gt 0 ]; then
        echo -e "${BOLD}Include:${NC}"
        for pattern in "${include_patterns[@]}"; do
            echo -e "  ${GREEN}+${NC} $pattern"
        done
    fi

    if [ ${#exclude_patterns[@]} -gt 0 ]; then
        echo -e "\n${BOLD}Exclude:${NC}"
        for pattern in "${exclude_patterns[@]}"; do
            echo -e "  ${RED}−${NC} $pattern"
        done
    fi

    echo ""
}
