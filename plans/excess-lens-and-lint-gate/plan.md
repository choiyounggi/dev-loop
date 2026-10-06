# excess-lens-and-lint-gate
Goal: (1) orchestrate's per-task reviewer gains lens 6 `Excess`, run at every tier, that blocks on new code no brief/plan line needs when a search proves it (zero callers, re-implemented helper/stdlib, constant parameter, single-implementation abstraction). (2) wiki-plan records every lint/typecheck command in analysis.md (enforced by a new gate-A id `lint-surveyed`) and writes it into every task's Verify, scoped to the task's files when the baseline is red; configure's `verify` role names lint/typecheck.
Acceptance: every Rule R1-R7 in analysis.md is covered by a task below, and the full bats suite passes (baseline 1535/1535).
Stack: POSIX sh / bash scripts, Markdown skills and agents, bats-core under Homebrew bash (`PATH=/opt/homebrew/bin:$PATH bats`).
## Decisions
| # | Decision | Choice | Wiki basis |
|---|----------|--------|------------|
| D1 | Where the excess check runs | lens in task-reviewer (fresh context) | wiki/qa/process/fresh-context-code-review.md |
| D2 | Lens number | append as lens 6 `Excess`; update count anchors; `four-lens pass` -> `lens pass` | wiki/qa/document-verification/editing-a-gated-document.md |
| D3 | Tiers running lens 6 | all: R0 1, 3 and 6; R1 1-4 and 6; R2/R3 1-6 — in profile table, Phase 4 paragraph, agent table | [no-wiki] |
| D4 | Lens 6 check and blocking rule | requirement line per new element; blocking only with search evidence (a)-(d); plan-named elements exempt | [no-wiki] |
| D5 | Lint record + enforcement | `- Lint:` bullets in Ground truth; gate-A `lint-surveyed` format check; never abandoned in lite mode | wiki/backend/common/llm/binding-instructions-for-agents.md |
| D6 | Task Verify lint line per baseline | rc=0 full command + LINT_OK; red + file operands -> Deliverables via `xargs -r`; red + no operands -> not gated (ABANDON) | wiki/infrastructure/ci-cd/changed-files-only-gates.md |
| D7 | Warnings | recorded command's exit status, verbatim; no promotion flag | wiki/platforms/processes/tool-diagnostics-without-a-failing-exit-code.md |
| D8 | configure verify text | test / build / lint / typecheck / QA in 3 places | [no-wiki] |
| D9 | r1 copy | edit base, run gen-agent-tier-variants.sh, `--check` exits 0 | [no-wiki] |
## Size verdict
size: large (9 tasks after the task-04 sweep repair, > 8; every task within the step-4 bounds)
Pre-dispatch split, two independent pieces:
- piece A (lint gate) — files: skills/wiki-plan/scripts/plan-gate.sh, templates/plan-gates.md, templates/analysis.md, skills/wiki-plan/SKILL.md, skills/configure/SKILL.md, references/tool-profile.md, README.md, README.ko.md, skills/loop-implement/SKILL.md, examples/tools.example.json, tests/plan-gate.bats, tests/fixtures/plan-gate/passing/analysis.md, tests/wiki-plan-lint-gate.bats, tests/verify-role-lint.bats; outputs: gate-A id lint-surveyed
- piece B (excess lens) — files: skills/orchestrate/SKILL.md, skills/orchestrate/templates/review-report.md, agents/task-reviewer.md, agents/task-reviewer-r1.md, tests/orchestrate-review-pass.bats, tests/orchestrate-dispatch-contracts.bats; outputs: review lens 6 Excess
## Task order
| Task | Depends on | Parallel-ok |
|------|------------|-------------|
| 01-lint-surveyed-check | — | |
| 02-gate-a-emits-lint-surveyed | 01 | |
| 03-wiki-plan-lint-prose | 02 | |
| 04-configure-verify-lint | — | parallel-ok with 01-03 |
| 04b-verify-wording-readmes | 04 | |
| 04c-verify-wording-loop-and-example | 04b | |
| 05-excess-lens-skill | — | parallel-ok with 01-04 |
| 06-excess-lens-report-template | 05 | |
| 07-excess-lens-agent | 06 | |
