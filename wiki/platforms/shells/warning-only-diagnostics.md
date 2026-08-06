---
id: platforms-shells-warning-only-diagnostics
domain: platforms
category: shells
applies_to: [bash, zsh, posix-sh]
confidence: verified
sources:
  - https://code.claude.com/docs/en/hooks
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
last_verified: 2026-08-06
related: [platforms-shells-command-text-inspected-before-execution, platforms-shells-portable-shell-scripts]
---

# Warnings a Tool Emits on stderr While Exiting 0, Wired into an Automated Gate

## When this applies

A hook, CI step, or wrapper script must react to a compiler/linter/validator's
warnings, but the tool prints them to stderr and still exits 0 (warnings are by
convention not failures); or a feedback hook stays silent even though the tool
visibly printed diagnostics.

## Do this

1. **Branch on captured stderr, not on the exit code.** Exit 0 with a non-empty
   stderr is the normal warning state; an exit-code-only gate misses every
   warning and cannot tell "clean" from "warned". Reserve the exit code for
   distinguishing hard failures.

2. **Capture stderr only, with the redirections in this order:**

   ```sh
   OUT=$(tool "$FILE" 2>&1 >/dev/null); RC=$?
   ```

   POSIX evaluates redirections "from beginning to end": `2>&1` first duplicates
   stderr onto the current stdout — which the command substitution is capturing —
   then `>/dev/null` re-points stdout (the tool's build output/IR) away. The
   reversed order `2>/dev/null >&1` discards the diagnostics and captures the
   product instead.

3. **Map the three observable states, each to its own action:**

| State | Meaning | Gate action |
|-------|---------|-------------|
| `RC != 0` | Hard failure (errors) | Fail the gate; forward `$OUT` |
| `RC = 0`, `$OUT` non-empty | Tool succeeded with warnings | Forward `$OUT` as feedback without failing the build/tool call |
| `RC = 0`, `$OUT` empty | Clean pass | Stay silent |

4. **In a Claude Code `PostToolUse` hook, forward warnings by printing `$OUT` to
   stderr and exiting 2.** A hook that exits 0 sends stderr to the debug log
   only — the model never sees it; exit 2 "shows stderr to Claude" while the
   tool call itself already ran, which is exactly the warn-don't-block shape.

## Edge cases

| Case | Then |
|------|------|
| The tool mixes warnings into stdout instead of stderr | Capture both streams separately (`2>err.tmp >out.tmp`) and grep the warning pattern per stream once, then encode which stream that tool uses |
| The tool has a strict mode (`-Werror`, `--max-warnings 0`) | Use it when the gate should fail on warnings — the exit code then carries the signal and step 2's capture is only needed for the message text |
| Warnings must not repeat on every run of an unchanged file | Hash `$OUT` per file and forward only on change; an unconditional exit 2 re-feeds the same text each time |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Gate on `if ! tool "$FILE"` | Capture stderr (step 2) and branch on the three states | Warning runs exit 0, so the branch never fires and warnings pass silently |
| Write `2>/dev/null >&1` (or `>&2 2>/dev/null`) to "grab stderr" | `2>&1 >/dev/null`, in that order | Redirections apply left to right; the reversed order captures the tool's stdout product and throws the diagnostics away |
| Print hook feedback to stdout with exit 0 | Print to stderr and exit 2 (PostToolUse) | Exit-0 hook stderr goes to the debug log only; the model sees the message on exit 2 |

## Sources

- https://code.claude.com/docs/en/hooks — PostToolUse cannot block ("the tool already ran"); exit 2 "shows stderr to Claude"; exit-0 stderr "goes to the debug log only, never the transcript"
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html — 2.7 Redirection: "the order of evaluation is from beginning to end"
- Local reproduction 2026-08-06 (macOS, Apple clang): `cc -Wall` on a snippet with an unused variable → exit 0, 157 bytes on stderr; `OUT=$(cc … 2>&1 >/dev/null)` captured the 156-char diagnostic; the reversed order captured 0 chars. Field origin 2026-08-06 (`linkly`, `lnpl compile`): warnings → rc 0 + stderr text, clean file → rc 0 + empty stderr, reserved-word error → rc 2 — three states distinguished only by this capture
