---
id: ADR-0004
title: "Remove the Unified CLI Facade (bin/tm)"
status: accepted
date: 2026-11-15
scope: cli/core
superseded_by: null
negative_knowledge: true
---

# 0004. Remove the Unified CLI Facade (`bin/tm`)

- Status: Accepted
- Date: 2026-11-15
- Deciders: maintainer, AI architect
- Scope: cli/core
- Supersedes: [ADR-0001](0001-unified-cli-architecture.md)

---

## Context and Problem Statement

ADR-0001 introduced `bin/tm` as a single public command that dispatched to the tier backup, restore, archive, mount, and maintenance scripts. The intent was to reduce the number of command names an operator had to remember and to make a full three-tier backup the default action.

In practice, `bin/tm` was almost entirely a router:

1. **No data-path or safety logic**: `bin/tm` did not touch backup data, create snapshots, or enforce restore safety. Every subcommand ended in `exec` against an existing engine.
2. **The important default lived elsewhere**: the single-confirmation, all-tier pipeline was implemented by `tools/backup-all.sh`, not by `bin/tm`. `bin/tm backup` only translated tier flags into `--skip-*` switches.
3. **Documentation drift**: user-facing docs referred to `./tm`, `bin/tm`, and the underlying scripts interchangeably. The repository root has no `tm`, so `sudo ./tm ...` was not a valid command. The subvolume count also diverged: `format` created five, while `mountctl` managed a sixth optional `@media`.
4. **Maintenance cost without a contract**: every new engine flag had to be forwarded and documented twice. The router claimed authority while the engines remained independently documented and invoked.

The facade therefore added a naming layer without providing a stable, enforced boundary.

---

## Decision Drivers

- **Auditability**: A backup tool should expose the commands that actually move data and create snapshots. A router with no data-path logic obscures that mapping.
- **Single source of truth**: Defaults, confirmations, and safety checks should live in the engine that performs the operation, not in a separate translation layer.
- **Documentation integrity**: Every documented command should exist at the documented path and accept the documented flags.
- **Operational simplicity**: Users should be able to read a script, run it, and understand which tier and destination it touches.
- **No product-facing facade**: The project is a script collection, not an installed application that needs a branded command surface.

---

## Considered Options

- **Option 1**: Keep `bin/tm` as a thin router and make it the only documented interface.
- **Option 2**: Remove `bin/tm`, promote `tools/backup-all.sh` to `bin/backup-all.sh`, and document the engines directly.
- **Option 3**: Fold all dispatch logic into a single monolithic script.

---

## Decision Outcome

Chosen option: **Option 2: Remove `bin/tm` and expose the engines directly.**

- `bin/tm` is deleted.
- `tools/backup-all.sh` moves to `bin/backup-all.sh` and remains the full-backup command: it runs System, Home, and Data sequentially with one confirmation.
- Single-tier backups use `bin/system-backup.sh`, `bin/home-backup.sh`, and `bin/data-backup.sh` directly.
- Archive, restore, drive lifecycle, and maintenance operations use their existing scripts in `bin/` and `tools/`.
- The five standard subvolumes remain `@system`, `@home`, `@data`, `@archive`, and `@snapshots`. `@media` is optional and is not created by `tools/format-btrfs-luks.sh`.
- `[INV-CLI-01]` is retired. `[INV-CLI-02]` and `[INV-CLI-03]` remain in force and are enforced by `bin/backup-all.sh`.

### Invariants & Behavioral Boundaries

- **`[INV-CLI-02] Backup-All Default Invariant`**:
  Invoking `bin/backup-all.sh` without tier-scoping flags MUST execute all three active tiers (System, Home, Data) sequentially.
- **`[INV-CLI-03] Single Confirmation Invariant`**:
  Multi-tier backup runs MUST present a consolidated execution plan and prompt the user exactly once prior to starting the pipeline.
- **`[INV-CLI-01] Single Public Interface Invariant`**:
  Retired. There is no router-level public interface; the engine scripts are the public commands.

---

## Positive Consequences

- Every documented command maps directly to a script that performs the operation.
- The full-backup default and confirmation logic live in the same script that runs the tiers.
- Removing the router eliminates a class of argument-forwarding and help-text drift.
- Users can copy a single engine command into a script or systemd unit without reverse-engineering a dispatcher.

## Negative Consequences & Trade-offs

- Users must remember a small set of script names instead of one `tm` command.
  - *Mitigation*: the README and CLI reference provide a short command table; shell aliases remain a user choice.
- Existing documentation and ADRs that referenced `bin/tm` required updates.
  - *Mitigation*: ADR-0001 is marked superseded; this ADR records the replacement. The human-maintained `AGENTS.md` was cleared by the maintainer and no longer defines a CLI contract.

---

## Rejected Alternatives & Negative Knowledge

### Option 1 (Keep `bin/tm` as the sole interface) — Rejected
- **Why considered**: One memorable command is convenient for new users.
- **Why rejected**: The convenience did not justify a second documentation surface. The router had no safety or data-path logic, and the repo already demonstrated drift between the router and the engines. Keeping it would require making the engines private, which contradicts their standalone design and the existing documentation.

### Option 3 (Monolithic command) — Rejected
- **Why considered**: Removes all cross-script calls.
- **Why rejected**: Produces a large, hard-to-audit shell script and couples unrelated backup, restore, mount, and format logic.

---

## Links

- Supersedes: [ADR-0001](0001-unified-cli-architecture.md)
- Related: [ADR-0002](0002-self-healing-mirror-reconciliation.md), [ADR-0003](0003-restore-fail-closed-safety.md)
