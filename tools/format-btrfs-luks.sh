#!/bin/bash

# format-btrfs-luks.sh - Production-grade LUKS2 + BTRFS multi-subvolume disk initializer
# Formats an external drive with LUKS2 encryption and creates standard Time Machine subvolumes.

set -euo pipefail

# Visual formatting
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
BOLD=$'\033[1m'
NC=$'\033[0m'

if [[ -n "${NO_COLOR:-}" ]] || [[ "${TERM:-}" == "dumb" ]]; then
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

DEVICE=""
LUKS_NAME="backup_crypt"
FS_LABEL="TimeMachine"

usage() {
    cat << EOF
${BOLD}Usage:${NC} $0 -d <device> [OPTIONS]

${BOLD}Description:${NC}
  Initializes an external drive for Time Machine for Linux.
  Encrypts the target block device with LUKS2, creates a BTRFS filesystem,
  and provisions the 5 standard subvolumes:
    • @system     - Operating system mirror
    • @home       - User configuration mirror
    • @data       - Active project workspace mirror
    • @archive    - Append-only cold sediment storage
    • @snapshots  - Point-in-time safety snapshots

${BOLD}Required Parameters:${NC}
  -d, --device <dev>       Target block device to format (e.g. /dev/sdb1)

${BOLD}Options:${NC}
  -n, --name <name>        LUKS device mapper name (default: ${LUKS_NAME})
  -l, --label <label>      BTRFS filesystem label (default: ${FS_LABEL})
  -h, --help               Show this help message

${BOLD}Examples:${NC}
  sudo $0 -d /dev/sdb1
  sudo $0 -d /dev/nvme2n1p1 --name my_backup --label BackupDisk

EOF
    exit "${1:-1}"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--device)
            [ -z "${2:-}" ] && { echo -e "${RED}[ERROR]${NC} Missing device argument" >&2; usage 1; }
            DEVICE="$2"
            shift 2
            ;;
        -n|--name)
            [ -z "${2:-}" ] && { echo -e "${RED}[ERROR]${NC} Missing name argument" >&2; usage 1; }
            LUKS_NAME="$2"
            shift 2
            ;;
        -l|--label)
            [ -z "${2:-}" ] && { echo -e "${RED}[ERROR]${NC} Missing label argument" >&2; usage 1; }
            FS_LABEL="$2"
            shift 2
            ;;
        -h|--help)
            usage 0
            ;;
        *)
            echo -e "${RED}[ERROR]${NC} Unknown option: $1" >&2
            usage 1
            ;;
    esac
done

if [[ -z "$DEVICE" ]]; then
    echo -e "${RED}[ERROR]${NC} Device not specified" >&2
    usage 1
fi

# Privilege check
if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} This script must be run as root (sudo)" >&2
    exit 1
fi

# Dependency check
for cmd in cryptsetup mkfs.btrfs btrfs lsblk findmnt; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${RED}[ERROR]${NC} Required tool missing: $cmd" >&2
        exit 1
    fi
done

# Device validation
if [[ ! -b "$DEVICE" ]]; then
    echo -e "${RED}[ERROR]${NC} '$DEVICE' is not a valid block device." >&2
    exit 1
fi

# Strict safety check: Ensure device or any parent/child is NOT currently mounted on active root/home/data
if findmnt -rn -S "$DEVICE" >/dev/null 2>&1; then
    echo -e "${RED}[ERROR]${NC} Device '$DEVICE' is currently mounted:" >&2
    findmnt -S "$DEVICE" >&2
    echo -e "Unmount it first before attempting format." >&2
    exit 1
fi

ACTIVE_MOUNTS=$(findmnt -rn -o TARGET)
for protected_mount in "/" "/boot" "/home" "/data"; do
    MOUNTED_DEV=$(findmnt -rn -o SOURCE "$protected_mount" 2>/dev/null || true)
    if [[ -n "$MOUNTED_DEV" && "$MOUNTED_DEV" == *"$DEVICE"* ]]; then
        echo -e "${RED}[FATAL ERROR]${NC} Refusing to format: '$DEVICE' appears associated with critical mount '$protected_mount'!" >&2
        exit 1
    fi
done

# Display device information & confirmation
echo -e "${BOLD}${BLUE}=== Target Device Details ===${NC}"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT "$DEVICE"
echo

echo -e "${BOLD}${RED}⚠ CRITICAL WARNING: DESTRUCTIVE ACTION${NC}"
echo -e "All data currently on ${BOLD}${RED}${DEVICE}${NC} will be ${BOLD}PERMANENTLY DESTROYED${NC}."
echo -e "LUKS Mapping Name:  ${BOLD}${LUKS_NAME}${NC}"
echo -e "BTRFS Label:        ${BOLD}${FS_LABEL}${NC}"
echo
read -r -p "Type 'FORMAT' in capital letters to confirm: " confirmation

if [[ "$confirmation" != "FORMAT" ]]; then
    echo -e "${YELLOW}Aborted by user. No changes were made.${NC}"
    exit 0
fi

echo
echo -e "${BLUE}[INFO]${NC} Formatting $DEVICE with LUKS2 encryption..."
cryptsetup luksFormat --type luks2 --pbkdf argon2id "$DEVICE"

echo -e "${BLUE}[INFO]${NC} Opening LUKS container as /dev/mapper/$LUKS_NAME..."
cryptsetup open "$DEVICE" "$LUKS_NAME"
LUKS_DEVICE="/dev/mapper/$LUKS_NAME"

# Trap to guarantee cleanup if interrupted
cleanup() {
    local exit_code=$?
    if [[ -n "${TEMP_MOUNT:-}" && -d "${TEMP_MOUNT:-}" ]]; then
        umount "$TEMP_MOUNT" 2>/dev/null || true
        rmdir "$TEMP_MOUNT" 2>/dev/null || true
    fi
    if [[ -b "/dev/mapper/$LUKS_NAME" ]]; then
        cryptsetup close "$LUKS_NAME" 2>/dev/null || true
    fi
    exit $exit_code
}
trap cleanup EXIT

echo -e "${BLUE}[INFO]${NC} Creating BTRFS filesystem (Label: $FS_LABEL)..."
mkfs.btrfs -f -L "$FS_LABEL" "$LUKS_DEVICE"

echo -e "${BLUE}[INFO]${NC} Provisioning standard subvolumes..."
TEMP_MOUNT=$(mktemp -d)
mount "$LUKS_DEVICE" "$TEMP_MOUNT"

btrfs subvolume create "$TEMP_MOUNT/@system"
btrfs subvolume create "$TEMP_MOUNT/@home"
btrfs subvolume create "$TEMP_MOUNT/@data"
btrfs subvolume create "$TEMP_MOUNT/@archive"
btrfs subvolume create "$TEMP_MOUNT/@snapshots"

echo -e "${GREEN}[SUCCESS]${NC} Created subvolumes:"
btrfs subvolume list "$TEMP_MOUNT"

echo -e "${BLUE}[INFO]${NC} Unmounting and closing container..."
umount "$TEMP_MOUNT"
rmdir "$TEMP_MOUNT"
TEMP_MOUNT=""

cryptsetup close "$LUKS_NAME"
trap - EXIT

echo
echo -e "${BOLD}${GREEN}✔ Disk setup completed successfully!${NC}"
echo
echo -e "${BOLD}Next Step - Mount All Subvolumes with:${NC}"
echo -e "  sudo tools/mountctl.sh mount -d $DEVICE -m /mnt"
echo
