---
id: testing-quality-differential-run-agreement
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - W. M. McKeeman, "Differential Testing for Software", Digital Technical Journal 10(1), 1998, pp. 100-107
  - https://arxiv.org/abs/2410.21904
  - https://pitest.org/quickstart/basic_concepts/
  - https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/
last_verified: 2026-08-05
related: [testing-strategy-differential-testing, testing-quality-harness-reverse-controls, testing-quality-tests-that-cannot-fail, testing-quality-minimum-case-set]
---

# Citing an "Agree" Verdict from a Differential Run

## When this applies

You ran two implementations of one spec on the same input, the harness reported
agreement (`EQUIVALENT`, "no diff", "N/N checks pass"), and you are about to cite
that verdict as evidence in a commit, PR, README, or report. Also when the two
sides model different amounts of state — one has a repository, cache, clock, or
session the other stubs out, omits, or hard-codes.

## Do this

1. **Before citing agreement, write down the state each side models and diff the
   two lists.** Every entry that appears on one side only is a dimension the run
   did not compare. A side that holds no repository cannot fail for a repository
   reason, so on any input where the repository does not decide the outcome it
   agrees with the stateful side by construction.

2. **Re-run with an input that makes each asymmetric dimension decide the
   outcome, and report that verdict separately from the default-input one.**
   Pick the input from what the dimension is:

| Asymmetric state | Input that makes it decide |
|------------------|----------------------------|
| Repository / persisted rows | Empty seed, or a seed missing exactly the row the flow reads |
| Uniqueness or key constraint | Two operations writing the same key in one run |
| Cache | Cold cache, then a second run against the warm one |
| Clock / deadline / TTL | A duration past the deadline the flow enforces |
| Session or auth context | A request with the identity absent or belonging to another owner |

3. **Read the default-input verdict as its literal claim: "the two sides agree on
   inputs where the unmodelled state does not decide the outcome."** That is a
   real result and a narrow one. Publish it in that form rather than as bare
   agreement.

4. **Treat divergence under the forcing input as the run's most informative
   output, not as a harness defect.** Record which side stopped and where — the
   step at which the two traces separate localizes the fault to one side.

5. **When the state-blind side cannot represent the forcing input at all,
   record the dimension as untested.** An input the harness cannot express is a
   coverage gap, and calling it agreement asserts something the run never
   evaluated.

6. **Ground the choice of input in reachability.** A fault is detected only when
   the test reaches it, infects the state, and propagates that state to the
   observed output (the RIP conditions). On the default input the asymmetric
   dimension is never reached, so no verdict about it is possible — the same
   reason a mutation-testing tool reports **no coverage** rather than **survived**
   for a mutant no test executes.

## Edge cases

| Case | Then |
|------|------|
| Both sides model the state, and they agree | The verdict is informative for that dimension; cite it with the forcing input named so a reader can see which dimension was exercised |
| The state-blind side is a deliberate reference model (a simplified oracle) | Scope the harness's claim to the modelled subset in its own output, and add a separate check that the unmodelled subset is covered elsewhere |
| The forcing input makes both sides fail identically | Confirm they fail for the same reason before counting it as agreement; identical failure text from different causes is a coincidence, not a comparison |
| Agreement is reported across a matrix of inputs, all of them defaults | The matrix size is not evidence; one forcing input per asymmetric dimension outranks a hundred default rows |
| The harness reports agreement and the score has already been published | Re-run with the forcing inputs before defending the number, and correct the citation when a dimension turns out untested |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Cite `EQUIVALENT` on the default input as proof two implementations match | Cite it as agreement on inputs where the unmodelled state does not decide, plus the separate forcing-input verdict | The state-blind side agrees by construction on the happy path, so the verdict certifies nothing about the dimension the harness exists to check |
| Add more default-shaped inputs to raise confidence | Add one input per asymmetric dimension, chosen so that dimension decides the outcome | Inputs that never reach the asymmetry re-prove the same fact; RIP requires reachability before any detection is possible |
| Read a divergence under a forcing input as the harness being too strict | Read it as the finding, and localize by the step at which the traces separate | The forcing input is the only place the harness can produce information about that dimension |
| Report one combined verdict for a run with mixed inputs | Report the default verdict and the forcing verdict as two lines | A single line lets a narrow agreement read as full coverage |

## Sources

- W. M. McKeeman, "Differential Testing for Software", Digital Technical Journal 10(1), 1998, pp. 100-107 — classic foundational work on differential testing methodology
- https://arxiv.org/abs/2410.21904 — recent work on differential testing applications and interpretation
- https://pitest.org/quickstart/basic_concepts/ — mutation testing concepts: no coverage, survived, killed
- https://stryker-mutator.io/docs/mutation-testing-elements/mutant-states-and-metrics/ — reachability, infection, and propagation (RIP) model for fault detection
