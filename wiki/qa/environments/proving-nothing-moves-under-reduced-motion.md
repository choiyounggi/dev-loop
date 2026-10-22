---
id: qa-environments-proving-nothing-moves-under-reduced-motion
domain: qa
category: environments
applies_to: [general, playwright]
confidence: verified
sources:
  - https://developer.mozilla.org/en-US/docs/Web/API/Document/getAnimations
  - https://drafts.csswg.org/web-animations-1/
  - https://drafts.csswg.org/css-animations-1/#events
  - https://drafts.csswg.org/css-transitions-1/#transition-events
  - https://developer.mozilla.org/en-US/docs/Web/API/TransitionEvent/propertyName
  - https://playwright.dev/docs/api/class-page
  - "Local reproduction 2026-10-11 (playwright-core 1.63.0, Chromium 153 headless shell): one getAnimations() sample vs start-event counts over load and hover, with and without a reduced-motion guard"
  - "Field origin 2026-10 (linkly-invitation task t5; recorded by the originating session): a plan-literal check printed MOTION OK with two guards removed"
last_verified: 2026-10-11
related: [frontend-design-scrubbed-scroll-animations-under-reduced-motion, frontend-design-anti-slop-visual-design, testing-quality-harness-reverse-controls, testing-quality-tests-that-cannot-fail, qa-environments-browser-console-capture-gaps, testing-e2e-e2e-stability]
---

# Proving Nothing Moves Under a Reduced-Motion Preference

## When this applies

A browser check (Playwright, a CDP script, a browser REPL) must prove that a
page shows no motion when `prefers-reduced-motion: reduce` is on —
`page.emulateMedia({ reducedMotion: 'reduce' })` — and it reads
`document.getAnimations()` once after the page loads. Also when such a check
printed its pass token for a page whose reduced-motion guard you removed.

## Do this

1. **Count starts instead of sampling what is running.** From an init script
   (`page.addInitScript`, which runs "after the document was created but before
   any of its scripts were run"), add one `animationstart` and one
   `transitionrun` listener on `document`; both events bubble, so two listeners
   see every element. `transitionrun` fires when the transition is created,
   before any `transition-delay`, so a delayed transition counts as well.
   `document.getAnimations()` returns the animations "currently in effect": a
   transition that nobody has triggered does not exist yet, and a finished
   animation without a `forwards` fill is neither current nor in effect, so one
   sample after load reads 0 for both.
2. **Drive the states that start motion before reading the counts**: hover
   every interactive element (`button, a, [role=button], input, select,
   textarea, [tabindex]`), scroll through the page so viewport-triggered
   entrances fire, and wait past the longest declared duration.
3. **Require zero starts.** Report the two counts, not a boolean, so a failure
   names the kind of motion.
4. **Prove the check with a known-bad probe before trusting its pass**: on a
   scratch copy of the page, remove one guard (the hover transition, the
   one-shot animation) and require the check to fail; a check that stays green
   has measured nothing ([testing-quality-harness-reverse-controls],
   [testing-quality-tests-that-cannot-fail]).

Measured with the guard removed (`reducedMotion: 'reduce'` emulated, Chromium 153):

| Motion left unguarded | `getAnimations()` once, 600 ms after load | `getAnimations()` while hovering | Start-event counts |
|-----------------------|-------------------------------------------|----------------------------------|--------------------|
| A 300 ms one-shot CSS animation (default fill) | 0 (1 when sampled right after load) | 0 | `animationstart` 1 |
| Hover transitions (`transform`, `color`) on 3 elements | 0 | up to 6 | `transitionrun` 12 (two properties, enter and leave, per element) |
| Nothing (guard intact: `animation: none; transition: none`) | 0 | 0 | 0 |

## Edge cases

| Case | Then |
|------|------|
| The animation has `animation-fill-mode: forwards` | It stays in effect after finishing, so a post-load `getAnimations()` sample does return it (`playState` `finished`); the start count catches it either way |
| Motion is scripted with `element.animate()` (Web Animations API) | It fires no `animationstart`; in the same init script wrap `Element.prototype.animate` and count the calls (measured: 1 call, 0 CSS events, present in `getAnimations()` only while running) |
| Motion is driven by `requestAnimationFrame` or an animation library (GSAP, framer-motion) | No CSS event fires and no `Animation` object exists; assert the library's reduced-motion branch directly ([frontend-design-scrubbed-scroll-animations-under-reduced-motion]) |
| The design keeps opacity cross-fades under reduced motion | Filter the counted events by `TransitionEvent.propertyName` and `AnimationEvent.animationName`, allow the agreed names, and count everything else |
| The check covers several routes | Run steps 1-3 per route: the counters live in the page and an init script re-runs on each navigation |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Read `document.getAnimations().length === 0` once after load as "nothing moves" | Count `animationstart` and `transitionrun` from an init script through load and hover (steps 1-2) | A hover transition is not running at load and a one-shot animation has finished; both read 0 (measured) |
| Trust the first pass token of a new motion check | Remove one guard on a scratch copy and require a failure first (step 4) | The plan-literal check passed with two guards removed in the field case |

## Sources

- https://developer.mozilla.org/en-US/docs/Web/API/Document/getAnimations — "returns an array of all `Animation` objects currently in effect whose target elements are descendants of the document. This array includes CSS Animations, CSS Transitions, and Web Animations"
- https://drafts.csswg.org/web-animations-1/ — an animation is relevant when "Its associated effect is current or in effect"; current needs the effect in play or in the before phase (for a positive playback rate); in effect needs a resolved active time, which outside the active phase only a `forwards`/`both` fill provides
- https://drafts.csswg.org/css-animations-1/#events — `animationstart` "occurs at the start of the animation. If there is an animation-delay then this event will fire once the delay period has expired"; "Bubbles: Yes"
- https://drafts.csswg.org/css-transitions-1/#transition-events — `transitionrun` "occurs when a transition is created (i.e., when it is added to the set of running transitions)"; "Bubbles: Yes"; `transitionstart` "occurs when a transition's delay phase ends"
- https://developer.mozilla.org/en-US/docs/Web/API/TransitionEvent/propertyName — "a string containing the name of the CSS property associated with the transition"
- https://playwright.dev/docs/api/class-page — `emulateMedia` `reducedMotion`: "Emulates 'prefers-reduced-motion' media feature, supported values are 'reduce', 'no-preference'"; `addInitScript`: "The script is evaluated after the document was created but before any of its scripts were run"
- Local reproduction 2026-10-11 (playwright-core 1.63.0, Chromium 153.0.8010.12 headless shell, `reducedMotion: 'reduce'`, a page with a 300 ms `fade` animation and three hover-transitioned elements, served through `page.route` + `page.goto`; `matchMedia('(prefers-reduced-motion: reduce)').matches` was `true`): guard intact, every reading 0. Guard removed, `getAnimations()` 1 right after load, 0 after 600 ms, 6 while hovering, 0 after; `animationstart` 1, `transitionrun` 12, `transitionstart` 12. A second page: a `forwards` animation was the only entry 600 ms after load (`finished`); `element.animate()` added an `Animation` right after load, fired no `animationstart`, and was counted once by a wrapped `Element.prototype.animate`; the hovered button's `transitionrun` events carried `propertyName` `color` and `transform`
- Field origin 2026-10 (linkly-invitation task t5; recorded by the originating session): the plan-literal `getAnimations()` check printed MOTION OK with a Polaroid tilt guard removed and with a Button guard removed; the event-counting version printed `started=14` and `started=66` (FAIL) for the same pages, a one-shot fade gave `started=1` with `animations=0`, and all 10 known-bad probes went red
