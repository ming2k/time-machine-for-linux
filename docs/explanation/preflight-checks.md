# Preflight Checks

## Overview

Preflight checks automatically run before backup operations and display warnings if issues are detected. Only warnings and errors are shown - if everything is fine, no preflight output appears.

## How It Works

When you run a backup operation, preflight checks run automatically:

```
System Backup
─────────────────────────────────
Source:       /
Destination:  /mnt/@system
Snapshots:    /mnt/@snapshots
Excludes:     25 patterns

[WARN]  38 snapshots found (consider cleanup)
[WARN]  Last backup: 14 days ago

Proceed with system backup? [y/N]
```

If no issues are detected, you only see the confirmation prompt:

```
System Backup
─────────────────────────────────
Source:       /
Destination:  /mnt/@system
Snapshots:    /mnt/@snapshots
Excludes:     25 patterns

Proceed with system backup? [y/N]
```

## What Gets Checked

### Disk Space
- **Warning**: < 20% free space
- **Error**: < 10% free space

### Snapshot Count
- **Warning**: > 10 snapshots (suggests cleanup needed)

### Last Backup Time
- **Warning**: > 7 days since last backup

### BTRFS Health
- **Error**: BTRFS errors detected in system logs

## Severity Levels

- `[WARN]` (Yellow): Issues to review, not blocking
- `[ERROR]` (Red): Serious issues, proceeding is risky

## Log Searching

Preflight output uses searchable prefixes:

```bash
grep "\[WARN\]" backup.log
grep "\[ERROR\]" backup.log
```

## Technical Details

### Implementation
- Preflight checks: `lib/utils/preflight-checks.sh`
- Confirmation dialog: `lib/utils/confirm-execution.sh`

### Adding Custom Checks

Edit `lib/utils/preflight-checks.sh`:

```bash
check_custom_metric() {
    local dest_path="$1"

    if [ some_condition ]; then
        add_preflight_notice "WARNING" "Your warning message"
    fi
}

# Add to run_preflight_checks()
run_preflight_checks() {
    # ... existing checks ...
    check_custom_metric "$dest_path"
}
```

## Special Considerations

### Podman Containers

If you use Podman, consider backing up container data manually. Restoring `~/.config/containers/` and `~/.local/share/containers/` directly may corrupt container state.

**Recommended approach:**

```bash
# Export container definitions
podman generate systemd --new --name my-container > my-container.service

# Export images
podman save -o my-image.tar my-image:tag

# After restore, reimport
podman load -i my-image.tar
```

Benefits:
- Smaller backups (only save what you need)
- No corruption risk
- Selective restore capability
