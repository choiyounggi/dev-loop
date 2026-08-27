#!/usr/bin/env bats
# Tests for graph-drop.sh — the symmetric shrink path to graph-add.sh.
# It removes ONE undispatched node and validates the RESULTING graph. A
# rejected drop must leave the file byte-identical: a half-applied graph
# breaks re-entry.

setup() {
  GD="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/graph-drop.sh"
  G="${BATS_TEST_TMPDIR}/graph.json"
  S="${BATS_TEST_TMPDIR}/status"; mkdir -p "$S"
}

graph() { printf '%s' "$1" > "$G"; }

@test "an undispatched leaf node nobody depends on is dropped" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]},{"id":"t2","deps":[],"outputs":["B"]}]}'
  run sh "$GD" "$G" "$S" "t2"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.tasks | length' "$G")" = "1" ]
  [ "$(jq -r '.tasks[0].id' "$G")" = "t1" ]
  [ "$(jq -r '.tasks[0].outputs[0]' "$G")" = "A" ]
}

@test "a node with a status file is refused as already dispatched (error)" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]},{"id":"t2","deps":[],"outputs":["B"]}]}'
  printf '{"task":"t2","phase":"pending"}' > "$S/t2.json"
  before=$(cat "$G")
  run sh "$GD" "$G" "$S" "t2"
  [ "$status" -eq 3 ]
  [[ "$output" == *"dispatched"* ]]
  [ "$(cat "$G")" = "$before" ]
}

@test "a node another task still depends on is refused (error)" {
  graph '{"tasks":[{"id":"t1","deps":["t2"],"outputs":["A"]},{"id":"t2","deps":[],"outputs":["B"]}]}'
  before=$(cat "$G")
  run sh "$GD" "$G" "$S" "t2"
  [ "$status" -eq 3 ]
  [[ "$output" == *"depend"* ]]
  [ "$(cat "$G")" = "$before" ]
}

@test "a node whose output is still consumed is refused (error)" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":[],"consumes":["B"]},{"id":"t2","deps":[],"outputs":["B"]}]}'
  before=$(cat "$G")
  run sh "$GD" "$G" "$S" "t2"
  [ "$status" -eq 3 ]
  [[ "$output" == *"consume"* ]]
  [ "$(cat "$G")" = "$before" ]
}

@test "a node whose multi-word output is still consumed is refused, not word-split (regression)" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":[],"consumes":["Auth Token"]},{"id":"t2","deps":[],"outputs":["Auth Token"]}]}'
  before=$(cat "$G")
  run sh "$GD" "$G" "$S" "t2"
  [ "$status" -eq 3 ]
  [[ "$output" == *"consume"* ]]
  [ "$(cat "$G")" = "$before" ]
}

@test "a node still named as another task's split_of parent is refused (error)" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]},{"id":"t1b","deps":[],"outputs":["B"],"split_of":"t1"}]}'
  before=$(cat "$G")
  run sh "$GD" "$G" "$S" "t1"
  [ "$status" -eq 3 ]
  [[ "$output" == *"split_of"* ]]
  [ "$(cat "$G")" = "$before" ]
}

@test "an id that names no task is refused (error)" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]}]}'
  before=$(cat "$G")
  run sh "$GD" "$G" "$S" "ghost"
  [ "$status" -eq 3 ]
  [[ "$output" == *"names no task"* ]]
  [ "$(cat "$G")" = "$before" ]
}

@test "dropping the only node leaves a valid empty graph (boundary)" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]}]}'
  run sh "$GD" "$G" "$S" "t1"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.tasks | length' "$G")" = "0" ]
  [ "$(jq -e 'type == "object"' "$G")" = "true" ]
}

@test "a graph with no .tasks array is refused with 4, not read as empty (error)" {
  graph '{"nodes":[]}'
  before=$(cat "$G")
  run sh "$GD" "$G" "$S" "t1"
  [ "$status" -eq 4 ]
  [ "$(cat "$G")" = "$before" ]
}

@test "a missing graph file is refused with 4 (error)" {
  run sh "$GD" "$BATS_TEST_TMPDIR/nope.json" "$S" "t1"
  [ "$status" -eq 4 ]
}

@test "a status-dir path that is not a directory is refused with 4 (error)" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]}]}'
  before=$(cat "$G")
  notdir="${BATS_TEST_TMPDIR}/notadir"
  printf 'x' > "$notdir"
  run sh "$GD" "$G" "$notdir" "t1"
  [ "$status" -eq 4 ]
  [ "$(cat "$G")" = "$before" ]
}

@test "an empty task-id argument is refused with 4 — usage (boundary)" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]}]}'
  before=$(cat "$G")
  run sh "$GD" "$G" "$S" ""
  [ "$status" -eq 4 ]
  [ "$(cat "$G")" = "$before" ]
}

@test "no arguments at all is refused with 4 and prints usage (boundary)" {
  run sh "$GD"
  [ "$status" -eq 4 ]
  [[ "$output" == *"usage"* ]]
}

@test "the written graph is valid input for ready-set.sh (integration boundary)" {
  RS="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/ready-set.sh"
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]},{"id":"t2","deps":[],"outputs":["B"]}]}'
  run sh "$GD" "$G" "$S" "t2"
  [ "$status" -eq 0 ]
  printf '{"task":"t1","phase":"pending"}' > "$S/t1.json"
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 0 ]
  [ "$output" = "t1" ]
}
