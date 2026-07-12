#!/usr/bin/env bats
# Tests for hooks/preflight.sh
# Run in CI (test.yml on ubuntu). bats may be absent on the author's macOS;
# the normal case is also verified directly via shell during development.

setup() {
  PREFLIGHT="${BATS_TEST_DIRNAME}/../hooks/preflight.sh"
}

# stub a PATH that contains everything EXCEPT the named tool
_stub_without() {
  local omit="$1" stub="${BATS_TEST_TMPDIR}/bin" b src
  mkdir -p "$stub"
  for b in git jq bash sh env grep tmux; do
    [ "$b" = "$omit" ] && continue
    src="$(command -v "$b")" && ln -sf "$src" "$stub/$b"
  done
  echo "$stub"
}

@test "all deps present: exit 0 and emits resolved paths" {
  run bash "$PREFLIGHT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"LOOP_GIT="* ]]
  [[ "$output" == *"LOOP_TMUX="* ]]
  [[ "$output" == *"LOOP_JQ="* ]]
}

@test "missing tmux: advises install but stays non-blocking (exit 0)" {
  stub="$(_stub_without tmux)"
  run env PATH="$stub" bash "$PREFLIGHT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tmux"* ]]
}

@test "missing tmux: install advice goes to stderr, not stdout" {
  stub="$(_stub_without tmux)"
  run bash -c "env PATH='$stub' bash '$PREFLIGHT' 2>/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" != *"brew install"* ]]
  [[ "$output" != *"apt-get"* ]]
}

@test "missing jq: reported in advice" {
  stub="$(_stub_without jq)"
  run env PATH="$stub" bash "$PREFLIGHT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"jq"* ]]
}
