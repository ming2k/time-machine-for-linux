# Entity: Living Architecture Blueprint & Compaction

Intent: condense historical multi-version ADR logs into living architecture snapshots and cold-tier archives to prevent context explosion, stale-rule poisoning, and discovery latency as decision counts scale.

---

## 1. Non-Negotiable Invariants

- **`[INV-ARCH-05]` Snapshot Compaction Integrity**:
  When related ADRs are compacted into a living snapshot (`docs/architecture/<subsystem>.md`), the snapshot must preserve all active invariants, boundary constraints, and incorporate a historical lineage table citing original ADR numbers.
- **`[INV-TEMP-01]` Hot Data Synchronization**:
  Living architecture blueprints are **HOT** tier documents. They must be kept in lockstep with the running codebase; any architectural modification requires updating the snapshot in the same PR.
- **`[INV-TEMP-03]` No Direct Deletion**:
  Never physically delete (`rm`) compacted ADRs. Relocate them to `docs/adr/archive/`. Citations embedded in source code (`See ADR-NNNN`) must remain resolvable.

---

## 2. The Duality: Event Log vs. Living State

Engineering documentation operates on two orthogonal planes:

```text
┌─────────────────────────────────────────────────────────────┐
│ Event Log Plane (WARM — Append-Only): `docs/adr/`           │
│ Immutable chronological sequence of decisions and trade-offs│
└──────────────────────────────┬──────────────────────────────┘
                               │ Compaction & Distillation
                               ▼
┌─────────────────────────────────────────────────────────────┐
│ State Snapshot Plane (HOT — Living State): `docs/architecture/` │
│ Authoritative current blueprint, component models, rules    │
└─────────────────────────────────────────────────────────────┘
```

- **The ADR Log (`docs/adr/`)**: Captures *why the system evolved over time*. Referenced just-in-time when investigating historical rationale.
- **The Living Snapshot (`docs/architecture/`)**: Captures *what the system is today*. Primary context window for human engineers and AI coding assistants.

---

## 3. When to Compact (Compaction Triggers)

Execute a compaction cycle when any trigger fires:
1. **Subsystem Saturation**: A subsystem (e.g., auth, network, storage) accumulates >= 5 incremental or amending ADRs.
2. **Repository Milestone**: Total active ADRs in `docs/adr/` exceed 50 records.
3. **High Invalidation Ratio**: Over 40% of records in `docs/adr/` are marked `Superseded` or `Deprecated`.

---

## 4. Compaction Standard Operating Procedure (4 Steps)

```text
Step 1: Consolidate       Step 2: Tombstone       Step 3: Relocate        Step 4: Re-Index
┌─────────────────┐       ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ Synthesize into │  ──►  │ Mark Status as  │ ──► │ Move file to    │ ──► │ Update index.md │
│ docs/           │       │ Compacted into  │     │ docs/adr/       │     │ with tombstone  │
│ architecture/   │       │ Snapshot        │     │ archive/        │     │ row pointer     │
└─────────────────┘       └─────────────────┘     └─────────────────┘     └─────────────────┘
```

### Step 1: Synthesize Living Snapshot
Create or update the authoritative document at `docs/architecture/<subsystem>.md`:
- Extract surviving invariants, domain models, and active component interfaces.
- Omit transient historical migration steps that have already concluded.
- Record a "Historical Lineage" section linking back to foundational ADR numbers.

### Step 2: Mark Tombstone
Update the header of compacted ADRs:
```markdown
# NNNN. <Original Title>

- Status: Compacted into [docs/architecture/<subsystem>.md](../../architecture/<subsystem>.md)
- Date: YYYY-MM-DD
- Compacted Date: YYYY-MM-DD
- Lineage: Preceded by [ADR-XXXX], incorporated into [Snapshot Path]

> **Notice**: This record has been compacted into the living architecture specification.
> Active rules and constraints are maintained in the snapshot. This file is preserved
> for historical rationale and negative-knowledge audits.
```

### Step 3: Relocate to Cold Storage
Move the compacted ADR into cold storage:
```bash
mv docs/adr/NNNN-<slug>.md docs/adr/archive/NNNN-<slug>.md
```

### Step 4: Re-Index Registry
Update `docs/adr/index.md` pointing the compacted ADR row to its archive path and living snapshot.

---

## 5. Living Snapshot Template (`docs/architecture/<subsystem>.md`)

```markdown
# Subsystem Architecture: [Name]

- Status: Living Blueprint
- Last Updated: YYYY-MM-DD
- Scope: [e.g., core/engine, storage/wal, network/transport]
- Maintainers: [Team / GitHub handles]

---

## 1. System Overview & Boundaries

High-level conceptual model describing what this subsystem does, its core responsibilities, and where its boundary stops.

## 2. Invariants & Non-Negotiable Rules

List active architectural constraints that human engineers and AI coding assistants must observe:
- **`[INV-<SUB>-01]`**: [e.g., Never perform blocking disk I/O on the event loop]
- **`[INV-<SUB>-02]`**: [e.g., All incoming RPC payloads must pass bounds-checking before serialization]

## 3. Component Architecture & Data Flow

Detailed breakdown of components, data structures, and state transitions:
- Component A: Responsibilities and concurrency model.
- Component B: Storage schema and memory boundaries.

## 4. Historical Lineage & Founding ADRs

Traceability back to foundational decisions compacted into this snapshot:
- Compaction Date: YYYY-MM-DD
- Founding Records:
  - [ADR-0012: Initial WAL Architecture](../../adr/archive/0012-wal.md) (Compacted)
  - [ADR-0034: Zero-Copy Ring Buffer](../../adr/archive/0034-ring-buffer.md) (Compacted)
  - [ADR-0056: Segment Compaction Strategy](../../adr/archive/0056-compaction.md) (Compacted)
```
