# Task 04b: READMEs describe verify as test / build / lint / typecheck / QA
## Objective
README.md and README.ko.md role tables match configure's verify wording (plan repair: found by task 04's adjacent sweep).
## Wiki pages (read these first, only these)
- wiki/qa/document-verification/editing-a-gated-document.md — use for: grep tests for the old strings before editing
## Inputs
- the wording from task 04: `test / build / lint / typecheck / QA`
- Decisions that bind you: D8
## Steps
1. Tests first in tests/verify-role-lint.bats: README.md contains `your project's **test / build / lint / typecheck / QA** command (the loop's run step)`; README.ko.md contains `프로젝트의 **테스트 / 빌드 / 린트 / 타입체크 / QA** 명령 (루프의 실행 스텝)`; negative control: a README.md copy with the old `**test / build / QA**` row fails.
2. README.md line `| \`verify\` | your project's **test / build / QA** command (the loop's run step) |` -> `**test / build / lint / typecheck / QA**`.
3. README.ko.md line `| \`verify\` | 프로젝트의 **테스트 / 빌드 / QA** 명령 (루프의 실행 스텝) |` -> `**테스트 / 빌드 / 린트 / 타입체크 / QA**`.
## Deliverables
- README.md
- README.ko.md
- tests/verify-role-lint.bats
## Verify
- PATH=/opt/homebrew/bin:$PATH bats tests/verify-role-lint.bats tests/scripts.bats — success = no `not ok` line
- lint: node scripts/wiki-lint-prohibitions.js wiki && echo LINT_OK — success = LINT_OK printed
- lint: bash scripts/gen-agent-tier-variants.sh --check && echo LINT_OK — success = LINT_OK printed
- covers: R6
## Out of scope
- skills/loop-implement/SKILL.md and examples/tools.example.json (task 04c)
