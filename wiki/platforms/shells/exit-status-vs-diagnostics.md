---
id: platforms-shells-exit-status-vs-diagnostics
domain: platforms
category: shells
applies_to: [bash, zsh, posix-sh]
confidence: verified
sources:
  - https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html
  - https://gcc.gnu.org/onlinedocs/gcc/Warning-Options.html
  - https://code.claude.com/docs/en/hooks
last_verified: 2026-08-05
related: [platforms-shells-portable-shell-scripts, testing-quality-checks-that-cannot-pass, platforms-processes-non-interactive-cli-invocation]
---

# A Wrapped Tool Reports Warnings on stderr and Exits 0

## When this applies

You are wrapping a compiler, linter, type checker, or validator in an automated
gate — a CI step, a git hook, or an agent tool-use hook — and the gate must
surface that tool's **warnings**, not only its hard failures. Also when a gate
you already wrote reports "clean" on a file the tool visibly complained about.

## Do this

1. **Decide from the diagnostic stream, not the exit status.** Capture stderr
   with stdout discarded, then branch on emptiness:

   ```sh
   OUT=$(tool "$f" 2>&1 >/dev/null)
   [ -n "$OUT" ] && { printf '%s\n' "$OUT" >&2; exit 2; }
   ```

2. **Write the redirections in that order.** They are evaluated left to right,
   so `2>&1` first duplicates stderr onto the *current* stdout (the capture),
   and `>/dev/null` then moves stdout away. Reversing them captures the tool's
   stdout — the build artifact or IR — and feeds that back as if it were a
   diagnostic.

3. **Map the three states the tool can be in**, and give each its own gate
   outcome:

| Tool state | Exit status | Captured stderr | Gate outcome |
|------------|-------------|-----------------|--------------|
| Clean | 0 | empty | pass silently |
| Diagnostics that are not failures (warnings, deprecations, lints) | 0 | non-empty | surface the text as the failure payload |
| Hard error | non-zero | non-empty | surface the text and fail |

4. **Emit the captured text on the gate's own stderr** and exit with the status
   the harness reads as "feed this back". For a Claude Code `PostToolUse` hook
   that status is 2 — "Shows stderr to Claude; the tool already ran" — so the
   model receives the warning text verbatim instead of a bare failure.

5. **Prove all three states before adopting the gate**: run it on a file with a
   warning, a clean file, and a file with a real error, and require the three
   distinct outcomes above ([testing-quality-checks-that-cannot-pass] owns the
   known-good-input discipline).

## Edge cases

| Case | Then |
|------|------|
| The tool writes diagnostics to **stdout** instead of stderr (some linters, `--format json` modes) | Capture stdout (`OUT=$(tool "$f" 2>/dev/null)`) after confirming which stream carries them on that version; check with `tool f 1>/dev/null` and `tool f 2>/dev/null` separately |
| The tool prints a progress or summary banner on stderr even when clean | Match the diagnostic shape rather than emptiness (`grep -E 'warning|error'`), and keep a clean-file run in the adoption check to prove the banner alone does not trip the gate |
| Warnings must not fail the gate, only be reported | Keep the same capture and print the text, exiting 0 — the capture is what makes the report possible either way |
| The tool is run through a pipeline (`tool f \| tee log`) | Capture into a variable or file first, then inspect; a pipeline reports the last command's status and the diagnostics land in the pipe |
| The tool offers `-Werror` / `--max-warnings 0` | Use it **in addition** — it converts the status, and the captured text is still what names which warning fired |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Gate on `if ! tool "$f"; then …` | Capture stderr and branch on whether it is empty | A warning is by definition not a failure, so the tool exits 0 and the gate never fires |
| Write `OUT=$(tool "$f" 2>/dev/null >&1)` | Write `OUT=$(tool "$f" 2>&1 >/dev/null)` | Redirections apply left to right; the reversed form discards stderr and captures the tool's stdout payload |
| Trust "the gate stayed quiet" as proof the file is clean | Run the gate once against a file you know produces a warning and require it to fire | A gate keyed on exit status is silent for the clean case and the warning case alike |

## Sources

- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html — Redirection: "If more than one redirection operator is specified with a command, the order of evaluation is from beginning to end"
- https://gcc.gnu.org/onlinedocs/gcc/Warning-Options.html — warnings are diagnostics that do not prevent compilation; `-Werror` exists precisely because they otherwise leave the exit status successful
- https://code.claude.com/docs/en/hooks — `PostToolUse` exit code 2: "Shows stderr to Claude; the tool already ran"
- Field reproduction 2026-08-05 (Apple clang, macOS): `cc -Wall -c w.c` with an unused variable → exit 0 with `warning: unused variable` on stderr; clean source → exit 0 with empty stderr; undeclared identifier → exit 1. Same run: `2>&1 >/dev/null` captured `STDERR-DIAG`, `2>/dev/null >&1` captured `STDOUT-PAYLOAD`
