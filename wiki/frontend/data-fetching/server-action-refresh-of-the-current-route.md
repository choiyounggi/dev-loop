---
id: frontend-data-fetching-server-action-refresh-of-the-current-route
domain: frontend
category: data-fetching
applies_to: [nextjs, react]
confidence: verified
sources:
  - https://nextjs.org/docs/app/api-reference/functions/revalidatePath
  - https://nextjs.org/docs/app/api-reference/functions/refresh
  - https://github.com/vercel/next.js/blob/v16.3.8/packages/next/src/server/web/spec-extension/revalidate.ts
  - https://github.com/vercel/next.js/blob/v16.3.8/packages/next/src/server/app-render/action-handler.ts
  - https://github.com/vercel/next.js/blob/v16.3.8/packages/next/src/client/components/router-reducer/reducers/server-action-reducer.ts
last_verified: 2026-10-12
related: [frontend-data-fetching-query-key-prefix-invalidation, frontend-data-fetching-async-ui-states, platforms-toolchains-flag-availability-at-the-execution-site]
---

# Refreshing the Current Route From a Next.js Server Action After a Write Made Elsewhere

## When this applies

A Next.js App Router page must show new server state right after a Server
Action completes, and the write itself happened on another path — an XHR or
`fetch` upload to a Route Handler, a background job, a second service — so the
action only "signals" the change. The action calls `revalidatePath` with some
other path (often `'/'`) and the page the user is on refreshes anyway, and you
are deciding whether to rely on that, or writing the test that pins it.

## Do this

1. **When the current page must refresh no matter which path was revalidated,
   call `refresh()` from `next/cache` inside the action** (Next.js 16.0.0 and
   later; the export is absent at 15.5.0). It marks the action as
   "revalidated dynamic data only", and the action response re-renders the
   current route tree.
2. **Keep `revalidatePath` / `revalidateTag` for the cache entries the write
   made stale**, naming the paths or tags the write actually affected. Pair it
   with `refresh()` when the current route is not among them.
3. **Pin the behaviour with a browser check that reads the page before any
   reload**: perform the action in Playwright (or the project's e2e runner), then
   assert the new item is in the DOM with no `page.reload()` and no navigation
   in between. A check that reloads first proves nothing about the action.
4. **Treat "any `revalidatePath` re-renders the current route" as a current
   implementation detail, not a contract.** The docs call it temporary and the
   source carries `// TODO: only revalidate if the path matches`; a later
   narrowing would stop the refresh with no error.

What the action response does on 16.3.8, by what the action called:

| The action calls | Server marks | Action response | Client router |
|------------------|--------------|-----------------|---------------|
| `revalidatePath(anyPath)` or `revalidateTag(tag)` with no cache-life profile | static-and-dynamic revalidated | re-renders the current page | evicts the entire prefetch cache, then refreshes |
| `refresh()` | dynamic-only revalidated | re-renders the current page | keeps the prefetch cache, refreshes dynamic data |
| `revalidateTag(tag, profile)` whose cache life does not expire at once | nothing (stale-while-revalidate: "so that server actions don't pull their own writes") | skips page rendering | no refresh |
| nothing | nothing | skips page rendering | no refresh |

## Edge cases

| Case | Then |
|------|------|
| `refresh()` runs in a Route Handler, a Client Component, or outside the action phase | Throws (`E870`): "refresh can only be called from within a Server Action" — move it into the action, or call `router.refresh()` on the client after the action resolves |
| The project is on Next.js 15.x | No `refresh` export; `revalidatePath` sets a boolean and the same current-route re-render happens. Use `router.refresh()` from `next/navigation` after the action, and re-read this page on the 16 upgrade |
| The action was forwarded from another worker (`actionWasForwarded`) | Page rendering is skipped regardless of what was revalidated; the client still refreshes from the revalidation header |
| The action ends in `redirect()` | The tree re-mounts at the target; `refresh()` is unnecessary for the destination |
| The page is served through a `rewrites()` source path | `revalidatePath` wants the destination path (the route file), not the URL in the address bar |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Call `revalidatePath('/')` so `/admin/photos` refreshes | `refresh()` plus `revalidatePath` of the paths the write affected | The cross-path refresh is a documented-temporary side effect |
| Prove "the list refreshes" with an e2e that reloads the page | Read the DOM before any reload | The reload would show the new state even if the action refreshed nothing |
| Call `revalidatePath` from the upload Route Handler and expect the open page to update | Make the page's own action call `refresh()` after the upload resolves | In a Route Handler, `revalidatePath` only marks the path for its next visit |

## Sources

- https://nextjs.org/docs/app/api-reference/functions/revalidatePath (version 16.3.8 of the docs) — Good to know: "Server Functions: Updates the UI immediately (if viewing the affected path). Currently, it also causes all previously visited pages to refresh when navigated to again. This behavior is temporary and will be updated in the future to apply only to the specific path."; "Route Handlers: Marks the path for revalidation. The revalidation is done on the next visit to the specified path."; rewrites: "you must pass the destination path (the actual route file location)"
- https://nextjs.org/docs/app/api-reference/functions/refresh — "`refresh` allows you to refresh the client router from within a Server Action"; "can only be called from within Server Actions. It cannot be used in Route Handlers, Client Components, or any other context"
- https://github.com/vercel/next.js/blob/v16.3.8/packages/next/src/server/web/spec-extension/revalidate.ts — L73–L91 `refresh()`: throws unless the phase is `'action'`, then "only revalidates the dynamic data on the client" and sets `pathWasRevalidated = ActionDidRevalidateDynamicOnly`; L255–L256: `// TODO: only revalidate if the path matches` followed by `store.pathWasRevalidated = ActionDidRevalidate` (static-and-dynamic), reached by any `revalidatePath`/`revalidateTag` call without a profile or with `expire === 0`. At tag v15.5.0 the same site sets a boolean (`pathWasRevalidated = true`) and no `refresh` is exported; the export exists from v16.0.0 (L60)
- https://github.com/vercel/next.js/blob/v16.3.8/packages/next/src/server/app-render/action-handler.ts — L1410–L1412: `skipPageRendering ||= workStore.pathWasRevalidated === undefined || workStore.pathWasRevalidated === ActionDidNotRevalidate`; L197–L202: the kind is sent to the client in the `x-action-revalidated` header
- https://github.com/vercel/next.js/blob/v16.3.8/packages/next/src/client/components/router-reducer/reducers/server-action-reducer.ts — L206–L207 accepts both kinds from the header; L364–L365 `invalidateEntirePrefetchCache` only for `ActionDidRevalidateStaticAndDynamic`
- Field case 2026-10-12 (Next.js 16.3.8): an admin photo page uploaded through an XHR Route Handler, then ran a Server Action calling `revalidatePath('/')`; the `/admin/photos` list refreshed in the action response. The same lines above were read from the installed `node_modules/next/dist` to confirm the mechanism
