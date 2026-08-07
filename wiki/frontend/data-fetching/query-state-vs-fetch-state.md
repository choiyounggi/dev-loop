---
id: frontend-data-fetching-query-state-vs-fetch-state
domain: frontend
category: data-fetching
applies_to: [react, tanstack-query, general]
confidence: verified
sources:
  - https://tanstack.com/query/latest/docs/framework/react/guides/queries
  - https://tanstack.com/query/latest/docs/framework/react/reference/useQuery
  - https://tanstack.com/query/latest/docs/framework/react/guides/disabling-queries
  - https://tanstack.com/query/latest/docs/framework/react/guides/network-mode
last_verified: 2026-08-07
related:
  [
    frontend-data-fetching-async-ui-states,
    frontend-state-client-vs-server-state,
    frontend-data-fetching-race-conditions,
    testing-mocking-what-to-mock,
  ]
---

# A Server-State Query That Has No Data and Is Not Loading

## When this applies

You are defining what a component receives from a server-state cache (TanStack
Query and equivalents) and are about to treat `data === undefined` as "loading".
Also when a view shows a permanent spinner with no error and no retry, or the
query it renders can be disabled (`enabled: false`, `skipToken`) or paused by
the network mode.

Designing the loading / error / empty / data renderings themselves →
[frontend-data-fetching-async-ui-states].

## Do this

1. **Take two independent inputs, not one.** The cache exposes them as separate
   fields for this reason: "The `status` gives information about the `data`: Do
   we have any or not? The `fetchStatus` gives information about the `queryFn`:
   Is it running or not?" — and "all combinations for `status` and `fetchStatus`
   [are] possible". A component prop of `data | undefined` collapses both axes
   into one bit and cannot recover them.

2. **Branch on the combination, and give every cell a rendering:**

| status    | fetchStatus | What it means                                                                                                                                                 | Render                                                                                |
| --------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| `pending` | `fetching`  | First fetch in flight — this is `isLoading`, defined as "`isFetching && isPending`"                                                                           | Skeleton                                                                              |
| `pending` | `idle`      | Disabled/lazy query: "status === 'pending' and fetchStatus === 'idle'" with `enabled: false`                                                                  | The pre-request state — the prompt, the disabled form, the "select a row" placeholder |
| `pending` | `paused`    | Wanted to fetch, has no connection: "state: 'pending', but fetchStatus: 'paused' if they are mounting for the first time, and you have no network connection" | Offline notice plus a retry affordance                                                |
| `error`   | any         | The attempt failed                                                                                                                                            | Error message plus retry ([frontend-data-fetching-async-ui-states])                   |
| `success` | `fetching`  | Background refresh over existing data                                                                                                                         | The data, plus a subtle refresh indicator                                             |
| `success` | `idle`      | Settled                                                                                                                                                       | The data (or the empty state when it is an empty collection)                          |

3. **Pass the discriminator down.** Give the presentational component either the
   two fields or an explicit union (`{kind: 'idle' | 'loading' | 'paused' |
'error' | 'ready', …}`) built at the boundary that holds the query. The union
   makes every unhandled state a type error instead of a blank screen.

4. **Use `isLoading` for spinners and `isPending` for "no data yet".** The docs
   state the split directly: lazy queries "will be in `status: 'pending'` right
   from the start because `pending` means that there is no data yet … you likely
   cannot use this flag to show a loading spinner".

5. **Cover the disabled and paused cells in tests explicitly.** A test that mocks
   the query hook supplies the flags by hand and therefore only ever produces
   combinations its author already thought of — so the combination that ships the
   bug is the one the suite never constructs. Write one case per row of the step-2
   table, taking the flag values from that table rather than from the component
   ([testing-mocking-what-to-mock]).

## Edge cases

| Case                                                                   | Then                                                                                                                                                                                                     |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| The query has `initialData` or `placeholderData`                       | It starts at `status: 'success'`, so the pending rows never render — assert which data the user is seeing before treating success as authoritative                                                       |
| A disabled query has cached data from an earlier mount                 | It initializes as "status === 'success' or isSuccess" rather than pending; the idle-pre-request rendering does not apply                                                                                 |
| The component must trigger the fetch itself                            | Keep `enabled: false` rather than `skipToken`: "`refetch` from `useQuery` will not work with `skipToken`. Calling `refetch()` on a query that uses `skipToken` will result in a `Missing queryFn` error" |
| `select` narrows the data and returns `undefined` for a valid response | That is `success` with `data === undefined` — the sixth combination the one-bit contract also loses; assert on `status`, not on the value                                                                |
| The paused state is unreachable because `networkMode: 'always'` is set | Drop the paused row for that query and state the mode in the component's contract, so a later mode change re-opens the row deliberately                                                                  |
| Several queries feed one view                                          | Combine on the axes, not the values: pending if any is pending, paused if any is paused — a merged `data === undefined` cannot distinguish them                                                          |

## Instead of

| If you are about to                                                                              | Do this instead                                                                         | Why                                                                                                                                                                              |
| ------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Type the child's prop as `data \| undefined` and read `undefined` as "loading"                   | Pass `status` and `fetchStatus`, or an explicit state union built at the query boundary | A disabled or paused query is `pending` with `data === undefined`, `isLoading === false` and `isError === false`, so the child renders a spinner that no fetch will ever resolve |
| Show the spinner on `isPending`                                                                  | Show it on `isLoading` (`isPending && isFetching`) and render the idle case separately  | A lazy query is `pending` from the first render, so `isPending` puts a spinner on a query that was never requested                                                               |
| Add a timeout that turns a long spinner into an error                                            | Render the `pending`/`idle` and `pending`/`paused` cells                                | The spinner is not slow, it is terminal — a timeout converts a missing state into a wrong one                                                                                    |
| Test the component by mocking the hook with `{data: undefined, isLoading: true}` and `{data: X}` | Drive one case per row of the step-2 table                                              | Hand-written mocks reproduce the author's model of the states, so the combination that causes the bug is the one never constructed                                               |

## Sources

- https://tanstack.com/query/latest/docs/framework/react/guides/queries — the `status` values (`pending` "The query has no data yet", `error`, `success`) and `fetchStatus` values (`fetching`, `paused` "The query wanted to fetch, but it is paused", `idle`); "Background refetches and stale-while-revalidate logic make all combinations for `status` and `fetchStatus` possible"; "The `status` gives information about the `data` … The `fetchStatus` gives information about the `queryFn`"
- https://tanstack.com/query/latest/docs/framework/react/reference/useQuery — `isLoading` "Is `true` whenever the first fetch for a query is in-flight. Is the same as `isFetching && isPending`"; `data` "Defaults to `undefined`"; `status` is `pending` "if there's no cached data and no query attempt was finished yet"
- https://tanstack.com/query/latest/docs/framework/react/guides/disabling-queries — a disabled query with no cached data is "status === 'pending' and fetchStatus === 'idle'"; "Lazy queries will be in `status: 'pending'` right from the start because `pending` means that there is no data yet … you likely cannot use this flag to show a loading spinner"; the `skipToken`/`refetch` incompatibility
- https://tanstack.com/query/latest/docs/framework/react/guides/network-mode — "Queries can be in `state: 'pending'`, but `fetchStatus: 'paused'` if they are mounting for the first time, and you have no network connection"; "it might not be enough to check for `pending` state to show a loading spinner"
- Source verification 2026-08-07 (`@tanstack/query-core@5.100.14`, `build/modern/queryObserver.js`): line 308 `const isPending = status === "pending"`, line 310 `const isLoading = isPending && isFetching`, line 332 `isPaused: newState.fetchStatus === "paused"` — the shipped derivation matches the reference, so `pending` + non-`fetching` yields `isLoading === false` with `data === undefined`
