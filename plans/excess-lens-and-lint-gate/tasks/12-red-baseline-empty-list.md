# Task 12: the red-baseline lint line logs its file list and says when it skipped
## Objective
The Phase C red-baseline row prints the files it lints and an explicit skip line when none remain, instead of a silent LINT_OK.
## Wiki pages (read these first, only these)
- wiki/infrastructure/ci-cd/changed-files-only-gates.md — use for: steps 1 (count + explicit skip), 3 (log the list), 5 (array operands)
## Inputs
- Decisions that bind you: D11
## Steps
1. Tests first in tests/wiki-plan-lint-gate.bats: the red-baseline check asserts `fs=(); for f in <only the Deliverables paths this tool lints>; do [ -f "$f" ] && fs+=("$f"); done`, `echo "lint files (${#fs[@]}): ${fs[*]}"`, `lint skipped: no lintable Deliverables remain`, and `<tool invocation that takes files> "${fs[@]}"`; drop the `xargs -0 -r` and printf-NUL assertions and the xargs negative control; add a negative control: a copy without the skip line fails.
2. wiki-plan SKILL.md red-baseline row Task Verify cell -> `- lint: fs=(); for f in <only the Deliverables paths this tool lints>; do [ -f "$f" ] && fs+=("$f"); done; echo "lint files (${#fs[@]}): ${fs[*]}"; if [ ${#fs[@]} -eq 0 ]; then echo "lint skipped: no lintable Deliverables remain"; else <tool invocation that takes files> "${fs[@]}"; fi && echo LINT_OK` (bash — gate-check runs CHECK with bash -c); keep the explanation, ending "deleted files and paths with spaces pass through safely, and an empty list is reported, not hidden".
3. Execute the line under bash -c on real files: a space path + a deleted path, an empty list, a failing tool; record the outputs in the task report.
## Deliverables
- skills/wiki-plan/SKILL.md
- tests/wiki-plan-lint-gate.bats
## Verify
- PATH=/opt/homebrew/bin:$PATH bats tests/wiki-plan-lint-gate.bats — success = no `not ok` line
- lint: node scripts/wiki-lint-prohibitions.js wiki && echo LINT_OK — success = LINT_OK printed
- lint: bash scripts/gen-agent-tier-variants.sh --check && echo LINT_OK — success = LINT_OK printed
- covers: R5
## Out of scope
- none
