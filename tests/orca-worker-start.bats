#!/usr/bin/env bats
# Tests for orca-worker-start.sh — Dispatch binding for an Orca worker.
# Worker mode must carry the guardrails escalation contract (which Orca's
# `worker-start --agent` cannot express); reuse mode must not re-create anything.

setup() {
  OWS="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/orca-worker-start.sh"
  OK_RECEIPT='{"ok":true,"result":{"runId":"run_1","taskId":"task_1","dispatchId":"ctx_abc","state":"ready","stage":"input_accepted","setup":{"state":"running"},"effects":[{"kind":"terminal","role":"agent","action":"created","id":"term_agent"},{"kind":"dispatch_input","role":"agent","id":"term_agent","state":"accepted"}]}}'
}

# --- worker mode (escalation contract active) ---------------------------------

@test "worker mode: creates the terminal with the escalation env + permission mode" {
  run env ORCA_WORKER_START_DRYRUN=1 GROUNDWORK_ESCALATION_DIR=/e GROUNDWORK_TASK_ID=lo-1 \
      bash "$OWS" --task task_1 --worktree "id:r::/wt" --agent claude
  [ "$status" -eq 0 ]
  [[ "$output" == *"[terminal] [create]"* ]]
  [[ "$output" == *"GROUNDWORK_ESCALATION_DIR='/e'"* ]]
  [[ "$output" == *"GROUNDWORK_TASK_ID='lo-1'"* ]]
  [[ "$output" == *"claude --permission-mode bypassPermissions"* ]]
  [[ "$output" == *"[terminal] [wait]"* ]]
  [[ "$output" == *"tui-idle"* ]]
}

@test "worker mode: binds the Dispatch to the terminal it created, not to --agent" {
  run env ORCA_WORKER_START_DRYRUN=1 GROUNDWORK_ESCALATION_DIR=/e \
      ORCA_WORKER_START_CREATE_JSON='{"result":{"terminal":{"handle":"term_new"}}}' \
      bash "$OWS" --task task_1 --worktree "id:r::/wt" --agent claude
  [ "$status" -eq 0 ]
  [[ "$output" == *"[orchestration] [worker-start]"* ]]
  [[ "$output" == *"[--terminal] [term_new]"* ]]
  [[ "$output" != *"[--agent]"* ]]
}

@test "worker mode: the bind names the worktree (else terminal_worktree_mismatch)" {
  run env ORCA_WORKER_START_DRYRUN=1 GROUNDWORK_ESCALATION_DIR=/e \
      ORCA_WORKER_START_CREATE_JSON='{"result":{"terminal":{"handle":"term_new"}}}' \
      bash "$OWS" --task task_1 --worktree "id:r::/wt" --agent claude
  [ "$status" -eq 0 ]
  [[ "$output" == *"[worker-start] [--task] [task_1] [--worktree] [id:r::/wt] [--terminal] [term_new]"* ]]
}

@test "reuse mode: a worktree given with --terminal is forwarded to the bind" {
  run env ORCA_WORKER_START_DRYRUN=1 bash "$OWS" \
      --task task_2 --terminal term_agent --worktree "id:r::/wt"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[--worktree] [id:r::/wt]"* ]]
  [[ "$output" == *"[--terminal] [term_agent]"* ]]
  [[ "$output" != *"[terminal] [create]"* ]]
}

@test "worker mode: honours an explicit --perm" {
  run env ORCA_WORKER_START_DRYRUN=1 GROUNDWORK_ESCALATION_DIR=/e \
      bash "$OWS" --task task_1 --worktree "id:r::/wt" --agent claude --perm acceptEdits
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude --permission-mode acceptEdits"* ]]
}

@test "worker mode: a single quote in the escalation dir is shell-escaped" {
  run env ORCA_WORKER_START_DRYRUN=1 GROUNDWORK_ESCALATION_DIR="/p'q" \
      bash "$OWS" --task task_1 --worktree "id:r::/wt" --agent claude
  [ "$status" -eq 0 ]
  [[ "$output" == *"/p'\\''q"* ]]
}

@test "worker mode: refuses new-* worktrees, which cannot carry the escalation env" {
  run env ORCA_WORKER_START_DRYRUN=1 GROUNDWORK_ESCALATION_DIR=/e \
      bash "$OWS" --task task_1 --worktree new-top-level --agent claude --name n
  [ "$status" -eq 2 ]
  [[ "$output" == *"GROUNDWORK_ESCALATION_DIR"* ]]
}

@test "worker mode: refuses a non-claude agent rather than dropping the contract" {
  run env ORCA_WORKER_START_DRYRUN=1 GROUNDWORK_ESCALATION_DIR=/e \
      bash "$OWS" --task task_1 --worktree "id:r::/wt" --agent codex
  [ "$status" -eq 2 ]
}

@test "worker mode: a terminal create with no handle fails (exit 5), no dispatch" {
  run env ORCA_WORKER_START_DRYRUN=1 GROUNDWORK_ESCALATION_DIR=/e \
      ORCA_WORKER_START_CREATE_JSON='{"result":{}}' \
      bash "$OWS" --task task_1 --worktree "id:r::/wt" --agent claude
  [ "$status" -eq 5 ]
  [[ "$output" != *"dispatch="* ]]
}

# --- composed agent-first mode (no escalation contract requested) -------------

@test "no escalation env: uses Orca's agent-first worker-start with --setup run" {
  run env ORCA_WORKER_START_DRYRUN=1 bash "$OWS" \
      --task task_1 --worktree new-top-level --agent claude --name probe
  [ "$status" -eq 0 ]
  [[ "$output" == *"[--worktree] [new-top-level]"* ]]
  [[ "$output" == *"[--agent] [claude]"* ]]
  [[ "$output" == *"[--name] [probe]"* ]]
  [[ "$output" == *"[--setup] [run]"* ]]
  [[ "$output" != *"[terminal] [create]"* ]]
}

@test "a guardrails worker worktree without the escalation env is refused, not downgraded" {
  wt="$BATS_TEST_TMPDIR/wt"; mkdir -p "$wt/.groundwork"
  printf '{}' > "$wt/.groundwork/guardrails.json"
  run env ORCA_WORKER_START_DRYRUN=1 bash "$OWS" \
      --task task_1 --worktree "id:r::$wt" --agent claude
  [ "$status" -eq 2 ]
  [[ "$output" == *"GROUNDWORK_ESCALATION_DIR"* ]]
}

@test "the same worktree WITH the escalation env takes the worker-mode path" {
  wt="$BATS_TEST_TMPDIR/wt2"; mkdir -p "$wt/.groundwork"
  printf '{}' > "$wt/.groundwork/guardrails.json"
  run env ORCA_WORKER_START_DRYRUN=1 GROUNDWORK_ESCALATION_DIR=/e bash "$OWS" \
      --task task_1 --worktree "id:r::$wt" --agent claude
  [ "$status" -eq 0 ]
  [[ "$output" == *"[terminal] [create]"* ]]
}

@test "a path: selector is also checked for the guardrails config" {
  wt="$BATS_TEST_TMPDIR/wt3"; mkdir -p "$wt/.groundwork"
  printf '{}' > "$wt/.groundwork/guardrails.json"
  run env ORCA_WORKER_START_DRYRUN=1 bash "$OWS" \
      --task task_1 --worktree "path:$wt" --agent claude
  [ "$status" -eq 2 ]
}

@test "a worktree with no guardrails config is not forced to carry the contract" {
  wt="$BATS_TEST_TMPDIR/plain"; mkdir -p "$wt"
  run env ORCA_WORKER_START_DRYRUN=1 bash "$OWS" \
      --task task_1 --worktree "id:r::$wt" --agent claude
  [ "$status" -eq 0 ]
  [[ "$output" == *"[--agent] [claude]"* ]]
}

@test "reuse mode is exempt: the env was injected when the terminal was created" {
  wt="$BATS_TEST_TMPDIR/wt4"; mkdir -p "$wt/.groundwork"
  printf '{}' > "$wt/.groundwork/guardrails.json"
  run env ORCA_WORKER_START_DRYRUN=1 bash "$OWS" \
      --task task_2 --worktree "id:r::$wt" --terminal term_agent
  [ "$status" -eq 0 ]
}

@test "no escalation env: an existing worktree does NOT rerun setup" {
  run env ORCA_WORKER_START_DRYRUN=1 bash "$OWS" \
      --task task_1 --worktree "id:r::/wt" --agent codex
  [ "$status" -eq 0 ]
  [[ "$output" != *"[--setup]"* ]]
}

# --- reuse mode ---------------------------------------------------------------

@test "reuse mode: passes --terminal only and creates nothing" {
  run env ORCA_WORKER_START_DRYRUN=1 GROUNDWORK_ESCALATION_DIR=/e \
      bash "$OWS" --task task_2 --terminal term_agent
  [ "$status" -eq 0 ]
  [[ "$output" == *"[--terminal] [term_agent]"* ]]
  [[ "$output" != *"[terminal] [create]"* ]]
  [[ "$output" != *"[--worktree]"* ]]
}

# --- receipt parsing ----------------------------------------------------------

@test "extracts dispatchId, the agent handle, state and setup from the receipt" {
  run env ORCA_WORKER_START_DRYRUN=1 ORCA_WORKER_START_JSON="$OK_RECEIPT" \
      bash "$OWS" --task task_1 --terminal term_x
  [ "$status" -eq 0 ]
  [[ "$output" == *"dispatch=ctx_abc"* ]]
  [[ "$output" == *"handle=term_agent"* ]]
  [[ "$output" == *"state=ready"* ]]
  [[ "$output" == *"setup=running"* ]]
}

@test "falls back to the bound handle when the receipt lists no agent effect" {
  run env ORCA_WORKER_START_DRYRUN=1 \
      ORCA_WORKER_START_JSON='{"ok":true,"result":{"dispatchId":"ctx_x","state":"ready","effects":[]}}' \
      bash "$OWS" --task task_2 --terminal term_old
  [ "$status" -eq 0 ]
  [[ "$output" == *"handle=term_old"* ]]
}

@test "receipt without a dispatchId fails (exit 3) rather than reporting success" {
  run env ORCA_WORKER_START_DRYRUN=1 \
      ORCA_WORKER_START_JSON='{"ok":true,"result":{"state":"ready","effects":[]}}' \
      bash "$OWS" --task task_1 --terminal term_a
  [ "$status" -eq 3 ]
}

@test "a failed start (ok:false) exits 4 and surfaces stage + residual resources" {
  run env ORCA_WORKER_START_DRYRUN=1 \
      ORCA_WORKER_START_JSON='{"ok":false,"result":{"state":"failed","stage":"terminal_create","residualResources":[{"kind":"worktree","id":"r::/wt"}]}}' \
      bash "$OWS" --task task_1 --terminal term_a
  [ "$status" -eq 4 ]
  [[ "$output" == *"terminal_create"* ]]
  [[ "$output" == *"r::/wt"* ]]
}

@test "malformed receipt fails closed (never a silent success)" {
  run env ORCA_WORKER_START_DRYRUN=1 ORCA_WORKER_START_JSON='not json at all' \
      bash "$OWS" --task task_1 --terminal term_a
  [ "$status" -ne 0 ]
  [[ "$output" != *"dispatch="* ]]
}

# --- usage / injection guards -------------------------------------------------

@test "missing --task is a usage error (boundary)" {
  run env ORCA_WORKER_START_DRYRUN=1 bash "$OWS" --worktree new-child --agent claude --name n
  [ "$status" -eq 1 ]
}

@test "no args at all is a usage error (boundary)" {
  run bash "$OWS"
  [ "$status" -eq 1 ]
}

@test "--terminal together with --agent is a usage error (ambiguous placement)" {
  run env ORCA_WORKER_START_DRYRUN=1 bash "$OWS" \
      --task task_1 --terminal term_a --agent claude
  [ "$status" -eq 1 ]
}

@test "neither --terminal nor --agent is a usage error (boundary)" {
  run env ORCA_WORKER_START_DRYRUN=1 bash "$OWS" --task task_1 --worktree "id:r::/wt"
  [ "$status" -eq 1 ]
}

@test "a new-* worktree without --name is a usage error" {
  run env ORCA_WORKER_START_DRYRUN=1 bash "$OWS" --task task_1 --worktree new-child --agent claude
  [ "$status" -eq 1 ]
}

@test "rejects an unsupported agent (injection guard)" {
  run env ORCA_WORKER_START_DRYRUN=1 bash "$OWS" \
      --task task_1 --worktree new-child --name n --agent "claude; rm -rf ~"
  [ "$status" -eq 2 ]
}

@test "rejects an invalid permission mode (injection guard)" {
  run env ORCA_WORKER_START_DRYRUN=1 GROUNDWORK_ESCALATION_DIR=/e bash "$OWS" \
      --task task_1 --worktree "id:r::/wt" --agent claude --perm "bad; rm -rf ~"
  [ "$status" -eq 2 ]
}
