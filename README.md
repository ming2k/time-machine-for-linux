# Time Machine for Linux

> Apple Time Machine-like tiered backup and immutable cold archiving for Linux, powered by BTRFS Copy-on-Write snapshots and rsync.

---

## Why Time Machine for Linux?

Most Linux backup scripts treat the entire machine as a single monolithic bucket, leading to bloated backups, slow syncs, and risky restores. **Time Machine for Linux** splits your storage into clean, independent tiers:

- **Independent Distro Switching**: Restore your personal `/home` configuration onto a fresh distribution without restoring outdated OS binaries from `/`.
- **Zero Cache Hoarding**: Intelligent blacklist rules strip out multi-gigabyte build artifacts (`node_modules`, `target`, `.venv`) and disposable package caches before files touch the backup disk.
- **Instant BTRFS Snapshots**: Rsync updates the live subvolume, then BTRFS locks the exact state in milliseconds using Copy-on-Write snapshots.
- **Append-Only Cold Archiving**: Retire finished projects and large media from internal NVMe drives to external cold storage with guaranteed **never-delete** semantics.

---

## Storage Topology

```text
[Internal Disks (Hot / Warm)]
  ├── NVMe 1 (Hot)  : / (OS root) + /home (Configs & dotfiles)
  └── NVMe 2 (Warm) : /data (Active projects & workspaces)
                           │
                           │ Periodic Sync or Manual Archive
                           ▼
[External Drive (BTRFS Backup & Cold Storage)]
  ├── @system     <── bin/system-backup.sh (Mirror sync + safety snapshots)
  ├── @home       <── bin/home-backup.sh   (Mirror sync + safety snapshots)
  ├── @data       <── bin/data-backup.sh   (Mirror sync + safety snapshots)
  ├── @archive    <── bin/archive-sync.sh  (Append-only + checksums)
  └── @snapshots  <── Point-in-time immutable BTRFS rollback snapshots
```

---

## Quickstart

All operations are unified under the authoritative CLI entrypoint: `./tm` (or `bin/tm`).

### 1. Initialize External Drive
Format an external drive with LUKS2 encryption and standard BTRFS subvolumes:
```bash
sudo ./tm format -d /dev/sdX
```

### 2. Mount All Subvolumes (One-Click)
Unlock LUKS and mount all subvolumes with zstd compression:
```bash
sudo ./tm mount /dev/sdX
```

### 3. Configure Ignore Rules
Copy default exclusion templates:
```bash
cp config/system-backup-ignore.example config/system-backup-ignore
cp config/home-backup-ignore.example config/home-backup-ignore
cp config/data-backup-ignore.example config/data-backup-ignore
```

### 4. Run Backups
**Default behavior runs all active tiers** (System + Home + Data) sequentially with 1 confirmation:
```bash
sudo ./tm backup
```
*(Or target a specific tier: `sudo ./tm backup --data`)*

### 5. Archive Cold Data & Safely Unmount
```bash
# Safely retire completed projects to cold storage (Append-Only)
sudo ./tm archive /data/archive/ --checksum --clean-source

# Unmount all subvolumes and lock LUKS device before unplugging
sudo ./tm unmount
```

---

## Documentation Matrix

Detailed documentation is organized using the [Diátaxis](https://diataxis.fr/) framework:

| Quadrant | Focus | Description |
|---|---|---|
| **[Tutorials](docs/tutorials/)** | Learning | [Getting Started from Scratch](docs/tutorials/getting-started.md) — 15-minute complete walkthrough. |
| **[How-To Guides](docs/how-to/)** | Problem Solving | Practical runbooks for [System Restore](docs/how-to/system-backup-and-restore.md), [Home Migration](docs/how-to/home-backup-and-restore.md), [Data Recovery](docs/how-to/data-backup-and-restore.md), [Cold Archiving](docs/how-to/archive-cold-data.md), [Drive Formatting](docs/how-to/format-btrfs-drive.md), and [Snapshot Pruning & BTRFS Balance](docs/how-to/maintain-btrfs-and-prune-snapshots.md). |
| **[Reference](docs/reference/)** | Lookup | Authoritative [CLI Parameter Specs](docs/reference/cli.md) and [Configuration Syntax](docs/reference/configuration.md). |
| **[Explanation](docs/explanation/)** | Understanding | Deep dives into [Storage Architecture](docs/explanation/storage-architecture.md), [Backup Principles](docs/explanation/backup-principles.md), and [Preflight Checks](docs/explanation/preflight-checks.md). |

---

## License

MIT License. See [LICENSE](LICENSE) for details.
