# Design — wiki-model-era

<!--
Parsed by skills/wiki-plan/scripts/plan-gate.sh (gate-B). Keep section
headers exactly as shown.
-->

## Decisions
| # | Decision | Choice | Wiki basis | Rejected alternative | Testability |
|---|----------|--------|------------|----------------------|-------------|
| D1 | Mechanical/semantic split for the new check | Countable half (keyword match, field presence/value) in a standalone `scripts/wiki-lint-model-era.js`; semantic half (whether a flagged page truly needs re-verification, what to rewrite) stays in wiki-lint SKILL.md's fix protocol — same split as prohibitions/structure-checks | wiki/qa/process/llm-review-pipelines.md | Prompt-prose-only check inside SKILL.md — undecidable drift, no CI-comparable output | tests/wiki-lint-model-era.bats runs the script on fixtures; SKILL.md check row names the script |
| D2 | Frontmatter field | New OPTIONAL key `verified_model: <model-id>` (single freeform id, e.g. `claude-opus-4-5`), placed after `last_verified`; NOT added to structure-checks REQUIRED_KEYS; absence on a model-coupled page = re-verification candidate signal, never an error | [no-wiki] | Overloading `last_verified` (date only) — date staleness is already check 8 and misses model-generation coupling; a `models:` list — speculative flexibility nothing consumes | R1 example: structure-checks exits 0 on pages with and without the field |
| D3 | Model-coupled page detection | Case-insensitive, word-boundary keyword set — `claude`, `sonnet`, `opus`, `gpt-`, `llm`, `subagent`, `hallucinat`, `context window` — matched over the page body EXCLUDING the `## Sources` section (scope-by-location, same exclusion wiki-lint-prohibitions.js uses); measured union ≈27/271 live pages | wiki/testing/quality/guard-shape-vs-consequence.md | Quirk-phrase regex ("model tends/may/will …") — measured 3/271 hits, misses the real aging surface (platforms/tools, backend/common/llm) | Fixture pair per Semgrep ruleid/ok split: a coupled page must be flagged, an uncoupled page and a Sources-only mention must not |
| D4 | Current-generation set + override precedence | CLI `--current <csv>` > env `DEV_LOOP_CURRENT_MODELS` (csv) > built-in default `opus-4,fable-5`; a page is current when ANY token is a case-insensitive substring of its `verified_model` value; the default lives in one documented constant at the top of the script | [no-wiki] | Hardcoded list with no override — recreates the exact aging the check exists to catch; config file — a third config surface for one value | Fixture stamped `verified_model: claude-sonnet-3-7` flips out of candidates under `--current sonnet-3`, back in under the default |
| D5 | Script output/exit contract + CI wiring | Exit 0 = no candidates, 3 = candidates, 4 = usage/unreadable root (structure-checks contract; distinct exit per outcome); stdout one summary line `pages: N, model-coupled: M, candidates: K`; stderr one line per candidate `revalidate:<file>: <reason>` where reason ∈ {`model-coupled, no verified_model`, `verified_model '<v>' not in current set`}; NOT added to test.yml's blocking wiki-checks step (live corpus carries ~27 candidates by design) | wiki/testing/quality/checks-that-cannot-pass.md | Wiring into CI blocking — permanent red on a report-only signal; boolean exit — conflates "could not run" with "found candidates" | bats: empty dir → 0, bad usage → 4, candidate fixture → 3; `git diff .github/` empty |
| D6 | wiki-lint SKILL.md integration | New check row `#12` (info severity): "model-coupled page whose `verified_model` is absent or outside the current generation — reported by `node scripts/wiki-lint-model-era.js`; re-verification candidate list, report-only"; Phase 0 gains the script as a fourth baseline command; Health score: info checks become 10–12, `total_weight = 25` (4×3 + 5×2 + 3×1); the prose pins in tests/wiki-lint-score.bats (`total_weight = 24` and Phase 0 three-command family assertion) are bumped in the SAME task | wiki/qa/document-verification/editing-a-gated-document.md | Leaving the score at 24 — Checks table and score section disagree; a new `warn` severity — a report-only candidate list is not a defect claim | bats tests/wiki-lint-score.bats green after the edit; anchor inventory greps recorded in the task |
| D7 | Test design for the new script | Fixtures under `tests/fixtures/model-era/` (convention: tests/fixtures/prohibitions); every @test puts its deciding assertion as the final command (bash 3.2 masking, issue #114 header convention); ≥1 negative control per detection direction; case set = normal (coupled+unstamped flagged) + error (usage → 4) + boundary (empty dir → 0; Sources-only mention → not flagged; stamped-current → not flagged; stamped-old → flagged; --current/env override) | wiki/testing/quality/tests-that-cannot-fail.md | Inline heredoc fixtures — diverges from the established fixture convention; corpus-dependent tests over live wiki/ — breaks on every ingest | bats tests/wiki-lint-model-era.bats — each check has a fixture that must redden it (seeded fault) |
| D8 | Schema documentation surface | AGENTS.md `### Frontmatter` block gains the `verified_model` line + one meaning sentence ("optional: the model generation the page's guidance was verified against; model-coupled pages missing it are surfaced by lint as re-verification candidates"); templates/page.md frontmatter gains the same line with a placeholder comment; wiki-lint SKILL.md is NOT the schema authority (AGENTS.md is the schema layer) | [no-wiki] | Documenting only in SKILL.md — schema truth would live in a workflow file; a new REQUIRED key — retroactively invalidates 271 pages against R6 | grep for `verified_model` in AGENTS.md + templates/page.md; structure-checks still 0 findings on live corpus |

Note on D6 arithmetic: weights are error 3×4 checks + warn 2×5 checks + info 1×3 checks = 12+10+3 = **25**; `total_weight = 25`.

`[no-wiki]` decisions (D2 wiki-schema field design, D4 override precedence, D8 schema-layer authority) are ingest candidates — genuinely uncovered conventions per the reviewer.

## Review

plan-reviewer subagent, call 1 of 1 (2026-09-03):

VERDICT: PASS
FINDINGS (all non-blocking):
- R1–R6 each map to at least one Decision row (R1→D2/D8, R2→D1/D3/D5, R3→D4, R4→D6, R5→D7, R6→D5); no uncovered rule.
- All five non-[no-wiki] Wiki basis paths exist under the wiki root and substantively support their decisions.
- [no-wiki] tags verified as genuinely uncovered conventions, not grounding dodges.
- Verified against the live repo: REQUIRED_KEYS has no unknown-key check (D2/R1 holds); exit contract 0/3/4 matches structure-checks; total_weight 24→25 arithmetic correct; test.yml blocking step confirmed limited to the two existing scripts.
- No Decision contradicts analysis.md Constraints; every Rejected alternative concretely justified (D3 backed by measured 3/271 vs 27/271 grep).
SUMMARY: All requirements covered, groundings resolve, constraints hold, baseline reproduced green. PASS.
