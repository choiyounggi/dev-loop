---
id: frontend-design-html-in-canvas
domain: frontend
category: design
applies_to: [general]
confidence: verified
sources:
  - https://github.com/WICG/html-in-canvas
  - https://groups.google.com/a/chromium.org/g/blink-dev/c/t_nGEmJ_v4s
  - https://tympanus.net/codrops/2026/05/13/exploring-the-html-in-canvas-proposal/
last_verified: 2026-08-29
related: [frontend-design-anti-slop-visual-design, frontend-accessibility-interactive-elements]
---

# Drawing Live HTML into Canvas for Shader and 3D Effect Layers

## When this applies

Wanting shader distortion, 3D-surface mapping, or canvas-composited effects on
real interactive HTML (forms, buttons, whole sections); about to hand-draw UI
widgets inside a canvas with manual hit-testing; adding a canvas effect layer to
an existing page.

## Do this

Check status first: HTML-in-Canvas is a WICG draft — Chromium-only, behind
`chrome://flags/#canvas-draw-element` since Chrome 138 (Dec 2025), Origin Trial
since Chrome 148 (May 2026). Names and signatures can still change. Ship it only
as progressive enhancement: feature-detect `ctx.drawElementImage`, and the plain
HTML must remain fully functional without it.

The core model: the element exists in two places at once — in the DOM (real
clicks, typing, accessibility, keyboard, CSS) and in the canvas (a live pixel
copy a shader can distort, blend, or map onto 3D). API surface:

| Primitive | Role |
|-----------|------|
| `<canvas layoutsubtree>` | Opt-in attribute; the canvas's child elements get layout and participate in hit testing |
| `ctx.drawElementImage(el, x, y)` | 2D context: paints a live copy of a child element; returns a transform for hit-test alignment |
| `texElementSubImage2D` | WebGL: feeds the element into a GPU texture |
| `drawElementImageToTexture` | WebGPU equivalent |
| `paint` event | Fires when embedded HTML changes (focus, hover, input) — redraw or re-run the shader in the listener |

Hit-test alignment is mandatory: apply the transform returned by
`drawElementImage` to `element.style.transform` so the invisible DOM element sits
where its pixels were painted. Skipping this leaves clicks landing where the
element is not.

Minimal render-loop shape (a reflection under a real clickable button, ~20
lines): each frame, clear the canvas → `ctx.save()` → translate down + flip +
30% alpha → `drawElementImage` (the reflection) → `ctx.restore()` → stamp once
more upright (the interactive copy) → apply the returned transform to the button
→ `requestAnimationFrame`.

Effect patterns this unlocks: forms mapped onto reacting 3D cloth, jelly-deformed
range inputs, shader dissolve on form submit, shader-driven focus glow on inputs,
burn-away light/dark theme transitions, liquid-glass refraction, live reflections.

## Edge cases

| Case | Then |
|------|------|
| `prefers-reduced-motion: reduce` | Collapse distortion/shader animation to a ≤150ms opacity crossfade, same as any other motion |
| Browser without the API | The feature-detect branch renders the same HTML uneffected — no canvas wrapper, no behavior loss |
| Clicks or focus land in the wrong place | The returned transform was not applied (or not re-applied after layout changed) — re-sync every frame you re-stamp |
| The base page fails the design tells audit | Fix the base first per [frontend-design-anti-slop-visual-design]; a shader over slop is animated slop |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Hand-draw buttons/inputs on canvas with manual coordinate hit-testing and hover redraws | `layoutsubtree` + `drawElementImage` over real DOM children | The hand-drawn version is a picture of a button — no accessibility, keyboard, or CSS; the API's whole point is keeping the real element |
| Ship it in production paths today | Prototype, demo, or Origin-Trial gated only | Draft proposal; signatures may change under you |
| Add decorative distortion to non-interactive content everywhere | Reserve effects for moments where interaction carries meaning (submit, mode switch, physical response) | Purposeless spectacle is the same tell as floating-orb decoration |
