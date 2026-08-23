#!/usr/bin/env bats
# Tests for scripts/auto-tag.sh — detects whether plugin.json's version
# needs a release tag (need/skip/collision). Detection only: the script
# never creates or pushes a tag, so these fixtures are throwaway git repos
# under $BATS_TEST_TMPDIR and the real repo is touched read-only.
#
# Content assertions use `grep -qF` rather than mid-test `[[ … ]]`: bats runs
# under bash 3.2 on macOS, where a false `[[ ]]` outside the test's last line
# does not fail the test (set -e is suppressed there pre-bash-4).

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/auto-tag.sh"
  REPO_ROOT="${BATS_TEST_DIRNAME}/.."
}

# Builds a minimal fixture git repo at $FIXTURE with plugin.json set to
# $1 (name) / $2 (version), committed on its own history so `git tag` and
# `git show <tag>:...` work against it.
make_fixture_repo() {
  FIXTURE="$BATS_TEST_TMPDIR/fixture"
  mkdir -p "$FIXTURE/.claude-plugin"
  git -C "$FIXTURE" init -q
  git -C "$FIXTURE" config user.email "test@example.com"
  git -C "$FIXTURE" config user.name "Test"
  jq -n --arg name "$1" --arg version "$2" '{name: $name, version: $version}' \
    > "$FIXTURE/.claude-plugin/plugin.json"
  git -C "$FIXTURE" add .claude-plugin/plugin.json
  git -C "$FIXTURE" commit -q -m "plugin.json: $1 $2"
}

@test "need: tag absent for the current version" {
  make_fixture_repo "widget" "1.0.0"

  run "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qF "need: v1.0.0 widget"
}

@test "skip: tag exists and matches plugin.json version" {
  make_fixture_repo "widget" "1.0.0"
  git -C "$FIXTURE" tag v1.0.0

  run "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qF "skip: v1.0.0 already released"
}

@test "error: tag exists but its plugin.json version disagrees with the current one (collision) exits 1" {
  make_fixture_repo "widget" "2.0.0"
  # Mistakenly tag v1.0.0 while the committed plugin.json still says 2.0.0 —
  # a tag/content mismatch, distinct from the normal "tag matches" case.
  git -C "$FIXTURE" tag v1.0.0

  # Now advance HEAD's plugin.json to the version that maps to that same
  # tag name, so auto-tag.sh computes tag=v1.0.0 and finds it pre-existing
  # with disagreeing content.
  jq -n '{name: "widget", version: "1.0.0"}' > "$FIXTURE/.claude-plugin/plugin.json"
  git -C "$FIXTURE" add .claude-plugin/plugin.json
  git -C "$FIXTURE" commit -q -m "bump to 1.0.0 (tag v1.0.0 already exists from the 2.0.0 commit)"

  run "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -qF "COLLISION"
  printf '%s\n' "$output" | grep -qF "1.0.0"
  printf '%s\n' "$output" | grep -qF "2.0.0"
}

@test "boundary: missing plugin.json exits 2" {
  FIXTURE="$BATS_TEST_TMPDIR/fixture"
  mkdir -p "$FIXTURE/.claude-plugin"
  git -C "$FIXTURE" init -q
  git -C "$FIXTURE" config user.email "test@example.com"
  git -C "$FIXTURE" config user.name "Test"

  run "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 2 ]
  printf '%s\n' "$output" | grep -qF "plugin.json"
}

@test "normal: the real repo reports skip for the already-released v1.9.0" {
  run "$SCRIPT" "$REPO_ROOT"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qF "skip: v1.9.0 already released"
}
