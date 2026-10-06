# Task 10: config-nudge and the configure example name lint and typecheck
## Objective
Review-fix (general-review notes 1-2): hooks/config-nudge.sh and the configure JSON example describe verify as test / build / lint / typecheck.
## Wiki pages (read these first, only these)
- wiki/qa/document-verification/editing-a-gated-document.md — use for: grep tests for the old strings first
## Inputs
- Decisions that bind you: D8
## Steps
1. Tests first in tests/verify-role-lint.bats: hooks/config-nudge.sh contains `your project's actual test / build / lint / typecheck command`; skills/configure/SKILL.md contains `"ref": "<your test/build/lint/typecheck command>"`; negative control: a config-nudge copy with the old text fails.
2. hooks/config-nudge.sh: `your project's actual test / build command` -> `your project's actual test / build / lint / typecheck command`.
3. skills/configure/SKILL.md: `"ref": "<your test/build command>"` -> `"ref": "<your test/build/lint/typecheck command>"`.
## Deliverables
- hooks/config-nudge.sh
- skills/configure/SKILL.md
- tests/verify-role-lint.bats
## Verify
- PATH=/opt/homebrew/bin:$PATH bats tests/verify-role-lint.bats tests/config-nudge.bats tests/scripts.bats — success = no `not ok` line
- lint: node scripts/wiki-lint-prohibitions.js wiki && echo LINT_OK — success = LINT_OK printed
- lint: bash scripts/gen-agent-tier-variants.sh --check && echo LINT_OK — success = LINT_OK printed
- covers: R6
## Out of scope
- none
