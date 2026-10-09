# Task 09a: `Lint: none — checked:` must name a command
## Objective
Review-fix (adversarial finding 2): `check lint-surveyed` rejects `- Lint: none — checked:` followed only by spaces.
## Wiki pages (read these first, only these)
- wiki/backend/common/llm/binding-instructions-for-agents.md — use for: the gate is the mechanical check (D5)
## Inputs
- Decisions that bind you: D5
## Steps
1. Tests first in tests/plan-gate.bats lint-surveyed section: a variant whose Lint line is `- Lint: none — checked:  ` (two trailing spaces) -> status 3, `malformed Lint bullet`.
2. plan-gate.sh check_lint_surveyed: pattern `'^- Lint: none — checked: .'` -> `'^- Lint: none — checked: *[^ ]'`.
## Deliverables
- skills/wiki-plan/scripts/plan-gate.sh
- tests/plan-gate.bats
## Verify
- PATH=/opt/homebrew/bin:$PATH bats tests/plan-gate.bats — success = no `not ok` line
- lint: node scripts/wiki-lint-prohibitions.js wiki && echo LINT_OK — success = LINT_OK printed
- lint: bash scripts/gen-agent-tier-variants.sh --check && echo LINT_OK — success = LINT_OK printed
- covers: R4
## Out of scope
- CRLF handling (pre-existing for every gate; follow-up)
