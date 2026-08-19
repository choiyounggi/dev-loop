---
id: testing-quality-default-values-under-test
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://pitest.org/quickstart/basic_concepts/
  - https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/
  - https://docs.python.org/3/reference/compound_stmts.html
last_verified: 2026-08-12
related: [
    testing-quality-minimum-case-set,
    testing-quality-tests-that-cannot-fail,
    testing-mocking-captured-call-arguments,
    testing-quality-harness-reverse-controls,
    testing-quality-expectation-sets-with-one-distinct-value,
  ]
---

# The Default Value of a Constructor or Factory Parameter

## When this applies

A constructor, factory, or config object has a default that a spec document, plan,
or measurement record names as a number (`ttl_s=600`, `max_tokens=256`,
`retries=3`), the class already has tests, and you are judging whether that default
is guarded — or a mutation run changed the default and the suite stayed green.

Choosing the case set for the behaviour itself → [testing-quality-minimum-case-set].
Asserting that a *caller* passes a constant on → [testing-mocking-captured-call-arguments].

## Do this

1. **Separate the two subjects and give the default its own test.** A test that
   passes the value in (`cls(ttl_s=0)`) pins the *mechanism* and says nothing about
   the shipped default; a test that constructs with defaults pins the default only
   if it *exercises* it. Both shapes are normal and both are needed — the gap is
   that neither is the default's test.

   **Give the mechanism test a value that differs from the shipped default**
   (default `21600` → fixture `100`). When the fixture repeats the default, the
   knob's two outcomes — "read the override" and "ignore the override and fall back
   to the default" — produce the same number, so a mutant that drops the lookup
   (`cfg.get("k", DEFAULT)` → `DEFAULT`) is unkillable: no assertion detects it,
   because the defect is in the input, not in the expected value. Locate this by
   grepping the fixtures for values equal to a default, not by strengthening
   assertions.

2. **Push the default to the point where it is observable, and assert from both
   sides of it.** The observable point is the behaviour the number decides:

| Default's role | Assert |
|---|---|
| A duration or TTL | Consumption just inside the boundary succeeds, and just outside it fails |
| A cap, limit, or pool size | Exactly the cap's worth of operations succeeds, and the next one is refused |
| A retry or attempt count | Exactly that many attempts are observed at the boundary the retries drive |
| A threshold or ratio | One case each side of the threshold, taken from the default's own value |
| An enum or mode | The behaviour that distinguishes this mode from the adjacent one |

3. **Require red in both directions before believing the test.** Shrinking the
   default and growing it are different mutants, and the growing direction is the
   one no incidental test catches: a test that issues N items passes for every cap
   ≥ N, and a test that consumes immediately passes for every TTL > 0. Run both
   mutants and require your new test red for each.

4. **Read the default's value from the code in the assertion, and assert the value
   itself once.** `assert store.ttl_s == 600` next to the boundary case makes the
   spec's number checkable at one place; deriving the boundary from
   `store.ttl_s` keeps the boundary cases correct when the default legitimately
   changes.

5. **Run the unmutated suite and require green.** The boundary cases in step 2 sit
   one unit from a limit, which is where an off-by-one in the *test* looks exactly
   like a caught mutant ([testing-quality-harness-reverse-controls]).

## Edge cases

| Case | Then |
|------|------|
| The default is a duration long enough that exercising it would slow the suite | Reach the boundary by controlling the clock the code reads — an injected clock, or seeding the stored timestamp — rather than by shortening the default for the test, which turns it back into a mechanism test |
| An existing test happens to catch the shrink direction | Keep it and still add the grow direction: reproduced 2026-08-10, an existing test that issued 2 items reddened a `cap 256 → 1` mutant incidentally while `cap → 9999` stayed green in the same suite |
| The default is evaluated once at definition time (a Python mutable or computed default) | Assert the shared-state consequence as its own case — the language evaluates the default expression once when the function is defined, so two instances observe one object |
| The default is supplied by a framework or config layer, not by the signature | Assert the effective value after the layer resolves it, at the level that layer runs; a signature default the framework always overrides is not the shipped default |
| The spec document and the code disagree about the number | Fix the disagreement before writing the test, and record which one was authoritative — a test written against the wrong one locks the drift in |
| The default path genuinely needs its own case and the value is awkward to vary | Write that case with the knob *omitted* entirely rather than set to the default's own number — omission exercises the fallback, while passing the default value exercises the override with an indistinguishable result |
| The default is deliberately unspecified (the caller is expected to always pass it) | Assert that omitting it is refused, so "no default" is itself the guarded behaviour |
| The value's only consequence is operational (a bind address, a timeout that only a probe observes) | Add one assertion at the level that observes it; the in-process suite cannot distinguish the values ([testing-mocking-captured-call-arguments]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Count a test that constructs with defaults as the default's coverage | Check whether that test reaches the default's observable point | Reproduced 2026-08-10: a suite whose "defaults" tests constructed with defaults and consumed immediately stayed **green** on a `ttl_s 600 → 1` mutant; the mechanism tests passed `ttl_s` in, so nothing read the default |
| Pass the value explicitly everywhere for determinism and leave it there | Keep those tests and add one default-valued test per number | Explicit passing is the right call for the mechanism, and it is exactly what makes the shipped default unasserted |
| Prove the default with one mutation in the direction that seems risky | Mutate it both smaller and larger | The grow direction survives every test that stays under the limit; reproduced, `ttl 6000 / cap 9999` was green against the whole existing suite |
| Shorten the default in a fixture so the boundary is quick to reach | Control the clock or the stored timestamp and keep the default | Changing the default for the test removes the subject; the test then proves the mechanism a second time |
| Set the knob to its own default in the fixture so the test reads like production | Pick a value that differs from the default, and cover the fallback by omitting the knob | With fixture equal to default, "override honoured" and "override ignored" are the same output; a mutation that deletes the lookup survives every assertion, literal or derived |
| Write the boundary as a literal (`599`, `257`) | Derive it from the default read off the object | A literal boundary and a literal default drift apart, and the pair passes while neither matches the spec |
| Treat a green run after adding the test as proof it works | Require red on each mutant and green on the unmutated suite | A boundary case built one unit off reads as a caught mutant on every run, including the honest one |

## Sources

- https://pitest.org/quickstart/basic_concepts/ — "'Survived' means the mutation was not detected by the covering test"; a changed default that leaves the suite green is that verdict for the default specifically, and PIT attributes a kill to the covering test rather than to the file
- https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/ — the published mutator set operates on operators, literals, and blocks; a parameter default's value is reached by literal mutation, which is why step 3 states both directions explicitly rather than relying on a tool's single generated variant
- https://docs.python.org/3/reference/compound_stmts.html — "Default parameter values are evaluated from left to right when the function definition is executed", so a mutable or computed default is shared across calls; the basis for the shared-state edge case
- Reproduction 2026-08-10 (Python 3, a TTL + cap store, four existing tests: two constructing with defaults, two passing the values in explicitly): baseline green. `ttl_s 600 → 1` — existing suite **GREEN**, added bidirectional default tests RED. `max_tokens 256 → 1` — existing suite RED (caught incidentally, because one existing test issued two items), added tests RED. `ttl_s → 6000` and `max_tokens → 9999` together — existing suite **GREEN**, added tests RED. The unmutated run was green with the added tests, which is the control showing the boundary cases are not simply always-failing. The grow direction was uncatchable by the existing suite in every configuration tried
- Field reproduction 2026-08-12 (a Python health-check daemon, `heal_detector.py`): `RENOTIFY_SEC_DEFAULT = 21600` with `renotify = det.get("renotify_sec", RENOTIFY_SEC_DEFAULT)`, and the re-notification tests built their policy with `{"renotify_sec": 21600}` — the default's own value. Mutating the lookup to `renotify = RENOTIFY_SEC_DEFAULT` (the knob ignored entirely) left all 36 tests **GREEN**. Changing only the fixture to `{"renotify_sec": 100}`, with no assertion touched, turned the same mutant **RED** in 2 cases. The surviving mutant's production consequence was that a per-detector re-notification interval would be silently ignored in favour of the 6-hour default
- Field measurement 2026-08-10 (a Python service's CSRF store, 8-round audit): `CsrfStore(ttl_s=600, max_tokens=256)` was named in the plan document, and `ttl_s=1` / `max_tokens=1` mutants passed all 65 existing cases. Three defaults-constructing tests consumed immediately or issued at most two tokens, and the two TTL/cap mechanism tests passed the values in. The production consequence of the surviving `ttl_s=1` was that any form taking longer than a second to fill would fail every submission while the page still rendered normally. Two bidirectional default tests turned all four mutants red
