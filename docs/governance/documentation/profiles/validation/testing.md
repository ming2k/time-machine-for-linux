# Entity: Programmatic Implementation Testing

Intent: document automated test execution, suite categories, environment prerequisites, and test fixture topologies to guarantee reproducible mechanical verification.

---

## 1. Non-Negotiable Invariants

- **`[INV-VAL-02]` Deterministic Test Reproducibility**:
  Every automated test command listed in `docs/dev/testing.md` must execute deterministically without hidden local fixtures, undeclared environment variables, or reliance on unversioned network assets.
- **`[INV-TEMP-01]` Hot Data Synchronization**:
  When test runner commands, environment flags, or CI test matrices change, `docs/dev/testing.md` must be updated in the same Pull Request.
- **`[INV-CORE-01]` Contributor Firewall**:
  `docs/dev/testing.md` resides in `docs/dev/` and must not be linked from user-facing documentation.

---

## 2. Document Structure Requirements

Every `docs/dev/testing.md` document must provide:
1. **Automated Suite Command Table**: Precise commands for running unit, integration, and end-to-end test suites.
2. **Environment & Fixture Matrix**: Explanation of test data, mock services, and cleanup procedures.
3. **CI/CD Integration**: Description of how tests run in the continuous integration pipeline.

---

## 3. Authoritative Testing Template (`docs/dev/testing.md`)

```markdown
# Testing Guide

This document defines automated test commands, suite categories, and verification procedures for this repository.

---

## 1. Quick Test Commands

Run tests from the repository root:

```bash
# Run full automated test suite
python3 -m unittest discover -s tests -v

# Run targeted unit tests
python3 -m unittest tests/test_core.py

# Run with warnings treated as errors
python3 -W error -m unittest discover -s tests -v
```

---

## 2. Test Suite Matrix

| Suite | Scope | Execution Command | Target Runtime | CI Enforcement |
| :--- | :--- | :--- | :--- | :--- |
| **Unit** | Isolated functions & classes | `pytest tests/unit` | < 5s | Mandatory (blocks PR) |
| **Integration** | Multi-component interactions | `pytest tests/integration` | < 30s | Mandatory (blocks PR) |
| **E2E / Regression** | Full system execution | `pytest tests/e2e` | < 2m | Mandatory (blocks PR) |
| **Benchmark** | Latency & throughput SLAs | `pytest tests/bench` | < 5m | Nightly / Release gate |

---

## 3. Test Fixtures & Data Topology

- **Unit Fixtures**: In-memory, stateless mocks located in `tests/fixtures/`.
- **Golden Files**: Expected serialized outputs located in `tests/golden/`.
- **Teardown Invariant**: All tests creating temporary directories or sockets must cleanly remove them upon test completion.
```
