#!/usr/bin/env bats
# Tests for scripts/flush-lock.sh — the owner-token mkdir-atomicity lock shared
# by hooks/auto-flush.sh and skills/knowledge-flush/SKILL.md (issue #77).
#
# Every test points DEV_LOOP_FLUSH_LOCK at a path under BATS_TEST_TMPDIR so no
# test ever touches the real ~/.dev-loop.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/flush-lock.sh"
  export DEV_LOOP_FLUSH_LOCK="${BATS_TEST_TMPDIR}/flush.lock"
}

_now() { date +%s; }

# Write a lock dir + owner file directly (bypassing the script) so tests can
# construct held/stale/malformed states precisely.
_seed_lock() { # runid pid epoch
  mkdir -p "$DEV_LOOP_FLUSH_LOCK"
  printf '%s %s %s\n' "$1" "$2" "$3" > "$DEV_LOOP_FLUSH_LOCK/owner"
}

# A pid guaranteed dead: spawn, wait for exit, reap it.
_dead_pid() {
  ( exit 0 ) &
  local pid=$!
  wait "$pid" 2>/dev/null || true
  echo "$pid"
}

@test "acquire on a clean dir: exit 0, lock dir + owner file exist" {
  run env DEV_LOOP_FLUSH_RUN_ID=run-a sh "$SCRIPT" acquire
  [ "$status" -eq 0 ]
  [[ "$output" == "acquired run-a" ]]
  [ -d "$DEV_LOOP_FLUSH_LOCK" ]
  [ -f "$DEV_LOOP_FLUSH_LOCK/owner" ]
  read -r runid pid epoch < "$DEV_LOOP_FLUSH_LOCK/owner"
  [ "$runid" = "run-a" ]
}

@test "second acquire while held (young, holder alive): exit 3, lock untouched" {
  _seed_lock run-holder "$$" "$(_now)"
  run env DEV_LOOP_FLUSH_RUN_ID=run-b sh "$SCRIPT" acquire
  [ "$status" -eq 3 ]
  [[ "$output" == *"held run-holder"* ]]
  read -r runid _ _ < "$DEV_LOOP_FLUSH_LOCK/owner"
  [ "$runid" = "run-holder" ]
}

@test "release with a different DEV_LOOP_FLUSH_RUN_ID: exit 4, lock still exists" {
  _seed_lock run-holder 1 "$(_now)"
  run env DEV_LOOP_FLUSH_RUN_ID=run-someone-else sh "$SCRIPT" release
  [ "$status" -eq 4 ]
  [[ "$output" == *"refused"* ]]
  [ -d "$DEV_LOOP_FLUSH_LOCK" ]
  [ -f "$DEV_LOOP_FLUSH_LOCK/owner" ]
}

@test "own release: match removes the lock, exit 0" {
  _seed_lock run-mine "$$" "$(_now)"
  run env DEV_LOOP_FLUSH_RUN_ID=run-mine sh "$SCRIPT" release
  [ "$status" -eq 0 ]
  [ ! -d "$DEV_LOOP_FLUSH_LOCK" ]
}

@test "stale lock (past TTL) + dead pid: acquire reclaims, exit 0" {
  dead="$(_dead_pid)"
  _seed_lock run-crashed "$dead" "$(( $(_now) - 1000 ))"
  run env DEV_LOOP_FLUSH_RUN_ID=run-new sh "$SCRIPT" acquire
  [ "$status" -eq 0 ]
  [[ "$output" == "reclaimed run-new" ]]
  read -r runid _ _ < "$DEV_LOOP_FLUSH_LOCK/owner"
  [ "$runid" = "run-new" ]
}

@test "young lock + dead pid: still held, not reclaimed (exit 3)" {
  dead="$(_dead_pid)"
  _seed_lock run-crashed "$dead" "$(_now)"
  run env DEV_LOOP_FLUSH_RUN_ID=run-new sh "$SCRIPT" acquire
  [ "$status" -eq 3 ]
  read -r runid _ _ < "$DEV_LOOP_FLUSH_LOCK/owner"
  [ "$runid" = "run-crashed" ]
}

@test "stale (past TTL) but pid alive: still held, not reclaimed (exit 3)" {
  _seed_lock run-holder "$$" "$(( $(_now) - 1000 ))"
  run env DEV_LOOP_FLUSH_RUN_ID=run-new sh "$SCRIPT" acquire
  [ "$status" -eq 3 ]
  read -r runid _ _ < "$DEV_LOOP_FLUSH_LOCK/owner"
  [ "$runid" = "run-holder" ]
}

@test "release with no lock present: exit 0 (empty/absent state)" {
  run env DEV_LOOP_FLUSH_RUN_ID=run-a sh "$SCRIPT" release
  [ "$status" -eq 0 ]
  [ ! -d "$DEV_LOOP_FLUSH_LOCK" ]
}

@test "malformed/empty owner file: acquire reclaims rather than wedging" {
  mkdir -p "$DEV_LOOP_FLUSH_LOCK"
  : > "$DEV_LOOP_FLUSH_LOCK/owner"
  run env DEV_LOOP_FLUSH_RUN_ID=run-new sh "$SCRIPT" acquire
  [ "$status" -eq 0 ]
  [[ "$output" == "reclaimed run-new" ]]
}

@test "holder: prints the owner line and exits 0 when held" {
  _seed_lock run-holder 123 "$(_now)"
  run sh "$SCRIPT" holder
  [ "$status" -eq 0 ]
  [[ "$output" == "run-holder 123"* ]]
}

@test "holder: exits 1 when no lock is held" {
  run sh "$SCRIPT" holder
  [ "$status" -eq 1 ]
}

@test "unknown or missing verb: exit 2" {
  run sh "$SCRIPT" bogus
  [ "$status" -eq 2 ]

  run sh "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "re-entrant acquire: same run id as current holder refreshes epoch, exit 0, already-owned" {
  old_epoch=$(( $(_now) - 500 ))
  _seed_lock run-a "$$" "$old_epoch"
  run env DEV_LOOP_FLUSH_RUN_ID=run-a sh "$SCRIPT" acquire
  [ "$status" -eq 0 ]
  [[ "$output" == "already-owned run-a" ]]
  read -r runid pid epoch < "$DEV_LOOP_FLUSH_LOCK/owner"
  [ "$runid" = "run-a" ]
  [ "$epoch" -gt "$old_epoch" ]
}

@test "re-entrant acquire does not extend to a foreign run id: still exit 3, owner unchanged" {
  _seed_lock run-a "$$" "$(_now)"
  run env DEV_LOOP_FLUSH_RUN_ID=run-b sh "$SCRIPT" acquire
  [ "$status" -eq 3 ]
  read -r runid _ _ < "$DEV_LOOP_FLUSH_LOCK/owner"
  [ "$runid" = "run-a" ]
}
