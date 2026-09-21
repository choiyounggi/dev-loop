---
id: infrastructure-agent-orchestration-inbound-validation-ownership-in-task-decomposition
domain: infrastructure
category: agent-orchestration
applies_to: [general]
confidence: verified
sources:
  - https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html
last_verified: 2026-09-03
related: [security-input-validation-at-trust-boundaries, infrastructure-agent-orchestration-worktree-isolated-workers, qa-process-adversarial-change-review]
---

# Recording Inbound Validation as a Decision on the Receiver's Task, Not Only the Producer's

## When this applies

A wiki-plan or task decomposition splits the producer and the receiver of a
message across a process boundary (WS/IPC/HTTP) into separate tasks — one task
builds and sends an envelope, another task's server/handler receives it. Also
when a plan's decision-to-page map cites a validation/trust-boundary page only
under the producer's task.

## Do this

1. **Give the receiver task's brief its own recorded decision: "call
   `validate()` on every inbound message before acting on it."** State it even
   when the producer already validates before sending — OWASP's guidance is
   that validation belongs "as early as possible in the data flow, preferably
   as soon as the data is received from the external party," which for the
   receiver task means at its own entry point, not the sender's.
2. **Cite the trust-boundary page from the receiver task's decision-to-page
   map**, in addition to any citation on the producer's task. A citation only
   on the producer records a decision about outbound assembly, not about what
   the receiver does with inbound bytes — those are two different decisions
   even when one page's guidance covers both.
3. **Treat the producer's "assemble gate" as covering only the producer's own
   code path.** Any other client of the same endpoint — a test client, a
   future caller, a different service version — reaches the receiver without
   ever passing through it, so the receiver's own `validate()` call is the
   only check that holds for every sender.
4. **When splitting a message-passing feature into tasks, add an explicit
   task-boundary checklist item**: "does a task exist whose brief owns
   inbound validation at this trust boundary?" If no task's brief names it,
   the plan is missing a task, not missing detail inside an existing one.

| Case | Do |
|------|----|
| Producer task assembles/serializes an envelope and a separate receiver task parses it | Receiver task's brief carries its own "validate on inbound" decision, independent of the producer's assembly gate |
| Producer and receiver are implemented by the same task/agent in one pass | One decision suffices, recorded against the receiver-side code path specifically (the handler, not the constructor) |
| The message crosses no process boundary (same-process function call) | This page does not apply — use ordinary call-site review, not a trust-boundary task |
| A later task adds a second producer (e.g., a test harness) for an existing receiver | Keep the existing receiver-side decision and verify the existing `validate()` call still covers the new producer's field set |

## Edge cases

| Case | Then |
|------|------|
| Per-task review passes because each task is internally consistent with its own brief | That is expected and insufficient — a missing receiver-side validation decision is invisible until integration review compares the task set against the trust boundaries the diff actually crosses |
| The receiver's `validate()` exists but only checks message shape, not required-field presence (e.g. non-empty `to`/`id`) | Still counts as a gap — the decision must name the specific invariants downstream code depends on (dedupe/ack table keys), not just "some validation exists" |
| The plan's decision-to-page map cites the trust-boundary page once, under a shared "messaging" task that covers both send and receive | Acceptable only if that task's brief itself states the inbound-validation decision; a citation without the decision text is not a substitute |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Cite the trust-boundary page only under the producer task in the plan's decision-to-page map | Cite it under the receiver task too, with the inbound-`validate()` decision spelled out there | The producer's citation documents a decision about what it sends, not what the receiver does with what arrives |
| Assume the producer's assemble-time gate protects the receiver | Add "call `validate()` on every inbound message" as a receiver-task decision | Every future or alternate client of the receiver bypasses a producer-side gate by construction |
| Treat "each task's review passed" as evidence the boundary is covered | Run an integration review that checks the task set against every trust boundary the diff crosses, per [qa-process-adversarial-change-review] | Task-scoped review cannot see a decision that belongs to a task nobody wrote |

## Sources

- https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html — "Input validation should happen as early as possible in the data flow, preferably as soon as the data is received from the external party" (raw page grep 2026-09-03)
- Field evidence 2026-08-30 (agent-crew M2 run, `.crew/archive-20260830-m2a-orchestration/reviews/t-bus-r1.md`): the integration reviewer flagged `crew-bus handle_envelope`'s missing `validate()` call as blocking; reverting the fix reproduced an empty `to` field being silently dropped, corrupting dedupe/ack-table keys — a defect invisible to either task's review run in isolation
