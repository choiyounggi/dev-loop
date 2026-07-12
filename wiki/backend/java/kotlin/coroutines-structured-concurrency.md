---
id: backend-java-kotlin-coroutines-structured-concurrency
domain: backend
category: kotlin
applies_to: [kotlin, kotlinx-coroutines, jvm]
confidence: verified
sources:
  - https://kotlinlang.org/docs/coroutines-basics.html
  - https://kotlinlang.org/docs/exception-handling.html
  - https://kotlinlang.org/docs/cancellation-and-timeouts.html
  - https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-global-scope/
last_verified: 2026-07-10
related: [backend-java-kotlin-coroutines-dispatchers-and-blocking, backend-common-errors-async-failure-handling]
---

# Structured Concurrency for Backend Coroutines

## When this applies

Launching coroutines in a backend service (fire-and-forget work, parallel calls);
coroutines leaking or surviving past the request/component that started them;
exceptions from `launch {}` vanishing or cancelling unrelated work.

## Do this

1. Apply the mental model: structured concurrency means every coroutine lives in a
   scope that outlives it; the scope waits for its children and propagates
   cancellation and failure through the parent-child tree. `GlobalScope.launch` is
   the unstructured escape hatch: no parent `Job` (cannot be cancelled or awaited
   collectively) and no `CoroutineExceptionHandler` installed (failures fall to
   last-resort handling) — work leaks past the request/component lifecycle. Work
   that must survive a crash/restart belongs in a durable job, not any in-process
   coroutine → [backend-common-errors-async-failure-handling].
2. Pick the scope by the work's lifetime:

| Work | Scope |
|------|-------|
| Request-scoped parallel work (fan out, join results) | `coroutineScope { async {} / launch {} }` — waits for all children; one child's failure cancels the siblings and rethrows to the caller (fails together) |
| Independent children where one failure must NOT kill siblings | `supervisorScope`, with a `CoroutineExceptionHandler` in each `launch`ed child's context — under a supervisor an uncaught child failure reaches only that handler |
| Service/component-lifetime background work | A scope the component owns: `CoroutineScope(SupervisorJob() + dispatcher + handler)`, with `scope.cancel()` in the component's shutdown hook |

3. Route exceptions by builder — this decides whether a failure is seen at all:

| Builder | Where the exception goes |
|---------|--------------------------|
| `async {}` | Held until `await()` — an un-awaited failed `async` is a silent loss; every started `async` gets awaited (`awaitAll` for groups) |
| `launch {}` | Propagates to the scope immediately — in a plain (non-supervisor) scope it cancels the scope and every sibling |

4. Make CPU-loop coroutines cancellable: cancellation is **cooperative** — code
   observes it only at suspension points. In a loop with no suspension, call
   `ensureActive()` (throws when cancelled) or `yield()` each iteration.
5. Let `CancellationException` fly: in any `catch (e: Exception)` inside a
   coroutine, rethrow it first (`if (e is CancellationException) throw e`) or catch
   the specific business exceptions instead. A swallowed `CancellationException`
   makes the coroutine uncancellable and stalls its parent's shutdown.
6. Clean up under cancellation with `try/finally`; when the cleanup itself suspends
   (closing a connection, final flush), wrap it in `withContext(NonCancellable)` —
   plain suspending calls in a cancelled coroutine throw immediately.

## Edge cases

| Case | Then |
|------|------|
| Coroutine keeps running after `cancel()`/`withTimeout` fired | It is either in a non-suspending CPU loop (rule 4) or inside a blocking call that cancellation cannot interrupt → [backend-java-kotlin-coroutines-dispatchers-and-blocking] |
| `async` child under `supervisorScope` fails | The supervisor keeps siblings alive, but the exception still surfaces only at `await()` — awaiting stays mandatory |
| Background scope built with plain `Job()` instead of `SupervisorJob()` | First child failure cancels the scope and kills all future background work silently — use `SupervisorJob()` for component scopes |
| Retry loop catches all exceptions to retry | Rethrow `CancellationException` before the retry branch, or shutdown waits out every remaining retry |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `GlobalScope.launch { }` for after-response work | Component-owned scope (table row 3); durable job when the work must happen → [backend-common-errors-async-failure-handling] | GlobalScope work is unobservable and uncancellable as a group; process death loses it silently |
| Wrap `launch {}` in `try/catch` to observe its failure | `CoroutineExceptionHandler` in the child's context (supervisor), or `coroutineScope` and catch at the caller | The `launch` call returns immediately; the try/catch around it never sees the coroutine's exception |
| `catch (e: Exception)` inside a coroutine to log-and-continue | Catch the specific exceptions; rethrow `CancellationException` | Swallowing cancellation makes the coroutine unstoppable |
| Fire `async` for a side effect and drop the `Deferred` | `launch` in the right scope (side effect), or `await` the result | A failed un-awaited `async` reports nothing, nowhere |

## Sources

- https://kotlinlang.org/docs/coroutines-basics.html — coroutine tree with linked lifecycles, parents wait for children, `coroutineScope` builder, `launch`, `runBlocking` bridging
- https://kotlinlang.org/docs/exception-handling.html — `launch` propagates / `async` defers to `await()`, `CoroutineExceptionHandler` semantics, child failure cancels parent and siblings, supervisor scoping, cancellation exceptions transparent
- https://kotlinlang.org/docs/cancellation-and-timeouts.html — cooperative cancellation, `ensureActive`/`yield`/`isActive` in non-suspending loops, `try/finally` cleanup, `withContext(NonCancellable)`, `withTimeout`
- https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-global-scope/ — GlobalScope has no Job (no collective cancel/await) and no exception handler; delicate API, leak warning
