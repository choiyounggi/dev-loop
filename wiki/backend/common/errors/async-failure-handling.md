---
id: backend-common-errors-async-failure-handling
domain: backend
category: errors
applies_to: [general, spring, java]
confidence: verified
sources:
  - https://docs.spring.io/spring-framework/reference/integration/scheduling.html
last_verified: 2026-07-10
related: [backend-common-errors-exception-handling, backend-common-jobs-idempotent-handlers, backend-common-orm-transaction-boundaries]
---

# Handling Failures in Fire-and-Forget Async Work

## When this applies

Code hands work to an in-process async executor (`@Async`, thread pool submit,
unawaited promise/coroutine) and moves on, or you are debugging side effects that
silently never happen (points not accrued, emails not sent) with no error logs.

## Do this

1. **Know the default: fire-and-forget forgets failures.** An exception in a
   `void` async method never reaches the caller's thread; the framework default is
   at most one log line (Spring: `SimpleAsyncUncaughtExceptionHandler` at WARN via
   `AsyncUncaughtExceptionHandler`) — under common log configs, effectively silent.
   In-process async also loses queued work on crash/restart/deploy, exception or not.
2. Route by how much the work matters:

| Case | Do |
|------|----|
| Caller needs the result or must react to failure | Return the future/promise and consume it (`CompletableFuture.exceptionally`/`whenComplete`) at a point that keeps the work parallel — not an immediate blocking `get()` |
| Caller doesn't need the result, but the work MUST happen (points, emails, sync to another system) | Not in-process async at all: a durable queue/outbox job with retries and a dead-letter queue ([backend-common-jobs-idempotent-handlers]) — durability is the requirement, and an executor queue is not durable |
| Genuinely optional best-effort side effect (metrics, cache pre-warm) | Fire-and-forget is acceptable — register an uncaught-exception handler that logs with context so failures are at least visible ([backend-common-errors-exception-handling] log-once rule) |

3. **Decide the failure policy when you write the async boundary**, not after the
   first silent loss: what retries (and how many), what lands in a dead-letter,
   what pages someone. "Async" without a failure path is a data-loss design.

## Edge cases

| Case | Then |
|------|------|
| Async annotation on a method called via `this.method()` | Proxy-based async is bypassed by self-invocation — same trap as transactional annotations ([backend-common-orm-transaction-boundaries]); the method runs synchronously and its failures follow sync rules |
| Async work enqueued inside a DB transaction that later rolls back | The async work still runs against rolled-back state; enqueue after commit or via transactional outbox ([backend-common-orm-transaction-boundaries]) |
| Future stored but never consumed | Same as void: the exception sits unobserved inside the future. Consuming the future IS the error handling |
| Executor queue fills up | Bounded queue + explicit rejection policy; an unbounded queue hides the backlog until memory pressure ([backend-common-concurrency-shared-state-and-pools]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `@Async void` for business-critical work | Durable job with retries + DLQ | In-process async loses work on exception AND on restart; critical work needs durability, not a thread |
| `future.get()` right after submitting | Compose the continuation (`thenApply`/`whenComplete`) or don't go async | Immediate blocking get is a synchronous call with extra failure modes |

## Sources

- https://docs.spring.io/spring-framework/reference/integration/scheduling.html — @Async semantics, void vs Future exception handling, AsyncUncaughtExceptionHandler
