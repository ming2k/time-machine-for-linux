# Configuration Reference

Technical reference for backup ignore configuration files in `config/`.

---

## Configuration Files

The project reads three tier-specific exclusion configuration files located in `config/`:

| File | Read By | Purpose |
|---|---|---|
| `config/system-backup-ignore` | `system-backup.sh` | OS root exclusions (caches, sockets, `/home`, `/data`). |
| `config/home-backup-ignore` | `home-backup.sh` | User home exclusions (volatile app caches, browser caches). |
| `config/data-backup-ignore` | `data-backup.sh` | Workspace exclusions (build artifacts, dependency trees). |

---

## Pattern Syntax & Semantics

Configurations use `rsync --exclude-from` rules with gitignore-like glob syntax:

### Basic Matching Rules
- **Comments**: Lines beginning with `#` are treated as comments.
- **Empty Lines**: Blank lines and lines consisting entirely of whitespace are ignored.
- **Directories**: Trailing slashes (e.g. `node_modules/`) match only directories.
- **Glob Wildcards**:
  - `*` matches any sequence of characters within a single directory component.
  - `**` matches across directory boundaries recursively.
  - `?` matches a single character.

### Crucial Difference from Gitignore (Negation Caveat)
In standard `git`, a negated rule (`!file`) can re-include a file inside an already-excluded parent directory.

**In rsync, this is NOT supported.** Once rsync matches a directory pattern to exclude (e.g. `downloads/`), it completely prunes the entire subtree. An exception like `!downloads/keep.txt` is never evaluated because the directory traversal stops at `downloads/`.

To selectively keep a child path, exclude sibling subdirectories instead of the top-level parent.

### Autonomous Pruning of Excluded Files (`--delete-excluded`)
Active mirror tiers (`tm backup`) automatically purge destination files matching current ignore patterns via `--delete-excluded --force`. This ensures that updating ignore rules immediately reclaims destination storage and prevents obsolete directories from deadlocking symlink updates. Prior versions remain accessible in `@snapshots`.

---

## Pre-Packaged Defaults

### System Backup (`system-backup-ignore`)
- **Mount points**: `/mnt/*`, `/media/*`, `/proc/*`, `/sys/*`, `/dev/*`, `/run/*`
- **Separate Tiers**: `/home/`, `/data/`
- **Temporary State**: `/tmp/*`, `/var/tmp/*`, `*.tmp`

### Home Backup (`home-backup-ignore`)
- **Tier 5 Caches**: `.cache/`, `.thumbnails/`, `.local/share/Trash/`, `.var/app/*/cache/`
- **Package Stores**: `.cargo/registry/`, `.npm/_cacache/`, `.local/share/pnpm/store/`
- **Runtime Toolchains**: `.rustup/`, `.local/share/uv/`, `.local/share/mise/installs/`

### Data Backup (`data-backup-ignore`)
- **Build Artifacts**: `**/node_modules/`, `**/target/`, `**/build/`, `**/dist/`
- **Compiler / Linter Caches**: `**/__pycache__/`, `**/.pytest_cache/`, `**/.mypy_cache/`
- **Disposable Environments**: `**/.venv/`, `**/venv/`
- **Heavy Bulk / Temporary**: `*.iso`, `vms/instances/`, `models/cache/`
