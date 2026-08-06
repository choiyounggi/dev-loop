# Task 02: Gate — Open-PR section, Pages-read verification, title marker

## Objective
hooks/pre-flush-pr-gate.sh (a) requires `## Open-PR check` as a 4th section,
(b) requires and verifies a `Pages read: <ids>` line against the flush
checkout's wiki (`<dirname(body-file)>/../wiki`; absent → skip verification,
0 ids → deny, unresolvable id → deny naming the id), (c) detects flush PRs
additionally via a `--title` containing `knowledge:`; all red-first tested.

## Wiki pages (read these first, only these)
- wiki/platforms/shells/command-text-inspected-before-execution.md — step 8
  (gate-author: three quoting forms; resolvable prefixes only)
- wiki/testing/quality/checks-that-cannot-pass.md — distinct outcomes per failure
  cause; prove pass AND fail directions
- wiki/testing/quality/minimum-case-set.md — case coverage

## Inputs
- hooks/pre-flush-pr-gate.sh (sites: `miss` section checks; IS_FLUSH block;
  after BODY_FILE resolution for the wiki check)
- tests/pre-flush-pr-gate.bats (`_mk_full_report`, `_run_gate` helpers)
- Decisions: D1, D2, D3, D6

## Steps
1. Red tests: (D1) report missing Open-PR section → exit 2 naming it; (D2) report
   without `Pages read:` → exit 2; `Pages read:` naming an id absent from a
   fixture wiki → exit 2 naming the id; valid ids in fixture wiki → pass; no wiki
   dir next to body-file → pass (skip); (D3) `gh pr create --title "knowledge: x"
   --body-file <missing>` with no other marker → exit 2 (gate engaged).
2. Implement: extend `_mk_full_report` in tests to include the new section +
   `Pages read:` (fixture wiki dir with matching `id:` lines under
   `$BATS_TEST_TMPDIR/repo/.dev-loop/../wiki`); gate: add 4th `grep` to `miss`;
   parse ids from the `Pages read:` line (portable grep/sed, all three quoting
   forms not needed — ids are bare tokens); resolve `WIKI_ROOT=$(dirname
   "$BODY_FILE")/../wiki`; per-id `grep -rq "^id: ${id}$"`; add
   `--title[= ]+["']?knowledge:` to IS_FLUSH.
3. Green: bats tests/pre-flush-pr-gate.bats.

## Deliverables
- hooks/pre-flush-pr-gate.sh, tests/pre-flush-pr-gate.bats

## Verify
- bats tests/pre-flush-pr-gate.bats → all pass; red-run recorded.

## Out of scope
- SKILL/prompt text (task 03); harvest (task 01).
