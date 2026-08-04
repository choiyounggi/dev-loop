#!/usr/bin/env bats
# Tests for watch-status.sh escalation surfacing (exit 5).

setup() {
  WS="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/watch-status.sh"
  ORCH="${BATS_TEST_TMPDIR}/.orchestration"
  mkdir -p "$ORCH/status" "$ORCH/escalations"
}

@test "exits 5 when an escalation is pending (wakes coordinator, no long wait)" {
  printf '{"task":"t1","phase":"implementing"}' > "$ORCH/status/t1.json"
  printf '{"taskId":"t1","rule":"git_force_push"}' > "$ORCH/escalations/e1.json"
  run bash "$WS" "$ORCH/status" impl_done 1 5 1
  [ "$status" -eq 5 ]
  [[ "$output" == *"escalation pending"* ]]
  [[ "$output" == *"t1"* ]]
}

@test "no escalation: normal completion still exits 0" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run bash "$WS" "$ORCH/status" done 1 5 1
  [ "$status" -eq 0 ]
}

@test "empty escalations dir does not false-trigger exit 5" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run bash "$WS" "$ORCH/status" done 1 5 1
  [ "$status" -eq 0 ]
}

# ---- liveness (dead-worker detection) ----

@test "liveness: a non-terminal task with a dead tmux session aborts (exit 3)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  run env WATCH_TMUX=false bash "$WS" "$ORCH/status" impl_done 1 5 1
  [ "$status" -eq 3 ]
  [[ "$output" == *"dead worker"* ]]
}

@test "liveness: a live session is not flagged and reaches the target (exit 0)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  run env WATCH_TMUX=true bash "$WS" "$ORCH/status" implementing 1 5 1
  [ "$status" -eq 0 ]
}

@test "liveness: a terminal phase is not liveness-checked even if session is dead" {
  printf '{"task":"t1","phase":"done","session":"lo-x"}' > "$ORCH/status/t1.json"
  run env WATCH_TMUX=false bash "$WS" "$ORCH/status" done 1 5 1
  [ "$status" -eq 0 ]
}

@test "liveness: no session field → not checked (backward compat)" {
  printf '{"task":"t1","phase":"implementing"}' > "$ORCH/status/t1.json"
  run env WATCH_TMUX=false bash "$WS" "$ORCH/status" implementing 1 5 1
  [ "$status" -eq 0 ]
}
