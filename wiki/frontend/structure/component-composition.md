---
id: frontend-structure-component-composition
domain: frontend
category: structure
applies_to: [react, general]
confidence: verified
sources:
  - https://react.dev/learn/passing-data-deeply-with-context
  - https://react.dev/learn/passing-props-to-a-component
  - https://react.dev/learn/reusing-logic-with-custom-hooks
  - https://react.dev/reference/rules/rules-of-hooks
last_verified: 2026-07-10
related: [frontend-rendering-rerender-and-memoization, frontend-state-client-vs-server-state]
---

# Structuring Components When Props Multiply or Data Threads Through Layers

## When this applies

A component's props keep growing (boolean flags, passthrough props), the same data
threads through many layers that never use it, a component has exceeded one
responsibility, or you are deciding how to make a component reusable.

## Do this

Route the structural pressure by this table:

| Situation | Do |
|-----------|----|
| Data is passed through intermediate layers that never read it (prop drilling) | Restructure with children/slot composition first: the intermediate components accept `children` (or named slot props), and the component that owns the data renders the consumer directly inside them — provider → consumer with no relay |
| The value is truly app-wide and cross-cutting (theme, locale, current user) | Context — accepting that every consumer re-renders when it changes; pass a memoized value per the context row of [frontend-rendering-rerender-and-memoization] |
| Per-feature server data is needed by distant components | Each consumer reads the server-state cache by key instead of the data being threaded down — see [frontend-state-client-vs-server-state] |
| Two or more mutually exclusive boolean props (`isPrimary`, `isDanger`, `isGhost`) | One `variant` union prop (`variant="primary" \| "danger" \| "ghost"`) — impossible combinations stop being representable |
| Props that only configure a slot's content (icon, header, footer renderers, flags like `showIcon`) | Accept elements/`children` for that slot; the caller composes the content, the component positions it |
| Stateful logic repeated across components | Extract a custom hook: name it `use*`, call it only at the top level of a component or another hook, never conditionally. A hook that returns JSX is a component in disguise — make it a component |

Split criterion: a component splits when its parts change for different reasons or
one part re-renders/fetches independently of the rest — not by line count alone.

Container/presentational, modern form: put the logic in custom hooks and the markup
in components that take data as props. Components testable by passing props need no
mocked network or store (behavior-focused testing guidance: `wiki/testing/`).

## Edge cases

| Case | Then |
|------|------|
| A slot's content needs data owned by the enclosing component | Accept a function for that slot (`renderRow={(item) => …}`) — plain elements stay the default when the caller already has everything it needs |
| Variants share most markup but differ in behavior | Build separate variant components that compose shared extracted parts and hooks; the shared pieces live once |
| The context value changes on rapid interaction (per keystroke) | It is not cross-cutting configuration — keep it in local state near the consumers; context re-renders every consumer on each change |
| Two components need the same custom hook's state, not just its logic | Custom hooks share logic, not state — each call gets independent state. Lift the state to a common parent (or the relevant store) and pass it down |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Reach for `cloneElement` or a render-prop pyramid on a simple wrapper | `children` composition | Explicit children keep the data flow visible; injected-prop contracts are implicit and break silently |
| Grow one God component with mode flags (`isAdmin`, `isCompact`, `isModal`) | Variant components sharing extracted hooks and parts | A change to one mode stops rippling through every other mode's branches |
| Add another layer of passthrough props | Children/slot composition at the layer that owns the data | Intermediates stop depending on data they never use, and their props stop churning |
| Jump straight to context for one feature's data | Children composition first; context only for app-wide values | Context couples every consumer to the provider and re-renders them all on change |

## Sources

- https://react.dev/learn/passing-data-deeply-with-context — try props and children composition before context; theme/current-user as context use cases
- https://react.dev/learn/passing-props-to-a-component — passing JSX as `children`; slot-style wrapping
- https://react.dev/learn/reusing-logic-with-custom-hooks — extract repeated stateful logic; `use*` naming; hooks share logic, not state
- https://react.dev/reference/rules/rules-of-hooks — top-level calls only, never conditional
