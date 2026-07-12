---
id: backend-java-kotlin-coroutines-dispatchers-and-blocking
domain: backend
category: kotlin
applies_to: [kotlin, kotlinx-coroutines, jvm]
confidence: verified
sources:
  - https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-dispatchers/-default.html
  - https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-dispatchers/-i-o.html
  - https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/run-blocking.html
  - https://kotlinlang.org/docs/coroutine-context-and-dispatchers.html
  - https://kotlinlang.org/docs/cancellation-and-timeouts.html
last_verified: 2026-07-10
related: [backend-java-kotlin-coroutines-structured-concurrency, backend-common-concurrency-shared-state-and-pools, backend-common-reliability-timeouts-and-retries, backend-java-runtime-threads-and-memory]
---

# Dispatcher Choice and Blocking Calls Inside Coroutines

## When this applies

Choosing a dispatcher for coroutine work; calling blocking libraries (JDBC, sync
HTTP clients, file I/O) from coroutines; `runBlocking` appearing in server code;
all coroutines stalling together under load.

## Do this

1. Apply the mental model: a blocking call inside a coroutine blocks the dispatcher
   **thread** — only a suspension point releases it. `Dispatchers.Default` has at
   most as many threads as CPU cores (minimum 2), so a handful of concurrent
   blocking JDBC calls freezes every coroutine scheduled on it. This is the JVM
   form of the node/python event-loop-blocking disease.
2. Route work to the dispatcher by its nature:

| Work | Dispatcher |
|------|-----------|
| CPU-bound (parsing, scoring, compression) | `Dispatchers.Default` — sized to cores, exactly what computation wants |
| Blocking I/O (JDBC, sync HTTP clients, files) | Wrap the call in `withContext(Dispatchers.IO)` — an elastic pool (64 threads or core count, whichever is larger) meant for threads that WAIT |
| Hot blocking path against one resource (main DB, one downstream) | A `Dispatchers.IO.limitedParallelism(n)` view, `n` sized like a blocking worker pool → [backend-common-concurrency-shared-state-and-pools]; views are elastic — not capped by IO's own 64 |
| Async-native client (suspending driver, WebClient, ktor client) | No dispatcher switch — the call suspends instead of blocking |

3. Place `runBlocking` only at the outermost sync→suspend bridge: `main`, tests,
   a legacy blocking-interface adapter. Inside a request handler or inside another
   coroutine it parks that thread until the block completes — on a small pool the
   parked threads are the same ones the inner work needs, which deadlocks (the
   same-pool acquisition trap).
4. Give blocking clients their own timeouts. `withTimeout(ms)` cancels
   **cooperatively** at suspension points — it cannot interrupt a blocking call
   already executing, so `withTimeout` alone around JDBC does not stop the query.
   Set the JDBC statement/socket timeout, the HTTP client timeout, etc.
   → [backend-common-reliability-timeouts-and-retries].
5. On Java 21+ JVMs, heavy blocking-I/O fan-out can alternatively run on virtual
   threads → [backend-java-runtime-threads-and-memory]. Choose coroutines when you
   want structured concurrency and `Flow` streams; with either choice, keep
   blocking work off `Dispatchers.Default`.

## Edge cases

| Case | Then |
|------|------|
| `withContext(Dispatchers.IO)` from Default shows the same thread name | Expected — IO and Default share threads, so the switch avoids a thread hop while still counting against IO's limit; the isolation is real |
| Whole service stalls at ~64 concurrent blocking calls | `Dispatchers.IO`'s default limit is saturated — bound each hot resource with its own `limitedParallelism(n)` view (views add capacity beyond the 64) and fix the slow downstream |
| `runBlocking` inside a `suspend` function | Delete it and call the suspending code directly — the docs flag this as redundant and thread-starving |
| Blocking call must become cancellable | Run it via `withContext(Dispatchers.IO)` and rely on the client's own timeout/interruption; coroutine cancellation alone never interrupts it (rule 4) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Call a JDBC repository directly inside a coroutine on Default | Wrap it in `withContext(Dispatchers.IO)` (bounded view for hot paths) | Each blocking call eats one of ~cores Default threads; a burst freezes all coroutines |
| Use `runBlocking` in a request handler to call suspend code | Make the handler `suspend` (framework support) or bridge once at the framework boundary | `runBlocking` parks the request thread and can deadlock the pool it borrows from |
| Wrap a JDBC call in `withTimeout` as the timeout | Set the driver/client's own timeout; keep `withTimeout` for suspending work | Cooperative cancellation cannot interrupt a running blocking call — the query keeps running |
| Raise `Dispatchers.IO`'s global limit because "IO is slow" | `limitedParallelism(n)` per resource, sized like a blocking pool | A bigger global pool hides the saturated resource and trades stall for thread pileup |

## Sources

- https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-dispatchers/-default.html — Default is the builders' default dispatcher; max threads = CPU cores, minimum 2
- https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/-dispatchers/-i-o.html — designed for offloading blocking IO to a shared pool; 64-or-cores default limit; `limitedParallelism` views elastic beyond the limit; shares threads with Default (no hop on switch)
- https://kotlinlang.org/api/kotlinx.coroutines/kotlinx-coroutines-core/kotlinx.coroutines/run-blocking.html — blocks the current thread; for `main`, tests, and non-suspend callbacks; calling it from suspend code flagged as redundant with thread-starvation risk
- https://kotlinlang.org/docs/coroutine-context-and-dispatchers.html — dispatchers as coroutine context, `withContext` switching
- https://kotlinlang.org/docs/cancellation-and-timeouts.html — `withTimeout` cancellation is cooperative; non-suspending code does not observe it
