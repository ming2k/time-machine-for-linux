# Spatial Taxonomy: The 4D Coordinate Tensor (Protocol v6.0.0)

Every documentation surface in an adopting repository maps deterministically to a unique coordinate in a **4-Dimensional Space Tensor**:

$$\text{Coordinate} = (\text{Temperature}, \text{Lifecycle}, \text{Audience}, \text{Cognitive Mode})$$

---

## Dimension 1: Temperature Tier (Retrieval & Maintenance Cadence)

Dictates update frequency, synchronization urgency, and AI agent context loading priorities:

| Tier | Characteristics | Maintenance Cadence | AI Context Protocol |
| :--- | :--- | :--- | :--- |
| **HOT** | Current ground truth; living state. | Continuous; updated in same change as code. | Primary context window for daily coding & generation. |
| **WARM** | Active architectural contracts & living ADRs. | Transactional upon decision (`status: accepted`). | Consulted just-in-time during architecture review. |
| **COLD** | Historical rationale & superseded decisions. | Retained in-place with `status: superseded` / `rejected`. | **Conditional Retrieval**: Excluded from generative mode (`[INV-AGENT-02]`); activated during refactoring & root-cause forensics. |

---

## Dimension 2: Lifecycle State (In-Place Frontmatter Progression)

Tracks the formal maturation stage of engineering knowledge without physical file movement:

```text
┌─────────────────┐       ┌─────────────────┐       ┌─────────────────┐
│  Draft / RFC    │  ──►  │    Accepted     │  ──►  │   Superseded    │
│ (In-Flight)     │       │ (Active Ground) │       │ (Negative Know) │
└─────────────────┘       └─────────────────┘       └─────────────────┘
         │                                                   ▲
         └───────────────────────────────────────────────────┘
                           (Direct Rejection)
```

- **Draft**: In-flight proposal under active deliberation.
- **Accepted**: Ratified architectural invariant binding on the repository.
- **Superseded / Deprecated**: Retired decision replaced by a newer standard. Retained in-place with Frontmatter pointer (`superseded_by: ADR-NNNN`).
- **Rejected**: Evaluated and discarded alternative preserved in-place for negative knowledge forensics.

---

## Dimension 3: Audience Firewall (Access & Intent Boundary)

Enforces strict isolation between external consumers and internal contributors:

```text
┌─────────────────────────────────────────────────────────────┐
│ Public Surface (External Users & Integrators)              │
│ `docs/tutorials/`, `how-to/`, `reference/`, `explanation/`  │
└──────────────────────────────┬──────────────────────────────┘
                               │ [INV-LINT-02] Contributor Firewall:
                               │ Public NEVER links into Internal
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ Internal Surface (Maintainers & Core Contributors)          │
│ `docs/dev/` (setup, testing, postmortems)                   │
└─────────────────────────────────────────────────────────────┘
```

- **Public Surface (Flat Diátaxis)**: Learning, task execution, technical reference, and architectural explanation for system consumers.
- **Internal Surface (`docs/dev/`)**: Firewall-protected environment setup, testing suites, release runbooks, and incident postmortems.
- **Boundary Rule (`[INV-LINT-02]`)**: Public documentation must never link into `docs/dev/`. Internal documentation may link outward to public explanation.

---

## Dimension 4: Cognitive Mode (User-Facing Diátaxis)

Splits public living documentation directly by cognitive objective into four flat directories:

| Quadrant | Directory | Objective | Voice & Tone |
| :--- | :--- | :--- | :--- |
| **Tutorial** | `docs/tutorials/` | Learning from zero | Second person ("you will build"). Step-by-step guarantee of success. |
| **How-To Guide** | `docs/how-to/` | Solving a real problem | Imperative ("Run", "Configure"). Assumes basic competence. |
| **Reference** | `docs/reference/` | Accurate factual lookup | Neutral, austere. Tables, lists, signatures. Minimal prose. |
| **Explanation** | `docs/explanation/` | Understanding architecture | Discursive, illuminating. Focuses on why; links to ADRs for decisions. |

---

## Complete 4D Document Mapping Tensor

Every document in a compliant repository occupies exactly one coordinate:

| Document Surface | Temperature | Lifecycle | Audience | Cognitive Mode | Primary Purpose |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `README.md` | **HOT** | Living | Public | Mixed (Pitch) | Project value pitch and shortest setup |
| `docs/tutorials/*.md` | **HOT** | Living | Public | Learning | Guided learning journey for beginners |
| `docs/how-to/*.md` | **HOT** | Living | Public | Doing | Practical recipe solving a specific goal |
| `docs/reference/*.md` | **HOT** | Living | Public | Lookup | Authoritative API, config, and CLI specs |
| `docs/explanation/*.md` | **HOT** | Living | Dual | Understanding | Deep background, domain rationale |
| `docs/dev/setup.md` | **HOT** | Living | Internal | Doing | Local environment bootstrap & build |
| `docs/dev/testing.md` | **HOT** | Living | Internal | Verification | Automated test suites, commands, fixtures |
| `docs/dev/acceptance.md` | **HOT** | Living | Internal | Verification | Real user journey acceptance matrices |
| `docs/dev/postmortems/*.md`| **COLD** | Archived | Internal | Postmortem | Blameless analysis of past incidents |
| `docs/adr/NNNN-*.md` (Accepted)| **WARM** | Accepted | Dual | Governance | Active architectural decision record |
| `docs/adr/NNNN-*.md` (Superseded)| **COLD** | Superseded | Dual | Governance | Historical negative knowledge (in-place) |

---

## Location Exception: Root Files

Files required at the repository root by Git hosting conventions or automated toolchains are classified as **location exceptions** (`[INV-LINT-01]`):

| File | Conceptual Home | Invariant |
| :--- | :--- | :--- |
| `.docgov.yml` | Top-Level Control Plane | Repository governance configuration (triggers, firewall, sanitization). |
| `AGENTS.md` | Policy Guardrail | Low-entropy machine directives defining invariants for AI assistants (< 30 lines). |
| `README.md` | Public pitch / Entry | Must link to `docs/` rather than sprawling into a monolithic manual. |
| `CHANGELOG.md` | Release history | Chronological ledger of user-facing changes per release. |
| `CONTRIBUTING.md` | Contributor entry | Onboarding entry point; links to `docs/dev/setup.md`. |
| `SECURITY.md` | Public disclosure | Vulnerability reporting procedures. |
| `LICENSE` / `LICENSE.md` | Legal | Unaltered license text. |

Arbitrary root Markdown files are forbidden. All other documentation must route through `docs/`.
