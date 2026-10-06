# Task 11a: plan-gate.sh judges CRLF plan files like LF files
## Objective
Every plan-gate.sh check gives the same verdict on a CRLF copy of a plan dir as on the LF original (follow-up to adversarial finding 4).
## Wiki pages (read these first, only these)
- wiki/qa/document-verification/editing-a-gated-document.md — use for: the existing tests pin exact-line matching; keep them green
## Inputs
- Decisions that bind you: D10
## Steps
1. Tests first in tests/plan-gate.bats (new section `# --- CRLF plan files ---`): copy `$FIX/passing` to `$BATS_TEST_TMPDIR/crlf` with `sed 's/$/\r/'` on analysis.md, design.md, review-verdict.md; for each id in baseline-tests-ran affected-files-evidenced open-questions-resolved constraints-surveyed lint-surveyed research-evidenced groundings-exist decision-rows-complete requirements-covered reviewer-verdict, `check <id> <crlf-dir> "$WIKI"` prints ok; `emit A` on the CRLF dir writes `CHECK: true && echo GATE_OK` (no CR inside the baseline command); error case: a CRLF copy with the `## Ground truth` line deleted still exits 4.
2. plan-gate.sh: in `extract_l2` and `extract_l3` add `{ sub(/\r$/, "") }` as the first awk rule; `has_heading() { tr -d '\r' < "$1" | grep -Fxq -- "$2"; }`; reviewer-verdict check: `tr -d '\r' < "$file" | grep -Fxq 'VERDICT: PASS'`.
## Deliverables
- skills/wiki-plan/scripts/plan-gate.sh
- tests/plan-gate.bats
## Verify
- PATH=/opt/homebrew/bin:$PATH bats tests/plan-gate.bats tests/loop-gate.bats — success = no `not ok` line
- lint: node scripts/wiki-lint-prohibitions.js wiki && echo LINT_OK — success = LINT_OK printed
- lint: bash scripts/gen-agent-tier-variants.sh --check && echo LINT_OK — success = LINT_OK printed
- covers: R4
## Out of scope
- emit-gaps.sh (11b)
