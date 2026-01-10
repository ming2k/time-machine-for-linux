# Preflight Checks Feature

## Overview

The preflight checks feature provides a "Good to know before you proceed" option during backup and restore operations. This allows you to optionally review important system information before confirming an operation.

## How It Works

When you run a backup or restore operation, you'll see an enhanced confirmation prompt:

```
Do you want to proceed with system backup? [y/N/c] (c=check preflight info)
```

### Options:
- **y** (yes): Proceed with the operation immediately
- **n** (no): Cancel the operation
- **c** (check): View preflight information before deciding

## Example Session

```bash
sudo ./bin/system-backup.sh --source / --dest /mnt/@root --snapshots /mnt/@snapshots
```

### Output:

```
═══════════════════════════════════════════════════
 BACKUP CONFIRMATION
═══════════════════════════════════════════════════

The following backup operation will be performed:

System Root Directory: /
Backup Directory: /mnt/@root
Safety Snapshot Base: /mnt/@snapshots

Do you want to proceed with system backup? [y/N/c] (c=check preflight info) c
```

### When you press 'c', you see:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Good to know before you proceed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ℹ  Disk space: 65% free (325G available)
  ℹ  Found 3 existing snapshot(s)
  ℹ  Last backup: 2 day(s) ago
  ℹ  BTRFS filesystem health: OK

Do you want to proceed with system backup? [y/N/c] (c=check preflight info)
```

Now you can make an informed decision:
- Press **y** to proceed
- Press **n** to cancel
- Press **c** again to re-check (useful if you just freed up space)

## What Gets Checked

### For Backup Operations:

#### System Backup
- ℹ **Disk space**: Available space on backup destination
  - INFO: > 20% free
  - WARNING: 10-20% free
  - CRITICAL: < 10% free

- ℹ **Snapshot count**: Number of existing snapshots
  - INFO: 0-10 snapshots
  - WARNING: > 10 snapshots (suggests cleanup needed)

- ℹ **Last backup time**: When the destination was last updated
  - INFO: < 7 days ago
  - WARNING: > 7 days ago (backup overdue)

- ℹ **BTRFS health**: Checks system logs for filesystem errors
  - INFO: No issues detected
  - WARNING: BTRFS warnings in system logs
  - CRITICAL: BTRFS errors detected

- ℹ **Podman containers**: Detects Podman container data that needs special handling
  - WARNING: Podman containers detected (manual backup recommended)
  - INFO: Explains why manual backup is needed

#### Data Backup
All of the above, plus:
- ℹ **Source accessibility**: Checks if all configured sources are readable
  - INFO: All sources accessible
  - WARNING: Some sources not accessible (will be skipped)
  - CRITICAL: No sources accessible

### For Restore Operations:
- ℹ **Destination disk space**: Available space for restore
- ℹ **Snapshot availability**: Pre-restore snapshot status
- ℹ **BTRFS health**: Filesystem health of restore destination

## Severity Levels

Preflight notices use three severity levels:

- **ℹ INFO** (Blue): Informational notices, no action needed
- **⚠ WARNING** (Yellow): Issues that should be reviewed but aren't blocking
- **✖ CRITICAL** (Red): Serious issues that make proceeding risky

## Benefits

1. **Non-intrusive**: Only shown when you choose to check
2. **No workflow disruption**: Doesn't force you to view info if you don't want to
3. **Informed decisions**: Make better choices about when to run backups
4. **Early warnings**: Catch issues before they cause failures mid-backup
5. **Educational**: Learn about your system's state over time

## Automated Scripts

For automated backup scripts (cron jobs, systemd timers), the preflight check doesn't interrupt:
- The default response 'n' or 'y' still works as before
- Only interactive users who type 'c' see the preflight info
- No breaking changes to existing automation

## Special Considerations

### Podman Containers

If you use Podman, the preflight check will detect container data and warn you about special handling requirements.

#### Why Manual Backup is Needed

Podman stores container data in:
- `~/.config/containers/` - Container configuration
- `~/.local/share/containers/` - Container images, volumes, and runtime data

**Problems with automatic backup/restore:**
1. **Corruption risk**: Restoring these directories directly may corrupt container state
2. **Space inefficiency**: Container images can be large (multi-GB)
3. **Portability issues**: Containers may have host-specific configurations

#### Recommended Approach

**For Configuration Backup:**
```bash
# Backup container definitions only
podman generate systemd --new --name my-container > ~/container-definitions/my-container.service

# Or export container configuration
podman inspect my-container > ~/container-configs/my-container.json
```

**For Complete Container Migration:**
```bash
# Export running containers as tar archives
podman save -o ~/backups/my-image.tar my-image:tag

# Or use podman export for container filesystems
podman export my-container > ~/backups/my-container.tar
```

**After Restore:**
```bash
# Import images on new system
podman load -i ~/backups/my-image.tar

# Recreate containers from systemd units
systemctl --user enable --now container-my-container.service
```

#### Benefits of Manual Backup
- ✅ **Smaller backups**: Only save what you need
- ✅ **No corruption**: Clean migration between systems
- ✅ **Selective restore**: Choose which containers to restore
- ✅ **Reproducible**: Use infrastructure-as-code approach

#### What the Preflight Check Shows

When Podman data is detected:
```
  ⚠  Podman containers detected: ~/.config/containers/ should be backed up manually
  ℹ  Reason: Restoring Podman data may corrupt containers. Manual backup saves space and allows selective restore
```

## Example Use Cases

### 1. Low Disk Space
Before running a large backup, check if you have enough space and potentially clean up old snapshots first.

### 2. Snapshot Cleanup
Discover you have accumulated many snapshots and clean them up before creating more.

### 3. Backup Schedule Awareness
See that your last backup was 10 days ago and realize you should run backups more frequently.

### 4. Source Verification (Data Backup)
Verify all your configured backup sources are accessible before starting a long backup operation.

### 5. BTRFS Health
Catch early signs of filesystem issues before they cause backup failures.

### 6. Podman Container Warning
Get reminded to manually backup your Podman containers before running a system backup, preventing corruption and saving space.

## Technical Details

### Implementation
- Preflight checks module: `lib/utils/preflight-checks.sh`
- Enhanced confirmation: `lib/utils/confirm-execution.sh`
- Loaded automatically via: `lib/loader.sh`

### Extending Checks

You can easily add custom checks by editing `lib/utils/preflight-checks.sh`:

```bash
# Add a custom check function
check_custom_metric() {
    local dest_path="$1"

    # Your check logic here
    if [ some_condition ]; then
        add_preflight_notice "WARNING" "Your custom warning message"
    fi
}

# Add it to the run_preflight_checks function
run_preflight_checks() {
    # ... existing checks ...
    check_custom_metric "$dest_path"
}
```

### Performance
Preflight checks are only executed when the user types 'c', so there's **zero performance impact** on normal operations.

## See Also
- [System Backup Documentation](../CLAUDE.md#backup-operations)
- [Data Backup Documentation](../CLAUDE.md#data-backup-workflow)
- [BTRFS Snapshots](../CLAUDE.md#btrfs-integration)
