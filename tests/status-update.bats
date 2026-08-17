#!/usr/bin/env bats
# Tests for status-update.sh — single atomic record write.

setup() {
  SU="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/status-update.sh"
  export STATUS_DIR="${BATS_TEST_TMPDIR}/status"
  # Session resolution reads $TMUX/$STATUS_SESSION from the ambient environment
  # (issue #97: a suite launched from inside a real tmux session would
  # otherwise silently inherit it and mask the non-tmux regression below).
  unset TMUX STATUS_SESSION
}

mk_tmux_stub() { # $1 = session name the stub's `display-message -p '#S'` answers with
  d="${BATS_TEST_TMPDIR}/tmuxbin"
  mkdir -p "$d"
  printf '#!/bin/sh\necho "%s"\n' "$1" > "$d/tmux"
  chmod +x "$d/tmux"
  printf '%s' "$d"
}

@test "writes phase, timestamp, worktree and extras in one valid-JSON record" {
  ( cd "$BATS_TEST_TMPDIR" && bash "$SU" t1 plan_ready prUrl=http://x/pr reworkCount=2 )
  f="$STATUS_DIR/t1.json"
  jq -e . "$f" >/dev/null
  [ "$(jq -r '.task' "$f")" = "t1" ]
  [ "$(jq -r '.phase' "$f")" = "plan_ready" ]
  [ "$(jq -r '.updatedAt' "$f")" != "null" ]
  [ "$(jq -r '.worktree' "$f")" != "null" ]
  [ "$(jq -r '.prUrl' "$f")" = "http://x/pr" ]
  [ "$(jq -r '.reworkCount' "$f")" = "2" ]
}

@test "malformed extra is ignored with a warning; good extra still applied" {
  run bash -c "cd '$BATS_TEST_TMPDIR' && STATUS_DIR='$STATUS_DIR' bash '$SU' t2 planning noequals worktree=/wt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"malformed"* ]]
  [ "$(jq -r '.phase' "$STATUS_DIR/t2.json")" = "planning" ]
  [ "$(jq -r '.worktree' "$STATUS_DIR/t2.json")" = "/wt" ]
}

@test "no extras: still writes a valid record (boundary)" {
  ( cd "$BATS_TEST_TMPDIR" && bash "$SU" t3 pending )
  jq -e . "$STATUS_DIR/t3.json" >/dev/null
  [ "$(jq -r '.phase' "$STATUS_DIR/t3.json")" = "pending" ]
}

@test "records the tmux session name (STATUS_SESSION override) for liveness" {
  ( cd "$BATS_TEST_TMPDIR" && STATUS_SESSION=lo-7 bash "$SU" t4 implementing )
  [ "$(jq -r '.session' "$STATUS_DIR/t4.json")" = "lo-7" ]
}

@test "TMUX set, no STATUS_SESSION: asks tmux and records its answer (normal)" {
  stub="$(mk_tmux_stub inside-session)"
  run env TMUX=fake PATH="$stub:$PATH" bash "$SU" t5 implementing
  [ "$status" -eq 0 ]
  [ "$(jq -r '.session' "$STATUS_DIR/t5.json")" = "inside-session" ]
}

@test "TMUX unset: tmux is never consulted, session field stays absent (regression, issue #97)" {
  stub="$(mk_tmux_stub wrongly-resolved-session)"
  run env PATH="$stub:$PATH" bash "$SU" t6 implementing
  [ "$status" -eq 0 ]
  [ "$(jq -r '.session // "MISSING"' "$STATUS_DIR/t6.json")" = "MISSING" ]
}

@test "STATUS_SESSION wins outside tmux even with tmux on PATH (boundary)" {
  stub="$(mk_tmux_stub wrongly-resolved-session)"
  run env STATUS_SESSION=explicit PATH="$stub:$PATH" bash "$SU" t7 implementing
  [ "$status" -eq 0 ]
  [ "$(jq -r '.session' "$STATUS_DIR/t7.json")" = "explicit" ]
}
