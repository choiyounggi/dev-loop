#!/usr/bin/env bats
# Tests for hooks/pre-flush-pr-gate.sh (PreToolUse gate on `gh pr create`).
#
# The gate must block a knowledge-flush PR until an INGEST_REPORT with three
# filled sections exists, while letting every non-flush command pass untouched.
# Stdin is the nested Claude Code PreToolUse payload: {"tool_input":{"command":..}}.
# Exit 0 = allow, exit 2 = deny (message on stderr).

setup() {
  GATE="${BATS_TEST_DIRNAME}/../hooks/pre-flush-pr-gate.sh"

  command -v node >/dev/null || {
    echo "node is required to run the gate tests"
    return 1
  }

  REPORT="${BATS_TEST_TMPDIR}/INGEST_REPORT.md"
}

# A complete, filled report that must satisfy the gate.
_mk_full_report() {
  cat > "$REPORT" <<'EOF'
# Knowledge flush — 1 insight

## Verified best-practice
Claim verified against the official PostgreSQL docs (real URL checked); the
directive reproduces locally; confidence: verified.

## Existing-layer check
Read databases/index.md and both indexing pages; no duplicate trigger found;
added related-links both ways.

## Routing decision
Target databases/indexing — existing category fits; no new category needed.
EOF
}

# Report with one required section removed. $1 = section heading to drop.
_mk_report_missing() {
  _mk_full_report
  grep -v "^## $1\$" "$REPORT" > "$REPORT.tmp" && mv "$REPORT.tmp" "$REPORT"
}

_run_gate() { # <command string>
  printf '{"tool_input":{"command":%s}}' \
    "$(node -e 'process.stdout.write(JSON.stringify(process.argv[1]))' "$1")" \
    | sh "$GATE"
}

@test "normal: a flush PR with a complete INGEST_REPORT passes" {
  _mk_full_report
  run _run_gate "gh pr create --head knowledge/me-1 --label dev-loop:knowledge --body-file $REPORT"
  [ "$status" -eq 0 ]
}

@test "normal: a non-pr command passes untouched" {
  run _run_gate "git status"
  [ "$status" -eq 0 ]
}

@test "normal: a non-flush gh pr create passes untouched" {
  run _run_gate "gh pr create --title 'fix: unrelated' --body-file /nonexistent"
  [ "$status" -eq 0 ]
}

@test "error: flush PR with no --body-file at all is denied" {
  run _run_gate "gh pr create --head knowledge/me-1 --label dev-loop:knowledge --body inline"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no --body-file"* ]]
}

@test "error: flush PR whose body file does not exist is denied" {
  run _run_gate "gh pr create --head knowledge/me-1 --body-file ${BATS_TEST_TMPDIR}/missing.md"
  [ "$status" -eq 2 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "error: missing 'Verified best-practice' section is denied and named" {
  _mk_report_missing "Verified best-practice"
  run _run_gate "gh pr create --head knowledge/me-1 --body-file $REPORT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Verified best-practice"* ]]
}

@test "error: missing 'Existing-layer check' section is denied and named" {
  _mk_report_missing "Existing-layer check"
  run _run_gate "gh pr create --head knowledge/me-1 --body-file $REPORT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Existing-layer check"* ]]
}

@test "error: missing 'Routing decision' section is denied and named" {
  _mk_report_missing "Routing decision"
  run _run_gate "gh pr create --head knowledge/me-1 --body-file $REPORT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Routing decision"* ]]
}

@test "boundary: headers-only report (empty stubs) is denied" {
  printf '## Verified best-practice\n## Existing-layer check\n## Routing decision\n' > "$REPORT"
  run _run_gate "gh pr create --head knowledge/me-1 --body-file $REPORT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"empty"* ]]
}

@test "boundary: each flush marker alone engages the gate (head / label / INGEST_REPORT)" {
  for marker in \
    "--head knowledge/me-1 --body-file ${BATS_TEST_TMPDIR}/missing.md" \
    "--label dev-loop:knowledge --body-file ${BATS_TEST_TMPDIR}/missing.md" \
    "--body-file ${BATS_TEST_TMPDIR}/missing_INGEST_REPORT.md"; do
    run _run_gate "gh pr create $marker"
    [ "$status" -eq 2 ]
  done
}

@test "boundary: prose mentioning gh pr create does not trip the gate" {
  run _run_gate "echo 'docs say: gh pr create --head knowledge/x needs a report'"
  [ "$status" -eq 0 ]
}

@test "regression: a double-quoted --body-file path is still recognized" {
  _mk_full_report
  run _run_gate "gh pr create --head knowledge/me-1 --body-file \"$REPORT\""
  [ "$status" -eq 0 ]
}

@test "regression: a \$HOME-prefixed --body-file path is expanded by the gate" {
  # The skill's example command writes the path with $HOME; the gate sees the
  # command text unexpanded and must resolve that prefix itself.
  export HOME="$BATS_TEST_TMPDIR"
  REPORT="$HOME/INGEST_REPORT.md"
  _mk_full_report
  run _run_gate 'gh pr create --head knowledge/me-1 --body-file "$HOME/INGEST_REPORT.md"'
  [ "$status" -eq 0 ]
}
