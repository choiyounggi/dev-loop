#!/usr/bin/env bats
# Tests for scripts/check-pin-drift.sh — "did the release actually reach users?"
#
# Exit codes under test: 0 in sync, 1 drift (either direction), 2 usage / bad
# tag format. The drift message must name the direction, because the fix
# differs: a behind pin needs a groundwork bump, an ahead pin needs a dev-loop
# tag (or a rollback).

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/check-pin-drift.sh"
}

@test "identical tags are in sync" {
  run bash "$SCRIPT" v1.11.0 v1.11.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"in sync"* ]]
}

@test "a pin behind the latest release is drift, with the groundwork fix" {
  run bash "$SCRIPT" v1.11.0 v1.10.0
  [ "$status" -eq 1 ]
  [[ "$output" == *"DRIFT"* ]]
  [[ "$output" == *"not reaching users"* ]]
  [[ "$output" == *"sync-dev-loop-pin.sh v1.11.0"* ]]
}

@test "a pin ahead of the latest release is drift, with the other fix" {
  run bash "$SCRIPT" v1.10.0 v1.11.0
  [ "$status" -eq 1 ]
  [[ "$output" == *"newer than the latest dev-loop release"* ]]
}

@test "double-digit versions compare numerically, not lexically" {
  # 1.9.0 vs 1.10.0 is the classic lexical-sort trap: "1.9" > "1.10" as strings.
  run bash "$SCRIPT" v1.10.0 v1.9.0
  [ "$status" -eq 1 ]
  [[ "$output" == *"not reaching users"* ]]
}

@test "a patch-level gap is still drift" {
  run bash "$SCRIPT" v1.11.1 v1.11.0
  [ "$status" -eq 1 ]
}

@test "usage error with no arguments" {
  run bash "$SCRIPT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage:"* ]]
}

@test "usage error with one argument" {
  run bash "$SCRIPT" v1.11.0
  [ "$status" -eq 2 ]
}

@test "usage error with three arguments" {
  run bash "$SCRIPT" v1.11.0 v1.11.0 extra
  [ "$status" -eq 2 ]
}

@test "an empty pinned ref is a format error, not 'in sync'" {
  run bash "$SCRIPT" v1.11.0 ""
  [ "$status" -eq 2 ]
  [[ "$output" == *"not a vX.Y.Z release tag"* ]]
}

@test "an empty latest tag is a format error" {
  run bash "$SCRIPT" "" v1.11.0
  [ "$status" -eq 2 ]
}

@test "a branch name as the pin is a format error" {
  run bash "$SCRIPT" v1.11.0 main
  [ "$status" -eq 2 ]
}

@test "a bare version without the v prefix is a format error" {
  run bash "$SCRIPT" 1.11.0 v1.11.0
  [ "$status" -eq 2 ]
}

@test "two equal but malformed tags do not short-circuit to in sync" {
  run bash "$SCRIPT" main main
  [ "$status" -eq 2 ]
}

@test "this repo's own version is a well-formed tag for the check" {
  version="$(jq -r .version "${BATS_TEST_DIRNAME}/../.claude-plugin/plugin.json")"
  run bash "$SCRIPT" "v${version}" "v${version}"
  [ "$status" -eq 0 ]
}
