---
id: qa-environments-element-crop-screenshots
domain: qa
category: environments
applies_to: [general, playwright]
confidence: field-tested
sources:
  - https://playwright.dev/docs/screenshots#element-screenshot
  - https://playwright.dev/docs/api/class-page
  - https://playwright.dev/docs/api/class-locator
last_verified: 2026-09-03
related: [qa-environments-browser-console-capture-gaps, qa-process-completion-claims, qa-bug-reports-reproducible-reports]
---

# Cropping a Screenshot to a Single Page Element

## When this applies

A browser-automation tool (Playwright, an `aside repl` session, a CDP script)
needs a close-up image of one element for a bug report, QA screenshot, or
visual diff — not the full page. Also when composing `page.screenshot({
clip })` by hand from a `boundingBox()` reading, or when a saved crop shows
the wrong region of the page even though the coordinates you passed look
correct.

## Do this

1. **Reach for the element-screenshot primitive first**: `locator.screenshot({
   path })`. The tool computes and applies the clip itself from the element's
   own geometry — fewer moving parts than composing coordinates by hand.
2. **When you must compose `clip` from `boundingBox()` yourself**, take the
   `boundingBox()` reading immediately before the screenshot call, on the same
   scroll position: the box is relative to the main frame viewport and
   scrolling changes it (`x`/`y` can go negative). For a `fullPage: true`
   capture, the clip is measured on the full scrollable page, so add the
   current scroll offset (`window.scrollX`/`scrollY`) to a viewport-relative
   box.
3. **Read back the first crop before producing a batch.** Open the saved PNG
   and confirm it shows the intended element before looping the same pattern
   over several more elements in one session — a systematic clip bug shows
   the same wrong region on every subsequent crop, so the first check catches
   the whole batch's defect at the cost of one look.
4. **When a crop shows the wrong region regardless of which coordinates you
   pass**, stop varying the coordinates and take a `fullPage: true` (or plain
   viewport) screenshot instead, then reference the element's region by its
   `boundingBox()` coordinates in the report text — the clip pipeline itself
   is the broken part, not the numbers fed into it.

## Edge cases

| Case | Then |
|------|------|
| Element requires scrolling into view first | Scroll it into view, then read `boundingBox()` — a reading taken before the scroll describes a viewport position that no longer matches |
| Element is a scrollable container | `locator.screenshot()` captures only the currently-scrolled content inside it, not the container's full scrollable content — state that scope next to the image |
| The automation tool wraps Playwright without exposing `locator.screenshot()` (only a generic `page.screenshot({ clip })`) | Confirm the wrapper's `clip` behaves like Playwright's on one known element before trusting a batch of crops through it |
| Several clip calls in one session all land on the same wrong region (near the page's top-left) | Treat it as a tool-side coordinate bug, not a per-call mistake — switch every remaining crop in that session to full-page capture |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Compute `page.screenshot({ clip: boundingBox })` for one element and trust the first result | Call `locator.screenshot({ path })` on that element directly | The tool derives and applies the clip itself instead of you composing raw viewport coordinates by hand |
| Produce a batch of clip screenshots without opening any of them | Open the first saved PNG before producing the rest | A systematic clip bug repeats identically on every later crop; one check catches it before the batch is wasted |
| Keep retrying with new coordinates when a clip result shows the wrong region every time | Fall back to a full-page or viewport screenshot and cite the element's region by its `boundingBox()` coordinates in the report | Coordinate correctness does not fix the output when the clip pipeline itself is the broken part |

## Sources

- https://playwright.dev/docs/screenshots#element-screenshot — element screenshots use `await page.locator('.header').screenshot({ path: 'screenshot.png' });`
- https://playwright.dev/docs/api/class-page — `clip` is "An object which specifies clipping of the resulting image," with `x`/`y` as "top-left corner of clip area"; `fullPage`: "When true, takes a screenshot of the full scrollable page, instead of the currently visible viewport. Defaults to false."
- https://playwright.dev/docs/api/class-locator — `locator.boundingBox()`: "The bounding box is calculated relative to the main frame viewport - which is usually the same as the browser window" and "Scrolling affects the returned bounding box... x and/or y may be negative"; `locator.screenshot()`: "captures a screenshot of the page, clipped to the size and position of a particular element matching the locator... If the element is a scrollable container, only the currently scrolled content will be visible on the screenshot."
- Field evidence 2026-09-01 (repo t1-visual, `aside repl`, Aside CLI 1.26.831.1513 / 1.26.810.1915): composing `page.screenshot({ path, clip: boundingBox })` from a locator's `boundingBox()` reading, 5 separate clip calls in one session (rail/roster/matrix/thread/right-column crops) each saved an image of the wrong region — `.panel--roster` at `{x:1081,y:139,w:359,h:761}` produced the rail+artifacts region instead — while every `fullPage: true` capture in the same session was correct; two subagents and the author read the files back independently. Not reproduced outside that session
