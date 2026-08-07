---
id: testing-quality-guard-shape-vs-consequence
domain: testing
category: quality
applies_to: [general]
confidence: field-tested
sources:
  - https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html
  - https://pitest.org/
last_verified: 2026-08-04
related: [testing-quality-tests-that-cannot-fail, testing-quality-behavior-not-implementation, testing-quality-source-text-wiring-assertions, testing-quality-spec-artifact-checks, testing-quality-harness-reverse-controls, qa-process-regression-scope]
---

# A Repo-Wide Guard That Fires on a Legitimate Artifact

## When this applies

A guard test scans every shipped artifact of a kind — example files, configs,
migrations, fixtures, schema docs — and asserts that none of them has a
structural shape S. A newly added, legitimate artifact now has S, so the guard
is red and you are deciding what to do about it. Also applies when authoring
such a guard, before the first legitimate collision happens.

Reviewing a guard that has never been red → [testing-quality-tests-that-cannot-fail].

## Do this

1. **Write down the consequence C that S was a proxy for.** The guard was never
   about the shape; it was about an outcome the shape stands in for — "this
   call can fail at runtime", "this migration takes an exclusive lock", "this
   config exposes a port". State C as a property you could compute from the
   artifact.

2. **Re-express the assertion as "no artifact has S *and* C".** Compute C by
   feeding the artifact to the **production derivation that already decides C** —
   the same resolver, planner, or rule engine the real system uses — rather than
   re-implementing the rule inside the test.

3. **Assert the specific reason the exempt artifact is exempt.** Name the
   property that makes it safe (its precondition is guaranteed, its target is
   seeded, its lock is already held). This keeps the guard's answer meaningful
   instead of merely quiet.

4. **Prove the sharpened guard still reddens.** Add a fixture artifact that has
   both S and C and require the guard to fail on it — a seeded fault that
   produces no failure means the guard stopped measuring when you sharpened it.

5. **When C cannot be computed at check time, narrow the guard's scope instead
   of exempting an artifact.** Restrict it to a directory or naming convention
   where S is always wrong, so membership is decided by location rather than by
   a list of names.

| Case | Do |
|------|----|
| Production code already derives C | Import that derivation and call it from the guard |
| C needs inputs the artifact does not carry | Synthesize the minimal input in the guard and state that assumption in the test name |
| C is genuinely uncomputable at check time | Narrow the guard's scope (step 5); keep the shape check inside that scope |
| The colliding artifact is the bug's own reproduction case | Move it into a fixture directory the guard excludes by scope — a reproduction is meant to have the shape |

## Edge cases

| Case | Then |
|------|------|
| An exemption/allow list already exists on the guard | Each entry is a case the guard stopped measuring; convert the guard to the consequence form and delete the list, or move those artifacts out of scope by location |
| The sharpened guard goes green immediately and no fixture has both S and C | It is unproven, not passing — add the fixture from step 4 before trusting it ([testing-quality-tests-that-cannot-fail]) |
| Reusing the production derivation means a bug in that derivation silently greens the guard | Accept the coupling — it is what keeps the guard's meaning in sync — and keep the step-4 fixture as the independent control that would catch the greening |
| Computing C over every artifact is expensive | Keep the shape check as a cheap prefilter and compute C only for the artifacts S matched; the assertion stays "S and C" |
| The guard reddens on an artifact that has S and genuinely has C | This is the guard working — fix the artifact, not the guard |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Delete the guard because a legitimate artifact now has the shape | Sharpen it to "shape and consequence" and keep it | The regression it was written for is still possible; deleting the guard drops the intent along with the false positive |
| Append the artifact to an exemption list | Compute the consequence and let the artifact pass on its merits | An exemption list grows by one on every collision, and a guard that exempts each new case measures nothing |
| Re-implement the consequence rule inside the test | Call the production derivation the real system uses | A copied rule drifts from the system it describes, so the guard eventually reports on a policy nobody ships |
| Ship the sharpened guard because the suite is green | Add a fixture with both the shape and the consequence and require red first | Sharpening an assertion is the easiest way to accidentally narrow it to nothing |

## Sources

- https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html — Alex Eagle, "Testing on the Toilet: Change-Detector Tests Considered Harmful" (2015-01-27), cited for the change-detector category: a shape-only guard that must be exempted for each new legitimate artifact is that failure mode at repo scope. Correction 2026-08-07: an earlier revision of this bullet presented "you cannot safely refactor code if you know you need to adapt the tests afterwards to get them passing again" as the article's own sentence. Re-fetching the page shows it is from a reader comment dated 2015-02-04 and its wording differs ("refactor stuff", "know for sure"); the article body was not retrievable in full, so nothing is quoted from it here
- https://pitest.org/ — "Faults (or mutations) are automatically seeded into your code, then your tests are run. If your tests fail then the mutation is killed, if your tests pass then the mutation lived" — the basis for step 4's required-red fixture
- Field evidence (linkly #35, 2026-08-04): `test_no_shipped_example_has_a_guarded_repository_call` asserted that no shipped `.lnpl` example contained a repository call under a guard. `examples/checkout.lnpl` legitimately added a `create` under `when stock > 0` — the issue's own reproduction shape — turning the guard permanently red. Re-expressing it as "a guarded call that could actually fail", with the conflict/miss decision taken from the production `_lnpl_ops` derivation via `seeded_entities`/`repository_calls`, returned the suite to `Ran 518 tests / OK` while a fixture holding a guarded-and-can-fail create still drove the guard red
