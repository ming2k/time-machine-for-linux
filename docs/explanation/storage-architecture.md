# Storage Architecture & Tiering Rationale

This document explains the technical architecture, physical storage topology, and design decisions behind `time-machine-for-linux`.

---

## 1. Physical Storage Topology

Modern Linux workstations often segregate high-speed I/O workloads across multiple physical NVMe drives, with nearline or offline drives handling backup and archive tiers:

```text
[Internal Workstation Hardware]
 ├── NVMe 1 (High Performance, Hot)
 │    ├── /      (Root OS, system packages, services)
 │    └── /home  (Personal configurations, desktop state, dotfiles)
 │
 └── NVMe 2 (High Capacity, Warm)
      ├── /data/projects (Active Git repositories, local workspaces)
      ├── /data/archive  (Local staging area for cold export)
      └── /data/scratch  (Unbacked safehouse: disposable media & temp testbeds)
           │
           │ (Periodic Synchronization or Low-Frequency Archival)
           ▼
[External Storage Device (BTRFS Backup & Cold Storage)]
 ├── @system     (OS mirror)
 ├── @home       (User home mirror)
 ├── @data       (Workspace mirror)
 ├── @archive    (Append-Only cold sediment)
 ├── @media      (Optional independent media library)
 └── @snapshots  (Read-only point-in-time BTRFS snapshots)
```

---

## 2. Why Segregate into Independent Backup Tiers?

Traditional backup solutions often dump `/` as a monolithic blob. This creates operational problems:

1. **Distro Upgrades & Switches**: When switching Linux distributions (e.g. from Ubuntu to Arch), you want to restore only `/home` (dotfiles, browser profiles, keys) without restoring outdated distro binaries from `/`.
2. **Disaster Recovery**: If an OS update breaks bootloader or libc, you want to restore `@system` cleanly without overwriting active ongoing work on `/data`.
3. **Data Growth & Explosion**: Development projects generate massive build artifacts (`node_modules/`, `target/`). Isolating `/data` ensures project backup rules do not contaminate system-level rules.

---

## 3. The Synergy of Rsync and BTRFS Copy-on-Write

`time-machine-for-linux` deliberately combines `rsync` with BTRFS snapshots:

### The Problem with Pure Rsync Hard-Links
Tools like `rsnapshot` emulate snapshots using POSIX hard-links (`rsync --link-dest`). While clever, hard-links:
- Cannot hard-link directories (only regular files).
- Break across filesystem boundaries.
- Cause metadata bloat on traditional filesystems (ext4) as directory inodes duplicate.

### The Problem with Pure BTRFS `send/receive`
Pure `btrfs send | btrfs receive` requires identical filesystem roots and cannot easily filter disposable directories (`node_modules/`, caches) at transfer time.

### The Hybrid Solution
1. **Rsync as the Intelligent Filter**:
   Rsync reads fine-grained ignore rules (`--exclude-from`), evaluates file modifications, and synchronizes only genuine state changes to a live subvolume (`@system`, `@home`, `@data`).
2. **BTRFS as the Snapshot Layer**:
   Once rsync finishes, BTRFS creates a subvolume snapshot (`btrfs subvolume snapshot`). The snapshot is a metadata operation: it initially shares data blocks with the source, and later writes to either subvolume consume additional space.

---

## 4. Mirroring vs. Cold Archiving (Append-Only)

A distinction exists between **Mirror Syncing** and **Archiving**:

| Characteristic | Mirror Tiers (`@system`, `@home`, `@data`) | Cold Archive Tier (`@archive`) |
|---|---|---|
| **Synchronization** | Mirror mode (`--delete` enabled). | **Append-Only** (no `--delete`; destination files may still be modified manually). |
| **Source Lifecycle** | Source remains active on the machine. | Source is often deleted locally after verified archive. |
| **History Mechanism** | History preserved via `@snapshots` tree. | History preserved directly in `@archive` + read-only snapshots. |
| **Verification** | Fast mtime & size comparisons. | Optional cryptographic `--checksum` content checks. |

Because archive synchronization never passes `--delete`, deleting an old finished project from `/data` does not remove its copy from `@archive`. This is a synchronization policy, not an immutable-storage guarantee: a user with write access can still modify the archive.

---

## 5. The Unbacked Safehouse (`/data/scratch`)

Users frequently handle temporary large media (e.g. 50GB 4K videos borrowed from `@media`), unpack large temporary datasets, or run disposable VM experiments.

If placed in normal directories, these gigabyte-heavy files would unintentionally trigger massive backup syncs, quickly exhausting external backup storage.

To solve this, the architecture establishes a dedicated **Safehouse Zone** (`/data/scratch` or `/data/media`):
- **Ignored by Contract**: Strictly excluded in `config/data-backup-ignore` and `config/home-backup-ignore`.
- **Zero Backup Footprint**: `bin/backup-all.sh` and the data backup engine skip it by configuration.
- **Fast Cleanup**: If it is a dedicated BTRFS subvolume on `/data`, it can be deleted and recreated without a recursive `rm -rf` traversal.
