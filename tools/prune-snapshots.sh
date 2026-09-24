#!/bin/bash

# prune-snapshots.sh - Safe Snapshot Retention and Pruning Engine
# Manages the lifecycle of BTRFS backup snapshots to prevent storage exhaustion.
# Default: DRY-RUN mode. Requires --apply to execute deletions.

set -euo pipefail

# Visual formatting
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
NC=$'\033[0m'

if [[ -n "${NO_COLOR:-}" ]] || [[ "${TERM:-}" == "dumb" ]]; then
    RED='' GREEN='' YELLOW='' BLUE='' DIM='' BOLD='' NC=''
fi

SNAPSHOTS_DIR="/mnt/@snapshots"
KEEP_COUNT=10
TARGET_TIER="all"
APPLY=false
AUTO_CONFIRM=false

usage() {
    cat << EOF
${BOLD}Usage:${NC} $0 [OPTIONS]

${BOLD}Description:${NC}
  Inspects and safely prunes old BTRFS backup snapshots based on retention policies.
  By default, runs in ${BOLD}DRY-RUN${NC} preview mode. Pass ${BOLD}--apply${NC} to delete snapshots.

${BOLD}Options:${NC}
  -s, --snapshots <path>     Directory containing BTRFS snapshots (default: ${SNAPSHOTS_DIR})
  -k, --keep <N>             Number of most recent snapshots to keep per tier (default: ${KEEP_COUNT})
  -t, --tier <tier>          Target tier to prune: system, home, data, archive, or all (default: ${TARGET_TIER})
  --apply                    Actually delete pruned snapshots (default: dry-run only)
  -y, --yes                  Skip interactive confirmation prompt when --apply is passed
  -h, --help                 Show this help message

${BOLD}Examples:${NC}
  # Preview which snapshots would be pruned keeping the 10 newest per tier
  sudo $0 -s /mnt/@snapshots --keep 10

  # Actually prune snapshots keeping the 7 newest system snapshots
  sudo $0 -s /mnt/@snapshots --tier system --keep 7 --apply

  # Clean up all tiers keeping the 5 newest of each
  sudo $0 -s /mnt/@snapshots --keep 5 --apply
EOF
    exit "${1:-1}"
}

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--snapshots) SNAPSHOTS_DIR="${2%/}"; shift 2 ;;
        -k|--keep)      KEEP_COUNT="$2"; shift 2 ;;
        -t|--tier)      TARGET_TIER="$2"; shift 2 ;;
        --apply)        APPLY=true; shift ;;
        -y|--yes)       AUTO_CONFIRM=true; shift ;;
        -h|--help)      usage 0 ;;
        *)
            echo -e "${RED}[ERROR]${NC} Unknown option: $1" >&2
            usage 1
            ;;
    esac
done

if [[ $# -eq 0 && ! -d "$SNAPSHOTS_DIR" ]]; then
    usage 1
fi

# Privilege check
if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} This script must be run as root (sudo) for BTRFS subvolume management." >&2
    exit 1
fi

if [[ ! -d "$SNAPSHOTS_DIR" ]]; then
    echo -e "${RED}[ERROR]${NC} Snapshots directory does not exist: $SNAPSHOTS_DIR" >&2
    exit 1
fi

# Check required commands
for cmd in btrfs find sort; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${RED}[ERROR]${NC} Missing required command: $cmd" >&2
        exit 1
    fi
done

# Tier definitions
TIERS_TO_PROCESS=()
case "$TARGET_TIER" in
    system)  TIERS_TO_PROCESS=("system-backup") ;;
    home)    TIERS_TO_PROCESS=("home-backup") ;;
    data)    TIERS_TO_PROCESS=("data-backup") ;;
    archive) TIERS_TO_PROCESS=("archive-batch") ;;
    all)     TIERS_TO_PROCESS=("system-backup" "home-backup" "data-backup" "archive-batch" "pre-restore-system" "pre-restore-home" "pre-restore-data") ;;
    *)
        echo -e "${RED}[ERROR]${NC} Invalid tier: $TARGET_TIER (must be system, home, data, archive, or all)" >&2
        exit 1
        ;;
esac

echo -e "${BOLD}${BLUE}=== BTRFS Snapshot Pruning Engine ===${NC}"
echo -e "${BOLD}Snapshots Path:${NC} $SNAPSHOTS_DIR"
echo -e "${BOLD}Keep Policy:${NC}    Retain ${GREEN}${KEEP_COUNT}${NC} newest per tier"
echo -e "${BOLD}Execution Mode:${NC} $(if [[ "$APPLY" = true ]]; then echo -e "${RED}APPLY (Live deletion)${NC}"; else echo -e "${YELLOW}DRY-RUN (Preview only)${NC}"; fi)"
echo

TOTAL_PRUNABLE=0
declare -a PRUNE_TARGETS=()

for prefix in "${TIERS_TO_PROCESS[@]}"; do
    # Find all snapshots matching the prefix, sorted newest first
    # Matching directories starting with prefix
    mapfile -t found_snapshots < <(find "$SNAPSHOTS_DIR" -maxdepth 1 -mindepth 1 -type d -name "${prefix}-*" 2>/dev/null | sort -r || true)
    count=${#found_snapshots[@]}

    if [[ $count -eq 0 ]]; then
        continue
    fi

    echo -e "${BOLD}Tier [${prefix}]:${NC} Found ${count} snapshots"

    if [[ $count -le $KEEP_COUNT ]]; then
        echo -e "  ${DIM}All $count snapshots within retention quota (<= $KEEP_COUNT). Nothing to prune.${NC}"
    else
        keep_list=("${found_snapshots[@]:0:$KEEP_COUNT}")
        prune_list=("${found_snapshots[@]:$KEEP_COUNT}")

        echo -e "  ${GREEN}Keeping ($KEEP_COUNT):${NC}"
        for s in "${keep_list[@]}"; do
            echo -e "    ${DIM}✓ $(basename "$s")${NC}"
        done

        echo -e "  ${RED}Pruning (${#prune_list[@]}):${NC}"
        for s in "${prune_list[@]}"; do
            echo -e "    ✗ $(basename "$s")"
            PRUNE_TARGETS+=("$s")
            TOTAL_PRUNABLE=$((TOTAL_PRUNABLE + 1))
        done
    fi
    echo
done

if [[ $TOTAL_PRUNABLE -eq 0 ]]; then
    echo -e "${GREEN}[SUCCESS] Snapshot retention is healthy. No snapshots require pruning.${NC}"
    exit 0
fi

echo -e "Total snapshots identified for pruning: ${BOLD}${RED}${TOTAL_PRUNABLE}${NC}"
echo

if [[ "$APPLY" != true ]]; then
    echo -e "${YELLOW}Notice: This was a DRY-RUN preview. No snapshots were modified.${NC}"
    echo -e "To permanently delete these $TOTAL_PRUNABLE snapshots, re-run with: ${BOLD}--apply${NC}"
    exit 0
fi

# Confirmation before destructive live deletion
if [[ "$AUTO_CONFIRM" != true ]]; then
    echo -e "${BOLD}${RED}⚠ WARNING: Permanent Deletion${NC}"
    read -r -p "Permanently delete these $TOTAL_PRUNABLE BTRFS snapshots? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Pruning aborted by user.${NC}"
        exit 0
    fi
fi

# Live deletion execution
echo -e "${BLUE}[INFO]${NC} Deleting snapshots..."
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
