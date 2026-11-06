---
id: ADR-0003
title: "Restore Fail-Closed Safety and Explicit Affirmation Guardrails"
status: accepted
date: 2026-10-31
scope: restore/core
superseded_by: null
negative_knowledge: true
---

# 0003. Restore Fail-Closed Safety and Explicit Affirmation Guardrails

- Status: Accepted
- Date: 2026-10-31
- Deciders: maintainer, AI architect
- Scope: restore/core

---

## Context and Problem Statement

A fundamental operational asymmetry exists between backup and restore operations:
- **Backup Risk Boundedness**: Backup source systems (`/`, `/home`, `/data`) remain strictly read-only. Destructive mirror reconciliation (`--delete --delete-excluded --force`) modifies only external backup subvolumes and is shielded by immutable BTRFS point-in-time snapshots in `@snapshots` ([INV-BACKUP-01, INV-BACKUP-02]).
- **Restore Overwrite Danger**: Restore operations write directly into active production environments (OS root `/`, user homes `/home`, or active development workspaces `/data`). Overwriting existing files during a disaster recovery run is irreversible without a valid rollback point.

Prior to this decision, the restore subsystem exhibited critical fail-open vulnerabilities:
1. **The "Fail-Open" Snapshot Trap**: When pre-restore safety snapshot creation failed (e.g. cross-filesystem link errors when attempting to snapshot local root into external `/mnt/@snapshots`, permission issues, or non-BTRFS targets), the engine logged a warning (`Failed to create pre-restore snapshot, but continuing...`) and proceeded with destructive rsync overwrites.
2. **Low Cognitive Friction Prompting**: Destructive restore operations relied on standard confirmation routines (`confirm_execution`), allowing muscle-memory single-character `y` or Enter to authorize full-system overwrites.
3. **Missing System Target Isolation**: System restore against `/` lacked exclusion guards for virtual pseudo-filesystems (`/proc`, `/sys`, `/dev`, `/run`) and active mountpoints (`/mnt`, `/media`), risking kernel I/O panics and recursive overwrites of the mounted backup disk itself.
4. **Target Identity Hazards**: No guards prevented catastrophic parameter inversion where source and destination were identical (`source == dest`) or where destination targeted protected backup tiers (`@archive`, `@snapshots`).

---

## Decision Drivers

- **Fail-Closed Default**: Destructive operations must never proceed when safety guarantees fail. If a rollback snapshot cannot be secured, the operation must immediately halt.
- **Cognitive Friction by Design**: Preventing muscle-memory authorization. An operator initiating a production overwrite must explicitly type a non-trivial, case-sensitive affirmative token.
- **Target Boundary Isolation**: System recovery must never touch virtual kernel filesystems or write back into the active backup drive mount trees.
- **Zero Legacy Baggage**: Cleanly eliminate fake snapshot promises and unshielded restore paths without preserving buggy fallback behavior.

---

## Considered Options

- **Option 1**: Keep warning-and-continue behavior but print more prominent red warning text.
- **Option 2**: Implement an elaborate multi-tiered restore state machine with online runtime kernel diagnostics and chroot rescue managers.
- **Option 3**: Standardize lean, uncompromising fail-closed mechanics: Fail-Closed snapshot abort, exact uppercase `YES` affirmation, path identity/archive protection, and mandatory virtual filesystem exclusions for system recovery.

---

## Decision Outcome

Chosen option: **Option 3: Standardize lean, uncompromising fail-closed mechanics**.

The restore execution engines (`bin/*-restore.sh`, `lib/restore/*`, `lib/utils/confirm-execution.sh`) enforce immediate abort upon snapshot failure, require explicit uppercase `YES` input, and apply boundary protections.

---

### Invariants & Behavioral Boundaries

- **`[INV-RESTORE-01] Fail-Closed Snapshot Invariant`**:
  In non-dry-run mode, when pre-restore snapshot creation is enabled, any snapshot failure MUST immediately terminate the restore pipeline with a non-zero exit code. Proceeding past snapshot failure is strictly prohibited. To proceed without snapshot protection, operators must explicitly pass `--no-snapshot`.
- **`[INV-RESTORE-02] Explicit Affirmation Invariant`**:
  Destructive restore confirmation MUST require exact case-sensitive affirmation (`YES`). Default Enter, empty responses, and lowercase tokens (`y`, `yes`) MUST be rejected and abort the operation.
- **`[INV-RESTORE-03] Target Boundary Protection Invariant`**:
  Restore operations MUST reject source/destination identity (`source == dest`), prohibit destination paths targeting protected backup tiers (`@archive`, `@snapshots`), and automatically exclude kernel pseudo-filesystems and mountpoint roots (`/proc/*`, `/sys/*`, `/dev/*`, `/run/*`, `/tmp/*`, `/mnt/*`, `/media/*`, `/lost+found`) when restoring system files.

---

### Positive Consequences

- Eliminates unshielded overwrites caused by silent cross-filesystem snapshot failures.
- Stops accidental muscle-memory confirmation (`y` + Enter) from wiping live production data.
- Shields active backup mounts (`/mnt`) and Linux virtual filesystems against recursive corruption during OS recovery.
- Maintains zero runtime bloat while providing deterministic disaster recovery safety.

---

### Negative Consequences & Trade-offs

- Operators performing disaster recovery across heterogeneous filesystems (e.g. non-BTRFS root) must explicitly pass `--no-snapshot` to bypass local snapshot generation.
- Automated headless restore scripts must pipe `YES` to stdin instead of relying on default responses.

---

## Rejected Alternatives & Negative Knowledge

### Option 1 (Warning Prominence Only) — Rejected
- **Why rejected**: Relying on visual warnings while the code continues execution violates the "Mechanisms Over Exhortations" doctrine. Operators under disaster recovery stress routinely overlook terminal warnings.

### Option 2 (Elaborate Multi-Layered State Machine) — Rejected
- **Why rejected**: Heavy runtime layers create maintenance debt in shell code and introduce new failure modes during emergency bare-metal recovery. Safety is maximized by simple, deterministic checks rather than complex abstractions.
