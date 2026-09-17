---
name: wiki-lint
effort: medium
argument-hint: "[optional: changed pages]"
description: Health-check the bundled wiki. Detect unsourced claims, bare prohibitions, broken links, index and page trigger mismatches, vague qualifiers, oversized pages, stale dates, and model-era re-verification candidates, then fix them; reports a numeric health score (0-100). Use to keep the wiki healthy before drift compounds.
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
  `node scripts/wiki-structure-checks.js wiki` (a second stdout line `warnings: K`
  is the lifecycle chain count — report it, it does not change the exit code)
- Model-era candidates: `node scripts/wiki-lint-model-era.js wiki` (report-only;
  exit 3 with candidates is the normal live-corpus state, not a failure)
- Recent history: `tail -5 log.md`

An assessment produced without the Phase 0 output pasted in its header is non-compliant.

## Checks

Run all of these; report findings grouped by severity.

| # | Check | Severity |
|---|-------|----------|
| 1 | Page with `confidence: verified` but empty/unverifiable `sources:` | error |
| 2 | A prohibition (`don't`/`do not`/`never`/`avoid`/`must not`) alone in its directive item (table cell or bullet), carrying no replacement action or mechanism — checked via `node scripts/wiki-lint-prohibitions.js`; `Instead of` rows must still pair the anti-pattern with its replacement | error |
| 3 | Broken `related:` id or inline link | error |
| 4 | Active page (`status` absent or `active`) not listed in its domain `index.md`, or index entry whose "load when" line no longer matches the page trigger | error |
| 5 | Vague qualifiers in directive sentences (usually, consider, might, generally, as appropriate) | warn |
| 6 | Body over 120 lines | warn |
| 7 | `confidence: unverified` older than 90 days | warn |
| 8 | `last_verified` older than 12 months on `verified` pages (docs move, defaults change) | warn |
| 9 | `contradiction` entries in `log.md` still unresolved | warn |
| 10 | `gap` entries in `log.md` with no page created after 30 days | info |
| 11 | Bare 2-word prohibition cell (e.g. `Never read`) — undecidable by shape between a state value and a real directive, so it is surfaced rather than judged; reported by `node scripts/wiki-lint-prohibitions.js` | info |
| 12 | Model-coupled page (body references model/LLM behavior) whose `verified_model` frontmatter is absent or outside the current model generation — a re-verification candidate, report-only; detected by `node scripts/wiki-lint-model-era.js` (override the current set with `--current <csv>` or `DEV_LOOP_CURRENT_MODELS`) | info |
| 13 | `status` value outside `active` / `superseded` / `retired` (an absent key reads as `active`), or `status: superseded` without a `superseded_by` that resolves to an existing page id — reported by `node scripts/wiki-structure-checks.js` as `bad-status` / `bad-superseded-by` | error |
| 14 | Page with `status: superseded` or `retired` still listed in its domain `index.md` — `listed-inactive` from `node scripts/wiki-structure-checks.js`; the file stays on disk, only the index row is removed | error |
| 15 | `superseded_by` target is itself superseded or retired — a chain to walk, allowed but surfaced; `superseded-chain` on stderr plus a `warnings: K` stdout line from `node scripts/wiki-structure-checks.js`, exit code unchanged | warn |
| 16 | Bundled `wiki/**` page carrying a non-empty `reference_impl:` (the field is `wiki-local/**` only) — `reference-impl-bundled` from `node scripts/wiki-structure-checks.js` | error |
| 17 | `wiki-local/**` page whose `reference_impl:` path is absolute, escapes the project, or does not exist under the project root (the parent of `wiki-local/`) — `reference-impl-missing` on stderr plus the `warnings: K` stdout line, exit code unchanged; run the checker over the local layer with `node scripts/wiki-structure-checks.js wiki-local --layer local` from the project root | warn |

## Health score

After running all checks, compute `score = round(100 × passed_weight / total_weight)`. A check "passes" when it reports 0 findings this run. Weight by severity:

| Severity | Weight | Checks |
|----------|--------|--------|
| error | 3 | 1–4, 13, 14, 16 |
| warn | 2 | 5–9, 15, 17 |
| info | 1 | 10–12 |

`total_weight = 38` (7×3 + 7×2 + 3×1). Report `health: NN/100 (errors E, warns W, infos I)` at the top of the report. This score never gates — no exit-code change, no blocking threshold; it exists only so two runs are comparable.

## Fix protocol

- Fix mechanical findings (3, 4, 6 splits, index lines) directly.
- For 1: fix when the correct source is known with certainty; otherwise downgrade
  to `unverified` and report it — do not invent sources.
- For 2: add the replacement action or the mechanism in place, in the same
  directive item; moving the row into `Instead of` is one option, not the required
  one. Do not invent a replacement — report it if none is known with certainty.
- For 5: rewrite the sentence as a conditional ("When X, do A") only when the
  condition is stated elsewhere in the page; otherwise report it.
- For 12: report-only — never stamp `verified_model` without actually
  re-verifying the page's directives against a current-generation model; after
  re-verifying, update `verified_model` + `last_verified` together, or
  rewrite/retire the guidance that no longer applies.
- For 13–14: fix mechanically — set the missing or dangling `superseded_by` to the
  live successor's id, or remove the inactive page's index row; keep the file. For
  15: report the chain; repoint `superseded_by` at the live end of the chain only
  when the intermediate page's body says the replacement carried over.
- Append `## [YYYY-MM-DD] lint | <n> errors fixed, <m> reported | health NN/100` to `log.md`.
- End the report with up to 3 suggested research questions from recurring gaps.
