#!/usr/bin/env bats
# Tests for collect-status.sh — coordinator-side collector that copies
# worker-local .orchestration/status (and questions) records into the
# canonical dir, filtered by graph.json, atomically, without regressing
# coordinator-set state.

bats_require_minimum_version 1.5.0

setup() {
  CS="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/collect-status.sh"
  G="${BATS_TEST_TMPDIR}/graph.json"
  CDIR="${BATS_TEST_TMPDIR}/canonical/status"
  WROOT="${BATS_TEST_TMPDIR}/worktrees"
  mkdir -p "$CDIR" "$WROOT"
}

graph() { printf '%s' "$1" > "$G"; }

# worker_status <worktree-name> <task> <phase> <updatedAt> [extra-jq-filter]
worker_status() {
  d="$WROOT/$1/.orchestration/status"
  mkdir -p "$d"
  extra="${5:-.}"
  jq -n --arg task "$2" --arg phase "$3" --arg t "$4" \
    '{task:$task, phase:$phase, updatedAt:$t}' | jq "$extra" > "$d/$2.json"
}

# canonical_status <task> <phase> <updatedAt> [extra-jq-filter]
canonical_status() {
  extra="${4:-.}"
  jq -n --arg task "$1" --arg phase "$2" --arg t "$3" \
    '{task:$task, phase:$phase, updatedAt:$t}' | jq "$extra" > "$CDIR/$1.json"
}

worker_question() {
  d="$WROOT/$1/.orchestration/questions"
  mkdir -p "$d"
  jq -n --arg t "$2" --arg q "$3" '{taskId:$t, question:$q, options:[]}' > "$d/$2.json"
}

# worker_blocked <worktree-name> <task> <ts> [reason]
worker_blocked() {
  d="$WROOT/$1/.orchestration/blocked"
  mkdir -p "$d"
  reason="${4:-idle_prompt}"
  jq -n --arg ts "$3" --arg task "$2" --arg reason "$reason" --arg wt "$WROOT/$1" \
    '{ts:$ts, taskId:$task, session:"lo-1", event:"Notification", reason:$reason, detail:"x", worktree:$wt}' \
    > "$d/$2.json"
}

# canonical_blocked <task> <ts> <worktree>
canonical_blocked() {
  bdir="$(dirname "$CDIR")/blocked"
  mkdir -p "$bdir"
  jq -n --arg ts "$2" --arg task "$1" --arg wt "$3" \
    '{ts:$ts, taskId:$task, session:"lo-1", event:"Notification", reason:"idle_prompt", detail:"canonical-marker", worktree:$wt}' \
    > "$bdir/$1.json"
}

@test "normal: worker record newer than canonical is collected, content matches" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  canonical_status t1 implementing 2026-01-01T00:00:00Z
  worker_status wt1 t1 impl_done 2026-01-01T00:05:00Z
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  [ "$output" = "collected=1 skipped=0 foreign=0" ]
  [ "$(jq -r '.phase' "$CDIR/t1.json")" = "impl_done" ]
  [ "$(jq -r '.updatedAt' "$CDIR/t1.json")" = "2026-01-01T00:05:00Z" ]
}

@test "no canonical yet: worker record is collected" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  worker_status wt1 t1 planning 2026-01-01T00:00:00Z
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  [ "$output" = "collected=1 skipped=0 foreign=0" ]
  [ "$(jq -r '.phase' "$CDIR/t1.json")" = "planning" ]
}

@test "foreign task id in a sibling worktree is not copied" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  worker_status wt1 t1 planning 2026-01-01T00:00:00Z
  worker_status other-run other-task planning 2026-01-01T00:00:00Z
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  [ "$output" = "collected=1 skipped=0 foreign=1" ]
  [ ! -e "$CDIR/other-task.json" ]
}

@test "r1 F1: a regex-metacharacter id does not fuzzy-match a near-miss basename (foreign, not collected)" {
  # is_task() must compare LITERALLY (-F), not as a BRE: graph id "t1-status"
  # and foreign basename "t1.status" differ only by a metachar ('.' matches
  # any char in a BRE), so a pattern-mode grep would wrongly collect it.
  graph '{"tasks":[{"id":"t1-status","deps":[]}]}'
  worker_status wt1 t1-status planning 2026-01-01T00:00:00Z
  worker_status other-run t1.status planning 2026-01-01T00:00:00Z
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  [ "$output" = "collected=1 skipped=0 foreign=1" ]
  [ ! -e "$CDIR/t1.status.json" ]
}

@test "tombstone: canonical phase=done is never overwritten by a newer worker record" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  canonical_status t1 done 2026-01-01T00:00:00Z
  worker_status wt1 t1 implementing 2026-01-01T00:05:00Z
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  [ "$output" = "collected=0 skipped=1 foreign=0" ]
  [ "$(jq -r '.phase' "$CDIR/t1.json")" = "done" ]
}

@test "tombstone: canonical phase=failed is never overwritten" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  canonical_status t1 failed 2026-01-01T00:00:00Z
  worker_status wt1 t1 implementing 2026-01-01T00:05:00Z
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.phase' "$CDIR/t1.json")" = "failed" ]
}

@test "stale: worker updatedAt not strictly newer is not collected, canonical rework survives" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  canonical_status t1 rework 2026-01-01T00:10:00Z '.attempt = 2'
  worker_status wt1 t1 implementing 2026-01-01T00:05:00Z
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  [ "$output" = "collected=0 skipped=1 foreign=0" ]
  [ "$(jq -r '.phase' "$CDIR/t1.json")" = "rework" ]
  [ "$(jq -r '.attempt' "$CDIR/t1.json")" = "2" ]
}

@test "stale: equal updatedAt is not collected (boundary, strictly-greater)" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  canonical_status t1 implementing 2026-01-01T00:05:00Z
  worker_status wt1 t1 impl_done 2026-01-01T00:05:00Z
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  [ "$output" = "collected=0 skipped=1 foreign=0" ]
  [ "$(jq -r '.phase' "$CDIR/t1.json")" = "implementing" ]
}

@test "attempt preserved: canonical .attempt=2 survives onto a collected record without it" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  canonical_status t1 implementing 2026-01-01T00:00:00Z '.attempt = 2'
  worker_status wt1 t1 impl_done 2026-01-01T00:05:00Z
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  [ "$output" = "collected=1 skipped=0 foreign=0" ]
  [ "$(jq -r '.phase' "$CDIR/t1.json")" = "impl_done" ]
  [ "$(jq -r '.attempt' "$CDIR/t1.json")" = "2" ]
}

@test "question copy-if-absent: absent canonical question is copied" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  worker_question wt1 t1 "pick an option"
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  qfile="$(dirname "$CDIR")/questions/t1.json"
  [ -f "$qfile" ]
  [ "$(jq -r '.question' "$qfile")" = "pick an option" ]
}

@test "question copy-if-absent: existing canonical question is left untouched" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  qdir="$(dirname "$CDIR")/questions"
  mkdir -p "$qdir"
  jq -n '{taskId:"t1", question:"already answered", options:[]}' > "$qdir/t1.json"
  worker_question wt1 t1 "a new different question"
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.question' "$qdir/t1.json")" = "already answered" ]
}

@test "usage: missing args exits 2" {
  run sh "$CS" "$G" "$CDIR"
  [ "$status" -eq 2 ]
}

@test "error: malformed graph exits 4" {
  graph '}{ not json'
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 4 ]
}

@test "error: graph missing .tasks array exits 4" {
  graph '{"nodes":[]}'
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 4 ]
}

@test "malformed worker JSON is skipped, exit still 0" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  d="$WROOT/wt1/.orchestration/status"
  mkdir -p "$d"
  printf 'not-json' > "$d/t1.json"
  run --separate-stderr sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  [ "$output" = "collected=0 skipped=1 foreign=0" ]
  [[ "$stderr" == *"malformed worker record"* ]]
  [ ! -e "$CDIR/t1.json" ]
}

@test "no worktree records at all: collected=0, exit 0 (boundary)" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  [ "$output" = "collected=0 skipped=0 foreign=0" ]
}

# ---- blocked records (R1-R3) ----

@test "R1 normal: blocked record absent from canonical is copied, content matches" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  worker_blocked wt1 t1 2026-01-01T00:05:00Z
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  bdir="$(dirname "$CDIR")/blocked"
  [ -f "$bdir/t1.json" ]
  [ "$(jq -S . "$bdir/t1.json")" = "$(jq -S . "$WROOT/wt1/.orchestration/blocked/t1.json")" ]
}

@test "R1 normal: worker blocked record newer than canonical replaces it" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  canonical_blocked t1 2026-01-01T00:00:00Z "$WROOT/wt1"
  worker_blocked wt1 t1 2026-01-01T00:05:00Z permission_prompt
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  bdir="$(dirname "$CDIR")/blocked"
  [ "$(jq -r '.reason' "$bdir/t1.json")" = "permission_prompt" ]
  [ "$(jq -r '.ts' "$bdir/t1.json")" = "2026-01-01T00:05:00Z" ]
}

@test "R1 boundary: equal ts blocked record is not replaced" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  canonical_blocked t1 2026-01-01T00:05:00Z "$WROOT/wt1"
  worker_blocked wt1 t1 2026-01-01T00:05:00Z permission_prompt
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  bdir="$(dirname "$CDIR")/blocked"
  [ "$(jq -r '.detail' "$bdir/t1.json")" = "canonical-marker" ]
}

@test "R2 normal: canonical blocked record is removed when the worker-side file is gone" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  mkdir -p "$WROOT/wt1/.orchestration"
  canonical_blocked t1 2026-01-01T00:00:00Z "$WROOT/wt1"
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  bdir="$(dirname "$CDIR")/blocked"
  [ ! -e "$bdir/t1.json" ]
}

@test "R2 boundary: canonical blocked record is removed when its worktree dir is missing" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  canonical_blocked t1 2026-01-01T00:00:00Z "$WROOT/nonexistent-wt"
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  bdir="$(dirname "$CDIR")/blocked"
  [ ! -e "$bdir/t1.json" ]
}

@test "R2 boundary: canonical blocked record with empty worktree field is removed" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  canonical_blocked t1 2026-01-01T00:00:00Z ""
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  bdir="$(dirname "$CDIR")/blocked"
  [ ! -e "$bdir/t1.json" ]
}

@test "R2 boundary: a canonical record whose worktree is a physical path survives a symlinked worktrees root" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  mkdir -p "$WROOT/wt1/.orchestration/blocked"
  jq -n --arg ts "2026-01-01T00:05:00Z" \
    '{ts:$ts, taskId:"t1", session:"lo-1", event:"Notification", reason:"idle_prompt", detail:"x", worktree:"placeholder"}' \
    > "$WROOT/wt1/.orchestration/blocked/t1.json"
  phys="$(cd "$WROOT/wt1" && pwd -P)"
  canonical_blocked t1 2026-01-01T00:05:00Z "$phys"
  link="$BATS_TEST_TMPDIR/link"
  ln -s "$WROOT" "$link"
  run sh "$CS" "$G" "$CDIR" "$link"
  [ "$status" -eq 0 ]
  bdir="$(dirname "$CDIR")/blocked"
  [ -f "$bdir/t1.json" ]
}

@test "R3 error: malformed worker blocked record is not copied, exit still 0" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  d="$WROOT/wt1/.orchestration/blocked"
  mkdir -p "$d"
  printf 'not-json' > "$d/t1.json"
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  bdir="$(dirname "$CDIR")/blocked"
  [ ! -e "$bdir/t1.json" ]
}

@test "R3 boundary: blocked record for a foreign task id is not copied" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  worker_blocked other-run zz 2026-01-01T00:05:00Z
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  bdir="$(dirname "$CDIR")/blocked"
  [ ! -e "$bdir/zz.json" ]
}

@test "R3 normal: stdout summary line is unchanged by blocked-record collection" {
  graph '{"tasks":[{"id":"t1","deps":[]}]}'
  worker_status wt1 t1 planning 2026-01-01T00:00:00Z
  worker_blocked wt1 t1 2026-01-01T00:05:00Z
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  [ "$output" = "collected=1 skipped=0 foreign=0" ]
}

@test "F4 error: a non-object (array) canonical blocked record is skipped, not fatal — still exits 0 and still prunes" {
  # Corrupted-by-hand or an out-of-band writer, not the hook itself: a
  # canonical blocked/t1.json that is valid JSON but not an object used to
  # abort the whole script under set -eu the moment its .ts field was read
  # (jq errors indexing an array with a string key, and `//` does not rescue
  # that). t2's stale canonical record (worktree gone) proves the prune pass
  # still runs afterward — the abort never happens.
  graph '{"tasks":[{"id":"t1","deps":[]},{"id":"t2","deps":[]}]}'
  bdir="$(dirname "$CDIR")/blocked"
  mkdir -p "$bdir"
  printf '[]' > "$bdir/t1.json"
  worker_blocked wt1 t1 2026-01-01T00:05:00Z permission_prompt
  canonical_blocked t2 2026-01-01T00:00:00Z "$WROOT/nonexistent-wt"
  run sh "$CS" "$G" "$CDIR" "$WROOT"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.reason' "$bdir/t1.json")" = "permission_prompt" ]
  [ ! -e "$bdir/t2.json" ]
}
