---
id: backend-common-reliability-timeouts-and-retries
domain: backend
category: reliability
applies_to: [general]
confidence: verified
sources:
  - https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/
  - https://sre.google/sre-book/addressing-cascading-failures/
  - https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/
last_verified: 2026-07-10
related: [backend-common-api-design-idempotency]
---

# Calling Another Service over the Network: Timeouts, Retries, Backoff

## When this applies

Your service makes outbound network calls — another internal service, an
external API, a database, a cache. Also when debugging worker-pool exhaustion,
retry storms, or requests that hang until a client gives up.

## Do this

1. Every outbound call gets an **explicit timeout** — connect timeout and
   request timeout both. Library defaults are unreliable and some are infinite;
   one hung dependency without a timeout exhausts your worker pool and takes
   your service down with it.
2. Budget the deadline: the caller's total deadline must exceed
   (attempt timeout × attempts) + total backoff for everything downstream —or
   propagate the caller's deadline in the request so downstream stops working
   when the caller has already given up (SRE deadline propagation).
3. Retry **only** operations that are idempotent or carry an idempotency key
   → [backend-common-api-design-idempotency]. A timed-out request may have executed.
4. Retry policy: 2–3 attempts total, capped exponential backoff with full
   jitter — `sleep = random(0, min(cap, base × 2^attempt))` (AWS). Add a
   service-wide retry budget (e.g. retries ≤10% of requests) so a down
   dependency does not receive multiplied traffic (SRE retry budget).
5. Decide retry by failure type:

| Failure | Retry decision |
|---------|----------------|
| Connection refused / connect timeout | Retry with backoff if idempotent — the request never reached the handler |
| Request timeout after sending (no reply) | Retry only if idempotent or keyed — the request may have executed |
| 500 / 502 / 503 / 504 | Retry within the 2–3 attempt budget if idempotent; on repeated failure, fail and surface the error |
| 429 | Wait the `Retry-After` value if present, then retry; absent the header, back off with jitter |
| 400 / 401 / 403 / 404 / 422 | Never retry — the request itself is wrong; the same bytes fail again. Fix and resend is a new request |

6. Propagate cancellation: when your caller disconnects or its deadline passes,
   cancel in-flight downstream calls and stop the work — finishing it burns
   capacity nobody will read.
7. Protect yourself from a slow dependency: cap concurrent calls to it
   (semaphore / connection-pool bound) or use a circuit breaker. When the cap
   is hit or the breaker is open, **fail fast** instead of queueing — under
   overload, fail early and cheaply (SRE); an unbounded queue turns a slow
   dependency into your own outage.

## Edge cases

| Case | Then |
|------|------|
| Retries exist at several layers (SDK, your code, gateway, client) | Retry at one layer only and set the others to 1 attempt — stacked retries multiply (3×3×3 = 27 attempts per user action), which is a self-inflicted DDoS on a struggling dependency |
| Choosing the timeout value | Derive from the dependency's observed p99 latency plus headroom, not a guess; alert when timeouts actually fire so drift is visible |
| Batch/scheduled job calling an API in a loop | Same rules per call, plus one overall deadline per run so a hung run does not overlap the next schedule |
| Dependency is a DB with its own driver timeout | Set both the driver statement timeout and your outer deadline; the outer one must be the larger of the two, or you cancel work the DB has almost finished |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Ship a call with no timeout ("the default is fine") | Set explicit connect + request timeouts on every call | Defaults vary and some are infinite; hung calls pile up until the pool is exhausted |
| Retry immediately in a tight loop | Capped exponential backoff + full jitter | Synchronized immediate retries spike load at the exact moment the dependency is weakest |
| Retry every failure the same way | Apply the failure-type table above | Retrying 4xx wastes the budget; retrying non-idempotent timeouts duplicates effects |

## Sources

- https://aws.amazon.com/builders-library/timeouts-retries-and-backoff-with-jitter/ — timeouts on every remote call, backoff, jitter, idempotency precondition for retries
- https://sre.google/sre-book/addressing-cascading-failures/ — deadlines and propagation, retry budgets, per-request retry limits, failing fast under overload
- https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/ — jittered backoff outperforms plain exponential backoff; full-jitter formula
