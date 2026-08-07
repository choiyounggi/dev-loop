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
   three things, and only one of them is a missing test. Run the mutated code
   against the input the branch claims to guard, by hand, and read the result:

| What the mutated code does on the guarded input               | Class                                                                                                          | Do                                                                                                                  |
| ------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Produces a different observable result than the original      | Missing or weak test                                                                                           | Add the case that distinguishes them ([testing-quality-minimum-case-set]), then re-run the mutation and require red |
| Produces the same observable result for every reachable input | Equivalent mutant — the mutated code is redundant                                                              | Steps 2–4: delete the redundancy rather than testing it                                                             |
| The line is never executed by any test                        | PIT's separate `No coverage` state — "the same as Survived except there were no tests that exercised the line" | Add a test that reaches the line first; the kill/survive question is not answerable until then                      |

2. **When the mutant is equivalent, find the condition that already absorbs it.**
   Equivalence means some other expression makes the mutated one unobservable —
   a later comparison, a type coercion, a caller-side check. Name that condition
   explicitly; it is the reason the branch is dead.

3. **Rewrite the code so the equivalent mutant cannot arise.** This is the
   remedy Stryker documents: "try to rewrite the code so it won't occur".
   Delete the redundant branch and keep the condition found in step 2 as the
   single decision point.

4. **Correct the justification comment in the same edit, using the mechanism you
   just measured.** A branch removed in step 3 usually carries a comment saying
   why it exists. That comment asserted a mechanism the equivalence just
   disproved, so leaving it in place moves a false premise onto whichever
   condition remains. Replace it with what the measurement showed, or delete it
   when the remaining condition is self-evident.

5. **Re-run the full suite and require the same pass count as before the edit.**
   Deleting a genuinely redundant branch changes no test outcome; a suite that
   moves means the branch was load-bearing and step 1 misclassified it — restore
   and re-run step 1 with the input that changed.

## Edge cases

| Case                                                                                                        | Then                                                                                                                                                                                           |
| ----------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The branch is unreachable through the public interface but reachable through another entry point            | Not equivalent — it is uncovered from this level. Move the test to the level that reaches it ([testing-quality-behavior-not-implementation]) rather than deleting the branch                   |
| The mutated behavior differs only in a dimension the suite is not meant to cover (logging, metrics, timing) | PIT's second undetectable class — exclude that region from the mutation set instead of adding a test to chase it                                                                               |
| The redundant branch exists for readability at a trust boundary (validating external input twice)           | Keep it and record why in the comment as a deliberate defense-in-depth, not as a correctness claim; the mutant stays a known survivor                                                          |
| The equivalence holds only for the current caller set                                                       | Treat it as coverage, not equivalence: enumerate the call sites ([backend-common-change-impact-call-site-enumeration]); when a future caller could pass the absorbed input, the branch is live |
| Several mutants survive in the same function                                                                | Classify each one separately — a single function commonly carries one missing test and one equivalent mutant, and one verdict for all of them hides whichever is the other kind                |
| The tool reports a 100% kill rate with no survivors at all                                                  | Read that as a harness signal, not a code signal, and run the no-op control ([testing-quality-harness-reverse-controls])                                                                       |
| The survivor is on a wiring call asserted by a source-text regex rather than by behavior                    | The count-style assertion is what let it live → [testing-quality-source-text-wiring-assertions]                                                                                                |

## Instead of

| If you are about to                                                                    | Do this instead                                                                                            | Why                                                                                                                                                            |
| -------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Read every surviving mutant as a test gap and write a case for it                      | Classify it against the step-1 table first                                                                 | An equivalent mutant cannot be killed by any correct test, so the case you add asserts a behavior the code does not have and passes for every implementation   |
| Chase a 100% mutation score by testing the survivors that resist                       | Rewrite the code so the equivalent mutant cannot arise, and report the score with the survivors classified | Stryker states there is no definitive way to detect equivalent mutants and that accepting a sub-100% score is the intended outcome                             |
| Delete a redundant branch and leave its explanatory comment on the remaining condition | Replace the comment with the mechanism the equivalence measurement showed                                  | The comment stated why the deleted branch was necessary; equivalence proved that claim false, and the next reader refactors the surviving condition against it |
| Suppress or ignore the mutant in the tool's config to get the run green                | Record the classification in the code (step 4) and leave the mutant visible                                | A suppression carries no reason, so the next person re-derives the same analysis; a corrected comment carries it                                               |

## Sources

- https://stryker-mutator.io/docs/mutation-testing-elements/equivalent-mutants/ — "There is no definitive way for Stryker to find and ignore them"; the remedy is "by finding these by hand, which is time consuming and try to rewrite the code so it won't occur, or accept that you won't make 100%"; the documented patterns include operations with neutral values, where several operators produce identical output
- https://pitest.org/quickstart/basic_concepts/ — "Not all mutations will behave differently than the unmutated class. These mutants are referred to as **equivalent mutations**"; "The resulting mutant behaves in exactly the same way as the original"; and the distinct verdicts "Survived: The mutation was not detected by the covering test" vs "No coverage: The same as Survived except there were no tests that exercised the line of code where the mutation was created" — the three-way split in step 1
- https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/ — the mutant state set and `detected / valid` scoring, which is what makes classifying a survivor a prerequisite to reporting the number
- https://testing.googleblog.com/2021/04/mutation-testing.html — inserting faults and requiring test failure is the measurement; a fault that changes no observable behavior is not one
- Field measurement 2026-08-07 (rtb-unified, `apps/web` building-detail URL parsing): a mutant that deleted the empty-string guard on `?buildingId=` survived. Hand-running the guarded input showed `Number('') === 0`, which the following `parsed > 0` check already rejected — equivalent, not a gap. The branch's comment claimed "an empty string is otherwise read as 0", which the measurement disproved. Deleting the branch and rewriting the comment to the measured mechanism kept all 49 tests passing at the same count
