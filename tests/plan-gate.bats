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

@test "emit A: writes 5 gates, all CHECK/EXPECT/EVIDENCE lines present" {
  run sh "$PG" emit A "$FIX/passing" "$WORK/plan-A-fixture.md"
  [ "$status" -eq 0 ]
  [ -f "$WORK/plan-A-fixture.md" ]
  ids="baseline-tests-ran affected-files-evidenced open-questions-resolved constraints-surveyed research-evidenced"
  for id in $ids; do
    grep -q -- "- \[ \] ${id}:" "$WORK/plan-A-fixture.md"
  done
  [ "$(grep -c '^  CHECK: ' "$WORK/plan-A-fixture.md")" -eq 5 ]
  [ "$(grep -c '^  EXPECT: ' "$WORK/plan-A-fixture.md")" -eq 5 ]
  [ "$(grep -c '^  EVIDENCE: pending' "$WORK/plan-A-fixture.md")" -eq 5 ]
  ! grep -q '{PLAN_DIR}' "$WORK/plan-A-fixture.md"
  ! grep -q '{BASELINE_CMD}' "$WORK/plan-A-fixture.md"
  grep -q 'CHECK: true && echo GATE_OK' "$WORK/plan-A-fixture.md"
}

@test "emit B: writes 3 gates, all CHECK/EXPECT/EVIDENCE lines present" {
  run sh "$PG" emit B "$FIX/passing" "$WORK/plan-B-fixture.md"
  [ "$status" -eq 0 ]
  ids="groundings-exist decision-rows-complete reviewer-verdict"
  for id in $ids; do
    grep -q -- "- \[ \] ${id}:" "$WORK/plan-B-fixture.md"
  done
  [ "$(grep -c '^  CHECK: ' "$WORK/plan-B-fixture.md")" -eq 3 ]
  [ "$(grep -c '^  EXPECT: ' "$WORK/plan-B-fixture.md")" -eq 3 ]
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
  [[ "$output" == *"unmet=5"* ]] || [[ "$output" == *"met=5"* ]]
}

@test "emitted ledger --run reaches MET for every gate-A id when the plan-dir is well formed" {
  sh "$PG" emit A "$FIX/passing" "$WORK/plan-A-run.md"
  CLAUDE_PLUGIN_ROOT="${BATS_TEST_DIRNAME}/.." run bash "$GC" --run "$WORK/plan-A-run.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"met=5 unmet=0"* ]]
}

@test "emitted ledger --run reaches MET for every gate-B id when the plan-dir is well formed" {
  sh "$PG" emit B "$FIX/passing" "$WORK/plan-B-run.md"
  CLAUDE_PLUGIN_ROOT="${BATS_TEST_DIRNAME}/.." run bash "$GC" --run "$WORK/plan-B-run.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"met=3 unmet=0"* ]]
}
