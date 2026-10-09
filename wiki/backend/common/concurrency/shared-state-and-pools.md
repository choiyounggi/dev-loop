---
id: backend-common-concurrency-shared-state-and-pools
domain: backend
category: concurrency
applies_to: [general]
confidence: verified
sources:
  - https://github.com/brettwooldridge/HikariCP/wiki/About-Pool-Sizing
  - https://docs.oracle.com/javase/tutorial/essential/concurrency/sync.html
  - https://www.psycopg.org/psycopg3/docs/advanced/async.html
last_verified: 2026-10-02
related: [databases-transactions-isolation-level-selection, backend-common-caching-invalidation-and-stampede, backend-common-reliability-timeouts-and-retries, databases-query-optimization-n-plus-one-queries, databases-indexing-index-selection, testing-quality-sequential-dispatch-assumption-under-concurrency]
---

# Shared In-Process State and Pool Sizing under Concurrent Requests

## When this applies

Request handlers share in-process mutable state — caches, counters, maps. Also
when sizing or debugging thread pools and connection pools, or when the service
deadlocks or starves under load.

## Do this

1. Request handlers run concurrently — unsynchronized shared mutable state
   produces thread interference and memory-consistency errors. Decide by case:

| Case | Do |
|------|----|
| Mutable state read and written by concurrent handlers | Use a concurrency-safe structure (concurrent map, atomic counter) or confine it: per-request state, or an immutable snapshot swapped atomically by a single writer |
| Correctness-bearing shared state (locks, counters, dedupe sets) and the service runs more than one instance | Move it to the shared store: DB row locks/atomic updates → [databases-transactions-isolation-level-selection], or Redis-style atomic operations — in-process state diverges across replicas and vanishes on restart |
| Process-local cache | Treat it as a performance layer only, never a correctness mechanism; staleness policy → [backend-common-caching-invalidation-and-stampede] |

2. Size pools from downstream capacity, not from incoming load:

| Pool | Size it |
|------|---------|
| DB connection pool | A small multiple of what the DB services in parallel — start near `cores × 2` on the DB host (HikariCP/PostgreSQL formula) and tune by measurement. Connections beyond DB capacity move the queuing into the DB and lower throughput |
| Thread pool for blocking I/O | `cores × (1 + wait_time/compute_time)` — threads beyond core count pay for themselves only while other threads are blocked on I/O |

3. Break the pool-deadlock pattern: holding one pooled resource while waiting to
   acquire another from the same exhausted pool (transaction open on connection
   1 → code requests connection 2) deadlocks under load, exactly when the pool
   is full. Acquire once per operation and release before acquiring elsewhere.
   When one thread genuinely holds `Cm` connections at once, the pool minimum is
   `Tn × (Cm − 1) + 1` (HikariCP deadlock formula, `Tn` = thread count).
4. Bound every in-memory queue and reject work when it is full — fail fast per
   [backend-common-reliability-timeouts-and-retries]. An unbounded queue is a
   memory-pressure crash deferred to peak load.

## Edge cases

| Case | Then |
|------|------|
| Read-mostly reference data (config, feature flags) updated occasionally | Publish an immutable snapshot through an atomic reference; the writer builds a new snapshot and swaps it — readers never take a lock |
| Storage got faster (SSD/NVMe), so the pool "can" grow | Shrink it — faster I/O means less blocking, which warrants fewer connections, not more (HikariCP) |
| One connection or driver instance is about to be shared by several request threads (a diagnostic patch to remove per-request connect cost, a hand-rolled singleton) | First grep whether the runtime opens a transaction per request (`begin` … `commit` around the handler). When it does, the unit of exclusivity is the request: keep the instances in a blocking queue, take one at request start and return it in a `finally` after the request's commit or rollback. A lock around each driver call is released between one request's `begin` and its `commit`, so another request's `begin` lands inside the open transaction — a nested-begin error, or statements committed under the wrong request. In an experiment, classify nested-begin errors as defects of the patch and keep them out of the hypothesis's error count |
| Single instance today, autoscaling planned | Apply the multi-instance row of the decision table now — in-process locks/dedupe silently become per-replica the day a second instance starts |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Put `synchronized`/a global lock around a hot section as the first fix | Narrow the shared state: atomics, sharded counters, immutable snapshot swap | A global lock serializes every handler — contention slows or suspends threads under exactly the load you tuned for |
| Raise the connection pool size because requests queue for connections | Hold the pool at DB capacity and fix the slow queries → [databases-query-optimization-n-plus-one-queries], [databases-indexing-index-selection] | Past DB capacity, more connections reduce throughput — the wait moves inside the DB |
| Make a shared connection "thread-safe" with a lock per method call | Check it out for the whole transaction (pool or queue), one holder at a time | Thread-safe calls do not make a transaction private: every user of the connection is inside the same transaction |
| Absorb bursts with an unbounded in-memory queue | Bounded queue + fail fast when full → [backend-common-reliability-timeouts-and-retries] | Unbounded queues defer the failure to an out-of-memory crash at peak |

## Sources

- https://github.com/brettwooldridge/HikariCP/wiki/About-Pool-Sizing — `cores × 2` starting formula, more connections ≠ more throughput, SSD warrants fewer connections, deadlock minimum `Tn × (Cm − 1) + 1`
- https://docs.oracle.com/javase/tutorial/essential/concurrency/sync.html — thread interference and memory-consistency errors from shared access; synchronization's thread-contention cost
- https://www.psycopg.org/psycopg3/docs/advanced/async.html — "Connection objects are thread-safe: more than one thread at time can use the same connection"; "All the cursors that share the same connection will also share the same transaction. This means that, if a thread starts a transaction, every cursor on the same connection will execute their queries in the same transaction"
- Local reproduction 2026-10-02 (Python 3.14, `sqlite3`, 8 threads × 40 requests of `BEGIN; INSERT; COMMIT` on one shared connection): a lock per `execute` call → 236 of 320 requests failed with `cannot start a transaction within a transaction`, 84 rows written; the same connection handed out through a `queue.Queue` for the whole request → 0 errors, 320 rows
- Field evidence 2026-10-02 (an HTTP runtime that wraps each request in `begin` … `commit`, with a PostgreSQL driver that rejects a nested `begin`): a diagnostic patch sharing driver instances through a per-request checkout queue ran a 100-request smoke and three 150 rps × 90 s runs with 0 errors; the runtime's per-request `begin` and the driver's nested-begin rejection were both confirmed in source before choosing the checkout design over a per-call lock
