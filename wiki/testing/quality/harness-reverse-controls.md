---
id: testing-quality-harness-reverse-controls
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://pitest.org/quickstart/basic_concepts/
  - https://stryker-mutator.io/docs/stryker-js/configuration/
  - https://stryker-mutator.io/docs/stryker-js/troubleshooting/
  - https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/
  - https://stryker-mutator.io/docs/mutation-testing-elements/equivalent-mutants/
  - https://testing.googleblog.com/2021/04/mutation-testing.html
last_verified: 2026-08-02
related: [testing-quality-tests-that-cannot-fail, testing-quality-minimum-case-set]
---

# Citing a Verification Harness's Own Score

## When this applies

You built a harness that reports how well something is verified — a mutation run, a
doc/spec gate suite, a matrix of CI checks — and you are about to cite its score as
evidence in a commit message, PR body, README, or report. Also when its verdicts
come out uniform across every case: every mutant caught, or every one surviving.

## Do this

1. **Run a case whose correct verdict is the opposite of the failure you are
   hunting, and require that verdict, before citing any score.** For a mutation
   harness the control is a semantics-preserving change (reformat, rename a local,
   edit a comment or docstring). That is an *equivalent mutation* — PIT's term for a
   mutant that "behaves in exactly the same way as the original" — so no correct
   test can kill it. Require **survived**. When the harness reports it caught, stop
   and report that nothing was measured: the cases are failing before the rule under
   test ever runs.
2. **Read a uniform verdict as a property of the harness, not of the code:**

| Observed | Read it as | Do |
|----------|------------|-----|
| Mixed verdicts, and the no-op control survived | The harness discriminates | Cite the score together with the control's result |
| Every case caught / red, including the no-op control | Cases die before the rule executes — a broken isolated environment (missing input files, absent dependency, wrong working directory) | Fix the environment, then re-run the control; a 100% catch rate here is a 0% detection rate |
| Every case survives / green | The harness never applied the mutation or never reached the rule — Stryker's troubleshooting carries two distinct "All mutants survive" sections whose documented causes are both sandbox mechanics, not weak tests (the Jest runner cannot run in a hidden temp directory; sandboxing does not support `module-alias/register`) | Verify one mutation reaches the artifact by hand before adjusting the rules |

3. **Observe the harness produce a verdict on the unmutated artifact first.** Stryker
   makes this a named phase — "Initial test run fails" is its own documented failure
   mode, and `dryRunOnly` ("Execute the initial test run only without doing actual
   mutation testing") runs the phase alone; the run's timing (`netTimeMs`,
   `overheadMs`) is derived from it. A harness never seen reporting the unmutated
   state has no reference point.
4. **Give the harness a working tree equivalent to the real runner's.** When
   isolating into a temp directory, copy the whole repository rather than the
   directory under test — a partial copy silently removes fixtures, data files, and
   path anchors that tests resolve relative to the repo root.
5. **Make "the case never ran" a distinct outcome from "the case ran and passed."**
   Count executed cases and fail the harness when the count is zero. Stryker's Vitest
   runner does exactly this — "No tests were executed. Stryker will exit prematurely.
   Please check your configuration." — and PIT separates **no coverage** from
   **survived** ("the same as Survived except there were no tests that exercised the
   line of code where the mutation was created").
6. **Score `detected / valid`, keeping errored cases out of the numerator *and* the
   denominator.** Stryker models `Killed` and `Survived` alongside `Timeout`,
   `Runtime error` and `Compile error`, and computes the score as
   "detected / valid * 100". A case that blew up before reaching the rule is invalid,
   not a detection — folding the two together is the arithmetic that turns a broken
   environment into a perfect score.
7. **Publish the score with the control alongside it** — "34/36 caught; no-op
   control survived" — so the number carries its own proof of discrimination.

## Edge cases

| Case | Then |
|------|------|
| A no-op change is impossible to construct (fully generated artifact) | Use a whitespace- or comment-only edit of the generator's input, and require the same survived verdict |
| The no-op control is legitimately caught | An assertion is pinned to formatting rather than behavior — narrow that assertion, then re-run; the control is measuring the right thing and finding a real over-specification ([testing-quality-tests-that-cannot-fail]) |
| The harness genuinely catches every real mutant (small rule set, exhaustive cases) | The no-op control is then the only evidence separating that from a broken harness — report it explicitly rather than the bare percentage |
| A mutation changes behavior in a way outside what the suite is meant to cover | PIT's second undetectable class (it excludes logging code for this reason) — exclude that region from the mutation set instead of adding a test to chase it |
| The score is already published and cited | Re-run with the control before defending the number, and correct the citation when the control fails |
| Individual checks each have a negative control already | Add the harness-level control too — a per-check control asks "can this check go red", the harness control asks "can this harness go green"; the second failure mode survives the first |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Cite "N/N caught" as proof the rules are enforced | Run the no-op control first and cite the score with its result | A harness whose cases all die before the rule runs reports every mutant as caught while detecting nothing |
| Read a uniform 100% detection rate as strength | Treat uniformity as the fault signal and run the control | Discriminating measurement produces mixed results; a single verdict for every input is what a constant function looks like |
| Tighten the rules when every case comes back red | Verify one case reaches the rule, then re-run the control | Rules are not what fails when the environment is missing the inputs the cases need |
| Copy only the directory under test into the harness's temp tree | Copy the repository, or fail the case on a missing input | Tests that resolve paths from the repo root read as detections when they die on a missing file |

## Sources

- https://pitest.org/quickstart/basic_concepts/ — "not all mutations will behave differently than the unmutated class. These mutants are referred to as **equivalent mutations**"; "The resulting mutant behaves in exactly the same way as the original"; a second undetectable class "behaves differently but in a way that is outside the scope of testing" (PIT excludes logging code); "**No coverage** is the same as **Survived** except there were no tests that exercised the line of code where the mutation was created"
- https://stryker-mutator.io/docs/stryker-js/configuration/ — the initial test run is a distinct phase with its own options: `dryRunOnly` "Execute the initial test run only without doing actual mutation testing", `dryRunTimeoutMinutes`; run timing (`netTimeMs`/`overheadMs`) is calculated during it
- https://stryker-mutator.io/docs/stryker-js/troubleshooting/ — section headings "Initial test run fails", "All mutants survive - Jest runner" (cause: Jest "doesn't support running in a hidden directory on windows") and "All mutants survive - module-alias" (cause: "StrykerJS's sandboxing does not support alias imports like `module-alias/register`") — both sandbox mechanics rather than test weakness; the Vitest-runner example "No tests were executed. Stryker will exit prematurely. Please check your configuration."
- https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/ — the state set (`Killed`, `Survived`, `No coverage`, `Timeout`, `Runtime error`, `Compile error`, `Ignored`) and the score as "detected / valid * 100", so errored cases leave the denominator rather than counting as catches
- https://stryker-mutator.io/docs/mutation-testing-elements/equivalent-mutants/ — an equivalent mutant cannot be killed and "There is no definitive way for Stryker to find and ignore them", which is why a surviving no-op is the correct control verdict
- https://testing.googleblog.com/2021/04/mutation-testing.html — inserting faults and requiring test failure is what measures detection, as opposed to coverage
- Field reproduction 2026-07-31 (Python rule-conformance harness): the harness copied only the implementation directory into its temp tree while the tests resolved `examples/*.json` from the repo root, so all 105 tests died on `FileNotFoundError` and every mutation reported as caught — "36/36" was cited in five commits and a README. A docstring-capitalization no-op reproduced the red verdict and exposed it; copying the full repository plus adding the no-op control moved the score to 34/36 and surfaced two rules no test asserted
