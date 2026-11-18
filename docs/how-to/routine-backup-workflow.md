# How to Run Routine Backups and Restores (End-to-End Workflow)

This guide provides the standard, end-to-end operational workflow for daily backups and restorations using **Time Machine for Linux**.

---

## 1. Quick Reference (Cheat Sheet)

If you are already familiar with the system and need the commands quickly:

```bash
# 1. Connect drive and mount all subvolumes
sudo ./tools/mountctl.sh mount -d /dev/sdX1

# 2. Check mount and capacity status
sudo ./tools/mountctl.sh status

# 3. Run backup (one tier at a time; all three = full backup)
sudo ./bin/system-backup.sh --dest /mnt/@system --snapshots /mnt/@snapshots
sudo ./bin/home-backup.sh   --dest /mnt/@home   --snapshots /mnt/@snapshots
sudo ./bin/data-backup.sh   --dest /mnt/@data   --snapshots /mnt/@snapshots

# 4. Verify snapshots
sudo ./tools/prune-snapshots.sh --list

# 5. Clean unmount and lock container before unplugging
sudo ./tools/mountctl.sh unmount
```

---

## 2. Standard Daily Backup Workflow

The standard operational lifecycle consists of six steps:

```text
[Plug in Drive] ──> [mountctl mount] ──> [mountctl status] ──> [tier backups] ──> [mountctl unmount] ──> [Unplug]
```

### Step 1: Identify External Block Device
Insert your external backup drive (e.g. USB/Thunderbolt) and inspect device nodes:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
```

*Identify the external partition* (e.g. `sda1`, `sdb1`). Ensure you do not confuse it with internal NVMe disks.

### Step 2: Unlock LUKS & Mount Subvolumes
Unlock the encrypted LUKS container and mount all standard BTRFS subvolumes with `zstd` compression:

```bash
sudo ./tools/mountctl.sh mount -d /dev/sdX1
```
*(Replace `/dev/sdX1` with your actual partition, e.g. `/dev/sda1`)*

Enter your LUKS passphrase when prompted. This automatically mounts:
- `@system`    -> `/mnt/@system`
- `@home`      -> `/mnt/@home`
- `@data`      -> `/mnt/@data`
- `@archive`   -> `/mnt/@archive`
- `@snapshots` -> `/mnt/@snapshots`

### Step 3: Check Drive Health & Capacity
Verify that all subvolumes mounted correctly and adequate disk space is available:

```bash
sudo ./tools/mountctl.sh status
```

> **BTRFS Best Practice**: Maintain at least 15% free unallocated space on BTRFS filesystems to prevent Copy-on-Write performance degradation or allocation deadlocks.

### Step 4: Execute Backup

Choose the appropriate scope:

#### Option A: Full Backup — All Three Tiers (Recommended for Routine Use)
There is no combined wrapper command. Run the three engines in sequence; each one confirms before it starts:
```bash
sudo ./bin/system-backup.sh --dest /mnt/@system --snapshots /mnt/@snapshots
sudo ./bin/home-backup.sh   --dest /mnt/@home   --snapshots /mnt/@snapshots
sudo ./bin/data-backup.sh   --dest /mnt/@data   --snapshots /mnt/@snapshots
```
If a tier fails, fix it before running the next one. Chaining with `&&` stops the sequence at the first failure.

#### Option B: System-Only Backup
Captures packages, `/etc` configurations, and system binaries under `/` (excluding `/home` and `/data`):
```bash
sudo ./bin/system-backup.sh --dest /mnt/@system --snapshots /mnt/@snapshots
```
*Best used right before or after major system kernel/driver updates.*

#### Option C: Home-Only Backup
Captures user configurations, dotfiles, app profiles, and browser data (excluding heavy temporary caches like `.cache/`, `node_modules/`, `target/`):
```bash
sudo ./bin/home-backup.sh --dest /mnt/@home --snapshots /mnt/@snapshots
```
*Best used after updating dotfiles, IDE settings, or workspace configurations.*

### Step 5: Verify Snapshots
Each successful backup run automatically creates a read-only, timestamped BTRFS snapshot:

```bash
sudo ./tools/prune-snapshots.sh --list
```
*Verify that a new snapshot named `<tier>-backup-YYYYMMDDHHMMSS` has been generated.*

### Step 6: Safely Unmount & Disconnect
Never pull the USB cable without unmounting! Dirty file pages and BTRFS metadata remain in kernel cache until safely synchronized:

```bash
sudo ./tools/mountctl.sh unmount
```

This safely unmounts all subvolumes in reverse dependency order and locks the LUKS container (`backup_crypt`). After the script reports `[SUCCESS]`, disconnect the external drive.

---

## 3. First-Time Setup: Initializing a New Backup Drive

If your drive (e.g. `/dev/sda1`) is new or uninitialized, format it once before entering the standard workflow.

> ⚠️ **Warning**: Formatting will destroy all existing data on the specified partition.

```bash
# 1. Format partition with LUKS2 encryption and standard BTRFS subvolumes
sudo ./tools/format-btrfs-luks.sh -d /dev/sdX1

# Type 'FORMAT' to confirm, then provide a strong encryption passphrase.

# 2. Test mount to verify subvolumes
sudo ./tools/mountctl.sh mount -d /dev/sdX1
sudo ./tools/mountctl.sh status
sudo ./tools/mountctl.sh unmount
```

---

## 4. Restoration Workflows

### Scenario A: In-Place Rollback (Fixing Corrupted Configs or Packages)

When your system is running but configurations or packages became broken:

```bash
# 1. Mount external drive
sudo ./tools/mountctl.sh mount -d /dev/sdX1

# 2. ALWAYS preview with Dry Run first (mandatory safety practice)
sudo ./bin/home-restore.sh --source /mnt/@home --dest /home --dry-run
# or for system:
sudo ./bin/system-restore.sh --source /mnt/@system --dest / --dry-run

# 3. Execute live restore (with local BTRFS snapshot, or --no-snapshot across disks)
sudo ./bin/home-restore.sh --source /mnt/@home --dest /home --snapshots /home/.snapshots
# or:
# sudo ./bin/home-restore.sh --source /mnt/@home --dest /home --no-snapshot

# 4. Safely unmount
sudo ./tools/mountctl.sh unmount
```

### Scenario B: Distro Migration (Restoring `/home` onto a Fresh OS)

When switching Linux distributions or reinstalling from scratch:

1. Install the new OS. Ensure your user account has the same username and UID (`id -u`, usually `1000`).
2. Mount the backup drive:
   ```bash
   sudo ./tools/mountctl.sh mount -d /dev/sdX1
   ```
3. Restore home without requiring snapshot infrastructure on the new target:
   ```bash
   sudo ./bin/home-restore.sh --source /mnt/@home --dest /home --no-snapshot
   sudo chown -R $USER:$USER /home/$USER
   ```
4. Unmount and re-login:
   ```bash
   sudo ./tools/mountctl.sh unmount
   ```

---

## 5. Routine Maintenance

### Snapshot Pruning
To prevent snapshots from accumulating and consuming disk space:

```bash
sudo ./tools/mountctl.sh mount -d /dev/sdX1

# Preview prune candidates (safe dry-run by default)
sudo ./tools/prune-snapshots.sh -t home -k 10    # Keep latest 10 home snapshots
sudo ./tools/prune-snapshots.sh -t system -k 5   # Keep latest 5 system snapshots

# Apply pruning
sudo ./tools/prune-snapshots.sh -t home -k 10 --apply
sudo ./tools/prune-snapshots.sh -t system -k 5 --apply
```

### BTRFS Balance
Reclaim unallocated raw space from sparse chunks:

```bash
sudo ./tools/balance-btrfs.sh /mnt/@system --quick
sudo ./tools/mountctl.sh unmount
```

---

## 6. Safety Invariants

- **Symlink Preservation**: Rsync preserves symlinks as symlinks. The system tier explicitly excludes `/home` and `/data`, so it does not copy those trees into `@system`.
- **Pre-Restore Snapshot**: When `--snapshots` is provided, restore creates a pre-restore snapshot of the target destination before overwriting files. If snapshot creation fails, the restore aborts.
- **Cache Exclusion**: Exclusion rules in `config/*-backup-ignore` ensure build caches (`node_modules`, `target`, `.venv`, `.cache`) are filtered before touching storage.
