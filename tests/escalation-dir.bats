#!/usr/bin/env bats
# Tests for escalation-dir.sh — derive a worktree's main-repo escalation dir.

setup() {
  ED="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/escalation-dir.sh"
  root="${BATS_TEST_TMPDIR}/repo"; mkdir -p "$root"
  git -C "$root" init -q -b main
  git -C "$root" config user.email t@t; git -C "$root" config user.name t
  echo x > "$root/f"; git -C "$root" add f; git -C "$root" commit -qm init
  git -C "$root" branch integ
  git -C "$root" worktree add -q "$root/.worktrees/t1" integ
  rootp=$(cd "$root" && pwd -P)   # physical path (macOS /var -> /private/var)
}

@test "derives the main repo's escalation dir from a linked worktree" {
  run sh "$ED" "$root/.worktrees/t1"
  [ "$status" -eq 0 ]
  [ "$output" = "$rootp/.orchestration/escalations" ]
}

@test "derives the same dir from the main worktree itself" {
  run sh "$ED" "$root"
  [ "$status" -eq 0 ]
  [ "$output" = "$rootp/.orchestration/escalations" ]
}

@test "prints nothing (exit 0) when the path is not a git worktree" {
  mkdir -p "$BATS_TEST_TMPDIR/plain"
  run sh "$ED" "$BATS_TEST_TMPDIR/plain"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "usage error without an argument" {
  run sh "$ED"
  [ "$status" -ne 0 ]
}
