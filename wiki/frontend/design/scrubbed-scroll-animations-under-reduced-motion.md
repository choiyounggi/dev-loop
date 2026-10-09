---
id: frontend-design-scrubbed-scroll-animations-under-reduced-motion
domain: frontend
category: design
applies_to: [general, react]
confidence: verified
sources:
  - https://gsap.com/docs/v3/Plugins/ScrollTrigger/
  - https://gsap.com/docs/v3/GSAP/Timeline/timeScale()/
  - https://gsap.com/docs/v3/GSAP/gsap.matchMedia()/
last_verified: 2026-09-28
related: [frontend-state-effects-usage, frontend-accessibility-interactive-elements, testing-mocking-fake-intersection-observer-for-viewport-animations]
---

# Scroll-Scrubbed Animations Under a Reduced-Motion Preference

## When this applies

A codebase honours `prefers-reduced-motion` through one global switch on the
animation engine's clock — `gsap.globalTimeline.timeScale(...)`, a global
duration multiplier, a "skip to end" on played tweens — and you are adding or
reviewing an effect whose progress is driven by scroll position: a GSAP tween
with `scrollTrigger: { scrub }`, a count-up or typing effect updated from a
scroll progress value, a parallax layer.

## Do this

1. **Classify each effect as played or scrubbed.** `scrub` "links the progress
   of the animation directly to the scrollbar so it acts like a scrubber": the
   engine sets `progress()` from scroll position instead of playing the tween,
   so a clock factor (`timeScale`, which scales "time in the animation") has
   nothing to scale. A global clock switch covers only the played class.
2. **For every scrubbed effect, read the preference where the effect is
   created** — `gsap.matchMedia()` with a `"(prefers-reduced-motion: reduce)"`
   condition, or `window.matchMedia` — and in the reduced branch skip creating
   the ScrollTrigger and set the final state directly (`gsap.set`, final text,
   final class).
3. **At review, list every `scrub` and every progress-driven `onUpdate` in the
   diff against the codebase's reduced-motion mechanism**; each one needs its
   own branch or a documented reason it is exempt.
4. **Test the reduced branch:** stub `matchMedia` to report `reduce`, render,
   and assert the final state is present and no trigger was created.

| Effect | Reduced-motion handling |
|--------|-------------------------|
| Played tween (`gsap.to`, `whileInView`) | The global clock switch or `duration: 0` in the `matchMedia` branch |
| `scrollTrigger: { scrub: true \| 1 }` | Do not create the trigger; `gsap.set` the end values |
| `onUpdate` writing text or attributes from progress (count-up, typing) | Write the final text once in the reduced branch |

## Edge cases

| Case | Then |
|------|------|
| `scrub: 1` (smoothed) | Still scroll-driven; the smoothing is a catch-up tween on progress, not playback under the global clock |
| The effect combines a pinned ScrollTrigger with a played child timeline | Split: the pin and scrub stay layout, the child timeline follows the played-class rule |
| The preference changes while the page is open | `gsap.matchMedia()` re-runs the matching context and reverts the other; a hand-rolled `window.matchMedia` check needs a `change` listener |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Rely on `globalTimeline.timeScale(0)` for a scrubbed tween | Branch on the preference and set the final state | Scrub sets progress from scroll; the clock never runs |
| Ship the scrubbed effect and let the integration reviewer catch it | Enumerate `scrub` sites at task review | The seam is per effect, so it is missed by a global check |

## Sources

- https://gsap.com/docs/v3/Plugins/ScrollTrigger/ — `scrub`: "Links the progress of the animation directly to the scrollbar so it acts like a scrubber"; `scrub: true` "links the animation's progress directly to the ScrollTrigger's progress"
- https://gsap.com/docs/v3/GSAP/Timeline/timeScale()/ — "Factor that's used to scale time in the animation where 1 = normal speed (the default), 0.5 = half speed, 2 = double speed"
- https://gsap.com/docs/v3/GSAP/gsap.matchMedia()/ — section "Accessible animations with prefers-reduced-motion": `reduceMotion: "(prefers-reduced-motion: reduce)"` condition and `duration: reduceMotion ? 0 : 2`
- Field evidence 2026-09-27 (cover-letter, t3-experience-motion, `DurationMeter.tsx`): the repo's reduced-motion story was `globalTimeline.timeScale()`; a scrubbed count-up meter kept animating under the preference and was caught by the integration reviewer, not at task review. Reworked to read the preference in the component, skip the trigger, and render the final value
