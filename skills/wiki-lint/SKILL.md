---
name: wiki-lint
effort: medium
argument-hint: "[optional: changed pages]"
description: Health-check the bundled wiki. Detect unsourced claims, bare prohibitions, broken links, index and page trigger mismatches, vague qualifiers, oversized pages, and stale dates, then fix them; reports a numeric health score (0-100). Use to keep the wiki healthy before drift compounds.
---

# Lint

> **In the dev-loop plugin.** The wiki is at the plugin root
> (**`${CLAUDE_PLUGIN_ROOT}/`**). To lint-and-fix, run against a writable git
> checkout of the dev-loop repo (as `knowledge-flush` prepares), not the read-only
> installed plugin dir.

Input: none (whole-wiki pass) or a list of recently changed pages.

## Phase 0 — Discovery (read-only)

Before reporting any finding, run these read-only commands and paste their
output in the report header:

- Page/index counts: `find wiki -name '*.md' | wc -l` (split into pages vs.
  `index.md` files)
- Checker baselines: `node scripts/wiki-lint-prohibitions.js wiki` and
  `node scripts/wiki-structure-checks.js wiki`
- Recent history: `tail -5 log.md`

An assessment produced without the Phase 0 output pasted in its header is non-compliant.

## Checks

Run all of these; report findings grouped by severity.

| # | Check | Severity |
|---|-------|----------|
| 1 | Page with `confidence: verified` but empty/unverifiable `sources:` | error |
| 2 | A prohibition (`don't`/`do not`/`never`/`avoid`/`must not`) alone in its directive item (table cell or bullet), carrying no replacement action or mechanism — checked via `node scripts/wiki-lint-prohibitions.js`; `Instead of` rows must still pair the anti-pattern with its replacement | error |
| 3 | Broken `related:` id or inline link | error |
| 4 | Page not listed in its domain `index.md`, or index entry whose "load when" line no longer matches the page trigger | error |
| 5 | Vague qualifiers in directive sentences (usually, consider, might, generally, as appropriate) | warn |
| 6 | Body over 120 lines | warn |
| 7 | `confidence: unverified` older than 90 days | warn |
| 8 | `last_verified` older than 12 months on `verified` pages (docs move, defaults change) | warn |
| 9 | `contradiction` entries in `log.md` still unresolved | warn |
| 10 | `gap` entries in `log.md` with no page created after 30 days | info |
| 11 | Bare 2-word prohibition cell (e.g. `Never read`) — undecidable by shape between a state value and a real directive, so it is surfaced rather than judged; reported by `node scripts/wiki-lint-prohibitions.js` | info |

## Health score

After running all checks, compute `score = round(100 × passed_weight / total_weight)`. A check "passes" when it reports 0 findings this run. Weight by severity:

| Severity | Weight | Checks |
|----------|--------|--------|
| error | 3 | 1–4 |
| warn | 2 | 5–9 |
| info | 1 | 10–11 |

`total_weight = 24` (4×3 + 5×2 + 2×1). Report `health: NN/100 (errors E, warns W, infos I)` at the top of the report. This score never gates — no exit-code change, no blocking threshold; it exists only so two runs are comparable.

## Fix protocol

- Fix mechanical findings (3, 4, 6 splits, index lines) directly.
- For 1: fix when the correct source is known with certainty; otherwise downgrade
  to `unverified` and report it — do not invent sources.
- For 2: add the replacement action or the mechanism in place, in the same
  directive item; moving the row into `Instead of` is one option, not the required
  one. Do not invent a replacement — report it if none is known with certainty.
- For 5: rewrite the sentence as a conditional ("When X, do A") only when the
  condition is stated elsewhere in the page; otherwise report it.
- Append `## [YYYY-MM-DD] lint | <n> errors fixed, <m> reported | health NN/100` to `log.md`.
- End the report with up to 3 suggested research questions from recurring gaps.
