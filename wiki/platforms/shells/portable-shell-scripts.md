---
id: platforms-shells-portable-shell-scripts
domain: platforms
category: shells
applies_to: [bash, zsh, posix-sh]
confidence: verified
sources:
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
  - https://zsh.sourceforge.io/Doc/Release/Expansion.html
  - https://zsh.sourceforge.io/Doc/Release/Parameters.html
  - https://google.github.io/styleguide/shellguide.html
  - https://www.shellcheck.net/
last_verified: 2026-07-10
related: [platforms-tools-bsd-vs-gnu-cli, platforms-toolchains-version-management]
---

# Shell Scripts That Must Run on More Than One Machine or Shell

## When this applies

Writing a shell script that will run on more than one machine, OS, shell, or in CI;
or a script that works locally fails elsewhere (different shell, different `sh`,
non-interactive environment).

## Do this

1. Declare the interpreter for the features you use:

| Case | Do |
|------|----|
| Script uses bash features (arrays, `[[ ]]`, `local`, `pipefail`) | Shebang `#!/usr/bin/env bash` — never `#!/bin/sh` |
| Target machines may lack bash (Alpine, minimal containers) | Write POSIX sh only — no arrays, no `[[ ]]`, no `local` — with shebang `#!/bin/sh`, and lint with `shellcheck --shell=sh` |
| Snippet will be sourced into users' interactive shells (bash *and* zsh users) | Keep to the POSIX subset both parse; test by sourcing in each shell |

2. Quote every expansion: `"$var"`, `"$(cmd)"`, `"${arr[@]}"`. In bash/sh, unquoted
   expansions word-split on whitespace and glob-expand — a filename with a space or
   `*` corrupts the argument list.
3. Start bash scripts with `set -euo pipefail`, and know its limits: `set -e` is
   suppressed for commands run inside condition contexts (`if cmd`, `cmd && x`,
   `cmd || x`, `while cmd`) and inside some subshells — a failed command there does
   not stop the script. After every state-changing command (file/branch/worktree
   creation), verify the state with an independent command (`test -e`, `git worktree
   list`), not with a following `echo` that prints success unconditionally.
4. When a script written for bash runs in zsh (or a user pastes it into a zsh
   terminal), these behaviors invert:

| Behavior | bash/sh | zsh | Portable action |
|----------|---------|-----|-----------------|
| Unquoted `$var` holding `cmd -flag` | Splits into `cmd` + `-flag` | Stays one word — runs `cmd -flag` as a single command name and fails `no such file` | Store only the binary path in the variable; pass flags as separate literal words or an array: `"$BIN" -C "$dir" init` |
| Word starting with `=` (e.g. `echo ===`) | Literal `===` | `=word` expands to a command's path — bare `===` errors `== not found` and aborts the compound command | Use an alphabetic separator string (`echo SEP`) or quote it (`echo '==='`) |
| Array indexing | 0-based | 1-based (unless `KSH_ARRAYS`) | Iterate with `"${arr[@]}"`; when a numeric index is unavoidable, gate the script to one shell via the shebang |

5. Build argument lists as arrays and expand quoted: `args=(-o "$out"); cmd "${args[@]}"`.
6. Run `shellcheck` on every script before it ships or gates anything; it flags
   unquoted expansions, bashisms under `#!/bin/sh`, and `set -e` blind spots.

## Edge cases

| Case | Then |
|------|------|
| `#!/bin/sh` script passes on macOS, fails on Debian/Ubuntu | Debian `sh` is dash (strict POSIX); macOS `sh` is bash in POSIX mode and forgives bashisms. Lint with `shellcheck --shell=sh` and test under dash |
| Critical command is in a pipeline but the interpreter is POSIX sh (no `pipefail`) | Run the critical command outside the pipeline (temp file between stages) and test `$?` directly |
| Script runs via cron/CI/hooks and commands are "not found" | Non-interactive shells load no rc files — no user PATH, no version-manager shims. Call binaries by absolute path (see platforms-toolchains-version-management) |
| `set -u` breaks on optional variables | Expand with an explicit default: `"${OPT:-}"` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Build a command string and `eval` it | Build an array and expand it: `cmd "${args[@]}"` | `eval` re-parses quotes and globs; arrays pass arguments through exactly |
| Put a command plus its flags in one variable and run `$cmd` | Variable holds the binary path only; flags are separate words | zsh runs the whole value as one command name; bash re-splits and re-globs it |
| Trust a trailing `echo "done"` as proof a step ran | Verify the produced state with an independent command | Inside `&&` chains and subshells, `set -e` misses failures and the echo still prints |

## Sources

- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html — POSIX shell quoting and field splitting (sections 2.2, 2.6.5)
- https://zsh.sourceforge.io/Doc/Release/Expansion.html — zsh: no word splitting of unquoted parameters (14.3); `=word` expansion (14.7.3)
- https://zsh.sourceforge.io/Doc/Release/Parameters.html — zsh arrays numbered from 1 (KSH_ARRAYS excepted)
- https://google.github.io/styleguide/shellguide.html — quote variables, prefer bash for scripts, arrays over eval
- https://www.shellcheck.net/ — shell script static analysis
