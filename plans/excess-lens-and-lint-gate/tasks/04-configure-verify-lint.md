# Task 04: configure's verify role names lint and typecheck
## Objective
skills/configure/SKILL.md and references/tool-profile.md describe `verify` as the test / build / lint / typecheck / QA command.
## Wiki pages (read these first, only these)
- wiki/qa/document-verification/editing-a-gated-document.md — use for: grep tests for the old strings before editing
## Inputs
- Decisions that bind you: D8
## Steps
1. Tests first: create tests/verify-role-lint.bats asserting: (a) skills/configure/SKILL.md frontmatter description contains `\`verify\` (your project's test/build/lint/typecheck/QA command)`; (b) its role table row contains `your project's **test / build / lint / typecheck / QA** command` and `scripts (test, lint, typecheck)`; (c) references/tool-profile.md contains `running the project's tests / build / lint / typecheck / QA checks`; (d) boundary: no file still contains the old `test/build/QA command` or `tests / build / QA checks` strings (count 0); (e) negative control: a copy of configure SKILL.md with `lint/typecheck/` removed fails (a).
2. skills/configure/SKILL.md: description `(your project's test/build/QA command)` -> `(your project's test/build/lint/typecheck/QA command)`; table row `your project's **test / build / QA** command | read \`package.json\` scripts / Makefile` -> `your project's **test / build / lint / typecheck / QA** command | read \`package.json\` scripts (test, lint, typecheck) / Makefile`.
3. references/tool-profile.md line `running the project's tests / build / QA checks` -> `running the project's tests / build / lint / typecheck / QA checks`; keep the table's column padding unchanged otherwise.
## Deliverables
- skills/configure/SKILL.md
- references/tool-profile.md
- tests/verify-role-lint.bats
## Verify
- PATH=/opt/homebrew/bin:$PATH bats tests/verify-role-lint.bats tests/wiki-rag-skills.bats tests/resolve-tools.bats tests/graph-setup-skill.bats — success = no `not ok` line
- lint: node scripts/wiki-lint-prohibitions.js wiki && echo LINT_OK — success = LINT_OK printed
- lint: bash scripts/gen-agent-tier-variants.sh --check && echo LINT_OK — success = LINT_OK printed
- covers: R6
## Out of scope
- resolve-tools.sh, examples/tools.example.json, any new role (D8 rejects a lint role)
