# How to Back Up and Restore the User Home Directory

This guide demonstrates how to back up your personal user configuration (dotfiles, application states, browser profiles) and restore it onto the same machine or a fresh Linux distribution install.

---

## 1. Backing Up the User Home Tier

### Recommended Method: Unified CLI
```bash
# Back up /home to @home subvolume on mounted drive
sudo tm backup --home
```

*(Underlying engine: `sudo ./bin/home-backup.sh --source /home --dest /mnt/@home --snapshots /mnt/@snapshots`)*

* **Exclusions Applied**: Volatile caches (`.cache/`), browser caches, flatpak cache directories, and package store caches are pruned automatically based on `config/home-backup-ignore`.
* **Symlink Integrity**: Symlinks pointing to `/data/projects` are backed up as symlinks without dereferencing or traversing into the secondary disk.

---

## 2. Restoring User Configuration

### In-Place Restoration (Restoring Deleted Configs)
To restore after accidental config deletion or app corruption:

```bash
# 1. Preview changes
sudo tm restore home --source /mnt/@home --dest /home --dry-run

# 2. Restore execution (type uppercase 'YES' when prompted [INV-RESTORE-02])
# If /home is a BTRFS subvolume with local snapshot support:
sudo tm restore home --source /mnt/@home --dest /home --snapshots /home/.snapshots

# Or restore without snapshot:
sudo tm restore home --source /mnt/@home --dest /home --no-snapshot
```

### Migration to a Fresh Distro Install
When reinstalling Linux or switching distributions (e.g. Ubuntu to Debian/Arch):

1. Install the base OS.
2. Ensure your primary user has the same username (e.g. `ming`) and UID (usually `1000`).
3. Mount the backup drive to `/mnt` (via `sudo tm mount /dev/sdX`).
4. Restore home:
   ```bash
   sudo tm restore home \
     --source /mnt/@home \
     --dest /home \
     --no-snapshot
   ```
5. Ensure permissions remain correct:
   ```bash
   sudo chown -R ming:ming /home/ming
   ```
6. Log out and log back in. Your desktop settings, shell configs, credentials, and app states will be restored.
