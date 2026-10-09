# Task 02: gate-A ledger and analysis template carry lint-surveyed
## Objective
`plan-gate.sh emit A` writes a 6-gate ledger that includes `lint-surveyed`, and templates/analysis.md shows the `- Lint:` bullet with its rule.
## Wiki pages (read these first, only these)
- wiki/qa/document-verification/editing-a-gated-document.md — use for: inventory the count anchors (5 gates, met=5) before editing
## Inputs
- skills/wiki-plan/scripts/plan-gate.sh with `check lint-surveyed` (task 01)
- tests/fixtures/plan-gate/passing/analysis.md with `- Lint: true -> rc=0` (task 01)
- Decisions that bind you: D5
## Steps
1. Tests first in tests/plan-gate.bats: change the emit-A assertions from 5 to 6 (test title `emit A: writes 6 gates, ...`, the three `-eq 5` counts, `met=5`/`unmet=5` strings to 6); add a test that the emitted A ledger contains `- [ ] lint-surveyed:` and `plan-gate.sh check lint-surveyed`; add a negative control: a copy of templates/plan-gates.md with the lint-surveyed block removed (awk dropping from `- [ ] lint-surveyed:` through its EVIDENCE line) does not contain `lint-surveyed`.
2. In templates/plan-gates.md, between the constraints-surveyed and research-evidenced blocks of PHASE A, add:
```
- [ ] lint-surveyed: analysis.md's `## Ground truth` records every lint/typecheck command as `- Lint: <command> -> rc=<n>` (or one `- Lint: none — checked: <command>` line)
  CHECK: sh ${CLAUDE_PLUGIN_ROOT}/skills/wiki-plan/scripts/plan-gate.sh check lint-surveyed {PLAN_DIR}
  EXPECT: ok
  EVIDENCE: pending
```
3. In templates/analysis.md `## Ground truth`, add directly below the Baseline bullet: `- Lint: <lint or typecheck command> -> rc=<n>`, and below the existing "baseline-tests-ran gate re-runs" paragraph add: "Add one `- Lint:` bullet per lint or typecheck command the project runs, with the rc you got running it now, or a single `- Lint: none — checked: <command that confirmed it>` bullet. The lint-surveyed gate fails without one; it checks the format only and never re-runs the command."
## Deliverables
- templates/plan-gates.md
- templates/analysis.md
- tests/plan-gate.bats
## Verify
- PATH=/opt/homebrew/bin:$PATH bats tests/plan-gate.bats tests/emit-gaps.bats tests/loop-gate.bats tests/orchestrate-graph-explore.bats tests/orchestrate-fresh-reviewer.bats tests/orchestrate-dispatch-contracts.bats — success = no `not ok` line
- lint: node scripts/wiki-lint-prohibitions.js wiki && echo LINT_OK — success = LINT_OK printed
- lint: bash scripts/gen-agent-tier-variants.sh --check && echo LINT_OK — success = LINT_OK printed
- covers: R4
## Out of scope
- wiki-plan SKILL.md prose (task 03)
