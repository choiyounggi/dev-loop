---
id: platforms-shells-redirection-order-for-a-silenced-write
domain: platforms
category: shells
applies_to: [bash, sh, zsh]
confidence: verified
sources:
  - https://www.gnu.org/software/bash/manual/bash.html#Redirections
  - https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html
last_verified: 2026-09-27
related: [platforms-processes-tool-diagnostics-without-a-failing-exit-code, platforms-shells-escapes-in-shell-string-literals, platforms-shells-portable-shell-scripts, platforms-tools-hook-input-fields-from-the-reference]
---

# Silencing a File Write That May Fail to Open

## When this applies

A script or hook writes a file that may not be writable (a state directory
with mode 555, a missing parent, a read-only mount) and must stay silent when
that happens; `cmd > "$file" 2>/dev/null` still prints `Permission denied` or
`No such file or directory` — with the local path — to stderr; a test that
asserts empty stderr fails on that line.

## Do this

1. **Wrap the command in a group and redirect the group's stderr:**
   `{ cmd > "$file"; } 2>/dev/null`. The shell opens `$file` while executing
   the inner command, after the group's `2>/dev/null` is already in effect, so
   its own "cannot open" diagnostic goes to `/dev/null`.
2. **Read the exit status from the group.** A failed redirection leaves `$?`
   at 1 in the braced form as well; under `set -e` the script exits there, so
   append `|| true` (or test `$?`) when the write is optional.

| Form | bash 3.2 / bash 5 / `sh` | zsh 5.9 |
|------|--------------------------|---------|
| `cmd > "$file" 2>/dev/null` | diagnostic leaks | diagnostic leaks |
| `cmd 2>/dev/null > "$file"` | silent | diagnostic leaks |
| `{ cmd > "$file"; } 2>/dev/null` | silent | silent |

3. **Pick the braced form whenever zsh may run the line** (an interactive
   macOS user's shell, a hook launched via `$SHELL`); reordering the
   redirections is enough for bash and POSIX `sh` only.

## Edge cases

| Case | Then |
|------|------|
| The write target is built from a path the user supplied | Silencing hides a typo in that path; log the failure to a location you do control (a fixed log file) inside the group, or check the directory with `[ -w "$dir" ]` before writing |
| The command is a pipeline (`gen \| cmd > "$file"`) | Group the whole pipeline: `{ gen \| cmd > "$file"; } 2>/dev/null`; a redirection on the last stage alone leaves earlier stages' stderr open |
| The script must keep the command's own stderr and drop only the open failure | Open the file first with `exec 3> "$file"` inside a group whose stderr is silenced, then run `cmd >&3`; the open and the command are now separate statements |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write `cmd > "$file" 2>/dev/null` | Write `{ cmd > "$file"; } 2>/dev/null` | Redirections apply left to right: `> "$file"` fails and prints before `2>/dev/null` exists |
| Fix it by reordering to `cmd 2>/dev/null > "$file"` | Use the braced group | The reorder silences bash and `sh`; zsh still prints its diagnostic |

## Sources

- https://www.gnu.org/software/bash/manual/bash.html#Redirections — "Redirections are processed in the order they appear, from left to right"
- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html — "If more than one redirection operator is specified with a command, the order of evaluation is from beginning to end"
- Local reproduction 2026-09-27 (macOS; target directory `chmod 555`): unwrapped form leaked `Permission denied` under `/bin/bash` 3.2.57, Homebrew bash 5.3.15, `/bin/sh`, and zsh 5.9; braced form was silent in all four; reordered form was silent in bash/`sh` and leaked in zsh; braced form exited 1 in bash and zsh, and terminated a `set -e` script unless followed by `|| true`
- Field evidence 2026-09 (memory-loop `correction-signal.bats` case 13, state dir `chmod 555`): `[ -z "$stderr" ]` failed with the unwrapped form and passed with the braced form under `/bin/bash` 3.2.57 and Homebrew bash
