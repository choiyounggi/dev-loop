# frontend — Domain Index

Route here for: web UI code — component state placement, effect usage, rendering
performance, component structure/composition, in-UI data fetching, async
loading/error/empty UI states, bundle/asset load performance, form validation UX,
XSS-safe output, client-side auth token handling, interactive-element accessibility,
agent-facing tool surfaces (WebMCP tool registration), visual design decisions
(color/typography/layout/motion styling, canvas effect layers, responsive
layout across viewport sizes), and visual-design deliverables (screen/UI mockups,
redesigns, design explorations, landing/print drafts — routed through the design
canvas skill).

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
| [query-state-vs-fetch-state](data-fetching/query-state-vs-fetch-state.md) | Defining what a component receives from a server-state cache (TanStack Query and equivalents) and about to treat `data === undefined` as "loading"; a view shows a permanent spinner with no error and no retry; the query can be disabled (`enabled: false`, `skipToken`) or paused by the network mode; deciding what the presentational component's state prop should be |
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

## agent-interfaces

| Page | Load when |
|------|-----------|
| [agent-facing-tool-surfaces](agent-interfaces/agent-facing-tool-surfaces.md) | Making a web app usable by AI agents ("agent-ready", "add WebMCP tools", assistant-driven ordering/search/booking); building a form or action flow where agent consumption is anticipated; reviewing browser-native agent tool registration |

## accessibility

| Page | Load when |
|------|-----------|
| [interactive-elements](accessibility/interactive-elements.md) | Building/reviewing any clickable or keyboard-operable UI (buttons, links, toggles, menus, dialogs, custom widgets); asked to make a div clickable; fixing focus/tab order; implementing a dropdown/tooltip/toast overlay or disabling background content behind an overlay |

## design

| Page | Load when |
|------|-----------|
| [design-canvas-workflow](design/design-canvas-workflow.md) | ANY task whose deliverable is a visual design the user will react to — a new screen/UI mockup, redesign proposal, design variants or exploration, landing/marketing page draft, mobile prototype, poster/print/report layout — or a new screen is about to be built with no agreed design spec (mandatory routing: when the session lists the `design` skill, the design phase goes through it, never a hand-rolled mockup file; the page carries the no-skill fallback) |
| [anti-slop-visual-design](design/anti-slop-visual-design.md) | Styling or restyling web UI without a design spec; picking the theme/aesthetic direction for a new screen (the committed non-generic direction is the default, not an upgrade); output looks "AI-generated" or template-like; choosing colors, fonts, page structure, or motion for new UI; reviewing a UI diff for template tells; writing reusable design guidance for an LLM |
| [responsive-layout](design/responsive-layout.md) | Building or reviewing UI that must work across viewport sizes (phone → desktop); choosing breakpoints, touch-target sizes, fluid type, or responsive images; a layout overflows horizontally or breaks on mobile; fixing a zoom/reflow accessibility failure (WCAG 1.4.4/1.4.10/2.5.8) |
| [html-in-canvas](design/html-in-canvas.md) | Wanting shader/3D/canvas-composited effects on real interactive HTML (forms, buttons, sections); about to hand-draw UI widgets inside a canvas with manual hit-testing; adding a canvas effect layer to an existing page |
