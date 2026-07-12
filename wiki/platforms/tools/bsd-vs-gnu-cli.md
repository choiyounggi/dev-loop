---
id: platforms-tools-bsd-vs-gnu-cli
domain: platforms
category: tools
applies_to: [macos, linux]
confidence: verified
sources:
  - https://www.gnu.org/software/coreutils/manual/html_node/index.html
  - https://man.freebsd.org/cgi/man.cgi?date(1)
  - https://man.freebsd.org/cgi/man.cgi?sed(1)
  - https://man.freebsd.org/cgi/man.cgi?seq(1)
last_verified: 2026-07-10
related: [platforms-shells-portable-shell-scripts]
---

# Same Command Name, Different Userland: BSD (macOS) vs GNU (Linux) Flags

## When this applies

A shell command works on Linux but fails on macOS or vice versa (`illegal option`,
silently different output); or you are writing a script/CI step that must run on both.

## Do this

macOS ships BSD userland; Linux ships GNU coreutils. The command names match, the
flags do not. Apply the portable fix per command:

| Command | GNU (Linux) | BSD (macOS) | Portable fix |
|---------|-------------|-------------|--------------|
| Relative date | `date -d '5 minutes ago'` | `date -v-5M` | Feature-detect with a fallback chain: `date -d '5 minutes ago' 2>/dev/null \|\| date -v-5M`; or compute epoch math: `$(( $(date +%s) - 300 ))` then format |
| In-place sed | `sed -i 's/a/b/' f` (bare `-i`) | `-i` takes a backup-extension argument (`sed -i '' 's/a/b/' f`) | `sed -i.bak 's/a/b/' f && rm f.bak` (no space before `.bak` — parses on both), or `perl -pi -e 's/a/b/' f` |
| `timeout` | In coreutils | Absent on stock macOS — exits 127 | Install coreutils and call `gtimeout`, or background the command and `kill` it from a sleep watchdog |
| `seq -s,` | Separator between numbers only | Separator also emitted after the last number, before the terminator | Join after generating (`seq 1 3 \| paste -sd, -`) and count items by lines, never by separators |
| PCRE grep | `grep -P` | Not supported | `grep -E` with ERE, or `perl -ne 'print if /…/'` |
| Resolve path | `readlink -f` | Absent before macOS 13 | `cd "$(dirname "$f")" && pwd -P` for directories, `python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))'`, or coreutils `greadlink -f` |
| File metadata | `stat -c '%s'` | `stat -f '%z'` | Detect once: `stat -c %s "$f" 2>/dev/null \|\| stat -f %z "$f"` |

General strategy by situation:

| Case | Do |
|------|----|
| Script must run unchanged on both OSes | Restrict to POSIX-specified flags — check the POSIX utility page, not your local man page, since the local page documents only one flavor |
| macOS machine, GNU behavior wanted | `brew install coreutils gnu-sed` → g-prefixed binaries (`gdate`, `gsed`, `gtimeout`); detect with `command -v gdate` and use the g-form when present |
| One-off command on a known machine | Read that machine's own `man` page before running — memory of the other flavor produces the wrong flags |
| Script developed on macOS will gate CI or other machines | Run it on Linux (container or the runner) before it gates anything — CI runners are Linux, and macOS-only testing does not validate GNU behavior |

## Edge cases

| Case | Then |
|------|------|
| `command -v timeout` succeeds on macOS | Someone installed coreutils unprefixed — confirm `timeout --version` reports GNU coreutils before relying on GNU exit-code semantics (124 on timeout) |
| Any flags passed to `echo` (`-e`, `-n`) | `echo` flag handling differs across shells and userlands — use `printf` for anything beyond a bare literal string |
| Script needs bash 4+ features on macOS | Stock `/bin/bash` on macOS is 3.2 — use `#!/usr/bin/env bash` so a brew-installed bash is picked up, and state the required bash version in the script header |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Hardcode GNU flags because the script passed in CI | Feature-detect the flavor or install coreutils on macOS | The same script runs on developers' BSD-userland Macs |
| Count list items by counting separators plus one | Count items directly (`wc -l` on newline-separated output) | BSD `seq`/`paste` trailing-separator behavior makes separator counts off-by-one |
| Port a failing command by trial-and-error flag swaps | Look the command up in the table above, or read both man pages | The differences are systematic, not random — the fix is per-command and known |

## Sources

- https://www.gnu.org/software/coreutils/manual/html_node/index.html — GNU date/timeout/seq/stat behavior
- https://man.freebsd.org/cgi/man.cgi?date(1) — BSD `date -v` adjustment flag
- https://man.freebsd.org/cgi/man.cgi?sed(1) — BSD `sed -i` backup-extension argument
- https://man.freebsd.org/cgi/man.cgi?seq(1) — BSD `seq -s` separator emitted after the last number (see man-page example)
