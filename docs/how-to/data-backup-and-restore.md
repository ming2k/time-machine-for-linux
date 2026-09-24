# How to Back Up and Restore the `/data` Workspace

This guide shows how to safeguard your primary development disk (`/data` — containing active source code repositories, projects, and local datasets) and recover from corrupted project trees.

---

## 1. Backing Up Active Workspaces

Run `data-backup.sh` against the `@data` subvolume:

```bash
sudo ./bin/data-backup.sh \
  --source /data \
  --dest /mnt/@data \
  --snapshots /mnt/@snapshots
```

* **Intelligent Pruning**: Heavy compilation outputs and disposable package trees (`node_modules/`, `target/`, `build/`, `.venv/`, `.pytest_cache/`) are ignored via `config/data-backup-ignore`.
* **Snapshot Point**: A timestamped BTRFS snapshot (`data-backup-YYYYMMDDHHMMSS`) is created on `/mnt/@snapshots` after synchronization.

---

## 2. Restoring the Entire Data Disk

If the secondary data drive suffers catastrophic hardware failure and is replaced:

1. Format and mount the new `/data` partition (BTRFS recommended):
   ```bash
   sudo mkfs.btrfs -L data /dev/nvme0n1p1
   sudo mount /dev/nvme0n1p1 /data
   ```
2. Restore all project repositories:
   ```bash
   sudo ./bin/data-restore.sh \
     --source /mnt/@data \
     --dest /data \
     --no-snapshot
   ```

---

## 3. Instant Rollback of a Single Project from Snapshot

If you accidentally delete or destroy a project under `/data/projects/my-app`, you don't need a full restore. Retrieve it instantly from a snapshot:

```bash
# 1. Locate the snapshot containing your desired state
ls -d /mnt/@snapshots/data-backup-*

# 2. Copy the intact project tree back
rsync -aAXv /mnt/@snapshots/data-backup-20261024120000/projects/my-app/ /data/projects/my-app/
```

---

## 4. Using the Safehouse / Scratchpad (`/data/scratch`)

For temporary large files (downloading 50GB movies, unpacking raw datasets, disposable ISOs) that you **do not want backed up**:

### 1. Store Files Safely
Place files directly in `/data/scratch/` (or `/data/media/`):
```bash
cp /mnt/@media/movie.mkv /data/scratch/
```
`tm backup` automatically ignores this entire tree. Your backup drive will not be filled with disposable media.

### 2. Instant Wiping via BTRFS
When done, you can instantly wipe hundreds of gigabytes in 0.1 seconds without slow `rm -rf` recursion:
```bash
# Recreate the subvolume in milliseconds
btrfs subvolume delete /data/scratch && btrfs subvolume create /data/scratch
```
