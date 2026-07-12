---
id: frontend-data-fetching-async-ui-states
domain: frontend
category: data-fetching
applies_to: [react, general]
confidence: verified
sources:
  - https://www.nngroup.com/articles/progress-indicators/
  - https://web.dev/articles/cls
  - https://tanstack.com/query/latest/docs/framework/react/guides/background-fetching-indicators
  - https://tanstack.com/query/latest/docs/framework/react/guides/optimistic-updates
  - https://react.dev/reference/react/Component
last_verified: 2026-07-10
related: [frontend-state-client-vs-server-state, frontend-data-fetching-race-conditions]
---

# Designing Loading, Error, Empty, and Data States for an Async View

## When this applies

Building any view backed by async data, users report blank screens / eternal
spinners / dead-end errors, or you are reviewing loading and error handling in UI
code.

## Do this

Design all four states explicitly — an unhandled state renders as a blank screen or
a lie (empty-looking UI over a failed fetch):

| State | Render |
|-------|--------|
| Loading (initial) | For content areas: a skeleton matching the final layout, with the space reserved — an indicator that collapses into content shifts the layout. For indeterminate actions: nothing under ~1 s, a spinner for ~1–10 s, a percent-done indicator beyond ~10 s |
| Error | A message plus a working retry affordance wired to the refetch — never a dead end, never a silent empty view |
| Empty (fetch succeeded, zero items) | A deliberate empty state naming what is empty plus the action that fills it — an empty list rendered as nothing is indistinguishable from broken |
| Data | The data |

Then apply these to the transitions between states:

1. Distinguish initial load from background refresh (stale-while-revalidate): when
   data already exists, keep showing it with a subtle refresh indicator instead of
   a full-screen spinner on every refetch. Server-state caches expose this split as
   `isLoading` (no data yet) vs `isFetching` (refreshing) — see
   [frontend-state-client-vs-server-state].
2. Error boundaries catch RENDER errors, not rejected promises — async failures are
   state you render via the Error row. Keep a boundary per route/section as the
   last-resort crash barrier only.
3. Optimistic updates: apply the local change immediately, roll back on failure and
   notify the user. Use them only for high-success actions that have an inverse;
   for mutation/refetch ordering see [frontend-data-fetching-race-conditions].
4. Avoid spinner cascades (N nested loaders revealing one another): start the
   fetches in parallel or hoist them to a route-level loader so one coordinated
   loading state replaces N sequential ones.

## Edge cases

| Case | Then |
|------|------|
| Background refetch fails while stale data is on screen | Keep the data visible; surface a non-blocking error indicator with retry — blanking a readable view to show an error loses more than it tells |
| List is empty because the user's filters excluded everything | Say so, and offer "clear filters" — the generic empty state ("add your first item") misleads |
| Response resolves fast enough that the skeleton only flashes | Keep the reserved space but suppress indicator animation for sub-second responses — feedback that fast is distraction, not information |
| Mutation has no inverse (send email, submit payment) | No optimistic update — render an explicit pending state until the server confirms |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Render `null` (nothing) while loading | Skeleton/reserved space matching the final layout | A blank screen is indistinguishable from broken, and late-arriving content shifts the layout |
| Write `catch(() => {})` around a fetch | Set error state that renders the message + retry | A swallowed rejection leaves the spinner spinning forever |
| Show a full-screen spinner on every refetch | Stale-while-revalidate: existing data + subtle `isFetching` indicator | Wiping content the user is reading to refresh it destroys their context |
| Rely on an error boundary to handle fetch failures | Render the error state from the fetch's result; boundary stays for render crashes | Boundaries do not catch async errors — the rejection would vanish |

## Sources

- https://www.nngroup.com/articles/progress-indicators/ — indicator thresholds: none < 1 s, spinner 1–10 s, percent-done > 10 s
- https://web.dev/articles/cls — reserve space; unexpected layout shifts from late-arriving content
- https://tanstack.com/query/latest/docs/framework/react/guides/background-fetching-indicators — `isFetching` background-refresh indicator vs initial loading state
- https://tanstack.com/query/latest/docs/framework/react/guides/optimistic-updates — optimistic UI with rollback on failure
- https://react.dev/reference/react/Component — error boundaries catch rendering errors; not event handlers or asynchronous code
