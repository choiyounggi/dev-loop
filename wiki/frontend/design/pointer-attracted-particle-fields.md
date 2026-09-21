---
id: frontend-design-pointer-attracted-particle-fields
domain: frontend
category: design
applies_to: [canvas, general]
confidence: verified
sources:
  - https://en.wikipedia.org/wiki/Banach_fixed-point_theorem
  - https://developer.mozilla.org/en-US/docs/Web/API/Element/pointerleave_event
  - https://developer.mozilla.org/en-US/docs/Web/API/Window/requestAnimationFrame
  - https://github.com/choiyounggi/cover-letter
last_verified: 2026-09-06
related: [frontend-design-anti-slop-visual-design, frontend-design-html-in-canvas, testing-quality-tests-that-cannot-fail]
---

# A Pointer-Attracted Particle Field Whose Nodes Must Not Pile Up

## When this applies

Writing or reviewing a canvas/WebGL background (particle network, constellation,
dot grid) whose per-frame update moves each node a fixed fraction of the
remaining distance toward the pointer (`p += (cursor - p) * k`); the effect
"clumps" after the visitor rests the mouse or scrolls away; a plan says "pull
N % per frame toward the cursor" and nothing else.

## Do this

1. **Read the rule as a contraction before shipping it.** With a stationary
   target, `p ← p + k·(t − p)` with `0 < k < 1` is a contraction whose only
   fixed point is `t`: every node within the pull radius converges onto the
   cursor position and stays there. A small random drift only sets the clump's
   radius (about drift ÷ k) — it does not restore the field. Two guards are
   required, and a review asks for both:

| Guard | Do |
|-------|----|
| Release | Store the pointer in canvas-local coordinates and set it to `null` when it falls outside `[0,w]×[0,h]` (or on the section's `pointerleave`). Without release, a cursor parked past the canvas edge, or off-screen while the page is scrolled, keeps pulling |
| Floor | Define an inner radius `r₀` and pull only while `r₀ < d < R`; clamp the step to `min(d·k, d − r₀)` so one step cannot cross the floor. Nodes then hold at `r₀` instead of stacking |

2. **Demand the many-step regression test.** A pure-function test that steps
   the update 1000× with a resting pointer and asserts `distance ≥ r₀` for
   every node is the assertion that separates "pulls toward" from "collapses
   onto"; a one-frame test passes both. Add a boundary case (a node already
   inside `r₀` is untouched) and a component case (an in-bounds then
   out-of-bounds `pointermove` delivers `null` to the next step). Show each
   test red with its guard reverted ([testing-quality-tests-that-cannot-fail]).
3. **Make resume safe by construction.** `requestAnimationFrame` pauses in
   background tabs, so the loop resumes later with whatever pointer it stored;
   release (guard 1) is what makes the resumed state harmless.

## Edge cases

| Case | Then |
|------|------|
| Touch devices — no `pointermove` stream, one tap sets a pointer | Clear the pointer on `pointerup`/`pointercancel` as well, or skip the attraction for coarse pointers |
| The pull should feel springy rather than damped | A spring (`v += (t − p)·k; p += v; v *= damping`) overshoots but has the same fixed point — it still needs the floor and the release |
| Several attractors (multi-touch, decorative anchors) | Apply the floor per attractor and clamp the combined step against the nearest attractor's `r₀`; two individually clamped pulls can still sum past one floor |
| `prefers-reduced-motion: reduce` | Keep the drift, drop the pointer pull — the attraction is the motion the preference asks to remove |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Approve "pull 2 % per frame toward the cursor" as a complete spec | Ask for the release condition and the inner radius and write them into the plan | The rule as stated converges every node in range onto one point |
| Test the pull with a single step call | Step it hundreds of times with a fixed pointer and assert the distance floor | Collapse is a limit behavior; one step cannot observe it |
| Store the pointer in page coordinates from a `window` listener | Convert to canvas-local coordinates and null it when out of bounds | Page coordinates outside the canvas still read as a valid attractor |

## Sources

- https://en.wikipedia.org/wiki/Banach_fixed-point_theorem — a contraction mapping "admits a unique fixed point" and the iterates `xₙ = T(xₙ₋₁)` converge to it
- https://developer.mozilla.org/en-US/docs/Web/API/Element/pointerleave_event — "fired when a pointing device is moved out of the hit test boundaries of an element"
- https://developer.mozilla.org/en-US/docs/Web/API/Window/requestAnimationFrame — callbacks are "paused in most browsers when running in background tabs or hidden `<iframe>`s"
- Field reproduction 2026-09-06 (https://github.com/choiyounggi/cover-letter, hero `NetworkCanvas.tsx` / `network.ts`, review t2-hero-code-intro-r1 F1): a 2 %/frame pull within 160 px and no floor collapsed nodes to ~8.7e-8 px from a resting pointer; the fix added `POINTER_INNER_RADIUS = 32`, the clamped step, and canvas-relative pointer nulling out of bounds, with a 1000-step distance-floor test, an inner-radius boundary test, and an out-of-bounds `null` component test — each shown red with its guard reverted, 374 tests green with the fixes
