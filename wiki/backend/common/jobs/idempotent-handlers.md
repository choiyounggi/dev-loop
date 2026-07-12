---
id: backend-common-jobs-idempotent-handlers
domain: backend
category: jobs
applies_to: [general]
confidence: verified
sources:
  - https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/standard-queues.html
  - https://microservices.io/patterns/data/transactional-outbox.html
  - https://docs.stripe.com/api/idempotent_requests
last_verified: 2026-07-10
related: [backend-common-api-design-idempotency, databases-query-optimization-existence-and-count-checks]
---

# Writing Queue Consumers and Background Jobs That Survive Redelivery

## When this applies

Writing a queue consumer, background job handler, or scheduled task; or
debugging duplicate side effects (double emails, double charges, double-counted
metrics) traced to jobs.

## Do this

1. Assume **at-least-once delivery**: standard queues (SQS and equivalents)
   redeliver on visibility timeout, consumer crash, or network error — the same
   message will run twice. Every handler must tolerate full re-execution from
   any point it can crash at.
2. Make each effect idempotent by construction:

| Effect | Do |
|--------|----|
| DB state write | Upsert / absolute set (`SET status = 'sent'`), not increment or blind append — re-running lands on the same final state |
| Increment or append that must remain (counters, ledger rows) | Processed-messages table with a unique message-id column: insert the id and apply the effect **in the same transaction**; a duplicate-key hit means already processed → ack and skip. Unique constraint, not select-then-insert ([databases-query-optimization-existence-and-count-checks]) |
| External side effect (email, charge, push) | Idempotency key derived deterministically from the message id, passed to the provider → [backend-common-api-design-idempotency] |
| Enqueue that belongs to a DB change | **Transactional outbox**: write an outbox row inside the same DB transaction as the business write; a separate relay publishes it (microservices.io). Enqueue-then-commit produces ghost messages on rollback; commit-then-enqueue loses messages on a crash between the two |

3. Poison messages: bound delivery attempts (e.g. `maxReceiveCount`), then move
   the message to a dead-letter queue **with alerting** — an always-failing
   message must not block or spin the consumer forever, and a silent DLQ is a
   data-loss buffer.
4. Long jobs: checkpoint progress (persist a step cursor keyed by job id) so a
   retry resumes from the checkpoint, or split the job into separately enqueued
   steps that are each idempotent.
5. Scheduled tasks: a schedule fire can duplicate (deploy overlap, two
   instances) or repeat after crash. Guard with a unique row per
   `(task, period)` inserted at run start — duplicate-key means another run owns
   this period → exit.

## Edge cases

| Case | Then |
|------|------|
| N workers consume concurrently and receive two copies at once | The dedupe insert must be a unique-constraint hit inside the effect's transaction — a select-check passes on both workers simultaneously |
| Producer supplies no message id | Derive a deterministic business key (entity id + event type + version) and dedupe on that |
| Handler writes the DB **and** calls an external API | Give the external call an idempotency key tied to the message id; then a crash on either side of the DB commit is safe — the retry re-runs the external call with the same key and the provider dedupes it |
| Dedupe table grows unbounded | Prune rows older than the queue's maximum redelivery horizon (retention + max retry window) |
| Message triggers a non-idempotent legacy system with no key support | Record intent (`sending`) in the dedupe row before the call and final state after; on retry with state `sending`, verify against the legacy system before re-sending, and alert when verification is impossible |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Enqueue inside business code, then commit the transaction | Outbox row in the transaction + relay | Rollback after enqueue = message for a change that never happened; crash after commit before enqueue = lost message |
| Increment a counter directly in the handler | Dedupe-insert + increment in one transaction | Redelivery double-counts |
| Retry a failing message forever | Bounded retries + DLQ + alert | A poison message blocks the queue and burns compute indefinitely |

## Sources

- https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/standard-queues.html — at-least-once delivery, duplicate message copies
- https://microservices.io/patterns/data/transactional-outbox.html — outbox row in the business transaction, separate relay publishes
- https://docs.stripe.com/api/idempotent_requests — provider-side idempotency keys for external effects
