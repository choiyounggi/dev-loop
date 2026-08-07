---
id: qa-exploratory-guard-true-path-coverage
domain: qa
category: exploratory
applies_to: [general]
confidence: verified
sources:
  - https://istqb-glossary.page/branch-coverage/
  - "Field reproduction (lnpl 0.2.0, 2026-08-05): undeclared event reference passed compile (0 errors) and IR validation (PASS); failed only in runs that executed the guarded emit step; the one run where a presence guard skipped the step exited 0"
last_verified: 2026-08-05
related: [qa-exploratory-override-control-pairs, testing-quality-minimum-case-set, qa-exploratory-exploratory-sessions, qa-exploratory-lowered-declaration-survival, testing-data-harness-vs-run-path-fixtures]
---

# Executing Guard-True Paths When Static Stages Skip Reference Resolution

## When this applies

You are QA-ing a program or workflow whose steps hide behind guards (`when` /
`until` conditions, optional branches) in a pipeline whose compile or schema
validation does not resolve cross-node references; or a guarded step has never
executed in any green run you are about to cite.

## Do this

1. **Enumerate every guard and run each direction at least once** — one run
   where the guard is true and one where it is false — and record which run
   exercised which direction in a bidirectional contrast table (guard, true
   run, false run, observed signal on each side). This is branch coverage
   ("the percentage of branches that have been exercised by a test suite" —
   ISTQB) applied at the whole-program QA level.
2. **Treat exit 0 from a run that skipped a guarded step as evidence about the
   skip path only.** The guarded step's body is unexecuted code of unknown
   validity; repeated green runs that all skip it accumulate no evidence about
   it.
3. **Establish what the static stages actually check.** When compile and
   validation do not resolve references between nodes, a dangling reference
   inside a guarded step (an undeclared event, a missing target id) survives
   every static stage and surfaces only when the guard lets the step run — so
   the guard-true run is the *only* reference check that exists. Run it before
   calling the artifact shippable.
4. **For loop guards (`until`, retry conditions), the zero-iteration case is
   also a branch**: include one run where the condition is satisfied
   immediately, alongside the run that iterates.
5. **Assert on the executed-step list, not on skip markers alone.** Observed
   asymmetry in the field reproduction: a zero-round `until` loop was absent
   from the skipped list even though its body never ran — skip markers and
   execution records can disagree.

## Edge cases

| Case | Then |
|------|------|
| A guard-true state is unreachable through the program's inputs | Record it explicitly as a coverage gap in the QA report; do not claim full guard coverage silently |
| Two guards cannot both be true in one run | Cover them in separate runs; one row per guard in the contrast table, each with its own true/false pair |
| The guard-true run fails late in QA | That is the mechanism working — the error was latent behind the guard; fix, then re-run both directions of that guard |
| Static validation claims to check references | Verify with a planted dangling reference that it actually fails validation; if it passes, treat reference resolution as runtime-only |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Ship after N green runs that all skipped a guarded step | Force one guard-true run per guard first | Compile 0 errors + validation PASS + exit 0 never executed the step body; an error inside it stays latent until production hits the guard-true state |
| Cite validator PASS as proof references resolve | Check whether the validator resolves references; if not, count only guard-true runs as reference checks | Validation scope and reference resolution are separate concerns; PASS on the former says nothing about the latter |
| Infer skipped steps from a skipped-markers list | Assert on the executed-step list | Zero-iteration loops can be missing from both lists — only the execution record is authoritative |

## Sources

- https://istqb-glossary.page/branch-coverage/ — "The percentage of branches that have been exercised by a test suite. 100% branch coverage implies both 100% decision coverage and 100% statement coverage"
- Field reproduction (2026-08-05, lnpl 0.2.0 workflow runner): an `emit` referencing an undeclared event passed compile (0 errors) and IR validation (PASS); 6 of 7 runs failed at runtime at the emit step ("EventEmit references undeclared event"), while the single run where a presence guard skipped emit exited 0 — a guard-skipping input masks the defect indefinitely. Raw run outputs archived alongside the QA case
