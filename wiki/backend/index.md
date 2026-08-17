# backend — Domain Index

Route here for: server-side application code. The domain has one shared subtree and
three stack subtrees — route by concern first, stack second:

| Subtree | Route there when |
|---------|------------------|
| [common](#common-language-agnostic) (below) | The concern is language-agnostic: API contracts, enumerating call sites before a contract change, idempotency, JWT issuance, outbound calls, caching, jobs, transactions in app code, shared state/pools, exception structure, consuming LLM APIs (completion validation, context budgeting), consuming external-API responses, externally-owned defaults, object-storage references, sync-vs-async integration choice, WebSocket/SSE connection lifecycle |
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
| [unenforced-declarations](common/api-design/unenforced-declarations.md) | Your system accepts declarative input (config file, DSL/manifest, policy block, schema annotation) and part of what a caller may write is unimplemented — an unknown key, a verb outside your vocabulary, or a knob recorded but never acted on; a user reports "I declared X and nothing happened"; choosing between reject/warn/ignore and where that strictness is selected |
| [cors-and-preflight](common/api-design/cors-and-preflight.md) | A browser-based caller on a different origin fails with a CORS error in the console (a direct curl to the same endpoint works); deciding whether a change to an endpoint's method/headers/content-type will trigger an OPTIONS preflight; designing `Access-Control-*` headers for a credentialed vs public endpoint; allowlisting more than one origin |
| [api-versioning-and-breaking-changes](common/api-design/api-versioning-and-breaking-changes.md) | An API has external callers you cannot enumerate or force-upgrade and you need to add/remove/rename/retype a field or endpoint; classifying a change as backward-compatible vs breaking; choosing a versioning mechanism (header vs URL); deprecating an old version (internal-only contract changes → [backend-common-change-impact-call-site-enumeration]) |

### change-impact

| Page | Load when |
|------|-----------|
| [widening-a-closed-value-table](common/change-impact/widening-a-closed-value-table.md) | Adding an entry to a closed table mapping names to magnitudes or codes (duration units, status codes, currency exponents, severity levels) that lives as a named constant; scoping that change from a search for the constant's name; a new entry parses at one layer and is rejected or mis-converted at another; deciding what to do about an inlined copy of the table in a hot path, a second language backend, or a fixture |
| [call-site-enumeration](common/change-impact/call-site-enumeration.md) | Changing the contract of a function/method/constructor other code calls — adding, removing, reordering or redefining a parameter — and you need the complete call-site list; scoping such a migration from a search; a migration scoped from recon came back green and then failed on call sites the search never listed; deciding whether to append a parameter or make it keyword-only (release-level re-test scope → qa/process/regression-scope) |

### reliability

| Page | Load when |
|------|-----------|
| [timeouts-and-retries](common/reliability/timeouts-and-retries.md) | Your service calls another service/external API/DB over the network — setting timeouts and deadlines, deciding what to retry per failure type, backoff/jitter, capping concurrency against a slow dependency; debugging pool exhaustion or retry storms |
| [client-side-rate-limiting](common/reliability/client-side-rate-limiting.md) | You added a throttle to an API client wrapper and the provider still returns 429 — especially on the first call after process start, or only on some days; a rate-limit failure was filed as intermittent because a rerun passed; deciding which layer the throttle belongs in and whether token/auth requests count against the quota |

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

### llm

| Page | Load when |
|------|-----------|
| [completion-response-validation](common/llm/completion-response-validation.md) | Consuming OpenAI-compatible `/chat/completions` output as a final artifact (summary, document, notification); LLM responses coming back empty or truncated while HTTP status is 200; a reasoning-family model may be routed onto the alias you call |
| [context-window-budget](common/llm/context-window-budget.md) | Repointing an LLM client or agent CLI at a different model, a self-hosted server (vLLM/Ollama), or a gateway (LiteLLM); setting `max_tokens` for a client whose default was sized for a larger model; the first request after such a switch returns 400 with a context-window error; deciding where to set the cap (request body vs client env var vs gateway config) and how to point the base URL at a proxy; handling truncation that arrives as a normal 200 |

### integrations

| Page | Load when |
|------|-----------|
| [externally-owned-defaults](common/integrations/externally-owned-defaults.md) | A code/config default names a resource the repo does not own (model alias, endpoint, bucket, queue, index) — reviewing or merging a PR that claims that default works, adding a startup check that the name still resolves, or diagnosing a default path that broke with no code change |
| [robots-txt-and-source-selection](common/integrations/robots-txt-and-source-selection.md) | Choosing which site to fetch a published dataset from and reading its robots.txt to decide whether your client may crawl it; the file contains a `Disallow: /` and you are deciding whose group it belongs to; setting the crawler's User-Agent and checking that token against the file; robots.txt returned a non-200 status; the origin restricts your token and you are looking for a portal that republishes the same records |

### storage

| Page | Load when |
|------|-----------|
| [multi-object-write-ordering](common/storage/multi-object-write-ordering.md) | A diff writes two or more related objects (payload + checksum, data file + index entry, new version + the pointer that marks it current) with no transaction around the writes; reviewing such a diff for what a concurrent reader observes between the writes, or what a crash between them leaves behind |
| [object-key-persistence](common/storage/object-key-persistence.md) | Persisting the result of an object-storage upload (`s3.upload()`, `lib-storage` `Upload`, a transfer manager) — choosing which response field goes in the DB column; building the read/signing path from a stored reference; migrating a column that holds URLs to keys; only large uploads 404 on read |

### architecture

| Page | Load when |
|------|-----------|
| [sync-vs-async-integration](common/architecture/sync-vs-async-integration.md) | Deciding whether one service/module should call another synchronously, hand work off through a queue, or publish an event — choosing by which property the interaction needs (immediate result, consistency, failure isolation, multiple independent consumers); a "fire and forget" call was made synchronously with no reason to block |

### realtime

| Page | Load when |
|------|-----------|
| [websocket-sse-lifecycle](common/realtime/websocket-sse-lifecycle.md) | Building or reviewing a WebSocket or Server-Sent Events channel — authenticating a long-lived connection, detecting a dead peer (ping/pong), reconnecting after a drop (SSE `retry`/`Last-Event-ID`, WebSocket client-side backoff), bounding backpressure on a slow client, or draining connections on shutdown/deploy |
