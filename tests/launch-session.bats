#!/usr/bin/env bats
# Tests for launch-session.sh argument/permission guards.
# (Full launch needs tmux + claude; those paths are covered by manual/integration
# runs. Here we cover the cheap, deterministic guards.)

setup() {
  LS="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/launch-session.sh"
}

@test "rejects an invalid permission mode (injection guard)" {
  run bash "$LS" sess "${BATS_TEST_TMPDIR}/wt" "bypassPermissions; rm -rf ~" "prompt"
  [ "$status" -eq 2 ]
}

@test "errors on wrong argument count" {
  run bash "$LS" sess
  [ "$status" -ne 0 ]
}

@test "LO_DRY_RUN prints the resolved session name and exits before tmux/claude" {
  run env LO_DRY_RUN=1 bash "$LS" lo-1 "${BATS_TEST_TMPDIR}/wt" bypassPermissions "prompt"
  [ "$status" -eq 0 ]
  [ "$output" = "session=lo-1" ]
}

@test "LO_RUN_ID makes the session name unique per run" {
  run env LO_RUN_ID=r1 LO_DRY_RUN=1 bash "$LS" lo-1 "${BATS_TEST_TMPDIR}/wt" bypassPermissions "prompt"
  [ "$status" -eq 0 ]
  [ "$output" = "session=lo-1-r1" ]
}

@test "invalid permission mode is still rejected in dry-run (no guard bypass)" {
  run env LO_DRY_RUN=1 bash "$LS" lo-1 "${BATS_TEST_TMPDIR}/wt" "bad; rm -rf ~" "prompt"
  [ "$status" -eq 2 ]
}
