#!/bin/bash

# Restore executor utilities
# This script provides core restore execution logic

# Execute restore with pre-restore snapshot
execute_restore_with_snapshot() {
    local source_path="$1"
    local dest_path="$2"
    local snapshot_dir="$3"
    local restore_type="$4"      # "system" or "data"
    local dry_run="${5:-false}"
    local additional_rsync_opts="${6:-}"

    if [ -z "$source_path" ] || [ -z "$dest_path" ] || [ -z "$snapshot_dir" ] || [ -z "$restore_type" ]; then
        log_msg "ERROR" "Missing required parameters for restore execution"
        return 1
    fi

    # Validate restore safety
    if ! validate_restore_safety "$source_path" "$dest_path"; then
        return 1
    fi

    # Calculate and display restore impact
    calculate_restore_impact "$source_path" "$dest_path"

    # If not dry-run, create pre-restore snapshot
    local snapshot_created=false
    if [ "$dry_run" != "true" ]; then
        if create_pre_restore_snapshot "$dest_path" "$snapshot_dir" "$restore_type"; then
            snapshot_created=true
        else
            log_msg "WARNING" "Failed to create pre-restore snapshot, but continuing..."
        fi
    fi

    # Execute rsync restore
    log_msg "INFO" "Starting restore from $source_path to $dest_path"

    local rsync_cmd="rsync -aAXHv --numeric-ids --info=progress2"

    # Add dry-run flag if requested
    if [ "$dry_run" = "true" ]; then
        rsync_cmd+=" --dry-run"
    fi

    # Add any additional rsync options
    if [ -n "$additional_rsync_opts" ]; then
        rsync_cmd+=" $additional_rsync_opts"
    fi

    # Execute rsync (add trailing slashes to paths)
    eval "$rsync_cmd '${source_path}/' '${dest_path}/'"
    local rsync_status=$?

    # Handle rsync exit status
    case $rsync_status in
        0)
            log_msg "SUCCESS" "Restore completed successfully"
            if [ "$dry_run" != "true" ]; then
                show_restore_results "true" "${PRE_RESTORE_SNAPSHOT:-}" "$restore_type"
            fi
            return 0
            ;;
        23)
            log_msg "WARNING" "Restore completed with partial transfer (some files could not be transferred)"
            if [ "$dry_run" != "true" ]; then
                show_restore_results "true" "${PRE_RESTORE_SNAPSHOT:-}" "$restore_type"
            fi
            return 0
            ;;
        24)
            log_msg "WARNING" "Restore completed - some source files vanished during transfer"
            if [ "$dry_run" != "true" ]; then
                show_restore_results "true" "${PRE_RESTORE_SNAPSHOT:-}" "$restore_type"
            fi
            return 0
            ;;
        *)
            log_msg "ERROR" "Restore failed with rsync status $rsync_status"
            if [ "$dry_run" != "true" ]; then
                show_restore_results "false" "${PRE_RESTORE_SNAPSHOT:-}" "$restore_type"
            fi
            return 1
            ;;
    esac
}

# Restore a single source (for data restore with multiple mappings)
restore_single_source() {
    local source_path="$1"
    local dest_path="$2"
    local snapshot_dir="$3"
    local exclude_patterns="${4:-}"
    local dry_run="${5:-false}"

    if [ -z "$source_path" ] || [ -z "$dest_path" ] || [ -z "$snapshot_dir" ]; then
        log_msg "ERROR" "Missing required parameters for single source restore"
        return 1
    fi

    log_msg "INFO" "Restoring: $source_path → $dest_path"

    # Validate paths
    if [ ! -d "$source_path" ]; then
        log_msg "ERROR" "Source path does not exist: $source_path"
        return 1
    fi

    # Create destination if it doesn't exist
    if [ ! -d "$dest_path" ] && [ "$dry_run" != "true" ]; then
        mkdir -p "$dest_path" || {
            log_msg "ERROR" "Failed to create destination directory: $dest_path"
            return 1
        }
    fi

    # Check if destination is writable
    if ! is_safe_restore_path "$dest_path"; then
        return 1
    fi

    # Build rsync options
    local additional_opts=""

    # Add exclude patterns if provided
    if [ -n "$exclude_patterns" ]; then
        local temp_exclude_file=$(mktemp)
        trap "rm -f '$temp_exclude_file'" RETURN

        # Convert comma-separated patterns to exclude file
        IFS=',' read -ra patterns <<< "$exclude_patterns"
        for pattern in "${patterns[@]}"; do
            # Trim whitespace
            pattern=$(echo "$pattern" | xargs)
            if [ -n "$pattern" ]; then
                echo "$pattern" >> "$temp_exclude_file"
            fi
        done

        if [ -s "$temp_exclude_file" ]; then
            additional_opts+=" --exclude-from='$temp_exclude_file'"
        fi
    fi

    # Create pre-restore snapshot for this destination
    if [ "$dry_run" != "true" ]; then
        if ! create_pre_restore_snapshot "$dest_path" "$snapshot_dir" "data"; then
            log_msg "WARNING" "Failed to create snapshot for $dest_path, continuing..."
        fi
    fi

    # Execute rsync
    local rsync_cmd="rsync -aAXHv --numeric-ids --info=progress2"

    if [ "$dry_run" = "true" ]; then
        rsync_cmd+=" --dry-run"
    fi

    if [ -n "$additional_opts" ]; then
        rsync_cmd+=" $additional_opts"
    fi

    eval "$rsync_cmd '${source_path}/' '${dest_path}/'"
    local rsync_status=$?

    # Handle result
    case $rsync_status in
        0|23|24)
            log_msg "SUCCESS" "Restored: $source_path → $dest_path"
            return 0
            ;;
        *)
            log_msg "ERROR" "Failed to restore: $source_path → $dest_path (status: $rsync_status)"
            return 1
            ;;
    esac
}

# Execute selective restore with include/exclude patterns
execute_selective_restore() {
    local source_path="$1"
    local dest_path="$2"
    local snapshot_dir="$3"
    local -n include_patterns_ref=$4
    local -n exclude_patterns_ref=$5
    local dry_run="${6:-false}"

    if [ -z "$source_path" ] || [ -z "$dest_path" ]; then
        log_msg "ERROR" "Missing required parameters for selective restore"
        return 1
    fi

    # Validate paths
    if ! validate_restore_safety "$source_path" "$dest_path"; then
        return 1
    fi

    # Build rsync include/exclude options
    local rsync_opts=""

    # Add include patterns
    if [ ${#include_patterns_ref[@]} -gt 0 ]; then
        for pattern in "${include_patterns_ref[@]}"; do
            # Add the pattern itself with '***' to include contents recursively
            rsync_opts+=" --include='${pattern}/***'"

            # Add parent directories
            local parent_path="$pattern"
            while [[ "$parent_path" == */* ]]; do
                rsync_opts+=" --include='${parent_path}/'"
                parent_path="${parent_path%/*}"
            done

            # Add the top-level component
            if [ -n "$parent_path" ]; then
                rsync_opts+=" --include='${parent_path}/'"
            fi
        done

        # Exclude everything else
        rsync_opts+=" --exclude='*'"
    fi

    # Add exclude patterns
    if [ ${#exclude_patterns_ref[@]} -gt 0 ]; then
        for pattern in "${exclude_patterns_ref[@]}"; do
            rsync_opts+=" --exclude='$pattern'"
        done
    fi

    # Execute restore with patterns
    log_msg "INFO" "Starting selective restore"

    local rsync_cmd="rsync -aAXHv --numeric-ids --info=progress2"

    if [ "$dry_run" = "true" ]; then
        rsync_cmd+=" --dry-run"
    fi

    if [ -n "$rsync_opts" ]; then
        rsync_cmd+=" $rsync_opts"
    fi

    # Create pre-restore snapshot if not dry-run and snapshot_dir provided
    if [ "$dry_run" != "true" ] && [ -n "$snapshot_dir" ]; then
        if ! create_pre_restore_snapshot "$dest_path" "$snapshot_dir" "data"; then
            log_msg "WARNING" "Failed to create pre-restore snapshot, continuing..."
        fi
    fi

    eval "$rsync_cmd '${source_path}/' '${dest_path}/'"
    local rsync_status=$?

    # Handle result
    case $rsync_status in
        0)
            log_msg "SUCCESS" "Selective restore completed successfully"
            if [ "$dry_run" != "true" ]; then
                show_restore_results "true" "${PRE_RESTORE_SNAPSHOT:-}" "data"
            fi
            return 0
            ;;
        23|24)
            log_msg "WARNING" "Selective restore completed with partial transfer"
            if [ "$dry_run" != "true" ]; then
                show_restore_results "true" "${PRE_RESTORE_SNAPSHOT:-}" "data"
            fi
            return 0
            ;;
        *)
            log_msg "ERROR" "Selective restore failed with status $rsync_status"
            if [ "$dry_run" != "true" ]; then
                show_restore_results "false" "${PRE_RESTORE_SNAPSHOT:-}" "data"
            fi
            return 1
            ;;
    esac
}
