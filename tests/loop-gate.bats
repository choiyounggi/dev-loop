#!/usr/bin/env bats
# Tests for hooks/loop-gate.sh (Stop hook).
# Run in CI; the same cases are verified directly via shell during development.

setup() {
  GATE="${BATS_TEST_DIRNAME}/../hooks/loop-gate.sh"
  WS="${BATS_TEST_TMPDIR}/ws"
  mkdir -p "$WS/.orchestration/status"
}

_run_gate() { # <cwd> <stop_hook_active>
  printf '{"cwd":"%s","stop_hook_active":%s}' "$1" "${2:-false}" | bash "$GATE"
}

@test "non-managed session: exit 0 (no .orchestration)" {
  run _run_gate "${BATS_TEST_TMPDIR}" false
  [ "$status" -eq 0 ]
}

@test "incomplete loop (phase=implementing): blocks with exit 2 + advice" {
  printf '{"worktree":"%s","phase":"implementing"}' "$WS" > "$WS/.orchestration/status/t1.json"
  run _run_gate "$WS" false
  [ "$status" -eq 2 ]
  [[ "$output" == *"incomplete"* ]]
}

@test "complete loop (phase=done): allows stop (exit 0)" {
  printf '{"worktree":"%s","phase":"done"}' "$WS" > "$WS/.orchestration/status/t1.json"
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}

@test "stop_hook_active=true: never loops even if incomplete (exit 0)" {
  printf '{"worktree":"%s","phase":"implementing"}' "$WS" > "$WS/.orchestration/status/t1.json"
  run _run_gate "$WS" true
  [ "$status" -eq 0 ]
}

@test "phase incomplete but worktree mismatch: not this session, exit 0" {
  printf '{"worktree":"%s","phase":"implementing"}' "/some/other/wt" > "$WS/.orchestration/status/t1.json"
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}
