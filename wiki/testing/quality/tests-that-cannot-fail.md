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
  - https://testing.googleblog.com/2013/05/testing-on-toilet-dont-overuse-mocks.html
  - https://pitest.org/quickstart/basic_concepts/
last_verified: 2026-08-04
related: [testing-quality-minimum-case-set, testing-quality-behavior-not-implementation, testing-mocking-what-to-mock, testing-async-async-testing, testing-quality-checks-that-cannot-pass, testing-quality-spec-artifact-checks, testing-quality-harness-reverse-controls, testing-quality-differential-run-agreement, testing-quality-completion-predicates, qa-document-verification-spec-document-gates]
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
2. **Seed one mutation per assertion, not one per file, and require exactly the
   test that owns that assertion to redden.** Choose each mutation from what its
   assertion actually reads. A file-level red proves the file executes and that
   *some* assertion discriminates; it says nothing about the others, which is why
   mutation tools attribute a kill to the covering test rather than to the file.
   Read the outcome per assertion:

| Mutation outcome | Read it as | Do |
|------------------|------------|-----|
| Exactly the expected test reddens | That assertion discriminates on that input | Record the pair (mutation → test) and move to the next assertion |
| The file reddens but the target test stays green | The target assertion is unproven; another one caught the mutation | Find the input this assertion owns — mutate what it reads, not what its name suggests |
| No test reddens | Nothing asserts that behavior | Add the assertion, then re-run the mutation |

3. Fix each never-fails pattern with its replacement:

| Never-fails pattern | Fix |
|---------------------|-----|
| Assertion inside a callback or branch that never runs (promise `.then`, event handler, `if` body) | Count assertions with `expect.assertions(n)` / `expect.hasAssertions()`, or restructure to await-then-assert on the test's main path ([testing-async-async-testing]) |
| Assertion swallowed by `try/catch`, or a `.catch` that ignores the error | Remove the catch and let the failure throw; for an expected failure, assert the rejection explicitly (next row) |
| Error-path test that passes when no error is thrown (`expect` sits in the `catch` block; nothing asserts the throw happened) | Use `await expect(...).rejects.toThrow(ErrorType)` / `assertThrows`-style APIs, which fail when the code succeeds |
| Always-true assertion (`toBeDefined`/`toBeTruthy` on a value that is always defined, `expect(arr.length).toBeGreaterThanOrEqual(0)`) | Assert the specific expected value or shape — the observable-outcome rule in [testing-quality-minimum-case-set] |
| Testing the mock instead of the code (mock returns X, test asserts X came back) | Assert the unit's transformation of its inputs, not the pass-through; when no transformation exists at this layer, test the layer that has one ([testing-mocking-what-to-mock]) |
| Copied test body with the name changed but identical inputs and expectation | Give each case distinct inputs and its own expectation; delete exact duplicates — a renamed copy re-proves the same fact and guards nothing new |
| Assertion inherited from a shared base class, mixin, or parameterised harness, whose name announces the new subject's whole shape while its body pins the original narrow scope | Read the inherited body and list what it compares; add a subject-specific assertion for each part of the shape the name claims, then prove each one with its own mutation |

4. **Coverage note:** a covered line is only an executed line. Use coverage to
   find untested code; it cannot certify tested behavior. The proof a test
   works is the red run from step 1, not the coverage report.

## Edge cases

| Case | Then |
|------|------|
| Mutating the code under test is impractical right now (slow build, shared branch) | Invert the expected value in the assertion instead and require red — this proves the assertion executes and compares, though not which code defects it catches |
| Auditing a whole suite, not one test | Run an automated mutation-testing tool (PIT, Stryker) and treat surviving mutants in changed code as missing or defective tests |
| The mutation run is your own script rather than PIT/Stryker | Prove the harness discriminates before citing its score — a semantics-preserving no-op must survive ([testing-quality-harness-reverse-controls]) |
| A test intentionally has no outcome assertion (smoke test: module loads, page renders) | Keep it only when the regression it guards manifests as a throw; name it as a smoke test so reviewers do not count it as behavior coverage |
| The always-green test is a snapshot approved without reading | Snapshot rules → [testing-quality-behavior-not-implementation] |
| Assertions were just pulled into a shared contract (base class, mixin, parameterised suite) so several subjects now run them | Re-prove each assertion against each subject: the assertion's scope stayed where it was written while its name now speaks for every subject, so one mutation per (assertion, subject) pair is the granularity |
| The two implementations under comparison model different amounts of state | An agreement verdict on the default input cannot fail for the unmodelled dimension → [testing-quality-differential-run-agreement] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add `expect(result).toBeDefined()` to give a test "an assertion" | Assert the specific value/shape the behavior guarantees | `toBeDefined` on an always-defined value passes for every behavior, including broken |
| Prove an error path with `try { await f() } catch (e) { expect(e.message)... }` alone | Use `rejects`/`assertThrows`-style assertion, or add `expect.assertions(1)` above the try | When `f()` succeeds, the catch never runs and the test passes with zero assertions |
| Trust "green suite + high coverage" as proof an area is tested | Break the behavior once and require a red run | Coverage counts execution, not detection; high numbers are reachable with assertion-free tests |
| Delete a suspicious always-green test to clean up | Fix it via the table above, then re-verify it can fail | The test names a behavior someone meant to guard; deletion drops the intent along with the defect |
| Prove a test file can fail by seeding one mutation and watching the file go red | Seed one mutation per assertion and require exactly the owning test to redden | A file-level red is produced by whichever assertion happens to be strictest; the silent ones remain unproven |
| Pick a mutation from what the test's name says it covers | Pick it from what the assertion body actually reads | An assertion inherited into a shared contract keeps its original narrow scope, so a reasonable-looking mutation sails past it |

## Sources

- https://jestjs.io/docs/expect — `expect.assertions(n)` / `expect.hasAssertions()` guard callback assertions; `.rejects`, `.toThrow`
- https://jestjs.io/docs/asynchronous — un-awaited promises let tests finish early; `.rejects`; `expect.assertions` with try/catch
- https://testing.googleblog.com/2021/04/mutation-testing.html — inserting faults and requiring test failure measures whether tests detect bugs; coverage alone does not
- https://martinfowler.com/bliki/TestCoverage.html — coverage finds untested code; it is not a measure of test quality
- https://testing.googleblog.com/2013/05/testing-on-toilet-dont-overuse-mocks.html — mock-heavy tests can pass while the real code is broken
- https://pitest.org/quickstart/basic_concepts/ — a kill is attributed per covering test: **Killed** is "a test caught the mutation successfully", **Survived** is "the mutation was not detected by the covering test", and **No coverage** is "the same as Survived except there were no tests that exercised the line of code where the mutation was created" — the three outcomes of the per-assertion table above
- Field reproduction 2026-08-04 (linkly `test_golden.py`, 8 mutations mapped to their owning tests): renaming `workflow Checkout` to `CheckoutX` reddened `test_source_compiles_to_the_committed_ir` while `test_node_ids_and_order_are_stable` stayed green — that assertion pins only the first node id and the trailing capability ids, so reddening it required a capability-order swap instead. The file-level red would have credited both
