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
last_verified: 2026-07-10
related: [debugging-methodology-hypothesis-testing, debugging-concurrency-intermittent-failures]
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
4. Record what the reproduction requires to fail (exact version/commit, runtime,
   OS, dataset, order of steps). Each required element is evidence: the bug lives
   in or near it.

When a full local reproduction is impossible, capture evidence instead:

| Case | Do |
|------|----|
| Prod-only (data volume, real traffic, or infra you cannot copy) | Capture the failing request payloads, logs around the failure, and relevant DB row states; replay the sanitized inputs against a local or staging build |
| Timing- or concurrency-dependent, fails only sometimes | Amplify until it reproduces on demand — loop, load, widen race windows — per [debugging-concurrency-intermittent-failures] |
| Process crash with no known trigger path | Capture a core dump / heap dump / crash report and inspect state post-mortem; pair it with the last log lines before death |
| Happened once, no evidence captured, cannot re-trigger | Add targeted logging and assertions at the suspected boundary, ship that, and wait for recurrence — file the bug as open, do not patch blind |

## Edge cases

| Case | Then |
|------|------|
| Bug vanishes when you add logging or attach a debugger | Timing-sensitive: treat as an intermittent failure ([debugging-concurrency-intermittent-failures]); use non-intrusive evidence (existing logs, counters) instead of stepping |
| Reproduction needs data you are not allowed to copy | Reproduce the shape, not the content: synthesize data matching the schema, volume, and the specific values named in the failure (nulls, empty lists, boundary sizes) |
| The report names the exact line to fix | Reproduce anyway before editing; a reproduction that survives the claimed fix disproves the report's diagnosis cheaply |
| Bug reproduces only on the reporter's machine | Diff the two environments one variable at a time — versions, locale, config — moving your environment toward theirs until it fails ([debugging-methodology-isolate-by-bisection]) |

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
