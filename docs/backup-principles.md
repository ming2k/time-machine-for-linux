# Backup Principles

The philosophy that decides **what gets backed up and what does not**.
Every rule in `config/*-ignore` should be traceable back to one of the
principles below. If a rule cannot be justified by them, it should not exist.

## Two Different Worlds: System vs Data

System and data are backed up with opposite logic — never mix them.

### System: back up for *recoverability*

The system exists to be **restored to a working state**, not to be preserved
byte-for-byte.

- **Keep**: everything needed to boot and get back to work — `/etc`, package
  state, installed apps, system-level config.
- **Drop**: anything **rebuildable** — package caches, downloaded packages,
  logs, tmp files, coredumps, container/vm runtime data. After restore you run
  `pacman -Syu` or `apt upgrade`, not "restore a cache".
- The question for any system path is: *"After a bare restore, do I need this
  file to have a usable machine again?"* If no → exclude.

### Data: back up by *rarity*

Personal data is backed up **by how hard it would be to obtain again**,
in decreasing priority:

| Tier | Definition | Examples | Policy |
|------|------------|----------|--------|
| 1 | **Irreplaceable** — exists nowhere else, lost = lost forever | personal documents, photos, KeePass vaults, notes, credentials | always back up, highest redundancy |
| 2 | **Hard to re-find** — exists somewhere but is painful to search for again | niche manuals, scraped/compiled data, work archives, uni archives | back up |
| 3 | **Useful resources** — in active use or plausibly needed soon | active projects, books/refs used monthly, current workspace | back up (working trees, not build artifacts) |
| 4 | **Re-obtainable** — downloadable on demand, version-pinned by a lockfile | `node_modules/`, package caches, toolchains, distro packages, ZIM dumps, Steam/game libraries | exclude; re-download or reinstall |
| 5 | **Regeneratable** — the machine rebuilds it automatically | caches, thumbnails, trash, journals, coredumps, build output | exclude |

Two corollaries:

- **Determinism beats copies.** If a manifest reproduces it (lockfile,
  `flatpak list`, mise config, dotfiles), back up the manifest, not the
  artifact. ~1 KB of lockfile replaces ~10 GB of `node_modules`.
- **A backup is not an archive.** Bulky, dormant, "might want it someday"
  data belongs in `@archive` (cold storage, managed manually), not in the
  scheduled backup tiers.

## Anti-Hoarding Rules

The default failure mode of backups is collecting, not protecting. Apply these
checks when in doubt:

1. **Prove usefulness, not possession.** "I have it" is not a reason to back
   something up. "I used it in the last year" or "it is uniquely mine" is.
2. **Re-obtainable ≠ keep.** If it is on the internet, version-pinned by a
   lockfile, or reinstallable with one command, do not spend backup space on
   it — regardless of how long it took to download.
3. **No sentimental exclusions-in-reverse.** Do not keep things *because
   deleting feels bad*. Storage, transfer time, restore time and snapshot
   bloat are all real costs you pay on every single backup run.
4. **Dormant data goes cold.** Anything untouched for a long time moves to
   `@archive` on purpose, with a manifest, instead of riding along in every
   backup forever.
5. **The exclude list is reviewed, not only the include list.** New tools
   silently drop gigabytes of caches into `$HOME` — audit with
   `du -h -d1 ~ | sort -rh` (or `ncdu`) before each backup season.

## Applying the Principles

| What | Where it lands |
|------|----------------|
| Tier 1–3 data | `home-backup.sh` → `@home` (config: `config/home-backup-ignore`) |
| System, recoverable-only | `system-backup.sh` → `@system` (config: `config/system-backup-ignore`) |
| Tier 4 bulk downloads, media libraries, game installs | excluded from backups; `@data` live storage or manual download |
| Dormant Tier 2–3 data | `@archive`, cold, manual |

When adding a pattern to an ignore file, comment **why** (which principle, how
to rebuild/re-obtain). When tempted to un-exclude something, name the tier it
belongs to first.

## Pattern Semantics (read before editing configs)

Patterns are passed to rsync `--exclude-from`, which is *similar to but not
identical with* gitignore:

- A pattern containing a `/` (not at the end) matches against the **full
  relative path** — and also works as a suffix match at any depth, so
  `.local/share/nvim/` excludes that dir for **every user** under the source.
  A pattern without `/` (e.g. `node_modules/`) matches by basename anywhere.
- `dir/` (trailing slash) matches directories; `**` spans multiple levels
  (`projects/**/node_modules/`).
- **Re-inclusion does not work like gitignore**: rsync will not descend into an
  excluded directory, so `!dir/sub/` cannot rescue `dir/sub` once `dir/` is
  excluded. To keep one subtree, **exclude its siblings** instead of excluding
  the parent and negating:

  ```
  # WRONG ( Steam/userdata is still skipped — rsync never enters Steam/ )
  Steam/
  !Steam/userdata/

  # RIGHT ( exclude siblings, keep saves )
  Steam/steamapps/
  Steam/runtime/
  Steam/compatibilitytools.d/
  ```

- Keep patterns **anchored and specific**; broad basename patterns
  (`build/`, `cache/`) surprise you years later.
- After editing, verify with `--dry-run` and preview the real transfer list
  before trusting a new rule. Remember that files already present in the
  backup destination but newly excluded are *not* removed by rsync `--delete` —
  use `tools/cleanup-excluded.sh` to prune them.
