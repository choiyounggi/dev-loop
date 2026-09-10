---
id: infrastructure-agent-orchestration-worker-reported-plan-contradiction
domain: infrastructure
category: agent-orchestration
applies_to: [general]
confidence: field-tested
sources:
  - https://docs.python.org/3/library/sqlite3.html#exceptions
  - https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them
  - https://www.anthropic.com/engineering/multi-agent-research-system
  - http://principles-wiki.net/principles:don_t_repeat_yourself
last_verified: 2026-09-10
related: [infrastructure-agent-orchestration-autonomous-decision-rulings, infrastructure-agent-orchestration-shared-run-state, debugging-methodology-hypothesis-testing, qa-process-evaluating-review-feedback]
---

# A Worker Reports the Design Doc and Step Files Disagree

## When this applies

A coordinator authored both a design doc and per-task step files for the same
piece of work, and a worker implementing a step reports that the two disagree
on a concrete, checkable fact — a value, an exception type, an API shape, a
threshold — not a matter of taste.

## Do this

1. Treat the worker's contradiction report as a hypothesis to test, not a
   deviation to correct by re-asserting the design doc. That the design doc
   was written by the stronger model, or written first, is not evidence about
   which document matches the working code.
2. Make the change the disputed reading requires, in the worker's own
   worktree, and run the affected test suite. The suite is ground truth
   neither document can substitute for.
3. Read any failures for what they assert about the running system, not about
   either document — a test that pins specific behavior (e.g. a bare
   exception type propagating) tells you which document's claim the codebase
   actually depends on.
4. Patch whichever document is wrong once confirmed, and record which
   document changed and why in the run's ledger
   ([infrastructure-agent-orchestration-autonomous-decision-rulings]), so the
   correction is visible to every other task still reading the stale copy.
5. When the worker misread a document rather than the documents actually
   disagreeing, correct the worker's step instead — the test run decided it,
   not who asserted first or loudest.

| Signal | Do |
|--------|----|
| A concrete, testable disagreement (a value, a type, an exception class, a threshold) | Run the disputed change and the suite before ruling either way |
| The dispute is over widening or narrowing a catch clause, condition, or table | Check the language's own exception/type hierarchy first — a broadened catch can silently swallow a narrower failure a test already asserts |
| The suite passes under both readings | The documents are underspecified, not contradictory in a way code can arbitrate — add a test that pins the intended behavior, then patch the wrong doc |
| The disagreement is architectural or subjective and the plan never claimed to test it | Escalate it as a plan defect for the requester to rule on, with both readings quoted, instead of forcing it through the suite — the suite cannot arbitrate a claim the plan never made testable |

## Edge cases

| Case | Then |
|------|------|
| The worker is the one who is wrong (misread a document, ran the wrong test target) | Correct the worker's step, cite the passing baseline that proves it, and leave both documents alone |
| Both documents are wrong — neither matches the codebase's actual constraint | Patch both, and record one ruling listing both edits so a reader of either document sees the correction |
| No test covers the disputed behavior either way | Write the missing test first instead of guessing, from behavior the codebase already depends on elsewhere, then apply steps 2-4 |
| The contradiction is about an external library's behavior the codebase merely calls (which exceptions a driver raises, a default a client library sets) | Confirm against that library's own documentation too — a test run shows what the current version does, not the documented contract a future upgrade must keep honoring |
| The step file and design doc are the same physical document, with no split | This page does not apply — the drift the trigger describes cannot occur here |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Re-assert the design doc because the coordinator wrote it on the stronger model | Run the disputed change and the test suite before ruling | A plan split across two documents drifts between them, and the worker executing both is the first reader to hit the seam; model strength is not evidence about which artifact matches the code |
| Tell the worker to "just follow the step file" or "just follow the design doc" without checking | Test both readings against the suite and patch whichever document is wrong | Overriding without verification leaves the same drift live for the next worker who reads the other document |
| Widen a catch clause because the design doc's exception table looks incomplete | Check the language's exception hierarchy for what the broader class already includes | `except sqlite3.Error` also catches `IntegrityError` and `OperationalError` — both are subclasses of `DatabaseError`, itself a subclass of `Error` — so a catch written to cover one silently absorbs a failure a test was written against the other |

## Sources

- https://docs.python.org/3/library/sqlite3.html#exceptions — `sqlite3.IntegrityError` and `sqlite3.OperationalError` are both subclasses of `sqlite3.DatabaseError`, itself a subclass of `sqlite3.Error`; `except sqlite3.Error` catches all of them
- https://claude.com/blog/building-multi-agent-systems-when-and-how-to-use-them — verification-subagent pattern: "You MUST run the complete test suite before marking as passed... Specify 'Run the full test suite and report all failures' rather than 'make sure it works'"; resolves disputes through executable validation rather than trusting either side's assertion
- https://www.anthropic.com/engineering/multi-agent-research-system — orchestrator-worker pattern: the lead agent "synthesizes these results and decides whether more research is needed," treating a subagent's report as new evidence to act on rather than trusting its own prior plan as final
- http://principles-wiki.net/principles:don_t_repeat_yourself — DRY as single source of truth: "if there is a single source of truth, there is only one place where changes have to be applied. Then the representations cannot diverge" — a design doc and step files stating the same fact twice is exactly the setup this principle warns drifts apart
- Field evidence (a dev-loop orchestrate run, one worker task, 2026-09-09): a step file said `except sqlite3.Error` while the design doc's table said `OperationalError` only. Running the widened catch in the worker's worktree produced `2 failed, 242 passed` — `test_insert_company_rejects_normalized_duplicate_names` and `test_init_db_preserves_existing_duplicate_rows` both failed with `DatabaseError` wrapping `IntegrityError` — confirming the design doc's table, not the step file, was the document to patch
