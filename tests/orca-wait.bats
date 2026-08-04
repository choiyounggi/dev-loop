#!/usr/bin/env bats
# Tests for orca-wait.sh — the Orca-substrate replacement for the status-file
# poll: one blocking coordinator mailbox read, classified into watch-status.sh's
# exit-code contract. Verified against canned Deliveries (no live runtime).

setup() {
  OW="${BATS_TEST_DIRNAME}/../skills/orchestrate/scripts/orca-wait.sh"
}

done_msg() { # $1 = outcome, $2 = task id
  printf '{"result":{"count":1,"deliveryId":"delivery_1","messages":[{"id":"msg_1","type":"worker_done","from_handle":"term_a","subject":"s","body":"b","payload":"{\\"taskId\\":\\"%s\\",\\"dispatchId\\":\\"ctx_1\\",\\"outcome\\":\\"%s\\"}"}]}}' "$2" "$1"
}

@test "worker_done succeeded: exit 0, message surfaced, delivery acked" {
  run env ORCA_WAIT_DRYRUN=1 ORCA_WAIT_CHECK_JSON="$(done_msg succeeded task_1)" bash "$OW" 60000
  [ "$status" -eq 0 ]
  [[ "$output" == *"worker_done"* ]]
  [[ "$output" == *"task_1"* ]]
  [[ "$output" == *"ack delivery_1"* ]]
}

@test "worker_done failed: exit 3 and the delivery is NOT acked (coordinator decides)" {
  run env ORCA_WAIT_DRYRUN=1 ORCA_WAIT_CHECK_JSON="$(done_msg failed task_9)" bash "$OW" 60000
  [ "$status" -eq 3 ]
  [[ "$output" == *"task_9"* ]]
  [[ "$output" != *"ack delivery_1"* ]]
}

@test "escalation message: exit 5 and NOT acked (recurs by design until resolved)" {
  run env ORCA_WAIT_DRYRUN=1 \
      ORCA_WAIT_CHECK_JSON='{"result":{"count":1,"deliveryId":"delivery_2","messages":[{"id":"msg_e","type":"escalation","from_handle":"term_b","subject":"guardrails ask: sql_drop","body":"blocked"}]}}' \
      bash "$OW" 60000
  [ "$status" -eq 5 ]
  [[ "$output" == *"sql_drop"* ]]
  [[ "$output" != *"ack delivery_2"* ]]
}

@test "question: exit 6 and the reply command carries the exact message id" {
  run env ORCA_WAIT_DRYRUN=1 \
      ORCA_WAIT_CHECK_JSON='{"result":{"count":1,"deliveryId":"delivery_3","messages":[{"id":"msg_q7","type":"question","from_handle":"term_c","subject":"Question","body":"which base branch?"}]}}' \
      bash "$OW" 60000
  [ "$status" -eq 6 ]
  [[ "$output" == *"msg_q7"* ]]
  [[ "$output" == *"reply"* ]]
  [[ "$output" != *"ack delivery_3"* ]]
}

@test "escalation wins over a worker_done in the same Delivery (nothing acked)" {
  run env ORCA_WAIT_DRYRUN=1 \
      ORCA_WAIT_CHECK_JSON='{"result":{"count":2,"deliveryId":"delivery_4","messages":[{"id":"m1","type":"worker_done","subject":"ok","payload":"{\"outcome\":\"succeeded\"}"},{"id":"m2","type":"escalation","subject":"needs approval"}]}}' \
      bash "$OW" 60000
  [ "$status" -eq 5 ]
  [[ "$output" != *"ack delivery_4"* ]]
}

@test "empty window: exit 2 as a checkpoint, never a false completion (boundary)" {
  run env ORCA_WAIT_DRYRUN=1 ORCA_WAIT_CHECK_JSON='{"result":{"count":0,"messages":[]}}' bash "$OW" 1000
  [ "$status" -eq 2 ]
  [[ "$output" != *"ack"* ]]
}

@test "malformed check output fails to the checkpoint code, not to success" {
  run env ORCA_WAIT_DRYRUN=1 ORCA_WAIT_CHECK_JSON='}{ not json' bash "$OW" 1000
  [ "$status" -eq 2 ]
}

@test "a payload delivered as an object (not a JSON string) is still classified" {
  run env ORCA_WAIT_DRYRUN=1 \
      ORCA_WAIT_CHECK_JSON='{"result":{"count":1,"deliveryId":"d5","messages":[{"id":"m","type":"worker_done","subject":"s","payload":{"outcome":"failed","taskId":"task_o"}}]}}' \
      bash "$OW" 60000
  [ "$status" -eq 3 ]
  [[ "$output" == *"task_o"* ]]
}

@test "a worker_done with no payload is treated as unproven, not as success" {
  run env ORCA_WAIT_DRYRUN=1 \
      ORCA_WAIT_CHECK_JSON='{"result":{"count":1,"deliveryId":"d6","messages":[{"id":"m","type":"worker_done","subject":"no payload"}]}}' \
      bash "$OW" 60000
  [ "$status" -eq 3 ]
}

# --- ack is part of the exit-0 contract ---------------------------------------

@test "an ack that does not land reports the checkpoint code, not success" {
  run env ORCA_WAIT_DRYRUN=1 ORCA_WAIT_ACK_FAIL=1 \
      ORCA_WAIT_CHECK_JSON="$(done_msg succeeded task_1)" bash "$OW" 60000
  [ "$status" -eq 2 ]
  [[ "$output" != *"ack delivery_1"* ]]
}

@test "a failed ack never prints a progress line (nothing was consumed)" {
  run env ORCA_WAIT_DRYRUN=1 ORCA_WAIT_ACK_FAIL=1 \
      ORCA_WAIT_CHECK_JSON="$(done_msg succeeded task_1)" \
      ORCA_WAIT_TASKLIST_JSON='{"result":{"tasks":[{"id":"task_1","status":"completed"}]}}' \
      bash "$OW" 60000 task_1,task_2
  [ "$status" -eq 2 ]
  [[ "$output" != *"completed="* ]]
}

# --- progress is scoped to this Wave's task ids -------------------------------

@test "progress counts only the task ids passed in" {
  run env ORCA_WAIT_DRYRUN=1 ORCA_WAIT_CHECK_JSON="$(done_msg succeeded task_1)" \
      ORCA_WAIT_TASKLIST_JSON='{"result":{"tasks":[{"id":"task_1","status":"completed"},{"id":"task_2","status":"completed"}]}}' \
      bash "$OW" 60000 task_1,task_3
  [ "$status" -eq 0 ]
  [[ "$output" == *"completed=1/2"* ]]
}

@test "an earlier Wave's completed tasks do not inflate this Wave's progress" {
  run env ORCA_WAIT_DRYRUN=1 ORCA_WAIT_CHECK_JSON="$(done_msg succeeded task_w2a)" \
      ORCA_WAIT_TASKLIST_JSON='{"result":{"tasks":[{"id":"task_w1a","status":"completed"},{"id":"task_w1b","status":"completed"}]}}' \
      bash "$OW" 60000 task_w2a,task_w2b
  [ "$status" -eq 0 ]
  [[ "$output" == *"completed=0/2"* ]]
}

@test "a task id that is a PREFIX of a wanted id does not count (exact match only)" {
  run env ORCA_WAIT_DRYRUN=1 ORCA_WAIT_CHECK_JSON="$(done_msg succeeded task_12)" \
      ORCA_WAIT_TASKLIST_JSON='{"result":{"tasks":[{"id":"task_1","status":"completed"}]}}' \
      bash "$OW" 60000 task_12,task_13
  [ "$status" -eq 0 ]
  [[ "$output" == *"completed=0/2"* ]]
}

@test "rejects a malformed task id list (injection guard)" {
  run env ORCA_WAIT_DRYRUN=1 bash "$OW" 60000 "task_1; rm -rf ~"
  [ "$status" -eq 1 ]
}

# --- guardrails escalation files are checked before blocking -------------------

@test "a pending guardrails escalation file exits 5 without blocking on the mailbox" {
  esc="$BATS_TEST_TMPDIR/esc"; mkdir -p "$esc"
  printf '{"taskId":"lo-2","rule":"sql_drop","reason":"blocked"}' > "$esc/1.json"
  run env ORCA_WAIT_DRYRUN=1 GROUNDWORK_ESCALATION_DIR="$esc" \
      ORCA_WAIT_CHECK_JSON="$(done_msg succeeded task_1)" bash "$OW" 60000
  [ "$status" -eq 5 ]
  [[ "$output" == *"lo-2:sql_drop"* ]]
  [[ "$output" != *"ack"* ]]
}

@test "an empty escalation dir does not false-trigger (boundary)" {
  esc="$BATS_TEST_TMPDIR/esc-empty"; mkdir -p "$esc"
  run env ORCA_WAIT_DRYRUN=1 GROUNDWORK_ESCALATION_DIR="$esc" \
      ORCA_WAIT_CHECK_JSON="$(done_msg succeeded task_1)" bash "$OW" 60000
  [ "$status" -eq 0 ]
  [[ "$output" == *"ack delivery_1"* ]]
}

@test "a non-existent escalation dir is simply not wired (no crash)" {
  run env ORCA_WAIT_DRYRUN=1 GROUNDWORK_ESCALATION_DIR="$BATS_TEST_TMPDIR/nope" \
      ORCA_WAIT_CHECK_JSON="$(done_msg succeeded task_1)" bash "$OW" 60000
  [ "$status" -eq 0 ]
}

@test "rejects a non-numeric timeout (boundary)" {
  run env ORCA_WAIT_DRYRUN=1 bash "$OW" "60000; rm -rf ~"
  [ "$status" -eq 1 ]
}
