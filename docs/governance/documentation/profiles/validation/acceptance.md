# Entity: Acceptance Criteria & User Journeys

Intent: verify that the software delivers intended end-to-end user outcomes through rigorous, real-world user journeys and acceptance scenario matrices.

---

## 1. Non-Negotiable Invariants

- **`[INV-VAL-01]` Real User Journey Parity**:
  Acceptance journeys must exercise the system strictly through real user interfaces, public CLI commands, or documented public APIs from a cold start, without invoking private test harness backdoors.
- **`[INV-TEMP-01]` Hot Data Synchronization**:
  Whenever a user-visible feature is added, changed, or removed, `docs/dev/acceptance.md` must be updated in the same Pull Request.
- **`[INV-CORE-01]` Contributor Firewall**:
  `docs/dev/acceptance.md` lives behind the contributor firewall (`docs/dev/`). User-facing guides must never link directly into it.

---

## 2. Document Structure Requirements

Every `docs/dev/acceptance.md` document must provide two core sections:
1. **Core User Journeys**: Step-by-step narrative operations executing the primary workflows from a cold start.
2. **Acceptance Scenario Matrix**: Tabular verification matrix covering happy paths, edge cases, error recovery, and security constraints.

---

## 3. Authoritative Acceptance Template (`docs/dev/acceptance.md`)

```markdown
# Acceptance Criteria & User Journeys

This document defines the real-world user journeys, acceptance scenario matrices, and deliverable criteria for this repository.

---

## 1. Core User Journeys

### Journey 1: Primary Onboarding & Quick Start
1. **Initial State**: Clean machine with prerequisites installed; no repository caches.
2. **Action**: Run the primary setup or installation command:
   ```bash
   ./setup.sh
   ```
3. **Verification**: Command exits with code 0; outputs expected welcome confirmation.
4. **Outcome**: User is ready to perform primary tasks.

### Journey 2: Standard Daily Workflow
1. **Initial State**: Operational local environment.
2. **Action**: Execute core system operation:
   ```bash
   ./bin/tool run --input sample.dat
   ```
3. **Verification**: System produces output artifact matching expected schema within latency SLA.

---

## 2. Acceptance Scenario Matrix

| Scenario ID | Category | Initial Condition | Action / Trigger | Expected Observable Outcome |
| :--- | :--- | :--- | :--- | :--- |
| `SCEN-01` | Happy Path | Default configuration | Execute standard workflow | Exit 0; artifact generated |
| `SCEN-02` | Edge Case | Input size exceeds buffer | Execute with `--oversized` flag | Clean graceful error; no panic |
| `SCEN-03` | Error Recovery | Network disconnected | Trigger remote sync | Retries 3 times; exits with code 2 |
| `SCEN-04` | Security | Unauthorized API token | Send authenticated request | Returns HTTP 401; logs security event |

---

## 3. Verification Checklist

Before tagging a release, verify:
- [ ] Every journey in Section 1 runs to completion from a cold start.
- [ ] Every scenario in Section 2 passes verification.
- [ ] No private developer test backdoors are required to achieve acceptance.
```
