# Task 13b: the red-baseline lint line survives set -u on bash 3.2
## Objective
Review-fix (fix-wave adversarial finding 1): the row's echo uses `${fs[*]-}`, so an empty array under `set -u` on macOS /bin/bash 3.2 (the interpreter gate-check.sh execs) prints the skip line instead of dying with "unbound variable".
## Wiki pages (read these first, only these)
- wiki/infrastructure/ci-cd/changed-files-only-gates.md — use for: the empty-list case must be reported
## Inputs
- Decisions that bind you: D11
## Steps
1. Tests first in tests/wiki-plan-lint-gate.bats: the row contains `echo "lint files (${#fs[@]}): ${fs[*]-}"`; a behavioral test extracts the row's line from SKILL.md, substitutes `<only the Deliverables paths this tool lints>` with a missing path and `<tool invocation that takes files>` with `true`, runs `/bin/bash -c "set -u; <line>"` in `$BATS_TEST_TMPDIR`, and asserts status 0 with `lint skipped: no lintable Deliverables remain` and `LINT_OK` in the output.
2. SKILL.md row: `echo "lint files (${#fs[@]}): ${fs[*]}"` -> `echo "lint files (${#fs[@]}): ${fs[*]-}"`.
## Deliverables
- skills/wiki-plan/SKILL.md
- tests/wiki-plan-lint-gate.bats
## Verify
- PATH=/opt/homebrew/bin:$PATH bats tests/wiki-plan-lint-gate.bats — success = no `not ok` line
- lint: node scripts/wiki-lint-prohibitions.js wiki && echo LINT_OK — success = LINT_OK printed
- lint: bash scripts/gen-agent-tier-variants.sh --check && echo LINT_OK — success = LINT_OK printed
- covers: R5
## Out of scope
- newline-in-filename display wrap (cosmetic)
