---
id: frontend-state-client-vs-server-state
domain: frontend
category: state
applies_to: [react, general]
confidence: verified
sources:
  - https://tanstack.com/query/latest/docs/framework/react/overview
  - https://react.dev/learn/choosing-the-state-structure
  - https://tanstack.com/query/latest/docs/framework/react/guides/query-invalidation
last_verified: 2026-07-10
related: [frontend-state-derived-state, frontend-data-fetching-race-conditions]
---

# Choosing Where a Piece of UI Data Lives

## When this applies

Deciding where/how to store a piece of UI data (new feature, new field), or an
existing global store has grown unmanageable and you are untangling it.

## Do this

Classify the data first; the class determines the storage mechanism:

| Data class | Store it in |
|------------|-------------|
| Server-owned data displayed in the UI (fetched entities, lists, detail records) | A server-state cache (TanStack Query / SWR pattern): cache keyed by endpoint + params, a staleness window, background refetch, invalidation after mutations — not a hand-rolled global store |
| UI-only ephemeral state (open modal, hover, accordion, input draft) | Local state in the component that uses it; lift only to the nearest common ancestor that needs it |
| Cross-cutting client state (theme, locale, authenticated session) | One small global store or context; keep it to genuinely app-wide values |
| Derived data (filtered list, count, selected item object) | Compute during render — do not store; see [frontend-state-derived-state] |
| URL-addressable state (filters, page number, selected tab, search query) | The URL (route/query params) — it survives refresh and back/forward, and makes the view shareable |

When auditing an overgrown global store, classify each field by this table and
move it to its row's mechanism; what remains in the store is only the
cross-cutting row.

## Edge cases

| Case | Then |
|------|------|
| Fetched entity must be edited locally before saving | Keep the cache as the source; hold the edit as a local draft initialized from the cached value with an explicit reset key ([frontend-state-derived-state] edge cases) |
| Live/streamed data (WebSocket, SSE) | Still the server-state cache: write pushed messages into the cache entry so all consumers read one copy |
| The same fetched data is needed by distant components | Both call the cache with the same key — the cache dedupes the request; passing it through a global store creates a second copy to sync |
| Sensitive state (tokens, PII) that must not persist | Exclude it from any cache/store persistence layer; keep it in memory only |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Copy fetched data into a global store and sync it manually | Use a server-state cache with invalidation after mutations | Manual copies go stale; invalidation refetches the one source of truth |
| Put modal-open / draft-input flags in the global store | Local component state | Global scope adds re-renders and coupling for data with one consumer |
| Track current filter/tab only in a store variable | Put it in the URL, read state from the URL | Refresh, back button, and shared links reproduce the view for free |

## Sources

- https://tanstack.com/query/latest/docs/framework/react/overview — server state challenges: staleness, deduping, background updates
- https://react.dev/learn/choosing-the-state-structure — avoid redundant/duplicated state
- https://tanstack.com/query/latest/docs/framework/react/guides/query-invalidation — invalidate-and-refetch after mutations
