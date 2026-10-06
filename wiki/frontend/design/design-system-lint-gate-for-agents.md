---
id: frontend-design-design-system-lint-gate-for-agents
domain: frontend
category: design
applies_to: [tailwind, react, vue, svelte, eslint]
confidence: verified
sources:
  - https://github.com/shadcn-ui/lint
  - https://github.com/shadcn-ui/lint/blob/main/docs/evals.md
  - https://github.com/shadcn-ui/lint/blob/main/docs/adoption.md
  - https://eslint.org/docs/latest/use/suppressions
  - https://eslint.org/blog/2025/04/eslint-v9.24.0-released/
last_verified: 2026-10-06
related: [frontend-design-anti-slop-visual-design, frontend-design-product-ui-vs-brand-surface, infrastructure-ci-cd-changed-files-only-gates, infrastructure-ci-cd-write-time-limit-guards, testing-quality-checks-that-cannot-pass]
---

# A Lint Gate for Agent-Written UI in a Tailwind Design System

## When this applies

An LLM agent writes or edits UI in a project that already has a Tailwind design
system (theme tokens plus shared components such as `Button`, `Card`), and the
rules ("use tokens", "don't restyle components") exist only as prose in
`AGENTS.md`, a wiki, or a prompt. New screens drift from the system page by page,
or reviews keep finding raw colors, `p-[13px]`, and `className` overrides on
shared components.

## Do this

1. **Turn the prose rules into lint rules the agent must pass before "done".**
   For Tailwind v4 with React, Vue, or Svelte, `@shadcn/lint` provides them as an
   ESLint or Oxlint plugin. You do not need shadcn/ui to use it. Peer
   requirements in v0.2.0: `eslint >=9.30.0`, Node `>=20.19`.

| Rule | Catches |
|------|---------|
| `no-raw-colors` | Palette colors outside the theme, such as `bg-pink-500` |
| `no-arbitrary-values` | Arbitrary values, such as `p-[13px]` |
| `no-restyle` | `className` that restyles a shared component (per-component `allow`/`deny` contracts) |
| `no-inline-styles` | `style=` props and `<style>` elements |
| `no-unknown-classes` | Classes Tailwind cannot generate, such as `rounded-huge` |
| `require-static-classes` | Classes the linter cannot read, such as `` `bg-${color}` `` |

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

## Edge cases

| Case | Then |
|------|------|
| Existing codebase already has violations | Start each rule at `warn` and cap the count (`eslint . --max-warnings <current>`), or set it to `error` and record the existing violations with `eslint --suppress-rule shadcn/<rule>` per rule (bulk suppressions, ESLint ≥ 9.24, ESLint only; written to `eslint-suppressions.json`, to be committed). `--suppress-all` also hides every other error-level rule's debt. Gate on "no new violations": suppressed ones stay quiet, new ones fail ([infrastructure-ci-cd-changed-files-only-gates]) |
| An agent fixes a suppressed legacy violation | ESLint then exits non-zero for the unused suppression. Have the agent run `eslint --prune-suppressions` and commit the smaller file, or run the loop with `--pass-on-unpruned-suppressions` and prune in a separate step |
| Suppressions apply only to errors | Use the `--max-warnings` cap for rules still at `warn`; move a rule to `error` once it is clean |
| Dynamic class strings (`` `bg-${tone}` ``) are common | Enable `require-static-classes` first. The other rules cannot check a class they cannot read |
| `.vue` / `.svelte` `<style>` blocks | The plugin does not read them; use a CSS linter there |
| Vue or Svelte linted with Oxlint | Oxlint reads script blocks only, so template classes go unchecked; use the ESLint plugin for these frameworks |
| The agent passes lint by adding a variant or a theme token | Review the new variant/token as a design change: lint-clean does not approve the design. The vendor's red-team table lists "Minting a new theme token" and "Raw CSS class in `globals.css`" as escaping the rules |
| The stack is not Tailwind v4 | This plugin does not apply. Keep the same pattern (a token-only lint rule whose message names the allowed token) with a linter for that stack |

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
- Package metadata checked 2026-10-06 (`packages/lint/package.json`): `@shadcn/lint` 0.2.0, peer `eslint >=9.30.0`, `@typescript-eslint/parser >=8.40.0`, engines `node >=20.19`
