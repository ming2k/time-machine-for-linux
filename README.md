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
### Data Backup - Keep Your Media & Files
```bash
# Backup your important data and media files
sudo ./bin/data-backup.sh /home/user /mnt/@data /mnt/@snapshots
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

### Data Backup (Whitelist - Include What You Want)
- **Goal**: Comprehensive data preservation with incremental support
- **Method**: Only backup explicitly included patterns
- **Strategy**: Selective backup of:
  - Documents and personal files
  - Media collections
  - Project files
  - Configuration backups

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

### Data Backup Config - `config/data-backup-keep`
```bash
# Include documents
*.pdf
*.doc
*.txt

# Include media (excluded from system backup)
/home/*/Music/
/home/*/Videos/
/home/*/Pictures/

# Include projects
Projects/
Documents/
```

## Installation

### Quick Start
```bash
git clone https://github.com/ming2k/time-machine-for-linux.git
cd time-machine-for-linux

# Run system backup
sudo ./bin/system-backup.sh / /mnt/@root /mnt/@snapshots

# Run data backup
sudo ./bin/data-backup.sh /home/user /mnt/@data /mnt/@snapshots
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

**Data Backup (Whitelist)**:
- Handles large media files separately
- Supports incremental backups efficiently
- Flexible selection of what to preserve
- Optimized for large storage scenarios

**Result**: You get a complete system that can be fully restored (without media clutter) + comprehensive data backup with all your files and media.

## License

MIT License - see [LICENSE](LICENSE) file for details.

