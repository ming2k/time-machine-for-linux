# Time Machine for Linux

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![BTRFS](https://img.shields.io/badge/Filesystem-BTRFS-blue.svg)](https://btrfs.wiki.kernel.org/)

A safe, simple, less dependency and opinionated backup solution for Linux systems inspired by Apple Time Machine.

> [!IMPORTANT]
> There are !!!RISKS!!! in manipulating data. Please pay attention to data security before ensuring that the solution can work properly.

## Prerequisites
- A storage medium with a storage capacity larger than the data to be backed up
- Root privileges for system operations
- Required packages:
  - `rsync` - file synchronization
  - `btrfs-progs` - BTRFS filesystem tools (provides `btrfs` and `mkfs.btrfs`)
  - `jq` - JSON processor (for data backup state tracking)
  - `cryptsetup` - LUKS encryption (optional, for encrypted backup storage)

```bash
# Debian/Ubuntu
sudo apt install rsync btrfs-progs jq cryptsetup

# Fedora
sudo dnf install rsync btrfs-progs jq cryptsetup

# Arch Linux
sudo pacman -S rsync btrfs-progs jq cryptsetup

# Void Linux
sudo xbps-install -S rsync btrfs-progs jq cryptsetup
```

## Backup Storage Medium Setup
> [!IMPORTANT]
> Please set up the partition scheme in advance and reserve one partition as a backup partition.

### TL;DR

```sh
# Format device with LUKS encryption + BTRFS with subvolumes
sudo ./tools/format-btrfs-luks.sh -d /dev/sdX
```

**⚠️ Warning**: The format tool will **DESTROY ALL DATA** on the specified device!

### More About Backup Storage Medium Setup

This project opinionatedly uses btrfs as the filesystem and creates expected subvolumes, while also opinionatedly using LUKS encryption.
The project will assume that you agree with and may have already adopted this behavior to perform a series of the project operations.
We do not recommend using configurations outside of this convention - they might work, but could pose potential risks.

#### BTRFS Subvolumes
```bash
# Create subvolumes
sudo btrfs subvolume create /mnt/@system    # OS backup
sudo btrfs subvolume create /mnt/@home      # Home backup
sudo btrfs subvolume create /mnt/@data      # Live data extension (mounted directly)
sudo btrfs subvolume create /mnt/@archive   # Cold archive backup
sudo btrfs subvolume create /mnt/@snapshots # Safety snapshots
```

#### LUKS Setup
```bash
sudo cryptsetup open /dev/sdX encrypted_root
sudo mount /dev/mapper/encrypted_root /mnt
```

## How to Use Regularly

The above backup storage media settings will only be used once to initialize the media. This section is a common reference for future backups.

*To prevent the temperature from being too high, the copy rate is limited. Please modify the agument of `--bwlimit` if necessary.*

### Mount
Mounting with zstd reduces read and write traffic to extend storage medium life.

```sh
# Mount LUKS device with BTRFS+zstd compression
sudo ./tools/mountctl.sh -b /dev/sdX -p /mnt/point
# Mount with custom compression level and LUKS name
sudo ./tools/mountctl.sh -b /dev/sdX -p /mnt/point --level 5
 --luks-name my-backup
# Unmount and close LUKS
sudo ./tools/mountctl.sh -u /mnt/point
```

### System Backup

#### TL;DR
```bash
# Back up / (excluding /home, which is backed up separately)
sudo ./bin/system-backup.sh --source / --dest /mnt/point/@system --snapshots /mnt/point/@snapshots
```
#### System Backup Config

`config/system-backup-ignore`

```bash
# Home directory (backed up separately by home-backup.sh)
/home/

# Exclude virtual filesystems
/proc/*
/sys/*
/dev/*

# Exclude temporary files
*.tmp
*.cache
```

**System Backup Features:**
- **Blacklist approach**: Backs up everything except excluded patterns
- **Excludes /home entirely**: Home is a dedicated tier backed up by `home-backup.sh`
- **BTRFS snapshots**: Creates pre-backup snapshots for safety
- **Efficient transfers**: Uses rsync with progress reporting
- **User confirmation**: Shows preview before execution

### Home Backup

#### TL;DR
```bash
# Back up /home (dotfiles, config, app state — excluding large data dirs)
sudo ./bin/home-backup.sh --dest /mnt/point/@home --snapshots /mnt/point/@snapshots
```

#### Home Backup Config

`config/home-backup-ignore`

```bash
# Caches and volatile data
.cache/
.thumbnails/

# Large data directories (manage separately with rsync or a dedicated tool)
downloads/
documents/
pictures/
music/
videos/
projects/
```

**Home Backup Features:**
- **Dotfiles and config**: Captures shell configs, app settings, and user state
- **Excludes large data**: Directories like `~/projects`, `~/downloads` go into archive backup
- **Independent restore**: Restore just `/home` without touching the system — clean for distro switches
- **BTRFS snapshots**: Pre-backup snapshots for safety
- **User confirmation**: Shows preview before execution

## How to Restore

> [!IMPORTANT]
> Restoring overwrites existing files at the destination. Always use `--dry-run` first to preview changes.

### System Restore

#### TL;DR
```bash
# Preview what would be restored (safe, no changes made)
sudo ./bin/system-restore.sh --source /mnt/point/@system --dest / --dry-run

# Restore system with a pre-restore safety snapshot
sudo ./bin/system-restore.sh --source /mnt/point/@system --dest / --snapshots /mnt/point/@snapshots

# Restore without creating a snapshot
sudo ./bin/system-restore.sh --source /mnt/point/@system --dest / --no-snapshot
```

**System Restore Features:**
- **Metadata preservation**: Restores permissions, ownership, timestamps, ACLs, extended attributes, hard links, and symlinks
- **Safety snapshot**: Creates a pre-restore BTRFS snapshot of the destination before making changes
- **Dry-run mode**: Preview all changes without modifying any files
- **Source validation**: Verifies the backup contains critical system directories (`bin`, `etc`, `lib`, `usr`) and files (`etc/passwd`, `etc/fstab`) before proceeding
- **Disk space check**: Confirms sufficient space at the destination before restore

### Home Restore

#### TL;DR
```bash
# Preview what would be restored (safe, no changes made)
sudo ./bin/home-restore.sh --source /mnt/point/@home --dest /home --dry-run

# Restore home with a pre-restore safety snapshot
sudo ./bin/home-restore.sh --source /mnt/point/@home --dest /home --snapshots /mnt/point/@snapshots

# Restore without creating a snapshot
sudo ./bin/home-restore.sh --source /mnt/point/@home --dest /home --no-snapshot
```

**Home Restore Features:**
- **Metadata preservation**: Restores permissions, ownership, timestamps, ACLs, extended attributes, hard links, and symlinks
- **Safety snapshot**: Creates a pre-restore BTRFS snapshot of the destination before making changes
- **Dry-run mode**: Preview all changes without modifying any files
- **Independent from system**: Restore just `/home` after a distro switch without touching `/`
- **Disk space check**: Confirms sufficient space at the destination before restore

## Backup Principles

Three backup tiers + one live storage subvolume, all independent:

| Subvolume | Role | Script |
|-----------|------|--------|
| `@system` | OS backup | `system-backup.sh` → `/` excluding `/home` |
| `@home` | Home backup | `home-backup.sh` → `/home` dotfiles and config |
| `@data` | Live disk extension | Mounted directly — no backup script |
| `@archive` | Cold storage | Manual `rsync` or dedicated tool — no backup script |

### System (`@system`)
- **Goal**: OS and application state for full system recovery
- **Method**: Backup everything under `/` EXCEPT excluded items
- **Excludes**: `/home/` entirely, virtual filesystems, caches, temp files

### Home (`@home`)
- **Goal**: User environment — dotfiles, shell config, app settings
- **Method**: Backup `/home` with cache and large-data exclusions
- **Excludes**: `.cache/`, dev tool caches, and large data dirs you manage separately
- **Key benefit**: Restore just home after a distro switch without touching `/`

### Data (`@data`) — Live Storage Extension
- **Goal**: Extend internal disk capacity with the external drive
- **Method**: Mount directly and use as regular storage (no backup script involved)
- **Use for**: Active projects, VMs, large working files — anything your internal disk can't fit
- **Mount example**: `sudo mount -o subvol=@data /dev/mapper/encrypted_root /mnt/data`

### Archive (`@archive`) — Cold Storage
- **Goal**: Long-term storage of infrequently accessed data
- **Method**: Managed manually — use `rsync`, `restic`, or `borgbackup` as needed
- **Use for**: Completed projects, media libraries, documents you rarely need

## Why This Approach?

**Two focused backup scripts, two plain storage subvolumes:**

- **Distro switch** → restore `@home` to new install, `@system` stays untouched
- **System crash** → restore `@system` without overwriting your home
- **Disk full** → use `@data` as transparent overflow storage, always available
- **Cold storage** → `rsync` to `@archive` manually when you need it

**Result**: Each subvolume has one clear job. Backups stay simple, restores stay safe.

## License

MIT License - see [LICENSE](LICENSE) file for details.

