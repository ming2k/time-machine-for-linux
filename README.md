# Linux Time Machine

A comprehensive backup solution for Linux systems, providing functionality similar to Apple's Time Machine. This project includes utilities for system backup, data backup, and user data restoration.

## Features

- **System Backup**: Full system backup with BTRFS snapshots support
- **Data Backup**: Configurable data backup with exclude patterns
- **User Restore**: Selective restoration of user data and system configurations
- **BTRFS Support**: Efficient snapshot management using BTRFS
- **Flexible Configuration**: Easily customizable backup paths and exclusion patterns

## Prerequisites

- Linux system with `rsync` installed
- BTRFS filesystem for backup destination (required)
- Root privileges for system operations

### Recommended BTRFS Structure

```
/mnt/
├── @root      # System root backup
├── @data      # General data backup
└── @snapshots # Backup snapshots
```

## Installation

1. Clone the repository:
```bash
git clone https://github.com/ming2k/time-machine-for-linux-script.git
cd time-machine-for-linux-script
```

2. Make scripts executable:
```bash
chmod +x bin/*.sh
```

## Usage

### System Backup

Backup the entire system with snapshots:

```bash
# Full system backup
sudo ./bin/system-backup.sh / /mnt/@root /mnt/@snapshots

# Validate snapshot functionality without performing backup
sudo ./bin/system-backup.sh --validate-snapshots / /mnt/@root /mnt/@snapshots
```

Requirements:
- `source_path`: Root filesystem to backup (usually /)
- `backup_path`: Destination path on BTRFS filesystem (e.g., /mnt/@root)
- `snapshot_path`: Path for storing snapshots (e.g., /mnt/@snapshots)

### Data Backup

Backup specified data directories according to configuration:

```bash
sudo ./bin/data-backup.sh /mnt/@data /mnt/@snapshots
```

Requirements:
- `backup_path`: Destination path for data backups (e.g., /mnt/@data)
- `snapshot_path`: Path for storing snapshots (e.g., /mnt/@snapshots)

The script will:
1. Create a safety snapshot before backup
2. Perform configured backup operations
3. Create a final snapshot if backup succeeds
4. Keep snapshots for recovery if needed

### User Data Restore

Restore user data and system configurations:

```bash
sudo ./bin/user-restore.sh /mnt/@root username
```

## Configuration

### Data Backup Maps

Edit `config/backup/data-maps.conf` to configure source and destination paths:

```
# Format: source_path|destination_path|exclude_patterns
/home/user/Documents|/documents|*.tmp,*.cache
/var/www/html|/websites|.git,node_modules
```

### System Backup Exclusions

Edit `config/backup/system-exclude.conf` to specify paths to exclude from system backup:

```
# System paths and mount points
/proc/*
/sys/*
/tmp/*
/run/*
/mnt/*
/media/*
...
```

### User Restore Configuration

- `config/restore/exclude.conf`: Patterns to exclude during user data restoration
- `config/restore/system-files.conf`: System configuration files to restore

## BTRFS Setup

### Create BTRFS Filesystem

```bash
sudo mkfs.btrfs /dev/sdX
```

### Create Subvolumes

```bash
sudo mount /dev/sdX /mnt
sudo btrfs subvolume create /mnt/@root
sudo btrfs subvolume create /mnt/@data
sudo btrfs subvolume create /mnt/@snapshots
```

### Mount Subvolumes

Add to /etc/fstab:
```
UUID=<device-uuid>  /mnt/@root      btrfs  subvol=@root,compress=zstd:1     0 0
UUID=<device-uuid>  /mnt/@data      btrfs  subvol=@data,compress=zstd:1     0 0
UUID=<device-uuid>  /mnt/@snapshots btrfs  subvol=@snapshots,compress=zstd:1 0 0
```

### Manage Snapshots

List snapshots:
```bash
sudo btrfs subvolume list /mnt
```

Delete snapshot:
```bash
sudo btrfs subvolume delete /mnt/@snapshots/snapshot-name
```

## Project Structure

```
linux-time-machine/
├── bin/                    # Executable scripts
├── lib/                    # Library modules
│   ├── core/              # Core functionality
│   ├── fs/                # Filesystem operations
│   ├── config/            # Configuration handling
│   ├── backup/            # Backup operations
│   └── ui/                # User interface components
├── config/                # Configuration files
│   ├── backup/           # Backup configurations
│   └── restore/          # Restore configurations
├── tests/                 # Test suite
└── docs/                 # Documentation
```

## Module Organization

### Core Module
- Basic utilities and shared functionality
- Logging, colors, library loading

### Filesystem Module
- Filesystem operations and utilities
- BTRFS-specific operations

### Config Module
- Configuration parsing and validation
- Config file management

### Backup Module
- Backup operations and protection
- Snapshot management

### UI Module
- User interface components
- Progress display and user interaction

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Safety Note

Always verify your backups and test the restoration process in a safe environment before relying on them for critical data.

