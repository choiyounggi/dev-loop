---
id: backend-common-concurrency-shared-state-and-pools
domain: backend
category: concurrency
applies_to: [general]
confidence: verified
sources:
  - https://github.com/brettwooldridge/HikariCP/wiki/About-Pool-Sizing
  - https://docs.oracle.com/javase/tutorial/essential/concurrency/sync.html
last_verified: 2026-07-10
related: [databases-transactions-isolation-level-selection, backend-common-caching-invalidation-and-stampede, backend-common-reliability-timeouts-and-retries, databases-query-optimization-n-plus-one-queries, databases-indexing-index-selection]
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
| Single instance today, autoscaling planned | Apply the multi-instance row of the decision table now — in-process locks/dedupe silently become per-replica the day a second instance starts |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Put `synchronized`/a global lock around a hot section as the first fix | Narrow the shared state: atomics, sharded counters, immutable snapshot swap | A global lock serializes every handler — contention slows or suspends threads under exactly the load you tuned for |
| Raise the connection pool size because requests queue for connections | Hold the pool at DB capacity and fix the slow queries → [databases-query-optimization-n-plus-one-queries], [databases-indexing-index-selection] | Past DB capacity, more connections reduce throughput — the wait moves inside the DB |
| Absorb bursts with an unbounded in-memory queue | Bounded queue + fail fast when full → [backend-common-reliability-timeouts-and-retries] | Unbounded queues defer the failure to an out-of-memory crash at peak |

## Sources

- https://github.com/brettwooldridge/HikariCP/wiki/About-Pool-Sizing — `cores × 2` starting formula, more connections ≠ more throughput, SSD warrants fewer connections, deadlock minimum `Tn × (Cm − 1) + 1`
- https://docs.oracle.com/javase/tutorial/essential/concurrency/sync.html — thread interference and memory-consistency errors from shared access; synchronization's thread-contention cost
