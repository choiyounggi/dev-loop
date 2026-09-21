---
id: testing-quality-narration-based-ordering-assertions
domain: testing
category: quality
applies_to: [general]
confidence: field-tested
sources:
  - https://developer.apple.com/documentation/foundation/nstask/1408746-terminationhandler
last_verified: 2026-09-08
related: [testing-quality-tests-that-cannot-fail, testing-quality-mutation-harness-file-custody, testing-async-async-testing, testing-quality-captured-log-message-assertions]
---

# An Ordering Test Built From Narration Strings at Existing Hook Sites

## When this applies

Writing a regression test for an ordering or timing invariant in concurrent or
async code (e.g. "the termination handler must be installed before the process
launches") by recording self-reported narration strings ("handlerAssigned",
"launching") at the code's existing instrumentation/hook call sites and
asserting their relative order.

## Do this

1. **Inject a hook that reads the real object's state at the critical moment**,
   rather than a hook that logs a narration string at a call site the fix might
   move. For a handler-before-launch invariant, read the real flag
   (`process.terminationHandler != nil`, or the language equivalent) inside the
   hook that fires at launch — a separately-logged "handlerAssigned" marker's
   position in the code is an assumption, not a guarantee.
2. **Prove the test can fail before trusting it**: reintroduce the exact
   original bug by mutation (move the state-mutating line back to its old,
   broken position) and require the test to go red — the same manual-mutation
   discipline as [testing-quality-tests-that-cannot-fail] step 1, applied
   specifically to ordering/timing invariants.
3. **Get independent confirmation of the red run** when the invariant is
   safety-critical (crash/race conditions): have a second person or session run
   the same mutation. A mutation performed and read only by the session that
   wrote the test is exactly the untrusted case step 2 exists to catch.

## Edge cases

| Case | Then |
|------|------|
| The hook call sites are the only instrumentation available and moving them is impractical | Read the real object's field through a debugger/inspector API at the hook, rather than trusting the call site's position to still track the code path it once matched |
| The mutation moves the fix to a place with no hook nearby at all | Add a hook at the new location too, or assert via polling the real object rather than narration — no single call site's presence decides the test's power |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Assert the order of two logged narration strings recorded at existing hook call sites | Inject a hook that reads the real object's state at the critical moment | Moving the actual state-mutating line does not move the hook calls written to match the old code, so a narration-order test silently degrades into a test of the narration, not the invariant |
| Trust a new ordering/timing regression test because it passes on the first run | Reintroduce the exact bug by mutation and require red before trusting it | A test built from self-reported narration can keep passing after the real bug returns |

## Sources

- https://developer.apple.com/documentation/foundation/nstask/1408746-terminationhandler — `terminationHandler` is a Foundation API with race-sensitive semantics (one handler settable at a time; if the process already finished, the block runs promptly) — the general class of invariant this case guards
- Field evidence (a Swift process-launching component, 2026-09; session-relayed, general mechanism confirmed against the API doc above): a first version of the test asserted the order of two logged strings ("handlerAssigned"/"launching") recorded at existing hook call sites; it still passed after mutating the source to reproduce the exact original race, because moving the state-mutating line did not move the hook calls. Replacing it with a hook reading `Process.terminationHandler != nil` at the call site correctly failed under the same mutation, confirmed independently by both the authoring session and an auditor
