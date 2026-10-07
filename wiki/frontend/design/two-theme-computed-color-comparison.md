---
id: frontend-design-two-theme-computed-color-comparison
domain: frontend
category: design
applies_to: [css, tailwind, playwright, chrome]
confidence: verified
sources:
  - https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/color
  - https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/color_value
  - https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/border-top-color
  - https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/text-decoration-color
  - https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/column-rule-color
  - https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/outline-color
  - https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/caret-color
  - https://tailwindcss.com/docs/upgrade-guide
last_verified: 2026-10-07
related: [frontend-design-theme-swap-propagation-check, testing-quality-tests-that-cannot-fail, frontend-design-token-mapping-under-scoped-theme-overrides]
---

# Known-Bad Controls for a Check That Compares Computed Colors Across Two Theme Wrappers

## When this applies

A test or script renders one component inside two theme wrappers (`[data-theme]`
sections, or two theme classes on sibling containers) and calls it themed when its
computed colors differ between the two. You are building the known-bad control that
proves the check can fail, or a control you built still reports "themed".

## Do this

1. **Pick the control from how the check reaches its verdict.** A computed color is
   not the class that set it: `color` is inherited from the themed wrapper; the
   border, `text-decoration` and `column-rule` colors start at `currentcolor`, so they
   resolve to that `color` unless the element sets them; the `outline` and `caret`
   colors start at `auto`, which Chrome 155 also resolved to `color` here. All of them
   keep following the theme after the element's own color classes are gone.

| The check calls a component themed when | Known-bad control | Deleting one color class as the control |
|------------------------------------------|-------------------|------------------------------------------|
| Any compared property differs | Render both wrappers with the same theme (T6), or strip the theme classes and pin every compared property the element sets with an inline literal (T4) | Still THEMED (T2, T3): the control cannot fail |
| Every property on the component's must-theme list differs (e.g. `color`, `background-color`) | For a listed property the element does not inherit (`background-color`), delete its class; for an inherited one (`color`), pin it with an inline literal (T5). Require the check to name that property | Works for `background-color` (T2 fails on it); not for `color`, which the wrapper still supplies (T3 names only `background-color`) |

2. **Run the control once and require the failure** before trusting a green run on
   real components; a control that reports "themed" proves nothing about the check.
3. **Print the differing and the equal properties, not only the verdict,** so a
   control that fails to fail shows which property still followed the theme.
4. **When the check must catch a hardcoded color, use the must-theme list.** An
   any-property-differs verdict passes a component with a literal background and
   themed text (T7); the list verdict fails it on `background-color`.

Reproduction (playwright-core 1.63.0, Chrome 155, 2026-10-07): tokens `--ink` and
`--surface` redefined under `[data-theme="noir"]`; each wrapper is
`class="bg-surface text-ink"`; `.border` is `border: 1px solid` (Tailwind v4's
`border` also leaves the color at `currentColor`); 13 properties compared (`color`,
`background-color`, the four `border-*-color`, `outline-color`,
`text-decoration-color`, `caret-color`, `column-rule-color`, `fill`, `stroke`,
`box-shadow`; the last three never differed); must-theme list `color`,
`background-color`.

| Case | Any-differs verdict | Must-theme verdict |
|------|---------------------|--------------------|
| T1 shipped: `text-ink bg-surface border` | THEMED (color, background, 4 borders, outline, text-decoration, caret, column-rule) | PASS |
| T2 control: `bg-surface` removed | THEMED (color and the 8 colors that follow it) | FAIL: `background-color` equal |
| T3 control: every color class removed | THEMED (the same 9; `color` now inherited) | FAIL: `background-color` equal |
| T4 control: classes removed, inline `color: rgb(10, 20, 30)` | UNTHEMED | FAIL: both equal |
| T5 control: inline literal `color`, `bg-surface` kept | THEMED (background-color) | FAIL: `color` equal |
| T6 control: same theme in both wrappers | UNTHEMED | FAIL: both equal |
| T7 shipped bug: inline `background-color: rgb(255, 255, 255)`, `text-ink` kept | THEMED (color and 8) | FAIL: `background-color` equal |
| T8 control: root pinned inline, child keeps `text-ink`, child compared | THEMED (color and 8) | FAIL: `background-color` equal |

## Edge cases

| Case | Then |
|------|------|
| The check compares descendants as well as the root | An inline literal on the root reaches only the properties descendants inherit, so a child with its own `text-*` class stays themed (T8): pin each descendant's own compared properties with inline literals too, or use the same-theme control |
| The question is whether a token swap reached every element, not whether one component follows the theme | Use [frontend-design-theme-swap-propagation-check]: it swaps the accent by value and names each element and property that kept the old color |
| Proving that some other kind of check can fail | [testing-quality-tests-that-cannot-fail]: pick the mutation from what the check reads; this check reads computed values, not class names |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Make the known-bad control for an any-differs check by deleting the component's `bg-*` class | Render both wrappers with one theme, or pin every compared property with an inline literal | `color` and the colors that follow it still differ, so the control reports themed (T2, T3) |
| Pin `color` inline but leave the element's `bg-*` class on the control | Pin every compared property the element sets | A themed `background-color` left on the element keeps the verdict themed (T5) |
| Read "themed" from an any-differs check as "no hardcoded color" | Require each property on the component's must-theme list to differ | A literal background with themed text still reports themed (T7) |

## Sources

- https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/color — `color`: "Inherited yes"
- https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/color_value — "The currentColor keyword represents the value of an element's color property. This lets you use the color value on properties that do not receive it by default."
- https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/border-top-color, https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/text-decoration-color, https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/column-rule-color — "Initial value currentcolor"
- https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/outline-color, https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/caret-color — "Initial value auto" (caret-color: "Inherited yes"); Chrome 155 returned the element's `color` for both in the reproduction
- https://tailwindcss.com/docs/upgrade-guide — "Default border color": v3 used `gray-200`; "We've changed this to currentColor in v4"
- Local reproduction 2026-10-07 (playwright-core 1.63.0, Chrome 155.0.8059.39, macOS; synthetic tokens, ink `rgb(200, 0, 0)` vs `rgb(0, 0, 200)`): the T1–T8 table above. The harvesting session saw the same split on a real two-theme `tokens.css`: an element with only `text-ink` read a different color in each wrapper → themed; the same element under one theme on both sides → unthemed
