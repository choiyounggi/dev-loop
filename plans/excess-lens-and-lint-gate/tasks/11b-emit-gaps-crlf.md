# Task 11b: emit-gaps.sh reads CRLF design.md
## Objective
gaps-emitted records a [no-wiki] row from a CRLF design.md exactly as from an LF one.
## Wiki pages (read these first, only these)
- wiki/qa/document-verification/editing-a-gated-document.md — use for: keep the existing emit-gaps assertions green
## Inputs
- Decisions that bind you: D10
## Steps
1. Tests first in tests/emit-gaps.bats: run emit-gaps.sh on a CRLF copy of `$FIX/nowiki` (same invocation the file's existing nowiki test uses) and assert the same recorded gap line as the LF run, with no CR in it.
2. emit-gaps.sh `extract_l2`: add `{ sub(/\r$/, "") }` as the first awk rule (it is a copy of plan-gate.sh's helper — keep them identical).
## Deliverables
- skills/wiki-plan/scripts/emit-gaps.sh
- tests/emit-gaps.bats
## Verify
- PATH=/opt/homebrew/bin:$PATH bats tests/emit-gaps.bats tests/plan-gate.bats — success = no `not ok` line
- lint: node scripts/wiki-lint-prohibitions.js wiki && echo LINT_OK — success = LINT_OK printed
- lint: bash scripts/gen-agent-tier-variants.sh --check && echo LINT_OK — success = LINT_OK printed
- covers: R4
## Out of scope
- none
