#!/usr/bin/env bats
# Tests for hooks/loop-gate.sh (Stop hook).
# Run in CI; the same cases are verified directly via shell during development.

setup() {
  GATE="${BATS_TEST_DIRNAME}/../hooks/loop-gate.sh"
  WS="${BATS_TEST_TMPDIR}/ws"
  mkdir -p "$WS/.orchestration/status"
  FAKE_TMUX="${BATS_TEST_TMPDIR}/fake-tmux"
  cat > "$FAKE_TMUX" <<'EOF'
#!/usr/bin/env bash
# Stub: answers `display-message -p '#S'` with $FAKE_TMUX_SESSION.
if [ "$1" = "display-message" ]; then
  printf '%s\n' "${FAKE_TMUX_SESSION:-}"
  exit 0
fi
exit 1
EOF
  chmod +x "$FAKE_TMUX"
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

# --- Terminal wait-phase allowlist (#127) ---

@test "phase=plan_ready, worker identity match: allows stop (exit 0)" {
  printf '{"worktree":"%s","phase":"plan_ready","session":"work-t1"}' "$WS" > "$WS/.orchestration/status/t1.json"
  export TMUX=/tmp/fake-socket LOOP_GATE_TMUX="$FAKE_TMUX" FAKE_TMUX_SESSION="work-t1"
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}

@test "phase=impl_done, worker identity match: allows stop (exit 0)" {
  printf '{"worktree":"%s","phase":"impl_done","session":"work-t1"}' "$WS" > "$WS/.orchestration/status/t1.json"
  export TMUX=/tmp/fake-socket LOOP_GATE_TMUX="$FAKE_TMUX" FAKE_TMUX_SESSION="work-t1"
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}

# --- Session identity check: block only the managed tmux worker ---

@test "worker identity match + phase=implementing: blocks (exit 2)" {
  printf '{"worktree":"%s","phase":"implementing","session":"work-t1"}' "$WS" > "$WS/.orchestration/status/t1.json"
  export TMUX=/tmp/fake-socket LOOP_GATE_TMUX="$FAKE_TMUX" FAKE_TMUX_SESSION="work-t1"
  run _run_gate "$WS" false
  [ "$status" -eq 2 ]
  [[ "$output" == *"incomplete"* ]]
}

@test "cwd matches but tmux session differs from record .session: not blocked (exit 0)" {
  printf '{"worktree":"%s","phase":"implementing","session":"work-t1"}' "$WS" > "$WS/.orchestration/status/t1.json"
  export TMUX=/tmp/fake-socket LOOP_GATE_TMUX="$FAKE_TMUX" FAKE_TMUX_SESSION="some-other-session"
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}

@test "cwd matches, not in tmux, .session set: not blocked (exit 0)" {
  printf '{"worktree":"%s","phase":"implementing","session":"work-t1"}' "$WS" > "$WS/.orchestration/status/t1.json"
  unset TMUX
  export LOOP_GATE_TMUX="$FAKE_TMUX"
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}

# fallback (no .session field) + phase=implementing is already covered by
# "incomplete loop (phase=implementing)" above — same code path, exit 2.

# --- Boundary + error cases ---

@test "empty status dir: allows stop (exit 0)" {
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}

@test "unknown phase value: allows stop (exit 0)" {
  printf '{"worktree":"%s","phase":"some_bogus_phase"}' "$WS" > "$WS/.orchestration/status/t1.json"
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}

@test "malformed status JSON: allows stop (exit 0), no crash" {
  printf 'not valid json {{{' > "$WS/.orchestration/status/t1.json"
  run _run_gate "$WS" false
  [ "$status" -eq 0 ]
}
