---
id: backend-common-architecture-sync-vs-async-integration
domain: backend
category: architecture
applies_to: [general]
confidence: verified
sources:
  - https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/sync-comm.html
last_verified: 2026-08-17
related: [backend-common-jobs-idempotent-handlers, backend-common-reliability-timeouts-and-retries]
---

# Choosing Direct Call vs Queue vs Event Between Services

## When this applies

One service (or one module boundary) needs another service's work done, and
you're deciding whether the caller should call it directly and wait (sync),
hand it off through a queue for later processing (async request), or publish
a fact and let interested consumers react (event). This is a design decision
to make explicitly before writing the integration, not a default to fall
into because HTTP was the easiest thing to reach for.

## Do this

Decide by which property the interaction actually needs, not by habit:

| Property you need | Choose |
|---------------------|--------|
| Caller needs the result before it can proceed (e.g. "is this payment authorized") | Synchronous call — the caller blocks and gets an immediate success/failure, so there is no ambiguity about whether the operation completed |
| Caller can proceed without knowing the outcome yet (e.g. "send a receipt email") | Asynchronous — hand the work to a queue/job and let the caller continue; the two systems are decoupled so the callee's downtime does not block the caller |
| Multiple independent consumers each need to react to the same fact, and the producer shouldn't know who they are | Event — the producer publishes what happened; consumers subscribe independently, and adding a new consumer requires no change to the producer |
| Caller cannot tolerate the callee being temporarily unavailable propagating into the caller's own failure | Asynchronous — a synchronous chain of calls fails the whole chain when any one link is down; an async handoff isolates the callee's downtime because the caller already returned |
| Strict consistency across both sides is required (both must succeed or both must roll back) | Synchronous, inside a single transaction boundary if possible — async introduces eventual consistency, which requires the caller to handle "the other side hasn't processed this yet" as a real state |

## Edge cases

| Case | Then |
|------|------|
| A "fire and forget" call is made synchronously only to avoid building a queue | Recognize this as a hidden coupling: the caller now blocks on (and fails with) a dependency it doesn't actually need a result from — move it to async once the queue infrastructure exists, don't leave it sync "for now" |
| An async handoff needs the caller to know it eventually succeeded (not just accepted) | Add a status the caller can poll, or a completion event the caller subscribes to — async does not mean the caller stops caring about the outcome, only that it stops blocking on it |
| Choosing between async-request (queue, one intended consumer) and event (pub/sub, unknown consumers) | If you can name every consumer today and the interaction is really "do this work for me," it's a queue, not an event; model it as an event only when the point is that consumers you don't control may subscribe later |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Default to a synchronous HTTP call because it's the simplest thing to write | Check whether the caller actually needs the result before proceeding, and whether the callee's downtime should be allowed to fail the caller | A sync call is the tightest coupling available — every synchronous hop in a chain becomes a shared point of failure and adds its latency to the caller's total latency |
| Make an integration async purely to "decouple things" without a durable queue behind it | Only claim the isolation/scalability benefits of async once the handoff is backed by a durable queue with retry semantics ([backend-common-jobs-idempotent-handlers]) | An in-memory or fire-and-forget "async" call without durability loses work on a crash and offers none of async's actual failure-isolation guarantee |

## Sources

- https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/sync-comm.html — consistency/latency/coupling/failure-isolation trade-off table between synchronous and asynchronous service communication
