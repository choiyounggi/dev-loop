---
id: platforms-filesystems-paths-case-and-line-endings
domain: platforms
category: filesystems
applies_to: [macos, windows, linux]
confidence: verified
sources:
  - https://support.apple.com/guide/disk-utility/file-system-formats-dsku19ed921c/mac
  - https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file
  - https://git-scm.com/docs/gitattributes
last_verified: 2026-07-10
related: [platforms-shells-portable-shell-scripts]
---

# Files That Break When a Repo Moves Between macOS, Windows, and Linux

## When this applies

Code or a repo moves across macOS/Windows/Linux and: files "disappear" or collide,
imports resolve on one OS and fail on another, diffs show every line changed,
a script fails with `bad interpreter`, or generated paths break on Windows.

## Do this

1. Know the case-sensitivity of each target filesystem:

| Filesystem | Case behavior |
|------------|---------------|
| macOS APFS (default format) | Case-INsensitive, case-preserving |
| Windows NTFS (default) | Case-insensitive |
| Linux (ext4 and defaults) | Case-SENSITIVE |

2. Write every import/require/open path with the file's exact on-disk casing.
   `import './Button'` resolving against `button.tsx` passes on macOS and Windows
   and breaks on the Linux CI runner and prod — the laptop never catches it.
3. Renaming only the casing of a tracked file on macOS/Windows: use a two-step
   rename — `git mv Button.tsx tmp && git mv tmp button.tsx`. A direct
   same-name-different-case rename on a case-insensitive filesystem leaves the old
   casing in the index (`core.ignorecase` hides the change).
4. Line endings: commit LF and enforce it repo-side with a committed
   `.gitattributes` containing `* text=auto eol=lf` (plus explicit rules for
   binaries and CRLF-required files). Repo-side attributes beat per-developer
   `core.autocrlf` settings, which drift per machine.
5. When a shell script fails on Linux with `bad interpreter: /bin/bash^M`, the file
   has CRLF endings — the `^M` is the carriage return glued to the shebang.
   Normalize the file to LF and fix the `.gitattributes` rule that let it in.
6. Build paths in code with the language's path API (`path.join`, `pathlib`,
   `filepath.Join`), which supplies the platform's separator and normalization.
7. When generating file names (exports, slugs, cache keys), exclude what Windows
   rejects: reserved device names (`CON`, `PRN`, `AUX`, `NUL`, `COM1`–`COM9`,
   `LPT1`–`LPT9` — with any extension), reserved characters `< > : " / \ | ? *`,
   and trailing dots or spaces.
8. Keep generated directory trees shallow: Windows caps paths at 260 characters
   (`MAX_PATH`) by default.

## Edge cases

| Case | Then |
|------|------|
| Two files differing only by case were committed from Linux | Checkout on macOS/Windows collapses them into one file and the tree looks corrupted — rename so every path is case-unique |
| `.gitattributes` added to an existing repo | Run `git add --renormalize . && git commit` — already-committed CRLF blobs stay until renormalized |
| A file must keep CRLF (`.bat`, `.ps1` consumed by cmd) | Per-pattern override in `.gitattributes`: `*.bat text eol=crlf` |
| Long paths are unavoidable on a Windows target | The 260 limit is removable via registry/Group Policy and the `\\?\` prefix, but tools without long-path support still fail — shallow trees remain the fix that works everywhere |
| Case-renamed file loops as modified/untracked in git | `git config core.ignorecase` disagrees with the filesystem — redo the rename as two steps and leave `core.ignorecase` at git's auto-detected value |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Ask every developer to set `core.autocrlf` | Commit `.gitattributes` with `* text=auto eol=lf` | Attributes travel with the repo; per-machine config drifts and new clones miss it |
| Concatenate paths with `/` or `\\` literals | Use the language's path API | Separators, drive prefixes, and normalization differ per OS |
| Fix a broken import by renaming the file in Finder/Explorer | Two-step `git mv` | On a case-insensitive filesystem the case-only rename never reaches the git index |

## Sources

- https://support.apple.com/guide/disk-utility/file-system-formats-dsku19ed921c/mac — APFS default is case-insensitive; case-sensitive is a separate format
- https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file — Windows reserved names, reserved characters, trailing dot/space rule, MAX_PATH 260
- https://git-scm.com/docs/gitattributes — `text=auto`, `eol=lf`, renormalization workflow
