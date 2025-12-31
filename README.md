# Time Machine for Linux

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![BTRFS](https://img.shields.io/badge/Filesystem-BTRFS-blue.svg)](https://btrfs.wiki.kernel.org/)

A safe, simple, less dependency and opinionated backup solution for Linux systems inspired by Apple Time Machine.

> [!IMPORTANT]
> There are !!!RISKS!!! in manipulating data. Please pay attention to data security before ensuring that the solution can work properly.

## Prerequisites
- A storage medium with a storage capacity larger than the data to be backed up
- Linux with `rsync` and `btrfs`(from btrfs-progs) commands
- Root privileges for system operations

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
sudo btrfs subvolume create /mnt/@root
sudo btrfs subvolume create /mnt/@data
sudo btrfs subvolume create /mnt/@snapshots
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
# Basic system backup (complete system excluding media files)
sudo ./bin/system-backup.sh --source / --dest /mnt/point/@ --snapshots /mnt/point/@snapshots
```
#### System Backup Config

`config/system-backup-ignore`

```bash
# Exclude media files (put them in data backup instead)
/home/*/Music/
/home/*/Videos/
/home/*/Downloads/

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
- **BTRFS snapshots**: Creates pre-backup snapshots for safety
- **Efficient transfers**: Uses rsync with progress reporting
- **Smart exclusions**: Automatically excludes virtual filesystems, temp files, and media
- **User confirmation**: Shows preview before execution

### Data Backup

#### TL;DR

```bash
# Backup multiple sources with individual configurations
sudo ./bin/data-backup.sh --dest /mnt/@data --snapshots /mnt/@snapshots
# Using custom configuration file
sudo ./bin/data-backup.sh --dest /mnt/@data --snapshots /mnt/@snapshots --config custom-map.conf
```

#### Data Backup Config

`config/data-map.conf`
```bash
# Map-based configuration with shell variables

# User home directory (excluding downloads and caches)
BACKUP_ENTRY_1_SOURCE="/home/user"
BACKUP_ENTRY_1_DEST="home_user"
BACKUP_ENTRY_1_IGNORE="Downloads/,downloads/,.cache/,*.tmp,*.log"
BACKUP_ENTRY_1_MODE="incremental"

# Important documents folder
BACKUP_ENTRY_2_SOURCE="/home/user/Documents"
BACKUP_ENTRY_2_DEST="documents"
BACKUP_ENTRY_2_MODE="full"

# Media collection
BACKUP_ENTRY_3_SOURCE="/home/user/Media"
BACKUP_ENTRY_3_DEST="media"
BACKUP_ENTRY_3_IGNORE="*.tmp,*.partial"
BACKUP_ENTRY_3_MODE="incremental"

# Website directory (exact mirror)
BACKUP_ENTRY_4_SOURCE="/var/www"
BACKUP_ENTRY_4_DEST="website"
BACKUP_ENTRY_4_MODE="mirror"  # Will delete files not in source
```

**Backup Modes:**
- **full**: Copy all files, keep existing files in destination
- **incremental**: Only copy changed files (uses rsync's change detection)
- **mirror**: Create exact mirror, removes files not present in source


## Backup Principles

### System Backup (Blacklist - Exclude What You Don't Need)
- **Goal**: Complete system preservation for full recovery
- **Method**: Backup everything EXCEPT excluded items
- **Strategy**: Keep it slim by excluding:
  - Large Data files (AI Models, Music, Videos and so on)
  - Temporary files and caches
  - Virtual filesystems (/proc, /sys, /dev)
  - Files that cause redundant (/home/*/{Downloads,downloads}, /mnt, /snapshots if it exists )

### Data Backup (Map-Based - Multiple Sources with Custom Rules)
- **Goal**: Flexible backup of multiple directories with individual control
- **Method**: Source-destination mapping with per-source ignore patterns and backup modes
- **Strategy**: Organized backup with:
  - Multiple source directories mapped to subdirectories
  - Individual ignore patterns per source (gitignore syntax)
  - Choice of backup modes: full, incremental, or mirror
  - Centralized configuration in `config/data-map.conf`

## Why This Approach?

**System Backup (Blacklist)**:
- Ensures complete system recovery capability
- Excludes media to keep backup size manageable
- Preserves all applications and system state
- Quick system restoration when needed

**Data Backup (Map-Based)**:
- Handles multiple sources with individual control
- Each source can have different ignore patterns and backup modes
- Organized into subdirectories for easy management
- Supports full, incremental, and mirror backup modes
- Flexible configuration for various backup scenarios

**Result**: You get a complete system that can be fully restored (without media clutter) + flexible data backup with multiple sources, each configured according to your specific needs.

## License

MIT License - see [LICENSE](LICENSE) file for details.

