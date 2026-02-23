# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2026-02-23

### Added
- `bin/home-backup.sh` — dedicated home directory backup (`/home`)
- `bin/home-restore.sh` — dedicated home directory restore
- `config/home-backup-ignore` — exclusion patterns for home backup (caches, dev tool data)
- New BTRFS subvolume structure: `@system`, `@home`, `@data`, `@archive`, `@snapshots`

### Changed
- System backup now excludes `/home/` entirely (single `/home/` rule replaces ~80 per-user patterns)
- Subvolume naming: `@` → `@system`, `@data` → `@archive`, new `@data` for live disk extension
- `format-btrfs-luks.sh` creates the full five-subvolume structure automatically

### Removed
- `bin/data-backup.sh` and `bin/data-restore.sh` — data backup is now managed manually
- `config/data-map.conf` and related pipe-delimited config format
- `lib/backup/backup-state.sh`, `backup-excludes.sh`, `ignore-parser.sh`, `keep-list-parser.sh`
- Orphan detection, `.backupignore` file support, and multi-source map system

## [2.0.0] - 2026-01-30

### Added
- Orphan detection for data backups - detects leftover directories when config entries are removed
- `--list-orphans` flag to view orphaned backup destinations with sizes
- `--cleanup-orphans` flag for interactive removal of orphaned directories
- Backup state tracking via `.backup-state.json` file
- New `docs/data-backup-scenarios.md` documentation for backup workflows
- `.backupignore` file support in source directories
- Package prerequisites section in README (rsync, btrfs-progs, jq, cryptsetup)

### Changed
- Data backup config format changed to pipe-delimited: `source|dest|ignore_patterns|mode`
- Orphan preflight notice elevated from WARNING to CRITICAL level
- Backup now blocks execution when orphans are detected (must resolve first)
- Renamed `docs/PREFLIGHT_CHECKS.md` to `docs/preflight-checks.md` for consistency

### Fixed
- Made test helper files executable

## [1.0.0] - 2024-04-15

### Added
- Initial stable release
- System backup with BTRFS snapshots support
- Data backup with configurable paths and exclusions
- User data restoration capabilities
- Comprehensive logging system with rotation
- Configuration validation
- Test suite for core functionality
- Documentation and examples

### Changed
- Improved error handling in backup scripts
- Enhanced BTRFS snapshot management
- Optimized rsync operations
- Updated logging system with date-based filenames
- Set appropriate file permissions for logs

### Fixed
- Fixed permission issues in backup operations
- Resolved BTRFS snapshot creation edge cases
- Addressed configuration validation issues
- Fixed rsync error handling and progress display

### Security
- Added root privilege checks
- Implemented basic input validation
- Added safety checks for BTRFS operations
- Set proper file permissions for logs

### Documentation
- Created comprehensive README
- Added usage examples
- Documented configuration options
- Added BTRFS setup instructions
- Added CHANGELOG

## [Unreleased]

### Added
- Initial project structure and core functionality
- System backup with BTRFS snapshots support
- Data backup with configurable paths and exclusions
- User data restoration capabilities
- Basic logging and error handling
- Configuration management system

### Changed
- Improved error handling in backup scripts
- Enhanced BTRFS snapshot management
- Optimized rsync operations

### Fixed
- Fixed permission issues in backup operations
- Resolved BTRFS snapshot creation edge cases
- Addressed configuration validation issues

### Security
- Added root privilege checks
- Implemented basic input validation
- Added safety checks for BTRFS operations

### Documentation
- Created comprehensive README
- Added usage examples
- Documented configuration options
- Added BTRFS setup instructions

## [0.1.0] - 2024-03-18

### Added
- Initial release
- Basic backup and restore functionality
- Core library modules
- Configuration system
- Test framework 