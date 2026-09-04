---
id: frontend-design-multi-shape-canvas-mask
domain: frontend
category: design
applies_to: [canvas, general]
confidence: verified
sources:
  - https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/globalCompositeOperation
last_verified: 2026-09-03
related: [frontend-design-html-in-canvas]
---

# Masking Canvas Content With Several Shapes via destination-in

## When this applies

Clipping or masking canvas content (paint strokes, an image) to the union of
several shapes with `globalCompositeOperation = 'destination-in'`; painted
content disappears after the mask step; reviewing a loop that sets
`destination-in` and draws one shape per iteration.

## Do this

`destination-in` keeps "the existing canvas content … where both the new shape
and existing canvas content overlap. Everything else is made transparent." Each
application intersects against what the previous application left, so a
per-shape loop computes content ∩ shape1 ∩ shape2 ∩ …, which is empty for shapes
that do not all overlap.

| Case | Do |
|------|----|
| One mask shape | Set `destination-in` once and draw the shape onto the target |
| Several mask shapes (a union of regions) | Draw every shape with `source-over` onto an offscreen canvas of the same size, then set `destination-in` on the target and `drawImage(offscreen, 0, 0)` once |
| Shapes arrive over time (strokes, body parts added per frame) | Accumulate them on the offscreen canvas with `source-over`; apply the single `destination-in` draw when the clipped result is needed (once per frame) |
| The mask needs soft edges or its own blending | Build that on the offscreen canvas; the target still receives one `destination-in` draw |

Restore `globalCompositeOperation` to `source-over` after the mask draw so later
paint is not clipped by accident.

## Edge cases

| Case | Then |
|------|------|
| The shapes genuinely all overlap one region and per-shape application "worked" | It computed the intersection, not the union; the first non-overlapping shape added later erases the paint |
| Device-pixel scaling (`devicePixelRatio`) differs between target and offscreen canvas | Size the offscreen canvas in the same device pixels and draw it at `0,0` with the same transform, or the mask lands offset |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Loop over mask shapes setting `destination-in` and drawing each one onto the target | Draw them all `source-over` onto an offscreen canvas and apply it with one `destination-in` `drawImage` | `destination-in` is an intersection with the current content; repeating it chains intersections and disjoint shapes leave nothing |

## Sources

- https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/globalCompositeOperation — `destination-in`: "The existing canvas content is kept where both the new shape and existing canvas content overlap. Everything else is made transparent."; `source-over` draws new shapes on top of existing content
- Field evidence 2026-08-19 (mechameleon-web, commit e34c2c5): brush strokes clipped per body part with `destination-in` in a loop lost all paint; drawing the parts onto one mask canvas and applying it with a single `destination-in` `drawImage` restored the strokes, confirmed by an E2E frame comparison
