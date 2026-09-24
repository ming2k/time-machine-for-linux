---
id: ADR-0001
title: "Unified CLI Architecture (bin/tm)"
status: accepted
date: 2026-09-24
scope: cli/core
superseded_by: null
negative_knowledge: true
---

# 0001. Unified CLI Architecture (`bin/tm`)

- Status: Accepted
- Date: 2026-09-24
- Deciders: maintainer, AI architect
- Scope: cli/core

---

## Context and Problem Statement

Historically, `time-machine-for-linux` grew organically by adding standalone shell scripts for each tier: `system-backup.sh`, `home-backup.sh`, and `data-backup.sh` in `bin/`, while hardware mount controllers (`mountctl.sh`), multi-tier wrappers (`backup-all.sh`), and maintenance tools (`prune-snapshots.sh`, `format-btrfs-luks.sh`) resided in `tools/`.

This split directory layout caused severe cognitive friction:
1. **Directory bouncing**: Users were forced to navigate between `tools/` (to mount drives and run wrappers) and `bin/` (to run tier backups and cold archives).
2. **First-class citizen inversion**: 90% of user interactions require a complete backup of all configured tiers. Treating whole-machine backup as an auxiliary "patch wrapper" in `tools/backup-all.sh` rather than the primary entrypoint inverted user expectations.
3. **Ergonomic fragmentation**: Inconsistent flag conventions, repeated confirmation prompts across multiple script invocations, and fragmented status reporting degraded operator confidence.

We need an authoritative, long-term, uncompromised command-line architecture.

---

## Decision Drivers

- **Cognitive Simplicity**: The operator should memorize exactly one executable name (`tm`), regardless of the underlying operation.
- **Sensible Defaults**: Running the primary `backup` command with zero flags must do the right thing by default: run all configured tiers (System, Home, Data) sequentially with a single confirmation.
- **Granular Control Without Fragmentation**: Selective tier execution (`--system`, `--home`, `--data`) must be sub-flags of the primary command rather than disjoint executables.
- **Maintainability & Modularity**: The unified CLI must orchestrate underlying modular scripts without creating a monolithic, unmaintainable single script.

---

## Considered Options

- **Option 1**: Monolithic script unification (fold all logic into one massive bash file).
- **Option 2**: Directory flattening (move all scripts into `bin/` and keep them separate).
- **Option 3**: Unified Git-style CLI front-controller (`bin/tm`) dispatching to modular subsystem engines.

---

## Decision Outcome

Chosen option: **Option 3: Unified Git-style CLI front-controller (`bin/tm`)**.

We establish `bin/tm` as the single authoritative public interface for the repository. All operations become subcommands:
- `tm mount <dev>` / `tm unmount`
- `tm backup` (defaults to all active tiers; flags `--system`, `--home`, `--data` allow granular scoping)
- `tm archive <source>`
- `tm prune [--keep <N>]`
- `tm restore <tier>`
- `tm status`
- `tm format <dev>`
- `tm cleanup [--tier <tier>]`

The underlying modular scripts in `bin/` and `tools/` remain as focused, independently testable subsystem engines.

---

### Invariants & Behavioral Boundaries

- **`[INV-CLI-01] Single Public Interface Invariant`**:
  All user-facing documentation, quickstarts, and workflows must treat `bin/tm` as the primary interaction model. Standalone scripts in `bin/` and `tools/` serve as internal implementation modules.
- **`[INV-CLI-02] Backup-All Default Invariant`**:
  Invoking `tm backup` without tier scoping flags MUST execute all three active tiers (System, Home, Data) sequentially. Fragmented one-tier-at-a-time execution must require explicit opt-in flags (e.g. `tm backup --data`).
- **`[INV-CLI-03] Single Confirmation Invariant`**:
  Unified multi-tier runs MUST present a consolidated execution plan and prompt the user exactly once prior to starting the pipeline.

---

### Positive Consequences

- Eliminates cognitive switching between `bin/` and `tools/`.
- Aligns with modern CLI standards (`git`, `docker`, `btrfs`, `systemctl`).
- Reduces routine maintenance to a single memorized command: `sudo bin/tm backup`.
- Simplifies shell autocompletion and global symlink installation (`/usr/local/bin/tm -> ...`).

---

### Negative Consequences & Trade-offs

- Adds a thin routing layer that must forward arguments cleanly to subsystem scripts.
  - *Mitigation*: Implemented using rigorous array expansion (`"$@"`) to preserve whitespace and quoted options.

---

## Rejected Alternatives & Negative Knowledge

### Option 1 (Monolithic Bash Amalgamation) — Rejected
- **Why considered**: Removes all inter-script calls; single self-contained file.
- **Why rejected**: Creates a 3,000+ line untestable bash monolith. Violates single-responsibility principle. Modifying exclusion parsing or snapshot logic would risk breaking mount handling and disk formatting.

### Option 2 (Directory Flattening into `bin/`) — Rejected
- **Why considered**: Avoids creating a dispatch layer while ending the `bin` vs `tools` split.
- **Why rejected**: Leaves the operator with 10+ disjoint top-level scripts in PATH. Does not solve the fundamental friction: the user still has to run 3 separate scripts sequentially or remember an unnatural wrapper script like `backup-all.sh`. Fails the ergonomic benchmark of modern CLI design.

---

## Links

- Related PR/Implementation: Unified CLI `bin/tm`
- Governing Protocol: Protocol v6.0.0 / `docs-governance`
