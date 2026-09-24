# Operational Knowledge Profile

Domain capability profile governing operational incident postmortems, root cause analysis, and knowledge escalation layering.

Activate this profile in `contracts.md` under `## 1. Activated Profiles`:
```markdown
- [x] `operations` (Operational knowledge: postmortems, triage runbooks)
```

---

## Escalation Layering (The Operational Escalation Ladder)

Operational knowledge flows upward through three distinct layers:

```text
┌─────────────────────────────────────────────────────────────┐
│ Layer 1: Triage Runbooks (Immediate Mitigation)             │
│ Symptoms, operational checks, restart procedures            │
└──────────────────────────────┬──────────────────────────────┘
                               │ Incident resolves
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 2: Postmortems (`postmortem.md` — Root Cause Analysis)│
│ Blameless timeline, detection gaps, preventative actions    │
└──────────────────────────────┬──────────────────────────────┘
                               │ Structural fix required
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ Layer 3: Architectural Decision Record (`docs/adr/`)        │
│ Permanent invariant change or protocol redesign             │
└─────────────────────────────────────────────────────────────┘
```

| Entity File | Surface | Scope | Temperature | Focus |
| :--- | :--- | :--- | :--- | :--- |
| [Postmortem Entity](postmortem.md) | `docs/dev/postmortems/` | Post-incident | **COLD** | Forensic root cause, detection timeline, action items |

---

## Directory Layout Bindings

When the `operations` profile is active, the repository establishes:

| Surface | Path | Required | Temperature | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| Incident Records | `docs/dev/postmortems/` | Yes | **COLD** | Archived blameless post-incident reviews |

---

## Governance Invariant Cross-Reference

- `[INV-OPS-01]`: Blameless Postmortem Structure (Systemic root causes; attribution of human error prohibited).
- `[INV-OPS-02]`: Escalation Layering (Runbook -> Postmortem -> ADR).
- `[INV-TEMP-03]`: No Direct Deletion (Postmortems are archived permanently in cold storage).
