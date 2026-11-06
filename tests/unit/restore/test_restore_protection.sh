#!/bin/bash

# Test suite for restore protection and fail-closed safety [INV-RESTORE-01, INV-RESTORE-02, INV-RESTORE-03]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../../lib" && pwd)"

# Source library loader and load restore libraries
source "${LIB_DIR}/loader.sh"
load_restore_libs "$LIB_DIR" >/dev/null 2>&1

test_confirm_restore_affirmation() {
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' RETURN

    local src="$tmp_dir/src"
    local dst="$tmp_dir/dst"
    mkdir -p "$src" "$dst"

    # Test 1: Empty input (Enter) must be rejected [INV-RESTORE-02]
    if echo "" | confirm_restore_execution "system" "$src" "$dst" "" >/dev/null 2>&1; then
        echo "FAIL: confirm_restore_execution allowed empty input (default enter)"
        return 1
    fi

    # Test 2: Lowercase 'y' must be rejected [INV-RESTORE-02]
    if echo "y" | confirm_restore_execution "system" "$src" "$dst" "" >/dev/null 2>&1; then
        echo "FAIL: confirm_restore_execution allowed lowercase 'y'"
        return 1
    fi

    # Test 3: Lowercase 'yes' must be rejected [INV-RESTORE-02]
    if echo "yes" | confirm_restore_execution "system" "$src" "$dst" "" >/dev/null 2>&1; then
        echo "FAIL: confirm_restore_execution allowed lowercase 'yes'"
        return 1
    fi

    # Test 4: Uppercase 'Y' must be rejected [INV-RESTORE-02]
    if echo "Y" | confirm_restore_execution "system" "$src" "$dst" "" >/dev/null 2>&1; then
        echo "FAIL: confirm_restore_execution allowed single uppercase 'Y'"
        return 1
    fi

    # Test 5: Arbitrary token 'NO' must be rejected
    if echo "NO" | confirm_restore_execution "system" "$src" "$dst" "" >/dev/null 2>&1; then
        echo "FAIL: confirm_restore_execution allowed token 'NO'"
        return 1
    fi

    # Test 6: Exact uppercase 'YES' must be accepted [INV-RESTORE-02]
    if ! echo "YES" | confirm_restore_execution "system" "$src" "$dst" "" >/dev/null 2>&1; then
        echo "FAIL: confirm_restore_execution rejected valid 'YES'"
        return 1
    fi

    echo "PASS: test_confirm_restore_affirmation"
    return 0
}

test_validate_restore_safety_paths() {
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' RETURN

    local src="$tmp_dir/src"
    local dst="$tmp_dir/dst"
    mkdir -p "$src" "$dst"
    echo "test content" > "$src/file.txt"

    # Test 1: Identical paths must be rejected [INV-RESTORE-03]
    if validate_restore_safety "$src" "$src" >/dev/null 2>&1; then
        echo "FAIL: validate_restore_safety allowed identical source and dest"
        return 1
    fi

    # Test 2: Protected tier @archive as destination must be rejected [INV-RESTORE-03, INV-BACKUP-03]
    local archive_dst="$tmp_dir/@archive"
    mkdir -p "$archive_dst"
    if validate_restore_safety "$src" "$archive_dst" >/dev/null 2>&1; then
        echo "FAIL: validate_restore_safety allowed restore targeting @archive"
        return 1
    fi

    # Test 3: Protected tier @snapshots as destination must be rejected [INV-RESTORE-03]
    local snapshot_dst="$tmp_dir/@snapshots"
    mkdir -p "$snapshot_dst"
    if validate_restore_safety "$src" "$snapshot_dst" >/dev/null 2>&1; then
        echo "FAIL: validate_restore_safety allowed restore targeting @snapshots"
        return 1
    fi

    # Test 4: Empty source must be rejected
    local empty_src="$tmp_dir/empty_src"
    mkdir -p "$empty_src"
    if validate_restore_safety "$empty_src" "$dst" >/dev/null 2>&1; then
        echo "FAIL: validate_restore_safety allowed empty source directory"
        return 1
    fi

    # Test 5: Valid distinct paths with files must pass
    if ! validate_restore_safety "$src" "$dst" >/dev/null 2>&1; then
        echo "FAIL: validate_restore_safety failed on valid distinct paths"
        return 1
    fi

    echo "PASS: test_validate_restore_safety_paths"
    return 0
}

test_system_restore_excludes() {
    local excludes
    excludes=$(get_system_restore_excludes)

    local required_patterns=("/dev/*" "/proc/*" "/sys/*" "/run/*" "/tmp/*" "/mnt/*" "/media/*" "/lost+found")
    for pattern in "${required_patterns[@]}"; do
        if [[ "$excludes" != *"$pattern"* ]]; then
            echo "FAIL: get_system_restore_excludes missing critical pattern: $pattern"
            return 1
        fi
    done

    echo "PASS: test_system_restore_excludes"
    return 0
}

test_fail_closed_snapshot() {
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' RETURN

    local src="$tmp_dir/src"
    local dst="$tmp_dir/dst"
    local fake_snap_dir="$tmp_dir/fake_snapshots"
    mkdir -p "$src" "$dst" "$fake_snap_dir"
    echo "payload" > "$src/file.txt"

    # Test 1: create_pre_restore_snapshot on non-BTRFS directory must fail-closed [INV-RESTORE-01]
    if create_pre_restore_snapshot "$dst" "$fake_snap_dir" "system" >/dev/null 2>&1; then
        echo "FAIL: create_pre_restore_snapshot succeeded on non-BTRFS directory"
        return 1
    fi

    # Test 2: execute_restore_with_snapshot must abort (exit non-zero) when snapshot fails [INV-RESTORE-01]
    # No files should be copied to dst
    if execute_restore_with_snapshot "$src" "$dst" "$fake_snap_dir" "system" "false" "" >/dev/null 2>&1; then
        echo "FAIL: execute_restore_with_snapshot did not abort when snapshot creation failed"
        return 1
    fi

    if [ -f "$dst/file.txt" ]; then
        echo "FAIL: execute_restore_with_snapshot modified destination after snapshot failure"
        return 1
    fi

    echo "PASS: test_fail_closed_snapshot"
    return 0
}

test_check_restore_disk_space() {
    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' RETURN

    local src="$tmp_dir/src"
    local dst="$tmp_dir/dst"
    mkdir -p "$src" "$dst"
    echo "small file" > "$src/file.txt"

    # Should pass when disk space is ample
    if ! check_restore_disk_space "$src" "$dst" >/dev/null 2>&1; then
        echo "FAIL: check_restore_disk_space failed on normal directories"
        return 1
    fi

    echo "PASS: test_check_restore_disk_space"
    return 0
}

# Run all tests
main() {
    test_confirm_restore_affirmation || exit 1
    test_validate_restore_safety_paths || exit 1
    test_system_restore_excludes || exit 1
    test_fail_closed_snapshot || exit 1
    test_check_restore_disk_space || exit 1
    echo "All restore protection tests passed successfully."
}

main "$@"
