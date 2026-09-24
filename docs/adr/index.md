# Architecture Decision Records

| ID | Title | Status | Scope | Decision Summary & Primary Invariant | Date |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [0001](0001-unified-cli-architecture.md) | Unified CLI Architecture (`bin/tm`) | Accepted | cli/core | Establish `bin/tm` as the single authoritative CLI entrypoint; `backup` defaults to all active tiers. | 2026-09-24 |
| [0002](0002-self-healing-mirror-reconciliation.md) | Self-Healing Mirror Reconciliation | Accepted | backup/core | Adopt `--delete-excluded` and `--force` for active mirror tiers; isolate immutable history in `@snapshots`. | 2026-09-24 |
