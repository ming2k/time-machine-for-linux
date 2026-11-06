# Subsystem Architecture & Topology Blueprint

- Status: Living Blueprint
- Last Updated: 2026-10-31
- Scope: workspace/topology, architecture/subsystems, storage/btrfs, cli/tm
- Maintainers: Time Machine Maintainers & Core Contributors

---

## 1. System Overview & Monorepo Topology

**Time Machine for Linux** provides Apple Time Machine-like tiered backup, instant Copy-on-Write snapshots, and immutable cold archiving for modern Linux workstations.

The repository is structured into clear functional boundaries:

```text
time-machine-for-linux/
├── bin/                       # Primary public CLI & Tiered execution engines
│   ├── tm                     # Single authoritative public CLI entrypoint [INV-CLI-01]
│   ├── system-backup.sh       # OS root backup engine
│   ├── system-restore.sh      # OS root restore engine
│   ├── home-backup.sh         # User home config backup engine
│   ├── home-restore.sh        # User home config restore engine
│   ├── data-backup.sh         # Active workspace backup engine
│   ├── data-restore.sh        # Active workspace restore engine
│   └── archive-sync.sh        # Append-only cold archiving engine [INV-BACKUP-03]
├── tools/                     # Drive lifecycle & maintenance tools
│   ├── mountctl.sh            # LUKS container unlock & multi-subvolume mounting
│   ├── format-btrfs-luks.sh   # LUKS2 formatting & 5 BTRFS subvolumes creation
│   ├── backup-all.sh          # Multi-tier pipeline orchestrator [INV-CLI-02, 03]
│   ├── prune-snapshots.sh     # Policy retention & dirty snapshot purging
│   ├── balance-btrfs.sh       # Safe filtered BTRFS chunk consolidation
│   └── cleanup-excluded.sh    # Prune paths matching updated ignore rules
├── lib/                       # Modular library substrates loaded via lib/loader.sh
│   ├── loader.sh              # Central discoverable module loader
│   ├── core/                  # Color definitions and logging facilities
│   ├── fs/                    # BTRFS operations, subvolume checks, path utilities
│   ├── config/                # Ignore list parser and permission validators
│   ├── backup/                # Backup executors, safety snapshotting, display formatting
│   ├── restore/               # Restore executors, pre-restore snapshots, display formatting
│   └── utils/                 # Preflight checks, confirmation prompts, rsync options
├── config/                    # Battle-tested ignore templates
│   ├── system-backup-ignore.example
│   ├── home-backup-ignore.example
│   └── data-backup-ignore.example
├── tests/                     # Automated test suites
│   ├── unit/                  # Fast deterministic module unit tests
│   ├── integration/           # Subsystem integration tests
│   ├── helpers/               # Test runners and fixture setup
│   └── run-tests.sh           # Test orchestrator
└── docs/                      # Diátaxis documentation & engineering standards
    ├── tutorials/             # Learning path for new operators
    ├── how-to/                # Task-oriented runbooks
    ├── reference/             # Precise technical parameter & config reference
    ├── explanation/           # Architectural and conceptual deep dives
    ├── adr/                   # Ratified Architectural Decision Records
    └── dev/                   # Internal blueprints and engineering standards
```

---

## 2. Storage Topology & Subvolume Stratification

Storage is divided into 4 independent operational tiers across hardware media:

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
  ├── @archive    <── bin/archive-sync.sh  (Append-only + bitstream checksums)
  └── @snapshots  <── Point-in-time immutable BTRFS rollback snapshots
```

### Subvolume Roles

| Subvolume | Mountpoint | Purpose | Synchronization Strategy | Pruning Policy |
| :--- | :--- | :--- | :--- | :--- |
| `@system` | `/mnt/@system` | OS Root (`/`) mirror | Rsync mirror (`--delete --delete-excluded --force`) | Overwritten to reflect live source state |
| `@home` | `/mnt/@home` | User home (`/home`) mirror | Rsync mirror (`--delete --delete-excluded --force`) | Overwritten to reflect live source state |
| `@data` | `/mnt/@data` | Workspaces (`/data`) mirror | Rsync mirror (`--delete --delete-excluded --force`) | Overwritten to reflect live source state |
| `@archive` | `/mnt/@archive` | Long-term cold data | Append-Only (NO `--delete`, NO `--force`) | **Never deleted**; permanent retention |
| `@snapshots` | `/mnt/@snapshots` | Rollback history | BTRFS Read-Only snapshots | Managed via retention policy (`tm prune`) |

---

## 3. Subsystem Boundaries & Interaction Flow

### 1. Front-Controller Layer (`bin/tm`)
- **Authority**: The sole public interface advertised in documentation ([INV-CLI-01]).
- **Behavior**: Parses subcommands (`backup`, `archive`, `restore`, `mount`, `unmount`, `status`, `snapshots`, `prune`, `balance`, `cleanup`, `format`), validates arguments, and dispatches to underlying engines.
- **Default Semantics**: Invoking `tm backup` with zero tier flags defaults to executing System + Home + Data sequentially with a single consolidated prompt ([INV-CLI-02], [INV-CLI-03]).

### 2. Execution Engine Layer (`bin/*`)
- **Isolation**: Each tier script is runnable standalone if needed, but adheres to standard parameters (`--source`, `--dest`, `--snapshots`).
- **Safety Snapshotting**: Before modifying the live destination subvolume, a pre-backup safety snapshot is created on `@snapshots`.
- **Exit Code Propagation**: Engines exit with code 0 on success, and non-zero on preflight failure or rsync errors.

### 3. Drive Lifecycle Layer (`tools/*`)
- **`mountctl.sh`**: Handles LUKS container unlocking (`cryptsetup open`) and reverse-order unmounting with LUKS container locking (`cryptsetup close`).
- **`format-btrfs-luks.sh`**: Creates partition, LUKS2 container, BTRFS filesystem, and establishes the 5 standard subvolumes.
- **`prune-snapshots.sh`**: Formats snapshot lists, implements policy retention (keep N newest per tier), and allows targeted pattern purging with safe dry-run default.
- **`balance-btrfs.sh`**: Executes filtered progressive chunk balancing (`-dusage=...`, `-musage=...`) to prevent false ENOSPC without unneeded disk wear.

### 4. Modular Library Layer (`lib/*`)
- **Loader Protocol**: Scripts import modules through `lib/loader.sh` via `load_backup_libs`, `load_restore_libs`, or `load_core_libs`.
- **Preflight Checks**: Verifies free disk space (>20% warn, >10% error), snapshot accumulation (>10 warn), and backup freshness before files are copied.
- **Confirm Execution**: Formats clean, non-intrusive preview tables before requesting user confirmation.

---

## 4. Ratified Architectural Invariants

| ID | Title | Summary & Enforcement | Ratifying ADR |
| :--- | :--- | :--- | :--- |
| `[INV-CLI-01]` | Single Public Interface | All documentation and workflows use `bin/tm`. Underlying scripts are engines. | [ADR-0001](../adr/0001-unified-cli-architecture.md) |
| `[INV-CLI-02]` | Backup-All Default | `tm backup` without tier flags executes System, Home, and Data sequentially. | [ADR-0001](../adr/0001-unified-cli-architecture.md) |
| `[INV-CLI-03]` | Single Confirmation | Consolidated multi-tier runs present one execution plan with exactly 1 confirmation. | [ADR-0001](../adr/0001-unified-cli-architecture.md) |
| `[INV-BACKUP-01]` | Mirror Fidelity | Active tiers use `--delete --delete-excluded --force` to prevent symlink and cache deadlocks. | [ADR-0002](../adr/0002-self-healing-mirror-reconciliation.md) |
| `[INV-BACKUP-02]` | Snapshot Shield | Destructive mirror synchronization is safe because immutable BTRFS snapshots protect history. | [ADR-0002](../adr/0002-self-healing-mirror-reconciliation.md) |
| `[INV-BACKUP-03]` | Cold Archive Prohibition | Destructive flags are strictly forbidden on `@archive`. Cold storage is Append-Only. | [ADR-0002](../adr/0002-self-healing-mirror-reconciliation.md) |
