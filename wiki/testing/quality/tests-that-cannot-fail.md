---
id: testing-quality-tests-that-cannot-fail
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://jestjs.io/docs/expect
  - https://jestjs.io/docs/asynchronous
  - https://testing.googleblog.com/2021/04/mutation-testing.html
  - https://martinfowler.com/bliki/TestCoverage.html
  - https://man7.org/linux/man-pages/man2/execve.2.html
  - https://www.gnu.org/software/sed/manual/html_node/Exit-status.html
  - https://testing.googleblog.com/2013/05/testing-on-toilet-dont-overuse-mocks.html
last_verified: 2026-08-05
related: [testing-quality-minimum-case-set, testing-quality-behavior-not-implementation, testing-mocking-what-to-mock, testing-async-async-testing, testing-quality-checks-that-cannot-pass, testing-quality-spec-artifact-checks, testing-quality-harness-reverse-controls, qa-document-verification-spec-document-gates, platforms-shells-portable-shell-scripts]
---

# Proving a Test Can Fail

## When this applies

You are reviewing tests that always pass, a bug shipped through an area the
suite reported as covered, or you are auditing a suspiciously green suite.

## Do this

1. **A test proves something only if it can fail.** Verify by breaking the code
   under test once: mutate the behavior the test claims to guard (flip the
   condition, change the returned value), rerun the test, and require red. If
   it stays green, the test is decoration — locate its defect in the table
   below and fix the test, then re-verify red before restoring the code.
   This is manual mutation testing; run it whenever a test's value is in doubt.
2. Fix each never-fails pattern with its replacement:

| Never-fails pattern | Fix |
|---------------------|-----|
| Assertion inside a callback or branch that never runs (promise `.then`, event handler, `if` body) | Count assertions with `expect.assertions(n)` / `expect.hasAssertions()`, or restructure to await-then-assert on the test's main path ([testing-async-async-testing]) |
| Assertion swallowed by `try/catch`, or a `.catch` that ignores the error | Remove the catch and let the failure throw; for an expected failure, assert the rejection explicitly (next row) |
| Error-path test that passes when no error is thrown (`expect` sits in the `catch` block; nothing asserts the throw happened) | Use `await expect(...).rejects.toThrow(ErrorType)` / `assertThrows`-style APIs, which fail when the code succeeds |
| Always-true assertion (`toBeDefined`/`toBeTruthy` on a value that is always defined, `expect(arr.length).toBeGreaterThanOrEqual(0)`) | Assert the specific expected value or shape — the observable-outcome rule in [testing-quality-minimum-case-set] |
| Testing the mock instead of the code (mock returns X, test asserts X came back) | Assert the unit's transformation of its inputs, not the pass-through; when no transformation exists at this layer, test the layer that has one ([testing-mocking-what-to-mock]) |
| Runner invokes the subject differently than production does (`bash script.sh` on a `#!/bin/sh` file, `node` on a file production runs under a different runtime/flags) | Invoke it the way production does, or add one job that does — a shebang is honoured only when the file is executed directly, so passing it to an interpreter silently swaps the interpreter and the suite becomes blind to that whole bug class ([platforms-shells-portable-shell-scripts]) |
| Copied test body with the name changed but identical inputs and expectation | Give each case distinct inputs and its own expectation; delete exact duplicates — a renamed copy re-proves the same fact and guards nothing new |

3. **Coverage note:** a covered line is only an executed line. Use coverage to
   find untested code; it cannot certify tested behavior. The proof a test
   works is the red run from step 1, not the coverage report.

## Edge cases

| Case | Then |
|------|------|
| The mutation is applied by a script (`sed`/`awk`) rather than by hand | Assert the edit landed — `diff` the file or grep for the injected text — and treat "mutation did not apply" as its own outcome. A pattern that matches nothing still exits 0, so the suite stays green because the code never changed, which reads exactly like a blind test and sends you rewriting a test that was fine |
| Mutating a guard that returns an error code (`if [ "$x" != "ok" ]; then exit 6; fi`) | Mutate it toward *unreachable* (make the condition impossible), not toward *always-firing*. An always-firing guard produces the asserted exit code more often, so the exit-code test stays green and proves nothing; the question is whether the test goes red when the guard is gone |
| Mutating the code under test is impractical right now (slow build, shared branch) | Invert the expected value in the assertion instead and require red — this proves the assertion executes and compares, though not which code defects it catches |
| Auditing a whole suite, not one test | Run an automated mutation-testing tool (PIT, Stryker) and treat surviving mutants in changed code as missing or defective tests |
| The mutation run is your own script rather than PIT/Stryker | Prove the harness discriminates before citing its score — a semantics-preserving no-op must survive ([testing-quality-harness-reverse-controls]) |
| A test intentionally has no outcome assertion (smoke test: module loads, page renders) | Keep it only when the regression it guards manifests as a throw; name it as a smoke test so reviewers do not count it as behavior coverage |
| The always-green test is a snapshot approved without reading | Snapshot rules → [testing-quality-behavior-not-implementation] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add `expect(result).toBeDefined()` to give a test "an assertion" | Assert the specific value/shape the behavior guarantees | `toBeDefined` on an always-defined value passes for every behavior, including broken |
| Prove an error path with `try { await f() } catch (e) { expect(e.message)... }` alone | Use `rejects`/`assertThrows`-style assertion, or add `expect.assertions(1)` above the try | When `f()` succeeds, the catch never runs and the test passes with zero assertions |
| Trust "green suite + high coverage" as proof an area is tested | Break the behavior once and require a red run | Coverage counts execution, not detection; high numbers are reachable with assertion-free tests |
| Delete a suspicious always-green test to clean up | Fix it via the table above, then re-verify it can fail | The test names a behavior someone meant to guard; deletion drops the intent along with the defect |

## Sources

- https://jestjs.io/docs/expect — `expect.assertions(n)` / `expect.hasAssertions()` guard callback assertions; `.rejects`, `.toThrow`
- https://jestjs.io/docs/asynchronous — un-awaited promises let tests finish early; `.rejects`; `expect.assertions` with try/catch
- https://testing.googleblog.com/2021/04/mutation-testing.html — inserting faults and requiring test failure measures whether tests detect bugs; coverage alone does not
- https://martinfowler.com/bliki/TestCoverage.html — coverage finds untested code; it is not a measure of test quality
- https://testing.googleblog.com/2013/05/testing-on-toilet-dont-overuse-mocks.html — mock-heavy tests can pass while the real code is broken
