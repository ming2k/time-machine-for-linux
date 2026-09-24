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

Use the automated initialization script to encrypt the external disk with LUKS2 and create all standard subvolumes (`@system`, `@home`, `@data`, `@archive`, `@snapshots`):

```bash
# WARNING: This will format the specified drive. Replace /dev/sdX with your actual drive.
sudo ./tools/format-btrfs-luks.sh -d /dev/sdX
```

Follow the prompts to enter your encryption passphrase. The script will format the partition, establish subvolumes, and close the device.

---

## 4. Step 2: Mount Subvolumes with One Command

Instead of manually running 5 mount commands, use `mountctl.sh` to unlock the LUKS container and mount all subvolumes with zstd compression in one step:

```bash
sudo ./tools/mountctl.sh mount -d /dev/sdX -m /mnt
```

Inspect the mount status anytime:
```bash
sudo ./tools/mountctl.sh status -m /mnt
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

You can run all three active tiers in an automated sequence using the unified orchestrator:

```bash
# Run System, Home, and Data backups sequentially with one unified prompt
sudo ./tools/backup-all.sh -m /mnt
```

*(Alternatively, you can run each tier individually: `sudo ./bin/system-backup.sh ...`, `sudo ./bin/home-backup.sh ...`, `sudo ./bin/data-backup.sh ...`)*

---

## 7. Step 5: Verify Your Time Machine Snapshots

Every successful run automatically takes an immutable BTRFS snapshot. Inspect your snapshot tree:

```bash
sudo btrfs subvolume list /mnt | grep backup-
```

Output will display snapshots tagged with timestamps:
```text
ID 265 gen 123 top level 5 path @snapshots/system-backup-20261024120000
ID 266 gen 124 top level 5 path @snapshots/home-backup-20261024120500
ID 267 gen 125 top level 5 path @snapshots/data-backup-20261024121000
```

---

## 8. Step 6: Unmount and Lock Drive

When your backup completes and you want to unplug your external drive, cleanly unmount all subvolumes and lock the LUKS device with a single command:

```bash
sudo ./tools/mountctl.sh unmount -m /mnt
```

You now have a fully operational, multi-tiered BTRFS time machine!

---

## Next Steps

- Consult [How-to: Archive Cold Data](../how-to/archive-cold-data.md) when you need to retire old projects.
- Read [Explanation: Backup Principles](../explanation/backup-principles.md) to understand why data is classified by rarity tiers.
