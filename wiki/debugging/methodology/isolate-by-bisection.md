---
id: debugging-methodology-isolate-by-bisection
domain: debugging
category: methodology
applies_to: [general]
confidence: verified
sources:
  - https://git-scm.com/docs/git-bisect
  - https://sre.google/sre-book/effective-troubleshooting/
  - https://www.debuggingbook.org/html/DeltaDebugger.html
last_verified: 2026-07-10
related: [debugging-methodology-reproduce-first, debugging-methodology-hypothesis-testing]
---

# Locating a Fault by Binary-Searching the Difference

## When this applies

A bug reproduces but you do not know where the cause lives; especially when a
working state exists on some axis — "worked in the last release", "works in
staging but not prod", "works with this input but not that one", "works on my
machine".

## Do this

1. Name the axis on which a working and a failing state both exist. That axis is
   what you bisect. If no working state exists on any axis, build understanding
   with [debugging-methodology-hypothesis-testing] instead.
2. You need a check that distinguishes pass from fail — the reproduction from
   [debugging-methodology-reproduce-first]. Automate it: bisection runs the check
   many times.
3. Split the axis at the midpoint, test which half contains the failure, discard
   the passing half, repeat. Each round halves the search space: 1000 commits ≈
   10 tests.

| Axis (working vs failing) | How to bisect it |
|---------------------------|------------------|
| Version / time ("worked before") | `git bisect start; git bisect bad; git bisect good <last-known-good>`, then `git bisect run <test-script>` — the script exits 0 for good, 1–124 or 126–127 for bad, 125 for untestable (skips the commit). Git lands on the first bad commit unattended |
| Code path (cause somewhere in a pipeline/flow) | Disable or stub half the stages (feature flags, early returns, hardcoded intermediate values); if the failure persists, the cause is in the live half — recurse into it |
| Input data ("fails with this dataset") | Split the dataset in half, run each half; recurse into the failing half until a minimal failing record set remains (delta debugging) |
| Environment ("works in A, not in B") | Enumerate the differences (runtime version, dependency versions, config, env vars, OS, data), then flip them one at a time from A toward B until A fails — the last flip names the culprit |

4. Change exactly one variable per experiment. An experiment that changes two
   things and flips the result tells you nothing attributable; redo it as two
   experiments.
5. Bisection yields a location (commit, stage, record, config key), not a
   mechanism. Read the located diff/element and confirm the mechanism per
   [debugging-methodology-hypothesis-testing] before fixing.

## Edge cases

| Case | Then |
|------|------|
| Failure is intermittent, so a single pass can lie | Make the check statistical: run the reproduction N times per bisection step (N sized so a false "good" is unlikely), or amplify first per [debugging-concurrency-intermittent-failures] |
| Some commits in the range do not build | Have the `bisect run` script exit 125 for unbuildable commits — git skips them instead of misclassifying |
| The "first bad commit" is a huge merge or refactor | Bisect inside it on a different axis: bisect the files/hunks of that commit by reverting halves, or bisect its code path |
| Two independent bugs in the range confuse good/bad answers | Bisect against one symptom only — pin the check to one exact failure signature (message, wrong value), not "anything fails" |
| Environment diff list is enormous | Bisect the diff itself: apply half of B's differences to A at once; if A still works, the culprit is in the other half |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Read through the whole commit range or codebase hunting the cause | Bisect the axis with an automated check | Reading is linear and trust-based; bisection is logarithmic and evidence-based |
| Flip several config values between env A and B in one go | Flip one variable per experiment | A multi-variable flip that changes the outcome cannot attribute the cause |
| Trust "it started failing after deploy X" as the cause | Bisect the commits inside deploy X | A deploy bundles many changes; the correlation names the batch, not the change |

## Sources

- https://git-scm.com/docs/git-bisect — bisect workflow, `git bisect run`, exit-code contract including 125 = skip
- https://sre.google/sre-book/effective-troubleshooting/ — divide and conquer / simplify and reduce in system troubleshooting
- https://www.debuggingbook.org/html/DeltaDebugger.html — binary-search reduction of failure-inducing inputs
