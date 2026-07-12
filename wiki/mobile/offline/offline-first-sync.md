---
id: mobile-offline-offline-first-sync
domain: mobile
category: offline
applies_to: [ios, android, cross-platform]
confidence: verified
sources:
  - https://developer.android.com/topic/architecture/data-layer/offline-first
  - https://developer.android.com/topic/libraries/architecture/workmanager
last_verified: 2026-07-10
related: [mobile-networking-calls-on-mobile-networks, mobile-lifecycle-process-death-and-state]
---

# Offline-First Reads and Writes That Sync Later

## When this applies

The app must work with intermittent connectivity: users read data and/or perform
actions while offline, and the app reconciles with the server later. Also when
diagnosing lost offline edits, duplicated actions after reconnect, or UI that blanks
out when the network drops.

## Do this

1. **One read path: UI ← local store ← sync engine ← server.** The UI reads only
   from the local database; network responses are written into the local store and
   the UI observes the store. Never render a screen directly from a network response
   with the cache as an afterthought — two sources of truth diverge.
2. **Offline writes go to a durable outbox.** Append each user action (action type +
   payload + client-generated id) to a persisted queue, apply it optimistically to
   the local store, and replay the queue in order on reconnect. Drive the replay
   from a connectivity-constrained scheduler (Android WorkManager with
   `NetworkType.CONNECTED`; iOS background task on reconnect) — retry timing rules
   are in [mobile-networking-calls-on-mobile-networks].
3. **Every replayed action is idempotent server-side.** Attach an idempotency key
   per outbox entry (generate once when enqueuing, reuse on every replay attempt).
   The server-side dedupe/storage pattern is a backend concern — see the backend
   domain (`wiki/backend/`, api-design idempotency).
4. **Detect conflicts with a version, resolve with a policy.** Each record carries a
   version/etag; the server rejects a write against a stale version — that is
   detection. Resolution is a per-data-type decision:

| Data being synced | Conflict policy |
|-------------------|-----------------|
| Single-user preference data (settings, flags, last-read markers) | Last-write-wins using the server-assigned timestamp |
| Structured user data edited on multiple devices (profile with independent fields) | Field-level merge — apply non-overlapping field changes; overlapping fields fall through to the row below |
| High-value conflicting edits (documents, financial entries) | Explicit user resolution — present both versions, the user chooses |

5. **Show sync status per item.** Each pending/synced/failed state is visible in the
   UI (icon, badge, or list section). Silent sync erodes trust and hides failures the
   user could fix.
6. **The server assigns authoritative order.** Client clocks skew — device clocks are
   user-settable and drift. Use client timestamps for display and hints only; use
   server-assigned timestamps/sequence for ordering and last-write-wins comparison.

## Edge cases

| Case | Then |
|------|------|
| An outbox action references an entity created offline earlier in the queue | Generate entity ids client-side (UUID) at creation so later actions reference them before the server has seen the create |
| Replay fails mid-queue on one action (conflict/validation error) | Mark that item failed and surface it; continue replaying independent actions; halt only the chain that depends on the failed one |
| App update ships while the outbox is non-empty | Version outbox entries; on replay, migrate old-version payloads (or keep a handler per version) — never drop the queue on upgrade |
| Server processed the write but the response was lost (timeout after commit) | This is why the idempotency key exists: replay with the same key returns the original result instead of duplicating |
| Process death between local write and outbox append | Write the local-store change and the outbox entry in one local transaction |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Render from the network response and treat the local DB as a cache to fill later | Write responses into the local store; UI observes the store | Single source of truth; the screen keeps working offline |
| Fire the write to the server and save locally only if it fails | Local write + outbox entry first, sync engine replays | "Online path vs offline path" forks diverge; one path is always undertested |
| Order merges by client timestamps | Server assigns order/version | Clock skew makes client time unreliable for ordering |
| Sync silently in the background with no per-item state | Pending/synced/failed status visible per item | Users retry or lose trust when edits vanish without explanation |

## Sources

- https://developer.android.com/topic/architecture/data-layer/offline-first — local store as source of truth, queued writes, last-write-wins, sync strategies
- https://developer.android.com/topic/libraries/architecture/workmanager — durable, network-constrained background replay with backoff
