# Task 04: Execute the adopted harvest-dedupe-processed fix

## Objective
`hooks/harvest.js` seeds its dedupe set from `~/.dev-loop/queue/.processed.jsonl`
in addition to the session queue file, so a flushed insight is never re-queued;
the existing red regression test in `tests/harvest.bats` turns green with the full
suite passing.

## Wiki pages (read these first, only these)
- wiki/backend/common/jobs/idempotent-handlers.md — use for: processed-store
  dedupe pattern (adopted plan D1/D2)
- wiki/testing/data/test-data-and-isolation.md — use for: per-test $HOME isolation (D6)
- wiki/testing/quality/minimum-case-set.md — use for: case coverage check (D7/D8)

## Inputs
- plans/harvest-dedupe-processed/plan.md and its task
  plans/harvest-dedupe-processed/tasks/01-dedupe-against-processed-store.md —
  execute THAT task file's steps verbatim; its D1–D11 bind you
- tests/harvest.bats (existing, expected red on the regression case)

## Steps
1. Run `bats tests/harvest.bats`; confirm and record the red case(s).
2. Apply the adopted task's change to hooks/harvest.js: read-only seed of `seen`
   from `.processed.jsonl` (existsSync-guarded, safeJson per line), placed with
   the existing queue-file seeding.
3. Re-run the suite to green.

## Deliverables
- hooks/harvest.js (modified)
- tests/harvest.bats (only if the adopted task file says it is incomplete)

## Verify
- `bats tests/` → all pass; the previously red regression case is named in output.

## Out of scope
- Pruning `.processed.jsonl` (adopted plan D11 follow-up); filter-policy changes
  (task 05 audits, issues only).
