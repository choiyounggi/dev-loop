---
id: frontend-design-slop-detector-gate
domain: frontend
category: design
applies_to: [tailwind, react, eslint, css]
confidence: field-tested
sources:
  - https://github.com/pbakaus/impeccable/blob/f676fb4ff08eeed1e422d9869d08618819e29549/README.npm.md — binary lookup order (line 86), exit codes 0/1/2 ("no primary findings (advisories may still be listed)"), JSON mode keeps stdout a findings array
  - https://github.com/pbakaus/impeccable/blob/f676fb4ff08eeed1e422d9869d08618819e29549/README.md — detector config `detector.ignoreRules` / `ignoreFiles` / `ignoreValues` in `.impeccable/config.json`; inline `impeccable-disable`, `-line`, `-next-line` waivers
  - https://github.com/pbakaus/impeccable/blob/f676fb4ff08eeed1e422d9869d08618819e29549/crates/foundation/src/registry.rs — rule ids: side-tab (line 34), overused-font (54), gradient-text (74), ai-color-palette (84), kicker-above-heading (254); severity is fixed per rule in this registry
  - https://github.com/pbakaus/impeccable/blob/f676fb4ff08eeed1e422d9869d08618819e29549/crates/detect/src/config.rs — `advisoryRules` accepts only "include" or "exclude" (line 114), not a rule list
  - https://github.com/pbakaus/impeccable/blob/f676fb4ff08eeed1e422d9869d08618819e29549/crates/core/src/checks/rules.rs#L1632 — `if !tp.is_empty() && tp != "all" && tp != "none"`: `transition-all` never triggers the layout-transition check
  - https://github.com/pbakaus/impeccable/blob/f676fb4ff08eeed1e422d9869d08618819e29549/crates/foundation/src/findings.rs — JSON finding fields `antipattern`, `severity`, `file`, `line`
  - https://github.com/schoero/eslint-plugin-better-tailwindcss/blob/main/docs/rules/no-restricted-classes.md — `restrict` option (`pattern`/`message`/`fix`), "Make sure to match possible variants and modifiers"
  - https://github.com/schoero/eslint-plugin-better-tailwindcss/blob/main/docs/settings/settings.md — `entryPoint` for Tailwind v4
  - the local hallmark skill lists 58 slop gates in `slop-test.md`: gate 1 (Inter display font), gate 2 (purple-to-blue gradient; atmospheric allows radial background gradients, no genre allows gradient text), gate 7 (modern-minimal allows pure `#fff` paper), gates 10/11 (`transition-all`; uniform hover-scale across multiple unrelated elements), gate 30 (emoji as feature icon)
last_verified: 2026-10-06
related: [frontend-design-anti-slop-visual-design, frontend-design-product-ui-vs-brand-surface, frontend-design-design-system-lint-gate-for-agents, infrastructure-ci-cd-changed-files-only-gates, infrastructure-ci-cd-write-time-limit-guards]
---

# A Deterministic Gate for AI-Slop Tells

## When this applies

Encoding the tells tables in [frontend-design-anti-slop-visual-design] or the local
hallmark skill's `slop-test.md` as a mechanical check instead of an agent re-reading
prose; the lint gate in [frontend-design-design-system-lint-gate-for-agents] is clean
but the UI still reads generic; deciding which tells a tool catches versus which stay
LLM judgment; setting up a pre-merge check for gradient text, `transition-all`, uniform
`hover:scale-105`, emoji-as-icon, or an Inter-only font stack.

## Do this

1. **Pick the severity per tell from this trial.** Fixture: Vite + `@tailwindcss/vite`,
   one known-bad page carrying each tell once plus an `md:`-prefixed form, one
   known-good page with the same content and no tells; `impeccable` 4.1.0,
   `eslint-plugin-better-tailwindcss` 4.9.0. No tool produced a false positive on the
   known-good page for any of the 11 tells (`side-tab`, outside the table, did; see Edge cases).

| # | Tell | Impeccable (source + URL) | better-tailwindcss pattern | Severity |
|---|------|---------------------------|----------------------------|----------|
| 1 | Gradient text | hit, `gradient-text` (checks clip + gradient together) | `bg-clip-text` alone: over-matches solid/image text fills | error, via Impeccable |
| 2 | Purple→blue gradient | hit, `ai-color-palette` | hit | warn: gate 2 lets atmospheric themes use radial background gradients; neither tool tells radial from linear |
| 3 | `transition-all` | miss (excluded in source) | hit | error, via better-tailwindcss |
| 4 | `hover:scale-105` | miss | hit, including one deliberate use | warn: gate 11 targets the uniform use across unrelated elements; a class pattern cannot count elements |
| 5 | Emoji as feature icons | miss | miss (text, not a class) | judgment |
| 6 | Italic `<em>` in a sans `<h1>` | miss | miss | judgment |
| 7 | Uppercase eyebrow above a heading | hit, `kicker-above-heading` | miss (needs the next element) | warn: ordinal content is allowed |
| 8 | Three equal icon/heading/body cards | miss | miss | judgment |
| 9 | `min-h-screen` centered hero | miss | miss | judgment |
| 10 | Inter-only font stack | hit, `overused-font` (CSS text and rendered) | only when the font is set by a class the pattern names | warn: Operate surfaces allow one tuned sans |
| 11 | Pure `#000` or `#fff` as a base color | miss | hit with `text-black` / `bg-white` patterns | warn: gate 7 allows `#fff` paper; a `bg-white` ban also flags legitimate white surfaces |

   The false-positive evidence is one hand-written known-good page. Before promoting a
   `warn` row to `error` in a project, run the rule over that project's existing
   well-designed screens and require zero hits.

2. **Configure better-tailwindcss as two ESLint runs.** ESLint sets severity per rule,
   not per `restrict` pattern, so the error patterns and the warn patterns need
   separate config files. Prefix every pattern with `(.*:)?`: an anchored
   `^hover:scale-105$` missed `md:hover:scale-105` on the trial fixture.

   ```js
   // eslint.slop.config.mjs — the blocking run (add your TS/JSX parser setup)
   import betterTailwindcss from 'eslint-plugin-better-tailwindcss';
   export default [{
     files: ['**/*.{jsx,tsx,html}'],
     plugins: { 'better-tailwindcss': betterTailwindcss },
     settings: { 'better-tailwindcss': { entryPoint: 'src/index.css' } },
     rules: { 'better-tailwindcss/no-restricted-classes': ['error', { restrict: [
       { pattern: '^(.*:)?transition-all$', message: 'Name the transitioned properties.' },
     ] }] },
   }];
   // eslint.slop-warn.config.mjs — same shape, severity 'warn', patterns:
   //   '^(.*:)?hover:scale-105$', '^(.*:)?(from|via|to)-(purple|violet|indigo|fuchsia)-\\d+(\\/\\d+)?$',
   //   '^(.*:)?text-black$', '^(.*:)?bg-white$'
   ```

   Run `eslint -c eslint.slop.config.mjs <changed files>` as the gate and
   `eslint -c eslint.slop-warn.config.mjs <changed files>` as a report that does not fail.
   Without the `files` key, ESLint 9 applies the config to `.js`/`.mjs`/`.cjs` only and
   the gate passes on `.tsx` with nothing checked. The patterns are a floor:
   `transition-all!`, `group-hover:scale-105` and `hover:scale-110` still pass them.
3. **Run Impeccable and gate on rule ids, not on its exit code.** Impeccable fixes each
   rule's severity in its registry, and `advisoryRules` only accepts `"include"` or
   `"exclude"`, so a warn-row rule cannot be downgraded in config. Run
   `npx impeccable detect --json <changed files> <dev-server url> > impeccable.json`.
   Exit 1 means a target could not be scanned: fail the gate. Exit 0 or 2: fail only
   when `jq -e '[.[] | select(.antipattern == "gradient-text")] | length == 0'
   impeccable.json` exits non-zero, and print the other findings as warnings. Run both
   modes: on the trial, URL mode also reported `low-contrast` and
   `body-text-viewport-edge`, which the source scan could not see.
4. **Waive a single finding in place.** For Impeccable, add an
   `impeccable-disable-next-line <rule>: <reason>` comment, or list the rule or file
   under `detector.ignoreRules` / `detector.ignoreFiles` in `.impeccable/config.json`.
   For ESLint, use `eslint-disable-next-line` with a reason.
5. **Gate changed files only** ([infrastructure-ci-cd-changed-files-only-gates]); on a
   codebase with existing hits, record a baseline and gate on "no new violations"
   ([infrastructure-ci-cd-write-time-limit-guards]).
6. **Send the judgment tells (5, 6, 8, 9) and hallmark's judgment-only gates to LLM
   review** (`/design-review`, `hallmark audit`) as advisory findings. No tool in the
   trial caught them.

## Edge cases

| Case | Then |
|------|------|
| The surface is Operate (dashboard, admin, settings) — [frontend-design-product-ui-vs-brand-surface] | Drop tell 10 from the warn report there: that page's Operate rows call for one well-tuned sans and permit system fonts. Keep the other rows |
| The theme is atmospheric or modern-minimal | Keep tells 2 and 11 at `warn` for that theme: radial background gradients and pure `#fff` paper are its named genre exceptions |
| An eyebrow labels ordinal content (step 1 of 3) | Keep tell 7 at `warn`; 1-2 per page is allowed by [frontend-design-anti-slop-visual-design] |
| Impeccable's `side-tab` fires on a deliberate one-sided accent border | Leave `side-tab` out of the blocking jq filter and report it as a warning; on the trial it fired on the known-good page's `border-l-2` accent in both modes |
| A codebase already has hits for an error-row rule | Start that rule in the warn config with a count cap, as in the lint gate's first edge case ([frontend-design-design-system-lint-gate-for-agents]) |

## Sources

- Impeccable at commit `f676fb4`: README.npm.md (lookup order, exit codes, JSON mode), README.md (detector config, inline waivers), `registry.rs` (rule ids and fixed severity), `config.rs` (`advisoryRules` values), `rules.rs` line 1632 (`transition-all` exclusion), `findings.rs` (JSON fields). URLs in frontmatter.
- eslint-plugin-better-tailwindcss docs: `no-restricted-classes` and `entryPoint` settings.
- The local hallmark skill's `slop-test.md`, gates 1, 2, 7, 10, 11, 30.
- Trial run 2026-10-06 (this page's table): fixture outputs are recorded in the PR that added this page.
