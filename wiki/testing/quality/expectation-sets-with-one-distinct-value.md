---
id: testing-quality-expectation-sets-with-one-distinct-value
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/
  - https://pitest.org/quickstart/basic_concepts/
last_verified: 2026-08-18
related:
  [
    testing-quality-default-values-under-test,
    testing-quality-tests-that-cannot-fail,
    testing-quality-unasserted-return-fields,
    testing-quality-harness-reverse-controls,
    testing-quality-source-text-wiring-assertions,
  ]
---

# Every Case Expecting the Same Value

## When this applies

You are locking that a computed value is actually carried into a response, DTO,
event, or report — the assertions exist and name the field — and every case in the
suite expects the **same literal** for it (`'HAS_VACANCY'`, `200`, `true`). Also
when a mutant that hardcodes that literal at the assembly point survives a fully
green run, and the reflex is to add more assertions.

## Do this

1. **Count the distinct expected values for the field before judging coverage.**
   One distinct value means the wired computation and a hardcoded constant produce
   identical output on every case in the suite, so no assertion on that field can
   separate them. The defect is in the case set, not in the assertions — adding
   assertions that expect the same literal changes nothing.

2. **Add one case whose expected value differs**, chosen from the branch that
   produces it (the empty input, the unmeasured row, the failure state). One
   differing case is the minimum that makes the field's assertions discriminating;
   re-run the constant mutant afterwards and require red.

3. **Probe by substituting the value, not by deleting the line.** The two probes
   answer different questions, and only the second is the one this page is about:

| Probe | What red proves | What it leaves unproven |
|---|---|---|
| Delete the field from the assembled object | The key is present in the output | Whether the key's value comes from the computation |
| Keep the key, replace the value with a constant | The value tracks the computation | Nothing — this is the probe that closes the wiring |
| Keep the key, swap in a *different* field's value | The right source feeds this key | Nothing, when the two fields differ in the fixtures |

4. **Grep the fixtures for the constant, not the test file for assertion count.**
   A field whose every fixture expects one literal is found by listing distinct
   expected values per field; a suite's assertion count says nothing about it.

5. **Run the no-op control in the same session.** A semantics-preserving edit must
   stay green, so that "the constant mutant died" is attributable to the new case
   rather than to a harness that reddens on everything
   ([testing-quality-harness-reverse-controls]).

## Edge cases

| Case | Then |
|------|------|
| The field genuinely has one legal value today (a constant status, a version tag) | Assert it once as a contract test and record that the wiring is unlocked by construction, so the next contributor does not read the green suite as wiring coverage |
| A second distinct value exists only in an error path the suite cannot reach | Pin the wiring one level down — unit-test the producing function with two values, and keep the response-level assertion as a smoke check |
| The expected values differ but all come from the same fixture row | The set is still degenerate along the input axis; vary the input that decides the value, not just the expectation text |
| The expectation is computed from the same symbol the code uses (`expect(x).toBe(STATUS.A)`) | Replace it with the literal — an expectation routed through the symbol under test drifts with it and can never fail |
| The field is absent from every assertion | That is the neighbouring defect, and its probe is deletion ([testing-quality-unasserted-return-fields]) |
| The value is a constructor or factory default | The same degeneracy, in its parameter form — [testing-quality-default-values-under-test] owns it, including the "fixture repeats the default" grep |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add more assertions on the field after a mutant survived | Add a case with a different expected value | Measured: three cases all expecting `HAS_VACANCY` left a hardcoded `HAS_VACANCY` alive; one added case expecting `UNSURVEYED` killed it |
| Report "wiring verified" from a deletion probe that went red | Re-probe by substituting a constant for the value | Deletion reddens through the missing key (a `KeyError`/undefined read), which every implementation of the key satisfies |
| Treat a large green assertion count as coverage of the field | List the distinct expected values per field | Assertion count and discriminating power are independent; a degenerate set scales the first without the second |
| Widen the fixture set arbitrarily to "add variety" | Pick the case from the branch that yields the other value | An added case that lands on the same branch reproduces the same expectation and buys nothing |

## Sources

- https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/ — "When all tests passed while this mutant was active, the mutant survived. You're missing a test for it." — the state a degenerate expectation set produces for a constant-substitution mutant; what is missing here is a *case*, not an assertion
- https://pitest.org/quickstart/basic_concepts/ — "Survived means the mutation was not detected by the covering test" — covering the line and discriminating on it are separate properties
- Local reproduction 2026-08-18 (CPython 3.9.6, `unittest`): with three cases all expecting `"HAS_VACANCY"`, replacing the wired computation with the constant `"HAS_VACANCY"` produced 0 failures (mutant survived); adding one case expecting `"UNSURVEYED"` produced 1 failure against the same constant (mutant killed), while the wired baseline stayed at 0 failures in both sets. A deletion probe on the same object reddened via `KeyError`, i.e. on key presence alone
- Field measurement 2026-08-14 (rtb-unified, NEWRTB-2786, api suite of 2046 tests): a constant `vacancyStatus: 'HAS_VACANCY'` at the assembly point passed the entire suite because both value assertions expected that same literal; after a case expecting `'UNSURVEYED'` was added, three seeded constants failed 2, 1 and 3 tests respectively
