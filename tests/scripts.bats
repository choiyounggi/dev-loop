#!/usr/bin/env bats
# Tests for status-update.sh and watch-status.sh

setup() {
  SU="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/status-update.sh"
  WS="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/watch-status.sh"
  export STATUS_DIR="${BATS_TEST_TMPDIR}/status"
}

@test "status-update: writes valid JSON with task/phase/extra" {
  run bash "$SU" task-1 plan_ready worktree=/some/wt
  [ "$status" -eq 0 ]
  [ "$(jq -r '.task'     "$STATUS_DIR/task-1.json")" = "task-1" ]
  [ "$(jq -r '.phase'    "$STATUS_DIR/task-1.json")" = "plan_ready" ]
  [ "$(jq -r '.worktree' "$STATUS_DIR/task-1.json")" = "/some/wt" ]
}

@test "status-update: missing phase arg errors" {
  run bash "$SU" task-1
  [ "$status" -ne 0 ]
}

@test "watch-status: exit 0 when all sessions reach target" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"a","phase":"done"}' > "$STATUS_DIR/a.json"
  printf '{"task":"b","phase":"done"}' > "$STATUS_DIR/b.json"
  run bash "$WS" "$STATUS_DIR" impl_done 2 5 1
  [ "$status" -eq 0 ]
}

@test "watch-status: exit 3 on a failed session" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"a","phase":"failed"}' > "$STATUS_DIR/a.json"
  run bash "$WS" "$STATUS_DIR" impl_done 1 5 1
  [ "$status" -eq 3 ]
}

@test "watch-status: exit 4 on unknown target phase (no false 'all done')" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"a","phase":"done"}' > "$STATUS_DIR/a.json"
  run bash "$WS" "$STATUS_DIR" bogusphase 1 2 1
  [ "$status" -eq 4 ]
}

@test "watch-status: exit 4 when status dir is missing" {
  run bash "$WS" "${BATS_TEST_TMPDIR}/does-not-exist" done 1 2 1
  [ "$status" -eq 4 ]
}

@test "status-update: ignores malformed extra and records worktree" {
  run bash "$SU" task-x implementing notakeyvalue good=1
  [ "$status" -eq 0 ]
  [ "$(jq -r '.good' "$STATUS_DIR/task-x.json")" = "1" ]
  [ "$(jq -r 'has("notakeyvalue")' "$STATUS_DIR/task-x.json")" = "false" ]
  [ "$(jq -r '.worktree | type' "$STATUS_DIR/task-x.json")" = "string" ]
}

@test "watch-status --tasks: only the named tasks are counted" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"old","phase":"approved"}' > "$STATUS_DIR/old.json"
  printf '{"task":"a","phase":"implementing"}' > "$STATUS_DIR/a.json"
  # `old` already passed the target, but it is not being tracked: without
  # scoping, expected=1 would be satisfied instantly and the wait would spin.
  run bash "$WS" --tasks a "$STATUS_DIR" impl_done 1 2 1
  [ "$status" -eq 2 ]
}

@test "watch-status --tasks: returns as soon as ANY tracked task reaches target" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"a","phase":"impl_done"}'    > "$STATUS_DIR/a.json"
  printf '{"task":"b","phase":"implementing"}' > "$STATUS_DIR/b.json"
  run bash "$WS" --tasks a,b "$STATUS_DIR" impl_done 1 5 1
  [ "$status" -eq 0 ]
}

@test "watch-status --tasks: an untracked failed task does not abort the wait" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"old","phase":"failed"}'     > "$STATUS_DIR/old.json"
  printf '{"task":"a","phase":"implementing"}' > "$STATUS_DIR/a.json"
  run bash "$WS" --tasks a "$STATUS_DIR" impl_done 1 2 1
  [ "$status" -eq 2 ]
}

@test "watch-status --tasks: an explicit timeout argument still outranks the env" {
  # --tasks is consumed before the positional count is taken; if argc were
  # captured before that, the 4th positional would stop being recognised and
  # LO_PHASE_TIMEOUTS would silently win.
  mkdir -p "$STATUS_DIR"
  printf '{"task":"a","phase":"implementing"}' > "$STATUS_DIR/a.json"
  run env LO_PHASE_TIMEOUTS="impl_done=999" bash "$WS" --tasks a "$STATUS_DIR" impl_done 1 2 1
  [[ "$output" == *"budget=2s"* ]]
  [[ "$output" == *"source=arg"* ]]
}

@test "watch-status: without --tasks every status file is still counted (no regression)" {
  mkdir -p "$STATUS_DIR"
  printf '{"task":"a","phase":"done"}' > "$STATUS_DIR/a.json"
  printf '{"task":"b","phase":"done"}' > "$STATUS_DIR/b.json"
  run bash "$WS" "$STATUS_DIR" impl_done 2 5 1
  [ "$status" -eq 0 ]
}

@test "SKILL.md Phase 2: graph.json artifact and the slot proposal are documented" {
  SKILL="${BATS_TEST_DIRNAME}/../skills/orchestrate/SKILL.md"
  grep -qF '.orchestration/graph.json' "$SKILL"
  grep -qF 'LO_MAX_SESSIONS' "$SKILL"
  # The cap must never be a bare number again: the report has to name what it
  # protects, or "dynamic" degrades back into a hardcoded 4.
  grep -qF 'coordinator attention' "$SKILL"
  ! grep -qF 'concurrent-session cap** (default 4)' "$SKILL"
}

@test "SKILL.md: the dispatch loop cites ready-set exit codes and --tasks" {
  SKILL="${BATS_TEST_DIRNAME}/../skills/orchestrate/SKILL.md"
  grep -qF 'scripts/ready-set.sh' "$SKILL"
  grep -q -- '--tasks' "$SKILL"
  # exit 3 is the guard this design turns on; it must be spelled out as
  # "do not wait", or it degrades into the silent stall it exists to prevent.
  grep -qF 'DEADLOCK' "$SKILL"
  # Waves must no longer be described as an execution barrier.
  ! grep -qF 'A later Wave launches only after' "$SKILL"
}
