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
    local threshold_percent="${2:-20}"

    # Skip if path is empty or doesn't exist
    [[ -z "$dest_path" || ! -d "$dest_path" ]] && return 0

    # Get disk usage percentage
    local usage_percent=$(df "$dest_path" 2>/dev/null | awk 'NR==2 {print $5}' | sed 's/%//')

    # Skip if we couldn't get usage
    [[ -z "$usage_percent" ]] && return 0

    local available_percent=$((100 - usage_percent))
    local available_space=$(df -h "$dest_path" 2>/dev/null | awk 'NR==2 {print $4}')

    if [ "$available_percent" -lt 10 ]; then
        add_preflight_notice "CRITICAL" "Only ${available_percent}% disk space remaining (${available_space} free)"
    elif [ "$available_percent" -lt "$threshold_percent" ]; then
        add_preflight_notice "WARNING" "Disk space: ${available_percent}% free (${available_space} available)"
    fi
}

# Check for old snapshots that should be cleaned up
check_snapshot_count() {
    local snapshot_path="$1"
    local max_snapshots="${2:-10}"

    [[ -z "$snapshot_path" || ! -d "$snapshot_path" ]] && return 0

    # Count snapshots
    local snapshot_count=$(find "$snapshot_path" -maxdepth 1 -type d \( -name "*-backup-*" -o -name "backup-*" \) 2>/dev/null | wc -l)

    if [ "$snapshot_count" -gt "$max_snapshots" ]; then
        add_preflight_notice "WARNING" "${snapshot_count} snapshots found (consider cleanup)"
    fi
}

# Check last backup time and warn if backup is overdue
check_last_backup_time() {
    local backup_path="$1"
    local max_days="${2:-7}"

    [[ -z "$backup_path" || ! -d "$backup_path" ]] && return 0

    # Find the most recently modified file in backup
    local last_modified=$(find "$backup_path" -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -1)
    [[ -z "$last_modified" ]] && return 0

    local current_time=$(date +%s)
    local days_since_backup=$(( (current_time - ${last_modified%.*}) / 86400 ))

    if [ "$days_since_backup" -gt "$max_days" ]; then
        add_preflight_notice "WARNING" "Last backup: ${days_since_backup} days ago"
    fi
}

# Check BTRFS filesystem health
check_btrfs_health() {
    local btrfs_path="$1"

    [[ -z "$btrfs_path" ]] && return 0

    # Check for BTRFS errors in kernel log (last 100 lines)
    if dmesg 2>/dev/null | tail -100 | grep -qi "btrfs.*error"; then
        add_preflight_notice "CRITICAL" "BTRFS errors in system logs (run 'dmesg | grep -i btrfs')"
    fi
}

# Run all preflight checks
# Usage: run_preflight_checks "backup_type" "dest_path" "snapshot_path"
run_preflight_checks() {
    local backup_type="$1"
    local dest_path="$2"
    local snapshot_path="$3"

    # Reset notices array
    PREFLIGHT_NOTICES=()
    PREFLIGHT_SEVERITIES=()

    # Run checks
    check_disk_space "$dest_path"
    check_snapshot_count "$snapshot_path"
    check_last_backup_time "$dest_path"
    check_btrfs_health "$dest_path"
}

# Display preflight notices (only warnings and critical)
show_preflight_info() {
    local notice_count=${#PREFLIGHT_NOTICES[@]}

    if [ "$notice_count" -eq 0 ]; then
        return 0
    fi

    local has_output=false

    # Display each notice with searchable prefixes
    for i in "${!PREFLIGHT_NOTICES[@]}"; do
        local severity="${PREFLIGHT_SEVERITIES[$i]}"
        local message="${PREFLIGHT_NOTICES[$i]}"

        case "$severity" in
            "WARNING")
                echo -e "${YELLOW}[WARN]${NC}  ${message}"
                has_output=true
                ;;
            "CRITICAL")
                echo -e "${RED}[ERROR]${NC} ${message}"
                has_output=true
                ;;
        esac
    done

    [ "$has_output" = true ] && echo ""
    return 0
}
