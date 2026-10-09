---
id: frontend-design-token-mapping-under-scoped-theme-overrides
domain: frontend
category: design
applies_to: [tailwind, css, chrome]
confidence: verified
sources:
  - https://tailwindcss.com/docs/theme
last_verified: 2026-10-07
related: [frontend-design-two-theme-computed-color-comparison, frontend-design-custom-property-values-read-from-script]
---

# Mapping a Token Stylesheet into Tailwind v4 When a Theme Overrides Tokens Below `:root`

## When this applies

A Tailwind v4 project keeps its design tokens as CSS custom properties in its own
stylesheet (`tokens.css`) and you are writing the `@theme` block that turns them into
utilities. Also when a theme redefines those tokens on an element below `<html>` (a
`[data-theme]` section, a theme class on a container) and a utility keeps the default
theme's value there, or when an off-token class such as `bg-pink-500` still compiles.

## Do this

1. **Map each token in `@theme inline`, referencing it with `var()`:**

```css
@import "tailwindcss";
@import "./tokens.css";
@theme { --color-*: initial; }
@theme inline {
  --color-ink: var(--ink);
  --color-surface: var(--surface);
}
```

   `inline` writes `var(--ink)` into the utility rule, so the browser resolves it on
   the element that carries the class, inside the wrapper. Plain `@theme` emits
   `--color-ink: var(--ink)` on `:root` and the utility reads `var(--color-ink)`,
   which was already resolved there against the default `--ink`.
2. **Reset each default namespace the tokens replace** (`--color-*: initial`, and the
   same form for any other namespace you map whole): the default palette then
   generates no rules, so an off-token class such as `bg-pink-500` produces nothing.
3. **Check the mapping inside two different theme wrappers**, not only in the default
   theme: there, plain `@theme` and `@theme inline` read the same `:root` value, so a
   default-theme check cannot tell them apart. The check and its known-bad controls:
   [frontend-design-two-theme-computed-color-comparison].

Measured (tailwindcss 4.3.3 CLI, Chrome 155, 2026-10-07): tokens
`:root { --ink: #111111 }` and `[data-theme="noir"] { --ink: #eeeeee }`;
`<p class="text-ink">` inside `<section data-theme="noir">`.

| Build | Declaration emitted on `:root` (`@layer theme`) | `.text-ink` rule | `color` inside the noir wrapper |
|-------|-------------------------------------------------|------------------|---------------------------------|
| `@theme { --color-ink: var(--ink); }` | `--color-ink: var(--ink);` | `color: var(--color-ink)` | `rgb(17, 17, 17)`: the `:root` ink |
| `@theme inline { --color-ink: var(--ink); }` | none for `--color-ink` while no scanned source file mentions the name (see Edge cases) | `color: var(--ink)` | `rgb(238, 238, 238)`: the noir ink |
| `@theme { --color-*: initial; }` added, `bg-pink-500` in the markup | (no `pink-500` variable) | no rule: `pink-500` matched 0 times in the output, 3 times without the reset | — |

## Edge cases

| Case | Then |
|------|------|
| The theme is set on `<html>` itself (`<html data-theme="noir">`, a `.dark` class on the root element) | Both mappings resolve on that element, so plain `@theme` also follows the theme there (measured `rgb(238, 238, 238)`); `inline` stays correct once a scoped wrapper is added |
| The theme variable has the same name as the token (`@theme inline { --font-hand: var(--font-hand); }`) | Either name works when the token sheet is imported unlayered, as `layer(theme)`, or as `layer(base)`: Tailwind emits the self-reference `--font-hand: var(--font-hand);` into `@layer theme`, the token's own `:root` declaration won, and `font-family` resolved to the token value in all three. In any other placement, give the token a name of its own (`--font-hand: var(--hand-face)`), which keeps the self-reference out of the build |
| A token is defined only under theme selectors (`[data-theme="noir"] { --accent: … }`, no `:root` value) | Give every token a `:root` default: outside every wrapper the utility has no value to read, so `text-accent` there computed to the inherited `rgb(0, 0, 0)` while the build exited 0 and nothing reported it (inside the wrapper: `rgb(255, 102, 0)`) |
| Script reads the mapped name (`getPropertyValue('--color-ink')`) | Read the token itself (`--ink`), which resolves inside the wrapper (`#eeeeee`). `@theme inline` emits `--color-ink: var(--ink)` on `:root` only when a scanned source file mentions the name (a script that reads it does), and that value resolves on `:root`: inside the noir wrapper it read `#111111`, the default ink. With no mention it is not emitted and reads `""`. Alias tokens read from script: [frontend-design-custom-property-values-read-from-script] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Map tokens with plain `@theme { --color-ink: var(--ink); }` | Use `@theme inline` | The utility reads `--color-ink`, resolved once on `:root`; a wrapper's `--ink` never reaches it (`rgb(17, 17, 17)` inside the noir wrapper) |
| Copy token values into `@theme` as literals (`--color-ink: #111111`) | Reference the token with `var()` in `@theme inline` | A literal is a second copy of the value: a wrapper's override cannot change it, and it drifts from `tokens.css` when the token is edited |
| Leave the default palette beside the token utilities | Add `--color-*: initial` | `bg-pink-500` and the other defaults keep compiling, so an off-token color renders with no error |

## Sources

- https://tailwindcss.com/docs/theme — "When defining theme variables that reference other variables, use the `inline` option"; "Using the `inline` option, the utility class will use the theme variable value instead of referencing the actual theme variable"; "This happens because `var(--font-sans)` is resolved where `--font-sans` is defined (on `#parent`), and `--font-inter` has no value there since it's not defined until deeper in the tree (on `#child`)"; "To completely override an entire namespace in the default theme, set the entire namespace to `initial` using the special asterisk syntax" and "all of the default utilities that use that namespace (like `bg-red-500`) will be removed"
- Local reproduction 2026-10-07 (tailwindcss and @tailwindcss/cli 4.3.3, playwright-core 1.63.0, Chrome 155.0.8059.39, macOS): the table and edge rows above, each fixture built with `tailwindcss -i input.css -o output.css` and read with `getComputedStyle` in Chrome
- Origin: a wiki-plan `[no-wiki]` decision gap in a Next.js 16 + Tailwind v4 app whose `tokens.css` defines two `[data-theme]` palettes; no page owned this mapping
