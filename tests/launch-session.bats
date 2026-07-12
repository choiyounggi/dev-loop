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
