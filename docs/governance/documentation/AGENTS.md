# AGENTS.md

Instructions for AI coding assistants working with Protocol v6.0.0.

---

## 1. Directory Mission & Invariant

This specification defines the canonical `docs-governance` protocol (Protocol v6.0.0).

- **Policy Status**: Normative governance policy.
- **AI Modification Invariant**: AI assistants may read this directory to inspect system invariants, taxonomy coordinates, and templates, but must only edit files within this directory upon explicit maintainer instruction.

---

## 2. Invariant Directives for AI Assistants

When authoring or modifying documentation in an adopting repository, always verify:

1. **Machine Invariants (`[INV-LINT-01]`, `[INV-LINT-02]`, `[INV-LINT-03]`)**:
   - Never create arbitrary Markdown files at the repository root (`[INV-LINT-01]`).
   - Never link from public documentation into `docs/dev/**` (`[INV-LINT-02]`).
   - Ensure all records in `docs/adr/` have valid YAML frontmatter with standardized status (`[INV-LINT-03]`).
2. **Context Routing & Chesterton's Fence (`[INV-AGENT-02]`)**:
   - In code generation mode, never recommend solutions from `status: superseded` or `status: rejected` records.
   - In refactoring/investigation mode, retrieve superseded/rejected records and cite their failure causes as negative constraints.
3. **Negative Knowledge Mandate (`[INV-AGENT-01]`)**:
   - Every new ADR must detail rejected alternatives and why they failed.
4. **Blameless Postmortems (`[INV-AGENT-03]`)**:
   - Focus strictly on defense-in-depth failure, detection gaps, and systemic causality. Human blame is prohibited.

---

## 3. Toolchain Verification

Before completing tasks that modify governance or documentation, run:
```bash
docgov check
```
