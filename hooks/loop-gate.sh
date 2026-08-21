#!/usr/bin/env bash
# loop-orchestrator Stop hook — verification-loop integrity gate.
#
# Blocks a MANAGED worker session from ending while its recorded phase is
# pending|planning|implementing|rework — mid-loop abandonment. Every other
# phase (done/approved/merged/failed/plan_ready/impl_done, or an unknown/unset
# value) is terminal or an instructed wait-phase and allows the stop. Blocking
# additionally requires THIS session to be the managed worker: when the
# matched status entry has a non-empty .session, only a tmux session whose
# name equals it is blocked — a coordinator visiting the same worktree, or
# any non-tmux session, is never blocked. Records without .session (pre-
# launch-session.sh) fall back to cwd-match only. See design.md §8.4.
#
# Stop hook stdin is FLAT JSON (verified against real hook payloads):
#   { "cwd": "...", "session_id": "...", "transcript_path": "...",
#     "stop_hook_active": false }
# Block protocol: exit 2 + message on stderr → Claude keeps going.
set +e

INPUT=$(cat)
JQ=$(command -v jq)

if [ -n "$JQ" ]; then
  CWD=$(printf '%s' "$INPUT" | "$JQ" -r '.cwd // empty' 2>/dev/null)
  ACTIVE=$(printf '%s' "$INPUT" | "$JQ" -r '.stop_hook_active // false' 2>/dev/null)
else
  CWD="$PWD"; ACTIVE="false"
fi
[ -z "$CWD" ] && CWD="$PWD"
# Normalize to a physical path so /private, symlinks, and /var->/private/var
# differences don't break the worktree match (macOS).
CWD=$(cd "$CWD" 2>/dev/null && pwd -P || printf '%s' "$CWD")

# Already re-entered after a previous block → never loop forever.
[ "$ACTIVE" = "true" ] && exit 0
# Without jq we cannot read status JSON. jq is required for the whole
# orchestration (status-update needs it too), so a jq-less env can't run a
# managed session anyway → this no-op is harmless.
[ -z "$JQ" ] && exit 0

# Locate .orchestration/status by walking up from the session cwd.
dir="$CWD"; statusdir=""
while [ -n "$dir" ] && [ "$dir" != "/" ]; do
  if [ -d "$dir/.orchestration/status" ]; then
    statusdir="$dir/.orchestration/status"; break
  fi
  dir=$(dirname "$dir")
done
[ -z "$statusdir" ] && exit 0   # not a managed workspace

# Find the status entry whose worktree == this session's cwd; inspect its phase.
incomplete_phase=""
for f in "$statusdir"/*.json; do
  [ -e "$f" ] || continue
  wt=$("$JQ" -r '.worktree // empty' "$f" 2>/dev/null)
  ph=$("$JQ" -r '.phase // empty' "$f" 2>/dev/null)
  sess=$("$JQ" -r '.session // empty' "$f" 2>/dev/null)
  [ -n "$wt" ] && wt=$(cd "$wt" 2>/dev/null && pwd -P || printf '%s' "$wt")
  [ "$wt" = "$CWD" ] || continue

  # Session identity: only the managed tmux worker is blockable. A record
  # without .session (pre-launch-session.sh) falls back to cwd-match alone.
  if [ -n "$sess" ]; then
    is_worker=0
    if [ -n "$TMUX" ]; then
      tmux_bin="${LOOP_GATE_TMUX:-tmux}"
      cur_sess=$("$tmux_bin" display-message -p '#S' 2>/dev/null)
      [ -n "$cur_sess" ] && [ "$cur_sess" = "$sess" ] && is_worker=1
    fi
    [ "$is_worker" -eq 1 ] || break   # coordinator, or a non-matching/non-tmux session
  fi

  case "$ph" in
    pending|planning|implementing|rework) incomplete_phase="$ph" ;;
    *) : ;;   # terminal, instructed-wait, or unrecognized — allow stop
  esac
  break   # one status entry per worktree; stop at the matched one
done

if [ -n "$incomplete_phase" ]; then
  echo "loop-orchestrator: verification loop incomplete (phase=${incomplete_phase})." >&2
  echo "Finish the loop-implement cycle — tests written, test-quality-auditor PASS, definition-of-done met — then emit the completion signal (status-update) before stopping." >&2
  exit 2
fi
exit 0
