#!/usr/bin/env bash
# worker-blocked-signal.sh — Claude Code plugin hook (StopFailure, Notification,
# UserPromptSubmit). Inside the MANAGED tmux worker only, it records that the
# worker is blocked on something no human will answer, so the coordinator can
# wake immediately instead of waiting for the pane-hash stall heuristic.
# Plugin hooks fire in EVERY Claude Code session on the machine, so every path
# outside a managed worker match is a fast, silent no-op.
#
# BlockedRecord (the contract t3-blocked-consume reads):
#   path   <worktree>/.orchestration/blocked/<task>.json   (worktree-relative;
#          never written into the coordinator checkout, issue #167)
#   fields exactly seven strings:
#     ts        date -u +%Y-%m-%dT%H:%M:%SZ  (same format as status updatedAt)
#     taskId    status record basename without .json
#     session   status record session ("" when absent)
#     event     StopFailure | Notification
#     reason    the StopFailure error value (unknown when absent), or the
#               notification_type
#     detail    error_details or message, first 300 characters ("" when absent)
#     worktree  physical cwd of the worker session
#   write  StopFailure (any error); Notification types permission_prompt,
#          idle_prompt, elicitation_dialog, elicitation_url_dialog,
#          agent_needs_input, worker_permission_prompt,
#          quota_auto_resume_stale, quota_auto_resume_disabled
#   clear  UserPromptSubmit whose source is not loop_wakeup, schedule_wakeup,
#          or poll (a missing/unrecognized source still clears — an older CLI
#          omits the field for ordinary user prompts); Notification
#          quota_auto_resume_fired
#   last event wins.
#
# Meaning: the last blocking event since the last prompt submission or
# automatic usage-limit resume. A dialog answered by keys inside a running
# turn produces no clear event, so the file can outlive its block: a consumer
# treats the record as current only while its ts is later than the task's
# status updatedAt, combined with its own progress evidence.
#
# Always exits 0.
set +e

INPUT=$(cat)
JQ=$(command -v jq)
[ -z "$JQ" ] && exit 0

hook_event_name=$(printf '%s' "$INPUT" | "$JQ" -r '.hook_event_name // empty' 2>/dev/null)
cwd=$(printf '%s' "$INPUT" | "$JQ" -r '.cwd // empty' 2>/dev/null)
error=$(printf '%s' "$INPUT" | "$JQ" -r '.error // empty' 2>/dev/null)
error_details=$(printf '%s' "$INPUT" | "$JQ" -r '.error_details // empty' 2>/dev/null)
notification_type=$(printf '%s' "$INPUT" | "$JQ" -r '.notification_type // empty' 2>/dev/null)
message=$(printf '%s' "$INPUT" | "$JQ" -r '.message // empty' 2>/dev/null)
source=$(printf '%s' "$INPUT" | "$JQ" -r '.source // empty' 2>/dev/null)

mode=""
event=""
reason=""
detail=""

case "$hook_event_name" in
  StopFailure)
    mode=write
    event=StopFailure
    reason="${error:-unknown}"
    detail="$error_details"
    ;;
  Notification)
    case "$notification_type" in
      permission_prompt|idle_prompt|elicitation_dialog|elicitation_url_dialog|agent_needs_input|worker_permission_prompt|quota_auto_resume_stale|quota_auto_resume_disabled)
        mode=write
        event=Notification
        reason="$notification_type"
        detail="$message"
        ;;
      quota_auto_resume_fired)
        mode=clear
        ;;
      *)
        exit 0
        ;;
    esac
    ;;
  UserPromptSubmit)
    case "$source" in
      loop_wakeup|schedule_wakeup|poll) exit 0 ;;
      *) mode=clear ;;
    esac
    ;;
  *)
    exit 0
    ;;
esac

[ -z "$cwd" ] && exit 0
CWD=$(cd "$cwd" 2>/dev/null && pwd -P)
[ -z "$CWD" ] && exit 0

# Walk up from CWD to the nearest dir containing .orchestration/status.
dir="$CWD"; statusdir=""
while [ -n "$dir" ] && [ "$dir" != "/" ]; do
  if [ -d "$dir/.orchestration/status" ]; then
    statusdir="$dir/.orchestration/status"; break
  fi
  dir=$(dirname "$dir")
done
[ -z "$statusdir" ] && exit 0

task=""
session=""
for f in "$statusdir"/*.json; do
  [ -e "$f" ] || continue
  wt=$("$JQ" -r '.worktree // empty' "$f" 2>/dev/null)
  sess=$("$JQ" -r '.session // empty' "$f" 2>/dev/null)
  [ -n "$wt" ] && wt=$(cd "$wt" 2>/dev/null && pwd -P || printf '%s' "$wt")
  [ "$wt" = "$CWD" ] || continue

  if [ -n "$sess" ]; then
    is_worker=0
    if [ -n "$TMUX" ]; then
      tmux_bin="${BLOCKED_SIGNAL_TMUX:-tmux}"
      cur_sess=$("$tmux_bin" display-message -p '#S' 2>/dev/null)
      [ -n "$cur_sess" ] && [ "$cur_sess" = "$sess" ] && is_worker=1
    fi
    [ "$is_worker" -eq 1 ] || exit 0
  fi

  task=$(basename "$f" .json)
  session="$sess"
  break
done
[ -z "$task" ] && exit 0

if [ "$mode" = clear ]; then
  rm -f "$CWD/.orchestration/blocked/$task.json"
  exit 0
fi

# mode=write
blocked_dir="$CWD/.orchestration/blocked"
mkdir -p "$blocked_dir" 2>/dev/null || exit 0
tmp="$blocked_dir/.$task.json.tmp.$$"
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
"$JQ" -n \
  --arg ts "$ts" \
  --arg taskId "$task" \
  --arg session "$session" \
  --arg event "$event" \
  --arg reason "$reason" \
  --arg detail "$detail" \
  --arg worktree "$CWD" \
  '{ts:$ts,taskId:$taskId,session:$session,event:$event,reason:$reason,detail:($detail[0:300]),worktree:$worktree}' \
  > "$tmp" 2>/dev/null \
  && mv -f "$tmp" "$blocked_dir/$task.json" 2>/dev/null \
  || rm -f "$tmp" 2>/dev/null
exit 0
