---
id: infrastructure-agent-orchestration-autonomous-decision-rulings
domain: infrastructure
category: agent-orchestration
applies_to: [general]
confidence: field-tested
sources:
  - https://github.com/obra/superpowers
last_verified: 2026-08-22
related: [infrastructure-agent-orchestration-unattended-worker-questions, infrastructure-agent-orchestration-shared-run-state, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, security-agent-exposure-authorization-scope-persistence]
---

# Deciding Without a Human During an Unattended Run

## When this applies

An unattended agent — a worker or its coordinator — hits a decision its plan
or prompt does not answer and must choose between stopping to ask and
proceeding; a run stalls on questions a human never needed to see; auditing
the decisions a finished run made on its own.

## Do this

1. Stop for the human only when the decision falls in one of four categories:
   (a) an irreversible or destructive operation, (b) a security-sensitive
   action, (c) a side effect that leaves the workspace — push or merge to a
   shared branch, publish, an external call with real-world effect — or
   (d) a plan broken to the point that every path forward is a guess. Route
   that question through the out-of-band channel of
   [infrastructure-agent-orchestration-unattended-worker-questions].
2. Rule on every other open decision and keep going — recording each ruling
   durably as `Ruling: <decision> — <why> — <cost if wrong>` in the run's
   ledger (the progress file of
   [infrastructure-agent-orchestration-shared-run-state], or the PR
   description).
3. After an interruption, compaction, or resume: re-read the ledger and the
   git log before dispatching work — memory of "where we were" re-dispatches
   already-completed task sequences; the ledger and the log do not.
4. Collect every `Ruling:` line into the final report, so the human audits
   the run's autonomous decisions in one pass instead of discovering them in
   the diff.

## Edge cases

| Case | Then |
|------|------|
| The same ruling keeps recurring across tasks | Promote it into the plan or the workers' prompt so it stops being re-decided per task |
| A ruling proves wrong later in the run | Fix forward and record the reversal as its own ruling; the original entry stays — the ledger is append-only history, not current state |
| A category-(c) action is pre-approved in the plan ("push to the feature branch after each task") | Proceed and cite the plan's written approval in the ruling — the written plan is the human decision |
| The worker cannot write the ledger (a permission gate blocks the path) | Report the signal as un-emitted and hand it back per [infrastructure-agent-orchestration-control-signals-vs-primary-artifacts], instead of working around the gate |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Stop the run to ask about a low-stakes choice | Rule, record, proceed | An unattended run that stalls on every choice loses the point of being unattended; the ledger preserves auditability |
| Decide silently and move on | Record the ruling with its cost-if-wrong | Silent decisions resurface as surprises in review, where they cost more than the ruling would have |
| Reconstruct progress from session memory after a resume | Re-read the ledger and git log | Controllers that trusted memory have re-dispatched entire completed task sequences |

## Sources

- https://github.com/obra/superpowers — subagent-driven-development skill: the four stop categories, the `Ruling:` ledger format with cost-if-wrong, ledger-over-memory recovery; field-tested across multi-agent plan executions
