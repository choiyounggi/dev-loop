---
id: frontend-data-fetching-infinite-scroll
domain: frontend
category: data-fetching
applies_to: [react, general]
confidence: verified
sources:
  - https://developer.mozilla.org/en-US/docs/Web/API/Intersection_Observer_API
  - https://tanstack.com/query/latest/docs/framework/react/guides/infinite-queries
  - https://addyosmani.com/blog/infinite-scroll-without-layout-shifts/
  - https://developer.mozilla.org/en-US/docs/Web/API/History/scrollRestoration
  - https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Guides/Live_regions
last_verified: 2026-07-10
related: [frontend-data-fetching-race-conditions, frontend-rendering-long-lists, frontend-state-client-vs-server-state, backend-common-api-design-pagination-contract, databases-query-optimization-keyset-pagination]
---

# Infinite Scroll and Load-More Feeds

## When this applies

Implementing infinite scroll or a load-more feed; or fixing an existing one
that loses scroll position on back-navigation, duplicates or skips items, or
spams page requests. Also when choosing between infinite scroll and a
load-more button.

## Do this

1. Trigger the next page with an IntersectionObserver on a sentinel element
   placed after the last row. Set `rootMargin` (a few hundred px, e.g.
   `"400px 0px"`) so the page is fetched before the user reaches the end.
   Observer callbacks are delivered asynchronously, off the per-scroll-event
   path — no manual scroll math.
2. Guard the loader — the observer fires repeatedly while the sentinel stays
   visible:

| Condition | Do |
|-----------|-----|
| A page request is already in flight | Return without fetching (in-flight flag / `isFetchingNextPage`) — one page request at a time |
| Response says `has_more: false` (or returns no next cursor) | Stop: unobserve the sentinel and render an explicit "end of list" marker |
| Page request failed | Render an inline retry row where the next page would appear; its button re-issues that page — a feed that stops silently reads as complete |

3. Request cursor pagination from the API and pass each response's cursor into
   the next request. Offset pages skip or duplicate items when rows are
   inserted or deleted between loads. Contract:
   [backend-common-api-design-pagination-contract]; SQL side:
   [databases-query-optimization-keyset-pagination].
4. Append pages into ONE ordered list in the server-state cache, keyed by the
   query params (TanStack Query `useInfiniteQuery` pattern;
   [frontend-state-client-vs-server-state]). Changing filters/search/sort is a
   new key: reset to page one and discard stale in-flight page responses
   ([frontend-data-fetching-race-conditions]).
5. When the feed can grow past a few hundred rows, virtualize it
   ([frontend-rendering-long-lists]) — without virtualization, infinite scroll
   grows the DOM without bound.
6. Restore position on back-navigation: keep loaded pages in the cache so they
   re-render instantly (the server-state cache from step 4 does this), set
   `history.scrollRestoration = "manual"` when your SPA router owns scrolling,
   and re-apply the stored scroll offset once the cached pages have rendered.
   Without this, users returning to the feed land at the top of page one.
7. Accessibility: announce appended content with an `aria-live="polite"`
   region ("20 more results loaded") and keep focus where the user left it.
   When accessibility requirements are uncertain, ship a load-more BUTTON —
   focusable, announced, keyboard-operable — as the accessible baseline.

## Edge cases

| Case | Then |
|------|------|
| First page is shorter than the viewport | The sentinel is visible on mount and the observer fires immediately — the in-flight flag plus the `has_more` stop from step 2 make this safe; verify both exist before shipping |
| Essential footer links sit below the feed | Move them elsewhere (header/sidebar) or use a load-more button — an infinite feed makes the footer unreachable |
| Live feed can insert new items above the viewport | Load them behind an explicit "N new items" control instead of auto-prepending — prepending shifts content under the user (layout shift) |
| Scroll restore runs before the cached rows have rendered | Re-apply the offset after the restored pages paint; restoring into an empty list lands at the top |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Attach a scroll event handler with manual position math | IntersectionObserver on a sentinel with `rootMargin` | Scroll handlers run per event on the main thread — jank plus missed/duplicate fires |
| Use offset/page-number pagination for a feed that changes | Cursor pagination ([backend-common-api-design-pagination-contract]) | Inserts/deletes between loads shift offsets — items skip or duplicate |
| Let every observer callback start a request | One page request at a time behind an in-flight flag | The callback fires repeatedly while the sentinel is visible — request stampede |
| Stop silently when a page load fails | Inline retry row at the load point | The feed reads as complete; the user has no recovery path |

## Sources

- https://developer.mozilla.org/en-US/docs/Web/API/Intersection_Observer_API — sentinel observation, `rootMargin` pre-load offsets, infinite-scroll use case, async delivery vs main-thread scroll handlers
- https://tanstack.com/query/latest/docs/framework/react/guides/infinite-queries — pages appended into one cached list, cursor via `getNextPageParam`, `hasNextPage` stop, in-flight guard before `fetchNextPage`
- https://addyosmani.com/blog/infinite-scroll-without-layout-shifts/ (canonical target of web.dev/patterns/web-vitals-patterns/infinite-scroll) — footer unreachability, load-more as the more accessible pattern, layout-shift pitfalls
- https://developer.mozilla.org/en-US/docs/Web/API/History/scrollRestoration — `auto`/`manual` scroll restoration control
- https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Guides/Live_regions — `aria-live="polite"` for announcing dynamically appended content
