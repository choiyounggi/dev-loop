# Task 01: Model-era candidate checker script with bats tests

## Objective
`scripts/wiki-lint-model-era.js` exists and mechanically reports model-coupled
wiki pages whose `verified_model` frontmatter is absent or outside the current
model generation, with a bats suite proving every detection direction.

## Wiki pages (read these first, only these)
- wiki/testing/quality/checks-that-cannot-pass.md — use for: the exit-code
  contract (distinct code per outcome; run the check against known-good input
  before adopting; predict failure modes first)
- wiki/testing/quality/guard-shape-vs-consequence.md — use for: detector scope
  narrowing (exclude by location, not by allowlist) and the seeded-fault rule
  (every check needs a fixture that must redden it)
- wiki/testing/quality/tests-that-cannot-fail.md — use for: bats assertion
  discipline (deciding assertion is the test's final command; mutation-check
  each assertion's ability to fail)
- wiki/testing/quality/minimum-case-set.md — use for: choosing the case set
  (normal + error + boundary per input dimension)

## Inputs
- scripts/wiki-structure-checks.js — the convention source: header comment
  style, walk(), frontmatter regex `^---\n([\s\S]*?)\n---`, report(),
  exit 0/3/4, summary-on-stdout/findings-on-stderr.
- tests/wiki-lint-prohibitions.bats + tests/fixtures/prohibitions/ — bats and
  fixture conventions (issue #114 header comment: deciding assertion last).
- Decisions that bind you: D3 (keyword set + scope), D4 (precedence + substring
  match + default `opus-4,fable-5`), D5 (output/exit contract), D7 (fixture
  layout).

## Steps
1. Write `scripts/wiki-lint-model-era.js` (no dependencies, Node ≥18):
   - Usage: `node scripts/wiki-lint-model-era.js <wiki-root> [--current <csv>]`.
     No root, unknown flag, `--current` without value, or unreadable root →
     usage/reason on stderr, exit 4.
   - Current set: `--current` csv if given, else env `DEV_LOOP_CURRENT_MODELS`
     csv if non-empty, else `DEFAULT_CURRENT = ['opus-4', 'fable-5']` (one
     documented constant at the top; header comment says why it is overridable).
   - Walk `<root>` recursively for `*.md`, skipping files named `index.md`.
   - Per page: frontmatter = the leading `^---\n([\s\S]*?)\n---` block if
     present; `verified_model` = trimmed value of `/^verified_model:\s*(.*)$/m`
     within it, else absent. Body = text after the frontmatter block (whole
     file when no frontmatter), minus the `## Sources` section (from
     `/^##\s+Sources\b/m` to the next `/^## /m` or EOF), minus markdown link
     targets (strip `/\(https?:[^)]*\)/g`).
   - Model-coupled = body matches
     `/(?<![A-Za-z0-9-])(claude|sonnet|opus|gpt-|llm|subagent|hallucinat|context window)/i`.
   - Candidate: coupled AND field absent → reason
     `model-coupled, no verified_model`; coupled AND field present AND no
     current-set token is a case-insensitive substring of the value → reason
     `verified_model '<value>' not in current set`.
   - Output: stdout exactly one line
     `pages: N, model-coupled: M, candidates: K`; stderr one line per candidate
     `revalidate:<file>: <reason>`; exit 3 if K>0 else 0.
2. Create fixtures, one mini-root directory per scenario (the bats test points
   the script at each subdirectory):
   - `tests/fixtures/model-era/coupled-unstamped/page.md` — minimal frontmatter
     (id/domain/category only is fine — this script reads only
     `verified_model`), body sentence mentioning Claude; plus an `index.md` in
     the same dir whose body says "claude" (proves index exclusion).
   - `tests/fixtures/model-era/coupled-stamped-current/page.md` — same body,
     frontmatter has `verified_model: claude-fable-5`.
   - `tests/fixtures/model-era/coupled-stamped-old/page.md` — same body,
     `verified_model: claude-sonnet-3-7`.
   - `tests/fixtures/model-era/uncoupled/page.md` — body with no keyword.
   - `tests/fixtures/model-era/sources-only/page.md` — keyword appears only
     inside `## Sources` (e.g. an anthropic.com/claude URL), body otherwise
     uncoupled.
   - `tests/fixtures/model-era/hyphen-id/page.md` — no frontmatter; body
     mentions `backend-common-llm-context-window-budget` only (hyphen-prefixed,
     must NOT count as coupled).
3. Write `tests/wiki-lint-model-era.bats` (header comment carries the issue
   #114 deciding-assertion-last rule, per the sibling suites). Cases, each
   against its fixture mini-root:
   - normal: coupled-unstamped → exit 3, stdout `candidates: 1`, stderr has
     `revalidate:` and `no verified_model`; index.md not listed.
   - stamped-current → exit 0, stdout `candidates: 0`.
   - stamped-old, default set → exit 3, stderr has `not in current set`.
   - stamped-old, `--current sonnet-3` → exit 0.
   - stamped-old, env `DEV_LOOP_CURRENT_MODELS=sonnet-3` → exit 0.
   - precedence: env `DEV_LOOP_CURRENT_MODELS=sonnet-3` AND
     `--current fable-5` → exit 3 (CLI wins).
   - uncoupled → exit 0, stdout `model-coupled: 0`.
   - sources-only → exit 0, stdout `model-coupled: 0`.
   - hyphen-id → exit 0, stdout `model-coupled: 0`.
   - boundary: empty directory (`mktemp -d` under `$BATS_TEST_TMPDIR`) →
     exit 0, `pages: 0`.
   - error: no args → exit 4; nonexistent root → exit 4; `--current` with no
     value → exit 4.
   - `node --check scripts/wiki-lint-model-era.js` exits 0.
4. Mutation-check per tests-that-cannot-fail: temporarily flip the coupled
   regex (e.g. require `zzz`) and require the normal case to redden, then
   restore (work is uncommitted — restore by editing back, not
   `git checkout --`).

## Deliverables
- scripts/wiki-lint-model-era.js (new)
- tests/wiki-lint-model-era.bats (new)
- tests/fixtures/model-era/ (new; the six mini-roots above)

## Verify
- `bats tests/wiki-lint-model-era.bats` → rc=0, all cases pass.
- `node scripts/wiki-lint-model-era.js wiki` on the repo corpus → exit 3, a
  summary of shape `pages: 2xx, model-coupled: ~27, candidates: ~27` (record
  the actual numbers; they are report data, not a gate).
- covers: R2, R3, R5
## Out of scope
- Any edit to skills/wiki-lint/SKILL.md, tests/wiki-lint-score.bats, or
  .github/workflows/test.yml (task 03 wires the report; CI stays untouched).
- Any edit to wiki/ pages, AGENTS.md, templates/page.md (task 02).
