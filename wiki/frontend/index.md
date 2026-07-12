# frontend — Domain Index

Route here for: web UI code — component state placement, effect usage, rendering
performance, component structure/composition, in-UI data fetching, async
loading/error/empty UI states, bundle/asset load performance, form validation UX,
XSS-safe output, client-side auth token handling, interactive-element accessibility.

Match your situation to a "load when" line; load only matching pages.

## state

| Page | Load when |
|------|-----------|
| [client-vs-server-state](state/client-vs-server-state.md) | Deciding where/how to store a piece of UI data (fetched entities vs ephemeral UI vs theme/session vs filters/tabs); untangling a global store that has grown unmanageable |
| [derived-state](state/derived-state.md) | About to store a value computable from existing state/props (filtered list, count, selected object); two copies of the same fact have drifted; tempted to set state from an effect |
| [effects-usage](state/effects-usage.md) | Writing or reviewing a useEffect (or framework-equivalent watcher); an effect chain causes render loops, flicker, or double-firing; deciding where non-render logic belongs (event handler vs effect vs module scope) |

## structure

| Page | Load when |
|------|-----------|
| [component-composition](structure/component-composition.md) | A component's props keep growing (boolean flags, passthrough props); the same data threads through layers that never use it; a component exceeds one responsibility; deciding how to make a component reusable (slots/children vs config props, variant props, custom hooks) |

## rendering

| Page | Load when |
|------|-----------|
| [rerender-and-memoization](rendering/rerender-and-memoization.md) | UI is measurably sluggish on an interaction; deciding whether to add memo/useMemo/useCallback to new or reviewed code |
| [long-lists](rendering/long-lists.md) | Rendering a list that can reach hundreds+ rows (feed, table, dropdown, log view); list scroll jank or slow mount; choosing row keys for reorderable/filterable lists |

## data-fetching

| Page | Load when |
|------|-----------|
| [race-conditions](data-fetching/race-conditions.md) | Repeated fetches with changing params can overlap (search-as-you-type, rapid tab/filter switches); UI intermittently shows results for a previous input; mutations race refetches |
| [async-ui-states](data-fetching/async-ui-states.md) | Building any view backed by async data; users see blank screens, eternal spinners, or dead-end errors; reviewing loading/error/empty handling in UI code; deciding on skeletons vs spinners, retry affordances, empty states, background-refresh indication, or optimistic updates |
| [infinite-scroll](data-fetching/infinite-scroll.md) | Implementing infinite scroll or a load-more feed; an existing feed loses scroll position on back-navigation, duplicates/skips items, or spams page requests; choosing between infinite scroll and a load-more button |

## performance

| Page | Load when |
|------|-----------|
| [bundle-and-assets](performance/bundle-and-assets.md) | First load is slow; LCP/CLS scores are poor; the bundle keeps growing; adding a heavy dependency, image, or font to a page; deciding what to code-split or lazy-load |

## forms

| Page | Load when |
|------|-----------|
| [validation-timing](forms/validation-timing.md) | Implementing form validation and deciding when to validate / when errors show; reworking a form abandoned over premature, late, or unexplained errors; mapping server validation errors to fields |

## security

| Page | Load when |
|------|-----------|
| [xss-safe-rendering](security/xss-safe-rendering.md) | Rendering any value your team did not author (user input, CMS/rich text, URL params, third-party API fields); touching raw-HTML sinks, user URLs in href/src, or runtime-built DOM |

## auth

| Page | Load when |
|------|-----------|
| [token-handling-client-side](auth/token-handling-client-side.md) | A browser app must store or send auth credentials (JWT access/refresh tokens or session ids); reviewing where tokens live client-side; implementing silent refresh or logout; deciding whether the auth transport needs CSRF defense |

## accessibility

| Page | Load when |
|------|-----------|
| [interactive-elements](accessibility/interactive-elements.md) | Building/reviewing any clickable or keyboard-operable UI (buttons, links, toggles, menus, dialogs, custom widgets); asked to make a div clickable; fixing focus/tab order |
