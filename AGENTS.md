# AGENTS.md

Operational invariants and architecture guidelines for AI coding assistants working in `time-machine-for-linux`.

> **Isolation Invariant**: This file is maintained exclusively by human developers as a top-level prompt contract. AI assistants must **NEVER** edit, update, reformat, or expand this file during routine development, refactoring, or documentation tasks unless explicitly requested by the maintainer.

---

## 1. System Mission & Storage Topology

This repository implements Apple Time Machine-like tiered backup and cold archiving for Linux machines, tightly integrated with BTRFS snapshots and rsync.

### Physical & Logical Storage Hierarchy

```text
[Internal Physical Disks (Hot / Warm)]
  ├── NVMe 1 (Hot)  : / (System root) + /home (User dotfiles & desktop configuration)
  └── NVMe 2 (Warm) : /data (Active projects, repositories, workspaces)
                           │
                           │ (Periodic Sync or Manual Archive)
                           ▼
[External Storage Device (Nearline / Offline Cold Backup)]
  ├── @system     <── bin/system-backup.sh (Mirror sync + safety snapshots)
  ├── @home       <── bin/home-backup.sh   (Mirror sync + safety snapshots)
  ├── @data       <── bin/data-backup.sh   (Mirror sync + safety snapshots)
  ├── @archive    <── bin/archive-sync.sh  (Append-only + checksum + read-only snapshots)
  └── @snapshots  <── Automatic timestamped rollback snapshots
```

---

## 2. Architectural Invariants for AI Assistants

When modifying or generating code, strictly adhere to these non-negotiable boundaries:

### 2.1 Storage Tier Separation (`[INV-TIER-*]`)
- **`[INV-TIER-01] System Tier Isolation`**:
  `bin/system-backup.sh` must NEVER back up `/home/` or `/data/`. Both must be explicitly listed in `config/system-backup-ignore`.
- **`[INV-TIER-02] Home Tier Symlink Preservation`**:
  `bin/home-backup.sh` operates with `-a` (preserving symlinks as links). It must NOT dereference symlinks into external mount points (such as `/home/user/projects -> /data/projects`).
- **`[INV-TIER-03] Data Tier Pruning`**:
  `bin/data-backup.sh` must strictly exclude rebuildable build caches, lock-replaceable dependency trees (`node_modules/`, `target/`, `.venv/`, `dist/`), and volatile artifacts.
- **`[INV-TIER-04] Cold Archive Append-Only Invariant`**:
  `bin/archive-sync.sh` must **NEVER** execute with `--delete`. The destination is a permanent sediment reservoir. Data must never be purged from `@archive` during synchronization.
- **`[INV-TIER-05] Safehouse Scratch Zone Invariant`**:
  Paths designated as disposable safehouses or scratchpads (`scratch/`, `safehouse/`, `media/`, `no-backup/`) are permanently excluded by contract from all active backup tiers (`@system`, `@home`, `@data`). Never remove or bypass these exclusions.

### 2.2 Filesystem & Restore Safety Invariants (`[INV-SYS-*]` / `[INV-RESTORE-*]`)
- **`[INV-SYS-01] Metadata Preservation`**:
  All backup, restore, and archive operations must maintain full Linux filesystem metadata (`-aAXH --numeric-ids`). Operations modifying backup destinations require root privileges.
- **`[INV-SYS-02] BTRFS Destination Requirement`**:
  Backup targets and snapshot directories must reside on a BTRFS filesystem to support subvolume snapshots.
- **`[INV-RESTORE-01] Fail-Closed Snapshot Invariant`**:
  In non-dry-run mode, when pre-restore snapshot creation is enabled, any snapshot failure MUST immediately abort the restore pipeline with a non-zero exit code. Proceeding past snapshot failure is strictly prohibited unless explicitly bypassed via `--no-snapshot`.
- **`[INV-RESTORE-02] Explicit Affirmation Invariant`**:
  Destructive restore confirmation MUST require exact case-sensitive affirmation (`YES`), rejecting default presses, empty returns, or lowercase affirmative tokens (`y`, `yes`).
- **`[INV-RESTORE-03] Target Boundary Protection Invariant`**:
  Restore operations MUST reject source/destination identity (`source == dest`), prohibit destination paths targeting protected backup tiers (`@archive`, `@snapshots`), and automatically exclude kernel pseudo-filesystems and mountpoint roots (`/proc/*`, `/sys/*`, `/dev/*`, `/run/*`, `/tmp/*`, `/mnt/*`, `/media/*`, `/lost+found`) when restoring system files.

---

## 3. Key Script Roster

### Primary Unified Interface: `bin/tm`
- All user workflows must prioritize `bin/tm <subcommand>` (`backup`, `archive`, `restore`, `mount`, `unmount`, `status`, `prune`, `cleanup`, `format`).

### Underlying Modular Engines

| Script | Purpose | Tier | Delete Mode |
|---|---|---|---|
| `bin/tm` | Unified master CLI interface | All | Dispatches to engines |
| `bin/system-backup.sh` | OS and boot recovery | Hot (System) | `--delete` + snapshot |
| `bin/home-backup.sh` | User configs & dotfiles | Hot (Home) | `--delete` + snapshot |
| `bin/data-backup.sh` | Active project worktrees | Warm (Data) | `--delete` + snapshot |
| `bin/archive-sync.sh` | Completed/Cold data | Cold (Archive) | **Append-Only (No delete)** |
| `bin/system-restore.sh` | Restore OS root | Disaster Recovery | Interactive confirmation (`YES`) |
| `bin/home-restore.sh` | Restore home configs | User Recovery | Interactive confirmation (`YES`) |
| `bin/data-restore.sh` | Restore active data | Workspace Recovery | Interactive confirmation (`YES`) |
| `tools/mountctl.sh` | Subvolume mount controller | Hardware/Drive | Mounts & closes LUKS |
| `tools/backup-all.sh` | Pipeline orchestrator | Multi-tier | Sequential runner |
| `tools/prune-snapshots.sh` | Retention policy engine | Maintenance | Deletes expired snapshots |
| `tools/balance-btrfs.sh` | Chunk allocator reclaimer | Maintenance | Reclaims allocated chunks |

---

## 4. Verification

Before completing tasks, verify behavioral correctness by running:
```bash
./tests/run-tests.sh
```
