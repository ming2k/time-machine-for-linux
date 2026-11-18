# How-To Guides

Task-oriented runbooks for specific backup, restoration, archiving, and maintenance workflows. Each guide assumes you have completed [Getting Started](../tutorials/getting-started.md) and understand the basic command layout.

---

## Guides Catalog

| Guide | Solves | Primary Commands |
| :--- | :--- | :--- |
| **[Routine End-to-End Backup Workflow](routine-backup-workflow.md)** | Standard daily lifecycle: mount, preflight status inspection, tier backups, snapshot verification, and clean unmount. | `tools/mountctl.sh mount`, `bin/system-backup.sh`, `bin/home-backup.sh`, `bin/data-backup.sh`, `tools/mountctl.sh unmount` |
| **[System Backup & Disaster Recovery](system-backup-and-restore.md)** | Protect the operating system root and recover a non-booting machine from a Live USB environment. | `bin/system-backup.sh`, `bin/system-restore.sh` |
| **[User Home Backup & Distro Migration](home-backup-and-restore.md)** | Back up personal user dotfiles and application states, and migrate configs onto a fresh Linux distribution install. | `bin/home-backup.sh`, `bin/home-restore.sh` |
| **[Workspace Data Backup & Rollback](data-backup-and-restore.md)** | Safeguard active development source trees while stripping build artifacts (`node_modules`, `target`), and restore projects from snapshots. | `bin/data-backup.sh`, `bin/data-restore.sh` |
| **[Archive Cold Data](archive-cold-data.md)** | Retire finished projects and bulky dormant media to append-only cold storage with optional checksum verification and local cleanup. | `bin/archive-sync.sh`, `bin/archive-sync.sh --checksum --clean-source` |
| **[Format Encrypted BTRFS Drive](format-btrfs-drive.md)** | Initialize a new external drive with LUKS2 encryption and 5 standard BTRFS subvolumes (`@system`, `@home`, `@data`, `@archive`, `@snapshots`). | `tools/format-btrfs-luks.sh -d <dev>`, `tools/mountctl.sh mount -d <dev>` |
| **[Snapshot Pruning & BTRFS Balance](maintain-btrfs-and-prune-snapshots.md)** | Inspect snapshot history, prune expired runs according to policy, and execute filtered chunk balancing to reclaim unallocated space. | `tools/prune-snapshots.sh --list`, `tools/prune-snapshots.sh --keep <N>`, `tools/balance-btrfs.sh` |

For the full CLI option specification, consult the [CLI Reference](../reference/cli.md).
