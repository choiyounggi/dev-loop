#!/usr/bin/env bats
# Tests for orca-detect.sh — the gate for adopting Orca as the substrate.

setup() {
  OD="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/orca-detect.sh"
  export ORCA_SKILLS_DIR="${BATS_TEST_TMPDIR}/skills"
  mkdir -p "$ORCA_SKILLS_DIR"
}

@test "reachable orca + orchestration skill present → exit 0 (adopt)" {
  run env ORCA_STATUS_JSON='{"result":{"runtime":{"reachable":true}}}' bash "$OD"
  [ "$status" -eq 0 ]
}

@test "orca present but not reachable → exit 1 (fall back to tmux)" {
  run env ORCA_STATUS_JSON='{"result":{"runtime":{"reachable":false}}}' bash "$OD"
  [ "$status" -eq 1 ]
}

@test "orchestration skill dir missing → exit 1 (do not adopt)" {
  run env ORCA_SKILLS_DIR="${BATS_TEST_TMPDIR}/nope" \
      ORCA_STATUS_JSON='{"result":{"runtime":{"reachable":true}}}' bash "$OD"
  [ "$status" -eq 1 ]
}

@test "no orca binary and no canned status → exit 1 (boundary)" {
  run env ORCA_BIN=/nonexistent/orca bash "$OD"
  [ "$status" -eq 1 ]
}

@test "malformed status json → exit 1 (fail closed)" {
  run env ORCA_STATUS_JSON='not json' bash "$OD"
  [ "$status" -eq 1 ]
}
