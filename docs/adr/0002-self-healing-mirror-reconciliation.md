---
id: ADR-0002
title: "Self-Healing Mirror Reconciliation"
status: accepted
date: 2026-09-24
scope: backup/core
superseded_by: null
negative_knowledge: true
---

# 0002. Self-Healing Mirror Reconciliation

- Status: Accepted
- Date: 2026-09-24
- Deciders: maintainer, AI architect
- Scope: backup/core

---

## Context and Problem Statement

When operating active backup tiers (`@system`, `@home`, `@data`), two routine filesystem evolutions occur:
1. **Morphological drift**: A physical directory on the source is replaced by a symlink (e.g. migrating `/home/user/projects` to `/data/projects` and creating a symlink `projects -> /data/projects`).
2. **Rule expansion**: A user adds new patterns to an ignore configuration (e.g. adding `.venv/` or compiler caches) after files matching those patterns were already copied to the backup destination in earlier runs.

Under the previous conservative rsync flags (`--delete` without `--force` or `--delete-excluded`), both evolutions resulted in fatal operational deadlocks:
- When a directory becomes a symlink, rsync refuses to overwrite a non-empty destination directory with a symlink, failing with `could not make way for new symlink` and exit code 23.
- Because rsync treats excluded files as invisible, ordinary `--delete` refuses to touch files matching current ignore patterns. If an obsolete directory contains even one excluded artifact, it can never be removed by rsync.
- This forced operators to manually diagnose and execute destructive `rm -rf` operations on the backup subvolume to unblock subsequent backup runs.

---

## Decision Drivers

- **Autonomous Convergence (Self-Healing)**: The backup system must autonomously converge the destination mirror to match the source state without requiring human intervention.
- **Strict Role Separation**: The live destination subvolume (`@system`, `@home`, `@data`) must strictly represent the *current* state of the source. Historical state preservation is exclusively the duty of BTRFS Copy-on-Write snapshots in `@snapshots`.
- **Zero Double-Backup**: Migrated trees must not linger in deprecated tiers.

---

## Considered Options

- **Option 1**: Retain conservative flags (`--delete` only) and require manual user intervention or dedicated standalone cleanup scripts (`cleanup-excluded.sh`).
- **Option 2**: Implement complex preflight shell hooks that traverse and prune type-mismatched paths before invoking rsync.
- **Option 3**: Adopt rsync native self-healing flags (`--delete --delete-excluded --force`) for active mirror tiers.

---

## Decision Outcome

Chosen option: **Option 3: Adopt rsync native self-healing flags (`--delete --delete-excluded --force`) for active mirror tiers**.

The core backup execution commands in `bin/system-backup.sh`, `bin/home-backup.sh`, and `bin/data-backup.sh` are standardized to:
```bash
rsync -aAXHv --numeric-ids --info=progress2 --delete --delete-excluded --force --exclude-from=...
```

---

### Invariants & Behavioral Boundaries

- **`[INV-BACKUP-01] Mirror Fidelity Invariant`**:
  The active backup destination subvolumes (`@system`, `@home`, `@data`) must be exact point-in-time reflections of source state governed by active ignore rules. Unwanted historical artifacts must be pruned automatically by the mirror engine.
- **`[INV-BACKUP-02] Snapshot Shield Invariant`**:
  Destructive pruning on live mirror subvolumes is permissible because and only because immutable BTRFS snapshots (`@snapshots/*-backup-YYYYMMDDHHMMSS`) permanently protect historical data against accidental exclusion.
- **`[INV-BACKUP-03] Cold Archive Prohibition Invariant`**:
  The flags `--delete`, `--delete-excluded`, and `--force` are **STRICTLY FORBIDDEN** in `bin/archive-sync.sh`. The cold storage tier (`@archive`) is strictly Append-Only.

---

### Positive Consequences

- Completely eliminates `could not make way for new symlink` failures and directory deadlocks.
- Automatically purges obsolete caches and build trees when ignore rules are updated.
- Prevents 30GB+ duplicate data residency when worktrees are moved between drives.
- Zero manual operator maintenance required when directory structures evolve.

---

### Negative Consequences & Trade-offs

- **Risk of Accidental Rule Pruning**: If a user mistakenly excludes an important directory in an ignore file, that directory will be deleted from the live backup mirror on the next run.
  - *Mitigation (Defense-in-Depth)*:
    1. Past states remain intact in prior BTRFS snapshots in `@snapshots`.
    2. Interactive preflight previews and confirmation prompts precede every run.
    3. Official `.example` templates provide pre-audited, battle-tested patterns.

---

## Rejected Alternatives & Negative Knowledge

### Option 1 (Manual Maintenance / Cleanup Scripts) — Rejected
- **Why considered**: Maximum caution; leaves live backup untouched unless explicitly requested.
- **Why rejected**: Violates autonomous backup principles. Operators will not remember to run maintenance tools after changing directory structures. The resulting failure during scheduled or automated backups degrades system reliability.

### Option 2 (Custom Pre-Sync Shell Hooks) — Rejected
- **Why considered**: Avoids giving rsync full pruning authority.
- **Why rejected**: Fragile, race-condition prone, and duplicates logic already implemented in rsync's battle-tested C codebase. Native flags `--force` and `--delete-excluded` solve the problem natively at C-level directory traversal.

---

## Links

- Related ADR: [ADR-0001: Unified CLI Architecture](0001-unified-cli-architecture.md)
- Governing Protocol: Protocol v6.0.0 / `docs-governance`
