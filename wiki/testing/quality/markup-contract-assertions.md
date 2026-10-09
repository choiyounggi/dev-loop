---
id: testing-quality-markup-contract-assertions
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://github.com/testing-library/jest-dom#tohaveclass
  - https://developer.mozilla.org/en-US/docs/Web/API/Element/getAttributeNames
  - https://www.w3.org/TR/SVG2/styling.html#PresentationAttributes
  - https://github.com/jsdom/jsdom#unimplemented-parts-of-the-web-platform
  - https://vitest.dev/config/css
  - https://tailwindcss.com/docs/detecting-classes-in-source-files
  - https://tailwindcss.com/docs/display
  - https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/
  - https://github.com/stryker-mutator/stryker-js/blob/v10.0.0/packages/instrumenter/src/mutators/array-declaration-mutator.ts
last_verified: 2026-10-07
related: [testing-quality-tests-that-cannot-fail, testing-quality-behavior-not-implementation, testing-quality-unasserted-return-fields, testing-quality-surviving-mutant-equivalence-triage]
---

# A Presentational Component's Fixed Markup Checked With Presence Assertions

## When this applies

Unit-testing a presentational component (an icon, a decorative SVG, a styled
heading) whose spec fixes its markup — tags, attributes, class tokens, child
nodes — while the test run loads none of its stylesheet CSS (a default Vitest
run replaces CSS imports with empty strings) and jsdom renders nothing. Also when
a hand-seeded mutant that adds a class, an inline `style`, or a sibling node
survives a green suite.

## Do this

1. **Assert every element the contract names as exact sets.** A presence
   matcher passes whenever the expected part is there, so it reddens only when
   something is removed; a fixed contract also rules out additions. Per element:

| Part | Exact check | Presence check it replaces |
|------|-------------|----------------------------|
| Root | `container.childNodes.length === 1`, plus the root's tag | Finding the element with `getByRole` / `querySelector` |
| Tag | `el.tagName.toLowerCase()` equals the contract tag | — |
| Attribute names | `el.getAttributeNames().sort()` equals the sorted contract list | One `toHaveAttribute(name, value)` per expected attribute |
| Attribute values | Each contract attribute's exact value | (keep these) |
| Class tokens | `[...el.classList].sort()` equals the sorted list, or `toHaveClass('a b', { exact: true })` with each token listed once (`exact` compares a subset plus the count) | `toHaveClass('a')` |
| Children | `el.childNodes.length`, then the same checks for each child | One query for the expected child |

2. **Compare the sets sorted.** Attribute order is invisible to CSS and to the
   accessibility tree, and class selectors (`.a.b`) match tokens in any order,
   while an `innerHTML` / `outerHTML` string changes when only the order
   changes — DOM serialization follows attribute insertion order.

3. **Prove each check with an additive mutant, then with a removal.** Seed one
   mutant per part — an extra class token, an extra attribute
   (`style="fill: red"`), a sibling beside the root, an extra child — and
   require the owning test to redden ([testing-quality-tests-that-cannot-fail]
   step 2). Write these mutants by hand: no StrykerJS operator builds a JSX
   attribute or element, and its string mutator skips JSX attribute values
   such as `className="…"`. A default run changes markup only through code the
   component already runs — a branch (`{title && <title/>}` → `||` renders
   `<title>`), a dropped `filter()`/`slice()`/`charAt()`
   (`['doodle', italic && 'italic'].filter(Boolean).join(' ')` →
   `class="doodle false"`), a loop bound (`i < 3` → `i <= 3` adds a fourth
   child), a flipped boolean literal (`hidden={false}` → `hidden=""`), or a
   filled empty string or array (`className = ''` → `'Stryker was here!'`,
   `[]` → `['Stryker was here']`). JSX with no expressions gives it none of
   these, so it does not produce the token, attribute, or sibling a static
   contract excludes.

4. **Read each addition as a rendering change.** Without the stylesheet the
   test sees the inline `style` through `getComputedStyle` (jsdom also ignores
   `fill="none"` and reports `rgb(0, 0, 0)`) and the sibling's text, which
   `toBeVisible()` passes; it sees neither the class's effect nor that
   `sr-only` hides the text. A browser shows all three:

| Addition | Effect in a browser |
|----------|---------------------|
| `style` on an SVG that sets `fill="none"` | The style wins: presentation attributes enter the cascade at specificity 0, below any author CSS |
| An extra utility class (`italic`) | Tailwind generates CSS for each source token that maps to a utility it knows (`italic` does), so the token takes effect |
| A visually hidden sibling (`<span class="sr-only">`) | Hidden from sight, still read by screen readers |

## Edge cases

| Case | Then |
|------|------|
| No spec fixes the markup (a page section, a form whose classes are layout detail) | Assert behavior through roles and text ([testing-quality-behavior-not-implementation]); exact sets there redden on every refactor |
| The framework adds attributes you did not write (Vue scoped-style `data-v-*`, a test id a wrapper injects) | Name them in the contract list, or filter one exact prefix inside a single helper with the reason beside it — an unexplained filter reopens the gap |
| An added class matches no CSS rule today | Keep the check: a utility generator or a later stylesheet rule gives the token effect with no change to the component |
| Several components share one contract shape | Write one helper (`expectExactElement(el, { tag, attrs, classes, children })`), prove it once per mutant kind, then prove each component with one mutant per part |
| A mutant survives an exact check | Classify it before writing a test ([testing-quality-surviving-mutant-equivalence-triage]); an addition the contract excludes is a missing test, because the contract defines the set |
| The run loads the component's CSS (Vitest `css` enabled, or the test injects the stylesheet) | jsdom applies only unlayered rules: Tailwind v4 emits its utilities inside `@layer utilities`, which jsdom 30.1.2 skips (`italic` still reads `normal`), while a plain `.italic {}` rule reads `italic`; keep the exact sets — presentation attributes and layout stay invisible to it too |
| The test runs in a real browser (Playwright component tests) | Also assert the computed property (`getComputedStyle(el).fill`); stylesheet rules and presentation attributes are observable there, so the markup is no longer the only signal |
| The returned composite is data, not markup | The same subset blind spot applies to fields no assertion reads ([testing-quality-unasserted-return-fields]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Assert `toHaveClass('doodle')` on a component whose spec fixes its class list | `toHaveClass('doodle', { exact: true })` | The default form checks a subset, so an added token passes |
| Check `toHaveAttribute('fill', 'none')` and stop | Also compare `getAttributeNames().sort()` with the contract list | An added `style` overrides `fill` while the attribute check still passes |
| Assert only on the element a query returned | Also assert the container's child count | A sibling rendered beside the root sits outside every element-scoped assertion |
| Prove the suite with a default Stryker run alone | Add hand-seeded additive mutants for each part | Its operators change markup only through code the component already runs — a branch, a dropped `filter()`/`slice()`, a loop bound, a flipped boolean, a filled empty string or array; JSX with no expressions gives them nothing to add |
| Snapshot the whole markup to catch additions | Exact sets compared sorted | A snapshot catches additions too, but it also fixes every incidental value (path data, generated ids), and its diffs get approved unread ([testing-quality-behavior-not-implementation]); exact sets name only the contract |

## Sources

- https://github.com/testing-library/jest-dom#tohaveclass — `toHaveClass` checks "whether the given element has certain classes within its `class` attribute"; `{exact: true}` checks for "EXACTLY a set of classes" — "if it has more than expected it is going to fail" (same text in the installed 7.0.1 README)
- https://developer.mozilla.org/en-US/docs/Web/API/Element/getAttributeNames — "returns the attribute names of the element as an Array of strings"
- https://www.w3.org/TR/SVG2/styling.html#PresentationAttributes — "Presentation attributes contribute to the author level of the cascade, followed by all other author-level style sheets, and have specificity 0"
- https://github.com/jsdom/jsdom#unimplemented-parts-of-the-web-platform — lists "Layout: the ability to calculate where elements will be visually laid out as a result of CSS" as unimplemented; the README's "Pretending to be a visual browser" section adds "jsdom still does not do any layout or rendering"
- https://vitest.dev/config/css — "When excluded, CSS files will be replaced with empty strings to bypass the subsequent processing"
- https://tailwindcss.com/docs/detecting-classes-in-source-files — "Tailwind works by scanning your project for utility classes, then generating all of the necessary CSS based on the classes you've actually used", "throwing away any tokens that don't map to a utility class the framework knows about"
- https://tailwindcss.com/docs/display — "Use sr-only to hide an element visually without hiding it from screen readers"
- https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/ — removal, negation and swap operators (`ArrayLiteralItemsRemoval`, `ObjectPropertiesRemoval`, `FilledStringToEmpty`, `BlockRemoval`, `AndNegation` …); `EmptyStringToFilled` (`""` → `"Stryker was here!"`) is the only listed operator that adds content
- https://github.com/stryker-mutator/stryker-js/blob/v10.0.0/packages/instrumenter/src/mutators/array-declaration-mutator.ts — an empty array literal becomes `['Stryker was here']`; this filling case is missing from the docs table. In the same directory (v10.0.0): `string-literal-mutator.ts` skips a string whose parent is a JSX attribute; `method-expression-mutator.ts` removes `charAt`, `filter`, `reverse`, `slice`, `sort`, `substr`, `substring` and `trim` calls ("Remove the method expression"); `equality-operator-mutator.ts` maps `<` to `<=` and `>=`; none of the 21 files builds a JSX node
- Local reproduction 2026-10-07 (Node 26.7.0, jsdom 30.1.2, @testing-library/jest-dom 7.0.1 matchers called directly): contract `<svg class="doodle" fill="none" aria-hidden="true">`. Presence checks (`toHaveClass('doodle')`, two `toHaveAttribute`) passed on the contract and on all three additive mutants (extra class, `style="fill: red"`, an `sr-only` sibling); exact checks (container child count, sorted `getAttributeNames()`, `toHaveClass(…, { exact: true })`, child count) passed on the contract and failed on each mutant; a class-removal mutant failed both. Two SVGs differing only in attribute order gave unequal `outerHTML` and equal sorted name sets. `getComputedStyle(…).fill` read `rgb(0, 0, 0)` for `fill="none"` and `rgb(255, 0, 0)` for the style mutant; with a `<style>` element present an unlayered `.italic` rule read `italic`, while the same rule inside `@layer utilities` (where Tailwind 4.3.3's `index.css` puts its utilities) read `normal`. `toBeVisible()` passed on an `sr-only` span with no stylesheet. `toHaveClass('btn btn btn', { exact: true })` passed on `class="btn extra btn-danger"`
- Field evidence 2026-10-07 (linkly-invitation, two presentational components, vitest + jsdom): four test-quality-auditor FAIL verdicts were all additive mutants; after the switch to exact lists, all 11 previously surviving mutants per component failed, measured by vitest runs against byte-restored files
