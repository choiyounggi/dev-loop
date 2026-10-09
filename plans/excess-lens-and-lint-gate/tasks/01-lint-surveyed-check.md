# Task 01: plan-gate.sh judges the lint-surveyed gate
## Objective
`sh skills/wiki-plan/scripts/plan-gate.sh check lint-surveyed <plan-dir>` prints `ok` (exit 0) when analysis.md's `## Ground truth` has well-formed `- Lint:` bullets, `fail` (exit 3) when it has none or a malformed one, `fail` (exit 4) when analysis.md or `## Ground truth` is missing.
## Wiki pages (read these first, only these)
- wiki/backend/common/llm/binding-instructions-for-agents.md — use for: why the record is a mechanical gate, not prose (D5)
## Inputs
- skills/wiki-plan/scripts/plan-gate.sh — existing `check_constraints_surveyed` is the shape to mirror; `extract_l2`, `has_heading`, `fail3`, `fail4`, `ok` helpers
- tests/plan-gate.bats and tests/fixtures/plan-gate/passing/analysis.md
- Decisions that bind you: D5
## Steps
1. Tests first, appended to tests/plan-gate.bats under a `# --- lint-surveyed ---` comment. Build variant fixtures in `$BATS_TEST_TMPDIR` by copying `$FIX/passing` (never add files under tests/fixtures/ for these):
   - passing fixture -> output `ok`, status 0
   - copy with every `^- Lint: ` line deleted -> status 3, output contains `fail`, stderr/output contains `no '- Lint: ' bullet`
   - copy with the Lint line replaced by `- Lint: npm run lint` (no rc) -> status 3, output contains `malformed Lint bullet`
   - copy whose only Lint line is `- Lint: none — checked: grep -n lint package.json` -> `ok`, status 0
   - copy with the `## Ground truth` heading line deleted -> status 4
   - an empty directory (no analysis.md) -> status 4
2. Add `- Lint: true -> rc=0` to tests/fixtures/plan-gate/passing/analysis.md directly below its `- Baseline:` line.
3. In plan-gate.sh add, after `check_constraints_surveyed`:
```sh
check_lint_surveyed() { # <plan-dir>
  file="$1/analysis.md"
  [ -f "$file" ] || fail4 "analysis.md not found in $1"
  has_heading "$file" "## Ground truth" || fail4 "## Ground truth section missing in $file"
  lines=$(extract_l2 "$file" "## Ground truth" | grep '^- Lint: ' || true)
  [ -n "$lines" ] || fail3 "no '- Lint: ' bullet under ## Ground truth (use '- Lint: none — checked: <command>' when the project has no lint or typecheck command)"
  bad=$(printf '%s\n' "$lines" | grep -v -e '^- Lint: none — checked: .' -e '^- Lint: [^ ].* -> rc=[0-9][0-9]*$' || true)
  [ -z "$bad" ] || fail3 "malformed Lint bullet(s): $(printf '%s' "$bad" | head -1)"
  ok
}
```
4. Add `lint-surveyed) check_lint_surveyed "$plan_dir" ;;` to `do_check`'s case, after `constraints-surveyed`.
5. In the header comment, change the gate-A id list to end `constraints-surveyed lint-surveyed research-evidenced`.
## Deliverables
- skills/wiki-plan/scripts/plan-gate.sh
- tests/plan-gate.bats
- tests/fixtures/plan-gate/passing/analysis.md
## Verify
- PATH=/opt/homebrew/bin:$PATH bats tests/plan-gate.bats tests/emit-gaps.bats tests/loop-gate.bats tests/orchestrate-graph-explore.bats — success = no `not ok` line
- lint: node scripts/wiki-lint-prohibitions.js wiki && echo LINT_OK — success = LINT_OK printed
- lint: bash scripts/gen-agent-tier-variants.sh --check && echo LINT_OK — success = LINT_OK printed
- covers: R4
## Out of scope
- templates/plan-gates.md and the emit count 5->6 (task 02); templates/analysis.md (task 02); wiki-plan SKILL.md prose (task 03)
