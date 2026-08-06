---
id: platforms-processes-tool-diagnostics-without-a-failing-exit-code
domain: platforms
category: processes
applies_to: [general]
confidence: verified
sources:
  - https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html
  - https://clang.llvm.org/docs/UsersManual.html
  - https://www.gnu.org/software/bash/manual/bash.html#Redirections
  - https://code.claude.com/docs/en/hooks
last_verified: 2026-08-06
related: [platforms-processes-non-interactive-cli-invocation, platforms-shells-command-text-inspected-before-execution, testing-quality-checks-that-cannot-pass]
---

# Feeding a Tool's Warnings Back When It Exits 0

## When this applies

You are wiring a compiler, linter, type checker, or validator into a hook, CI
step, or agent loop so its diagnostics reach the author; and the tool prints
warnings to stderr while exiting 0. Also when a gate you wrote never fires
although the tool clearly printed diagnostics, or the feedback reaches the model
containing build artifacts it should not see.

## Do this

1. **Decide from the diagnostic stream, not the exit status, when the signal is
   a warning.** A warning is by definition not a failure, so most tools exit 0
   when they emit warnings. A gate that branches on the exit code misses 100% of
   warnings and cannot distinguish "clean" from "warned".

2. **Capture stderr alone with `OUT=$(tool "$F" 2>&1 >/dev/null)`.** POSIX
   evaluates redirections "from beginning to end": `2>&1` first duplicates
   stderr onto the current stdout — which inside `$(...)` is the capture pipe —
   then `>/dev/null` discards the tool's own stdout. Build artifacts and IR
   printed to stdout stay out of the captured text.

```sh
OUT=$(tool "$FILE" 2>&1 >/dev/null)
[ -n "$OUT" ] && printf '%s\n' "$OUT" >&2 && exit 2
```

3. **Distinguish three outcomes explicitly** — clean, warned, failed — and emit
   a different signal for each. A wrapper with two branches cannot tell
   "nothing to say" from "said something the exit code did not encode":

| Observed | Read it as | Wrapper does |
|----------|------------|--------------|
| exit 0, captured stderr empty | Clean | Pass silently |
| exit 0, captured stderr non-empty | Warned — the case an exit-code-only wrapper loses | Surface the text to the author; choose block or advise per gate policy |
| exit non-zero | Failed | Surface the text and block |

4. **For a Claude Code hook, return exit 2 with the text on stderr.** The
   hooks contract: on exit 2 "stderr text is fed back to Claude as an error
   message". For `PostToolUse` the tool has already run, so exit 2 does not
   block — it shows the stderr to the model, which is exactly the feedback loop
   a warning needs.

5. **Prefer the tool's own promotion switch when you own the invocation and want
   a hard gate**: `-Werror` (clang/gcc), `--max-warnings 0` (ESLint), `--strict`
   equivalents. Then the exit code carries the decision again and the wrapper
   stays a one-liner. Use stream capture when you must keep warnings non-fatal
   for humans while still surfacing them to the loop.

6. **Prove all three states before adopting the gate.** Run it on a file with a
   warning, a clean file, and a file with a real error, and require the three
   distinct outcomes above. Keep the control inputs in the repo so contributors
   cannot drift the gate ([testing-quality-checks-that-cannot-pass]).

## Edge cases

| Case | Then |
|------|------|
| The tool writes diagnostics to **stdout** instead of stderr (some linters, `--format json` modes) | Capture stdout (`OUT=$(tool "$f" 2>/dev/null)`) after confirming which stream carries them; run the tool once with each stream discarded to confirm |
| The tool prints a progress or summary banner on stderr even when clean | Match the diagnostic shape (`grep -E 'warning|error'`) rather than emptiness; keep a clean-file run in the adoption check to prove the banner alone does not trip the gate |
| Warnings must not fail the gate, only be reported | Keep the same capture and print the text, exiting 0 — the capture is what makes the report possible either way |
| The tool is run through a pipeline (`tool f \| tee log`) | Capture into a variable or file first, then inspect; a pipeline reports the last command's status and the diagnostics land in the pipe |
| The tool offers `-Werror` / `--max-warnings 0` | Use it **in addition** — it converts the status, and the captured text is still what names which warning fired |
| The wrapper runs under `set -e` | Command substitution failure inside `OUT=$(…)` is not suppressed by a condition context — assign first, test after, as above |
| Warnings must not repeat on every run of an unchanged file | Hash `$OUT` per file and forward only on change; an unconditional exit 2 re-feeds the same text each time |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Branch the hook on the tool's exit code | Capture stderr and branch on whether it is empty | Warnings are by definition not failures, so the tool exits 0 and the gate never fires |
| Write `OUT=$(tool "$F" 2>/dev/null >&1)` to "get stderr" | Write `OUT=$(tool "$F" 2>&1 >/dev/null)` | Redirections apply left to right; the reversed form discards stderr and captures the tool's stdout payload |
| Trust "the gate stayed quiet" as proof the file is clean | Run the gate once against a file you know produces a warning and require it to fire | A gate keyed on exit status is silent for both the clean case and the warning case |
| Exit 1 with the diagnostics on stderr | Exit 2 | For `PostToolUse` only exit 2 shows stderr to Claude; other codes surface one line to the user as a hook error |
| Put diagnostics on stdout and exit 0 | Print to stderr and exit 2 | On exit 0 `PostToolUse` stdout goes to the debug log, not the transcript — the model never sees it |

## Sources

- https://pubs.opengroup.org/onlinepubs/9799919799/utilities/V3_chap02.html — Redirection: "If more than one redirection operator is specified with a command, the order of evaluation is from beginning to end"
- https://clang.llvm.org/docs/UsersManual.html — warnings are diagnostics that do not prevent compilation; `-Werror` exists precisely because they otherwise leave the exit status successful
- https://www.gnu.org/software/bash/manual/bash.html#Redirections — "Redirections are processed in the order they appear, from left to right", with the `ls > dirlist 2>&1` vs `ls 2>&1 > dirlist` example
- https://code.claude.com/docs/en/hooks — exit 2: "stderr text is fed back to Claude as an error message"; `PostToolUse` cannot block ("the tool already ran") but shows stderr to Claude
- Field reproduction 2026-08-05: compiler with warning input → exit 0 with 3 warnings on stderr; clean input → exit 0 with empty stderr; error → non-zero exit with errors; the three outcomes observed directly when the gate was tested
- Local reproduction 2026-08-06 (macOS, Apple clang): `cc -Wall` on a snippet with an unused variable → exit 0, 157 bytes on stderr; `OUT=$(cc … 2>&1 >/dev/null)` captured the diagnostic while the reversed redirection order captured 0 chars
