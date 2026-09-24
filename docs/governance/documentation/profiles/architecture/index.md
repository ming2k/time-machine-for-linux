# Architecture Governance Profile

Domain capability profile governing architectural decision lifecycles, living system blueprints, and pre-decision proposals.

Activate this profile in `contracts.md` under `## 1. Activated Profiles`:
```markdown
- [x] `architecture` (Architecture decision records: ADR lifecycle, blueprints, RFCs)
```

---

## The Three Architecture Entities

This profile provides three tightly coupled vertical entities:

```text
┌──────────────────────────────┐
│ In-Flight RFC (`rfc.md`)     │  Pre-Decision Deliberation (WARM)
│ Exploration, feedback, debate│  Location: `docs/rfc/RFC-NNNN-*.md`
└──────────────┬───────────────┘
               │ Reaches consensus
               ▼
┌──────────────────────────────┐
│ Ratified ADR (`adr.md`)      │  Immutable Decision Covenant (WARM)
│ Decision, trade-offs, rules  │  Location: `docs/adr/NNNN-*.md`
└──────────────┬───────────────┘
               │ Compaction cycle
               ▼
┌──────────────────────────────┐
│ Living Snapshot (`living-    │  Current System Truth (HOT)
│ snapshot.md`)                │  Location: `docs/architecture/*.md`
└──────────────────────────────┘
```

| Entity File | Purpose | Document Surface | Temperature Tier |
| :--- | :--- | :--- | :--- |
| [ADR Entity](adr.md) | Immutable decision records and negative knowledge | `docs/adr/` | **WARM** (Cold when archived) |
| [RFC Entity](rfc.md) | Optional pre-decision debate and alternatives exploration | `docs/rfc/` | **WARM** (Cold when archived) |
| [Living Snapshot Entity](living-snapshot.md) | Authoritative current system blueprints & ADR compaction | `docs/architecture/` | **HOT** |

---

## Directory Layout Bindings

When the `architecture` profile is active, the repository establishes:

| Surface | Path | Required | Temperature | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| Active ADRs | `docs/adr/` | Yes | **WARM** | Active architectural decision records |
| Archived ADRs | `docs/adr/archive/` | Yes | **COLD** | Compacted, superseded, and deprecated records |
| Living Architecture | `docs/architecture/` | Yes | **HOT** | Current subsystem state blueprints and invariants |
| In-Flight RFCs | `docs/rfc/` | Optional | **WARM** | Active multi-stakeholder proposals |
| Archived RFCs | `docs/rfc/archive/` | Optional | **COLD** | Concluded and withdrawn proposals |

---

## Governance Invariant Cross-Reference

- `[INV-ARCH-01]`: ADR Immutability Contract.
- `[INV-ARCH-02]`: Negative Knowledge Requirement.
- `[INV-ARCH-03]`: RFC Misuse Isolation (No raw RFCs in AI context).
- `[INV-ARCH-04]`: RFC Terminal Closure Mandate (Distill or withdraw).
- `[INV-ARCH-05]`: Snapshot Compaction Integrity.
- `[INV-ARCH-06]`: Architectural Significance Threshold (Anti-triviality firewall).
- `[INV-TEMP-02]`: Archival Firewall (AI agents default-exclude `**/archive/**`).
