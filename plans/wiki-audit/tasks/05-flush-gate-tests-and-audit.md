# Task 05: Flush-gate bats tests + harvest/flush pipeline audit

## Objective
(a) `tests/pre-flush-pr-gate.bats` proving the PreToolUse gate's decision table;
(b) `plans/wiki-audit/findings/pipeline.md` auditing, with quoted line evidence,
whether harvest admits only wiki-grade material and whether knowledge-flush's
dedup/verification steps are enforced vs merely instructed.

## Wiki pages (read these first, only these)
- wiki/testing/quality/minimum-case-set.md — use for: gate test case selection
- wiki/testing/quality/checks-that-cannot-pass.md — use for: distinguishing
  "body-file missing" vs "section missing" vs "content empty" exit semantics
- wiki/testing/data/test-data-and-isolation.md — use for: per-test tmp isolation

## Inputs
- hooks/pre-flush-pr-gate.sh, hooks/auto-flush.sh, hooks/harvest.js (as fixed by
  task 04), hooks/insight-instruction.sh, skills/knowledge-flush/SKILL.md,
  skills/wiki-ingest/SKILL.md
- Decisions that bind you: D6 (test cases), D7 (audit-only for filter policy), D4

## Steps
1. Write tests/pre-flush-pr-gate.bats: (normal) flush command with complete
   INGEST_REPORT passes; (error) each of the 3 sections missing → exit 2 with the
   section named; body under 40 non-header chars → exit 2; --body-file absent from
   command → exit 2; body file path nonexistent → exit 2; (boundary) non-flush
   `gh pr create` passes untouched; non-pr command passes; flush markers detected
   from each of the 3 alternatives (--head knowledge/, label, INGEST_REPORT).
2. Audit for enforcement gaps, recording each as finding + evidence line: e.g.
   is the dedup step (SKILL step 2b) enforced by any gate or only prose? Can
   auto-flush PENDING count be satisfied by rows that will fail verification?
   Does anything verify wiki-ingest's merge-before-create actually ran?
3. Classify each finding per D7: mechanical fix on-branch vs `→ issue`.

## Deliverables
- tests/pre-flush-pr-gate.bats
- plans/wiki-audit/findings/pipeline.md

## Verify
- `bats tests/` → all pass (harvest + gate suites together).

## Out of scope
- Rewriting gate/skill policy (owner-approval layer — issues); auto-flush spawn
  mechanics (claude/gh availability paths are environment-dependent, note only).
