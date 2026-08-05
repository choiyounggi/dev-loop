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
  - https://git-scm.com/docs/git-checkout
  - https://git-scm.com/docs/git-restore
last_verified: 2026-08-05
related: [testing-quality-minimum-case-set, testing-quality-behavior-not-implementation, testing-mocking-what-to-mock, testing-async-async-testing, testing-quality-checks-that-cannot-pass, testing-quality-spec-artifact-checks, testing-quality-harness-reverse-controls, qa-document-verification-spec-document-gates]
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
2. **Choose the restore mechanism by whether the work under test is committed,
   before you mutate anything.** `git checkout -- <path>` replaces the file "with
   the version from the index" and discards every unstaged change to it — when
   the fix you are validating is itself unstaged, undoing the mutation and undoing
   the fix are the same operation:

| State of the work under test | Restore with |
|------------------------------|--------------|
| Committed (or already `git add`-ed) | `git checkout -- <path>` / `git restore <path>` — it restores the index copy, which holds the fix |
| Uncommitted and unstaged | Copy the file aside first, restore from the copy, and compare hashes (`shasum -a 256`) to prove the restore was exact |
| Uncommitted, and you would rather use git | `git add <path>` before mutating — that makes the index the fix, and `git checkout --` then reverts only the mutation |

3. **Confirm the restore by count, not by appearance.** Re-run the full suite and
   require the same number of tests as before the mutation. A restore that
   silently dropped an import turns the affected module into a collection error,
   which the runner reports as a mostly-green run with a smaller total.
4. Fix each never-fails pattern with its replacement:

| Never-fails pattern | Fix |
|---------------------|-----|
| Assertion inside a callback or branch that never runs (promise `.then`, event handler, `if` body) | Count assertions with `expect.assertions(n)` / `expect.hasAssertions()`, or restructure to await-then-assert on the test's main path ([testing-async-async-testing]) |
| Assertion swallowed by `try/catch`, or a `.catch` that ignores the error | Remove the catch and let the failure throw; for an expected failure, assert the rejection explicitly (next row) |
| Error-path test that passes when no error is thrown (`expect` sits in the `catch` block; nothing asserts the throw happened) | Use `await expect(...).rejects.toThrow(ErrorType)` / `assertThrows`-style APIs, which fail when the code succeeds |
| Always-true assertion (`toBeDefined`/`toBeTruthy` on a value that is always defined, `expect(arr.length).toBeGreaterThanOrEqual(0)`) | Assert the specific expected value or shape — the observable-outcome rule in [testing-quality-minimum-case-set] |
| Testing the mock instead of the code (mock returns X, test asserts X came back) | Assert the unit's transformation of its inputs, not the pass-through; when no transformation exists at this layer, test the layer that has one ([testing-mocking-what-to-mock]) |
| Copied test body with the name changed but identical inputs and expectation | Give each case distinct inputs and its own expectation; delete exact duplicates — a renamed copy re-proves the same fact and guards nothing new |

5. **Coverage note:** a covered line is only an executed line. Use coverage to
   find untested code; it cannot certify tested behavior. The proof a test
   works is the red run from step 1, not the coverage report.

## Edge cases

| Case | Then |
|------|------|
| Mutating the code under test is impractical right now (slow build, shared branch) | Invert the expected value in the assertion instead and require red — this proves the assertion executes and compares, though not which code defects it catches |
| The suite total dropped after a restore but the run still looks green | Read it as a lost import or file, not as a passing suite: a module that fails to import contributes one error and removes all of its tests from the total. Compare totals against the pre-mutation run, then restore from the copy again |
| Several sessions or agents mutate the same working tree | Each one keeps its own hashed copy and restores before handing the tree on; a shared `git checkout --` discards whichever uncommitted work landed most recently |
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
| Undo a mutation with `git checkout -- <path>` while the fix under test is unstaged | Restore from a copy taken before the mutation and compare hashes, or `git add` the fix first | The command restores the index copy and discards every unstaged change, so it removes the fix and the mutation together while reporting nothing |

## Sources

- https://jestjs.io/docs/expect — `expect.assertions(n)` / `expect.hasAssertions()` guard callback assertions; `.rejects`, `.toThrow`
- https://jestjs.io/docs/asynchronous — un-awaited promises let tests finish early; `.rejects`; `expect.assertions` with try/catch
- https://testing.googleblog.com/2021/04/mutation-testing.html — inserting faults and requiring test failure measures whether tests detect bugs; coverage alone does not
- https://martinfowler.com/bliki/TestCoverage.html — coverage finds untested code; it is not a measure of test quality
- https://testing.googleblog.com/2013/05/testing-on-toilet-dont-overuse-mocks.html — mock-heavy tests can pass while the real code is broken
- https://git-scm.com/docs/git-checkout — `git checkout [--] <pathspec>…` with no tree-ish: "Replace the specified files and/or directories with the version from the index"; "`git checkout file.txt` will discard any unstaged changes to `file.txt`"
- https://git-scm.com/docs/git-restore — "By default, if `--staged` is given, the contents are restored from `HEAD`, otherwise from the index"

## Field context

Restore semantics measured 2026-08-05 in a scratch repository. With the fix
unstaged, mutating the file and running `git checkout -- m.py` returned the file
to its committed state — the fix's import and changed return value were both
gone. With the same fix `git add`-ed first, the identical sequence restored the
fix and reverted only the mutation. A copy-and-hash restore (`shasum -a 256`
before and after) reproduced the file byte-for-byte in either state. Originally
observed in a session where the lost import made one test module fail collection,
so the suite reported `Ran 1042 tests … errors=1` where the intact tree reported
1098 — a green-looking run with 56 tests missing.
