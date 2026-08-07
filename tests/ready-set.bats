#!/usr/bin/env bats
# Tests for ready-set.sh — the Wave-barrier replacement. Given the dependency
# graph and each task's recorded phase, it answers exactly one question:
# which tasks may be dispatched right now. It never launches anything.

setup() {
  RS="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/ready-set.sh"
  G="${BATS_TEST_TMPDIR}/graph.json"
  S="${BATS_TEST_TMPDIR}/status"
  mkdir -p "$S"
}

graph() { printf '%s' "$1" > "$G"; }
phase() { printf '{"task":"%s","phase":"%s"}' "$1" "$2" > "$S/$1.json"; }

@test "no deps, empty status: every task is dispatchable up to the cap" {
  graph '{"tasks":[{"id":"t1","deps":[]},{"id":"t2","deps":[]},{"id":"t3","deps":[]}]}'
  run sh "$RS" "$G" "$S" 2
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | grep -c .)" -eq 2 ]
}

@test "a dependent waits until its dep is approved, not merely impl_done" {
  graph '{"tasks":[{"id":"t1","deps":[]},{"id":"t2","deps":["t1"]}]}'
  phase t1 impl_done
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 2 ]          # t1 busy (review pending), t2 not yet startable

  phase t1 approved
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 0 ]
  [ "$output" = "t2" ]
}

@test "review-pending phases occupy a slot (plan_ready and impl_done both count)" {
  graph '{"tasks":[{"id":"a","deps":[]},{"id":"b","deps":[]},{"id":"c","deps":[]}]}'
  phase a plan_ready
  phase b impl_done
  run sh "$RS" "$G" "$S" 2
  [ "$status" -eq 2 ]          # cap 2 fully occupied by two review-waiting tasks
}

@test "a failed dependency is a deadlock, never a quiet wait (the core guard)" {
  graph '{"tasks":[{"id":"t1","deps":[]},{"id":"t2","deps":["t1"]}]}'
  phase t1 failed
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 3 ]
  [[ "$output" == *"DEADLOCK"* ]]
}

@test "a cycle surfaces as the same deadlock (boundary)" {
  graph '{"tasks":[{"id":"t1","deps":["t2"]},{"id":"t2","deps":["t1"]}]}'
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 3 ]
}

@test "all tasks terminal: exit 5, the run is complete (boundary)" {
  graph '{"tasks":[{"id":"t1","deps":[]},{"id":"t2","deps":["t1"]}]}'
  phase t1 approved
  phase t2 merged
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 5 ]
}

@test "an empty task array is complete, not a deadlock (boundary)" {
  graph '{"tasks":[]}'
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 5 ]
}

@test "a graph with no .tasks array is refused, not read as empty (error)" {
  graph '{"nodes":[]}'
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 4 ]
}

@test "malformed JSON is refused (error)" {
  graph '}{ not json'
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 4 ]
}

@test "a dep naming an undefined task is refused, not blocked forever (error)" {
  graph '{"tasks":[{"id":"t1","deps":["ghost"]}]}'
  run sh "$RS" "$G" "$S" 4
  [ "$status" -eq 4 ]
}

@test "LO_MAX_SESSIONS lowers the cap but never raises it" {
  graph '{"tasks":[{"id":"a","deps":[]},{"id":"b","deps":[]},{"id":"c","deps":[]}]}'
  run env LO_MAX_SESSIONS=1 sh "$RS" "$G" "$S" 3
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | grep -c .)" -eq 1 ]

  run env LO_MAX_SESSIONS=9 sh "$RS" "$G" "$S" 2
  [ "$(echo "$output" | grep -c .)" -eq 2 ]
}

@test "a non-numeric or zero cap is refused (boundary)" {
  graph '{"tasks":[{"id":"a","deps":[]}]}'
  run sh "$RS" "$G" "$S" 0
  [ "$status" -eq 4 ]
  run sh "$RS" "$G" "$S" abc
  [ "$status" -eq 4 ]
}

@test "a missing graph or status dir is refused (error)" {
  run sh "$RS" "$BATS_TEST_TMPDIR/nope.json" "$S" 2
  [ "$status" -eq 4 ]
  graph '{"tasks":[]}'
  run sh "$RS" "$G" "$BATS_TEST_TMPDIR/nodir" 2
  [ "$status" -eq 4 ]
}
