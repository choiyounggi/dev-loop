# wiki-audit — LLM-perspective audit of the bundled wiki + knowledge pipeline

Goal: Audit the dev-loop wiki as a production-grade knowledge base for LLM
implementation planning, across five axes, fixing defects found and filing
GitHub issues for enhancement-grade findings:
1. **Structure** — can an LLM route to the right page semantically and cheaply
   (INDEX.md → domain index "load when" lines → page trigger)?
2. **Content** — do pages give unambiguous direction (no vague qualifiers, no
   bare prohibitions, sourced claims, edge cases covered)?
3. **Category taxonomy** — are categories sufficient and unambiguous from ALL
   development perspectives; which categories are missing? (→ GitHub issues)
4. **Harvest filtering** — does the Stop-hook queue admit only wiki-grade
   material? (includes finishing the already-planned dedupe fix on this branch)
5. **Flush gates** — does knowledge-flush provably dedupe against the existing
   wiki and refine before PR; can the pre-PR gate be bypassed?

Acceptance criteria: findings documented per axis with evidence (commands + hit
counts, 0-hit stated); mechanical defects fixed on this branch with tests where
code changed; category/enhancement findings filed as GitHub issues on
choiyounggi/dev-loop; `bats tests/` green.

Stack: Bash/Node (hooks), bats (tests), gh CLI (issues), Markdown wiki.
Baseline: branch `fix/harvest-dedup-processed`, HEAD 91409d0, untracked
`plans/` + `tests/harvest.bats` (red regression test from the adopted plan).

## Decisions

| # | Decision | Choice | Wiki basis |
|---|----------|--------|------------|
| D1 | Audit rubric for structure/content | The 10 checks in `skills/wiki-lint/SKILL.md` + `AGENTS.md` format rules, run mechanically (grep/script), each finding recorded with the command and hit count; gates assert structure (table shape, bidirectional index↔page match), not keyword presence alone | qa-document-verification-spec-document-gates — "what a doc gate must assert beyond keyword presence"; audit scripts live in `.claude/tmp/` (user security policy: no /tmp) |
| D2 | Routing probe method | 15 realistic implementation scenarios spanning all 10 domains + 3 cross-domain; for each, walk INDEX.md "route here when" → domain index "load when"; verdict per probe: UNIQUE / AMBIGUOUS (≥2 equally-matching rows) / MISS (no row); AMBIGUOUS+MISS are findings | `[no-wiki]` — semantic evaluation; method fixed here so the implementer doesn't design it |
| D3 | Category-gap reference taxonomy | Compare existing categories against a fixed checklist of development concerns: requirements/planning, architecture/design, API design, concurrency, distributed systems, messaging/queues, caching, networking, observability, performance, docs/i18n, data engineering/ML, config mgmt/releases, cost, accessibility, compliance/privacy. Each unmatched concern → judged "genuine gap" vs "out of wiki charter" with 1-line rationale | `[no-wiki]` — taxonomy fixed by planner per user request "모든 개발 관점" |
| D4 | Findings routing | Mechanical defects (broken links, index drift, vague qualifiers with statable conditions, stale dates) → fix on this branch. Structural/coverage/category enhancements → `gh issue create` on choiyounggi/dev-loop, one issue per coherent theme, label `dev-loop:knowledge` not used (that's for flush PRs); use plain issues with title prefix `wiki-audit:` | `[no-wiki]` — user instruction (fix gaps; issues for 고도화) |
| D5 | Harvest dedupe fix | Adopt the existing `plans/harvest-dedupe-processed/` plan verbatim (its D1–D11 are already wiki-grounded); execute its single task 01 in this run | backend-common-jobs-idempotent-handlers (via adopted plan D1/D2) |
| D6 | Gate tests | New `tests/pre-flush-pr-gate.bats` exercising the PreToolUse gate: pass path, each missing section, empty-stub body, non-flush command untouched, missing body-file; per-test $HOME/tmp isolation, no real ~/.dev-loop touched | testing-quality-minimum-case-set (normal+error+boundary); testing-data-test-data-and-isolation (per-test tmp/env); testing-quality-checks-that-cannot-pass (target-missing vs content-missing exit semantics) |
| D7 | Harvest filter verdict scope | Audit-only findings for filter-quality gaps beyond the dedupe fix (e.g., evidence-less rows admitted, no cross-session semantic dedup at harvest time); do NOT redesign the filter in this branch — file as issues, because filter policy is a schema-layer change needing owner approval per AGENTS.md layer table | `[no-wiki]` — AGENTS.md mutability table (Workflows layer = owner approval) |
| D8 | Issue filing mechanics | `gh issue create --repo choiyounggi/dev-loop` with body containing: finding, evidence, proposed fix; one issue per theme (category gaps may bundle related categories into one issue per domain-area) | `[no-wiki]` — gh CLI per user Tool Priority policy |

## Task order

| Task | Depends on | Parallel-ok |
|------|-----------|-------------|
| 01-mechanical-lint-sweep | — | parallel-ok with 04 |
| 02-routing-probe | 01 (uses its inventory) | — |
| 03-category-taxonomy-audit | 02 (uses probe misses) | — |
| 04-harvest-dedupe-fix | — | parallel-ok with 01 |
| 05-flush-gate-tests-and-audit | 04 (shares bats conventions) | — |
| 06-issues-and-final-report | 01,02,03,05 | — |
