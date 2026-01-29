#!/bin/bash

# Preflight checks for backup operations
# Provides "Good to know before you proceed" information

source "${LIB_DIR}/core/colors.sh"
source "${LIB_DIR}/core/logging.sh"

# Global array to collect preflight notices
declare -a PREFLIGHT_NOTICES=()
declare -a PREFLIGHT_SEVERITIES=()

# Add a preflight notice
# Usage: add_preflight_notice "severity" "message"
# Severity: INFO, WARNING, CRITICAL
add_preflight_notice() {
    local severity="$1"
    local message="$2"

    PREFLIGHT_NOTICES+=("$message")
    PREFLIGHT_SEVERITIES+=("$severity")
}

# Check available disk space and warn if low
check_disk_space() {
    local dest_path="$1"
    local threshold_percent="${2:-20}"  # Default: warn if < 20% free

    if [ ! -d "$dest_path" ]; then
        return 0
    fi

    # Get disk usage percentage
    local usage_percent=$(df "$dest_path" | awk 'NR==2 {print $5}' | sed 's/%//')
    local available_percent=$((100 - usage_percent))
    local available_space=$(df -h "$dest_path" | awk 'NR==2 {print $4}')

    if [ "$available_percent" -lt "$threshold_percent" ]; then
        if [ "$available_percent" -lt 10 ]; then
            add_preflight_notice "CRITICAL" "Only ${available_percent}% disk space remaining (${available_space} free)"
        else
            add_preflight_notice "WARNING" "Disk space: ${available_percent}% free (${available_space} available)"
        fi
    else
        add_preflight_notice "INFO" "Disk space: ${available_percent}% free (${available_space} available)"
    fi
}

# Check for old snapshots that should be cleaned up
check_snapshot_count() {
    local snapshot_path="$1"
    local max_snapshots="${2:-10}"  # Default: warn if > 10 snapshots

    if [ ! -d "$snapshot_path" ]; then
        add_preflight_notice "INFO" "Snapshot directory will be created on first backup"
        return 0
    fi

    # Count snapshots (directories starting with backup- or restore-)
    local snapshot_count=$(find "$snapshot_path" -maxdepth 1 -type d \( -name "backup-*" -o -name "restore-*" \) 2>/dev/null | wc -l)

    if [ "$snapshot_count" -eq 0 ]; then
        add_preflight_notice "INFO" "No previous snapshots found"
    elif [ "$snapshot_count" -gt "$max_snapshots" ]; then
        add_preflight_notice "WARNING" "Found ${snapshot_count} snapshots (consider cleanup to save space)"
    else
        add_preflight_notice "INFO" "Found ${snapshot_count} existing snapshot(s)"
    fi
}

# Check last backup time and warn if backup is overdue
check_last_backup_time() {
    local backup_path="$1"
    local max_days="${2:-7}"  # Default: warn if > 7 days since last backup

    if [ ! -d "$backup_path" ]; then
        add_preflight_notice "INFO" "First backup to this destination"
        return 0
    fi

    # Find the most recently modified file in backup
    local last_modified=$(find "$backup_path" -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -1)

    if [ -z "$last_modified" ]; then
        add_preflight_notice "INFO" "No previous backup data found"
        return 0
    fi

    local current_time=$(date +%s)
    local days_since_backup=$(( (current_time - ${last_modified%.*}) / 86400 ))

    if [ "$days_since_backup" -gt "$max_days" ]; then
        add_preflight_notice "WARNING" "Last backup: ${days_since_backup} days ago (overdue)"
    elif [ "$days_since_backup" -eq 0 ]; then
        add_preflight_notice "INFO" "Last backup: today"
    else
        add_preflight_notice "INFO" "Last backup: ${days_since_backup} day(s) ago"
    fi
}

# Check BTRFS filesystem health
check_btrfs_health() {
    local btrfs_path="$1"

    if ! is_btrfs_filesystem "$btrfs_path"; then
        return 0
    fi

    # Check for BTRFS errors in kernel log (last 100 lines)
    if dmesg 2>/dev/null | tail -100 | grep -i "btrfs.*error\|btrfs.*warning" >/dev/null 2>&1; then
        add_preflight_notice "CRITICAL" "BTRFS warnings detected in system logs (run 'dmesg | grep -i btrfs')"
    else
        add_preflight_notice "INFO" "BTRFS filesystem health: OK"
    fi
}

# Check if source directories exist and are readable
check_source_accessibility() {
    local -n sources_array=$1  # Array reference

    local total_sources=${#sources_array[@]}
    local accessible_count=0
    local inaccessible_sources=()

    for source in "${sources_array[@]}"; do
        if [ -d "$source" ] && [ -r "$source" ]; then
            accessible_count=$((accessible_count + 1))
        else
            inaccessible_sources+=("$source")
        fi
    done

    if [ "$accessible_count" -eq "$total_sources" ]; then
        add_preflight_notice "INFO" "All ${total_sources} source(s) accessible"
    elif [ "$accessible_count" -eq 0 ]; then
        add_preflight_notice "CRITICAL" "No sources are accessible"
    else
        local inaccessible_count=$((total_sources - accessible_count))
        add_preflight_notice "WARNING" "${accessible_count}/${total_sources} sources accessible (${inaccessible_count} will be skipped)"
    fi
}

# Check for orphaned backup destinations (data backups only)
# Usage: check_orphaned_destinations dest_path destinations_array_name
check_orphaned_destinations() {
    local dest_path="$1"
    local destinations_array_name="$2"

    # Check if detect_orphans function exists (from backup-state.sh)
    if ! declare -f detect_orphans &>/dev/null; then
        return 0
    fi

    # Check if jq is available (required for state management)
    if ! command -v jq &>/dev/null; then
        return 0
    fi

    local -n _dests_ref=$destinations_array_name
    local -a orphans=()

    # Collect orphans
    while IFS= read -r orphan; do
        [[ -n "$orphan" ]] && orphans+=("$orphan")
    done < <(detect_orphans "$dest_path" _dests_ref 2>/dev/null)

    if [[ ${#orphans[@]} -eq 0 ]]; then
        return 0
    fi

    # Build display message
    local orphan_count=${#orphans[@]}
    local display_orphans=""

    if [[ $orphan_count -le 3 ]]; then
        display_orphans=$(printf '%s, ' "${orphans[@]}")
        display_orphans="${display_orphans%, }"
    else
        display_orphans="${orphans[0]}, ${orphans[1]}"
        local remaining=$((orphan_count - 2))
        display_orphans+=" (+${remaining} more)"
    fi

    add_preflight_notice "WARNING" "Found ${orphan_count} orphaned backup(s): ${display_orphans}"
    add_preflight_notice "INFO" "Run with --list-orphans to see details or --cleanup-orphans to remove"
}

# Check for Podman containers and warn about manual backup needs
check_podman_containers() {
    # Check if podman is installed
    if ! command -v podman >/dev/null 2>&1; then
        return 0
    fi

    local found_podman_data=false
    local podman_dirs=()

    # Check for Podman data in common locations
    # 1. Current user (if not root)
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
        local user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [ -d "$user_home/.config/containers" ] || [ -d "$user_home/.local/share/containers" ]; then
            found_podman_data=true
            podman_dirs+=("$user_home/.config/containers" "$user_home/.local/share/containers")
        fi
    fi

    # 2. Root user
    if [ -d "/root/.config/containers" ] || [ -d "/root/.local/share/containers" ]; then
        found_podman_data=true
        podman_dirs+=("/root/.config/containers" "/root/.local/share/containers")
    fi

    # 3. Check all home directories for any users running Podman
    while IFS=: read -r username _ _ _ _ homedir _; do
        if [ -d "$homedir/.config/containers" ] || [ -d "$homedir/.local/share/containers" ]; then
            if [[ ! " ${podman_dirs[@]} " =~ " ${homedir}/.config/containers " ]]; then
                found_podman_data=true
                podman_dirs+=("$homedir/.config/containers" "$homedir/.local/share/containers")
            fi
        fi
    done < /etc/passwd

    if [ "$found_podman_data" = true ]; then
        add_preflight_notice "WARNING" "Podman containers detected: ~/.config/containers/ should be backed up manually"
        add_preflight_notice "INFO" "Reason: Restoring Podman data may corrupt containers. Manual backup saves space and allows selective restore"
    fi
}

# Run all preflight checks
# Usage: run_preflight_checks "backup_type" "dest_path" "snapshot_path" [sources_array_name] [destinations_array_name]
run_preflight_checks() {
    local backup_type="$1"      # "system" or "data"
    local dest_path="$2"
    local snapshot_path="$3"
    local sources_array_name="$4"       # Optional: name of array variable containing sources
    local destinations_array_name="$5"  # Optional: name of array variable containing destinations

    # Reset notices array
    PREFLIGHT_NOTICES=()
    PREFLIGHT_SEVERITIES=()

    # Run checks
    check_disk_space "$dest_path"
    check_snapshot_count "$snapshot_path"
    check_last_backup_time "$dest_path"
    check_btrfs_health "$dest_path"
    check_podman_containers

    # Check source accessibility for data backups
    if [ "$backup_type" = "data" ] && [ -n "$sources_array_name" ]; then
        check_source_accessibility "$sources_array_name"
    fi

    # Check for orphaned destinations (data backups only)
    if [ "$backup_type" = "data" ] && [ -n "$destinations_array_name" ]; then
        check_orphaned_destinations "$dest_path" "$destinations_array_name"
    fi
}

# Display preflight notices
show_preflight_info() {
    local notice_count=${#PREFLIGHT_NOTICES[@]}

    # Display header
    echo -e "\n${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  Good to know before you proceed${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    if [ "$notice_count" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} No issues detected\n"
        return 0
    fi

    # Track severity counts
    local info_count=0
    local warning_count=0
    local critical_count=0

    # Display each notice with appropriate color
    for i in "${!PREFLIGHT_NOTICES[@]}"; do
        local severity="${PREFLIGHT_SEVERITIES[$i]}"
        local message="${PREFLIGHT_NOTICES[$i]}"

        case "$severity" in
            "INFO")
                echo -e "  ${BLUE}ℹ${NC}  ${message}"
                info_count=$((info_count + 1))
                ;;
            "WARNING")
                echo -e "  ${YELLOW}⚠${NC}  ${message}"
                warning_count=$((warning_count + 1))
                ;;
            "CRITICAL")
                echo -e "  ${RED}✖${NC}  ${message}"
                critical_count=$((critical_count + 1))
                ;;
        esac
    done

    # Display summary
    echo ""
    if [ "$critical_count" -gt 0 ]; then
        echo -e "${BOLD}${RED}Found ${critical_count} critical issue(s). Proceeding is not recommended.${NC}\n"
        return 1
    elif [ "$warning_count" -gt 0 ]; then
        echo -e "${BOLD}${YELLOW}Found ${warning_count} warning(s). Review before proceeding.${NC}\n"
    else
        echo -e "${BOLD}${GREEN}All checks passed.${NC}\n"
    fi

    return 0
}
