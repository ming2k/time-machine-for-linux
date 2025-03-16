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
- BTRFS filesystem for backup destination (recommended)
- Root privileges for system operations

### Recommended BTRFS Structure

```
/mnt/backup/
├── @root      # System root backup
├── @data      # General data backup
└── @snapshots # Backup snapshots
```

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/linux-time-machine.git
cd linux-time-machine
```

2. Make scripts executable:
```bash
chmod +x bin/*.sh
```

## Usage

### System Backup

Backup the entire system with optional snapshots:

```bash
sudo ./bin/system-backup.sh <source_path> <backup_path> <snapshot_path>
```

Requirements:
- `source_path`: Root filesystem to backup
- `backup_path`: Destination path on BTRFS filesystem
- `snapshot_path`: Path for storing snapshots on BTRFS filesystem

Example:
```bash
sudo ./bin/system-backup.sh / /mnt/backup/@root /mnt/backup/@snapshots
```

### Data Backup

Backup specified data directories according to configuration:

```bash
sudo ./bin/data-backup.sh <backup_path> <snapshot_path>
```

Both `backup_path` and `snapshot_path` must be on a BTRFS filesystem. The script will:
1. Create a safety snapshot before backup
2. Perform the backup operation
3. Create a final snapshot if backup succeeds
4. Clean up the pre-backup snapshot
5. Keep the last 5 snapshots, removing older ones

### User Data Restore

Restore user data and system configurations:

```bash
sudo ./bin/user-restore.sh /path/to/backup username
```

Example:
```bash
sudo ./bin/user-restore.sh /mnt/backup/@root john
```

## Configuration

### Data Backup Maps

Edit `config/data-backup-maps.txt` to configure source and destination paths:

```
# Format: source_path|destination_path|exclude_patterns
/home/user/Documents|/documents|*.tmp,*.cache
/var/www/html|/websites|.git,node_modules
```

### System Backup Exclusions

Edit `config/system-backup-exclude-list.txt` to specify paths to exclude from system backup:

```
/proc/*
/sys/*
/tmp/*
/run/*
...
```

### User Restore Configuration

- `config/user-restore-exclude-list.txt`: Patterns to exclude during user data restoration
- `config/user-restore-system-files-list.txt`: System configuration files to restore

## BTRFS Operations

### Create BTRFS Filesystem

```bash
sudo mkfs.btrfs /dev/sdX
```

### Create Subvolumes

```bash
sudo mount /dev/sdX /mnt/backup
sudo btrfs subvolume create /mnt/backup/@root
sudo btrfs subvolume create /mnt/backup/@data
sudo btrfs subvolume create /mnt/backup/@snapshots
```

### Manage Snapshots

List snapshots:
```bash
sudo btrfs subvolume list /mnt/backup
```

Delete snapshot:
```bash
sudo btrfs subvolume delete /mnt/backup/@snapshots/snapshot-name
```

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

# Project Structure

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
│   ├── restore/          # Restore configurations
│   └── defaults/         # Default configurations
├── tests/                 # Test suite
│   ├── unit/             # Unit tests
│   ├── integration/      # Integration tests
│   └── fixtures/         # Test fixtures
└── docs/                 # Documentation
    ├── api/              # API documentation
    └── examples/         # Usage examples
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

