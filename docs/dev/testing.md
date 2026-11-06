# Automated Verification & Testing Guide

This guide establishes the automated testing strategy, verification practices, and execution commands for developers and maintainers working on `time-machine-for-linux`.

---

## 1. The Test Pyramid

Verification is organized across three tiers:

```text
                  ▲
                 / \
                /   \     Tier 3: End-to-End & Integration Tests
               / Integ\   (Simulated root backup run, snapshot lifecycle)
              /───────\
             /  Subsys \  Tier 2: Subsystem Verification Tests
            /  -tem     \ (BTRFS subvolume detection, ignore parsing)
           /─────────────\
          /     Unit      \ Tier 1: Fast Unit Tests
         /   Assertions    \ (Path utilities, config validation, logging)
        /───────────────────\
```

---

## 2. Testing Principles

1. **Deterministic Execution**:
   - Tests must run reliably in local developer environments and CI environments.
   - Operations requiring physical block devices or root mounts must gracefully skip or use isolated temporary directories and loop devices.
2. **Invariant Verification (`test_inv_*`)**:
   - Whenever an ADR defines a true system invariant, an automated test or runtime assertion must verify the invariant.
   - Example: Verifying that `archive-sync.sh` rejects `--delete` flags ([INV-BACKUP-03]).
3. **Leak-Free Temporary Fixtures**:
   - Tests creating temporary directories must use `mktemp -d` and register bash cleanup traps (`trap 'rm -rf "$TEST_DIR"' EXIT`), preventing disk clutter.
4. **Fast Feedback**:
   - Tier 1 unit tests must execute in under 1 second to support rapid developer feedback loops.

---

## 3. Running the Test Suite

The unified test runner is `./tests/run-tests.sh`:

```bash
# Run all tests (unit + integration)
./tests/run-tests.sh

# Run only fast unit tests
./tests/run-tests.sh unit

# Run integration tests (some tests skip if run without sudo)
./tests/run-tests.sh integration

# Run with root privileges for complete hardware/btrfs coverage
sudo ./tests/run-tests.sh
```

---

## 4. Test Organization & Layout

```text
tests/
├── helpers/
│   └── test_utils.sh          # Common test setup, assertion helpers, and reporters
├── unit/
│   ├── backup/
│   │   └── test_backup_protection.sh   # Path safety and safety snapshot tests
│   ├── config/
│   │   └── test_config.sh              # Ignore list validation and parser tests
│   └── fs/
│       ├── test_btrfs.sh               # BTRFS filesystem identification tests
│       ├── test_fs.sh                  # Directory accessibility and space check tests
│       └── test_fs_utils.sh            # Absolute path resolution and path tests
├── integration/
│   └── test_system_backup.sh           # End-to-end simulated system backup test
└── run-tests.sh                        # Authoritative test orchestrator
```

---

## 5. Authoring New Tests

When adding a new module or function, create a matching test in `tests/unit/<subsystem>/test_<feature>.sh`:

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../../lib" && pwd)"
source "${LIB_DIR}/loader.sh"
load_backup_libs "$LIB_DIR" >/dev/null 2>&1

test_feature_name() {
    local test_dir=$(mktemp -d)
    trap 'rm -rf "$test_dir"' EXIT

    # Test logic
    if ! check_directory "$test_dir"; then
        echo "FAIL: Expected directory to be valid"
        return 1
    fi

    echo "PASS: test_feature_name"
    return 0
}

test_feature_name
```
