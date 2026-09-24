# Entity: Request for Comments (RFC)

Intent: provide an optional, structured space for pre-decision debate, stakeholder feedback, and exploration of alternatives *before* committing to a durable architectural contract.

---

## 1. Non-Negotiable Invariants

- **The Golden Rule**: **An unused or omitted RFC workflow is harmless; a misused RFC workflow is toxic.**
  - If adopted, every proposal must be shepherded to a terminal state (`Consensus Reached` or `Withdrawn`).
  - If a project is maintained by a single engineer or small pair, **do not introduce RFCs**; write ADRs directly.
- **`[INV-ARCH-03]` AI Misuse Isolation**:
  Unresolved RFC debates (`docs/rfc/`) must never be loaded into AI coding assistants as architectural truth. Speculative designs must not pollute code generation.
- **`[INV-ARCH-04]` Terminal Closure Mandate**:
  RFCs are ephemeral. An RFC must reach consensus (and distill into an ADR) or be decisively withdrawn to `docs/rfc/archive/`. Lingering zombie RFCs are prohibited.
- **`[INV-TEMP-02]` Archival Firewall**:
  AI coding tools must default-exclude `docs/rfc/archive/**` from daily prompt contexts and search indices.

---

## 2. When to Use vs. When to Skip

| Scenario | Action | Rationale |
| :--- | :--- | :--- |
| Single-developer or small-team repo | **Skip RFC** | Overhead exceeds collaborative benefit. Author ADRs directly. |
| Local refactoring or minor feature | **Skip RFC** | Operates inside existing boundaries; PR discussion suffices. |
| Incremental architecture adjustment | **Skip RFC** | Propose directly via an ADR in `Proposed` state. |
| Cross-subsystem paradigm shift | **Use RFC** | Multiple stakeholders, trade-offs, and broad blast radius. |
| Breaking public API redesign | **Use RFC** | External consumer feedback and migration planning required. |

---

## 3. Deliberation Lifecycle & Archival SOP

```text
[ Draft ] ──► [ Under Review ] ──► [ Consensus Reached ] ──► Distill into ADR (docs/adr/)
                     │                                       │
                     │                                       ▼
                     └─────────────────────────────► [ Withdrawn ] ──► Move to docs/rfc/archive/
```

### The 4-Step Archival SOP
When an RFC reaches a terminal conclusion, it must not remain at the top level of `docs/rfc/`:
1. **Step 1: Terminate**: Set Status to `Consensus Reached` or `Withdrawn`.
2. **Step 2: Formalize**:
   - If consensus reached: Author the binding ADR under `docs/adr/NNNN-<slug>.md` and link it under `Target ADR`.
   - If withdrawn: Record `Withdrawn Reason` documenting why the design was abandoned.
3. **Step 3: Relocate**:
   ```bash
   mv docs/rfc/RFC-NNNN-<slug>.md docs/rfc/archive/RFC-NNNN-<slug>.md
   ```
4. **Step 4: Re-Index**: Update `docs/rfc/index.md` pointing to the archived file.

---

## 4. Authoritative RFC Template

```markdown
# RFC-NNNN: [Title of Proposal]

- Status: Draft | Under Review | Consensus Reached | Withdrawn
- Author: [Name / GitHub handle]
- Created: YYYY-MM-DD
- Last Updated: YYYY-MM-DD
- Target ADR: [docs/adr/NNNN-slug.md once distilled, or None]
- Discussion: [Link to PR / Issue / Discussion thread]

---

> **Notice**: This RFC is a pre-decision deliberation document. It explores possibilities
> and solicits stakeholder feedback. **It does not represent binding architectural policy.**
> For authoritative constraints, consult accepted records in `docs/adr/`.

---

## 1. Summary

A brief 2-3 sentence executive pitch explaining what is being proposed and why.

## 2. Motivation & Problem Statement

- What specific pain point or limitation are we solving?
- Why are existing mechanisms or architectural patterns insufficient?
- What happens if we do nothing?

## 3. Proposed Design

Detailed description of the proposed solution:
- Conceptual model, workflow, and component boundaries.
- Proposed public APIs, configuration structures, or protocols.
- Interaction with existing subsystems.

## 4. Drawbacks & Trade-offs

- Why should we **NOT** adopt this proposal?
- What new cognitive load, runtime overhead, or operational complexity does this introduce?
- Are there migration costs or compatibility breaks?

## 5. Alternatives Considered

Describe alternative designs that were evaluated:
- **Alternative A**: Brief description, pros, and why it was not favored.
- **Alternative B**: Brief description, pros, and why it was not favored.

## 6. Unresolved Questions

Explicit list of open issues that require stakeholder consensus during review:
- [ ] Question 1: e.g., How should we handle backward-compatibility during transition?
- [ ] Question 2: e.g., What are the memory limits for the new buffer pool?

## 7. Resolution & Next Steps

*(To be filled when deliberation concludes)*
- **Consensus Outcome**: Summary of agreed direction.
- **Resulting ADR**: Distill binding constraints into `docs/adr/NNNN-<slug>.md`.
- **Implementation PRs**: Track code execution once the ADR is accepted.
```
