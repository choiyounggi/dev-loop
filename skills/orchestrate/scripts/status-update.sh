#!/bin/sh
# status-update.sh — the single session->orchestrator status channel.
# A session calls this at the end of each phase to record its state.
#
# usage: STATUS_DIR=<absolute-dir> status-update.sh <task> <phase> [key=value ...]
#   phase: pending|planning|plan_ready|implementing|impl_done|approved|merged|done|failed
#   extra: worktree=... branch=... prUrl=... planPath=... error=... reworkCount=...
#
# e.g. STATUS_DIR=/repo/.orchestration/status status-update.sh task-1 plan_ready worktree=/repo/.worktrees/task-1
set -eu
JQ=$(command -v jq) || { echo "status-update: jq not found" >&2; exit 127; }

dir="${STATUS_DIR:?STATUS_DIR env required}"
[ $# -ge 2 ] || { echo "usage: status-update.sh <task> <phase> [k=v ...]" >&2; exit 1; }
task="$1"; phase="$2"; shift 2

mkdir -p "$dir"
file="$dir/$task.json"
[ -f "$file" ] || printf '{"task":"%s"}' "$task" > "$file"

now=$(date -u +%Y-%m-%dT%H:%M:%SZ)   # cross-platform (GNU/BSD) iso-8601 UTC
wt=$(pwd -P)                          # physical path so loop-gate can match it
# Record the tmux session name so watch-status can detect a dead worker. The
# worker runs inside its tmux session; allow an explicit override (orchestrator
# / tests) via STATUS_SESSION.
sess="${STATUS_SESSION:-$(tmux display-message -p '#S' 2>/dev/null || true)}"

# Collect the extra key=value pairs into one JSON object first (in memory — no
# file writes), so the whole record lands in a single atomic write below.
extra='{}'
for kv in "$@"; do
  case "$kv" in
    *=*) : ;;
    *) echo "status-update: ignoring malformed extra '$kv' (expected key=value)" >&2; continue ;;
  esac
  k=${kv%%=*}; v=${kv#*=}
  extra=$(printf '%s' "$extra" | "$JQ" --arg k "$k" --arg v "$v" '.[$k]=$v')
done

# One atomic write: phase + timestamp + worktree + all extras (extras win on key
# collisions, e.g. an explicit worktree= overrides the cwd default).
tmp="$file.tmp.$$"
trap 'rm -f "$tmp"' EXIT
"$JQ" --arg p "$phase" --arg t "$now" --arg w "$wt" --arg s "$sess" --argjson e "$extra" \
  '.phase=$p | .updatedAt=$t | .worktree=$w
   | (if $s != "" then .session=$s else . end)
   | . + $e' "$file" > "$tmp" && mv "$tmp" "$file"

echo "status[$task] = $phase"
