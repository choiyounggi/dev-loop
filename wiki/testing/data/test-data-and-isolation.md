---
id: testing-data-test-data-and-isolation
domain: testing
category: data
applies_to: [general]
confidence: verified
sources:
  - https://martinfowler.com/articles/nonDeterminism.html
  - https://abseil.io/resources/swe-book/html/ch12.html
last_verified: 2026-07-10
related: [testing-flaky-diagnosing-flaky-tests, testing-strategy-test-level-choice]
---

# Owning Test Data and Isolating Test State

## When this applies

Tests need fixture data and you are deciding how to create it; or tests pass
alone but fail when run together (or pass together but fail alone) — a
state-leak symptom.

## Do this

1. **Each test creates the data it needs and owns it.** Build fixtures through
   factory functions/builders that fill defaults, and pass explicitly only the
   fields the test's behavior depends on — a reader must be able to tell why
   the test passes from the values visible in the test body.
2. **No test depends on execution order or leftover state.** Every test must
   pass when run alone, in any order, and in parallel with the rest of its
   suite. When one test's setup relies on another test having run, merge them
   or give each its own setup.
3. Isolate by resource type:

| Case | Do |
|------|----|
| DB-backed tests | Wrap each test in a transaction rolled back at the end, or truncate the touched tables between tests — pick one mechanism per suite and apply it uniformly |
| Rollback impossible (code under test commits, or asserts across connections) | Truncate/reset between tests, or give each test uniquely-keyed rows it queries back by its own keys |
| Shared mutable fixture object (module-level constant a test mutates) | Give each test its own copy from the factory; reserve shared fixtures for immutable data |
| Time-dependent logic (expiry, scheduling, "created today") | Inject a clock/time source and freeze it in the test; assert against the frozen instant |
| Unique-constrained values (emails, usernames, external ids) | Generate per test (counter, UUID suffix) inside the factory — hardcoded constants collide across tests and across parallel runs |
| Filesystem / temp files | Create a fresh per-test temp directory and remove it in teardown |
| Global config / environment variables / singletons mutated by a test | Set in setup, restore in teardown that runs on failure too (`finally`/fixture teardown) |

4. Keep fixture data **minimal**: create only the entities the behavior under
   test reads. Every extra row is a value a reader must rule out and a
   dependency that breaks when the schema changes.

## Edge cases

| Case | Then |
|------|------|
| A seeded reference dataset is genuinely shared (country codes, static enums) | Load it once per suite and treat it as immutable; tests still create their own mutable rows |
| Suite is too slow because every test builds a deep object graph | Move the invariant graph into a per-suite setup that tests never mutate; keep mutated entities per-test |
| Failure appears only in the full suite, never alone | Run the suite in random order to expose the order dependency, then bisect to the polluting test; fix the polluter's ownership, not the victim ([testing-flaky-diagnosing-flaky-tests]) |
| Test needs "now"-relative data but the code reads the system clock directly | Refactor the code to accept an injected clock; that seam is the fix — assertions with tolerance windows around real time stay flaky |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Rely on rows created by an earlier test in the file | Create the rows in this test (or shared immutable setup) | Order dependence breaks under parallelism, filtering, and random order |
| Hardcode `test@example.com` / `user1` in many tests | Generate unique values in the factory per test | Unique-constraint collisions fail tests that are individually correct |
| `sleep()` until background work lands the data | Wait explicitly on the condition/event with a timeout | Sleeps are both too slow and too short; the race remains |
| Copy a full production-like JSON blob as fixture for one field's behavior | Build the minimal object via a factory, explicit only in that field | Giant fixtures hide the relevant value and break on unrelated schema changes |

## Sources

- https://martinfowler.com/articles/nonDeterminism.html — isolation between tests, wrapping the system clock, callbacks/polling over bare sleeps
- https://abseil.io/resources/swe-book/html/ch12.html — tests should contain the values they depend on; clarity over shared magic setup
