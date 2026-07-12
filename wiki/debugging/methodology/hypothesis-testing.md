---
id: debugging-methodology-hypothesis-testing
domain: debugging
category: methodology
applies_to: [general]
confidence: verified
sources:
  - https://www.debuggingbook.org/html/Intro_Debugging.html
  - https://sre.google/sre-book/effective-troubleshooting/
last_verified: 2026-07-10
related: [debugging-methodology-reproduce-first, debugging-methodology-isolate-by-bisection]
---

# Testing a Suspected Cause Before Changing Code

## When this applies

You have a reproduction and a suspect cause ("I think it's the cache", "the
timeout is too low") and you are about to "try a fix" to see if it helps. Also
applies when several suspects compete and you must pick what to investigate next.

## Do this

1. State the hypothesis as a specific mechanism, written down: "X causes the
   failure because Y" — not "something with the cache". A hypothesis you cannot
   write down is a hunch; go gather more evidence first.
2. Derive a testable prediction the hypothesis forces: "if this is the cause,
   then the failure disappears with the cache disabled / the log shows a stale
   entry at T / the request carries value V". A hypothesis with no prediction
   that could come out false is untestable — replace it.
3. Run the cheapest experiment that can falsify the prediction, before any code
   change. Ordered by cost: read existing logs/evidence → add one log
   line/assertion → toggle one flag or config → stub one component → change code.
4. Change exactly one variable per experiment; compare against the unmodified
   reproduction as baseline.
5. Record each hypothesis and its outcome (confirmed / falsified / inconclusive)
   in a running log — the issue comment, PR description, or a scratch file kept
   for the session. This prevents re-testing falsified ideas and makes handoffs
   and "back to it tomorrow" cheap.
6. When two hypotheses remain, test the one that is cheaper to falsify first —
   a cheap falsification eliminates a branch at low cost, regardless of which
   one you believe more.
7. Only after the mechanism is confirmed, write the fix — and predict what the
   fix changes so the reproduction from [debugging-methodology-reproduce-first]
   can verify exactly that.

## Edge cases

| Case | Then |
|------|------|
| The fix "works" but you never confirmed the mechanism | Verify before closing: re-introduce the original condition and confirm the failure returns, or trace the mechanism end-to-end in evidence (logs/values). A fix that works for unknown reasons masks symptoms and leaves the cause live |
| Experiment is inconclusive (failure is intermittent) | Make the observation statistical — N runs per arm, per [debugging-concurrency-intermittent-failures] — before drawing any conclusion |
| Every hypothesis you can think of is falsified | Your model of the system is wrong somewhere upstream. Return to evidence gathering: widen what you observe ([debugging-signals-logs-and-correlation]) or bisect to relocate the fault ([debugging-methodology-isolate-by-bisection]) |
| Testing the hypothesis requires touching prod | Prefer a read-only prediction (something already in logs/metrics that must be true if the hypothesis holds); active prod experiments require owner approval and a rollback plan |
| Hypothesis confirmed but the fix belongs to another domain (slow query, infra limit) | Record the confirmed mechanism, then route the fix to the owning domain — e.g. a slow SQL statement goes to wiki/databases/query-optimization/reading-execution-plans.md |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Change several suspicious things at once and rerun | One variable per experiment | If the batch flips the result you cannot attribute it; if it doesn't, you have falsified nothing |
| Conclude "the fix worked, so that was the cause" | Confirm the mechanism: re-introduce the condition and watch the failure return, or explain via evidence why the fix closes it | Rebuilds, cache resets, and restarts ride along with "fixes" and mask the real cause |
| Keep hypotheses in your head across a long session | Write the hypothesis log as you go | Untracked falsified hypotheses get re-tested; sessions and handoffs lose the search state |
| Start with the most invasive experiment (rewrite the suspect module) | Run the cheapest falsifying experiment first | Most hypotheses die cheap; invasive experiments add new variables and new bugs |

## Sources

- https://www.debuggingbook.org/html/Intro_Debugging.html — scientific method for debugging: hypothesis → prediction → experiment → repeat
- https://sre.google/sre-book/effective-troubleshooting/ — hypothetico-deductive troubleshooting; test causes, treat the confirmed one
