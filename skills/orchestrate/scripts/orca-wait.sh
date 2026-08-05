#!/bin/sh
# orca-wait.sh — block on the Orca coordinator mailbox for ONE Delivery (or, with
# --until-all, for as many as this Wave needs) and classify it into
# watch-status.sh's exit-code contract. This is the Orca-
# substrate replacement for polling `.orchestration/status/*.json` every 15s:
# workers push `worker_done` / `escalation` / `question`, so the coordinator
# wakes on the event instead of on a timer (measured: question surfaced in 2.3s).
#
# usage: orca-wait.sh [--until-all] <timeout-ms> [task_id,task_id,...]
#   --until-all   keep consuming successful worker_done batches until every task
#                 id listed below is completed, then exit 0 once. Requires the
#                 task id list. Exit 3/5/6 still return immediately, unacked.
#   <timeout-ms>  total budget for this call (real tasks run 15-60 min); with
#                 --until-all it covers ALL batches and is never reset per batch
#   [task ids]    if given, also report how many of exactly THOSE tasks are
#                 completed — scoping the progress line to this Wave instead of
#                 to every task the Run has ever completed
#
# exit 0  worker_done(s) received, all succeeded, Delivery acked — process them
# exit 2  no completion in this call, or the ack did not land — CHECKPOINT: re-run
#         (--until-all: some tasks are still running; batches already acked in
#         this call are consumed and are not replayed)
# exit 3  a worker reported outcome=failed (or an unprovable worker_done)
# exit 5  an escalation is pending — resolve it, then re-run
# exit 6  a worker question is pending — `orchestration reply --id <msg>`, re-run
#
# Deliveries that need a coordinator decision (3/5/6) are deliberately NOT acked,
# so the same batch replays until it is handled — the same "never silently
# dropped" property watch-status.sh's exit 5 has. Orca delivery is at-least-once,
# so the coordinator must treat a replayed batch idempotently.
#
# A Delivery carrying NO worker_done (heartbeats reach this mailbox even though
# --types excludes them) is acked but never reported as exit 0 — it is consumed
# and the wait continues. Acking it is deliberate: liveness needs no decision, so
# replaying it forever would livelock the wait, while exit 0 would send the
# coordinator after completions that never happened.
#
# GROUNDWORK_ESCALATION_DIR is checked before EVERY blocking window: guardrails
# writes an escalation record from inside the worker regardless of whether the
# worker survives to send the matching Orca message, so this file check is the
# safety net that keeps a stuck worker from costing a whole timeout window. The
# record can land at any moment, including while this script is already blocked,
# so re-checking between windows is what bounds the detection delay to one
# interval instead of one full <timeout-ms>.
#
# env (also test hooks):
#   GROUNDWORK_ESCALATION_DIR  guardrails escalation sink to check (optional)
#   ORCA_WAIT_RECHECK_MS       escalation re-check interval in ms (default 15000,
#                              matching watch-status.sh's 15s poll); the total
#                              <timeout-ms> is split into windows of this size
#   ORCA_BIN                   orca executable (default: orca)
#   ORCA_WAIT_DRYRUN           print the ack instead of sending it
#   ORCA_WAIT_CHECK_JSON       canned `check --wait --json` Delivery (tests)
#   ORCA_WAIT_ACK_FAIL         force the ack to fail (tests)
#   ORCA_WAIT_TASKLIST_JSON    canned `task-list --status completed --json` (tests)
set -u

ORCA="${ORCA_BIN:-orca}"
JQ=$(command -v jq) || { echo "orca-wait: jq not found" >&2; exit 127; }

usage() { echo "usage: orca-wait.sh [--until-all] <timeout-ms> [task_id,...]" >&2; exit 1; }

until_all=0
while [ $# -gt 0 ]; do
  case "$1" in
    --until-all) until_all=1; shift ;;
    --) shift; break ;;
    -*) usage ;;
    *) break ;;
  esac
done

tmo="${1:-}"; want_ids="${2:-}"
case "$tmo" in ''|*[!0-9]*) usage ;; esac
case "$want_ids" in
  '') : ;;
  *[!A-Za-z0-9_,-]*) echo "orca-wait: task id list must be comma-separated ids" >&2; exit 1 ;;
esac
# "all of" needs a set to be all of; without ids there is no termination condition.
if [ "$until_all" = 1 ] && [ -z "$want_ids" ]; then
  echo "orca-wait: --until-all needs the task id list to be 'all' of" >&2
  exit 1
fi

# The blocking window is sliced this small so the escalation dir is re-read often.
# Rejected rather than clamped when unusable: a 0 interval would spin forever, and
# `00` passes the digit test, so the arithmetic test below is not redundant.
recheck="${ORCA_WAIT_RECHECK_MS:-15000}"
bad_recheck() { echo "orca-wait: ORCA_WAIT_RECHECK_MS must be a positive integer (ms)" >&2; exit 1; }
case "$recheck" in ''|*[!0-9]*) bad_recheck ;; esac
[ "$recheck" -gt 0 ] || bad_recheck

# 1) guardrails escalations first — a worker blocked on an `ask` must not cost a
#    full window, and this path does not depend on the worker staying alive.
esc_scan() { # 0 = pending (message printed), 1 = none
  escdir="${GROUNDWORK_ESCALATION_DIR:-}"
  [ -n "$escdir" ] && [ -d "$escdir" ] || return 1
  pending=""
  for e in "$escdir"/*.json; do
    [ -f "$e" ] || continue
    etk=$("$JQ" -r '.taskId // "?"' "$e" 2>/dev/null || echo "?")
    erule=$("$JQ" -r '.rule // "?"' "$e" 2>/dev/null || echo "?")
    pending="$pending ${etk}:${erule}"
  done
  [ -n "$pending" ] || return 1
  echo "[orca-wait] guardrails escalation pending —$pending — approve/deny and clear $escdir"
  return 0
}

# A payload arrives as a JSON *string* on the wire, but tolerate an object (or
# nothing) so a shape change can never read as success.
PAYLOAD='(.payload | if type=="string" then (fromjson? // {}) elif type=="object" then . else {} end)'

# 2) block for one Delivery, in windows of $recheck rather than one long wait, so
#    an escalation written mid-wait is seen within one interval. The windows sum
#    to exactly $tmo: the caller's deadline is neither extended nor truncated.
remaining="$tmo"; completed=0; total=0
while :; do
  if esc_scan; then exit 5; fi
  if [ "$remaining" -le 0 ]; then
    echo "[orca-wait] no message in ${tmo}ms — checkpoint, keep waiting"
    exit 2
  fi
  slice="$recheck"
  [ "$slice" -gt "$remaining" ] && slice="$remaining"

  if [ -n "${ORCA_WAIT_CHECK_JSON:-}" ]; then
    out="$ORCA_WAIT_CHECK_JSON"
  else
    out=$("$ORCA" orchestration check --wait \
          --types worker_done,escalation,question --timeout-ms "$slice" --json 2>/dev/null) || out=""
  fi
  remaining=$((remaining - slice))

  count=$(printf '%s' "$out" | "$JQ" -r '.result.count // 0' 2>/dev/null) || count=0
  case "$count" in ''|*[!0-9]*) count=0 ;; esac
  [ "$count" -lt 1 ] && continue

  delivery=$(printf '%s' "$out" | "$JQ" -r '.result.deliveryId // empty' 2>/dev/null)

  printf '%s' "$out" | "$JQ" -r '
    .result.messages[]? | . as $m | '"$PAYLOAD"' as $p |
    "msg type=\($m.type // "?") id=\($m.id // "-") from=\($m.from_handle // "-") task=\($p.taskId // "-") outcome=\($p.outcome // "-") files=\(($p.filesModified // []) | join(",")) :: \($m.subject // "")"
  ' 2>/dev/null

  n_of() { printf '%s' "$out" | "$JQ" -r "[.result.messages[]? | select(.type==\"$1\")] | length" 2>/dev/null || echo 0; }
  esc=$(n_of escalation); q=$(n_of question); dones=$(n_of worker_done)
  # How many of this batch's completions are ours. A worker_done belonging to an
  # EARLIER Wave (or to an unrelated task on the same Run) is delivered here too,
  # so "the batch had a worker_done" is not "this Wave progressed" — measured live:
  # a batch of one previous-Wave plan completion + one unrelated probe completion +
  # a heartbeat returned exit 0 while all three of this Wave's tasks still ran.
  # Without ids we cannot judge relevance, so every completion counts (as before).
  if [ -n "$want_ids" ]; then
    dones=$(printf '%s' "$out" | "$JQ" -r --arg ids "$want_ids" '
      ($ids | split(",") | map(select(length > 0))) as $want |
      [.result.messages[]? | select(.type=="worker_done") | '"$PAYLOAD"'
        | select((.outcome // "") == "succeeded")
        | select(.taskId as $t | $want | index($t))] | length' 2>/dev/null) || dones=0
  fi
  bad=$(printf '%s' "$out" | "$JQ" -r '
    [.result.messages[]? | select(.type=="worker_done") | '"$PAYLOAD"' | select((.outcome // "") != "succeeded")] | length
  ' 2>/dev/null) || bad=0
  for v in esc q bad dones; do
    eval "val=\$$v"; case "$val" in ''|*[!0-9]*) eval "$v=0" ;; esac
  done

  if [ "$esc" -gt 0 ]; then
    echo "[orca-wait] escalation pending — approve/deny, then re-run (left unread: ${delivery:--})"
    exit 5
  fi
  if [ "$q" -gt 0 ]; then
    printf '%s' "$out" | "$JQ" -r '.result.messages[]? | select(.type=="question")
      | "[orca-wait] next: orca orchestration reply --id \(.id) --body \"<answer>\" --json"' 2>/dev/null
    echo "[orca-wait] question pending — answer it, then re-run (left unread: ${delivery:--})"
    exit 6
  fi
  if [ "$bad" -gt 0 ]; then
    echo "[orca-wait] a worker reported failure (or an unprovable completion) — left unread: ${delivery:--}"
    exit 3
  fi

  # Nothing in this batch needs a decision: consume it so the next window returns
  # the following batch instead of replaying this one. If the ack does not land,
  # this batch WILL replay, so report the checkpoint code rather than exit 0 —
  # exit 0 must mean "consumed", or the coordinator double-counts.
  if [ -n "$delivery" ]; then
    acked=0
    if [ -n "${ORCA_WAIT_DRYRUN:-}" ]; then
      [ -z "${ORCA_WAIT_ACK_FAIL:-}" ] && acked=1
    elif "$ORCA" orchestration check --ack "$delivery" --json >/dev/null 2>&1; then
      acked=1
    fi
    if [ "$acked" = 1 ]; then
      echo "ack $delivery"
    else
      echo "[orca-wait] could not consume $delivery — it will replay; treat this window as a checkpoint" >&2
      exit 2
    fi
  fi

  # A Delivery can arrive carrying no worker_done at all — heartbeats reach this
  # mailbox even though --types asks only for worker_done/escalation/question. Exit
  # 0 means "completions arrived, process them", so returning it here sends the
  # coordinator after artifacts nobody produced. The batch is already acked above:
  # liveness needs no decision, and replaying it forever would livelock the wait.
  # Treat it as an empty window that happened to carry noise and keep waiting.
  if [ "$dones" -lt 1 ]; then
    echo "[orca-wait] batch carried no completion for these task ids — kept waiting"
    continue
  fi

  # Progress, scoped to the task ids this Wave actually dispatched. Counting every
  # completed task in the Run would fold in earlier Waves and overstate progress.
  if [ -n "$want_ids" ]; then
    if [ -n "${ORCA_WAIT_TASKLIST_JSON:-}" ]; then
      tl="$ORCA_WAIT_TASKLIST_JSON"
    else
      tl=$("$ORCA" orchestration task-list --status completed --json 2>/dev/null) || tl=""
    fi
    # `index` is exact membership. `inside` would be substring containment
    # (["task_1"] | inside(["task_12"]) is true), so a shorter id from another Wave
    # would count here — the exact inflation this scoping exists to prevent.
    completed=$(printf '%s' "$tl" | "$JQ" -r --arg ids "$want_ids" '
      ($ids | split(",") | map(select(length > 0))) as $want |
      [.result.tasks[]? | select((.status // "completed") == "completed")
                       | select(.id as $i | $want | index($i))] | length' 2>/dev/null) || completed=0
    case "$completed" in ''|*[!0-9]*) completed=0 ;; esac
    total=$(printf '%s' "$want_ids" | tr ',' '\n' | grep -c '[^[:space:]]')
    echo "completed=$completed/$total"
  fi

  # --until-all: this batch is consumed and acked, but the Wave is not finished
  # until every requested task id is completed. Keep waiting on the SAME budget —
  # termination keys off actual completions, never off "a batch arrived".
  if [ "$until_all" = 1 ] && [ "$completed" -lt "$total" ]; then
    continue
  fi
  exit 0
done
