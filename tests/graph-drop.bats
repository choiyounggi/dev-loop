#!/usr/bin/env bats
# Tests for graph-drop.sh — the symmetric shrink path to graph-add.sh.
# It removes ONE undispatched node and validates the RESULTING graph. A
# rejected drop must leave the file byte-identical: a half-applied graph
# breaks re-entry.

setup() {
  GD="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/graph-drop.sh"
  G="${BATS_TEST_TMPDIR}/graph.json"
  S="${BATS_TEST_TMPDIR}/status"; mkdir -p "$S"
  SKILL="${BATS_TEST_DIRNAME}/../skills/orchestrate/SKILL.md"
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

# --- SKILL.md ordering: split keeps its own lead-in -> mechanics -> closing
# arc intact, drop is appended as its own self-contained coda, and the two
# closing sentences are self-identifying rather than near-duplicates
# (review r2 F1).

split_section() {
  awk '/^## Splitting a task mid-run/{p=1} p && /^## / && !/^## Splitting a task mid-run/{exit} p' "$1"
}

@test "SKILL.md: split's closing sentence precedes the drop paragraph, not the reverse (order)" {
  section="$(split_section "$SKILL")"
  grew_line=$(printf '%s\n' "$section" | grep -n 'just \*\*grew\*\* (split)' | head -1 | cut -d: -f1)
  drop_line=$(printf '%s\n' "$section" | grep -n '\*\*Dropping a task mid-run\.\*\*' | head -1 | cut -d: -f1)
  [ -n "$grew_line" ]
  [ -n "$drop_line" ]
  [ "$grew_line" -lt "$drop_line" ]
}

@test "SKILL.md: split and drop closing sentences are self-identifying, not near-duplicates (order)" {
  section="$(split_section "$SKILL")"
  [[ "$section" == *"just **grew** (split)"* ]]
  [[ "$section" == *"just **shrank** (drop)"* ]]
}

# --- negative control: reproducing the r2 defect (drop's paragraph moved
# before split's own closing sentence) must fail the order check above ------

@test "negative control: a SKILL.md copy with drop's paragraph swapped ahead of split's closing sentence fails the order check" {
  swapped="${BATS_TEST_TMPDIR}/skill-swapped-split-drop.md"
  awk -v RS='' -v ORS='\n\n' '
    /just \*\*grew\*\* \(split\)/ { grewP = $0; next }
    /\*\*Dropping a task mid-run\.\*\*/ { print; print grewP; next }
    { print }
  ' "$SKILL" > "$swapped"
  section="$(split_section "$swapped")"
  grew_line=$(printf '%s\n' "$section" | grep -n 'just \*\*grew\*\* (split)' | head -1 | cut -d: -f1)
  drop_line=$(printf '%s\n' "$section" | grep -n '\*\*Dropping a task mid-run\.\*\*' | head -1 | cut -d: -f1)
  [ -n "$grew_line" ]
  [ -n "$drop_line" ]
  [ "$grew_line" -gt "$drop_line" ]
}
