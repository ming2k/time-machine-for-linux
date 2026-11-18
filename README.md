# Time Machine for Linux

Back up a Linux workstation's system, home directory, and data area to an encrypted external BTRFS drive. Every run creates a read-only snapshot, so you can go back to the state of any previous backup. Cold data you no longer use day to day can be archived separately and stays on the backup drive even after you delete it locally.

## Quickstart

### 1. Install dependencies

You need Linux, root privileges, and `git`, `rsync`, `btrfs-progs`, `cryptsetup`:

```bash
# Debian / Ubuntu
sudo apt install git rsync btrfs-progs cryptsetup
# Arch Linux
sudo pacman -S git rsync btrfs-progs cryptsetup
# Fedora
sudo dnf install git rsync btrfs-progs cryptsetup
```

### 2. Get the code

```bash
git clone https://github.com/ming2k/time-machine-for-linux.git
cd time-machine-for-linux
```

Nothing to build or install; run all following commands from this directory.

### 3. Format the backup drive (first time only)

> [!CAUTION]
> This **erases the entire drive**. Check the device name with `lsblk` first and make sure it is not your system disk.

```bash
lsblk                                            # find the external drive, e.g. /dev/sdb
sudo ./tools/format-btrfs-luks.sh -d /dev/sdX    # set an encryption passphrase and create the subvolumes
```

### 4. Create ignore rules (first time only)

```bash
cp config/system-backup-ignore.example config/system-backup-ignore
cp config/home-backup-ignore.example   config/home-backup-ignore
cp config/data-backup-ignore.example   config/data-backup-ignore
```

The templates ship with sensible defaults (caches, build artifacts, large media folders); edit them as needed.

### 5. Run a backup

Every backup is the same three steps: mount → back up → unmount.

```bash
# Unlock and mount the backup drive under /mnt
sudo ./tools/mountctl.sh mount -d /dev/sdX

# Back up each tier; every command asks for confirmation first
sudo ./bin/system-backup.sh --dest /mnt/@system --snapshots /mnt/@snapshots
sudo ./bin/home-backup.sh   --dest /mnt/@home   --snapshots /mnt/@snapshots
sudo ./bin/data-backup.sh   --dest /mnt/@data   --snapshots /mnt/@snapshots

# (Optional) archive cold data
sudo ./bin/archive-sync.sh --checksum

# Unmount; the drive can then be unplugged
sudo ./tools/mountctl.sh unmount
```

To back up a single tier, run only the matching command. For a longer step-by-step walkthrough, see [Getting Started](docs/tutorials/getting-started.md).

## What gets backed up

| Local path | Backed up to | Notes |
|---|---|---|
| `/` | `/mnt/@system` | OS and configuration (`/etc`, `/usr`, `/var`, …); excludes `/home`, `/data`, caches, and logs |
| `/home` | `/mnt/@home` | Dotfiles and app settings; skips downloads, music, videos, and other large folders by default |
| `/data` | `/mnt/@data` | Active projects; skips `archive/`, `scratch/`, and similar folders plus build artifacts |
| `/data/archive/`, `~/archive/` | `/mnt/@archive` | Cold-data archive: **add-only** — files you delete locally are kept on the backup drive |
| — | `/mnt/@snapshots` | Read-only snapshots created automatically by every backup and archive run |

The first three tiers are **mirrors**: the backup matches your machine, so a file deleted locally is also removed from the mirror on the next run — but it can still be recovered from earlier snapshots.

## Directory layout

The scripts work on any distribution. `/home` and `/data` should ideally be separate partitions or mount points so they can be restored independently:

```text
/                       # system tier
├── /home               # home tier (separate mount recommended)
└── /data               # data tier (separate mount recommended)
    ├── projects/       # backed up
    ├── archive/        # cold-data staging; written to @archive by the archive command
    ├── scratch/        # not backed up
    ├── media/          # not backed up
    ├── safehouse/      # not backed up
    └── no-backup/      # not backed up
```

If `/home` or `/data` is just a directory under `/`, backups still work, but they cannot be restored as independent units. Symlinks under `/home` are backed up as links and are not followed into `/data`.

The backup drive is mounted at `/mnt` by default (change with `-m`):

```text
/mnt/
├── @system/            # mirror of /
├── @home/              # mirror of /home
├── @data/              # mirror of /data
├── @archive/           # cold-data archive
└── @snapshots/
    ├── system-backup-YYYYMMDDHHMMSS/
    ├── home-backup-YYYYMMDDHHMMSS/
    ├── data-backup-YYYYMMDDHHMMSS/
    └── archive-batch-YYYYMMDDHHMMSS/
```

For media files you can manually create an optional `@media` subvolume; `mountctl.sh` mounts it as well.

## Common commands

| Task | Command |
|---|---|
| Mount / unmount / status | `sudo ./tools/mountctl.sh mount -d <dev>` / `unmount` / `status` |
| Single-tier backup | `sudo ./bin/<tier>-backup.sh --dest /mnt/@<tier> --snapshots /mnt/@snapshots` |
| Archive cold data | `sudo ./bin/archive-sync.sh [--checksum] [--clean-source]` |
| Restore | `sudo ./bin/<tier>-restore.sh --source ... --dest ...` |
| List snapshots | `sudo ./tools/prune-snapshots.sh --list` |
| Prune old snapshots | `sudo ./tools/prune-snapshots.sh [pattern] [-k N] [--apply]` |
| BTRFS balance | `sudo ./tools/balance-btrfs.sh [path] [--quick]` |
| Remove newly excluded files | `sudo ./tools/cleanup-excluded.sh [-t <tier>] [--execute]` |
| Format a backup drive | `sudo ./tools/format-btrfs-luks.sh -d <dev>` |

`<tier>` is `system`, `home`, or `data`. Before restoring, a `pre-restore-*` snapshot is created automatically at the `--snapshots` path; see the restore guides for details.

## What is not backed up

- `@system`: `/home`, `/data`, `/proc`, `/sys`, `/dev`, `/run`, `/tmp`, `/mnt`, `/media`, EFI, package caches, logs, container and VM images, and database data directories.
- `@home`: large or re-downloadable directories such as `downloads/`, `music/`, `videos/`, `books/`, `games/`, `Android/`, `sdks/`, `applications/`, `vms/`, plus caches.
- `@data`: `archive/`, `scratch/`, `media/`, `safehouse/`, `no-backup/`, `node_modules/`, `target/`, `.venv/`, `dist/`, and similar build artifacts.

The complete lists are in `config/*-backup-ignore`.

## Caveats

- `@system` is a file-level backup, not a bootable image; the bootloader and EFI partition must be handled separately.
- `@archive` is add-only but not tamper-proof: anyone with write access can still modify or delete its files.
- Snapshots and backups live on the same drive, so a drive failure loses both; keep a second off-site copy of important data.
- `archive-sync.sh --clean-source` deletes the local originals after a successful archive; it is off by default and asks for confirmation.

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
