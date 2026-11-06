# How to Back Up and Restore the Operating System

This guide covers operating system backup using `tm backup --system` (engine: `bin/system-backup.sh`) and disaster recovery using `tm restore system` (engine: `bin/system-restore.sh`), including recovery from a Live USB environment.

---

## 1. Operating System Backup

The system backup captures installed packages, boot configuration, services, and system binaries under `/`, while strictly excluding `/home/` and `/data/`.

### Recommended Method: Unified CLI
```bash
# Run system backup against mounted drive (default /mnt)
sudo tm backup --system

# Specify custom mount base if needed
sudo tm backup --system -m /mnt
```

*(Underlying engine: `sudo ./bin/system-backup.sh --source / --dest /mnt/@system --snapshots /mnt/@snapshots`)*

### Preflight Checks
Before copying files, the engine checks:
- Available disk space on `/mnt/@system`.
- Health of the destination BTRFS filesystem.
- Snapshot history and staleness.

A preview prompt summarizes the operation before modifying destination files.

---

## 2. Restoring the System (Online Mode)

If your system is functional but specific binaries or `/etc` configuration got corrupted:

### Step 1: Preview with Dry Run
```bash
sudo tm restore system --source /mnt/@system --dest / --dry-run
```

### Step 2: Execute Restore
```bash
# If your destination is on a BTRFS filesystem with local snapshot subvolume (e.g. /.snapshots):
sudo tm restore system --source /mnt/@system --dest / --snapshots /.snapshots

# If restoring across disks or without local BTRFS snapshots:
sudo tm restore system --source /mnt/@system --dest / --no-snapshot
```

* **Fail-Closed Safety [INV-RESTORE-01]**: Under ADR-0003, if `--snapshots` is specified, snapshot creation MUST succeed on the destination filesystem; otherwise, the restore immediately aborts to prevent unshielded overwrites.
* **Affirmation Prompt [INV-RESTORE-02]**: The script requires typing uppercase `YES` to authorize execution. Pressing Enter or typing lowercase `y` immediately aborts.
* **Virtual Filesystem Exclusion [INV-RESTORE-03]**: Virtual directories (`/dev/*`, `/proc/*`, `/sys/*`, `/run/*`, `/tmp/*`) and external mountpoints (`/mnt/*`, `/media/*`) are automatically excluded from rsync to protect active kernel subsystems and mounted backup volumes.

---

## 3. Disaster Recovery (from a Live USB)

When the machine fails to boot:

1. **Boot into a Linux Live USB** (e.g. Arch, Fedora, or Ubuntu Live image).
2. **Unlock and mount internal drive**:
   ```bash
   sudo cryptsetup open /dev/nvme1n1p2 root_crypt
   sudo mount -o subvol=@ /dev/mapper/root_crypt /target
   ```
3. **Unlock and mount external backup drive**:
   ```bash
   sudo cryptsetup open /dev/sda1 backup_crypt
   sudo mount -o subvol=@system /dev/mapper/backup_crypt /backup_system
   ```
4. **Clone or navigate to the repository on Live USB**:
   ```bash
   cd time-machine-for-linux
   ```
5. **Run restore targeting `/target` (using `--no-snapshot` for cross-disk bare-metal recovery)**:
   ```bash
   sudo ./bin/system-restore.sh \
     --source /backup_system \
     --dest /target \
     --no-snapshot
   ```
   *(When prompted, type uppercase `YES` to confirm.)*
6. **Reinstall GRUB / update initramfs** (if bootloader was damaged):
   ```bash
   arch-chroot /target
   update-initramfs -u
   grub-install /dev/nvme1n1
   exit
   ```
7. **Reboot**: Cleanly unmount filesystems and reboot into your restored OS.
