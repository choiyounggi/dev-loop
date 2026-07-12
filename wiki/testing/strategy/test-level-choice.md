---
id: testing-strategy-test-level-choice
domain: testing
category: strategy
applies_to: [general]
confidence: verified
sources:
  - https://martinfowler.com/articles/practical-test-pyramid.html
  - https://testing.googleblog.com/2017/04/where-do-our-flaky-tests-come-from.html
last_verified: 2026-07-10
related: [testing-quality-minimum-case-set, testing-mocking-what-to-mock]
---

# Choosing the Test Level for a Behavior

## When this applies

You are deciding at which level (unit / integration / end-to-end) to test new or
changed behavior, or you are reviewing a test plan and judging whether coverage
sits at the right levels.

## Do this

1. Write each test at the **lowest level that can catch the regression** you are
   guarding against. If a unit test can fail when the behavior breaks, do not
   write an integration or e2e test for it.
2. Pick the level by what the behavior spans:

| Case | Do |
|------|----|
| Pure logic: branching, calculation, mapping, validation rules — all inside your own code | Unit test. In-process, no real I/O; one test per behavior, run in milliseconds |
| Your code plus a real dependency's **contract**: SQL query shape, ORM mapping, serialization/deserialization, framework request binding | Integration test against the real dependency (test DB, real serializer) — a unit test with a mocked dependency only asserts your own guess about the contract |
| A user-critical flow across the deployed stack (signup, checkout, login) | Few e2e smoke tests covering the flow end to end — one per critical journey, not per input variation |
| Behavior already regression-caught by a lower-level test | No additional test at a higher level — duplicate coverage across levels adds run time and maintenance without new protection |

3. Keep the pyramid shape: many unit tests, fewer integration tests, very few
   e2e tests. Test input variations, error paths, and boundaries at the unit
   level; test one representative path per contract at the integration level;
   test only whole-flow health at the e2e level. Larger tests are measurably
   flakier and slower, so every case pushed down the pyramid buys reliability.
4. When a higher-level test fails and no lower-level test fails, write the
   missing lower-level test that reproduces the failure, then keep that one.

## Edge cases

| Case | Then |
|------|------|
| Logic worth unit-testing is buried inside a controller/handler that needs the framework to run | Extract the logic into a plain function/class, unit-test the extraction, and leave one integration test proving the controller wires it in |
| The framework wiring itself is the risk (routing, DI configuration, middleware order) | One integration test that boots the wiring and exercises one representative request — enumerate input cases at the unit level, not per-case through the framework |
| The behavior is a thin pass-through with no branching (delegating call, field copy) | Cover it via the integration test of the contract it participates in; a dedicated unit test would assert structure, not behavior |
| A bug escaped to production and you are adding coverage | Add the regression test at the lowest level that reproduces the bug; add a higher-level test only if the bug lived in the interaction itself |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add an e2e test per input variation of a form/endpoint | Enumerate variations in unit tests; keep one e2e smoke test for the flow | E2e per-case multiplies run time and flake surface for no added regression coverage |
| Unit-test a repository by mocking the DB driver | Integration-test it against a real test database | The mock encodes your assumption of the SQL contract; the test passes even when the query is wrong |
| Duplicate a passing unit-level case at integration level "for confidence" | Keep the unit test only; add integration tests only for real-dependency contracts | Duplicated levels double maintenance and slow the suite without catching new regressions |

## Sources

- https://martinfowler.com/articles/practical-test-pyramid.html — pyramid proportions, "push your tests as far down the test pyramid as you can", write a lower-level test when a high-level one fails
- https://testing.googleblog.com/2017/04/where-do-our-flaky-tests-come-from.html — larger tests are measurably flakier (supports keeping e2e minimal)
