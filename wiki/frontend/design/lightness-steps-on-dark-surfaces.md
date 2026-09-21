---
id: frontend-design-lightness-steps-on-dark-surfaces
domain: frontend
category: design
applies_to: [css, general]
confidence: verified
sources:
  - https://www.w3.org/TR/WCAG21/
  - https://www.w3.org/WAI/WCAG21/Understanding/non-text-contrast.html
  - https://www.w3.org/TR/css-color-4/
  - "Local reproduction 2026-09-06: WCAG contrast ratios recomputed from the engine-measured sRGB bytes; a CSS Color 4 OKLab→sRGB conversion reproduced those bytes within ±2"
last_verified: 2026-09-06
related: [frontend-design-anti-slop-visual-design, frontend-accessibility-interactive-elements]
---

# Distinguishing States by OKLCH Lightness on a Dark Surface

## When this applies

Designing fill colors for a dark UI where two or more states (idle / hover /
selected / disabled, or elevation levels) are told apart by OKLCH lightness
steps and any step sits below about L 30%; writing `oklch(L C H)` token ladders
for dark surfaces; reviewing a dark-theme token set that calls its steps
"perceptually distinct" because the L values differ.

## Do this

1. **Verify a step by the sRGB contrast ratio it produces, not by the lightness
   difference.** Convert each token to sRGB (the browser does this at paint
   time), compute WCAG relative luminance, and take `(L1 + 0.05) / (L2 + 0.05)`.
   The OKLCH `L` axis is perceptually uniform, but the sRGB bytes a dark color
   lands on are few and close together, and the `+ 0.05` term flattens every
   difference near black — so equal `L` steps yield shrinking ratios as they go
   darker. Measured on a WKWebView (Tauri, macOS), chroma ≈ 0.015, hue ≈ 215:

| OKLCH L | sRGB | Ratio vs L 13% |
|---------|------|----------------|
| 13% | rgb(3, 8, 10) | 1.00 |
| 19% | rgb(14, 21, 23) | 1.09 |
| 22% | rgb(20, 28, 30) | 1.15 |
| 27% | rgb(31, 40, 43) | 1.34 |
| 72% | rgb(155, 167, 170) | text-range reference |

   Four rungs of a 5–6 pp ladder never reach 1.4:1; a 6 pp step that is obvious
   at L 70% is 1.09:1 at L 13%.

2. **Pick the axis by what the difference must carry:**

| The difference must | Do |
|---------------------|----|
| Identify a component or its state boundary (selected vs idle, focus, a toggle's on/off fill) | Meet WCAG 1.4.11's 3:1 against the adjacent color. At L < 30% that ratio is out of reach for lightness alone inside a dark palette, so carry it on another axis: an outline or border token, a chroma jump (tinted vs neutral), an icon or shape change, or lightness from a far rung (L ≥ 45%) |
| Suggest elevation or grouping (card on page, hover wash) that a user need not detect to operate the UI | Lightness steps stay — the +3%-per-level elevation rule in [frontend-design-anti-slop-visual-design] is this case — and the ratio check records them as decorative |

3. **Keep the check in the token pipeline.** Store the ladder as OKLCH tokens,
   generate the sRGB values and pairwise ratios with a script at build or review
   time, and fail the review when a pair the table marks as "identify" is under
   3:1. Name the measuring script beside the tokens so a later ladder edit
   re-runs it.

## Edge cases

| Case | Then |
|------|------|
| A hand-written OKLCH→sRGB converter disagrees with the browser | Trust the engine: draw the color to a canvas and read it back (`fillStyle` + `getImageData`), then fix the converter until it matches byte for byte — the measurement above was validated this way on four rungs |
| The ladder is for text on the dark surface | Apply the text thresholds (4.5:1 body, 3:1 large) against the surface; a 72% rung on a 13% surface is in range, the low rungs are not |
| Only the darkest rung is out of reach and the ladder is otherwise fine | Move the whole ladder up (start at L ≥ 20%) rather than widening one gap; per-rung tweaks reintroduce the unevenness OKLCH was chosen to avoid |
| The state is also signalled by a border, icon, or text label with its own 3:1 ratio | The fill step may stay decorative; the check applies to whichever cue carries the identification |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Approve a dark-state ladder because the `L` values differ by 5–8 pp | Compute the sRGB contrast ratio for each adjacent pair and gate on it | Below L 30% those steps land at about 1.1–1.3:1 — under the 3:1 UI-component floor |
| Widen the lightness gap until the state reads | Switch the distinguishing cue to outline, chroma, or shape, keeping the fills close | A gap wide enough to read pulls the "dark" state into mid-tones and breaks the dark theme; another axis buys the distinction without the lightness cost |
| Cite "OKLCH is perceptually uniform" as proof the steps are visible | Cite the measured ratio | Uniformity describes the axis; visibility is the ratio of the sRGB colors the page paints |

## Sources

- https://www.w3.org/TR/WCAG21/ — contrast ratio defined as `(L1 + 0.05) / (L2 + 0.05)` on sRGB relative luminance
- https://www.w3.org/WAI/WCAG21/Understanding/non-text-contrast.html — SC 1.4.11: user-interface components and the visual information required to identify them "have a contrast ratio of at least 3:1 against adjacent color(s)"
- https://www.w3.org/TR/css-color-4/ — OKLCH lightness "clearly reflect[s] the visual lightnesses" of colors (in contrast to HSL); sRGB is gamma-encoded and colors are encoded to it at paint time
- Local reproduction 2026-09-06 (Python, CSS Color 4 OKLab→linear-sRGB matrices): `oklch(13% 0.015 215)` → rgb(2, 9, 11), 19% → (12, 22, 24), 22% → (19, 28, 31), 27% → (30, 40, 43), 72% → (155, 167, 170), within ±2 of the engine-measured bytes; WCAG ratios from the measured bytes: 13% vs 19% = 1.091, 22% vs 27% = 1.15, 13% vs 27% = 1.339
- Field measurement 2026-09-02 (linkly-crew, Tauri macOS WKWebView): canvas `fillStyle` + `getImageData` readback of the four rungs matched the project's OKLCH→sRGB converter byte for byte; the state ladder was redesigned onto outline and chroma cues
