# How-To Guides

Task-oriented runbooks for specific backup, restoration, archiving, and maintenance workflows. Each guide assumes you have completed [Getting Started](../tutorials/getting-started.md) and understand the basic CLI workflow.

---

## Guides Catalog

| Guide | Solves | Primary Commands |
| :--- | :--- | :--- |
| **[Routine End-to-End Backup Workflow](routine-backup-workflow.md)** | Standard daily lifecycle: mount, preflight status inspection, backup execution, snapshot verification, and clean unmount. | `tm mount`, `tm backup`, `tm unmount` |
| **[System Backup & Disaster Recovery](system-backup-and-restore.md)** | Protect the operating system root and recover a non-booting machine from a Live USB environment. | `tm backup --system`, `tm restore system` |
| **[User Home Backup & Distro Migration](home-backup-and-restore.md)** | Back up personal user dotfiles and application states, and migrate configs onto a fresh Linux distribution install. | `tm backup --home`, `tm restore home` |
| **[Workspace Data Backup & Rollback](data-backup-and-restore.md)** | Safeguard active development source trees while stripping build artifacts (`node_modules`, `target`), and rollback projects from snapshots. | `tm backup --data`, `tm restore data` |
| **[Archive Cold Data](archive-cold-data.md)** | Safely retire finished projects and bulky dormant media to append-only cold storage with bitstream verification and local cleanup. | `tm archive`, `tm archive --checksum --clean-source` |
| **[Format Encrypted BTRFS Drive](format-btrfs-drive.md)** | Initialize a new external drive with LUKS2 encryption and standard BTRFS subvolumes (`@system`, `@home`, `@data`, `@archive`, `@snapshots`). | `tm format -d <dev>`, `tm mount <dev>` |
| **[Snapshot Pruning & BTRFS Balance](maintain-btrfs-and-prune-snapshots.md)** | Inspect snapshot history, prune expired runs according to policy, and execute safe filtered chunk balancing to reclaim unallocated space. | `tm snapshots`, `tm prune --keep <N>`, `tm balance` |

For the full CLI option specification, consult the [CLI Reference](../reference/cli.md).
