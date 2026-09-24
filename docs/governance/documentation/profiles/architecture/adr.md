# Entity: Architectural Decision Record (ADR)

Intent: record a durable architectural decision and its historical context for the lifetime of the project.

---

## 1. Non-Negotiable Invariants

- **`[INV-LINT-03]` Frontmatter & Lifecycle Integrity**: Every ADR must declare standardized Frontmatter metadata (`id`, `title`, `status`, `date`). Retired or superseded records transition in-place without physical file relocation.
- **`[INV-AGENT-01]` Negative Knowledge**: Every ADR must explicitly record rejected alternatives and why they failed to prevent future human contributors and AI assistants from attempting discarded approaches.
- **`[INV-AGENT-02]` Context Routing & Chesterton's Fence**: Superseded and rejected records serve as negative knowledge constraints during refactoring and root-cause analysis, but are excluded during routine generative tasks.
- **`[INV-AGENT-04]` Significance Threshold**: Trivial implementation details, localized function refactorings, or temporary workarounds must never be recorded in `docs/adr/`. An ADR must satisfy the 3-Question Significance Test.

---

## 2. Admission Filter: What Qualifies as an ADR (The 3-Question Test)

To prevent **ADR Inflation** and keep the architecture log high-signal, a proposal must satisfy **at least two** of the following three criteria:

```text
       ┌─────────────────────────────────────────────────────────────┐
       │ 1. High Reversal Cost?                                      │
       │ Would reversing this decision require multi-week refactoring│
       │ or breaking downstream migrations?                          │
       └──────────────────────────────┬──────────────────────────────┘
                                      │
       ┌──────────────────────────────┼──────────────────────────────┐
       │ 2. Cross-Boundary Blast Radius?                             │
       │ Does it alter subsystem boundaries, public API protocols,   │
       │ storage layouts, or non-functional SLAs (latency, security)?│
       └──────────────────────────────┬──────────────────────────────┘
                                      │
       ┌──────────────────────────────┴──────────────────────────────┐
       │ 3. Generates Binding Invariants?                            │
       │ Does it establish hard behavioral red-lines that human devs │
       │ and AI coding assistants must unconditionally obey?         │
       └─────────────────────────────────────────────────────────────┘
```

If a decision does not meet this threshold, **do not write an ADR**. Route it to a Pull Request description, a code comment, or an issue thread.

---

## 3. Anti-Patterns: Bad ADRs to Reject

Maintainers and AI review gates must reject proposals exhibiting these anti-patterns:

| Anti-Pattern | Symptom | Correct Alternative |
| :--- | :--- | :--- |
| **The Triviality Smear** | Authoring ADRs for routine choices (e.g., choosing a JSON serializer or renaming an internal module). | Document rationale in the Git commit message or PR description. |
| **The Ephemeral Workaround** | Recording temporary bug fixes, transient feature flags, or environment hacks. | Use inline code comments (`// TODO: ...`) and tracking issues. |
| **The Toothless Declaration** | An ADR written as vague prose without explicit, testable `Invariants & Behavioral Boundaries`. | Reject or revise to extract enforceable constraints. |
| **The Post-Hoc Justification** | Writing an ADR after code is already merged with zero genuine consideration of alternatives. | Reject. If no real options existed, it was an implementation detail, not a decision. |
| **The Style Guide Masquerade** | Recording formatting rules, naming conventions, or lint preferences. | Add to linter configuration or `.docgov.yml`. |

---

## 4. ADR Lifecycle State Machine (In-Place Evolution)

ADRs evolve in-place via Frontmatter status transitions. Records are never deleted or physically moved into an archive subfolder:

```text
       [ Proposed ] ───► [ Accepted ] ───► [ Deprecated ]
             │                  │
             │                  └───► [ Superseded by ADR-NNNN ]
             ▼
       [ Rejected ]
```

- **Proposed**: Open for stakeholder review and feedback (`status: draft`).
- **Accepted**: Ratified and binding on the repository (`status: accepted`).
- **Rejected**: Evaluated but not adopted. Retained in-place for negative knowledge audit (`status: rejected`).
- **Deprecated**: Functionality removed without direct replacement (`status: deprecated`).
- **Superseded**: Formally replaced by a subsequent accepted ADR (`status: superseded`, with `superseded_by: ADR-NNNN`).

---

## 5. Directory Setup & Registry

Create `docs/adr/` with an index before recording decisions:
- `docs/adr/index.md` — The registry table of all decisions.
- `docs/adr/NNNN-<slug>.md` — Individual records numbered as zero-padded integers (e.g., `0001-modular-governance.md`).

### Registry Index Pattern (`docs/adr/index.md`)

To allow human engineers and AI coding assistants to quickly locate architectural decisions and assess constraints without loading complete ADR files into context, `docs/adr/index.md` must provide a concise decision summary and primary invariant for every entry:

```markdown
# Architecture Decision Records

| ID | Title | Status | Scope | Decision Summary & Primary Invariant | Date |
| :--- | :--- | :--- | :--- | :--- | :--- |
| [0001](0001-setup.md) | Modular Architecture | Accepted | core | Adopt hexagonal architecture with decoupled adapter layers | 2026-01-10 |
| [0002](0002-wal.md) | In-Memory WAL | Superseded | storage | Shared-memory append log; superseded by ClickHouse engine in ADR-0024 | 2026-02-15 |
```

#### Index Summary Guidelines
- **Conciseness**: Keep each summary to 1–2 factual sentences (around 20–50 words).
- **Substantive Outcome**: State the chosen option, key trade-off, or binding invariant; avoid meaningless tautologies.
- **Fast AI Routing**: The summary serves as an authoritative filter so agents can determine whether an ADR applies before fetching the full text.

---

## 6. Authoritative ADR Template

```markdown
---
id: ADR-NNNN
title: "[Title of Decision]"
status: draft # [draft | accepted | superseded | rejected | deprecated]
date: YYYY-MM-DD
scope: [e.g., core/network, storage/wal, cli]
superseded_by: null # e.g., ADR-0042
negative_knowledge: true
---

# NNNN. [Title of Decision]

- Status: Draft | Accepted | Rejected | Deprecated | Superseded by [ADR-NNNN](NNNN-slug.md)
- Date: YYYY-MM-DD
- Deciders: [Names / GitHub handles]
- Consulted: [Names / GitHub handles]
- Informed: [Names / GitHub handles]

---

## Context and Problem Statement

Describe the context and problem statement in a few sentences. What problem are we solving, and why does it matter now?

## Decision Drivers

- Driver 1: e.g., Modularity, performance, maintainability
- Driver 2: e.g., Backward compatibility with existing ecosystem

## Considered Options

- Option 1: Title of option 1
- Option 2: Title of option 2
- Option 3: Title of option 3

## Decision Outcome

Chosen option: "[Option 1]", because [detailed justification].

### Invariants & Behavioral Boundaries

List the non-negotiable architectural rules resulting from this decision:
- Invariant 1: Mandatory behavioral constraint for human contributors and AI coding assistants.
- Invariant 2: Permitted or prohibited cross-boundary dependencies.

### Positive Consequences

- Positive consequence 1
- Positive consequence 2

### Negative Consequences & Trade-offs

- Negative consequence 1 (trade-off)
- Mitigation strategy

## Rejected Alternatives & Negative Knowledge

Detail why alternative options were discarded:

### Option 2 (Rejected)
- Why considered: [e.g., Lower initial implementation cost]
- Why rejected: [e.g., Introduced unbounded memory growth under backpressure]

### Option 3 (Rejected)
- Why considered: [e.g., Simpler concurrency model]
- Why rejected: [e.g., Incompatible with required latency SLA]

## Links

- Related PRs or issues: [Link]
- Related ADRs: [Link]
```
