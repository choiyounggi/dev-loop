# backend — Domain Index

Route here for: server-side application code. The domain has one shared subtree and
three stack subtrees — route by concern first, stack second:

| Subtree | Route there when |
|---------|------------------|
| [common](#common-language-agnostic) (below) | The concern is language-agnostic: API contracts, idempotency, JWT issuance, outbound calls, caching, jobs, transactions in app code, shared state/pools, exception structure |
| [java](java/index.md) | You are writing/reviewing JVM backend code (Java/Kotlin, Spring, JPA/Hibernate) and the concern is stack-specific: entity mapping, persistence context, proxy pitfalls, JVM threads/memory |
| [node](node/index.md) | You are writing/reviewing Node.js/TypeScript backend code: event-loop blocking, promise error handling, runtime validation at boundaries, graceful shutdown |
| [python](python/index.md) | You are writing/reviewing Python backend code: GIL/concurrency model, pydantic validation, WSGI/ASGI workers, language traps |

Load a stack page IN ADDITION to the matching common page when both apply — common
owns the principle, the stack page owns the mechanics. SQL, index, and DB-side
transaction/locking mechanics stay in the databases domain (pages link there).

Match your situation to a "load when" line; load only matching pages.

## common (language-agnostic)

### api-design

| Page | Load when |
|------|-----------|
| [error-responses](common/api-design/error-responses.md) | Designing or reviewing API error handling — choosing status codes (400/401/403/404/409/422/500), defining the error body shape, deciding what a 500 may reveal; clients report inconsistent/unparseable errors |
| [idempotency](common/api-design/idempotency.md) | An endpoint with side effects (create, charge, send) can receive the same request twice — client retry after timeout, user double-submit, gateway retry; designing idempotency-key storage; deciding which operations are safe to retry |
| [pagination-contract](common/api-design/pagination-contract.md) | Designing a list endpoint's request/response contract — cursor vs page-number, limit caps, total counts, expired-cursor behavior (the backing SQL/index → databases/query-optimization/keyset-pagination) |

### reliability

| Page | Load when |
|------|-----------|
| [timeouts-and-retries](common/reliability/timeouts-and-retries.md) | Your service calls another service/external API/DB over the network — setting timeouts and deadlines, deciding what to retry per failure type, backoff/jitter, capping concurrency against a slow dependency; debugging pool exhaustion or retry storms |

### caching

| Page | Load when |
|------|-----------|
| [invalidation-and-stampede](common/caching/invalidation-and-stampede.md) | Adding a cache in front of an expensive read — choosing invalidation (delete-on-write vs TTL), building cache keys (tenant/locale/version dimensions), protecting hot keys from stampede; debugging stale reads, cross-tenant leaks, expiry-time load spikes, or eviction evicting sessions |

### jobs

| Page | Load when |
|------|-----------|
| [idempotent-handlers](common/jobs/idempotent-handlers.md) | Writing a queue consumer, background job, or scheduled task — surviving at-least-once redelivery, dedupe by message id, transactional outbox for enqueue-with-DB-write, poison messages/DLQ, checkpointing long jobs; debugging duplicate side effects from jobs |
| [scheduled-job-overlap](common/jobs/scheduled-job-overlap.md) | A scheduled job may still be running when its next start fires (cron, K8s CronJob concurrencyPolicy, multi-host schedulers); doubled batch effects at schedule boundaries; pairing skip-on-overlap with hang timeouts |

### errors

| Page | Load when |
|------|-----------|
| [exception-handling](common/errors/exception-handling.md) | Writing a catch block or deciding where errors are handled/logged/translated in a service — catch placement, log-once, wrapping with cause preserved, typed results for expected outcomes; one fault producing duplicate alerts |
| [async-failure-handling](common/errors/async-failure-handling.md) | Handing work to in-process async (@Async, unawaited futures/promises) — deciding fire-and-forget vs consumed future vs durable job; side effects silently never happening with no error logs; unobserved futures; async work enqueued inside a transaction |

### auth

| Page | Load when |
|------|-----------|
| [jwt-server-side](common/auth/jwt-server-side.md) | Implementing or reviewing JWT issuance/verification on the server — signing algorithm choice, per-request verification checklist, access/refresh lifetimes, refresh rotation with reuse detection, revocation, claim contents (the session-vs-token choice lives in wiki/security/authn/; client-side storage in wiki/frontend/) |

### orm

| Page | Load when |
|------|-----------|
| [transaction-boundaries](common/orm/transaction-boundaries.md) | Deciding where a DB transaction starts/ends in application code — service vs controller vs per-repository-call boundaries, what belongs inside, annotation/proxy pitfalls, read-only flags, chunking batch writes; debugging partial writes or connection-pool exhaustion around open transactions |

### concurrency

| Page | Load when |
|------|-----------|
| [shared-state-and-pools](common/concurrency/shared-state-and-pools.md) | Request handlers share in-process mutable state — concurrency-safe structures/confinement vs shared store in multi-instance deployments; sizing thread/connection pools; same-pool nested-acquisition deadlock; bounding queues; debugging deadlock or starvation under load |
| [distributed-locks](common/concurrency/distributed-locks.md) | Only one instance may perform an action at a time — Redis-style lock with owner token and TTL/watchdog, safe release, when a DB constraint/advisory lock suffices instead; debugging locks released by the wrong holder or work done twice despite a lock |
