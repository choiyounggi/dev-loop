#!/usr/bin/env bats
# Tests for orca-worker-stalled.sh — the third worker state the alive/dead split
# cannot express. Driven entirely by canned `worktree ps` payloads plus a pinned
# clock, so no live Orca runtime is involved.
#
# The script is `#!/bin/sh`; invoke it with `sh`, not `bash`, or the shebang is
# overridden and a bashism would pass every test here while failing under dash in
# production.

setup() {
  WS="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/orca-worker-stalled.sh"
  WT=/repo/wt
  NOW=1700000000000
}

ps_json() { # $1 = agent updatedAt, $2 = liveTerminalCount, $3 = agent state (optional)
  printf '{"result":{"worktrees":[{"path":"%s","liveTerminalCount":%s,"hasAttachedPty":true,"lastOutputAt":%s,"agents":[{"state":"%s","updatedAt":%s}]}]}}' \
    "$WT" "$2" "$NOW" "${3:-working}" "$1"
}

@test "recent output is progressing (exit 0)" {
  run env ORCA_WORKTREE_PS_JSON="$(ps_json $((NOW - 1000)) 1)" ORCA_STALL_NOW_MS="$NOW" \
      sh "$WS" "$WT"
  [ "$status" -eq 0 ]
}

@test "silence past the threshold is a stall (exit 1) and names the worktree" {
  run env ORCA_WORKTREE_PS_JSON="$(ps_json $((NOW - 900000)) 1)" ORCA_STALL_NOW_MS="$NOW" \
      sh "$WS" "$WT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[stalled]"* ]]
  [[ "$output" == *"$WT"* ]]
  [[ "$output" == *"900s"* ]]
}

@test "the agent state is reported as context on a stall" {
  run env ORCA_WORKTREE_PS_JSON="$(ps_json $((NOW - 900000)) 1 done)" ORCA_STALL_NOW_MS="$NOW" \
      sh "$WS" "$WT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"agent state: done"* ]]
}

@test "exactly at the threshold counts as stalled (boundary)" {
  run env ORCA_WORKTREE_PS_JSON="$(ps_json $((NOW - 600000)) 1)" ORCA_STALL_NOW_MS="$NOW" \
      sh "$WS" "$WT"
  [ "$status" -eq 1 ]
}

@test "one millisecond under the threshold is not stalled (boundary)" {
  run env ORCA_WORKTREE_PS_JSON="$(ps_json $((NOW - 599999)) 1)" ORCA_STALL_NOW_MS="$NOW" \
      sh "$WS" "$WT"
  [ "$status" -eq 0 ]
}

@test "ORCA_STALL_MS overrides the threshold" {
  run env ORCA_WORKTREE_PS_JSON="$(ps_json $((NOW - 30000)) 1)" ORCA_STALL_NOW_MS="$NOW" \
      ORCA_STALL_MS=10000 sh "$WS" "$WT"
  [ "$status" -eq 1 ]
}

@test "no live terminal is NOT reported as a stall — that is the alive/dead question" {
  run env ORCA_WORKTREE_PS_JSON='{"result":{"worktrees":[{"path":"/repo/wt","liveTerminalCount":0,"hasAttachedPty":false,"agents":[{"state":"x","updatedAt":1}]}]}}' \
      ORCA_STALL_NOW_MS="$NOW" sh "$WS" "$WT"
  [ "$status" -eq 0 ]
}

@test "an untracked worktree is unknown, never 'healthy' (exit 2)" {
  run env ORCA_WORKTREE_PS_JSON='{"result":{"worktrees":[{"path":"/other","liveTerminalCount":1,"hasAttachedPty":true,"agents":[{"state":"x","updatedAt":1}]}]}}' \
      ORCA_STALL_NOW_MS="$NOW" sh "$WS" "$WT"
  [ "$status" -eq 2 ]
}

@test "no agents array at all is unknown, not stalled (exit 2)" {
  run env ORCA_WORKTREE_PS_JSON='{"result":{"worktrees":[{"path":"/repo/wt","liveTerminalCount":1,"hasAttachedPty":true,"lastOutputAt":1}]}}' \
      ORCA_STALL_NOW_MS="$NOW" sh "$WS" "$WT"
  [ "$status" -eq 2 ]
}

@test "malformed payload is unknown, not stalled (exit 2)" {
  run env ORCA_WORKTREE_PS_JSON='not json at all' ORCA_STALL_NOW_MS="$NOW" sh "$WS" "$WT"
  [ "$status" -eq 2 ]
}

@test "an empty payload is unknown (boundary)" {
  run env ORCA_WORKTREE_PS_JSON=' ' ORCA_STALL_NOW_MS="$NOW" sh "$WS" "$WT"
  [ "$status" -eq 2 ]
}

@test "a sub-second future timestamp is precision, not skew — still progressing" {
  run env ORCA_WORKTREE_PS_JSON="$(ps_json $((NOW + 800)) 1)" ORCA_STALL_NOW_MS="$NOW" \
      sh "$WS" "$WT"
  [ "$status" -eq 0 ]
}

@test "a far-future timestamp is real clock skew, not a stall (exit 2)" {
  run env ORCA_WORKTREE_PS_JSON="$(ps_json $((NOW + 60000)) 1)" ORCA_STALL_NOW_MS="$NOW" \
      sh "$WS" "$WT"
  [ "$status" -eq 2 ]
}

@test "terminal repaint does not mask an idle agent (the lastOutputAt trap)" {
  # lastOutputAt is fresh (a TUI spinner), the agent has not moved in 15 min.
  run env ORCA_WORKTREE_PS_JSON="$(ps_json $((NOW - 900000)) 1)" ORCA_STALL_NOW_MS="$NOW" \
      sh "$WS" "$WT"
  [ "$status" -eq 1 ]
}

@test "a non-numeric threshold is refused rather than silently defaulted (error)" {
  run env ORCA_WORKTREE_PS_JSON="$(ps_json $((NOW - 900000)) 1)" ORCA_STALL_NOW_MS="$NOW" \
      ORCA_STALL_MS=abc sh "$WS" "$WT"
  [ "$status" -eq 2 ]
}

@test "a zero threshold is refused (boundary — it would flag every worker)" {
  run env ORCA_WORKTREE_PS_JSON="$(ps_json $NOW 1)" ORCA_STALL_NOW_MS="$NOW" \
      ORCA_STALL_MS=0 sh "$WS" "$WT"
  [ "$status" -eq 2 ]
}

@test "a missing worktree argument is a usage error" {
  run sh "$WS"
  [ "$status" -eq 2 ]
  [[ "$output" == *"usage"* ]]
}
