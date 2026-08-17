---
id: testing-data-harness-vs-run-path-fixtures
domain: testing
category: data
applies_to: [general]
confidence: verified
sources:
  - https://www.postgresql.org/docs/current/functions-comparison.html
  - https://jqlang.org/manual/
  - https://istqb-glossary.page/branch-coverage/
last_verified: 2026-08-07
related: [testing-data-test-data-and-isolation, testing-quality-differential-run-agreement, testing-strategy-differential-testing, qa-exploratory-guard-true-path-coverage, testing-quality-tests-that-cannot-fail]
---

# A Harness That Synthesizes Its Own Default Input

## When this applies

A spec/test harness and the production entry point each *synthesize* the input
the program runs on (nobody hand-wrote a fixture), and the two synthesizers read
different declaration sets. Also when a harness run reports a guarded step
skipped, exit 0, and you are about to record that skip as program behavior.

## Do this

1. **Give both entry points one synthesizer over one declaration set.** Export
   the function the run path uses and call it from the harness, so a declaration
   added later reaches both. Two synthesizers that "agree today" are one commit
   from diverging, and the divergence surfaces as a program-level symptom, not
   as a fixture error.
2. **When the harness must narrow the input, make the narrowing explicit and
   author-overridable** — a named argument (`entities=[…]`) plus a way for the
   spec author to supply the fixture outright. A narrowing hidden inside the
   harness is indistinguishable from the program's own behavior at the point
   where a reader sees the output.
3. **Read "guard false / step skipped" as two hypotheses, and separate them
   before filing anything.** In every expression language that returns a null or
   undefined for an absent member, an absent operand and a present-but-false
   operand collapse onto the same not-true branch:

| Observed | Hypothesis | Check that separates them |
|----------|------------|---------------------------|
| Guarded step skipped, exit 0 | The operand was present and false — program behavior | Print the guard's operands as resolved, not the guard's verdict |
| Guarded step skipped, exit 0 | The operand is absent from the synthesized input — harness artifact | Inject just that field into the fixture and re-run; a flip in the executed-step list proves the artifact |
| Skipped in the harness, executed on the run path, same input | The two synthesizers differ | Diff the declaration sets each one reads, not the two outputs |

4. **Confirm the fix by the executed-step list, not by the exit code.** The
   before/after pair to record is the step counts (`STEPS: 1 SKIPPED: 1` →
   `STEPS: 2 SKIPPED: 0`), with the injected field as the only change.
5. **Count a harness run that skipped a guard as evidence about the skip path
   only** — branch coverage is per direction, so the guard-true body stays
   unexecuted code of unknown validity ([qa-exploratory-guard-true-path-coverage]).

## Edge cases

| Case | Then |
|------|------|
| Several separately-filed bugs all report a skipped step in the same harness | Suspect one shared narrowing before triaging them individually; a single fixture scope produced all of them |
| The harness's narrowing is deliberate (speed, isolation) | Keep it, name it in the harness output (`fixture: entities=[order]`), so the reader can attribute a skip without reading harness source |
| The guard operand is legitimately absent in production too | Then the skip is behavior — assert it explicitly with the operand shown absent, so a later fixture change cannot silently turn the assertion into a different test |
| The program has no way to observe resolved operands | Add that observability before triaging guard-false reports; without it every skip is unattributable |
| The two paths synthesize equal inputs today | Assert equality between the two synthesized inputs in one test, so divergence fails there instead of inside a feature test |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| File "step is skipped / guard is false" from a harness run | Inject the guard's operands into the fixture and re-run first | An absent operand and a false operand produce the same not-true branch, so the report names the program for a fixture's scope |
| Let the harness build its own default input beside the run path's | Call the run path's synthesizer, narrowing through an argument | Independent synthesizers drift on the next declaration, and the drift reads as a program defect |
| Cite a green harness run that skipped a guarded step | Cite it as evidence about the skip direction and run the guard-true direction separately | 100% of the runs exercised one branch; the other branch has no verdict |

## Sources

- https://www.postgresql.org/docs/current/functions-comparison.html — "Ordinary comparison operators yield null (signifying "unknown"), not true or false, when either input is null"; `NULL::boolean IS TRUE` → `f` — an unknown operand lands on the not-true side, where it is indistinguishable from false
- https://jqlang.org/manual/ — `.foo` on an object without that key produces `null`, and `if` takes the else branch "if A produces a value other than false or null" — absent member and literal `false` select the same branch
- https://istqb-glossary.page/branch-coverage/ — "The percentage of branches that have been exercised by a test suite" — a skipped guard leaves its true branch unexercised
- Local reproduction 2026-08-07 (Python 3.14.6 + jq, macOS): one guard `shipment.ready` over a one-entity fixture returned false and over the full fixture returned true; the one-entity result compared equal to the result on an explicit `{"shipment": {"ready": false}}` input — the two causes are one observable. `echo '{"order":{}}' | jq '.shipment.ready'` → `null`, and both inputs took the `else` branch
- Field reproduction 2026-08-07 (lnpl spec runner): the runner built its payload from `sample_payload([first_entity])` while `run`/`diff`/mode-B all used `sample_payload(all_entities)`; injecting only the missing second-entity field moved the same workflow from `STATUS: completed STEPS: 1 SKIPPED: 1` to `STEPS: 2 SKIPPED: 0` with no other change. Three separately-filed major bugs traced to that one narrowing
