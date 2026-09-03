# wiki-model-era

Goal: The wiki gains an aging-management signal for model-generation debt: an
optional `verified_model` frontmatter field records the model a page's guidance
was verified against, and a mechanical checker reports model-coupled pages whose
field is absent or outdated as re-verification candidates in the wiki-lint
report. Acceptance: all six R-rules in analysis.md hold; live corpus unedited;
CI stays green.

Stack: Node ≥18 (repo scripts convention, no deps), bats (tests convention),
Markdown/YAML frontmatter (wiki schema).

## Decisions
| # | Decision | Choice | Wiki basis |
|---|----------|--------|------------|
| D1 | Mechanical/semantic split | Countable half in `scripts/wiki-lint-model-era.js`; semantic half in wiki-lint SKILL.md fix protocol | wiki/qa/process/llm-review-pipelines.md |
| D2 | Frontmatter field | Optional `verified_model: <model-id>` after `last_verified`; never a REQUIRED key | [no-wiki] |
| D3 | Model-coupled detection | Case-insensitive keyword set (claude, sonnet, opus, gpt-, llm, subagent, hallucinat, context window), leading boundary `(?<![A-Za-z0-9-])`, body excluding frontmatter + `## Sources` + markdown link URLs; index.md files skipped | wiki/testing/quality/guard-shape-vs-consequence.md |
| D4 | Current-generation set | CLI `--current <csv>` > env `DEV_LOOP_CURRENT_MODELS` > default `opus-4,fable-5`; current = any token is a case-insensitive substring of the field value | [no-wiki] |
| D5 | Output/exit contract + CI | Exit 0 clean / 3 candidates / 4 usage; stdout `pages: N, model-coupled: M, candidates: K`; stderr `revalidate:<file>: <reason>`; NOT in test.yml blocking step | wiki/testing/quality/checks-that-cannot-pass.md |
| D6 | SKILL.md integration | Check #12 (info), Phase 0 fourth command, `total_weight = 25`, score pins in tests/wiki-lint-score.bats bumped same task | wiki/qa/document-verification/editing-a-gated-document.md |
| D7 | Test design | Fixtures under tests/fixtures/model-era/ (mini-root per scenario); deciding assertion last per @test; ≥1 negative control per direction | wiki/testing/quality/tests-that-cannot-fail.md |
| D8 | Schema docs | AGENTS.md frontmatter block + meaning sentence; templates/page.md YAML comment line; SKILL.md is not schema authority | [no-wiki] |

## Size verdict
size: small

## Task order
| Task | Depends on | Parallel-ok |
|------|-----------|-------------|
| 01-model-era-script | — | parallel-ok with 02 |
| 02-schema-docs | — | parallel-ok with 01 |
| 03-skill-check-row | 01 | — |
