# CLI Reference

Technical reference for the command-line scripts in `time-machine-for-linux`.

All commands are run from the repository root and require root privileges unless noted otherwise.

---

## Command Surface

| Task | Script | Key Options |
|---|---|---|
| Full backup (System + Home + Data) | `bin/backup-all.sh` | `[-m <base>] [--snapshots <path>] [--skip-system] [--skip-home] [--skip-data] [-y]` |
| System backup | `bin/system-backup.sh` | `--dest <path> --snapshots <path> [--source <path>]` |
| Home backup | `bin/home-backup.sh` | `--dest <path> --snapshots <path> [--source <path>]` |
| Data backup | `bin/data-backup.sh` | `--dest <path> --snapshots <path> [--source <path>]` |
| Cold archive | `bin/archive-sync.sh` | `[source] [--dest <path>] [--checksum] [--clean-source] [--dry-run] [--no-snapshot]` |
| System restore | `bin/system-restore.sh` | `--source <path> --dest <path> [--snapshots <path> \| --no-snapshot] [--dry-run]` |
| Home restore | `bin/home-restore.sh` | `--source <path> --dest <path> [--snapshots <path> \| --no-snapshot] [--dry-run]` |
| Data restore | `bin/data-restore.sh` | `--source <path> --dest <path> [--snapshots <path> \| --no-snapshot] [--dry-run]` |
| Mount / unmount / status | `tools/mountctl.sh` | `mount -d <dev> [-m <base>] [--level <1-22>]`, `unmount`, `status` |
| List snapshots | `tools/prune-snapshots.sh --list` | `[-s <path>]` |
| Prune snapshots | `tools/prune-snapshots.sh` | `[pattern...] [-k <N>] [-t <tier>] [--apply] [-y]` |
| BTRFS balance | `tools/balance-btrfs.sh` | `[mount_path] [--quick\|--normal\|--deep]` |
| Remove newly excluded files | `tools/cleanup-excluded.sh` | `[-t <tier>] [-m <base>] [--dest <path>] [--config <path>] [--execute]` |
| Format drive | `tools/format-btrfs-luks.sh` | `-d <dev> [-n <luks_name>] [-l <label>]` |

---

## Backup Engines

### `bin/backup-all.sh`

Runs System, Home, and Data backups sequentially with one execution plan and one confirmation.

```bash
sudo ./bin/backup-all.sh [-m <base>] [OPTIONS]
```

| Parameter | Default | Description |
|---|---|---|
| `-m, --base <path>` | `/mnt` | Base directory containing `@system`, `@home`, `@data`, and `@snapshots`. |
| `--snapshots <path>` | `<base>/@snapshots` | Snapshot directory. |
| `--source-system <path>` | `/` | System source. |
| `--source-home <path>` | `/home` | Home source. |
| `--source-data <path>` | `/data` | Data source. |
| `--skip-system` | `false` | Skip the system tier. |
| `--skip-home` | `false` | Skip the home tier. |
| `--skip-data` | `false` | Skip the data tier. |
| `-y, --yes` | `false` | Skip the confirmation prompt. |

Before running, it verifies that the required destination subvolumes and the snapshot subvolume are mounted.

### `bin/system-backup.sh`

Mirrors the OS root into `@system` and creates a `system-backup-YYYYMMDDHHMMSS` snapshot.

```bash
sudo ./bin/system-backup.sh --dest <path> --snapshots <path> [OPTIONS]
```

| Parameter | Required | Default | Description |
|---|---|---|---|
| `--dest <path>` | Yes | — | Target backup directory (must be on BTRFS, e.g. `/mnt/@system`). |
| `--snapshots <path>` | Yes | — | Snapshot destination directory (must be on BTRFS, e.g. `/mnt/@snapshots`). |
| `--source <path>` | No | `/` | Source directory. |
| `--help`, `-h` | No | — | Show usage. |

### `bin/home-backup.sh`

Mirrors `/home` into `@home` and creates a `home-backup-YYYYMMDDHHMMSS` snapshot.

```bash
sudo ./bin/home-backup.sh --dest <path> --snapshots <path> [OPTIONS]
```

| Parameter | Required | Default | Description |
|---|---|---|---|
| `--dest <path>` | Yes | — | Target backup directory (e.g. `/mnt/@home`). |
| `--snapshots <path>` | Yes | — | Snapshot directory (e.g. `/mnt/@snapshots`). |
| `--source <path>` | No | `/home` | Source directory. |
| `--help`, `-h` | No | — | Show usage. |

### `bin/data-backup.sh`

Mirrors `/data` into `@data` and creates a `data-backup-YYYYMMDDHHMMSS` snapshot.

```bash
sudo ./bin/data-backup.sh --dest <path> --snapshots <path> [OPTIONS]
```

| Parameter | Required | Default | Description |
|---|---|---|---|
| `--dest <path>` | Yes | — | Target backup directory (e.g. `/mnt/@data`). |
| `--snapshots <path>` | Yes | — | Snapshot directory (e.g. `/mnt/@snapshots`). |
| `--source <path>` | No | `/data` | Source directory. |
| `--help`, `-h` | No | — | Show usage. |

---

## Cold Archive

### `bin/archive-sync.sh`

Copies cold data into `@archive` without passing `--delete`. Sources can be given explicitly or discovered automatically.

```bash
sudo ./bin/archive-sync.sh [SOURCE] [OPTIONS]
```

| Parameter | Required | Default | Description |
|---|---|---|---|
| `[SOURCE]` or `--source <path>` | No | Autodiscovery | Local staging directory or completed project path. Without it, the script scans `/data/archive/` and `/home/*/archive/` for non-empty directories. |
| `--dest <path>` | No | `/mnt/@archive` | Cold storage subvolume. |
| `--snapshots <path>` | No | `/mnt/@snapshots` | Snapshot repository for `archive-batch-*` snapshots. |
| `--checksum`, `-c` | No | `false` | Compare file contents by checksum. |
| `--clean-source` | No | `false` | After transfer, prompt to delete the source directory contents. |
| `--dry-run`, `-n` | No | `false` | Preview files without modifying the destination. |
| `--no-snapshot` | No | `false` | Do not create a read-only archive snapshot. |
| `--help`, `-h` | No | — | Show usage. |

---

## Restore Engines

### `bin/system-restore.sh`, `bin/home-restore.sh`, `bin/data-restore.sh`

Restore files from a backup subvolume or snapshot back to a destination.

```bash
sudo ./bin/<tier>-restore.sh --source <path> --dest <path> [OPTIONS]
```

| Parameter | Required | Default | Description |
|---|---|---|---|
| `--source <path>` | Yes | — | Backup subvolume or snapshot to restore from. Must not equal the destination ([INV-RESTORE-03]). |
| `--dest <path>` | Yes | — | Destination path. Cannot target `@archive` or `@snapshots`. |
| `--snapshots <path>` | Conditional | — | Path for a pre-restore safety snapshot on the destination filesystem ([INV-RESTORE-01]). Required unless `--no-snapshot` is passed. |
| `--no-snapshot` | Conditional | `false` | Explicitly bypass pre-restore snapshot creation ([INV-RESTORE-01]). |
| `--dry-run` | No | `false` | Preview files without writing changes. |
| `--help`, `-h` | No | — | Show usage. |

> **Safety**: Non-dry-run restore requires typing uppercase `YES` to confirm. If `--snapshots` is provided and snapshot creation fails, the restore aborts. Virtual filesystems and mountpoints (`/proc/*`, `/sys/*`, `/dev/*`, `/run/*`, `/tmp/*`, `/mnt/*`, `/media/*`) are excluded during system restore ([INV-RESTORE-03]).

---

## Drive Lifecycle

### `tools/mountctl.sh`

Unlocks LUKS, mounts the five standard subvolumes, and can unmount and close the container.

```bash
sudo ./tools/mountctl.sh <command> [OPTIONS]
```

| Command | Key Options | Description |
|---|---|---|
| `mount` | `-d <dev> [-m <base>] [-n <name>] [--level <1-22>]` | Unlocks LUKS and mounts `@system`, `@home`, `@data`, `@archive`, and `@snapshots` under the base. If an optional `@media` subvolume exists, it is mounted too. |
| `unmount` | `[-m <base>] [-n <name>] [--no-close]` | Unmounts managed subvolumes in reverse order and closes the LUKS container. |
| `status` | `[-m <base>] [-n <name>]` | Displays LUKS state, mount points, and per-subvolume usage. |

### `tools/format-btrfs-luks.sh`

Creates a LUKS2 container, a BTRFS filesystem, and the five standard subvolumes.

```bash
sudo ./tools/format-btrfs-luks.sh -d <device> [-n <luks_name>] [-l <label>]
```

| Parameter | Default | Description |
|---|---|---|
| `-d, --device <dev>` | Required | Target block device. Refuses mounted or system-critical drives. |
| `-n, --name <name>` | `backup_crypt` | LUKS mapper name. |
| `-l, --label <label>` | `TimeMachine` | BTRFS filesystem label. |

---

## Maintenance

### `tools/prune-snapshots.sh`

Lists, retains, or deletes snapshots. Without `--apply`, it only previews changes.

```bash
sudo ./tools/prune-snapshots.sh [OPTIONS] [SNAPSHOT_OR_PATTERN...]
```

| Parameter | Default | Description |
|---|---|---|
| `-l, --list` | — | List snapshots and exit. |
| `[pattern...]` | — | Snapshot names or glob patterns to delete (e.g. `*1301*`). |
| `-s, --snapshots <path>` | `/mnt/@snapshots` | Snapshot repository. |
| `-k, --keep <N>` | `10` | Number of newest snapshots to keep per tier. |
| `-t, --tier <tier>` | `all` | Tier to prune: `system`, `home`, `data`, `archive`, or `all`. |
| `--apply` | `false` | Actually delete matching snapshots. |
| `-y, --yes` | `false` | Skip confirmation when `--apply` is used. |

### `tools/balance-btrfs.sh`

Consolidates under-utilized BTRFS block groups with filtered balance operations.

```bash
sudo ./tools/balance-btrfs.sh [OPTIONS] [MOUNT_PATH]
```

| Parameter | Default | Description |
|---|---|---|
| `MOUNT_PATH` | `/mnt` | BTRFS mountpoint to balance. |
| `--quick` | — | Reclaim chunks with <10% utilization. |
| `--normal` | Selected | Consolidate chunks with <50% utilization. |
| `--deep` | — | Consolidate chunks with <75% utilization. |

### `tools/cleanup-excluded.sh`

Removes files that were backed up before an ignore rule was added. Without `--execute`, it only previews matches.

```bash
sudo ./tools/cleanup-excluded.sh [OPTIONS]
```

| Parameter | Description |
|---|---|
| `-t, --tier <tier>` | Preset tier (`system`, `home`, `data`) for destination and config paths. |
| `-m, --base <path>` | Base mount path when using `--tier` (default: `/mnt`). |
| `--dest <path>` | Explicit destination directory. |
| `--config <path>` | Explicit ignore configuration file. |
| `--execute` | Delete matching files. |

---

## Exit Codes

All scripts use standard POSIX exit statuses:

| Exit Code | Meaning |
|---|---|
| `0` | Success, or a dry-run/list operation completed. |
| `1` | General error: missing parameters, missing tools, permission denied, failed operation, or user cancellation. |
