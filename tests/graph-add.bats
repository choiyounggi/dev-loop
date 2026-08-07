#!/usr/bin/env bats
# Tests for graph-add.sh — the only writer of graph.json after Phase 2.
# It adds ONE node and validates the RESULTING graph. A rejected add must
# leave the file byte-identical: a half-applied graph breaks re-entry.

setup() {
  GA="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/graph-add.sh"
  G="${BATS_TEST_TMPDIR}/graph.json"
}

graph() { printf '%s' "$1" > "$G"; }

@test "a valid split child is appended and the parent is untouched" {
  graph '{"tasks":[{"id":"t1","deps":[],"files":["a.ts"],"outputs":["A"]}]}'
  run sh "$GA" "$G" '{"id":"t1b","deps":["t1"],"files":["b.ts"],"outputs":["B"],"split_of":"t1"}'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.tasks | length' "$G")" = "2" ]
  [ "$(jq -r '.tasks[1].split_of' "$G")" = "t1" ]
  [ "$(jq -r '.tasks[0].outputs[0]' "$G")" = "A" ]
}

@test "splitting a split is refused (depth 1) and the file is untouched" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]},{"id":"t1b","deps":["t1"],"outputs":["B"],"split_of":"t1"}]}'
  before=$(cat "$G")
  run sh "$GA" "$G" '{"id":"t1c","deps":["t1b"],"outputs":["C"],"split_of":"t1b"}'
  [ "$status" -eq 3 ]
  [[ "$output" == *"depth 1"* ]]
  [ "$(cat "$G")" = "$before" ]
}

@test "a duplicate output is refused — one producer per output (error)" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["AuthToken"]}]}'
  before=$(cat "$G")
  run sh "$GA" "$G" '{"id":"t2","deps":[],"outputs":["AuthToken"]}'
  [ "$status" -eq 3 ]
  [[ "$output" == *"two producers"* ]]
  [ "$(cat "$G")" = "$before" ]
}

@test "a node that would close a cycle is refused (boundary)" {
  graph '{"tasks":[{"id":"t1","deps":["t2"],"outputs":["A"]}]}'
  before=$(cat "$G")
  run sh "$GA" "$G" '{"id":"t2","deps":["t1"],"outputs":["B"]}'
  [ "$status" -eq 3 ]
  [[ "$output" == *"cycle"* ]]
  [ "$(cat "$G")" = "$before" ]
}

@test "a duplicate task id is refused, never an overwrite (error)" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]}]}'
  before=$(cat "$G")
  run sh "$GA" "$G" '{"id":"t1","deps":[],"outputs":["Z"]}'
  [ "$status" -eq 3 ]
  [[ "$output" == *"already exists"* ]]
  [ "$(cat "$G")" = "$before" ]
}

@test "a dependency on an undefined task is refused (error)" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]}]}'
  run sh "$GA" "$G" '{"id":"t2","deps":["ghost"],"outputs":["B"]}'
  [ "$status" -eq 3 ]
  [[ "$output" == *"ghost"* ]]
}

@test "split_of naming an undefined parent is refused (error)" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]}]}'
  run sh "$GA" "$G" '{"id":"t2","deps":[],"outputs":["B"],"split_of":"ghost"}'
  [ "$status" -eq 3 ]
  [[ "$output" == *"ghost"* ]]
}

@test "a node with no outputs is fine — not every split produces an interface (boundary)" {
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]}]}'
  run sh "$GA" "$G" '{"id":"t1b","deps":["t1"],"files":["b.ts"],"split_of":"t1"}'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.tasks | length' "$G")" = "2" ]
}

@test "an empty graph accepts a first node (boundary)" {
  graph '{"tasks":[]}'
  run sh "$GA" "$G" '{"id":"t1","deps":[],"outputs":["A"]}'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.tasks[0].id' "$G")" = "t1" ]
}

@test "malformed node JSON is refused with 4, not 3 (error)" {
  graph '{"tasks":[]}'
  run sh "$GA" "$G" '}{ not json'
  [ "$status" -eq 4 ]
}

@test "a node without an id is refused with 4 (boundary)" {
  graph '{"tasks":[]}'
  run sh "$GA" "$G" '{"deps":[]}'
  [ "$status" -eq 4 ]
}

@test "a missing graph file is refused with 4 (error)" {
  run sh "$GA" "$BATS_TEST_TMPDIR/nope.json" '{"id":"t1","deps":[]}'
  [ "$status" -eq 4 ]
}

@test "a graph with no .tasks array is refused with 4, not read as empty (error)" {
  graph '{"nodes":[]}'
  run sh "$GA" "$G" '{"id":"t1","deps":[]}'
  [ "$status" -eq 4 ]
}

@test "the written graph is valid input for ready-set.sh (integration boundary)" {
  # The only consumer of this file. An add that ready-set.sh cannot parse would
  # strand the whole run, and the rejection codes differ (3 here, 4 there).
  RS="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/ready-set.sh"
  S="${BATS_TEST_TMPDIR}/status"; mkdir -p "$S"
  graph '{"tasks":[{"id":"t1","deps":[],"outputs":["A"]}]}'
  run sh "$GA" "$G" '{"id":"t1b","deps":["t1"],"outputs":["B"],"split_of":"t1"}'
  [ "$status" -eq 0 ]
  printf '{"task":"t1","phase":"approved"}' > "$S/t1.json"
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 0 ]
  [ "$output" = "t1b" ]
}
