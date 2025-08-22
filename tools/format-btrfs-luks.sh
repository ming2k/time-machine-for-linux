#!/bin/bash

set -euo pipefail

DEVICE=""
LUKS_NAME="encrypted_root"

usage() {
    echo "Usage: $0 -d <device>"
    echo "  -d <device>    Block device to format (e.g., /dev/sda2)"
    echo ""
    echo "Example: $0 -d /dev/sda2"
    echo ""
    echo "WARNING: This will DESTROY all data on the specified device!"
    exit 1
}

while getopts "d:h" opt; do
    case $opt in
        d)
            DEVICE="$OPTARG"
            ;;
        h)
            usage
            ;;
        *)
            usage
            ;;
    esac
done

if [[ -z "$DEVICE" ]]; then
    echo "Error: Device not specified"
    usage
fi

if [[ ! -b "$DEVICE" ]]; then
    echo "Error: $DEVICE is not a valid block device"
    exit 1
fi

echo "WARNING: This will DESTROY all data on $DEVICE"
echo "Device: $DEVICE"
echo "LUKS name: $LUKS_NAME"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 1
fi

echo "Setting up LUKS encryption on $DEVICE..."
cryptsetup luksFormat --type luks2 "$DEVICE"

echo "Opening LUKS device..."
cryptsetup open "$DEVICE" "$LUKS_NAME"

LUKS_DEVICE="/dev/mapper/$LUKS_NAME"

echo "Creating Btrfs filesystem on $LUKS_DEVICE..."
mkfs.btrfs -f "$LUKS_DEVICE"

echo "Mounting filesystem temporarily..."
TEMP_MOUNT=$(mktemp -d)
mount "$LUKS_DEVICE" "$TEMP_MOUNT"

echo "Creating Btrfs subvolumes..."
btrfs subvolume create "$TEMP_MOUNT/@"
btrfs subvolume create "$TEMP_MOUNT/@snapshots"
btrfs subvolume create "$TEMP_MOUNT/@data"

# echo "Setting default subvolume to @..."
# btrfs subvolume set-default "$TEMP_MOUNT/@"

echo "Listing created subvolumes..."
btrfs subvolume list "$TEMP_MOUNT"

echo "Unmounting temporary mount..."
umount "$TEMP_MOUNT"
rmdir "$TEMP_MOUNT"

echo "Closing LUKS device..."
cryptsetup close "$LUKS_NAME"

echo ""
echo "Setup complete!"
