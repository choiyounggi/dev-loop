# Task 04c: loop-implement and the example profile describe verify the same way
## Objective
skills/loop-implement/SKILL.md's role list and examples/tools.example.json's verify `how` match configure's verify wording (plan repair: found by task 04's adjacent sweep).
## Wiki pages (read these first, only these)
- wiki/qa/document-verification/editing-a-gated-document.md — use for: grep tests for the old strings before editing
## Inputs
- Decisions that bind you: D8
## Steps
1. Tests first in tests/verify-role-lint.bats (whitespace-normalized): skills/loop-implement/SKILL.md contains `\`verify\` (the project's test / build / lint / typecheck / QA command)`; examples/tools.example.json's `.verify.how` (read with jq) equals `run the project's test/build/lint/typecheck/QA command; report failures verbatim`; boundary: the json still parses (jq exit 0); negative control: a loop-implement copy with the old wording fails.
2. skills/loop-implement/SKILL.md: `\`verify\` (the project's test / build / QA` + newline + `command)` -> `\`verify\` (the project's test / build / lint /` + newline + `typecheck / QA command)`.
3. examples/tools.example.json verify `how`: `run the project's test/build/QA command; report failures verbatim` -> `run the project's test/build/lint/typecheck/QA command; report failures verbatim`.
## Deliverables
- skills/loop-implement/SKILL.md
- examples/tools.example.json
- tests/verify-role-lint.bats
## Verify
- PATH=/opt/homebrew/bin:$PATH bats tests/verify-role-lint.bats tests/resolve-tools.bats tests/orchestrate-graph-explore.bats tests/scripts.bats — success = no `not ok` line
- lint: node scripts/wiki-lint-prohibitions.js wiki && echo LINT_OK — success = LINT_OK printed
- lint: bash scripts/gen-agent-tier-variants.sh --check && echo LINT_OK — success = LINT_OK printed
- covers: R6
## Out of scope
- any other loop-implement wording
