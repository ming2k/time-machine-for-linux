# How to Archive Cold Data to `@archive`

This practical guide demonstrates how to safely retire finished projects, completed videos, or large dormant datasets from your active internal storage (`/data`) to external cold storage (`@archive`), freeing up internal NVMe space without risk of data loss.

---

## 1. Prerequisites

1. An external backup drive formatted with a BTRFS `@archive` subvolume (and optionally `@snapshots`).
2. The external drive mounted to `/mnt` (e.g. `/mnt/@archive` and `/mnt/@snapshots`).
3. Root or `sudo` privileges.

---

## 2. Managing Cold Data Locally (Staging Approach)

Instead of maintaining a separate permanent internal disk for cold storage, use a local staging folder on `/data`:

```bash
# Create local staging directory if not already existing
mkdir -p /data/archive
```

When a project is finished or assets are no longer actively accessed:
```bash
# Move inactive project to local staging folder
mv /data/projects/old-website-2023 /data/archive/
```

---

## 3. Running the Archive Sync

When your external backup drive is plugged in and mounted at `/mnt`:

### Basic Archive Sync (Append-Only)
```bash
sudo ./bin/archive-sync.sh --source /data/archive/ --dest /mnt/@archive --snapshots /mnt/@snapshots
```

* **Append-Only guarantee**: Unlike `system-backup.sh` or `data-backup.sh`, the archive script **never uses `--delete`**. Any data already existing on `@archive` remains permanently preserved.
* **Metadata preservation**: Full permissions, timestamps, ACLs, and ownership are transferred.
* **BTRFS Read-Only snapshot**: Automatically creates an immutable snapshot (e.g. `/mnt/@snapshots/archive-batch-20261024120000`) for tamper protection.

---

## 4. Archiving with Content Checksum Verification

For long-term assets where bit-for-bit integrity must be verified before local deletion, use the `--checksum` (`-c`) flag:

```bash
sudo ./bin/archive-sync.sh \
  --source /data/archive/ \
  --dest /mnt/@archive \
  --snapshots /mnt/@snapshots \
  --checksum
```

---

## 5. Freeing Local NVMe Space Safely

To safely reclaim internal disk space, pass `--clean-source`:

```bash
sudo ./bin/archive-sync.sh \
  --source /data/archive/ \
  --dest /mnt/@archive \
  --snapshots /mnt/@snapshots \
  --checksum \
  --clean-source
```

**Workflow:**
1. The script synchronizes all new files to `/mnt/@archive`.
2. Verifies bitstream checksums.
3. Generates a read-only BTRFS snapshot on `@snapshots`.
4. Prompts you explicitly: `Do you want to permanently delete local source files in '/data/archive' to free disk space? [y/N]`
5. Only upon answering `y`, the local `/data/archive/` staging directory is emptied.

---

## 6. Selective Ad-Hoc Directory Archiving

If you prefer not to stage files into `/data/archive/`, you can archive any directory directly:

```bash
# Archive a specific inactive project directly
sudo ./bin/archive-sync.sh \
  --source /data/projects/legacy-firmware-v1 \
  --dest /mnt/@archive/projects/ \
  --clean-source
```

---

## 7. Verifying Archive Storage

Inspect your archived contents on the backup drive:

```bash
# List archived items
ls -la /mnt/@archive

# List read-only archive snapshot batches
sudo btrfs subvolume list /mnt | grep archive-batch
```
