#!/bin/bash

# prune-snapshots.sh - Safe Snapshot Retention and Pruning Engine
# Manages the lifecycle of BTRFS backup snapshots to prevent storage exhaustion.
# Supports retention policies (keep N), targeted specific deletion, and list views.
# Default: DRY-RUN mode. Requires --apply to execute deletions.

set -euo pipefail

# Visual formatting
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
NC=$'\033[0m'

if [[ -n "${NO_COLOR:-}" ]] || [[ "${TERM:-}" == "dumb" ]]; then
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' DIM='' BOLD='' NC=''
fi

SNAPSHOTS_DIR="/mnt/@snapshots"
KEEP_COUNT=""
TARGET_TIER="all"
APPLY=false
AUTO_CONFIRM=false
MODE="retention" # "retention", "targeted", or "list"
declare -a TARGET_PATTERNS=()

usage() {
    cat << EOF
${BOLD}Usage:${NC} $0 [OPTIONS] [SNAPSHOT_NAME_OR_PATTERN...]

${BOLD}Description:${NC}
  Safely inspects, lists, and prunes BTRFS backup snapshots.
  Supports both policy-based retention (keep newest N) and targeted deletion.
  By default, runs in ${BOLD}DRY-RUN${NC} preview mode. Pass ${BOLD}--apply${NC} to delete snapshots.

${BOLD}Options:${NC}
  -l, --list                 List all current snapshots sorted by time
  -s, --snapshots <path>     Directory containing BTRFS snapshots (default: ${SNAPSHOTS_DIR})
  -k, --keep <N>             Number of most recent snapshots to keep per tier (default: 10)
  -t, --tier <tier>          Target tier: system, home, data, archive, or all (default: all)
  --apply                    Actually delete matching snapshots (default: safe dry-run)
  -y, --yes                  Skip interactive confirmation prompt when --apply is passed
  -h, --help                 Show this help message

${BOLD}Examples:${NC}
  # List all current snapshots with formatted dates
  sudo $0 --list

  # Preview keeping the 3 newest snapshots per tier (prune older ones)
  sudo $0 --keep 3

  # Actually delete snapshots older than the 3 newest per tier
  sudo $0 --keep 3 --apply

  # Delete a specific dirty/test snapshot by name
  sudo $0 data-backup-20260924130011 --apply

  # Delete all snapshots matching a time pattern (e.g. all runs from 13:01)
  sudo $0 "*202609241301*" --apply
EOF
    exit "${1:-1}"
}

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -l|--list)      MODE="list"; shift ;;
        -s|--snapshots) SNAPSHOTS_DIR="${2%/}"; shift 2 ;;
        -k|--keep)      KEEP_COUNT="$2"; shift 2 ;;
        -t|--tier)      TARGET_TIER="$2"; shift 2 ;;
        --apply)        APPLY=true; shift ;;
        -y|--yes)       AUTO_CONFIRM=true; shift ;;
        -h|--help)      usage 0 ;;
        -*)
            echo -e "${RED}[ERROR]${NC} Unknown option: $1" >&2
            usage 1
            ;;
        *)
            MODE="targeted"
            TARGET_PATTERNS+=("$1")
            shift
            ;;
    esac
done

# If no patterns provided and not in list mode, default keep count to 10
if [[ "$MODE" == "retention" && -z "$KEEP_COUNT" ]]; then
    KEEP_COUNT=10
fi

# Format snapshot timestamp helper (YYYYMMDDHHMMSS -> YYYY-MM-DD HH:MM:SS)
format_ts() {
    local name="$1"
    if [[ "$name" =~ ([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2}) ]]; then
        echo "${BASH_REMATCH[1]}-${BASH_REMATCH[2]}-${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
    else
        echo "unknown date"
    fi
}

# Check directory
if [[ ! -d "$SNAPSHOTS_DIR" ]]; then
    echo -e "${RED}[ERROR]${NC} Snapshots directory does not exist: $SNAPSHOTS_DIR" >&2
    echo -e "Make sure the backup drive is mounted: ${BOLD}sudo ./tm mount /dev/sdX${NC}" >&2
    exit 1
fi

# Subcommand: list
if [[ "$MODE" == "list" ]]; then
    echo -e "${BOLD}${BLUE}=== Current BTRFS Snapshots in $SNAPSHOTS_DIR ===${NC}"
    printf "  %-36s %-12s %s\n" "SNAPSHOT NAME" "TIER" "TIMESTAMP"
    printf "  %-36s %-12s %s\n" "─────────────" "────" "─────────"
    
    mapfile -t all_snaps < <(find "$SNAPSHOTS_DIR" -maxdepth 1 -mindepth 1 -type d | sort)
    if [[ ${#all_snaps[@]} -eq 0 ]]; then
        echo -e "  ${DIM}(No snapshots found)${NC}"
        echo
        exit 0
    fi

    for snap in "${all_snaps[@]}"; do
        bname=$(basename "$snap")
        tier="other"
        [[ "$bname" =~ ^system-backup ]] && tier="system"
        [[ "$bname" =~ ^home-backup ]]   && tier="home"
        [[ "$bname" =~ ^data-backup ]]   && tier="data"
        [[ "$bname" =~ ^archive-batch ]] && tier="archive"
        [[ "$bname" =~ ^pre-restore ]]   && tier="restore-safe"

        formatted_time=$(format_ts "$bname")
        printf "  %-36s ${CYAN}%-12s${NC} %s\n" "$bname" "$tier" "$formatted_time"
    done
    echo
    echo -e "Total: ${BOLD}${#all_snaps[@]}${NC} snapshots"
    exit 0
fi

# Privilege check for deletion / inspection
if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} Snapshot operations require root privileges (sudo)." >&2
    exit 1
fi

for cmd in btrfs find sort; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${RED}[ERROR]${NC} Missing required command: $cmd" >&2
        exit 1
    fi
done

TOTAL_PRUNABLE=0
declare -a PRUNE_TARGETS=()

if [[ "$MODE" == "targeted" ]]; then
    # Mode: Targeted deletion by name or glob pattern
    echo -e "${BOLD}${BLUE}=== BTRFS Targeted Snapshot Deletion ===${NC}"
    echo -e "${BOLD}Snapshots Path:${NC} $SNAPSHOTS_DIR"
    echo -e "${BOLD}Patterns:${NC}       ${TARGET_PATTERNS[*]}"
    echo -e "${BOLD}Execution Mode:${NC} $(if [[ "$APPLY" = true ]]; then echo -e "${RED}APPLY (Live deletion)${NC}"; else echo -e "${YELLOW}DRY-RUN (Preview only)${NC}"; fi)"
    echo

    for pattern in "${TARGET_PATTERNS[@]}"; do
        # Search matching directories
        mapfile -t matches < <(find "$SNAPSHOTS_DIR" -maxdepth 1 -mindepth 1 -type d -name "$pattern" 2>/dev/null || true)
        for m in "${matches[@]}"; do
            PRUNE_TARGETS+=("$m")
            TOTAL_PRUNABLE=$((TOTAL_PRUNABLE + 1))
        done
    done

    if [[ $TOTAL_PRUNABLE -eq 0 ]]; then
        echo -e "${YELLOW}[INFO] No snapshots matched your pattern(s): ${TARGET_PATTERNS[*]}${NC}"
        echo -e "Run ${BOLD}sudo $0 --list${NC} to see available snapshot names."
        exit 0
    fi

    echo -e "${BOLD}Matching snapshots identified for removal:${NC}"
    for snap in "${PRUNE_TARGETS[@]}"; do
        bname=$(basename "$snap")
        echo -e "  ✗ ${RED}$bname${NC} (${DIM}$(format_ts "$bname")${NC})"
    done
    echo

else
    # Mode: Retention policy pruning (keep N newest per tier)
    TIERS_TO_PROCESS=()
    case "$TARGET_TIER" in
        system)  TIERS_TO_PROCESS=("system-backup") ;;
        home)    TIERS_TO_PROCESS=("home-backup") ;;
        data)    TIERS_TO_PROCESS=("data-backup") ;;
        archive) TIERS_TO_PROCESS=("archive-batch") ;;
        all)     TIERS_TO_PROCESS=("system-backup" "home-backup" "data-backup" "archive-batch" "pre-restore-system" "pre-restore-home" "pre-restore-data") ;;
        *)
            echo -e "${RED}[ERROR]${NC} Invalid tier: $TARGET_TIER" >&2
            exit 1
            ;;
    esac

    echo -e "${BOLD}${BLUE}=== BTRFS Snapshot Pruning Engine ===${NC}"
    echo -e "${BOLD}Snapshots Path:${NC} $SNAPSHOTS_DIR"
    echo -e "${BOLD}Keep Policy:${NC}    Retain ${GREEN}${KEEP_COUNT}${NC} newest per tier"
    echo -e "${BOLD}Execution Mode:${NC} $(if [[ "$APPLY" = true ]]; then echo -e "${RED}APPLY (Live deletion)${NC}"; else echo -e "${YELLOW}DRY-RUN (Preview only)${NC}"; fi)"
    echo

    for prefix in "${TIERS_TO_PROCESS[@]}"; do
        mapfile -t found_snapshots < <(find "$SNAPSHOTS_DIR" -maxdepth 1 -mindepth 1 -type d -name "${prefix}-*" 2>/dev/null | sort -r || true)
        count=${#found_snapshots[@]}
        [[ $count -eq 0 ]] && continue

        echo -e "${BOLD}Tier [${prefix}]:${NC} Found ${count} snapshots"

        if [[ $count -le $KEEP_COUNT ]]; then
            echo -e "  ${DIM}All $count snapshots within quota (<= $KEEP_COUNT). Keeping all.${NC}"
        else
            keep_list=("${found_snapshots[@]:0:$KEEP_COUNT}")
            prune_list=("${found_snapshots[@]:$KEEP_COUNT}")

            echo -e "  ${GREEN}Keeping ($KEEP_COUNT newest):${NC}"
            for s in "${keep_list[@]}"; do
                echo -e "    ${DIM}✓ $(basename "$s")${NC}"
            done

            echo -e "  ${RED}Pruning (${#prune_list[@]} older/dirty):${NC}"
            for s in "${prune_list[@]}"; do
                echo -e "    ✗ $(basename "$s")"
                PRUNE_TARGETS+=("$s")
                TOTAL_PRUNABLE=$((TOTAL_PRUNABLE + 1))
            done
        fi
        echo
    done
fi

if [[ $TOTAL_PRUNABLE -eq 0 ]]; then
    echo -e "${GREEN}[SUCCESS] All snapshots are within retention limits. Nothing to prune.${NC}"
    exit 0
fi

echo -e "Total snapshots identified for removal: ${BOLD}${RED}${TOTAL_PRUNABLE}${NC}"
echo

if [[ "$APPLY" != true ]]; then
    echo -e "${YELLOW}Notice: This was a DRY-RUN preview. No snapshots were touched.${NC}"
    echo -e "To permanently delete these $TOTAL_PRUNABLE snapshots, re-run with: ${BOLD}--apply${NC}"
    exit 0
fi

# Confirmation prompt
if [[ "$AUTO_CONFIRM" != true ]]; then
    echo -e "${BOLD}${RED}⚠ WARNING: Permanent Deletion${NC}"
    read -r -p "Permanently delete these $TOTAL_PRUNABLE BTRFS snapshots? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Pruning aborted by user.${NC}"
        exit 0
    fi
fi

# Execute deletion
echo -e "${BLUE}[INFO]${NC} Deleting snapshots via BTRFS subvolume delete..."
DELETED_COUNT=0
FAILED_COUNT=0

for snap in "${PRUNE_TARGETS[@]}"; do
    if btrfs subvolume delete "$snap" >/dev/null 2>&1; then
        echo -e "  ${GREEN}[DELETED]${NC} $(basename "$snap")"
        DELETED_COUNT=$((DELETED_COUNT + 1))
    else
        echo -e "  ${RED}[FAILED]${NC}  Could not delete $snap"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
done

echo
if [[ $FAILED_COUNT -gt 0 ]]; then
    echo -e "${YELLOW}[WARNING] Pruned $DELETED_COUNT snapshots ($FAILED_COUNT failed).${NC}"
    exit 1
else
    echo -e "${GREEN}[SUCCESS] Successfully pruned $DELETED_COUNT snapshots.${NC}"
    exit 0
fi
