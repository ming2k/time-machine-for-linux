# Entity: Incident Postmortem

Intent: conduct blameless post-incident forensics to identify systemic defense failures, detection gaps, and binding preventative action items.

---

## 1. Non-Negotiable Invariants

- **`[INV-OPS-01]` Blameless Postmortem Structure**:
  Post-incident reviews must focus strictly on timeline reconstruction, detection gaps, and systemic engineering defenses. Attribution of human error, negligence, or blame is strictly prohibited.
- **`[INV-OPS-02]` Escalation Layering**:
  Recurring mitigation steps must be codified into operational runbooks. If the root cause requires structural code or protocol redesign, an ADR must be authored to ratify the permanent invariant change.
- **`[INV-TEMP-03]` No Direct Deletion**:
  Postmortems are archived permanently under `docs/dev/postmortems/`. They must never be deleted.

---

## 2. Directory Setup & File Naming

Postmortems live in cold storage under `docs/dev/postmortems/`:
- Format: `docs/dev/postmortems/YYYY-MM-DD-<slug>.md` (e.g., `2026-04-12-wal-corruption.md`).
- A registry index must exist at `docs/dev/postmortems/index.md`.

---

## 3. Authoritative Postmortem Template

```markdown
# Postmortem: [Incident Title]

- Date of Incident: YYYY-MM-DD
- Date Published: YYYY-MM-DD
- Severity: Sev 1 | Sev 2 | Sev 3
- Lead Investigator: [Name / GitHub handle]
- Impact Summary: [e.g., 42 minutes degraded throughput; zero permanent data loss]

---

## 1. Executive Summary

A 2-3 sentence overview of what broke, the user-visible impact, and the key fix deployed.

## 2. Incident Timeline (UTC)

Chronological reconstruction of events from trigger to recovery:
- **HH:MM** - Incident trigger or deployment occurs.
- **HH:MM** - First automated alert fires or customer report received.
- **HH:MM** - Incident response team assembles; mitigation triage begins.
- **HH:MM** - Mitigation deployed (e.g., traffic rerouted, rollback applied).
- **HH:MM** - Recovery verified; incident declared resolved.

## 3. Root Cause Analysis (The 5 Whys)

1. *Why did the service crash?* Buffer overflowed under sudden traffic spike.
2. *Why did the buffer overflow?* Backpressure signaling was disabled on worker threads.
3. *Why was backpressure disabled?* Feature flag introduced during last sprint had inverted boolean logic.
4. *Why was the inverted logic not caught in CI?* Integration tests ran with backpressure pre-mocked.
5. *Why was it pre-mocked?* Test fixture lacked end-to-end backpressure validation.

## 4. Detection & Response Gaps

- What alert should have fired earlier?
- Was operational runbook documentation accurate and immediately reachable?
- Did telemetry metrics provide sufficient diagnostic resolution?

## 5. Preventative Action Items

Every action item must have a ticket link, an assigned owner, and an explicit target date:

| Action Item | Type | Owner | Target Date | Tracking Ticket |
| :--- | :--- | :--- | :--- | :--- |
| Add E2E backpressure integration test | Prevent | @alice | 2026-05-01 | Issue #104 |
| Add high-watermark buffer alert | Detect | @bob | 2026-04-20 | Issue #105 |
| Update operational triage runbook | Mitigate | @carol | 2026-04-18 | Issue #106 |
```
