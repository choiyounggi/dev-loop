---
id: frontend-design-responsive-layout
domain: frontend
category: design
applies_to: [css, html, general]
confidence: verified
sources:
  - https://web.dev/articles/responsive-web-design-basics
  - https://developer.mozilla.org/en-US/docs/Web/HTML/Guides/Viewport_meta_element
  - https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html
  - https://www.w3.org/WAI/WCAG21/Understanding/target-size.html
  - https://www.w3.org/WAI/WCAG21/Understanding/resize-text.html
  - https://www.w3.org/WAI/WCAG21/Understanding/reflow.html
  - https://web.dev/articles/min-max-clamp
  - https://web.dev/patterns/layout/repeat-auto-minmax
  - https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_container_queries
  - https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/img
  - https://developer.mozilla.org/en-US/docs/Web/CSS/min-width
  - https://developer.mozilla.org/en-US/docs/Web/CSS/length#relative_length_units_based_on_viewport
  - https://developer.mozilla.org/en-US/docs/Web/CSS/@media/hover
  - https://webkit.org/blog/7929/designing-websites-for-iphone-x/
  - https://developer.mozilla.org/en-US/docs/Web/CSS/position
  - https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_cascade/Specificity
  - https://developer.mozilla.org/en-US/docs/Web/CSS/word-break
  - https://www.w3.org/TR/css-text-3/
  - https://developer.mozilla.org/en-US/docs/Web/CSS/flex-shrink
last_verified: 2026-09-06
related: [frontend-design-anti-slop-visual-design, frontend-accessibility-interactive-elements, frontend-performance-bundle-and-assets, frontend-design-design-canvas-workflow]
---

# Making One Layout Work From 320px Phones to Desktop

## When this applies

Building or reviewing web UI that must render across viewport sizes (phone →
desktop); choosing breakpoints, touch-target sizes, fluid type, or responsive
images; a layout overflows horizontally, breaks on mobile, or fails a zoom/reflow
accessibility check.

## Do this

Work through these in order — each later item assumes the earlier ones hold:

| Case | Do |
|------|----|
| Any page intended for mobile | Ship exactly `<meta name="viewport" content="width=device-width, initial-scale=1">`. Without it, mobile browsers render into a ~980px virtual viewport and scale down, so width-based media queries never trigger |
| Same meta tag, zoom settings | Leave pinch-zoom enabled: `user-scalable=no` and `maximum-scale=1` are forbidden because low-vision users need ≥2× zoom (WCAG minimum; 5× is the documented best practice) and iOS ignores the restriction anyway — omit both attributes |
| Writing the stylesheet | Mobile-first: base styles target the smallest screen; layer wider layouts with `min-width` media queries. This minimizes overrides versus a desktop-first `max-width` cascade |
| Choosing breakpoint values | Place a breakpoint where THIS content's layout breaks (expand the window until it does), not at device-catalog widths — device-based breakpoints rot as hardware ships |
| A grid of cards/tiles must reflow by width | `grid-template-columns: repeat(auto-fit, minmax(<content-min>, 1fr))` — zero media queries; `auto-fit` collapses empty tracks and stretches the rest, `auto-fill` keeps empty tracks |
| A component must respond to its container, not the viewport (sidebar vs main placement) | `@container` query with `container-type: inline-size` on the ancestor; keep an intrinsic grid/flex layout as the no-support fallback |
| Sizing interactive targets | ≥24×24 CSS px per WCAG 2.2 AA (SC 2.5.8); 44×44 meets AAA (SC 2.5.5). A smaller target is compliant only when a 24px-diameter circle centered on it intersects no other target's circle — see [frontend-accessibility-interactive-elements] for the rest of the interactive contract |
| Fluid type | `font-size: clamp(<min-rem>, <vw-based>, <max-rem>)`, then verify at 200% browser zoom before shipping — a clamp ceiling can stop text from reaching 200% of its original size, which fails WCAG 1.4.4 |
| Serving images | `srcset` + `sizes` so the browser picks the resource for the slot's layout width; explicit `width`/`height` attributes on every `<img>` so space is reserved pre-load (prevents CLS; matters most on lazy-loaded images) |
| Final gate before shipping | Render at 320px CSS width: all content and functions present with no horizontal scrolling (WCAG 1.4.10 reflow — 320px equals a 1280px desktop at 400% zoom) |

## Edge cases

| Case | Then |
|------|------|
| A full-height section uses `100vh` and content hides under the mobile URL bar | `vh` sizes to the largest viewport (chrome retracted). Use `dvh` (tracks the current chrome state, may reflow during scroll) or `svh` (smallest viewport — stable, may leave a gap when chrome retracts) |
| UI is revealed only on hover | Gate it behind `@media (hover: hover)` and give touch users a tap-visible path — `hover: none` devices can only emulate hover via long-tap |
| Edge-to-edge layout on notched/rounded-corner phones | Add `viewport-fit=cover` to the viewport meta, then `padding: max(<base>, env(safe-area-inset-left))` (and the other three insets) so content clears the sensor housing without losing its baseline padding |
| A grid/flex track overflows the viewport because of one long unbreakable child (URL, image, `<pre>`) | Items default to `min-width: auto` ≈ their `min-content` size, so the track cannot shrink below the child. Use `minmax(0, 1fr)` for the track or `min-width: 0` on the item |
| A media query overrides `position` (`sticky` → `static`) on a container a third-party SDK (Kakao/Google map, a chat or payment widget) mounts into | Reset the inset properties in the same override: `top: auto; right: auto; bottom: auto; left: auto` (and `z-index` when set). Under `position: static` those declarations are inert, but the SDK sets an inline `style="position:relative"` on its container, and an inline declaration beats any author-stylesheet rule — the dormant `top` then applies as a live relative offset. A static preview without the SDK never shows it, so verify with the SDK mounted at the mobile width |
| A flex row holds a text label plus a pill/badge in CJK (Korean/Japanese/Chinese) and a restyle adds horizontal padding or `min-height` to the row | CJK text has a break opportunity between any two characters under the default `word-break: normal`, so a pill that lost a few px to the new padding wraps into a vertical stack of characters instead of overflowing — and every computed-style check (radius, color, height) still passes. In the same change give the pill `white-space: nowrap; flex-shrink: 0` and the label `flex: 1; min-width: 0` (with the ellipsis/overflow the design wants), then measure the row in a real browser with the actual label strings before approving |
| The layout passes but still "reads AI-generated" | Responsiveness is the floor, not the design — apply [frontend-design-anti-slop-visual-design] (its narrow-viewport row assumes this page's overflow fixes) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Copy breakpoints from a device list (375/768/1024/…) | Derive each breakpoint from where this content's layout fails | Device catalogs churn; content-driven breakpoints are fewer and don't rot |
| Add `maximum-scale=1` to stop iOS input-focus zoom | Set the input's `font-size` to ≥16px so iOS has no reason to zoom | The attribute blocks low-vision zoom (WCAG ≥2×) and iOS ignores it since iOS 10 anyway |
| Write one media query per column count for a card grid | `repeat(auto-fit, minmax(<min>, 1fr))` | The intrinsic grid covers every width, including ones you didn't test |
| Give a track a fixed-px minimum: `minmax(200px, 1fr)` on a container that can be <200px | `minmax(0, 1fr)` plus `min-width` on the content that truly needs it | The px floor forces horizontal overflow on viewports narrower than the sum of floors |
| Override only `position` in the mobile media query and leave the desktop `top`/`left` values in place | Reset the inset properties to `auto` in the same media-query block | A third-party script's inline `position:relative` outranks the stylesheet's `static`, so an inset left behind becomes a real offset the moment the SDK mounts |
| Approve a list-row padding or `min-height` change from computed styles or a snapshot with placeholder Latin text | Render the row with the real CJK label strings in a browser and read the pill's wrapped height | Latin labels break only at spaces; CJK breaks at every character, so the same padding change wraps the pill only in the languages the placeholder never showed |
| Fix mobile layout bugs desktop-first, per bug report | Run the 320px no-horizontal-scroll gate once and fix what it surfaces | The gate is the WCAG 1.4.10 reflow criterion — piecemeal fixes miss views nobody reported |

## Sources

- https://web.dev/articles/responsive-web-design-basics — content-driven (not device-based) breakpoints; small-screen-first workflow
- https://developer.mozilla.org/en-US/docs/Web/HTML/Guides/Viewport_meta_element — ~980px virtual viewport without the meta tag; `user-scalable=no` harm; ≥2× zoom requirement, 5× best practice
- https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html — SC 2.5.8: 24×24 CSS px AA minimum, 24px-circle spacing exception
- https://www.w3.org/WAI/WCAG21/Understanding/target-size.html — SC 2.5.5: 44×44 CSS px AAA
- https://www.w3.org/WAI/WCAG21/Understanding/resize-text.html — 1.4.4: text must resize to 200% without loss
- https://www.w3.org/WAI/WCAG21/Understanding/reflow.html — 1.4.10: no 2-D scrolling at 320 CSS px width
- https://web.dev/articles/min-max-clamp — clamp() fluid type; clamp ceiling can fail 1.4.4
- https://web.dev/patterns/layout/repeat-auto-minmax — auto-fit vs auto-fill semantics
- https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_container_queries — @container, container-type, fallback stance
- https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/img — srcset/sizes selection; width/height reserve space against layout shift
- https://developer.mozilla.org/en-US/docs/Web/CSS/min-width — `min-width: auto` → min-content minimum on grid/flex items (the overflow mechanism)
- https://developer.mozilla.org/en-US/docs/Web/CSS/length#relative_length_units_based_on_viewport — vh ≈ lvh; svh/dvh semantics
- https://developer.mozilla.org/en-US/docs/Web/CSS/@media/hover — hover:none on touch (long-tap emulation only)
- https://webkit.org/blog/7929/designing-websites-for-iphone-x/ — viewport-fit=cover + env(safe-area-inset-*) + max() pattern
- https://developer.mozilla.org/en-US/docs/Web/CSS/position — `static`: "The top, right, bottom, left, and z-index properties have no effect"; `relative`: the element is laid out in normal flow "and then offset relative to itself based on the values of top, right, bottom, and left"
- https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_cascade/Specificity — inline styles "always overwrite any normal styles in author stylesheets"; only `!important` overrides them
- https://www.w3.org/TR/css-text-3/ — for Chinese, Japanese, Yi and Korean, "line breaking conventions allow the line to break anywhere except between certain character combinations"
- https://developer.mozilla.org/en-US/docs/Web/CSS/word-break — `keep-all`: "Word breaks should not be used for Chinese/Japanese/Korean (CJK) text. Non-CJK text behavior is the same as for `normal`" — i.e. the default `normal` rule breaks CJK text between characters
- https://developer.mozilla.org/en-US/docs/Web/CSS/flex-shrink — flex items shrink by default (initial value `1`); `flex-shrink: 0` exempts the pill from negative space distribution, which is what keeps it on one line
- Field reproduction 2026-09-03 (linkly-crew, review t3-fe-feature-skins-r1 finding 1, fix in `apps/crew-app/src/features/channels/sidebar.css` `.sidebar__channel .badge`): a sidebar row restyle added horizontal padding and the Korean pill badge wrapped into a vertical stack while radius/color/height checks passed; the r2 re-review confirmed the `nowrap` + `flex-shrink: 0` / `flex: 1; min-width: 0` pair with a browser measurement
- Field reproduction 2026-08-21 (chungyak-alimi, production at 390×844 emulation, fix commit d5e119b): a Kakao Maps container carried desktop `position:sticky; top:<n>px` and a mobile override of `position:static` only; the SDK set inline `position:relative`, producing a 217px gap; forcing `position:static` in the console restored the expected 22px; adding `top:auto` to the mobile override fixed it
