---
id: infrastructure-agent-orchestration-done-criteria-in-a-split-task-piece
domain: infrastructure
category: agent-orchestration
applies_to: [general]
confidence: field-tested
sources:
  - https://www.anthropic.com/engineering/multi-agent-research-system
  - https://en.wikipedia.org/wiki/Traceability_matrix
last_verified: 2026-10-10
related: [infrastructure-agent-orchestration-checkable-claims-in-an-adopted-plan, infrastructure-agent-orchestration-worker-reported-plan-contradiction, infrastructure-agent-orchestration-unattended-worker-questions, infrastructure-agent-orchestration-inbound-validation-ownership-in-task-decomposition, infrastructure-agent-orchestration-verify-command-in-a-worker-brief]
---

# Done Criteria Restated When a Task Was Split Into Pieces

## When this applies

You are about to implement one piece of a task that was split into sibling
pieces (a mid-run split, a `split_of` node, a re-planned slice), and your
brief's done criteria (DoD) were rewritten at split time — a route-level outcome
restated as function names and return shapes. Also when you are the coordinator
writing those per-piece criteria.

## Do this

1. **Before writing code, map every DoD item to the proof inside your own
   piece**: one row per item with the DoD wording, the plan task that builds
   it, the test that asserts it, and the file that test lives in. Quote the DoD
   sentence and the test's assertion side by side, so a mismatch is visible
   without re-reading either document.
2. **Classify each row and act on it before the first commit:**

| What the row shows | Do |
|--------------------|----|
| A task and a test in your piece assert the item as worded | Proceed; keep the row for the completion report |
| The only task or test that proves the item belongs to a sibling piece (its files, its plan) | Report it as a contradiction through the run's blocking-question channel ([infrastructure-agent-orchestration-unattended-worker-questions]) and wait |
| Your piece's test asserts a different value or shape than the DoD sentence (the DoD names a route outcome, the plan asserts `toEqual({ kind: 'fallback', reason })` on a function) | Report both quotes; the coordinator rules which wording binds before you write the test |
| The item is observable only after the pieces merge (an end-to-end route check) | Report it so the coordinator moves it to the integration check instead of either piece's DoD |
| No task or test anywhere proves the item | Report it as a plan gap — the split dropped it |

3. **Send the whole table with the report**, not only the failing rows: the
   coordinator patches the brief from it and records the ruling, and the
   reviewer later checks rows instead of re-deriving them.
4. **As the coordinator writing per-piece criteria, restate each pre-split DoD
   item under exactly one piece** — the one whose files hold both the code and
   the test that prove it — and move any item that needs two pieces to the
   integration check. Run step 1 on your own draft before dispatching it.

A split restates a route-level DoD in the vocabulary of functions, and the
restatement can hand your piece an outcome whose producing code or observing
test the plan placed in a sibling. Implemented as briefed, the piece either
fails review on the unmet item or meets it by changing a contract the sibling
builds against.

## Edge cases

| Case | Then |
|------|------|
| The sibling piece that proves the item has already merged | Point the row at the merged test by path and commit and report it as proven there; your piece re-implements nothing |
| The DoD sentence reads both as a route-level and a function-level outcome | Quote both readings in the report — they lead to different tests, so the ruling decides which test you write |
| The adopted plan also states derived numbers, symbol contracts, or a dependency table | Run [infrastructure-agent-orchestration-checkable-claims-in-an-adopted-plan] in the same pass and send one report |
| A worker already reported that the design doc and its step files disagree | [infrastructure-agent-orchestration-worker-reported-plan-contradiction] governs the ruling; this page governs the adopt-time mapping that finds it |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Implement the sibling piece's part so your DoD item passes | Report the row as a contradiction and wait for the ruling | The sibling builds the same behavior from its own brief; the two meet at merge as a conflict or a duplicate, and your piece's files now overlap the sibling's |
| Leave out a DoD item because your plan has no test for it | Report the item with the mapping table | The reviewer checks the DoD as written and fails the piece on the missing item |
| Change a function's return shape so a route-level DoD sentence holds | Ask which wording binds, with both quotes | The sibling piece builds against the shape your plan states; changing it in one piece breaks the other at merge |

## Sources

- https://www.anthropic.com/engineering/multi-agent-research-system — "Each subagent needs an objective, an output format, guidance on the tools and sources to use, and clear task boundaries."; "Without detailed task descriptions, agents duplicate work, leave gaps, or fail to find necessary information."
- https://en.wikipedia.org/wiki/Traceability_matrix — a traceability matrix is a table "used to assist in determining the completeness of a relationship by correlating any two baselined documents", applied to requirements against "test plan, and test cases"; "Zero values indicate that no relationship exists. It must be determined if a relationship must be made."
- Field evidence 2026-10-09 (an orchestrated run, piece t6 of a split plan; recorded by the originating session): the split-time brief's DoD item 2, restated from a route-level outcome into function names, did not match what the piece's own plan proves — task 05 asserts `toEqual({ kind: 'fallback', reason })` and task 10 test 2 follows design §3 step 9 — and the mismatch was reported as a contradiction before any code was written
