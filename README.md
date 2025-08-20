# Time Machine for Linux

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![BTRFS](https://img.shields.io/badge/Filesystem-BTRFS-blue.svg)](https://btrfs.wiki.kernel.org/)

[English](README.md) | [中文](README.zh.md)

A simple backup solution for Linux systems providing Apple Time Machine-like functionality. Separates system backup (slim & complete) from data backup (comprehensive & selective).

## How to Use

### System Backup
```bash
# Backup your complete system (excluding media files)
sudo ./bin/system-backup.sh / /mnt/@root /mnt/@snapshots
```
### Data Backup - Multiple Sources & Destinations
```bash
# Backup multiple sources with individual configurations
sudo ./bin/data-backup.sh --dest /mnt/@data --snapshots /mnt/@snapshots

# Using custom configuration file
sudo ./bin/data-backup.sh --dest /mnt/@data --snapshots /mnt/@snapshots --config custom-map.conf
```
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
  - Centralized configuration in `config/data-backup-map.conf`

## Configuration

### System Backup Config - `config/system-backup-ignore`
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

### Data Backup Config - `config/data-backup-map.conf`
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

## Installation

### Quick Start
```bash
git clone https://github.com/ming2k/time-machine-for-linux.git
cd time-machine-for-linux

# Configure data backup sources (edit config/data-backup-map.conf)
# See examples in config/data-backup-map.conf.example

# Run system backup
sudo ./bin/system-backup.sh --source / --dest /mnt/@root --snapshots /mnt/@snapshots

# Run data backup (multiple sources)
sudo ./bin/data-backup.sh --dest /mnt/@data --snapshots /mnt/@snapshots
```

### Prerequisites
- Linux with `rsync` and `btrfs` commands
- BTRFS filesystem for backup destination
- Root privileges for system operations

### BTRFS Setup

#### Option 1: Simple BTRFS Setup
```bash
# Create subvolumes
sudo btrfs subvolume create /mnt/@root
sudo btrfs subvolume create /mnt/@data
sudo btrfs subvolume create /mnt/@snapshots
```

#### Option 2: Encrypted BTRFS+LUKS Setup
Use the provided tool for secure encrypted backup storage:

```bash
# Format device with LUKS encryption + BTRFS with subvolumes
sudo ./tools/format-btrfs-luks.sh -d /dev/sdX

# After setup, mount the encrypted filesystem:
sudo cryptsetup open /dev/sdX encrypted_root
sudo mount /dev/mapper/encrypted_root /mnt

# Create additional subvolumes for backups:
sudo btrfs subvolume create /mnt/@root     # System backups
sudo btrfs subvolume create /mnt/@data     # Data backups
sudo btrfs subvolume create /mnt/@snapshots # Backup snapshots
```

**⚠️ Warning**: The format tool will **DESTROY ALL DATA** on the specified device!

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

