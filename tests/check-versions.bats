#!/usr/bin/env bats
# Tests for scripts/check-versions.sh — CI-enforced version consistency
# between plugin.json and this repo's own entry in marketplace.json,
# matched by plugin NAME rather than the marketplace entry's source path.
# (dev-loop's marketplace entry sources a git URL, not a local path — see
# the script's header comment for why source-path matching cannot work here.)
#
# Content assertions use `grep -qF` rather than mid-test `[[ … ]]`: bats runs
# under bash 3.2 on macOS, where a false `[[ ]]` outside the test's last line
# does not fail the test (set -e is suppressed there pre-bash-4).

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/check-versions.sh"
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
}

# Builds a minimal fixture repo tree at $FIXTURE with the given plugin.json
# and marketplace.json bodies (jq -n filters). Never touches the real repo's
# manifests.
make_fixture() {
  FIXTURE="$BATS_TEST_TMPDIR/fixture"
  mkdir -p "$FIXTURE/.claude-plugin"
  jq -n "$1" > "$FIXTURE/.claude-plugin/plugin.json"
  jq -n "$2" > "$FIXTURE/.claude-plugin/marketplace.json"
}

@test "normal: real repo's marketplace entry (url source) matches plugin.json by name" {
  run "$SCRIPT" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qF "ok: dev-loop"
}

@test "error: a version mismatch exits 1 and names the plugin and both versions" {
  make_fixture \
    '{name: "dev-loop", version: "1.0.0"}' \
    '{plugins: [{name: "dev-loop", source: {source: "url", url: "https://example.com/repo.git"}, version: "2.0.0"}]}'

  run "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -qF "dev-loop"
  printf '%s\n' "$output" | grep -qF "2.0.0"
  printf '%s\n' "$output" | grep -qF "1.0.0"
}

@test "boundary: marketplace has no entry named like the plugin exits 1, not silently 0" {
  make_fixture \
    '{name: "dev-loop", version: "1.0.0"}' \
    '{plugins: [{name: "other-plugin", source: {source: "url", url: "https://example.com/repo.git"}, version: "1.0.0"}]}'

  run "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -qF "no entry"
  printf '%s\n' "$output" | grep -qF "dev-loop"
}

@test "boundary: missing plugin.json exits 2" {
  FIXTURE="$BATS_TEST_TMPDIR/fixture"
  mkdir -p "$FIXTURE/.claude-plugin"
  jq -n '{plugins: []}' > "$FIXTURE/.claude-plugin/marketplace.json"

  run "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 2 ]
  printf '%s\n' "$output" | grep -qF "plugin.json"
}

@test "boundary: unparseable marketplace.json exits 2" {
  FIXTURE="$BATS_TEST_TMPDIR/fixture"
  mkdir -p "$FIXTURE/.claude-plugin"
  jq -n '{name: "dev-loop", version: "1.0.0"}' > "$FIXTURE/.claude-plugin/plugin.json"
  printf '{not valid json' > "$FIXTURE/.claude-plugin/marketplace.json"

  run "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 2 ]
  printf '%s\n' "$output" | grep -qF "unparseable"
}

@test "boundary: an extra non-matching-name entry is skipped, not an error" {
  make_fixture \
    '{name: "dev-loop", version: "1.0.0"}' \
    '{plugins: [{name: "other-plugin", source: "./x", version: "9.9.9"}, {name: "dev-loop", source: {source: "url", url: "https://example.com/repo.git"}, version: "1.0.0"}]}'

  run "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qF "skip: other-plugin"
  printf '%s\n' "$output" | grep -qF "ok: dev-loop"
}
