# Task 09b: the red-baseline lint row survives spaces, deleted files, and other file types; step 0 names the not-gated ABANDON
## Objective
Review-fix (adversarial finding 3, general-review note 3): the Phase C red-baseline row lints only existing files the tool lints, NUL-separated; loop-implement step 0 says how a `lint: not gated` line becomes an ABANDON.
## Wiki pages (read these first, only these)
- wiki/infrastructure/ci-cd/changed-files-only-gates.md — use for: operand list passing (step 5) and the empty-list guard
## Inputs
- Decisions that bind you: D6
## Steps
1. Tests first in tests/wiki-plan-lint-gate.bats: SKILL.md Phase C contains `[ -f "$f" ] && printf '%s\0' "$f"`, `xargs -0 -r`, and `only the Deliverables paths this tool lints`; loop-implement SKILL.md step 0 (whitespace-normalized) contains `a \`lint: not gated\` Verify line becomes an \`ABANDON:\` line with its stated reason`; negative control: a wiki-plan copy without `xargs -0 -r` fails.
2. wiki-plan SKILL.md red-baseline row Task Verify cell -> `- lint: for f in <only the Deliverables paths this tool lints>; do [ -f "$f" ] && printf '%s\0' "$f"; done \| xargs -0 -r <tool invocation that takes files> && echo LINT_OK` — keep the trailing explanation sentence and add "deleted files and paths with spaces pass through safely".
3. loop-implement SKILL.md step 0: after `manual ones EVIDENCE only.` add `A \`lint: not gated\` Verify line becomes an \`ABANDON:\` line with its stated reason.` (reflow the step's column-aligned lines).
## Deliverables
- skills/wiki-plan/SKILL.md
- skills/loop-implement/SKILL.md
- tests/wiki-plan-lint-gate.bats
## Verify
- PATH=/opt/homebrew/bin:$PATH bats tests/wiki-plan-lint-gate.bats tests/orchestrate-graph-explore.bats tests/verify-role-lint.bats tests/scripts.bats — success = no `not ok` line
- lint: node scripts/wiki-lint-prohibitions.js wiki && echo LINT_OK — success = LINT_OK printed
- lint: bash scripts/gen-agent-tier-variants.sh --check && echo LINT_OK — success = LINT_OK printed
- covers: R5
## Out of scope
- verify wording leftovers (10)
