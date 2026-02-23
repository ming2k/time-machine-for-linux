# Features

## Overview

Time Machine for Linux provides Apple Time Machine-like backup functionality for Linux systems using BTRFS snapshots and rsync.

## Backup Scripts

### System Backup (`bin/system-backup.sh`)

Full system backup with blacklist approach.

```bash
sudo ./bin/system-backup.sh --source / --dest /mnt/@system --snapshots /mnt/@snapshots
```

**Features:**
- Backs up entire system except excluded patterns
- Excludes `/home/` entirely (backed up separately by `home-backup.sh`)
- Uses `config/system-backup-ignore` for exclusions
- Gitignore-style pattern syntax
- Mirror mode (syncs deletions)
- BTRFS snapshot after backup

### Home Backup (`bin/home-backup.sh`)

Home directory backup — dotfiles, config, app state.

```bash
sudo ./bin/home-backup.sh --dest /mnt/@home --snapshots /mnt/@snapshots
```

**Features:**
- Backs up `/home` excluding caches and large data dirs
- Uses `config/home-backup-ignore` for exclusions
- Independent of system backup — restore after distro switch without touching `/`
- BTRFS snapshot after backup

## Configuration

### System Backup (`config/system-backup-ignore`)

Gitignore-style exclusion patterns:

```gitignore
# Home directory (backed up separately by home-backup.sh)
/home/

# Virtual filesystems
/proc/*
/sys/*
/dev/*

# Temporary files
/tmp/*
*.tmp
```

### Home Backup (`config/home-backup-ignore`)

Gitignore-style exclusion patterns:

```gitignore
# Caches and volatile data
.cache/
.thumbnails/

# Large data directories (manage separately)
downloads/
documents/
projects/
```

## Safety Features

### BTRFS Snapshots
- Creates snapshot after successful backup
- Naming: `system-backup-YYYYMMDDHHMMSS`, `home-backup-YYYYMMDDHHMMSS`
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

See [preflight-checks.md](preflight-checks.md) for details.

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
```

## Requirements

- **Bash 4.0+** - For associative arrays
- **rsync** - File synchronization
- **btrfs-progs** - BTRFS operations
- **Root privileges** - Required for backup operations

## File Structure

```
time-machine-for-linux/
├── bin/
│   ├── system-backup.sh     # System backup (/ excluding /home)
│   ├── system-restore.sh    # System restore
│   ├── home-backup.sh       # Home backup (/home)
│   └── home-restore.sh      # Home restore
├── config/
│   ├── system-backup-ignore      # System exclusions
│   ├── home-backup-ignore        # Home exclusions
│   └── *.example                 # Example configs
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
[2024-01-15 10:30:45] [SUCCESS] Backup completed
[2024-01-15 10:32:15] [ERROR] rsync operation failed with status 1
```

## Related Documentation

- [Preflight Checks](preflight-checks.md)
- [CLAUDE.md](../CLAUDE.md) - Developer guide
