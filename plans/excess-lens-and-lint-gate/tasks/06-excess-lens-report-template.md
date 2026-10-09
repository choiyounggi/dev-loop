# Task 06: review-report template has the lens 6 row
## Objective
skills/orchestrate/templates/review-report.md has a sixth per-lens row `6. Excess` and states what an Excess finding's failure scenario is.
## Wiki pages (read these first, only these)
- wiki/qa/document-verification/editing-a-gated-document.md — use for: the `5 rows` count anchors
## Inputs
- lens 6 name `Excess` from skills/orchestrate/SKILL.md (task 05)
- Decisions that bind you: D2, D4
## Steps
1. Tests first in tests/orchestrate-review-pass.bats: the per-lens table test becomes "has 6 rows" with `clean —` and `not run —` counts of 6 and asserts `| 6. Excess |`; add a test that the template contains `For a lens 6 (Excess) finding, the failure scenario is the search command, its hit count, and "no brief or plan line needs it".` (whitespace-normalized); add a negative control: a copy with the `| 6. Excess |` row deleted has a `clean —` count of 5.
2. Template: add after the lens 5 row: `| 6. Excess | \`clean — <what was checked>\` or \`findings: F1, F2\` or \`not run — <why>\` |` (same cell text as the other rows).
3. Template `## Findings`: after the paragraph "Each finding must state a concrete failure scenario. If it cannot, it belongs in **Non-blocking** below, not here." add the paragraph: `For a lens 6 (Excess) finding, the failure scenario is the search command, its hit count, and "no brief or plan line needs it".`
## Deliverables
- skills/orchestrate/templates/review-report.md
- tests/orchestrate-review-pass.bats
## Verify
- PATH=/opt/homebrew/bin:$PATH bats tests/orchestrate-review-pass.bats tests/session-prompt-rework.bats — success = no `not ok` line
- lint: node scripts/wiki-lint-prohibitions.js wiki && echo LINT_OK — success = LINT_OK printed
- lint: bash scripts/gen-agent-tier-variants.sh --check && echo LINT_OK — success = LINT_OK printed
- covers: R3
## Out of scope
- agents (task 07)
