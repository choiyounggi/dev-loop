---
name: wiki-lint
description: Health-check the bundled wiki. Detect unsourced claims, bare prohibitions, broken links, index and page trigger mismatches, vague qualifiers, oversized pages, and stale dates, then fix them. Use to keep the wiki healthy before drift compounds.
---

# Lint

> **In the dev-loop plugin.** The wiki is at the plugin root
> (**`${CLAUDE_PLUGIN_ROOT}/`**). To lint-and-fix, run against a writable git
> checkout of the dev-loop repo (as `knowledge-flush` prepares), not the read-only
> installed plugin dir.

Input: none (whole-wiki pass) or a list of recently changed pages.

## Checks

Run all of these; report findings grouped by severity.

| # | Check | Severity |
|---|-------|----------|
| 1 | Page with `confidence: verified` but empty/unverifiable `sources:` | error |
| 2 | "Don't/never/avoid" directive outside an `Instead of` table, or an `Instead of` row missing its replacement | error |
| 3 | Broken `related:` id or inline link | error |
| 4 | Page not listed in its domain `index.md`, or index entry whose "load when" line no longer matches the page trigger | error |
| 5 | Vague qualifiers in directive sentences (usually, consider, might, generally, as appropriate) | warn |
| 6 | Body over 120 lines | warn |
| 7 | `confidence: unverified` older than 90 days | warn |
| 8 | `last_verified` older than 12 months on `verified` pages (docs move, defaults change) | warn |
| 9 | `contradiction` entries in `log.md` still unresolved | warn |
| 10 | `gap` entries in `log.md` with no page created after 30 days | info |

## Fix protocol

- Fix mechanical findings (3, 4, 6 splits, index lines) directly.
- For 1 and 2: fix when the correct source/replacement is known with certainty;
  otherwise downgrade to `unverified` / move the prohibition into `Instead of` with a
  `TODO replacement` marker and report it — do not invent sources or replacements.
- For 5: rewrite the sentence as a conditional ("When X, do A") only when the
  condition is stated elsewhere in the page; otherwise report it.
- Append `## [YYYY-MM-DD] lint | <n> errors fixed, <m> reported` to `log.md`.
- End the report with up to 3 suggested research questions from recurring gaps.
