---
id: ADR-0005
title: "Remove the backup-all.sh Orchestrator"
status: accepted
date: 2026-11-18
scope: cli/core
superseded_by: null
negative_knowledge: true
---

# 0005. Remove the `backup-all.sh` Orchestrator

- Status: Accepted
- Date: 2026-11-18
- Deciders: maintainer, AI architect
- Scope: cli/core
- Amends: [ADR-0004](0004-remove-unified-cli-facade.md) — retires its `bin/backup-all.sh` clause and `[INV-CLI-02]`/`[INV-CLI-03]`. The `bin/tm` removal and direct-engine command model remain in force.

---

## Context and Problem Statement

ADR-0004 removed the `bin/tm` router but kept a wrapper: `tools/backup-all.sh` was promoted to `bin/backup-all.sh` and documented as *the* full-backup command. That left a single orchestrator on top of otherwise standalone engines, and the orchestrator re-implemented work each engine already performs:

1. **Confirmation bypassed instead of consolidated**: `backup-all.sh` asked its own single confirmation, then piped `y` into three engines that each run their own preflight checks and confirmation prompt. The per-tier preflight output still printed, but the operator was never given the chance to read or act on it, and the engines' "cancelled by user" path became unreachable.
2. **Exit-status erosion**: each tier was invoked inside an `if` condition, so a failed tier was recorded as `FAILED` and the pipeline continued into the next tier. `set -euo pipefail` could not stop a partially failing run.
3. **Hardcoded tier contract**: the wrapper fixed the sources (`/`, `/home`, `/data`), destinations (`<base>/@system`, `@home`, `@data`), and snapshot layout, even though the engines accept arbitrary `--source`, `--dest`, and `--snapshots`. Anything outside that layout was unreachable through the wrapper.
4. **Two places to change**: new engine flags and safety checks had to be mirrored in the wrapper's argument parser and help text, the same drift ADR-0004 rejected for `bin/tm`.

At the same time, the wrapper was not the default path: the README, how-to guides, and tutorials already showed the three engine invocations directly, and every other operation (archive, restore, mount, prune) was a direct command.

---

## Decision Drivers

- **Single source of truth**: mount validation, preflight checks, and confirmation must live in the engine that moves the data.
- **Honest exit codes**: a failed tier must surface immediately, not be collected into a summary after the remaining tiers already ran.
- **Documentation integrity**: documented commands must exist at the documented paths and expose the flags they document.
- **Uniform command model**: every operation is a standalone script; no operation gets a private orchestrator.

---

## Considered Options

- **Option 1**: Keep `bin/backup-all.sh` and forward `-y`/preflight state into the engines so warnings are not lost.
- **Option 2**: Delete `bin/backup-all.sh` and document a full backup as the three tier engines run in sequence.
- **Option 3**: Move orchestration out of shell into a systemd unit or Makefile target.

---

## Decision Outcome

Chosen option: **Option 2: delete `bin/backup-all.sh` and run the tier engines directly.**

- `bin/backup-all.sh` is deleted. There is no combined backup command.
- A full backup is the three engines in sequence, each with its own preflight and confirmation:

  ```bash
  sudo ./bin/system-backup.sh --dest /mnt/@system --snapshots /mnt/@snapshots
  sudo ./bin/home-backup.sh   --dest /mnt/@home   --snapshots /mnt/@snapshots
  sudo ./bin/data-backup.sh   --dest /mnt/@data   --snapshots /mnt/@snapshots
  ```

- Operators who routinely run all three tiers can script the sequence themselves (shell function, alias, or systemd unit); the repository does not ship one.
- `[INV-CLI-02]` and `[INV-CLI-03]` are retired: there is no multi-tier run to scope or confirm.
- The backup disk contract is unchanged: `@system`, `@home`, `@data`, `@archive`, `@snapshots`, with optional `@media`.

### Invariants & Behavioral Boundaries

- **`[INV-CLI-02] Backup-All Default Invariant`**: Retired. No command implies "run all tiers".
- **`[INV-CLI-03] Single Confirmation Invariant`**: Retired. Confirmation is per engine run, not per multi-tier pipeline.
- **`[INV-CLI-01] Single Public Interface Invariant`**: Remains retired (ADR-0004). Engine scripts are the public commands.

Each `bin/*-backup.sh` engine is a domain contract, not a global invariant: it validates its own `--dest`/`--snapshots`, runs preflight checks, and requires its own confirmation before transferring data.

---

## Positive Consequences

- Every tier runs with its own preflight checks and its own confirmation, instead of having its confirmation piped in from a wrapper.
- A failing tier is visible immediately, instead of being collected into a summary after the remaining tiers already ran.
- Arbitrary `--source`, `--dest`, and `--snapshots` values work for all tiers, including backups to a non-`/mnt` base.
- One less script to keep in sync with engine flags; the documented commands are the only commands.

## Negative Consequences & Trade-offs

- A full backup is three commands instead of one.
  - *Mitigation*: the README, tutorial, how-to, and CLI reference show the three commands together in copy-paste order; operators can wrap them in their own alias or unit.
- Automated full-backup jobs must chain the commands and handle failures.
  - *Mitigation*: each engine exits non-zero on failure, so `cmd1 && cmd2 && cmd3` stops at the first failure.

---

## Rejected Alternatives & Negative Knowledge

### Option 1 (Keep the wrapper, forward confirmation state) — Rejected
- **Why considered**: Preserves a single-command full backup without losing preflight output.
- **Why rejected**: Requires an engine-level "already confirmed" channel (`-y` passthrough or environment flag) that weakens the per-run confirmation contract, and keeps the duplicated destination/source assumptions that block non-standard layouts.

### Option 3 (systemd unit or Makefile orchestrator) — Rejected
- **Why considered**: Declarative sequencing outside shell.
- **Why rejected**: Adds an operational surface that does not exist in the repository today, and would re-encode the same hardcoded tier layout the shell wrapper encoded. Sequencing is the operator's choice, not a shipped artifact.

---

## Links

- Amends: [ADR-0004](0004-remove-unified-cli-facade.md)
- Related: [ADR-0001](0001-unified-cli-architecture.md), [ADR-0002](0002-self-healing-mirror-reconciliation.md)
