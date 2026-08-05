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

@test "liveness: unresolvable tmux disables liveness (no false dead-worker abort)" {
  printf '{"task":"t1","phase":"implementing","session":"lo-x"}' > "$ORCH/status/t1.json"
  # tmux binary can't be resolved → skip liveness, do not flag everything dead
  run env WATCH_TMUX=/nonexistent/tmux bash "$WS" "$ORCH/status" implementing 1 3 1
  [ "$status" -eq 0 ]
}

# ---- per-phase deadlines (LO_PHASE_TIMEOUTS) --------------------------------
# One flat timeout gave a plan phase and a long implement phase the same budget.
# The budget is now keyed on the TARGET phase of this wait, and every run states
# which budget it is using and where that budget came from.
#
# These invoke the script with `sh`, not `bash`: it is `#!/bin/sh`, and `bash`
# would override the shebang and let a bashism pass here but fail under dash.
# (The eight tests above predate this and are left exactly as they were — note
# they all pass the 4th positional argument, which still wins.)

@test "per-phase: the target phase's entry supplies the budget" {
  printf '{"task":"t1","phase":"plan_ready"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="plan_ready=900,impl_done=3600" \
      sh "$WS" "$ORCH/status" plan_ready 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"budget=900s target=plan_ready source=LO_PHASE_TIMEOUTS"* ]]
}

@test "per-phase: the SAME env string yields a different budget for a different target" {
  printf '{"task":"t1","phase":"impl_done"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="plan_ready=900,impl_done=3600" \
      sh "$WS" "$ORCH/status" impl_done 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"budget=3600s target=impl_done source=LO_PHASE_TIMEOUTS"* ]]
}

@test "per-phase: with no env at all the default budget is used and named" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run sh "$WS" "$ORCH/status" done 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"budget=3600s target=done source=default"* ]]
}

@test "per-phase: an explicitly passed timeout argument wins over the env" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="done=900" sh "$WS" "$ORCH/status" done 1 42 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"budget=42s target=done source=arg"* ]]
}

@test "per-phase: a target absent from the env falls back to the default (boundary)" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="plan_ready=900" sh "$WS" "$ORCH/status" done 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"budget=3600s target=done source=default"* ]]
}

@test "per-phase: an empty env value is treated as unset, not as an error (boundary)" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="" sh "$WS" "$ORCH/status" done 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"source=default"* ]]
}

@test "per-phase: a trailing comma is tolerated (boundary)" {
  printf '{"task":"t1","phase":"plan_ready"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="plan_ready=900," sh "$WS" "$ORCH/status" plan_ready 1
  [ "$status" -eq 0 ]
  [[ "$output" == *"budget=900s"* ]]
}

@test "per-phase: the env budget actually bounds the wait, and the TIMEOUT line names it" {
  printf '{"task":"t1","phase":"pending"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="done=1" sh "$WS" "$ORCH/status" done 1
  [ "$status" -eq 2 ]
  [[ "$output" == *"TIMEOUT (1s, source=LO_PHASE_TIMEOUTS)"* ]]
}

@test "per-phase: a non-numeric budget is refused, never silently defaulted (error)" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="plan_ready=abc" sh "$WS" "$ORCH/status" done 1
  [ "$status" -eq 4 ]
  [[ "$output" == *"plan_ready=abc"* ]]
}

@test "per-phase: a typo'd phase name is refused, not silently ignored (error)" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="notaphase=900" sh "$WS" "$ORCH/status" done 1
  [ "$status" -eq 4 ]
  [[ "$output" == *"notaphase"* ]]
}

@test "per-phase: a zero budget is refused — it would time out instantly (boundary)" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="done=0" sh "$WS" "$ORCH/status" done 1
  [ "$status" -eq 4 ]
}

@test "per-phase: an entry with no '=' is refused (error)" {
  printf '{"task":"t1","phase":"done"}' > "$ORCH/status/t1.json"
  run env LO_PHASE_TIMEOUTS="plan_ready" sh "$WS" "$ORCH/status" done 1
  [ "$status" -eq 4 ]
}
