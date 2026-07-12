---
id: testing-quality-behavior-not-implementation
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://kentcdodds.com/blog/testing-implementation-details
  - https://abseil.io/resources/swe-book/html/ch12.html
  - https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html
last_verified: 2026-07-10
related: [testing-quality-minimum-case-set, testing-mocking-what-to-mock]
---

# Asserting Behavior Through the Public Interface

## When this applies

You are deciding what a test should assert; or a refactor that did not change
behavior broke existing tests and you are deciding whether to fix the tests or
the code.

## Do this

1. Assert through the **public interface**: feed inputs the caller controls,
   assert outputs the caller observes — return values, resulting state, rendered
   output, or the message sent to an external boundary. Treat private methods,
   internal fields, and call sequences between your own classes as
   implementation details a test must not reference.
2. Hold this invariant: **a refactor that preserves behavior keeps every test
   green**. When a pure-refactor breaks a test, the test was coupled to
   implementation — rewrite the test to assert the observable outcome; do not
   contort the code to satisfy the old test.
3. When a test needs to observe something with no public path, that is a design
   signal, not a mocking problem:

| Case | Do |
|------|----|
| The interesting logic is private inside a large class/module | Extract it into its own unit with a public interface, and test that unit directly |
| The outcome is a side effect on an external boundary (email sent, event published) | Assert the outbound message at the boundary you own ([testing-mocking-what-to-mock]) — that message is public contract, not internals |
| The outcome is internal state with no observable consequence | Delete the assertion — state no caller can observe is not a behavior; test the consequence that is observable |
| The test needs to force an internal intermediate step | Assert the end-to-end input → output of the public path instead; intermediate steps are free to change |

4. Use snapshot tests only for output that is itself a **stable, consumed
   serialization** (a public API response body, a generated config file).
   Review every snapshot diff like code — an approved-without-reading snapshot
   asserts nothing. Snapshots of volatile internals (full component trees,
   objects with incidental fields) break on every refactor.

## Edge cases

| Case | Then |
|------|------|
| The refactor intentionally changed the public contract (renamed field, new status code) | Test updates are legitimate — this is a behavior change, not coupling; update tests to the new contract deliberately |
| Legacy code has no seams and extraction is too risky right now | Pin current behavior with tests at the nearest public boundary (characterization tests), refactor under them, then extract |
| Framework/library requires lifecycle hooks that look like internals (React hooks, Spring beans) | Assert what the user of the component/bean observes (rendered result, endpoint response), not hook call order or bean internals |
| A test asserts a mock of your own class was called (interaction test on owned code) | Replace with a state/output assertion on the real collaborator; keep interaction assertions only for external boundaries |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Assert the order/count of internal method calls between your own classes | Assert the resulting state or returned output | Call sequences change on every refactor; outcomes change only when behavior changes |
| Expose a private method or field (`@VisibleForTesting`, casting to `any`) to assert it | Test through the public path, or extract the logic into a unit with a real public interface | Privates are free to change; tests on them fail refactors and pass real bugs |
| Snapshot a whole component tree / large object to "cover everything" | Assert the specific fields/elements the behavior guarantees; snapshot only stable serialized contracts | Broad snapshots break on unrelated changes and get rubber-stamp-approved |
| Fix a refactor-broken test by mirroring the new implementation in the test | Rewrite the test against the public input → output contract | A test that mirrors implementation is a change detector: it fails all refactors and detects no bugs |

## Sources

- https://kentcdodds.com/blog/testing-implementation-details — implementation-detail tests: false negatives on refactor, false positives on real bugs
- https://abseil.io/resources/swe-book/html/ch12.html — test via public APIs; prefer state testing over interaction testing
- https://testing.googleblog.com/2015/01/testing-on-toilet-change-detector-tests.html — tests mirroring implementation block refactoring and detect nothing
