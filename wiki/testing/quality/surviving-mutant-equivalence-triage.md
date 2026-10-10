---
id: testing-quality-surviving-mutant-equivalence-triage
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://stryker-mutator.io/docs/mutation-testing-elements/equivalent-mutants/
  - https://stryker-mutator.io/docs/stryker-js/incremental/
  - https://pitest.org/quickstart/incremental_analysis/
  - https://pitest.org/quickstart/basic_concepts/
  - https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/
  - https://testing.googleblog.com/2021/04/mutation-testing.html
  - https://html.spec.whatwg.org/multipage/form-control-infrastructure.html
  - https://bugs.webkit.org/show_bug.cgi?id=193758
last_verified: 2026-10-11
related:
  [
    testing-quality-tests-that-cannot-fail,
    testing-quality-harness-reverse-controls,
    testing-quality-mutation-harness-file-custody,
    testing-quality-minimum-case-set,
    testing-quality-behavior-not-implementation,
    testing-quality-source-text-wiring-assertions,
    backend-common-change-impact-call-site-enumeration,
    qa-process-evaluating-review-feedback,
    frontend-browser-apis-copying-text-from-a-tap,
  ]
---

# A Surviving Mutant Before You Write a Test for It

## When this applies

A mutation run (PIT, Stryker, or a hand-seeded mutation) left a mutant alive on
code you own, and you are deciding what to change. Also when a reviewer asks for
a test to cover a specific surviving mutant (including an "also assert X" edit to
an existing test block), or a defensive branch you added has a comment explaining
why it is needed and its mutant survives.

Building the mutation harness itself, or citing its score →
[testing-quality-harness-reverse-controls].

## Do this

1. **Classify the survivor before writing anything.** A live mutant is one of
   three things, and only one of them is a missing test. Start from the tool's
   own verdict, then decide the remaining split by argument over the input
   domain, not by trying one value:

| Signal                                                                                                                | Class                                       | Do                                                                                                                          |
| --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| The tool reports `No coverage` — "there were no tests that exercised the line of code where the mutation was created" | Uncovered line                              | Add a test that reaches the line, then re-run the mutation; the kill/survive question is not answerable until it is covered |
| The line is covered, and some input in the branch's domain makes original and mutant differ                           | Missing or weak test                        | Add that input as a case ([testing-quality-minimum-case-set]), then re-run the mutation and require red; when the case goes into an existing test block, follow step 6 |
| The line is covered, and step 2 produces a proof that no input in the branch's domain makes them differ               | Equivalent mutant — the branch is redundant | Steps 3–5                                                                                                                   |

2. **Prove equivalence over the domain, not over one input.** Name the condition
   elsewhere in the code that absorbs the mutated branch — a later comparison, a
   type coercion, a caller-side check — and state why it covers the branch's
   whole input set (`Number(s) === 0` for every `s` the branch accepts is
   rejected by a following `parsed > 0`). One value that agrees is consistent
   with equivalence and does not establish it. When you cannot write that
   argument, treat the mutant as the missing-test row and add the case: Stryker
   states "There is no definitive way for Stryker to find and ignore them", so
   the burden of proof sits on the deletion, not on keeping the branch.

3. **Delete the redundant branch and keep the absorbing condition from step 2 as
   the single decision point.** Stryker's guidance names two acceptable
   outcomes — "The only solution is by finding these by hand, which is time
   consuming and try to rewrite the code so it won't occur, or accept that you
   won't make 100%" — so recording the mutant as a classified survivor is the
   correct alternative when the branch stays for a reason in the edge table.

4. **Correct the justification comment in the same edit, using the argument from
   step 2.** When the branch removed in step 3 carries a comment saying why it
   exists, that comment asserted a mechanism the equivalence proof contradicts,
   so leaving it in place moves a false premise onto whichever condition remains.
   Replace it with the absorbing condition you named, or delete it when that
   condition is self-evident.

5. **Re-run the full suite and read a changed pass count by what moved:**

| After the deletion                                                                                              | Read it as                                                       | Do                                                                                |
| --------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| Same pass count                                                                                                 | The branch had no observable consequence the suite asserts       | Keep the deletion                                                                 |
| A behavior test reddens (asserting an input/output pair)                                                        | Step 2's domain argument is wrong — the branch is live           | Restore it and re-classify with the input that failed                             |
| Only a test that names the branch itself reddens (source-shape guard, branch-coverage threshold, path snapshot) | The deletion is correct and the test asserted the implementation | Update that test to the new shape ([testing-quality-behavior-not-implementation]) |

6. **When the fix lands in an existing test block, add to the block and re-run
   every mutant it covers.** The review names the mutant it wants killed, not the
   ones the block already kills, so re-running the named mutant cannot see them.
   Copy the block's assertion lines aside before editing, and put the new
   assertion beside them; when it needs another input or environment
   (`NODE_ENV=production` beside a block written for `test`), give it its own
   case, because switching the block's input retargets every assertion in it.
   Afterwards diff the assertion lines, require that none disappeared, and
   compare every mutant's verdict with the pre-edit run. With the source
   untouched, PIT and Stryker apply the same rule: they reuse a "Killed" result
   only while its killing test still exists unchanged.

| After the edit                                                         | Read it as                                                  | Do                                                                                                           |
| ---------------------------------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| The named mutant is killed and every previously killed mutant still is | The fix added detection and removed none                    | Keep the edit                                                                                                |
| The named mutant is killed and a previously killed mutant now survives | The edit removed or retargeted the assertion that killed it | Restore that assertion beside the new one (or move the new one into its own case), then re-run the whole set |
| The named mutant still survives                                        | The new assertion does not read what the mutant changes     | Re-classify it with the step-1 table                                                                         |

## Edge cases

| Case                                                                                                        | Then                                                                                                                                                                                           |
| ----------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The branch is unreachable through the public interface but reachable through another entry point            | Not equivalent — it is uncovered from this level. Move the test to the level that reaches it ([testing-quality-behavior-not-implementation]) rather than deleting the branch                   |
| The mutated behavior differs only in a dimension the suite is not meant to cover (logging, metrics, timing) | PIT's second undetectable class — exclude that region from the mutation set instead of adding a test to chase it                                                                               |
| The redundant branch exists for readability at a trust boundary (validating external input twice)           | Keep it and record why in the comment as a deliberate defense-in-depth, not as a correctness claim; the mutant stays a classified survivor                                                     |
| The equivalence holds only for the current caller set                                                       | Treat it as coverage, not equivalence: enumerate the call sites ([backend-common-change-impact-call-site-enumeration]); when a future caller could pass the absorbed input, the branch is live |
| The survivor deletes one of two calls the test environment implements identically — under jsdom 30.1.2, `textarea.select()` already sets the range that `setSelectionRange(0, value.length)` sets | Equivalent in that environment only, so keep both calls: each exists for an engine the suite does not run (iOS `select()` moved the caret instead of selecting until WebKit fixed it in 2019, and WebKit's legacy copy example calls `setSelectionRange`). Prove the test with mutants the environment can observe — `setSelectionRange(0, len - 1)`, or deleting both calls — and require red; capture `selectionStart`/`selectionEnd` inside the `execCommand` stub, because the fallback removes its textarea before returning ([frontend-browser-apis-copying-text-from-a-tap]) |
| Several mutants survive in the same function                                                                | Classify each one separately — one verdict covering all of them hides whichever is the other kind                                                                                              |
| Step 6's re-run is a Stryker incremental run                                                                | With the source untouched, Stryker re-runs a killed mutant only when it sees the killing test change or disappear. Jest, Vitest and CucumberJS report test locations; Mocha and Tap mark every test in a changed file as changed; Jasmine and Karma see only added or removed tests; the command runner and static mutants see no test change. With Jasmine, Karma, the command runner or a static mutant, run `--force` — otherwise Stryker reuses the "Killed" verdicts recorded before the edit |
| The mutation run is your own script                                                                         | Save its pre-edit verdict table as the baseline and re-run the whole matrix after the edit — a script that records only pass/fail per mutant cannot tell which assertion each kill depended on ([testing-quality-mutation-harness-file-custody]) |
| The review asks to replace an existing assertion rather than add one                                        | Replace it, then run step 6's comparison: each previously killed mutant that now survives lost its only killer — add an assertion that kills it, or classify it with the step-1 table |
| A previously killed mutant now survives, yet the assertion diff shows nothing removed and the block's input is unchanged | Re-run that mutant against the pre-edit test block before restoring anything: when it survives there too, the earlier kill did not reproduce — a flaky verdict, not lost coverage ([testing-flaky-diagnosing-flaky-tests]) |
| The tool reports a 100% kill rate with no survivors at all                                                  | Read that as a harness signal, not a code signal, and run the no-op control ([testing-quality-harness-reverse-controls])                                                                       |
| The survivor is on a wiring call asserted by a source-text regex rather than by behavior                    | The count-style assertion is what let it live → [testing-quality-source-text-wiring-assertions]                                                                                                |
| The survivor was reported inside a review or audit whose verdict is PASS, labelled "secondary"              | The verdict scopes to the reviewer's FAIL list, not to coverage. Classify the survivor against the brief's own requirement list before accepting the label: a guarantee the brief states literally is the missing-test row; add the case, re-run the mutation and the same reviewer ([qa-process-evaluating-review-feedback]) |

## Instead of

| If you are about to                                                                    | Do this instead                                                                                                                                 | Why                                                                                                                                                                     |
| -------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Read every surviving mutant as a test gap and write a case for it                      | Classify it against the step-1 table first                                                                                                      | An equivalent mutant cannot be killed by any correct test, so the case you add asserts a behavior the code does not have and passes for every implementation            |
| Declare equivalence because one input produced the same result                         | Write the step-2 domain argument, or classify it as a missing test                                                                              | Agreement on one value is what both classes look like; the deletion in step 3 changes production code, so it needs the stronger claim                                   |
| Chase a 100% mutation score by testing the survivors that resist                       | Take one of the two documented outcomes: rewrite the code so the mutant cannot arise, or record the survivor as classified and accept the score | Stryker states there is no definitive way to detect equivalent mutants and names accepting a sub-100% score as an acceptable outcome                                    |
| Delete a redundant branch and leave its explanatory comment on the remaining condition | Replace the comment with the absorbing condition from step 2                                                                                    | The comment stated why the deleted branch was necessary; the equivalence proof contradicts that claim, and the next reader refactors the surviving condition against it |
| Suppress or ignore the mutant in the tool's config to get the run green                | Record the classification in the code (step 4) and leave the mutant visible                                                                     | A suppression carries no reason, so the next person re-derives the same analysis; a corrected comment carries it                                                        |
| Re-run only the mutant the review named after editing an existing test block           | Re-run every mutant the block covers and compare each verdict with the pre-edit run (step 6)                                                   | The named mutant turning red says nothing about mutants a removed assertion killed — reproduced: the named mutant went red while two previously killed mutants survived |

## Sources

- https://stryker-mutator.io/docs/mutation-testing-elements/equivalent-mutants/ — "There is no definitive way for Stryker to find and ignore them"; "The only solution is by finding these by hand, which is time consuming and try to rewrite the code so it won't occur, or accept that you won't make 100%" — both halves of that sentence are load-bearing here: rewriting is one outcome, a classified survivor is the other
- https://pitest.org/quickstart/basic_concepts/ — "Not all mutations will behave differently than the unmutated class. These mutants are referred to as **equivalent mutations**"; "The resulting mutant behaves in exactly the same way as the original"; and the distinct verdicts "Survived: The mutation was not detected by the covering test" vs "No coverage: The same as Survived except there were no tests that exercised the line of code where the mutation was created" — the split in step 1
- https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/ — the mutant state set and `detected / valid` scoring, which is what makes classifying a survivor a prerequisite to reporting the number
- https://testing.googleblog.com/2021/04/mutation-testing.html — inserting faults and requiring test failure is the measurement; a fault that changes no observable behavior is not one
- https://stryker-mutator.io/docs/stryker-js/incremental/ — "Reuse is possible when: A mutant was "Killed"; the culprit test still exists, and it didn't change." Whether an edit is seen depends on the runner: Jest, Vitest and CucumberJS are "Full"; for Mocha and Tap "Stryker assumes all tests inside a file changed when that file changed"; for Jasmine and Karma "Stryker will only see test changes for tests that are added or removed"; the command runner "will only detect changes in mutants, not their tests"; "Static mutants don't have test coverage; thus, Stryker won't detect test changes for them"; `--force` reruns "all mutants in scope, regardless of the incremental file"
- https://pitest.org/quickstart/incremental_analysis/ — "If a mutation was killed in the last run and neither the class under test or the killing test has changed, then it can be assumed that this mutation is still killed"; once the killing test has changed the kill is no longer assumed, and "the last killing test" is "prioritised above others" when the mutation is analysed again
- Local reproduction 2026-10-08 (Node 26.7.0, `node:test`, a fresh directory per mutant): a block asserting `resolveConfig('test')`'s `logLevel` and `seed`; mutants N1 (`'debug'`→`'info'`), N2 (`42`→`0`), A21 (`=== 'production'`→`=== 'prod'`) and a no-op control N0 (quote style). Before the fix N1 and N2 were killed and A21 survived. Rewriting the block to assert the `'production'` values killed A21 while N1 and N2 survived, and the assertion diff listed both removed lines. Adding the `'production'` assertions beside the old ones killed all three. The unmutated code passed every variant and N0 survived in every run
- Field evidence 2026-10-08 (linkly-invitation, task t2 Task 06 attempt 4; recorded by the originating session, not re-run in this flush): an auditor's "also assert" fix was applied by swapping the block's `NODE_ENV=test` assertion for a production one; mutants A9 and A21 were then killed while N1–N3 survived with 4/4 tests passing, and re-adding the two removed lines turned all three red
- Field measurement 2026-08-07 (rtb-unified, `apps/web` building-detail URL parsing): a mutant that deleted the empty-string guard on `?buildingId=` survived. The domain argument was that the guard's whole input set is strings that `Number()` maps to `0` or `NaN`, both of which the following `parsed > 0` rejects — so no accepted input distinguishes the two. The branch's comment claimed "an empty string is otherwise read as 0", which that argument contradicts. Deleting the branch and rewriting the comment left all 49 tests passing at the same count
- Field evidence 2026-09 (a Rust `serde` wire-format crate, crew-proto task t5-proto; recorded by the originating session, not re-run in this flush): a test-quality audit returned PASS and recorded that a `deny_unknown_fields` mutant survived all 12 tests as a "secondary" guarantee; the brief stated "unknown fields tolerated" literally, so the survivor was the missing-test row — one added case reddened under the mutant (13 tests, `unknown_entry_fields_are_tolerated ... FAILED`), the suite read 82 passed after restore, and the resumed auditor reproduced the kill
- Local reproduction 2026-10-11 (jsdom 30.1.2, Node 26.7.0; selection captured inside a `document.execCommand` stub, 19-character value): the original, `setSelectionRange` removed, and `select()` removed all read (0, 19); `setSelectionRange(0, len - 1)` read (0, 18); both removed read (19, 19). jsdom's `lib/jsdom/living/nodes/HTMLTextAreaElement-impl.js` `select()` sets `_selectionStart = 0` and `_selectionEnd = this._getValueLength()`; the HTML `select()` steps end "Set the selection range with 0 and infinity" (https://html.spec.whatwg.org/multipage/form-control-infrastructure.html); https://bugs.webkit.org/show_bug.cgi?id=193758 removed iOS's "We don't want to select all the text on iOS" (committed r240452, 2019-01-24). Field origin 2026-10-10 (linkly-invitation task t5b, vitest 5.0.3 + jsdom 30.1.2; recorded by the originating session): the same outcomes
