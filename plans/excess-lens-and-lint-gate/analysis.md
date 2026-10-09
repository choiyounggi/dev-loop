# Analysis — excess-lens-and-lint-gate

## Requirements
| Rule | Concrete example | Open question |
|------|------------------|---------------|
| R1: the per-task reviewer runs an Excess lens at every tier and reports a new element no requirement needs as a finding | given a diff that adds `makeSaver(opts)` factory with one caller and no brief/plan line naming it, when task-reviewer runs at R0, then the review file's lens 6 row reads `findings: F1` and F1 cites the search showing one implementation and no requirement | |
| R2: the Excess lens reports a re-implementation of an existing repo helper or a standard-library function as a finding | given a diff that hand-rolls a group-by reduce while `lodash.groupBy` is already imported elsewhere in the repo, when task-reviewer runs, then a finding names the existing helper and its grep hit | |
| R3: review-report.md carries a sixth per-lens row and the R0/R1 not-run instructions name the right rows | given review-report.md, when a reviewer fills it, then the table has rows 1-6 and an R0 review writes `not run — R0 profile` in rows 2, 4, 5 only | |
| R4: wiki-plan Phase A records every lint/typecheck command in analysis.md, and gate-A fails without that record | given an analysis.md whose `## Ground truth` has no `- Lint:` line, when `plan-gate.sh check lint-surveyed` runs, then it prints `fail` and exits 3 | |
| R5: wiki-plan Phase C puts the recorded lint/typecheck command into every task's Verify, scoped to the task's files when the baseline is red | given `- Lint: npm run lint -> rc=0`, when Phase C writes tasks, then each task's Verify has `npm run lint && echo LINT_OK`; given rc=1 for an eslint command, each task's Verify runs eslint on that task's Deliverables only | |
| R6: configure's verify role names lint and typecheck commands | given skills/configure/SKILL.md, when a user runs configure, then the verify row reads test / build / lint / typecheck / QA | |
| R7: the generated task-reviewer-r1 copy stays in sync with its base | given the edited agents/task-reviewer.md, when `scripts/gen-agent-tier-variants.sh --check` runs, then it exits 0 | |

## Ground truth
- Baseline: PATH=/opt/homebrew/bin:$PATH bats tests/plan-gate.bats tests/orchestrate-review-pass.bats tests/orchestrate-dispatch-contracts.bats tests/agent-tier-variants.bats tests/emit-gaps.bats tests/resolve-tools.bats -> rc=0, HEAD c46ef85, git status clean
- Lint: node scripts/wiki-lint-prohibitions.js wiki -> rc=0
- Lint: bash scripts/gen-agent-tier-variants.sh --check -> rc=0

### Affected files
- agents/task-reviewer.md — evidence: grep -nE "lenses 1|Plan conformance" agents/task-reviewer.md -> 4 hits
- agents/task-reviewer-r1.md — evidence: grep -c "GENERATED from agents/task-reviewer.md" agents/task-reviewer-r1.md -> 1 hits (regenerated, never hand-edited)
- skills/orchestrate/SKILL.md — evidence: grep -nE "four-lens|lenses 1|\| review lenses" skills/orchestrate/SKILL.md -> 5 hits
- skills/orchestrate/templates/review-report.md — evidence: grep -c "^| [0-9]\. " skills/orchestrate/templates/review-report.md -> 5 hits
- tests/orchestrate-review-pass.bats — evidence: grep -nE "12345|exactly five|5 rows" tests/orchestrate-review-pass.bats -> 5 hits
- tests/orchestrate-dispatch-contracts.bats — evidence: grep -n "lenses 1 and 3 only" tests/orchestrate-dispatch-contracts.bats -> 1 hits
- skills/wiki-plan/scripts/plan-gate.sh — evidence: grep -n "check_constraints_surveyed" skills/wiki-plan/scripts/plan-gate.sh -> 2 hits
- templates/plan-gates.md — evidence: grep -c "^- \[ \] " templates/plan-gates.md -> 9 hits
- templates/analysis.md — evidence: grep -n "Baseline:" templates/analysis.md -> 1 hits
- tests/plan-gate.bats — evidence: grep -nE "writes 5 gates|met=5" tests/plan-gate.bats -> 3 hits
- tests/fixtures/plan-gate/passing/analysis.md — evidence: grep -n "Baseline:" tests/fixtures/plan-gate/passing/analysis.md -> 1 hits
- skills/wiki-plan/SKILL.md — evidence: grep -nE "Gate ids: .baseline-tests-ran|## Verify" skills/wiki-plan/SKILL.md -> 2 hits
- skills/configure/SKILL.md — evidence: grep -n "test / build / QA" skills/configure/SKILL.md -> 1 hits
- references/tool-profile.md — evidence: grep -n "tests / build / QA" references/tool-profile.md -> 1 hits

## Constraints
- scripts/gen-agent-tier-variants.sh --check (CI drift guard, tests/agent-tier-variants.bats) — agents/task-reviewer-r1.md must be regenerated, never hand-edited — checked: bash scripts/gen-agent-tier-variants.sh --check
- tests/orchestrate-review-pass.bats pins the lens order to "12345" and states "exactly five lenses"; tests/orchestrate-dispatch-contracts.bats pins the phrase "lenses 1 and 3 only" — both change with the lens set — checked: grep -nE "12345|exactly five|lenses 1 and 3 only" tests/*.bats
- tests/plan-gate.bats pins the gate-A ledger at 5 gates and met=5 — becomes 6 — checked: grep -nE "writes 5 gates|met=5" tests/plan-gate.bats
- session-prompt.md byte cksum pin (tests/send-prompt.bats) — not touched by this feature — checked: grep -nE "lens|lint" skills/orchestrate/templates/session-prompt.md -> 0 hits
- version bump — auto-release.yml bumps both version files on push to main, so no manual bump — checked: sed -n 1,10p .github/workflows/auto-release.yml
- wiki/** — not touched, so wiki-lint and the bats directive count stay as they are — checked: the Affected files list above has no wiki/ path

## Spikes
- R0 lite mode: agents/task-analyst.md row R0 abandons only research-evidenced on gate-A (grep -n "research-evidenced" agents/task-analyst.md -> 1 hit). The new lint-surveyed gate is a format check costing one grep, so it is never abandoned in lite mode; wiki-plan's lite-mode paragraph must say so.
- gates ledger EXPECT needs a success-only token (templates/gates.md authoring rules); most linters print nothing on success, so the Verify line appends `&& echo LINT_OK` and EXPECT is `LINT_OK` — the same shape templates/plan-gates.md already uses for baseline-tests-ran (`{BASELINE_CMD} && echo GATE_OK`).
- Standalone loop-implement has no per-task reviewer (only step 6 self-review); the Excess lens lands only in orchestrate's task-reviewer. Recorded as out of scope.

## Research
| Query | Source | Applied |
|-------|--------|---------|
| google eng-practices code review over-engineering complexity speculate | https://google.github.io/eng-practices/review/reviewer/looking-for.html (brave-search) | Excess lens wording: "more generic than it needs to be, or added functionality that isn't presently needed by the system" is the review question the lens asks per new element |
| eslint lint only changed files existing violations baseline | brave-search rate-limited; answered by wiki/infrastructure/ci-cd/changed-files-only-gates.md instead | red-baseline row: lint only the task's files, with the empty-list guard (`xargs -r`) |
