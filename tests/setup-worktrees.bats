#!/usr/bin/env bats
# Tests for setup-worktrees.sh idempotency — the infrastructure partial resume
# relies on: an existing branch/worktree (e.g. a sub-issue already worked) must be
# detected and kept, never re-created, while new task branches are still added.

setup() {
  SW="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/setup-worktrees.sh"
  root="${BATS_TEST_TMPDIR}/repo"; mkdir -p "$root"
  git -C "$root" init -q -b main
  git -C "$root" config user.email t@t; git -C "$root" config user.name t
  echo x > "$root/f"; git -C "$root" add f; git -C "$root" commit -qm init
}

@test "creates integration branch + a worktree per task" {
  run bash "$SW" feat/goal "$root" main feat/t1 feat/t2
  [ "$status" -eq 0 ]
  git -C "$root" show-ref --verify --quiet refs/heads/feat/goal
  [ -d "$root/.worktrees/feat-t1" ]
  [ -d "$root/.worktrees/feat-t2" ]
}

@test "idempotent: existing branch/worktree kept, new task added (partial resume)" {
  bash "$SW" feat/goal "$root" main feat/t1            # first run: t1 done elsewhere
  [ -d "$root/.worktrees/feat-t1" ]
  marker="$root/.worktrees/feat-t1/already-here"
  : > "$marker"                                        # prove the worktree is NOT recreated
  run bash "$SW" feat/goal "$root" main feat/t1 feat/t2  # second run adds t2
  [ "$status" -eq 0 ]
  [ -f "$marker" ]                                     # t1 worktree preserved
  [ -d "$root/.worktrees/feat-t2" ]                    # t2 newly created
  [[ "$output" == *"feat/t1 exists"* ]]
}

@test "errors on too few arguments" {
  run bash "$SW" feat/goal "$root"
  [ "$status" -ne 0 ]
}

# Regression: the script cd's to <repo-root>, so a RELATIVE $0 must be resolved
# to an absolute dir first — otherwise the sibling worker-guardrails.sh is looked
# up under the repo root, is not found, and set -e aborts mid-provision leaving a
# worktree with no guardrails sandbox.
@test "invoked by a relative path from another cwd: still provisions the sandbox" {
  scriptdir=$(cd "$(dirname "$SW")" && pwd -P)
  parent=$(dirname "$scriptdir")                       # .../skills/orchestrate
  base=$(dirname "$parent")                            # .../skills
  run env -C "$base" sh "orchestrate/scripts/$(basename "$SW")" feat/goal "$root" main feat/t1
  [ "$status" -eq 0 ]
  [ -f "$root/.worktrees/feat-t1/.groundwork/guardrails.json" ]
  [[ "$output" != *"No such file or directory"* ]]
}

@test "writes a worker-scoped guardrails config into each worktree" {
  run bash "$SW" feat/goal "$root" main feat/t1
  [ "$status" -eq 0 ]
  cfg="$root/.worktrees/feat-t1/.groundwork/guardrails.json"
  [ -f "$cfg" ]
  [ "$(jq -r '.rules.rm_rf.mode' "$cfg")" = "off" ]
  [ "$(jq -r '.rules.cloud_delete.mode' "$cfg")" = "ask" ]
  [ "$(jq -r '.rules.worktree_escape.mode' "$cfg")" = "ask" ]
}

@test "worker guardrails config is git-excluded (not accidentally committable)" {
  run bash "$SW" feat/goal "$root" main feat/t1
  [ "$status" -eq 0 ]
  run git -C "$root/.worktrees/feat-t1" status --porcelain
  [[ "$output" != *".groundwork/guardrails.json"* ]]
}
