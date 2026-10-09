# Task 08: lens 6 exempts later-task seams and needs 2+ call sites for evidence (c)
## Objective
Review-fix (adversarial finding 1): lens 6 no longer blocks a producer task's element that a later task consumes, and evidence (c) needs two or more call sites.
## Wiki pages (read these first, only these)
- wiki/qa/document-verification/editing-a-gated-document.md — use for: update the lens-6 substring tests with the prose
## Inputs
- plans/excess-lens-and-lint-gate/lens6.txt (revised text)
- Decisions that bind you: D4 (revised by this review fix)
## Steps
1. Tests first in tests/orchestrate-review-pass.bats: the Phase 4 lens-6 test and the agent lens-6 test also assert `or a later task's Inputs` and `two or more call sites that all pass the same value`; add a negative control: a SKILL.md copy with `, or a later task's Inputs` removed fails.
2. Replace the lens 6 block in skills/orchestrate/SKILL.md and in agents/task-reviewer.md with lens6.txt verbatim.
3. Run `bash scripts/gen-agent-tier-variants.sh`.
## Deliverables
- skills/orchestrate/SKILL.md
- agents/task-reviewer.md (+ generated agents/task-reviewer-r1.md)
- tests/orchestrate-review-pass.bats
## Verify
- PATH=/opt/homebrew/bin:$PATH bats tests/orchestrate-review-pass.bats tests/orchestrate-dispatch-contracts.bats tests/agent-tier-variants.bats — success = no `not ok` line
- lint: node scripts/wiki-lint-prohibitions.js wiki && echo LINT_OK — success = LINT_OK printed
- lint: bash scripts/gen-agent-tier-variants.sh --check && echo LINT_OK — success = LINT_OK printed
- covers: R1
## Out of scope
- lint gate fixes (09a, 09b)
