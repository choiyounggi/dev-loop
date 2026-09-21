---
id: frontend-design-custom-property-values-read-from-script
domain: frontend
category: design
applies_to: [css, javascript, jsdom]
confidence: verified
sources:
  - https://www.w3.org/TR/css-variables-1/
  - https://html.spec.whatwg.org/multipage/canvas.html
  - https://github.com/jsdom/jsdom/issues/1895
last_verified: 2026-09-21
related: [frontend-design-anti-slop-visual-design, frontend-design-html-in-canvas, testing-mocking-what-to-mock]
---

# Design-Token Values Read from Script When Tokens Alias Other Tokens

## When this applies

A helper reads a CSS custom property from script —
`getComputedStyle(el).getPropertyValue('--x')` — to feed a non-CSS consumer
(canvas `fillStyle`/`strokeStyle`, a chart library, WebGL uniforms), the token
set contains alias tokens (`--color-go: var(--color-accent)`), and the helper's
tests run under jsdom (the Jest/Vitest `jsdom` environment).

## Do this

The two environments return different strings for an alias token. A browser
returns the computed value: the CSS Variables spec defines a custom property's
computed value as the "specified value with variables substituted, or the
guaranteed-invalid value", and the guaranteed-invalid value "serializes as the
empty string". jsdom stores the declaration and returns it unsubstituted
(measured on jsdom 30.1.0, 2026-09-21):

| Declaration on `:root` | Browser `getPropertyValue` | jsdom `getPropertyValue` |
|------------------------|----------------------------|--------------------------|
| `--b: #ff0000` | `#ff0000` | `#ff0000` |
| `--a: var(--b)` | `#ff0000` | `var(--b)` |
| `--c: var(--a)` (two hops) | `#ff0000` | `var(--a)` |
| `--u: var(--missing)` | empty string | `var(--missing)` |
| `--x: var(--y)` with `--y: var(--x)` (cycle) | empty string | `var(--y)` |
| property never declared | empty string | empty string |

The jsdom string is non-empty, so an `if (!value) return fallback` guard never
fires, and the literal `var(--b)` reaches the consumer. Canvas ignores it — the
HTML spec says of `fillStyle` "Invalid values are ignored" — so the draw keeps
the previous style (black on a fresh context) with no error in either
environment's test output.

1. In the helper, treat any value that still contains `var(` as unresolved.
   Choose by what the caller needs:

   | Case | Do |
   |------|----|
   | The caller has a usable fallback colour and alias fidelity under jsdom is not asserted | Return the fallback when the trimmed value is empty **or** contains `var(` |
   | Tests assert the resolved colour of alias tokens under jsdom | Resolve the chain in the helper: match `var(--name)`, re-read `--name` from the same computed style, repeat up to a fixed hop bound (8) with a visited-set cycle guard; return the fallback when the bound or the guard trips or the target is empty |

2. Add one test per row of the table above that differs between environments:
   single alias, chained alias, undefined target, cycle. Each asserts the
   helper's return value (resolved colour or fallback), and none asserts the raw
   `getPropertyValue` string — that string is the environment's behaviour, not
   the helper's.
3. Assert the consumer's input once in a real browser (Playwright or the
   browser-mode runner) when the token feeds pixels: jsdom has no canvas
   rasterizer, so a jsdom test proves the string handed over, not the colour
   drawn.

## Edge cases

| Case | Then |
|------|------|
| Alias carries a fallback argument, `var(--b, #00f)` | The one-name regex does not match it; extend the resolver to use the fallback argument when `--b` reads empty, or return the helper's fallback and add that declaration shape to the test set |
| Value embeds the reference inside a function, `rgb(var(--r) 0 0)` | The `var(` containment check still flags it as unresolved under jsdom; take the fallback branch — substituting inside arbitrary functions is a CSS parser's job, not the helper's |
| The alias is declared on a descendant and read from `:root` | Read from the element the consumer is styled by; custom properties inherit downward only, so a `:root` read returns empty in a browser and the fallback fires correctly |
| Test environment is happy-dom or a real browser runner | Run the same four alias cases there before dropping the `var(` check — the jsdom column above was measured on jsdom only and says nothing about another DOM implementation |
| Helper caches token values at module load | Cache the resolved value, and invalidate on theme change; a cached `var(--b)` literal otherwise survives a later correct read |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Guard only with `if (!value) return fallback` | Guard on empty **or** `value.includes('var(')` | jsdom returns the unsubstituted declaration, which is truthy |
| Test the helper only with literal-valued tokens (`--b: #ff0000`) | Add the single, chained, undefined-target and cycle alias cases | Literal tokens read identically in both environments, so the suite is green while alias tokens draw black |
| Mock `getComputedStyle` to return the resolved colour | Let jsdom return its real string and assert the helper's handling of it | A mock that returns what a browser would return hides the environment difference the helper must survive ([testing-mocking-what-to-mock]) |

## Sources

- https://www.w3.org/TR/css-variables-1/ — §2: custom-property computed value is the "specified value with variables substituted, or the guaranteed-invalid value"; §2.2: that value "serializes as the empty string"; §2.3: every property in a dependency cycle is invalid at computed-value time
- https://html.spec.whatwg.org/multipage/canvas.html — `fillStyle`: "Invalid values are ignored"
- https://github.com/jsdom/jsdom/issues/1895 — "Implement CSS custom properties", open: jsdom's custom-property support is partial
- Reproduction, jsdom 30.1.0 on Node, 2026-09-21: the jsdom column of the table above is the printed output of `getComputedStyle(document.documentElement).getPropertyValue(p)` for each declaration; first observed in a Vitest jsdom environment where `--color-go: var(--color-accent)` read back as `var(--color-accent)`
