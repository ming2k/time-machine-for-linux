# Linux Time Machine

A comprehensive backup solution for Linux systems, providing functionality similar to Apple's Time Machine. This project includes utilities for system backup, data backup, and user data restoration.

## Features

- **System Backup**: Full system backup with BTRFS snapshots support
- **Data Backup**: Configurable data backup with exclude patterns
- **User Restore**: Selective restoration of user data and system configurations
- **BTRFS Support**: Efficient snapshot management using BTRFS
- **Flexible Configuration**: Easily customizable backup paths and exclusion patterns
- **Robust Logging**: Comprehensive logging system with rotation support
- **Configuration Validation**: Automatic validation of backup configurations
- **Test Suite**: Comprehensive test coverage for core functionality
- **Error Handling**: Detailed error reporting and recovery options

## Prerequisites

- Linux system with `rsync` installed
- BTRFS filesystem for backup destination (required)
- Root privileges for system operations
- Bash 4.0 or later

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
git clone https://github.com/ming2k/time-machine-for-linux.git
cd time-machine-for-linux
```

2. Make scripts executable:
```bash
chmod +x bin/*.sh
```

3. Validate your configuration:
```bash
sudo ./bin/validate-config.sh all
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

## Logging

The backup system maintains detailed logs in the `logs` directory:

- `backup.log`: Current log file
- `backup.log.1`, `backup.log.2`, etc.: Rotated log files
- Log rotation: 10MB size limit, keeps 5 rotated files

## Testing

Run the test suite to verify functionality:

```bash
./tests/test_runner.sh
```

Test categories:
- Unit tests for core functionality
- Integration tests for backup operations
- Configuration validation tests
- Error handling tests

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
│   ├── system-backup.sh   # System backup utility
│   ├── data-backup.sh     # Data backup utility
│   ├── user-restore.sh    # User data restore utility
│   └── validate-config.sh # Configuration validator
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
│   ├── unit/             # Unit tests
│   ├── integration/      # Integration tests
│   └── test_utils.sh     # Test utilities
├── logs/                  # Log files
└── docs/                 # Documentation
```

## Module Organization

### Core Module
- Basic utilities and shared functionality
- Logging, colors, library loading
- Error handling and reporting

### Filesystem Module
- Filesystem operations and utilities
- BTRFS-specific operations
- Path validation and management

### Config Module
- Configuration parsing and validation
- Config file management
- Environment variable support

### Backup Module
- Backup operations and protection
- Snapshot management
- Progress tracking and reporting

### UI Module
- User interface components
- Progress display and user interaction
- Error message formatting

## Contributing

1. Fork the repository
2. Create your feature branch
3. Run tests: `./tests/test_runner.sh`
4. Commit your changes
5. Push to the branch
6. Create a new Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Safety Note

Always verify your backups and test the restoration process in a safe environment before relying on them for critical data.

