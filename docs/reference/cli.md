# CLI Reference

Technical reference for command-line interfaces in `time-machine-for-linux`.

---

## Primary Interface: `bin/tm`

The authoritative single command-line interface for all Time Machine operations.

```bash
sudo tm <command> [OPTIONS]
# or: sudo ./bin/tm <command> [OPTIONS]
```

### Core Subcommands

| Command | Alias | Key Flags | Description |
|---|---|---|---|
| `backup` | `b` | `[--system] [--home] [--data] [-m <base>] [-y]` | **Default: runs all active tiers** (System + Home + Data) sequentially with 1 confirmation. Flags scope to specific tiers. |
| `archive` | `a` | `<source> [--checksum] [--clean-source]` | Append-only cold archiving to `@archive` with tamper-proof read-only BTRFS snapshots. |
| `restore` | `r` | `<system\|home\|data> --source <src> --dest <dst>` | Restore files from backup subvolume or historical snapshot. |
| `mount` | `m` | `<dev> [-m <base>] [--level <1-22>]` | Unlock LUKS container and mount all subvolumes (`@system`, `@home`, `@data`, `@archive`, `@snapshots`, `@media`). |
| `unmount` | `um` | `[-m <base>] [--no-close]` | Reverse-order clean unmount and automatic LUKS container locking. |
| `status` | `st` | `[-m <base>]` | Detailed view of LUKS state and per-subvolume storage consumption. |
| `prune` | `p` | `[-k <N>] [-t <tier>] [--apply]` | Inspect and prune expired snapshots (**default: safe dry-run preview**; requires `--apply`). |
| `cleanup` | `c` | `[-t <tier>] [--execute]` | Remove files matching newly added ignore rules from destination. |
| `format` | `f` | `-d <dev> [-l <label>]` | Safe LUKS2 + 5 BTRFS subvolumes drive initialization. |

---

## Low-Level Engine Modules (Underlying Scripts)

The following scripts function as underlying execution engines orchestrated by `bin/tm`:

### `bin/system-backup.sh`

Creates an incremental backup of the operating system root into a BTRFS subvolume.

```bash
sudo ./bin/system-backup.sh --dest <path> --snapshots <path> [OPTIONS]
```

| Parameter | Required | Default | Description |
|---|---|---|---|
| `--dest <path>` | Yes | — | Target backup directory (must be on BTRFS, e.g. `/mnt/@system`). |
| `--snapshots <path>` | Yes | — | Snapshot destination directory (must be on BTRFS, e.g. `/mnt/@snapshots`). |
| `--source <path>` | No | `/` | Source directory to backup. |
| `--help`, `-h` | No | — | Display usage information and exit. |

---

### `bin/home-backup.sh`

Creates an incremental backup of `/home` user configurations into a BTRFS subvolume.

```bash
sudo ./bin/home-backup.sh --dest <path> --snapshots <path> [OPTIONS]
```

| Parameter | Required | Default | Description |
|---|---|---|---|
| `--dest <path>` | Yes | — | Target backup directory (e.g. `/mnt/@home`). |
| `--snapshots <path>` | Yes | — | Snapshot directory (e.g. `/mnt/@snapshots`). |
| `--source <path>` | No | `/home` | Source home directory. |
| `--help`, `-h` | No | — | Display usage information and exit. |

---

### `bin/data-backup.sh`

Creates an incremental backup of the `/data` project drive into a BTRFS subvolume.

```bash
sudo ./bin/data-backup.sh --dest <path> --snapshots <path> [OPTIONS]
```

| Parameter | Required | Default | Description |
|---|---|---|---|
| `--dest <path>` | Yes | — | Target backup directory (e.g. `/mnt/@data`). |
| `--snapshots <path>` | Yes | — | Snapshot directory (e.g. `/mnt/@snapshots`). |
| `--source <path>` | No | `/data` | Source data mount point or directory. |
| `--help`, `-h` | No | — | Display usage information and exit. |

---

### `bin/archive-sync.sh`

Synchronizes cold data to long-term storage under an **Append-Only** policy (never deletes destination files).

```bash
sudo ./bin/archive-sync.sh --source <path> --dest <path> [OPTIONS]
```

| Parameter | Required | Default | Description |
|---|---|---|---|
| `--source <path>` | Yes | — | Local staging directory or completed project path. |
| `--dest <path>` | Yes | — | Cold storage subvolume (e.g. `/mnt/@archive`). |
| `--snapshots <path>` | No | — | If provided, creates an immutable read-only snapshot of `@archive`. |
| `--checksum`, `-c` | No | `false` | Verifies file contents by checksum instead of mod-time/size. |
| `--clean-source` | No | `false` | Interactively prompts to delete source files after verified transfer. |
| `--dry-run`, `-n` | No | `false` | Simulates file transfer without making any disk modifications. |
| `--no-snapshot` | No | `false` | Suppresses automatic BTRFS snapshot creation. |
| `--help`, `-h` | No | — | Display usage information and exit. |

---

## Restore Scripts

### `bin/system-restore.sh`, `bin/home-restore.sh`, `bin/data-restore.sh`

Restores files from backup subvolumes back to the target destination.

```bash
sudo ./bin/<script>.sh --source <path> --dest <path> [OPTIONS]
```

| Parameter | Required | Default | Description |
|---|---|---|---|
| `--source <path>` | Yes | — | Path to the backup or snapshot subvolume to restore from. |
| `--dest <path>` | Yes | — | Destination path on system to restore into. |
| `--snapshots <path>` | No | — | Path for creating an automatic pre-restore safety snapshot before write. |
| `--dry-run` | No | `false` | Preview files to be restored without writing changes to disk. |
| `--no-snapshot` | No | `false` | Bypasses safety snapshot creation. |
| `--help`, `-h` | No | — | Display usage information and exit. |

---

## Operational Tools (`tools/`)

### `tools/mountctl.sh`

Subvolume-aware lifecycle controller for unlocking, mounting, and locking Time Machine drives.

```bash
sudo ./tools/mountctl.sh <command> [OPTIONS]
```

| Command | Key Options | Description |
|---|---|---|
| `mount` | `-d <dev> [-m <base>] [--level <1-22>]` | Unlocks LUKS and mounts all 5 subvolumes (`@system`, `@home`, `@data`, `@archive`, `@snapshots`) under base. |
| `unmount` | `[-m <base>] [--no-close]` | Unmounts all subvolumes in reverse order and closes the LUKS container. |
| `status` | `[-m <base>]` | Displays LUKS device state and mount points with storage usage. |

---

### `tools/backup-all.sh`

Orchestrated pipeline executing System, Home, and Data backups sequentially with a single confirmation.

```bash
sudo ./tools/backup-all.sh [-m <base>] [OPTIONS]
```

| Parameter | Default | Description |
|---|---|---|
| `-m, --base <path>` | `/mnt` | Base directory where backup subvolumes are mounted. |
| `--snapshots <path>` | `<base>/@snapshots` | Directory for storing point-in-time snapshots. |
| `--skip-system` | `false` | Exclude system root backup from run. |
| `--skip-home` | `false` | Exclude user home backup from run. |
| `--skip-data` | `false` | Exclude active data workspace backup from run. |
| `-y, --yes` | `false` | Non-interactive execution mode. |

---

### `tools/prune-snapshots.sh`

Snapshot retention and pruning engine to prevent disk space exhaustion.

```bash
sudo ./tools/prune-snapshots.sh [-s <path>] [OPTIONS]
```

| Parameter | Default | Description |
|---|---|---|
| `-s, --snapshots <path>` | `/mnt/@snapshots` | Path to BTRFS snapshot repository. |
| `-k, --keep <N>` | `10` | Number of most recent snapshots to preserve per tier. |
| `-t, --tier <tier>` | `all` | Specific tier to prune (`system`, `home`, `data`, `archive`, or `all`). |
| `--apply` | `false` | Live execution flag. Without this flag, script runs in safe **DRY-RUN** preview. |
| `-y, --yes` | `false` | Skip confirmation prompt when `--apply` is enabled. |

---

### `tools/format-btrfs-luks.sh`

Production-grade external drive partitioner and subvolume provisioner.

```bash
sudo ./tools/format-btrfs-luks.sh -d <device> [-n <luks_name>] [-l <label>]
```

| Parameter | Default | Description |
|---|---|---|
| `-d, --device <dev>` | Required | Target block device to format. Refuses mounted or system-critical drives. |
| `-n, --name <name>` | `backup_crypt` | LUKS device mapper container name. |
| `-l, --label <label>` | `TimeMachine` | BTRFS filesystem volume label. |

---

### `tools/cleanup-excluded.sh`

Removes legacy files that were previously backed up but now match exclusion patterns.

```bash
sudo ./tools/cleanup-excluded.sh [OPTIONS]
```

| Parameter | Description |
|---|---|
| `-t, --tier <tier>` | Preset tier shortcut (`system`, `home`, `data`). Auto-deduces paths. |
| `-m, --base <path>` | Base mount path when using `--tier` (default: `/mnt`). |
| `--dest <path>` | Explicit destination directory to clean. |
| `--config <path>` | Explicit exclude rules configuration file. |
| `--execute` | Permanently deletes matching files (default: safe preview). |

---

## Exit Codes

All CLI scripts adhere to standard POSIX exit status conventions:

| Exit Code | Meaning |
|---|---|
| `0` | Success / Operation completed cleanly. |
| `1` | General error (missing parameters, missing tools, permission denied, user cancellation). |
