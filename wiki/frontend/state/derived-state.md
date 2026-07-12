---
id: frontend-state-derived-state
domain: frontend
category: state
applies_to: [react, general]
confidence: verified
sources:
  - https://react.dev/learn/you-might-not-need-an-effect
  - https://react.dev/learn/choosing-the-state-structure
  - https://react.dev/reference/react/useMemo
last_verified: 2026-07-10
related: [frontend-state-client-vs-server-state, frontend-rendering-rerender-and-memoization]
---

# Values Computable from Existing State or Props

## When this applies

You are about to create a state variable whose value can be computed from state or
props you already have (filtered list, count, full name, selected-item object), or
you are debugging two copies of the same fact that have drifted apart.

## Do this

1. Compute the value during render as a plain expression — no state variable, no
   effect:
   `const visible = items.filter(matches(filter));`
   `const selectedItem = items.find(i => i.id === selectedId);`
2. The moment the same fact lives in two places, you own a synchronization bug:
   every code path that updates one place must remember the other. Keep one
   canonical value and derive the rest.
3. For selections, store the identity (`selectedId`), derive the object. A stored
   object copy goes stale when the list item updates or disappears.
4. Memoize the computation (`useMemo`) only when you have measured it as expensive
   (profiler or timing) or its result feeds a memoized child / dependency array —
   see [frontend-rendering-rerender-and-memoization]. Memoization changes cost,
   not correctness.

## Edge cases

Cases that look derived but need different handling:

| Case | Then |
|------|------|
| Computation is measured-expensive (profiled, perceptible lag) | Still compute — wrap in `useMemo` with the inputs as dependencies; do not move it to state + effect |
| Editable draft initialized from a prop (edit form seeded by an entity) | It is real state: initialize once from the prop (`useState(entity.name)`) and pass a `key={entity.id}` so the component remounts (resetting the draft) when the entity changes |
| Value derived from async/server data (needs a fetch to compute) | It is server state — put it in the server-state cache and transform at read time; see [frontend-state-client-vs-server-state] |
| Derived value must persist across the inputs disappearing (last non-empty result) | It is its own state; set it at the event that produces it, not in an effect watching the inputs |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write a `useEffect` that sets state from other state/props | Compute the value in render | The effect version renders a stale frame first, then re-renders; it is an extra copy that can drift |
| Store `filteredItems` next to `items` + `filter` | Derive `filteredItems` in render | Any update path that touches `items` but forgets `filteredItems` ships a drift bug |
| Store the full selected object in state | Store `selectedId`, derive the object with `find` | The copy goes stale when the source list changes |

## Sources

- https://react.dev/learn/you-might-not-need-an-effect — calculate during render instead of effect-set state
- https://react.dev/learn/choosing-the-state-structure — avoid redundant state; avoid duplication (selectedId pattern)
- https://react.dev/reference/react/useMemo — cache expensive calculations; only as a performance optimization
