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
