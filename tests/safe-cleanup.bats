#!/usr/bin/env bats
# Tests for safe-cleanup.sh guards

setup() {
  SC="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/safe-cleanup.sh"
}

@test "init-check: refuse inside an existing repo (nesting)" {
  outer="${BATS_TEST_TMPDIR}/outer"; mkdir -p "$outer/sub"
  git -C "$outer" init -q
  run bash "$SC" init-check "$outer/sub"
  [ "$status" -ne 0 ]
  [[ "$output" == *"REFUSE"* ]]
}

@test "init-check: refuse when secret-like files present" {
  wd="${BATS_TEST_TMPDIR}/sec"; mkdir -p "$wd"; : > "$wd/.env"
  run bash "$SC" init-check "$wd"
  [ "$status" -ne 0 ]
  [[ "$output" == *"secret"* ]]
}

@test "init-check: ok on a clean dir" {
  wd="${BATS_TEST_TMPDIR}/fresh"; mkdir -p "$wd"
  run bash "$SC" init-check "$wd"
  [ "$status" -eq 0 ]
}

@test "merge: refuse when a worktree has uncommitted changes" {
  root="${BATS_TEST_TMPDIR}/repo"; mkdir -p "$root"
  git -C "$root" init -q
  git -C "$root" config user.email t@t; git -C "$root" config user.name t
  echo x > "$root/f"; git -C "$root" add f; git -C "$root" commit -qm init
  git -C "$root" branch feat/t1
  git -C "$root" worktree add -q "$root/.worktrees/feat-t1" feat/t1
  echo dirty > "$root/.worktrees/feat-t1/g"   # untracked → dirty
  run bash "$SC" merge "$root" main feat/t1
  [ "$status" -ne 0 ]
  [[ "$output" == *"REFUSE"* ]]
}

@test "kill-sessions: skip a non-existent exact name (no prefix match)" {
  run bash "$SC" kill-sessions "lo-nonexistent-xyz-000"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skip"* ]]
}
