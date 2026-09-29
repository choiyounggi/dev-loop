---
id: frontend-design-product-ui-vs-brand-surface
domain: frontend
category: design
applies_to: [css, general]
confidence: unverified
sources:
  - "https://github.com/pbakaus/impeccable/blob/114ea1d3838fca73b253af45f873b9c4f5f213c8/skill/reference/operate.md — Impeccable skill 4.x, Operate-mode depth (one family, fixed rem scale, 150–250 ms, no page-load sequence, second neutral, all component states, dropdown clipping); pinned to a commit because the repo restructures its reference paths between versions"
  - "https://github.com/pbakaus/impeccable/blob/114ea1d3838fca73b253af45f873b9c4f5f213c8/skill/SKILL.src.md — the four visitor modes (Persuade / Operate / Read / Experience) and the rule that the mode comes from the requested surface, not the product"
  - "https://claude.com/blog/improving-frontend-design-through-skills — Anthropic Engineering, 2025-11-12; the brand-surface rules this page inverts for product surfaces"
last_verified: 2026-09-29
related: [frontend-design-anti-slop-visual-design, frontend-data-fetching-async-ui-states, frontend-accessibility-interactive-elements, frontend-design-responsive-layout]
---

# Styling a Product Surface Where the Design Serves a Task

## When this applies

Deciding which of Persuade / Operate / Read / Experience a surface is; building or
restyling an app surface (dashboard, admin, settings, data table, editor,
authenticated tool) or a docs, guide, changelog, portfolio or gallery surface
rather than a landing page; a brand-surface rule (display/body font pairing,
fluid `clamp()` headings, one orchestrated page-load animation, a committed
accent field) is about to be applied to one of those; a product UI reads
over-designed or subtly strange; a dropdown is clipped by an overflow ancestor;
a modal is the first idea for a task.

## Do this

First name the mode of the surface in front of you. The mode comes from the
requested surface, not from the product: a developer tool's landing page is
Persuade; a fashion brand's help center is Read.

| Case | Do |
|------|----|
| The visitor decides and acts (landing, pricing, campaign) | Persuade — apply [frontend-design-anti-slop-visual-design] as written; expression carries the page |
| The visitor completes a task (app UI, dashboard, editor, admin, settings) | Operate — apply the rows below; scanability, consistency and familiar affordances outrank expression, and the brand lives in precise details |
| The visitor understands something (docs, guides, changelog) | Read — this page's typography and consistency rows plus a 65–75ch prose measure; navigation matters more than component density |
| The visitor is inside the work (portfolio, gallery) | Experience — the artifact leads from the first viewport and the interface recedes; anti-slop rules apply to the chrome that remains |

Operate-mode rules (rows are ordered general → specific):

| Rule | Detail |
|------|--------|
| Judge by earned familiarity | The test is whether a category-fluent user trusts the interface at once or pauses at each subtly-off control; the failure mode is strangeness without purpose, not flatness |
| One well-tuned sans for headings, labels, buttons, body and data | A display/body pairing is a brand-surface move; a display face in UI labels, buttons or data cells is the product-UI tell |
| Fixed rem type scale with a 1.125–1.2 ratio between steps | Users view at a consistent DPI and a fluid h1 that shrinks inside a sidebar reads worse; many more type elements share the screen, so exaggerated size contrast becomes noise |
| Restrained color is the floor | Accent goes on primary actions, current selection and state indicators only; give sidebars, toolbars and panels a second neutral a step cooler or warmer than the content surface; inactive states get muted, never full-saturation, color |
| Standardize a state vocabulary once | hover, focus, active, disabled, selected, loading, error, warning, success, info — one token set, reused on every screen |
| Ship every component state | default, hover, focus, active, disabled, loading, error; loading is a skeleton in place of the content, not a spinner in the middle of it; an empty state teaches the interface ([frontend-data-fetching-async-ui-states]) |
| Consistent affordances across screens | Same button shape, same form-control vocabulary, same icon style; when the save button looks different on two screens, one of them is wrong |
| Responsive behavior is structural | Collapse the sidebar, switch the table to a responsive form, change column counts at breakpoints — layout adapts, type stays fixed |
| Motion conveys state, 150–250 ms | State change, feedback, loading, reveal; the surface loads straight into the task with no page-load choreography |
| Standard patterns are permitted here | System fonts, top bar + side nav, breadcrumbs, tabs, command palettes, dense tables — density and sameness screen to screen are virtues on a task surface |

## Edge cases

| Case | Then |
|------|------|
| One Operate surface earns committed color (an onboarding welcome screen, a report where one category color carries the data) | Commit on that surface alone and keep Restrained as the floor everywhere else; record the exception next to the token set |
| A dropdown, menu or tooltip is clipped by an `overflow: hidden` / `overflow: auto` ancestor | Let the overlay escape the container: `<dialog>`, the popover API, `position: fixed`, or a portal — an absolutely positioned child cannot leave a clipping ancestor |
| The brief reaches for a modal | A modal is for a task that needs interruption or protected focus; exhaust inline and progressive-disclosure alternatives first |
| The brand-surface page says to theme scrollbars, selection and the caret | On an Operate surface keep standard scrollbars and form controls; theme only the focus ring, selection color and tabular numerals from the palette — reinvented standard affordances are the product-UI version of decoration |
| The same product needs both a marketing site and the app | Route each surface separately: the site follows [frontend-design-anti-slop-visual-design], the app follows this page; sharing tokens is right, sharing the motion and type rules is not |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Pair a display face with a body face in a dashboard | One tuned sans across headings, labels, controls and data | Product UI has more type elements per screen; a second voice reads as noise |
| Size app headings with `clamp()` | Fixed rem steps at a 1.125–1.2 ratio | A heading that shrinks in a narrow panel looks broken, not responsive |
| Open the app with a staggered reveal sequence | Load into the task; spend 150–250 ms on state transitions only | Users arrive mid-flow and wait through choreography every visit |
| Custom scrollbars, hand-drawn select controls, a non-standard modal | Native or platform-standard controls styled from the tokens | Familiar affordances are what let a fluent user trust the screen at once |
| A spinner centered in the content area | A skeleton in the shape of the content | The skeleton keeps layout stable and signals what is coming |
| Full-saturation accent on disabled or inactive controls | Muted tokens for inactive states, accent for the current selection | Saturated inactive states compete with the one action that matters |

## Sources

- https://github.com/pbakaus/impeccable/blob/114ea1d3838fca73b253af45f873b9c4f5f213c8/skill/reference/operate.md — product slop test (earned familiarity), one-family typography, fixed rem scale and 1.125–1.2 ratio, "line length still applies for prose (65–75ch)" with Read surfaces taking this file's typography rules, Restrained color floor, state vocabulary, second neutral, all component states, skeleton loading, structural responsiveness, 150–250 ms motion, no page-load sequence, product constraints and permissions, dropdown clipping
- https://github.com/pbakaus/impeccable/blob/114ea1d3838fca73b253af45f873b9c4f5f213c8/skill/SKILL.src.md — Persuade / Operate / Read / Experience modes; "choose the mode from the requested surface, not the product"; modal only for interruption or protected focus (craft-floor reflex)
- https://claude.com/blog/improving-frontend-design-through-skills — the brand-surface rules (font pairing, extreme contrast, one orchestrated page-load) that this page scopes to Persuade surfaces
- Status note: `confidence: unverified` because the only sources are a third-party skill file and a blog post — no official document and no production use of this wiki's own is described. Cross-checked 2026-09-29 against this wiki's anti-slop page and the hallmark v1.1.0 skill, both landing-page-centric (21 macrostructures, 9 hero types, 8 footers, zero product-UI rows). Upgrade to `field-tested` after the first project applies it and records the context here
