---
id: platforms-shells-warnings-on-stderr-with-exit-zero
domain: platforms
category: shells
applies_to: [bash, zsh, posix-sh]
confidence: verified
sources:
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
  - https://www.gnu.org/software/bash/manual/html_node/Redirections.html
  - https://code.claude.com/docs/en/hooks
last_verified: 2026-08-05
related: [platforms-shells-portable-shell-scripts, platforms-shells-command-text-inspected-before-execution]
---

# Feeding a Tool's Warnings Into a Gate When It Exits Zero

## When this applies

Wiring a compiler, linter, or build tool into an automated gate — a CI step, a
pre-commit check, or an agent hook (e.g. Claude Code `PostToolUse`) — and the
tool emits its warnings on stderr while still exiting 0. Also when such a gate
exists but warnings sail through it silently.

## Do this

1. **Branch on captured stderr, not on the exit code.** Warnings are by
   definition not failures, so most tools exit 0 when they emit them; a gate
   keyed on the exit code misses 100% of warnings and cannot tell "clean" from
   "warned".

2. **Capture stderr alone with `OUT=$(tool "$F" 2>&1 >/dev/null)`.** POSIX
   evaluates redirections "from beginning to end": `2>&1` first duplicates
   stderr onto the current stdout — which inside `$(...)` is the capture pipe —
   then `>/dev/null` discards the tool's own stdout. Build artifacts and IR
   printed to stdout stay out of the captured text.

3. **Distinguish three outcomes, not two:**

| Observed | Meaning | Gate action |
|----------|---------|-------------|
| exit ≠ 0 | Error | Fail the gate; forward stderr |
| exit 0, captured stderr non-empty | Warnings | Forward the warning text to the loop (below) |
| exit 0, captured stderr empty | Clean | Pass silently |

4. **In a Claude Code hook, return the text via exit 2 with the warnings on
   stderr.** The hooks contract: on exit 2 "stderr text is fed back to Claude as
   an error message". For `PostToolUse` the tool has already run, so exit 2 does
   not block — it shows the stderr to the model, which is exactly the feedback
   loop a warning needs.

## Edge cases

| Case | Then |
|------|------|
| The tool prints diagnostics to **stdout** instead | Verify where diagnostics go before wiring the gate: run one known-warning input and inspect both streams separately |
| The tool offers a `--werror`-style flag promoting warnings to failures | Prefer the flag when the policy is "warnings fail the build"; keep stderr capture when warnings should inform but not block |
| The gate must also preserve the tool's stdout for a later stage | Redirect stdout to a file instead of `/dev/null`: `OUT=$(tool "$F" 2>&1 >"$ART")` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Gate on `if tool "$F"; then ... fi` (exit code only) | Capture stderr and test it for content as well | Warnings exit 0; the exit-code gate passes them indistinguishably from clean runs |
| Write the capture as `2>/dev/null >&1` or `>/dev/null 2>&1` inside `$(...)` | `2>&1 >/dev/null` — stderr onto the capture pipe first, then discard stdout | Redirections apply left to right; the reversed order discards stderr or captures stdout, mixing build output into the feedback |

## Sources

- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html — 2.7 Redirection: "If more than one redirection operator is specified with a command, the order of evaluation is from beginning to end"
- https://www.gnu.org/software/bash/manual/html_node/Redirections.html — "Redirections are processed in the order they appear, from left to right", with the `ls > dirlist 2>&1` vs `ls 2>&1 > dirlist` example showing why the order matters
- https://code.claude.com/docs/en/hooks — exit 2: "stderr text is fed back to Claude as an error message"; PostToolUse cannot block ("the tool already ran") but shows stderr to Claude
- Local reproduction 2026-08-05 (`lnpl` compiler, macOS): warning input → rc=0 with 3 warnings on stderr; minimal clean input → rc=0, empty stderr; reserved-word error → rc=2 with errors on stderr — the three-way split above observed directly
