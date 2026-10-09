---
id: frontend-state-concurrent-optimistic-updates
domain: frontend
category: state
applies_to: [general, react, android]
confidence: verified
sources:
  - https://tanstack.com/query/latest/docs/framework/react/guides/optimistic-updates
  - https://tkdodo.eu/blog/concurrent-optimistic-updates-in-react-query
last_verified: 2026-09-28
related: [frontend-state-client-vs-server-state, frontend-data-fetching-race-conditions, frontend-data-fetching-async-ui-states, mobile-offline-offline-first-sync]
---

# Several Optimistic Updates In Flight Against One Server-Owned Object

## When this applies

A view model or store applies optimistic updates to one server-owned object
(a preferences record, a profile, a settings row) through per-field PATCH calls
the UI can fire concurrently — several switches, each launching its own request
— and the naive shape is "snapshot previous → replace the whole object with
the response on success → restore the snapshot on failure". Web or mobile; the
hazard is in the state model, not the platform.

## Do this

1. **Keep two things, not one:** the last server-confirmed snapshot and an
   ordered list of pending patches. Render `confirmed` with the pending patches
   folded on top, in order.
2. **Serialize the requests** through a FIFO queue or mutex so each response
   is authoritative for everything sent before it.
3. **On success set `confirmed = response`** (the server's full object is now the
   truth for all earlier patches) **and remove that patch**; **on failure remove
   only that patch** and surface the error — other pending patches stay visible.
4. **With a query cache (TanStack Query / SWR):** cancel outgoing refetches in
   `onMutate` and invalidate in `onSettled` only when no other mutation is in
   flight (`queryClient.isMutating() === 1`), so an early refetch does not
   revert a later mutation's optimistic value.
5. **Write the overlap test before the fix:** two toggles, response gates you
   release by hand (a `CompletableDeferred` / deferred promise per call), one
   succeeds and one fails, assert the surviving state of both fields. Per-field
   tests never exercise the overlap, so keep them and add this one.

| Situation | Do |
|-----------|----|
| One field toggled repeatedly | Serialize; the last response wins and carries every earlier toggle |
| Different fields patched concurrently | Overlay: each success confirms all earlier fields, each failure drops only its own patch |
| Whole-object PUT instead of PATCH | Build the PUT body from `confirmed` plus every pending patch, still serialized — a body built from the rendered state alone re-sends a failed patch |

## Edge cases

| Case | Then |
|------|------|
| The server response includes changes made elsewhere (another device) | `confirmed = response` absorbs them; pending patches still render on top until their own response |
| A patch fails after a later one succeeded | Drop the failed patch; the later success already confirmed the server truth for its own field, so the rendered state converges without a rollback |
| The device is offline | Route through an outbox with conflict rules ([mobile-offline-offline-first-sync]) rather than holding patches in memory |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Restore a per-call `previous` snapshot on failure | Remove only that call's patch from the pending list | The snapshot predates other in-flight patches and reverts them |
| Replace the whole object with each response as it arrives | Serialize the calls, then `confirmed = response` | An earlier call's late response overwrites a later call's optimistic field |
| Invalidate the query on every `onSettled` | Invalidate only when `isMutating() === 1` | The first invalidation's refetch lands while another mutation is in flight and reverts its optimistic value |

## Sources

- https://tanstack.com/query/latest/docs/framework/react/guides/optimistic-updates — `onMutate` cancels outgoing refetches "so they don't overwrite our optimistic update"; "there might be multiple mutations running at the same time"; links the concurrent-updates guide below as further reading
- https://tkdodo.eu/blog/concurrent-optimistic-updates-in-react-query — TanStack Query maintainer: "If that refetch is faster than our second mutation, our UI will revert and we'll see the dreaded window of inconsistency again"; remedy `if (queryClient.isMutating() === 1) { queryClient.invalidateQueries(...) }` in `onSettled`
- Field evidence 2026-09-27 (linkly-calendar Android, `SettingsViewModel.patchPreference`, Kotlin coroutines): a review lens on execution-environment reality found per-call snapshot + whole-object replace; four overlap tests with `CompletableDeferred` response gates and `runCurrent` were red on that version and green after moving to confirmed snapshot + `pendingPatches` + `Mutex`; the auditor reproduced the red independently; suite 131 passed, 0 failed
