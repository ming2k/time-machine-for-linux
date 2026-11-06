# Invariant & Constraint Governance

This document codifies the definition, categorization, and lifecycle of invariants. It establishes a policy against pseudo-invariant tag proliferation, ensuring that invariants remain high-value architectural anchors rather than ceremonial comments.

---

## 1. Core Principle: Mechanisms Over Exhortations

In software engineering, an invariant is a condition that must unconditionally hold across all valid states of a system. Historically, projects suffer from "invariant inflation" when mundane UI styles, layout heuristics, or ephemeral flags are labeled as invariants without verification mechanics.

**The Golden Rule**:
> **If a rule has neither a runtime enforcement mechanism nor an automated test assertion, it is NOT an invariant — it is merely an aspiration.**

---

## 2. Constraint Admissibility Matrix

Every architectural and operational rule maps deterministically into one of four categories:

| Category | Definition & Scope | Identifier Policy | Mandatory Enforcement Mechanism |
| :--- | :--- | :--- | :--- |
| **System Invariant** | Non-negotiable structural red-lines with cross-boundary blast radius (e.g., storage safety, CLI unification, mirror reconciliation). Max ~15 total across the repository. | Formally ratified in ADRs (`[INV-CLI-*]`, `[INV-BACKUP-*]`) | 1. Script architecture boundaries<br>2. Preflight safety assertions<br>3. Dedicated regression test suite (`tests/unit/`, `tests/integration/`) |
| **Domain Contract** | State-machine transitions and behavioral rules within a single module or subsystem (e.g. exit code propagation, loader discovery order). | **NO global `INV-` tag**.<br>Expressed as named functions and contracts. | 1. Return code checks<br>2. Parameter validation functions (`lib/utils/validation.sh`)<br>3. Unit tests |
| **Design Specification** | Terminal visual styling, colors, banner layout, prompt text formatting. | **NO `INV-` tag**.<br>Expressed as design constants. | 1. Color constants (`lib/core/colors.sh`)<br>2. Display formatters (`lib/backup/backup-display.sh`) |
| **Implementation Note** | Localized shell traps, temporary variable cleanups, tool workarounds. | **NO `INV-` tag**.<br>Standard code comments. | Direct regression unit test |

---

## 3. The 3-Condition Gate for System Invariants

A rule may be elevated to a **System Invariant** if and only if it satisfies all three criteria:

1. **High Blast Radius**: Violation results in data corruption, accidental file deletion, broken recovery paths, or tool inversion.
2. **Durable Architecture**: It represents a foundational pillar that will not become obsolete due to routine flag additions or internal refactoring.
3. **Mechanically Enforced**: It specifies an automated enforcement mechanism (preflight verification gate, runtime assertion, or automated test).

---

## 4. Current System Invariants

The repository currently ratifies the following system invariants:

### CLI Interface Subsystem (ADR-0001)
- **`[INV-CLI-01] Single Public Interface Invariant`**: All user-facing documentation and workflows must treat `bin/tm` as the primary interaction model. Standalone scripts in `bin/` and `tools/` serve as internal execution engines.
- **`[INV-CLI-02] Backup-All Default Invariant`**: Invoking `tm backup` without tier scoping flags MUST execute all three active tiers (System, Home, Data) sequentially.
- **`[INV-CLI-03] Single Confirmation Invariant`**: Multi-tier backup runs MUST present a consolidated execution plan and prompt the user exactly once prior to starting the pipeline.

### Backup & Storage Subsystem (ADR-0002)
- **`[INV-BACKUP-01] Mirror Fidelity Invariant`**: The active backup destination subvolumes (`@system`, `@home`, `@data`) must be exact point-in-time reflections of source state governed by active ignore rules (`--delete --delete-excluded --force`).
- **`[INV-BACKUP-02] Snapshot Shield Invariant`**: Destructive pruning on live mirror subvolumes is permissible because and only because immutable BTRFS snapshots in `@snapshots` permanently protect historical data.
- **`[INV-BACKUP-03] Cold Archive Prohibition Invariant`**: Destructive flags (`--delete`, `--delete-excluded`, `--force`) are **STRICTLY FORBIDDEN** in `bin/archive-sync.sh`. The cold storage tier (`@archive`) is strictly Append-Only.

### Restore & Disaster Recovery Subsystem (ADR-0003)
- **`[INV-RESTORE-01] Fail-Closed Snapshot Invariant`**: In non-dry-run mode, when pre-restore snapshot creation is enabled, any snapshot failure MUST immediately terminate the restore pipeline with a non-zero exit code. Proceeding past snapshot failure is strictly prohibited unless explicitly bypassed via `--no-snapshot`.
- **`[INV-RESTORE-02] Explicit Affirmation Invariant`**: Destructive restore confirmation MUST require exact case-sensitive affirmation (`YES`), rejecting all default presses, empty returns, or lowercase affirmative tokens (`y`, `yes`).
- **`[INV-RESTORE-03] Target Boundary Protection Invariant`**: Restore operations MUST reject source/destination identity (`source == dest`), prohibit destination paths targeting protected backup tiers (`@archive`, `@snapshots`), and automatically exclude kernel pseudo-filesystems and mountpoint roots (`/proc/*`, `/sys/*`, `/dev/*`, `/run/*`, `/tmp/*`, `/mnt/*`, `/media/*`, `/lost+found`) when restoring system files.

---

## 5. Degazetting & Retirement Policy

1. **Pseudo-Invariants**: All non-structural rules labeled with pseudo-tags are formally degazetted and converted into standard code comments or constants.
2. **True Invariants**: When an architectural invariant evolves, it follows the in-place lifecycle via ADR (`superseded_by: ADR-NNNN`), retaining negative knowledge for retrospective auditing.
