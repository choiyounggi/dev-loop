#!/usr/bin/env bats
# Tests for orca-spawn.sh — the Orca-substrate worker launch (command
# construction + handle extraction, verified without a live spawn).

setup() {
  OS="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/orca-spawn.sh"
}

@test "dry-run: builds terminal create (escalation env + claude + perm), wait, send" {
  run env ORCA_SPAWN_DRYRUN=1 GROUNDWORK_ESCALATION_DIR=/e GROUNDWORK_TASK_ID=lo-1 \
      bash "$OS" "repo1::/wt" bypassPermissions "do the task"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[terminal] [create]"* ]]
  [[ "$output" == *"[id:repo1::/wt]"* ]]
  [[ "$output" == *"GROUNDWORK_ESCALATION_DIR='/e'"* ]]
  [[ "$output" == *"claude --permission-mode bypassPermissions"* ]]
  [[ "$output" == *"[terminal] [wait]"* ]]
  [[ "$output" == *"tui-idle"* ]]
  [[ "$output" == *"[terminal] [send]"* ]]
  [[ "$output" == *"[do the task]"* ]]
  [[ "$output" == *"handle=term_DRYRUN"* ]]
}

@test "extracts the agent handle from terminal create's .result.terminal.handle (verified live)" {
  run env ORCA_SPAWN_DRYRUN=1 \
      ORCA_SPAWN_CREATE_JSON='{"result":{"terminal":{"handle":"term_live"}}}' \
      bash "$OS" "r::/wt" bypassPermissions "p"
  [ "$status" -eq 0 ]
  [[ "$output" == *"handle=term_live"* ]]
  [[ "$output" == *"[--terminal] [term_live]"* ]]
}

@test "extracts the agent handle from startupTerminal.handle and targets it" {
  run env ORCA_SPAWN_DRYRUN=1 \
      ORCA_SPAWN_CREATE_JSON='{"result":{"startupTerminal":{"handle":"term_abc"}}}' \
      bash "$OS" "r::/wt" bypassPermissions "p"
  [ "$status" -eq 0 ]
  [[ "$output" == *"handle=term_abc"* ]]
  [[ "$output" == *"[--terminal] [term_abc]"* ]]
}

@test "falls back to .result.handle when startupTerminal is absent" {
  run env ORCA_SPAWN_DRYRUN=1 ORCA_SPAWN_CREATE_JSON='{"result":{"handle":"term_xyz"}}' \
      bash "$OS" "r::/wt" bypassPermissions "p"
  [ "$status" -eq 0 ]
  [[ "$output" == *"handle=term_xyz"* ]]
}

@test "errors (exit 3) when create returns no handle" {
  run env ORCA_SPAWN_DRYRUN=1 ORCA_SPAWN_CREATE_JSON='{"result":{}}' \
      bash "$OS" "r::/wt" bypassPermissions "p"
  [ "$status" -eq 3 ]
}

@test "rejects an invalid permission mode (injection guard)" {
  run env ORCA_SPAWN_DRYRUN=1 bash "$OS" "r::/wt" "bad; rm -rf ~" "p"
  [ "$status" -eq 2 ]
}

@test "usage error without args (boundary)" {
  run bash "$OS"
  [ "$status" -ne 0 ]
}

@test "single quote in the escalation dir is shell-escaped (no command break)" {
  run env ORCA_SPAWN_DRYRUN=1 GROUNDWORK_ESCALATION_DIR="/p'q" GROUNDWORK_TASK_ID=lo-1 \
      bash "$OS" "r::/wt" bypassPermissions "p"
  [ "$status" -eq 0 ]
  # the POSIX single-quote escape '\'' must appear — proves the value was escaped
  [[ "$output" == *"/p'\\''q"* ]]
}

# --- worker model pin (DEV_LOOP_WORKER_MODEL) ---------------------------------
# orca-spawn takes positional args only, so the model arrives by env — the same
# variable orca-worker-start.sh and launch-session.sh read.

@test "model: DEV_LOOP_WORKER_MODEL reaches the claude command" {
  run env ORCA_SPAWN_DRYRUN=1 DEV_LOOP_WORKER_MODEL=claude-sonnet-5 \
      bash "$OS" "r::/wt" bypassPermissions "p"
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude --permission-mode bypassPermissions --model 'claude-sonnet-5'"* ]]
}

@test "model: unset adds no --model flag (boundary — unchanged behavior)" {
  run env ORCA_SPAWN_DRYRUN=1 bash "$OS" "r::/wt" bypassPermissions "p"
  [ "$status" -eq 0 ]
  [[ "$output" != *"--model"* ]]
}

@test "model: a shell-metacharacter model is rejected, nothing is created" {
  run env ORCA_SPAWN_DRYRUN=1 DEV_LOOP_WORKER_MODEL='x; rm -rf ~' \
      bash "$OS" "r::/wt" bypassPermissions "p"
  [ "$status" -eq 2 ]
  [[ "$output" == *"invalid model"* ]]
  [[ "$output" != *"[terminal] [create]"* ]]
}
