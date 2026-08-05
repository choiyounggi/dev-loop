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
last_verified: 2026-08-05
related: [platforms-tools-bsd-vs-gnu-cli, platforms-toolchains-version-management, platforms-shells-command-text-inspected-before-execution]
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
   In POSIX sh there are no arrays — reorder the positional parameters in place, and
   write that loop **inline at the top level of the dispatcher**, never inside a
   helper function:

   ```sh
   n=$#; while [ "$n" -gt 0 ]; do a="$1"; shift
     case "$a" in --dry-run) DRY=1 ;; *) set -- "$@" "$a" ;; esac
     n=$((n-1)); done
   ```

   POSIX restores a function's caller positional parameters on return, so a helper's
   `set --` is discarded and the caller's `"$@"` still carries the flag as an operand.
6. Choose the quoting by what the text is, not by habit. Inside double quotes the
   backquote "shall retain its special meaning introducing … command substitution"
   and `$` still introduces expansion, so text quoting a command runs it. Wrap
   literal text — prose, error messages, anything containing a command example — in
   **single** quotes, and pass long bodies via a file (`--body-file`) rather than as
   an argument.
7. Run `shellcheck` on every script before it ships or gates anything; it flags
   unquoted expansions, bashisms under `#!/bin/sh`, and `set -e` blind spots.

## Edge cases

| Case | Then |
|------|------|
| `#!/bin/sh` script passes on macOS, fails on Debian/Ubuntu | Debian `sh` is dash (strict POSIX); macOS `sh` is bash in POSIX mode and forgives bashisms. Lint with `shellcheck --shell=sh` and test under dash |
| Critical command is in a pipeline but the interpreter is POSIX sh (no `pipefail`) | Run the critical command outside the pipeline (temp file between stages) and test `$?` directly |
| Script runs via cron/CI/hooks and commands are "not found" | Non-interactive shells load no rc files — no user PATH, no version-manager shims. Call binaries by absolute path (see platforms-toolchains-version-management) |
| `set -u` breaks on optional variables | Expand with an explicit default: `"${OPT:-}"` |
| A flag is parsed correctly but still appears among the operands | The reordering loop is inside a function. Flags set globals (which survive), operands are set positionally (which do not) — so detection works and the argument list stays wrong, with no error. Move the loop inline (step 5) |
| A payload argument begins with `-` | Pass it after a `--` separator (`cmd -- "$text"`); quoting does not help, because the option parser, not the shell, is what claims it |
| Message text must contain a command example | Single-quote the whole argument, or write the text to a file and pass the path — a double-quoted backtick executes and the message ships with the output spliced in |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Build a command string and `eval` it | Build an array and expand it: `cmd "${args[@]}"` | `eval` re-parses quotes and globs; arrays pass arguments through exactly |
| Put a command plus its flags in one variable and run `$cmd` | Variable holds the binary path only; flags are separate words | zsh runs the whole value as one command name; bash re-splits and re-globs it |
| Trust a trailing `echo "done"` as proof a step ran | Verify the produced state with an independent command | Inside `&&` chains and subshells, `set -e` misses failures and the echo still prints |
| Wrap POSIX-sh flag parsing in a `parse_flags "$@"` helper | Keep the `set --` reordering loop inline in the dispatcher | Positional parameters are restored when the function returns, so the caller runs with the original, unfiltered arguments |
| Accumulate POSIX-sh operands into a string to work around the missing array | Reorder `"$@"` in place with `set -- "$@" "$a"` | A string re-splits on whitespace, so a path containing a space becomes two operands |
| Double-quote a message that quotes a command | Single-quote it, or pass it with `--body-file` | `"…\`cmd\`…"` runs `cmd`, substitutes its output, and can exit 0 with the message silently gutted |

## Sources

- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html — POSIX shell quoting and field splitting (sections 2.2, 2.6.5)
- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html — 2.2.3 Double-Quotes: the backquote "shall retain its special meaning introducing the other form of command substitution" and `<dollar-sign>` "shall retain its special meaning introducing parameter expansion … command substitution … and arithmetic expansion"; 2.9.5 Function Definition Command: on return "the value of the special parameter `#` and the positional parameters shall be restored to the values they had before the function was executed"
- https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/V1_chap12.html — Utility Syntax Guideline 10: `--` delimits the end of options
- Reproduced 2026-08-05 under `/bin/sh` and `dash`: `parse_flags "$@"` left the caller with `argc=4` still containing `--dry-run`, while the identical loop inline gave `argc=3` with the space-bearing operand intact — `DRY=1` in both, so the flag was detected either way and only the operand list was wrong. In zsh, `echo "run: \`pip install -e .[dev]\` first"` printed `run:  first` after a `no matches found: .[dev]` error and still exited 0; the single-quoted form printed the text verbatim
- https://zsh.sourceforge.io/Doc/Release/Expansion.html — zsh: no word splitting of unquoted parameters (14.3); `=word` expansion (14.7.3)
- https://zsh.sourceforge.io/Doc/Release/Parameters.html — zsh arrays numbered from 1 (KSH_ARRAYS excepted)
- https://google.github.io/styleguide/shellguide.html — quote variables, prefer bash for scripts, arrays over eval
- https://www.shellcheck.net/ — shell script static analysis
