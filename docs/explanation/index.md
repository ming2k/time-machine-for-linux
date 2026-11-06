# Explanation

Discursive documentation that explains how and why Time Machine for Linux is built the way it is. Read these articles to understand architectural philosophy, storage topology, and design trade-offs.

---

## Articles Catalog

| Article | Explains |
| :--- | :--- |
| **[Storage Architecture & Tiering Rationale](storage-architecture.md)** | Multi-tier NVMe hardware topology, why storage is divided into independent subvolumes, and the synergy of rsync filtering with BTRFS Copy-on-Write snapshots. |
| **[Backup Principles & Anti-Hoarding](backup-principles.md)** | The philosophy deciding what gets backed up and what does not: system recoverability vs data rarity, deterministic manifests over disposable binaries, and backup vs archive demarcation. |
| **[Preflight Checks Architecture](preflight-checks.md)** | Pre-execution safety architecture: disk capacity thresholds, snapshot accumulation warnings, BTRFS log analysis, and non-blocking interactive confirmation. |

For the ratified decision records behind these choices, consult the [Architectural Decision Records](../adr/index.md).
