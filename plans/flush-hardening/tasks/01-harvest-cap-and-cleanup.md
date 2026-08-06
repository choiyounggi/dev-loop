# Task 01: Harvest runaway backstop + empty-file cleanup

## Objective
hooks/harvest.js caps a session queue file at 10 rows total (D4) and unlinks its
own session file when it exists empty with nothing to append (D5); both behaviors
regression-tested red-first in tests/harvest.bats.

## Wiki pages (read these first, only these)
- wiki/testing/quality/minimum-case-set.md — case selection (normal/error/boundary)
- wiki/testing/quality/tests-that-cannot-fail.md — red-first; count-based assertions
- wiki/testing/data/test-data-and-isolation.md — per-test $HOME isolation

## Inputs
- hooks/harvest.js (site: the `rows` append block at the end of main(); the
  existing `_queue_lines` helper style in tests/harvest.bats)
- Decisions: D4 (cap=10, silent), D5 (unlink own empty file only), D6

## Steps
1. Red tests first: (cap) transcript with 12 distinct ★ blocks → queue has exactly
   10 lines; (cap-existing) 9 rows already present + transcript with 3 new → 10;
   (cleanup) empty s1.jsonl + no-insight transcript → file absent after run;
   (preserved) empty s1.jsonl + 1-insight transcript → file has 1 line.
2. Implement in harvest.js: before append, count existing non-blank lines in
   queueFile; append at most (10 - count) rows. After the found/dedupe logic, if
   queueFile exists, has 0 non-blank lines, and rows to append is 0 → fs.unlinkSync.
3. Green: bats tests/harvest.bats full file.

## Deliverables
- hooks/harvest.js, tests/harvest.bats

## Verify
- bats tests/harvest.bats → all pass; red-run output recorded for the new cases.

## Out of scope
- Cross-session file sweeps; SKILL.md wording (task 03); gate (task 02).
