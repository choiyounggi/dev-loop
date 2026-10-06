# Task 04d: resolve-tools.sh's default verify description names lint and typecheck
## Objective
`resolve-tools.sh --role verify` (unconfigured) reports `when: running tests / build / lint / typecheck / QA checks (step 5)` (plan repair: found by task 04c's re-sweep).
## Wiki pages (read these first, only these)
- wiki/qa/document-verification/editing-a-gated-document.md — use for: grep tests for the old string before editing
## Inputs
- Decisions that bind you: D8 (wording only; no schema or resolution-logic change)
## Steps
1. Tests first in tests/verify-role-lint.bats: run `sh scripts/resolve-tools.sh --summary` with HOME set to an empty `$BATS_TEST_TMPDIR` dir and cwd an empty dir (no tools.json anywhere), assert the verify line contains `running tests / build / lint / typecheck / QA checks (step 5)`; negative control: a copy of resolve-tools.sh with the old text yields the old line.
2. scripts/resolve-tools.sh DEFAULTS verify `when`: `running tests / build / QA checks (step 5)` -> `running tests / build / lint / typecheck / QA checks (step 5)`.
## Deliverables
- scripts/resolve-tools.sh
- tests/verify-role-lint.bats
## Verify
- PATH=/opt/homebrew/bin:$PATH bats tests/verify-role-lint.bats tests/resolve-tools.bats tests/scripts.bats — success = no `not ok` line
- lint: node scripts/wiki-lint-prohibitions.js wiki && echo LINT_OK — success = LINT_OK printed
- lint: bash scripts/gen-agent-tier-variants.sh --check && echo LINT_OK — success = LINT_OK printed
- covers: R6
## Out of scope
- skills/orchestrate/SKILL.md:66 (folded into task 05)
