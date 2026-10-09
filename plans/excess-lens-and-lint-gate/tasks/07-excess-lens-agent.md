# Task 07: task-reviewer agent applies lens 6 at every tier
## Objective
agents/task-reviewer.md carries the lens 6 text and the tier table naming lens 6 for every tier; agents/task-reviewer-r1.md is regenerated from it.
## Wiki pages (read these first, only these)
- wiki/qa/process/fresh-context-code-review.md — use for: the reviewer is the fresh-context session (D1)
## Inputs
- lens6.txt (plans/excess-lens-and-lint-gate/lens6.txt) — the same text task 05 put in SKILL.md
- skills/orchestrate/templates/review-report.md with the `6. Excess` row (task 06)
- Decisions that bind you: D3, D4, D9
## Steps
1. Tests first in tests/orchestrate-review-pass.bats (new section `# --- task-reviewer agent lens 6 ---`), whitespace-normalized: agents/task-reviewer.md contains `6. **Excess**`, `zero call sites outside its own tests`, `| R0 | lenses 1, 3 and 6; write not run — R0 profile in rows 2, 4, 5 |`, `| R1 | lenses 1-4 and 6; write not run — R1 profile in row 5 |`, `| R2 or R3 | lenses 1-6; R3 also applies the adversarial-change-review techniques under lens 5 |`; the same lens-6 assertion holds for agents/task-reviewer-r1.md; boundary: the agent body contains exactly one `6. **Excess**` line; negative control: a copy of the agent with the R1 row reverted to `| R1 | lenses 1-4; write not run — R1 profile in row 5 |` fails the R1 assertion.
2. agents/task-reviewer.md: tier table rows -> the three rows above, verbatim. Insert lens6.txt verbatim after the agent's lens 5 entry (`5. **AC traceability** ...`), before `4. No file modification`.
3. Run `bash scripts/gen-agent-tier-variants.sh` (never hand-edit the -r1 file).
## Deliverables
- agents/task-reviewer.md
- agents/task-reviewer-r1.md (generated)
- tests/orchestrate-review-pass.bats
## Verify
- PATH=/opt/homebrew/bin:$PATH bats tests/orchestrate-review-pass.bats tests/agent-tier-variants.bats tests/agent-model-pin.bats tests/orchestrate-fresh-reviewer.bats — success = no `not ok` line
- PATH=/opt/homebrew/bin:$PATH bats tests/ — full suite, success = `not ok` count 0 (final task; baseline 1535/1535)
- lint: node scripts/wiki-lint-prohibitions.js wiki && echo LINT_OK — success = LINT_OK printed
- lint: bash scripts/gen-agent-tier-variants.sh --check && echo LINT_OK — success = LINT_OK printed
- covers: R1, R2, R7
## Out of scope
- integration-reviewer agents; loop-implement step 6
