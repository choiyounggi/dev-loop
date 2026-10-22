---
id: testing-e2e-polling-an-animated-element-for-its-end-position
domain: testing
category: e2e
applies_to: [general, playwright]
confidence: verified
sources:
  - https://developer.mozilla.org/en-US/docs/Web/API/Animation/finished
  - https://developer.mozilla.org/en-US/docs/Web/API/Element/getAnimations
  - https://playwright.dev/docs/actionability
  - https://playwright.dev/docs/api/class-locator
last_verified: 2026-10-20
related: [testing-e2e-e2e-stability, qa-environments-element-crop-screenshots, testing-quality-completion-predicates]
---

# Polling an Animated Element Until It Reaches Its End Position

## When this applies

A capture script, screenshot step, or E2E test waits for an animated element
(a tween, a CSS transition, a spring) to "arrive" by reading its box
(`boundingBox()`, `getBoundingClientRect()`) in a loop and comparing it to a
target. Also when a screenshot taken after such a wait shows the element in
the wrong place and a reviewer reports it as a product bug.

## Do this

1. **Wait on the animation's own end signal when the page exposes one.** Pick
   the first row that applies:

| The motion is driven by | Wait on |
|-------------------------|---------|
| CSS animations, CSS transitions, or `element.animate()` | `Promise.all(el.getAnimations().map((a) => a.finished))`, run in the page. `getAnimations()` includes CSS Animations, CSS Transitions and Web Animations; pass `{ subtree: true }` when a child moves |
| A JS tween or spring library (GSAP, framer-motion, react-spring, a hand-rolled rAF loop) | The library's completion callback or promise, exposed to the test as a flag or a `data-*` attribute that the test waits for |
| None of the above is reachable from the test | The box comparison in step 2 |

2. **When you compare the box, check every axis that moves.** Compute the
   travel on each axis (`|end − start|` for `left`, `top`, `width` and
   `height`) and compare every axis whose travel is non-zero.
   An axis with little travel is already "within tolerance" for most of the
   journey, so a check on that axis alone fires mid-flight.
3. **Set the tolerance well below the smallest non-zero travel**, and below
   the error a reader of the screenshot would notice. A ±6 px band on an axis
   that travels 13 px passes as soon as half of that axis's travel is done.
4. **Require the box to stop changing as well as reach the target.** Take two
   readings one animation frame apart and require them to be equal (Playwright's
   own Stable check uses the same bounding box across two consecutive animation
   frames). A spring that overshoots passes through the target before it settles.
5. **Record the box you captured at,** next to the screenshot (`left`, `top`,
   and the target). A reviewer can then tell "the element was still moving"
   from "the product puts it in the wrong place".

## Edge cases

| Case | Then |
|------|------|
| The animation is infinite (a loop, a pulse) | `finished` never resolves. Wait for the box (step 2 and 4) on the axes the loop does not move, or pause the animation for the capture |
| The test only needs the final state, not the motion | Pass `animations: 'disabled'` to the Playwright screenshot call: finite animations are fast-forwarded to completion and infinite ones are reset to their initial state. Locator and element-handle screenshots default to `"allow"`, so set it explicitly. Keep the box wait for tests that judge the motion itself |
| The poll loop has a timeout | On timeout, fail with the last box and the target. Taking the screenshot anyway produces the mid-flight image this page is about |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Poll only `top` (or only the axis you think of as "the" motion) against the target | Compare every axis with non-zero travel, or wait on `a.finished` | The axis with the smallest travel enters its tolerance band first. In the reproduction a top-only ±6 px check fired at 144 ms with `left` still 84 px from the target |
| Use a tolerance chosen once for "close enough" | Derive it from the smallest travel and the size a reviewer would notice | The same ±6 px band covered almost half of a 13 px travel |
| Read the box once after a fixed sleep | Wait on the end signal or poll the box until it is at the target and unchanged | Playwright's docs say box coordinates are safe for input "assuming the page is static"; a single reading of a moving element is a snapshot of one frame |

## Sources

- https://developer.mozilla.org/en-US/docs/Web/API/Animation/finished — "returns a Promise which resolves once the animation has finished playing"; the page's example waits for all of an element's animations with `Promise.all(elem.getAnimations().map((animation) => animation.finished))`
- https://developer.mozilla.org/en-US/docs/Web/API/Element/getAnimations — "returns an array of all Animation objects affecting this element, or that are scheduled to do so in the future"; "This array includes CSS Animations, CSS Transitions, and Web Animations"; `subtree: true` also returns descendants' animations
- https://playwright.dev/docs/actionability — Stable: the element "has maintained the same bounding box for at least two consecutive animation frames" (the check Playwright runs before actions such as `click`, and the model for step 4)
- https://playwright.dev/docs/api/class-locator — `boundingBox()` returns the box relative to the main frame viewport; "Assuming the page is static, it is safe to use bounding box coordinates to perform input". Screenshot `animations` option: "When set to "disabled", stops CSS animations, CSS transitions and Web Animations"; "finite animations are fast-forwarded to completion, so they'll fire transitionend event. infinite animations are canceled to initial state, and then played over after the screenshot"; locator screenshot "Defaults to "allow" that leaves animations untouched"
- Local reproduction 2026-10-20 (Node 26.7.0, a 600 ms ease-out-cubic tween from `left 890.25, top 670` to `left 698.25, top 657`, sampled every 16 ms): top-only ±6 px first passed at 144 ms with `left 782.5`; both axes ±6 px at 416 ms with `left 703.8`; both axes ±1 px at 496 ms with `left 699.2`; the end of the animation at 608 ms with `left 698.3, top 657.0`
- Field evidence 2026-10 (a Playwright capture script for a game's hand animation; recorded by the originating session): the press-hand shot was taken at `top 651.1` with `left ≈ 750` while the target was `left 698.25`; the top had to travel 13 px and the left 192 px. An LLM judge reported the fingertip "on the felt" as a product defect. Adding `left` within 6 px of 698.25 to the wait captured `left 700.5, top 656.5`, and the judge then saw the tip on the bell
