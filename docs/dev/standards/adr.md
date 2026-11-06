# Architectural Decision Records (ADR) Standards

This document establishes the qualification criteria, lifecycle progression, frontmatter schema, and canonical template for Architectural Decision Records (ADRs).

---

## 1. Intent & Qualification (The 3-Question Test)

To prevent ADR inflation and maintain a high-signal registry, author an ADR only if a proposal meets **at least two** of these criteria:

1. **High Reversal Cost**: Would reversing this decision require multi-week refactoring or breaking operator migration paths?
2. **Cross-Boundary Blast Radius**: Does it alter storage layout, public CLI contracts, data safety guarantees, or subsystem responsibilities?
3. **Generates Binding Red-Lines**: Does it establish hard structural boundaries that developers and AI assistants must follow?

### Anti-Patterns to Reject
- **The Triviality Smear**: Authoring ADRs for routine implementation choices (e.g., tweaking an rsync buffer or renaming an internal helper).
- **The Ephemeral Workaround**: Recording temporary hotfixes, local aliases, or transient distribution quirks.
- **The Toothless Declaration**: Vague prose lacking enforceable constraints or clear behavioral boundaries.
- **The Post-Hoc Justification**: Authoring an ADR after code is merged with zero genuine consideration of discarded alternatives.

---

## 2. In-Place Lifecycle & Frontmatter Schema

ADRs evolve strictly in-place through YAML frontmatter transitions. Files are never physically moved to an `archive/` directory:

```text
       [ draft ] ───► [ accepted ] ───► [ superseded ]
           │
           └───► [ rejected ]
```

- **draft**: Proposal under active deliberation.
- **accepted**: Ratified invariant or architectural contract binding on the repository.
- **superseded**: Formally replaced by a subsequent ADR (`superseded_by: ADR-NNNN`).
- **rejected**: Discarded alternative preserved in-place for negative knowledge audit.

### Frontmatter Schema
```yaml
---
id: ADR-NNNN
title: "[Title of Decision]"
status: accepted # [draft | accepted | superseded | rejected]
date: YYYY-MM-DD
scope: [cli | backup | storage | fs | utils]
superseded_by: null # e.g., ADR-0003 (mandatory when status is superseded)
negative_knowledge: true
---
```

---

## 3. Authoritative ADR Template

```markdown
---
id: ADR-NNNN
title: "[Title of Decision]"
status: draft
date: YYYY-MM-DD
scope: [comma-separated domain/component scopes]
superseded_by: null
negative_knowledge: true
---

# NNNN. [Title of Decision]

- Status: Draft | Accepted | Superseded by [ADR-NNNN](NNNN-slug.md) | Rejected
- Date: YYYY-MM-DD
- Deciders: [Maintainer, Architecture Working Group]
- Scope: [subsystems affected]

---

## Context and Problem Statement

Describe the context and motivation in concise, precise terms. What operational bottleneck, data safety issue, or boundary violation requires resolution?

## Decision Drivers

- Driver 1: [Primary technical driver]
- Driver 2: [Operational, safety, or ergonomic requirement]

## Considered Options

- Option 1: [Alternative A]
- Option 2: [Alternative B]
- Option 3: [Alternative C]

## Decision Outcome

Chosen option: **[Option N: Name]**.

Detail the technical approach, module responsibilities, and structural changes.

### Subsystem Boundaries & Structural Changes
Explain the exact changes to scripts, directories, flags, and library contracts.

### Invariants & Behavioral Boundaries
- `[INV-XXX-01] Name`: Non-negotiable red-line backed by runtime assertions or automated tests.

### Positive Consequences
- Architectural and operational benefits.

### Negative Consequences & Trade-offs
- Incurred operational complexity and mitigation strategy.

## Rejected Alternatives & Negative Knowledge

### Option 1 ([Name]) — Rejected
- **Why considered**: Short explanation.
- **Why rejected**: Technical or operational rationale.
```
