# How to Back Up and Restore the Operating System

This guide covers operating system backup with `system-backup.sh` and disaster recovery using `system-restore.sh` (including recovery from a Live USB environment).

---

## 1. Operating System Backup

The system backup captures installed packages, boot configuration, services, and system binaries under `/`, while strictly excluding `/home/` and `/data/`.

```bash
sudo ./bin/system-backup.sh \
  --source / \
  --dest /mnt/@system \
  --snapshots /mnt/@snapshots
```

### Preflight Checks
Before copying files, the script checks:
- Available disk space on `/mnt/@system`.
- Health of the destination BTRFS filesystem.
- Snapshot history and staleness.

A preview prompt will summarize the operation before modifying destination files.

---

## 2. Restoring the System (Online Mode)

If your system is functional but specific binaries or `/etc` configuration got corrupted:

### Step 1: Preview with Dry Run
```bash
sudo ./bin/system-restore.sh \
  --source /mnt/@system \
  --dest / \
  --dry-run
```

### Step 2: Execute Restore with Safety Snapshot
```bash
sudo ./bin/system-restore.sh \
  --source /mnt/@system \
  --dest / \
  --snapshots /mnt/@snapshots
```

* The script automatically generates a `pre-restore-system-YYYYMMDDHHMMSS` snapshot of `/` before overwriting files.
* If anything goes wrong, you can roll back using the pre-restore snapshot.

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
   sudo mount -o subvol=@snapshots /dev/mapper/backup_crypt /backup_snapshots
   ```
4. **Clone or navigate to the repository on Live USB**:
   ```bash
   cd time-machine-for-linux
   ```
5. **Run restore targeting `/target`**:
   ```bash
   sudo ./bin/system-restore.sh \
     --source /backup_system \
     --dest /target \
     --snapshots /backup_snapshots
   ```
6. **Reinstall GRUB / update initramfs** (if bootloader was damaged):
   ```bash
   arch-chroot /target
   update-initramfs -u
   grub-install /dev/nvme1n1
   exit
   ```
7. **Reboot**: Cleanly unmount filesystems and reboot into your restored OS.
