# Architectural Decision Records

This directory records the architectural decisions, trade-offs, and negative knowledge binding upon the Time Machine codebase.

For ADR qualification criteria (the 3-Question Test), in-place lifecycle transitions, and the authoring template, see [ADR Standards](../dev/standards/adr.md).

---

## Decision Records

| ID | Title | Status | Scope | Decision Summary & Primary Invariants | Date |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [0001](0001-unified-cli-architecture.md) | Unified CLI Architecture (`bin/tm`) | Accepted | cli/core | Establish `bin/tm` as the single authoritative public CLI entrypoint; `backup` defaults to all active tiers (System + Home + Data) with a single consolidated confirmation. `[INV-CLI-01, INV-CLI-02, INV-CLI-03]` | 2026-09-24 |
| [0002](0002-self-healing-mirror-reconciliation.md) | Self-Healing Mirror Reconciliation | Accepted | backup/core | Standardize active mirror tiers to use `--delete --delete-excluded --force` to prevent symlink and rule deadlocks; isolate historical retention in `@snapshots`; strictly prohibit destructive flags in `@archive`. `[INV-BACKUP-01, INV-BACKUP-02, INV-BACKUP-03]` | 2026-09-24 |
| [0003](0003-restore-fail-closed-safety.md) | Restore Fail-Closed Safety & Affirmation | Accepted | restore/core | Establish fail-closed snapshot abort, uppercase `YES` affirmation, and system path exclusion guardrails during disaster recovery operations. `[INV-RESTORE-01, INV-RESTORE-02, INV-RESTORE-03]` | 2026-10-31 |
