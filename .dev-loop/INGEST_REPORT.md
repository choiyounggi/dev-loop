# Knowledge flush — 10 candidates: 3 new pages, 9 plan-gaps retired as local-layer

One session insight and two general lessons pulled out of plan-gap rows, each checked against official docs and a local reproduction. **3 new pages, 2 back-links, 3 index rows. 9 plan-gap rows → local layer (2 of them also fed a general page). 0 conflicts.**

| Candidate | Verdict | Page |
|-----------|---------|------|
| `4de9cb59af64dff8` (session insight) | new | `wiki/frontend/design/two-theme-computed-color-comparison.md` |
| `61e0efcc16733efe` (plan-gap t1/D8) | general part new, project part local | `wiki/frontend/design/token-mapping-under-scoped-theme-overrides.md` |
| `4d1ffb7de029e168` (plan-gap t3/D5) | general part new, project part local | `wiki/backend/node/boundaries/structured-output-schema-from-zod.md` |
| 7 other plan-gap rows | local-layer | — |

## Verified best-practice

### 1. Known-bad control for a two-theme computed-color check — `4de9cb59af64dff8` → verified

Claim: a check that renders one component in two `[data-theme]` wrappers and calls it themed when its computed colors differ cannot be failed by deleting the component's color class. `color` is inherited from the themed wrapper, and the border, outline, text-decoration, caret and column-rule colors resolve to it. The control has to make every compared property equal: the same theme in both wrappers, or inline literals.

Sources checked:

- https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/color — "Inherited yes"
- https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/color_value — "The currentColor keyword represents the value of an element's color property."
- https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/border-top-color, https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/text-decoration-color, https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/column-rule-color — "Initial value currentcolor"
- https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/outline-color, https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/caret-color — "Initial value auto"; Chrome resolved both to the element's `color`
- https://tailwindcss.com/docs/upgrade-guide — v4 changed the default border color to `currentColor`

How verified: an 8-case reproduction (playwright-core 1.63.0, Chrome 155.0.8059.39, synthetic tokens), 13 color properties compared per case:

| Case | Any-differs verdict | Must-theme list (`color`, `background-color`) |
|------|---------------------|-----------------------------------------------|
| T1 component as shipped | THEMED | PASS |
| T2 control: `bg-surface` removed | THEMED — the control cannot fail | FAIL on `background-color` |
| T3 control: every color class removed | THEMED — `color` inherited from the wrapper | FAIL on `background-color` |
| T4 control: inline literal `color`, no theme classes | UNTHEMED | FAIL |
| T5 control: inline literal `color`, `bg-surface` kept | THEMED | FAIL on `color` |
| T6 control: same theme in both wrappers | UNTHEMED | FAIL |
| T7 shipped bug: literal background, themed text | THEMED — a false pass | FAIL on `background-color` |
| T8 control: root pinned, child keeps `text-ink` | THEMED | FAIL on `background-color` |

New beyond the harvested claim: the any-differs verdict itself passes a partly hardcoded component (T7). A per-component must-theme list catches it and also lets the one-class-removed control fail (T2). Both are on the page.

### 2. Tailwind v4 token mapping under scoped theme overrides — general part of `61e0efcc16733efe` → verified

The plan-gap row is a project decision (`src/app/globals.css`). Its general content:

- use `@theme inline` when theme variables reference token variables;
- reset the default palette with `--color-*: initial`;
- give theme variables names distinct from the tokens so no variable references itself.

Source: https://tailwindcss.com/docs/theme — "When defining theme variables that reference other variables, use the `inline` option"; the `#parent`/`#child` example of where `var()` resolves; "set the entire namespace to `initial`" … "all of the default utilities that use that namespace (like `bg-red-500`) will be removed".

How verified (tailwindcss and @tailwindcss/cli 4.3.3, Chrome 155): a background agent built the fixtures; I rebuilt every fixture from its `input.css` and re-read the computed styles myself.

| Check | Result |
|-------|--------|
| `<p class="text-ink">` in a noir wrapper, plain `@theme` | `rgb(17, 17, 17)`, the `:root` ink: the wrapper's override never reaches the utility |
| Same with `@theme inline` | `rgb(238, 238, 238)`, the noir ink |
| `--color-*: initial` plus `bg-pink-500` in the markup | `pink-500` matched 0 times in the output (3 times without the reset) |
| Same-name mapping `--font-hand: var(--font-hand)`, token sheet unlayered / `layer(theme)` / `layer(base)` | Resolved to the token value in all 3, although the build emits a self-reference into `@layer theme` |
| Theme on `<html>` itself, plain `@theme` | `rgb(238, 238, 238)`: no gap when the theme sits on the root element |
| `getPropertyValue('--color-ink')` with `@theme inline`, no scanned file mentioning the name | `""`: not emitted |
| Same, with a scanned script that mentions `--color-ink` | Emitted on `:root` as `--color-ink: var(--ink)`; read inside the noir wrapper it is `#111111`, the default ink (the utility itself still shows the noir ink) |
| Token defined only under `[data-theme="noir"]`, `@theme inline`, element outside every wrapper | `rgb(0, 0, 0)` outside (inherited), `rgb(255, 102, 0)` inside; build exit 0 |

The plan's distinct-name rule did not matter in the 3 tested placements, so the page records it as an edge case: either name works there, and distinct names are the rule for any other placement.

### 3. zod schema → Claude structured outputs — general part of `4d1ffb7de029e168` → verified, one claim corrected

The plan-gap row picks `z.toJSONSchema(TraitSpecSchema)` in output mode for a later Claude call. It rejects `io: 'input'` because input mode "drops `required` and `additionalProperties: false`, which Claude structured outputs require on every object".

Sources:

- https://platform.claude.com/docs/en/build-with-claude/structured-outputs (https://docs.claude.com/en/docs/build-with-claude/structured-outputs redirects here) — supported: `enum`, `const`, `default`, "required and additionalProperties (must be set to false for objects)"; not supported: numeric and string length constraints; "required properties appear first, followed by optional properties"; "Wrap a Zod schema in zodOutputFormat() and pass it to client.messages.parse()"
- https://zod.dev/json-schema — output mode is the default; "When converting to JSON Schema in "input" mode, additionalProperties is not set."
- `@anthropic-ai/sdk` 0.131.0 source: `src/helpers/zod.ts`, `src/lib/transform-json-schema.ts`, `src/helpers/json-schema.ts`

How verified (zod 4.6.5, SDK 0.131.0, Node 26.7.0, no API calls; agent-run, then re-run by me):

| Check | Result |
|-------|--------|
| Output mode | `additionalProperties: false` on the root and nested objects; `.default()` keys in `required` |
| `io: 'input'` | No `additionalProperties`; `.default()` keys dropped from `required` |
| `.transform()` in output mode | Throws "Transforms cannot be represented in JSON Schema" |
| `zodOutputFormat()` | Output mode; forces `additionalProperties: false`; moves `enum`, `const`, `default`, `minimum`/`maximum` and `minLength`/`maxLength` into `description` |
| `parse()` of a reply with `n: 9` against `.max(8)` | Throws `AnthropicError` "Failed to parse structured output" |

Correction: Claude does not require every key in `required` (optional keys are allowed, up to 24 per request across all strict schemas: "Total optional parameters across all strict tool schemas and JSON output schemas"); it requires `additionalProperties: false`. Hand conversion needs one more step than the plan note says: output mode keeps `minimum`/`maximum`/`minLength`/`maxLength`, which the docs list as unsupported ("If you use an unsupported feature, you'll receive a 400 error with details"), so they must be removed from the sent schema. Found during verification: SDK 0.131.0's helper sends `enum`/`const`/`default` as description text although the docs list them as supported, so the request does not constrain those fields and `parse()` rejects bad values afterwards. Not exercised: sending any schema to the API (no paid calls); the page says so for the `transform: false` path.

### 4. The other 7 plan-gap rows

These are project design records with no general claim to verify. One rationale is contradicted by MDN. `36433307f92e8246` rejects CSS `steps()` animation because it "needs a data-URL PNG built in the browser, which has no zlib". MDN disagrees on both counts:

- https://developer.mozilla.org/en-US/docs/Web/API/CompressionStream/CompressionStream: `"deflate"` "Compresses the stream using the DEFLATE algorithm in ZLIB Compressed Data Format".
- https://developer.mozilla.org/en-US/docs/Web/API/HTMLCanvasElement/toDataURL produces `image/png`.

That row is flagged under Local-layer candidates.

## Existing-layer check

Pages read: frontend-design-theme-swap-propagation-check, testing-quality-tests-that-cannot-fail, backend-common-llm-completion-response-validation, frontend-design-custom-property-values-read-from-script, backend-node-boundaries-runtime-validation

How the pages were found. I grepped all of `wiki/`, took the count first, then read every hit:

- `positive control|known-bad|currentcolor|computed colou?r|data-theme` → 10 files. Only theme-swap-propagation-check compares computed colors; the rest use "known-bad" or "positive control" for lint gates, queries and spec gates.
- `tailwind|@theme` → 4 files (theme-swap-propagation-check, design-system-lint-gate-for-agents, slop-detector-gate, `frontend/index.md`). None covers mapping tokens into `@theme`.
- `zod|toJSONSchema|additionalProperties|structured output` → 8 files. None covers producing a schema for an LLM; runtime-validation covers zod at process boundaries.
- Semantic search: the `dev-loop-wiki` MCP server (`wiki_search`) failed to connect this session, so wiki-ingest step 4 ran in its documented no-tool form and there is no top-5 list.

| Candidate | Overlap found | Decision |
|-----------|---------------|----------|
| A (`4de9…`) | theme-swap-propagation-check is a different check (swap the accent by value, find hardcoded copies) and its body is at the 120-line limit; tests-that-cannot-fail holds the general "mutate what the check reads" rule | New page; links to both; back-link on theme-swap-propagation-check only (see Open-PR check) |
| B (`61e0…`) | custom-property-values-read-from-script covers reading alias tokens from script; theme-swap-propagation-check's Sources line notes the `@theme inline` compile output | New page; linked both ways with custom-property-values-read-from-script and with A |
| C (`4d1f…`) | runtime-validation covers zod at boundaries, and its "encode transforms in the parse schema" row agrees with C's step 3; completion-response-validation covers OpenAI-compatible `finish_reason` gating, a different trigger | New page; links to runtime-validation one way |

Conflicts: none. No existing directive is contradicted.

Lints run on the branch:

- `node scripts/wiki-structure-checks.js wiki/` → `pages: 362, indexes: 13, findings: 0`
- `node scripts/wiki-lint-prohibitions.js wiki/` → 0 violations (1 info row in keys-ahead-of-their-consumer.md, a page not touched here)
- `node scripts/wiki-lint-model-era.js wiki/` (report-only) → C is a new candidate ("model-coupled, no verified_model"); 36 other pages were already listed. `verified_model` is left unset on purpose: C is pinned to the API docs, SDK 0.131.0 and zod 4.6.5, and no model was called, so naming a model generation would be false.
- Body lines after the review fixes: 76 / 69 / 75 (limit 120).

## Open-PR check

22 open `knowledge/*` heads: #223, #225, #226, #227, #228, #229, #230, #231, #233, #234, #235, #236, #237, #238, #239, #241, #244, #249, #253, #254, #255, #256.

Method: `git diff --name-status origin/main...origin/<head> -- wiki/` for each head, then a count of each candidate's key terms in each head's added lines, reading every hit.

- No head adds Tailwind or `@theme` text.
- The C-term hits (#236 golden key order, #233 a `related:` id) and the A-term hits (#223, #225, #233, #235: "positive control" for hooks, timing, a bundle grep, globs) are unrelated.

Files this PR shares with open heads, and how it keeps its hunks apart:

| File | Open head's hunk | This PR |
|------|------------------|---------|
| `frontend/design/theme-swap-propagation-check.md` | #253: line 121 | Line 14 (`related:`) only |
| `frontend/index.md` | #253: line 98; #225: after 19 and 92; #244: after 43 | 2 rows inserted between lines 96 and 97 |
| `testing/quality/tests-that-cannot-fail.md` | #223: line 19 (`related:`) | Not edited; A links to it one way |
| `backend/node/boundaries/runtime-validation.md` | #233: line 10 (`related:`) | Not edited; C links to it one way |
| `backend/node/index.md` | #233: after 27; #249: after 15 | 1 row inserted before line 27 |
| `backend/index.md`, `INDEX.md` | #249: line 10; 5 heads edit `INDEX.md` | Not edited |
| `log.md`, `.dev-loop/INGEST_REPORT.md` | Every flush PR appends or replaces | Appended / replaced, as every flush does |

Verdicts:

- `4de9cb59af64dff8`: **new**.
- `61e0efcc16733efe` and `4d1ffb7de029e168`: **new** for the general part, local-layer for the project part.
- `1d79a3953022f952`, `fdcff6ff49e211a4`, `8ae1f75de4985c8f`, `c1321da32b7a6a5e`, `36433307f92e8246`, `77908e11b9bb56f5`, `a8ddd3142b6e8d24`: **drop** from the bundled layer (project-specific, see Local-layer candidates).

## Routing decision

| Page | Why here |
|------|----------|
| `frontend/design/two-theme-computed-color-comparison.md` | The mechanism is CSS inheritance and `currentcolor` inside a theming check, next to theme-swap-propagation-check; the general rule stays in testing/quality and is linked |
| `frontend/design/token-mapping-under-scoped-theme-overrides.md` | `frontend/design` holds the Tailwind and design-token pages |
| `backend/node/boundaries/structured-output-schema-from-zod.md` | The directive is specific to zod and the TypeScript SDK; AGENTS.md puts stack mechanics in the stack subtree, and `node/index.md` says "common owns the principle, these pages own the Node mechanics"; `boundaries` already owns zod at the process edge |

No new category.

## Local-layer candidates

All 9 plan-gap rows come from **linkly-invitation** (`/Users/choeyeong-gi/Desktop/workspace/linkly-invitation`, wiki-plan designs `plans/t1` and `plans/t3`). Each directive names that repository's files, contracts or constants and would be wrong in another codebase. They are excluded from this PR; run wiki-ingest inside that project to keep any of them.

| Row | Decision | Target |
|-----|----------|--------|
| `61e0efcc16733efe` | t1 D8: `src/app/globals.css` Tailwind mapping and tilt utilities | `wiki-local/frontend/design/tailwind-token-mapping.md`. General part is now bundled; the distinct-name rule is optional (a same-name mapping resolved in all 3 tested placements) |
| `1d79a3953022f952` | t1 D16: dev-only `/dev/primitives` preview route | `wiki-local/frontend/structure/dev-primitives-preview-route.md` |
| `4d1ffb7de029e168` | t3 D5: `TRAIT_SPEC_JSON_SCHEMA` | `wiki-local/backend/boundaries/trait-spec-json-schema.md`. General part is now bundled; fix the rationale (Claude allows optional keys, up to 24 per request), drop `minimum`/`maxLength`-style limits from a hand-converted schema, and record `zodOutputFormat()` as the documented path for t6 |
| `fdcff6ff49e211a4` | t3 D7: slot model and palettes | `wiki-local/frontend/design/character-slot-palettes.md` |
| `8ae1f75de4985c8f` | t3 D9: 24×32 frame, layer order, part format | `wiki-local/frontend/design/character-frame-and-layers.md` |
| `c1321da32b7a6a5e` | t3 D10: art direction as checkable rules | `wiki-local/frontend/design/character-art-rules.md` |
| `36433307f92e8246` | t3 D11: animation model | `wiki-local/frontend/design/character-animation-frames.md`. Re-check the rejected-alternative rationale first: MDN contradicts "the browser has no zlib" (Verified best-practice §4) |
| `77908e11b9bb56f5` | t3 D17: variant generation | `wiki-local/frontend/design/character-variant-generation.md` |
| `a8ddd3142b6e8d24` | t3 D19: couple presets | `wiki-local/frontend/design/couple-presets.md` |

## Review before commit

Two independent reviews ran on the uncommitted pages; every finding below is applied in this commit.

| Review | Result | Applied |
|--------|--------|---------|
| Rules + accuracy (read-only reviewer) | 8 should-fix, 6 nits, 0 blockers | All 14. Main ones: A's must-theme control works for `background-color` but not for the inherited `color` (pin `color` inline instead); the 13 compared properties are now listed; B's "When this applies" also covers the palette reset; C's hand conversion must drop unsupported limits (400 error) and `.optional()` is capped at 24 per request; array `minItems` 0/1 is kept by the helper |
| Adversarial re-test (fresh fixtures, own tokens, same versions) | A1–A4, B2–B4, C1–C3 confirmed; B1 partly refuted; 1 overreach | B1: an `@theme inline` variable IS emitted when a scanned file mentions its name, and a script then reads the `:root`-resolved default inside a wrapper. I re-measured that myself (tailwindcss 4.3.3, `source(none)` plus one `@source` script mentioning `--color-ink`: emitted; `getPropertyValue` inside the noir wrapper = `#111111`) and rewrote B's edge row, table cell, index row and log line. Its new finding, a token with no `:root` default, I also re-measured (`rgb(0, 0, 0)` outside the wrapper) and added as an edge row. Overreach: A now separates `currentcolor` (spec) from `auto` (Chrome-observed) |

After the fixes: `wiki-structure-checks` 0 findings, `wiki-lint-prohibitions` 0 violations (see the lint list above for the exact output).

## Run notes

- `hooks/auto-flush.sh` started this run. It holds the flush lock under run id `20261007-163924-67550` and exports that id to the session it spawns. Step 0 of `skills/knowledge-flush/SKILL.md` (line 36 on main) generates a fresh id instead, so the first acquire reported this run's own parent as a foreign holder (`held 20261007-163924-67550 11s`). Re-acquiring with the inherited `DEV_LOOP_FLUSH_RUN_ID` returned `already-owned`. This is the failure `infrastructure-agent-orchestration-inherited-lock-ownership-in-a-spawned-session` documents; the skill text still contains it.
