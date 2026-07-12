---
id: debugging-methodology-verify-the-fix
domain: debugging
category: methodology
applies_to: [general]
confidence: field-tested
sources:
  - https://www.debuggingbook.org/html/Intro_Debugging.html
  - https://sre.google/sre-book/effective-troubleshooting/
last_verified: 2026-07-10
related: [debugging-methodology-reproduce-first, debugging-methodology-hypothesis-testing]
---

# Verifying a Fix Before Closing the Bug

## When this applies

You believe a bug is fixed and are about to close or ship it; the bug "cannot
be reproduced anymore" after changes; or a previously fixed bug came back.

## Do this

A fix is verified when the SAME reproduction that failed before passes after,
with a stated mechanism. Work through every row:

| Step | Do |
|------|----|
| Re-run the exact repro | Use the recorded reproduction from [debugging-methodology-reproduce-first] — same steps, same data, same environment — not a "similar" scenario |
| Flip both directions | The repro must fail on the pre-fix build/commit and pass on the post-fix one; where feasible, re-introduce the faulty condition and watch the failure return — the mechanism confirmation from [debugging-methodology-hypothesis-testing] |
| Eliminate state pollution | Run the verification from a clean state: clear caches (build cache, HTTP/browser cache, dependency cache), remove stale artifacts and hot-reload state, reset leftover DB rows — clean build, fresh session |
| Intermittent bug | Run the repro the SAME amplified number of times that reliably failed before (amplification: wiki/debugging/concurrency/intermittent-failures.md) — one green run of a 1-in-20 bug proves nothing |
| Pin with a regression test | Encode the repro as an automated test that fails without the fix and passes with it, so the bug cannot silently return (failing-test-first rule: wiki/testing/) |
| Clean up the investigation | Remove debug logging/prints, temporary config/flags, commented-out experiments; diff the final change against the intent — everything not serving the fix reverts |
| Scope check | List the other inputs/paths the confirmed mechanism implies (same root cause elsewhere) and confirm the fix covers them; re-run the edge cases of the touched code that worked before the fix |

"It stopped happening" after unrelated restarts or rebuilds is the classic
false fix: the restart cleared the state that expressed the bug, not the bug.
A pass only counts after the state-pollution row above.

## Edge cases

| Case | Then |
|------|------|
| Pre-fix build is unavailable (env destroyed, data migrated) | Substitute the reverse direction: locally revert the fix commit on the current build and confirm the repro fails again |
| Fix shipped, same symptom reported again | Re-run the recorded repro against the shipped version first — repro fails again means regression; repro passes means a different bug sharing the symptom |
| Repro passes but the mechanism was never confirmed | Confirm the mechanism per [debugging-methodology-hypothesis-testing] before closing; a pass without a mechanism does not distinguish a fix from masking |
| Fix is config/infra only, nothing to encode as a code test | Verify by toggling the config both ways against the repro; record the config delta with the repro so the regression check is re-runnable |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Close on "can't reproduce anymore" | Re-run the recorded repro on a clean state, both directions | Unreproducibility after unrelated changes is state pollution, not proof |
| Ship the fix plus leftover debug changes | Diff the final change against the intent; revert experiments, keep the surgical fix | Debug flags and prints change behavior and hide the fix's real effect |
| Verify with a scenario "like" the original | Run the exact recorded repro | A similar scenario can pass while the original failing path stays broken |

## Sources

- https://www.debuggingbook.org/html/Intro_Debugging.html — verify by re-running the previously failing tests; previously passing tests must stay unaffected; fix only with a diagnosis showing causality
- https://sre.google/sre-book/effective-troubleshooting/ — proving a factor caused the problem by reproducing at will; test and treat
- State-pollution checklist and investigation cleanup: field-tested practice; no citable primary source
