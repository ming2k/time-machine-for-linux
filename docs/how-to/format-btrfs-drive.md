# How to Format and Prepare an Encrypted BTRFS Backup Drive

This guide explains how to format an external storage device using LUKS encryption and create the 5 required BTRFS subvolumes.

---

## 1. Automated Setup (Recommended)

Use the built-in formatting script:

```bash
# WARNING: All existing data on the device will be destroyed!
sudo ./tools/format-btrfs-luks.sh -d /dev/sdX
```

The script performs the following automatically:
1. Validates the device is a valid block device and ensures it is not mounted on critical system paths (`/`, `/home`, `/data`).
2. Prompts for explicit typed confirmation (`FORMAT`).
3. Formats the device with LUKS2 encryption using Argon2id key derivation.
4. Opens the container (default mapper name: `backup_crypt`).
5. Formats the filesystem with BTRFS (label: `TimeMachine`).
6. Creates standard subvolumes:
   - `@system`: Operating system backups
   - `@home`: User configuration and dotfile backups
   - `@data`: Active development workspace backups
   - `@archive`: Cold storage append-only sediment
   - `@snapshots`: BTRFS timestamped historical rollback snapshots
7. Closes and locks the device cleanly, printing the recommended `tools/mountctl.sh mount` command.

---

## 2. Manual Setup

If you prefer to partition or configure options manually:

```bash
# 1. Encrypt partition
sudo cryptsetup luksFormat --type luks2 /dev/sdX1
sudo cryptsetup open /dev/sdX1 backup_crypt

# 2. Format with BTRFS
sudo mkfs.btrfs -L "TimeMachine" /dev/mapper/backup_crypt

# 3. Mount root subvolume temporarily
sudo mkdir -p /tmp/btrfs-init
sudo mount /dev/mapper/backup_crypt /tmp/btrfs-init

# 4. Create subvolumes
sudo btrfs subvolume create /tmp/btrfs-init/@system
sudo btrfs subvolume create /tmp/btrfs-init/@home
sudo btrfs subvolume create /tmp/btrfs-init/@data
sudo btrfs subvolume create /tmp/btrfs-init/@archive
sudo btrfs subvolume create /tmp/btrfs-init/@snapshots

# 5. Clean up
sudo umount /tmp/btrfs-init
sudo cryptsetup close backup_crypt
```
