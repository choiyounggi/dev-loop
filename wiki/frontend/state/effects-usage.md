---
id: frontend-state-effects-usage
domain: frontend
category: state
applies_to: [react, general]
confidence: verified
sources:
  - https://react.dev/learn/you-might-not-need-an-effect
  - https://react.dev/learn/synchronizing-with-effects
  - https://react.dev/learn/removing-effect-dependencies
  - https://react.dev/reference/react/useRef
  - https://github.com/darkroomengineering/lenis
last_verified: 2026-09-08
related: [frontend-state-derived-state, frontend-state-client-vs-server-state, frontend-data-fetching-race-conditions]
---

# Deciding Whether Logic Belongs in an Effect

## When this applies

You are writing or reviewing a `useEffect` (or a framework equivalent: watcher,
lifecycle hook), an effect chain is causing render loops / flicker / double-firing,
or you are deciding where a piece of non-render logic belongs.

## Do this

An effect exists to synchronize the component with an **external system**: DOM APIs,
subscriptions, timers, non-React widgets, analytics fired because a view appeared.
Before writing one, route the logic by this table:

| The logic is | Put it in |
|--------------|-----------|
| A value computable from current props/state | Compute it during render — no state, no effect; see [frontend-state-derived-state] |
| A response to a specific user action (submit, buy, delete) | That action's event handler. An effect watching a state flag cannot tell which interaction set the flag and re-fires whenever any dependency changes for unrelated reasons |
| Resetting a component's state when a prop changes | Pass `key={thatProp}` so React remounts with fresh state; for adjusting one value, compare the previous prop during render — not an effect that sets state after a stale frame |
| Data fetching for display | The server-state cache / router loader — see [frontend-state-client-vs-server-state]. A hand-rolled fetch effect requires cleanup plus a race guard — [frontend-data-fetching-race-conditions] |
| App-initialization that runs once per app load (SDK init, environment check) | Module scope or the app entry point — a mount effect runs once per component instance, and twice in dev |
| Synchronizing with an external system (the cases in the first paragraph) | An effect — apply rules 1–3 below |

Rules for the effects that remain:

1. Return a cleanup function that undoes the setup: subscribe → unsubscribe,
   `setInterval` → `clearInterval`, `AbortController` → `abort()`, widget create →
   destroy. Setup without teardown leaks and duplicates work on remount.
2. The dependency array lists every reactive value (props, state, values derived
   from them) the effect reads. When the linter flags a missing dependency, change
   the code so the array is honest — move the function inside the effect, wrap it
   in `useCallback`, or split one effect into two independent ones. A suppressed
   dependency is a stale-closure bug scheduled for later.
3. React StrictMode remounts components once in development (setup → cleanup →
   setup) specifically to expose missing cleanup. When the double run breaks
   something, write the cleanup that makes setup+teardown symmetric.

## Edge cases

| Case | Then |
|------|------|
| Effect A sets state that triggers effect B, which sets state… (chain causing extra renders/flicker) | Collapse the chain: compute what can be computed during render, and set the rest together in the single event handler that started the sequence |
| Analytics "view" event fires twice in development | Expected under StrictMode dev remounting; production mounts once. Keep the effect as-is |
| Effect must read a value without re-running when it changes | Split the effect so the frequently-changing value lives in its own effect, or move the logic into the event handler that owns the change |
| The external subscription is a data store | Subscribing in a raw effect is replaceable with `useSyncExternalStore`, which handles the subscribe/read contract |
| The effect starts/stops an imperative loop (`requestAnimationFrame`, a canvas/WebGL draw loop) and also reads a value that changes identity without changing anything the loop needs (a theme/colors hook, or any hook whose return value is derived by watching `<html>`/`<body>` attribute or class mutations) | Key the setup/teardown effect only on the values that actually start or stop the loop. Mirror the frequently-changing value into a ref via its own tiny effect (`useEffect(() => { colorsRef.current = colors }, [colors])`) and read `colorsRef.current` inside the frame callback — the loop then survives identity churn instead of tearing down and re-seeding |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write an effect watching a `submitted` flag to run submit logic | Run the logic in the submit handler and delete the flag | The flag erases which interaction happened and the effect re-fires on unrelated dependency changes |
| Add `eslint-disable` on `exhaustive-deps` | Restructure: move the function into the effect, `useCallback` it, or split the effect | Every suppressed dependency reads stale values on later renders |
| Guard an effect with a `didRun` ref to survive StrictMode | Write the cleanup that undoes the setup | The double-invoke exists to expose missing cleanup; the ref also masks real remount bugs in production |
| Reset state via an effect that watches a prop | Remount with `key={prop}` | The effect version renders one frame of stale state, then re-renders |
| Key a canvas/animation setup effect on every hook value the frame callback reads (`useEffect(setup, [reduced, colors])`) | Key it only on the values that start/stop the loop; read the rest through a ref updated by its own effect | A class-toggling scroll library (Lenis adds/removes `lenis-scrolling`/`lenis-stopped` on its root element on every scroll start/stop) or any hook that derives state from DOM mutations returns a fresh object each time even when the underlying values are identical, so the whole effect — and whatever expensive setup it runs — re-fires on every toggle |

## Sources

- https://react.dev/learn/you-might-not-need-an-effect — compute in render, event-handler logic, key-based resets, effect chains, app init, fetching
- https://react.dev/learn/synchronizing-with-effects — external systems, cleanup contract, StrictMode dev remount
- https://react.dev/learn/removing-effect-dependencies — honest dependency arrays; change the code, never suppress the linter; "Object and function dependencies can make your Effect re-synchronize more often than you need"
- https://react.dev/reference/react/useRef — "Changing a ref does not trigger a re-render"; the mechanism for reading a latest value inside a callback (including an animation-frame loop) without depending on it
- https://github.com/darkroomengineering/lenis — `packages/core/src/lenis.ts` `updateClassName()` adds/removes `lenis-scrolling`/`lenis-stopped` on the root element (`<html>` by default) from the scroll start/stop lifecycle (read 2026-09-08)
- Field reproduction 2026-09 (a React canvas hero keyed on `[reduced, colors]` from a theme hook watching `<html>` classes): `seedNodes` calls went 2 → 3 → 4 across one `lenis-scrolling` add/remove; holding colors in a ref and keying the lifecycle effect on `[reduced]` alone stopped the re-seeding, pinned by a regression test
