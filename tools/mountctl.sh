#!/bin/bash

# mountctl.sh - Modern LUKS + BTRFS Multi-Subvolume Lifecycle Controller
# Orchestrates unlocking, subvolume mounting, unmounting, and locking for Time Machine backup disks.

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

DEFAULT_BASE="/mnt"
DEFAULT_LUKS_NAME="backup_crypt"
DEFAULT_ZSTD_LEVEL=3
STANDARD_SUBVOLUMES=("@system" "@home" "@data" "@archive" "@snapshots" "@media")

log_msg() {
    local level="$1"
    local message="$2"
    case "$level" in
        "ERROR")   echo -e "${RED}[ERROR]${NC} $message" >&2 ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        "WARNING") echo -e "${YELLOW}[WARNING]${NC} $message" ;;
        "INFO")    echo -e "${BLUE}[INFO]${NC} $message" ;;
    esac
}

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        log_msg "ERROR" "This tool requires root privileges. Please run with sudo."
        exit 1
    fi
}

check_dependencies() {
    for cmd in cryptsetup btrfs findmnt lsblk; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_msg "ERROR" "Required command missing: $cmd"
            exit 1
        fi
    done
}

show_usage() {
    cat << EOF
${BOLD}Usage:${NC} $0 <command> [OPTIONS]

${BOLD}Commands:${NC}
  mount                     Unlock LUKS and mount all Time Machine subvolumes
  unmount, umount           Unmount all Time Machine subvolumes and close LUKS
  status                    Inspect LUKS and subvolume mount states

${BOLD}Mount Options:${NC}
  -d, --device <dev>        Block device (LUKS encrypted, e.g. /dev/sdb1)
  -m, --base <path>         Base mount directory (default: ${DEFAULT_BASE})
  -n, --name <name>         LUKS mapper name (default: ${DEFAULT_LUKS_NAME})
  --level <1-22>            Zstd compression level (default: ${DEFAULT_ZSTD_LEVEL})

${BOLD}Unmount Options:${NC}
  -m, --base <path>         Base mount directory (default: ${DEFAULT_BASE})
  -n, --name <name>         LUKS mapper name to close (default: ${DEFAULT_LUKS_NAME})
  --no-close                Unmount filesystems but keep LUKS container open

${BOLD}Examples:${NC}
  # Mount external backup drive (unlocks LUKS and mounts all 5 subvolumes to /mnt/@...)
  sudo $0 mount -d /dev/sdb1

  # Check current mount status
  sudo $0 status -m /mnt

  # Safely unmount all subvolumes and lock/close LUKS container
  sudo $0 unmount -m /mnt
EOF
    exit "${1:-1}"
}

# Subcommand: mount
cmd_mount() {
    local device=""
    local base_dir="$DEFAULT_BASE"
    local luks_name="$DEFAULT_LUKS_NAME"
    local zstd_level="$DEFAULT_ZSTD_LEVEL"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--device) device="$2"; shift 2 ;;
            -m|--base)   base_dir="${2%/}"; shift 2 ;;
            -n|--name)   luks_name="$2"; shift 2 ;;
            --level)     zstd_level="$2"; shift 2 ;;
            -h|--help)   show_usage 0 ;;
            *)           log_msg "ERROR" "Unknown option: $1"; show_usage 1 ;;
        esac
    done

    if [[ -z "$device" ]]; then
        log_msg "ERROR" "Missing required option: -d / --device"
        show_usage 1
    fi

    if [[ ! -b "$device" ]]; then
        log_msg "ERROR" "Device '$device' does not exist or is not a block device"
        exit 1
    fi

    # 1. Unlock LUKS if not already opened
    local mapper_path="/dev/mapper/$luks_name"
    if [[ -b "$mapper_path" ]]; then
        log_msg "INFO" "LUKS container already unlocked at $mapper_path"
    else
        log_msg "INFO" "Unlocking $device as $luks_name..."
        if ! cryptsetup open "$device" "$luks_name"; then
            log_msg "ERROR" "Failed to unlock LUKS container"
            exit 1
        fi
    fi

    # 2. Mount each subvolume with compression and noatime
    local mount_opts="compress=zstd:${zstd_level},noatime"
    log_msg "INFO" "Mounting subvolumes to $base_dir with options '$mount_opts':"

    for subvol in "${STANDARD_SUBVOLUMES[@]}"; do
        local target="${base_dir}/${subvol}"
        mkdir -p "$target"

        if findmnt -rn "$target" >/dev/null 2>&1; then
            log_msg "INFO" "  $subvol is already mounted at $target"
        else
            if mount -t btrfs -o "subvol=${subvol},${mount_opts}" "$mapper_path" "$target"; then
                log_msg "SUCCESS" "  Mounted $subvol -> $target"
            else
                log_msg "WARNING" "  Could not mount $subvol (subvolume may not exist)"
            fi
        fi
    done

    echo
    log_msg "SUCCESS" "All available subvolumes mounted successfully under $base_dir"
}

# Subcommand: unmount
cmd_unmount() {
    local base_dir="$DEFAULT_BASE"
    local luks_name="$DEFAULT_LUKS_NAME"
    local close_luks=true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--base)   base_dir="${2%/}"; shift 2 ;;
            -n|--name)   luks_name="$2"; shift 2 ;;
            --no-close)  close_luks=false; shift ;;
            -h|--help)   show_usage 0 ;;
            *)           log_msg "ERROR" "Unknown option: $1"; show_usage 1 ;;
        esac
    done

    log_msg "INFO" "Unmounting Time Machine subvolumes from $base_dir..."

    # Reverse order unmount
    local unmounted_any=false
    for (( i=${#STANDARD_SUBVOLUMES[@]}-1; i>=0; i-- )); do
        local subvol="${STANDARD_SUBVOLUMES[i]}"
        local target="${base_dir}/${subvol}"

        if findmnt -rn "$target" >/dev/null 2>&1; then
            if umount "$target"; then
                log_msg "SUCCESS" "  Unmounted $target"
                unmounted_any=true
            else
                log_msg "ERROR" "  Failed to unmount $target (files may be in use)"
                lsof +f -- "$target" 2>/dev/null || true
                exit 1
            fi
        fi
    done

    # Close LUKS mapper if requested
    local mapper_path="/dev/mapper/$luks_name"
    if [[ "$close_luks" = true && -b "$mapper_path" ]]; then
        # Check if mapper still in use
        if findmnt -rn -S "$mapper_path" >/dev/null 2>&1; then
            log_msg "WARNING" "Cannot close LUKS device $luks_name: other mounts are still active"
            findmnt -S "$mapper_path"
        else
            log_msg "INFO" "Closing LUKS device $luks_name..."
            if cryptsetup close "$luks_name"; then
                log_msg "SUCCESS" "LUKS device $luks_name locked and closed"
            else
                log_msg "ERROR" "Failed to close LUKS device $luks_name"
                exit 1
            fi
        fi
    fi

    echo
    log_msg "SUCCESS" "Unmount operation completed."
}

# Subcommand: status
cmd_status() {
    local base_dir="$DEFAULT_BASE"
    local luks_name="$DEFAULT_LUKS_NAME"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -m|--base) base_dir="${2%/}"; shift 2 ;;
            -n|--name) luks_name="$2"; shift 2 ;;
            -h|--help) show_usage 0 ;;
            *)         shift ;;
        esac
    done

    echo -e "${BOLD}${BLUE}=== Time Machine Mount Status ===${NC}"
    local mapper_path="/dev/mapper/$luks_name"

    if [[ -b "$mapper_path" ]]; then
        echo -e "${BOLD}LUKS Container:${NC}  ${GREEN}UNLOCKED${NC} ($mapper_path)"
        lsblk -o NAME,SIZE,FSTYPE,LABEL "$mapper_path" | tail -n +2 | sed 's/^/  /'
    else
        echo -e "${BOLD}LUKS Container:${NC}  ${YELLOW}LOCKED / NOT FOUND${NC} ($luks_name)"
    fi

    echo
    echo -e "${BOLD}Subvolume Mount Points under ${base_dir}:${NC}"
    printf "  %-14s %-20s %-12s %s\n" "SUBVOLUME" "STATUS" "USAGE" "MOUNTPOINT"
    printf "  %-14s %-20s %-12s %s\n" "─────────" "──────" "─────" "──────────"

    for subvol in "${STANDARD_SUBVOLUMES[@]}"; do
        local target="${base_dir}/${subvol}"
        if findmnt -rn "$target" >/dev/null 2>&1; then
            local usage
            usage=$(df -h "$target" 2>/dev/null | awk 'NR==2 {print $3 "/" $2}')
            printf "  %-14s ${GREEN}%-20s${NC} %-12s %s\n" "$subvol" "MOUNTED" "$usage" "$target"
        else
            printf "  %-14s ${DIM}%-20s${NC} %-12s %s\n" "$subvol" "Not mounted" "-" "$target"
        fi
    done
    echo
}

# Main routing
main() {
    if [[ $# -eq 0 ]] || [[ "${1:-}" =~ ^(-h|--help|help)$ ]]; then
        show_usage 0
    fi

    local is_help=false
    for arg in "$@"; do
        if [[ "$arg" =~ ^(-h|--help|help)$ ]]; then
            is_help=true
            break
        fi
    done

    if [[ "$is_help" = false ]]; then
        check_root
        check_dependencies
    fi

    local command="$1"
    shift

    case "$command" in
        mount)           cmd_mount "$@" ;;
        unmount|umount)  cmd_unmount "$@" ;;
        status)          cmd_status "$@" ;;
        -h|--help|help)  show_usage 0 ;;
        *)
            log_msg "ERROR" "Unknown command: $command"
            show_usage 1
            ;;
    esac
}

main "$@"
