# How to Prune Dirty Snapshots and Balance BTRFS

This guide covers routine maintenance for BTRFS backup storage: inspecting historical snapshots, safely purging dirty or expired runs, and running filtered BTRFS balances to reclaim locked disk space.

---

## 1. Inspecting Historical Snapshots

Whenever you want to check your snapshot history and identify dirty/test runs:

```bash
./tm snapshots
```

Output displays all snapshots tagged with tier and human-readable timestamp:
```text
=== Current BTRFS Snapshots in /mnt/@snapshots ===
  SNAPSHOT NAME                        TIER         TIMESTAMP
  ───────────── ──── ─────────
  archive-batch-20260924131706         archive      2026-09-24 13:17:06
  data-backup-20260924130011           data         2026-09-24 13:00:11
  home-backup-20260924125957           home         2026-09-24 12:59:57
  ...
Total: 18 snapshots
```

---

## 2. Pruning Snapshots

### Strategy A: Policy Retention (Keep N Newest per Tier)
To clean up routine clutter and retain only the newest runs (e.g. keep newest 3 per tier):

```bash
# 1. Preview changes (safe dry-run)
sudo ./tm prune --keep 3

# 2. Actually delete older snapshots
sudo ./tm prune --keep 3 --apply
```

### Strategy B: Targeted Deletion of Dirty / Test Snapshots
If a specific run was interrupted or captured unwanted temporary state:

```bash
# Delete a single specific snapshot
sudo ./tm prune data-backup-20260924130011 --apply

# Delete all snapshots matching a time pattern (e.g. testing runs at 13:01)
sudo ./tm prune "*202609241301*" --apply
```

---

## 3. Reclaiming Disk Space with BTRFS Balance

### Does BTRFS Balance Save Space?
**Yes, but in a specific way.**

BTRFS allocates disk space in large **1GB Chunks (Block Groups)**. When you delete 30GB of old files or prune 10 historical snapshots:
- The chunks still hold sparse residual data.
- The chunks remain allocated to BTRFS, preventing the drive from returning them to the **unallocated pool**.
- You may encounter the dreaded **"False ENOSPC" (No space left on device)** even when `df -h` reports hundreds of gigabytes free.

### Why You Should NEVER Run a Naked `btrfs balance start`
Running a bare `btrfs balance start /mnt` without filters forces BTRFS to re-write **every single gigabyte on the disk**, wearing out SSD write endurance (TBW) and freezing I/O for hours.

### Safe Filtered Balancing with `tm balance`
`tm balance` applies safe, progressive threshold filters (`-dusage` and `-musage`), consolidating only sparsely populated block groups:

```bash
# Recommended: Standard balance (consolidates chunks under 50% utilization)
sudo ./tm balance /mnt

# Fast balance (reclaims only near-empty chunks under 10% utilization; takes seconds)
sudo ./tm balance --quick /mnt
```

### When to Run Balance
- After deleting large obsolete directories (e.g. removing 30GB of old projects).
- After pruning multiple historical snapshots.
- When `btrfs filesystem usage /mnt` shows `Device unallocated` dropping below 5–10GB.
