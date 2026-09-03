# Analysis — wiki-model-era

<!--
Parsed by skills/wiki-plan/scripts/plan-gate.sh (gate-A). Keep section
headers exactly as shown.
-->

## Requirements
| Rule | Concrete example | Open question |
|------|------------------|---------------|
| R1: An optional frontmatter field records the model context a page's guidance was verified against; documented in AGENTS.md + templates/page.md; NOT added to structure-check REQUIRED_KEYS (absence is a signal, not an error) | Given a page with `verified_model: claude-opus-4-5` in frontmatter, when wiki-structure-checks runs, then no new finding; given a page without the field, then structure-checks still exits 0 | |
| R2: A mechanical script reports re-verification candidates: pages whose body is model-coupled (keyword match) AND (field absent OR field value matches no current-generation token) | Given a fixture page whose body says "Claude returns…" and no `verified_model`, when `node scripts/wiki-lint-model-era.js <root>` runs, then stderr lists `revalidate:<file>: model-coupled, no verified_model` and exit is 3 | |
| R3: The current-generation token set is overridable (CLI flag wins over env var over built-in default) so the default's aging never requires editing callers | Given `--current opus-4,fable-5` and a page with `verified_model: claude-sonnet-3-7`, then that page is listed; given `verified_model: claude-fable-5`, then it is not | |
| R4: wiki-lint SKILL.md gains the new check row (info severity) and the health score stays consistent (total_weight 24 → 25); the bats pin in tests/wiki-lint-score.bats is bumped in the same task | Given the updated SKILL.md, when `bats tests/wiki-lint-score.bats` runs, then all tests pass with the new `total_weight = 25` assertion | |
| R5: The new script has bats tests covering normal + error + boundary cases with fixtures (per tests/fixtures/prohibitions convention) | Given `bats tests/wiki-lint-model-era.bats`, then ≥3 cases pass incl. ≥1 error case (bad usage → exit 4) and ≥1 boundary (empty dir → exit 0) | |
| R6: No retroactive edit of the live corpus, and CI stays green: the new script is NOT added to test.yml's blocking wiki-checks step (live corpus has ~27 candidates by design) | Given the final diff, when `node scripts/wiki-structure-checks.js wiki && node scripts/wiki-lint-prohibitions.js wiki` and the full bats suite run, then rc=0 and no wiki/ page content changed | |

## Ground truth
- Baseline: bats tests/wiki-lint-score.bats tests/wiki-structure-checks.bats tests/wiki-lint-prohibitions.bats -> rc=0, HEAD 300e4bef52fb9338b7d87df4c59851e09bd6512a, git status clean

### Affected files
- scripts/wiki-lint-model-era.js (new) — evidence: `ls scripts/ | grep model-era` -> 0 hits (name free)
- tests/wiki-lint-model-era.bats (new) + tests/fixtures/model-era/ (new) — evidence: `ls tests/ tests/fixtures/` -> no model-era entries; prohibitions fixture convention confirmed (`ls tests/fixtures/prohibitions` -> bad.md, good.md)
- templates/page.md — evidence: `grep -n last_verified templates/page.md` -> 1 hit (frontmatter block to extend)
- AGENTS.md — evidence: `grep -n "### Frontmatter" AGENTS.md` -> line 116 (frontmatter schema section to extend)
- skills/wiki-lint/SKILL.md — evidence: `grep -n "total_weight = 24" skills/wiki-lint/SKILL.md` -> 1 hit (Checks table + Health score section)
- tests/wiki-lint-score.bats — evidence: `grep -n "total_weight = 24" tests/wiki-lint-score.bats` -> 1 hit (prose pin to bump)

## Constraints
- tests/wiki-lint-score.bats pins SKILL.md health-score constants (`total_weight = 24`, weight rows, `health: NN/100` format) — checked: `grep -n "total_weight" tests/wiki-lint-score.bats` -> pinned; bumping the weight requires bumping this pin in the same task (T3)
- .github/workflows/test.yml runs `node scripts/wiki-structure-checks.js wiki` and `node scripts/wiki-lint-prohibitions.js wiki` as blocking — checked: `grep -n wiki-structure-checks .github/workflows/test.yml` -> lines 44-47; the new script must NOT join this blocking step (live corpus would exit 3 by design)
- scripts/wiki-structure-checks.js REQUIRED_KEYS (line 49) must NOT gain the new field — checked: `grep -n REQUIRED_KEYS scripts/wiki-structure-checks.js`; an unknown extra frontmatter key produces no finding in that script (verified by reading its checks — only missing/duplicate/stray keys are flagged), so adding `verified_model` to fixtures/pages is compatible
- AGENTS.md is schema-layer ("change only with repo owner approval") — the repo owner requested this feature in this session

## Spikes
- Quirk-phrase detection is the wrong mechanical signal: explicit "model tends/may/will" phrasing appears on only 3 pages, while model-coupled *subject* keywords identify the real aging surface — `claude` 23 pages, `llm` 16, `subagent` 5, `opus` 2, `context window` 2, `sonnet` 1, `gpt-` 1, `hallucinat` 0; union ≈ 27 of 271 pages (10%), concentrated in wiki/platforms/tools and wiki/backend/common/llm. Verified by grep over the live corpus this session. → Detection = case-insensitive word-boundary keyword match on the body (excluding `## Sources`, same scope convention as wiki-lint-prohibitions.js).
- Exit-code conventions differ between existing scripts (prohibitions: 2 for bad dir; structure-checks: 0/3/4 documented). → Follow the newer documented 0 clean / 3 findings / 4 usage contract of wiki-structure-checks.js.
- ~27 candidates on the live corpus is an actionable list (not noise) for an info-severity report-only check; the health score counts check pass/fail, not finding count, so the score impact is bounded to the one new info check.

## Research
| Query | Source | Applied |
|-------|--------|---------|
| pruning outdated model-specific instructions CLAUDE.md steering files agent context rot model upgrade | brave-search MCP: jonkrohn.com field guide ("Treat steering files as code: owned, reviewed and pruned"), r/ClaudeCode on Opus 5 ("anything correcting model or harness specific behaviour doesn't belong… Opus 5 does not behave the same as Sonnet 5"), addyosmani.com self-improving agents (archive obsolete info; pruned knowledge files), windowsforum/Anthropic guidance (prune stale CLAUDE.md) | Confirms the feature premise: model/harness-corrective guidance ages with model generations and needs a review trigger, not silent accumulation. Grounds D2 (field records the verification-time model) and D5 (report-only info severity — pruning is a human review act, not an auto-fix) |
