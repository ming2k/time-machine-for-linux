# Data Backup Scenarios

This document explains how the data backup tool handles various configuration changes and workflows.

## How State Tracking Works

After each successful backup, the tool saves a state file (`.backup-state.json`) at the backup destination root:

```json
{
  "version": 1,
  "last_backup": "2026-01-30T10:15:00Z",
  "mappings": [
    {"source": "/home/user/documents", "dest": "documents"},
    {"source": "/home/user/photos", "dest": "photos"}
  ]
}
```

This state is compared with your current config on the next run to detect changes.

---

## Scenario 1: Adding a New Backup Entry

**Config change:**
```bash
# Before
/home/user/documents|documents||mirror

# After (added photos)
/home/user/documents|documents||mirror
/home/user/photos|photos||mirror
```

**What happens:**
1. Backup runs normally
2. New `photos/` directory created in backup destination
3. State file updated with both mappings

**No warnings** - adding entries is safe.

---

## Scenario 2: Removing a Backup Entry (Orphan Created)

**Config change:**
```bash
# Before
/home/user/documents|documents||mirror
/home/user/photos|photos||mirror

# After (removed photos)
/home/user/documents|documents||mirror
```

**What happens:**
1. Script detects `photos/` exists but not in config
2. Warning and error displayed:
   ```
   ⚠ Orphaned backup destinations detected.
   Orphaned backup destinations found:
     • photos/     (15.2 GB)
   ✖ Backup cannot proceed while orphans exist.
   ```
3. **Backup exits** (no data is backed up until resolved)

**User options:**
- Run with `--cleanup-orphans` to remove the orphan
- Add the entry back to `data-map.conf`
- Manually move/delete the directory if preferred

---

## Scenario 3: Renaming a Destination

**Config change:**
```bash
# Before
/home/user/photos|photos||mirror

# After (renamed dest to pictures)
/home/user/photos|pictures||mirror
```

**What happens:**
1. Script detects `photos/` as an orphan because the config now expects `pictures/`
2. **Backup exits** with an error about orphaned destinations

**Result:** You must resolve the orphan before the new backup can run.

**Recommended approach:**
```bash
# Option A: Manually rename before backup to avoid re-copying all data
mv /mnt/@data/photos /mnt/@data/pictures
# Then run backup (no orphan, no re-copy)

# Option B: Cleanup orphan first (if you don't care about old data)
sudo ./bin/data-backup.sh --dest /mnt/@data --snapshots /mnt/@snapshots --cleanup-orphans
# Then run backup
```

---

## Scenario 4: Changing Source Path

**Config change:**
```bash
# Before
/home/user/Documents|documents||mirror

# After (source moved to new location)
/home/user/docs|documents||mirror
```

**What happens:**
1. Same destination `documents/`, different source
2. Backup syncs new source to existing destination
3. In mirror mode: files only in old source are **deleted** from backup
4. In incremental mode: files from old source **remain** in backup

**No orphan warning** - destination name unchanged.

---

## Scenario 5: First Run (No State File)

**What happens:**
1. No `.backup-state.json` exists
2. Orphan detection skipped (nothing to compare)
3. Backup runs normally
4. State file created after successful backup

---

## Scenario 6: Multiple Orphans

**Config change:**
```bash
# Before
/home/user/documents|documents||mirror
/home/user/photos|photos||mirror
/home/user/videos|videos||mirror
/home/user/music|music||mirror

# After (keeping only documents)
/home/user/documents|documents||mirror
```

**What happens:**
1. Script detects multiple orphans
2. Output:
   ```
   ⚠ Orphaned backup destinations detected.
   Orphaned backup destinations found:
     • photos/     (15.2 GB)
     • videos/     (50.1 GB)
     • music/      (8.7 GB)
   ✖ Backup cannot proceed while orphans exist.
   ```
3. **Backup exits** until orphans are cleaned up or restored to config.

---

## Scenario 7: Corrupted or Missing State File

**Situations:**
- `.backup-state.json` deleted manually
- File corrupted (invalid JSON)
- Permission issues

**What happens:**
1. Warning logged: "State file is malformed, treating as first run"
2. No orphan detection (can't compare)
3. Backup proceeds normally
4. New state file created after backup

**Note:** Orphans won't be detected until after the next backup cycle.

---

## How .backupignore Works

### Pattern Sources (in order of precedence)

1. **Source directory `.backupignore`** - `/home/user/projects/.backupignore`
2. **Global ignore file** - `config/backup/.backupignore`
3. **Inline patterns** - from `data-map.conf` entry

### Example Workflow

```bash
# 1. Global ignore (applies to ALL sources)
# config/backup/.backupignore
*.log
*.tmp
.DS_Store
Thumbs.db

# 2. Source-specific ignore
# /home/user/projects/.backupignore
node_modules/
dist/
.venv/

# 3. Inline pattern in config
/home/user/projects|projects|__pycache__/,*.pyc|mirror
```

**Result:** All three pattern sources are merged when backing up `/home/user/projects`.

### Pattern Syntax

Uses gitignore-style patterns:
```bash
# Ignore all .log files
*.log

# Ignore directory anywhere
node_modules/

# Ignore at root only
/build/

# Negate pattern (include despite other rules)
!important.log
```

---

## Backup Mode Comparison

| Aspect | Incremental | Mirror |
|--------|-------------|--------|
| Copy changed files | Yes | Yes |
| Delete extra files in dest | No | Yes |
| Safe for append-only data | Yes | Yes |
| Exact replica of source | No | Yes |
| Risk of data loss | Lower | Higher (deletes files) |
| Use case | Archives, growing collections | Sync exact state |

### When to Use Each

**Incremental:**
- Media collections (photos, music, videos)
- Data that only grows, never deletes
- When you want to keep deleted files in backup

**Mirror:**
- Project directories (code, documents)
- Website deployments
- When backup should exactly match source
- When you want to free space by removing deleted files
