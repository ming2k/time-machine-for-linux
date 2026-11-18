# How to Archive Cold Data to `@archive`

This guide shows how to retire finished projects, completed videos, or large dormant datasets from active internal storage to external cold storage (`@archive`), freeing internal space while keeping the archived copy.

---

## 1. Prerequisites

1. An external backup drive formatted with a BTRFS `@archive` subvolume (and optionally `@snapshots`).
2. The external drive mounted to `/mnt` (via `sudo ./tools/mountctl.sh mount -d /dev/sdX`).
3. Root or `sudo` privileges.

---

## 2. Staging Paths

The archive script looks at two locations:
- **Primary staging (`/data/archive/`)**: the usual cold-data staging directory on the secondary drive.
- **Home staging (`/home/*/archive/`)**: legacy or per-user archive directories.

Both paths are excluded from routine tier backups (`config/data-backup-ignore` and `config/home-backup-ignore`), so cold archives are not copied into the hot/warm mirrors.

---

## 3. Running the Archive Sync

When your external backup drive is plugged in and mounted at `/mnt`:

### Autodiscover and Archive All Staging Paths
Run:
```bash
sudo ./bin/archive-sync.sh
```

* **Autodiscovery**: Scans for non-empty paths at `/data/archive/` and `/home/*/archive/`, presents the list and total sizes, and synchronizes all pending paths with one confirmation.
* **No destination deletion**: The archive engine does not pass `--delete`. Files already present on `@archive` are not removed by the synchronization.
* **Metadata preservation**: Linux permissions, timestamps, ACLs, and ownership are transferred.
* **Read-only snapshot**: After a successful batch, creates a read-only snapshot such as `/mnt/@snapshots/archive-batch-20261024120000`. This is a point-in-time snapshot, not a tamper-proof or WORM guarantee.

---

## 4. Archiving with Checksum & Freeing Local NVMe Space

For long-term assets where you want content comparison before local deletion, use `--checksum` and `--clean-source`:

```bash
sudo ./bin/archive-sync.sh --checksum --clean-source
```

**Workflow:**
1. Synchronizes all new files across active staging paths to `/mnt/@archive`.
2. Compares file contents by checksum instead of modification time and size.
3. Creates a read-only BTRFS snapshot on `@snapshots`.
4. Prompts for each staging path: `Permanently delete contents of '<path>' to free local disk space? [y/N]`
5. Only on `y`, local files are deleted.

---

## 5. Selective Single-Directory Archiving

If you wish to archive a specific directory without autodiscovery:

```bash
# Archive a specific inactive project directly
sudo ./bin/archive-sync.sh /home/ming/archive/projects/ --dest /mnt/@archive/projects/ --clean-source
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
