# frontend — Domain Index

Route here for: web UI code — component state placement, effect usage, rendering
performance, component structure/composition, in-UI data fetching, async
loading/error/empty UI states, bundle/asset load performance, form validation UX,
XSS-safe output, client-side auth token handling, interactive-element accessibility,
any new or changed user action (this wiki's development standard adds a WebMCP tool per action), visual design decisions
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
| [effects-usage](state/effects-usage.md) | Writing or reviewing a useEffect (or framework-equivalent watcher); an effect chain causes render loops, flicker, or double-firing; deciding where non-render logic belongs (event handler vs effect vs module scope); a canvas/WebGL/rAF setup-teardown effect is keyed on an object a hook returns (theme, colors, viewport) that gets a fresh identity on every DOM mutation a scroll/animation library makes (e.g. Lenis toggling `<html>` classes on scroll start/stop), re-running setup though nothing the loop needs changed |

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
| [dropzone-copy-without-drop-handlers](forms/dropzone-copy-without-drop-handlers.md) | Building or restyling a file-upload control whose `<input type=file>` is visually hidden and whose label/wrapper is styled as a dropzone; deciding whether the copy may say "drag and drop"; adding real drag-and-drop to such a control; reviewing a restyle diff for an advertised affordance with no `dragover`/`drop` handlers |

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
| [agent-facing-tool-surfaces](agent-interfaces/agent-facing-tool-surfaces.md) | Adding or changing any user action in a web UI (form, button flow, search/filter, state change) under this wiki's development standard of an additive WebMCP tool per action (owner policy, log.md 2026-09-28); making a web app usable by AI agents ("agent-ready", "add WebMCP tools", assistant-driven ordering/search/booking); fixing a bug in a handler a tool wraps; targeting the ChatGPT desktop browser's site tools; verifying tool registration in Chrome DevTools; reviewing browser-native agent tool registration |

## accessibility

| Page | Load when |
|------|-----------|
| [interactive-elements](accessibility/interactive-elements.md) | Building/reviewing any clickable or keyboard-operable UI (buttons, links, toggles, menus, dialogs, custom widgets); asked to make a div clickable; fixing focus/tab order; implementing a dropdown/tooltip/toast overlay or disabling background content behind an overlay |

## design

| Page | Load when |
|------|-----------|
| [design-canvas-workflow](design/design-canvas-workflow.md) | ANY task whose deliverable is a visual design the user will react to — a new screen/UI mockup, redesign proposal, design variants or exploration, landing/marketing page draft, mobile prototype, poster/print/report layout — or a new screen is about to be built with no agreed design spec (mandatory routing: when the session lists the `design` skill, the design phase goes through it, never a hand-rolled mockup file; the page carries the no-skill fallback) |
| [anti-slop-visual-design](design/anti-slop-visual-design.md) | Styling or restyling web UI without a design spec; picking the theme/aesthetic direction for a new screen (the committed non-generic direction is the default, not an upgrade); output looks "AI-generated" or template-like; choosing colors, fonts, page structure, or motion for new UI; reviewing a UI diff for template tells; writing reusable design guidance for an LLM; theming browser-default surfaces (selection, caret, scrollbar, focus ring, tabular numerals) on a brand page |
| [design-system-lint-gate-for-agents](design/design-system-lint-gate-for-agents.md) | An LLM agent writes or edits UI in a Tailwind v4 project (React/Vue/Svelte) or a plain-CSS project with theme tokens and shared components, and the design-system rules exist only as prose in AGENTS.md or a wiki; agent-built screens drift (raw colors like `bg-pink-500`, arbitrary values like `p-[13px]`, `className` overrides on shared components); choosing a done-gate for agent UI work; adding a design-system lint to a codebase that already has violations (warn + `--max-warnings` cap or ESLint bulk suppressions); the same gate for plain CSS custom properties (stylelint `declaration-strict-value`); "match the existing design" keeps changing untouched parts; verifying theming with a theme-swap check after lint is clean; lint-clean UI that still reads generic |
| [slop-detector-gate](design/slop-detector-gate.md) | Encoding the anti-slop tells tables or the local hallmark skill's 58 slop gates as a mechanical check instead of relying on an agent re-reading prose; the design-system lint gate is clean but the UI still reads generic; deciding which tells a lint rule or Impeccable can catch deterministically versus which stay LLM judgment; setting up a pre-merge check for gradient text, `transition-all`, uniform `hover:scale-105`, emoji-as-icon, or an Inter-only font stack |
| [product-ui-vs-brand-surface](design/product-ui-vs-brand-surface.md) | Building or restyling an app/task surface — dashboard, admin, settings, editor, data table, authenticated tool — rather than a landing or marketing page; deciding which of Persuade / Operate / Read / Experience a surface is; a brand-surface rule (font pairing, fluid `clamp()` headings, page-load animation, committed accent field) is about to be applied to a task UI; a product UI reads over-designed or subtly strange; a dropdown is clipped by an overflow ancestor; a modal is the first idea for a task |
| [ui-hardening-against-real-content](design/ui-hardening-against-real-content.md) | A screen verified only with short English placeholder data is about to ship; adding translations or an RTL locale; a field, list or label will show user-generated content (100+ char names, emoji, CJK, thousands of rows); writing or reviewing a custom drag / slider / scrub control (`pointercancel`, `lostpointercapture`, second pointer, window blur); a diff sets fixed widths on text containers, hand-rolls English plurals, or formats numbers and dates without `Intl`; error copy needs a recovery action |
| [responsive-layout](design/responsive-layout.md) | Building or reviewing UI that must work across viewport sizes (phone → desktop); choosing breakpoints, touch-target sizes, fluid type, or responsive images; a layout overflows horizontally or breaks on mobile; fixing a zoom/reflow accessibility failure (WCAG 1.4.4/1.4.10/2.5.8); a mobile media query overrides `position` on a container a third-party SDK mounts into and a gap appears only with the SDK loaded |
| [html-in-canvas](design/html-in-canvas.md) | Wanting shader/3D/canvas-composited effects on real interactive HTML (forms, buttons, sections); about to hand-draw UI widgets inside a canvas with manual hit-testing; adding a canvas effect layer to an existing page |
| [multi-shape-canvas-mask](design/multi-shape-canvas-mask.md) | Masking or clipping canvas content to the union of several shapes with `globalCompositeOperation = 'destination-in'`; painted strokes vanish after a per-shape mask loop; reviewing a loop that applies `destination-in` once per shape |
| [lightness-steps-on-dark-surfaces](design/lightness-steps-on-dark-surfaces.md) | Designing or reviewing dark-UI fill tokens where states or elevation levels differ by OKLCH lightness steps and any step sits below about L 30%; a token ladder is called "perceptually distinct" because its L values differ; deciding whether a state cue meets WCAG 1.4.11's 3:1 or must move to outline/chroma/shape; validating an OKLCH→sRGB converter against the browser |
| [pointer-attracted-particle-fields](design/pointer-attracted-particle-fields.md) | Writing or reviewing a canvas/WebGL particle or network background whose nodes move a fixed fraction toward the pointer each frame; the effect clumps after the mouse rests or the page is scrolled; a plan says "pull N % per frame toward the cursor" with no release or inner radius; choosing the regression test for such an update rule |
| [custom-property-values-read-from-script](design/custom-property-values-read-from-script.md) | A script helper reads a CSS custom property with `getComputedStyle(...).getPropertyValue('--x')` to feed canvas `fillStyle`, a chart, or WebGL, and the token set has alias tokens (`--a: var(--b)`); such a helper is tested under jsdom (Jest/Vitest); a canvas draws black although the token is defined; a jsdom test is green while alias tokens misrender; choosing between an empty-or-`var(` fallback guard and a bounded alias-chain resolver, and the alias test cases (single, chained, undefined target, cycle) |
| [theme-swap-propagation-check](design/theme-swap-propagation-check.md) | Verifying theming propagated after a design-system lint gate is clean (the lint-gate page's step 5); finding hardcoded copies of the accent color the linter cannot trace (plain CSS, inline `style=`, SVG `fill`; images and canvas need a screenshot fallback); choosing which custom property to swap when tokens alias each other (swap by value, not by name); running the check once per color scheme, including a class-toggled dark theme (shadcn/ui default) that `page.emulateMedia` alone does not reach; an `oklch()`-declared accent and a hardcoded hex copy of the same color that a raw string comparison misses |
