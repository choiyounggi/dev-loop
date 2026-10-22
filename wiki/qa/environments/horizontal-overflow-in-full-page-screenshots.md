---
id: qa-environments-horizontal-overflow-in-full-page-screenshots
domain: qa
category: environments
applies_to: [general, playwright]
confidence: verified
sources:
  - https://playwright.dev/docs/api/class-page
  - https://playwright.dev/docs/screenshots
  - https://www.w3.org/TR/png-3/
  - "Local reproduction 2026-10-11 (playwright-core 1.63.0, Chromium 153 headless shell): full-page and viewport PNG widths, scrollWidth and the centred column's box at 375 and 1440 px viewports, normal and widened, with and without a root overflow-x clip"
  - "Field origin 2026-10 (linkly-invitation task t7b; recorded by the originating session): a blind vision subagent judging full-page screenshots with the viewport width in the brief"
last_verified: 2026-10-11
related: [qa-environments-element-crop-screenshots, testing-quality-harness-reverse-controls, qa-process-completion-claims, frontend-design-anti-slop-visual-design]
---

# Horizontal Overflow in a Full-Page Screenshot

## When this applies

A screenshot-based check, or a screenshot-judging subagent (a vision model
reading images), must catch horizontal overflow — content wider than the
viewport — from Playwright `page.screenshot({ fullPage: true })` images of a
page whose content column is centred (`margin: 0 auto`, Tailwind `mx-auto`).
Also when writing the brief for such a judge.

## Do this

1. **Measure the overflow with numbers before anyone looks at pixels.** A
   full-page capture "takes a screenshot of the full scrollable page, instead
   of the currently visible viewport", so the image is as wide as the
   document's scrollable width. In the page: `document.documentElement.scrollWidth
   > window.innerWidth`. On disk: the PNG width (the IHDR chunk's first field,
   bytes 16-19 of the file) `> viewport width × deviceScaleFactor`.
2. **When a judge reads the images, give it the one number the image lacks.**
   Put the viewport width in every file name (`home-375w.png`), state in the
   brief that it is the viewport width in CSS px, and state the rule: an image
   wider than that number is horizontal overflow. A centred column re-centres
   inside the widened body, so nothing in a full-page image looks cut off; the
   width is the only evidence.
3. **Plant a control the judge must flag**: the same page with
   `body { width: calc(100vw + 300px) }`, saved under the same naming. A judge
   that passes the control has not applied the rule — re-brief before reading
   its verdicts on real pages ([testing-quality-harness-reverse-controls]).
4. **Add a viewport-only capture (`fullPage: false`) of the same page.** There
   the overflow is visible: the column is pushed right and cut at the edge.

Measured on a page with a 375 px centred `main`, body widened by 300 px:

| Viewport | Widened | `scrollWidth` | `main` box (x, right) | Full-page PNG width | Viewport PNG width |
|----------|---------|---------------|-----------------------|---------------------|--------------------|
| 375 | no | 375 | 0, 375 | 375 | 375 |
| 375 | yes | 675 | 150, 525 | 675 | 375 |
| 1440 | no | 1440 | 532.5, 907.5 | 1440 | 1440 |
| 1440 | yes | 1740 | 682.5, 1057.5 | 1740 | 1440 |

## Edge cases

| Case | Then |
|------|------|
| `deviceScaleFactor` is 2 (a mobile device descriptor) | The PNG is twice the CSS width; compare against `viewport × deviceScaleFactor`, or set `deviceScaleFactor: 1` for the check |
| The root has `overflow-x: hidden` or `clip` | The numbers still report the overflow (measured: `scrollWidth` 675 and a 675 px full-page image at a 375 px viewport in both cases) while the user cannot drag the page sideways; keep the measurement, and describe the failure as clipped content |
| The judge also rates layout, spacing or copy | Keep the overflow rule as its own line in the brief with its own verdict; a page can pass the eye and fail the number |
| Several viewports are captured | Plant one control per viewport width; the field case flagged 4 of 4 widened controls across full-page and viewport-clipped images |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Ask the judge "does anything look cut off?" over full-page images | Compare the numbers (step 1), or give the judge the viewport width and the rule (step 2) | Measured: the widened page's full-page image was 675 px wide at a 375 px viewport and its column sat centred at 150-525; nothing looked cut off |
| Accept a judge that passed every real page | Include the planted widened control and require it flagged (step 3) | A judge without the width cannot see overflow, so passing real pages is not evidence |

## Sources

- https://playwright.dev/docs/api/class-page — `page.screenshot` `fullPage`: "When true, takes a screenshot of the full scrollable page, instead of the currently visible viewport."
- https://playwright.dev/docs/screenshots — a full page screenshot is "as if you had a very tall screen and the page could fit it entirely"
- https://www.w3.org/TR/png-3/ — IHDR: "Width 4 bytes, Height 4 bytes, …"; "Width and height give the image dimensions in pixels"; after the 8-byte signature and the chunk's 4-byte length and 4-byte type, the width occupies bytes 16-19
- Local reproduction 2026-10-11 (playwright-core 1.63.0, Chromium 153.0.8010.12 headless shell, `deviceScaleFactor: 1`, a page with `main { max-width: 375px; margin: 0 auto }` and, in the widened variant, `body { width: calc(100vw + 300px) }`): the table above, PNG widths read from bytes 16-19 of each file. With `html, body { overflow-x: clip }` and with `hidden`, the widened page still measured `scrollWidth` 675, its widest child's right edge at 525 and a 675 px full-page image
- Field origin 2026-10 (linkly-invitation task t7b; recorded by the originating session): a mock page with a 375 px `mx-auto` column and the body widened by 300 px gave a 675×812 full-page image at a 375 viewport and 1740 wide at 1440; a blind Opus subagent briefed with the viewport width returned 2/2 normal pages ok and flagged 4/4 widened images (full-page and viewport-clipped), `FLOW_OK=no`
