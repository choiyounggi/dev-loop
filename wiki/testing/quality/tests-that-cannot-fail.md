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
  - https://man7.org/linux/man-pages/man2/execve.2.html
  - https://www.gnu.org/software/sed/manual/html_node/Exit-status.html
  - https://git-scm.com/docs/git-checkout
  - https://git-scm.com/docs/git-restore
last_verified: 2026-08-12
related: [testing-quality-minimum-case-set, testing-quality-behavior-not-implementation, testing-mocking-what-to-mock, testing-async-async-testing, testing-quality-checks-that-cannot-pass, testing-quality-spec-artifact-checks, testing-quality-harness-reverse-controls, testing-quality-schema-additions-under-a-golden-gate, testing-quality-differential-run-agreement, testing-quality-completion-predicates, testing-quality-guard-shape-vs-consequence, testing-quality-injected-clock-duration-assertions, testing-quality-write-path-assertions, testing-quality-value-preserving-refactor-assertions, testing-quality-unasserted-return-fields, testing-quality-stale-artifact-baselines, backend-common-change-impact-call-site-enumeration, platforms-shells-portable-shell-scripts, qa-document-verification-spec-document-gates, testing-quality-surviving-mutant-equivalence-triage, testing-quality-source-text-wiring-assertions, testing-quality-default-values-under-test, testing-mocking-captured-call-arguments]
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
   *some* assertion discriminates; mutation tools attribute a kill to the
   covering test, not to the file. Read the outcome per assertion:

| Mutation outcome | Read it as | Do |
|------------------|------------|-----|
| Exactly the expected test reddens | That assertion discriminates on that input | Record the pair (mutation → test) and move on |
| The file reddens but the target test stays green | The target assertion is unproven; another one caught the mutation | Mutate what this assertion reads, not what its name suggests |
| No test reddens | Nothing asserts that behavior | Add the assertion, then re-run the mutation |
| No test reddens, and an assertion on that exact observable already exists | Another writer on the same execution path sets the same observable, so no case can attribute it to this branch | Add a case where only this branch acts — for a branch that runs before a loop, an input with zero items to process — then re-run and require red |

3. **Choose the restore mechanism by whether the work under test is committed,
   before you mutate anything.** `git checkout -- <path>` replaces the file with
   the version from the index and discards every unstaged change — when the fix
   you are validating is itself unstaged, undoing the mutation and undoing the
   fix are the same operation:

| State of the work under test | Restore with |
|------------------------------|--------------|
| Committed (or already `git add`-ed) | `git checkout -- <path>` / `git restore <path>` — the index copy holds the fix |
| Uncommitted and unstaged | Copy the file aside first, restore from the copy, and compare hashes (`shasum -a 256`) to prove the restore was exact |
| Uncommitted, and you would rather use git | `git add <path>` before mutating — the index then holds the fix, and `git checkout --` reverts only the mutation |

4. **Confirm the restore by count, not by appearance.** Re-run the full suite
   and require the same number of tests as before the mutation — a restore that
   silently dropped an import turns the module into a collection error, which
   reads as a mostly-green run with a smaller total.
5. Fix each never-fails pattern with its replacement:

| Never-fails pattern | Fix |
|---------------------|-----|
| Assertion inside a callback or branch that never runs (promise `.then`, event handler, `if` body) | Count assertions with `expect.assertions(n)` / `expect.hasAssertions()`, or restructure to await-then-assert on the test's main path ([testing-async-async-testing]) |
| Assertion swallowed by `try/catch`, or a `.catch` that ignores the error | Remove the catch and let the failure throw; for an expected failure, assert the rejection explicitly (next row) |
| Error-path test that passes when no error is thrown (`expect` sits in the `catch` block; nothing asserts the throw happened) | Use `await expect(...).rejects.toThrow(ErrorType)` / `assertThrows`-style APIs, which fail when the code succeeds |
| Always-true assertion (`toBeDefined`/`toBeTruthy` on a value that is always defined, `expect(arr.length).toBeGreaterThanOrEqual(0)`) | Assert the specific expected value or shape — the observable-outcome rule in [testing-quality-minimum-case-set] |
| Testing the mock instead of the code (mock returns X, test asserts X came back) | Assert the unit's transformation of its inputs, not the pass-through; when no transformation exists at this layer, test the layer that has one ([testing-mocking-what-to-mock]) |
| Copied test body with the name changed but identical inputs and expectation | Give each case distinct inputs and its own expectation; delete exact duplicates — a renamed copy re-proves the same fact and guards nothing new |
| Assertion inherited from a shared base class, mixin, or parameterised harness, whose name announces the new subject's whole shape while its body pins the original narrow scope | Read the inherited body and list what it compares; add a subject-specific assertion for each part of the shape the name claims, then prove each one with its own mutation |
| Bats assertion written as `[[ … ]]` anywhere but the test's last command, when bats resolves to bash 3.2 (macOS system bash) — a false `[[ ]]` mid-test does not fail the test | Write bats assertions as simple commands — `[ … ]` or `printf '%s\n' "$output" \| grep -qF "expected"` — which fail at any position; before bash 4.0, `set -e` ignores a failing compound command, so a mid-test `[[ ]]` is decoration on that shell (same shape as the documented bats `!`-negation gotcha) |

6. **Coverage note:** a covered line is only an executed line. Use coverage to
   find untested code; it cannot certify tested behavior. The proof a test
   works is the red run from step 1, not the coverage report.

## Edge cases

| Case | Then |
|------|------|
| Mutating the code under test is impractical right now (slow build, shared branch) | Invert the expected value in the assertion instead and require red — this proves the assertion executes and compares, though not which code defects it catches |
| Auditing a whole suite, not one test | Run an automated mutation-testing tool (PIT, Stryker), then classify each surviving mutant in changed code before writing a test for it — a missing test, an equivalent mutant, or an uncovered line ([testing-quality-surviving-mutant-equivalence-triage]) |
| The mutation run is your own script rather than PIT/Stryker | Prove the harness discriminates before citing its score — a semantics-preserving no-op must survive ([testing-quality-harness-reverse-controls]) |
| A test intentionally has no outcome assertion (smoke test: module loads, page renders) | Keep it only when the regression it guards manifests as a throw; name it as a smoke test so reviewers do not count it as behavior coverage |
| The branch under test writes a flag or counter that a later loop, retry, or error handler on the same path also writes | Assert it from an input that leaves the other writers inert (empty collection, zero retries, no error injected); with both active the observable is the same whether or not the branch ran, so deleting the branch entirely keeps the suite green |
| The always-green test is a snapshot approved without reading | Snapshot rules → [testing-quality-behavior-not-implementation] |
| Assertions were just pulled into a shared contract (base class, mixin, parameterised suite) so several subjects now run them | Re-prove each assertion against each subject: the assertion's scope stayed where it was written while its name now speaks for every subject — one mutation per (assertion, subject) pair is the granularity |
| The two implementations under comparison model different amounts of state | An agreement verdict on the default input cannot fail for the unmodelled dimension → [testing-quality-differential-run-agreement] |
| Runner invokes the subject differently than production does (`bash script.sh` on a `#!/bin/sh` file, `node` on a file production runs under a different runtime/flags) | Invoke it the way production does, or add one job that does — a shebang is honoured only when the file is executed directly, so passing it to an interpreter silently swaps the interpreter and the suite becomes blind to that whole bug class ([platforms-shells-portable-shell-scripts]) |
| The mutation is applied by a script (`sed`/`awk`) rather than by hand | Assert the edit landed — `diff` the file or grep for the injected text — and treat "mutation did not apply" as its own outcome: a pattern that matches nothing still exits 0, the code never changed, and the green run reads exactly like a blind test |
| Mutating a guard that returns an error code (`if [ "$x" != "ok" ]; then exit 6; fi`) | Mutate it toward *unreachable* (make the condition impossible), not toward *always-firing* — an always-firing guard produces the asserted exit code more often, so the test stays green and proves nothing |
| HTTP test of a write endpoint asserting only the response status | Read the persisted record back and assert the values sent — a request whose body never decoded still returns the success status ([testing-quality-write-path-assertions]) |
| The suite total dropped after a restore but the run still looks green | Read it as a lost import or file, not a passing suite: a module that fails to import contributes one error and removes all of its tests from the total. Compare totals against the pre-mutation run, then restore from the copy again |
| Several sessions or agents mutate the same working tree | Each one keeps its own hashed copy and restores before handing the tree on; a shared `git checkout --` discards whichever uncommitted work landed most recently |
| The change under test moved a literal into config/SSOT without changing the value | No observation of the output can separate the two versions — assert the dependency by substituting the constant with a sentinel ([testing-quality-value-preserving-refactor-assertions]) |
| The subject returns a composite and the assertions read one field | Diff the returned field list against the fields assertions mention, then mutate each unread field and add the invariant that binds them ([testing-quality-unasserted-return-fields]) |
| The "before" side of a comparison is a previously published output file | Date its generation from its schema fields and compare row by row before citing it; matching totals do not establish matching rows ([testing-quality-stale-artifact-baselines]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add `expect(result).toBeDefined()` to give a test "an assertion" | Assert the specific value/shape the behavior guarantees | `toBeDefined` on an always-defined value passes for every behavior, including broken |
| Prove an error path with `try { await f() } catch (e) { expect(e.message)... }` alone | Use `rejects`/`assertThrows`-style assertion, or add `expect.assertions(1)` above the try | When `f()` succeeds, the catch never runs and the test passes with zero assertions |
| Trust "green suite + high coverage" as proof an area is tested | Break the behavior once and require a red run | Coverage counts execution, not detection; high numbers are reachable with assertion-free tests |
| Read "the branch's tests pass and its lines are covered" as the branch being guarded | Delete the branch and require a test to redden; when none does, add an input that isolates it | A co-occurring writer of the same flag makes coverage and assertion counts rise while nothing pins the branch's own contribution |
| Delete a suspicious always-green test to clean up | Fix it via the table above, then re-verify it can fail | The test names a behavior someone meant to guard; deletion drops the intent along with the defect |
| Prove a test file can fail by seeding one mutation and watching the file go red | Seed one mutation per assertion and require exactly the owning test to redden | A file-level red is produced by whichever assertion happens to be strictest; the silent ones remain unproven |
| Pick a mutation from what the test's name says it covers | Pick it from what the assertion body actually reads | An assertion inherited into a shared contract keeps its original narrow scope, so a reasonable-looking mutation sails past it |
| Undo a red-run mutation with `git checkout -- <path>` while the fix under test is unstaged | Restore from a copy saved before mutating and compare hashes, or `git add` the fix first | The checkout restores the index copy and discards every unstaged change, so it removes the fix and the mutation together while reporting nothing |

## Sources

- https://jestjs.io/docs/expect — `expect.assertions(n)` / `expect.hasAssertions()` guard callback assertions; `.rejects`, `.toThrow`
- https://jestjs.io/docs/asynchronous — un-awaited promises let tests finish early; `.rejects`; `expect.assertions` with try/catch
- https://testing.googleblog.com/2021/04/mutation-testing.html — inserting faults and requiring test failure measures whether tests detect bugs; coverage alone does not
- https://pitest.org/quickstart/basic_concepts/ — a kill is attributed to the covering test, not the file: per-assertion granularity is the tool model
- https://martinfowler.com/bliki/TestCoverage.html — coverage finds untested code; it is not a measure of test quality
- https://testing.googleblog.com/2013/05/testing-on-toilet-dont-overuse-mocks.html — mock-heavy tests can pass while the real code is broken
- https://man7.org/linux/man-pages/man2/execve.2.html — the shebang is honoured only on direct execution, not when a file is passed to an interpreter
- https://www.gnu.org/software/sed/manual/html_node/Exit-status.html — a `sed` expression that matches nothing still exits 0
- https://git-scm.com/docs/git-checkout, https://git-scm.com/docs/git-restore — `checkout -- <path>` restores the index copy, discarding unstaged changes; measured 2026-08-05: with the fix unstaged the checkout removed fix and mutation together, and the lost import surfaced as `Ran 1042 … errors=1` where the intact tree ran 1098
- https://tiswww.case.edu/php/chet/bash/COMPAT — bash-4.0 changed `set -e` handling so the shell exits when a compound command fails; bash-3.2 and earlier do not, which is what lets a false mid-test `[[ ]]` pass silently under bats on macOS system bash
- https://bats-core.readthedocs.io/en/stable/gotchas.html, https://www.shellcheck.net/wiki/SC2314 — the documented same-shape gotcha: bats commands whose failure is excluded from errexit (negated `!` commands) "can never fail when used in the middle of a test"
- Local reproduction 2026-08-06 (Bats 1.14.0, GNU bash 3.2.57, macOS arm64): a false `[[ "a" == *"zzz"* ]]` mid-test → `ok`; the same false comparison as `[ "a" = "zzz" ]` or piped `grep -qF` mid-test → `not ok`; the `[[ ]]` as the test's last line → `not ok`. Outside bats, `bash -ec '[[ … ]]; echo survived'` printed and exited 0 while the `[ ]` form aborted — bash-3.2 errexit semantics, not a bats defect
- Field reproduction 2026-08-12 (a Python health-check daemon, `heal_detector.py`): the `secret_source == "none"` branch sets `run_ok = False; send_failed = True` before the message loop, and the loop's own failure handling sets the same two. Deleting the branch entirely left all 42 tests passing, because both `none` cases supplied trigger messages that fail in the loop. Adding one case with `messages=[]` — the branch's only active writer — turned the same deletion RED in 1 test, with no assertion changed
