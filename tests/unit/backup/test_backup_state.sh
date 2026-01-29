#!/bin/bash

# Unit tests for backup-state.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

source "${PROJECT_ROOT}/tests/helpers/test_utils.sh"
source "${LIB_DIR}/core/colors.sh"
source "${LIB_DIR}/core/logging.sh"
source "${LIB_DIR}/backup/backup-state.sh"

# Test helper functions
test_pass() {
    local msg="$1"
    TEST_COUNT=$((TEST_COUNT + 1))
    TEST_PASSED=$((TEST_PASSED + 1))
    echo -e "${GREEN}✓ $msg${NC}"
}

test_fail() {
    local msg="$1"
    TEST_COUNT=$((TEST_COUNT + 1))
    TEST_FAILED=$((TEST_FAILED + 1))
    echo -e "${RED}✗ $msg${NC}"
}

# Test fixtures
TEST_DIR=""

setup() {
    TEST_DIR=$(mktemp -d)
}

teardown() {
    [ -n "$TEST_DIR" ] && rm -rf "$TEST_DIR"
}

# Test: State file is created correctly
test_update_backup_state_creates_file() {
    setup

    local -a sources=("/home/user/docs" "/home/user/photos")
    local -a destinations=("docs" "photos")

    update_backup_state "$TEST_DIR" sources destinations

    local state_file="$TEST_DIR/.backup-state.json"
    if [ -f "$state_file" ]; then
        test_pass "State file created"
    else
        test_fail "State file not created"
        teardown
        return 1
    fi

    # Verify JSON structure
    if jq -e '.version == 1' "$state_file" >/dev/null 2>&1; then
        test_pass "State file has correct version"
    else
        test_fail "State file version incorrect"
    fi

    if jq -e '.mappings | length == 2' "$state_file" >/dev/null 2>&1; then
        test_pass "State file has correct number of mappings"
    else
        test_fail "State file mappings count incorrect"
    fi

    teardown
}

# Test: Read backup state returns correct data
test_read_backup_state() {
    setup

    # Create a state file manually
    local state_file="$TEST_DIR/.backup-state.json"
    cat > "$state_file" << 'EOF'
{
  "version": 1,
  "last_backup": "2026-01-30T10:00:00Z",
  "mappings": [
    {"source": "/home/user/docs", "dest": "docs"}
  ]
}
EOF

    local result
    if result=$(read_backup_state "$TEST_DIR"); then
        test_pass "Read state file successfully"
    else
        test_fail "Failed to read state file"
        teardown
        return 1
    fi

    if echo "$result" | jq -e '.mappings[0].dest == "docs"' >/dev/null 2>&1; then
        test_pass "State data is correct"
    else
        test_fail "State data is incorrect"
    fi

    teardown
}

# Test: No orphans when config matches state
test_detect_orphans_no_orphans() {
    setup

    # Create state with docs and photos
    local state_file="$TEST_DIR/.backup-state.json"
    cat > "$state_file" << 'EOF'
{
  "version": 1,
  "last_backup": "2026-01-30T10:00:00Z",
  "mappings": [
    {"source": "/home/user/docs", "dest": "docs"},
    {"source": "/home/user/photos", "dest": "photos"}
  ]
}
EOF

    # Create the directories
    mkdir -p "$TEST_DIR/docs" "$TEST_DIR/photos"

    # Config matches state
    local -a current_destinations=("docs" "photos")

    local orphans
    if orphans=$(detect_orphans "$TEST_DIR" current_destinations 2>/dev/null); then
        test_fail "Should not detect orphans when config matches state"
    else
        test_pass "No orphans detected when config matches state"
    fi

    teardown
}

# Test: Detects orphans when config removes a mapping
test_detect_orphans_finds_orphans() {
    setup

    # Create state with docs and photos
    local state_file="$TEST_DIR/.backup-state.json"
    cat > "$state_file" << 'EOF'
{
  "version": 1,
  "last_backup": "2026-01-30T10:00:00Z",
  "mappings": [
    {"source": "/home/user/docs", "dest": "docs"},
    {"source": "/home/user/photos", "dest": "photos"}
  ]
}
EOF

    # Create the directories
    mkdir -p "$TEST_DIR/docs" "$TEST_DIR/photos"

    # Config only has docs (photos removed)
    local -a current_destinations=("docs")

    local orphans
    if orphans=$(detect_orphans "$TEST_DIR" current_destinations 2>/dev/null); then
        if [[ "$orphans" == "photos" ]]; then
            test_pass "Correctly detected 'photos' as orphan"
        else
            test_fail "Detected wrong orphan: $orphans"
        fi
    else
        test_fail "Should detect orphans when config is missing a mapping"
    fi

    teardown
}

# Test: No false positives when directory doesn't exist
test_detect_orphans_no_false_positives() {
    setup

    # Create state with docs and photos
    local state_file="$TEST_DIR/.backup-state.json"
    cat > "$state_file" << 'EOF'
{
  "version": 1,
  "last_backup": "2026-01-30T10:00:00Z",
  "mappings": [
    {"source": "/home/user/docs", "dest": "docs"},
    {"source": "/home/user/photos", "dest": "photos"}
  ]
}
EOF

    # Only create docs directory (photos doesn't exist on disk)
    mkdir -p "$TEST_DIR/docs"

    # Config only has docs
    local -a current_destinations=("docs")

    local orphans
    if orphans=$(detect_orphans "$TEST_DIR" current_destinations 2>/dev/null); then
        test_fail "Should not report orphan for non-existent directory: $orphans"
    else
        test_pass "No false positive for non-existent directory"
    fi

    teardown
}

# Test: First run (no state file) has no orphans
test_detect_orphans_first_run() {
    setup

    local -a current_destinations=("docs" "photos")

    local orphans
    if orphans=$(detect_orphans "$TEST_DIR" current_destinations 2>/dev/null); then
        test_fail "Should not detect orphans on first run: $orphans"
    else
        test_pass "No orphans on first run (no state file)"
    fi

    teardown
}

# Run tests
echo "Running backup-state.sh unit tests..."
echo ""

# Check for jq
if ! command -v jq &>/dev/null; then
    echo "SKIP: jq not installed (required for backup state tests)"
    exit 0
fi

test_update_backup_state_creates_file
test_read_backup_state
test_detect_orphans_no_orphans
test_detect_orphans_finds_orphans
test_detect_orphans_no_false_positives
test_detect_orphans_first_run

echo ""
print_test_summary
