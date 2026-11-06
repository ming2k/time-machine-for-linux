# Time Machine Engineering Standards

This directory defines the authoritative engineering, architectural, and quality standards for the `time-machine-for-linux` project.

Rather than adopting external meta-frameworks or creating disconnected governance silos, the project maintains a **flat, high-cohesion, practical, and code-aligned standards suite directly inside `docs/dev/standards/`**.

---

## Standards Directory Structure

All engineering standards reside flatly in `docs/dev/standards/`:

| Document | Purpose & Authority |
| :--- | :--- |
| **[`invariants.md`](invariants.md)** | **Invariant Standards & Admissibility**: Codifies true system invariants (mechanisms over exhortations), establishes the classification matrix, and degazettes pseudo-tags. |
| **[`adr.md`](adr.md)** | **Architectural Decision Records**: The 3-Question Test for ADR qualification, in-place lifecycle (`draft`, `accepted`, `superseded`, `rejected`), frontmatter schema, and template. |
| **[`taxonomy.md`](taxonomy.md)** | **Documentation Taxonomy**: Four-quadrant Diátaxis layout, audience boundaries (public user vs contributor internal), and knowledge lifecycle. |
| **[`style.md`](style.md)** | **Documentation & Markdown Style**: Canonical hyperlink conventions, relative routing, formatting consistency, and prose guidelines. |

For subsystem topology, crate/directory architecture, and testing guides, see:
- Subsystem Blueprint: [`docs/dev/subsystems.md`](../subsystems.md)
- Testing Strategy: [`docs/dev/testing.md`](../testing.md)

---

## Core Governance Philosophy

1. **Mechanisms Over Exhortations**:
   Rules and system boundaries must be enforced by concrete mechanisms: Bash strict modes (`set -euo pipefail`), automated preflight assertions, confirmation gates, safety snapshot creation, or deterministic automated tests. Natural-language "swearing" in comments is forbidden.
2. **Anti-Inflation**:
   A sharp line separates **System Invariants** (non-negotiable structural red-lines with high blast radius), **Domain Contracts** (internal shell state and function contracts), **Design Specifications** (color palettes, banner formatting), and **Implementation Notes**.
3. **Flat & Pragmatic**:
   Zero arbitrary nesting or nested "core" junk drawers. Every governance document directly addresses an active engineering concern in Time Machine.
4. **Self-Contained Epistemic Lineage**:
   All architectural decisions and references must resolve directly within `docs/adr/` (ADR-0001 through current). Phantom references to external or uncommitted decision records are strictly prohibited.
