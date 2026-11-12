---
id: frontend-design-polish-values-for-product-ui
domain: frontend
category: design
applies_to: [css, tailwind, react]
confidence: unverified
sources:
  - https://github.com/jakubkrehel/skills/blob/8b254eb75dadf3615a6abce87aed28e1b6e4d77c/skills/better-ui/SKILL.md
  - https://github.com/jakubkrehel/skills/blob/8b254eb75dadf3615a6abce87aed28e1b6e4d77c/skills/better-typography/SKILL.md
  - https://github.com/jakubkrehel/skills/blob/8b254eb75dadf3615a6abce87aed28e1b6e4d77c/skills/better-layout/SKILL.md
  - https://github.com/jakubkrehel/skills/blob/8b254eb75dadf3615a6abce87aed28e1b6e4d77c/skills/better-colors/SKILL.md
  - https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/length
  - https://developer.mozilla.org/en-US/docs/Web/CSS/font-variant-numeric
last_verified: 2026-11-12
related: [frontend-design-product-ui-vs-brand-surface, frontend-design-anti-slop-visual-design, frontend-design-rendered-ui-gate-for-agent-built-screens, frontend-design-interface-copy-for-actions-and-confirmations, frontend-design-responsive-layout]
---

# Exact Polish Values for a Product UI Screen

## When this applies

You are polishing or reviewing a product (Operate) screen, such as a dashboard,
settings page, table or form, and need concrete values for press feedback, motion,
nested radii, type weight and leading, group spacing and color roles, instead of
"make it feel nicer". The surface choice itself is
[frontend-design-product-ui-vs-brand-surface]; this page supplies the numbers.

## Do this

Use these values where the project has no token for the same thing. When a token
exists (a hallmark `--dur-*` / `--ease-*` set, a design-system scale), keep the token
and change its value only when the row below names a measurable defect.

| Concern | Value |
|---------|-------|
| Button press | `transform: scale(0.96)` on `:active` over `150ms` `ease-out`; a disabled button does not scale (`enabled:active:scale-[0.96]` in Tailwind) |
| Frequent feedback (keystroke, row hover, tab switch) | Instant, or a transition of `150ms` or less on `opacity` or `background-color` only |
| Staged entrance of an infrequent reveal whose order carries hierarchy | Split into title, description, actions; stagger `100ms`; each enters with opacity, `4px` blur and `12px` `translateY` over `300ms` `ease-out`. Routine interactions get no stagger |
| Exit | Opacity, `4px` blur and a fixed `-12px` `translateY` over `150ms` `ease-out`; never animate by the full container height |
| Nested surfaces with an even inset | Outer radius = inner radius + padding + border width; past `24px` of padding, treat them as separate surfaces with independent radii |
| Content images | A `1px` outline inset by `1px`: `oklch(0 0 0 / 0.1)` in light mode, `oklch(1 0 0 / 0.1)` in dark |
| Text weight | `400` or heavier below `18px`; weights `100`-`300` only at `28px` and up |
| Line height (unitless) | Display `1.1`, headings `1.2`-`1.3`, body `1.5`-`1.6` |
| Measure | 60-75 characters per line for long-form text |
| Changing numbers | `font-variant-numeric: tabular-nums` on timers, counters, prices and numeric columns; leave figures in prose proportional |
| Font features | Use the property (`font-weight: 650`, `font-variant-numeric`), not `font-variation-settings` / `font-feature-settings`, so a non-variable fallback still renders it |
| Group spacing | The gap between groups is at least 2x the gap inside one (`8px` inside means `16px` or more between) |
| Adjacent controls without a density system | `12px` between bordered or filled controls; `24px` between the visible glyphs of borderless text or icon controls |
| Full-width and full-height panes | `width: 100%` instead of `100vw` (it includes the scrollbar); `100dvh` instead of `100vh` on mobile full-height panes |
| Color roles | One color, one purpose; hues within `15°` of OKLCH hue count as the same color, so move a status hue 15° or more from the accent, or give the destructive action a distinct treatment |
| White text on a Tailwind `500` fill | Measure it; when it fails 4.5:1, move the fill to `600` |

Then run [frontend-design-rendered-ui-gate-for-agent-built-screens]: these values do
not prove the screen renders each state correctly.

## Edge cases

| Case | Then |
|------|------|
| The screen is an Operate surface that loads straight into the task | Skip the staged entrance on page load, as [frontend-design-product-ui-vs-brand-surface] requires; keep it for a panel or dialog the user opens |
| A staged entrance on an Operate surface | Shorten each element's entrance from `300ms` to `250ms`, the ceiling of [frontend-design-product-ui-vs-brand-surface]'s 150-250 ms state-motion row; keep the `100ms` stagger |
| `prefers-reduced-motion: reduce` | Drop the blur and translate; keep an opacity change of `150ms` or less, or none |
| A component library already scales on press (`active:scale-95`) | Change it to `0.96` only when you own the component; a library default you do not own stays, recorded as a known deviation |
| The project ships hallmark tokens (`--dur-micro: 120ms`, `--ease-out: cubic-bezier(0.16, 1, 0.3, 1)`) | Keep them and use one easing set per screen: `120ms` sits inside the 150 ms feedback ceiling |
| Padding is deliberately asymmetric | The concentric-radius rule does not apply; pick each radius on its own |

## Sources

- jakubkrehel/skills at 8b254eb (MIT, Jakub Krehel): `better-ui` (press `0.96` / `150ms`,
  feedback `150ms` or less, stagger and exit values, concentric radius with the `24px`
  cutoff, image outline), `better-typography` (weights, unitless leading, 60-75
  characters, `tabular-nums`, properties over raw feature tags), `better-layout` (2x
  group gap, `12px` / `24px` control spacing, `100vw` and `100vh` replacements),
  `better-colors` (one color per purpose within `15°`, Tailwind `500` to `600`).
- MDN viewport-percentage lengths (`dvh`) and `font-variant-numeric`.
- Field context, 2026-11-12: one settings screen redesigned three ways. The arm that
  applied these skills passed 11 of 13 rendered checks against 10 of 13 for no skill;
  its two misses were a 320 px table overflow and a measure of 96 characters.
