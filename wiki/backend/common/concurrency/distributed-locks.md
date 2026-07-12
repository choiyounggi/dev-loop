---
id: backend-common-concurrency-distributed-locks
domain: backend
category: concurrency
applies_to: [general, redis]
confidence: verified
sources:
  - https://redis.io/docs/latest/develop/clients/patterns/distributed-locks/
  - https://martin.kleppmann.com/2016/02/08/how-to-do-distributed-locking.html
last_verified: 2026-07-10
related: [backend-common-concurrency-shared-state-and-pools, backend-common-jobs-scheduled-job-overlap, databases-transactions-isolation-level-selection]
---

# Distributed Locks

## When this applies

Multiple service instances must ensure only one performs an action at a time
(batch run, external side effect, resource rebuild), or you are reviewing/debugging
a Redis-style lock: locks released by the wrong holder, work done twice, locks
stuck after a crash.

## Do this

1. **Exhaust resource-local tools first.** When the protected resource is a
   database row/table, the database already serializes correctly:

| Case | Do |
|------|----|
| Guarding a DB state change | Conditional atomic UPDATE or row lock ([databases-transactions-isolation-level-selection]) — no external lock needed |
| Guarding uniqueness | Unique constraint + conflict handling |
| Coordinating on the same PostgreSQL | Advisory lock (`pg_advisory_xact_lock`) — released automatically with the transaction |
| Non-DB resource (external API call, file build, cache rebuild) across instances | A distributed lock (below) is appropriate |

2. **Single-store lock pattern** (Redis-style): acquire with one atomic command
   setting key, **owner token** (random per acquisition), and TTL
   (`SET lock:<name> <token> NX PX <ttl>`). Release by delete-if-token-matches in
   one atomic step (Lua script / CAS) — a plain `DELETE` in your `finally` block
   deletes the NEXT holder's lock whenever your TTL expired mid-work.
3. **Pick the TTL against both failure modes**: shorter than acceptable recovery
   time after a holder crash, longer than the p99 of the protected work. When the
   work duration is unbounded, use a **watchdog**: a keeper thread extends the TTL
   while the holder runs (Redisson pattern) — crash stops the extensions and the
   lock self-expires.
4. **Treat the lock as probability reduction, not proof.** A paused process (GC,
   VM freeze) can resume after its TTL expired and keep working while another
   holder runs. When the protected effect must never happen twice, the RESOURCE
   must reject the stale actor: unique constraint / conditional update at the
   final write, or a fencing token (monotonic counter issued with the lock,
   checked by the resource) — the lock alone cannot provide this.

## Edge cases

| Case | Then |
|------|------|
| Lock store (single Redis) restarts | All lock state is gone; two holders can coexist until TTLs realign — another reason the final write must self-defend |
| Considering Redlock (multi-node quorum) | It raises availability, but its correctness under network delay/pauses is contested (Kleppmann); for correctness-critical exclusion use the DB/consensus store you already trust + fencing, not more Redis nodes |
| Lock wraps a scheduled batch | Overlap prevention for jobs has simpler tools first ([backend-common-jobs-scheduled-job-overlap]) |
| Waiting for a busy lock | Prefer fail-fast + retry with backoff over blocking waits — queued waiters amplify outages ([backend-common-concurrency-shared-state-and-pools] bounded-queue rule) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Release the lock with a bare `DELETE` in `finally` | Atomic delete-if-my-token-matches | After a TTL expiry your delete removes the current holder's lock |
| Protect a money-critical effect with a lock alone | Add the resource-level defense (unique constraint / conditional update / fencing token) | Pauses and store failures make lone locks best-effort |

## Sources

- https://redis.io/docs/latest/develop/clients/patterns/distributed-locks/ — single-instance pattern, owner token, Redlock
- https://martin.kleppmann.com/2016/02/08/how-to-do-distributed-locking.html — efficiency vs correctness, fencing tokens, Redlock critique
