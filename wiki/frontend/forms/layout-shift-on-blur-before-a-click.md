---
id: frontend-forms-layout-shift-on-blur-before-a-click
domain: frontend
category: forms
applies_to: [general, react, playwright]
confidence: verified
sources:
  - https://developer.mozilla.org/en-US/docs/Web/API/Element/click_event
  - https://w3c.github.io/uievents/split/mouse-events.html
  - https://w3c.github.io/pointerevents/
  - https://playwright.dev/docs/actionability
  - https://playwright.dev/docs/api/class-locator
last_verified: 2026-10-15
related: [frontend-forms-validation-timing, testing-e2e-e2e-stability, frontend-performance-bundle-and-assets, frontend-accessibility-interactive-elements]
---

# A Blur Handler That Moves Layout Under the Button the User Clicks Next

## When this applies

A field's blur (`onBlur` / `focusout`) handler shows, hides or resizes content
that sits above a button the user clicks right after typing — a map or image
preview, an inline validation message, an expanding summary, an async lookup
result. Also when a browser test that fills a field and then clicks the button
passes as `fill → blur → wait → click` but the plain `fill → click` saves
nothing, and no error appears anywhere.

## Do this

1. **Reserve the region's space before the blur can change it.** Give the
   conditional region a fixed `min-height` (or a fixed-size box) sized to its
   largest state, and render the empty / loading / failed text *inside* that box.
   Content swapping inside a sized box moves no sibling, so the button's position
   is the same before and after the blur re-render.
2. **Verify with a real-browser `fill → click`, nothing between.** The test must
   match the user: `await field.fill('…'); await button.click();` then assert on
   the outcome (the request the handler sends, the saved row, the DOM). Add a
   check that the button's bounding box is equal before `mousedown` and after the
   blur-driven re-render.
3. **Read the failure from the event sequence** when a click "does nothing":

| Step | What the browser does |
|------|-----------------------|
| `mousedown` on the button | Focus moves to the button (mousedown's default action), so the field blurs before `mouseup` |
| The blur handler re-renders | The region above the button appears, collapses or resizes; the button moves |
| `mouseup` | Lands on whatever element now sits under the pointer |
| `click` | Is dispatched to the nearest common inclusive ancestor of the `mousedown` and `mouseup` targets (the form or the body), so the button's handler never runs, with no error and no console line |

4. **When the region's height depends on data** (a result list of N rows, a
   third-party map SDK), reserve the box and let the content scroll inside it
   (`max-height` + `overflow: auto`) rather than letting the box grow.

## Edge cases

| Case | Then |
|------|------|
| The Playwright click passed the actionability checks and still missed | The Stable check (same bounding box for two animation frames) and the Receives-Events hit test run *before* the action; nothing is re-checked between `mousedown` and `mouseup`. Fix the layout (step 1); an auto-waited click cannot see a shift the click itself triggers |
| A keyboard-only test is green (Tab to the button, Enter) | Tab moves focus and the blur re-render finishes before Enter, so the action runs. The defect is pointer-only; keep a pointer `fill → click` case |
| Touch or pen input | Same rule: the `click` target is the nearest common inclusive ancestor of the `pointerdown` and `pointerup` targets (Pointer Events) |
| The conditional region sits *below* the button | The button does not move on that blur; still reserve the space when another action sits below the region |
| The blur handler runs validation only (an inline error line) | The error line is a region above the submit button; reserve one line's height for it, or render it in a box that exists in both states ([frontend-forms-validation-timing]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Script the test as `fill → blur (Tab / click elsewhere) → wait → click` | `fill → click`, as the user does it | The explicit blur lets the re-render finish before the click and hides the defect |
| Delay the blur handler (`setTimeout`) so the click lands first | Reserve the region's space | A timing fix depends on render speed; a slow render still moves the button under the pointer |
| Call `preventDefault()` on the button's `mousedown` to keep focus in the field | Reserve the region's space | Focus then never leaves the field on a click, so the blur validation and the preview never run for pointer users |
| Pass `force: true` to the Playwright click | Reserve the region's space, keep the checks | `force` skips the actionability checks; the pointer still lands where the button was before the shift |

## Sources

- https://developer.mozilla.org/en-US/docs/Web/API/Element/click_event — "`click` fires after both the mousedown and mouseup events have fired, in that order"; "If the button is pressed on one element and the pointer is moved outside the element before the button is released, the event is fired on the most specific ancestor element that contained both elements"
- https://w3c.github.io/uievents/split/mouse-events.html — implementations "SHOULD fire click and dblclick events on the nearest common inclusive ancestor when the associated mousedown and mouseup event targets are different"
- https://w3c.github.io/pointerevents/ — the `click` target is "the nearest common inclusive ancestor of the corresponding pointerdown and pointerup targets in the DOM at the moment event is being dispatched"
- https://playwright.dev/docs/actionability — `locator.click()` checks Visible, Stable ("not animating or completed animation"), Receives Events ("the hit target of the pointer event at the action point"), Enabled; `force` "will not check that the target element actually receives click events"
- https://playwright.dev/docs/api/class-locator — `locator.click()` steps: wait for actionability checks, scroll into view, click the element's center with `page.mouse`, wait for initiated navigations
- Field reproduction 2026-10-12 (Next.js 16 admin form, Playwright + Chrome against `next start`; an address field whose blur renders a map preview above the save button): the save button's page y read 1093 at press and 1057 at release, and no POST left the page. With the preview area reserved at `min-h-64`, the button read y 1847 / 1847 / 1847 across three blurs and the unchanged `fill → click` script saved the form
