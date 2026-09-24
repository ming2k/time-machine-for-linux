#!/bin/bash

# backup-all.sh - Unified Orchestrator for All Backup Tiers
# Executes System, Home, and Data backups sequentially with unified preflight and reporting.

set -euo pipefail

SCRIPT_PATH="$(readlink -f "$0")"
PROJECT_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
BIN_DIR="${PROJECT_ROOT}/bin"

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

BASE_DIR="/mnt"
SOURCE_SYSTEM="/"
SOURCE_HOME="/home"
SOURCE_DATA="/data"
SNAPSHOT_DIR=""
AUTO_CONFIRM=false

RUN_SYSTEM=true
RUN_HOME=true
RUN_DATA=true

usage() {
    cat << EOF
${BOLD}Usage:${NC} $0 [OPTIONS]

${BOLD}Description:${NC}
  Runs all active Time Machine backup tiers sequentially in an orchestrated pipeline:
    1. System Backup  (OS root -> @system)
    2. Home Backup    (User configs -> @home)
    3. Data Backup    (Project trees -> @data)

${BOLD}Options:${NC}
  -m, --base <path>          Base mount path for backup subvolumes (default: ${BASE_DIR})
  --snapshots <path>         Snapshots directory (default: <base>/@snapshots)
  --source-system <path>     Custom source path for system (default: ${SOURCE_SYSTEM})
  --source-home <path>       Custom source path for home (default: ${SOURCE_HOME})
  --source-data <path>       Custom source path for data (default: ${SOURCE_DATA})
  --skip-system              Skip OS system backup
  --skip-home                Skip user home backup
  --skip-data                Skip active data backup
  -y, --yes                  Skip interactive confirmation prompt
  -h, --help                 Show this help message

${BOLD}Example:${NC}
  # Run all three tiers against drive mounted at /mnt
  sudo $0 -m /mnt

  # Run only Home and Data backups
  sudo $0 -m /mnt --skip-system
EOF
    exit "${1:-1}"
}

# Parse CLI arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--base)           BASE_DIR="${2%/}"; shift 2 ;;
        --snapshots)         SNAPSHOT_DIR="${2%/}"; shift 2 ;;
        --source-system)     SOURCE_SYSTEM="$2"; shift 2 ;;
        --source-home)       SOURCE_HOME="$2"; shift 2 ;;
        --source-data)       SOURCE_DATA="$2"; shift 2 ;;
        --skip-system)       RUN_SYSTEM=false; shift ;;
        --skip-home)         RUN_HOME=false; shift ;;
        --skip-data)         RUN_DATA=false; shift ;;
        -y|--yes)            AUTO_CONFIRM=true; shift ;;
        -h|--help)           usage 0 ;;
        *)
            echo -e "${RED}[ERROR]${NC} Unknown option: $1" >&2
            usage 1
            ;;
    esac
done

# Set default snapshots path if not specified
if [[ -z "$SNAPSHOT_DIR" ]]; then
    SNAPSHOT_DIR="${BASE_DIR}/@snapshots"
fi

# Privilege check
if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} This script must be run as root (sudo)." >&2
    exit 1
fi

DEST_SYSTEM="${BASE_DIR}/@system"
DEST_HOME="${BASE_DIR}/@home"
DEST_DATA="${BASE_DIR}/@data"

# Verify subvolume mounts
echo -e "${BOLD}${BLUE}=== Validating Backup Environment ===${NC}"
MISSING_MOUNTS=0

check_mount() {
    local target="$1"
    local name="$2"
    if findmnt -rn "$target" >/dev/null 2>&1; then
        echo -e "  [${GREEN}OK${NC}] $name mounted at $target"
    else
        echo -e "  [${RED}MISSING${NC}] $name is NOT mounted at $target"
        MISSING_MOUNTS=$((MISSING_MOUNTS + 1))
    fi
}

[[ "$RUN_SYSTEM" = true ]] && check_mount "$DEST_SYSTEM" "@system"
[[ "$RUN_HOME" = true ]]   && check_mount "$DEST_HOME" "@home"
[[ "$RUN_DATA" = true ]]   && check_mount "$DEST_DATA" "@data"
check_mount "$SNAPSHOT_DIR" "@snapshots"

if [[ $MISSING_MOUNTS -gt 0 ]]; then
    echo
    echo -e "${RED}[ERROR]${NC} Required backup subvolumes are not mounted."
    echo -e "Mount them first with: ${BOLD}sudo tools/mountctl.sh mount -d <device> -m $BASE_DIR${NC}"
    exit 1
fi

# Plan overview
echo
echo -e "${BOLD}${BLUE}=== Backup Execution Plan ===${NC}"
printf "  %-10s %-16s %-16s %s\n" "TIER" "SOURCE" "DESTINATION" "ACTION"
printf "  %-10s %-16s %-16s %s\n" "────" "──────" "───────────" "──────"
[[ "$RUN_SYSTEM" = true ]] && printf "  %-10s %-16s %-16s ${GREEN}%s${NC}\n" "System" "$SOURCE_SYSTEM" "$DEST_SYSTEM" "Backup + Snapshot"
[[ "$RUN_SYSTEM" = false ]] && printf "  %-10s %-16s %-16s ${DIM}%s${NC}\n" "System" "-" "-" "Skipped"

[[ "$RUN_HOME" = true ]] && printf "  %-10s %-16s %-16s ${GREEN}%s${NC}\n" "Home" "$SOURCE_HOME" "$DEST_HOME" "Backup + Snapshot"
[[ "$RUN_HOME" = false ]] && printf "  %-10s %-16s %-16s ${DIM}%s${NC}\n" "Home" "-" "-" "Skipped"

[[ "$RUN_DATA" = true ]] && printf "  %-10s %-16s %-16s ${GREEN}%s${NC}\n" "Data" "$SOURCE_DATA" "$DEST_DATA" "Backup + Snapshot"
[[ "$RUN_DATA" = false ]] && printf "  %-10s %-16s %-16s ${DIM}%s${NC}\n" "Data" "-" "-" "Skipped"
echo

if [[ "$AUTO_CONFIRM" != true ]]; then
    read -r -p "Execute all planned backup tiers? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Backup sequence cancelled by user.${NC}"
        exit 0
    fi
fi

PIPELINE_START=$(date +%s)
STATUS_SYSTEM="SKIPPED"
STATUS_HOME="SKIPPED"
STATUS_DATA="SKIPPED"

# 1. System Tier
if [[ "$RUN_SYSTEM" = true ]]; then
    echo
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}▶ [1/3] Running System Backup...${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    START_TIER=$(date +%s)
    if echo "y" | "$BIN_DIR/system-backup.sh" --source "$SOURCE_SYSTEM" --dest "$DEST_SYSTEM" --snapshots "$SNAPSHOT_DIR"; then
        STATUS_SYSTEM="SUCCESS ($(( $(date +%s) - START_TIER ))s)"
    else
        STATUS_SYSTEM="FAILED"
    fi
fi

# 2. Home Tier
if [[ "$RUN_HOME" = true ]]; then
    echo
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}▶ [2/3] Running Home Backup...${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    START_TIER=$(date +%s)
    if echo "y" | "$BIN_DIR/home-backup.sh" --source "$SOURCE_HOME" --dest "$DEST_HOME" --snapshots "$SNAPSHOT_DIR"; then
        STATUS_HOME="SUCCESS ($(( $(date +%s) - START_TIER ))s)"
    else
        STATUS_HOME="FAILED"
    fi
fi

# 3. Data Tier
if [[ "$RUN_DATA" = true ]]; then
    echo
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}▶ [3/3] Running Data Backup...${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    START_TIER=$(date +%s)
    if echo "y" | "$BIN_DIR/data-backup.sh" --source "$SOURCE_DATA" --dest "$DEST_DATA" --snapshots "$SNAPSHOT_DIR"; then
        STATUS_DATA="SUCCESS ($(( $(date +%s) - START_TIER ))s)"
    else
        STATUS_DATA="FAILED"
    fi
fi

PIPELINE_END=$(date +%s)
TOTAL_DURATION=$((PIPELINE_END - PIPELINE_START))

# Summary Report
echo
echo -e "${BOLD}${BLUE}=====================================================${NC}"
echo -e "${BOLD}              BACKUP PIPELINE SUMMARY                ${NC}"
echo -e "${BOLD}${BLUE}=====================================================${NC}"
printf "  %-12s : %s\n" "System Tier" "$STATUS_SYSTEM"
printf "  %-12s : %s\n" "Home Tier"   "$STATUS_HOME"
printf "  %-12s : %s\n" "Data Tier"   "$STATUS_DATA"
printf "  %-12s : %ss\n" "Total Time"  "$TOTAL_DURATION"
echo -e "${BOLD}${BLUE}=====================================================${NC}"

if [[ "$STATUS_SYSTEM" == "FAILED" || "$STATUS_HOME" == "FAILED" || "$STATUS_DATA" == "FAILED" ]]; then
    echo -e "${RED}[WARNING] One or more backup tiers encountered errors. Please check the logs above.${NC}"
    exit 1
else
    echo -e "${GREEN}[SUCCESS] All requested backup tiers completed successfully!${NC}"
    exit 0
fi
