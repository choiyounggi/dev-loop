# Task 13a: plan readers drop every CR, not only a trailing one
## Objective
Review-fix (fix-wave adversarial finding 2): extract_l2/extract_l3 in plan-gate.sh and emit-gaps.sh remove every CR, matching has_heading's `tr -d '\r'`, so a stray mid-line CR cannot reach an emitted CHECK line.
## Wiki pages (read these first, only these)
- wiki/qa/document-verification/editing-a-gated-document.md — use for: keep the existing CRLF tests green
## Inputs
- Decisions that bind you: D10 (now: drop every CR)
## Steps
1. Tests first in tests/plan-gate.bats CRLF section: a passing-fixture copy whose Baseline line is `- Baseline: true\r -> rc=0, HEAD abc1234, git status clean` (CR mid-line, LF ending); `emit A` writes `CHECK: true && echo GATE_OK` and the ledger contains no CR.
2. plan-gate.sh extract_l2 and extract_l3, and emit-gaps.sh extract_l2: `{ sub(/\r$/, "") }` -> `{ gsub(/\r/, "") }`.
## Deliverables
- skills/wiki-plan/scripts/plan-gate.sh
- skills/wiki-plan/scripts/emit-gaps.sh
- tests/plan-gate.bats
## Verify
- PATH=/opt/homebrew/bin:$PATH bats tests/plan-gate.bats tests/emit-gaps.bats tests/loop-gate.bats — success = no `not ok` line
- lint: node scripts/wiki-lint-prohibitions.js wiki && echo LINT_OK — success = LINT_OK printed
- lint: bash scripts/gen-agent-tier-variants.sh --check && echo LINT_OK — success = LINT_OK printed
- covers: R4
## Out of scope
- non-UTF-8 bytes (pre-existing, unchanged outcome)
