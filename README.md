# Time Machine for Linux

[English](README.md) | [简体中文](README-zh.md)

> Apple Time Machine-like tiered backup, instant Copy-on-Write snapshots, and immutable cold archiving for Linux, powered by BTRFS and rsync.

Time Machine for Linux organizes workstation storage into clean, independent tiers: protecting operating system state, user desktop configurations, and active project workspaces with sub-second BTRFS snapshots while guaranteeing never-delete append-only semantics for cold archives.

---

## Features

- **Independent Multi-Tier Storage**: Splits storage into isolated tiers (`@system`, `@home`, `@data`, `@archive`, `@snapshots`). Restore user configurations onto a fresh distribution without restoring outdated OS binaries from `/`.
- **Zero Cache Hoarding**: Pre-audited ignore rules strip out multi-gigabyte build artifacts (`node_modules`, `target`, `.venv`, `.pytest_cache`) and disposable package caches before files touch the backup disk.
- **Instant BTRFS Snapshots**: Rsync synchronizes live mirror subvolumes, then BTRFS locks the exact state in milliseconds using Copy-on-Write snapshots.
- **Append-Only Cold Archiving**: Safely retire completed projects and dormant datasets from internal NVMe drives to external cold storage with guaranteed **never-delete** semantics and bitstream verification.
- **Unified CLI Controller (`tm`)**: A single authoritative command-line interface orchestrating the entire lifecycle: LUKS encryption, mounting, multi-tier backup pipelines, snapshot pruning, and filtered BTRFS balancing.

---

## Storage Topology

```text
[Internal Disks (Hot / Warm)]
  ├── NVMe 1 (Hot)  : / (OS root) + /home (Configs & dotfiles)
  └── NVMe 2 (Warm) : /data (Active projects & workspaces)
                           │
                           │ Periodic Sync or Manual Archival
                           ▼
[External Drive (Encrypted BTRFS Storage)]
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

## CLI Cheatsheet

| Command | Alias | Key Flags | Description |
| :--- | :--- | :--- | :--- |
| `tm backup` | `b` | `[--system] [--home] [--data] [-m <base>] [-y]` | **Default: runs all active tiers** (System + Home + Data) sequentially with 1 prompt. Flags scope to specific tiers. |
| `tm archive` | `a` | `[source] [--checksum] [--clean-source]` | Append-only cold archiving to `@archive` with tamper-proof read-only BTRFS snapshots. |
| `tm restore` | `r` | `<system\|home\|data> --source <src> --dest <dst>` | Restore files from backup subvolume or historical snapshot. |
| `tm mount` | `m` | `<dev> [-m <base>]` | Unlock LUKS container and mount all subvolumes with zstd compression. |
| `tm unmount` | `um` | `[-m <base>]` | Clean reverse-order unmount and automatic LUKS container locking. |
| `tm status` | `st` | `[-m <base>]` | Inspect LUKS container state and per-subvolume storage utilization. |
| `tm snapshots` | `snaps`| `[-s <path>]` | List formatted table of all snapshots, tiers, and creation timestamps. |
| `tm prune` | `p` | `[pattern] [-k <N>] [--apply]` | Prune expired or targeted dirty snapshots (**default: safe dry-run**; requires `--apply`). |
| `tm balance` | `bal` | `[path] [--quick]` | Safe filtered BTRFS balance to reclaim sparse chunks and unallocated space. |
| `tm cleanup` | `c` | `[-t <tier>] [--execute]` | Remove files matching newly added ignore rules from destination. |
| `tm format` | `f` | `-d <dev>` | Initialize drive with LUKS2 encryption and 5 standard BTRFS subvolumes. |

---

## Documentation

Detailed documentation is organized using the [Diátaxis](https://diataxis.fr/) framework:

- **[Tutorials](docs/tutorials/index.md)**: Guided lessons starting from a fresh checkout:
  - [Getting Started from Scratch](docs/tutorials/getting-started.md) — 15-minute complete walkthrough.
- **[How-To Guides](docs/how-to/index.md)**: Task-oriented runbooks for practical workflows:
  - [Routine End-to-End Backup Workflow](docs/how-to/routine-backup-workflow.md) — Standard daily operational lifecycle.
  - [System Backup & Disaster Recovery](docs/how-to/system-backup-and-restore.md) — OS protection & Live USB recovery.
  - [User Home Migration](docs/how-to/home-backup-and-restore.md) — Dotfiles backup & clean distro switching.
  - [Workspace Data Recovery](docs/how-to/data-backup-and-restore.md) — Project trees protection & instant snapshot rollback.
  - [Cold Archiving](docs/how-to/archive-cold-data.md) — Dual-staging append-only cold sediment storage.
  - [Encrypted Drive Formatting](docs/how-to/format-btrfs-drive.md) — LUKS2 & subvolume partitioning.
  - [Snapshot Pruning & BTRFS Balance](docs/how-to/maintain-btrfs-and-prune-snapshots.md) — Chunk consolidation & retention policies.
- **[Reference](docs/reference/index.md)**: Technical specifications and syntax catalogs:
  - [CLI Reference](docs/reference/cli.md) — Parameter specifications, exit codes, and low-level script interfaces.
  - [Configuration Syntax](docs/reference/configuration.md) — Pattern matching rules and default exclusion templates.
- **[Explanation](docs/explanation/index.md)**: Conceptual deep dives and architectural rationale:
  - [Storage Architecture](docs/explanation/storage-architecture.md) — Subvolume stratification and rsync + CoW synergy.
  - [Backup Principles](docs/explanation/backup-principles.md) — Recoverability vs rarity and anti-hoarding policies.
  - [Preflight Checks](docs/explanation/preflight-checks.md) — Automated capacity, health, and freshness verification.
- **[Subsystem Architecture Blueprint](docs/dev/subsystems.md)**: Workspace topology, module boundaries, and system invariants.
- **[Architectural Decision Records (ADR)](docs/adr/index.md)**: Ratified decisions, design trade-offs, and negative knowledge.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
