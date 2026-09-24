# System Invariants Constitution (Protocol v6.0.0)

This document codifies the non-negotiable architectural and documentation invariants across software repositories adopting the `docs-governance` standard.

Every invariant carries a unique, citeable canonical identifier partitioned into two operational tiers:
- **`[INV-LINT-*]`**: Deterministic Machine Layer, verified by automated AST linters and CI in `< 50ms`.
- **`[INV-AGENT-*]`**: Cognitive & Agent Protocol Layer, governing LLM attention routing, negative knowledge, and architectural reasoning.

---

## 1. Deterministic Machine Layer (`INV-LINT`)

Enforced deterministically by compiler/AST engines (e.g. `docgov` CLI). Violations cause instant CI/PR failure.

- **`[INV-LINT-01]` Location Sanitization (Root Whitelist)**:
  Arbitrary Markdown files are prohibited at the repository root. Only explicitly whitelisted entries (`README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `AGENTS.md`, `LICENSE.md`, `SECURITY.md`) may reside at the root level. All other documentation must route through `docs/`.
- **`[INV-LINT-02]` Contributor Firewall Rule**:
  Public user-facing documentation (`docs/tutorials/`, `docs/how-to/`, `docs/reference/`, `docs/explanation/`) must never contain relative Markdown links pointing into internal contributor spaces (`docs/dev/**`). Contributor documentation may link outward into public documentation.
- **`[INV-LINT-03]` Frontmatter Schema & Lifecycle Integrity**:
  Every record in `docs/adr/` must declare valid YAML Frontmatter containing mandatory fields (`id`, `title`, `status`, `date`). The `status` field must be an enum member of `[draft, accepted, superseded, rejected]`. Records marked `superseded` must supply a valid `superseded_by` pointer.
- **`[INV-LINT-04]` Code-Doc Synchronization Trigger**:
  Any Pull Request modifying monitored source code surfaces (e.g. `src/api/**`, `src/cli/**`) must synchronize corresponding documentation surfaces in the same change, as verified by Git diff analysis.

---

## 2. Cognitive & Agent Protocol Layer (`INV-AGENT`)

Enforced by AI agent system directives (`AGENTS.md`), reasoning chains, and human architectural peer reviews.

- **`[INV-AGENT-01]` Negative Knowledge Mandate**:
  Every Architectural Decision Record (ADR) must contain a dedicated "Rejected Alternatives & Negative Knowledge" section detailing which alternatives were considered and why they failed. Decisions without explicit failure modes must be rejected.
- **`[INV-AGENT-02]` Context Routing & Chesterton's Fence**:
  - *Generative Isolation*: When generating code or proposing new implementations, AI agents and prompt loaders must filter out documents with `status: superseded` or `status: rejected` to prevent resurrecting dead architectural patterns.
  - *Archeological Retrieval*: When prompted for refactoring, historical rationale, or root-cause investigation, AI agents must actively retrieve superseded/rejected records and cite their documented failure modes as negative constraints.
- **`[INV-AGENT-03]` Blameless Postmortem Structure**:
  Post-incident reviews in `docs/dev/postmortems/` must strictly focus on timeline reconstruction, detection gaps, and systemic defense-in-depth failures. Attribution of personal human error or developer blame is strictly prohibited.
- **`[INV-AGENT-04]` Architectural Significance Threshold**:
  An ADR must only be authored for decisions satisfying at least two criteria of the 3-Question Significance Test (high reversal cost, cross-boundary blast radius, or generating binding invariants). Trivial implementation details, localized function refactorings, or ephemeral workarounds must never be admitted to `docs/adr/`.
