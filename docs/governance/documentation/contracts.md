# Repository Contracts (Protocol v6.0.0)

Reference data, profile declarations, and configuration bindings for repositories adopting Protocol v6.0.0.

---

## 1. Activated Profiles

Declare the domain capability profiles active in this repository. Toolchains use this declaration to assemble and verify documentation surfaces:

- [x] `core` (Mandatory: 4D spatial taxonomy, system invariants, operational workflow, style)
- [x] `architecture` (Architecture records, living blueprints, pre-decision RFCs)
- [x] `validation` (Product validation: user journeys, acceptance matrices, testing guides)
- [ ] `operations` (Operational knowledge: postmortems, triage runbooks)

---

## 2. Declarative Contract Schema (`/.docgov.yml`)

In Protocol v6.0.0, repository contracts and profiles are configured via `/.docgov.yml` at the repository root:

```yaml
version: "6.0"

# [INV-LINT-01] Root Location Sanitization
root_sanitization:
  enforce: true
  allowed_markdown:
    - "README.md"
    - "CHANGELOG.md"
    - "CONTRIBUTING.md"
    - "AGENTS.md"
    - "LICENSE.md"
    - "SECURITY.md"

# [INV-LINT-02] Contributor Firewall Bindings
firewall:
  public_surfaces:
    - "docs/tutorials/**"
    - "docs/how-to/**"
    - "docs/reference/**"
    - "docs/explanation/**"
  internal_surfaces:
    - "docs/dev/**"

# [INV-LINT-03] Architecture & Metadata Profile
architecture:
  adr_path: "docs/adr"
  require_frontmatter:
    status_enum: ["draft", "accepted", "superseded", "rejected", "deprecated"]
    mandatory_fields: ["id", "title", "status", "date"]

# [INV-LINT-04] Code-to-Doc Trigger Bindings
triggers:
  - watch: "src/api/**"
    require_update: "docs/reference/**"
    message: "Public API modified; docs/reference/ must be synchronized in the same commit."
  - watch: "src/cli/**"
    require_update: "docs/how-to/**"
    message: "CLI syntax changed; docs/how-to/ must be synchronized in the same commit."
```

---

## 3. Directory Layout Bindings

| Surface | Path | Required | Temperature | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Top Control Plane** | `.docgov.yml` | Yes | **HOT** | Declarative governance rules & triggers |
| **AI Directives** | `AGENTS.md` | Yes | **HOT** | Machine & cognitive invariant mapping (< 30 lines) |
| **Public Tutorials** | `docs/tutorials/` | Optional | **HOT** | Guided learning from zero |
| **Public How-To** | `docs/how-to/` | Optional | **HOT** | Practical recipes for real tasks |
| **Public Reference** | `docs/reference/` | Optional | **HOT** | Authoritative technical & API specifications |
| **Public Explanation**| `docs/explanation/`| Optional | **HOT** | Architectural context & domain concepts |
| **Contributor Surface**| `docs/dev/` | Yes | **HOT** | Internal setup, testing, and procedures |
| **ADR Registry** | `docs/adr/` | If Architecture | **WARM** / **COLD** | Decisions evolved in-place via Frontmatter |
| **Incident Reviews** | `docs/dev/postmortems/`| If Operations | **COLD** | Blameless analysis of past incidents |
| **Root Entry** | `README.md` | Yes | **HOT** | Project value pitch and shortest setup |
