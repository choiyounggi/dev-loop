---
id: platforms-shells-zero-exit-diagnostics-into-a-hook
domain: platforms
category: shells
applies_to: [bash, zsh, posix-sh]
confidence: verified
sources:
  - https://code.claude.com/docs/en/hooks
  - https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html
last_verified: 2026-08-05
related: [platforms-shells-command-text-inspected-before-execution, platforms-shells-portable-shell-scripts, testing-quality-checks-that-cannot-pass]
---

# Feeding a Tool's Diagnostics to an Agent When the Tool Exits 0

## When this applies

You are wiring a compiler, linter, type checker, or validator into an agent loop
(a `PostToolUse` hook, a CI wrapper, a watch script) so its diagnostics reach the
model; and the tool prints warnings to stderr while exiting 0. Also when a hook
you wrote never fires although the tool clearly printed diagnostics, or the
feedback the model receives contains build output it should not see.

## Do this

1. **Decide on the stream, not the exit status, when the signal is a warning.**
   A warning is by definition not a failure, so the tool exits 0 and a hook that
   branches on `$?` cannot distinguish "clean" from "compiled with warnings".
   Capture stderr and treat non-empty as the trigger:

```sh
OUT=$(tool "$FILE" 2>&1 >/dev/null)
[ -z "$OUT" ] && exit 0
printf '%s\n' "$OUT" >&2
exit 2
```

2. **Write the redirections in the order `2>&1 >/dev/null`.** Redirections are
   evaluated left to right, and `2>&1` duplicates fd 2 onto *whatever fd 1 is at
   that moment*. Left-to-right gives: fd 2 → the capture pipe, then fd 1 →
   `/dev/null`. Only stderr survives into `$( )`.

| Written as | Captured | Use when |
|------------|----------|----------|
| `2>&1 >/dev/null` | stderr only | The tool writes its artifact/IR to stdout and its diagnostics to stderr |
| `2>&1` | stdout + stderr merged | The tool writes only diagnostics, or you want the whole transcript |
| `2>/dev/null >&1` | stdout only | Never for this purpose — the reversed order sends stderr to `/dev/null` and captures the build artifact instead |

3. **Return exit 2 to hand the text to the model.** For `PostToolUse`, exit 2
   "Shows stderr to Claude; the tool already ran". Every other non-zero code is a
   non-blocking error: the transcript shows a hook-error notice with only the
   **first line** of stderr, and the model does not receive the diagnostics.
4. **Put the diagnostics on stderr, not stdout.** On exit 0 the hook's stdout goes
   to the debug log and is not shown in the transcript for `PostToolUse`; only
   `UserPromptSubmit`, `UserPromptExpansion`, and `SessionStart` add stdout as
   context.
5. **Prove the wrapper discriminates before adopting it** — run it against an
   input with diagnostics and an input without, and require non-empty and empty
   respectively ([testing-quality-checks-that-cannot-pass]).

## Edge cases

| Case | Then |
|------|------|
| The tool also exits non-zero on hard errors | Keep both paths: capture stderr for the exit-0 warning case, and pass the error text through on non-zero too — one `exit 2` with the captured text covers both |
| The tool writes diagnostics to stdout instead of stderr | Capture with plain `2>&1` and filter by line shape (`grep -E '^(warning|error)'`); confirm which stream carries what by running the tool once with each stream discarded |
| stderr carries progress chatter as well as diagnostics | Filter the captured text before the emptiness test, so progress lines do not fire the hook on every run |
| The tool exits 0 and prints nothing on success but is slow | Keep the capture; an empty `$OUT` is the success signal and costs nothing |
| The wrapper runs under `set -e` | Command substitution failure inside `OUT=$(…)` is not suppressed by a condition context — assign first, test after, as above |
| A pipeline sits between the tool and the capture | Set `set -o pipefail` or capture into a variable and compare, so the tool's status is not replaced by the last stage's ([testing-quality-checks-that-cannot-pass]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Branch the hook on the tool's exit code | Capture stderr and branch on whether it is empty | Warnings exit 0 by design; an exit-code branch reports a warning-laden run as clean |
| Write `tool "$F" 2>/dev/null >&1` to "get stderr" | Write `tool "$F" 2>&1 >/dev/null` | Redirections evaluate left to right, so the reversed form discards stderr and captures the build artifact into the feedback |
| Exit 1 with the diagnostics on stderr | Exit 2 | For `PostToolUse` only exit 2 shows stderr to Claude; other codes surface one line to the user as a hook error |
| `echo` the diagnostics to stdout and exit 0 | Print to stderr and exit 2 | On exit 0 `PostToolUse` stdout goes to the debug log, not the transcript — the model never sees it |

## Sources

- https://code.claude.com/docs/en/hooks — `PostToolUse` runs "After a tool call succeeds"; exit-code-2 table row for `PostToolUse`: Can block? "No", "Shows stderr to Claude; the tool already ran". "Any other exit code is a non-blocking error for most hook events. The action proceeds, and the transcript shows a `<hook name> hook error` notice followed by the first line of stderr". On exit 0 "stdout is written to the debug log but not shown in the transcript" except for `UserPromptSubmit`, `UserPromptExpansion`, and `SessionStart`
- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html — "If more than one redirection operator is specified with a command, the order of evaluation is from beginning to end"; `[n]>&word` "shall duplicate one output file descriptor from another", making fd n "a copy of the file descriptor denoted by word"

## Field context

Measured 2026-08-05 (bash 3.2, macOS) with a stub that writes an artifact line to
stdout, one `warning:` line to stderr, and exits 0. `2>&1 >/dev/null` captured
only `warning: unused variable x`; `2>/dev/null >&1` captured only
`BUILD-ARTIFACT-ON-STDOUT`; plain `2>&1` captured both; the exit-code branch saw
`rc=0` in every case. A diagnostic-free stub captured the empty string, giving the
clean/dirty discrimination the hook depends on. Originally observed wiring
`lnpl compile` (rc=0 with 3 stderr warnings; rc=2 with stderr errors on a
reserved word) into a `PostToolUse` hook.
