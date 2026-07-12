---
id: testing-quality-minimum-case-set
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://martinfowler.com/articles/practical-test-pyramid.html
  - https://abseil.io/resources/swe-book/html/ch12.html
  - https://martinfowler.com/bliki/TestDrivenDevelopment.html
last_verified: 2026-07-10
related: [testing-strategy-test-level-choice, testing-quality-behavior-not-implementation]
---

# Selecting the Minimum Case Set for a Function or Endpoint

## When this applies

You are writing tests for a function, endpoint, or change and choosing which
cases to cover; or you are reviewing tests and judging whether coverage is
sufficient.

## Do this

1. Cover each behavior with at least **one normal case, one error case, and one
   boundary case**. A behavior is one guarantee the code makes ("rejects expired
   tokens", "sums line items"), so a function with three behaviors needs three
   such sets, each in its own test.
2. Make every test assert an **observable outcome**: the return value, the
   resulting state, or the call emitted to a boundary you own. A test that only
   runs code and asserts nothing (or asserts "no exception thrown" for code
   that cannot throw) is not a test — it passes regardless of behavior.
3. Pick boundary cases from the input's type and domain:

| Input type | Boundary cases to test |
|-----------|------------------------|
| String | Empty string; max allowed length; length just over the limit |
| Nullable / optional | `null`/`undefined`/absent field — assert the defined behavior (default, rejection) |
| Number | 0; negative when the domain is non-negative; the exact limit and one past it (off-by-one) |
| Collection | Empty collection; single element; size at the limit and one over |
| Range / pagination | First item, last item, one before/after each end of the range |
| Date/time | Boundary instant itself (expires exactly now) — assert whether the limit is inclusive or exclusive |

4. For error cases, assert the **error contract** — the error type/class and
   the message or code callers branch on — because a bare "it throws" passes
   when the code throws the wrong error for the wrong reason. When the error
   surface is an HTTP response, assert status code and error body shape.
5. When fixing a bug, **first write a regression test that reproduces the bug
   and fails** on the current code, then fix until it passes (red → green).
   The failing run is the proof the test guards the bug.

## Edge cases

| Case | Then |
|------|------|
| The function cannot error by construction (total function over its input type) | Skip the error case and state why in the test file; keep normal + boundary |
| Inputs are combinatorial (many flags/fields) | Test each behavior's cases independently plus one representative combination — enumerate combinations only where behaviors interact |
| The boundary is unreachable through the public interface (guarded upstream) | Test at the level that owns the guard; do not force unreachable inputs through the unit ([testing-quality-behavior-not-implementation]) |
| Reviewing a change that only adds a case to existing behavior | Require the new case's test; the existing normal/error/boundary set stands |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write a test that calls the code and asserts nothing | Assert the return value, resulting state, or emitted boundary call | An assertion-free test passes for any behavior, including broken |
| Assert only `toThrow()` with no error type | Assert the error type and the message/code callers depend on | The test passes when the wrong error fires for the wrong reason |
| Fix a bug and add the test after the fix, never seeing it fail | Write the reproducing test first, watch it fail, then fix | A test that never failed can pass vacuously and guard nothing |
| Chase a coverage percentage by touching lines without assertions | Add normal/error/boundary cases per behavior | Line coverage without outcome assertions detects nothing |

## Sources

- https://martinfowler.com/articles/practical-test-pyramid.html — test one condition per test; cover happy path and edge cases
- https://abseil.io/resources/swe-book/html/ch12.html — test behaviors (guarantees), not methods; clear assertions per behavior
- https://martinfowler.com/bliki/TestDrivenDevelopment.html — write the failing test first (red–green–refactor)
