generate_prefixed_exclude_list() {
    local source_path="$1"
    local temp_exclude_file="$2"
    local exclude_config="$3"
    
    # Check if exclude config exists
    if [ ! -f "$exclude_config" ]; then
        log_msg "ERROR" "Exclude list file not found: $exclude_config"
        exit 1
    fi
    
    # Remove trailing slash from source path if present
    source_path="${source_path%/}"
    
    # Create temporary exclude file with prefixed paths
    > "$temp_exclude_file"  # Clear the file first
    
    while IFS= read -r line; do
        # Preserve comments and empty lines
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
            echo "$line" >> "$temp_exclude_file"
            continue
        fi
        
        # Remove leading slash if present
        line="${line#/}"
        # Add source path prefix
        echo "${source_path}/${line}" >> "$temp_exclude_file"
    done < "$exclude_config"
}

# ---------------------------------------------------------------------------
# Human-friendly transfer summary
#
# rsync's --stats block is precise but hard to read. Instead, terminal stats
# are suppressed (--info=stats0) and rsync writes an itemized change log to a
# temp file, which print_rsync_summary turns into a short summary.
#
# Usage:
#   rsync_summary_begin                      # sets RSYNC_SUMMARY_LOG / _ARGS
#   local -a rsync_cmd=(rsync ... "${RSYNC_SUMMARY_ARGS[@]}")
#   local start=$SECONDS
#   "${rsync_cmd[@]}" src/ dest/
#   print_rsync_summary "$RSYNC_SUMMARY_LOG" $((SECONDS - start)) mirror
# ---------------------------------------------------------------------------

# Create the temp change log and set RSYNC_SUMMARY_LOG / RSYNC_SUMMARY_ARGS.
# Call directly (not in a subshell). On failure the args are empty, so rsync
# still runs, just without a summary.
rsync_summary_begin() {
    RSYNC_SUMMARY_ARGS=()
    RSYNC_SUMMARY_LOG=$(mktemp "${TMPDIR:-/tmp}/tm-rsync-summary.XXXXXX" 2>/dev/null) || {
        RSYNC_SUMMARY_LOG=""
        return 1
    }
    RSYNC_SUMMARY_ARGS=(
        --info=stats0
        --log-file="$RSYNC_SUMMARY_LOG"
        "--log-file-format=%i|%l|%b|%n"
    )
}

# 1234567 -> 1,234,567
_tm_group_digits() {
    local n="$1" out=""
    while (( ${#n} > 3 )); do
        out=",${n: -3}${out}"
        n="${n:0:${#n}-3}"
    done
    printf '%s' "${n}${out}"
}

# 15073871084 -> 14.0 GiB
_tm_human_size() {
    awk -v b="$1" 'BEGIN {
        split("B KiB MiB GiB TiB PiB", u, " "); i = 1
        while (b >= 1024 && i < 6) { b /= 1024; i++ }
        if (i == 1) printf "%d %s", b, u[i]; else printf "%.1f %s", b, u[i]
    }'
}

# Format seconds as "1h 02m 03s" / "3m 13s" / "8s"
format_duration() {
    local s="${1:-0}"
    if (( s >= 3600 )); then
        printf '%dh %02dm %02ds' $((s / 3600)) $((s % 3600 / 60)) $((s % 60))
    elif (( s >= 60 )); then
        printf '%dm %02ds' $((s / 60)) $((s % 60))
    else
        printf '%ds' "$s"
    fi
}

_tm_summary_line() {
    log_msg "INFO" "$(printf '  %-15s %s' "$1" "$2")"
}

# Print a readable summary from the change log, then delete the log.
#   $1 log file   $2 elapsed seconds   $3 mode: mirror (default) | archive
print_rsync_summary() {
    local log_file="$1"
    local elapsed="${2:-0}"
    local mode="${3:-mirror}"

    [ -n "$log_file" ] && [ -f "$log_file" ] || return 0

    local new_files=0 updated_files=0 del_files=0 del_dirs=0 written=0 total_size="-"
    read -r new_files updated_files del_files del_dirs written total_size < <(
        awk '
            {
                p = index($0, "] "); if (!p) next
                line = substr($0, p + 2)
                if (line ~ /^sent [0-9]+ bytes +received [0-9]+ bytes +total size [0-9]+/) {
                    total = $NF; next
                }
                if (split(line, f, "|") < 4) next
                code = f[1]
                if (code ~ /^\*deleting/) {
                    if (substr(line, length(line)) == "/") ddir++; else dfile++
                    next
                }
                type = substr(code, 2, 1)
                if (type == "d") next
                if (substr(code, 3, 9) == "+++++++++") created++
                else if (substr(code, 1, 1) == ">" && type == "f") updated++
                written += f[3]
            }
            END {
                printf "%d %d %d %d %.0f %s\n", created, updated, dfile, ddir, written, (total == "" ? "-" : total)
            }
        ' "$log_file"
    )
    rm -f "$log_file"

    echo ""
    echo -e "${BOLD}Summary${NC}"
    if (( new_files == 0 && updated_files == 0 && del_files == 0 && del_dirs == 0 )); then
        _tm_summary_line "Changes" "none since the last run"
    else
        _tm_summary_line "New files" "$(_tm_group_digits "$new_files")"
        _tm_summary_line "Updated files" "$(_tm_group_digits "$updated_files")"
        if [ "$mode" = "mirror" ]; then
            local removed
            removed="$(_tm_group_digits "$del_files") file$( (( del_files == 1 )) || echo s)"
            (( del_dirs > 0 )) && removed+=", $(_tm_group_digits "$del_dirs") folder$( (( del_dirs == 1 )) || echo s)"
            _tm_summary_line "Removed" "$removed"
        fi
        _tm_summary_line "Data copied" "$(_tm_human_size "$written")"
    fi

    if [ "$total_size" != "-" ]; then
        if [ "$mode" = "archive" ]; then
            _tm_summary_line "Source size" "$(_tm_human_size "$total_size")"
        else
            _tm_summary_line "Backup size" "$(_tm_human_size "$total_size")"
        fi
    fi

    local duration
    duration=$(format_duration "$elapsed")
    if (( elapsed > 0 && written > 0 )); then
        duration+="  ($(_tm_human_size $((written / elapsed)))/s)"
    fi
    _tm_summary_line "Duration" "$duration"
}
