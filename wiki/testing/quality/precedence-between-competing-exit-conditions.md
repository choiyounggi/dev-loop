---
id: testing-quality-precedence-between-competing-exit-conditions
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://arxiv.org/abs/1909.04770
  - https://pitest.org/quickstart/basic_concepts/
  - https://testing.googleblog.com/2021/04/mutation-testing.html
last_verified: 2026-09-16
related: [testing-quality-tests-that-cannot-fail, testing-quality-policy-at-several-return-sites, testing-quality-completion-predicates, testing-quality-surviving-mutant-equivalence-triage, testing-quality-minimum-case-set, testing-quality-harness-reverse-controls]
---

# Asserting Which of Two Competing Exit Conditions Wins

## When this applies

A loop, monitor, or handler can end for more than one reason in the same pass —
a witness-confirmed exit code and a task-failure code, a timeout and a
cancellation — and a test claims one of them takes precedence. Also when
reviewing such a test, or judging whether it would catch a reordering of the
checks it names.

## Do this

1. **Stage the competing condition to become true in the same iteration the
   condition under test reaches its threshold.** Drive it from a stub the loop
   already calls, mutating fixture state as a side effect of a specific call
   count — the Nth `capture-pane`, the Nth status read — so both conditions are
   live at one decision point and the assertion depends on the order of the
   checks.

2. **Derive the staging iteration from the threshold, in the test.** A witness
   that needs two polls to confirm decides at poll 2, so the competing
   transition is staged at the same capture count the confirmation uses; writing
   the number as a literal detaches the staging from the threshold it must track.

3. **Prove the test by swapping the two checks in the source and requiring
   exactly that test to redden.** Restore from a pre-swap copy and compare
   hashes ([testing-quality-tests-that-cannot-fail] owns the restore rules).
   Read the result:

| Swap outcome | Read it as | Do |
|--------------|------------|-----|
| Only the precedence test reddens | The assertion discriminates on the order | Record the pair (swap → test) and move on |
| Every test in the file reddens | The edit hit shared code, not the two blocks | Narrow the swap to the two branches and re-run |
| The whole suite stays green | The competing condition is not live at the decision point | Move its staging to the deciding iteration, then re-run |
| The suite stays green and no case can stage both conditions at once | The two orders are indistinguishable for this suite | Triage it as an equivalent mutant ([testing-quality-surviving-mutant-equivalence-triage]) |

4. **Assert the loser's absence as well as the winner's code.** Require the exit
   code of the winning condition *and* that the losing branch's own side effect
   (its log line, status write, or cleanup) did not run — an implementation that
   runs both and returns the first code passes a code-only assertion.

## Edge cases

| Case | Then |
|------|------|
| The competing condition can only be made true before the condition under test could activate | The case proves reachability, not precedence — name it for what it proves and add a separate staged case for the ordering |
| Both exits are produced by one shared helper | Precedence lives at the call site that selects the argument; swap the call sites, not the helper's internals |
| Both conditions produce the same exit code | Give them distinct codes before writing the precedence test; with one code the observable cannot separate the orders |
| The stub has no call counter | Back the counter with a file the stub appends to, and read its line count as the iteration number — a subshell-local variable resets on each invocation |
| The loop breaks on the first match, so ordering is the entire contract | Keep the staged case and add one case per condition alone, so a regression that drops a branch is distinguishable from one that reorders it |
| The threshold is configurable at run time | Stage from the configured value the test passes in, and add a second case at a different threshold to prove the staging follows it |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Make the competing condition true from the first iteration so it is "definitely active" | Stage it at the iteration the condition under test decides | Firing first means the loop exits before the contested comparison is reached, so the assertion holds under either order and the test cannot fail |
| Read the source and call the precedence covered because the checks are in the right order | Swap the two blocks and require the test to redden | Reading confirms today's order; only the swap shows the suite would object to tomorrow's |
| Treat a green run after the swap as "the order does not matter" | Check whether any case has both conditions live at one decision point first | An untriggered competitor never infects the program state, so the mutant survives for lack of input, not for lack of consequence |

## Sources

- https://arxiv.org/abs/1909.04770 — Vera-Pérez, Danglot, Monperrus, Baudry (2019): an undetected mutant has three possible causes, the first being that "the test inputs are not sufficient to infect the state of the program" — the case here, where the competing condition never coexists with the decision
- https://pitest.org/quickstart/basic_concepts/ — a surviving mutant means no test distinguishes the mutated program; a kill is attributed to the covering test, so the precedence test must be the one that reddens
- https://testing.googleblog.com/2021/04/mutation-testing.html — inserting a fault and requiring a test failure is what measures detection; coverage of the branch does not
- Field evidence 2026-09-16 (dev-loop `watch-status.sh`, three "R6 precedence" bats cases): moving the exit-8 block above the failed/done check left all three green, because the competing task-failure status was staged before the two-poll witness could confirm. Re-staging the status transition to the same tmux-stub capture count that confirms the witness made the same swap red, and the rewritten cases stayed green on the unswapped source
