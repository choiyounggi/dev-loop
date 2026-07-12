---
id: frontend-performance-bundle-and-assets
domain: frontend
category: performance
applies_to: [react, general]
confidence: verified
sources:
  - https://react.dev/reference/react/lazy
  - https://web.dev/articles/optimize-lcp
  - https://web.dev/articles/cls
  - https://developer.mozilla.org/en-US/docs/Web/Performance/Guides/Lazy_loading
  - https://web.dev/articles/font-best-practices
last_verified: 2026-07-10
related: [frontend-rendering-rerender-and-memoization]
---

# Reducing First-Load Payload: Bundle, Images, Fonts

## When this applies

First load is slow, LCP/CLS scores are poor, the bundle keeps growing, or you are
adding a heavy dependency, image, or font to a page. This page owns payload;
runtime rendering cost belongs to [frontend-rendering-rerender-and-memoization].

## Do this

1. Measure first: a bundle analyzer for weight, Lighthouse/field data for LCP and
   CLS. Fix the measured top item — JS that is not shipped is faster than JS that
   is optimized.
2. Split the bundle by this table:

| Target | Do |
|--------|----|
| Route level | Lazy route components (`React.lazy(() => import(…))` declared at module top level + `<Suspense>` with a route-level fallback) so each page loads only its own code |
| Heavy, rarely-used feature (rich editor, chart library, modal behind a click) | Dynamic `import()` triggered on interaction or visibility — the code loads when the feature is first used |
| A third-party dependency you are adding | Check its size before adopting; import the module subpath where the library supports it; use the platform API for trivial utilities (date diff, one array helper). Vetting the dependency itself: `wiki/security/` |

3. Images: give every image explicit `width`/`height` (or `aspect-ratio`) so the
   browser reserves the space — unsized images are the classic CLS source. Add
   `loading="lazy"` to below-the-fold images; never to the LCP/hero image —
   lazy-loading the LCP image always delays it. Serve modern formats with a
   responsive `srcset` so devices download the size they render.
4. Fonts: set a `font-display` strategy — `swap` renders fallback text immediately
   and swaps in the web font; `optional` skips the web font on slow connections.
   Invisible text waiting on a font is a fake outage. Preload the one critical
   font file; deliver WOFF2 and subset to the characters you use.

## Edge cases

| Case | Then |
|------|------|
| `lazy()` called inside a component body | Move the declaration to module top level — recreating it per render resets the component's state on every render |
| The LCP element is a CSS `background-image` | The browser discovers it late — reference the image from the HTML (an `<img>`, or a preload) and mark it `fetchpriority="high"` |
| A component library lazy-loads its images by default and one lands above the fold | Override to eager loading for that instance; keep the below-fold default |
| The brand font is decorative, not content-critical | `font-display: optional` — fallback text stays when the font misses the window, trading the brand glyph for zero swap shift |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Import a 300 KB library for one function | Subpath import of that module, or the platform API | The whole library ships to every user on first load |
| Lazy-load everything, including above-the-fold content | Split by route and interaction; keep the critical path eager | Lazy-loading what first paint needs (LCP image, visible components) delays it behind an extra round trip |
| Optimize runtime rendering while first load is the complaint | Run the bundle analyzer and Lighthouse first, cut the top payload item | Payload, not re-renders, dominates first load; unshipped JS beats optimized JS |
| Hide text until the web font arrives | `font-display: swap`/`optional` + preload the critical font | Users read fallback text immediately instead of staring at invisible text |

## Sources

- https://react.dev/reference/react/lazy — dynamic-import components with Suspense fallback; declare at module top level
- https://web.dev/articles/optimize-lcp — never lazy-load the LCP image; `fetchpriority`; make the LCP resource discoverable early
- https://web.dev/articles/cls — unsized images/late content cause layout shifts; reserve space
- https://developer.mozilla.org/en-US/docs/Web/Performance/Guides/Lazy_loading — `loading="lazy"` for images/iframes; code splitting via dynamic import
- https://web.dev/articles/font-best-practices — `font-display` tradeoffs (swap/optional/block), preloading, WOFF2, subsetting
