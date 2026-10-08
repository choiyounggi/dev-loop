---
id: frontend-accessibility-contrast-of-interactive-states
domain: frontend
category: accessibility
applies_to: [playwright, chromium, wcag]
confidence: verified
sources:
  - https://raw.githubusercontent.com/ChromeDevTools/devtools-protocol/master/json/browser_protocol.json
  - https://playwright.dev/docs/api/class-browsercontext
  - https://github.com/microsoft/playwright/issues/3347
  - https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
  - https://www.w3.org/TR/WCAG22/#non-text-contrast
  - https://www.w3.org/TR/css-ui-4/
  - https://www.w3.org/TR/selectors-4/
  - "Local reproduction 2026-10-08 (Playwright 1.59.1, headless Chromium 147.0.7727.15): painted vs canvas filter, forced states, swatch, ring diff, transitions"
  - "Field case 2026-10-07 (state-contrast QA of a design-system button)"
last_verified: 2026-10-08
related: [frontend-accessibility-interactive-elements, frontend-design-lightness-steps-on-dark-surfaces]
---

# Measuring Text Contrast of Hover, Focus, Active and Disabled States

## When this applies

You must prove, in a test, a review, or a QA report, that a component's text
or focus indicator meets WCAG contrast in each interactive state (hover, focus,
active, disabled), and a state changes colour through a CSS `filter`,
`opacity`, a blend mode, or an outline, so `getComputedStyle` colours are not
the painted colours. The browser is Chromium driven by Playwright.

## Do this

1. **Force each state through the Chrome DevTools Protocol.** Playwright has
   no API that forces a pseudo-class; `CSS.forcePseudoState` "Ensures that the
   given node will have specified pseudo-classes whenever its style is
   computed by the browser."

```js
const cdp = await page.context().newCDPSession(page);
await cdp.send('DOM.enable');
await cdp.send('CSS.enable');
const { root } = await cdp.send('DOM.getDocument');
const { nodeId } = await cdp.send('DOM.querySelector', { nodeId: root.nodeId, selector: '#save' });
await cdp.send('CSS.forcePseudoState', { nodeId, forcedPseudoClasses: ['hover'] });
// focus ring: ['focus', 'focus-visible']   pressed: ['active']   release: []
```

   Forcing applies to the given node only, while a real hover also matches every
   ancestor. When a state's style comes from an ancestor's state
   (`.group:hover .label`, Tailwind `group-hover:`, `li:hover > a`), force the
   state on that ancestor as well.

2. **Let transitions finish before sampling.** A forced state starts the
   element's CSS transitions like a real one. Inject
   `*{transition:none!important}` with `page.addStyleTag` for the
   measurement, or wait longer than the longest `transition-duration` plus
   `transition-delay`.

3. **Sample painted pixels from an in-memory screenshot.**
   `page.screenshot({ clip })` returns a PNG buffer; decode it in the test.

| Colour you need | Sample |
|-----------------|--------|
| Fill | A padding pixel clear of text and border |
| Label | The centre of a swatch appended inside the element for the measurement, `<span style="display:inline-block;width:8px;height:8px;background:currentColor"></span>`. It paints the text colour through the same filter and opacity; anti-aliased edge pixels blend the glyph with the fill |
| Focus ring | The pixels that differ between an unfocused and a focused screenshot of the element plus a margin. The ring of `outline-style: auto` has a browser-chosen shape and offset |

4. **Prove the pixel path with controls, then compute.** A swatch of a known
   colour with no filter must read back exactly (`deviceScaleFactor: 1`), and
   each forced state's sample must differ from the unforced sample when the
   stylesheet gives that state a different colour; an unchanged sample means
   the state's rule did not match. Then compute (L1 + 0.05) / (L2 + 0.05) from
   the sampled sRGB values: text needs 4.5:1 (3:1 for large text); an
   author-styled focus indicator needs 3:1 against adjacent colours (SC 1.4.11).

## Edge cases

| Case | Then |
|------|------|
| Disabled state | Record its ratio and keep it out of the pass/fail: components "not available for user interaction (e.g., a disabled control in HTML) are not required to meet contrast requirements" |
| The focus ring is the browser's own, unstyled (`outline-style: auto` with no author `outline` rules) | Record its ratio and keep it out of the 1.4.11 pass/fail: the SC excepts appearance "determined by the user agent and not modified by the author" |
| The state comes from a JS handler (a class added on `mouseenter` or `keydown`) | Forcing changes style matching only; drive the real interaction (`locator.hover()`, `keyboard.press('Tab')`) for that state |
| The project also runs Firefox or WebKit | CDP sessions are only supported on Chromium-based browsers; run this measurement in the Chromium project |
| Several states on one element | Force one set at a time; send `forcedPseudoClasses: []` to release before the next set |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Reproduce a state's `filter` with canvas `ctx.filter`, or by arithmetic, to get its colour | Read the painted pixel | Chromium painted `brightness(0.95)` on rgb(151,95,104) as (143,90,99); the canvas filter gave (143,90,98): the exact 98.8 is rounded when painted and truncated in canvas. In the field case the canvas route read 4.42 where painted pixels read 4.46 for the same hover state |
| Sample a glyph pixel for the label colour | Sample the appended `currentColor` swatch | Anti-aliased edges blend the text with the fill |
| Sample the focus ring at a fixed offset from the border box | Diff unfocused and focused screenshots | `outline-style: auto` lets the browser choose the ring; a fixed-offset sampler missed Chrome's ring in the field case |
| Force `hover` only on the element whose colour you read | Also force it on the ancestor an ancestor-state selector names | Forced on a child alone, `.g:hover .c` and `li:hover > a` stayed at the base colour; the sample silently measured the unhovered state |

## Sources

- https://raw.githubusercontent.com/ChromeDevTools/devtools-protocol/master/json/browser_protocol.json — `CSS.forcePseudoState`: "Ensures that the given node will have specified pseudo-classes whenever its style is computed by the browser."; parameters `nodeId` (`DOM.NodeId`), `forcedPseudoClasses` (array of string); the CSS domain depends on DOM and Page
- https://playwright.dev/docs/api/class-browsercontext — `browserContext.newCDPSession(page)`: "CDP sessions are only supported on Chromium-based browsers."
- https://github.com/microsoft/playwright/issues/3347 — "[Feature] CSS.forcePseudoState", closed 2020-11-23 with no Playwright API
- https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html — applies to "text that is shown when a pointer is hovering over an object or when an object has keyboard focus"; disabled-control exemption; contrast ratio "(L1 + 0.05) / (L2 + 0.05)"
- https://www.w3.org/TR/WCAG22/#non-text-contrast — 3:1 for "Visual information required to identify user interface components and states, except for inactive components or where the appearance of the component is determined by the user agent and not modified by the author"
- https://www.w3.org/TR/selectors-4/ — `:hover`: "An element also matches :hover if one of its descendants in the flat tree (including non-element nodes, such as text nodes) matches the above conditions."
- Local reproduction 2026-10-08 (global Playwright, headless Chromium 147.0.7727.15, computed colours): `CSS.forcePseudoState(['hover'])` on `.c` and on `a` left `.g:hover .c` and `li:hover > a` unmatched (base colour) while `.self:hover` on a forced element matched; forcing `.g` and `li` matched both; a real `page.hover()` on the child matched both
- https://www.w3.org/TR/css-ui-4/ — "The auto value permits the user agent to render a custom outline style"; "User agents may treat auto as solid."
- Local reproduction 2026-10-08 (Playwright 1.59.1, headless Chromium 147.0.7727.15, `deviceScaleFactor: 1`): a control swatch read back (151,95,104); `brightness(0.95)` painted (143,90,99) vs canvas (143,90,98). Forced `:hover` gave fill (143,90,99) and swatch (242,242,242) from (255,255,255). With `transition: filter 1s` the first read after forcing was still (151,95,104), and (143,90,99) after 1200 ms; with transitions disabled the forced colour applied at once. `['active']` gave (76,48,52) for `brightness(0.5)` and `[]` restored (151,95,104). Forcing `focus` + `focus-visible` changed 500 pixels, 288 of them outside the border box
- Field case 2026-10-07 (state-contrast QA of a design-system button, Playwright + CDP): rose hover read 4.42 from canvas emulation and 4.46 from painted pixels (reviewer's pixel value 4.463); the fixed-offset ring sampler missed Chrome's `outline-style: auto` ring, which the changed-pixel method measured at 5.76
