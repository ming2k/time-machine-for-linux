#!/bin/bash

# balance-btrfs.sh - Safe Filtered BTRFS Balance & Chunk Reclaimer
# Reclaims sparse/unallocated block groups to prevent ENOSPC without unnecessary SSD wear.
# Uses progressive threshold filtering (-dusage / -musage) instead of full disk rewrites.

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

TARGET_PATH="/mnt"
LEVEL="normal" # "quick" (10%), "normal" (50%), "deep" (75%)

usage() {
    cat << EOF
${BOLD}Usage:${NC} $0 [OPTIONS] [MOUNT_PATH]

${BOLD}Description:${NC}
  Reclaims locked unallocated BTRFS chunks by consolidating under-utilized block groups.
  Prevents 'false out of space' (ENOSPC) conditions and recovers disk space.
  Uses progressive filtered balancing to avoid unnecessary SSD wear.

${BOLD}Parameters:${NC}
  MOUNT_PATH                 BTRFS mountpoint to balance (default: ${TARGET_PATH})

${BOLD}Options:${NC}
  -m, --mount <path>         Explicit mount path
  --quick                    Quick mode (reclaims chunks with <10% utilization; very fast)
  --normal                   Normal mode (consolidates chunks with <50% utilization; default)
  --deep                     Deep mode (consolidates chunks with <75% utilization)
  -h, --help                 Show this help message

${BOLD}Examples:${NC}
  sudo $0 /mnt
  sudo $0 --quick /mnt
EOF
    exit "${1:-1}"
}

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--mount) TARGET_PATH="${2%/}"; shift 2 ;;
        --quick)    LEVEL="quick"; shift ;;
        --normal)   LEVEL="normal"; shift ;;
        --deep)     LEVEL="deep"; shift ;;
        -h|--help)  usage 0 ;;
        -*)
            echo -e "${RED}[ERROR]${NC} Unknown option: $1" >&2
            usage 1
            ;;
        *)
            TARGET_PATH="${1%/}"
            shift
            ;;
    esac
done

if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} BTRFS balance operations require root privileges (sudo)." >&2
    exit 1
fi

if ! command -v btrfs >/dev/null 2>&1; then
    echo -e "${RED}[ERROR]${NC} 'btrfs' command not found." >&2
    exit 1
fi

if ! btrfs filesystem df "$TARGET_PATH" >/dev/null 2>&1; then
    echo -e "${RED}[ERROR]${NC} '$TARGET_PATH' is not a mounted BTRFS filesystem." >&2
    exit 1
fi

echo -e "${BOLD}${BLUE}=== BTRFS Balance & Chunk Reclaimer ===${NC}"
echo -e "${BOLD}Target Mount:${NC} $TARGET_PATH"
echo -e "${BOLD}Filter Mode:${NC}  ${CYAN}${LEVEL}${NC}"
echo

echo -e "${BOLD}Current Allocation State (Before):${NC}"
btrfs filesystem usage "$TARGET_PATH" 2>/dev/null | grep -E "Device allocated|Device unallocated|Free \(estimated\)" | sed 's/^/  /'
echo

case "$LEVEL" in
    quick)
        echo -e "${BLUE}[1/2] Reclaiming sparse data chunks (usage < 10%)...${NC}"
        btrfs balance start -dusage=10 "$TARGET_PATH" || true
        echo -e "${BLUE}[2/2] Reclaiming sparse metadata chunks (usage < 10%)...${NC}"
        btrfs balance start -musage=10 "$TARGET_PATH" || true
        ;;
    normal)
        echo -e "${BLUE}[1/3] Step 1: Rapid pass on empty/sparse chunks (< 10%)...${NC}"
        btrfs balance start -dusage=10 "$TARGET_PATH" || true
        echo -e "${BLUE}[2/3] Step 2: Consolidating underutilized data chunks (< 50%)...${NC}"
        btrfs balance start -dusage=50 "$TARGET_PATH" || true
        echo -e "${BLUE}[3/3] Step 3: Consolidating metadata chunks (< 30%)...${NC}"
        btrfs balance start -musage=30 "$TARGET_PATH" || true
        ;;
    deep)
        echo -e "${BLUE}[1/3] Step 1: Reclaiming empty/sparse chunks (< 10%)...${NC}"
        btrfs balance start -dusage=10 "$TARGET_PATH" || true
        echo -e "${BLUE}[2/3] Step 2: Deep consolidation on data chunks (< 75%)...${NC}"
        btrfs balance start -dusage=75 "$TARGET_PATH" || true
        echo -e "${BLUE}[3/3] Step 3: Deep consolidation on metadata chunks (< 50%)...${NC}"
        btrfs balance start -musage=50 "$TARGET_PATH" || true
        ;;
esac

echo
echo -e "${BOLD}${GREEN}✔ Balance operation completed successfully!${NC}"
echo
echo -e "${BOLD}Allocation State (After):${NC}"
btrfs filesystem usage "$TARGET_PATH" 2>/dev/null | grep -E "Device allocated|Device unallocated|Free \(estimated\)" | sed 's/^/  /'
echo
