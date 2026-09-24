# Product Validation Profile

Domain capability profile governing the dual-tier product validation standard for software engineering repositories.

Activate this profile in `contracts.md` under `## 1. Activated Profiles`:
```markdown
- [x] `validation` (Product validation: acceptance journeys, testing guides)
```

---

## The Dual-Tier Validation Model

Software correctness is verified on two complementary tiers:

```text
┌─────────────────────────────────────────────────────────────┐
│ Tier 1: Acceptance (`acceptance.md`)                       │
│ User Journey Verification & Scenario Matrices               │
│ Question: "Does the system deliver what the user needs?"    │
└──────────────────────────────┬──────────────────────────────┘
                               │ Backed by
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ Tier 2: Implementation Testing (`testing.md`)               │
│ Programmatic Test Suites, CLI Commands, Unit/E2E Coverage   │
│ Question: "Is the implementation mechanically correct?"     │
└─────────────────────────────────────────────────────────────┘
```

| Entity File | Surface | Scope | Focus |
| :--- | :--- | :--- | :--- |
| [Acceptance Entity](acceptance.md) | `docs/dev/acceptance.md` | Outer loop | End-to-end user journeys, acceptance scenario matrices |
| [Testing Entity](testing.md) | `docs/dev/testing.md` | Inner loop | Automated test runner commands, unit/integration suites |

---

## Directory Layout Bindings

When the `validation` profile is active, the repository establishes:

| Surface | Path | Required | Temperature | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| Acceptance Guide | `docs/dev/acceptance.md` | Yes | **HOT** | Real user journey acceptance matrices |
| Testing Guide | `docs/dev/testing.md` | Yes | **HOT** | Automated test commands and suite catalog |

---

## Governance Invariant Cross-Reference

- `[INV-VAL-01]`: Real User Journey Parity (No synthetic backdoors; cold start verification).
- `[INV-VAL-02]`: Deterministic Test Reproducibility (All commands runnable deterministically).
- `[INV-TEMP-01]`: Hot Data Synchronization (Updated in same PR as capability changes).
