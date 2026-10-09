---
id: frontend-data-fetching-query-key-prefix-invalidation
domain: frontend
category: data-fetching
applies_to: [tanstack-query]
confidence: verified
sources:
  - https://tanstack.com/query/latest/docs/framework/react/guides/query-invalidation
  - https://tanstack.com/query/latest/docs/reference/QueryClient
last_verified: 2026-10-06
related: [frontend-data-fetching-query-state-vs-fetch-state, frontend-state-client-vs-server-state, frontend-data-fetching-race-conditions]
---

# Placing a New Query Key Under an Existing Key Prefix

## When this applies

You are adding a query key for a new server resource (a status endpoint, a
sub-resource, a polled job) to a TanStack Query cache that already has keys for
related entities, and you must decide whether the new key starts with an existing
entity's key (`['postings', id, 'research']`) or gets its own first segment
(`['research', id, 'status']`). Also when a mutation's `onSuccess` invalidates a
key and an unrelated view refetches.

## Do this

`invalidateQueries({ queryKey })` matches by **prefix**: `queryKey: ['todos']`
invalidates both `['todos']` and `['todos', { page: 1 }]`. Where you put a new key
therefore decides which existing invalidations reach it.

| Case | Do |
|------|----|
| The new data changes whenever the parent entity changes (the posting's own fields, its comments list) | Nest it under the parent's key (`['postings', id, 'comments']`) so every existing `invalidateQueries({ queryKey: ['postings', id] })` refreshes it too |
| The new data has its own lifecycle — written by a different process, polled, or expensive to fetch — and a parent edit does not change it | Give it its own first segment (`['research', id, 'status']`); then list every existing call that invalidates the parent prefix and confirm none of them needs to reach the new key |
| The new key has its own first segment and a mutation does change it | Invalidate it explicitly in that mutation's `onSuccess` with its own key; the parent's invalidation does not reach it |
| You need one call to refresh the parent entry but not its nested children | Pass `exact: true` — only the key equal to `queryKey` is invalidated, `['todos', { type: 'done' }]` is left alone |
| Keys are built in several files | Add the new key as one entry of the project's key-factory object (`queryKeys.x(id) => [...] as const`) and build every call site from it, so the prefix the entry starts with is visible in one place |

## Edge cases

| Case | Then |
|------|------|
| The resource is polled (`refetchInterval`) and nested under a frequently invalidated parent | Each parent invalidation adds an extra fetch on top of the poll; move it to its own first segment |
| You are renaming an existing key's first segment | Search every `invalidateQueries`, `removeQueries` and `cancelQueries` call (these take query filters) for the old prefix in the same change — a prefix that no longer matches fails silently: nothing refetches and nothing errors. Update every `setQueryData`/`getQueryData` call too; those take one exact key, not a prefix |
| Two features share a first segment by coincidence (`['user', id]` for profile and for settings) | Treat them as one prefix: an invalidation for either reaches both. Split the first segment when they change independently |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Nest a new key under the closest related entity because it "belongs" there | Decide by which writes change the data: nest when parent writes change it, use a separate first segment when they do not | Prefix matching turns key placement into an invalidation rule; placement by topic refetches data no write touched |
| Add `exact: true` to an existing parent invalidation to stop it reaching a new nested key | Move the new key out of the prefix | `exact: true` on the old call also stops it refreshing the children that do depend on the parent |

## Sources

- https://tanstack.com/query/latest/docs/framework/react/guides/query-invalidation — "you can match multiple queries by their prefix, or get really specific and match an exact query"; with `queryKey: ['todos']` both `['todos']` and `['todos', { page: 1 }]` are invalidated; with `exact: true`, `['todos', { type: 'done' }]` is NOT invalidated
- https://tanstack.com/query/latest/docs/reference/QueryClient — `removeQueries` "Removes queries from the cache that match the given filters" and `cancelQueries` takes `QueryFilters`; `setQueryData` takes a `queryKey` parameter, not filters
- Field evidence 2026-10-06 (a React Native + TanStack Query v5 app, research-status screen plan): a per-posting status key placed under `['postings', id, ...]` would have refetched on every posting edit through the existing `invalidateQueries(queryKeys.posting(id))`; the plan moved it to `['research', postingId, 'status']`
