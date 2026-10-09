# Task 03: wiki-plan records lint commands and writes them into every task's Verify
## Objective
skills/wiki-plan/SKILL.md tells the planner to record `- Lint:` bullets in A2, lists `lint-surveyed` among gate-A ids, keeps it in lite mode, and gives Phase C a predicate table that turns each bullet into a task Verify line.
## Wiki pages (read these first, only these)
- wiki/infrastructure/ci-cd/changed-files-only-gates.md — use for: the red-baseline row (task files only, `xargs -r` empty guard) (D6)
- wiki/platforms/processes/tool-diagnostics-without-a-failing-exit-code.md — use for: the warnings sentence (D7)
- wiki/qa/document-verification/editing-a-gated-document.md — use for: tests on SKILL.md normalize whitespace before substring checks
## Inputs
- templates/plan-gates.md with lint-surveyed (task 02); gate id name `lint-surveyed`
- Decisions that bind you: D5, D6, D7
## Steps
1. Tests first: create tests/wiki-plan-lint-gate.bats. Normalize the file with `tr '\n' ' ' | tr -s ' '` before substring checks. Assert: (a) SKILL.md contains `Lint: <command> -> rc=<n>` and `Lint: none — checked:`; (b) the gate-A ids line contains `lint-surveyed`; (c) contains `lint-surveyed` is never abandoned in lite mode; (d) contains `&& echo LINT_OK`, `xargs -r`, `not gated — baseline rc=<n>`, and `never adds a warning-promotion flag`; (e) boundary: contains the `Lint: none` row text `no lint line`; (f) negative control: a copy with every line containing `LINT_OK` removed fails check (d); (g) negative control: a copy with `lint-surveyed` replaced by `x` fails check (b).
2. A2 (`**A2. Ground truth**` bullet list): add after the Baseline bullet:
   "- `Lint: <command> -> rc=<n>` — one bullet per lint or typecheck command the project runs (package.json scripts named lint, typecheck, type-check or check; Makefile lint targets; CI workflow steps that run a linter or type checker; the `verify` role when it names one), run once now to record its rc — or one `Lint: none — checked: <search command>` bullet when there is none. gate-A's `lint-surveyed` checks this format only and never re-runs the command."
3. gate-A `Gate ids:` line: insert ``lint-surveyed`` after ``constraints-surveyed``.
4. Lite mode section: after the paragraph ending "...simply records nothing when the [no-wiki] count is the zero the lite verdict assumed." add: "`lint-surveyed` is never abandoned in lite mode either: it is one format check, and Phase C needs the recorded command."
5. Phase C step 5: in the task template's `## Verify` block add the line `- lint: <one line per Lint bullet — see the Lint gating table below>`. Directly after the task template's closing fence add:
   **Lint gating in every task's `## Verify`.** For each `- Lint:` bullet in analysis.md's `## Ground truth`, write one lint line into every task's Verify:

   | Ground truth bullet | Task Verify line |
   |---|---|
   | `Lint: <command> -> rc=0` | `- lint: <command> && echo LINT_OK` — `<command>` copied verbatim; success = `LINT_OK` printed |
   | `Lint: <command> -> rc=<non-zero>`, the tool accepts file operands | `- lint: printf '%s\n' <this task's Deliverables paths> \| xargs -r <tool invocation that takes files> && echo LINT_OK` — the untouched tree already fails, so only this task's files are judged |
   | `Lint: <command> -> rc=<non-zero>`, the tool takes no file operands | `- lint: not gated — baseline rc=<n>, <command> takes no file operands`; loop-implement step 0 records it as `ABANDON: <gate id> baseline rc=<n>, <command> takes no file operands` |
   | `Lint: none — checked: ...` | no lint line |

   Warnings block only when the recorded command already promotes them (a lint script running `eslint --max-warnings 0`); the plan never adds a warning-promotion flag.
6. Step 6 self-check: append the sentence "Then check lint: every task's Verify carries one lint line per `- Lint:` bullet, per the Lint gating table."
## Deliverables
- skills/wiki-plan/SKILL.md
- tests/wiki-plan-lint-gate.bats
## Verify
- PATH=/opt/homebrew/bin:$PATH bats tests/wiki-plan-lint-gate.bats tests/emit-gaps.bats tests/orchestrate-fresh-reviewer.bats tests/orchestrate-dispatch-contracts.bats tests/wiki-rag-skills.bats — success = no `not ok` line
- lint: node scripts/wiki-lint-prohibitions.js wiki && echo LINT_OK — success = LINT_OK printed
- lint: bash scripts/gen-agent-tier-variants.sh --check && echo LINT_OK — success = LINT_OK printed
- covers: R5
## Out of scope
- loop-implement SKILL.md (its step 0 already turns Verify lines into CHECK/EXPECT and allows ABANDON); configure (task 04)
