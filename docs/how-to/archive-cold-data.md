# How to Archive Cold Data to `@archive`

This practical guide demonstrates how to safely retire finished projects, completed videos, or large dormant datasets from your active internal storage to external cold storage (`@archive`), freeing up internal NVMe space without risk of data loss.

---

## 1. Prerequisites

1. An external backup drive formatted with a BTRFS `@archive` subvolume (and optionally `@snapshots`).
2. The external drive mounted to `/mnt` (via `sudo ./tm mount /dev/sdX`).
3. Root or `sudo` privileges.

---

## 2. Defensive Dual-Staging Architecture

The system operates a **Defensive Dual-Staging Model**:
- **Primary Canonical Staging (`/data/archive/`)**: The official long-term home for cold data staged on your secondary high-capacity NVMe drive.
- **Defensive Historical Staging (`/home/*/archive/`)**: Acknowledges legacy or habitual archive directories in user home folders so that no assets are missed.

Both staging paths are **strictly excluded from routine daily backups** (`tm backup`) by contract, ensuring cold archives never contaminate hot/warm mirrors.

---

## 3. Running the Archive Sync

When your external backup drive is plugged in and mounted at `/mnt`:

### Autodiscover and Archive All Staging Exits
Simply run:
```bash
sudo ./tm archive
```

* **Autodiscovery**: Automatically scans for non-empty exits at `/data/archive/` and `/home/*/archive/`, presents the list and total sizes, and synchronizes all pending exits with one confirmation.
* **Append-Only guarantee**: The archive engine **NEVER uses `--delete`**. Any data already existing on `@archive` remains permanently preserved.
* **Metadata preservation**: Full Linux permissions, timestamps, ACLs, and ownership are transferred.
* **BTRFS Read-Only snapshot**: Automatically creates an immutable snapshot (e.g. `/mnt/@snapshots/archive-batch-20261024120000`) for tamper protection.

---

## 4. Archiving with Checksum & Freeing Local NVMe Space

For long-term assets where bit-for-bit integrity must be verified before local deletion, use `--checksum` and `--clean-source`:

```bash
sudo ./tm archive --checksum --clean-source
```

**Workflow:**
1. Synchronizes all new files across active staging exits to `/mnt/@archive`.
2. Verifies bitstream checksums against physical media.
3. Generates a read-only BTRFS snapshot on `@snapshots`.
4. Prompts you explicitly for each staging exit: `Permanently delete contents of '<path>' to free local disk space? [y/N]`
5. Only upon answering `y`, local files are deleted, instantly recovering gigabytes of internal disk space.

---

## 5. Selective Single-Directory Archiving

If you wish to archive a specific directory without autodiscovery:

```bash
# Archive a specific inactive project directly
sudo ./tm archive /home/ming/archive/projects/ --dest /mnt/@archive/projects/ --clean-source
```

---

## 6. Verifying Archive Storage

Inspect your archived contents on the backup drive:

```bash
# List archived items
ls -la /mnt/@archive

# List read-only archive snapshot batches
sudo btrfs subvolume list /mnt | grep archive-batch
```
