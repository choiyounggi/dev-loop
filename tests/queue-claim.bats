#!/usr/bin/env bats
# Tests for hooks/queue-claim.js — claim/release insight-queue rows by run id
# (issue #77). Makes the queue self-defend against a lock that has already
# been bypassed or reclaimed from a dead holder.
#
# Every test points DEV_LOOP_QUEUE_DIR at a path under BATS_TEST_TMPDIR so no
# test ever touches the real ~/.dev-loop/queue.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../hooks/queue-claim.js"
  command -v node >/dev/null || {
    echo "node is required to run the queue-claim tests"
    return 1
  }
  export DEV_LOOP_QUEUE_DIR="${BATS_TEST_TMPDIR}/queue"
  mkdir -p "$DEV_LOOP_QUEUE_DIR"
}

_pending_row() { # hash
  printf '{"hash":"%s","status":"pending","trigger":"t","directive":"d"}' "$1"
}

_claimed_row() { # hash claimedBy claimedAtIso
  printf '{"hash":"%s","status":"claimed","claimedBy":"%s","claimedAt":"%s"}' "$1" "$2" "$3"
}

# An ISO8601 timestamp $1 seconds in the past — via node, not `date -d`
# (GNU-only) or `date -v` (BSD-only), so this works on macOS and Linux alike.
_iso_seconds_ago() {
  node -e "console.log(new Date(Date.now() - $1 * 1000).toISOString())"
}

@test "claim over a 3-row pending file: all 3 become claimed with this run id" {
  { _pending_row a; echo; _pending_row b; echo; _pending_row c; } > "$DEV_LOOP_QUEUE_DIR/s1.jsonl"
  run env DEV_LOOP_FLUSH_RUN_ID=run-a node "$SCRIPT" claim
  [ "$status" -eq 0 ]
  [[ "$output" == $'a\nb\nc' ]]

  run node -e "
    const rows = require('fs').readFileSync('$DEV_LOOP_QUEUE_DIR/s1.jsonl','utf8')
      .split('\n').filter(Boolean).map(JSON.parse);
    if (rows.length !== 3) throw new Error('expected 3 rows, got ' + rows.length);
    for (const r of rows) {
      if (r.status !== 'claimed') throw new Error(r.hash + ' not claimed');
      if (r.claimedBy !== 'run-a') throw new Error(r.hash + ' wrong claimedBy');
      if (!r.claimedAt) throw new Error(r.hash + ' missing claimedAt');
    }
  "
  [ "$status" -eq 0 ]
}

@test "a second run's list on an already-claimed file: prints nothing" {
  { _pending_row a; echo; _pending_row b; } > "$DEV_LOOP_QUEUE_DIR/s1.jsonl"
  env DEV_LOOP_FLUSH_RUN_ID=run-a node "$SCRIPT" claim >/dev/null

  run env DEV_LOOP_FLUSH_RUN_ID=run-b node "$SCRIPT" list
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "--max 2 on 3 pending rows: exactly 2 claimed, 1 still pending" {
  { _pending_row a; echo; _pending_row b; echo; _pending_row c; } > "$DEV_LOOP_QUEUE_DIR/s1.jsonl"
  run env DEV_LOOP_FLUSH_RUN_ID=run-a node "$SCRIPT" claim --max 2
  [ "$status" -eq 0 ]
  [[ "$output" == $'a\nb' ]]

  run env DEV_LOOP_FLUSH_RUN_ID=run-b node "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == "c" ]]
}

@test "a claimed row past the claim TTL reappears in list" {
  past="$(_iso_seconds_ago 4000)"
  _claimed_row a run-old "$past" > "$DEV_LOOP_QUEUE_DIR/s1.jsonl"
  run node "$SCRIPT" list
  [ "$status" -eq 0 ]
  [[ "$output" == "a" ]]
}

@test "a claimed row within the claim TTL does not reappear in list" {
  recent="$(_iso_seconds_ago 5)"
  _claimed_row a run-recent "$recent" > "$DEV_LOOP_QUEUE_DIR/s1.jsonl"
  run node "$SCRIPT" list
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "empty queue dir (no files at all): list prints nothing, exit 0" {
  run node "$SCRIPT" list
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "queue dir does not exist: list/claim/release do not crash, exit 0" {
  rm -rf "$DEV_LOOP_QUEUE_DIR"
  run node "$SCRIPT" list
  [ "$status" -eq 0 ]

  run node "$SCRIPT" claim
  [ "$status" -eq 0 ]

  run node "$SCRIPT" release whatever
  [ "$status" -eq 0 ]
}

@test "a queue file with zero rows: list prints nothing, exit 0, no crash" {
  : > "$DEV_LOOP_QUEUE_DIR/s1.jsonl"
  run node "$SCRIPT" list
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "one malformed line plus one valid pending row: malformed survives verbatim, valid row claimed" {
  printf '{not valid json\n' > "$DEV_LOOP_QUEUE_DIR/s1.jsonl"
  _pending_row b >> "$DEV_LOOP_QUEUE_DIR/s1.jsonl"
  echo >> "$DEV_LOOP_QUEUE_DIR/s1.jsonl"

  run env DEV_LOOP_FLUSH_RUN_ID=run-a node "$SCRIPT" claim
  [ "$status" -eq 0 ]
  [[ "$output" == "b" ]]

  run grep -Fx '{not valid json' "$DEV_LOOP_QUEUE_DIR/s1.jsonl"
  [ "$status" -eq 0 ]
}

@test ".processed.jsonl present with pending-looking rows: never claimed" {
  _pending_row z > "$DEV_LOOP_QUEUE_DIR/.processed.jsonl"
  run node "$SCRIPT" list
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  run node "$SCRIPT" claim
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  run node -e "
    const r = JSON.parse(require('fs').readFileSync('$DEV_LOOP_QUEUE_DIR/.processed.jsonl','utf8'));
    if (r.status !== 'pending') throw new Error('processed row was mutated: ' + r.status);
  "
  [ "$status" -eq 0 ]
}

@test "release: sets a claimed row back to pending and clears claimedBy/claimedAt" {
  { _pending_row a; echo; _pending_row b; } > "$DEV_LOOP_QUEUE_DIR/s1.jsonl"
  env DEV_LOOP_FLUSH_RUN_ID=run-a node "$SCRIPT" claim >/dev/null

  run node "$SCRIPT" release a
  [ "$status" -eq 0 ]

  run node -e "
    const rows = require('fs').readFileSync('$DEV_LOOP_QUEUE_DIR/s1.jsonl','utf8')
      .split('\n').filter(Boolean).map(JSON.parse);
    const a = rows.find(r => r.hash === 'a');
    const b = rows.find(r => r.hash === 'b');
    if (a.status !== 'pending') throw new Error('a not pending: ' + a.status);
    if ('claimedBy' in a || 'claimedAt' in a) throw new Error('a still carries claim fields');
    if (b.status !== 'claimed') throw new Error('release touched an id it was not given');
  "
  [ "$status" -eq 0 ]
}

@test "release: unknown id is a no-op, exit 0, no crash" {
  _pending_row a > "$DEV_LOOP_QUEUE_DIR/s1.jsonl"
  run node "$SCRIPT" release does-not-exist
  [ "$status" -eq 0 ]

  run node -e "
    const r = JSON.parse(require('fs').readFileSync('$DEV_LOOP_QUEUE_DIR/s1.jsonl','utf8'));
    if (r.status !== 'pending') throw new Error('untouched row was mutated');
  "
  [ "$status" -eq 0 ]
}

@test "release with no ids given: no-op, exit 0" {
  _pending_row a > "$DEV_LOOP_QUEUE_DIR/s1.jsonl"
  run node "$SCRIPT" release
  [ "$status" -eq 0 ]
}
