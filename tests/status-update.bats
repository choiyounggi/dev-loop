#!/usr/bin/env bats
# Tests for status-update.sh — single atomic record write.

setup() {
  SU="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/status-update.sh"
  export STATUS_DIR="${BATS_TEST_TMPDIR}/status"
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

@test "rework increments .attempt atomically across two calls (normal)" {
  ( cd "$BATS_TEST_TMPDIR" && bash "$SU" t10 implementing )
  ( cd "$BATS_TEST_TMPDIR" && bash "$SU" t10 rework )
  f="$STATUS_DIR/t10.json"
  [ "$(jq '.attempt' "$f")" = "1" ]
  [ "$(jq -r '.phase' "$f")" = "rework" ]
  ( cd "$BATS_TEST_TMPDIR" && bash "$SU" t10 rework )
  [ "$(jq '.attempt' "$f")" = "2" ]
  [ "$(jq -r '.phase' "$f")" = "rework" ]
}

@test "a non-rework phase after rework preserves .attempt (normal)" {
  ( cd "$BATS_TEST_TMPDIR" && bash "$SU" t11 implementing )
  ( cd "$BATS_TEST_TMPDIR" && bash "$SU" t11 rework )
  f="$STATUS_DIR/t11.json"
  [ "$(jq '.attempt' "$f")" = "1" ]
  ( cd "$BATS_TEST_TMPDIR" && bash "$SU" t11 implementing )
  [ "$(jq '.attempt' "$f")" = "1" ]
  [ "$(jq -r '.phase' "$f")" = "implementing" ]
}

@test "rework with no existing status file is refused, file not created (error)" {
  f="$STATUS_DIR/t12.json"
  run bash -c "cd '$BATS_TEST_TMPDIR' && STATUS_DIR='$STATUS_DIR' bash '$SU' t12 rework"
  [ "$status" -eq 4 ]
  [ ! -e "$f" ]
}

@test "rework on malformed status JSON exits 4, file left byte-identical (error)" {
  f="$STATUS_DIR/t13.json"
  mkdir -p "$STATUS_DIR"
  printf 'not-json' > "$f"
  run bash -c "cd '$BATS_TEST_TMPDIR' && STATUS_DIR='$STATUS_DIR' bash '$SU' t13 rework"
  [ "$status" -eq 4 ]
  [ "$(cat "$f")" = "not-json" ]
}

@test "first-ever write (pending) initializes .attempt to 0 (boundary)" {
  ( cd "$BATS_TEST_TMPDIR" && bash "$SU" t14 pending )
  [ "$(jq '.attempt' "$STATUS_DIR/t14.json")" = "0" ]
}
