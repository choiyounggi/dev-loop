---
id: frontend-rendering-rerender-and-memoization
domain: frontend
category: rendering
applies_to: [react]
confidence: verified
sources:
  - https://react.dev/reference/react/memo
  - https://react.dev/reference/react/useMemo
  - https://react.dev/reference/react/useContext
  - https://react.dev/learn/react-developer-tools
last_verified: 2026-07-10
related: [frontend-state-derived-state, frontend-rendering-long-lists]
---

# Deciding What to Memoize When Interaction Is Sluggish

## When this applies

The UI is measurably sluggish on an interaction (typing lag, slow toggle), or you
are deciding whether to add `memo` / `useMemo` / `useCallback` to code you are
writing or reviewing.

## Do this

1. Measure first: record the interaction in the React DevTools Profiler. Identify
   which components re-rendered and why (the profiler shows the triggering
   state/props change). Memoization decisions made without this recording are
   guesses.
2. Fix the measured cause — apply the first matching row (ordered by preference:
   structural fixes before memoization):

| Profiler finding | Fix |
|------------------|-----|
| State lives in a high component but only a small subtree consumes it; unrelated siblings re-render | Move the state down into the consuming component — no memoization needed |
| An expensive subtree re-renders although its props are value-equal | Wrap that component in `memo(Component)` |
| A `memo` child still re-renders — a prop gets a new object/array/function identity every render | Stabilize the identity: `useMemo` for objects/arrays, `useCallback` for functions, module-level constant for values that never change |
| All consumers of a context re-render whenever the provider's parent renders | Memoize the context value: `useMemo(() => ({...}), [deps])` (functions inside via `useCallback`) |
| One calculation inside render is slow (measured, e.g. `console.time`) | Wrap the calculation in `useMemo` with its inputs as dependencies |
| A long list dominates the flame graph | Virtualize — [frontend-rendering-long-lists] |

3. Re-record the same interaction after the fix and confirm the wasted re-renders
   are gone. Keep the memoization only if the recording improved.

## Edge cases

| Case | Then |
|------|------|
| `memo` component re-renders despite stable props | It also subscribes to changed context or has its own state change — `memo` only skips parent-driven renders; check the profiler's "why did this render" |
| Prop is JSX (`children`) | Passing children through from the parent keeps their identity stable when the wrapper's own state changes — restructure so the stateful wrapper receives `children` instead of rendering the subtree itself |
| Render is fast but the interaction still lags | The cost is outside render (effects, layout thrash, network) — profile with the browser Performance panel, not more memoization |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Wrap every component/value in `memo`/`useMemo`/`useCallback` preemptively | Profile, memoize only the measured offenders | Unmeasured memoization adds comparison/cache cost and dependency-array surface for stale-value bugs, with no verified gain |
| Fix a slow render by memoizing a component whose state sits too high | Move the state down to the consumer | Structural fix removes the re-render entirely; memoization only masks it |
| Rely on `useMemo` for correctness (value must be stable or code breaks) | Fix the design so correctness never depends on caching | React may discard memoized values; `useMemo` is a performance hint, not a guarantee |

## Sources

- https://react.dev/reference/react/memo — when memo pays off; profiler-driven use; not a guarantee
- https://react.dev/reference/react/useMemo — expensive-calculation and memoized-child use cases; measuring with console.time
- https://react.dev/reference/react/useContext — "Optimizing re-renders when passing objects and functions" (memoized context value)
- https://react.dev/learn/react-developer-tools — Components and Profiler panels
