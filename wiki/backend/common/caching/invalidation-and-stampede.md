---
id: backend-common-caching-invalidation-and-stampede
domain: backend
category: caching
applies_to: [general]
confidence: field-tested
sources:
  - https://aws.amazon.com/builders-library/caching-challenges-and-strategies/
last_verified: 2026-07-10
related: [backend-common-reliability-timeouts-and-retries]
---

# Adding a Cache: Invalidation Design and Stampede Protection

## When this applies

Putting a cache (in-process map, Redis, memcached) in front of an expensive
read; or debugging stale reads, cross-tenant data leaks from cached responses,
or load spikes when hot keys expire (thundering herd).

## Do this

1. Design the invalidation **before** adding the cache:

| Data changes via | Invalidation |
|------------------|--------------|
| Your own write path only | Delete the cache key in the write path, **after** the DB commit (delete-on-write). Deleting beats writing the new value through: no recompute logic in the write path, no last-writer-wins races between concurrent writers |
| Other systems, replication, or unknowable writers | TTL only. Size the TTL to the staleness the feature owner accepts, and record that number next to the cache code |

2. Give **every key a TTL**, including delete-on-write keys — the TTL is the
   backstop for missed invalidations and races (rule 1 chooses the primary
   mechanism, not whether a TTL exists).
3. The cache key includes **every input that changes the result**: tenant id,
   principal/role when authorization shapes the data, locale, API version,
   active feature flags. A missing dimension serves one tenant's data to
   another — review key construction as a security concern, not a perf detail.
4. Stampede protection for hot keys — apply when a key's recompute is expensive
   and many requests hit it concurrently:
   - **single-flight**: per-key lock/promise so exactly one loader recomputes on
     a miss while concurrent requests wait for its result (AWS: request
     coalescing), or
   - **stale-while-revalidate**: serve the expired value and refresh in the
     background.
5. Add TTL jitter (e.g. ±10% of the TTL) so keys warmed together do not expire
   together and re-herd the source.
6. Cache negative results ("not found", empty) with a TTL shorter than the
   positive TTL, so repeated lookups of an absent row do not hammer the source
   on every request (AWS negative caching).

## Edge cases

| Case | Then |
|------|------|
| Read races a write: reader fetches the old DB value, the write deletes the key, then the reader caches the old value | The per-key TTL from rule 2 bounds the damage; where even that staleness is unacceptable, version the key (append a version/updated_at read from the source of truth) |
| In-process cache on multiple instances | A write-path delete clears only the local instance. Use a shared cache, or broadcast invalidation (pub/sub) to all instances; the TTL covers instances that miss the broadcast |
| Caching authorization/permission results | Key by (principal, resource) and use a short TTL — revocation must propagate within the TTL, so the TTL equals your maximum acceptable revocation delay |
| Shared cache is down (Redis outage) | Fall through to the source **with a concurrency cap** and treat the cap as fail-fast — an uncapped fallthrough herd turns a cache outage into a source outage → [backend-common-reliability-timeouts-and-retries] |
| Cache shares a store (Redis instance) with sessions or other loss-intolerant data | Separate them: different instances, or at minimum different eviction domains — rebuildable cache data on `allkeys-lru`-style eviction, sessions/critical keys on a store configured `noeviction` with by-design TTLs. When memory fills, eviction picks victims by policy, not by importance — TTL-less cache keys silently evict sessions and users get logged out with zero error logs |
| Inherited store has accumulated TTL-less keys | Audit (`SCAN` + check TTL = -1) and assign TTLs in throttled batches — a single mass-expire pass herds both the store and the source |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Ship the cache now and "invalidate later" | Set a TTL on every key from day one, sized to acceptable staleness | Keys with neither TTL nor invalidation serve stale data indefinitely, discovered as a data bug in production |
| Write computed values through from multiple writers | Delete-on-write + recompute on the next read | Concurrent writers race on who writes the cache last; the loser's value wins wrongly |
| Use one global TTL constant for all key classes | Choose a TTL per key class from that data's staleness tolerance | A single number is either too stale for volatile data or too short (herd-inducing) for stable data |

## Sources

- https://aws.amazon.com/builders-library/caching-challenges-and-strategies/ — TTL sizing by staleness tolerance, thundering herd / request coalescing, negative caching with distinct TTL
