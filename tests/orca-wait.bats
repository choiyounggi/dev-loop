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

# --- the `orca` CLI test double ------------------------------------------------
# Multi-window and multi-batch behavior cannot be observed through a single canned
# JSON string, so these tests replace the one boundary they do not own — the `orca`
# process — via the existing ORCA_BIN hook, and keep the script, jq and the real
# ack path real. Assertions below are always on what orca-wait.sh *did* (exit code,
# stdout, which deliveries it acked, how many windows it opened), never on the
# stub's canned bytes.
#
# The executable lives under the repo's gitignored .claude/tmp — never $TMPDIR or
# /tmp, where creating and chmod +x-ing an executable is forbidden by policy.
# Non-executable fixture data keeps using $BATS_TEST_TMPDIR, as the tests above do.
REPO_TMP() { printf '%s' "${BATS_TEST_DIRNAME}/../.claude/tmp"; }

mk_stub() { # -> path of an executable `orca` test double
  mkdir -p "$(REPO_TMP)"
  local stub="$(REPO_TMP)/orca-stub-${BATS_TEST_NUMBER}"
  cat > "$stub" <<'STUBEOF'
#!/bin/sh
# Test double for the `orca` CLI. All state under $STUB_DIR:
#   rc-fail            if present, every `check --wait` prints this file and exits 1
#   calls              window counter for `check --wait`
#   windows            the --timeout-ms value of each window, one per line
#   <n>.json           canned Delivery returned by the nth window (absent -> empty)
#   esc-at             window number during which an escalation record is written
#   tasklist-<n>.json  `task-list` output after the nth window (falls back to tasklist.json)
#   acked              one delivery id per successful ack, in order
#   ack-fail           if present, every ack fails
set -u
d="${STUB_DIR:?}"
case "${2:-}" in
  check)
    case "${3:-}" in
      --wait)
        n=$(cat "$d/calls" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > "$d/calls"
        prev=""; for a in "$@"; do
          if [ "$prev" = "--timeout-ms" ]; then echo "$a" >> "$d/windows"; fi
          prev="$a"
        done
        if [ -f "$d/esc-at" ] && [ "$(cat "$d/esc-at")" = "$n" ]; then
          printf '{"taskId":"%s","rule":"%s","reason":"blocked"}' \
            "${STUB_ESC_TASK:-t_esc}" "${STUB_ESC_RULE:-sql_drop}" > "${STUB_ESC_DIR:?}/esc-$n.json"
        fi
        if [ -f "$d/rc-fail" ]; then cat "$d/rc-fail"; exit 1; fi
        if [ -f "$d/$n.json" ]; then cat "$d/$n.json"
        else echo '{"result":{"count":0,"messages":[]}}'; fi ;;
      --ack)
        if [ -f "$d/ack-fail" ]; then exit 1; fi
        echo "${4:-}" >> "$d/acked"; echo '{"ok":true}' ;;
      *) exit 1 ;;
    esac ;;
  task-list)
    n=$(cat "$d/calls" 2>/dev/null || echo 0)
    if [ -f "$d/tasklist-$n.json" ]; then cat "$d/tasklist-$n.json"
    elif [ -f "$d/tasklist.json" ]; then cat "$d/tasklist.json"
    else echo '{"result":{"tasks":[]}}'; fi ;;
  *) exit 1 ;;
esac
STUBEOF
  chmod +x "$stub"
  printf '%s' "$stub"
}

teardown() { rm -f "$(REPO_TMP)/orca-stub-${BATS_TEST_NUMBER}"; }

@test "the orca test double drives the real check/ack/task-list path (no dry-run)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  printf '%s' "$(done_msg succeeded task_1)" > "$sd/1.json"
  printf '{"result":{"tasks":[{"id":"task_1","status":"completed"}]}}' > "$sd/tasklist.json"
  run env STUB_DIR="$sd" ORCA_BIN="$(mk_stub)" bash "$OW" 60000 task_1
  [ "$status" -eq 0 ]
  [[ "$output" == *"ack delivery_1"* ]]
  [[ "$output" == *"completed=1/1"* ]]
  [ "$(cat "$sd/acked")" = "delivery_1" ]
  [ "$(cat "$sd/calls")" = "1" ]
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

# --- a dead runtime is exit 4, never a quiet window ----------------------------
# Measured against the live CLI: an ordinary timeout answers ok:true / count 0 /
# timedOut:true with status 0, and a runtime fault answers ok:false with status 1.
# Before this split, every one of these read as "no message yet".

@test "the real timeout envelope is still a checkpoint, not an outage (regression)" {
  run env ORCA_WAIT_DRYRUN=1 \
      ORCA_WAIT_CHECK_JSON='{"ok":true,"result":{"runId":"run_1","deliveryId":null,"messages":[],"count":0,"timedOut":true,"connectionLost":false}}' \
      bash "$OW" 1000
  [ "$status" -eq 2 ]
  [[ "$output" == *"checkpoint"* ]]
}

@test "an ok:false runtime error exits 4 and names the error code" {
  run env ORCA_WAIT_DRYRUN=1 ORCA_WAIT_CHECK_RC=1 \
      ORCA_WAIT_CHECK_JSON='{"ok":false,"error":{"code":"runtime_unavailable","message":"The Orca runtime closed the connection before responding."}}' \
      bash "$OW" 60000
  [ "$status" -eq 4 ]
  [[ "$output" == *"runtime_unavailable"* ]]
  [[ "$output" != *"checkpoint"* ]]
}

# An empty ORCA_WAIT_CHECK_JSON cannot express this case — it deselects the canned
# branch — so a killed CLI is only observable through the real orca path.
@test "a killed CLI (no output at all, nonzero status) exits 4, not 2 (error path)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  : > "$sd/rc-fail"
  run env STUB_DIR="$sd" ORCA_BIN="$(mk_stub)" bash "$OW" 60000
  [ "$status" -eq 4 ]
  [[ "$output" == *"no response"* ]]
  [ ! -f "$sd/acked" ]
}

@test "connectionLost mid-wait exits 4 even though ok:true and count 0 (boundary)" {
  run env ORCA_WAIT_DRYRUN=1 \
      ORCA_WAIT_CHECK_JSON='{"ok":true,"result":{"count":0,"messages":[],"timedOut":false,"connectionLost":true}}' \
      bash "$OW" 60000
  [ "$status" -eq 4 ]
  [[ "$output" == *"connection_lost"* ]]
}

@test "a nonzero check through the live orca path exits 4 without acking anything" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  printf '{"ok":false,"error":{"code":"runtime_timeout","message":"Timed out waiting for the Orca runtime."}}' > "$sd/rc-fail"
  run env STUB_DIR="$sd" ORCA_BIN="$(mk_stub)" bash "$OW" 60000 task_1
  [ "$status" -eq 4 ]
  [[ "$output" == *"runtime_timeout"* ]]
  [ ! -f "$sd/acked" ]
  [ "$(cat "$sd/calls")" = "1" ]
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

# --- --until-all consumes batches until the whole Wave is completed -------------

@test "--until-all consumes successive batches and exits 0 once when all are completed" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  printf '%s' "$(done_msg succeeded task_a)" > "$sd/1.json"
  printf '%s' "$(done_msg succeeded task_b)" | sed 's/delivery_1/delivery_2/' > "$sd/2.json"
  printf '{"result":{"tasks":[{"id":"task_a","status":"completed"}]}}' > "$sd/tasklist-1.json"
  printf '{"result":{"tasks":[{"id":"task_a","status":"completed"},{"id":"task_b","status":"completed"}]}}' > "$sd/tasklist-2.json"
  run env STUB_DIR="$sd" ORCA_BIN="$(mk_stub)" bash "$OW" --until-all 60000 task_a,task_b
  [ "$status" -eq 0 ]
  [[ "$output" == *"completed=1/2"* ]]   # the first batch did NOT end the call
  [[ "$output" == *"completed=2/2"* ]]
  [ "$(cat "$sd/calls")" = "2" ]
  [ "$(tr '\n' ',' < "$sd/acked")" = "delivery_1,delivery_2," ]
}

@test "--until-all without a task id list is a usage error" {
  run env ORCA_WAIT_DRYRUN=1 bash "$OW" --until-all 60000
  [ "$status" -eq 1 ]
  [[ "$output" == *"needs the task id list"* ]]
}

@test "an unknown flag is rejected before any window is opened (not read as the timeout)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  run env STUB_DIR="$sd" ORCA_BIN="$(mk_stub)" bash "$OW" --bogus 60000 task_a
  [ "$status" -eq 1 ]
  [[ "$output" == *"usage:"* ]]
  [ ! -f "$sd/calls" ]
}

@test "--until-all that does not complete inside the budget checkpoints at exit 2" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  printf '%s' "$(done_msg succeeded task_a)" > "$sd/1.json"
  printf '{"result":{"tasks":[{"id":"task_a","status":"completed"}]}}' > "$sd/tasklist.json"
  run env STUB_DIR="$sd" ORCA_BIN="$(mk_stub)" ORCA_WAIT_RECHECK_MS=1000 \
      bash "$OW" --until-all 2000 task_a,task_b
  [ "$status" -eq 2 ]
  [[ "$output" == *"completed=1/2"* ]]
  [ "$(cat "$sd/acked")" = "delivery_1" ]   # the consumed batch stays consumed
  [ "$(cat "$sd/calls")" = "2" ]
}

# --- --until-all still stops dead on anything needing a coordinator decision ----
# Batch 1 is a real completion (acked); batch 2 needs a decision and must be left
# unread so it replays. Asserting the ack log, not just the exit code, is the
# point: an implementation that acked the batch and then exited would still return
# the right code while silently dropping the event.

_until_all_two_batches() { # $1 = JSON for batch 2 -> echoes the state dir
  local sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  printf '%s' "$(done_msg succeeded task_a)" > "$sd/1.json"
  printf '%s' "$1" > "$sd/2.json"
  printf '{"result":{"tasks":[{"id":"task_a","status":"completed"}]}}' > "$sd/tasklist.json"
  printf '%s' "$sd"
}

@test "--until-all returns 3 immediately on a failed worker and does not ack that batch" {
  sd="$(_until_all_two_batches "$(done_msg failed task_b | sed 's/delivery_1/delivery_2/')")"
  run env STUB_DIR="$sd" ORCA_BIN="$(mk_stub)" bash "$OW" --until-all 60000 task_a,task_b
  [ "$status" -eq 3 ]
  [[ "$output" == *"task_b"* ]]
  [[ "$(cat "$sd/acked")" == *"delivery_1"* ]]
  [[ "$(cat "$sd/acked")" != *"delivery_2"* ]]
}

@test "--until-all returns 5 immediately on an escalation and does not ack that batch" {
  sd="$(_until_all_two_batches '{"result":{"count":1,"deliveryId":"delivery_2","messages":[{"id":"m_e","type":"escalation","from_handle":"term_b","subject":"guardrails ask: rm_rf"}]}}')"
  run env STUB_DIR="$sd" ORCA_BIN="$(mk_stub)" bash "$OW" --until-all 60000 task_a,task_b
  [ "$status" -eq 5 ]
  [[ "$output" == *"rm_rf"* ]]
  [[ "$(cat "$sd/acked")" == *"delivery_1"* ]]
  [[ "$(cat "$sd/acked")" != *"delivery_2"* ]]
}

@test "--until-all returns 6 immediately on a question and does not ack that batch" {
  sd="$(_until_all_two_batches '{"result":{"count":1,"deliveryId":"delivery_2","messages":[{"id":"msg_q9","type":"question","from_handle":"term_c","subject":"which base branch?"}]}}')"
  run env STUB_DIR="$sd" ORCA_BIN="$(mk_stub)" bash "$OW" --until-all 60000 task_a,task_b
  [ "$status" -eq 6 ]
  [[ "$output" == *"msg_q9"* ]]
  [[ "$output" == *"reply"* ]]
  [[ "$(cat "$sd/acked")" == *"delivery_1"* ]]
  [[ "$(cat "$sd/acked")" != *"delivery_2"* ]]
}

# --- the escalation dir is re-checked between blocking windows ------------------

@test "an escalation written AFTER the wait started surfaces within one interval" {
  sd="$BATS_TEST_TMPDIR/sd"; esc="$BATS_TEST_TMPDIR/esc"; mkdir -p "$sd" "$esc"
  echo 1 > "$sd/esc-at"   # guardrails writes the record while window 1 is blocked
  run env STUB_DIR="$sd" STUB_ESC_DIR="$esc" STUB_ESC_TASK=lo-7 STUB_ESC_RULE=sql_drop \
      GROUNDWORK_ESCALATION_DIR="$esc" ORCA_BIN="$(mk_stub)" ORCA_WAIT_RECHECK_MS=1000 \
      bash "$OW" 10000
  [ "$status" -eq 5 ]
  [[ "$output" == *"lo-7:sql_drop"* ]]
  [[ "$output" != *"ack"* ]]
  # detected after ONE window, not after burning the whole 10-window budget
  [ "$(cat "$sd/calls")" = "1" ]
}

@test "the re-check loop consumes exactly the caller's budget, no more, no less" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  run env STUB_DIR="$sd" ORCA_BIN="$(mk_stub)" ORCA_WAIT_RECHECK_MS=500 bash "$OW" 2000
  [ "$status" -eq 2 ]
  [ "$(cat "$sd/calls")" = "4" ]
  # the windows sum to exactly the caller's 2000ms — not extended, not truncated
  [ "$(tr '\n' ',' < "$sd/windows")" = "500,500,500,500," ]
  [[ "$output" == *"no message in 2000ms"* ]]
}

@test "a re-check interval larger than the timeout yields exactly one clamped window" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  run env STUB_DIR="$sd" ORCA_BIN="$(mk_stub)" ORCA_WAIT_RECHECK_MS=15000 bash "$OW" 1000
  [ "$status" -eq 2 ]
  [ "$(cat "$sd/calls")" = "1" ]
  # clamped to the remaining budget: the caller asked for 1000ms, not 15000ms
  [ "$(tr '\n' ',' < "$sd/windows")" = "1000," ]
}

@test "a zero timeout opens no window at all (boundary)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  run env STUB_DIR="$sd" ORCA_BIN="$(mk_stub)" bash "$OW" 0
  [ "$status" -eq 2 ]
  [ ! -f "$sd/calls" ]
}

@test "rejects a non-numeric or zero re-check interval (boundary)" {
  run env ORCA_WAIT_DRYRUN=1 ORCA_WAIT_RECHECK_MS=abc bash "$OW" 60000
  [ "$status" -eq 1 ]
  [[ "$output" == *"ORCA_WAIT_RECHECK_MS"* ]]
  run env ORCA_WAIT_DRYRUN=1 ORCA_WAIT_RECHECK_MS=00 bash "$OW" 60000
  [ "$status" -eq 1 ]
  [[ "$output" == *"ORCA_WAIT_RECHECK_MS"* ]]
}

# --- a batch that carried no worker_done is not a completion --------------------
# Heartbeats are delivered even though --types asks only for worker_done/escalation/
# question (observed live). Exit 0 means "completions arrived — process them", so a
# liveness-only batch must not report it, or the coordinator collects artifacts that
# were never produced.

hb_only() { # $1 = delivery id
  printf '{"result":{"count":2,"deliveryId":"%s","messages":[{"type":"heartbeat","id":"m1","from_handle":"term_x","payload":"{\\"taskId\\":\\"task_1\\"}","subject":"alive"},{"type":"heartbeat","id":"m2","from_handle":"term_y","payload":"{\\"taskId\\":\\"task_2\\"}","subject":"alive"}]}}' "$1"
}

@test "a heartbeat-only batch is consumed but never reported as a completion" {
  run env ORCA_WAIT_DRYRUN=1 ORCA_WAIT_CHECK_JSON="$(hb_only delivery_hb)" \
      ORCA_WAIT_TASKLIST_JSON='{"result":{"tasks":[]}}' \
      bash "$OW" 1000 task_1,task_2
  [ "$status" -eq 2 ]
  [[ "$output" == *"ack delivery_hb"* ]]   # consumed: replaying liveness would livelock
  [[ "$output" != *"completed="* ]]        # and never counted as Wave progress
}

@test "a heartbeat mixed with a real worker_done still completes normally (no regression)" {
  mix='{"result":{"count":2,"deliveryId":"delivery_mix","messages":[{"type":"heartbeat","id":"m1","from_handle":"term_x","payload":"{\"taskId\":\"task_2\"}","subject":"alive"},{"id":"msg_1","type":"worker_done","from_handle":"term_a","subject":"s","payload":"{\"taskId\":\"task_1\",\"outcome\":\"succeeded\"}"}]}}'
  run env ORCA_WAIT_DRYRUN=1 ORCA_WAIT_CHECK_JSON="$mix" \
      ORCA_WAIT_TASKLIST_JSON='{"result":{"tasks":[{"id":"task_1","status":"completed"}]}}' \
      bash "$OW" 60000 task_1,task_2
  [ "$status" -eq 0 ]
  [[ "$output" == *"ack delivery_mix"* ]]
  [[ "$output" == *"completed=1/2"* ]]
}

@test "--until-all keeps waiting through a heartbeat-only batch (boundary)" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  printf '%s' "$(hb_only delivery_hb)" > "$sd/1.json"
  printf '%s' "$(done_msg succeeded task_a)" | sed 's/delivery_1/delivery_2/' > "$sd/2.json"
  printf '{"result":{"tasks":[{"id":"task_a","status":"completed"}]}}' > "$sd/tasklist.json"
  run env STUB_DIR="$sd" ORCA_BIN="$(mk_stub)" bash "$OW" --until-all 60000 task_a
  [ "$status" -eq 0 ]
  [[ "$output" == *"completed=1/1"* ]]
  [[ "$output" != *"completed=0/1"* ]]     # the noise batch reported no progress
  [ "$(tr '\n' ',' < "$sd/acked")" = "delivery_hb,delivery_2," ]
}

@test "rejects a non-numeric timeout (boundary)" {
  run env ORCA_WAIT_DRYRUN=1 bash "$OW" "60000; rm -rf ~"
  [ "$status" -eq 1 ]
}

# Observed live while orchestrating this very change: a Delivery carried one
# worker_done from a PREVIOUS Wave's plan task plus one from an unrelated probe
# task, and orca-wait.sh exited 0 with completed=0/3 while all three of the
# current Wave's tasks were still running. "The batch had a worker_done" is not
# "this Wave progressed" — relevance must be judged against the caller's ids.
other_wave_done() { # $1 = delivery id
  printf '{"result":{"count":2,"deliveryId":"%s","messages":[{"type":"worker_done","id":"m1","from_handle":"term_x","payload":"{\\"taskId\\":\\"task_oldwave\\",\\"outcome\\":\\"succeeded\\"}","subject":"plan_ready: old"},{"type":"worker_done","id":"m2","from_handle":"term_y","payload":"{\\"taskId\\":\\"task_probe\\",\\"outcome\\":\\"succeeded\\"}","subject":"probe"}]}}' "$1"
}

@test "a batch whose only completions belong to OTHER tasks is not a completion here" {
  run env ORCA_WAIT_DRYRUN=1 ORCA_WAIT_CHECK_JSON="$(other_wave_done delivery_ow)" \
      ORCA_WAIT_TASKLIST_JSON='{"result":{"tasks":[]}}' \
      bash "$OW" 1000 task_a,task_b,task_c
  [ "$status" -eq 2 ]
  [[ "$output" == *"ack delivery_ow"* ]]
  [[ "$output" != *"completed="* ]]
}

@test "--until-all keeps waiting through an other-wave completion batch" {
  sd="$BATS_TEST_TMPDIR/sd"; mkdir -p "$sd"
  printf '%s' "$(other_wave_done delivery_ow)" > "$sd/1.json"
  printf '%s' "$(done_msg succeeded task_a)" | sed 's/delivery_1/delivery_2/' > "$sd/2.json"
  printf '{"result":{"tasks":[{"id":"task_a","status":"completed"}]}}' > "$sd/tasklist.json"
  run env STUB_DIR="$sd" ORCA_BIN="$(mk_stub)" bash "$OW" --until-all 60000 task_a
  [ "$status" -eq 0 ]
  [[ "$output" == *"completed=1/1"* ]]
  [ "$(tr '\n' ',' < "$sd/acked")" = "delivery_ow,delivery_2," ]
}

@test "with no task id list, relevance cannot be judged — any completion still counts" {
  run env ORCA_WAIT_DRYRUN=1 ORCA_WAIT_CHECK_JSON="$(other_wave_done delivery_ow)" \
      bash "$OW" 1000
  [ "$status" -eq 0 ]
  [[ "$output" == *"ack delivery_ow"* ]]
}
