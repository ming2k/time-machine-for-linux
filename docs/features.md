# Features

## Overview

Time Machine for Linux provides Apple Time Machine-like backup functionality for Linux systems using BTRFS snapshots and rsync.

## Backup Utilities

### System Backup (`bin/system-backup.sh`)

Full system backup with blacklist approach.

```bash
sudo ./bin/system-backup.sh --source / --dest /mnt/@ --snapshots /mnt/@snapshots
```

**Features:**
- Backs up entire system except excluded patterns
- Uses `config/system-backup-ignore` for exclusions
- Gitignore-style pattern syntax
- Mirror mode (syncs deletions)
- BTRFS snapshot after backup

### Data Backup (`bin/data-backup.sh`)

Multi-source backup with map-based configuration.

```bash
sudo ./bin/data-backup.sh --dest /mnt/@data --snapshots /mnt/@snapshots
```

**Features:**
- Multiple source-destination mappings
- Per-source ignore patterns
- Incremental or mirror mode per source
- Orphan detection when config changes
- Supports `.backupignore` files in source directories

## Configuration

### System Backup (`config/system-backup-ignore`)

Gitignore-style exclusion patterns:

```gitignore
# Virtual filesystems
/proc/*
/sys/*
/dev/*

# Temporary files
/tmp/*
*.tmp

# User data (backed up separately)
/home/*/documents/*
```

### Data Backup (`config/data-map.conf`)

Pipe-delimited format: `source|dest|ignore_patterns|mode`

```
/home/user/documents|documents||incremental
/home/user/projects|projects|node_modules/,target/|mirror
/var/www|website||mirror
```

**Fields:**
- `source` - Source directory path
- `dest` - Subdirectory name under backup destination
- `ignore_patterns` - Comma-separated patterns (optional)
- `mode` - `incremental` (default) or `mirror`

## Backup Modes

### Incremental
- Only copies changed files
- Never deletes files from destination
- Safe for accumulating backups

### Mirror
- Exact copy of source
- Deletes files not present in source
- Uses `--delete` flag

## Safety Features

### BTRFS Snapshots
- Creates snapshot after successful backup
- Naming: `system-backup-YYYYMMDDHHMMSS` or `data-backup-YYYYMMDDHHMMSS`
- Enables point-in-time recovery

### Preflight Checks

Automatically warns about issues before backup:

```
[WARN]  38 snapshots found (consider cleanup)
[WARN]  Last backup: 14 days ago
[ERROR] Only 8% disk space remaining
```

**Checks:**
- Disk space (< 20% warning, < 10% error)
- Snapshot count (> 10 warning)
- Last backup time (> 7 days warning)
- BTRFS filesystem health
- Source accessibility (data backup)
- Orphaned destinations (data backup)

See [preflight-checks.md](preflight-checks.md) for details.

### Orphan Detection

Detects backup destinations no longer in config:

```bash
# List orphaned directories
sudo ./bin/data-backup.sh --dest /mnt/@data --snapshots /mnt/@snapshots --list-orphans

# Interactive cleanup
sudo ./bin/data-backup.sh --dest /mnt/@data --snapshots /mnt/@snapshots --cleanup-orphans
```

## .backupignore Files

Place `.backupignore` in any source directory to exclude files:

```
# /home/user/projects/.backupignore
node_modules/
dist/
*.log
.env
```

## Terminal Output

### Log Levels
- `[ERROR]` - Red, searchable
- `[WARN]` - Yellow, searchable
- Success/info - Plain text

### Color Support
Colors automatically disabled when:
- `NO_COLOR` environment variable set
- Output piped or redirected
- Terminal is "dumb"

```bash
# Force no colors
NO_COLOR=1 sudo ./bin/system-backup.sh ...

# Pipe to file (colors auto-disabled)
sudo ./bin/system-backup.sh ... | tee backup.log
```

## Requirements

- **Bash 4.0+** - For associative arrays
- **rsync** - File synchronization
- **btrfs-progs** - BTRFS operations
- **Root privileges** - Required for system backup

## File Structure

```
time-machine-for-linux/
├── bin/
│   ├── system-backup.sh    # System backup script
│   └── data-backup.sh      # Data backup script
├── config/
│   ├── system-backup-ignore     # System exclusions
│   ├── data-map.conf            # Data backup mappings
│   └── *.example                # Example configs
├── lib/
│   ├── core/               # Logging, colors
│   ├── config/             # Config parsing
│   ├── fs/                 # Filesystem, BTRFS
│   ├── backup/             # Backup operations
│   ├── restore/            # Restore operations
│   └── utils/              # Utilities, preflight
├── docs/                   # Documentation
├── tests/                  # Test suite
└── logs/                   # Backup logs
```

## Logging

Logs written to `logs/backup-YYYYMMDD.log`:

```
[2024-01-15 10:30:45] [SUCCESS] Backup completed for: /home/user/documents
[2024-01-15 10:31:02] [WARNING] Source directory does not exist: /home/user/old
[2024-01-15 10:32:15] [ERROR] rsync operation failed with status 1
```

## Related Documentation

- [Preflight Checks](preflight-checks.md)
- [Data Backup Scenarios](data-backup-scenarios.md)
- [CLAUDE.md](../CLAUDE.md) - Developer guide
