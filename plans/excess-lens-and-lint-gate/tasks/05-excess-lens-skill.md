# Task 05: orchestrate Phase 4 gains lens 6 Excess at every tier
## Objective
skills/orchestrate/SKILL.md lists lens 6 `Excess` after lens 5, and all three tier statements in SKILL.md (profile table row, Phase 4 Lens set by tier paragraph) include lens 6 for every tier.
## Wiki pages (read these first, only these)
- wiki/qa/document-verification/editing-a-gated-document.md — use for: anchor inventory before editing (lens_order, "exactly five", "1 and 3 only")
- wiki/qa/process/fresh-context-code-review.md — use for: why the check sits in the fresh-context reviewer (D1)
## Inputs
- the lens 6 text, verbatim, in plans/excess-lens-and-lint-gate/lens6.txt
- Decisions that bind you: D1, D2, D3, D4
## Steps
1. Tests first.
   tests/orchestrate-review-pass.bats: (a) the order test becomes "Phase 4 contains the six lenses, numbered 1-6, in order", requires `lens_order` = `123456` and `Excess` in the section; (b) the test-quality-auditor test asserts `6. **Excess` present and `7. **` absent (comment: "the lens list is fixed at six"); (c) the strip negative control adds `Excess` to its grep -v alternation and compares to `123456`; the swap negative control compares to `123456`; (d) new test, whitespace-normalized (`tr '\n' ' ' | tr -s ' '`): Phase 4 contains `name the brief or plan line it serves`, `zero call sites outside its own tests`, `standard-library/language function`, `exactly one implementation`, `belongs to lens 1`, and `goes under Non-blocking`; (e) negative control for (d): a copy with every line from `6. **Excess` to the line containing `Non-blocking.` deleted fails (d); update the header comment's `four-lens` to `six-lens`.
   tests/orchestrate-dispatch-contracts.bats: line-384 assertion becomes `| review lenses | 1, 3 and 6 only | 1-4 and 6 | 1-6 | 1-6 plus the adversarial-change-review techniques recorded under lens 5 |`; the Phase 4 lens-set test asserts `lenses 1, 3 and 6 only`, `when R1, lenses 1-4 and 6`, `when R2 or R3, lenses 1-6`; add a negative control: a copy with `lenses 1-4 and 6` replaced by `lenses 1-4` fails the R1 assertion.
2. SKILL.md Phase 4: insert the lens6.txt block directly after the lens 5 line (`5. **AC traceability**...`), before the blank line preceding `**Lens set by tier.**`.
3. SKILL.md Phase 4 Lens set by tier paragraph: `it runs lenses 1 and 3 only` -> `it runs lenses 1, 3 and 6 only`; `when R1, lenses 1-4; when R2 or R3,` + `lenses 1-5.` -> `when R1, lenses 1-4 and 6; when R2 or R3,` + `lenses 1-6.` (reflow the paragraph's line breaks only as needed).
4. SKILL.md Phase 2 profile table row: `| review lenses | 1 and 3 only | 1-4 | 1-5 | 1-5 plus the adversarial-change-review techniques recorded under lens 5 |` -> `| review lenses | 1, 3 and 6 only | 1-4 and 6 | 1-6 | 1-6 plus the adversarial-change-review techniques recorded under lens 5 |`.
5. SKILL.md Phase 4: `continue to the four-lens pass unchanged` -> `continue to the lens pass unchanged`.
6. SKILL.md Preflight role list (plan repair from task 04c's sweep): `` `verify` (test/build/QA`` + newline + ``command)`` -> `` `verify` (test/build/lint/typecheck/QA`` + newline + ``command)``; add to tests/verify-role-lint.bats? No — assert it in tests/orchestrate-dispatch-contracts.bats (whitespace-normalized): Preflight text contains `` `verify` (test/build/lint/typecheck/QA command)``.
## Deliverables
- skills/orchestrate/SKILL.md
- tests/orchestrate-review-pass.bats
- tests/orchestrate-dispatch-contracts.bats
## Verify
- PATH=/opt/homebrew/bin:$PATH bats tests/orchestrate-review-pass.bats tests/orchestrate-dispatch-contracts.bats tests/orchestrate-token-budget.bats tests/orchestrate-fresh-reviewer.bats — success = no `not ok` line
- lint: node scripts/wiki-lint-prohibitions.js wiki && echo LINT_OK — success = LINT_OK printed
- lint: bash scripts/gen-agent-tier-variants.sh --check && echo LINT_OK — success = LINT_OK printed
- covers: R1, R2
## Out of scope
- review-report.md (task 06); agents/task-reviewer*.md (task 07); integration-reviewer (not in this plan)
