#!/usr/bin/env bats
# Tests for ask-coordinator.sh — the worker-side question writer.
# Contract: STATUS_DIR=<abs> ask-coordinator.sh <task> <question> [options-csv]
#   -> atomic $(dirname $STATUS_DIR)/questions/<task>.json {ts,taskId,question,options,worktree}
#   exit 0 written / 1 usage / 127 jq missing; one pending question per task.

bats_require_minimum_version 1.5.0

setup() {
  AC="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/ask-coordinator.sh"
  ORCH="${BATS_TEST_TMPDIR}/.orchestration"
  mkdir -p "$ORCH/status"
}

@test "writes the record with every contract field (normal)" {
  cd "$BATS_TEST_TMPDIR"
  run env STATUS_DIR="$ORCH/status" sh "$AC" t1 "Which DB?" "postgres,sqlite"
  [ "$status" -eq 0 ]
  [[ "$output" == *"question[t1] recorded"* ]]
  [ -f "$ORCH/questions/t1.json" ]
  [ "$(jq -r '.taskId' "$ORCH/questions/t1.json")" = "t1" ]
  [ "$(jq -r '.question' "$ORCH/questions/t1.json")" = "Which DB?" ]
  [ "$(jq -c '.options' "$ORCH/questions/t1.json")" = '["postgres","sqlite"]' ]
  [ "$(jq -r '.worktree' "$ORCH/questions/t1.json")" = "$(pwd -P)" ]
  [[ "$(jq -r '.ts' "$ORCH/questions/t1.json")" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]
}

@test "no options argument yields an empty options array (normal)" {
  run env STATUS_DIR="$ORCH/status" sh "$AC" t1 "Proceed?"
  [ "$status" -eq 0 ]
  [ "$(jq -c '.options' "$ORCH/questions/t1.json")" = '[]' ]
}

@test "a second call for the same task overwrites — one pending question (normal)" {
  run env STATUS_DIR="$ORCH/status" sh "$AC" t1 "first?"
  [ "$status" -eq 0 ]
  run env STATUS_DIR="$ORCH/status" sh "$AC" t1 "second?"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.question' "$ORCH/questions/t1.json")" = "second?" ]
  [ "$(find "$ORCH/questions" -name '*.json' | wc -l | tr -d ' ')" = "1" ]
}

@test "missing arguments is a usage error (error)" {
  run env STATUS_DIR="$ORCH/status" sh "$AC"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
}

@test "unset STATUS_DIR is a usage error (error)" {
  run env -u STATUS_DIR sh "$AC" t1 "q?"
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
}

@test "missing jq exits 127 (error)" {
  run -127 env PATH=/nonexistent STATUS_DIR="$ORCH/status" /bin/sh "$AC" t1 "q?"
  [ "$status" -eq 127 ]
  [[ "$output" == *"jq not found"* ]]
}

@test "empty question is refused (boundary)" {
  run env STATUS_DIR="$ORCH/status" sh "$AC" t1 ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage"* ]]
}

@test "a task name that would escape the questions dir is refused (boundary)" {
  run env STATUS_DIR="$ORCH/status" sh "$AC" "../evil" "q?"
  [ "$status" -eq 1 ]
  [ ! -e "$ORCH/evil.json" ]
  [ ! -e "${BATS_TEST_TMPDIR}/evil.json" ]
}

@test "a trailing comma splits verbatim into a trailing empty option (boundary)" {
  run env STATUS_DIR="$ORCH/status" sh "$AC" t1 "q?" "a,"
  [ "$status" -eq 0 ]
  [ "$(jq -c '.options' "$ORCH/questions/t1.json")" = '["a",""]' ]
}

@test "no temp file is left behind after a successful write (boundary)" {
  run env STATUS_DIR="$ORCH/status" sh "$AC" t1 "q?"
  [ "$status" -eq 0 ]
  [ -z "$(find "$ORCH/questions" -name '*.tmp.*' -print)" ]
}
