---
id: infrastructure-agent-orchestration-autonomous-decision-rulings
domain: infrastructure
category: agent-orchestration
applies_to: [general]
confidence: field-tested
sources:
  - https://github.com/obra/superpowers
  - https://www.gnu.org/software/make/manual/html_node/Rule-Syntax.html
last_verified: 2026-10-29
related: [infrastructure-agent-orchestration-unattended-worker-questions, infrastructure-agent-orchestration-shared-run-state, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, security-agent-exposure-authorization-scope-persistence, infrastructure-agent-orchestration-escape-hatch-uses-as-a-knowledge-gap-signal, infrastructure-agent-orchestration-semantic-conflicts-after-parallel-merge, infrastructure-agent-orchestration-worker-reported-plan-contradiction, platforms-processes-signalling-a-remembered-pid, infrastructure-agent-orchestration-checkable-claims-in-an-adopted-plan]
---

# Deciding Without a Human During an Unattended Run

## When this applies

An unattended agent — a worker or its coordinator — hits a decision its plan
or prompt does not answer and must choose between stopping to ask and
proceeding; a run stalls on questions a human never needed to see; auditing
the decisions a finished run made on its own; a worker adopting a plan that
cites rulings from a ledger the coordinator is still appending to.

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
| You are adopting a plan that cites rulings by id ("C1–C17") from a ledger the coordinator is still appending to | Before signalling the plan ready, list the ledger's ruling ids past the highest one the plan cites and read each: decide whether it drops, reorders, or rewrites an input this task copies (compare its file and line ranges with your task's), and escalate when one does. A ledger modified after the plan is only the cue to look; the id comparison is the check. The plan's own review passed against the rulings that existed when it was written, so it cannot vouch for later ones — the plan is a derived artifact, stale whenever a source it depends on is newer |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Stop the run to ask about a low-stakes choice | Rule, record, proceed | An unattended run that stalls on every choice loses the point of being unattended; the ledger preserves auditability |
| Decide silently and move on | Record the ruling with its cost-if-wrong | Silent decisions resurface as surprises in review, where they cost more than the ruling would have |
| Reconstruct progress from session memory after a resume | Re-read the ledger and git log | Controllers that trusted memory have re-dispatched entire completed task sequences |

## Sources

- https://github.com/obra/superpowers — subagent-driven-development skill: the four stop categories, the `Ruling:` ledger format with cost-if-wrong, ledger-over-memory recovery; field-tested across multi-agent plan executions
- https://www.gnu.org/software/make/manual/html_node/Rule-Syntax.html — make treats a target as out of date when it does not exist or is older than any of its prerequisites, compared by last-modification time; the same staleness rule applied to a plan derived from a rulings ledger
- Field evidence 2026-10-28 (an RFC-consolidation orchestration run, worker t1): the worker's plan cited rulings C1–C17 and passed review, while the rulings file had been modified one minute after the plan (16:49:10 vs 16:48:08) and now held C18–C20; reading the new rulings showed C18(2) named a source line (rfcs/0016:173) outside t1's copied range (0016 lines 90–112), so the plan stood — a check the plan's review could not have made
