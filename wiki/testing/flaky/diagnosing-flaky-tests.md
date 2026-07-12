---
id: testing-flaky-diagnosing-flaky-tests
domain: testing
category: flaky
applies_to: [general]
confidence: verified
sources:
  - https://martinfowler.com/articles/nonDeterminism.html
  - https://testing.googleblog.com/2016/05/flaky-tests-at-google-and-how-we.html
  - https://testing.googleblog.com/2017/04/where-do-our-flaky-tests-come-from.html
last_verified: 2026-07-10
related: [testing-data-test-data-and-isolation, testing-mocking-what-to-mock]
---

# Fixing a Test That Fails Intermittently

## When this applies

A test sometimes fails and sometimes passes with no code change: it fails in CI
but passes locally, fails only when run with other tests, or passes on retry.
This page covers test-specific causes and fixes; for general root-cause
methodology on the intermittent failure itself, see wiki/debugging/.

## Do this

1. Reproduce the failure mode before fixing: rerun the single test in a loop,
   run the suite in random order, and run it in parallel. Which reproduction
   works points to the cause:

| Symptom → cause | Fix |
|-----------------|-----|
| Fails in a loop alone → async wait via `sleep(n)` racing background work | Replace the sleep with an explicit wait on the completion condition or event (poll/callback/framework `waitFor`) with a timeout; the test proceeds the moment the condition holds |
| Fails only with other tests / only in some orders → order dependence, leftover state | Make each test create and own its state ([testing-data-test-data-and-isolation]); bisect random-order runs to find the polluting test and fix the polluter |
| Fails only in parallel / only in CI → shared external resource (same DB schema, port, temp dir across runs) | Give each run/worker its own resource: unique schema or database per worker, ephemeral ports, per-test temp dirs |
| Fails at certain times of day / dates / in CI's timezone → time and timezone dependence | Inject a frozen clock and assert against the injected instant; store and compare in UTC |
| Fails on network errors/timeouts to a real external service → infra flake | Move the dependency behind an owned boundary and stub it ([testing-mocking-what-to-mock]); keep real-service calls in a separate non-blocking suite |
| Fails on differing float/collection ordering → nondeterministic iteration or randomness | Seed the randomness; sort before asserting or assert order-independently |

2. The moment a test is identified as flaky, **quarantine it and file a
   ticket**: move it out of the blocking CI path (skip-with-annotation or a
   quarantine suite) so the suite stays trustworthy, and fix it from the
   ticket. A flaky test left blocking trains everyone to rerun and ignore red.
3. After the fix, prove it: rerun the previously failing reproduction (loop /
   random order / parallel) and require a clean streak before unquarantining.
4. Detect proactively: run the suite in random order and in parallel in CI so
   order and isolation defects surface as immediate failures instead of
   accumulating as latent flakiness.

## Edge cases

| Case | Then |
|------|------|
| Retry-on-failure is configured at the runner level and masks which tests are flaky | Keep at most one automated retry, and only with flake-reporting that files the pass-on-retry as a defect; a silent retry converts a detector into a suppressor |
| The flake reproduces only in CI, never locally | Diff the environments: CPU/parallelism, timezone, locale, dependency versions, resource limits — then reproduce locally by matching the differing factor (e.g. run with CI's timezone and parallelism) |
| The "flaky test" is actually an intermittent production bug (race in the code under test) | The test is doing its job — fix the code, not the test; deep diagnosis methodology → wiki/debugging/ |
| A test cannot be de-flaked at its current level (full-stack e2e with inherent variance) | Push the assertions down to unit/integration level and keep only a minimal smoke check at e2e ([testing-strategy-test-level-choice]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Bump the `sleep` from 1s to 5s to make it pass | Wait explicitly on the condition with a timeout | Longer sleeps slow every run and still race under load; the failure returns |
| Normalize retry-until-green as the standing fix | Quarantine + ticket + root-cause fix; retries only as monitored, reported stopgap | Retries hide real races in test and production code and erode trust in red |
| Delete the flaky test to unblock CI | Quarantine it and fix from the ticket | Deletion silently drops the regression coverage the test provided |
| Mark the test "known flaky" in a comment and leave it blocking | Move it out of the blocking path via quarantine mechanism | A blocking flaky test teaches the team to ignore failures, including real ones |

## Sources

- https://martinfowler.com/articles/nonDeterminism.html — quarantine strategy; isolation; polling/callbacks over bare sleeps; wrapping the clock
- https://testing.googleblog.com/2016/05/flaky-tests-at-google-and-how-we.html — flake handling at scale: marking/quarantining flaky tests, retry pitfalls
- https://testing.googleblog.com/2017/04/where-do-our-flaky-tests-come-from.html — measured flake causes: timing, randomness, threading/async, infra timeouts; larger tests flakier
