---
id: platforms-processes-tool-diagnostics-without-a-failing-exit-code
domain: platforms
category: processes
applies_to: [general]
confidence: verified
sources:
  - https://clang.llvm.org/docs/UsersManual.html
  - https://www.gnu.org/software/bash/manual/bash.html#Redirections
  - https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
last_verified: 2026-08-05
related: [platforms-processes-non-interactive-cli-invocation, platforms-shells-command-text-inspected-before-execution, debugging-signals-reading-error-messages]
---

# Feeding a Tool's Warnings Back When It Exits 0

## When this applies

You are wiring a compiler, linter, type checker, or validator into a hook, CI
step, or agent loop so its complaints reach the author. The tool prints
diagnostics but exits 0 for anything it classifies below "error", so a wrapper
that branches on the exit code reports success on a file that was warned about.

## Do this

1. **Decide what the wrapper treats as failure, then read the channel that
   carries it.** An exit code answers "did the tool refuse to finish"; it does
   not answer "did the tool have something to say". Warnings are by definition
   not failures, so a tool that emits them still exits 0.
2. **Capture the diagnostic stream without swallowing the artifact:**

```sh
OUT=$(tool "$FILE" 2>&1 >/dev/null)   # stderr -> current stdout, then stdout -> /dev/null
[ -n "$OUT" ] && printf '%s\n' "$OUT" >&2 && exit 2
```

   Redirections are applied left to right, so `2>&1 >/dev/null` duplicates
   stderr onto the terminal/pipe stdout currently points at and *then* discards
   stdout. The reversed spelling `>/dev/null 2>&1` sends both to `/dev/null` and
   captures nothing.

3. **Prefer the tool's own promotion switch when you own the invocation and want
   a hard gate**: `-Werror` (clang/gcc), `--max-warnings 0` (ESLint),
   `--strict` equivalents. Then the exit code carries the decision again and the
   wrapper stays a one-liner. Use stream capture when you must keep warnings
   non-fatal for humans while still surfacing them to the loop.
4. **Distinguish the three outcomes explicitly** — clean, warned, failed — and
   emit a different signal for each. A wrapper with two branches cannot tell
   "nothing to say" from "said something the exit code did not encode".

| Observed | Read it as | Wrapper does |
|----------|------------|--------------|
| exit 0, diagnostic stream empty | Clean | Pass silently |
| exit 0, diagnostic stream non-empty | Warned — the case an exit-code-only wrapper loses | Surface the text to the author; choose block or advise per your gate policy |
| exit non-zero | Failed | Surface the text and block |

5. **Keep the exit code readable end to end.** When the wrapper's own exit code
   is a decision, do not pipe it into `head`/`tail`/`grep` — the pipeline's status
   is the last command's. Capture to a variable or read `${PIPESTATUS[0]}`.

## Edge cases

| Case | Then |
|------|------|
| The tool writes diagnostics to stdout, mixed with its real output | Prefer a machine-readable flag (`--format json`, `--output-file`) and parse the diagnostics field; when none exists, send the artifact to a file (`-o out.bin`) so the remaining stream is diagnostics only |
| Diagnostics include absolute paths, timings, or ids that change per run | Strip the volatile fields before comparing runs; an unstable string makes "did anything change" untestable |
| The tool prints a banner or progress line on stderr even when clean | Match on the diagnostic form (a `warning:`/`error:` prefix, a non-empty JSON array), not on stream non-emptiness |
| The wrapper runs on every save and the tool is slow | Gate on the changed file only, and bound the call with a timeout so a hung tool fails the step rather than the session ([platforms-processes-non-interactive-cli-invocation]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Branch a hook solely on `$?` from a compiler or linter | Read the diagnostic stream, and branch on the exit code only for hard failures | Warnings are defined as non-failures, so the exit code is 0 for every one of them |
| Write `tool "$F" 2>/dev/null >&1` to keep stderr | Write `tool "$F" 2>&1 >/dev/null` | The reversed order points stderr at the old stdout and then keeps stdout, so the captured text is the tool's artifact, not its diagnostics |
| Add `-Werror` to a shared build so a hook can use the exit code | Capture the stream in the hook, and keep `-Werror` a deliberate build policy decision | Promoting every warning changes what the build rejects for everyone, to fix a wrapper's read of one stream |

## Sources

- https://clang.llvm.org/docs/UsersManual.html — diagnostics are emitted at levels (ignored / warning / error / fatal); warnings do not produce a non-zero exit status unless promoted with `-Werror`, and clang warns rather than errors on flags it has not implemented
- https://www.gnu.org/software/bash/manual/bash.html#Redirections — "Redirections are processed in the order they appear, from left to right", which is why `2>&1 >/dev/null` and `>/dev/null 2>&1` capture different streams
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html — a pipeline's exit status is that of its last command, so a decision-bearing status must be read before piping
- Local reproduction 2026-08-05: the same CLI returned rc=0 with three `warning:` lines on stderr for one input, rc=0 with an empty stderr for a clean input, and rc=2 with an error for a rejected input — the three cases are distinguishable only by reading both the code and the stream
