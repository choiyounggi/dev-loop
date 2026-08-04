#!/bin/sh
# orca-wait.sh — block on the Orca coordinator mailbox for ONE Delivery and
# classify it into watch-status.sh's exit-code contract. This is the Orca-
# substrate replacement for polling `.orchestration/status/*.json` every 15s:
# workers push `worker_done` / `escalation` / `question`, so the coordinator
# wakes on the event instead of on a timer (measured: question surfaced in 2.3s).
#
# usage: orca-wait.sh <timeout-ms> [task_id,task_id,...]
#   <timeout-ms>  how long this window blocks (real tasks run 15-60 min)
#   [task ids]    if given, also report how many of exactly THOSE tasks are
#                 completed — scoping the progress line to this Wave instead of
#                 to every task the Run has ever completed
#
# exit 0  worker_done(s) received, all succeeded, Delivery acked — process them
# exit 2  no message in this window, or the ack did not land — CHECKPOINT: re-run
# exit 3  a worker reported outcome=failed (or an unprovable worker_done)
# exit 5  an escalation is pending — resolve it, then re-run
# exit 6  a worker question is pending — `orchestration reply --id <msg>`, re-run
#
# Deliveries that need a coordinator decision (3/5/6) are deliberately NOT acked,
# so the same batch replays until it is handled — the same "never silently
# dropped" property watch-status.sh's exit 5 has. Orca delivery is at-least-once,
# so the coordinator must treat a replayed batch idempotently.
#
# GROUNDWORK_ESCALATION_DIR is checked BEFORE blocking: guardrails writes an
# escalation record from inside the worker regardless of whether the worker
# survives to send the matching Orca message, so this file check is the safety
# net that keeps a stuck worker from costing a whole timeout window.
#
# env (also test hooks):
#   GROUNDWORK_ESCALATION_DIR  guardrails escalation sink to pre-check (optional)
#   ORCA_BIN                   orca executable (default: orca)
#   ORCA_WAIT_DRYRUN           print the ack instead of sending it
#   ORCA_WAIT_CHECK_JSON       canned `check --wait --json` Delivery (tests)
#   ORCA_WAIT_ACK_FAIL         force the ack to fail (tests)
#   ORCA_WAIT_TASKLIST_JSON    canned `task-list --status completed --json` (tests)
set -u

ORCA="${ORCA_BIN:-orca}"
JQ=$(command -v jq) || { echo "orca-wait: jq not found" >&2; exit 127; }

tmo="${1:-}"; want_ids="${2:-}"
case "$tmo" in ''|*[!0-9]*) echo "usage: orca-wait.sh <timeout-ms> [task_id,...]" >&2; exit 1 ;; esac
case "$want_ids" in
  '') : ;;
  *[!A-Za-z0-9_,-]*) echo "orca-wait: task id list must be comma-separated ids" >&2; exit 1 ;;
esac

# 1) guardrails escalations first — a worker blocked on an `ask` must not cost a
#    full window, and this path does not depend on the worker staying alive.
escdir="${GROUNDWORK_ESCALATION_DIR:-}"
if [ -n "$escdir" ] && [ -d "$escdir" ]; then
  pending=""
  for e in "$escdir"/*.json; do
    [ -f "$e" ] || continue
    etk=$("$JQ" -r '.taskId // "?"' "$e" 2>/dev/null || echo "?")
    erule=$("$JQ" -r '.rule // "?"' "$e" 2>/dev/null || echo "?")
    pending="$pending ${etk}:${erule}"
  done
  if [ -n "$pending" ]; then
    echo "[orca-wait] guardrails escalation pending —$pending — approve/deny and clear $escdir"
    exit 5
  fi
fi

# 2) block for one Delivery
if [ -n "${ORCA_WAIT_CHECK_JSON:-}" ]; then
  out="$ORCA_WAIT_CHECK_JSON"
else
  out=$("$ORCA" orchestration check --wait \
        --types worker_done,escalation,question --timeout-ms "$tmo" --json 2>/dev/null) || out=""
fi

# A payload arrives as a JSON *string* on the wire, but tolerate an object (or
# nothing) so a shape change can never read as success.
PAYLOAD='(.payload | if type=="string" then (fromjson? // {}) elif type=="object" then . else {} end)'

count=$(printf '%s' "$out" | "$JQ" -r '.result.count // 0' 2>/dev/null) || count=0
case "$count" in ''|*[!0-9]*) count=0 ;; esac
if [ "$count" -lt 1 ]; then
  echo "[orca-wait] no message in ${tmo}ms — checkpoint, keep waiting"
  exit 2
fi

delivery=$(printf '%s' "$out" | "$JQ" -r '.result.deliveryId // empty' 2>/dev/null)

printf '%s' "$out" | "$JQ" -r '
  .result.messages[]? | . as $m | '"$PAYLOAD"' as $p |
  "msg type=\($m.type // "?") id=\($m.id // "-") from=\($m.from_handle // "-") task=\($p.taskId // "-") outcome=\($p.outcome // "-") files=\(($p.filesModified // []) | join(",")) :: \($m.subject // "")"
' 2>/dev/null

n_of() { printf '%s' "$out" | "$JQ" -r "[.result.messages[]? | select(.type==\"$1\")] | length" 2>/dev/null || echo 0; }
esc=$(n_of escalation); q=$(n_of question)
bad=$(printf '%s' "$out" | "$JQ" -r '
  [.result.messages[]? | select(.type=="worker_done") | '"$PAYLOAD"' | select((.outcome // "") != "succeeded")] | length
' 2>/dev/null) || bad=0
for v in esc q bad; do
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

# Everything in this batch was a successful completion: consume it so the next
# window returns the following batch instead of replaying this one. If the ack
# does not land, this batch WILL replay, so report the checkpoint code rather
# than exit 0 — exit 0 must mean "consumed", or the coordinator double-counts.
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

# Progress, scoped to the task ids this Wave actually dispatched. Counting every
# completed task in the Run would fold in earlier Waves and overstate progress.
if [ -n "$want_ids" ]; then
  if [ -n "${ORCA_WAIT_TASKLIST_JSON:-}" ]; then
    tl="$ORCA_WAIT_TASKLIST_JSON"
  else
    tl=$("$ORCA" orchestration task-list --status completed --json 2>/dev/null) || tl=""
  fi
  completed=$(printf '%s' "$tl" | "$JQ" -r --arg ids "$want_ids" '
    ($ids | split(",") | map(select(length > 0))) as $want |
    [.result.tasks[]? | select((.status // "completed") == "completed")
                     | select([.id] | inside($want))] | length' 2>/dev/null) || completed=0
  case "$completed" in ''|*[!0-9]*) completed=0 ;; esac
  total=$(printf '%s' "$want_ids" | tr ',' '\n' | grep -c '[^[:space:]]')
  echo "completed=$completed/$total"
fi
exit 0
