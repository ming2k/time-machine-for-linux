# Getting Started with Time Machine for Linux

This tutorial walks you through setting up a multi-tiered backup system from scratch. In about 15 minutes, you will prepare an external drive, configure backup tiers, perform your first backup, and inspect the resulting BTRFS snapshots.

---

## 1. What You Will Build

You will configure a reliable 4-tier storage backup architecture:

```text
[Local Machine]
  ├── / (Root)            ──> System tier (OS & packages)
  ├── /home               ──> Home tier (Configs & dotfiles)
  └── /data               ──> Data tier (Active project trees)
                                   │
                                   │ rsync + BTRFS snapshots
                                   ▼
[External Drive (/mnt)]
  ├── @system             ──> OS backup
  ├── @home               ──> User backup
  ├── @data               ──> Projects backup
  ├── @archive            ──> Cold storage (append-only)
  └── @snapshots          ──> Instant rollback points
```

---

## 2. Requirements

- A Linux system with `rsync`, `btrfs-progs`, and `cryptsetup` installed.
- An external storage drive (e.g. `/dev/sdb`, with all important data backed up elsewhere).
- Root privileges (`sudo`).

---

## 3. Step 1: Format External Drive with BTRFS & LUKS

Use the unified CLI to encrypt the external disk with LUKS2 and establish all 5 standard subvolumes (`@system`, `@home`, `@data`, `@archive`, `@snapshots`):

```bash
# WARNING: This will format the specified drive. Replace /dev/sdX with your actual drive.
sudo ./tm format -d /dev/sdX
```

Follow the prompts to enter your encryption passphrase. The tool formats the partition, establishes standard subvolumes, and locks the device.

---

## 4. Step 2: Mount Subvolumes with One Command

Unlock the LUKS container and mount all subvolumes with zstd compression in one step:

```bash
sudo ./tm mount /dev/sdX
```

Inspect the mount status and subvolume disk utilization anytime:
```bash
sudo ./tm status
```

---

## 5. Step 3: Initialize Ignore Configurations

Configuration files contain exclusion patterns tailored to your machine. Copy the example templates to create your active configurations:

```bash
cp config/system-backup-ignore.example config/system-backup-ignore
cp config/home-backup-ignore.example config/home-backup-ignore
cp config/data-backup-ignore.example config/data-backup-ignore
```

The defaults automatically exclude disposable caches (`.cache/`, `node_modules/`, `target/`, temporary sockets, and virtual filesystems).

---

## 6. Step 4: Perform Your First Full Backup

Run all three active tiers (System + Home + Data) sequentially with a single consolidated confirmation prompt:

```bash
sudo ./tm backup
```

*(Alternatively, you can target a specific tier: `sudo ./tm backup --data` or `sudo ./tm backup --home`)*

---

## 7. Step 5: Verify Your Time Machine Snapshots

Every successful run automatically takes an immutable BTRFS snapshot. Inspect your snapshot history:

```bash
sudo ./tm snapshots
```

Output displays snapshots tagged with tiers and human-readable timestamps:
```text
=== Current BTRFS Snapshots in /mnt/@snapshots ===
  SNAPSHOT NAME                        TIER         TIMESTAMP
  ───────────── ──── ─────────
  system-backup-20261024120000         system       2026-10-24 12:00:00
  home-backup-20261024120500           home         2026-10-24 12:05:00
  data-backup-20261024121000           data         2026-10-24 12:10:00
Total: 3 snapshots
```

---

## 8. Step 6: Unmount and Lock Drive

When your backup completes and you want to unplug your external drive, cleanly unmount all subvolumes and lock the LUKS container with a single command:

```bash
sudo ./tm unmount
```

You now have a fully operational, multi-tiered BTRFS time machine!

---

## Next Steps

- Consult [How-to: Archive Cold Data](../how-to/archive-cold-data.md) when you need to retire old projects.
- Read [Explanation: Backup Principles](../explanation/backup-principles.md) to understand why data is classified by rarity tiers.
