---
id: platforms-filesystems-deleted-file-recovery-on-apfs
domain: platforms
category: filesystems
applies_to: [macos]
confidence: field-tested
sources:
  - "man tmutil (macOS 15, Darwin 25.5.0)"
  - "man trimforce (macOS 15, Darwin 25.5.0)"
  - "Local verification 2026-08-18 (macOS 15, APPLE SSD AP0512Z)"
last_verified: 2026-08-18
related: []
---

# Recovering a File a User Deleted on a macOS SSD

## When this applies

Someone asks you to recover a deleted file or folder on macOS, and you are about
to recommend a recovery tool or start scanning free space. Also when the exact
path or name of the deleted item is uncertain and that uncertainty is blocking
every search.

## Do this

1. **Establish whether free-space recovery is even on the table, before
   recommending tooling.** On an internal Apple SSD with TRIM active, freed blocks
   are discarded by the drive, so carving from free space is not a path to plan
   around — sources of a *copy* are:

```sh
system_profiler SPNVMeDataType | grep -i TRIM     # "TRIM Support: Yes" → carving is not the plan
tmutil listlocalsnapshots /System/Volumes/Data    # APFS local snapshots — the first real source
tmutil listbackups                                # Time Machine destinations, when attached
```

2. **Work the copy sources in order of fidelity**, and stop at the first hit:

| Source | Check with | Recovers |
|---|---|---|
| Trash (not yet emptied) | `ls ~/.Trash` and per-volume `.Trashes` | The file itself |
| APFS local snapshot | `tmutil listlocalsnapshots /System/Volumes/Data`, then mount it read-only | State as of the snapshot time |
| Time Machine backup | `tmutil listbackups`, Migration/Finder restore | State as of the last backup |
| Cloud copy (iCloud Drive, Drive, Dropbox) | The provider's own trash/version history, in the web UI | Versions the provider still holds — server-side retention runs on the provider's own window, so a copy survives the local deletion until that window elapses |
| Version-controlled or published copies | `git fsck --lost-found`, the remote, a package registry | Committed or published states only |

3. **Recover the exact path from an application's bookmark data when the name is
   uncertain.** Apps that remember a chosen folder store a security-scoped
   bookmark in their preferences, and the path components sit in it as readable
   ASCII, which beats recalled spelling:

```sh
defaults export <app-bundle-id> - > prefs.plist    # then, in Python:
# plistlib.load(...) → walk values → for bytes values, extract ASCII runs and
# read the path components (e.g. Users|<user>|Desktop|<folder>)
```

4. **Report which source produced the answer and what it does not cover.** A
   snapshot restore returns the file as of a timestamp; say the timestamp, so the
   user knows what edits are still missing.

## Edge cases

| Case | Then |
|------|------|
| The volume is an external non-Apple SSD | TRIM is off by default for third-party AHCI drives (`trimforce(8)`), so free-space carving can still work — check `system_profiler SPStorageDataType`/`SPNVMeDataType` for that specific drive before ruling it in or out |
| The volume is a rotational HDD or a disk image | Carving is viable; stop writing to the volume immediately and image it before running any tool |
| `tmutil listlocalsnapshots` prints only the header line | There are no local snapshots for that volume; move to Time Machine and cloud sources rather than re-running it |
| The user is unsure whether the item was on Desktop or in a synced folder | Check the cloud provider's trash first — synced deletions are retained server-side for a provider-defined window even when the local copy is gone |
| The deleted item was a git working tree with uncommitted changes | Uncommitted content was never an object, so `fsck --lost-found` cannot return it; the copy sources above are the only route |
| Recovery attempts have already run and written to the volume | Record that in the report — later carving results become unreliable, which changes what a negative result means |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Recommend a file-recovery tool as the first step | Run the TRIM and snapshot checks first, and route to a copy source | With TRIM active the tool scans blocks the drive has already discarded, so a negative result costs time without narrowing anything |
| Ask the user to recall the exact folder name | Read the path from an app's bookmark blob, then confirm it with them | Recalled names drift by a character (`raycast-script` vs the stored `raycast-scripts`), and every path-based search then returns nothing |
| Report "unrecoverable" after the tool finds nothing | Report which sources were checked, with their timestamps | "No snapshot, no backup, no cloud copy" is an actionable statement; "the tool found nothing" is not |

## Sources

- `man tmutil` (macOS 15, Darwin 25.5.0) — `listlocalsnapshots mount_point`: "List local Time Machine snapshots of the specified volume"; `listlocalsnapshotdates`, `localsnapshot` for creation
- `man trimforce` (macOS 15) — "trimforce enables sending TRIM commands to third-party drives attached to an AHCI controller. By default, TRIM commands are not sent to third-party drives" — the basis for the third-party edge case
- Local verification 2026-08-18 (macOS 15, Darwin 25.5.0, APPLE SSD AP0512Z): `system_profiler SPNVMeDataType` reports "TRIM Support: Yes"; `tmutil listlocalsnapshots /System/Volumes/Data` runs and prints its header with no snapshots listed
- Field measurement 2026-08-18: with carving ruled out by the TRIM check, the deleted folder's exact path was recovered from Raycast's `NSOSPLastRootDirectory` bookmark blob as `Users|<user>|Desktop|raycast-scripts`, correcting the user's recalled `raycast-script`
