---
id: backend-common-api-design-idempotency
domain: backend
category: api-design
applies_to: [general]
confidence: verified
sources:
  - https://docs.stripe.com/api/idempotent_requests
  - https://www.rfc-editor.org/rfc/rfc9110
  - https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/standard-queues.html
last_verified: 2026-07-10
related: [backend-common-jobs-idempotent-handlers, backend-common-reliability-timeouts-and-retries, databases-query-optimization-existence-and-count-checks]
---

# Making Side-Effecting Endpoints Safe to Retry

## When this applies

An endpoint has side effects (create, charge, send, enqueue) and the same
request can arrive twice: network timeout followed by client retry, user
double-submit, gateway retry, or queue redelivery. Retrying such an endpoint
without this design duplicates the effect.

## Do this

Pick the mechanism by operation type:

| Operation | Do |
|-----------|----|
| PUT full replace, DELETE | Make the handler idempotent — no key needed. PUT sets absolute state; DELETE of an already-deleted resource returns 404 or success without side effects. HTTP defines these methods idempotent (RFC 9110), so clients and proxies retry them |
| POST create / charge / send | **Idempotency key**: client generates a unique key (UUID) per logical operation and sends it in a header (`Idempotency-Key`); server stores key → response and replays the stored response for a repeated key (Stripe pattern) |
| Queue consumer under at-least-once delivery | Dedupe by message id or make the effect naturally idempotent → [backend-common-jobs-idempotent-handlers] |

Idempotency-key implementation:

1. Persist the key with a **unique constraint** and handle the duplicate-key
   error. Check-then-insert races: two concurrent retries both pass the check —
   the same machinery as the insert-if-absent case in
   [databases-query-optimization-existence-and-count-checks].
2. Write the key record and the operation's DB writes in the **same
   transaction**; store the response (status + body) against the key at commit.
3. On duplicate key with a stored response: return the stored response verbatim.
4. On duplicate key while the first attempt is still in flight (key row exists,
   no stored response): return 409 with a retry-later error code — do not run
   the operation a second time in parallel.
5. On a repeated key with a **different request payload**: reject with 422 —
   the client has a key-generation bug (Stripe rejects reused keys with
   changed parameters).
6. Expire stored keys after a window at least as long as the longest client
   retry horizon (Stripe keeps them ≥24h); a key reused after expiry executes
   as a new request.

## Edge cases

| Case | Then |
|------|------|
| Handler makes an external call (payment provider) plus DB writes | Pass an idempotency key **downstream** too (derive it from your key), so a retry of your handler cannot double-charge regardless of which write completed before the crash |
| Effect cannot join the key's DB transaction (external system) | Store progress state under the key (e.g. `charge_started`, `charge_confirmed`); on retry, resume/verify from the recorded state instead of restarting |
| Client cannot send a key (plain browser form double-submit) | Derive the key server-side from request identity fields (e.g. user id + order draft id) and enforce it with the same unique constraint |
| Key store grows unbounded | Prune rows older than the expiry window from step 6 |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Check if the key exists, then insert it | Unique constraint + handle duplicate-key error | Two concurrent retries both pass the existence check |
| Add retries to a keyless side-effecting POST | Add the idempotency key first, then retry | A timed-out request may have executed; retrying duplicates the effect |
| Dedupe by hashing the request body | Explicit client-generated key per logical operation | Two legitimate identical operations (buy the same item twice) hash identically and the second is wrongly swallowed |

## Sources

- https://docs.stripe.com/api/idempotent_requests — key header, stored-response replay, 24h retention, key format
- https://www.rfc-editor.org/rfc/rfc9110 — idempotent method definitions (PUT, DELETE)
- https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/standard-queues.html — at-least-once delivery, duplicate copies of messages
