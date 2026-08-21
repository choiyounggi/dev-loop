# Ingest report — responsive-layout (frontend/design)

One new verified page: `wiki/frontend/design/responsive-layout.md` — the mobile-responsive
layout contract for UI that must work across viewport sizes (320px phone → desktop).

## Verified best-practice

Every directive was live-verified this session by a research subagent that fetched each
cited URL (web.dev, MDN, W3C WCAG Understanding docs, WebKit official blog):

- Exact viewport meta `width=device-width, initial-scale=1`; zoom stays enabled —
  `user-scalable=no`/`maximum-scale=1` block the ≥2× zoom WCAG requires and iOS
  ignores them anyway (MDN Viewport_meta_element; ~980px virtual-viewport mechanism).
- Mobile-first `min-width` layering with content-driven (not device-catalog)
  breakpoints (web.dev responsive-web-design-basics, quoted).
- Intrinsic layout before media queries: `repeat(auto-fit, minmax(<min>, 1fr))`
  (web.dev patterns) and `@container`/`container-type` with intrinsic fallback (MDN).
- Touch targets: 24×24 CSS px AA (WCAG 2.2 SC 2.5.8, 24px-circle spacing exception)
  and 44×44 AAA (SC 2.5.5) — W3C Understanding docs.
- `clamp()` fluid type gated on a 200%-zoom check — a clamp ceiling can fail
  WCAG 1.4.4 (web.dev min-max-clamp, quoted).
- `srcset`/`sizes` + explicit `width`/`height` for CLS-free responsive images (MDN img).
- Horizontal-overflow mechanism: grid/flex `min-width: auto` → min-content floor,
  fixed with `minmax(0, 1fr)` / `min-width: 0` (MDN min-width).
- Edge cases: `vh`≈`lvh` vs `dvh`/`svh` (MDN length units), `@media (hover: hover)`
  long-tap emulation (MDN), `viewport-fit=cover` + `env(safe-area-inset-*)` +
  `max()` (WebKit blog 7929).
- Final gate: 320px width, no horizontal scrolling (WCAG 1.4.10 reflow).

Deliberately NOT ingested (unverifiable this session): Apple HIG 44pt and Material 3
48dp exact figures (JS-rendered pages returned no body text — WCAG carries the
target-size claims instead) and the rem-vs-px media-query sub-claim (no authoritative
fetch performed). `confidence: verified`, 14 sources in frontmatter, each annotated
in the page's Sources section with what it supports.

## Existing-layer check

Pages read: frontend-design-anti-slop-visual-design, frontend-design-html-in-canvas,
frontend-accessibility-interactive-elements, frontend-performance-bundle-and-assets,
frontend-rendering-long-lists, frontend-data-fetching-infinite-scroll.

No existing page carries this trigger. Closest overlaps and how they were handled:
- anti-slop-visual-design has one narrow-viewport edge-case row (overflow-x clip,
  minmax(0,1fr)) — that row is symptom triage inside a visual-design audit, not a
  responsive methodology; the new page owns the mechanism and the two are
  cross-linked both ways (its edge case now routes to the new page and vice versa).
- interactive-elements owns the full interactive contract; the new page's
  touch-target row routes onward to it rather than duplicating.
- bundle-and-assets owns image loading performance; the new page covers only the
  responsive selection (`srcset`/`sizes`) + CLS reservation angle; related both ways.

## Open-PR check

`gh pr list --state open` returned zero rows at ingest time — no open knowledge PR
touches frontend/design; routed as `new`.

## Routing decision

Domain `frontend` (web UI code), category `design` (existing — visual/layout design
decisions; created 2026-08-20). New page rather than merge because the trigger
(viewport-range layout, breakpoints, touch targets, zoom/reflow failures) matches no
existing "load when" line. Plumbing: frontend/index.md +1 design row with the WCAG
SC numbers in the load-when line, routing intro extended with responsive scope,
log.md ingest entry appended. Lint: prohibition directives unchanged at 71 (no bats
bump needed); structure checks 252 pages / 13 indexes / 0 findings; page body 63
lines (≤120).

---

# Ingest report — anti-slop theme-defaults reinforcement (same PR, second unit)

Amends `wiki/frontend/design/anti-slop-visual-design.md` so a committed non-generic
theme is framed as the DEFAULT for unspecced screens, not an upgrade.

## Verified best-practice

Primary source live-fetched: Anthropic Engineering, "Improving frontend design
through Skills" (claude.com/blog, 2025-11-12). The contributor-supplied
velog.io/@xxziiko post was confirmed to be its Korean translation (content
cross-checked as matching). Ingested from it: default-font avoid-list
(Inter/Roboto/Open Sans/Lato/system) with the distributional-convergence
mechanism; feel-category font taxonomy; the second-order convergence warning
(vary the escape choice — "Space Grotesk as the new Inter"); quantified extreme
contrast (weights 100–200 vs 800–900, 3×+ size jumps); dominant-field +
sharp-accent palettes with IDE-theme/cultural inspiration; domain-derived
aesthetic direction; staggered page-load motion budget; right-altitude rule for
authoring reusable design guidance. Secondary source live-fetched:
github.com/pbakaus/impeccable README (gray-text-on-colored-background,
bounce/elastic easing anti-patterns). The aurora-blob Instead-of row was
reconciled with Anthropic's atmospheric-background endorsement instead of left
contradictory.

Deliberately NOT ingested: javaexpert.tistory.com/1624's deeper Impeccable quotes
(the SKILL.md path it cites 404s — repo restructured, command set unstable
17→23), the 16px body floor, and "adapt don't delete" (third-party, no stated
mechanism, primary unverifiable).

## Existing-layer check

Pages read: frontend-design-anti-slop-visual-design, frontend-design-responsive-layout,
frontend-design-html-in-canvas, frontend-accessibility-interactive-elements.

Same trigger as anti-slop-visual-design (styling unspecced UI / avoiding the
generated look) → merged into that page per the merge-before-create rule; no new
page. Fluid-type clamp() guidance from the tistory post was already covered by
this PR's responsive-layout page — not duplicated.

## Open-PR check

This PR (#122) is the only open knowledge PR; the amendment lands on its branch
as a second commit, keeping one PR per flush.

## Routing decision

Domain frontend, category design, existing page amended: +2 frontmatter sources,
+5 directive rows, +1 edge case, 2 rows reworded; frontend/index.md load-when
line extended (theme direction as default; LLM design-guidance authoring).
Confidence stays field-tested (page mixes Anthropic-verified and hallmark-distilled
rules). Prohibition directives unchanged at 71; structure checks 252/13/0; body
85 lines (≤120).
