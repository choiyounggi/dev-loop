---
id: testing-quality-surviving-mutant-equivalence-triage
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://stryker-mutator.io/docs/mutation-testing-elements/equivalent-mutants/
  - https://pitest.org/quickstart/basic_concepts/
  - https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/
  - https://testing.googleblog.com/2021/04/mutation-testing.html
last_verified: 2026-08-07
related:
  [
    testing-quality-tests-that-cannot-fail,
    testing-quality-harness-reverse-controls,
    testing-quality-minimum-case-set,
    testing-quality-behavior-not-implementation,
    testing-quality-source-text-wiring-assertions,
    backend-common-change-impact-call-site-enumeration,
  ]
---

# A Surviving Mutant Before You Write a Test for It

## When this applies

A mutation run (PIT, Stryker, or a hand-seeded mutation) left a mutant alive on
code you own, and you are deciding what to change. Also when a reviewer asks for
a test to cover a specific surviving mutant, or a defensive branch you added has
a comment explaining why it is needed and its mutant survives.

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
| The line is covered, and some input in the branch's domain makes original and mutant differ                           | Missing or weak test                        | Add that input as a case ([testing-quality-minimum-case-set]), then re-run the mutation and require red                     |
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

## Edge cases

| Case                                                                                                        | Then                                                                                                                                                                                           |
| ----------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The branch is unreachable through the public interface but reachable through another entry point            | Not equivalent — it is uncovered from this level. Move the test to the level that reaches it ([testing-quality-behavior-not-implementation]) rather than deleting the branch                   |
| The mutated behavior differs only in a dimension the suite is not meant to cover (logging, metrics, timing) | PIT's second undetectable class — exclude that region from the mutation set instead of adding a test to chase it                                                                               |
| The redundant branch exists for readability at a trust boundary (validating external input twice)           | Keep it and record why in the comment as a deliberate defense-in-depth, not as a correctness claim; the mutant stays a classified survivor                                                     |
| The equivalence holds only for the current caller set                                                       | Treat it as coverage, not equivalence: enumerate the call sites ([backend-common-change-impact-call-site-enumeration]); when a future caller could pass the absorbed input, the branch is live |
| Several mutants survive in the same function                                                                | Classify each one separately — one verdict covering all of them hides whichever is the other kind                                                                                              |
| The tool reports a 100% kill rate with no survivors at all                                                  | Read that as a harness signal, not a code signal, and run the no-op control ([testing-quality-harness-reverse-controls])                                                                       |
| The survivor is on a wiring call asserted by a source-text regex rather than by behavior                    | The count-style assertion is what let it live → [testing-quality-source-text-wiring-assertions]                                                                                                |

## Instead of

| If you are about to                                                                    | Do this instead                                                                                                                                 | Why                                                                                                                                                                     |
| -------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Read every surviving mutant as a test gap and write a case for it                      | Classify it against the step-1 table first                                                                                                      | An equivalent mutant cannot be killed by any correct test, so the case you add asserts a behavior the code does not have and passes for every implementation            |
| Declare equivalence because one input produced the same result                         | Write the step-2 domain argument, or classify it as a missing test                                                                              | Agreement on one value is what both classes look like; the deletion in step 3 changes production code, so it needs the stronger claim                                   |
| Chase a 100% mutation score by testing the survivors that resist                       | Take one of the two documented outcomes: rewrite the code so the mutant cannot arise, or record the survivor as classified and accept the score | Stryker states there is no definitive way to detect equivalent mutants and names accepting a sub-100% score as an acceptable outcome                                    |
| Delete a redundant branch and leave its explanatory comment on the remaining condition | Replace the comment with the absorbing condition from step 2                                                                                    | The comment stated why the deleted branch was necessary; the equivalence proof contradicts that claim, and the next reader refactors the surviving condition against it |
| Suppress or ignore the mutant in the tool's config to get the run green                | Record the classification in the code (step 4) and leave the mutant visible                                                                     | A suppression carries no reason, so the next person re-derives the same analysis; a corrected comment carries it                                                        |

## Sources

- https://stryker-mutator.io/docs/mutation-testing-elements/equivalent-mutants/ — "There is no definitive way for Stryker to find and ignore them"; "The only solution is by finding these by hand, which is time consuming and try to rewrite the code so it won't occur, or accept that you won't make 100%" — both halves of that sentence are load-bearing here: rewriting is one outcome, a classified survivor is the other
- https://pitest.org/quickstart/basic_concepts/ — "Not all mutations will behave differently than the unmutated class. These mutants are referred to as **equivalent mutations**"; "The resulting mutant behaves in exactly the same way as the original"; and the distinct verdicts "Survived: The mutation was not detected by the covering test" vs "No coverage: The same as Survived except there were no tests that exercised the line of code where the mutation was created" — the split in step 1
- https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/ — the mutant state set and `detected / valid` scoring, which is what makes classifying a survivor a prerequisite to reporting the number
- https://testing.googleblog.com/2021/04/mutation-testing.html — inserting faults and requiring test failure is the measurement; a fault that changes no observable behavior is not one
- Field measurement 2026-08-07 (rtb-unified, `apps/web` building-detail URL parsing): a mutant that deleted the empty-string guard on `?buildingId=` survived. The domain argument was that the guard's whole input set is strings that `Number()` maps to `0` or `NaN`, both of which the following `parsed > 0` rejects — so no accepted input distinguishes the two. The branch's comment claimed "an empty string is otherwise read as 0", which that argument contradicts. Deleting the branch and rewriting the comment left all 49 tests passing at the same count
