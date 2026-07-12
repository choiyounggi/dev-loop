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
tmp="$file.tmp.$$"
trap 'rm -f "$tmp"' EXIT
# phase + timestamp + worktree in one atomic write
"$JQ" --arg p "$phase" --arg t "$now" --arg w "$wt" \
  '.phase=$p | .updatedAt=$t | .worktree=$w' "$file" > "$tmp" && mv "$tmp" "$file"

for kv in "$@"; do
  case "$kv" in
    *=*) : ;;
    *) echo "status-update: ignoring malformed extra '$kv' (expected key=value)" >&2; continue ;;
  esac
  k=${kv%%=*}; v=${kv#*=}
  "$JQ" --arg k "$k" --arg v "$v" '.[$k]=$v' "$file" > "$tmp" && mv "$tmp" "$file"
done

echo "status[$task] = $phase"
