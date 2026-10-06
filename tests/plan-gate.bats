#!/usr/bin/env bats
# Tests for skills/wiki-plan/scripts/plan-gate.sh (Phase A/B plan gates).
# Covers normal (check ok, emit), error (usage, unknown gate), and boundary
# cases (content-defect fail vs target-missing fail, per gate-A0-B) using the
# fixtures under tests/fixtures/plan-gate/.

setup() {
  PG="${BATS_TEST_DIRNAME}/../skills/wiki-plan/scripts/plan-gate.sh"
  GC="${BATS_TEST_DIRNAME}/../skills/loop-implement/scripts/gate-check.sh"
  FIX="${BATS_TEST_DIRNAME}/fixtures/plan-gate"
  # groundings-exist joins <wiki-root>/<Wiki-basis-cell>, and every Wiki basis
  # cell already carries a leading "wiki/" (repo convention) — so the root
  # passed here is the fixture root, one level above the wiki/ subtree.
  WIKI="${FIX}"
  WORK="${BATS_TEST_TMPDIR}/work"
  mkdir -p "$WORK"
  cd "$WORK"
}

# local_design <plan-dir> <basis> — a one-row design.md citing <basis>
local_design() {
  mkdir -p "$1"
  cat > "$1/design.md" <<EOF2
## Decisions
| # | Decision | Choice | Wiki basis | Rejected alternative | Testability |
|---|----------|--------|------------|----------------------|-------------|
| 1 | Local rule | choice X | $2 | choice Y | plan-gate.bats |
EOF2
}

# ---------- usage errors (exit 2) ----------

@test "no args: usage error exit 2" {
  run sh "$PG"
  [ "$status" -eq 2 ]
}

@test "unknown mode: usage error exit 2" {
  run sh "$PG" bogus
  [ "$status" -eq 2 ]
}

@test "check with no gate-id: usage error exit 2" {
  run sh "$PG" check
  [ "$status" -eq 2 ]
}

@test "check with no plan-dir: usage error exit 2" {
  run sh "$PG" check baseline-tests-ran
  [ "$status" -eq 2 ]
}

@test "check with unknown gate id: usage error exit 2" {
  run sh "$PG" check not-a-real-gate "$FIX/passing"
  [ "$status" -eq 2 ]
}

@test "emit with bad phase: usage error exit 2" {
  run sh "$PG" emit C "$FIX/passing" "$WORK/out.md"
  [ "$status" -eq 2 ]
}

@test "emit with missing out-file arg: usage error exit 2" {
  run sh "$PG" emit A "$FIX/passing"
  [ "$status" -eq 2 ]
}

# ---------- check: passing fixture -> ok, exit 0 (one per gate) ----------

@test "check baseline-tests-ran: passing fixture -> ok" {
  run sh "$PG" check baseline-tests-ran "$FIX/passing"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "check affected-files-evidenced: passing fixture -> ok" {
  run sh "$PG" check affected-files-evidenced "$FIX/passing"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "check open-questions-resolved: passing fixture -> ok" {
  run sh "$PG" check open-questions-resolved "$FIX/passing"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "check constraints-surveyed: passing fixture -> ok" {
  run sh "$PG" check constraints-surveyed "$FIX/passing"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "check research-evidenced: passing fixture -> ok" {
  run sh "$PG" check research-evidenced "$FIX/passing"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "check groundings-exist: passing fixture -> ok" {
  run sh "$PG" check groundings-exist "$FIX/passing" "$WIKI"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "check groundings-exist: [no-wiki] cell is skipped, not a miss" {
  mkdir -p "$WORK/plan"
  cat > "$WORK/plan/design.md" <<'EOF'
## Decisions
| # | Decision | Choice | Wiki basis | Rejected alternative | Testability |
|---|----------|--------|------------|----------------------|-------------|
| 1 | Something novel | choice X | [no-wiki] | choice Y | plan-gate.bats |
EOF
  run sh "$PG" check groundings-exist "$WORK/plan" "$WIKI"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "check decision-rows-complete: passing fixture -> ok" {
  run sh "$PG" check decision-rows-complete "$FIX/passing"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "check reviewer-verdict: passing fixture -> ok" {
  run sh "$PG" check reviewer-verdict "$FIX/passing"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

# ---------- check: failing fixture -> fail, exit 3 (content defect) ----------

@test "check baseline-tests-ran: unparseable Baseline command -> fail exit 3" {
  run sh "$PG" check baseline-tests-ran "$FIX/failing/baseline-tests-ran"
  [ "$status" -eq 3 ]
  [ "${lines[0]}" = "fail" ]
}

@test "check baseline-tests-ran: never executes the command (false still -> ok)" {
  run sh "$PG" check baseline-tests-ran "$FIX/nonexec"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "check affected-files-evidenced: bullet without evidence -> fail exit 3" {
  run sh "$PG" check affected-files-evidenced "$FIX/failing/affected-files-evidenced"
  [ "$status" -eq 3 ]
  [ "${lines[0]}" = "fail" ]
}

@test "check open-questions-resolved: unresolved OPEN: -> fail exit 3" {
  run sh "$PG" check open-questions-resolved "$FIX/failing/open-questions-resolved"
  [ "$status" -eq 3 ]
  [ "${lines[0]}" = "fail" ]
}

@test "check constraints-surveyed: no bullets -> fail exit 3" {
  run sh "$PG" check constraints-surveyed "$FIX/failing/constraints-surveyed"
  [ "$status" -eq 3 ]
  [ "${lines[0]}" = "fail" ]
}

@test "check research-evidenced: no data row, no no-useful-results line -> fail exit 3" {
  run sh "$PG" check research-evidenced "$FIX/failing/research-evidenced"
  [ "$status" -eq 3 ]
  [ "${lines[0]}" = "fail" ]
}

@test "check groundings-exist: cited page does not exist -> fail exit 3" {
  run sh "$PG" check groundings-exist "$FIX/failing/groundings-exist" "$WIKI"
  [ "$status" -eq 3 ]
  [ "${lines[0]}" = "fail" ]
}

@test "check decision-rows-complete: blank cell -> fail exit 3" {
  run sh "$PG" check decision-rows-complete "$FIX/failing/decision-rows-complete"
  [ "$status" -eq 3 ]
  [ "${lines[0]}" = "fail" ]
}

@test "check reviewer-verdict: VERDICT: FAIL -> fail exit 3" {
  run sh "$PG" check reviewer-verdict "$FIX/failing/reviewer-verdict"
  [ "$status" -eq 3 ]
  [ "${lines[0]}" = "fail" ]
}

# ---------- check: target missing -> fail, exit 4 (distinct from exit 3) ----

@test "check baseline-tests-ran: no Ground truth section -> fail exit 4" {
  run sh "$PG" check baseline-tests-ran "$FIX/missing/baseline-tests-ran"
  [ "$status" -eq 4 ]
  [ "${lines[0]}" = "fail" ]
}

@test "check affected-files-evidenced: no Affected files section -> fail exit 4" {
  run sh "$PG" check affected-files-evidenced "$FIX/missing/affected-files-evidenced"
  [ "$status" -eq 4 ]
  [ "${lines[0]}" = "fail" ]
}

@test "check open-questions-resolved: no Requirements section -> fail exit 4" {
  run sh "$PG" check open-questions-resolved "$FIX/missing/open-questions-resolved"
  [ "$status" -eq 4 ]
  [ "${lines[0]}" = "fail" ]
}

@test "check constraints-surveyed: no Constraints section -> fail exit 4" {
  run sh "$PG" check constraints-surveyed "$FIX/missing/constraints-surveyed"
  [ "$status" -eq 4 ]
  [ "${lines[0]}" = "fail" ]
}

@test "check research-evidenced: no Research section -> fail exit 4" {
  run sh "$PG" check research-evidenced "$FIX/missing/research-evidenced"
  [ "$status" -eq 4 ]
  [ "${lines[0]}" = "fail" ]
}

@test "check groundings-exist: no Decisions section -> fail exit 4" {
  run sh "$PG" check groundings-exist "$FIX/missing/groundings-exist" "$WIKI"
  [ "$status" -eq 4 ]
  [ "${lines[0]}" = "fail" ]
}

@test "check decision-rows-complete: no Decisions section -> fail exit 4" {
  run sh "$PG" check decision-rows-complete "$FIX/missing/decision-rows-complete"
  [ "$status" -eq 4 ]
  [ "${lines[0]}" = "fail" ]
}

@test "check reviewer-verdict: review-verdict.md absent -> fail exit 4" {
  run sh "$PG" check reviewer-verdict "$FIX/missing/reviewer-verdict"
  [ "$status" -eq 4 ]
  [ "${lines[0]}" = "fail" ]
}

@test "check: plan-dir itself absent -> fail exit 4" {
  run sh "$PG" check baseline-tests-ran "$FIX/missing/does-not-exist"
  [ "$status" -eq 4 ]
  [ "${lines[0]}" = "fail" ]
}

@test "check: analysis.md absent entirely -> fail exit 4" {
  run sh "$PG" check research-evidenced "$FIX/missing/empty-dir"
  [ "$status" -eq 4 ]
  [ "${lines[0]}" = "fail" ]
}

@test "check: design.md absent entirely -> fail exit 4" {
  run sh "$PG" check groundings-exist "$FIX/missing/empty-dir" "$WIKI"
  [ "$status" -eq 4 ]
  [ "${lines[0]}" = "fail" ]
}

# ---------------------------------------------------------------- emit -----

@test "emit A: writes 6 gates, all CHECK/EXPECT/EVIDENCE lines present" {
  run sh "$PG" emit A "$FIX/passing" "$WORK/plan-A-fixture.md"
  [ "$status" -eq 0 ]
  [ -f "$WORK/plan-A-fixture.md" ]
  ids="baseline-tests-ran affected-files-evidenced open-questions-resolved constraints-surveyed lint-surveyed research-evidenced"
  for id in $ids; do
    grep -q -- "- \[ \] ${id}:" "$WORK/plan-A-fixture.md"
  done
  [ "$(grep -c '^  CHECK: ' "$WORK/plan-A-fixture.md")" -eq 6 ]
  [ "$(grep -c '^  EXPECT: ' "$WORK/plan-A-fixture.md")" -eq 6 ]
  [ "$(grep -c '^  EVIDENCE: pending' "$WORK/plan-A-fixture.md")" -eq 6 ]
  ! grep -q '{PLAN_DIR}' "$WORK/plan-A-fixture.md"
  ! grep -q '{BASELINE_CMD}' "$WORK/plan-A-fixture.md"
  grep -q 'CHECK: true && echo GATE_OK' "$WORK/plan-A-fixture.md"
}

@test "emit B: writes 5 gates, all CHECK/EXPECT/EVIDENCE lines present" {
  run sh "$PG" emit B "$FIX/passing" "$WORK/plan-B-fixture.md"
  [ "$status" -eq 0 ]
  ids="groundings-exist decision-rows-complete requirements-covered reviewer-verdict gaps-emitted"
  for id in $ids; do
    grep -q -- "- \[ \] ${id}:" "$WORK/plan-B-fixture.md"
  done
  [ "$(grep -c '^  CHECK: ' "$WORK/plan-B-fixture.md")" -eq 5 ]
  [ "$(grep -c '^  EXPECT: ' "$WORK/plan-B-fixture.md")" -eq 5 ]
  ! grep -q '{PLAN_DIR}' "$WORK/plan-B-fixture.md"
}

@test "emit A: plan-dir missing -> fail exit 4" {
  run sh "$PG" emit A "$FIX/missing/does-not-exist" "$WORK/out.md"
  [ "$status" -eq 4 ]
}

@test "emit A: analysis.md has no Baseline line -> fail exit 4" {
  run sh "$PG" emit A "$FIX/missing/open-questions-resolved" "$WORK/out.md"
  [ "$status" -eq 4 ]
}

@test "emit output is parseable by gate-check.sh --status unmodified (no PARSE error)" {
  sh "$PG" emit A "$FIX/passing" "$WORK/plan-A-parse.md"
  run bash "$GC" --status "$WORK/plan-A-parse.md"
  [[ "$output" != *PARSE* ]]
  [[ "$output" == *"unmet=6"* ]] || [[ "$output" == *"met=6"* ]]
}

@test "emitted ledger --run reaches MET for every gate-A id when the plan-dir is well formed" {
  sh "$PG" emit A "$FIX/passing" "$WORK/plan-A-run.md"
  CLAUDE_PLUGIN_ROOT="${BATS_TEST_DIRNAME}/.." run bash "$GC" --run "$WORK/plan-A-run.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"met=6 unmet=0"* ]]
}

@test "emitted ledger --run reaches MET for every gate-B id when the plan-dir is well formed" {
  sh "$PG" emit B "$FIX/passing" "$WORK/plan-B-run.md"
  printf '# Change Log\n\n' > "$WORK/log.md"
  CLAUDE_PLUGIN_ROOT="${BATS_TEST_DIRNAME}/.." DEV_LOOP_LOG_MD="$WORK/log.md" DEV_LOOP_QUEUE_DIR="$WORK/queue" run bash "$GC" --run "$WORK/plan-B-run.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"met=5 unmet=0"* ]]
}

# ---------- groundings-exist: project-local layer (issue #194 A) ----------

@test "groundings-exist: a present wiki-local page cited from plans/<feature> -> ok" {
  mkdir -p wiki-local/alpha/cat
  printf '# p\n' > wiki-local/alpha/cat/page.md
  local_design plans/feat wiki-local/alpha/cat/page.md
  run sh "$PG" check groundings-exist plans/feat "$WIKI"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "groundings-exist: the ancestor walk finds wiki-local/ from .orchestration/plans/<task>" {
  mkdir -p proj/wiki-local/alpha/cat
  printf '# p\n' > proj/wiki-local/alpha/cat/page.md
  local_design proj/.orchestration/plans/t9 wiki-local/alpha/cat/page.md
  mkdir -p elsewhere
  cd elsewhere
  [ ! -d wiki-local ]
  run sh "$PG" check groundings-exist ../proj/.orchestration/plans/t9 "$WIKI"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "groundings-exist: a plan dir that itself holds wiki-local/ is its own project root (boundary)" {
  # the walk starts AT the resolved plan dir, not at its parent: here the only
  # wiki-local/ in the tree sits inside the plan dir itself.
  mkdir -p planroot/wiki-local/alpha/cat
  printf '# p\n' > planroot/wiki-local/alpha/cat/page.md
  local_design planroot wiki-local/alpha/cat/page.md
  mkdir -p elsewhere
  cd elsewhere
  [ ! -d wiki-local ]
  [ ! -d ../wiki-local ]
  run sh "$PG" check groundings-exist ../planroot "$WIKI"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "negative control: with no wiki-local/ above the plan dir the walk falls back to the cwd -> fail exit 3" {
  mkdir -p proj/.orchestration/plans/t9 elsewhere
  local_design proj/.orchestration/plans/t9 wiki-local/alpha/cat/page.md
  cd elsewhere
  [ ! -d wiki-local ]
  run sh "$PG" check groundings-exist ../proj/.orchestration/plans/t9 "$WIKI"
  [ "$status" -eq 3 ]
  [ "${lines[0]}" = "fail" ]
  [[ "$output" == *"not found under $WORK/elsewhere (project-local layer): wiki-local/alpha/cat/page.md"* ]]
}

@test "groundings-exist: a basis that only looks local (wiki-localX/...) resolves against the bundled root" {
  # the prefix that routes a basis to the project-local root is exactly
  # "wiki-local/": a sibling directory whose name merely starts with it stays a
  # bundled citation, even when that same path exists under the project root.
  mkdir -p wiki-local/alpha/cat wiki-localX/alpha/cat
  printf '# p\n' > wiki-local/alpha/cat/page.md
  printf '# p\n' > wiki-localX/alpha/cat/page.md
  local_design plans/feat wiki-localX/alpha/cat/page.md
  run sh "$PG" check groundings-exist plans/feat "$WIKI"
  [ "$status" -eq 3 ]
  [ "${lines[0]}" = "fail" ]
  [[ "$output" == *"not found under $WIKI: wiki-localX/alpha/cat/page.md"* ]]
  [[ "$output" != *"project-local layer"* ]]
}

@test "groundings-exist: an absent wiki-local page -> fail exit 3 naming the project-local layer" {
  mkdir -p wiki-local/alpha/cat
  local_design plans/feat wiki-local/alpha/cat/absent.md
  run sh "$PG" check groundings-exist plans/feat "$WIKI"
  [ "$status" -eq 3 ]
  [ "${lines[0]}" = "fail" ]
  [[ "$output" == *"not found under $WORK (project-local layer): wiki-local/alpha/cat/absent.md"* ]]
  [[ "$output" != *"not found under $WIKI"* ]]
}

@test "groundings-exist: no wiki-local/ dir -> bundled behavior and stderr unchanged (boundary)" {
  [ ! -d wiki-local ]
  local_design plans/feat wiki/platforms/shells/portable-shell-scripts.md
  run sh "$PG" check groundings-exist plans/feat "$WIKI"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
  run sh "$PG" check groundings-exist "$FIX/failing/groundings-exist" "$WIKI"
  [ "$status" -eq 3 ]
  [ "${lines[0]}" = "fail" ]
  [[ "$output" == *"Wiki basis page(s) not found under $WIKI: wiki/does/not/exist.md"* ]]
  [[ "$output" != *"project-local layer"* ]]
}

@test "groundings-exist: with a miss in EACH root the bundled miss is the one reported (priority)" {
  mkdir -p wiki-local/alpha/cat plans/feat
  cat > plans/feat/design.md <<EOF2
## Decisions
| # | Decision | Choice | Wiki basis | Rejected alternative | Testability |
|---|----------|--------|------------|----------------------|-------------|
| 1 | Bundled rule | choice X | wiki/does/not/exist.md | choice Y | plan-gate.bats |
| 2 | Local rule | choice X | wiki-local/alpha/cat/absent.md | choice Y | plan-gate.bats |
EOF2
  run sh "$PG" check groundings-exist plans/feat "$WIKI"
  [ "$status" -eq 3 ]
  [ "${lines[0]}" = "fail" ]
  [[ "$output" == *"not found under $WIKI: wiki/does/not/exist.md"* ]]
  [[ "$output" != *"project-local layer"* ]]
}

@test "negative control: the same local citation in a project without wiki-local/ -> fail exit 3" {
  [ ! -d wiki-local ]
  local_design plans/feat wiki-local/alpha/cat/page.md
  run sh "$PG" check groundings-exist plans/feat "$WIKI"
  [ "$status" -eq 3 ]
  [ "${lines[0]}" = "fail" ]
  [[ "$output" == *"not found under $WORK (project-local layer): wiki-local/alpha/cat/page.md"* ]]
  [[ "$output" != *"not found under $WIKI"* ]]
}

# ------------------------------------------------------ requirements-covered --

# req_plan <dir> <rule-cell>... — analysis.md whose ## Requirements table has
# one row per <rule-cell>; the caller writes design.md.
req_plan() {
  d="$1"; shift
  mkdir -p "$d"
  {
    printf '## Requirements\n| Rule | Concrete example | Open question |\n|------|------------------|---------------|\n'
    for r in "$@"; do printf '| %s | given x, then y | |\n' "$r"; done
    printf '\n## Ground truth\n- Baseline: true -> rc=0, HEAD abc1234, git status clean\n'
  } > "$d/analysis.md"
}

# req_design <dir> <row-text>... — design.md whose ## Decisions rows carry
# <row-text> in the Testability cell.
req_design() {
  d="$1"; shift
  {
    printf '## Decisions\n| # | Decision | Choice | Wiki basis | Rejected alternative | Testability |\n|---|---|---|---|---|---|\n'
    i=0
    for t in "$@"; do i=$((i + 1)); printf '| D%s | d | c | [no-wiki] | r | %s |\n' "$i" "$t"; done
  } > "$d/design.md"
}

@test "requirements-covered: every rule named by a Decision row -> ok" {
  req_plan p "R1: login works" "R2. logout works"
  req_design p "covers R1" "covers R2"
  run sh "$PG" check requirements-covered p
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "requirements-covered: rules named by no Decision row -> fail exit 3 listing them" {
  req_plan p "R1: a" "R2: b" "R3: c"
  req_design p "covers R1"
  run sh "$PG" check requirements-covered p
  [ "$status" -eq 3 ]
  [ "${lines[0]}" = "fail" ]
  [[ "$output" == *"Rule(s) named by no ## Decisions row: R2 R3"* ]]
}

@test "requirements-covered: ranges with -, en dash and .. expand; Korean text does not break awk" {
  req_plan p "R1: 가" "R2: 나" "R3: 다" "R4: 라" "R5: 마" "R6: 바" "R7: 사"
  req_design p "검증 R1–R3 한글" "R4-R5" "R6..R7 끝"
  run sh "$PG" check requirements-covered p
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "requirements-covered: R<n> glued to a word (PR2, XR2) is not a citation" {
  req_plan p "R1: a" "R2: b"
  req_design p "covers R1, see PR2 and XR2"
  run sh "$PG" check requirements-covered p
  [ "$status" -eq 3 ]
  [[ "$output" == *"no ## Decisions row: R2"* ]]
}

@test "requirements-covered: an id named only outside the Decisions table does not count" {
  req_plan p "R1: a" "R2: b"
  req_design p "covers R1"
  printf '\n## Constraints\n- R2 is handled elsewhere\n' >> p/design.md
  run sh "$PG" check requirements-covered p
  [ "$status" -eq 3 ]
  [[ "$output" == *"no ## Decisions row: R2"* ]]
}

@test "requirements-covered: a bold or backticked rule id is still read" {
  req_plan p "**R1**: a" "\`R2\` b"
  req_design p "R1 R2"
  run sh "$PG" check requirements-covered p
  [ "$status" -eq 0 ]
}

@test "requirements-covered: a rule row with no leading R<n> id -> fail exit 3" {
  req_plan p "R1: a" "login must work"
  req_design p "R1"
  run sh "$PG" check requirements-covered p
  [ "$status" -eq 3 ]
  [[ "$output" == *"1 ## Requirements row(s) have no leading R<n> id"* ]]
}

@test "requirements-covered: an empty Requirements table -> fail exit 3" {
  req_plan p
  req_design p "R1"
  run sh "$PG" check requirements-covered p
  [ "$status" -eq 3 ]
  [[ "$output" == *"## Requirements has no rule rows"* ]]
}

@test "requirements-covered: design.md absent -> fail exit 4" {
  req_plan p "R1: a"
  run sh "$PG" check requirements-covered p
  [ "$status" -eq 4 ]
  [ "${lines[0]}" = "fail" ]
}

@test "requirements-covered: ## Requirements heading absent -> fail exit 4" {
  mkdir -p p
  printf '# Analysis\n' > p/analysis.md
  req_design p "R1"
  run sh "$PG" check requirements-covered p
  [ "$status" -eq 4 ]
}

@test "prose wiring: requirements-covered is named by the gate-B ids line, the pre-review check and the analysis template" {
  root="${BATS_TEST_DIRNAME}/.."
  [[ "$(grep -n 'Gate ids:' "$root/skills/wiki-plan/SKILL.md" | grep groundings-exist)" == *"requirements-covered"* ]]
  grep -q '^\*\*Pre-review check\*\*' "$root/skills/wiki-plan/SKILL.md"
  grep -q 'Start every Rule cell with its id' "$root/templates/analysis.md"
  grep -q 'check requirements-covered <plan dir>' "$root/agents/task-planner.md"
}

@test "prose wiring: orchestrate routes a missing-R<n> failure to the analyst and bounds the bounces" {
  orch="${BATS_TEST_DIRNAME}/../skills/orchestrate/SKILL.md"
  grep -q 'check requirements-covered <plan dir>' "$orch"
  grep -q 'failure to the same `task-analyst` first' "$orch"
  grep -q '`fail` on the same task is escalated to the user' "$orch"
}

@test "requirements-covered: an id in a second table under ## Decisions does not count" {
  req_plan p "R1: a" "R2: b"
  req_design p "covers R1"
  printf '\nAlternatives below.\n\n| Alt | Why rejected |\n|---|---|\n| R2 approach | too slow |\n' >> p/design.md
  run sh "$PG" check requirements-covered p
  [ "$status" -eq 3 ]
  [[ "$output" == *"no ## Decisions row: R2"* ]]
}

@test "requirements-covered: a Rule cell naming several ids (R1/R2, R3, R4) needs each one covered" {
  req_plan p "R1/R2: a" "R3, R4: b"
  req_design p "covers R1, R3"
  run sh "$PG" check requirements-covered p
  [ "$status" -eq 3 ]
  [[ "$output" == *"no ## Decisions row: R2 R4"* ]]
}

@test "requirements-covered: a range wider than 100 still names every number in it" {
  req_plan p "R1: a" "R120: b"
  req_design p "covers R1-R150"
  run sh "$PG" check requirements-covered p
  [ "$status" -eq 0 ]
}

# --- lint-surveyed ---
# Variants are built from the passing fixture in $BATS_TEST_TMPDIR, so the
# only difference from a passing analysis.md is the line under test.

lint_variant() { # <name> <sed expression> -> prints the variant plan dir
  d="${BATS_TEST_TMPDIR}/lint-$1"
  mkdir -p "$d"
  sed -e "$2" "$FIX/passing/analysis.md" > "$d/analysis.md"
  printf '%s\n' "$d"
}

@test "check lint-surveyed: passing fixture -> ok" {
  run sh "$PG" check lint-surveyed "$FIX/passing"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "check lint-surveyed: an explicit 'none — checked:' bullet -> ok" {
  d="$(lint_variant none 's/^- Lint: .*/- Lint: none — checked: grep -n lint package.json/')"
  run sh "$PG" check lint-surveyed "$d"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}

@test "check lint-surveyed: no Lint bullet -> fail exit 3" {
  d="$(lint_variant absent '/^- Lint: /d')"
  run sh "$PG" check lint-surveyed "$d"
  [ "$status" -eq 3 ]
  [ "${lines[0]}" = "fail" ]
  [[ "$output" == *"no '- Lint: ' bullet"* ]]
}

@test "check lint-surveyed: a Lint bullet with no rc -> fail exit 3" {
  d="$(lint_variant norc 's/^- Lint: .*/- Lint: npm run lint/')"
  run sh "$PG" check lint-surveyed "$d"
  [ "$status" -eq 3 ]
  [ "${lines[0]}" = "fail" ]
  [[ "$output" == *"malformed Lint bullet"* ]]
}

@test "check lint-surveyed: no Ground truth heading -> fail exit 4" {
  d="$(lint_variant noheading '/^## Ground truth$/d')"
  run sh "$PG" check lint-surveyed "$d"
  [ "$status" -eq 4 ]
  [ "${lines[0]}" = "fail" ]
}

@test "check lint-surveyed: empty plan dir (no analysis.md) -> fail exit 4" {
  mkdir -p "${BATS_TEST_TMPDIR}/lint-empty"
  run sh "$PG" check lint-surveyed "${BATS_TEST_TMPDIR}/lint-empty"
  [ "$status" -eq 4 ]
  [[ "$output" == *"analysis.md not found"* ]]
}

# --- gate-A ledger carries lint-surveyed ---

@test "emit A: the ledger runs plan-gate.sh check lint-surveyed" {
  sh "$PG" emit A "$FIX/passing" "$WORK/plan-A-lint.md"
  content="$(cat "$WORK/plan-A-lint.md")"
  [[ "$content" == *"- [ ] lint-surveyed:"* ]]
  [[ "$content" == *"plan-gate.sh check lint-surveyed "* ]]
}

@test "negative control: a plan-gates.md copy without the lint-surveyed block names no lint-surveyed gate" {
  stripped="${BATS_TEST_TMPDIR}/plan-gates-no-lint.md"
  awk '/^- \[ \] lint-surveyed:/{skip=1} skip && /^  EVIDENCE:/{skip=0; next} !skip' \
    "${BATS_TEST_DIRNAME}/../templates/plan-gates.md" > "$stripped"
  run grep -c 'lint-surveyed' "$stripped"
  [ "$output" = "0" ]
}

@test "templates/analysis.md shows the Lint bullet and its none-checked form" {
  tpl="${BATS_TEST_DIRNAME}/../templates/analysis.md"
  content="$(cat "$tpl")"
  [[ "$content" == *"- Lint: <lint or typecheck command> -> rc=<n>"* ]]
  [[ "$content" == *"- Lint: none — checked: <command that confirmed it>"* ]]
}

@test "check lint-surveyed: 'none — checked:' followed only by spaces -> fail exit 3" {
  d="$(lint_variant blankcmd 's/^- Lint: .*/- Lint: none — checked:  /')"
  run sh "$PG" check lint-surveyed "$d"
  [ "$status" -eq 3 ]
  [[ "$output" == *"malformed Lint bullet"* ]]
}

# --- CRLF plan files (D10) ---

crlf_copy() { # <src-dir> <name> -> prints the CRLF copy dir
  d="${BATS_TEST_TMPDIR}/crlf-$2"
  mkdir -p "$d"
  for f in "$1"/*.md; do sed 's/$/\r/' "$f" > "$d/$(basename "$f")"; done
  printf '%s\n' "$d"
}

@test "CRLF: every gate id judges a CRLF copy of the passing fixture ok" {
  d="$(crlf_copy "$FIX/passing" all)"
  [[ "$(cat "$d/analysis.md")" == *$'\r'* ]]
  for id in baseline-tests-ran affected-files-evidenced open-questions-resolved constraints-surveyed lint-surveyed research-evidenced groundings-exist decision-rows-complete requirements-covered reviewer-verdict; do
    run sh "$PG" check "$id" "$d" "$WIKI"
    [ "$status" -eq 0 ] || { echo "gate $id: $output"; false; }
    [ "$output" = "ok" ]
  done
}

@test "CRLF: emit A takes the Baseline command without a trailing CR" {
  d="$(crlf_copy "$FIX/passing" emit)"
  run sh "$PG" emit A "$d" "$WORK/plan-A-crlf.md"
  [ "$status" -eq 0 ]
  content="$(cat "$WORK/plan-A-crlf.md")"
  [[ "$content" == *"CHECK: true && echo GATE_OK"* ]]
  [[ "$content" != *$'\r'* ]]
}

@test "CRLF: a CRLF copy with no Ground truth heading still exits 4" {
  d="$(crlf_copy "$FIX/passing" noheading)"
  grep -v '^## Ground truth' "$d/analysis.md" > "$d/a.tmp" && mv "$d/a.tmp" "$d/analysis.md"
  run sh "$PG" check lint-surveyed "$d"
  [ "$status" -eq 4 ]
}
