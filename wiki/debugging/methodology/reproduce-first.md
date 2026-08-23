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
last_verified: 2026-08-24
related: [debugging-methodology-hypothesis-testing, debugging-concurrency-intermittent-failures, debugging-signals-logs-and-correlation]
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

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write a fix based on the report's stated cause | Reproduce first, then diagnose from the reproduction | The reporter's diagnosis is an untested hypothesis; a fix for an unreproduced bug cannot be verified |
| Verify the fix only against the full original scenario | Keep the minimal reproduction as an automated test and run it against the fix | The full scenario can pass for unrelated reasons; the minimal repro checks the exact failing mechanism |
| Keep a 40-step reproduction because it "works" | Shrink until every remaining step is required | Every removable step is noise that widens the search space for the cause |

## Sources

- https://sscce.org/ — minimal, self-contained example discipline
- https://www.debuggingbook.org/html/DeltaDebugger.html — systematically reducing failure-inducing inputs
- https://sre.google/sre-book/effective-troubleshooting/ — "simplify and reduce"; reproduction as the basis of diagnosis
- Field context 2026-08 (silent-swallow row, field-tested): a prod-only bookmark bug where backend code, proxy, and browser click were all verified normal from the outside; one `journalctl | grep bookmark` surfaced PostgreSQL's "no unique or exclusion constraint matching the ON CONFLICT specification", pinning the cause to a deployed DB left on an old schema — a cause invisible in the repo's code
- https://github.com/mattpocock/skills/blob/main/skills/engineering/diagnosing-bugs/SKILL.md — feedback-loop-first debugging discipline: the red-capable/deterministic/fast/agent-runnable loop criteria, the construction ladder, the tighten step, and the higher-reproduction-rate directive for non-deterministic bugs
