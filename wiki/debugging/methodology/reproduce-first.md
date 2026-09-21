---
id: debugging-methodology-reproduce-first
domain: debugging
category: methodology
applies_to: [general]
confidence: verified
sources:
  - https://sscce.org/
  - https://www.debuggingbook.org/html/DeltaDebugger.html
  - https://sre.google/sre-book/effective-troubleshooting/
  - https://github.com/mattpocock/skills/blob/main/skills/engineering/diagnosing-bugs/SKILL.md
  - https://www.gnu.org/software/bash/manual/html_node/Aliases.html
  - https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html
  - https://zsh.sourceforge.io/Doc/Release/Files.html
  - https://en.wikipedia.org/wiki/Regression_testing
last_verified: 2026-09-06
related: [debugging-methodology-hypothesis-testing, debugging-concurrency-intermittent-failures, debugging-signals-logs-and-correlation, platforms-environment-path-resolution, qa-process-completion-claims, debugging-methodology-probe-path-vs-operation-path]
---

# Building a Reproduction Before Investigating a Bug

## When this applies

A bug is reported or observed behavior is wrong, and you are about to investigate
or fix it. Covers user bug reports, wrong output, failing behavior in any
environment — the entry point of every debugging session.

## Do this

1. Reproduce the failure yourself before changing any code. A report contains
   symptoms plus the reporter's interpretation; only a reproduction separates the
   two. The reproduction defines "fixed": if you cannot trigger the bug, you cannot
   demonstrate its absence.
2. Shrink the reproduction: remove inputs, config, flags, dependencies, and steps
   one piece at a time, keeping each removal only while the bug still occurs.
   Stop when removing anything makes the bug vanish — that is the minimal
   reproduction, and every remaining element is implicated in the cause.
3. Capture the minimal reproduction as a runnable artifact — a failing automated
   test when the bug lives in code you test, a script when it needs external
   services. This artifact verifies the fix and becomes the regression test.
   Build it to a tight loop: **red-capable** (asserts the exact symptom, not
   merely "didn't crash"), **deterministic** (same verdict every run), **fast**
   (seconds, not minutes), and **agent-runnable** (runs unattended, no manual
   step). A hypothesis about the cause is testable only once this loop exists —
   form it after, not before.

   When no obvious runnable artifact exists, work down this ladder and stop at
   the first rung that isolates the bug:

   | Rung | Artifact |
   |------|----------|
   | 1 | Failing test at the nearest seam (the unit/integration boundary closest to the bug) |
   | 2 | HTTP/curl script against the running service |
   | 3 | CLI invocation with a fixture, diffed against expected output |
   | 4 | Headless browser script driving the exact user action |
   | 5 | Replay of a captured trace or request log |
   | 6 | Throwaway harness: the minimal subset of the system, one call |
   | 7 | Property/fuzz loop generating inputs until it fails |
   | 8 | Bisection harness (`git bisect run <script>`) |
   | 9 | Differential loop comparing old vs. new behavior on the same input |
   | 10 | Human-in-the-loop script — last resort, only when every rung above is blocked |

   Then tighten whatever rung you land on: faster (cache setup, narrow scope),
   sharper (assert the specific symptom, not a proxy for it), and more
   deterministic (pin time, seed RNG, isolate filesystem/network) — before
   trusting it as the fix criterion.
4. Record what the reproduction requires to fail (exact version/commit, runtime,
   OS, dataset, order of steps). Each required element is evidence: the bug lives
   in or near it.

When a full local reproduction is impossible, capture evidence instead:

| Case | Do |
|------|----|
| Prod-only (data volume, real traffic, or infra you cannot copy) | Capture the failing request payloads, logs around the failure, and relevant DB row states; replay the sanitized inputs against a local or staging build |
| Timing- or concurrency-dependent, fails only sometimes | Aim for a higher reproduction rate, not a single clean repro: loop the trigger (e.g. 100×), add load, and narrow timing windows until the failure is reliably debuggable — per [debugging-concurrency-intermittent-failures] |
| Process crash with no known trigger path | Capture a core dump / heap dump / crash report and inspect state post-mortem; pair it with the last log lines before death |
| Happened once, no evidence captured, cannot re-trigger | Add targeted logging and assertions at the suspected boundary, ship that, and wait for recurrence — file the bug as open, do not patch blind |

## Edge cases

| Case | Then |
|------|------|
| Bug vanishes when you add logging or attach a debugger | Timing-sensitive: treat as an intermittent failure ([debugging-concurrency-intermittent-failures]); use non-intrusive evidence (existing logs, counters) instead of stepping |
| Reproduction needs data you are not allowed to copy | Reproduce the shape, not the content: synthesize data matching the schema, volume, and the specific values named in the failure (nulls, empty lists, boundary sizes) |
| The report names the exact line to fix | Reproduce anyway before editing; a reproduction that survives the claimed fix disproves the report's diagnosis cheaply |
| Bug reproduces only on the reporter's machine | Diff the two environments one variable at a time — versions, locale, config — moving your environment toward theirs until it fails ([debugging-methodology-isolate-by-bisection]) |
| Prod-only failure with no visible error — the client swallows it (a `.catch()` that ignores, an empty error handler) and the action just "does nothing" | Grep the production service logs for the endpoint path before reading more code: from the UI a 500 and a no-op are indistinguishable, and one server-side exception line kills whole families of hypotheses that local code reading cannot ([debugging-signals-logs-and-correlation]) |
| No loop can be built after working down the whole construction ladder | Stop before forming hypotheses: state that plainly, list what was tried, and ask for one of — environment access, a redacted artifact, or temporary instrumentation shipped to capture the next occurrence |
| The bug is in a shell script (or a command it runs) and the command pasted into your interactive shell does not reproduce it — or reproduces the opposite | Run it the way production runs it: `sh -c '…'` for a `#!/bin/sh` script, `bash script.sh` for the script itself, `env -i sh -c '…'` for a daemon or CI context — then compare `command -v <tool>` / `type <tool>` in both contexts. An interactive shell expands aliases and has loaded `~/.zshrc`/`~/.bashrc`; a non-interactive `sh` does neither, so a bare name such as `grep` can resolve to a different program with different regex semantics ([platforms-environment-path-resolution]) |
| A green test already covers the failing path and you are about to cite it as "that stage is healthy" | Read where its last assertion sits relative to the symptom: a test that waits for events 1–2 says nothing about event 3. When the assertions stop before the symptom, build the reproduction that asserts past it (step 3) before trusting the stage ([qa-process-completion-claims]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write a fix based on the report's stated cause | Reproduce first, then diagnose from the reproduction | The reporter's diagnosis is an untested hypothesis; a fix for an unreproduced bug cannot be verified |
| Verify the fix only against the full original scenario | Keep the minimal reproduction as an automated test and run it against the fix | The full scenario can pass for unrelated reasons; the minimal repro checks the exact failing mechanism |
| Keep a 40-step reproduction because it "works" | Shrink until every remaining step is required | Every removable step is noise that widens the search space for the cause |
| Paste a failing script's command into your terminal to reproduce it | Invoke it under the script's own interpreter (`sh -c`, or run the script) and diff `command -v` between the two contexts | The interactive shell's aliases and rc-set `PATH` can pick a different binary than the script's `sh` does, giving a false "works for me" or a false failure |
| Treat an existing passing test as the reproduction | Check its assertion boundary against the symptom; add the assertion past the symptom | A test that stops asserting before the failure point is green on the broken build |

## Sources

- https://sscce.org/ — minimal, self-contained example discipline
- https://www.debuggingbook.org/html/DeltaDebugger.html — systematically reducing failure-inducing inputs
- https://sre.google/sre-book/effective-troubleshooting/ — "simplify and reduce"; reproduction as the basis of diagnosis
- Field context 2026-08 (silent-swallow row, field-tested): a prod-only bookmark bug where backend code, proxy, and browser click were all verified normal from the outside; one `journalctl | grep bookmark` surfaced PostgreSQL's "no unique or exclusion constraint matching the ON CONFLICT specification", pinning the cause to a deployed DB left on an old schema — a cause invisible in the repo's code
- https://github.com/mattpocock/skills/blob/main/skills/engineering/diagnosing-bugs/SKILL.md — feedback-loop-first debugging discipline: the red-capable/deterministic/fast/agent-runnable loop criteria, the construction ladder, the tighten step, and the higher-reproduction-rate directive for non-deterministic bugs
- https://www.gnu.org/software/bash/manual/html_node/Aliases.html — "Aliases are not expanded when the shell is not interactive"; https://www.gnu.org/software/bash/manual/html_node/Bash-Startup-Files.html — a non-interactive bash reads only `$BASH_ENV`, not `~/.bashrc`; https://zsh.sourceforge.io/Doc/Release/Files.html — `.zshrc` is read only "if the shell is interactive"
- Field reproduction 2026-08-25 (dev-loop issue #145, `t1-detect`, macOS): `printf … \| LC_ALL=C grep -n '^[[:space:]]*─\{3,\}[[:space:]]*$'` typed into the interactive zsh matched 2 lines (`grep` resolved to `ugrep`); the same pipeline under `sh -c` matched 0 (`grep` resolved to `/usr/bin/grep`, byte-oriented under `LC_ALL=C`) — the production bug, invisible from the interactive shell
- https://en.wikipedia.org/wiki/Regression_testing — "when a bug is located and fixed, to record a test that exposes the bug and re-run that test regularly"; https://github.com/choiyounggi/linkly-crew/pull/10 — field reproduction 2026-09-02: the existing pump test (`core.rs:426-431`) awaited `RunStarted` + `SpecReady` and was cited as "core is fine" while the app stopped right after `SpecReady`; a new test asserting `TaskStateChanged` and a message after `SpecReady` reproduced the stall
