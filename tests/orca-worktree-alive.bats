#!/usr/bin/env bats
# Tests for orca-worktree-alive.sh — Orca-native worker liveness.

setup() {
  OA="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/orca-worktree-alive.sh"
}

@test "alive: worktree has a live terminal → exit 0" {
  json='{"result":{"worktrees":[{"path":"/wt","liveTerminalCount":1,"hasAttachedPty":true}]}}'
  run env ORCA_WORKTREE_PS_JSON="$json" bash "$OA" /wt
  [ "$status" -eq 0 ]
}

@test "alive via hasAttachedPty even when liveTerminalCount is 0" {
  json='{"result":{"worktrees":[{"path":"/wt","liveTerminalCount":0,"hasAttachedPty":true}]}}'
  run env ORCA_WORKTREE_PS_JSON="$json" bash "$OA" /wt
  [ "$status" -eq 0 ]
}

@test "dead: worktree tracked but no live terminal → exit 1" {
  json='{"result":{"worktrees":[{"path":"/wt","liveTerminalCount":0,"hasAttachedPty":false}]}}'
  run env ORCA_WORKTREE_PS_JSON="$json" bash "$OA" /wt
  [ "$status" -eq 1 ]
}

@test "unknown: worktree not tracked by Orca → exit 2 (not dead)" {
  json='{"result":{"worktrees":[{"path":"/other","liveTerminalCount":1}]}}'
  run env ORCA_WORKTREE_PS_JSON="$json" bash "$OA" /wt
  [ "$status" -eq 2 ]
}

@test "unknown: malformed ps output → exit 2 (fail to unknown, never dead)" {
  run env ORCA_WORKTREE_PS_JSON='not json' bash "$OA" /wt
  [ "$status" -eq 2 ]
}

@test "usage error without a path" {
  run bash "$OA"
  [ "$status" -ne 0 ]
}
