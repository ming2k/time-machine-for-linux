# Operational Workflows & Verification Gates (Protocol v6.0.0)

This document defines the operational lifecycle: the code-to-doc trigger matrix, pull request review gates, governance intake SOP, and zero-vendoring downstream adoption procedures.

---

## Part 1: Code-to-Documentation Trigger Matrix

Whenever a source code change is proposed, consult this matrix to determine mandatory documentation synchronization (`[INV-LINT-04]`):

| Code / System Change | Required Documentation Surface | Invariant Reference |
| :--- | :--- | :--- |
| **New public CLI flag, subcommand, or API** | `docs/reference/` + `README.md` (if primary path) | `[INV-LINT-04]` |
| **Breaking API, protocol, or ABI change** | `CHANGELOG.md` + `docs/reference/` + `docs/adr/` | `[INV-LINT-03]`, `[INV-LINT-04]` |
| **Subsystem paradigm shift / Architectural refactor** | `docs/adr/NNNN-*.md` (evaluated against 3-Question Test) | `[INV-AGENT-01]`, `[INV-AGENT-04]` |
| **Build system, test runner, or CI pipeline change** | `docs/dev/testing.md` | `[INV-LINT-04]` |
| **Contributor workflow or dev bootstrap change** | `docs/dev/setup.md` | `[INV-LINT-02]` |
| **New end-to-end user capability or journey** | `docs/dev/acceptance.md` + `docs/tutorials/` | `[INV-LINT-04]` |
| **Production outage, security incident, data loss** | `docs/dev/postmortems/YYYY-MM-DD-*.md` | `[INV-AGENT-03]` |

---

## Part 2: Pull Request Review Gates

Maintainers and AI code review agents must verify pull requests against two formal gates before merging:

### Gate A: Machine AST & Structural Gate (`INV-LINT`)
Must be verified deterministically by automated CI via `docgov check`:
- [ ] No arbitrary Markdown files are added at the repository root (`[INV-LINT-01]`).
- [ ] No user-facing document contains relative links into `docs/dev/` (`[INV-LINT-02]`).
- [ ] All records in `docs/adr/` contain valid Frontmatter with standardized status enums (`[INV-LINT-03]`).
- [ ] Monitored code modifications in `src/` have synchronized documentation updates in the same PR (`[INV-LINT-04]`).

### Gate B: Cognitive & Reasoning Gate (`INV-AGENT`)
Verified by peer reviewers and AI reasoning self-checks:
- [ ] Proposed ADRs satisfy the 3-Question Significance Test (`[INV-AGENT-04]`).
- [ ] Proposed ADRs explicitly detail rejected alternatives and failure modes (`[INV-AGENT-01]`).
- [ ] In generative mode, no deprecated or superseded patterns are introduced (`[INV-AGENT-02]`).
- [ ] Post-incident reviews maintain blameless systemic focus without personal attribution (`[INV-AGENT-03]`).

---

## Part 3: Standard Evolution Intake SOP

Proposed modifications to the `docs-governance` specification itself must pass the **Four-Tier Admission Filter**:

```text
┌─────────────────────────────────────────────────────────────┐
│ Tier 0: Core Protocol Meta-Rules (`spec/core/`)             │
│ Universal rules affecting >=95% of software repositories    │
└──────────────────────────────┬──────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ Tier 1: Pattern Catalog                                     │
│ Generalized patterns across >=3 production codebases        │
└──────────────────────────────┬──────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ Tier 2: Domain Profiles (`spec/profiles/`)                  │
│ Pluggable vertical entities (Architecture, Validation, Ops) │
└──────────────────────────────┬──────────────────────────────┘
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ Tier 3: Repository Contracts (`.docgov.yml`)                │
│ Project-specific path bindings, profiles, and custom rules  │
└─────────────────────────────────────────────────────────────┘
```

1. **Tier 0 Admission Test**: Does this invariant apply universally regardless of programming language or domain? If yes, admit to `spec/core/`.
2. **Tier 2 Admission Test**: Does this capability represent a domain vertical (e.g. Architecture, Operations)? If yes, package as a profile under `spec/profiles/`.
3. **Tier 3 Admission Test**: Is this constraint specific to one repository's path layout or business domain? If yes, define it in downstream `.docgov.yml`.

---

## Part 4: Repository Adoption Workflow (Protocol v6.0.0)

Downstream repositories adopt Protocol v6.0.0 with **zero vendoring**:

1. **Initialize Configuration**:
   Create `/.docgov.yml` at the repository root defining public surfaces, internal surfaces, and triggers.
2. **Anchor AI Directives**:
   Create `/AGENTS.md` at the repository root with concise invariant mappings (< 30 lines).
3. **Verify Locally**:
   Run verification via the zero-install CLI:
   ```bash
   npx @docs-governance/cli check
   # or
   uvx docgov check
   ```
4. **Enforce in CI**:
   Add a GitHub Actions job invoking `docgov check` on every pull request.
