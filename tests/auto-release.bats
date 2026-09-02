#!/usr/bin/env bats
# Tests for scripts/auto-release.sh — detects unreleased commits on main and
# computes the next semver from conventional-commit messages (need/skip/
# collision). Detection only: the script never edits, commits, or pushes, so
# these fixtures are throwaway git repos under $BATS_TEST_TMPDIR.
#
# Content assertions use `grep -qF` rather than mid-test `[[ … ]]`: bats runs
# under bash 3.2 on macOS, where a false `[[ ]]` outside the test's last line
# does not fail the test (set -e is suppressed there pre-bash-4).

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../scripts/auto-release.sh"
}

# Builds a minimal fixture git repo at $FIXTURE with plugin.json at version
# $1, committed and tagged v$1 — the "everything released" baseline the
# script diffs against.
make_released_fixture() {
  FIXTURE="$BATS_TEST_TMPDIR/fixture"
  rm -rf "$FIXTURE"
  mkdir -p "$FIXTURE/.claude-plugin"
  git -C "$FIXTURE" init -q
  git -C "$FIXTURE" config user.email "test@example.com"
  git -C "$FIXTURE" config user.name "Test"
  jq -n --arg version "$1" '{name: "widget", version: $version}' \
    > "$FIXTURE/.claude-plugin/plugin.json"
  git -C "$FIXTURE" add .claude-plugin/plugin.json
  git -C "$FIXTURE" commit -q -m "chore(release): $1"
  git -C "$FIXTURE" tag "v$1"
}

# Adds one empty commit with subject $1 (and optional body $2) to $FIXTURE.
add_commit() {
  if [ "$#" -ge 2 ]; then
    git -C "$FIXTURE" commit -q --allow-empty -m "$1" -m "$2"
  else
    git -C "$FIXTURE" commit -q --allow-empty -m "$1"
  fi
}

@test "need: a fix commit bumps patch" {
  make_released_fixture "1.2.3"
  add_commit "fix(orchestrate): close the gap"

  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qF "need: 1.2.3 1.2.4"
}

@test "need: a feat commit bumps minor and resets patch" {
  make_released_fixture "1.2.3"
  add_commit "feat(wiki): new page router"

  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qF "need: 1.2.3 1.3.0"
}

@test "need: a bang subject bumps major and resets minor+patch" {
  make_released_fixture "1.2.3"
  add_commit "refactor(core)!: drop the v1 status protocol"

  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qF "need: 1.2.3 2.0.0"
}

@test "need: BREAKING CHANGE in a body bumps major even with a plain subject" {
  make_released_fixture "1.2.3"
  add_commit "fix: adjust collector" "BREAKING CHANGE: status files moved"

  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qF "need: 1.2.3 2.0.0"
}

@test "need: the highest rule in the range wins (feat + fix -> minor)" {
  make_released_fixture "0.9.9"
  add_commit "fix: small thing"
  add_commit "feat: bigger thing"
  add_commit "docs: readme"

  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qF "need: 0.9.9 0.10.0"
}

@test "need: a merge/other commit alone still bumps patch" {
  make_released_fixture "1.0.0"
  add_commit "merge: task/t1 into orch/integration"

  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qF "need: 1.0.0 1.0.1"
}

@test "skip: nothing new since the tag" {
  make_released_fixture "1.2.3"

  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qF "skip: nothing new since v1.2.3"
}

@test "skip: version ahead of tags means a release is in flight (loop guard)" {
  # This is the state right after the bump commit lands and before auto-tag
  # tags it — the re-triggered run must do nothing.
  make_released_fixture "1.2.3"
  jq '.version = "1.2.4"' "$FIXTURE/.claude-plugin/plugin.json" > "$FIXTURE/p.tmp"
  mv "$FIXTURE/p.tmp" "$FIXTURE/.claude-plugin/plugin.json"
  git -C "$FIXTURE" add .claude-plugin/plugin.json
  add_commit "chore(release): 1.2.4 [auto-release]"

  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qF "skip: v1.2.4 awaiting tag"
}

@test "error: computed next version already tagged is a collision, exit 1" {
  make_released_fixture "1.2.3"
  add_commit "fix: regressed history"
  git -C "$FIXTURE" tag v1.2.4

  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 1 ]
  printf '%s\n' "$output" | grep -qF "COLLISION"
}

@test "error: malformed version string exits 2" {
  make_released_fixture "1.2.3"
  jq '.version = "1.2"' "$FIXTURE/.claude-plugin/plugin.json" > "$FIXTURE/p.tmp"
  mv "$FIXTURE/p.tmp" "$FIXTURE/.claude-plugin/plugin.json"

  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 2 ]
}

@test "error: a 4-segment version exits 2 (review F1 — rejoining read folds it into patch)" {
  make_released_fixture "1.2.3"
  jq '.version = "1.2.3.4"' "$FIXTURE/.claude-plugin/plugin.json" > "$FIXTURE/p.tmp"
  mv "$FIXTURE/p.tmp" "$FIXTURE/.claude-plugin/plugin.json"

  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 2 ]
  printf '%s\n' "$output" | grep -qF "is not X.Y.Z"
}

@test "error: empty-segment versions exit 2 (1..2 and .1.2)" {
  make_released_fixture "1.2.3"
  for bad in "1..2" ".1.2" "1.2."; do
    jq --arg v "$bad" '.version = $v' "$FIXTURE/.claude-plugin/plugin.json" > "$FIXTURE/p.tmp"
    mv "$FIXTURE/p.tmp" "$FIXTURE/.claude-plugin/plugin.json"
    run bash "$SCRIPT" "$FIXTURE"
    [ "$status" -eq 2 ]
  done
}

@test "error: missing plugin.json exits 2" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/does-not-exist"
  [ "$status" -eq 2 ]
}

@test "error: two arguments is a usage error, exit 2" {
  run bash "$SCRIPT" a b
  [ "$status" -eq 2 ]
}

@test "boundary: feat with scope and bang prefers major over minor" {
  make_released_fixture "3.4.5"
  add_commit "feat(api)!: remove legacy endpoint"

  run bash "$SCRIPT" "$FIXTURE"
  [ "$status" -eq 0 ]
  printf '%s\n' "$output" | grep -qF "need: 3.4.5 4.0.0"
}
