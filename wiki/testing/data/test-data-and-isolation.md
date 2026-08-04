---
id: testing-data-test-data-and-isolation
domain: testing
category: data
applies_to: [general]
confidence: verified
sources:
  - https://martinfowler.com/articles/nonDeterminism.html
  - https://abseil.io/resources/swe-book/html/ch12.html
  - https://testing.googleblog.com/2017/01/testing-on-toilet-keep-cause-and-effect.html
last_verified: 2026-08-04
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
| The fixture's shape depends on a value the test also passes to the code under test (a key, a tenant id, a payload, a timestamp) | Put that value in the factory's signature so every call site names it — a factory that defaults it to a module-level constant lets fixture and run diverge silently |
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
| A group of tests fails as a lookup miss, an empty result, or a "not found" far from any fixture code | Compare each factory's defaulted values against the input the test actually runs before migrating fixture shape; when the two disagree, the fixture was built for a different input and only the signature change fixes the group |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Rely on rows created by an earlier test in the file | Create the rows in this test (or shared immutable setup) | Order dependence breaks under parallelism, filtering, and random order |
| Hardcode `test@example.com` / `user1` in many tests | Generate unique values in the factory per test | Unique-constraint collisions fail tests that are individually correct |
| `sleep()` until background work lands the data | Wait explicitly on the condition/event with a timeout | Sleeps are both too slow and too short; the race remains |
| Copy a full production-like JSON blob as fixture for one field's behavior | Build the minimal object via a factory, explicit only in that field | Giant fixtures hide the relevant value and break on unrelated schema changes |
| Let a factory seed itself from a module-level constant while the test passes a different value to the code under test | Take that value as a factory parameter and name it at every call site | The fixture is then built for the input the test actually runs; a defaulted constant makes the two drift apart with nothing in the test body showing it |

## Sources

- https://martinfowler.com/articles/nonDeterminism.html — isolation between tests, wrapping the system clock, callbacks/polling over bare sleeps
- https://abseil.io/resources/swe-book/html/ch12.html — a test is complete when "its body contains all of the information a reader needs in order to understand how it arrives at its result"; prefer DAMP over DRY, and where a helper is used, give it "descriptive parameters that make dependencies explicit" rather than reusing shared constants
- https://testing.googleblog.com/2017/01/testing-on-toilet-keep-cause-and-effect.html — keep the inputs a test's result depends on visible in the test method instead of in shared setup, so the cause-and-effect relationship is readable without jumping elsewhere
- Field incident 2026-08-04 (`linkly-t1-repo-policy`, Python): `rows_for(doc)` seeded its rows from the module constant `PAYLOAD` while its tests ran payload `{}`; a shape-only migration of the helper fixed 1 of 11 failures, and moving the payload into the helper's signature fixed 11 of 11
