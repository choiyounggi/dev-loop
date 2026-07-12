---
id: frontend-data-fetching-race-conditions
domain: frontend
category: data-fetching
applies_to: [react, general]
confidence: verified
sources:
  - https://developer.mozilla.org/en-US/docs/Web/API/AbortController
  - https://react.dev/reference/react/useEffect
  - https://tanstack.com/query/latest/docs/framework/react/guides/query-invalidation
last_verified: 2026-07-10
related: [frontend-state-client-vs-server-state]
---

# Out-of-Order Responses Overwriting Fresh UI

## When this applies

The same fetch can be issued repeatedly with changing params before earlier
responses arrive — search-as-you-type, rapid tab/filter switches — or you are
debugging a UI that intermittently shows results for a previous input.

## Do this

1. State the invariant: the LAST-issued request must win. Network delivery order
   is not issue order — a slow earlier response can arrive after a fast later one
   and overwrite it. Every repeated-fetch call site needs one of these mechanisms:

| Mechanism | Use when |
|-----------|----------|
| Server-state cache keyed by params (TanStack Query / SWR pattern) | The app already uses one — each param set is its own cache entry, so a stale response cannot land under the current key; prefer this over hand-rolling |
| AbortController: keep the previous request's controller, `abort()` it when issuing the next, pass `signal` to `fetch` | Hand-rolled `fetch` you control — also stops wasted transfer/parse |
| Ignore-stale guard: record a token (request id or the params) per request; on resolve, discard the response when its token no longer matches the latest | The request cannot be aborted (third-party SDK, non-fetch transport). In a React effect: `let ignore = false; ... if (!ignore) setState(...); return () => { ignore = true; }` |

2. Debounce the input to cut request volume — as an addition, not a replacement:
   two requests can still be in flight after any debounce, so keep the
   abort/ignore mechanism.
3. After a mutation, invalidate the affected cache entries and let them refetch
   once the mutation settles, rather than hand-writing the response into caches —
   invalidation cannot leave a partially-updated copy.

## Edge cases

| Case | Then |
|------|------|
| Aborted `fetch` rejects with `AbortError` (`DOMException`) | Catch and return silently for that name; rendering it as a user-facing error turns every keystroke into an error flash |
| Mutation response races with an in-flight refetch of the same data | Invalidate after the mutation settles; when the library supports it, cancel in-flight queries for the key at mutation start |
| Response updates several state slots (results + count + facets) | Apply the guard once around one combined update; guarding only `results` lets the other slots desync to a stale response |
| Latest request fails after an older one succeeded | Last-issued still wins: show the error for the latest request; resurfacing the older success displays results for an input the user already left |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Trust that responses arrive in issue order | Abort the previous request or discard stale responses by token | Delivery order is unrelated to issue order; slow-then-overwrite is the standard failure |
| Ship debounce as the race fix | Debounce + abort/ignore-stale | Debounce reduces races; any two in-flight requests still race |
| Hand-write mutation results into every cached copy | Invalidate-and-refetch after the mutation settles | Manual multi-cache writes miss copies and race with refetches |

## Sources

- https://developer.mozilla.org/en-US/docs/Web/API/AbortController — aborting in-flight fetch requests
- https://react.dev/reference/react/useEffect — "Fetching data with Effects": cleanup `ignore` flag for race conditions
- https://tanstack.com/query/latest/docs/framework/react/guides/query-invalidation — invalidation + background refetch after mutations
