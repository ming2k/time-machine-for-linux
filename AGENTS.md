# AGENTS.md

Instructions and architectural invariants for AI coding assistants working in `time-machine-for-linux`.

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

When modifying or generating code, AI assistants must strictly respect these system invariants:

### 2.1 Storage Tier Separation (`[INV-TIER-*]`)
- **`[INV-TIER-01] System Tier Isolation`**:
  `bin/system-backup.sh` must NEVER backup `/home/` or `/data/`. Both must be explicitly listed in `config/system-backup-ignore`.
- **`[INV-TIER-02] Home Tier Symlink Preservation`**:
  `bin/home-backup.sh` operates with `-a` (preserving symlinks as links). It must NOT dereference symlinks into external mount points (such as `/home/user/projects -> /data/projects`).
- **`[INV-TIER-03] Data Tier Pruning`**:
  `bin/data-backup.sh` must strictly exclude rebuildable build caches, lock-replaceable dependency trees (`node_modules/`, `target/`, `.venv/`, `dist/`), and volatile artifacts.
- **`[INV-TIER-04] Cold Archive Append-Only Invariant`**:
  `bin/archive-sync.sh` must **NEVER** execute with `--delete`. The destination is a permanent sediment reservoir. Data must never be purged from `@archive` during synchronization.
- **`[INV-TIER-05] Safehouse Scratch Zone Invariant`**:
  Paths designated as disposable safehouses or scratchpads (`scratch/`, `safehouse/`, `media/`, `no-backup/`) are permanently excluded by contract from all active backup tiers (`@system`, `@home`, `@data`). AI assistants must never remove or bypass these exclusions.

### 2.2 Filesystem & Privilege Invariants (`[INV-SYS-*]`)
- **`[INV-SYS-01] Metadata Preservation`**:
  All backup, restore, and archive operations must maintain full Linux filesystem metadata (`-aAXH --numeric-ids`). Operations modifying backup destinations require root privileges.
- **`[INV-SYS-02] BTRFS Destination Requirement`**:
  Backup targets and snapshot directories must reside on a BTRFS filesystem to support subvolume snapshots.
- **`[INV-SYS-03] Rollback Protection`**:
  Restore scripts must provide a `--dry-run` inspection mode and attempt to take a pre-restore safety snapshot before destructive operations.

---

## 3. Documentation Governance (`[INV-DOCS-*]`)

This repository adopts Protocol v0.0.3 docs governance managed by the `docgov` toolchain.

- **`[INV-DOCS-01] Root Sanitization`**:
  Do not create arbitrary `.md` files at the repository root. Root markdown files must be approved in `.docgov.yml`.
- **`[INV-DOCS-02] Diátaxis Taxonomy Alignment`**:
  - `docs/how-to/`: Practical operational runbooks and disaster-recovery step-by-step guides.
  - `docs/reference/`: CLI arguments, configuration file syntax, and exit code specifications.
  - `docs/explanation/` or root `docs/backup-principles.md`: High-level principles, data rarity tiers, and design rationale.
- **`[INV-DOCS-03] Governance Verification`**:
  Before finishing documentation or CLI-level changes, run:
  ```bash
  docgov check
  ```

---

## 4. Key Script Roster

### Primary Unified Interface: `bin/tm` (or root symlink `./tm`)
- All user workflows must prioritize `bin/tm <subcommand>` (`backup`, `archive`, `restore`, `mount`, `unmount`, `status`, `prune`, `cleanup`, `format`).

### Underlying Modular Engines

| Script | Purpose | Tier | Delete Mode |
|---|---|---|---|
| `bin/tm` | Unified master CLI interface | All | Dispatches to engines |
| `bin/system-backup.sh` | OS and boot recovery | Hot (System) | `--delete` + snapshot |
| `bin/home-backup.sh` | User configs & dotfiles | Hot (Home) | `--delete` + snapshot |
| `bin/data-backup.sh` | Active project worktrees | Warm (Data) | `--delete` + snapshot |
| `bin/archive-sync.sh` | Completed/Cold data | Cold (Archive) | **Append-Only (No delete)** |
| `bin/system-restore.sh` | Restore OS root | Disaster Recovery | Interactive confirmation |
| `bin/home-restore.sh` | Restore home configs | User Recovery | Interactive confirmation |
| `bin/data-restore.sh` | Restore active data | Workspace Recovery | Interactive confirmation |
| `tools/mountctl.sh` | Subvolume mount controller | Hardware/Drive | Mounts & closes LUKS |
| `tools/backup-all.sh` | Pipeline orchestrator | Multi-tier | Sequential runner |
| `tools/prune-snapshots.sh` | Retention policy engine | Maintenance | Deletes expired snapshots |

<!-- BEGIN DOCGOV DIRECTIVES -->
## Documentation Governance Directives

You are bound by repository invariants. Violations will fail CI (`docgov check`).

### 1. Machine Invariants (Pre-Submit Checklist)
- `[INV-LINT-01] Location Sanitization`: Never create arbitrary Markdown files at the repository root.
- `[INV-LINT-02] Contributor Firewall`: Public docs (`docs/{tutorials,how-to,reference,explanation}/`) must NEVER link into internal docs (`docs/dev/`).
- `[INV-LINT-03] Frontmatter Schema`: ADRs must contain valid Frontmatter with standardized status enum.
- `[INV-LINT-04] Code-Doc Sync`: Modifying monitored paths in `src/` requires updating `docs/` in the same change.
- `[INV-LINT-05] Agent Directives Binding`: Ensure this docgov directives block is retained in agent configuration.

### 2. Cognitive & Architecture Protocols (Thinking Framework)
- `[INV-AGENT-01] Negative Knowledge`: Every new ADR MUST contain a 'Rejected Alternatives' section explaining why discarded options were not chosen.
- `[INV-AGENT-02] Context Routing & Chesterton's Fence`:
  - In feature generation: NEVER use docs marked `status: superseded` or `status: rejected` as active designs (prevents resurrecting dead patterns).
  - In refactoring/investigation: MUST retrieve `superseded` docs as negative constraints (learn from historical failure modes).
- `[INV-AGENT-03] Blameless Postmortem`: Postmortems MUST analyze system defense failures and detection gaps. Attribution of personal human blame is strictly prohibited.

### 3. Canonical Governance Knowledge & Context
Before drafting or restructuring documentation, inspect the local governance specifications:
- 4D Coordinate Tensor: `docs/governance/documentation/core/taxonomy.md`
- System Invariants Constitution: `docs/governance/documentation/core/invariants.md`
- Technical Voice & Link Contracts: `docs/governance/documentation/core/style.md`
- ADR & Architecture RFC Standard: `docs/governance/documentation/profiles/architecture/adr.md`
- Quality & Verification Guides: `docs/governance/documentation/profiles/validation/testing.md`

### 4. Fast Verification
Before completing any task, run:
```bash
docgov check
```
<!-- END DOCGOV DIRECTIVES -->
