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
  - https://github.com/apple-oss-distributions/text_cmds/blob/main/wc/wc.c
  - https://github.com/freebsd/freebsd-src/blob/main/usr.bin/wc/wc.c
  - https://www.gnu.org/software/coreutils/manual/html_node/wc-invocation.html
last_verified: 2026-10-11
related: [platforms-shells-portable-shell-scripts, platforms-environment-unicode-text-matching, platforms-filesystems-trailing-separator-under-realpath, platforms-shells-echo-of-text-you-did-not-write]
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
| Line count as a number | `wc -l < f` prints `398` | Prints `     398` — every count is right-aligned in a 7-wide field (`%7ju` in `wc.c`), also on stdin | Strip before use: `n=$(( $(wc -l < f) ))` or `n=$(wc -l < f \| tr -d ' ')`; then guard with `case "$n" in *[!0-9]*) exit 2;; esac` before handing it to `tail`/`sed` |

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
| A program (not a script) resolves `file/` through `realpath(3)`/`canonicalize` and the check passes on macOS but fails on Linux with `ENOTDIR` | The libc divergence, not the coreutils one: macOS `realpath` resolves a trailing slash on a regular file, glibc/musl reject it — decide the trailing-separator rule in code ([platforms-filesystems-trailing-separator-under-realpath]) |
| Script needs bash 4+ features on macOS | Stock `/bin/bash` on macOS is 3.2 — use `#!/usr/bin/env bash` so a brew-installed bash is picked up, and state the required bash version in the script header |
| A `wc -l` count is passed on as `tail -n +"$N"`, `sed -n "$N,…p"`, or compared as a string (`[ "$N" = 398 ]`, `case`) | On macOS the value is `     398`: `tail` fails with `illegal offset -- +     398`, and inside an `until`/`while` waiter that error repeats every tick while reading as "still waiting". Arithmetic contexts (`$(( ))`, `[ "$N" -eq 398 ]`) tolerate the spaces, which is why the same loop passes a numeric self-check and still fails at `tail`. Strip with the table row above; GNU `wc` prints no padding for a single stdin count, and its manual says "you should not depend on a particular field width" |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Hardcode GNU flags because the script passed in CI | Feature-detect the flavor or install coreutils on macOS | The same script runs on developers' BSD-userland Macs |
| Count list items by counting separators plus one | Count items directly (`wc -l` on newline-separated output) | BSD `seq`/`paste` trailing-separator behavior makes separator counts off-by-one |
| Port a failing command by trial-and-error flag swaps | Look the command up in the table above, or read both man pages | The differences are systematic, not random — the fix is per-command and known |
| Use `$(wc -l < f)` directly as an offset or in a string comparison | Wrap it in `$(( ))` or `tr -d ' '`, and assert all-digits | BSD `wc` pads every count to 7 columns; the padding survives into `tail -n +`, `sed -n`, and `=` while `-eq` hides it |

## Sources

- https://www.gnu.org/software/coreutils/manual/html_node/index.html — GNU date/timeout/seq/stat behavior
- https://man.freebsd.org/cgi/man.cgi?date(1) — BSD `date -v` adjustment flag
- https://man.freebsd.org/cgi/man.cgi?sed(1) — BSD `sed -i` backup-extension argument
- https://man.freebsd.org/cgi/man.cgi?seq(1) — BSD `seq -s` separator emitted after the last number (see man-page example)
- https://github.com/apple-oss-distributions/text_cmds/blob/main/wc/wc.c — macOS `wc` emits each count as `{:lines/%7ju/%ju}` (7-wide right-aligned field) for lines, words, characters and long-lines; the man page documents only "written to the standard output"
- https://github.com/freebsd/freebsd-src/blob/main/usr.bin/wc/wc.c — same `%7ju` format in FreeBSD
- https://www.gnu.org/software/coreutils/manual/html_node/wc-invocation.html — GNU: "The width of the count fields varies depending on the inputs, so you should not depend on a particular field width"
- Reproduction 2026-10-11 (macOS 26.1, 398-line file): `wc -l < f` printed `     398` and `tail -n +"$N" f` failed with `tail: illegal offset -- +     398: Invalid argument`; `$(( $(wc -l < f) ))` and `tr -d ' '` both yielded `398` and `tail` then printed line 398; `[ "$N" -eq 398 ]` passed on the padded value while `case "$N" in *[!0-9]*)` matched it as not-all-digits; GNU `gwc -l < f` printed `398`. Field case the same day: a background waiter looping on `tail -n +"$(wc -l < log)"` logged the `illegal offset` error every 10 s until the count was trimmed
