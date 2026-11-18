# Architectural Decision Records

This directory records the architectural decisions, trade-offs, and negative knowledge binding upon the Time Machine codebase.

For ADR qualification criteria (the 3-Question Test), in-place lifecycle transitions, and the authoring template, see [ADR Standards](../dev/standards/adr.md).

---

## Decision Records

| ID | Title | Status | Scope | Decision Summary & Primary Invariants | Date |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [0001](0001-unified-cli-architecture.md) | Unified CLI Architecture (`bin/tm`) | Superseded by [0004](0004-remove-unified-cli-facade.md) | cli/core | Established `bin/tm` as a single public CLI entrypoint. Superseded after the router proved to be a facade without data-path or safety logic. | 2026-09-24 |
| [0002](0002-self-healing-mirror-reconciliation.md) | Self-Healing Mirror Reconciliation | Accepted | backup/core | Standardize active mirror tiers to use `--delete --delete-excluded --force` to prevent symlink and rule deadlocks; isolate historical retention in `@snapshots`; strictly prohibit destructive flags in `@archive`. `[INV-BACKUP-01, INV-BACKUP-02, INV-BACKUP-03]` | 2026-09-24 |
| [0003](0003-restore-fail-closed-safety.md) | Restore Fail-Closed Safety & Affirmation | Accepted | restore/core | Establish fail-closed snapshot abort, uppercase `YES` affirmation, and system path exclusion guardrails during disaster recovery operations. `[INV-RESTORE-01, INV-RESTORE-02, INV-RESTORE-03]` | 2026-10-31 |
| [0004](0004-remove-unified-cli-facade.md) | Remove the Unified CLI Facade (`bin/tm`) | Accepted; amended by [0005](0005-remove-backup-all-orchestrator.md) | cli/core | Remove `bin/tm`; expose backup, restore, archive, mount, and maintenance scripts directly. Retire `[INV-CLI-01]`. The `bin/backup-all.sh` promotion and `[INV-CLI-02, INV-CLI-03]` were later retired by ADR-0005. | 2026-11-15 |
| [0005](0005-remove-backup-all-orchestrator.md) | Remove the `backup-all.sh` Orchestrator | Accepted | cli/core | Delete `bin/backup-all.sh`; a full backup is the three tier engines run in sequence, each with its own preflight and confirmation. Retire `[INV-CLI-02, INV-CLI-03]`. | 2026-11-18 |
