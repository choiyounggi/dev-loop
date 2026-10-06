---
id: frontend-design-design-system-lint-gate-for-agents
domain: frontend
category: design
applies_to: [tailwind, react, vue, svelte, eslint, css]
confidence: verified
sources:
  - https://github.com/shadcn-ui/lint
  - https://github.com/shadcn-ui/lint/blob/main/docs/evals.md
  - https://github.com/shadcn-ui/lint/blob/main/docs/adoption.md
  - https://eslint.org/docs/latest/use/suppressions
  - https://eslint.org/blog/2025/04/eslint-v9.24.0-released/
  - https://github.com/shadcn-ui/lint/blob/main/docs/how-it-works.md
  - https://stylelint.io/user-guide/rules/color-no-hex/
  - https://github.com/AndyOGo/stylelint-declaration-strict-value
  - https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Cascading_variables/Using_custom_properties
  - https://tailwindcss.com/docs/theme
last_verified: 2026-10-06
related: [frontend-design-anti-slop-visual-design, frontend-design-product-ui-vs-brand-surface, frontend-design-design-canvas-workflow, frontend-design-custom-property-values-read-from-script, infrastructure-ci-cd-changed-files-only-gates, infrastructure-ci-cd-write-time-limit-guards, testing-quality-checks-that-cannot-pass]
---

# A Lint Gate for Agent-Written UI in a Tailwind Design System

## When this applies

An LLM agent writes or edits UI in a project that already has a design system —
Tailwind theme tokens plus shared components such as `Button`, `Card`, or plain
CSS custom properties — and the
rules ("use tokens", "don't restyle components") exist only as prose in
`AGENTS.md`, a wiki, or a prompt. New screens drift from the system page by page,
or reviews keep finding raw colors, `p-[13px]`, and `className` overrides on
shared components.

## Do this

1. **Turn the prose rules into lint rules the agent must pass before "done".**
   For Tailwind v4 with React, Vue, or Svelte, `@shadcn/lint` provides them as an
   ESLint or Oxlint plugin. You do not need shadcn/ui to use it. Peer
   requirements in v0.2.0: `eslint >=9.30.0`, Node `>=20.19`. Pick the linter
   by styling stack:

| Stack | Linter |
|-------|--------|
| Tailwind v4 classes in React | `@shadcn/lint` on ESLint or Oxlint |
| Tailwind v4 classes in Vue/Svelte | `@shadcn/lint` on ESLint (Oxlint skips templates, see Edge cases) |
| Plain CSS, CSS modules, `.vue`/`.svelte` `<style>` blocks | stylelint: core `color-no-hex` and `color-named`, plus `scale-unlimited/declaration-strict-value` on `/color$/`, `font-size`, `border-radius` and spacing properties with per-property `ignoreValues` — `currentColor`, `inherit`, `transparent` on colors; `0`, `auto`, `none` on spacing; `0`, `50%`, `100%` on radius. The plugin flags every literal keyword and number by default, so without these lists the gate never reaches zero |
| Both in one repo | Run both; each reads files the other cannot |

| Rule | Catches |
|------|---------|
| `no-raw-colors` | Palette colors outside the theme, such as `bg-pink-500` |
| `no-arbitrary-values` | Arbitrary values, such as `p-[13px]` |
| `no-restyle` | `className` that restyles a shared component (per-component `allow`/`deny` contracts) |
| `no-inline-styles` | `style=` props and `<style>` elements |
| `no-unknown-classes` | Classes Tailwind cannot generate, such as `rounded-huge` |
| `require-static-classes` | Classes the linter cannot read, such as `` `bg-${color}` `` |

   Set `settings.shadcn.note` to the project's design source (`DESIGN.md` or the
   token file path); it is appended to every diagnostic.

2. **Feed the diagnostics back to the agent and loop until the count is 0.** Each
   diagnostic names the violating class, says why it is not allowed, and points
   to the fix — for `p-4` on `<Button>`: "Use a size (sm, lg), or margin here or
   gap on the parent for space around it. Add a size in components/ui/button.tsx
   only if the design explicitly calls for one." The agent fixes
   from that text. It does not have to work out the rule from prose.

3. **Write the allowed escape hatches as `no-restyle` contracts.** Example: a
   Button may take `w-full`, `mt-*`, `mb-*`, but not padding or radius. That
   leaves one legal way to change a component's look: add a variant or token in
   the component's own file.

4. **Check the gate on one known-bad and one known-good file before relying on
   it.** It must report on `<Button className="bg-[#FF6B35]">` and stay quiet on
   `<Button variant="brand">` ([testing-quality-checks-that-cannot-pass]).

5. **After lint is clean, run a theme-swap check.** Temporarily set the accent
   to a color absent from the design (pure magenta), screenshot every touched
   screen, restore it. A region still showing the old accent is a hardcoded value
   the linter could not trace (plain CSS, SVG `fill`, images, parent selectors).
   Swap the variable the compiled utility reads: under `@theme inline`
   (shadcn/ui's layout) `bg-primary` compiles to `var(--primary)`, so swap
   `--primary`, not `--color-primary`.

## Edge cases

| Case | Then |
|------|------|
| Existing codebase already has violations | Start each rule at `warn` and cap the count (`eslint . --max-warnings <current>`), or set it to `error` and record the existing violations with `eslint --suppress-rule shadcn/<rule>` per rule (bulk suppressions, ESLint ≥ 9.24, ESLint only; written to `eslint-suppressions.json`, to be committed). `--suppress-all` also hides every other error-level rule's debt. Gate on "no new violations": suppressed ones stay quiet, new ones fail ([infrastructure-ci-cd-changed-files-only-gates]) |
| An agent fixes a suppressed legacy violation | ESLint then exits non-zero for the unused suppression. Have the agent run `eslint --prune-suppressions` and commit the smaller file, or run the loop with `--pass-on-unpruned-suppressions` and prune in a separate step |
| Suppressions apply only to errors | Use the `--max-warnings` cap for rules still at `warn`; move a rule to `error` once it is clean |
| Dynamic class strings (`` `bg-${tone}` ``) are common | Enable `require-static-classes` first. The other rules cannot check a class they cannot read |
| `.vue` / `.svelte` `<style>` blocks | The plugin does not read them; run the stylelint row of step 1 on them |
| Vue or Svelte linted with Oxlint | Oxlint reads script blocks only, so template classes go unchecked; use the ESLint plugin for these frameworks |
| The agent passes lint by adding a variant or a theme token | Review the new variant/token as a design change: lint-clean does not approve the design. The vendor's red-team table lists "Minting a new theme token" and "Raw CSS class in `globals.css`" as escaping the rules |
| The stack is neither Tailwind v4 nor plain CSS (CSS-in-JS, another utility framework) | Keep the same pattern with that stack's linter: a token-only rule whose message names the allowed token and the file that defines it |
| Lint is clean and screens are consistent, yet the UI still reads generic | The gate enforces consistency, not taste: a default theme passed through it stays a default theme. Revisit the token values with [frontend-design-anti-slop-visual-design] or [frontend-design-product-ui-vs-brand-surface] |
| A token is read from script for canvas or charts | The lint gate does not see it; follow [frontend-design-custom-property-values-read-from-script] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Add another paragraph of design rules to `AGENTS.md` after the agent drifted again | Encode the rule as a lint rule and make lint-clean a done criterion | A prose rule is checked only when the agent remembers it; a diagnostic names the exact site and the allowed alternative, so the fix is mechanical and its result is checkable |
| Turn every rule to `error` on a legacy codebase on day one | Use bulk suppressions or a `--max-warnings` cap, then tighten | A gate that starts red on unchanged code gets turned off, not obeyed |
| Ask the agent to review its own UI against the rules text | Give it the linter's diagnostics | In the vendor's eval (one control run per model), Sonnet 5 and Opus 5 also reached zero from the rules text alone, but Haiku 4.5 left one task broken after three tries; with diagnostics all three converged in one round, and correction cost fell about 10% (Opus), 31% (Sonnet) and 48% (Haiku) |

## Sources

- https://github.com/shadcn-ui/lint — README: "agent-first linter for Tailwind design systems"; Tailwind v4, ESLint and Oxlint, React/Svelte/Vue; the six-rule table; run table (one run per model): 8/8 tasks for Sonnet 5, Haiku 4.5, Opus 5 and GPT 5.6 Terra and 6/8 for GPT 5.6 Sol, with errors 42–117 before → 0 after; "10% to 48% less" correction cost in the Claude control runs
- https://github.com/shadcn-ui/lint/blob/main/docs/evals.md — methodology: paired fresh agents, up to three correction rounds, a rules-only control; "more than 150 task runs", zero after feedback on all but two (linter bugs fixed the same day); no model used `eslint-disable` or an inline style to reach green. rules-only control costs $3.57/$1.41/$4.35 vs $2.47/$0.74/$3.93 with diagnostics (Sonnet/Haiku/Opus); "New tokens and variants still need human review. A passing lint result does not approve the design." This is a **vendor eval** on a small shadcn project, with the judge from the same model family; the doc itself says these are measurements of specific runs, not promises for every model or project
- https://github.com/shadcn-ui/lint (Frameworks table) — Oxlint: "script blocks only, warns once" for Vue and Svelte
- https://github.com/shadcn-ui/lint/blob/main/docs/adoption.md — start at `warn`, cap with `--max-warnings`, or use ESLint bulk suppressions ("They apply to errors, not warnings")
- https://eslint.org/docs/latest/use/suppressions — "While the rule will be enforced for new code, the existing violations will not be reported"; `--suppress-all` covers "all the rules that are enabled as error", `--suppress-rule` targets named rules; a fixed suppressed violation makes ESLint exit non-zero ("There are suppressions left that do not occur anymore") until `--prune-suppressions` runs or `--pass-on-unpruned-suppressions` is passed; commit `eslint-suppressions.json`
- https://eslint.org/blog/2025/04/eslint-v9.24.0-released/ — bulk suppressions introduced in v9.24.0
- https://github.com/shadcn-ui/lint/blob/main/docs/how-it-works.md — "A clean lint result does not mean every styling path was checked": parent selectors, imported class values, plain CSS and locally rebuilt components are not traced (the gap step 5 covers)
- https://stylelint.io/user-guide/rules/color-no-hex/ — core rule disallowing hex colors; `color-named` is also core
- https://github.com/AndyOGo/stylelint-declaration-strict-value — `scale-unlimited/declaration-strict-value`: variables or functions only for the named properties; by default it also flags keywords (`inherit`, `none`) and numbers (`0`, `100%`), hence the per-property `ignoreValues`
- https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Cascading_variables/Using_custom_properties — a custom property defined once reaches every `var()` reference, the mechanism step 5 relies on
- https://tailwindcss.com/docs/theme — with `@theme inline` "the utility class will use the theme variable value instead of referencing the actual theme variable", which decides the variable step 5 swaps
- Package metadata checked 2026-10-06 (`packages/lint/package.json`): `@shadcn/lint` 0.2.0, peer `eslint >=9.30.0`, `@typescript-eslint/parser >=8.40.0`, engines `node >=20.19`
