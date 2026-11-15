# Time Machine for Linux

Rsync-based tiered backups for Linux workstations. `/`, `/home`, and `/data` are mirrored to an encrypted BTRFS disk; each run creates a read-only snapshot. Cold data is copied to `@archive` without `--delete`.

## What gets backed up

| Source | Destination | Behavior |
|---|---|---|
| `/` | `/mnt/@system` | rsync mirror; removes destination files that no longer exist or are now excluded; excludes `/home`, `/data`, virtual filesystems, and rebuildable caches |
| `/home` | `/mnt/@home` | rsync mirror; preserves symlinks as links; large media directories are excluded by default |
| `/data` | `/mnt/@data` | rsync mirror; excludes `archive/`, `scratch/`, `media/`, `safehouse/`, `no-backup/`, and build artifacts |
| `/data/archive/`, `~/archive/` | `/mnt/@archive` | append-only; no `--delete`; optional checksum verification; read-only snapshot per batch |
| — | `/mnt/@snapshots` | stores `system-backup-*`, `home-backup-*`, `data-backup-*`, and `archive-batch-*` |

`@system` is a file-level mirror, not a bootable image. `@archive` is append-only at the rsync level, not WORM. Snapshots live on the same disk as the mirrors and do not protect against disk failure.

## Assumed directory layout

The scripts do not require a specific distribution. Tiered restore only works well when `/home` and `/data` are separate trees or mount points:

```text
/                       # system tier: OS, /etc, /usr, /var (caches, logs, containers, VMs excluded)
├── /home               # home tier: dotfiles and application configs (recommended separate mount)
└── /data               # data tier: active projects (recommended separate mount)
    ├── projects/       # backed up by @data
    ├── archive/        # cold staging; excluded from @data, copied to @archive
    ├── scratch/        # never backed up
    ├── media/          # never backed up
    ├── safehouse/      # never backed up
    └── no-backup/      # never backed up
```

If `/home` or `/data` is only a directory under `/`, backups still run, but they are not independent restore units; `@system` explicitly excludes both paths. Symlinks under `/home` are preserved as links and are not followed into `/data`.

The backup disk is mounted at `/mnt` by default (`-m` changes the base):

```text
/mnt/
├── @system/            # mirror of /
├── @home/              # mirror of /home
├── @data/              # mirror of /data
├── @archive/           # cold data; append-only
└── @snapshots/
    ├── system-backup-YYYYMMDDHHMMSS/
    ├── home-backup-YYYYMMDDHHMMSS/
    ├── data-backup-YYYYMMDDHHMMSS/
    └── archive-batch-YYYYMMDDHHMMSS/
```

`@media` is an optional sixth subvolume. `format-btrfs-luks.sh` does not create it; if you create it manually, `mountctl.sh` mounts it as well.

Restore operations write their `pre-restore-*` snapshots to the `--snapshots` path you pass, which is usually on the destination filesystem (for example `/home/.snapshots`), not necessarily to `/mnt/@snapshots`.

## Quickstart

Requirements: Linux, `rsync`, `btrfs-progs`, `cryptsetup`, and root privileges.

```bash
# 1. Format an external drive with LUKS2 + BTRFS (5 subvolumes)
sudo ./tools/format-btrfs-luks.sh -d /dev/sdX

# 2. Unlock and mount everything under /mnt
sudo ./tools/mountctl.sh mount -d /dev/sdX

# 3. Create ignore configs from the templates
cp config/system-backup-ignore.example config/system-backup-ignore
cp config/home-backup-ignore.example config/home-backup-ignore
cp config/data-backup-ignore.example config/data-backup-ignore

# 4. Full backup: System + Home + Data, one confirmation
sudo ./bin/backup-all.sh

# 5. Archive cold data (append-only), then unmount
sudo ./bin/archive-sync.sh --checksum --clean-source
sudo ./tools/mountctl.sh unmount
```

Single-tier backups:

```bash
sudo ./bin/system-backup.sh --dest /mnt/@system --snapshots /mnt/@snapshots
sudo ./bin/home-backup.sh   --dest /mnt/@home   --snapshots /mnt/@snapshots
sudo ./bin/data-backup.sh   --dest /mnt/@data   --snapshots /mnt/@snapshots
```

## Common commands

| Task | Command |
|---|---|
| Full backup (all tiers) | `sudo ./bin/backup-all.sh` |
| Single-tier backup | `sudo ./bin/<tier>-backup.sh --dest /mnt/@<tier> --snapshots /mnt/@snapshots` |
| Cold archive | `sudo ./bin/archive-sync.sh [--checksum] [--clean-source]` |
| Restore | `sudo ./bin/<tier>-restore.sh --source ... --dest ...` |
| Mount / unmount / status | `sudo ./tools/mountctl.sh mount -d <dev>` / `unmount` / `status` |
| List snapshots | `sudo ./tools/prune-snapshots.sh --list` |
| Prune snapshots | `sudo ./tools/prune-snapshots.sh [pattern] [-k N] [--apply]` |
| BTRFS balance | `sudo ./tools/balance-btrfs.sh [path] [--quick]` |
| Remove newly excluded files | `sudo ./tools/cleanup-excluded.sh [-t <tier>] [--execute]` |
| Format drive | `sudo ./tools/format-btrfs-luks.sh -d <dev>` |

## What is not backed up

- `@system`: `/home`, `/data`, `/proc`, `/sys`, `/dev`, `/run`, `/tmp`, `/mnt`, `/media`, EFI, package caches, logs, container and VM images, and database data directories.
- `@home`: large or re-downloadable directories such as `downloads/`, `music/`, `videos/`, `books/`, `games/`, `Android/`, `sdks/`, `applications/`, `vms/`, plus caches.
- `@data`: `archive/`, `scratch/`, `media/`, `safehouse/`, `no-backup/`, `node_modules/`, `target/`, `.venv/`, `dist/`, and similar build artifacts.

The complete lists are in `config/*-backup-ignore`.

## Limits

- `@system` is not a bootable image; bootloader and ESP are handled separately.
- `@archive` does not delete destination files, but a user with write access can still modify or remove them. It is not WORM.
- Snapshots and mirrors share one disk; keep a second off-site copy for disaster recovery.
- `--clean-source` deletes local files after archiving; it is off by default and asks for confirmation.

## Documentation

- [Getting Started](docs/tutorials/getting-started.md)
- [Routine Backup Workflow](docs/how-to/routine-backup-workflow.md)
- [System Backup & Recovery](docs/how-to/system-backup-and-restore.md)
- [Home Backup & Restore](docs/how-to/home-backup-and-restore.md)
- [Data Backup & Restore](docs/how-to/data-backup-and-restore.md)
- [Cold Archiving](docs/how-to/archive-cold-data.md)
- [Formatting an Encrypted Drive](docs/how-to/format-btrfs-drive.md)
- [Snapshot Pruning & BTRFS Balance](docs/how-to/maintain-btrfs-and-prune-snapshots.md)
- [CLI Reference](docs/reference/cli.md)
- [Configuration Reference](docs/reference/configuration.md)
- [Storage Architecture](docs/explanation/storage-architecture.md)
- [Architecture Decisions](docs/adr/index.md)

## License

MIT License. See [LICENSE](LICENSE) for details.
